#!/usr/bin/env python3
"""Extract v1.10 scene/rune PNGs from intact archived image_gen sources."""
import json
from pathlib import Path
import shutil
from PIL import Image
from import_v19_art import normalized

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/"app/src/main/assets"
ARCHIVE=ASSETS/"project_archive/source_sheets/v20"
ART=ASSETS/"art_v20"


def main():
    document=json.loads((ARCHIVE/"ENVIRONMENT_PROMPTS.json").read_text())
    selected={}
    for entry in document["prompts"]:
        key=entry["key"]
        target=ARCHIVE/("ENVIRONMENT_"+key+".png")
        source=Path(entry["selectedSource"])
        if not source.is_file(): source=target
        if source.resolve()!=target.resolve(): shutil.copy2(source,target)
        selected[key]=target
    (ART/"scenes").mkdir(parents=True,exist_ok=True)
    for zone in range(6,9): shutil.copy2(selected[f"zone_{zone}"],ART/f"scenes/zone_{zone}.png")
    atlas=Image.open(selected["rune_icons"])
    (ART/"runes").mkdir(parents=True,exist_ok=True)
    for index,name in enumerate(("arcana","ember","frost","mark")):
        row,col=divmod(index,2)
        box=(round(col*atlas.width/2),round(row*atlas.height/2),round((col+1)*atlas.width/2),round((row+1)*atlas.height/2))
        normalized(atlas.crop(box)).save(ART/f"runes/{name}.png")
    print(json.dumps({"importedV20Art":7,"sourcesPreserved":4}))


if __name__=="__main__": main()
