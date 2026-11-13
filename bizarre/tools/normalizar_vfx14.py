#!/usr/bin/env python3
"""Rebuild curated real templates offline; original ZIP is never changed."""
import argparse,hashlib,json,pathlib,subprocess,tempfile,xml.etree.ElementTree as ET,zipfile
ZIP_SHA='fd7569c0dec63ab43a99ec27e55bd64f2a9e857a7bb274a65287ada115b73c8c'
ROOT=pathlib.Path(__file__).resolve().parents[1]
E='112672322113504'; S='107474757639811'
def selections():
 result=[]
 for asset,parent,names in [(E,['Anime'],['Punch-01','Punch-02','Punch-03','Stars-01','Shiny-01','Wind-01','Wind-02','Charge-01','ForceField-Break-01','Crack-01','Shoot-01','Portal-01','Portal-Enter-01']), (E,['Beams'],['Wind-01']),(E,['Big'],['Explosion-01']),(S,['vfxpack','premade'],['direction_one','direction_all','speedlines']),(S,['vfxpack','separated'],['impacts','stars','ring','lines','smoke'])]:
  for n in names:
   p=parent+[n]
   result.append(dict(asset=asset,path=p,ordinals=[1]*len(p),name=('E_' if asset==E else 'S_')+'_'.join(p).replace('-','_')))
 return result
def props(n):return {p.get('name'):p for p in n.find('Properties')}
def canonical(n):
 # XML whitespace only; property content remains unchanged.
 n=ET.fromstring(ET.tostring(n)); ET.indent(n,space=' ')
 return ET.tostring(n,encoding='unicode').strip()
def fingerprints(n):
 keys=['AttributesSerialize','TextureContent','EmissionDirection','FlipbookLayout','FlipbookFramerate','FlipbookMode','FlipbookStartRandom','Lifetime','Size','Speed','Rotation','RotSpeed','Color','Rate','TimeScale','Transparency','Acceleration','Drag','SpreadAngle','LightEmission','LightInfluence','LockedToPart','Orientation','Squash','ZOffset','VelocityInheritance']
 return [dict(name=props(i)['Name'].text,properties={k:canonical(props(i)[k]) for k in keys if k in props(i)}) for i in n.iter('Item') if i.get('class')=='ParticleEmitter']

def beam_fingerprints(root):
 paths={}
 def walk(n,path):
  paths[n.get('referent')]=path
  for index,c in enumerate(n.findall('Item')):walk(c,path+'/'+str(index))
 walk(root,'template')
 keys=['TextureContent','Width0','Width1','CurveSize0','CurveSize1','TextureLength','TextureMode','TextureSpeed','Color','Transparency','FaceCamera','Segments','LightEmission','LightInfluence','Brightness','ZOffset']
 result=[]
 for n in root.iter('Item'):
  if n.get('class') not in ['Beam','Trail']:continue
  p=props(n)
  refs={k:paths[p[k].text] for k in ['Attachment0','Attachment1']}
  result.append(dict(className=n.get('class'),path=paths[n.get('referent')],refs=refs,properties={k:canonical(p[k]) for k in keys if k in p}))
 return result

def build(zip_path,lune):
 raw=pathlib.Path(zip_path).read_bytes()
 if hashlib.sha256(raw).hexdigest()!=ZIP_SHA:raise ValueError('ZIP diferente do aprovado')
 out=ROOT/'assets/vfx14'; out.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='bb-vfx14-') as d:
  temp=pathlib.Path(d); plan=selections(); source_info={}
  with zipfile.ZipFile(zip_path) as z:
   for asset in [E,S]:
    filename=next(n for n in z.namelist() if n.startswith(asset+'_'))
    data=z.read(filename); source_info[asset]=dict(filename=filename,sha256=hashlib.sha256(data).hexdigest())
    if not data.startswith(b'<roblox!'):
     root=ET.fromstring(data)
     for el in root.iter('ContentId'):el.tag='Content'
     data=ET.tostring(root,encoding='utf-8')
    (temp/(asset+'.rbxm')).write_bytes(data)
  (temp/'plan.json').write_text(json.dumps(plan))
  subprocess.run([lune,'run',str(ROOT/'tools/curar_vfx14.luau'),'build',d,str(out)],check=True)
  source={props(n)['Name'].text:n for n in ET.parse(temp/'fontes.xml').find('Item').findall('Item')}
  target={props(n)['Name'].text:n for n in ET.parse(temp/'catalogo.xml').find('Item').findall('Item')}
  for spec in plan:
   name=spec['name']; before=fingerprints(source[name]); after=fingerprints(target[name])
   if before!=after:raise ValueError('Particle properties changed: '+name)
   ids=sorted(x.text for p in target[name].iter('Properties') for x in p.iter('uri') if x.text)
   original_ids=sorted(x.text for p in source[name].iter('Properties') for x in p.iter('uri') if x.text)
   if ids!=original_ids:raise ValueError('Texture content changed: '+name)
   beam_before=beam_fingerprints(source[name]);beam_after=beam_fingerprints(target[name])
   if beam_before!=beam_after:raise ValueError('Beam/Trail properties or relative references changed: '+name)
   spec.update(source_info[spec['asset']],credit='Euphoric Games' if spec['asset']==E else 'acertaincreatorwesley; package disclaimer: images are not original',textureIds=ids,particles=len(before),integrityBefore=before,integrityAfter=after,textureIdsBefore=original_ids,beamIntegrityBefore=beam_before,beamIntegrityAfter=beam_after)
  manifest=dict(version=14,root='BB_VFXCatalogo14',zipSha256=ZIP_SHA,catalogoSha256=hashlib.sha256((out/'catalogo.rbxm').read_bytes()).hexdigest(),xmlSha256=hashlib.sha256((out/'catalogo.rbxmx').read_bytes()).hexdigest(),templates=plan)
  (out/'manifesto.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(); p.add_argument('zip'); p.add_argument('--lune',default='/workspace/ideias-tools/lune');a=p.parse_args();build(a.zip,a.lune)
