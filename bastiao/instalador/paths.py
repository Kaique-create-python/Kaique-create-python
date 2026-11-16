"""Private local state; reject symlinks in every existing path component."""
import os
from pathlib import Path
from .codec import Failure,MAX_FILE

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

def remove(path):
 path=guard(path);path.unlink(missing_ok=True);sync_dir(path.parent)

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
