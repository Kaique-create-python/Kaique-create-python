"""Execute the distributed updater only against disposable phone-package copies."""
import ast
import base64
import os
import zlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
# Built artifact kept one level above the reviewed package, outside its payload.
BUNDLE=ROOT.parent/'dist/CORRIGIR_ETAPA3_10_CODEX.py'
GRAPHICS=ROOT.parent/'dist/BASTIAO_GRAFICOS.py'


def payload(path):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    rows = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign)
                and any(isinstance(target, ast.Name) and target.id == 'ARQUIVOS' for target in node.targets))
    return {name: zlib.decompress(base64.b85decode(item['dados'])) for name, item in rows.items()}


def before_graphics(phone):
    # Restore the actual versions delivered by C10 in files the new addon changes.
    old = payload(BUNDLE)
    for name in payload(GRAPHICS):
        if name in old:
            (phone / name).write_bytes(old[name])
        else:
            (phone / name).unlink(missing_ok=True)

class StandaloneBundleTests(unittest.TestCase):
    def test_distributed_update_preserves_foreign_files_and_repeats_without_writes(self):
        self.assertTrue(BUNDLE.is_file(),'Build the actual standalone delivery first')
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary);phone=home/'pacote'
            shutil.copytree(ROOT,phone,ignore=shutil.ignore_patterns('__pycache__','.correcao10','payload'))
            before_graphics(phone)
            # A real C9 source revision is restored to demonstrate an actual upgrade.
            incoming=ROOT.parent/'dist/CORRIGIR_ETAPA3_9.py'
            old=payload(incoming)['src/client/Efeitos.luau']
            self.assertNotEqual(old,(ROOT/'src/client/Efeitos.luau').read_bytes())
            (phone/'src/client/Efeitos.luau').write_bytes(old)
            marker=phone/'audio/.asset_upload_state/protected.txt';marker.parent.mkdir(parents=True,exist_ok=True)
            marker.write_text('Keep upload receipt')
            environment={**os.environ,"HOME":str(home/"isolated_home")}
            command=[sys.executable,str(BUNDLE),str(phone)]
            one=subprocess.run(command,capture_output=True,text=True,env=environment)
            self.assertEqual(one.returncode,0,one.stdout+one.stderr)
            backups=list((phone/'.correcao10').glob('aplicacao_*'))
            two=subprocess.run(command,capture_output=True,text=True,env=environment)
            self.assertEqual(two.returncode,0,two.stdout+two.stderr)
            self.assertIn('ja estava corrigido',two.stdout)
            self.assertEqual(backups,list((phone/'.correcao10').glob('aplicacao_*')))
            self.assertEqual(marker.read_text(),'Keep upload receipt')
            self.assertEqual((phone/'src/client/Efeitos.luau').read_bytes(),(ROOT/'src/client/Efeitos.luau').read_bytes())

    def test_foreign_source_refusal_never_partially_applies_update(self):
        self.assertTrue(BUNDLE.is_file(),'Build the actual standalone delivery first')
        with tempfile.TemporaryDirectory() as temporary:
            phone=Path(temporary)/'pacote';shutil.copytree(ROOT,phone,ignore=shutil.ignore_patterns('__pycache__','.correcao10','payload'))
            before_graphics(phone)
            target=phone/'src/server/Criatura.luau';target.write_text('-- User modification to preserve\nreturn {}\n')
            expected=(phone/'src/client/Som.luau').read_bytes()
            result=subprocess.run([sys.executable,str(BUNDLE),str(phone)],capture_output=True,text=True,env={**os.environ,"HOME":str(Path(temporary)/"isolated_home")})
            self.assertNotEqual(result.returncode,0)
            self.assertIn('RECUSADO',result.stdout)
            self.assertEqual(target.read_text(),'-- User modification to preserve\nreturn {}\n')
            self.assertEqual((phone/'src/client/Som.luau').read_bytes(),expected)
            self.assertFalse((phone/'.correcao10').exists())

    def test_graphics_installer_updates_only_three_files_in_existing_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            phone = home / '.bastiao_etapa3' / 'pacote_fixture'
            shutil.copytree(ROOT, phone, ignore=shutil.ignore_patterns('__pycache__', 'payload'))
            before_graphics(phone)
            before = {p.relative_to(phone).as_posix(): p.read_bytes() for p in phone.rglob('*') if p.is_file()}
            command = [sys.executable, str(GRAPHICS)]
            environment = {**os.environ, 'HOME': str(home)}

            verify = subprocess.run([*command, '--verificar'], capture_output=True, text=True, env=environment)
            self.assertEqual(verify.returncode, 0, verify.stdout + verify.stderr)
            self.assertFalse((phone / '.graficos_bastiao').exists())
            self.assertFalse((phone.parent / 'execucao.lock').exists())

            result = subprocess.run(command, capture_output=True, text=True, env=environment)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            after = {p.relative_to(phone).as_posix(): p.read_bytes() for p in phone.rglob('*')
                     if p.is_file() and '.graficos_bastiao' not in p.parts}
            changed = {name for name in before.keys() | after.keys() if before.get(name) != after.get(name)}
            self.assertEqual(changed, {'src/client/BastiaoIluminacao.client.luau', 'tooling/release_builder.py', 'src/teste_nuvem.luau'})
            for name in changed:
                self.assertEqual(after[name], (ROOT / name).read_bytes())
            reports = list((phone / '.graficos_bastiao').glob('aplicacao_*'))
            self.assertEqual(len(reports), 1)
            self.assertEqual((reports[0] / 'originais/tooling/release_builder.py').read_bytes(), before['tooling/release_builder.py'])
            repeat = subprocess.run(command, capture_output=True, text=True, env=environment)
            self.assertEqual(repeat.returncode, 0, repeat.stdout + repeat.stderr)
            self.assertEqual(list((phone / '.graficos_bastiao').glob('aplicacao_*')), reports)

if __name__=='__main__':unittest.main()
