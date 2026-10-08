#!/usr/bin/env python3
"""Prepare generated Arcana orb art, without per-frame size normalization.

Source art is preserved unchanged. Only cell extraction, near-zero alpha cleanup,
a documented fixed scale, and translation to the core pivot are applied.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
SOURCE = ASSETS / "project_archive/source_sheets/v17/arcana_orb_source.png"
OUT = ASSETS / "fx_v17"
PREVIEW = ASSETS / "project_archive/previews/v17"
SOURCE_SCALE = 0.25
CELL = 160
PIVOT = (80, 80)
PHASES = ["birth", "formation", "concentration", "launch", "flight", "pulse", "impact", "dissipation"]
# Anchors are measured on the black core, never on the aura bounding box.
# Impact uses the shattered centre, and dissipation retains that same origin.
CORE_ANCHORS = [(222, 235), (225, 230), (220, 229), (293, 230),
                (292, 222), (224, 216), (220, 223), (222, 219)]
DURATIONS = [50, 40, 100, 80, 100, 100, 110, 130]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    sheet = Image.new("RGBA", (4 * CELL, 2 * CELL), (0, 0, 0, 0))
    frames = []
    records = []
    for index, phase in enumerate(PHASES):
        col, row = index % 4, index // 4
        rect = (round(col * source.width / 4), round(row * source.height / 2),
                round((col + 1) * source.width / 4), round((row + 1) * source.height / 2))
        cell = source.crop(rect)
        # Generated sources can contain alpha 1..7 in apparently empty space.
        # They are invisible render residue, not intended VFX.
        cell.putalpha(cell.getchannel("A").point(lambda a: 0 if a < 8 else a))
        anchor = CORE_ANCHORS[index]
        # All cells use one 640px canvas and one 0.25 scale. No bbox fitting.
        canvas = Image.new("RGBA", (640, 640), (0, 0, 0, 0))
        canvas.paste(cell, (320 - anchor[0], 320 - anchor[1]))
        frame = canvas.resize((CELL, CELL), Image.Resampling.LANCZOS)
        # Remove low-alpha resampling residue from truly empty pixels.
        frame.putalpha(frame.getchannel("A").point(lambda a: 0 if a < 2 else a))
        path = OUT / f"orb_{index}.png"
        frame.save(path)
        sheet.paste(frame, (col * CELL, row * CELL))
        bbox = frame.getchannel("A").getbbox()
        assert bbox and bbox[0] >= 6 and bbox[1] >= 6 and bbox[2] <= 154 and bbox[3] <= 154, (phase, bbox)
        assert frame.getpixel((0, 0))[3] == 0
        frames.append(frame)
        records.append({
            "index": index, "phase": phase, "file": f"fx_v17/orb_{index}.png",
            "cellWidth": CELL, "cellHeight": CELL, "pivotX": 80, "pivotY": 80,
            "baseline": 80, "baselineMeaning": "magic effect origin, no foot baseline",
            "sourceRect": list(rect), "sourcePivot": list(anchor), "sourceScale": SOURCE_SCALE,
            "durationMs": DURATIONS[index], "visibleBounds": list(bbox),
            "direction": "right" if phase in ("launch", "flight") else "radial",
            "hitFrame": phase == "impact", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()
        })
    sheet.save(OUT / "arcana_orb_sheet.png")
    shutil.copy2(OUT / "arcana_orb_sheet.png", SOURCE.with_name("arcana_orb_runtime_sheet.png"))
    manifest = {
        "version": "1.7.0", "animation": "arcana_viii_orb", "frameCount": 8,
        "recommendedFPS": 10, "order": list(range(8)), "flightLoop": [4, 5, 4],
        "hitFrame": 6, "cellWidth": CELL, "cellHeight": CELL,
        "columns": 4, "rows": 2, "pivotX": 80, "pivotY": 80,
        "baseline": 80, "scale": "One 0.25 source-pixel scale for every phase; never normalize bounds",
        "source": "project_archive/source_sheets/v17/arcana_orb_source.png",
        "sourceDimensions": list(source.size), "sourceGrid": [4, 2],
        "canonicalSheet": "fx_v17/arcana_orb_sheet.png", "frames": records,
        "runtime": {
            "castFormation": [0, 1, 2], "release": 3, "flight": [4, 5], "impact": [6, 7],
            "castWindowsSeconds": {"birth": [0.09, 0.14], "formation": [0.14, 0.18], "concentration": [0.18, 0.28]},
            "projectileLaunchSeconds": 0.08, "flightFPS": 10,
            "impactSeconds": 0.11, "dissipationSeconds": 0.13,
            "lifeExpiry": "dissipation frame 7 only",
            "canvasHeightFraction": {"charge": 0.090, "flight": 0.105, "impact": 0.140},
            "rotation": "launch and flight point RIGHT (0 radians); rotate about (80,80) to projectile direction",
            "rendering": "translate by core pivot, use a single size for all phases; fade dissipation to zero",
        },
        "qa": {
            "generation": "Real image_gen generation, second attempt selected; original kept unchanged",
            "review": "All eight cells visually inspected; seed/rings/trail/shattered impact/wisps are distinct",
            "alpha": "RGBA. Invisible alpha below 8 cleared before crop; no opaque backdrop or checkerboard",
            "cropping": "No cell-neighbour content; common canvas and scale; all visible bounds have >=6px padding",
            "pivot": "Core anchors measured separately from changing aura; all output pivots are (80,80)",
            "characterChecks": "No characters in this VFX set; face, limbs and clothing checks not applicable",
        },
    }
    (OUT / "orb_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    shutil.copy2(OUT / "orb_manifest.json", SOURCE.with_name("arcana_orb_manifest.json"))
    contact = Image.new("RGB", (4 * 240, 2 * 235), (24, 21, 27))
    draw = ImageDraw.Draw(contact)
    for index, frame in enumerate(frames):
        x, y = index % 4 * 240, index // 4 * 235
        draw.rectangle((x, y, x + 239, y + 234), outline=(75, 49, 59))
        draw.text((x + 10, y + 10), f"{index}: {PHASES[index]} / {DURATIONS[index]} ms", fill=(230, 202, 208))
        # Every preview cell has the exact same 1:1 source sprite display scale.
        contact.paste(frame, (x + 40, y + 38), frame)
        draw.line((x + 113, y + 118, x + 127, y + 118), fill=(108, 109, 129))
        draw.line((x + 120, y + 111, x + 120, y + 125), fill=(108, 109, 129))
        draw.text((x + 12, y + 213), "160x160 / pivot 80,80", fill=(168, 150, 166))
    contact.save(PREVIEW / "arcana_orb_contact.png")
    # Small runtime readability preview has the same global reduction in all cells.
    small = contact.resize((480, 235), Image.Resampling.LANCZOS)
    small.save(PREVIEW / "arcana_orb_small_preview.png")
    frames[0].save(PREVIEW / "arcana_orb_lifecycle.gif", save_all=True,
                   append_images=frames[1:], duration=DURATIONS, loop=0, disposal=2)
    # Both generations use the same 160px display rectangle in this comparison.
    # No frame is fitted to its own bounds.
    original = Image.open(ASSETS / "fx_v16/arcana_orb_sheet.png").convert("RGBA")
    comparison = Image.new("RGB", (8 * 180, 430), (24, 21, 27))
    cd = ImageDraw.Draw(comparison)
    cd.text((8, 6), "ANTES v1.6.1: 6 quadros / area de desenho 160x160", fill=(230, 202, 208))
    cd.text((8, 221), "DEPOIS: 8 fases / 160x160 / escala unica e nucleo ancorado", fill=(230, 202, 208))
    for index in range(6):
        col, row = index % 3, index // 3
        old = original.crop((round(col * original.width / 3), round(row * original.height / 2),
                             round((col + 1) * original.width / 3), round((row + 1) * original.height / 2)))
        old = old.resize((160, 160), Image.Resampling.LANCZOS)
        comparison.paste(old, (index * 180 + 10, 35), old)
        cd.text((index * 180 + 10, 198), f"original {index}", fill=(168, 150, 166))
    for index, frame in enumerate(frames):
        comparison.paste(frame, (index * 180 + 10, 250), frame)
        cd.text((index * 180 + 10, 413), f"{index}: {PHASES[index]}", fill=(168, 150, 166))
    comparison.save(PREVIEW / "arcana_orb_before_after.png")
    print(json.dumps({"frames": len(records), "paths": str(OUT), "bounds": [r["visibleBounds"] for r in records]}))


if __name__ == "__main__":
    main()
