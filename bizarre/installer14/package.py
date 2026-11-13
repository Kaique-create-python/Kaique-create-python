"""Fixed AJ13-to-AJ14 source manifest and native preflight contract."""
import hashlib,json
from .codec import Failure
from .patcher import patch_place,validate
from .catalog import patch_catalog,Binary,_validate_catalog,xml_doc,_xml_signature,_xml_shared_values
from .runtime import TARGET

def sha(raw):return hashlib.sha256(raw).hexdigest()
def djb(raw):
 value=5381
 for byte in raw:value=(value*33+byte)&0xffffffff
 return '%08x'%value

def literal(text):
 for n in range(30):
  eq='='*n
  if ']'+eq+']' not in text:return '['+eq+'['+text+']'+eq+']'
 raise Failure('Nao foi possivel escapar script do teste.')

class Package:
 def __init__(self,files):
  self.files=files;self.stage=json.loads(files.get('package.json',b'{"stage":14}'))['stage']
  if self.stage not in (14,15,16,17,18):raise Failure('Revisao invalida.')
  self.name='BIZARRE-AJUSTE-'+str(self.stage)
  manifest=json.loads(files['manifest.json'])
  if len(files)>256 or sum(map(len,files.values()))>16*1024*1024:raise Failure('Pacote acima do limite.')
  if set(manifest)!=set(files)-{'manifest.json'}:raise Failure('Manifesto incompleto.')
  for name,digest in manifest.items():
   if sha(files[name])!=digest:raise Failure('Integridade invalida: '+name)
  self.digest=sha(files['manifest.json']);self.entries=json.loads(files['sources.json'])
  validate(self.entries)
  _validate_catalog(Binary(files['catalogo.rbxm']))
  if self.stage>=15:
   newer=Binary(files['catalogo15.rbxm']);ref=_validate_catalog(newer)
   if newer.objects[ref]['name']!='BB_VFXCatalogo15':raise Failure('Catalogo15 incorreto.')
   newer_xml=xml_doc(files['catalogo15.rbxmx']);new_roots=newer_xml.findall('Item')
   if len(new_roots)!=1 or new_roots[0].findtext("Properties/string[@name='Name']")!='BB_VFXCatalogo15':raise Failure('Catalogo15 XML incorreto.')
   _xml_signature(new_roots[0]);_xml_shared_values(newer_xml,new_roots[0])
  cat=xml_doc(files['catalogo.rbxmx']);roots=cat.findall('Item')
  if len(roots)!=1:raise Failure('Catalogo XML sem raiz unica.')
  _xml_signature(roots[0])
  _xml_shared_values(cat,roots[0])
  if not files['teste_nuvem14.luau'].strip():raise Failure('Teste nativo ausente.')
 def patch(self,raw):
  first,a=patch_place(raw,self.entries)
  second,b=patch_catalog(first,self.files['catalogo.rbxm' if raw.startswith(b'<roblox!') else 'catalogo.rbxmx'])
  if self.stage>=15:
   third,c=patch_catalog(second,self.files['catalogo15.rbxm' if raw.startswith(b'<roblox!') else 'catalogo15.rbxmx'])
   return third,a or b or c
  return second,a or b
 def scripts(self,version,verify=False):
  cfg=dict(package=self.name,stage=self.stage,version=version,**TARGET)
  cfg['hashes']=[{'path':r['path'],'class':r['cls'],'bytes':len(r['source'].encode()),'hash':djb(r['source'].encode())} for r in self.entries]
  script='local cfg=game:GetService("HttpService"):JSONDecode('+literal(json.dumps(cfg,ensure_ascii=False,separators=(',',':')))+')\n'+self.files['teste_nuvem14.luau'].decode()
  if len(script.encode())>=200000:raise Failure('Teste nativo acima do limite Roblox de 200 KB.')
  return [script]
