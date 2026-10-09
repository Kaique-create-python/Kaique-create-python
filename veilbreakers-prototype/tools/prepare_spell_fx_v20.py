#!/usr/bin/env python3
"""Isolate supplied generated fire/frost artwork; no effects are synthesized."""
from array import array
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
SOURCE = ASSETS / "project_archive/source_sheets/v20"
PREVIEW = ASSETS / "project_archive/previews/v20"
PHASES = ("birth", "charge_a", "charge_b", "release_shock", "flight_a", "flight_b",
          "flight_c", "flight_d", "impact_flash", "impact_bloom", "impact_fragments", "dissipation")
DURATIONS = (.05, .07, .12, .08, .08, .08, .08, .08, .045, .07, .10, .12)


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def isolate_effects(sheet):
    width, height = sheet.size
    alpha = sheet.getchannel("A").tobytes()
    labels = array("H", [0]) * (width * height)
    components = []
    ident = 0
    for seed, value in enumerate(alpha):
        if value <= 20 or labels[seed]: continue
        ident += 1
        if ident > 65534: raise ValueError("Too many alpha fragments")
        todo = [seed]; labels[seed] = ident
        count = 0; x0, y0, x1, y1 = width, height, 0, 0
        while todo:
            pos = todo.pop(); y, x = divmod(pos, width); count += 1
            x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            for neighbour in (pos - 1 if x else -1, pos + 1 if x + 1 < width else -1,
                              pos - width if y else -1, pos + width if y + 1 < height else -1):
                if neighbour >= 0 and alpha[neighbour] > 20 and not labels[neighbour]:
                    labels[neighbour] = ident; todo.append(neighbour)
        components.append({"id": ident, "count": count, "box": [x0, y0, x1 + 1, y1 + 1]})
    major = sorted(components, key=lambda item: item["count"], reverse=True)[:12]
    if len(major) != 12 or min(item["count"] for item in major) < 1500:
        raise ValueError("Expected twelve substantial independent effects")
    major.sort(key=lambda item: (item["box"][1] + item["box"][3]) / 2)
    ordered = []
    for row in range(3): ordered.extend(sorted(major[row * 4:(row + 1) * 4], key=lambda item: item["box"][0]))
    main_ids = {item["id"] for item in major}
    groups = [{item["id"]} for item in ordered]
    # Detached authored embers/snow flakes belong to the source's own nominal
    # cell. Preserve meaningful particles, excluding single-pixel alpha noise.
    for item in components:
        if item["id"] in main_ids or item["count"] < 25: continue
        x0, y0, x1, y1 = item["box"]
        col = min(3, int((x0 + x1) / 2 / (width / 4)))
        row = min(2, int((y0 + y1) / 2 / (height / 3)))
        if x0 < col * width / 4 + 2 or x1 > (col + 1) * width / 4 - 2: continue
        if y0 < row * height / 3 + 2 or y1 > (row + 1) * height / 3 - 2: continue
        groups[row * 4 + col].add(item["id"])
    results = []
    for index, ids in enumerate(groups):
        selected = [item for item in components if item["id"] in ids]
        crop = [max(0, min(item["box"][0] for item in selected) - 2),
                max(0, min(item["box"][1] for item in selected) - 2),
                min(width, max(item["box"][2] for item in selected) + 2),
                min(height, max(item["box"][3] for item in selected) + 2)]
        figure = sheet.crop(crop)
        mask = bytes(255 if labels[y * width + x] in ids else 0
                     for y in range(crop[1], crop[3]) for x in range(crop[0], crop[2]))
        own = Image.frombytes("L", figure.size, mask).filter(ImageFilter.MaxFilter(5))
        figure.putalpha(ImageChops.multiply(figure.getchannel("A"), own))
        results.append((figure, crop, len(ids)))
    return results


def main():
    SOURCE.mkdir(parents=True, exist_ok=True); PREVIEW.mkdir(parents=True, exist_ok=True)
    origins = json.loads((SOURCE / "spell_fx_origins.json").read_text())
    animations = []; sources = []
    for school in ("fire", "ice"):
        path = SOURCE / f"{school}_generated.png"; sheet = Image.open(path)
        if sheet.mode != "RGBA" or sheet.getchannel("A").getextrema()[0] != 0:
            raise ValueError("Generated sources must retain real RGBA transparency")
        sources.append({"file": str(path.relative_to(ASSETS)), "sha256": sha(path)})
        figures = isolate_effects(sheet); frames = []; preview_frames = []
        contact = Image.new("RGB", (1024, 900), (18, 22, 30)); draw = ImageDraw.Draw(contact)
        master = Image.new("RGBA", (1024, 768))
        shared = origins[school]["scale"]
        for index, (figure, crop, component_count) in enumerate(figures):
            core = origins[school]["cores"][index]
            width, height = round(figure.width * shared), round(figure.height * shared)
            left, top = round(128 - (core[0] - crop[0]) * shared), round(128 - (core[1] - crop[1]) * shared)
            if min(left, top) < 2 or left + width > 254 or top + height > 254:
                raise ValueError(f"Insufficient core-centered padding: {school}/{index} {(left, top, width, height)}")
            canvas = Image.new("RGBA", (256, 256)); canvas.alpha_composite(figure.resize((width, height), Image.Resampling.LANCZOS), (left, top))
            target = ASSETS / f"fx_v20/{school}_{index}.png"; target.parent.mkdir(exist_ok=True)
            canvas.save(target, optimize=True); box = canvas.getchannel("A").getbbox()
            assert min(box[:2]) > 0 and max(box[2:]) < 256
            frames.append({"index": index, "file": str(target.relative_to(ASSETS)), "phase": PHASES[index],
                           "sha256": sha(target), "source": path.name, "sourceCrop": crop,
                           "sourceCorePx": core, "sharedScale": shared, "sourceComponents": component_count,
                           "visibleBounds": list(box)})
            row, col = divmod(index, 4); x, y = col * 256, row * 300
            contact.paste(canvas, (x, y), canvas); draw.text((x + 8, y + 267), f"{school} {index} {PHASES[index]}", fill=(224, 223, 233))
            draw.line((x + 124, y + 128, x + 132, y + 128), fill=(213, 198, 133))
            master.alpha_composite(canvas, (col * 256, row * 256)); preview_frames.append(canvas)
        contact.save(PREVIEW / f"{school}_fx_contact.png", optimize=True)
        master.save(SOURCE / f"{school}_runtime_sheet.png", optimize=True)
        gif = []
        for frame in preview_frames:
            background = Image.new("RGB", (256, 256), (18, 22, 30)); background.paste(frame, (0, 0), frame); gif.append(background)
        gif[0].save(PREVIEW / f"{school}_lifecycle.gif", save_all=True, append_images=gif[1:], loop=0,
                    duration=[round(d * 1000) for d in DURATIONS], disposal=2)
        animations.append({"name": "spell_" + school, "direction": "radial / authored travel right; rotate by facing",
                           "frameCount": 12, "fps": 24, "recommendedFPS": 24, "cellWidth": 256, "cellHeight": 256,
                           "pivotX": 128, "pivotY": 128, "baseline": None, "neutralBodyHeight": None,
                           "scale": "screenHeight*0.18/256 travel; charge0.16; impact0.27",
                           "frameOrder": list(range(12)), "frameDurationsSeconds": list(DURATIONS),
                           "phaseNames": list(PHASES), "frames": frames})
    document = {"version": "1.10.0", "versionCode": 24, "package": "com.veilbreakers.prototype",
                "runtimeFrameCount": 24, "generationTool": "built-in image_gen.imagegen", "sources": sources, "animations": animations}
    encoded = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    (ROOT / "SPELL_FX_MANIFEST_V200.json").write_text(encoded)
    (ASSETS / "project_archive/SPELL_FX_MANIFEST_V200.json").write_text(encoded)
    print(json.dumps({"frames": 24, "schools": ["fire", "ice"], "pivot": [128, 128]}))


if __name__ == "__main__": main()
