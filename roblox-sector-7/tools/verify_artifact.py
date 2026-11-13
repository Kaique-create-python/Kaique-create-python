"""Structural validation of the portable place; not a substitute for Studio playtest."""
from pathlib import Path
import xml.etree.ElementTree as ET
import json
root=Path(__file__).resolve().parents[1]
tree=ET.parse(root/'build/Sector7.rbxlx')
items=list(tree.iter('Item'))
refs={i.attrib['referent'] for i in items}
assert len(refs)==len(items), 'Duplicate references'
for ref in tree.iter('Ref'):
    assert ref.text in refs|{'null','nil',None}, f'Dangling reference {ref.text}'
def named(name):
    return next(i for i in items if i.findtext("Properties/string[@name='Name']")==name)
world=named('Sector7World')
assert not list(world.iter('SurfaceGui'))
assert not any(i.attrib['class'] in {'SurfaceGui','TextLabel'} for i in world.iter('Item')), 'Environmental lettering prohibited'
parts=[i for i in world.iter('Item') if i.attrib['class'] in {'Part','SpawnLocation'}]
assert len(parts)==1515, len(parts)
rig=named('StarterCharacter')
humanoid=next(i for i in rig.iter('Item') if i.attrib['class']=='Humanoid')
assert humanoid.findtext("Properties/token[@name='RigType']")=='0', 'R6 required'
assert named('Animate').findtext("Properties/ProtectedString[@name='Source']"), 'Default animation script missing'
assert rig.findtext("Properties/Ref[@name='PrimaryPart']")==named('HumanoidRootPart').attrib['referent']
for path in (root/'src').rglob('*.luau'):
    name=path.name.replace('.client','').replace('.server','').replace('.luau','')
    source=named(name).findtext("Properties/ProtectedString[@name='Source']")
    assert source==path.read_text(encoding='utf-8'), f'Stale source {name}'
manifest=named('AttributeManifest')
interactions=set()
for value in manifest.findall('Item'):
    data=value.find("Item/Properties/string[@name='Value']")
    if data is not None:
        attrs=json.loads(data.text)
        if 'InteractionId' in attrs: interactions.add(attrs['InteractionId'])
assert interactions=={'Fuse1','Fuse2','Fuse3','Generator','Keycard','Exit','Note1','Note2','Note3','Note4'}
print(f'PASS: {len(items)} instances, 1515 map parts, no signs, R6 rig, 10 interactions, current source, no dangling references')
