#!/usr/bin/env python3
"""Integrate the generated v1.8 running sheet without synthesizing character art.

Pillow only isolates the supplied 4x6 cells, scales each directional sequence
with one shared factor, anchors it, and creates review and package artifacts.
The v17 Base64 package and its 156 unchanged runtime frames remain untouched.
"""
from pathlib import Path
from array import array
import argparse
import base64
import hashlib
import json
import statistics
import zipfile

from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
ARCHIVE = ASSETS / "project_archive/source_sheets/v18"
PREVIEWS = ASSETS / "project_archive/previews/v18"
DIRECTIONS = ("down", "up", "left", "right")
PHASES = ("contact_A", "compression_A", "flight_A", "contact_B", "compression_B", "flight_B")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def isolated_figures(sheet, rows=4, columns=6):
    """Keep alpha-connected figures even when generated gutters vary slightly.

    Only isolation/cropping occurs. Original pixels and alpha antialiasing are
    retained around the chosen component; another cell can never leak in.
    """
    width, height = sheet.size
    alpha = sheet.getchannel("A").tobytes()
    labels = array("H", [0]) * (width * height)
    figures = []
    ident = 0
    for seed, value in enumerate(alpha):
        if value <= 20 or labels[seed]:
            continue
        ident += 1
        if ident >= 65535:
            raise ValueError("Too many alpha fragments in source sheet")
        todo = [seed]
        labels[seed] = ident
        count = 0
        x0, y0, x1, y1 = width, height, 0, 0
        while todo:
            pos = todo.pop()
            y, x = divmod(pos, width)
            count += 1
            x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            neighbours = (pos - 1 if x else -1, pos + 1 if x + 1 < width else -1,
                          pos - width if y else -1, pos + width if y + 1 < height else -1)
            for neighbour in neighbours:
                if neighbour >= 0 and alpha[neighbour] > 20 and not labels[neighbour]:
                    labels[neighbour] = ident
                    todo.append(neighbour)
        if count >= 500:
            figures.append({"id": ident, "box": [x0, y0, x1 + 1, y1 + 1]})
    if len(figures) != rows * columns:
        raise ValueError(f"Source has {len(figures)} separate figures, expected exactly {rows * columns}")
    figures.sort(key=lambda item: (item["box"][1] + item["box"][3]) / 2)
    ordered = []
    for row in range(rows):
        group = sorted(figures[row * columns:(row + 1) * columns], key=lambda item: item["box"][0])
        for item in group:
            x0, y0, x1, y1 = item["box"]
            if x0 < 2 or y0 < 2 or x1 > width - 2 or y1 > height - 2:
                raise ValueError(f"Source figure touches outer sheet boundary: {item['box']}")
            crop = [x0 - 2, y0 - 2, x1 + 2, y1 + 2]
            figure = sheet.crop(crop)
            own = bytes(255 if labels[y * width + x] == item["id"] else 0
                        for y in range(crop[1], crop[3]) for x in range(crop[0], crop[2]))
            mask = Image.frombytes("L", figure.size, own).filter(ImageFilter.MaxFilter(5))
            figure.putalpha(ImageChops.multiply(figure.getchannel("A"), mask))
            ordered.append((figure, crop))
    return ordered


def anatomical_axis(figure, direction):
    # Hair axis, independent of cape/sword width, with a common profile pelvis
    # offset. No width/bounds rescaling per frame and no bitmap mirroring.
    alpha = figure.getchannel("A")
    xs = []
    for y in range(round(figure.height * .07), max(1, round(figure.height * .20))):
        xs.extend(x for x in range(figure.width) if alpha.getpixel((x, y)) > 80)
    if not xs:
        raise ValueError("Source head band is empty")
    axis = statistics.median(xs)
    if direction == "left":
        axis += figure.height * .14
    elif direction == "right":
        axis -= figure.height * .14
    return axis


def make_previews(frames):
    contact = Image.new("RGB", (1536, 1178), (23, 25, 32))
    draw = ImageDraw.Draw(contact)
    draw.text((10, 10), "Kael RUN v1.8 | A/B alternating contacts | base 12 FPS, distance driven | pivot 128,232", fill=(225, 218, 218))
    master = Image.new("RGBA", (1536, 1024))
    for row, direction in enumerate(DIRECTIONS):
        for index in range(6):
            frame = frames[row * 6 + index]
            master.alpha_composite(frame, (index * 256, row * 256))
            x, y = index * 256, 34 + row * 286
            draw.rectangle((x, y, x + 255, y + 255), outline=(62, 51, 60))
            draw.line((x + 8, y + 232, x + 248, y + 232), fill=(105, 55, 64))
            contact.paste(frame, (x, y), frame)
            draw.ellipse((x + 126, y + 230, x + 130, y + 234), outline=(224, 84, 99))
            draw.text((x + 8, y + 262), f"{direction} {index} {PHASES[index]}", fill=(220, 214, 218))
    contact.save(PREVIEWS / "kael_run_contact.png", optimize=True)
    master.save(ARCHIVE / "kael_run_runtime_sheet.png", optimize=True)
    sequence = []
    for index in range(6):
        canvas = Image.new("RGB", (1024, 280), (23, 25, 32))
        d = ImageDraw.Draw(canvas)
        for row, direction in enumerate(DIRECTIONS):
            canvas.paste(frames[row * 6 + index], (row * 256, 0), frames[row * 6 + index])
            d.line((row * 256 + 8, 232, row * 256 + 248, 232), fill=(105, 55, 64))
            d.text((row * 256 + 8, 260), f"{direction} {PHASES[index]}", fill=(220, 214, 218))
        sequence.append(canvas)
    sequence[0].save(PREVIEWS / "kael_run_preview.gif", save_all=True,
                     append_images=sequence[1:], duration=83, loop=0, disposal=2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ARCHIVE / "kael_run_generated.png")
    parser.add_argument("--opposite-source", type=Path, help="Approved six-pose left/right opposite half-cycle source")
    parser.add_argument("--package", action="store_true", help="Write the versioned v18 overlay Base64 package")
    args = parser.parse_args()
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    raw = Image.open(args.source)
    if raw.mode != "RGBA":
        raise ValueError(f"Generated source must have real RGBA transparency, found {raw.mode}")
    sheet = raw.copy()
    if sheet.getchannel("A").getextrema()[0] != 0:
        raise ValueError("Generated sheet lacks fully transparent pixels")
    isolated = isolated_figures(sheet)
    opposite = None
    if args.opposite_source:
        opposite_sheet = Image.open(args.opposite_source)
        if opposite_sheet.mode != "RGBA" or opposite_sheet.getchannel("A").getextrema()[0] != 0:
            raise ValueError("Opposite half-cycle sheet must retain true RGBA transparency")
        opposite = isolated_figures(opposite_sheet, rows=2, columns=3)
    frames = []
    subset = {"version": "1.8.0", "versionCode": 22, "character": "Kael Varyn",
              "cellWidth": 256, "cellHeight": 256, "pivotX": 128, "pivotY": 232,
              "baseline": 232, "neutralBodyHeight": 174, "frameCount": 24,
              "generationTool": "built-in image_gen.imagegen", "source": args.source.name,
              "sourceSha256": digest(args.source), "sourceSize": list(sheet.size),
              "reference": "kael_model_sheet_reference.png", "baseFPS": 12,
              "runtimeCadence": "Phase advances with actual post-collision ground displacement; nominal 12 FPS",
              "processing": "Crop generated source cells; shared scale per direction; anatomical axis; no character drawing, no mirroring",
              "animations": []}
    if opposite:
        subset["oppositeHalfCycle"] = {"source": args.opposite_source.name,
                                       "sourceSha256": digest(args.opposite_source),
                                       "sourceSize": list(opposite_sheet.size),
                                       "replacement": "left/right frames3,4,5 only; source rowsleft,right",
                                       "scalePolicy": "One shared scale per direction per generated source; 174px median source figure height"}
    for row, direction in enumerate(DIRECTIONS):
        group = isolated[row * 6:(row + 1) * 6]
        scale = 174 / statistics.median(frame.height for frame, _ in group)
        scales = [scale] * 6
        sources = [args.source.name] * 6
        if opposite and row >= 2:
            replacements = opposite[(row - 2) * 3:(row - 1) * 3]
            opposite_scale = 174 / statistics.median(frame.height for frame, _ in replacements)
            group = group[:3] + replacements
            scales[3:] = [opposite_scale] * 3
            sources[3:] = [args.opposite_source.name] * 3
        target = ASSETS / "kael_v18/run"
        target.mkdir(parents=True, exist_ok=True)
        entries = []
        for index, (figure, source_crop) in enumerate(group):
            scale = scales[index]
            axis = anatomical_axis(figure, direction)
            width, height = round(figure.width * scale), round(figure.height * scale)
            resized = figure.resize((width, height), Image.Resampling.LANCZOS)
            flight_lift = 4 if index in (2, 5) else 0
            left, top = round(128 - axis * scale), 232 - flight_lift - height
            if left < 2 or left + width > 254 or top < 2:
                raise ValueError(f"Insufficient padding {direction}/{index}: {(left, top, width, height)}")
            canvas = Image.new("RGBA", (256, 256))
            canvas.alpha_composite(resized, (left, top))
            visible = canvas.getchannel("A").getbbox()
            if not visible or visible[0] < 1 or visible[1] < 1 or visible[2] > 255 or visible[3] > 255:
                raise ValueError(f"Invalid runtime boundary {direction}/{index}: {visible}")
            name = f"kael_v18/run/{direction}_{index}.png"
            path = ASSETS / name
            canvas.save(path, optimize=True)
            entries.append({"index": index, "phase": PHASES[index], "file": name,
                            "sourceFile": sources[index], "sourceCrop": source_crop, "sourceAxisX": round(axis, 3),
                            "scale": round(scale, 8), "flightLiftPixels": flight_lift,
                            "sha256": digest(path), "visibleBounds": list(visible)})
            frames.append(canvas)
        subset["animations"].append({"name": "kael_run", "direction": direction,
                                     "frameCount": 6, "fps": 12, "frames": entries})
    (ARCHIVE / "kael_run_manifest.json").write_text(json.dumps(subset, indent=2) + "\n", encoding="utf-8")
    (ASSETS / "kael_v18/run_manifest.json").write_text(json.dumps(subset, indent=2) + "\n", encoding="utf-8")
    document = json.loads((ROOT / "SPRITES_MANIFEST_V170.json").read_text(encoding="utf-8"))
    document.update(version="1.8.0", versionCode=22, runtimeFrameCount=180,
                    sourceCommit="c25a15c86064d45a7613503aeaddd29f6774591a")
    document["reconstruction"] = "Decode preserved v17_reviewed_art package first, then apply run_v18_assets overlay for the exact 180-frame hybrid"
    document["reconstructionScripts"] = sorted(set(document["reconstructionScripts"] + ["prepare_run_v18.py"]))
    document["runningOverlay"] = {"source": "project_archive/source_sheets/v18/kael_run_generated.png",
                                  "preview": "project_archive/previews/v18/kael_run_contact.png",
                                  "manifest": "kael_v18/run_manifest.json",
                                  "generationTool": "built-in image_gen.imagegen",
                                  "frameCount": 24, "contract": "6 alternating A/B phases in four directions; base 12 FPS, ground-distance cadence"}
    replaced = 0
    for animation in document["animations"]:
        if animation["name"] != "kael_run":
            continue
        animation["fps"] = animation["recommendedFPS"] = 12
        animation["runtimeCadence"] = "distance-driven; nominal 12 FPS"
        for frame in animation["frames"]:
            frame["file"] = frame["file"].replace("kael_v17/run/", "kael_v18/run/")
            frame["phase"] = PHASES[frame["index"]]
            frame["sha256"] = digest(ASSETS / frame["file"])
            replaced += 1
    assert replaced == 24 and sum(a["frameCount"] for a in document["animations"]) == 180
    manifest_text = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    (ROOT / "SPRITES_MANIFEST_V180.json").write_text(manifest_text, encoding="utf-8")
    (ASSETS / "project_archive/SPRITES_MANIFEST_V180.json").write_text(manifest_text, encoding="utf-8")
    make_previews(frames)
    if args.package:
        # Only the new paths and main v180 manifest are packaged. Existing v17
        # chunks stay byte-for-byte historical and are decoded before this.
        files = []
        for prefix in ("kael_v18", "project_archive/source_sheets/v18", "project_archive/previews/v18"):
            files.extend(p for p in (ASSETS / prefix).rglob("*") if p.is_file())
        files.append(ASSETS / "project_archive/SPRITES_MANIFEST_V180.json")
        review = ROOT / "RUN_REVIEW_V180.md"
        if review.exists():
            archived_review = ASSETS / "project_archive/RUN_REVIEW_V180.md"
            archived_review.write_bytes(review.read_bytes())
            files.append(archived_review)
        archive = ROOT / "RUN_v1.8.0_Assets.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for path in sorted(set(files)):
                info = zipfile.ZipInfo(path.relative_to(ASSETS).as_posix(), (2026, 10, 8, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o600 << 16
                z.writestr(info, path.read_bytes())
        encoded = base64.b64encode(archive.read_bytes())
        parts = ASSETS.parent / "assets_b64"
        # Remove only stale parts produced by this task's own v18 overlay.
        for stale in parts.glob("run_v18_assets.zip.b64.part-*"):
            stale.unlink()
        for index, start in enumerate(range(0, len(encoded), 900000)):
            (parts / f"run_v18_assets.zip.b64.part-{index:03d}").write_bytes(encoded[start:start + 900000])
        print(json.dumps({"runtimeFrames": 24, "totalManifestFrames": 180, "overlayFiles": len(files),
                          "zipBytes": archive.stat().st_size, "zipSha256": digest(archive),
                          "base64Parts": (len(encoded) + 899999) // 900000}))
    else:
        print("Prepared 24 run frames, source/master/preview/subset and hybrid v180 manifest")


if __name__ == "__main__":
    main()
