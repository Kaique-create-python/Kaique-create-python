"""Real filesystem/protocol and HTTP transport boundaries, with no sockets."""
import contextlib
import copy
import gzip
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from installer14 import cloud as transport
from installer14.cli import hidden_key
from installer14.codec import Failure
from installer14.paths import guard, write_once
from installer14.runtime import Runtime, TARGET, read, save
from test_installer14 import FakeCloud, fixture, patch_place


class FilesystemTests(unittest.TestCase):
    def test_parent_traversal_is_blocked_even_with_lexical_state_prefix(self):
        with tempfile.TemporaryDirectory() as name:
            state=Path(name)/'state';state.mkdir()
            with self.assertRaises(Failure): guard(state/'..'/'outside.json',state)
    def test_symlink_ancestor_and_conflicting_backup_preserve_original(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);outside=root/'outside';outside.mkdir();(root/'link').symlink_to(outside,target_is_directory=True)
            with self.assertRaises(Failure):write_once(root/'link'/'file',b'new')
            backup=root/'backup';write_once(backup,b'original')
            with self.assertRaises(Failure):write_once(backup,b'new')
            self.assertEqual(backup.read_bytes(),b'original')
    def test_missing_zstd_raises_friendly_failure_with_correct_termux_package(self):
        from installer14.codec import Compression
        with patch('installer14.codec.ctypes.util.find_library',return_value=None),patch('installer14.codec.ctypes.CDLL',side_effect=OSError('missing')):
            with self.assertRaisesRegex(Failure,'pkg install zstd'):
                Compression()
    def test_getpass_warning_fails_closed(self):
        import getpass,warnings
        def unsupported(*args):warnings.warn('echo would be enabled',getpass.GetPassWarning);return 'NEVER-READ'
        with patch('getpass.getpass',side_effect=unsupported),self.assertRaises(Failure):hidden_key()


class ReceiptBoundaries(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.rt=Runtime(self.root,14,'sources-digest',patch_place,lambda version,verify:['verify'])
        self.cloud=FakeCloud()
    def tearDown(self):self.temp.cleanup()
    def test_empty_existing_active_receipt_is_not_treated_as_absent(self):
        save(self.rt.active,{})
        with self.assertRaises(Failure):self.rt.test(self.cloud)
        self.assertEqual(read(self.rt.active),{});self.assertEqual(self.cloud.writes,[])
    def test_foreign_receipt_arriving_during_post_is_never_overwritten(self):
        for uncertain in (False,True):
            with self.subTest(uncertain=uncertain):
                self.rt.active.unlink(missing_ok=True)
                self.cloud=FakeCloud()
                request=self.cloud.request
                def substituted(*args,**kwargs):
                    result=request(*args,**kwargs)
                    save(self.rt.active,{'package':'FOREIGN','original':'preserve'})
                    if uncertain:raise Failure('uncertain')
                    return result
                with patch.object(self.cloud,'request',side_effect=substituted),self.assertRaises(Failure):self.rt.test(self.cloud)
                self.assertEqual(read(self.rt.active),{'package':'FOREIGN','original':'preserve'})
    def test_invalid_intent_cannot_write_receipt_outside_state(self):
        self.cloud.fail_write=True
        with self.assertRaises(Failure):self.rt.test(self.cloud)
        entry=read(self.rt.active);entry['intent']='../../outside';save(self.rt.active,entry)
        self.cloud.fail_write=False
        with self.assertRaises(Failure):self.rt.resume(self.cloud)
        self.assertEqual(read(self.rt.active),entry)
    def test_intent_is_on_disk_before_post_and_invalid_response_stays_pending(self):
        request=self.cloud.request
        def check_intent(*args,**kwargs):
            entry=read(self.rt.active)
            self.assertEqual(entry['status'],'UPLOADING')
            self.assertEqual(entry['mode'],'Saved')
            request(*args,**kwargs)
            return {'versionNumber':8}
        with patch.object(self.cloud,'request',side_effect=check_intent),self.assertRaises(Failure):self.rt.test(self.cloud)
        self.assertEqual(read(self.rt.active)['status'],'UNCERTAIN')
        self.rt.resume(self.cloud)
        self.assertEqual(self.cloud.writes,['Saved'])
    def test_wrong_package_in_saved_test_proof_blocks_publish(self):
        self.rt.test(self.cloud)
        proof=read(self.rt.state/'test.json');proof['reports'][0]['package']='FOREIGN';save(self.rt.state/'test.json',proof)
        with patch('builtins.input',return_value='PUBLICAR AJUSTE14'),self.assertRaises(Failure):self.rt.publish(self.cloud)
        self.assertEqual(self.cloud.writes,['Saved'])


class Response(io.BytesIO):
    def __init__(self,raw,headers=None,status=200):super().__init__(raw);self.headers=headers or {};self.status=status
class Opener:
    def __init__(self,*responses):self.responses=list(responses);self.requests=[]
    def open(self,request,timeout):
        self.requests.append(request)
        result=self.responses.pop(0)
        if isinstance(result,Exception):raise result
        return result


class TransportTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.state_patch=patch.object(transport,'STATE',self.root);self.state_patch.start()
        self.cloud=transport.Cloud('TEST-SECRET-NOT-REAL',dict(TARGET))
    def tearDown(self):self.state_patch.stop();self.temp.cleanup()
    def test_post_network_failure_is_one_attempt_and_secret_is_hidden(self):
        opener=Opener(URLError('failed TEST-SECRET-NOT-REAL'))
        self.cloud.opener=opener
        with self.assertRaises(Failure) as error:self.cloud.request('/upload',raw=b'x',method='POST')
        self.assertEqual(len(opener.requests),1);self.assertNotIn(self.cloud.key,str(error.exception))
    def test_post_503_is_one_attempt_and_secret_is_hidden(self):
        error=HTTPError('https://apis.roblox.com/test',503,'bad',{},io.BytesIO(b'TEST-SECRET-NOT-REAL'))
        opener=Opener(error);self.cloud.opener=opener
        with self.assertRaises(Failure) as caught:self.cloud.request('/upload',raw=b'x',method='POST')
        self.assertEqual(len(opener.requests),1);self.assertNotIn(self.cloud.key,str(caught.exception))
    def test_get_retry_is_bounded_to_three_requests(self):
        opener=Opener(URLError('retry'),URLError('retry'),Response(b'{"ok":true}'));self.cloud.opener=opener
        with patch.object(transport.time,'sleep'):self.assertEqual(self.cloud.request('/read'),{'ok':True})
        self.assertEqual(len(opener.requests),3)
    def test_download_gzip_is_validated_before_preserving_integral_backup(self):
        raw=fixture();self.cloud.opener=Opener(Response(gzip.compress(raw),{'Content-Encoding':'gzip'}))
        path=self.root/'backup.rbxl';self.assertEqual(self.cloud.download(8,path),raw);self.assertEqual(path.read_bytes(),raw)
    def test_cdn_never_receives_api_key(self):
        opener=Opener(Response(fixture()))
        self.cloud.opener=Opener(Response(json.dumps({'assetTypeId':9,'location':'https://c0.rbxcdn.com/abc'}).encode()))
        with patch.object(transport,'build_opener',return_value=opener):self.cloud.download(8,self.root/'backup')
        self.assertNotIn('X-api-key',opener.requests[0].headers)
    def test_http_redirect_to_untrusted_host_is_rejected_without_request(self):
        error=HTTPError('https://apis.roblox.com/x',302,'redirect',{'Location':'https://example.org/payload'},io.BytesIO())
        self.cloud.opener=Opener(error)
        with self.assertRaises(Failure):self.cloud.download(8,self.root/'backup')
        self.assertFalse((self.root/'backup').exists())
    def test_html_and_conflicting_backup_are_never_saved(self):
        path=self.root/'backup';path.write_bytes(b'original')
        for raw in (b'<html>invalid</html>',fixture()):
            self.cloud.opener=Opener(Response(raw))
            with self.assertRaises(Failure):self.cloud.download(8,path)
            self.assertEqual(path.read_bytes(),b'original')
    def test_task_error_does_not_echo_api_key(self):
        result={'state':'FAILED','path':f"universes/{TARGET['universe']}/places/{TARGET['place']}/versions/8/luau-execution-sessions/session/tasks/task",'error':{'message':'rejected TEST-SECRET-NOT-REAL'}}
        with patch.object(self.cloud,'request',return_value=result),self.assertRaises(Failure) as caught:self.cloud.task(8,'return {}')
        self.assertNotIn(self.cloud.key,str(caught.exception))
    def test_destination_override_rejected_before_network(self):
        with self.assertRaises(Failure):transport.Cloud('TEST',dict(TARGET,place=1))


class ReviewRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.rt=Runtime(self.root,14,'sources-digest',patch_place,lambda version,verify:['verify'])
        self.cloud=FakeCloud()
    def tearDown(self):self.temp.cleanup()
    def test_approved_proof_is_revoked_before_any_failed_revalidation(self):
        for boundary in ('validate_destination','download','task'):
            with self.subTest(boundary=boundary):
                self.rt.test(self.cloud)
                with patch.object(self.cloud,boundary,side_effect=Failure('revalidation failed')),self.assertRaises(Failure):self.rt.test(self.cloud)
                with patch('builtins.input',return_value='PUBLICAR AJUSTE14'),self.assertRaises(Failure):self.rt.publish(self.cloud)
                self.assertNotIn('Published',self.cloud.writes)
    def test_intent_and_ready_are_durable_before_post(self):
        import os,stat
        events=[];fsync=os.fsync;request=self.cloud.request
        def barrier(fd):
            events.append(('directory'if stat.S_ISDIR(os.fstat(fd).st_mode)else'file',os.readlink('/proc/self/fd/'+str(fd))))
            return fsync(fd)
        def post(*args,**kwargs):
            intent=read(self.rt.active);ready=intent['ready']
            self.assertIn(('file',ready),events)
            self.assertIn(('directory',str(self.rt.state)),events)
            self.assertIn(('file',str(self.rt.active)),events)
            self.assertEqual(events[-1],('directory',str(self.rt.root)))
            return request(*args,**kwargs)
        with patch('os.fsync',side_effect=barrier),patch.object(self.cloud,'request',side_effect=post):self.rt.test(self.cloud)
    def test_directory_barrier_failure_blocks_post_and_revokes_approval(self):
        import os,stat
        self.rt.test(self.cloud)
        oldwrites=list(self.cloud.writes);fsync=os.fsync
        def failed_directory(fd):
            if stat.S_ISDIR(os.fstat(fd).st_mode):raise OSError('directory persistence unavailable')
            return fsync(fd)
        with patch('os.fsync',side_effect=failed_directory),self.assertRaises(OSError):self.rt.test(self.cloud)
        with patch('builtins.input',return_value='PUBLICAR AJUSTE14'),self.assertRaises(Failure):self.rt.publish(self.cloud)
        self.assertEqual(self.cloud.writes,oldwrites)
    def test_active_directory_barrier_failure_stops_before_post(self):
        import os,stat
        fsync=os.fsync
        def fail_intent_directory(fd):
            if self.rt.active.exists() and stat.S_ISDIR(os.fstat(fd).st_mode) and os.readlink('/proc/self/fd/'+str(fd))==str(self.rt.root):
                raise OSError('intent directory is not durable')
            return fsync(fd)
        with patch('os.fsync',side_effect=fail_intent_directory),self.assertRaises(OSError):self.rt.test(self.cloud)
        self.assertEqual(self.cloud.writes,[])
        self.assertEqual(read(self.rt.active)['status'],'UPLOADING')
    def test_rename_unlink_and_new_directory_entries_have_directory_barriers(self):
        import os,stat
        from installer14.paths import private_dir
        events=[];fsync=os.fsync
        def barrier(fd):
            events.append(('directory'if stat.S_ISDIR(os.fstat(fd).st_mode)else'file',os.readlink('/proc/self/fd/'+str(fd))))
            return fsync(fd)
        with patch('os.fsync',side_effect=barrier):
            child=private_dir(self.root/'new'/'nested')
            save(child/'metadata.json',{'safe':True})
        self.assertIn(('directory',str(self.root)),events)
        self.assertIn(('directory',str(self.root/'new')),events)
        self.assertEqual(events[-1],('directory',str(child)))
        self.rt.test(self.cloud)
        events.clear()
        # Force uncertain POST so resume can be observed after unlink directly.
        self.cloud.fail_write=True
        with patch('builtins.input',return_value='PUBLICAR AJUSTE14'),self.assertRaises(Failure):self.rt.publish(self.cloud)
        self.cloud.fail_write=False
        with patch('os.fsync',side_effect=barrier):self.rt.resume(self.cloud)
        self.assertEqual(events[-1],('directory',str(self.rt.root)))
    def test_task_path_cannot_echo_secret(self):
        with patch.object(transport,'STATE',self.root),patch.object(transport,'PACKAGE','BIZARRE-AJUSTE-14'):
            cloud=transport.Cloud('TESTSECRET',dict(TARGET))
            response={'state':'COMPLETE','path':f"universes/{TARGET['universe']}/places/{TARGET['place']}/versions/8/luau-execution-sessions/TESTSECRET/tasks/task",'output':{'results':[{'package':'BIZARRE-AJUSTE-14','passed':True}]}}
            output=io.StringIO()
            with patch.object(cloud,'request',return_value=response),contextlib.redirect_stdout(output):cloud.task(8,'return {}')
            self.assertNotIn(cloud.key,output.getvalue())

if __name__=='__main__':unittest.main()
