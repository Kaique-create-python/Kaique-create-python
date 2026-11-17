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

class StandaloneBundleTests(unittest.TestCase):
    def test_distributed_update_preserves_foreign_files_and_repeats_without_writes(self):
        self.assertTrue(BUNDLE.is_file(),'Build the actual standalone delivery first')
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary);phone=home/'pacote'
            shutil.copytree(ROOT,phone,ignore=shutil.ignore_patterns('__pycache__','.correcao10','payload'))
            # A real C9 source revision is restored to demonstrate an actual upgrade.
            incoming=ROOT.parent/'dist/CORRIGIR_ETAPA3_9.py'
            tree=ast.parse(incoming.read_text())
            rows=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign)
                      and any(isinstance(x,ast.Name) and x.id=='ARQUIVOS' for x in n.targets))
            old=zlib.decompress(base64.b85decode(rows['src/client/Efeitos.luau']['dados']))
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
            target=phone/'src/server/Criatura.luau';target.write_text('-- User modification to preserve\nreturn {}\n')
            expected=(phone/'src/client/Som.luau').read_bytes()
            result=subprocess.run([sys.executable,str(BUNDLE),str(phone)],capture_output=True,text=True,env={**os.environ,"HOME":str(Path(temporary)/"isolated_home")})
            self.assertNotEqual(result.returncode,0)
            self.assertIn('RECUSADO',result.stdout)
            self.assertEqual(target.read_text(),'-- User modification to preserve\nreturn {}\n')
            self.assertEqual((phone/'src/client/Som.luau').read_bytes(),expected)
            self.assertFalse((phone/'.correcao10').exists())

if __name__=='__main__':unittest.main()
