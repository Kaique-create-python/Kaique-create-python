import importlib
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from instalador.patcher import patch_place, Failure


def xml_item(name,cls='ModuleScript',children='',source='old'):
    return f'<Item class="{cls}"><Properties><string name="Name">{name}</string><ProtectedString name="Source">{source}</ProtectedString></Properties>{children}</Item>'

class PatcherXMLTest(unittest.TestCase):
    def test_ambiguous_ancestor_cannot_select_unique_child(self):
        a=xml_item('ReplicatedStorage','ReplicatedStorage',xml_item('BastiaoShared'))
        b=xml_item('ReplicatedStorage','ReplicatedStorage')
        raw=('<roblox version="4">'+a+b+'</roblox>').encode()
        import hashlib
        rows=[{'path':['ReplicatedStorage','BastiaoShared'],'cls':'ModuleScript','source':'new','known':[hashlib.sha256(b'old').hexdigest()]}]
        with self.assertRaises(Failure):patch_place(raw,rows)

    def test_utf16_doctype_is_rejected_before_entity_expansion(self):
        raw=('<?xml version="1.0" encoding="UTF-16"?><!DOCTYPE roblox [<!ENTITY evil "expanded">]>'
             '<roblox version="4">'+xml_item('ReplicatedStorage','ReplicatedStorage',xml_item('BastiaoShared',source='&evil;'))+'</roblox>').encode('utf-16')
        rows=[{'path':['ReplicatedStorage','BastiaoShared'],'cls':'ModuleScript','source':'expanded'}]
        with self.assertRaises(Failure):patch_place(raw,rows)

    def test_plain_valid_utf16_xml_remains_accepted(self):
        raw=('<?xml version="1.0" encoding="UTF-16"?><roblox version="4">'+xml_item('ReplicatedStorage','ReplicatedStorage',xml_item('BastiaoShared'))+'</roblox>').encode('utf-16')
        rows=[{'path':['ReplicatedStorage','BastiaoShared'],'cls':'ModuleScript','source':'old'}]
        self.assertEqual(patch_place(raw,rows),(raw,False))

if __name__=='__main__':unittest.main()
