"""One file Termux entrypoint. No key, write, or network for testar/status."""
import argparse,fcntl,getpass,json,os,warnings
from pathlib import Path
from .codec import Failure
from .runtime import Runtime,read,TARGET
from .paths import guard,private_dir
from .package import Package
from . import cloud as transport

def hidden_key():
 try:
  with warnings.catch_warnings():
   warnings.simplefilter('error',getpass.GetPassWarning)
   value=getpass.getpass('Chave Open Cloud (oculta; nunca salva): ').strip()
 except (getpass.GetPassWarning,EOFError,KeyboardInterrupt):raise Failure('Nao foi possivel ocultar a chave. Abra um terminal Termux; nada foi enviado.') from None
 if not value:raise Failure('Chave vazia.')
 return value

def main(files,argv=None):
 parser=argparse.ArgumentParser(description='BIZARRE AJUSTE14 — atualiza Sources reconhecidas e catalogo; preserva Place atual.')
 parser.add_argument('command',choices=['testar','testaroffline','testar-nuvem','test','publicar','publish','resume','status'])
 args=parser.parse_args(argv);os.umask(0o077);package=Package(files)
 if args.command in ('testar','testaroffline'):
  package.scripts(1)
  print('Integridade offline OK: AJUSTE'+str(package.stage)+', '+str(len(package.entries))+' fontes, catalogos binario/XML. Nenhuma conexao ou publicacao.');return
 root=private_dir(Path.home()/'.bizarre_instalador')
 conf=read(root/'config.json',{})
 for k,v in TARGET.items():
  if k in conf and str(conf[k])!=str(v):raise Failure('Configuracao existente pertence a outro jogo. Preserve os arquivos.')
 rt=Runtime(root,package.stage,package.digest,package.patch,package.scripts)
 lockpath=guard(root/'lock')
 fd=os.open(lockpath,os.O_WRONLY|os.O_CREAT|getattr(os,'O_NOFOLLOW',0),0o600)
 with os.fdopen(fd,'a') as lock:
  try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  except BlockingIOError:raise Failure('Outro instalador BIZARRE esta em execucao.') from None
  if args.command=='status':print(json.dumps(rt.status(),ensure_ascii=False,indent=2));return
  if args.command!='resume' and rt.pending():raise Failure('Envio pendente. Use resume; nunca repita o POST.')
  key=hidden_key();transport.STATE=rt.state;transport.PACKAGE=rt.package;cloud=transport.Cloud(key,dict(TARGET))
  try:
   if args.command in ('test','testar-nuvem'):rt.test(cloud)
   elif args.command in ('publish','publicar'):rt.publish(cloud)
   else:rt.resume(cloud)
  finally:cloud.key='';key=''
