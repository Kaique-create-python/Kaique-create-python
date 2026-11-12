"""Exercise the real generator/bootstrap in a disposable, offline fixture project."""
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from installer14.package import Package


class StandaloneTests(unittest.TestCase):
    def test_build_is_deterministic_and_one_file_runs_offline_in_empty_folder(self):
        spec=importlib.util.spec_from_file_location('generator14_fixture',ROOT/'tools/gerar_ajuste14.py')
        generator=importlib.util.module_from_spec(spec);spec.loader.exec_module(generator)
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)/'project';root.mkdir()
            shutil.copytree(ROOT/'installer14',root/'installer14',ignore=shutil.ignore_patterns('__pycache__'))
            (root/'src/ReplicatedStorage/BB').mkdir(parents=True)
            source=b'return { fixture = true }\n';relative='ReplicatedStorage/BB/Offline.luau'
            (root/'src'/relative).write_bytes(source)
            (root/'installer14/baseline13.json').write_text(json.dumps({'sources':{relative:hashlib.sha256(source).hexdigest()}}))
            (root/'assets/vfx14').mkdir(parents=True)
            for suffix in ('rbxm','rbxmx'):shutil.copyfile(ROOT/f'assets/vfx14/catalogo.{suffix}',root/f'assets/vfx14/catalogo.{suffix}')
            (root/'tools').mkdir()
            # Local fixture only. Offline validation composes but never executes this source.
            (root/'tools/teste_nuvem14.luau').write_text('return { package=cfg.package, passed=true }')
            with patch.object(generator,'ROOT',root):
                files=generator.collect()
                self.assertEqual(Package(files).scripts(7)[0].count('"version":7'),1)
                first=generator.build(root/'first.py');second=generator.build(root/'second.py')
            self.assertEqual(first.read_bytes(),second.read_bytes())
            empty=Path(name)/'empty';empty.mkdir();home=Path(name)/'isolated-home';home.mkdir()
            executable=empty/'BIZARRE_AJUSTE14.py';shutil.copyfile(first,executable)
            env=dict(os.environ,HOME=str(home),PYTHONPATH='')
            for command in ('testaroffline','testar'):
                result=subprocess.run([sys.executable,'-I',str(executable),command],cwd=empty,env=env,capture_output=True,text=True,timeout=30)
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertIn('Integridade offline OK',result.stdout)
            self.assertEqual(list(home.iterdir()),[])
            self.assertEqual([p.name for p in empty.iterdir()],['BIZARRE_AJUSTE14.py'])
            data=executable.read_text();executable.write_text(data.replace('SHA256 = ',"SHA256 = 'bad' #",1))
            result=subprocess.run([sys.executable,'-I',str(executable),'testaroffline'],cwd=empty,env=env,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('Pacote corrompido',result.stderr)

if __name__=='__main__':unittest.main()
