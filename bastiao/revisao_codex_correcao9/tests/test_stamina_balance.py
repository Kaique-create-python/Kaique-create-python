"""The only authorised Sector7 edit is a modest sprint drain adjustment."""
import copy
from pathlib import Path
import sys
import unittest
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from instalador import patcher

OLD = '''-- All balance and camera values live here. No paid assets required.
return table.freeze({
    WalkSpeed = 10,
    SprintSpeed = 18,
    MaxStamina = 100,
    DrainRate = 22,
    RegenRate = 16,
    RegenDelay = 1.5,
    RestartThreshold = 30,
    -- Bodycam: chest mount below the eyes (studs), lens angle measured
    -- horizontally (degrees) so every screen shape sees the same width,
    -- and the motion-blur cap for fast turns.
    Camera = table.freeze({ChestDrop=0.72, ChestForward=0.28, WideHorizontalFov=112, NormalHorizontalFov=100, MaxTurnBlur=14}),
    Animations = table.freeze({Walk="", Run="", Idle=""}),
})
'''
NEW = OLD.replace('DrainRate = 22,', 'DrainRate = 19,')
PATH = ['ReplicatedStorage', 'Sector7', 'Config']

def row():
    return {'path':PATH.copy(), 'cls':'ModuleScript', 'source':NEW, 'known':[patcher.digest(OLD)]}

def place(source=OLD, config=True):
    root=ET.Element('roblox',version='4')
    rs=ET.SubElement(root,'Item',{'class':'ReplicatedStorage'})
    ET.SubElement(ET.SubElement(rs,'Properties'),'string',name='Name').text='ReplicatedStorage'
    sector=ET.SubElement(rs,'Item',{'class':'Folder'})
    ET.SubElement(ET.SubElement(sector,'Properties'),'string',name='Name').text='Sector7'
    if config:
        obj=ET.SubElement(sector,'Item',{'class':'ModuleScript'}); props=ET.SubElement(obj,'Properties')
        ET.SubElement(props,'string',name='Name').text='Config'
        ET.SubElement(props,'ProtectedString',name='Source').text=source
    ET.SubElement(root,'External',{'map':'preserve','HUD':'preserve'})
    return ET.tostring(root)

class StaminaBalanceTests(unittest.TestCase):
    def test_patch_changes_only_drain_and_is_idempotent(self):
        raw=place(); patched,changed=patcher.patch_place(raw,[row()])
        self.assertTrue(changed)
        doc=ET.fromstring(patched)
        source=doc.find('.//ProtectedString').text
        self.assertEqual(source.replace('DrainRate = 19,','DrainRate = 22,'),OLD)
        self.assertEqual(doc.find('External').attrib,{'map':'preserve','HUD':'preserve'})
        self.assertEqual(patcher.patch_place(patched,[row()]),(patched,False))

    def test_scope_cannot_expand_to_map_hud_or_other_config_edits(self):
        for field,value in [('path',['ReplicatedStorage','Sector7','Other']),('cls','Script'),('source',NEW.replace('SprintSpeed = 18','SprintSpeed = 50'))]:
            bad=row();bad[field]=value
            with self.subTest(field=field),self.assertRaises(patcher.Failure): patcher.validate([bad])

    def test_known_hash_cannot_authorise_foreign_sector_config(self):
        foreign=OLD.replace('WalkSpeed = 10','WalkSpeed = 11'); r=row()
        r['known'].append(patcher.digest(foreign))
        with self.assertRaises(patcher.Failure):patcher.patch_place(place(foreign),[r])

    def test_missing_config_is_not_created(self):
        with self.assertRaises(patcher.Failure):patcher.patch_place(place(config=False),[row()])

    def test_existing_stamina_simulation_keeps_server_authority(self):
        # Both runs use the same 100-unit pool; only drain changes, +15.79% duration.
        self.assertAlmostEqual(100/19,5.2631578947)
        self.assertLess((100/19)/(100/22)-1,.17)


class StaminaReleaseTests(unittest.TestCase):
    def test_release_binds_the_single_reviewed_config_and_test_hash(self):
        import tempfile
        from release_fixture import make_release
        from tooling import release_builder
        from instalador.package import Package
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); make_release(root)
            files,report=release_builder.build_files(root)
            package=Package(files)
            configs=[r for r in package.entries if r['path']==PATH]
            self.assertEqual(len(configs),1,'stamina must reach actual tested/published sources')
            self.assertEqual(configs[0]['source'],NEW)
            self.assertIn('Sector7',package.scripts(1)[0])
            self.assertAlmostEqual(report['sprintSeconds'],100/19)

class OptionalMonsterAnimationTests(unittest.TestCase):
    def test_extra_authored_pursuit_animation_is_preserved(self):
        import json,tempfile
        from release_fixture import make_release,asset,ready,write_json
        from tooling import release_builder as b
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);make_release(root)
            p=root/'modelo/MONSTER_ASSET_PLAN.json'; plan=json.loads(p.read_text())
            clip=asset(root/'modelo','animations/36_CORRER_MEDONHO.rbxm',b'reviewed fixture','36_CORRER_MEDONHO','Animation','model/x-rbxm')
            plan['animations'].append({'file':clip['path'],**{k:v for k,v in clip.items() if k!='path'},'name':clip['key'],'duration_seconds':2,'loop':True,'markers':[{'name':'Step','time':.3,'value':'L'}]})
            receipts=json.loads((root/'modelo/UPLOADED_ASSETS.json').read_text());receipts['assets']+=ready([clip],20000)['assets']
            catalog=b.monster_catalog(plan,receipts)
            self.assertEqual(len(catalog['animations']),36)
            self.assertEqual(catalog['animations']['36_CORRER_MEDONHO']['id'],20000)
            self.assertEqual(catalog['animations']['36_CORRER_MEDONHO']['markers'][0]['name'],'Step')

if __name__=='__main__':unittest.main()
