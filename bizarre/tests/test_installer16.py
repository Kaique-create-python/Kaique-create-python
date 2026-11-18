import sys,json,unittest,tempfile
from pathlib import Path
from unittest.mock import patch
sys.path[:0]=[str(Path(__file__).resolve().parents[1]),str(Path(__file__).resolve().parents[1]/'tools')]
from installer14.package import Package
from installer14.runtime import Runtime
from installer14.codec import Failure
from test_installer14 import FakeCloud,patch_place
class Stage16Tests(unittest.TestCase):
 def test_stage16_keeps_pending15_and_requires_own_confirmation(self):
  with tempfile.TemporaryDirectory()as d:
   r=Runtime(Path(d),16,'digest',patch_place,lambda *a:['verify'])
   self.assertEqual(r.state.name,'state-ajuste16')
   r.active.write_text(json.dumps({'package':'BIZARRE-AJUSTE-15','intent':'keep'}))
   with self.assertRaises(Failure):r.pending()
   self.assertEqual(json.loads(r.active.read_text())['intent'],'keep');r.active.unlink()
   c=FakeCloud();c.task=lambda *a:{'package':'BIZARRE-AJUSTE-16','passed':True}
   r.test(c)
   with patch('builtins.input',return_value='PUBLICAR AJUSTE15'),self.assertRaises(Failure):r.publish(c)
   self.assertEqual(c.writes,['Saved'])
   with patch('builtins.input',return_value='PUBLICAR AJUSTE16'):receipt=r.publish(c)
   self.assertEqual(receipt['status'],'VERIFIED');self.assertEqual(c.writes,['Saved','Published'])
 def test_builder_recognizes14_and15_and_adds_only_modules(self):
  import gerar_ajuste16 as gen
  p=Package(gen.collect());self.assertEqual(p.name,'BIZARRE-AJUSTE-16')
  rows={tuple(r['path']):r for r in p.entries};config=rows[('ReplicatedStorage','BB','Config')]
  for v in (14,15):
   b=json.loads((gen.ROOT/f'installer14/baseline{v}.json').read_text())
   self.assertIn(b['sources']['ReplicatedStorage/BB/Config.luau'],config['known'])
  self.assertTrue(rows[('ReplicatedStorage','BB','Cliente','Barragem16')]['add'])
  self.assertTrue(rows[('ReplicatedStorage','BB','Cliente','RastroStand15')]['add'])
  self.assertIn('"stage":16',p.scripts(36)[0]);self.assertLess(len(p.scripts(36)[0].encode()),200000)
 def test_new_stage_resume_after_saved_response_loss_never_reposts(self):
  with tempfile.TemporaryDirectory()as d:
   r=Runtime(Path(d),16,'digest',patch_place,lambda *a:['verify'])
   c=FakeCloud();c.task=lambda *a:{'package':'BIZARRE-AJUSTE-16','passed':True};c.fail_write=True
   with self.assertRaises(Failure):r.test(c)
   c.fail_write=False;r.resume(c);r.test(c)
   self.assertEqual(c.writes,['Saved']);self.assertIsNone(r.pending())
