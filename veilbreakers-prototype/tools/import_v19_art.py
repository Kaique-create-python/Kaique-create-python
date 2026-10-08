#!/usr/bin/env python3
"""Import selected generated atlases using authored cells; preserve every source intact.

This extracts runtime assets and normalizes sprite pivots. No visual content is
painted or reconstructed: all imagery comes from the archived image_gen outputs.
"""
import json
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
ARCHIVE = ASSETS / "project_archive/source_sheets/v19"
ART = ASSETS / "art_v19"


def trim(image):
    image = image.convert("RGBA")
    # Ignore nearly transparent compression fringes when finding authored bounds.
    bounds = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0).getbbox()
    if not bounds:
        raise ValueError("Empty authored cell")
    return image.crop(bounds)


def save(image, path):
    target = ART / path
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)


def normalized(image, actor=False):
    visible = trim(image)
    if actor:
        scale = min(174 / visible.height, 225 / visible.width)
        size = tuple(max(1, round(value * scale)) for value in visible.size)
        visible = visible.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (256, 256))
        canvas.alpha_composite(visible, ((256 - visible.width) // 2, 232 - visible.height))
    else:
        scale = min(224 / visible.width, 224 / visible.height)
        visible = visible.resize(tuple(max(1, round(value * scale)) for value in visible.size), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (256, 256))
        canvas.alpha_composite(visible, ((256 - visible.width) // 2, (256 - visible.height) // 2))
    return canvas


def main():
    data = json.loads((ARCHIVE / "ENVIRONMENT_PROMPTS.json").read_text())
    selected = {entry["key"]: Path(entry["selectedSource"]) for entry in data["prompts"] if entry.get("selectedSource")}
    for key, original in selected.items():
        shutil.copy2(original, ARCHIVE / ("ENVIRONMENT_" + key + ".png"))
    for zone in range(6):
        save(Image.open(selected[f"zone_{zone}"]), f"scenes/zone_{zone}.png")
    portraits = Image.open(selected["portraits"])
    for column, name in enumerate(("kael", "mara", "ivo")):
        left = round(column * portraits.width / 3)
        right = round((column + 1) * portraits.width / 3)
        save(trim(portraits.crop((left, 0, right, portraits.height))), f"portraits/{name}.png")
    sprites = Image.open(selected["npc_clean"])
    for row, name in enumerate(("mara", "ivo")):
        for column in range(3):
            cell = sprites.crop((column * 512, row * 512, (column + 1) * 512, (row + 1) * 512))
            save(normalized(cell, actor=True), f"npc/{name}_{column}.png")
    kit = Image.open(selected["ui_kit"])
    for row, column, name in ((0, 0, "status_panel"), (0, 1, "dialogue_frame"),
                              (1, 0, "item_slot"), (1, 1, "button")):
        cell = kit.crop((column * 768, row * 512, (column + 1) * 768, (row + 1) * 512))
        save(trim(cell), f"ui/{name}.png")
    atlas = Image.open(selected["items_props"])
    crops = {
        "items/sword_varyn.png": (0, 0, 512, 341),
        "items/bandage.png": (512, 0, 1024, 341),
        "items/mana_draught.png": (1024, 0, 1536, 341),
        "items/ivo_note.png": (0, 341, 512, 682),
        "props/chest_closed.png": (512, 341, 1024, 682),
        "props/chest_open.png": (1024, 341, 1536, 682),
        "props/sword_ground.png": (0, 682, 550, 1024),
        "props/trace.png": (550, 682, 1070, 1024),
        "props/altar.png": (1070, 682, 1536, 1024),
    }
    for path, box in crops.items():
        save(normalized(atlas.crop(box)), path)
    print(json.dumps({"importedGameArt": len(list(ART.rglob("*.png"))), "sourcesPreserved": len(selected)}))


if __name__ == "__main__":
    main()
