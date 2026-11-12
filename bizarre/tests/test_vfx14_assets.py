"""Real curated model evidence; no source scripts are executed."""
import hashlib,json,pathlib,subprocess,tempfile,unittest,xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[1]
LUNE='/workspace/ideias-tools/lune'
class CatalogoReal(unittest.TestCase):
 def test_catalogo_real_sanitizado_e_texturas_roundtrip(self):
  self.assertTrue((ROOT/'assets/vfx14/catalogo.rbxm').is_file(),'catálogo curado ainda não implementado')
  manifest=json.loads((ROOT/'assets/vfx14/manifesto.json').read_text())
  self.assertEqual(manifest['zipSha256'],'fd7569c0dec63ab43a99ec27e55bd64f2a9e857a7bb274a65287ada115b73c8c')
  self.assertEqual(len(manifest['templates']),23)
  self.assertEqual(hashlib.sha256((ROOT/'assets/vfx14/catalogo.rbxm').read_bytes()).hexdigest(),manifest['catalogoSha256'])
  self.assertEqual(hashlib.sha256((ROOT/'assets/vfx14/catalogo.rbxmx').read_bytes()).hexdigest(),manifest['xmlSha256'])
  with tempfile.TemporaryDirectory() as d:
   script=pathlib.Path(d)/'inspect.luau'; out=pathlib.Path(d)/'out.xml'
   script.write_text("local r=require('@lune/roblox') local f=require('@lune/fs') f.writeFile("+repr(str(out))+",r.serializeModel(r.deserializeModel(f.readFile("+repr(str(ROOT/'assets/vfx14/catalogo.rbxm'))+")),true))")
   subprocess.run([LUNE,'run',str(script)],check=True,capture_output=True)
   root=ET.parse(out).getroot(); roots=root.findall('Item')
   # Same classes, properties, duplicate-name ordinals and internal refs in XML and binary.
   def tree_signature(document):
    paths={}
    def walk(n,path):
     paths[n.get('referent')]=path
     for index,c in enumerate(n.findall('Item')):walk(c,path+'/'+str(index))
    for index,n in enumerate(document.findall('Item')):walk(n,str(index))
    result=[]
    for n in document.iter('Item'):
     properties={}
     for prop in n.find('Properties'):
      copy=ET.fromstring(ET.tostring(prop));ET.indent(copy,space=' ')
      if copy.tag=='Ref':copy.text=paths.get(copy.text,copy.text)
      properties[copy.get('name')]=ET.tostring(copy,encoding='unicode').strip()
     result.append((paths[n.get('referent')],n.get('class'),properties))
    return result
   self.assertEqual(tree_signature(root),tree_signature(ET.parse(ROOT/'assets/vfx14/catalogo.rbxmx').getroot()))
   self.assertEqual(len(roots),1); self.assertEqual(roots[0].get('class'),'Folder')
   def props(n):return {p.get('name'):p for p in n.find('Properties')}
   self.assertEqual(props(roots[0])['Name'].text,'BB_VFXCatalogo14')
   allowed={'Folder','Model','Part','MeshPart','SpecialMesh','Attachment','ParticleEmitter','Beam','Trail','Decal','Texture','PointLight','SpotLight','SurfaceLight'}
   refs={n.get('referent') for n in root.iter('Item')}
   byname={props(n)['Name'].text:n for n in roots[0].findall('Item')}
   for n in root.iter('Item'):
    self.assertIn(n.get('class'),allowed)
    p=props(n)
    if n.get('class') in {'Beam','Trail'}:
     for k in ['Attachment0','Attachment1']:self.assertIn(p[k].text,refs)
    if n.get('class') in {'Part','MeshPart'}:
     for k in ['CanCollide','CanTouch','CanQuery']:self.assertEqual(p[k].text,'false')
     self.assertEqual(p['Anchored'].text,'true'); self.assertEqual(p['Transparency'].text,'1')
   for t in manifest['templates']:
    n=byname[t['name']]
    textures=sorted(x.text for p in n.iter('Properties') for x in p.iter('uri') if x.text)
    self.assertEqual(textures,sorted(t['textureIds']))
    self.assertEqual(t['textureIdsBefore'],t['textureIds'])
    self.assertEqual(t['beamIntegrityBefore'],t['beamIntegrityAfter'])
    pe=[i for i in n.iter('Item') if i.get('class')=='ParticleEmitter']
    self.assertEqual(len(pe),t['particles'])
    self.assertEqual(t['integrityBefore'],t['integrityAfter'])
    for before,after in zip(t['integrityBefore'],pe):
     p=props(after)
     for k,v in before['properties'].items():
      copy=ET.fromstring(ET.tostring(p[k]));ET.indent(copy,space=' ')
      self.assertEqual(ET.tostring(copy,encoding='unicode').strip(),v)
if __name__=='__main__':unittest.main()
