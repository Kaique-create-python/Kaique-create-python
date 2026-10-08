#!/usr/bin/env python3
"""Validate the authored v1.7 runtime frames and produce a reproducible hash report.

This validates technical properties, not anatomical or artistic quality. The
contact sheets and Android captures remain the evidence for visual review.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("down", "up", "left", "right")
MANIFEST = "project_archive/SPRITES_MANIFEST_V170.json"
REPORT = "project_archive/V17_ASSET_QA.json"


def expected_frames():
    result = {}
    for direction in DIRECTIONS:
        for state, count in (("idle", 4), ("walk", 6), ("run", 6), ("cast", 5)):
            for index in range(count):
                result[f"kael_v17/{state}/{direction}_{index}.png"] = (256, 256, 128, 232)
        for stage in range(1, 4):
            for index in range(3):
                result[f"kael_v17/combo/{direction}_c{stage}_{index}.png"] = (512, 256, 256, 232)
        for state, count in (("idle", 3), ("chase", 4), ("attack", 4)):
            for index in range(count):
                result[f"enemy_v17/{state}/{direction}_{index}.png"] = (256, 256, 128, 232)
    for state, count in (("hurt", 3), ("death", 5)):
        for index in range(count):
            result[f"enemy_v17/{state}_{index}.png"] = (256, 256, 128, 232)
    for index in range(8):
        result[f"fx_v17/orb_{index}.png"] = (160, 160, 80, 80)
    assert len(result) == 180
    return result


def manifest_records(document):
    """Expand inherited animation fields into individual frame records."""
    records = {}
    errors = []
    animations = document.get("animations", [])
    if isinstance(animations, dict):
        animations = list(animations.values())
    for animation in animations:
        frames = animation.get("frames", [])
        for index, frame in enumerate(frames):
            record = dict(animation)
            record.pop("frames", None)
            if isinstance(frame, str):
                record.update(file=frame, index=index)
            else:
                record.update(frame)
            file = record.get("file", "")
            if file in records:
                errors.append(f"Duplicate manifest record: {file}")
            records[file] = record
    return records, errors


def validate(assets):
    expected = expected_frames()
    errors = []
    warnings = []
    manifest_path = assets / MANIFEST
    if not manifest_path.is_file():
        raise ValueError(f"Missing authoritative manifest: {manifest_path}")
    document = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    records, manifest_errors = manifest_records(document)
    errors.extend(manifest_errors)
    if str(document.get("version")) != "1.7.0":
        errors.append("Main manifest version must be 1.7.0")
    missing_metadata = set(expected) - set(records)
    unexpected_metadata = set(records) - set(expected)
    if missing_metadata:
        errors.append("Missing frame metadata: " + ", ".join(sorted(missing_metadata)))
    if unexpected_metadata:
        errors.append("Unexpected runtime frame metadata: " + ", ".join(sorted(unexpected_metadata)))
    frames = []
    pixel_hashes = {}
    for file, shape in sorted(expected.items()):
        path = assets / file
        if not path.is_file():
            errors.append(f"Missing runtime frame: {file}")
            continue
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG" or image.mode != "RGBA":
                errors.append(f"Expected RGBA PNG: {file} ({image.format}, {image.mode})")
            if image.size != shape[:2]:
                errors.append(f"Invalid cell dimensions: {file}: {image.size}, expected {shape[:2]}")
            rgba = image.convert("RGBA")
            alpha = rgba.getchannel("A")
            bbox = alpha.getbbox()
            if not bbox:
                errors.append(f"Empty frame: {file}")
            elif bbox[0] < 1 or bbox[1] < 1 or bbox[2] > image.width - 1 or bbox[3] > image.height - 1:
                errors.append(f"Visible pixels touch cell boundary: {file}: {bbox}")
            if alpha.getextrema()[0] != 0:
                errors.append(f"No genuinely transparent pixels: {file}")
            pixel_digest = hashlib.sha256(rgba.tobytes()).hexdigest()
            pixel_hashes[file] = pixel_digest
            transparent_count = alpha.histogram()[0]
        record = records.get(file, {})
        for name, value in zip(("cellWidth", "cellHeight", "pivotX", "pivotY"), shape):
            if record.get(name) != value:
                errors.append(f"Metadata {name} must be {value}: {file} (found {record.get(name)})")
        fps = record.get("recommendedFPS", record.get("fps", record.get("FPS")))
        if not isinstance(fps, (int, float)) or fps <= 0:
            errors.append(f"Missing positive recommended FPS: {file}")
        # An orb has an effect origin and no foot baseline. Its pivot is still
        # required above; characters always carry the authored foot baseline.
        if not file.startswith("fx_v17/") and record.get("baseline") != shape[3]:
            errors.append(f"Missing authored baseline {shape[3]}: {file}")
        frames.append({"file": file, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                       "pixelSha256": pixel_digest, "cellWidth": shape[0], "cellHeight": shape[1],
                       "pivotX": shape[2], "pivotY": shape[3], "visibleBounds": list(bbox) if bbox else None,
                       "transparentPixels": transparent_count, "recommendedFPS": fps})
    walk_hashes = {digest for file, digest in pixel_hashes.items() if file.startswith("kael_v17/walk/")}
    run_hashes = {digest for file, digest in pixel_hashes.items() if file.startswith("kael_v17/run/")}
    duplicates = walk_hashes & run_hashes
    if duplicates:
        errors.append(f"Walk and run reuse {len(duplicates)} identical RGBA frames")
    groups = {}
    for file, digest in pixel_hashes.items():
        groups.setdefault(digest, []).append(file)
    for identical in groups.values():
        if len(identical) > 1:
            warnings.append({"identicalPixels": identical})
    report = {
        "version": "1.7.0", "package": "com.veilbreakers.prototype", "versionCode": 21,
        "frameCount": len(frames), "expectedFrameCount": 180,
        "counts": {"kael": sum(f["file"].startswith("kael_v17/") for f in frames),
                   "veilborn": sum(f["file"].startswith("enemy_v17/") for f in frames),
                   "arcanaOrb": sum(f["file"].startswith("fx_v17/") for f in frames)},
        "manifest": MANIFEST,
        "manifestSha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "checks": {"RGBA": True, "cellDimensions": True, "transparentBoundary": True,
                   "documentedPivotAndBaseline": True, "walkRunPixelHashesDisjoint": not duplicates},
        "visualReview": "Technical validation only. Consult contact sheets and Android runtime captures.",
        "frames": frames, "warnings": warnings, "errors": errors, "passed": not errors,
    }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=ROOT / "app/src/main/assets")
    parser.add_argument("--report", type=Path, help="Defaults to project_archive/V17_ASSET_QA.json inside assets")
    args = parser.parse_args()
    try:
        report = validate(args.assets)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"Asset validation failed: {error}\n")
    output = args.report or args.assets / REPORT
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "frameCount": report["frameCount"],
                      "counts": report["counts"], "warnings": len(report["warnings"]), "report": str(output)}))
    if report["errors"]:
        parser.exit(1, "\n".join(report["errors"]) + "\n")


if __name__ == "__main__":
    main()
