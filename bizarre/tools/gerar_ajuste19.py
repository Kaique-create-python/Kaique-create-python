#!/usr/bin/env python3
"""AJ19: patch recognized AJ14-AJ18 Sources; keep the complete live Place and media."""
import argparse,json
from pathlib import Path
import gerar_ajuste14 as core
from installer14.package import Package
from installer14.codec import Failure
ROOT=Path(__file__).resolve().parents[1]
def collect():
 bases=[json.loads((ROOT/f'installer14/baseline{v}.json').read_text())['sources']for v in(14,15,16,17,18)]
 rows=[];present=set()
 for path in sorted((ROOT/'src').rglob('*.luau')):
  rel=path.relative_to(ROOT/'src');key=rel.as_posix();present.add(key);gamepath,cls=core.identity(rel)
  known=sorted({base[key]for base in bases if key in base})
  add=key not in bases[0]
  if add and cls!='ModuleScript':raise Failure('Somente novos modulos reconhecidos sao permitidos: '+key)
  rows.append(dict(path=gamepath,cls=cls,source=path.read_text(),known=known,add=add))
 if any(not set(base)<=present for base in bases):raise Failure('Source anterior removida; original preservado.')
 files={'sources.json':json.dumps(rows,ensure_ascii=False,separators=(',',':')).encode(),'package.json':b'{"stage":19}'}
 for key,file in{'catalogo.rbxm':'assets/vfx14/catalogo.rbxm','catalogo.rbxmx':'assets/vfx14/catalogo.rbxmx','catalogo15.rbxm':'assets/vfx15/catalogo.rbxm','catalogo15.rbxmx':'assets/vfx15/catalogo.rbxmx','teste_nuvem14.luau':'tools/teste_nuvem19.luau'}.items():files[key]=(ROOT/file).read_bytes()
 files['manifest.json']=json.dumps({k:core.sha(v)for k,v in sorted(files.items())},sort_keys=True).encode()
 Package(files).scripts(36)
 return files
def build(output=None):return core.build(output or ROOT/'dist/BIZARRE_AJUSTE19.py',files=collect())
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);args=p.parse_args(argv);return build(args.output)
if __name__=='__main__':main()
