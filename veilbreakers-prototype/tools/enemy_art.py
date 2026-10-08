#!/usr/bin/env python3
"""Reproduce v1.7 Veilborn runtime frames from preserved imagegen originals.

Requires Pillow, NumPy and SciPy. This script only cuts authored art, isolates
adjacent source cells, applies explicitly reviewed constant source scales, and
places frames onto documented canvases. It does not draw or synthesize art.
"""
from pathlib import Path
import json
import shutil

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
SOURCE = ASSETS / "project_archive/source_sheets/v17"
DEST = ASSETS / "enemy_v17"
PREVIEW = ASSETS / "project_archive/previews/v17/veilborn"
ARCHIVE_FRAMES = SOURCE / "veilborn_frames"
DIRECTIONS = ("down", "up", "left", "right")
CELL = 256
PIVOT = (128, 232)

# Pivots are manually reviewed boot-ground origins in ORIGINAL sheet pixels.
# Scales are calibrated once from the neutral body in each source row. They
# remain constant through the whole sequence, including outstretched VFX.
SPECS = [
    dict(name="idle", source="veilborn_idle_original.png", rows=4, cols=3,
         neutral=[304, 303, 296, 302], fps=4,
         anchors=[[(183,351),(545,352),(903,352)],
                  [(185,693),(550,693),(910,693)],
                  [(155,1035),(515,1035),(876,1035)],
                  [(207,1380),(569,1381),(928,1382)]]),
    dict(name="chase", source="veilborn_chase_original.png", rows=4, cols=4,
         neutral=[283,282,265,271], fps=8,
         anchors=[[(165,315),(479,314),(784,318),(1094,318)],
                  [(165,627),(480,627),(789,627),(1100,627)],
                  [(148,912),(455,909),(769,909),(1079,910)],
                  [(215,1201),(522,1201),(831,1199),(1147,1200)]]),
    dict(name="attack", source="veilborn_attack_compact.png", rows=4, cols=4,
         neutral=[251,261,273,272], fps=4/.44, duration=.44, hitFrame=2,
         hitTime=.22,
         anchors=[[(188,293),(492,293),(786,292),(1086,293)],
                  [(184,593),(488,593),(793,593),(1093,593)],
                  [(178,895),(484,895),(789,895),(1094,895)],
                  [(207,1196),(516,1196),(820,1197),(1122,1196)]]),
    dict(name="hurt_death", source="veilborn_hurt_death_original.png", rows=2,
         cols=4, neutral=[341,341], fps=3/.28,
         anchors=[[(245,441),(690,438),(1100,441),(1555,445)],
                  [(241,828),(690,826),(1110,823),(1550,828)]]),
]


def isolate_source_cells(im, count, rows, cols, keep_wisps=False):
    """Assign transparent pixels to the closest authored body alpha component.

    Source generator row placements are not perfectly regular. Major connected
    bodies give safer cell boundaries than cutting through a nominal grid. Alpha
    is preserved exactly; the nearest-body assignment removes neighboring body
    fragments and retains nearby antialiasing, hand trails and death embers.
    """
    pixels = np.array(im.convert("RGBA"))
    alpha = pixels[:, :, 3]
    labels, _ = ndi.label(alpha > 35)
    sizes = np.bincount(labels.ravel())
    primary_ids = np.argsort(sizes[1:])[::-1][:count] + 1
    boxes = ndi.find_objects(labels)
    bodies = []
    for body_id in primary_ids:
        sy, sx = boxes[body_id - 1]
        bodies.append(dict(id=int(body_id), box=[sx.start,sy.start,sx.stop,sy.stop],
                           center=((sx.start+sx.stop)/2,(sy.start+sy.stop)/2)))
    # Cluster by source y order, then x within each row; actual cell dimensions
    # need not be guessed and no figure can be accidentally bisected.
    bodies.sort(key=lambda body: body["center"][1])
    ordered = []
    for row in range(rows):
        ordered.extend(sorted(bodies[row*cols:(row+1)*cols],
                              key=lambda body: body["center"][0]))
    seeds = np.where(np.isin(labels, primary_ids), labels, 0)
    distances, indices = ndi.distance_transform_edt(seeds == 0,
                                                   return_indices=True)
    nearest = seeds[indices[0], indices[1]]
    reach = 90 if keep_wisps else 30
    result = []
    for body in ordered:
        mask = (nearest == body["id"]) & (alpha > 0) & (distances <= reach)
        yy, xx = np.nonzero(mask)
        bounds = [int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
        left, top, right, bottom = bounds
        isolated = pixels[top:bottom, left:right].copy()
        isolated[:, :, 3] = np.where(mask[top:bottom,left:right],
                                    isolated[:, :, 3], 0)
        isolated[isolated[:, :, 3] == 0,:3] = 0
        result.append((Image.fromarray(isolated), bounds, body["box"]))
    return result


def compose(im, bounds, anchor, scale):
    # No per-frame alpha bounding-box normalization: scale stays sequence-wide.
    left, top, _, _ = bounds
    size = (round(im.width*scale), round(im.height*scale))
    resized = im.resize(size, Image.Resampling.LANCZOS)
    offset = (round(PIVOT[0]-(anchor[0]-left)*scale),
              round(PIVOT[1]-(anchor[1]-top)*scale))
    canvas = Image.new("RGBA", (CELL,CELL), (0,0,0,0))
    # Verify the entire visibly authored sprite fits BEFORE pasting. Tiny
    # antialias fringe (< alpha 8) is allowed to touch the crop rectangle only.
    solid = resized.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if solid:
        out = (solid[0]+offset[0],solid[1]+offset[1],
               solid[2]+offset[0],solid[3]+offset[1])
        if min(out[:2]) < 2 or max(out[2:]) > CELL-2:
            raise ValueError(f"Sprite would clip: {out}, anchor={anchor}, scale={scale}")
    canvas.alpha_composite(resized, offset)
    # Guarantee documented clear guard pixels and zero-RGB transparency.
    array = np.array(canvas)
    array[[0,-1],:,3] = 0
    array[:,[0,-1],3] = 0
    array[array[:,:,3] == 0,:3] = 0
    return Image.fromarray(array), offset


def contact(name, paths, columns):
    thumb = 176
    band = 24
    rows = (len(paths)+columns-1)//columns
    out = Image.new("RGB",(columns*thumb,rows*(thumb+band)),"#17141a")
    draw = ImageDraw.Draw(out)
    for index,path in enumerate(paths):
        sprite = Image.open(path).convert("RGBA").resize((thumb,thumb),Image.Resampling.LANCZOS)
        x,y = (index%columns)*thumb,(index//columns)*(thumb+band)
        out.paste(sprite,(x,y),sprite)
        draw.text((x+5,y+thumb+4),path.stem,fill="#e2ccd2")
        draw.line((x,y+round(232*thumb/256),x+thumb,y+round(232*thumb/256)),fill="#4a3038")
    out.save(PREVIEW/f"{name}_contact.png")


def main():
    DEST.mkdir(parents=True,exist_ok=True)
    PREVIEW.mkdir(parents=True,exist_ok=True)
    ARCHIVE_FRAMES.mkdir(parents=True,exist_ok=True)
    records = []
    sequences = []
    for spec in SPECS:
        source = Image.open(SOURCE/spec["source"]).convert("RGBA")
        cells = isolate_source_cells(source,spec["rows"]*spec["cols"],
                                     spec["rows"],spec["cols"],
                                     spec["name"] == "hurt_death")
        paths = []
        for index,(sprite,bounds,body_bounds) in enumerate(cells):
            row,col = divmod(index,spec["cols"])
            anchor = spec["anchors"][row][col]
            scale = 168/spec["neutral"][row]
            if spec["name"] == "hurt_death":
                if index < 3:
                    animation, direction, frame, fps = "hurt", "down", index, 3/.28
                else:
                    animation, direction, frame, fps = "death", "down", index-3, 5/.70
                relative = Path(f"{animation}_{frame}.png")
            else:
                animation,direction,frame,fps = spec["name"],DIRECTIONS[row],col,spec["fps"]
                relative = Path(animation)/f"{direction}_{frame}.png"
            output,offset = compose(sprite,bounds,anchor,scale)
            path = DEST/relative
            path.parent.mkdir(parents=True,exist_ok=True)
            output.save(path,optimize=True)
            archived = ARCHIVE_FRAMES/relative
            archived.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,archived)
            paths.append(path)
            record = dict(file="enemy_v17/"+relative.as_posix(),animation=animation,
                          direction=direction,frameIndex=frame,frameCount=3 if animation in ("idle","hurt") else 5 if animation=="death" else 4,
                          fpsRecommended=round(fps,6),cellWidth=CELL,cellHeight=CELL,
                          pivotX=PIVOT[0],pivotY=PIVOT[1],baseline=232,
                          neutralBodyHeight=168,sourceSheet=spec["source"],
                          sourceCrop=bounds,sourceBodyBounds=body_bounds,
                          sourcePivotX=anchor[0],sourcePivotY=anchor[1],
                          sourceScale=round(scale,9),destinationCropOffset=list(offset),
                          frameOrder="ascending frameIndex",alphaBackground="true transparency")
            if animation == "attack":
                record.update(hitFrame=2,hitTimeSeconds=.22,durationSeconds=.44)
            if animation == "hurt": record.update(durationSeconds=.28)
            if animation == "death": record.update(durationSeconds=.70)
            records.append(record)
        contact(spec["name"],paths,spec["cols"])
        # Reconstruct a regular runtime sheet with the EXACT frames used in APK.
        sheet = Image.new("RGBA",(spec["cols"]*CELL,spec["rows"]*CELL))
        for index,path in enumerate(paths):
            row,col = divmod(index,spec["cols"])
            sheet.alpha_composite(Image.open(path).convert("RGBA"),(col*CELL,row*CELL))
        sheet.save(SOURCE/f"veilborn_{spec['name']}_runtime.png",optimize=True)
    for animation in ("idle","chase","attack","hurt","death"):
        directions = DIRECTIONS if animation in ("idle","chase","attack") else ("down",)
        for direction in directions:
            group = [r for r in records if r["animation"]==animation and r["direction"]==direction]
            sequences.append(dict(animation=animation,direction=direction,
                                  frameCount=len(group),fpsRecommended=group[0]["fpsRecommended"],
                                  frames=[r["file"] for r in group],
                                  hitFrame=2 if animation=="attack" else None))
            backgrounds=[]
            for record in group:
                background=Image.new("RGB",(CELL,CELL),"#17141a")
                sprite=Image.open(ASSETS/record["file"])
                background.paste(sprite,(0,0),sprite)
                backgrounds.append(background)
            backgrounds[0].save(PREVIEW/f"{animation}_{direction}.gif",save_all=True,
                                append_images=backgrounds[1:],loop=0,
                                duration=round(1000/group[0]["fpsRecommended"]),disposal=2)
    manifest=dict(schemaVersion=1,character="Veilborn Wretch",version="1.7.0",
                  authoring="Image generation with visual review; deterministic alpha-aware slicing",
                  frames=records,sequences=sequences,
                  scalePolicy="168px neutral body. Source row calibration constant across all poses; VFX does not change scale.",
                  pivotPolicy="128,232 ground origin. Manual source boot pivots preserved here.",
                  rejectedSheets=[dict(file="veilborn_attack_original.png",reason="Upward VFX nearly touches previous source row; not used."),
                                  dict(file="veilborn_attack_repaired.png",reason="Crouched broad poses did not fit fixed neutral-body scale without clipping; not used.")],
                  replacedAssets=["enemy_v14/idle_front_*.png","enemy_v14/chase_side_*.png",
                                  "enemy_v14/attack_side_*.png","enemy_v14/hurt_front_*.png",
                                  "enemy_v14/death_front_*.png"],
                  validation=dict(frameCount=52,format="RGBA PNG",cellSize=[256,256],
                                  transparentEdgePixels=1,mirroredDirections=False,
                                  sourceCellsVisuallyReviewed=True,runtimeScaleDynamic=False))
    manifest_path=DEST/"SPRITES_MANIFEST_V17.json"
    manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    shutil.copy2(manifest_path,SOURCE/"VEILBORN_MANIFEST_V17.json")
    print(f"Generated {len(records)} validated Veilborn frames; manifest: {manifest_path}")


if __name__ == "__main__":
    main()
