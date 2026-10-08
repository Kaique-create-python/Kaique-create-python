#!/usr/bin/env python3
"""Capture all 180 authored frames from the installed Android debug renderer.

The debug review reuses GameView's normal player, enemy and magic render paths.
Captures and contact sheets support manual visual review; pixel statistics are
only smoke checks, never a claim of anatomical or artistic approval.
"""
import argparse
from collections import Counter
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
import time

from PIL import Image, ImageDraw

PACKAGE = "com.veilbreakers.prototype"
ACTIVITY = PACKAGE + "/.MainActivity"
DIRECTIONS = ("down", "up", "left", "right")
DIRECTED = (("idle", 4), ("walk", 6), ("run", 6), ("combo1", 3), ("combo2", 3),
            ("combo3", 3), ("cast", 5), ("enemy_idle", 3), ("enemy_chase", 4), ("enemy_attack", 4))
UNDIRECTED = (("hurt", 3), ("death", 5), ("orb", 8))


def review_frames():
    for state, count in DIRECTED:
        for direction in range(4):
            for frame in range(count):
                yield state, direction, frame
    for state, count in UNDIRECTED:
        for frame in range(count):
            yield state, 0, frame


class Android:
    def __init__(self, serial):
        self.prefix = ["adb"] + (["-s", serial] if serial else [])

    def run(self, *args, timeout=45, check=True):
        result = subprocess.run(self.prefix + list(args), capture_output=True, text=True,
                                timeout=timeout, check=check)
        return result.stdout

    def start(self, state=None, direction=0, frame=0, fresh=False):
        command = ["shell", "am", "start", "-W"]
        if fresh:
            command += ["-S"]
        else:
            command += ["--activity-single-top"]
        command += ["-n", ACTIVITY]
        if state is not None:
            command += ["--ez", "art_review", "true", "--es", "review_state", state,
                        "--ei", "review_direction", str(direction), "--ei", "review_frame", str(frame)]
        output = self.run(*command)
        if "Error:" in output or "Exception" in output:
            raise RuntimeError("Activity launch failed: " + output)

    def screenshot(self, path):
        result = subprocess.run(self.prefix + ["exec-out", "screencap", "-p"],
                                check=True, capture_output=True, timeout=45)
        image = Image.open(BytesIO(result.stdout)).convert("RGB")
        image.load()
        if image.width <= image.height or image.width < 640 or image.height < 360:
            raise ValueError(f"Expected landscape Android rendering, received {image.size}")
        if max(image.getextrema()[channel][1] for channel in range(3)) < 80:
            raise ValueError("Screenshot is blank or the app failed to render")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(result.stdout)
        return image


def subject_crop(image, state):
    width, height = image.size
    x_fraction = 0.67 if state.startswith("enemy_") or state in ("hurt", "death") else 0.33
    y_fraction = 0.68
    if state == "orb":
        x_fraction, y_fraction = 0.50, 0.58
    # Preserve one screenshot-pixel scale in all character previews. This is a
    # common rectangle around the authored pivot, never a per-frame bbox fit.
    crop_h = round(height * (0.38 if state != "orb" else 0.24))
    crop_w = round(height * 0.66) if state.startswith("combo") else crop_h
    left = round(width * x_fraction - crop_w / 2)
    top = round(height * y_fraction - crop_h * (0.85 if state != "orb" else 0.5))
    return image.crop((left, top, left + crop_w, top + crop_h))


def contact_sheets(output, records, screenshots):
    contacts = output / "contacts"
    contacts.mkdir(parents=True, exist_ok=True)
    paths = []
    by_state = {}
    for record in records:
        by_state.setdefault(record["state"], []).append(record)
    for state, group in by_state.items():
        directed = any(state == item[0] for item in DIRECTED)
        columns = max(record["frame"] for record in group) + 1
        rows = 4 if directed else 1
        tile_w, tile_h = (490 if state.startswith("combo") else 285), 310
        sheet = Image.new("RGB", (columns * tile_w, rows * tile_h), (20, 18, 23))
        draw = ImageDraw.Draw(sheet)
        for record in group:
            x = record["frame"] * tile_w
            y = (record["direction"] if directed else 0) * tile_h
            draw.rectangle((x, y, x + tile_w - 1, y + tile_h - 1), outline=(92, 47, 60))
            draw.text((x + 8, y + 8), f"{state} / {DIRECTIONS[record['direction']]} / {record['frame']}",
                      fill=(241, 217, 222))
            with Image.open(screenshots / record["screenshot"]) as image:
                crop = subject_crop(image.convert("RGB"), state)
            # All character captures share the same size. Orb alone uses a
            # smaller region to show its internal animation at readable scale.
            crop.thumbnail((tile_w - 11, 274), Image.Resampling.LANCZOS)
            sheet.paste(crop, (x + (tile_w - crop.width) // 2, y + 29))
        path = contacts / f"runtime_{state}.jpg"
        sheet.save(path, quality=91, optimize=True)
        paths.append(str(path.relative_to(output)))
    return paths


def capture_video(android, output):
    remote = "/sdcard/veilbreakers_v17_review.mp4"
    process = subprocess.Popen(android.prefix + ["shell", "screenrecord", "--time-limit", "40",
                               "--bit-rate", "3000000", remote], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    states = [(state, direction) for state in ("idle", "walk", "run", "combo1", "combo2", "combo3", "cast")
              for direction in range(4)] + [("enemy_attack", 0), ("death", 0), ("orb", 0)]
    started = time.monotonic()
    try:
        for state, direction in states:
            if time.monotonic() - started > 36:
                break
            android.start(state, direction, -1)
            time.sleep(0.65)
        # The screenrecord process has a strict forty second limit. Polling
        # keeps every individual wait short and leaves logs available on error.
        while process.poll() is None and time.monotonic() - started < 47:
            time.sleep(0.25)
        if process.poll() is None:
            process.terminate()
        process.communicate(timeout=5)
        android.run("pull", remote, str(output / "runtime_animation_review.mp4"), timeout=45)
        return None
    except (OSError, subprocess.SubprocessError, RuntimeError) as error:
        if process.poll() is None:
            process.terminate()
        return str(error)


def capture_normal_combat(android, output, dimensions):
    """Exercise real touch controls and preserve a video of actual update()."""
    width, height = dimensions
    remote = '/sdcard/veilbreakers_v17_combat.mp4'
    process = subprocess.Popen(android.prefix + ['shell', 'screenrecord', '--time-limit', '18',
                               '--bit-rate', '3000000', remote], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    images = []
    def snap(name):
        path = output / 'screenshots' / ('normal_' + name + '.png')
        images.append((name, android.screenshot(path)))
    try:
        joyx, joyy = round(width*.13), round(height*.79)
        android.run('shell', 'input', 'swipe', str(joyx), str(joyy),
                    str(joyx+round(height*.14)), str(joyy), '650')
        snap('movement_right')
        android.run('shell', 'input', 'tap', str(round(width*.755)), str(round(height*.665)))
        time.sleep(.15)
        snap('cast_charge')
        time.sleep(.17)
        snap('cast_release')
        time.sleep(.80)
        for index in range(5):
            android.run('shell', 'input', 'tap', str(round(width*.865)), str(round(height*.78)))
            time.sleep(.14)
            if index in (1,3): snap('combo_tap_' + str(index))
        time.sleep(.8)
        android.run('shell', 'input', 'swipe', str(joyx), str(joyy),
                    str(joyx-round(height*.14)), str(joyy), '500')
        snap('movement_left')
        android.run('shell', 'input', 'tap', str(round(width*.755)), str(round(height*.665)))
        time.sleep(.30)
        snap('cast_left')
        process.communicate(timeout=25)
        android.run('pull', remote, str(output/'normal_combat_smoke.mp4'))
        sheet = Image.new('RGB', (960, 290*len(images)), (20,18,23))
        draw = ImageDraw.Draw(sheet)
        for row, (name, screenshot) in enumerate(images):
            screenshot.thumbnail((900,255),Image.Resampling.LANCZOS)
            draw.text((20,row*290+8), 'Normal touch controls: '+name, fill=(241,217,222))
            sheet.paste(screenshot,(20,row*290+30))
        sheet.save(output/'contacts/runtime_normal_combat.jpg',quality=90,optimize=True)
        return {'video':'normal_combat_smoke.mp4','touchInputsExecuted':True,
                'note':'Actual gameplay capture for manual review; inputs alone do not prove every attempted strike hit.'}
    except (OSError,subprocess.SubprocessError,RuntimeError) as error:
        if process.poll() is None: process.terminate()
        return {'warning':str(error),'touchInputsExecuted':bool(images)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path("runtime-review"))
    parser.add_argument("--serial")
    parser.add_argument("--no-video", action="store_true")
    args = parser.parse_args()
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    screenshots = output / "screenshots"
    screenshots.mkdir(exist_ok=True)
    android = Android(args.serial)
    records = []
    summary = {"version": "1.7.0", "package": PACKAGE, "expectedReviewFrames": 180,
               "capturedFrames": 0, "passed": False, "manualVisualReviewRequired": True,
               "scope": "Actual Android GameView rendering at fixed frame indices; menu and normal gameplay also captured"}
    try:
        android.run("wait-for-device")
        android.run("shell", "wm", "size", "720x1280")
        android.run("shell", "settings", "put", "system", "accelerometer_rotation", "0")
        android.run("shell", "settings", "put", "system", "user_rotation", "1")
        android.run("shell", "input", "keyevent", "82")
        android.run("install", "-r", str(args.apk), timeout=180)
        android.run("logcat", "-c")
        android.start(fresh=True)
        time.sleep(1.6)
        menu = android.screenshot(screenshots / "normal_menu.png")
        # New Game is initially selected; the real menu transition loads the
        # real gameplay view instead of a debug-only alternate scene.
        android.run("shell", "input", "keyevent", "66")
        time.sleep(1.0)
        gameplay = android.screenshot(screenshots / "normal_gameplay.png")
        overview = Image.new("RGB", (960, 580), (20, 18, 23))
        draw = ImageDraw.Draw(overview)
        for row, (label, image) in enumerate((("Normal menu", menu), ("Normal gameplay", gameplay))):
            image.thumbnail((900, 255), Image.Resampling.LANCZOS)
            draw.text((20, row * 290 + 8), label, fill=(241, 217, 222))
            overview.paste(image, (20, row * 290 + 30))
        (output / "contacts").mkdir(exist_ok=True)
        overview.save(output / "contacts/runtime_menu_gameplay.jpg", quality=92, optimize=True)
        if not args.no_video:
            summary['normalCombatSmoke'] = capture_normal_combat(android, output, gameplay.size)
        for index, (state, direction, frame) in enumerate(review_frames()):
            android.start(state, direction, frame, fresh=index == 0)
            time.sleep(0.18)
            name = f"{state}_{DIRECTIONS[direction]}_{frame:02d}.png"
            image = android.screenshot(screenshots / name)
            crop = subject_crop(image, state)
            colors = Counter(crop.getdata())
            if len(colors) < 20:
                raise ValueError(f"No rendered sprite detail for {name}: only {len(colors)} RGB colors")
            records.append({"state": state, "direction": direction, "frame": frame, "screenshot": name,
                            "dimensions": list(image.size), "subjectRGBColors": len(colors),
                            "subjectPixelSha256": hashlib.sha256(crop.tobytes()).hexdigest()})
            print(f"Captured {index + 1}/180: {name}", flush=True)
        if len(records) != 180:
            raise ValueError(f"Expected 180 runtime captures, received {len(records)}")
        summary["contacts"] = contact_sheets(output, records, screenshots)
        logcat = android.run("logcat", "-d", "-v", "threadtime", timeout=45)
        (output / "logcat.txt").write_text(logcat, encoding="utf-8")
        if not re.search(r"VEILBREAKERS_ASSETS.*v1\.7 loaded: kael_v17=120 enemy_v17=52 fx_v17=8", logcat):
            raise ValueError("Runtime did not confirm loading all 180 v1.7 sprites")
        for record in records:
            expected = f"{record['state']} direction={record['direction']} frame={record['frame']}"
            if not any("VEILBREAKERS_REVIEW" in line and expected in line for line in logcat.splitlines()):
                raise ValueError(f"Android did not acknowledge review state: {expected}")
        if "FATAL EXCEPTION" in logcat or "Missing runtime sprite" in logcat:
            raise ValueError("Android logcat contains a crash or a missing runtime sprite")
        warnings = []
        hashes = {}
        for record in records:
            key = (record["state"], record["direction"], record["subjectPixelSha256"])
            if key in hashes:
                warnings.append({"sameRenderedSubject": [hashes[key], record["screenshot"]]})
            hashes[key] = record["screenshot"]
        summary.update(passed=True, capturedFrames=len(records), androidLoadedRuntimeFrames=180,
                       records=records, warnings=warnings, landscapeDimensions=list(gameplay.size),
                       apkSha256=hashlib.sha256(args.apk.read_bytes()).hexdigest())
        if not args.no_video:
            summary["videoWarning"] = capture_video(android, output)
        final_log = android.run("logcat", "-d", "-v", "threadtime", timeout=45)
        (output / "logcat.txt").write_text(final_log, encoding="utf-8")
        if "FATAL EXCEPTION" in final_log:
            raise ValueError("Android crashed during animated playback review")
    except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        summary.update(passed=False, error=str(error), capturedFrames=len(records), records=records)
        try:
            (output / "logcat.txt").write_text(android.run("logcat", "-d", "-v", "threadtime"), encoding="utf-8")
        except (OSError, subprocess.SubprocessError):
            pass
    finally:
        (output / "runtime_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in summary.items() if key not in ("records", "contacts")}), flush=True)
    if not summary["passed"]:
        parser.exit(1, "Runtime review failed: " + summary.get("error", "unknown error") + "\n")


if __name__ == "__main__":
    main()
