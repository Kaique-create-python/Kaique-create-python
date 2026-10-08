#!/usr/bin/env python3
"""Prove the APK contains the exact 180 reviewed frames and v1.7 metadata."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from validate_v17_assets import MANIFEST, REPORT, ROOT, expected_frames


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
    if not report.get("passed") or report.get("frameCount") != 180:
        raise ValueError("Source asset report must pass with exactly 180 runtime frames")
    records = {record["file"]: record for record in report["frames"]}
    if set(records) != set(expected_frames()):
        raise ValueError("Source report has an unexpected set of runtime frames")
    with zipfile.ZipFile(apk) as package:
        names = set(package.namelist())
        for file, record in records.items():
            name = "assets/" + file
            if name not in names:
                raise ValueError(f"APK missing runtime sprite: {file}")
            if hashlib.sha256(package.read(name)).hexdigest() != record["sha256"]:
                raise ValueError(f"APK sprite differs from reviewed source: {file}")
        if hashlib.sha256(package.read("assets/" + MANIFEST)).hexdigest() != report["manifestSha256"]:
            raise ValueError("APK main sprite manifest differs from validation report")
        if package.read("assets/" + REPORT) != report_bytes:
            raise ValueError("APK embedded QA report differs from source report")
        for required in ("assets/project_archive/CHAT_CONTEXTO_ATUAL.txt", "assets/project_archive/BUILD_VERSION.txt",
                         "assets/project_archive/HISTORIA_COMPLETA.txt"):
            if required not in names:
                raise ValueError(f"Missing recovery context: {required}")
        version = package.read("assets/project_archive/BUILD_VERSION.txt").decode("utf-8-sig").strip()
        if "1.7.0" not in version:
            raise ValueError(f"Stale embedded build version: {version}")
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
        if not match or match.groups() != ("com.veilbreakers.prototype", "21", "1.7.0"):
            raise ValueError("Incorrect APK package/version metadata: " + (match.group(0) if match else "not found"))
        package_metadata = {"package": match.group(1), "versionCode": 21, "versionName": match.group(3)}
    return {"passed": True, "apk": apk.name, "apkSha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
            "apkBytes": apk.stat().st_size, "verifiedRuntimeFrames": len(records),
            "sourceSheets": len(sources), "previewFiles": len(previews),
            "metadata": package_metadata, "packageMetadataChecked": not skip_package}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--report", type=Path, default=ROOT / "app/src/main/assets" / REPORT)
    parser.add_argument("--aapt", default=find_aapt())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--skip-package", action="store_true", help="Only for a local synthetic ZIP verifier test")
    args = parser.parse_args()
    try:
        report = verify(args.apk, args.report, args.aapt, args.skip_package)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        parser.exit(1, f"APK verification failed: {error}\n")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
