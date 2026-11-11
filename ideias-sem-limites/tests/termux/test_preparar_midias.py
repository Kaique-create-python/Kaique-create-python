"""Real helper regression boundaries; local files only, no network/key."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('media_helper',ROOT/'tools/preparar_midias.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)

def media_ids(raw):
 source=helper.config_source(raw)
 return {kind:int(helper.pattern(kind).search(source)[2])for kind in helper.MARKERS}

class HelperBoundaries(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.folder=Path(self.tmp.name)/'download';shutil.copytree(ROOT/'dist',self.folder)
  self.state=Path(self.tmp.name)/'state';self.state.mkdir();self.m=helper.Media(self.state,self.folder)
 def record(self,kind,asset='9876543210123'):self.m.record(kind,asset,self.m.digest(kind))
 def rewrite_manifest(self):
  names=['IdeiasSemLimites_V3.rbxl','IdeiasSemLimites_V3.rbxlx']+list(helper.FILES.values())
  (self.folder/'SHA256SUMS').write_text(''.join(helper.sha((self.folder/n).read_bytes())+'  '+n+'\n'for n in names))

 def test_original_audio_receipt_reused_without_new_upload(self):
  (self.state/'audio_id').write_text('9876543210123\n')
  (self.state/'audio_sha').write_text(self.m.digest('audio')+'\n')
  self.assertEqual(self.m.id('audio'),'9876543210123')
  final=self.m.compose();self.assertEqual(media_ids(final.read_bytes())['audio'],9876543210123)
  self.assertFalse((self.state/'midia_audio.json').exists())

 def test_three_receipts_preserve_every_unrelated_instance_and_property(self):
  before=ET.fromstring(self.m.baseline())
  for kind in helper.FILES:self.record(kind)
  out=self.m.compose().read_bytes();after=ET.fromstring(out)
  self.assertEqual(media_ids(out),{'audio':9876543210123,'logo':9876543210123,'icons':9876543210123})
  for a,b in zip(before.iter('Item'),after.iter('Item')):
   self.assertEqual(a.attrib,b.attrib)
   for x,y in zip(a.find('Properties'),b.find('Properties')):
    if x.attrib.get('name')=='Source'and a.findtext("Properties/string[@name='Name']")=='Config':continue
    self.assertEqual(ET.tostring(x),ET.tostring(y))

 def test_changed_asset_never_keeps_old_id(self):
  self.record('icons');file=self.folder/helper.FILES['icons'];file.write_bytes(file.read_bytes()+b'\0')
  self.rewrite_manifest();self.assertEqual(self.m.id('icons'),'')
  self.assertEqual(media_ids(self.m.compose().read_bytes())['icons'],0)

 def test_receipt_for_different_bytes_cannot_be_registered(self):
  with self.assertRaises(ValueError):self.m.record('icons','123456','0'*64)
  self.assertFalse((self.state/'midia_icons.json').exists())

 def test_invalid_ids_cannot_be_recorded(self):
  for invalid in ('0','-1','abc','',True,False,'1\n2','1'*21,9007199254740993):
   with self.subTest(value=invalid):
    with self.assertRaises(ValueError):self.m.record('logo',invalid,self.m.digest('logo'))

 def test_corrupt_receipt_blocks_instead_of_silently_reuploading(self):
  receipt=self.state/'midia_logo.json';receipt.write_text('{"assetId": 0}')
  original=receipt.read_bytes()
  with self.assertRaises(ValueError):self.m.compose()
  self.assertEqual(receipt.read_bytes(),original)

 def test_old_prepared_source_is_backed_up_and_never_used_as_base(self):
  old=(self.folder/'IdeiasSemLimites_V3.rbxlx').read_bytes().replace(b'Config.Version = "3.0.0"',b'Config.Version = "OLD-CODE"')
  path=self.folder/'IdeiasSemLimites_V3_sons.rbxlx';path.write_bytes(old)
  output=self.m.compose().read_bytes();self.assertNotEqual(output,old)
  copies=list((self.folder/'historico-midias').glob('*.rbxlx'))
  self.assertEqual(len(copies),1);self.assertEqual(copies[0].read_bytes(),old)

 def test_same_composition_is_idempotent_without_extra_backups(self):
  first=self.m.compose().read_bytes();second=self.m.compose().read_bytes()
  self.assertEqual(first,second);self.assertFalse((self.folder/'historico-midias').exists())

 def test_broken_download_preserves_last_prepared_file(self):
  path=self.m.compose();before=path.read_bytes()
  file=self.folder/'IdeiasLogo.png';file.write_bytes(b'bad transfer')
  with self.assertRaises(ValueError):self.m.compose()
  self.assertEqual(path.read_bytes(),before)

 def test_legacy_image_ids_migrate_only_for_matching_unmodified_inputs(self):
  path=self.folder/'IdeiasSemLimites_V3_final.rbxlx';raw=self.m.baseline().decode()
  for kind in ('logo','icons'):raw=helper.pattern(kind).sub(lambda m:m[1]+'9876543210123'+m[3],raw)
  path.write_text(raw);newest=max((self.folder/n).stat().st_mtime_ns for n in helper.FILES.values())+1000000
  os.utime(path,ns=(newest,newest));self.m.migrate()
  self.assertEqual(self.m.id('logo'),'9876543210123');self.assertEqual(self.m.id('icons'),'9876543210123')

 def test_legacy_ids_not_associated_with_newer_png(self):
  path=self.folder/'IdeiasSemLimites_V3_final.rbxlx';raw=self.m.baseline().decode()
  raw=helper.pattern('icons').sub(lambda m:m[1]+'9876543210123'+m[3],raw);path.write_text(raw)
  file=self.folder/helper.FILES['icons'];new=path.stat().st_mtime_ns+1000000;os.utime(file,ns=(new,new))
  self.m.migrate();self.assertEqual(self.m.id('icons'),'')

 def test_symlink_destination_never_overwrites_other_file(self):
  other=Path(self.tmp.name)/'other';other.write_bytes(b'keep')
  (self.folder/'IdeiasSemLimites_V3_final.rbxlx').symlink_to(other)
  with self.assertRaises(ValueError):self.m.compose()
  self.assertEqual(other.read_bytes(),b'keep')

if __name__=='__main__':unittest.main(verbosity=2)
