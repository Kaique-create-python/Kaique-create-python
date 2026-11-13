"""Run the actual validator/config/hash manifest from the standalone installer in Lune."""
import ast,base64,io,json,re,shutil,subprocess,sys,tempfile,unittest,zipfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from installer14.package import Package
from installer14.codec import Failure

def read_bundle(path):
 tree=ast.parse(Path(path).read_bytes())
 payload=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='PAYLOAD'for t in n.targets))
 with zipfile.ZipFile(io.BytesIO(zlib.decompress(base64.b85decode(payload))))as z:
  return {n.removeprefix('payload/'):z.read(n)for n in z.namelist()if n.startswith('payload/')}

class NativeContract19Tests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  lune=shutil.which('lune')
  if not lune:
   candidate=Path('/workspace/ideias-tools/lune')
   lune=str(candidate)if candidate.is_file()else None
  if not lune:raise unittest.SkipTest('Lune is required for the embedded native validator suite')
  files=read_bundle(ROOT/'dist/BIZARRE_AJUSTE19.py')
  package=Package(files)
  line=package.scripts(41)[0].splitlines()[0]
  match=re.search(r'JSONDecode\(\[(=*)\[(.*)\]\1\]\)',line)
  if not match:raise AssertionError('native task config could not be decoded')
  fixture={'cfg':json.loads(match[2]),'entries':package.entries}
  with tempfile.TemporaryDirectory()as name:
   p=Path(name)/'contract.json';p.write_text(json.dumps(fixture,ensure_ascii=False))
   result=subprocess.run([lune,'run','bizarre/tools/validar_pacote_nativo.luau',str(p)],cwd=ROOT.parent,text=True,capture_output=True,timeout=60)
   if result.returncode:raise AssertionError(result.stdout+result.stderr)
   cls.reports=json.loads(result.stdout)
 def test_standalone19_approves_its_actual_config_and_all_sources(self):
  r=self.reports['actual'];self.assertTrue(r['passed'],r['erros']);self.assertEqual(r['info']['fonts'],68)
 def test_stage18_is_supported_by_the_native_validator(self):
  r=self.reports['stage18'];self.assertTrue(r['passed'],r['erros'])
 def test_wrong_universe_place_package_and_future_revision_remain_blocked(self):
  for name in('wrongUniverse','wrongPlace','wrongPackage','future'):
   with self.subTest(name=name):self.assertFalse(self.reports[name]['passed'])
 def test_builder_can_patch_original19_without_forcing_unknown_sources(self):
  sys.path.insert(0,str(ROOT/'tools'))
  import gerar_ajuste19 as gen
  p=Package(gen.collect())
  baseline=ROOT/'installer14/baseline19.json'
  self.assertTrue(baseline.is_file(),'baseline original19 ausente')
  original=json.loads(baseline.read_text())
  by_path={'/'.join(r['path']):r for r in p.entries}
  for name,digest in original['sources'].items():
   key=name.removesuffix('.luau').replace('.client','').replace('.server','')
   if key.startswith('StarterPlayerScripts/')or key.startswith('StarterCharacterScripts/'):key='StarterPlayer/'+key
   with self.subTest(source=name):self.assertIn(digest,by_path[key]['known'])
