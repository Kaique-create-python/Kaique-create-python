import sys,unittest,tempfile,json
from pathlib import Path
sys.path[:0]=[str(Path(__file__).resolve().parents[1]),str(Path(__file__).resolve().parents[1]/'tools')]
from installer14.package import Package
from installer14.codec import Failure
from installer14.runtime import Runtime
from test_installer14 import patch_place
class Stage15Tests(unittest.TestCase):
 def test_real_package_has_baseline14_new_catalog_and_stage15(self):
  import gerar_ajuste15 as gen
  p=Package(gen.collect());self.assertEqual(p.stage,15);self.assertEqual(p.name,'BIZARRE-AJUSTE-15')
  rows={tuple(x['path']):x for x in p.entries}
  self.assertFalse(rows[('ReplicatedStorage','BB','Config')]['add'])
  b=json.loads((gen.ROOT/'installer14/baseline14.json').read_text())
  self.assertIn(b['sources']['ReplicatedStorage/BB/Config.luau'],rows[('ReplicatedStorage','BB','Config')]['known'])
  self.assertIn('catalogo15.rbxm',p.files);self.assertIn('"stage":15',p.scripts(36)[0])
 def test_stage15_state_and_package_preserve_foreign_pending14(self):
  with tempfile.TemporaryDirectory()as d:
   rt=Runtime(Path(d),15,'digest',patch_place,lambda *a:[])
   self.assertEqual(rt.package,'BIZARRE-AJUSTE-15');self.assertEqual(rt.state.name,'state-ajuste15')
   rt.active.write_text(json.dumps({'package':'BIZARRE-AJUSTE-14','intent':'old'}))
   with self.assertRaises(Failure):rt.pending()
   self.assertEqual(json.loads(rt.active.read_text())['intent'],'old')

class Stage15ProtocolTests(unittest.TestCase):
 def test_saved_test_publish_confirmation_is_stage15(self):
  from unittest.mock import patch
  from test_installer14 import FakeCloud
  with tempfile.TemporaryDirectory()as d:
   rt=Runtime(Path(d),15,'digest',patch_place,lambda *a:['verify'])
   cloud=FakeCloud();cloud.task=lambda *a:{'package':'BIZARRE-AJUSTE-15','passed':True}
   rt.test(cloud)
   with patch('builtins.input',return_value='PUBLICAR AJUSTE14'),self.assertRaises(Failure):rt.publish(cloud)
   self.assertEqual(cloud.writes,['Saved'])
   with patch('builtins.input',return_value='PUBLICAR AJUSTE15'):receipt=rt.publish(cloud)
   self.assertEqual(receipt['status'],'VERIFIED');self.assertEqual(cloud.writes,['Saved','Published'])
