import sys, unittest, struct, xml.etree.ElementTree as ET
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from installer14.codec import Binary,Chunk,Compression,pack32,pstring,prefs,puints,refs,Failure
from installer14.catalog import patch_catalog
from test_installer14 import fixture
ROOT=Path(__file__).resolve().parents[1]

class CatalogTests(unittest.TestCase):
 def test_real_catalog_in_both_formats_preserves_objects_and_idempotency(self):
  for binary in (True,False):
   with self.subTest(binary=binary):
    raw=fixture(binary);cat=(ROOT/'assets/vfx14'/('catalogo.rbxm' if binary else 'catalogo.rbxmx')).read_bytes()
    result,changed=patch_catalog(raw,cat)
    self.assertTrue(changed);self.assertEqual(patch_catalog(result,cat),(result,False))
    if binary:
     before,after,catalog=Binary(raw),Binary(result),Binary(cat)
     self.assertEqual(len(after.objects),len(before.objects)+len(catalog.objects))
     for r,o in before.objects.items():self.assertEqual(o,after.objects[r]);self.assertEqual(before.parents[r],after.parents[r])
     for c in before.chunks:
      if c.tag not in (b'PRNT',):self.assertIn(c.packet,[v.packet for v in after.chunks])
     for (g,name),(c,t,q) in after.props.items():
      if t==19:
       for r in refs(c.data[q:],len(after.groups[g]['refs'])):self.assertIn(r,after.objects)
    else:
     a,b=ET.fromstring(raw),ET.fromstring(result)
     self.assertEqual(ET.tostring(a.find("Item[@class='Workspace']")),ET.tostring(b.find("Item[@class='Workspace']")))
 def test_conflicting_catalog_is_not_overwritten(self):
  cat=(ROOT/'assets/vfx14/catalogo.rbxmx').read_bytes()
  result,_=patch_catalog(fixture(),cat)
  tampered=result.replace(b'ParticleEmitter',b'Script',1)
  with self.assertRaises((Failure,ValueError)):patch_catalog(tampered,cat)
 def test_shared_strings_and_internal_object_refs_are_remapped(self):
  def cat():
   chunks=[Chunk(b'INST',pack32(0)+pstring(b'Folder')+b'\0'+pack32(1)+prefs([0])),Chunk(b'INST',pack32(1)+pstring(b'Attachment')+b'\0'+pack32(1)+prefs([1]))]
   for g,name in [(0,b'BB_VFXCatalogo14'),(1,b'A')]:chunks.append(Chunk(b'PROP',pack32(g)+pstring(b'Name')+b'\1'+pstring(name)))
   chunks.extend([Chunk(b'SSTR',pack32(0)+pack32(1)+bytes(16)+pstring(b'catalog-shared')),Chunk(b'PROP',pack32(1)+pstring(b'CustomShared')+bytes([28])+puints([0])),Chunk(b'PROP',pack32(1)+pstring(b'ObjectRef')+bytes([19])+prefs([0])),Chunk(b'PRNT',b'\0'+pack32(2)+prefs([0,1])+prefs([-1,0])),Chunk(b'END\0',b'</roblox>')])
   return b'<roblox!\x89\xff\r\n\x1a\n\0\0'+pack32(2)+pack32(2)+bytes(8)+b''.join(c.encoded(Compression()) for c in chunks)
  raw=fixture(True);c=cat();out,_=patch_catalog(raw,c)
  b=Binary(out);self.assertEqual(len(b.shared),1);self.assertEqual(patch_catalog(out,c),(out,False))


class XmlSharedStringReviewTests(unittest.TestCase):
 def catalog(self):
  return b'<roblox version="4"><Item class="Folder" referent="catalog"><Properties><string name="Name">BB_VFXCatalogo14</string><SharedString name="Test">key</SharedString></Properties></Item><SharedStrings><SharedString md5="key">Y2F0YWxvZw==</SharedString></SharedStrings></roblox>'
 def test_existing_catalog_shared_payload_must_match_expected_payload(self):
  catalog=self.catalog();out,_=patch_catalog(fixture(),catalog)
  self.assertEqual(patch_catalog(out,catalog),(out,False))
  corrupt=out.replace(b'Y2F0YWxvZw==',b'Y29ycnVwdA==')
  with self.assertRaises(Failure):patch_catalog(corrupt,catalog)
 def test_missing_duplicate_or_ambiguous_shared_entries_are_rejected(self):
  catalog=self.catalog();out,_=patch_catalog(fixture(),catalog)
  table=b'<SharedString md5="key">Y2F0YWxvZw==</SharedString>'
  for raw in (out.replace(table,b''),out.replace(table,table+table),out.replace(table,table+b'<SharedString md5="key">Y29ycnVwdA==</SharedString>')):
   with self.subTest(raw=raw):
    with self.assertRaises(Failure):patch_catalog(raw,catalog)

if __name__=='__main__':unittest.main()
