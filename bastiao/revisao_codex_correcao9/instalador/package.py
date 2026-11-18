"""Pacote da etapa: lista fixa de scripts novos, o teste nativo e (opcional) os sons da etapa."""
import hashlib,json
from .codec import Failure
from .patcher import patch_place,validate
from .runtime import TARGET
from .midia import fonte_audio,validar_dados,CAMINHO as CAMINHO_AUDIO,CABECALHO as CABECALHO_AUDIO

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
  self.files=files;config=json.loads(files.get('package.json',b'{"stage":0}'));self.stage=config['stage']
  if type(self.stage)is not int or not 1<=self.stage<=99:raise Failure('Etapa invalida.')
  self.assets_ready=config.get('assetsReady')is True
  self.bound_ids=config.get('legacyAudioIds',{})
  if self.stage>=3 and (not self.assets_ready or not isinstance(self.bound_ids,dict)):
   raise Failure('ETAPA3 requer assets aprovados e IDs vinculados antes do teste.')
  self.name='BASTIAO-ETAPA-'+str(self.stage)
  manifest=json.loads(files['manifest.json'])
  if len(files)>256 or sum(map(len,files.values()))>16*1024*1024:raise Failure('Pacote acima do limite.')
  if set(manifest)!=set(files)-{'manifest.json'}:raise Failure('Manifesto incompleto.')
  for name,digest in manifest.items():
   if sha(files[name])!=digest:raise Failure('Integridade invalida: '+name)
  self.digest=sha(files['manifest.json']);self.entries=json.loads(files['sources.json'])
  validate(self.entries)
  if not files.get('teste_nuvem.luau','').strip():raise Failure('Teste nativo ausente.')
  # sons: o modulo Audio e gerado (trechos + IDs); um Audio gerado antes pode ser trocado
  self.audio=None;self.ids={}
  row=self._linha_audio()
  if 'audio.json' in files:
   self.audio=validar_dados(json.loads(files['audio.json']))
   for info in self.audio['sprites'].values():
    if info['arquivo'] not in files:raise Failure('Arquivo de som ausente no pacote: '+info['arquivo'])
   if self.stage>=3:
    if any(type(self.bound_ids.get(k))is not int or not 0<self.bound_ids[k]<=2**53-1 for k in self.audio['sprites']):
     raise Failure('ETAPA3 requer ID real para cada sprite obrigatório.')
    self.ids=dict(self.bound_ids)
   if row is None or row['source']!=fonte_audio(self.audio,self.ids):raise Failure('Modulo Audio do pacote nao bate com audio.json.')
   row.setdefault('generatedAudio',[self.audio])
   row.pop('gerado',None)
  elif self.stage>=3:raise Failure('Áudio obrigatório da ETAPA3 ausente.')
 def _linha_audio(self):
  return next((r for r in self.entries if r['path']==CAMINHO_AUDIO),None)
 def usar_ids(self,ids):
  """Coloca os IDs dos sons no modulo Audio (antes do teste; publish usa os mesmos IDs)."""
  if self.audio is None:return
  if self.stage>=3 and ids!=self.bound_ids:
   raise Failure('IDs divergem dos assets aprovados desta entrega. Rode assets e testar-nuvem novamente.')
  self._linha_audio()['source']=fonte_audio(self.audio,ids)
  self.ids=dict(ids)
 def aceitar_proprias(self,digests):
  """Fontes que o próprio instalador gravou antes (Saved de teste) também podem ser trocadas."""
  extra=sorted(d for d in digests if isinstance(d,str) and len(d)==64)
  if not extra:return 0
  for row in self.entries:row['known']=sorted(set(row.get('known',[]))|set(extra))
  return len(extra)
 def patch(self,raw):
  return patch_place(raw,self.entries)
 def scripts(self,version,verify=False):
  cfg=dict(package=self.name,stage=self.stage,version=version,**TARGET)
  cfg['hashes']=[{'path':r['path'],'class':r['cls'],'bytes':len(r['source'].encode()),'hash':djb(r['source'].encode())} for r in self.entries]
  script='local cfg=game:GetService("HttpService"):JSONDecode('+literal(json.dumps(cfg,ensure_ascii=False,separators=(',',':')))+')\n'+self.files['teste_nuvem.luau'].decode()
  if len(script.encode())>=200000:raise Failure('Teste nativo acima do limite Roblox de 200 KB.')
  return [script]
