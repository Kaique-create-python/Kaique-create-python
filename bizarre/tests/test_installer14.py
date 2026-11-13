"""Regressões reais do patch e protocolo; só a fronteira Roblox é simulada."""
import copy
import hashlib
import importlib.util
import io
import json
import struct
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch as replace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from installer14.codec import Binary, Chunk, Compression, Failure, pack32, prefs, pstring
from installer14.runtime import Runtime, TARGET, read, save, sha

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ['ServerScriptService', 'BB_Servidor', 'PersonagensR6']
CAMERA_PATH = ['ReplicatedStorage', 'BB', 'Cliente', 'Camera']


def fixture(binary=False):
    rows = [
        (-1, 'ReplicatedStorage', 'ReplicatedStorage', None),
        (0, 'BB', 'Folder', None), (1, 'Cliente', 'Folder', None),
        (2, 'Camera', 'ModuleScript', 'return "camera antiga"'),
        (-1, 'ServerScriptService', 'ServerScriptService', None),
        (4, 'BB_Servidor', 'Folder', None),
        (5, 'Dados', 'ModuleScript', 'return "nao alterar economia"'),
        (-1, 'Workspace', 'Workspace', None), (7, 'Morioh', 'Model', None),
        (8, 'Casa', 'Part', None),
        (-1, 'StarterPlayer', 'StarterPlayer', None),
        (10, 'StarterPlayerScripts', 'StarterPlayerScripts', None),
        (0, 'BB_VozesAnime', 'StringValue', None),
    ]
    if not binary:
        root = ET.Element('roblox', version='4')
        items = []
        for n, (parent, name, cls, source) in enumerate(rows):
            item = ET.SubElement(root if parent == -1 else items[parent], 'Item', {'class': cls, 'referent': str(n)})
            p = ET.SubElement(item, 'Properties')
            ET.SubElement(p, 'string', name='Name').text = name
            if source is not None:
                ET.SubElement(p, 'ProtectedString', name='Source').text = source
            if name == 'Casa': ET.SubElement(p, 'bool', name='CanCollide').text = 'true'
            if name == 'BB_VozesAnime': ET.SubElement(p, 'string', name='Value').text = '987654321:64'
            items.append(item)
        return ET.tostring(root)
    chunks = []
    grouped = {}
    for n, row in enumerate(rows): grouped.setdefault(row[2], []).append((n, row))
    for gid, (cls, objects) in enumerate(grouped.items()):
        refs = [n for n, row in objects]
        chunks.append(Chunk(b'INST', pack32(gid) + pstring(cls.encode()) + b'\0' + pack32(len(refs)) + prefs(refs)))
        chunks.append(Chunk(b'PROP', pack32(gid) + pstring(b'Name') + b'\1' + b''.join(pstring(row[1].encode()) for _, row in objects)))
        if cls == 'ModuleScript': chunks.append(Chunk(b'PROP', pack32(gid) + pstring(b'Source') + b'\1' + b''.join(pstring(row[3].encode()) for _, row in objects)))
    chunks.append(Chunk(b'BBOP', b'opaque-unknown-packet-must-survive'))
    chunks.append(Chunk(b'PRNT', b'\0' + pack32(len(rows)) + prefs(list(range(len(rows)))) + prefs([row[0] for row in rows])))
    chunks.append(Chunk(b'END\0', b'</roblox>'))
    header = b'<roblox!\x89\xff\r\n\x1a\n\0\0' + pack32(len(grouped)) + pack32(len(rows)) + bytes(8)
    return header + b''.join(chunk.encoded(Compression()) for chunk in chunks)


def targets():
    return [dict(path=CAMERA_PATH, cls='ModuleScript', source='return "camera corrigida"', known=[sha(b'return "camera antiga"')], add=False),
            dict(path=MODULE_PATH, cls='ModuleScript', source='return { rig = "R6" }', known=[], add=True)]


def patch_place(raw):
    from installer14.patcher import patch_place as actual
    return actual(raw, targets())


class SourcePatchTests(unittest.TestCase):
    def test_changes_sources_adds_r6_without_altering_map_or_media(self):
        for binary in (False, True):
            with self.subTest(binary=binary):
                raw = fixture(binary)
                ready, changed = patch_place(raw)
                self.assertTrue(changed)
                self.assertEqual(patch_place(ready), (ready, False))
                if binary:
                    a, b = Binary(raw), Binary(ready)
                    self.assertEqual(len(b.objects), len(a.objects) + 1)
                    for ref, obj in a.objects.items():
                        self.assertEqual(obj['name'], b.objects[ref]['name'])
                        self.assertEqual(a.parents[ref], b.parents[ref])
                        if obj['class'] == 'ModuleScript' and obj['name'] != 'Camera':
                            self.assertEqual(a.value(ref, 'Source'), b.value(ref, 'Source'))
                    for chunk in a.chunks:
                        if chunk.tag not in (b'INST', b'PROP', b'PRNT'):
                            self.assertIn(chunk.packet, [x.packet for x in b.chunks])
                else:
                    a, b = ET.fromstring(raw), ET.fromstring(ready)
                    for ref in ('6', '8', '9', '12'):
                        self.assertEqual(ET.tostring(a.find(f".//Item[@referent='{ref}']")), ET.tostring(b.find(f".//Item[@referent='{ref}']")))

    def test_unknown_source_is_blocked_before_any_edit(self):
        raw = fixture().replace(b'camera antiga', b'camera de outra revisao')
        with self.assertRaisesRegex((Failure, ValueError), 'desconhecida|divergiu'):
            patch_place(raw)

    def test_missing_required_or_ambiguous_target_is_blocked(self):
        for raw in (fixture().replace(b'>Camera<', b'>OutraCamera<'), fixture().replace(b'>Camera<', b'>Dados<')):
            with self.assertRaises((Failure, ValueError)): patch_place(raw)

    def test_wrong_class_and_conflicting_addition_are_blocked(self):
        with self.assertRaises((Failure, ValueError)):
            patch_place(fixture().replace(b'class="ModuleScript" referent="3"', b'class="LocalScript" referent="3"'))
        ready, _ = patch_place(fixture())
        with self.assertRaises((Failure, ValueError)):
            patch_place(ready.replace(b'return { rig = "R6" }', b'return "modulo externo"'))


class FakeCloud:
    def __init__(self):
        self.blobs = {8: fixture()}; self.rows = [{'version': 8, 'isPublished': True}]
        self.writes = []; self.requests = []; self.fail_write = False; self.fail_test = False
        self.returned = None; self.fail_download = False
    def validate_destination(self): pass
    def team_empty(self): pass
    def history(self): return max(self.blobs), copy.deepcopy(self.rows)
    def download(self, version, path):
        if self.fail_download: raise Failure('Rede caiu depois do POST')
        raw = self.blobs[version]; Path(path).write_bytes(raw); return raw
    def request(self, path, **kwargs):
        self.requests.append((path, kwargs))
        if kwargs.get('method') != 'POST': raise AssertionError('Só writes via request no fake')
        mode = path.rsplit('=', 1)[-1]
        self.writes.append(mode)
        version = max(self.blobs) + 3  # versão não precisa ser base+1
        self.blobs[version] = kwargs['raw']; self.rows.append({'version': version, 'isPublished': mode == 'Published'})
        if self.fail_write: raise Failure('Conexao interrompida sem resposta')
        return {'versionNumber': self.returned if self.returned is not None else version}
    def task(self, version, source):
        self.assert_prepared = patch_place(self.blobs[version]) == (self.blobs[version], False)
        if not self.assert_prepared: raise Failure('Teste rodou em código antigo')
        if self.fail_test: raise Failure('R6 reprovado no motor')
        return {'package': 'BIZARRE-AJUSTE-14', 'passed': True, 'verified': True}


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        self.rt = Runtime(self.root, 14, 'sources-digest', patch_place, lambda version, verify: ['verificar'])
        self.cloud = FakeCloud()
    def tearDown(self): self.temp.cleanup()
    def test_rigid_destination_is_jojo(self):
        self.assertEqual(TARGET, {'universe': 10774214555, 'place': 108061345551908})
    def test_test_uses_saved_then_cloud_test_and_never_publishes(self):
        proof = self.rt.test(self.cloud)
        self.assertEqual(self.cloud.writes, ['Saved'])
        self.assertTrue(self.cloud.assert_prepared)
        self.assertEqual(proof['base'], 11)
        self.assertFalse(self.rt.pending())
    def test_publish_is_rejected_without_approved_test(self):
        with self.assertRaises(Failure): self.rt.publish(self.cloud)
        self.assertEqual(self.cloud.writes, [])
    def test_rejected_native_test_cannot_publish(self):
        self.cloud.fail_test = True
        with self.assertRaisesRegex(Failure, 'R6 reprovado'): self.rt.test(self.cloud)
        with self.assertRaises(Failure): self.rt.publish(self.cloud)
        self.assertNotIn('Published', self.cloud.writes)
    def test_publish_verifies_actual_returned_version_bytes(self):
        self.rt.test(self.cloud)
        with replace('builtins.input', return_value='PUBLICAR AJUSTE14'):
            receipt = self.rt.publish(self.cloud)
        self.assertEqual(receipt['version'], 14)
        self.assertEqual(self.cloud.writes, ['Saved', 'Published'])
        self.assertIsNone(self.rt.pending())
    def test_uncertain_saved_is_never_reposted_and_resume_is_read_only(self):
        self.cloud.fail_write = True
        with self.assertRaises(Failure): self.rt.test(self.cloud)
        self.assertTrue(self.rt.active.exists())
        with self.assertRaises(Failure): self.rt.test(self.cloud)
        self.cloud.fail_write = False
        self.rt.resume(self.cloud)
        self.assertEqual(self.cloud.writes, ['Saved'])
        self.assertFalse(self.rt.active.exists())
        self.rt.test(self.cloud)
        self.assertEqual(self.cloud.writes, ['Saved'])
    def test_uncertain_publish_resumes_without_second_post(self):
        self.rt.test(self.cloud); self.cloud.fail_write = True
        with replace('builtins.input', return_value='PUBLICAR AJUSTE14'), self.assertRaises(Failure): self.rt.publish(self.cloud)
        self.cloud.fail_write = False
        self.rt.resume(self.cloud)
        self.assertEqual(self.cloud.writes, ['Saved', 'Published'])
    def test_inexact_or_changed_backup_stays_pending(self):
        self.rt.test(self.cloud); self.cloud.fail_download = True
        with replace('builtins.input', return_value='PUBLICAR AJUSTE14'), self.assertRaises(Failure): self.rt.publish(self.cloud)
        self.assertTrue(self.rt.active.exists())
        self.cloud.fail_download = False; self.cloud.blobs[14] += b' changed'
        with self.assertRaises(Failure): self.rt.resume(self.cloud)
        self.assertTrue(self.rt.active.exists())
        self.assertEqual(self.cloud.writes, ['Saved', 'Published'])
    def test_other_save_after_test_blocks_publication(self):
        self.rt.test(self.cloud)
        self.cloud.blobs[12] = fixture(); self.cloud.rows.append({'version': 12, 'isPublished': False})
        with self.assertRaisesRegex(Failure, 'mudou'): self.rt.publish(self.cloud)
        self.assertEqual(self.cloud.writes, ['Saved'])
    def test_foreign_receipt_is_preserved(self):
        save(self.rt.active, {'package': 'OUTRO', 'ready': '/other'})
        with self.assertRaises(Failure): self.rt.test(self.cloud)
        self.assertEqual(read(self.rt.active)['package'], 'OUTRO')
    def test_unknown_source_exports_only_game_files(self):
        self.cloud.blobs[8] = fixture().replace(b'camera antiga', b'camera desconhecida')
        (self.root / 'credencial-nao-exportar.txt').write_text('SEGREDO-TESTE')
        with self.assertRaises((Failure, ValueError)): self.rt.test(self.cloud)
        exports = list(self.root.rglob('*Revisar*.zip')); self.assertEqual(len(exports), 1)
        import zipfile
        with zipfile.ZipFile(exports[0]) as z:
            self.assertEqual(set(z.namelist()), {'Backup_Completo.rbxlx', 'sources.json', 'LEIA.txt'})
            self.assertNotIn(b'SEGREDO-TESTE', b''.join(z.read(n) for n in z.namelist()))
        self.assertEqual(self.cloud.writes, [])


if __name__ == '__main__': unittest.main()
