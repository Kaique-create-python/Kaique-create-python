#!/usr/bin/env python3
"""Package v1.10 areas/runes/fire/ice while preserving all v1.9 asset bytes."""
import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from PIL import Image
from pack_v19_assets import write_json
from refresh_release_context import refresh
from v19_art_contract import GAME_ART_MANIFESTS, game_art_files
from validate_v17_assets import MANIFESTS, REPORTS, expected_frames, manifest_records, validate

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app/src/main/assets"
VERSION = "1.10.0"


def pack(assets):
    archive = assets / "project_archive"
    base_path = archive / "SPRITES_MANIFEST_V190.json"
    if not base_path.is_file(): base_path = ROOT / "SPRITES_MANIFEST_V190.json"
    subset_path = archive / "SPELL_FX_MANIFEST_V200.json"
    if not subset_path.is_file(): subset_path = ROOT / "SPELL_FX_MANIFEST_V200.json"
    base = json.loads(base_path.read_text(encoding="utf-8-sig"))
    subset = json.loads(subset_path.read_text(encoding="utf-8-sig"))
    additions, errors = manifest_records(subset)
    required = {file for file in expected_frames(VERSION) if file.startswith("fx_v20/")}
    if errors or set(additions) != required:
        raise ValueError("Spell FX subset must describe exactly 12 fire + 12 ice frames")
    document = copy.deepcopy(base)
    document["animations"].extend(copy.deepcopy(subset["animations"]))
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=False)
    document.update(version=VERSION, versionCode=24, runtimeFrameCount=212, artBaseVersion="1.9.0",
                    preservedBaseFrames=188, generationBaseCommit=result.stdout.strip() if result.returncode == 0 else None,
                    gameArtManifest=GAME_ART_MANIFESTS[VERSION],
                    sourceSheetsDirectories=[f"project_archive/source_sheets/v{value}" for value in (17, 18, 19, 20)],
                    previewsDirectories=[f"project_archive/previews/v{value}" for value in (17, 18, 19, 20)],
                    reconstruction="Decode v17_reviewed_art, run_v18_assets, v19_assets, then v20_assets; source sheets/crop metadata preserved.")
    document["reconstructionScripts"] = sorted(set(document.get("reconstructionScripts", []) + [
        "import_v20_art.py", "pack_v20_assets.py", "prepare_spell_fx_v20.py"]))
    write_json(assets / MANIFESTS[VERSION], document)
    write_json(ROOT / "SPRITES_MANIFEST_V200.json", document)
    art_records = []
    previous = json.loads((assets / GAME_ART_MANIFESTS["1.9.0"]).read_text(encoding="utf-8-sig"))
    previous_records = {record["file"]: record for record in previous["assets"]}
    for file in game_art_files(VERSION):
        path = assets / file
        if not path.is_file(): raise ValueError("Missing mandatory generated game art: " + file)
        if file in previous_records:
            art_records.append(copy.deepcopy(previous_records[file]))
        else:
            with Image.open(path) as image:
                art_records.append({"file": file, "width": image.width, "height": image.height,
                                    "mode": image.mode, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    art = {"version": VERSION, "versionCode": 24, "assetCount": 35, "preservedV19Assets": 28,
           "sourceSheets": "project_archive/source_sheets/v20", "previews": "project_archive/previews/v20",
           "assets": art_records}
    write_json(assets / GAME_ART_MANIFESTS[VERSION], art)
    write_json(ROOT / "GAME_ART_MANIFEST_V200.json", art)
    refresh(assets)
    report = validate(assets, VERSION)
    write_json(assets / REPORTS[VERSION], report)
    if not report["passed"]: raise ValueError("\n".join(report["errors"]))
    roots = ("art_v20", "fx_v20", "project_archive/source_sheets/v20", "project_archive/previews/v20")
    files = {path for folder in roots for path in (assets / folder).rglob("*") if path.is_file()}
    files.update(path for path in archive.iterdir() if path.is_file() and ("V200" in path.name or path.name.startswith("V20_")))
    files.add(assets / REPORTS[VERSION])
    output = ROOT / "build/v20_assets.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for path in sorted(files): package.write(path, path.relative_to(assets).as_posix())
    encoded = base64.b64encode(output.read_bytes()).decode("ascii")
    dest = ROOT / "app/src/main/assets_b64"
    parts = []
    for index, start in enumerate(range(0, len(encoded), 900000)):
        path = dest / f"v20_assets.zip.b64.part-{index:03d}"
        path.write_text(encoded[start:start+900000], encoding="ascii")
        parts.append(path)
    for old in dest.glob("v20_assets.zip.b64.part-*"):
        if old not in parts: old.unlink()
    print(json.dumps({"runtimeFrames": 212, "gameArtFiles": 35, "preservedBaseFrames": 188,
                      "preservedGameArtFiles": 28, "zipFiles": len(files), "zipBytes": output.stat().st_size,
                      "sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "base64Parts": len(parts)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=ASSETS)
    pack(parser.parse_args().assets)


if __name__ == "__main__":
    main()
