#!/usr/bin/env python3
"""Cut generated v19 casting/effect artwork and record authored origins.

No character or effect is drawn procedurally. Component isolation preserves
the selected source pixels; one documented factor per cast direction and one
shared FX factor preserve scale. Stable v17 casting endpoints are copied.
"""
from pathlib import Path
import hashlib
import json
import shutil
import statistics

from PIL import Image, ImageDraw
from prepare_run_v18 import isolated_figures

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
SOURCE = ASSETS / "project_archive/source_sheets/v19"
PREVIEWS = ASSETS / "project_archive/previews/v19"
DIRECTIONS = ("down", "up", "left", "right")
PHASES = ("ready", "chamber", "charge", "release", "follow_through", "settle")
STARTS = (0, .07, .18, .34, .44, .58)
DURATIONS = (.07, .11, .16, .10, .14, .14)
FX_PHASES = ("birth", "gather", "charged", "release_shock", "flight_a", "flight_b",
             "flight_c", "flight_d", "impact_flash", "impact_burst", "impact_ring", "dissipation")
FX_DURATIONS = (.05, .07, .12, .08, .08, .08, .08, .08, .045, .07, .10, .12)
OLD_HANDS = ((167.39, 174.28), (166.22, 153.22), (110.06, 175.06), (159.98, 173.50))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(path, pivot):
    im = Image.open(path)
    alpha = im.getchannel("A")
    box = alpha.getbbox()
    if im.mode != "RGBA" or im.size != (256, 256) or not box or alpha.getextrema()[0] != 0:
        raise ValueError(f"Invalid RGBA256 frame {path}")
    if box[0] < 1 or box[1] < 1 or box[2] > 255 or box[3] > 255:
        raise ValueError(f"No transparent boundary: {path}: {box}")
    return {"sha256": sha(path), "visibleBounds": list(box), "pivotX": pivot[0], "pivotY": pivot[1]}


def write_preview(cast_frames, fx_frames, animations):
    contact = Image.new("RGB", (1536, 1178), (20, 23, 31))
    draw = ImageDraw.Draw(contact)
    draw.text((10, 9), "V19 Kael cast | body174 pivot128,232 | empty gloves + authored hand/orb sockets | .34s release/.72s total", fill=(225, 224, 229))
    master = Image.new("RGBA", (1536, 1024))
    for row, direction in enumerate(DIRECTIONS):
        for phase in range(6):
            frame = cast_frames[row * 6 + phase]
            x, y = phase * 256, 34 + row * 286
            master.alpha_composite(frame, (x, row * 256))
            draw.rectangle((x, y, x + 255, y + 255), outline=(62, 56, 70))
            draw.line((x + 5, y + 232, x + 251, y + 232), fill=(97, 55, 71))
            contact.paste(frame, (x, y), frame)
            socket = animations[row]["frames"][phase]["orbSocketPx"]
            hand = animations[row]["frames"][phase]["handSocketPx"]
            draw.ellipse((x + hand[0] - 3, y + hand[1] - 3, x + hand[0] + 3, y + hand[1] + 3), outline=(62, 190, 255))
            draw.line((x + socket[0] - 5, y + socket[1], x + socket[0] + 5, y + socket[1]), fill=(248, 220, 95))
            draw.line((x + socket[0], y + socket[1] - 5, x + socket[0], y + socket[1] + 5), fill=(248, 220, 95))
            draw.text((x + 8, y + 262), f"{direction} {phase} {PHASES[phase]}", fill=(220, 218, 229))
    contact.save(PREVIEWS / "kael_cast_socket_contact.png", optimize=True)
    master.save(SOURCE / "kael_cast_runtime_sheet.png", optimize=True)
    fx_contact = Image.new("RGB", (1024, 900), (20, 23, 31))
    fx_master = Image.new("RGBA", (1024, 768))
    d = ImageDraw.Draw(fx_contact)
    for index, frame in enumerate(fx_frames):
        row, col = divmod(index, 4)
        x, y = col * 256, row * 300
        fx_contact.paste(frame, (x, y), frame)
        d.line((x + 122, y + 128, x + 134, y + 128), fill=(237, 222, 137))
        d.line((x + 128, y + 122, x + 128, y + 134), fill=(237, 222, 137))
        d.text((x + 10, y + 267), f"{index} {FX_PHASES[index]}", fill=(220, 218, 229))
        fx_master.alpha_composite(frame, (x, row * 256))
    fx_contact.save(PREVIEWS / "arcana_fx_contact.png", optimize=True)
    fx_master.save(SOURCE / "arcana_fx_runtime_sheet.png", optimize=True)
    preview = []
    for phase in range(6):
        canvas = Image.new("RGB", (1024, 280), (20, 23, 31))
        d = ImageDraw.Draw(canvas)
        for direction in range(4):
            canvas.paste(cast_frames[direction * 6 + phase], (direction * 256, 0), cast_frames[direction * 6 + phase])
            d.text((direction * 256 + 8, 260), f"{DIRECTIONS[direction]} {PHASES[phase]}", fill=(220, 218, 229))
        preview.append(canvas)
    preview[0].save(PREVIEWS / "kael_cast_poses.gif", save_all=True, append_images=preview[1:],
                    duration=[round(d * 1000) for d in DURATIONS], loop=0, disposal=2)


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    authored = json.loads((SOURCE / "arcana_authored_origins.json").read_text())
    cast_source = SOURCE / "kael_cast_generated.png"
    fx_source = SOURCE / "arcana_fx_generated.png"
    figures = isolated_figures(Image.open(cast_source), rows=4, columns=4)
    fx_figures = isolated_figures(Image.open(fx_source), rows=3, columns=4)
    animations = []
    cast_frames = []
    for direction_index, direction in enumerate(DIRECTIONS):
        config = authored["casting"][direction]
        row = config["sourceRow"]
        group = figures[row * 4:(row + 1) * 4]
        body_heights = [crop[3] - top for (_, crop), top in zip(group, config["headTopSourceY"])]
        scale = 174 / statistics.median(body_heights)
        frames = []
        for phase in range(6):
            target = ASSETS / f"kael_v19/cast/{direction}_{phase}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            if phase in (0, 5):
                old = ASSETS / f"kael_v17/cast/{direction}_{0 if phase == 0 else 4}.png"
                shutil.copy2(old, target)
                hand = list(OLD_HANDS[direction_index])
                provenance = {"preservedFrom": str(old.relative_to(ASSETS)), "sourceSha256": sha(old)}
            else:
                index = phase - 1
                figure, crop = group[index]
                axis = config["pelvisSourceX"][index] - crop[0]
                width, height = round(figure.width * scale), round(figure.height * scale)
                left, top = round(128 - axis * scale), 232 - height
                if left < 2 or top < 2 or left + width > 254:
                    raise ValueError(f"Cast lacks padding: {direction}/{phase}: {(left, top, width, height)}")
                canvas = Image.new("RGBA", (256, 256))
                canvas.alpha_composite(figure.resize((width, height), Image.Resampling.LANCZOS), (left, top))
                canvas.save(target, optimize=True)
                source_hand = config["handSourcePx"][index]
                hand = [round(left + (source_hand[0] - crop[0]) * scale, 2),
                        round(top + (source_hand[1] - crop[1]) * scale, 2)]
                provenance = {"source": cast_source.name, "sourceRow": row, "sourceColumn": index,
                              "sourceCrop": crop, "sharedDirectionScale": round(scale, 8),
                              "sourceHandPx": source_hand, "pelvisSourceX": config["pelvisSourceX"][index]}
            vector = ((0, 1), (0, -1), (-1, 0), (1, 0))[direction_index]
            socket = [round(hand[0] + vector[0] * 8, 2), round(hand[1] + vector[1] * 8, 2)]
            frame = {"index": phase, "file": str(target.relative_to(ASSETS)), "phase": PHASES[phase],
                     "handSocketPx": hand, "orbSocketPx": socket, "baseline": 232,
                     **provenance, **check(target, (128, 232))}
            frames.append(frame)
            cast_frames.append(Image.open(target).copy())
        animations.append({"name": "kael_arcana_cast", "direction": direction, "frameCount": 6,
                           "fps": round(6 / .72, 6), "recommendedFPS": round(6 / .72, 6),
                           "cellWidth": 256, "cellHeight": 256, "pivotX": 128, "pivotY": 232,
                           "baseline": 232, "neutralBodyHeight": 174, "scale": "screenHeight*0.205/174",
                           "frameOrder": list(range(6)), "frameDurationsSeconds": list(DURATIONS),
                           "phaseStartsSeconds": list(STARTS), "releaseFrame": 3,
                           "releaseTimeSeconds": .34, "durationSeconds": .72, "frames": frames})
    cast_manifest = {"version": "1.9.0", "versionCode": 23, "generationTool": "built-in image_gen.imagegen",
                     "character": "Kael Varyn", "runtimeFrameCount": 24, "animations": animations}
    (ASSETS / "kael_v19/cast_manifest.json").write_text(json.dumps(cast_manifest, indent=2) + "\n")
    fx_frames = []
    fx_records = []
    shared_fx_scale = authored["fx"]["sharedScale"]
    for index, (figure, crop) in enumerate(fx_figures):
        origin = authored["fx"]["coreSourcePx"][index]
        width, height = round(figure.width * shared_fx_scale), round(figure.height * shared_fx_scale)
        left = round(128 - (origin[0] - crop[0]) * shared_fx_scale)
        top = round(128 - (origin[1] - crop[1]) * shared_fx_scale)
        if min(left, top) < 2 or left + width > 254 or top + height > 254:
            raise ValueError(f"Effect lacks padding at authored core {index}: {(left, top, width, height)}")
        canvas = Image.new("RGBA", (256, 256))
        canvas.alpha_composite(figure.resize((width, height), Image.Resampling.LANCZOS), (left, top))
        target = ASSETS / f"fx_v19/arcana_{index}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(target, optimize=True)
        fx_frames.append(canvas)
        fx_records.append({"index": index, "file": str(target.relative_to(ASSETS)), "phase": FX_PHASES[index],
                           "source": fx_source.name, "sourceCrop": crop, "sourceCorePx": origin,
                           "sharedScale": shared_fx_scale, **check(target, (128, 128))})
    fx_animation = {"name": "arcana_orb", "direction": "radial / authored travel right; runtime rotates by facing",
                    "frameCount": 12, "fps": 24, "recommendedFPS": 24, "cellWidth": 256, "cellHeight": 256,
                    "pivotX": 128, "pivotY": 128, "baseline": None, "neutralBodyHeight": None,
                    "scale": "screenHeight*0.18/256 travel; charge0.16; impact0.27",
                    "frameOrder": list(range(12)), "frameDurationsSeconds": list(FX_DURATIONS),
                    "phaseNames": list(FX_PHASES), "impactDurationSeconds": .335, "frames": fx_records}
    subset = {"version": "1.9.0", "versionCode": 23, "package": "com.veilbreakers.prototype",
              "runtimeFrameCount": 36, "generationTool": "built-in image_gen.imagegen",
              "sources": [{"file": str(cast_source.relative_to(ASSETS)), "sha256": sha(cast_source)},
                          {"file": str(fx_source.relative_to(ASSETS)), "sha256": sha(fx_source)}],
              "animations": animations + [fx_animation]}
    subset_text = json.dumps(subset, ensure_ascii=False, indent=2) + "\n"
    (ROOT / "CAST_FX_MANIFEST_V190.json").write_text(subset_text)
    (ASSETS / "project_archive/CAST_FX_MANIFEST_V190.json").write_text(subset_text)
    write_preview(cast_frames, fx_frames, animations)
    print(json.dumps({"castFrames": 24, "effects": 12, "releaseSeconds": .34, "durationSeconds": .72,
                      "manifest": "CAST_FX_MANIFEST_V190.json"}))


if __name__ == "__main__":
    main()
