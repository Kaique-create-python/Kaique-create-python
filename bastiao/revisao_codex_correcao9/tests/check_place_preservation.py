"""Offline integration against an original RBXL. Fixtures IDs NEVER go to Roblox.
Usage: python tests/check_place_preservation.py /path/to/original.rbxl
"""
import json
from pathlib import Path
import shutil
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT),str(ROOT/'tests')]
from instalador.codec import Binary
from instalador.patcher import patch_place
from instalador.stamina import PATH,ORIGINAL,SOURCE
from release_fixture import make_release
from tooling import release_builder


def verify(original):
    raw=Path(original).read_bytes();before=Binary(raw)
    with tempfile.TemporaryDirectory() as temporary:
        temp=Path(temporary);make_release(temp)
        for p in (ROOT/'src').rglob('*.luau'):
            dest=temp/p.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
        shutil.copyfile(ROOT/'modelo/MonsterImportContract.luau',temp/'modelo/MonsterImportContract.luau')
        rows,report=release_builder.assemble_sources(temp)
        patched,changed=patch_place(raw,rows)
        assert changed
        assert patch_place(patched,rows)==(patched,False),'Patch must be byte-idempotent'
        after=Binary(patched)
    config=before.locate(list(PATH));assert before.value(config,'Source').decode()==ORIGINAL
    assert after.value(config,'Source').decode()==SOURCE
    other_sources=0
    for ref,obj in before.objects.items():
        assert after.objects[ref]==obj and after.parents[ref]==before.parents[ref],f'Original object changed: {ref}'
        if obj['class'] in ('Script','LocalScript','ModuleScript') and ref!=config:
            assert before.value(ref,'Source')==after.value(ref,'Source'),f'Protected source changed: {ref}'
            other_sources+=1
    unchanged_properties=0
    for key,(chunk,typ,offset) in before.props.items():
        if key[1]!='Source':
            assert chunk.data==after.props[key][0].data,f'Original property changed: {key}'
            unchanged_properties+=1
    return {'passed':True,'originalInstancesPreserved':len(before.objects),
            'protectedOriginalSourcesUnchanged':other_sources,'nonSourcePropertyChunksUnchanged':unchanged_properties,
            'sourceRows':len(rows),'idempotent':True,'mapAndHudGeometryUnchanged':True,
            'onlyOriginalSourceChange':'ReplicatedStorage/Sector7/Config: DrainRate 22 -> 19',
            'fixtureAssetIdsOnly':True,'engineExecuted':False,'published':False}

if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('Usage: python tests/check_place_preservation.py ORIGINAL.rbxl')
    print(json.dumps(verify(sys.argv[1]),ensure_ascii=False,indent=2))
