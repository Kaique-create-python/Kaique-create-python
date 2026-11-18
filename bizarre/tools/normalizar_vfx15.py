#!/usr/bin/env python3
"""Curate the exact owner ZIP. No original or Roblox assets are modified."""
import hashlib,json,tempfile,zipfile,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ZIP_SHA='fd7569c0dec63ab43a99ec27e55bd64f2a9e857a7bb274a65287ada115b73c8c'
def selections():
 rows=[]
 for name in ['Fire-01','Fire-02','Fire-03','Flamethrower-01','Fire-Slash-01','Slash-01','Slashes-01','Slash-Impact-01','Realistic-Explosion-01','Smoke-01']:
  rows.append(dict(asset='112672322113504',path=['Anime',name],name='N_'+name.replace('-','_')))
 rows.append(dict(asset='112672322113504',path=['Auras','Fire-Aura-01'],name='N_Fire_Aura_01'))
 for leaf,name in [('Slash','N_Mesh_Slash'),('MeshPart','N_Mesh_Wide')]:
  rows.append(dict(asset='94340858809782',path=['Sword Slash Effect','ReplicatedStorage','Combat','Sword','Fx',leaf],name=name,mesh=True))
 rows.append(dict(asset='10153386313',path=['Sword Slash Effect'],name='N_Mesh_Arc',mesh=True))
 for row in rows:row["ordinals"]=[1]*len(row["path"])
 return rows

def build(zip_path,lune):
 raw=Path(zip_path).read_bytes()
 if hashlib.sha256(raw).hexdigest()!=ZIP_SHA:raise ValueError('Original ZIP does not match')
 out=ROOT/'assets/vfx15';out.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory()as d:
  tmp=Path(d);plan=selections()
  with zipfile.ZipFile(zip_path)as z:
   for asset in sorted({r['asset']for r in plan}):
    data=z.read(next(n for n in z.namelist()if n.startswith(asset+'_')))
    if not data.startswith(b'<roblox!'):
     tree=ET.fromstring(data)
     for el in tree.iter('ContentId'):el.tag='Content'
     data=ET.tostring(tree,encoding='utf-8')
    (tmp/(asset+'.rbxm')).write_bytes(data)
  (tmp/'plan.json').write_text(json.dumps(plan))
  subprocess.run([lune,'run',str(ROOT/'tools/curar_vfx15.luau'),d,str(out)],check=True)
 if __name__=='__main__':print(out)
if __name__=='__main__':build(sys.argv[1],sys.argv[2])
