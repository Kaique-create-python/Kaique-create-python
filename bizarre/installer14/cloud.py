"""Reviewed V13 read/download/task transport. POST requests are never retried."""
import ctypes,ctypes.util,datetime,hashlib,io,json,os,re,struct,sys,time
from pathlib import Path
from urllib.request import Request,build_opener,HTTPRedirectHandler
from urllib.error import HTTPError,URLError
from urllib.parse import urlencode,urlsplit
from .codec import Failure,MAX_FILE
from .runtime import save,read,sha,stamp,TARGET
from .paths import guard,write_once
import xml.etree.ElementTree as ET
API='https://apis.roblox.com'
STATE=None
PACKAGE=None
def number(value):
 if not re.fullmatch(r'[1-9][0-9]{0,18}',str(value)):raise Failure('ID precisa ser um numero positivo.')
 return int(value)
class NoRedirect(HTTPRedirectHandler):
 def redirect_request(self,*a,**k):return None

class Cloud:
 def __init__(self,key,c):
  if c!=TARGET:raise Failure("Destino fixo BIZARRE invalido.")
  self.key=key;self.c=dict(TARGET);self.opener=build_opener(NoRedirect())
 def request(self,path,body=None,method=None,raw=None,mime='application/json'):
  if not path.startswith('/')or path.startswith('//')or '..'in path or '#'in path:raise Failure('Destino invalido.')
  method=method or('POST'if body is not None or raw is not None else 'GET')
  data=raw if raw is not None else json.dumps(body).encode()if body is not None else None
  headers={'x-api-key':self.key,'Accept':'application/json','User-Agent':'BIZARRE-AJUSTE14/1.0'}
  if data is not None:headers['Content-Type']=mime
  for attempt in range(3 if method=='GET'else 1):
   try:
    with self.opener.open(Request(API+path,data=data,headers=headers,method=method),timeout=90)as r:answer=r.read(8*1024*1024+1)
    if len(answer)>8*1024*1024:raise Failure('Resposta acima do limite.')
    return json.loads(answer)if answer else {}
   except HTTPError as e:
    detail=e.read(6000).decode('utf-8','replace').replace(self.key,'[OCULTA]')
    if method=='GET'and e.code in [429,500,502,503,504]and attempt<2:time.sleep(3);continue
    hint=''
    if e.code==403:
     hint=' Confira as permissoes da chave e se o criador e a conta que criou a chave.'
    raise Failure('HTTP '+str(e.code)+' em '+path+': '+detail[:1800]+hint,e.code)from None
   except(URLError,TimeoutError,OSError)as e:
    if method=='GET'and attempt<2:time.sleep(2);continue
    raise Failure(str(e).replace(self.key,'[OCULTA]'))from None
 def history(self):
  rows=[];cursor=None;seen=set()
  for _ in range(100):
   q={'pageSize':100}
   if cursor:q['cursor']=cursor
   r=self.request('/place-version-history-api/v1/'+str(self.c['place'])+'/history?'+urlencode(q))
   if not isinstance(r.get('placeVersions'),list):raise Failure('Formato de historico inesperado.')
   rows.extend(r['placeVersions']);cursor=r.get('nextCursor')
   if not cursor:
    if r.get('hasMore'):raise Failure('Historico incompleto.')
    break
   if cursor in seen:raise Failure('Cursor de historico repetido.')
   seen.add(cursor)
  else:raise Failure('Historico excedeu limite; nada sera enviado.')
  if not rows:raise Failure('Historico vazio. Nao foi escolhida uma versao por tentativa; nada sera enviado.')
  return max(number(r['version'])for r in rows),rows
 def validate_destination(self):
  r=self.request('/universes/v1/places/'+str(self.c['place'])+'/universe')
  if number(r.get('universeId',0))!=self.c['universe']:raise Failure('O Place nao pertence ao universo configurado.')
 def team_empty(self):
  try:r=self.request('/legacy-develop/v1/places/'+str(self.c['place'])+'/teamcreate/active_session/members?limit=100')
  except Failure as e:
   if e.code==403 and('"code":4'in str(e).replace(' ','')or'"code": 4'in str(e)):return
   raise
  if not isinstance(r.get('data'),list):raise Failure('Nao foi possivel conferir Team Create.')
  if r['data']or r.get('nextPageCursor'):raise Failure('Feche as sessoes do Studio/Team Create antes de publicar.')
 def download(self,version,path):
  # GET only. Decode transport compression before checking the Roblox signature.
  import gzip,zlib
  limit=MAX_FILE
  diagnostic={'format':'bizarre-backup-v14','version':number(version),'responses':[],'result':'started'}
  report_path=STATE/'backup-diagnostico-v1_3.json'
  def fail(code,message):
   diagnostic['result']=code;save(report_path,diagnostic)
   raise Failure(message+' Diagnostico seguro: '+str(report_path))
  def kind(raw):
   stripped=raw.removeprefix(b'\xef\xbb\xbf').lstrip()
   if raw.startswith(b'\x1f\x8b'):return 'gzip'
   if raw.startswith(b'\x28\xb5\x2f\xfd'):return 'zstd'
   if raw.startswith(b'<roblox!\x89\xff\r\n\x1a\n'):return 'roblox-binary'
   if stripped.startswith((b'<roblox',b'<?xml')):return 'xml'
   if stripped.startswith((b'{',b'[')):return 'json'
   if stripped[:32].lower().startswith((b'<!doctype html',b'<html')):return 'html'
   if raw.startswith((b'\xff\xfe',b'\xfe\xff')):return 'utf16'
   return 'unknown'
  def receive(response,stage):
   with response as r:
    wire=r.read(limit+1)
    encoding=str(r.headers.get('Content-Encoding','')).strip().lower()
    mime=str(r.headers.get('Content-Type','')).split(';')[0].strip().lower()
    row={'stage':stage,'status':getattr(r,'status',None),'wire_bytes':len(wire),'wire_kind':kind(wire),
     'encoding':encoding if encoding in ['','identity','gzip','x-gzip','deflate','br','zstd']else 'other',
     'mime':mime if mime in ['application/json','application/xml','text/xml','application/octet-stream','text/html','binary/octet-stream']else 'other'}
   diagnostic['responses'].append(row)
   if len(wire)>limit:fail('wire_limit','Backup acima de 64 MB.')
   raw=wire
   for layer in range(3):
    mode=kind(raw)
    if mode=='gzip':
     try:
      with gzip.GzipFile(fileobj=io.BytesIO(raw)) as stream:raw=stream.read(limit+1)
     except (OSError,EOFError,zlib.error):fail('invalid_gzip','O backup chegou com compressao gzip invalida ou incompleta.')
    elif layer==0 and encoding=='deflate'and mode not in ['xml','json','roblox-binary']:
     try:
      decoder=zlib.decompressobj();raw=decoder.decompress(raw,limit+1)
      if len(raw)>limit or decoder.unconsumed_tail:fail('decoded_limit','Backup descompactado acima de 64 MB.')
      if not decoder.eof or decoder.unused_data:fail('invalid_deflate','Compressao deflate incompleta ou inesperada.')
     except zlib.error:fail('invalid_deflate','Nao foi possivel abrir a compressao deflate do backup.')
    else:break
    if len(raw)>limit:fail('decoded_limit','Backup descompactado acima de 64 MB.')
   row.update(decoded_bytes=len(raw),decoded_kind=kind(raw),sha256=sha(raw))
   if kind(raw)=='gzip':fail('compression_depth','Camadas de compressao acima do limite.')
   if kind(raw)=='zstd'or(encoding in ['br','zstd']and kind(raw)not in ['xml','json','roblox-binary']):
    fail('unsupported_compression','O backup usa compressao ainda nao suportada por este instalador.')
   return raw
  url=API+'/asset-delivery-api/v1/assetId/'+str(self.c['place'])+'/version/'+str(number(version))
  request=Request(url,headers={'x-api-key':self.key,'User-Agent':'BIZARRE-AJUSTE14/1.0','Accept-Encoding':'identity'})
  try:
   try:response=self.opener.open(request,timeout=90);stage='asset-delivery'
   except HTTPError as e:
    if e.code in [301,302,303,307,308]:response=self.cdn(e.headers.get('Location',''));stage='cdn-redirect'
    else:
     diagnostic['http_status']=e.code
     fail('http_error','Nao baixou backup: HTTP '+str(e.code)+'.')
   raw=receive(response,stage)
   if kind(raw)=='json':
    try:data=json.loads(raw.decode('utf-8-sig'))
    except (ValueError,UnicodeError):fail('invalid_json','O Roblox devolveu metadados de backup invalidos.')
    if not isinstance(data,dict):fail('unexpected_json','O Roblox nao devolveu o arquivo nem um endereco de download valido.')
    if data.get('assetTypeId')is not None and str(data['assetTypeId'])!='9':
     fail('wrong_asset_type','O download nao foi identificado como um Place.')
    loc=data.get('location')
    if not loc:
     locations=data.get('locations')
     if isinstance(locations,list):loc=next((x.get('location')for x in locations if isinstance(x,dict)and x.get('location')),None)
    if not isinstance(loc,str)or not loc:fail('missing_location','O Roblox respondeu com metadados sem endereco para o backup.')
    raw=receive(self.cdn(loc),'cdn')
  except Failure:raise
  except HTTPError as e:
   diagnostic['http_status']=e.code;fail('http_error','Nao baixou backup: HTTP '+str(e.code)+'.')
  except (URLError,TimeoutError,OSError):fail('network_error','A conexao do backup falhou. Nenhum arquivo desconhecido foi salvo como backup.')
  mode=kind(raw)
  if mode=='roblox-binary':
   if len(raw)<32:fail('truncated_binary','O backup binario recebido esta incompleto.')
  elif mode in ['xml','utf16']:
   try:doc=ET.fromstring(raw)
   except (ET.ParseError,ValueError):fail('invalid_xml','O XML recebido como backup esta incompleto ou invalido.')
   if doc.tag!='roblox'or doc.get('version')!='4':fail('wrong_xml_root','O XML recebido nao e um mapa Roblox versao 4.')
  else:fail('not_roblox','O download do backup ainda nao foi reconhecido como Roblox; publicacao bloqueada.')
  target=guard(path)
  if target.is_symlink():fail('backup_symlink','Caminho inesperado para backup; original preservado.')
  if target.exists()and target.read_bytes()!=raw:
   fail('backup_conflict','Ja existe um backup diferente para esta versao. Ele foi preservado; envie o diagnostico para revisao.')
  write_once(target,raw)
  diagnostic.update(result='validated',backup_format=mode,backup_bytes=len(raw),backup_sha256=sha(raw))
  save(report_path,diagnostic)
  print('Backup reconhecido:',mode,'|',len(raw),'bytes',flush=True)
  return raw

 def cdn(self,url):
  p=urlsplit(url or'');host=p.hostname or''
  if p.scheme!='https'or p.username or p.password or p.port not in [None,443]or not any(host==d or host.endswith('.'+d)for d in ['rbxcdn.com','roblox.com']):raise Failure('URL do CDN invalida.')
  return build_opener(NoRedirect()).open(Request(url,headers={'User-Agent':'BIZARRE-AJUSTE14/1.0'}),timeout=90)
 def task(self,version,source):
  if len(source.encode())>=200000:raise Failure('Luau da tarefa excedeu limite.')
  last=read(STATE/'last-task.json',{})
  delay=max(0,min(13,13-(time.time()-last.get('time',0))))
  if delay:print('Aguardando intervalo entre tarefas…',flush=True);time.sleep(delay)
  save(STATE/'last-task.json',{'time':time.time()})
  r=self.request(f"/cloud/v2/universes/{self.c['universe']}/places/{self.c['place']}/versions/{version}/luau-execution-session-tasks",{'script':source,'timeout':'300s'})
  path=r.get('path','');prefix=f"universes/{self.c['universe']}/places/{self.c['place']}/versions/{version}/luau-execution-sessions/"
  if not path.startswith(prefix)or'/tasks/'not in path or not re.fullmatch(r'[A-Za-z0-9/_-]+',path):raise Failure('Identificador de tarefa invalido.')
  print('Tarefa isolada:',path.replace(self.key,'[OCULTA]'),flush=True);start=time.monotonic();laststate=None
  while r.get('state')in [None,'QUEUED','PROCESSING','STATE_UNSPECIFIED']:
   if r.get('state')!=laststate:print('Estado:',r.get('state','QUEUED'),flush=True);laststate=r.get('state')
   if time.monotonic()-start>420:raise Failure('Tarefa ainda pendente; envie a saida antes de repetir.')
   time.sleep(3);r=self.request('/cloud/v2/'+path)
  if r.get('state')!='COMPLETE':raise Failure('Tarefa falhou: '+json.dumps(r.get('error',r),ensure_ascii=False).replace(self.key,'[OCULTA]'))
  results=r.get('output',{}).get('results',[])
  if not isinstance(results,list)or not results:raise Failure('Relatorio de tarefa ausente.')
  result=results[0]
  if isinstance(result,str):
   try:result=json.loads(result)
   except ValueError:raise Failure('Relatorio de tarefa nao e JSON valido.')from None
  if not isinstance(result,dict)or result.get('package')!=PACKAGE:raise Failure('Relatorio de tarefa inesperado.')
  return result
