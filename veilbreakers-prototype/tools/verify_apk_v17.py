#!/usr/bin/env python3
"""Prove the APK contains exact reviewed sprite/game-art bytes and release metadata."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from validate_v17_assets import CURRENT_VERSION, MANIFESTS, REPORTS, ROOT, VERSION_CODES, expected_frames


def find_aapt():
    command = shutil.which("aapt")
    if command:
        return command
    for variable in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        sdk = os.environ.get(variable)
        if sdk:
            candidates = sorted((Path(sdk) / "build-tools").glob("*/aapt*"), reverse=True)
            for path in candidates:
                if path.name in ("aapt", "aapt.exe"):
                    return str(path)
    return None


def verify(apk, report_path, aapt, skip_package=False):
    report_bytes = report_path.read_bytes()
    report = json.loads(report_bytes)
    version_name = report.get("version")
    if version_name not in MANIFESTS:
        raise ValueError("Unknown artwork/release version in source asset report")
    version_code = VERSION_CODES[version_name]
    expected = expected_frames(version_name)
    if not report.get("passed") or report.get("frameCount") != len(expected):
        raise ValueError(f"Source asset report must pass with exactly {len(expected)} runtime frames")
    records = {record["file"]: record for record in report["frames"]}
    if set(records) != set(expected):
        raise ValueError("Source report has an unexpected set of runtime frames")
    with zipfile.ZipFile(apk) as package:
        names = set(package.namelist())
        for file, record in records.items():
            name = "assets/" + file
            if name not in names:
                raise ValueError(f"APK missing runtime sprite: {file}")
            if hashlib.sha256(package.read(name)).hexdigest() != record["sha256"]:
                raise ValueError(f"APK sprite differs from reviewed source: {file}")
        if hashlib.sha256(package.read("assets/" + MANIFESTS[version_name])).hexdigest() != report["manifestSha256"]:
            raise ValueError("APK main sprite manifest differs from validation report")
        if package.read("assets/" + REPORTS[version_name]) != report_bytes:
            raise ValueError("APK embedded QA report differs from source report")
        if version_name == "1.9.0":
            if not report.get("runtimeMetadata"):
                raise ValueError("Source report must validate the runtime cast timing/socket JSON")
            for record in report["runtimeMetadata"]:
                if hashlib.sha256(package.read("assets/" + record["file"])).hexdigest() != record["sha256"]:
                    raise ValueError("APK runtime timing/socket metadata differs from reviewed source")
            if report.get("gameArtCount") != 28 or len(report.get("gameArt", [])) != 28:
                raise ValueError("Source asset report must validate all 28 mandatory generated game-art files")
            for record in report["gameArt"]:
                name = "assets/" + record["file"]
                if name not in names or hashlib.sha256(package.read(name)).hexdigest() != record["sha256"]:
                    raise ValueError("APK game art differs from reviewed source: " + record["file"])
            if hashlib.sha256(package.read("assets/" + report["gameArtManifest"])).hexdigest() != report["gameArtManifestSha256"]:
                raise ValueError("APK GameArt manifest differs from validation report")
        for required in ("assets/project_archive/CHAT_CONTEXTO_ATUAL.txt", "assets/project_archive/BUILD_VERSION.txt",
                         "assets/project_archive/HISTORIA_COMPLETA.txt"):
            if required not in names:
                raise ValueError(f"Missing recovery context: {required}")
        version = package.read("assets/project_archive/BUILD_VERSION.txt").decode("utf-8-sig").strip()
        if f"v{version_name}" not in version:
            raise ValueError(f"Stale embedded build version: {version}")
        if version_name in ("1.8.0", "1.9.0"):
            metadata = json.loads(package.read("assets/project_archive/BUILD_METADATA.json"))
            if (metadata.get("package"), metadata.get("version"), metadata.get("versionCode")) != (
                    "com.veilbreakers.prototype", version_name, version_code):
                raise ValueError("Embedded release metadata differs from current build")
            if version_name == "1.8.0" and (metadata.get("preservedV17Frames") != 156 or metadata.get("newRunFrames") != 24):
                raise ValueError("Release metadata must describe 156 preserved and 24 new running frames")
            if version_name == "1.9.0" and (metadata.get("preservedBaseFrames"), metadata.get("newCastFrames"),
                    metadata.get("newFxFrames"), metadata.get("gameArtFiles")) != (152, 24, 12, 28):
                raise ValueError("Release metadata must describe 152 preserved sprites, 36 new cast/FX and 28 world/UI assets")
            for folder in ("source_sheets/v18/", "previews/v18/"):
                if not any(n.startswith("assets/project_archive/" + folder) for n in names):
                    raise ValueError("APK must preserve v1.8 running review artifacts: " + folder)
            if version_name == "1.9.0":
                for folder in ("source_sheets/v19/", "previews/v19/"):
                    if not any(n.startswith("assets/project_archive/" + folder) for n in names):
                        raise ValueError("APK must preserve generated v1.9 sources/previews: " + folder)
        sources = [n for n in names if n.startswith("assets/project_archive/source_sheets/v17/") and n.endswith(".png")]
        previews = [n for n in names if n.startswith("assets/project_archive/previews/v17/")]
        if not sources or not previews:
            raise ValueError("APK must preserve new source sheets and preview artifacts")
    package_metadata = None
    if not skip_package:
        if not aapt:
            raise ValueError("aapt unavailable: provide --aapt PATH or install Android build-tools")
        result = subprocess.run([aapt, "dump", "badging", str(apk)], check=True, capture_output=True, text=True)
        match = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", result.stdout)
        if not match or match.groups() != ("com.veilbreakers.prototype", str(version_code), version_name):
            raise ValueError("Incorrect APK package/version metadata: " + (match.group(0) if match else "not found"))
        package_metadata = {"package": match.group(1), "versionCode": version_code, "versionName": match.group(3)}
    return {"passed": True, "apk": apk.name, "apkSha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
            "apkBytes": apk.stat().st_size, "verifiedRuntimeFrames": len(records),
            "sourceSheets": len(sources), "previewFiles": len(previews),
            "verifiedGameArtFiles": report.get("gameArtCount", 0),
            "metadata": package_metadata, "packageMetadataChecked": not skip_package}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", choices=tuple(MANIFESTS), default=CURRENT_VERSION)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--aapt", default=find_aapt())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--skip-package", action="store_true", help="Only for a local synthetic ZIP verifier test")
    args = parser.parse_args()
    try:
        report_path = args.report or ROOT / "app/src/main/assets" / REPORTS[args.version]
        report = verify(args.apk, report_path, args.aapt, args.skip_package)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        parser.exit(1, f"APK verification failed: {error}\n")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
