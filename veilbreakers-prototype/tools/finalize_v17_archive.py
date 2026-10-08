#!/usr/bin/env python3
"""Describe the exact runtime contract and package reviewed v1.7 artwork."""
import base64
import hashlib
import json
from pathlib import Path
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'app/src/main/assets'
ARCHIVE = ASSETS / 'project_archive'
DIRS = ['down', 'up', 'left', 'right']

def main():
    animations = []
    def add(name, direction, files, fps, durations=None, hit=None, body=174):
        orb = name == 'arcana_orb'
        width, height = Image.open(ASSETS/files[0]).size
        record = dict(name=name, direction=direction, frameCount=len(files),
                      recommendedFPS=fps, fps=fps, cellWidth=width,
                      cellHeight=height, pivotX=width//2,
                      pivotY=80 if orb else 232, baseline=None if orb else 232,
                      neutralBodyHeight=None if orb else body,
                      scale='screenHeight*0.105/160' if orb else
                            f'screenHeight*{0.190 if body == 168 else 0.205}/{body}',
                      frameOrder=list(range(len(files))),
                      frames=[dict(index=i, file=f, sha256=hashlib.sha256((ASSETS/f).read_bytes()).hexdigest())
                              for i, f in enumerate(files)])
        if durations: record['frameDurationsSeconds'] = durations
        if hit is not None: record['hitFrame'] = hit
        animations.append(record)
    for direction in DIRS:
        for state, count, fps in [('idle',4,5),('walk',6,9),('run',6,12)]:
            add('kael_'+state, direction, [f'kael_v17/{state}/{direction}_{i}.png' for i in range(count)], fps)
        for stage, duration in enumerate([.38,.44,.54],1):
            add(f'kael_combo{stage}',direction,[f'kael_v17/combo/{direction}_c{stage}_{i}.png' for i in range(3)],
                round(3/duration,6),[round(duration*w,6) for w in [.30,.28,.42]],1)
        add('kael_arcana_cast',direction,[f'kael_v17/cast/{direction}_{i}.png' for i in range(5)],10,[.09,.09,.10,.10,.12])
        animations[-1]['releaseFrame'] = 3
        animations[-1]['releaseTimeSeconds'] = .28
        for state,count,fps in [('idle',3,4),('chase',4,8),('attack',4,4/.44)]:
            add('veilborn_'+state,direction,[f'enemy_v17/{state}/{direction}_{i}.png' for i in range(count)],
                round(fps,6),[.11]*4 if state=='attack' else None,2 if state=='attack' else None,168)
    add('veilborn_hurt','down',[f'enemy_v17/hurt_{i}.png' for i in range(3)],round(3/.28,6),[.28/3]*3,body=168)
    add('veilborn_death','down',[f'enemy_v17/death_{i}.png' for i in range(5)],round(5/.70,6),[.14]*5,body=168)
    add('arcana_orb','radial / travel right',[f'fx_v17/orb_{i}.png' for i in range(8)],10,
        [.05,.04,.10,.08,.10,.10,.11,.13])
    animations[-1]['phaseNames']=['birth','formation','concentration','launch','flight','pulse','impact','dissipation']
    manifest = dict(version='1.7.0',versionCode=21,package='com.veilbreakers.prototype',
        sourceRepository='Kaique-create-python/Kaique-create-python',sourceBranch='veilbreakers-apk-build',
        sourceCommit='bc70c03b0ee04e46b4b04abea6726ba9e06ffa9f',runtimeFrameCount=180,
        artMethod='Generated with image_gen; inspected; recut and placed on fixed canvases using recorded source coordinates.',
        characterModel='project_archive/source_sheets/v17/kael_model_sheet.png',
        sourceSheetsDirectory='project_archive/source_sheets/v17',previewsDirectory='project_archive/previews/v17',
        reconstruction='Decode the v17_reviewed_art Base64 package for exact reproduction; cutting scripts record selected sources and authored coordinates.',
        reconstructionScripts=[p.name for p in sorted((ROOT/'tools').glob('*.py'))],
        animations=animations)
    assert sum(a['frameCount'] for a in animations)==180
    (ARCHIVE/'SPRITES_MANIFEST_V170.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ARCHIVE/'BUILD_VERSION.txt').write_text('VEILBREAKERS v1.7.0\nversionCode 21\n',encoding='utf-8')
    (ARCHIVE/'CHAT_CONTEXTO_ATUAL.txt').write_bytes((ROOT/'VEILBREAKERS_CONTEXTO.txt').read_bytes())
    prefixes=['kael_v17','enemy_v17','fx_v17','project_archive/source_sheets/v17',
              'project_archive/previews/v17','project_archive/baseline_v161_audit']
    files=[]
    for prefix in prefixes: files.extend(p for p in (ASSETS/prefix).rglob('*') if p.is_file())
    files.extend(ARCHIVE/x for x in ['SPRITES_MANIFEST_V170.json','BUILD_VERSION.txt','CHAT_CONTEXTO_ATUAL.txt','ART_REVIEW_V170.md'])
    zip_path=ROOT/'VEILBREAKERS_v1.7.0_Arte.zip'
    with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for f in sorted(set(files)): z.write(f,f.relative_to(ASSETS).as_posix())
    b64=base64.b64encode(zip_path.read_bytes()).decode('ascii')
    dest=ROOT/'app/src/main/assets_b64'
    for old in dest.glob('v17_reviewed_art.zip.b64.part-*'): old.unlink()
    for i,start in enumerate(range(0,len(b64),900000)):
        (dest/f'v17_reviewed_art.zip.b64.part-{i:03d}').write_text(b64[start:start+900000],encoding='ascii')
    print(json.dumps(dict(runtimeFrames=180,archiveFiles=len(files),zipBytes=zip_path.stat().st_size,
                          sha256=hashlib.sha256(zip_path.read_bytes()).hexdigest(),base64Parts=(len(b64)+899999)//900000)))

if __name__=='__main__': main()
