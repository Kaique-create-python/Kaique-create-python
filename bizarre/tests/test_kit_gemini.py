"""Portable handoff: exact source/installer transfer, isolation and reconstruction."""
import importlib.util,json,subprocess,sys,tempfile,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'tools/criar_kit_gemini.py'

class GeminiKitTests(unittest.TestCase):
 def load(self):
  self.assertTrue(SCRIPT.is_file(),'exportador Gemini ainda nao existe')
  spec=importlib.util.spec_from_file_location('kit_gemini',SCRIPT)
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
 def archive(self,path,bad=False):
  with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED)as z:
   for folder in('src','installer14','tools','tests','docs'):
    for p in (ROOT/folder).rglob('*'):
     if p.is_file()and'__pycache__'not in p.parts and p.suffix in('.luau','.py','.md','.txt','.json','.html','.js'):
      z.write(p,'snapshot/bizarre/'+str(p.relative_to(ROOT)))
   z.write(ROOT/'dist/BIZARRE_AJUSTE19.py','snapshot/bizarre/dist/BIZARRE_AJUSTE19.py')
   z.writestr('snapshot/outro-projeto/privado.txt','OTHER PROJECT MUST NOT BE EXPORTED')
   z.writestr('snapshot/bizarre/.env','SYNTHETIC EXCLUDED DATA')
   z.writestr('snapshot/bizarre/state-ajuste19/active-write.json','{}')
   if bad:z.writestr('snapshot/bizarre/src/../../escape.py','raise Exception()')
 def test_exports_at_most_ten_files_without_audio_and_is_exactly_reconstructible(self):
  kit=self.load()
  with tempfile.TemporaryDirectory()as d:
   base=Path(d);archive=base/'repo.zip';self.archive(archive)
   result=kit.exportar(archive,base/'out')
   with zipfile.ZipFile(result['zip'])as z:
    self.assertEqual(len(z.namelist()),9)
    self.assertTrue(all(Path(n).suffix in('.txt','.json','.py')for n in z.namelist()))
    project=json.loads(z.read('06_PROJETO_FONTE.json'))
    self.assertFalse(any('.env'in n or 'state-ajuste'in n or 'outro-projeto'in n for n in project['files']))
    self.assertEqual(sum(n.startswith('src/')and n.endswith('.luau')for n in project['files']),68)
    self.assertEqual(z.read('07_BIZARRE_AJUSTE19.py'),(ROOT/'dist/BIZARRE_AJUSTE19.py').read_bytes())
    self.assertIn('ccae563',z.read('00_CONTEXTO_GEMINI.txt').decode())
    z.extractall(base/'unpacked')
   rebuilt=base/'rebuilt'
   r=subprocess.run([sys.executable,str(base/'unpacked/08_RECONSTRUIR_PROJETO.py'),'--saida',str(rebuilt)],capture_output=True,text=True)
   self.assertEqual(r.returncode,0,r.stdout+r.stderr)
   build=base/'rebuilt-installer.py'
   r=subprocess.run([sys.executable,str(rebuilt/'bizarre/tools/gerar_ajuste19.py'),'--output',str(build)],capture_output=True,text=True)
   self.assertEqual(r.returncode,0,r.stdout+r.stderr)
   self.assertEqual(build.read_bytes(),(ROOT/'dist/BIZARRE_AJUSTE19.py').read_bytes())
 def test_rejects_path_traversal_without_writing_project_data(self):
  kit=self.load()
  with tempfile.TemporaryDirectory()as d:
   p=Path(d);a=p/'bad.zip';self.archive(a,True)
   with self.assertRaises(ValueError):kit.exportar(a,p/'out')
   self.assertFalse((p/'escape.py').exists())
 def test_doc_and_embedded_prompt_match(self):
  kit=self.load();self.assertEqual(kit.CONTEXTO,(ROOT/'CONTEXTO_GEMINI.txt').read_text())
