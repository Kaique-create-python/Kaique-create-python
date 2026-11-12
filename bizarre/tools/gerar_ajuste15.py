#!/usr/bin/env python3
"""AJ15 source patch over the verified AJ14, without reconstructing the Place."""
import argparse,json
from pathlib import Path
import gerar_ajuste14 as core
from installer14.package import Package
from installer14.codec import Failure
ROOT=Path(__file__).resolve().parents[1]
def collect():
 baseline=json.loads((ROOT/'installer14/baseline14.json').read_text())['sources']
 rows=[];present=set()
 for path in sorted((ROOT/'src').rglob('*.luau')):
  rel=path.relative_to(ROOT/'src');key=str(rel);present.add(key);gamepath,cls=core.identity(rel)
  before=baseline.get(key)
  if before is None and cls!='ModuleScript':raise Failure('Somente novos modulos reconhecidos sao permitidos: '+key)
  rows.append(dict(path=gamepath,cls=cls,source=path.read_text(),known=[before]if before else[],add=before is None))
 if not set(baseline)<=present:raise Failure('Source14 removida; original preservado.')
 files={'sources.json':json.dumps(rows,ensure_ascii=False,separators=(',',':')).encode(),'package.json':b'{"stage":15}'}
 for key,file in {'catalogo.rbxm':'assets/vfx14/catalogo.rbxm','catalogo.rbxmx':'assets/vfx14/catalogo.rbxmx','catalogo15.rbxm':'assets/vfx15/catalogo.rbxm','catalogo15.rbxmx':'assets/vfx15/catalogo.rbxmx','teste_nuvem14.luau':'tools/teste_nuvem14.luau'}.items():files[key]=(ROOT/file).read_bytes()
 files['manifest.json']=json.dumps({k:core.sha(v)for k,v in sorted(files.items())},sort_keys=True).encode()
 Package(files).scripts(36)
 return files
def build(output=None):return core.build(output or ROOT/'dist/BIZARRE_AJUSTE15.py',files=collect())
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);args=p.parse_args(argv);return build(args.output)
if __name__=='__main__':main()
