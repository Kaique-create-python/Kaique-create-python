#!/usr/bin/env python3
"""Audit alpha, bounds, frame identity and runtime v1.6.1 contact previews."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib, math

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'app/src/main/assets'
OUT = A / 'project_archive/baseline_v161_audit'
OUT.mkdir(parents=True, exist_ok=True)
groups = {}
for row, name, count in [(0,'idle_down',4),(1,'idle_up',4),(2,'idle_left',4),(3,'idle_right',4),(4,'run_down',6),(5,'run_up',6)]:
    groups[name] = [A/f'kael/move/move_r{row}_f{i}.png' for i in range(count)]
for state in ['walk','run']:
    for direction in ['left','right']:
        groups[f'{state}_{direction}'] = [A/f'kael_v14/side/{state}_{direction}_{i}.png' for i in range(6)]
for direction in ['down','up','left','right']:
    version = 'kael_v15' if direction in ['down','up'] else 'kael_v14'
    for stage in range(1,4):
        groups[f'combo_{direction}_c{stage}'] = [A/f'{version}/combo/{direction}_c{stage}_{i}.png' for i in range(3)]
for state,prefix,count in [('enemy_idle','idle_front_',4),('enemy_chase','chase_side_',4),('enemy_attack','attack_side_',4),('enemy_hurt','hurt_front_',2),('enemy_death','death_front_',4)]:
    groups[state] = [A/f'enemy_v14/{prefix}{i}.png' for i in range(count)]

rows = []
preview_data = {}
for name,paths in groups.items():
    images=[]
    for path in paths:
        image = Image.open(path).convert('RGBA')
        alpha=image.getchannel('A')
        bbox=alpha.point(lambda x:255 if x>12 else 0).getbbox()
        rows.append({'path':str(path.relative_to(A)), 'size':list(image.size), 'alphaRange':list(alpha.getextrema()),'visibleBounds':bbox,'rgbaSHA256':hashlib.sha256(image.tobytes()).hexdigest()})
        images.append((path.name,image))
    preview_data[name]=images

for sheetname,path,cols,nrows in [('arcana_cast',A/'kael_v16/magic_cast_sheet.png',3,4),('arcana_orb',A/'fx_v16/arcana_orb_sheet.png',3,2)]:
    sheet=Image.open(path).convert('RGBA')
    w,h=sheet.width//cols,sheet.height//nrows
    images=[]
    for row in range(nrows):
        for col in range(cols):
            image=sheet.crop((col*w,row*h,(col+1)*w,(row+1)*h))
            alpha=image.getchannel('A')
            bbox=alpha.point(lambda x:255 if x>12 else 0).getbbox()
            label=f'{sheetname}_r{row}_f{col}'
            rows.append({'path':str(path.relative_to(A)),'cell':label,'size':[w,h],'alphaRange':list(alpha.getextrema()),'visibleBounds':bbox,'rgbaSHA256':hashlib.sha256(image.tobytes()).hexdigest()})
            images.append((label,image))
    preview_data[sheetname]=images

def contact(name, images, cols=6, cellw=240, cellh=260, fixedheight=150):
    canvas=Image.new('RGB',(cols*cellw, math.ceil(len(images)/cols)*cellh),(21,18,23))
    draw=ImageDraw.Draw(canvas)
    for i,(label,image) in enumerate(images):
        x,y=(i%cols)*cellw,(i//cols)*cellh
        draw.rectangle((x,y,x+cellw-1,y+cellh-1),outline=(70,49,59))
        draw.text((x+8,y+8),label[:33],fill=(225,200,201))
        draw.line((x+4,y+cellh-24,x+cellw-4,y+cellh-24),fill=(103,44,59))
        bbox=image.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox()
        # Use one common scale per atlas category to expose actual frame size drift.
        scale=min((cellw-12)/image.width,(cellh-44)/image.height)
        scaled=image.resize((round(image.width*scale),round(image.height*scale)),Image.Resampling.LANCZOS)
        canvas.paste(scaled,(x+(cellw-scaled.width)//2,y+26+(cellh-44-scaled.height)//2),scaled)
    canvas.save(OUT/f'{name}.jpg',quality=94)

for category, names in [('kael_movement',[n for n in groups if 'combo' not in n and 'enemy' not in n]),('kael_combo',[n for n in groups if 'combo' in n]),('veilborn',[n for n in groups if 'enemy' in n]),('arcana',['arcana_cast','arcana_orb'])]:
    imgs=[]
    for name in names:
        imgs += [(name+' '+label,image) for label,image in preview_data[name]]
    contact(category,imgs)
for name in ['arcana_cast','arcana_orb']:
    contact(name,preview_data[name],cols=3,cellw=360,cellh=330)

# Four canonical idle directions without extrapolating a new design.
contact('kael_reference_existing',[(n,preview_data[n][0][1]) for n in ['idle_down','idle_up','idle_left','idle_right']],cols=4,cellw=280,cellh=340)
duplicates=[]
for a in rows:
    matched=[b.get('cell',b['path']) for b in rows if b is not a and b['rgbaSHA256']==a['rgbaSHA256']]
    if matched:
        duplicates.append({'frame':a.get('cell',a['path']),'duplicates':matched})
(OUT/'baseline_asset_audit.json').write_text(json.dumps({'version':'1.6.1','frames':rows,'exactDuplicates':duplicates},indent=2)+'\n')
print('Audited',len(rows),'runtime sprite frames, duplicate entries',len(duplicates))
print('Previews:',str(OUT))
