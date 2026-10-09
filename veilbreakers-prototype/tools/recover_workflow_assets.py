#!/usr/bin/env python3
"""Rebuild historical assets, apply v1.7-v1.10 overlays, then refresh context."""
from pathlib import Path
import base64, json, re, shutil, zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / 'app/src/main'
ASSETS = MAIN / 'assets'
B64 = MAIN / 'assets_b64'
ZIPS = ROOT / 'build/recovery-zips'
ZIPS.mkdir(parents=True, exist_ok=True)

def decode(name):
    parts = sorted(B64.glob(name + '.b64.part-*'))
    if not parts:
        raise RuntimeError('Missing encoded group ' + name)
    raw = base64.b64decode(''.join(p.read_text().strip() for p in parts), validate=True)
    (ZIPS / name).write_bytes(raw)
    return raw

for name in ['kael_frames_v03.zip', 'ui_v08.zip', 'v13_assets.zip', 'v14_assets.zip']:
    decode(name)
    with zipfile.ZipFile(ZIPS / name) as z:
        assert z.testzip() is None
        z.extractall(ASSETS)
        print(name, len(z.namelist()), 'files')

raw = decode('menu_background_v08.mp4')
(MAIN / 'res/raw').mkdir(parents=True, exist_ok=True)
(MAIN / 'res/raw/menu_background.mp4').write_bytes(raw)
print('menu video', len(raw), 'bytes')

# Reproduce the workflow's reviewed lateral-combo anchor coordinates.
workflow = (ROOT.parent / '.github/workflows/build-veilbreakers.yml').read_text()
entries = re.findall(r'Name="([^"]+)";\s+X=(\d+);\s+Y=(\d+);\s+W=(\d+);\s+H=(\d+);\s+AX=(\d+);\s+AY=(\d+)', workflow)
source = Image.open(ASSETS / 'project_archive/source_sheets/kael_combo_v14_source.png').convert('RGBA')
dest = ASSETS / 'kael_v14/combo'
dest.mkdir(parents=True, exist_ok=True)
for name, *values in entries:
    x, y, w, h, ax, ay = map(int, values)
    frame = Image.new('RGBA', (700, 240))
    frame.paste(source.crop((x,y,x+w,y+h)), (350-(ax-x), 220-(ay-y)))
    frame.save(dest / name)
assert len(entries) == 18
print('Lateral combos recut:', len(entries))

decode('v15_combo_q256.zip')
with zipfile.ZipFile(ZIPS / 'v15_combo_q256.zip') as z:
    assert z.testzip() is None
    z.extractall(ASSETS)
    print('Vertical combos:', len(z.namelist()))

decode('v161_magic_sheets.zip')
with zipfile.ZipFile(ZIPS / 'v161_magic_sheets.zip') as z:
    assert z.testzip() is None
    for source_name, runtime_name in [('kael_arcana_cast_v161.png','kael_v16/magic_cast_sheet.png'), ('arcana_orb_v161.png','fx_v16/arcana_orb_sheet.png')]:
        p = ASSETS / runtime_name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(z.read(source_name))

archive = ASSETS / 'project_archive'
sheet_dir = archive / 'source_sheets'
sheet_dir.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / 'VEILBREAKERS_CONTEXTO.txt', archive / 'CHAT_CONTEXTO_ATUAL.txt')
(archive / 'BUILD_VERSION.txt').write_text('VEILBREAKERS v1.6.1\n')
# Keep the workflow-authoritative manifest without replacing historical manifests.
match = re.search(r"@'\n\s+(\{\n.*?\n\s+\})\n\s+'@ \| Set-Content \"\$archive/SPRITES_MANIFEST_V161.json\"", workflow, re.S)
assert match
manifest = json.loads(match.group(1))
(archive / 'SPRITES_MANIFEST_V161.json').write_text(json.dumps(manifest, indent=2) + '\n')
vertical_dir = archive / 'v15_vertical_combo_frames'
vertical_dir.mkdir(exist_ok=True)
for path in (ASSETS / 'kael_v15/combo').glob('*.png'):
    shutil.copy2(path, vertical_dir / path.name)
for direction in ['down', 'up']:
    sheet = Image.new('RGBA', (2100,720))
    for stage in range(1,4):
        for pose in range(3):
            image = Image.open(ASSETS / f'kael_v15/combo/{direction}_c{stage}_{pose}.png').convert('RGBA')
            sheet.paste(image, (pose*700,(stage-1)*240))
    sheet.save(sheet_dir / f'kael_combo_{direction}_v15_source.png')
magic_dir = archive / 'v161_arcana_assets'
magic_dir.mkdir(exist_ok=True)
for runtime, source, archived in [('kael_v16/magic_cast_sheet.png', 'kael_arcana_cast_v161_source.png','kael_arcana_cast_v161.png'), ('fx_v16/arcana_orb_sheet.png','arcana_orb_v161_source.png','arcana_orb_v161.png')]:
    shutil.copy2(ASSETS / runtime, sheet_dir / source)
    shutil.copy2(ASSETS / runtime, magic_dir / archived)
for folder, zipname in [(vertical_dir,'v15_vertical_combo_frames.zip'), (magic_dir,'v161_arcana_assets.zip')]:
    with zipfile.ZipFile(archive / zipname, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted(folder.glob('*.png')):
            z.write(p,p.name)
with zipfile.ZipFile(archive / 'v14_source_sheets.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(sheet_dir.glob('*_v14_source.png')):
        z.write(p,p.name)
print('Rebuilt workflow archives and v1.6.1 magic sheets')
if list(B64.glob('v17_reviewed_art.zip.b64.part-*')):
    decode('v17_reviewed_art.zip')
    with zipfile.ZipFile(ZIPS / 'v17_reviewed_art.zip') as z:
        assert z.testzip() is None
        z.extractall(ASSETS)
    print('Applied reviewed v1.7 artwork and historical recovery context')

# The running override and current story must be applied after the archived v1.7
# context; historical recovery archives are intentionally left unchanged.
if list(B64.glob('run_v18_assets.zip.b64.part-*')):
    decode('run_v18_assets.zip')
    with zipfile.ZipFile(ZIPS / 'run_v18_assets.zip') as z:
        assert z.testzip() is None
        z.extractall(ASSETS)
    print('Applied v1.8 authored running override')
if list(B64.glob('v19_assets.zip.b64.part-*')):
    decode('v19_assets.zip')
    with zipfile.ZipFile(ZIPS / 'v19_assets.zip') as z:
        assert z.testzip() is None
        z.extractall(ASSETS)
    print('Applied v1.9 generated world/UI and cast/FX assets')
if list(B64.glob('v20_assets.zip.b64.part-*')):
    decode('v20_assets.zip')
    with zipfile.ZipFile(ZIPS / 'v20_assets.zip') as z:
        assert z.testzip() is None
        z.extractall(ASSETS)
    print('Applied v1.10 generated areas/runes and fire/ice spell FX')
if list(B64.glob('run_v18_assets.zip.b64.part-*')):
    from refresh_release_context import refresh
    refresh(ASSETS)
