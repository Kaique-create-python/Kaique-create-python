#!/usr/bin/env python3
"""Refresh release metadata after applying the immutable artwork archives."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def refresh(assets):
    gradle = (ROOT / "app/build.gradle").read_text(encoding="utf-8")
    version = re.search(r"versionName\s+['\"]([^'\"]+)['\"]", gradle).group(1)
    code = int(re.search(r"versionCode\s+(\d+)", gradle).group(1))
    archive = assets / "project_archive"
    archive.mkdir(parents=True, exist_ok=True)
    for source, destination in (("VEILBREAKERS_CONTEXTO.txt", "CHAT_CONTEXTO_ATUAL.txt"),
                                ("HISTORIA_COMPLETA.txt", "HISTORIA_COMPLETA.txt"),
                                ("SPRITES_MANIFEST_V180.json", "SPRITES_MANIFEST_V180.json"),
                                ("RUN_REVIEW_V180.md", "RUN_REVIEW_V180.md")):
        path = ROOT / source
        if path.is_file():
            shutil.copy2(path, archive / destination)
    commit = os.environ.get("GITHUB_SHA")
    if not commit:
        result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                capture_output=True, text=True, check=False)
        commit = result.stdout.strip() if result.returncode == 0 else None
    metadata = {
        "package": "com.veilbreakers.prototype", "version": version, "versionCode": code,
        "sourceCommit": commit, "sourceBranch": "veilbreakers-apk-build",
        "artBaseVersion": "1.7.0", "runOverrideVersion": "1.8.0",
        "runtimeManifest": "project_archive/SPRITES_MANIFEST_V180.json",
        "runtimeFrameCount": 180, "preservedV17Frames": 156, "newRunFrames": 24,
    }
    (archive / "BUILD_VERSION.txt").write_text(
        f"VEILBREAKERS v{version}\nversionCode {code}\nArtwork: v1.7 base + v1.8 running\n",
        encoding="utf-8")
    (archive / "BUILD_METADATA.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata))
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=ROOT / "app/src/main/assets")
    refresh(parser.parse_args().assets)


if __name__ == "__main__":
    main()
