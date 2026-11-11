#!/usr/bin/env python3
"""Compose current Place bytes with confirmed local media receipts. No HTTP/key access."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET

FILES={'audio':'IdeiasSons.ogg','logo':'IdeiasLogo.png','icons':'IdeiasIcones.png'}
MARKERS={'audio':('Id','SPRITE_ID'),'logo':('Logo','LOGO_ID'),'icons':('Icons','ICONS_ID')}

def sha(raw):return hashlib.sha256(raw).hexdigest()
def positive(value):
 return isinstance(value,(int,str))and not isinstance(value,bool)and re.fullmatch(r'[1-9][0-9]{0,18}',str(value))is not None and int(value)<=9007199254740991
def pattern(kind):
 name,marker=MARKERS[kind]
 return re.compile(r'\b('+name+r'\s*=\s*)([0-9]+)(,\s*--@@'+marker+r'@@)')

def config_source(raw):
 root=ET.fromstring(raw)
 if root.tag!='roblox'or root.get('version')!='4':raise ValueError('O arquivo base nao e um Place XML valido.')
 found=[]
 def walk(node,path):
  for item in node.findall('Item'):
   current=path+(item.findtext("Properties/string[@name='Name']"),)
   if current==('ReplicatedStorage','IdeiasShared','Config'):
    source=item.find("Properties/*[@name='Source']")
    if item.get('class')!='ModuleScript'or source is None:raise ValueError('Config do Place invalido.')
    found.append(source.text or '')
   walk(item,current)
 walk(root,())
 if len(found)!=1:raise ValueError('Config do Place ausente ou ambiguo.')
 for kind in MARKERS:
  if len(pattern(kind).findall(found[0]))!=1:raise ValueError('Marcador de midia ausente/duplicado: '+kind)
 return found[0]

def atomic(path,raw):
 path=Path(path)
 if path.is_symlink():raise ValueError('Link inesperado; preserve e revise: '+str(path))
 path.parent.mkdir(parents=True,exist_ok=True)
 fd,tmp=tempfile.mkstemp(prefix=path.name+'.',suffix='.tmp',dir=path.parent)
 try:
  with os.fdopen(fd,'wb')as stream:stream.write(raw);stream.flush();os.fsync(stream.fileno())
  os.replace(tmp,path)
 finally:
  if os.path.exists(tmp):os.unlink(tmp)

class Media:
 def __init__(self,state,folder):self.state=Path(state);self.folder=Path(folder)
 def digest(self,kind):
  file=self.folder/FILES[kind]
  return sha(file.read_bytes())if file.is_file()and not file.is_symlink()else None
 def receipt(self,kind):
  path=self.state/('midia_'+kind+'.json')
  if path.is_symlink():raise ValueError('Recibo de midia e um link inesperado.')
  try:r=json.loads(path.read_text())
  except FileNotFoundError:r=None
  if r is not None:
   if not isinstance(r,dict)or not positive(r.get('assetId'))or not re.fullmatch(r'[0-9a-f]{64}',str(r.get('sha256',''))):
    raise ValueError('Recibo de midia invalido; preserve e revise: '+path.name)
   return r
  if kind=='audio':
   # Exact original receipt format: no configuration/key file is read.
   try:
    asset=(self.state/'audio_id').read_text().strip();digest=(self.state/'audio_sha').read_text().strip()
   except FileNotFoundError:return None
   if positive(asset)and re.fullmatch(r'[0-9a-f]{64}',digest):return {'assetId':asset,'sha256':digest}
  return None
 def id(self,kind):
  r=self.receipt(kind)
  return str(r['assetId'])if r and r['sha256']==self.digest(kind)else ''
 def record(self,kind,asset,digest):
  if not positive(asset)or not re.fullmatch(r'[0-9a-f]{64}',digest):raise ValueError('Recibo de upload invalido.')
  if digest!=self.digest(kind):raise ValueError('A midia mudou durante o envio; recibo nao foi associado ao arquivo novo.')
  r={'assetId':str(asset),'sha256':digest}
  atomic(self.state/('midia_'+kind+'.json'),(json.dumps(r,sort_keys=True)+'\n').encode())
 def baseline(self):
  path=self.folder/'IdeiasSemLimites_V3.rbxlx'
  if path.is_symlink():raise ValueError('Arquivo base e um link inesperado.')
  raw=path.read_bytes();config_source(raw)
  sums=self.folder/'SHA256SUMS'
  expected={}
  for line in sums.read_text().splitlines():
   digest,name=line.split(maxsplit=1);expected[name.lstrip('*')]=digest
  for name in ['IdeiasSemLimites_V3.rbxlx']+list(FILES.values()):
   if name not in expected or sha((self.folder/name).read_bytes())!=expected[name]:raise ValueError('Download incompleto ou alterado: '+name+'. Rode baixar.')
  return raw
 def migrate(self):
  # Old images had no receipts: recover only a matching Config and files older
  # than the generated final. Never infer a new image ID from a changed PNG.
  base=self.folder/'IdeiasSemLimites_V3.rbxlx';final=self.folder/'IdeiasSemLimites_V3_final.rbxlx'
  if not base.is_file()or not final.is_file()or base.is_symlink()or final.is_symlink():return
  try:a=config_source(base.read_bytes());b=config_source(final.read_bytes())
  except(ET.ParseError,ValueError):return
  for kind in MARKERS:
   a=pattern(kind).sub(lambda m:m[1]+'0'+m[3],a)
   b=pattern(kind).sub(lambda m:m[1]+'0'+m[3],b)
  if a!=b:return
  old=config_source(final.read_bytes())
  for kind in ('logo','icons'):
   if self.receipt(kind):continue
   file=self.folder/FILES[kind]
   if not file.is_file()or file.is_symlink()or file.stat().st_mtime_ns>final.stat().st_mtime_ns:continue
   asset=pattern(kind).search(old)[2]
   if positive(asset):self.record(kind,asset,self.digest(kind))
 def prepare(self):
  raw=self.baseline();text=raw.decode('utf-8')
  for kind in MARKERS:
   p=pattern(kind)
   if len(p.findall(text))!=1:raise ValueError('Marcador global duplicado: '+kind)
   text=p.sub(lambda m:m[1]+(self.id(kind)or'0')+m[3],text)
  out=text.encode();config_source(out)
  return out
 def compose(self):
  out=self.prepare()
  for name in ('IdeiasSemLimites_V3_final.rbxlx','IdeiasSemLimites_V3_sons.rbxlx'):
   path=self.folder/name
   if path.exists()and not path.is_symlink():
    previous=path.read_bytes()
    if previous!=out:
     backup=self.folder/'historico-midias'/(path.stem+'_'+sha(previous)[:16]+'.rbxlx')
     if not backup.exists():atomic(backup,previous)
   atomic(path,out)
  return self.folder/'IdeiasSemLimites_V3_final.rbxlx'

def main():
 p=argparse.ArgumentParser();p.add_argument('--state',required=True);p.add_argument('--folder',required=True)
 p.add_argument('command',choices=('migrar','validar','compor','id','registrar'));p.add_argument('values',nargs='*')
 a=p.parse_args();media=Media(a.state,a.folder)
 if a.command=='migrar':media.migrate()
 elif a.command=='validar':media.prepare()
 elif a.command=='compor':print(media.compose())
 else:
  if not a.values or a.values[0]not in FILES:raise ValueError('Tipo de midia invalido.')
  if a.command=='id':print(media.id(a.values[0]))
  else:
   if len(a.values)!=3:raise ValueError('Recibo incompleto.')
   media.record(*a.values)

if __name__=='__main__':
 try:main()
 except(Exception,)as error:print('ERRO: '+str(error),file=sys.stderr);sys.exit(1)
