import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import warnings

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audio_auth_under_test',ROOT/'tooling/prepare_audio.py')
audio=importlib.util.module_from_spec(spec);sys.modules[spec.name]=audio;spec.loader.exec_module(audio)

class AudioHiddenInputTests(unittest.TestCase):
    def plan(self,root):
        p=root/'plan.json'
        p.write_text(json.dumps({'schemaVersion':1,'target':{'userId':'10735737143','universeId':'10776462844','placeId':'89520940302906'},
         'voices':{'PAVEL':{'voiceId':'voice'}},'clips':[{'key':'test','kind':'tts','role':'PAVEL','text':'Teste.',
         'profile':'local','category':'Voice','volume':.7,'radio':False}]}))
        return p

    def test_non_tty_refuses_before_reading_key_or_contacting_provider(self):
        with tempfile.TemporaryDirectory() as temp:
            plan=self.plan(Path(temp));transport=Mock(side_effect=audio.AudioProductionError('unexpected transport'))
            with patch.object(audio.sys.stdin,'isatty',return_value=False),patch.object(audio.getpass,'getpass',return_value='sensitive-test-key') as read:
                with self.assertRaises(audio.AudioProductionError):audio.prepare(plan,transport=transport)
                read.assert_not_called();transport.assert_not_called()

    def test_echo_warning_cannot_fall_back_to_visible_input(self):
        def bad_reader(*args):
            warnings.warn('echo unavailable',audio.getpass.GetPassWarning)
            return 'sensitive-test-key'
        with tempfile.TemporaryDirectory() as temp:
            plan=self.plan(Path(temp));transport=Mock(side_effect=audio.AudioProductionError('unexpected transport'))
            out,err=io.StringIO(),io.StringIO()
            with contextlib.redirect_stdout(out),contextlib.redirect_stderr(err),patch.object(audio.sys.stdin,'isatty',return_value=True),patch.object(audio.getpass,'getpass',side_effect=bad_reader):
                with self.assertRaises(audio.AudioProductionError):audio.prepare(plan,transport=transport)
            transport.assert_not_called();self.assertNotIn('sensitive-test-key',out.getvalue()+err.getvalue())

    def test_recovery_cli_uses_the_same_hidden_input_guard(self):
        with patch.object(audio.sys.stdin,'isatty',return_value=False),patch.object(audio.getpass,'getpass',return_value='sensitive-test-key') as read,patch.object(audio,'recover_history') as recover,contextlib.redirect_stderr(io.StringIO()):
            result=audio.main(['--recover-history','test','id'])
        self.assertEqual(result,2);read.assert_not_called();recover.assert_not_called()

if __name__=='__main__':unittest.main()
