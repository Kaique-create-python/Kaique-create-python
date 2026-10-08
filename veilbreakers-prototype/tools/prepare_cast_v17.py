#!/usr/bin/env python3
"""Extract the generated four-direction cast with measured bands and foot pivots.

This is technical sprite preparation, not painting: no body parts or VFX are
redrawn. The unchanged image_gen source is kept next to the canonical atlas.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
ARCHIVE = ASSETS / "project_archive/source_sheets/v17"
SOURCE = ARCHIVE / "kael_cast_source.png"
OUT = ASSETS / "kael_v17/cast"
PREVIEW = ASSETS / "project_archive/previews/v17"
DIRECTIONS = ["down", "up", "left", "right"]
PHASES = ["preparation", "concentration", "formation", "release", "recovery"]
DURATIONS = [90, 90, 100, 100, 120]
XS = [0, 280, 560, 840, 1120, 1402]
# An equal-row split would include preceding boots in some cells. These bands
# have been inspected against the source's actual transparent inter-row gaps.
BANDS = [(60, 312), (315, 576), (588, 828), (836, 1070)]
FEET = [[(144.5, 299), (418, 299), (701, 299), (976, 299), (1263, 299)],
        [(149, 567), (427.5, 567), (706, 566), (979.5, 567), (1263, 567)],
        [(135, 817), (424, 817), (698.5, 817), (973.5, 816), (1258, 817)],
        [(158, 1053), (433.5, 1053), (715, 1053), (990, 1053), (1281, 1054)]]
# Source pixels: glove palm/core centre, not effect bounds. Neutral UP palms are
# covered by the cape and are approximate; all three active poses are visible.
SOCKETS = [[(195, 225), (475, 166), (727, 179), (1017, 230), (1313, 225)],
           [(198, 466), (484, 410), (764, 358), (1020, 368), (1320, 466)],
           [(112, 744), (385, 674), (626, 670), (912, 679), (1230, 744)],
           [(199, 978), (480, 927), (787, 914), (1066, 925), (1322, 978)]]
SCALE = 0.78
CELL = 256
PIVOT = (128, 232)


def socket_output(socket, foot):
    return [round(128 + (socket[0] - foot[0]) * SCALE, 2),
            round(232 + (socket[1] - foot[1]) * SCALE, 2)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    assert source.size == (1402, 1122), "Measured source layout changed; review before extracting"
    sheet = Image.new("RGBA", (5 * CELL, 4 * CELL), (0, 0, 0, 0))
    frames = []
    records = []
    sockets = []
    for row, direction in enumerate(DIRECTIONS):
        direction_frames = []
        direction_sockets = []
        for index, phase in enumerate(PHASES):
            rect = (XS[index], BANDS[row][0], XS[index + 1], BANDS[row][1])
            cell = source.crop(rect)
            cell.putalpha(cell.getchannel("A").point(lambda a: 0 if a < 8 else a))
            foot = FEET[row][index]
            local_foot = (foot[0] - rect[0], foot[1] - rect[1])
            inverse = (1 / SCALE, 0, local_foot[0] - 128 / SCALE,
                       0, 1 / SCALE, local_foot[1] - 232 / SCALE)
            frame = cell.transform((CELL, CELL), Image.Transform.AFFINE, inverse,
                                   Image.Resampling.BICUBIC, fillcolor=(0, 0, 0, 0))
            frame.putalpha(frame.getchannel("A").point(lambda a: 0 if a < 2 else a))
            path = OUT / f"{direction}_{index}.png"
            frame.save(path)
            sheet.paste(frame, (index * CELL, row * CELL))
            bounds = frame.getchannel("A").getbbox()
            assert bounds and bounds[0] >= 8 and bounds[1] >= 8 and bounds[2] <= 248 and bounds[3] <= 242, (direction, index, bounds)
            hand = socket_output(SOCKETS[row][index], foot)
            direction_sockets.append(hand)
            direction_frames.append(frame)
            records.append({
                "animation": "arcana_viii_cast", "direction": direction, "index": index,
                "phase": phase, "file": f"kael_v17/cast/{direction}_{index}.png",
                "cellWidth": CELL, "cellHeight": CELL, "pivotX": 128, "pivotY": 232,
                "baseline": 232, "sourceRect": list(rect), "sourcePivot": list(foot),
                "sourceScale": SCALE, "referenceBodyHeight": 174,
                "handSocketX": hand[0], "handSocketY": hand[1],
                "sourceHandSocket": list(SOCKETS[row][index]),
                "handSocketVisibility": "occluded/approximate" if row == 1 and index in (0, 4) else "visible/measured",
                "durationMs": DURATIONS[index], "hitFrame": index == 3,
                "visibleBounds": list(bounds), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
        frames.append(direction_frames)
        sockets.append(direction_sockets)
    sheet.save(OUT / "magic_cast_sheet.png")
    shutil.copy2(OUT / "magic_cast_sheet.png", ARCHIVE / "kael_cast_runtime_sheet.png")
    manifest = {
        "version": "1.7.0", "animation": "arcana_viii_cast", "frameCountPerDirection": 5,
        "totalFrameCount": 20, "recommendedFPS": 10, "directions": DIRECTIONS,
        "order": list(range(5)), "phases": PHASES, "durationsMs": DURATIONS,
        "durationSeconds": 0.50, "releaseTimeSeconds": 0.28, "hitFrame": 3,
        "cellWidth": CELL, "cellHeight": CELL, "columns": 5, "rows": 4,
        "pivotX": 128, "pivotY": 232, "baseline": 232,
        "scale": "0.78 source pixels, one fixed scale for every cell, no bounds normalization",
        "referenceBodyHeight": 174, "runtimeBodyScale": "playerHeight / 174",
        "source": "project_archive/source_sheets/v17/kael_cast_source.png",
        "sourceDimensions": list(source.size), "manualSourceRowBands": BANDS,
        "canonicalSheet": "kael_v17/cast/magic_cast_sheet.png",
        "castHandSockets": sockets, "frames": records,
        "runtimeSocketTransform": "worldHand=(footX+(socketX-128)*playerScale,footY+(socketY-232)*playerScale)",
        "qa": {
            "generation": "Real image_gen art; selected repaired sheet with DOWN/UP release directed correctly",
            "review": "All 20 cells and all hand sockets visually inspected, no extra limbs or neighbour contamination",
            "layout": "Manual horizontal bands avoid the irregular source sheet row spacing",
            "identity": "Same charcoal hair, face, black/silver plate, torn crimson cloak, sword and boots as model sheet",
            "alpha": "RGBA, no opaque background/checkerboard/white edge; only alpha<8 residue cleared",
            "pivots": "Boot sole centre, excluding cape/sword; especially RIGHT formation/release",
            "bodyScale": "DOWN neutral ~174px; UP ~173px, LEFT ~170px, RIGHT ~168px at one fixed scale",
            "handSockets": "Active poses measured at palm/core; neutral UP palms are occluded and approximate",
        },
    }
    (OUT / "cast_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    shutil.copy2(OUT / "cast_manifest.json", ARCHIVE / "kael_cast_manifest.json")
    contact = Image.new("RGB", (5 * 280, 4 * 294), (24, 21, 27))
    cd = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRECTIONS):
        for index, frame in enumerate(frames[row]):
            x, y = index * 280, row * 294
            cd.rectangle((x, y, x + 279, y + 293), outline=(70, 48, 58))
            cd.text((x + 8, y + 8), f"{direction} {index}: {PHASES[index]} {DURATIONS[index]}ms", fill=(230, 202, 208))
            contact.paste(frame, (x + 12, y + 25), frame)
            cd.line((x + 8, y + 257, x + 271, y + 257), fill=(106, 66, 75))
            cd.line((x + 140, y + 251, x + 140, y + 263), fill=(144, 126, 139))
    contact.save(PREVIEW / "kael_cast_contact.png")
    sockets_preview = contact.copy()
    sd = ImageDraw.Draw(sockets_preview)
    for row in range(4):
        for index in range(5):
            sx, sy = sockets[row][index]
            x, y = index * 280 + 12 + round(sx), row * 294 + 25 + round(sy)
            sd.line((x - 5, y, x + 5, y), fill=(244, 209, 68))
            sd.line((x, y - 5, x, y + 5), fill=(244, 209, 68))
    sockets_preview.save(PREVIEW / "kael_cast_socket_contact.png")
    for row, direction in enumerate(DIRECTIONS):
        frames[row][0].save(PREVIEW / f"kael_cast_{direction}.gif", save_all=True,
                            append_images=frames[row][1:], duration=DURATIONS, loop=0, disposal=2)
    # Canonical-atlas area is the same across old/new rows; never bbox-fit frames.
    old = Image.open(ASSETS / "kael_v16/magic_cast_sheet.png").convert("RGBA")
    comparison = Image.new("RGB", (8 * 256, 4 * 294), (24, 21, 27))
    bd = ImageDraw.Draw(comparison)
    for row, direction in enumerate(DIRECTIONS):
        bd.text((8, row * 294 + 8), f"ANTES {direction}: 3 fases", fill=(230, 202, 208))
        bd.text((3 * 256 + 8, row * 294 + 8), f"DEPOIS {direction}: 5 fases", fill=(230, 202, 208))
        for index in range(3):
            prior = old.crop((round(index * old.width / 3), round(row * old.height / 4),
                              round((index + 1) * old.width / 3), round((row + 1) * old.height / 4)))
            prior = prior.resize((256, 256), Image.Resampling.LANCZOS)
            comparison.paste(prior, (index * 256, row * 294 + 25), prior)
        for index, frame in enumerate(frames[row]):
            comparison.paste(frame, ((index + 3) * 256, row * 294 + 25), frame)
    comparison.save(PREVIEW / "kael_cast_before_after.png")
    hashes = [r["sha256"] for r in records]
    assert len(hashes) == len(set(hashes)), "Duplicated full frames"
    print(json.dumps({"frames": len(records), "out": str(OUT), "castHandSockets": sockets,
                      "bounds": [r["visibleBounds"] for r in records]}))


if __name__ == "__main__":
    main()
