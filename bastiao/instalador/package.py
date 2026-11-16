"""Pacote da etapa: lista fixa de scripts novos e o teste nativo. Sem catalogos, sem midia."""
import hashlib,json
from .codec import Failure
from .patcher import patch_place,validate
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
  self.files=files;self.stage=json.loads(files.get('package.json',b'{"stage":0}'))['stage']
  if not isinstance(self.stage,int) or not 1<=self.stage<=99:raise Failure('Etapa invalida.')
  self.name='BASTIAO-ETAPA-'+str(self.stage)
  manifest=json.loads(files['manifest.json'])
  if len(files)>256 or sum(map(len,files.values()))>16*1024*1024:raise Failure('Pacote acima do limite.')
  if set(manifest)!=set(files)-{'manifest.json'}:raise Failure('Manifesto incompleto.')
  for name,digest in manifest.items():
   if sha(files[name])!=digest:raise Failure('Integridade invalida: '+name)
  self.digest=sha(files['manifest.json']);self.entries=json.loads(files['sources.json'])
  validate(self.entries)
  if not files.get('teste_nuvem.luau','').strip():raise Failure('Teste nativo ausente.')
 def patch(self,raw):
  return patch_place(raw,self.entries)
 def scripts(self,version,verify=False):
  cfg=dict(package=self.name,stage=self.stage,version=version,**TARGET)
  cfg['hashes']=[{'path':r['path'],'class':r['cls'],'bytes':len(r['source'].encode()),'hash':djb(r['source'].encode())} for r in self.entries]
  script='local cfg=game:GetService("HttpService"):JSONDecode('+literal(json.dumps(cfg,ensure_ascii=False,separators=(',',':')))+')\n'+self.files['teste_nuvem.luau'].decode()
  if len(script.encode())>=200000:raise Failure('Teste nativo acima do limite Roblox de 200 KB.')
  return [script]
