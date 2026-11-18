"""Installer tests never touch the user's package cache or network."""
import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zlib

MODULE = Path(__file__).parents[1] / 'tooling' / 'patch_install.py'

def row(new=b'new', old=b'old', mode='trocar', **extra):
    return {'modo': mode, 'antes': [hashlib.sha256(old).hexdigest()],
            'novo': hashlib.sha256(new).hexdigest(),
            'dados': base64.b85encode(zlib.compress(new)).decode(), **extra}


class PatchInstallTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE.is_file(), 'safe patch installer has not been implemented')
        spec = importlib.util.spec_from_file_location('patch_install', MODULE)
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'package'
        self.root.mkdir()

    def put(self, name, data=b'old'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_known_old_versions_backup_permissions_and_repeat(self):
        path = self.put('src/file.py')
        path.chmod(0o751)
        rows = {'src/file.py': row()}
        report = self.mod.apply(self.root, rows)
        self.assertEqual(path.read_bytes(), b'new')
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o751)
        self.assertEqual(Path(report['backups']['src/file.py']).read_bytes(), b'old')
        saved = json.loads(Path(report['report_path']).read_text())
        self.assertEqual(saved['changed'], ['src/file.py'])
        self.assertEqual(saved['files'][0]['before_sha256'], hashlib.sha256(b'old').hexdigest())
        before = sorted(p.relative_to(self.root) for p in self.root.rglob('*'))
        repeat = self.mod.apply(self.root, rows)
        self.assertEqual(repeat['changed'], [])
        self.assertEqual(before, sorted(p.relative_to(self.root) for p in self.root.rglob('*')))

    def test_unknown_create_file_is_preserved_and_package_is_not_partly_written(self):
        self.put('safe.py')
        foreign = self.put('foreign.py', b'Claude changes')
        with self.assertRaisesRegex(self.mod.PatchError, 'foreign.py'):
            self.mod.apply(self.root, {'safe.py': row(), 'foreign.py': row(mode='criar')})
        self.assertEqual((self.root / 'safe.py').read_bytes(), b'old')
        self.assertEqual(foreign.read_bytes(), b'Claude changes')
        self.assertFalse((self.root / '.correcao10').exists())

    def test_all_payloads_checked_even_if_file_already_updated(self):
        self.put('safe.py')
        self.put('already.py', b'new')
        broken = row()
        broken['dados'] = 'not valid compressed data'
        with self.assertRaisesRegex(self.mod.PatchError, 'already.py'):
            self.mod.apply(self.root, {'safe.py': row(), 'already.py': broken})
        self.assertEqual((self.root / 'safe.py').read_bytes(), b'old')

    def test_wrong_payload_hash_aborts_before_write(self):
        self.put('safe.py')
        broken = row(b'bad')
        broken['novo'] = hashlib.sha256(b'other').hexdigest()
        with self.assertRaises(self.mod.PatchError):
            self.mod.apply(self.root, {'safe.py': row(), 'new.py': broken})
        self.assertEqual((self.root / 'safe.py').read_bytes(), b'old')

    def test_plan_merge_preserves_foreign_voice_config_and_owned_extra_fields(self):
        old = {'schemaVersion': 1, 'voiceConfig': {'voiceId': 'claude'}, 'clips': [
            {'key': 'voice_pavel', 'voiceId': 'custom', 'sourcePath': 'claude.mp3'},
            {'key': 'impacto_porta', 'sha256': 'old', 'customSetting': True}]}
        desired = {'schemaVersion': 1, 'voiceConfig': {'voiceId': 'wrong'}, 'clips': [
            {'key': 'voice_pavel', 'voiceId': 'wrong'},
            {'key': 'impacto_porta', 'sha256': 'new', 'sourcePath': 'new.mp3'}]}
        self.put('audio/AUDIO_PLAN.json', json.dumps(old).encode())
        rows = {'audio/AUDIO_PLAN.json': row(json.dumps(desired).encode(), mode='plano')}
        self.mod.apply(self.root, rows)
        result = json.loads((self.root / 'audio/AUDIO_PLAN.json').read_bytes())
        self.assertEqual(result['voiceConfig'], old['voiceConfig'])
        self.assertEqual(result['clips'][0], old['clips'][0])
        self.assertTrue(result['clips'][1]['customSetting'])
        self.assertEqual(result['clips'][1]['sha256'], 'new')
        self.assertEqual(self.mod.apply(self.root, rows)['changed'], [])

    def test_clipes_allowlist_supports_new_effect_without_importing_foreign_voices(self):
        old = {'schemaVersion': 1, 'clips': [{'key': 'pavel', 'voiceId': 'claude'}]}
        desired = {'schemaVersion': 1, 'clips': [
            {'key': 'pavel', 'voiceId': 'erase'}, {'key': 'impacto_zumbido', 'sourcePath': 'new.mp3'}]}
        self.put('audio/AUDIO_PLAN.json', json.dumps(old).encode())
        rows = {'audio/AUDIO_PLAN.json': row(json.dumps(desired).encode(), mode='plano',
                                             clipes=['impacto_zumbido'])}
        self.mod.apply(self.root, rows)
        result = json.loads((self.root / 'audio/AUDIO_PLAN.json').read_bytes())
        self.assertEqual(result['clips'], [old['clips'][0], desired['clips'][1]])

    def test_supports_original_and_current_c9_hashes(self):
        path = self.put('file', b'C9')
        update = row(b'C10', old=b'original')
        update['antes'].append(hashlib.sha256(b'C9').hexdigest())
        self.mod.apply(self.root, {'file': update})
        self.assertEqual(path.read_bytes(), b'C10')

    def test_report_failure_also_rolls_back_targets_and_backups(self):
        path = self.put('file')
        real_write = self.mod._atomic_write
        def fail_report(target, raw, mode):
            if target.name == 'relatorio.json':
                raise OSError('report disk failure')
            return real_write(target, raw, mode)
        with patch.object(self.mod, '_atomic_write', side_effect=fail_report):
            with self.assertRaisesRegex(self.mod.PatchError, 'rollback concluido'):
                self.mod.apply(self.root, {'file': row()})
        self.assertEqual(path.read_bytes(), b'old')
        self.assertEqual([p.name for p in self.root.iterdir()], ['file'])

    def test_backup_failure_precedes_any_target_write(self):
        path = self.put('file')
        real_write = self.mod._atomic_write
        def fail_backup(target, raw, mode):
            if 'originais' in target.parts:
                raise OSError('backup disk failure')
            return real_write(target, raw, mode)
        with patch.object(self.mod, '_atomic_write', side_effect=fail_backup):
            with self.assertRaisesRegex(self.mod.PatchError, 'rollback concluido'):
                self.mod.apply(self.root, {'file': row()})
        self.assertEqual(path.read_bytes(), b'old')
        self.assertEqual([p.name for p in self.root.iterdir()], ['file'])

    def test_unknown_optional_test_preserved(self):
        path = self.put('tests/custom.py', b'foreign test')
        report = self.mod.apply(self.root, {'tests/custom.py': row(mode='criar_teste')})
        self.assertEqual(report['skipped'], ['tests/custom.py'])
        self.assertEqual(path.read_bytes(), b'foreign test')

    def test_preexisting_transaction_is_never_overwritten_or_deleted(self):
        self.put('file')
        existing = self.put('.correcao10/aplicacao_collision/originais/keep', b'previous backup')
        class FixedUUID:
            hex = 'collision'
        with patch.object(self.mod.uuid, 'uuid4', return_value=FixedUUID()):
            with self.assertRaises(self.mod.PatchError):
                self.mod.apply(self.root, {'file': row()})
        self.assertEqual(existing.read_bytes(), b'previous backup')
        self.assertEqual((self.root / 'file').read_bytes(), b'old')

    def test_default_candidate_location_uses_phone_cache(self):
        home = Path(self.temp.name) / 'mock_home'
        valid = home / '.bastiao_etapa3/pacote_123'
        valid.mkdir(parents=True)
        (valid / 'instalar.py').write_text('# marker')
        empty = home / '.bastiao_etapa3/pacote_empty'
        empty.mkdir()
        self.assertEqual(self.mod.candidatas(home), [valid])
        self.assertEqual(self.mod.candidatas(home / 'absent'), [])

    def test_reject_path_traversal_absolute_and_metadata_targets(self):
        for name in ['../escape', '/tmp/escape', 'a/../escape', 'a\\escape', '.correcao10/evil', 'a//b']:
            with self.subTest(name=name), self.assertRaises(self.mod.PatchError):
                self.mod.apply(self.root, {name: row(mode='criar')})
        self.assertEqual(list(self.root.iterdir()), [])

    def test_reject_leaf_ancestor_and_root_symlinks(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        (outside / 'file').write_bytes(b'old')
        (self.root / 'link').symlink_to(outside, target_is_directory=True)
        (self.root / 'leaf').symlink_to(outside / 'file')
        for name in ['link/file', 'leaf']:
            with self.subTest(name=name), self.assertRaises(self.mod.PatchError):
                self.mod.apply(self.root, {name: row()})
        alias = Path(self.temp.name) / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(self.mod.PatchError):
            self.mod.apply(alias, {})
        self.assertEqual((outside / 'file').read_bytes(), b'old')

    def test_verify_writes_nothing_and_skips_missing_optional_test(self):
        self.put('file')
        before = {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        report = self.mod.apply(self.root, {'file': row(), 'tests/optional': row(mode='teste')}, verify=True)
        self.assertEqual(report['status'], 'verified')
        self.assertEqual(report['skipped'], ['tests/optional'])
        self.assertEqual(before, {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()})
        self.assertFalse((self.root / '.correcao10').exists())

    def test_keyboard_interrupt_during_commit_rolls_back(self):
        self.put('first')
        self.put('second')
        real_replace = self.mod.os.replace
        interrupted = False
        def interrupt_once(source, destination):
            nonlocal interrupted
            if Path(destination) == self.root / 'second' and not interrupted:
                interrupted = True
                raise KeyboardInterrupt()
            return real_replace(source, destination)
        with patch.object(self.mod.os, 'replace', side_effect=interrupt_once):
            with self.assertRaisesRegex(self.mod.PatchError, 'rollback concluido'):
                self.mod.apply(self.root, {'first': row(), 'second': row()})
        self.assertEqual((self.root / 'first').read_bytes(), b'old')
        self.assertEqual((self.root / 'second').read_bytes(), b'old')
        self.assertFalse((self.root / '.correcao10').exists())

    def test_failed_rollback_retains_original_backup_with_diagnostic(self):
        self.put('first')
        self.put('second')
        real_replace = self.mod.os.replace
        failed_commit = False
        def fail_commit_and_restore(source, destination):
            nonlocal failed_commit
            destination = Path(destination)
            if destination == self.root / 'second':
                failed_commit = True
                raise OSError('disk refuses second')
            if destination == self.root / 'first' and failed_commit:
                raise OSError('disk refuses restoration')
            return real_replace(source, destination)
        with patch.object(self.mod.os, 'replace', side_effect=fail_commit_and_restore):
            with self.assertRaisesRegex(self.mod.PatchError, 'rollback incompleto.*Backups preservados'):
                self.mod.apply(self.root, {'first': row(), 'second': row()})
        backups = list((self.root / '.correcao10').glob('aplicacao_*/originais/first'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), b'old')

    def test_late_failure_rolls_back_existing_new_files_backups_and_directories(self):
        original = self.put('file')
        original.chmod(0o740)
        rows = {'file': row(), 'added/deep/new': row(mode='criar')}
        real_replace = self.mod.os.replace
        failed = False
        def fail_after_first(source, destination):
            nonlocal failed
            if Path(destination) == self.root / 'added/deep/new' and not failed:
                failed = True
                raise OSError('simulated disk failure')
            return real_replace(source, destination)
        with patch.object(self.mod.os, 'replace', side_effect=fail_after_first):
            with self.assertRaisesRegex(self.mod.PatchError, 'rollback'):
                self.mod.apply(self.root, rows)
        self.assertEqual(original.read_bytes(), b'old')
        self.assertEqual(stat.S_IMODE(original.stat().st_mode), 0o740)
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), ['file'])


    def test_one_success_cannot_hide_a_refused_package_from_shell_chain(self):
        import contextlib,io
        self.put('module.py')
        other=Path(self.temp.name)/'foreign';other.mkdir();(other/'module.py').write_bytes(b'User changes')
        with contextlib.redirect_stdout(io.StringIO()):
            result=self.mod.main({'module.py':row()},[str(self.root),str(other)])
        self.assertNotEqual(result,0,'Do not run publication when any discovered package was refused')
        self.assertEqual((other/'module.py').read_bytes(),b'User changes')


if __name__ == '__main__':
    unittest.main()
