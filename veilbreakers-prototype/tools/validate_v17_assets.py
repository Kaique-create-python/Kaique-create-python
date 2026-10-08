#!/usr/bin/env python3
"""Validate current runtime sprites/world artwork while preserving historical art.

This validates technical properties, not anatomical or artistic quality. The
contact sheets and Android captures remain the evidence for visual review.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from v19_art_contract import GAME_ART_MANIFEST, game_art_files

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("down", "up", "left", "right")
CURRENT_VERSION = "1.9.0"
MANIFESTS = {"1.7.0": "project_archive/SPRITES_MANIFEST_V170.json",
             "1.8.0": "project_archive/SPRITES_MANIFEST_V180.json",
             "1.9.0": "project_archive/SPRITES_MANIFEST_V190.json"}
REPORTS = {"1.7.0": "project_archive/V17_ASSET_QA.json",
           "1.8.0": "project_archive/V18_ASSET_QA.json",
           "1.9.0": "project_archive/V19_ASSET_QA.json"}
VERSION_CODES = {"1.7.0": 21, "1.8.0": 22, "1.9.0": 23}
MANIFEST = MANIFESTS[CURRENT_VERSION]
REPORT = REPORTS[CURRENT_VERSION]


def expected_frames(version=CURRENT_VERSION):
    result = {}
    for direction in DIRECTIONS:
        for state, count in (("idle", 4), ("walk", 6), ("run", 6), ("cast", 6 if version == "1.9.0" else 5)):
            for index in range(count):
                root = "kael_v18" if version != "1.7.0" and state == "run" else "kael_v17"
                if version == "1.9.0" and state == "cast": root = "kael_v19"
                result[f"{root}/{state}/{direction}_{index}.png"] = (256, 256, 128, 232)
        for stage in range(1, 4):
            for index in range(3):
                result[f"kael_v17/combo/{direction}_c{stage}_{index}.png"] = (512, 256, 256, 232)
        for state, count in (("idle", 3), ("chase", 4), ("attack", 4)):
            for index in range(count):
                result[f"enemy_v17/{state}/{direction}_{index}.png"] = (256, 256, 128, 232)
    for state, count in (("hurt", 3), ("death", 5)):
        for index in range(count):
            result[f"enemy_v17/{state}_{index}.png"] = (256, 256, 128, 232)
    for index in range(12 if version == "1.9.0" else 8):
        if version == "1.9.0": result[f"fx_v19/arcana_{index}.png"] = (256, 256, 128, 128)
        else: result[f"fx_v17/orb_{index}.png"] = (160, 160, 80, 80)
    assert len(result) == (188 if version == "1.9.0" else 180)
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


def validate(assets, version=CURRENT_VERSION):
    expected = expected_frames(version)
    errors = []
    warnings = []
    manifest_path = assets / MANIFESTS[version]
    if not manifest_path.is_file():
        raise ValueError(f"Missing authoritative manifest: {manifest_path}")
    document = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    records, manifest_errors = manifest_records(document)
    errors.extend(manifest_errors)
    if str(document.get("version")) != version:
        errors.append(f"Main manifest version must be {version}")
    if document.get("versionCode") != VERSION_CODES[version]:
        errors.append(f"Main manifest versionCode must be {VERSION_CODES[version]}")
    historical_records = {}
    base_version = {"1.8.0": "1.7.0", "1.9.0": "1.8.0"}.get(version)
    if base_version:
        historical = json.loads((assets / MANIFESTS[base_version]).read_text(encoding="utf-8-sig"))
        historical_records, _ = manifest_records(historical)
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
        file_digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if record.get("sha256") != file_digest:
            errors.append(f"Frame differs from its authored manifest hash: {file}")
        if base_version and file in historical_records:
            if historical_records[file].get("sha256") != file_digest:
                errors.append(f"Preserved v{base_version} frame was modified: {file}")
        for name, value in zip(("cellWidth", "cellHeight", "pivotX", "pivotY"), shape):
            if record.get(name) != value:
                errors.append(f"Metadata {name} must be {value}: {file} (found {record.get(name)})")
        fps = record.get("recommendedFPS", record.get("fps", record.get("FPS")))
        if not isinstance(fps, (int, float)) or fps <= 0:
            errors.append(f"Missing positive recommended FPS: {file}")
        # An orb has an effect origin and no foot baseline. Its pivot is still
        # required above; characters always carry the authored foot baseline.
        if not file.startswith("fx_v") and record.get("baseline") != shape[3]:
            errors.append(f"Missing authored baseline {shape[3]}: {file}")
        frames.append({"file": file, "sha256": file_digest,
                       "pixelSha256": pixel_digest, "cellWidth": shape[0], "cellHeight": shape[1],
                       "pivotX": shape[2], "pivotY": shape[3], "visibleBounds": list(bbox) if bbox else None,
                       "transparentPixels": transparent_count, "recommendedFPS": fps})
    walk_hashes = {digest for file, digest in pixel_hashes.items() if file.startswith("kael_v17/walk/")}
    run_prefix = "kael_v17/run/" if version == "1.7.0" else "kael_v18/run/"
    run_hashes = {digest for file, digest in pixel_hashes.items() if file.startswith(run_prefix)}
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
        "version": version, "package": "com.veilbreakers.prototype", "versionCode": VERSION_CODES[version],
        "frameCount": len(frames), "expectedFrameCount": len(expected),
        "counts": {"kael": sum(f["file"].startswith("kael_v") for f in frames),
                   "veilborn": sum(f["file"].startswith("enemy_v17/") for f in frames),
                   "arcanaOrb": sum(f["file"].startswith("fx_v") for f in frames)},
        "manifest": MANIFESTS[version],
        "manifestSha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "checks": {"RGBA": True, "cellDimensions": True, "transparentBoundary": True,
                   "documentedPivotAndBaseline": True, "walkRunPixelHashesDisjoint": not duplicates},
        "preservedBaseVersion": base_version,
        "preservedBaseFrames": sum(f["file"] in historical_records for f in frames) if base_version else len(frames),
        "visualReview": "Technical validation only. Consult contact sheets and Android runtime captures.",
        "frames": frames, "warnings": warnings, "errors": errors, "passed": not errors,
    }
    if version == "1.8.0": report["preservedV17Frames"] = report["preservedBaseFrames"]
    if version == "1.9.0":
        cast_path = assets / "kael_v19/cast_manifest.json"
        cast = json.loads(cast_path.read_text(encoding="utf-8-sig"))
        cast_records, cast_errors = manifest_records(cast)
        errors.extend(cast_errors)
        required_cast = {file for file in expected if file.startswith("kael_v19/cast/")}
        if set(cast_records) != required_cast:
            errors.append("Runtime cast/socket JSON must describe all 24 active v1.9 cast frames")
        for animation in cast.get("animations", []):
            if animation.get("releaseFrame") != 3 or animation.get("releaseTimeSeconds") != .34 or animation.get("durationSeconds") != .72:
                errors.append("Runtime cast timing requires 0.34s release at frame 3 within a 0.72s cast")
            durations = animation.get("frameDurationsSeconds", [])
            if len(durations) != 6 or abs(sum(durations) - .72) > .00001:
                errors.append("Runtime cast timing requires six documented frame durations totaling 0.72s")
        for file in required_cast:
            socket = cast_records.get(file, {}).get("orbSocketPx")
            if not isinstance(socket, list) or len(socket) != 2 or not all(isinstance(value, (int, float)) and 0 <= value <= 256 for value in socket):
                errors.append("Missing valid authored orb hand socket: " + file)
            elif socket != records.get(file, {}).get("orbSocketPx"):
                errors.append("Runtime cast/socket JSON differs from principal sprite metadata: " + file)
        report["runtimeMetadata"] = [{"file": "kael_v19/cast_manifest.json", "sha256": hashlib.sha256(cast_path.read_bytes()).hexdigest()}]
        art_path = assets / GAME_ART_MANIFEST
        art = json.loads(art_path.read_text(encoding="utf-8-sig"))
        art_records = {record["file"]: record for record in art.get("assets", [])}
        if art.get("version") != version or set(art_records) != set(game_art_files()):
            errors.append("GameArt manifest must contain exactly the 28 required v1.9 assets")
        verified_art = []
        for file in game_art_files():
            path = assets / file
            if not path.is_file():
                errors.append("Missing mandatory generated game art: " + file)
                continue
            record = art_records.get(file, {})
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            with Image.open(path) as image:
                image.load()
                if image.format != "PNG" or image.size != (record.get("width"), record.get("height")):
                    errors.append("GameArt dimensions/format differ from manifest: " + file)
                if file.startswith("art_v19/scenes/"):
                    if image.width < 640 or image.height < 360 or image.width <= image.height:
                        errors.append("Scene must be a landscape background of at least 640x360: " + file)
                else:
                    if image.mode != "RGBA" or image.getchannel("A").getextrema()[0] != 0:
                        errors.append("Generated cutout requires RGBA transparency: " + file)
                    if not image.convert("RGBA").getchannel("A").getbbox():
                        errors.append("Generated cutout is empty: " + file)
                if file.startswith("art_v19/npc/") and image.size != (256, 256):
                    errors.append("NPC requires a fixed 256x256 canvas: " + file)
            if digest != record.get("sha256"):
                errors.append("GameArt differs from authored manifest hash: " + file)
            verified_art.append({"file": file, "sha256": digest})
        report["gameArt"] = verified_art
        report["gameArtManifest"] = GAME_ART_MANIFEST
        report["gameArtManifestSha256"] = hashlib.sha256(art_path.read_bytes()).hexdigest()
        report["gameArtCount"] = len(verified_art)
        report["passed"] = not errors
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", choices=tuple(MANIFESTS), default=CURRENT_VERSION,
                        help="Use 1.7.0 to reproduce historical artwork validation")
    parser.add_argument("--assets", type=Path, default=ROOT / "app/src/main/assets")
    parser.add_argument("--report", type=Path, help="Defaults to project_archive/V17_ASSET_QA.json inside assets")
    args = parser.parse_args()
    try:
        report = validate(args.assets, args.version)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"Asset validation failed: {error}\n")
    output = args.report or args.assets / REPORTS[args.version]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "frameCount": report["frameCount"],
                      "counts": report["counts"], "warnings": len(report["warnings"]), "report": str(output)}))
    if report["errors"]:
        parser.exit(1, "\n".join(report["errors"]) + "\n")


if __name__ == "__main__":
    main()
