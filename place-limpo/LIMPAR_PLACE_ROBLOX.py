#!/usr/bin/env python3
"""Atualizador de Baseplate para o Place 122033314086516."""

import datetime, fcntl, getpass, hashlib, io, json, os, re, sys, time, uuid, warnings, argparse

from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit

from urllib.request import Request, build_opener, HTTPRedirectHandler
import xml.etree.ElementTree as ET

API = 'https://apis.roblox.com'
MAX_FILE = 64 * 1024 * 1024
STATE = None

TARGET = {'universe': 10774214423, 'place': 122033314086516}

PLACE_LIMPO = b'<roblox!\x89\xff\r\n\x1a\n\x00\x00\x03\x00\x00\x00\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00INST\x17\x00\x00\x00\x15\x00\x00\x00\x00\x00\x00\x00\xf0\x06\x00\x00\x00\x00\x04\x00\x00\x00Part\x00\x01\x00\x00\x00\x00\x00\x00\x00INST \x00\x00\x00\x1e\x00\x00\x00\x00\x00\x00\x00\xf0\x0f\x01\x00\x00\x00\r\x00\x00\x00SpawnLocation\x00\x01\x00\x00\x00\x00\x00\x00\x02INST\x1d\x00\x00\x00\x1b\x00\x00\x00\x00\x00\x00\x00\xf0\x0c\x02\x00\x00\x00\t\x00\x00\x00Workspace\x01\x01\x00\x00\x00\x00\x00\x00\x04\x01PROP\x14\x00\x00\x00\x12\x00\x00\x00\x00\x00\x00\x00\xf0\x03\x00\x00\x00\x00\x08\x00\x00\x00Anchored\x02\x01PROP\x19\x00\x00\x00\x17\x00\x00\x00\x00\x00\x00\x00\xf0\x08\x00\x00\x00\x00\x0b\x00\x00\x00Color3uint8\x1ac_bPROP\x17\x00\x00\x00\x15\x00\x00\x00\x00\x00\x00\x00\xf0\x06\x00\x00\x00\x00\x08\x00\x00\x00Material\x12\x00\x00\x01\x00PROP\x1c\x00\x00\x00\x1a\x00\x00\x00\x00\x00\x00\x00\xf0\x0b\x00\x00\x00\x00\x04\x00\x00\x00Name\x01\t\x00\x00\x00BaseplatePROP\x1b\x00\x00\x00\x19\x00\x00\x00\x00\x00\x00\x00\xf0\n\x00\x00\x00\x00\x04\x00\x00\x00size\x0e\x88\x00\x00\x00\x83@\x00\x00\x88\x00\x00\x00PROP\x19\x00\x00\x00\x17\x00\x00\x00\x00\x00\x00\x00\xf0\x08\x00\x00\x00\x00\n\x00\x00\x00TopSurface\x12\x00\x00\x00\x03PROP"\x00\x00\x00 \x00\x00\x00\x00\x00\x00\x00\xf0\x11\x01\x00\x00\x00\x16\x00\x00\x00AllowTeamChangeOnTouch\x02\x00PROP\x14\x00\x00\x00\x12\x00\x00\x00\x00\x00\x00\x00\xf0\x03\x01\x00\x00\x00\x08\x00\x00\x00Anchored\x02\x01PROP\x17\x00\x00\x00\x15\x00\x00\x00\x00\x00\x00\x00\xf0\x06\x01\x00\x00\x00\x08\x00\x00\x00Duration\x03\x00\x00\x00\x00PROP \x00\x00\x00\x1e\x00\x00\x00\x00\x00\x00\x00\xf0\x0f\x01\x00\x00\x00\x04\x00\x00\x00Name\x01\r\x00\x00\x00SpawnLocationPROP\x13\x00\x00\x00\x11\x00\x00\x00\x00\x00\x00\x00\xf0\x02\x01\x00\x00\x00\x07\x00\x00\x00Neutral\x02\x01PROP\x1b\x00\x00\x00\x19\x00\x00\x00\x00\x00\x00\x00\xf0\n\x01\x00\x00\x00\x04\x00\x00\x00size\x0e\x81\x80\x00\x00\x7f\x00\x00\x00\x81\x80\x00\x00PROP\x1c\x00\x00\x00\x1a\x00\x00\x00\x00\x00\x00\x00\xf0\x0b\x02\x00\x00\x00\x04\x00\x00\x00Name\x01\t\x00\x00\x00WorkspacePRNT\x12\x00\x00\x00\x1d\x00\x00\x00\x00\x00\x00\x008\x00\x03\x00\x01\x00"\x02\x02\x0e\x00`\x00\x00\x00\x04\x00\x05END\x00\x00\x00\x00\x00\t\x00\x00\x00\x00\x00\x00\x00</roblox>'

class Failure(Exception):
 def __init__(self,message,code=None):super().__init__(message);self.code=code

def guard(path,within=None):
 p=Path(path).absolute()
 if '..' in p.parts:raise Failure('Caminho com retorno de pasta bloqueado.')
 for part in [p,*p.parents]:
  if part.is_symlink():raise Failure('Caminho com link simbolico bloqueado: '+str(part))
 if within is not None:
  try:p.relative_to(Path(within).absolute())
  except ValueError:raise Failure('Arquivo fora da pasta privada do instalador.') from None
 return p

def private_dir(path):
 path=guard(path);missing=[];current=path
 while not current.exists():missing.append(current);current=current.parent
 for directory in reversed(missing):
  directory.mkdir(mode=0o700);sync_dir(directory.parent)
 os.chmod(path,0o700);sync_dir(path);return path

def sync_dir(path):
 path=guard(path)
 fd=os.open(path,os.O_RDONLY|getattr(os,'O_DIRECTORY',0)|getattr(os,'O_NOFOLLOW',0))
 try:os.fsync(fd)
 finally:os.close(fd)

def sync_file(path):
 path=guard(path)
 fd=os.open(path,os.O_RDONLY|getattr(os,'O_NOFOLLOW',0))
 try:os.fsync(fd)
 finally:os.close(fd)
 sync_dir(path.parent)

def write_once(path,raw):
 path=guard(path)
 if len(raw)>MAX_FILE:raise Failure('Arquivo acima do limite de 64 MB.')
 if path.exists():
  if path.read_bytes()!=raw:raise Failure('Backup/arquivo existente diferente; original preservado.')
  sync_file(path)
  return path
 fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|getattr(os,'O_NOFOLLOW',0),0o600)
 with os.fdopen(fd,'wb') as f:f.write(raw);f.flush();os.fsync(f.fileno())
 sync_dir(path.parent)
 return path

def sha(raw):return hashlib.sha256(raw).hexdigest()

def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()

def read(path,default=None):
    path=guard(path)
    if path.is_symlink():raise Failure('Metadado e um link inesperado; preserve e revise: '+str(path))
    try:return json.loads(path.read_text())
    except FileNotFoundError:return default

def save(path,value):
    path=guard(path)
    if path.is_symlink():raise Failure('Metadado e um link inesperado: '+str(path))
    private_dir(path.parent)
    temp=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    try:
        with temp.open('x',encoding='utf8')as stream:
            os.chmod(temp,0o600);json.dump(value,stream,ensure_ascii=False,indent=2)
            stream.flush();os.fsync(stream.fileno())
        temp.replace(path)
        sync_dir(path.parent)
    finally:temp.unlink(missing_ok=True)

def number(value):
 if not re.fullmatch(r'[1-9][0-9]{0,18}',str(value)):raise Failure('ID precisa ser um numero positivo.')
 return int(value)

class NoRedirect(HTTPRedirectHandler):
 def redirect_request(self,*a,**k):return None

class Cloud:
 def __init__(self,key,c):
  if c!=TARGET:raise Failure("Destino fixo inválido.")
  self.key=key;self.c=dict(TARGET);self.opener=build_opener(NoRedirect())
 def request(self,path,body=None,method=None,raw=None,mime='application/json'):
  if not path.startswith('/')or path.startswith('//')or '..'in path or '#'in path:raise Failure('Destino invalido.')
  method=method or('POST'if body is not None or raw is not None else 'GET')
  data=raw if raw is not None else json.dumps(body).encode()if body is not None else None
  headers={'x-api-key':self.key,'Accept':'application/json','User-Agent':'Place-Limpo/1.0'}
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
  diagnostic={'format':'bastiao-backup-v1','version':number(version),'responses':[],'result':'started'}
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
  request=Request(url,headers={'x-api-key':self.key,'User-Agent':'Place-Limpo/1.0','Accept-Encoding':'identity'})
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
  return build_opener(NoRedirect()).open(Request(url,headers={'User-Agent':'Place-Limpo/1.0'}),timeout=90)

"""Fluxo do atualizador. O gerador inclui o transporte e o Baseplate revisados."""


def confirmar_destino():
    opener = build_opener(NoRedirect())

    def public(url):
        with opener.open(url, timeout=25) as response:
            return json.loads(response.read(2 * 1024 * 1024))

    link = public(f"{API}/universes/v1/places/{TARGET['place']}/universe")
    games = public(f"https://games.roblox.com/v1/games?universeIds={TARGET['universe']}")["data"]
    if link.get("universeId") != TARGET["universe"] or len(games) != 1:
        raise Failure("O Roblox não confirmou a correspondência dos IDs.")
    game = games[0]
    if game.get("id") != TARGET["universe"] or game.get("rootPlaceId") != TARGET["place"]:
        raise Failure("O Roblox não confirmou este Place como o local inicial.")
    print(f"Experiência {game['name']!r} · Universo {TARGET['universe']} · Place inicial {TARGET['place']}")
    print("Conteúdo preparado: Baseplate 512 × 512 e um ponto de nascer, sem conteúdo personalizado.")


def atual(cloud):
    latest, rows = cloud.history()
    published = [number(v["version"]) for v in rows if v.get("isPublished") is True]
    if not published:
        raise Failure("Não foi possível identificar uma versão publicada para o backup.")
    return latest, max(published)


def conferir_publicacao(cloud, receipt):
    latest, published = atual(cloud)
    if published <= receipt["publicada_anterior"]:
        raise Failure("O Roblox ainda não confirmou uma versão publicada após o envio. Use verificar.")
    if receipt.get("versao_resposta", published) != published:
        raise Failure("A versão publicada atual diverge da resposta do envio. Preserve o backup.")
    found = cloud.download(published, STATE / f"Conferencia_v{published}.rbxl")
    if found != PLACE_LIMPO:
        raise Failure("O arquivo devolvido pelo Roblox difere do preparado. Preserve o recibo e confira o histórico.")
    save(STATE / f"Publicacao_v{published}.json", {**receipt, "publicada": published, "verificada": True})
    (STATE / "envio-pendente.json").unlink()
    sync_dir(STATE)
    print(f"Place limpo publicado e conferido na versão {published}.")


def limpar(cloud):
    pending = STATE / "envio-pendente.json"
    if pending.exists():
        raise Failure("Já existe um envio pendente. Execute verificar antes de tentar novamente.")
    latest, published = atual(cloud)
    backups = {}
    for version in sorted({latest, published}):
        target = STATE / f"Backup_Place_{TARGET['place']}_v{version}.rbxl"
        raw = cloud.download(version, target)
        backups[str(version)] = {"arquivo": target.name, "sha256": sha(raw), "bytes": len(raw)}
        print(f"Backup da versão {version} guardado em {target}")
        if version == published and raw == PLACE_LIMPO and latest == published:
            print("A versão publicada já corresponde ao Baseplate preparado.")
            return
    write_once(STATE / "Baseplate.rbxl", PLACE_LIMPO)
    print(f"A limpeza troca todo o conteúdo do Place inicial. Versão publicada atual {published}.")
    confirmacao = f"LIMPAR {TARGET['place']}"
    if input(f"Para substituir o Place, digite {confirmacao}\n> ").strip() != confirmacao:
        print("Limpeza cancelada. Backups preservados.")
        return
    cloud.validate_destination()
    if atual(cloud) != (latest, published):
        raise Failure("O histórico mudou desde o backup. Rode limpar novamente para conferir a versão nova.")
    receipt = {**TARGET, "salva_anterior": latest, "publicada_anterior": published,
               "backups": backups, "sha256_baseplate": sha(PLACE_LIMPO), "data": stamp()}
    write_once(pending, json.dumps(receipt).encode())
    try:
        path = f"/universes/v1/{TARGET['universe']}/places/{TARGET['place']}/versions?versionType=Published"
        result = cloud.request(path, method="POST", raw=PLACE_LIMPO, mime="application/octet-stream")
    except Failure as exc:
        if exc.code in (400, 401, 403, 404, 413, 415, 422, 429):
            save(STATE / "envio-recusado.json", {**receipt, "http": exc.code})
            pending.unlink()
            sync_dir(STATE)
        raise
    receipt["versao_resposta"] = number(result.get("versionNumber", 0))
    save(pending, receipt)
    conferir_publicacao(cloud, receipt)


def main():
    global STATE
    parser = argparse.ArgumentParser(description="Modelo limpo para o Place inicial de Ideias.")
    parser.add_argument("acao", nargs="?", default="info", choices=("info", "limpar", "verificar"))
    args = parser.parse_args()
    confirmar_destino()
    if args.acao == "info":
        return
    STATE = private_dir(Path.home() / f"roblox-place-{TARGET['place']}")
    with guard(STATE / "execucao.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Failure("Já existe uma execução aberta para este Place.") from None
        pending = STATE / "envio-pendente.json"
        if args.acao == "limpar" and pending.exists():
            raise Failure("Já existe um envio pendente. Execute verificar.")
        receipt = read(pending) if args.acao == "verificar" else None
        if args.acao == "verificar" and receipt is None:
            print("Nenhum envio pendente. Backups e recibos ficam em", STATE)
            return
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            key = getpass.getpass("Chave Open Cloud (oculta): ").strip()
        if not key:
            raise Failure("A chave está vazia.")
        cloud = Cloud(key, TARGET)
        cloud.validate_destination()
        if args.acao == "limpar":
            limpar(cloud)
        else:
            if any(receipt.get(k) != v for k, v in TARGET.items()) or receipt.get("sha256_baseplate") != sha(PLACE_LIMPO):
                raise Failure("Recibo pertence a outro envio.")
            conferir_publicacao(cloud, receipt)


if __name__ == "__main__":
    try:
        main()
    except (Failure, OSError, ValueError, KeyError, EOFError, KeyboardInterrupt, getpass.GetPassWarning) as error:
        print("Interrompido.", str(error), file=sys.stderr)
        if STATE and (STATE / "envio-pendente.json").exists():
            print("Envio pendente. Use o comando verificar com este mesmo arquivo.", file=sys.stderr)
        raise SystemExit(1)
