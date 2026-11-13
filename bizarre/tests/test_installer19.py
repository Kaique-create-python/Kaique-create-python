import sys,json,unittest,tempfile
from pathlib import Path
from unittest.mock import patch
sys.path[:0]=[str(Path(__file__).resolve().parents[1]),str(Path(__file__).resolve().parents[1]/'tools')]
from installer14.package import Package
from installer14.runtime import Runtime
from installer14.codec import Failure
from test_installer14 import FakeCloud,patch_place
class Stage19Tests(unittest.TestCase):
 def rt(self,d):
  return Runtime(Path(d),19,'digest',patch_place,lambda *a:['verify'])
 def cloud(self):
  c=FakeCloud();c.task=lambda *a:{'package':'BIZARRE-AJUSTE-19','passed':True};return c
 def test_stage18_requires_own_confirmation_and_keeps_other_pending(self):
  with tempfile.TemporaryDirectory()as d:
   r=self.rt(d)
   self.assertEqual(r.state.name,'state-ajuste19')
   r.active.write_text(json.dumps({'package':'BIZARRE-AJUSTE-18','intent':'keep'}))
   with self.assertRaises(Failure)as e:r.pending()
   self.assertIn('BIZARRE_AJUSTE18.py resume',str(e.exception))
   self.assertEqual(json.loads(r.active.read_text())['intent'],'keep');r.active.unlink()
   c=self.cloud();r.test(c)
   with patch('builtins.input',return_value='PUBLICAR AJUSTE18'),self.assertRaises(Failure):r.publish(c)
   self.assertEqual(c.writes,['Saved'])
   with patch('builtins.input',return_value='PUBLICAR AJUSTE19'):receipt=r.publish(c)
   self.assertEqual(receipt['status'],'VERIFIED');self.assertEqual(c.writes,['Saved','Published'])
 def test_install_runs_saved_test_then_publish_with_one_confirmation(self):
  with tempfile.TemporaryDirectory()as d:
   r=self.rt(d);c=self.cloud()
   with patch('builtins.input',return_value='PUBLICAR AJUSTE19')as asked:receipt=r.install(c)
   self.assertEqual(asked.call_count,1)
   self.assertEqual(receipt['status'],'VERIFIED');self.assertEqual(c.writes,['Saved','Published'])
 def test_install_wrong_confirmation_never_publishes_and_keeps_test(self):
  with tempfile.TemporaryDirectory()as d:
   r=self.rt(d);c=self.cloud()
   with patch('builtins.input',return_value='sim'),self.assertRaises(Failure):r.install(c)
   self.assertEqual(c.writes,['Saved'])
   self.assertTrue((r.state/'test.json').is_file(),'teste aprovado tem que ficar guardado para publicar depois')
   with patch('builtins.input',return_value='PUBLICAR AJUSTE19'):receipt=r.publish(c)
   self.assertEqual(receipt['status'],'VERIFIED');self.assertEqual(c.writes,['Saved','Published'])
 def test_install_failed_cloud_test_blocks_publish(self):
  with tempfile.TemporaryDirectory()as d:
   r=self.rt(d);c=self.cloud();c.task=lambda *a:{'package':'BIZARRE-AJUSTE-19','passed':False,'erros':['AJ19 HUD montado no motor']}
   with patch('builtins.input',side_effect=AssertionError('nao pode perguntar')),self.assertRaises(Failure)as e:r.install(c)
   self.assertIn('Publicacao bloqueada',str(e.exception))
   self.assertEqual(c.writes,['Saved']);self.assertFalse((r.state/'test.json').exists())
 def test_builder_recognizes14_to18_and_adds_only_modules(self):
  import gerar_ajuste19 as gen
  p=Package(gen.collect());self.assertEqual(p.name,'BIZARRE-AJUSTE-19')
  rows={tuple(r['path']):r for r in p.entries};config=rows[('ReplicatedStorage','BB','Config')]
  for v in (14,15,16,17,18):
   b=json.loads((gen.ROOT/f'installer14/baseline{v}.json').read_text())
   self.assertIn(b['sources']['ReplicatedStorage/BB/Config.luau'],config['known'])
  self.assertTrue(rows[('ReplicatedStorage','BB','Cliente','EditorToques17')]['add'])
  script=p.scripts(36)[0]
  self.assertIn('"stage":19',script);self.assertIn('AJ19 HUD montado no motor',script);self.assertLess(len(script.encode()),200000)
 def test_new_stage_resume_after_saved_response_loss_never_reposts(self):
  with tempfile.TemporaryDirectory()as d:
   r=self.rt(d);c=self.cloud();c.fail_write=True
   with self.assertRaises(Failure):r.test(c)
   c.fail_write=False;r.resume(c);r.test(c)
   self.assertEqual(c.writes,['Saved']);self.assertIsNone(r.pending())
