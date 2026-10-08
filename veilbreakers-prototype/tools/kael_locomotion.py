#!/usr/bin/env python3
"""Rebuild v1.7 Kael locomotion PNGs from archived imagegen source sheets.

No animation is synthesized, mirrored or reused between walk and run. Pillow
only cuts/resamples/aligns the supplied generated artwork. Source images remain
unchanged. Connected components prevent a cape crossing a nominal source grid
line from leaking into its neighbour's frame.
"""
from pathlib import Path
import hashlib
import json
import shutil
import argparse

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, find_objects, binary_dilation

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "app/src/main/assets"
ARCHIVE = ASSETS / "project_archive/source_sheets/v17"
PREVIEWS = ASSETS / "project_archive/previews/v17"
RUNTIME = ASSETS / "kael_v17"
DIRECTIONS = ["down", "up", "left", "right"]
GENERATED = {
    "idle": "/workspace/generated_images/exec-2d38bb58-c461-4df4-8b89-2ebda58807b9.png",
    "run": "/workspace/generated_images/exec-da5f1669-1ebf-413e-840c-fe839fb275c5.png",
    "walk_down": "/workspace/generated_images/exec-751f472a-3256-47e4-a8a7-5138fc248ad3.png",
    "walk_up": "/workspace/generated_images/exec-4b8689da-f924-4537-bc1a-32645066eeca.png",
    "walk_left": "/workspace/generated_images/exec-0a362fee-bb0f-4d0f-90dd-5355be1b1f26.png",
    "walk_right": "/workspace/generated_images/exec-66d0cbe1-bdfd-4e8f-bb05-2cd9a56c97fc.png",
}
CORRECTED = {
    "down": "/workspace/generated_images/exec-b318687f-f8ba-4a21-9b34-7f8f145704c4.png",
    "up": "/workspace/generated_images/exec-9e15e470-629e-46ae-861a-ddf53415b552.png",
    "right": "/workspace/generated_images/exec-18825f85-a11b-40df-9fc9-4944ba515b32.png",
}


def walk_source(direction):
    corrected = ARCHIVE / f"kael_walk_{direction}_approved.png"
    return corrected if corrected.exists() else ARCHIVE / f"kael_walk_{direction}_original.png"


def isolated_figures(path, rows, cols):
    im = Image.open(path).convert("RGBA")
    data = np.array(im)
    ids, _ = label(data[:, :, 3] > 20)
    items = []
    for ident, sl in enumerate(find_objects(ids), 1):
        if sl is None or np.count_nonzero(ids[sl] == ident) < 500:
            continue
        y, x = sl
        items.append({"id": ident, "box": [x.start, y.start, x.stop, y.stop]})
    if len(items) != rows * cols:
        raise ValueError(f"{path}: {len(items)} figures, expected {rows * cols}")
    items.sort(key=lambda item: (item["box"][1] + item["box"][3]) / 2)
    ordered = []
    for row in range(rows):
        group = sorted(items[row * cols:(row + 1) * cols], key=lambda item: item["box"][0])
        for item in group:
            ident = item["id"]
            x0, y0, x1, y1 = item["box"]
            # Keep original antialiasing immediately surrounding this figure,
            # excluding every other major figure even when bounding boxes overlap.
            x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
            x1, y1 = min(im.width, x1 + 2), min(im.height, y1 + 2)
            local = data[y0:y1, x0:x1].copy()
            own = binary_dilation(ids[y0:y1, x0:x1] == ident, iterations=2)
            local[:, :, 3][~own] = 0
            local[:, :, 3][local[:, :, 3] <= 3] = 0
            local[:, :, :3][local[:, :, 3] == 0] = 0
            frame = Image.fromarray(local)
            ordered.append((frame, [x0, y0, x1, y1]))
    return ordered


def head_anchor(im, direction, animation):
    """Stable anatomical axis: hair centroid, independent of cape width."""
    alpha = np.array(im.getchannel("A"))
    # The hair/head's central band excludes the sword hilt and cape.
    y0, y1 = round(im.height * .07), round(im.height * .20)
    coords = np.argwhere(alpha[y0:y1] > 80)
    anchor = float(np.median(coords[:, 1]))
    # Profile pelvis lies slightly behind the head. This common correction is
    # shared by every frame; it does not normalize separate frame widths.
    pelvis_offset = .18 if animation == "run" else .035
    if direction == "left":
        anchor += im.height * pelvis_offset
    elif direction == "right":
        anchor -= im.height * pelvis_offset
    return anchor


def contact(frames, cols, label_text):
    canvas = Image.new("RGB", (cols * 256, 4 * 286 + 34), (24, 25, 32))
    draw = ImageDraw.Draw(canvas)
    draw.text((10, 9), label_text + " | pivot 128,232 | cells 256 x 256", fill=(215, 210, 205))
    for row, direction in enumerate(DIRECTIONS):
        for col in range(cols):
            x, y = col * 256, 34 + row * 286
            draw.rectangle((x, y, x + 255, y + 255), outline=(64, 54, 61))
            draw.line((x + 8, y + 232, x + 248, y + 232), fill=(71, 44, 47))
            canvas.paste(frames[row * cols + col], (x, y), frames[row * cols + col])
            draw.ellipse((x + 126, y + 230, x + 130, y + 234), outline=(220, 84, 96))
            draw.text((x + 9, y + 261), f"{direction} {col}", fill=(210, 210, 210))
    return canvas


def gif_preview(frames, cols, fps, path):
    states = []
    for index in range(cols):
        canvas = Image.new("RGB", (4 * 256, 276), (26, 28, 35))
        draw = ImageDraw.Draw(canvas)
        for row, direction in enumerate(DIRECTIONS):
            frame = frames[row * cols + index]
            canvas.paste(frame, (row * 256, 0), frame)
            draw.line((row * 256 + 12, 232, row * 256 + 244, 232), fill=(73, 45, 48))
            draw.text((row * 256 + 12, 258), direction, fill=(200, 200, 200))
        states.append(canvas)
    states[0].save(path, save_all=True, append_images=states[1:], loop=0,
                   duration=round(1000 / fps), disposal=2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture-generated", action="store_true", help="Archive initial imagegen outputs")
    args = parser.parse_args()
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    if args.capture_generated:
        for key, source in GENERATED.items():
            name = f"kael_{key}_original.png"
            shutil.copy2(source, ARCHIVE / name)
        for direction, source in CORRECTED.items():
            shutil.copy2(source, ARCHIVE / f"kael_walk_{direction}_approved.png")
    manifest = {
        "version": "1.7.0", "character": "Kael Varyn",
        "authoritativeModel": "project_archive/source_sheets/v17/kael_model_sheet.png",
        "cellWidth": 256, "cellHeight": 256, "pivotX": 128, "pivotY": 232,
        "baseline": 232, "neutralBodyHeight": 174,
        "order": "Rows Down, Up, Left, Right; columns chronological left to right",
        "processing": "Original generated poses; component-isolated automatic crop; one shared scale per directional sequence; stable head/pelvis axis; true alpha",
        "animations": [],
    }
    all_frames = {}
    for animation, count, fps in [("idle", 4, 5), ("walk", 6, 9), ("run", 6, 12)]:
        if animation == "walk":
            source_groups = [isolated_figures(walk_source(direction), 1, 6)
                             for direction in DIRECTIONS]
        else:
            sliced = isolated_figures(ARCHIVE / f"kael_{animation}_original.png", 4, count)
            source_groups = [sliced[row * count:(row + 1) * count] for row in range(4)]
        runtime_frames = []
        source_sheet = Image.new("RGBA", (count * 256, 4 * 256))
        (RUNTIME / animation).mkdir(parents=True, exist_ok=True)
        for row, (direction, group) in enumerate(zip(DIRECTIONS, source_groups)):
            median_height = float(np.median([frame.height for frame, _ in group]))
            # One shared factor for all frames of this sequence. Natural pose
            # changes therefore retain their breathing, compression and flight.
            scale = 174.0 / median_height
            entries = []
            for index, (source, box) in enumerate(group):
                anchor_x = head_anchor(source, direction, animation)
                width, height = round(source.width * scale), round(source.height * scale)
                resized = source.resize((width, height), Image.Resampling.LANCZOS)
                canvas = Image.new("RGBA", (256, 256))
                # Flight frames rise above the grounded baseline, rather than
                # stretching the sprite down to the floor at every frame.
                flight = 4 if animation == "run" and index in (2, 5) else 0
                left = round(128 - anchor_x * scale)
                top = 232 - flight - height
                if left < 2 or left + width > 254 or top < 2:
                    raise ValueError(f"{animation}/{direction}_{index}: insufficient padding {(left, top, width, height)}")
                canvas.alpha_composite(resized, (left, top))
                alpha = canvas.getchannel("A")
                assert alpha.getbbox() is not None
                assert not alpha.crop((0, 0, 256, 1)).getbbox()
                assert not alpha.crop((0, 255, 256, 256)).getbbox()
                assert not alpha.crop((0, 0, 1, 256)).getbbox()
                assert not alpha.crop((255, 0, 256, 256)).getbbox()
                relative = f"kael_v17/{animation}/{direction}_{index}.png"
                canvas.save(ASSETS / relative, optimize=True)
                source_sheet.alpha_composite(canvas, (index * 256, row * 256))
                runtime_frames.append(canvas)
                entries.append({"index": index, "file": relative, "sourceCrop": box,
                                "sourceAnchorX": round(anchor_x, 3), "scale": round(scale, 8),
                                "sourceFile": walk_source(direction).name if animation == "walk" else f"kael_{animation}_original.png",
                                "baseline": 232 - flight, "sha256": hashlib.sha256(canvas.tobytes()).hexdigest()})
            manifest["animations"].append({"name": animation, "direction": direction,
                    "frameCount": count, "fps": fps, "cellWidth": 256, "cellHeight": 256,
                    "pivotX": 128, "pivotY": 232, "hitFrame": None,
                    "recommendedGroundSpeed": 118 if animation == "walk" else 178 if animation == "run" else 0,
                    "frames": entries})
        # Complete normalized master sheets are equal-cell, padded and can be
        # re-sliced directly. Raw original images are archived alongside them.
        source_sheet.save(ARCHIVE / f"kael_{animation}_source.png", optimize=True)
        contact(runtime_frames, count, f"Kael {animation.upper()} {fps} FPS").save(PREVIEWS / f"kael_{animation}_contact.png")
        gif_preview(runtime_frames, count, fps, PREVIEWS / f"kael_{animation}_preview.gif")
        all_frames[animation] = runtime_frames
    assert set(hashlib.sha256(im.tobytes()).hexdigest() for im in all_frames["walk"]).isdisjoint(
           set(hashlib.sha256(im.tobytes()).hexdigest() for im in all_frames["run"]))
    (ARCHIVE / "kael_locomotion_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    shutil.copy2(ARCHIVE / "kael_locomotion_manifest.json", RUNTIME / "locomotion_manifest.json")
    comparison = Image.new("RGB", (520, 4 * 290 + 32), (23, 24, 31))
    draw = ImageDraw.Draw(comparison)
    draw.text((12, 10), "v1.6.1 / antes", fill=(220, 210, 210))
    draw.text((272, 10), "v1.7.0 / novo modelo", fill=(220, 210, 210))
    pairs = [
        ("idle Down", "kael/move/move_r0_f0.png", "kael_v17/idle/down_0.png"),
        ("idle Up", "kael/move/move_r1_f0.png", "kael_v17/idle/up_0.png"),
        ("walk Left", "kael_v14/side/walk_left_0.png", "kael_v17/walk/left_0.png"),
        ("run Right", "kael_v14/side/run_right_0.png", "kael_v17/run/right_0.png"),
    ]
    for row, (caption, old, new) in enumerate(pairs):
        y = 32 + row * 290
        for column, path in enumerate([old, new]):
            source = Image.open(ASSETS / path).convert("RGBA")
            bbox = source.getchannel("A").point(lambda value: 255 if value > 20 else 0).getbbox()
            cropped = source.crop(bbox)
            factor = 174 / cropped.height
            cropped = cropped.resize((round(cropped.width * factor), 174), Image.Resampling.LANCZOS)
            x = column * 260 + (260 - cropped.width) // 2
            comparison.paste(cropped, (x, y + 56), cropped)
            draw.text((column * 260 + 12, y + 258), caption, fill=(210, 210, 210))
    comparison.save(PREVIEWS / "kael_locomotion_before_after.png")
    print("64 locomotion PNGs, 3 equal-cell source sheets, 3 contact sheets and 3 previews written.")


if __name__ == "__main__":
    main()
