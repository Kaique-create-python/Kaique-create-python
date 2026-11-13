#!/usr/bin/env python3
"""Build the source patch installer, never a replacement Place. No network/API calls."""
import argparse,base64,hashlib,io,json,sys,zipfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from installer14.package import Package
from installer14.codec import Failure
from installer14.paths import guard

def sha(raw):return hashlib.sha256(raw).hexdigest()
def identity(relative):
 parts=list(relative.parts);name=parts[-1][:-5];cls='ModuleScript'
 if name.endswith('.server'):name=name[:-7];cls='Script'
 elif name.endswith('.client'):name=name[:-7];cls='LocalScript'
 parts[-1]=name
 if parts[0] in ('StarterPlayerScripts','StarterCharacterScripts'):parts.insert(0,'StarterPlayer')
 return parts,cls

def collect(baseline=None):
 known=json.loads((ROOT/'installer14/baseline13.json').read_bytes())
 if baseline is not None:
  actual={str(p.relative_to(baseline)):sha(p.read_bytes()) for p in sorted(Path(baseline).rglob('*.luau'))}
  if actual!=known['sources']:raise Failure('Baseline nao corresponde ao AJ13 remoto b60be0a8.')
 rows=[];current={}
 for path in sorted((ROOT/'src').rglob('*.luau')):
  rel=path.relative_to(ROOT/'src');key=str(rel);gamepath,cls=identity(rel);raw=path.read_bytes();current[key]=sha(raw)
  old=known['sources'].get(key)
  if old is None and cls!='ModuleScript':raise Failure('Novo script executavel nao autorizado: '+key)
  rows.append(dict(path=gamepath,cls=cls,source=raw.decode('utf8'),known=[old] if old else [],add=old is None))
 if not set(known['sources']).issubset(current):raise Failure('Fonte AJ13 removida; build bloqueado.')
 files={'sources.json':json.dumps(rows,ensure_ascii=False,separators=(',',':')).encode()}
 for name,relative in [('catalogo.rbxm','assets/vfx14/catalogo.rbxm'),('catalogo.rbxmx','assets/vfx14/catalogo.rbxmx'),('teste_nuvem14.luau','tools/teste_nuvem14.luau')]:
  files[name]=(ROOT/relative).read_bytes()
 files['manifest.json']=json.dumps({n:sha(v) for n,v in sorted(files.items())},sort_keys=True).encode()
 package=Package(files);package.scripts(1)
 return files

def build(output=None,baseline=None,files=None):
 files=collect(baseline) if files is None else files;bundle={'payload/'+n:v for n,v in files.items()}
 for path in sorted((ROOT/'installer14').glob('*.py')):bundle['installer14/'+path.name]=path.read_bytes()
 bundle['bundle-manifest.json']=json.dumps({n:sha(v) for n,v in sorted(bundle.items())},sort_keys=True).encode()
 stream=io.BytesIO()
 with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for name,value in sorted(bundle.items()):
   info=zipfile.ZipInfo(name,(2026,11,11,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o600<<16;z.writestr(info,value)
 payload=zlib.compress(stream.getvalue(),9)
 script=(ROOT/'installer14/bootstrap.py.txt').read_text().replace('__PAYLOAD__',repr(base64.b85encode(payload))).replace('__SHA256__',repr(sha(payload)))
 target=guard(output or ROOT/'dist/BIZARRE_AJUSTE14.py');target.parent.mkdir(parents=True,exist_ok=True)
 target.write_text(script);target.chmod(0o600)
 print(str(target)+' | SHA256 '+sha(script.encode())+' | '+str(len(script.encode()))+' bytes')
 return target

def main(argv=None):
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--baseline',type=Path);parser.add_argument('--output',type=Path)
 args=parser.parse_args(argv);return build(args.output,args.baseline)
if __name__=='__main__':main()
