#!/usr/bin/env python3
"""Package exact authored v1.9 game art and cast/FX over the preserved v1.8 base.

No bitmap is transformed here. Source sheets, crop metadata and previews are
archived with the runtime bytes, and technical validation must pass before encoding.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
import base64

from PIL import Image
from v19_art_contract import GAME_ART_MANIFEST, game_art_files
from validate_v17_assets import MANIFESTS, REPORTS, expected_frames, manifest_records, validate
from refresh_release_context import refresh

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def pack(assets):
    archive = assets / "project_archive"
    base_path = archive / "SPRITES_MANIFEST_V180.json"
    if not base_path.is_file(): base_path = ROOT / "SPRITES_MANIFEST_V180.json"
    subset_path = archive / "CAST_FX_MANIFEST_V190.json"
    if not subset_path.is_file(): subset_path = ROOT / "CAST_FX_MANIFEST_V190.json"
    base = json.loads(base_path.read_text(encoding="utf-8-sig"))
    subset = json.loads(subset_path.read_text(encoding="utf-8-sig"))
    replacement_records, duplicate_errors = manifest_records(subset)
    expected = expected_frames("1.9.0")
    new_paths = {file for file in expected if file.startswith(("kael_v19/", "fx_v19/"))}
    if duplicate_errors or set(replacement_records) != new_paths:
        raise ValueError("Cast/FX subset must describe exactly the 24 cast + 12 FX runtime frames")
    document = copy.deepcopy(base)
    document["animations"] = [animation for animation in base["animations"]
        if not any((frame if isinstance(frame, str) else frame["file"]).startswith(("kael_v17/cast/", "fx_v17/"))
                   for frame in animation["frames"])] + copy.deepcopy(subset["animations"])
    document.pop("sourceCommit", None)
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=False)
    document.update(version="1.9.0", versionCode=23, runtimeFrameCount=188,
                    artBaseVersion="1.8.0", preservedBaseFrames=152,
                    generationBaseCommit=result.stdout.strip() if result.returncode == 0 else None,
                    gameArtManifest=GAME_ART_MANIFEST,
                    castTimingManifest="kael_v19/cast_manifest.json",
                    reconstruction="Decode v17_reviewed_art, run_v18_assets, then v19_assets; source sheets and crop metadata are preserved.")
    write_json(assets / MANIFESTS["1.9.0"], document)
    write_json(ROOT / "SPRITES_MANIFEST_V190.json", document)
    art_records = []
    for file in game_art_files():
        path = assets / file
        if not path.is_file(): raise ValueError("Missing mandatory generated game art: " + file)
        with Image.open(path) as image:
            record = {"file": file, "width": image.width, "height": image.height,
                      "mode": image.mode, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        if file.startswith("art_v19/npc/"):
            record.update(pivotX=128, pivotY=232, baseline=232, runtimeFPS=.5)
        art_records.append(record)
    art = {"version": "1.9.0", "versionCode": 23, "assetCount": len(art_records),
           "sourceSheets": "project_archive/source_sheets/v19",
           "previews": "project_archive/previews/v19", "assets": art_records}
    write_json(assets / GAME_ART_MANIFEST, art)
    write_json(ROOT / "GAME_ART_MANIFEST_V190.json", art)
    refresh(assets)
    report = validate(assets, "1.9.0")
    write_json(assets / REPORTS["1.9.0"], report)
    if not report["passed"]: raise ValueError("\n".join(report["errors"]))
    roots = ("art_v19", "kael_v19", "fx_v19", "project_archive/source_sheets/v19", "project_archive/previews/v19")
    files = {p for folder in roots for p in (assets / folder).rglob("*") if p.is_file()}
    files.update(p for p in archive.iterdir() if p.is_file() and ("V190" in p.name or p.name.startswith("V19_")
                                                               or p.name == "ARCANA_PROMPTS.txt"))
    files.add(assets / REPORTS["1.9.0"])
    output = ROOT / "build/v19_assets.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for path in sorted(files): package.write(path, path.relative_to(assets).as_posix())
    encoded = base64.b64encode(output.read_bytes()).decode("ascii")
    dest = ROOT / "app/src/main/assets_b64"
    parts = []
    for index, start in enumerate(range(0, len(encoded), 900000)):
        path = dest / f"v19_assets.zip.b64.part-{index:03d}"
        path.write_text(encoded[start:start + 900000], encoding="ascii")
        parts.append(path)
    # Only obsolete chunks authored by this exact packer are removed. No phone
    # files or pre-existing historical asset archives are touched.
    for old in dest.glob("v19_assets.zip.b64.part-*"):
        if old not in parts: old.unlink()
    print(json.dumps({"runtimeFrames": 188, "gameArtFiles": 28, "preservedBaseFrames": 152,
                      "zipFiles": len(files), "zipBytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "base64Parts": len(parts)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=ASSETS)
    pack(parser.parse_args().assets)


if __name__ == "__main__":
    main()
