#!/usr/bin/env python3
"""Review v1.8 gameplay scenes and all 180 authored frames in a CI emulator.

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
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw

PACKAGE = "com.veilbreakers.prototype"
ACTIVITY = PACKAGE + "/.MainActivity"
DIRECTIONS = ("down", "up", "left", "right")
DIRECTED = (("idle", 4), ("walk", 6), ("run", 6), ("combo1", 3), ("combo2", 3),
            ("combo3", 3), ("cast", 5), ("enemy_idle", 3), ("enemy_chase", 4), ("enemy_attack", 4))
UNDIRECTED = (("hurt", 3), ("death", 5), ("orb", 8))
GAMEPLAY_SCENES = ("map", "map1", "map2", "map3", "map4", "map5", "status", "journal", "dialogue")


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

    def start_scene(self, scene):
        output = self.run("shell", "am", "start", "-W", "--activity-single-top", "-n", ACTIVITY,
                          "--ez", "gameplay_review", "true", "--es", "review_scene", scene)
        if "Error:" in output or "Exception" in output:
            raise RuntimeError("Gameplay review launch failed: " + output)

    def screenshot(self, path):
        result = subprocess.run(self.prefix + ["exec-out", "screencap", "-p"],
                                check=True, capture_output=True, timeout=45)
        image = Image.open(BytesIO(result.stdout)).convert("RGB")
        image.load()
        if image.width <= image.height or image.width < 640 or image.height < 360:
            raise ValueError(f"Expected landscape Android rendering, received {image.size}")
        if max(image.getextrema()[channel][1] for channel in range(3)) < 80:
            raise ValueError("Screenshot is blank or the app failed to render")
        # The API 29 fullscreen hint is a large flat teal overlay. It obscured
        # the previous review despite producing nonblank, colorful captures.
        sample = image.resize((160, 90), Image.Resampling.NEAREST)
        teal = sum(r < 35 and 105 < g < 160 and 95 < b < 150 and abs(g - b) < 35
                   for r, g, b in sample.getdata())
        if teal / (160 * 90) > .03:
            raise ValueError("Android fullscreen hint or a large teal system overlay obscures the screenshot")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(result.stdout)
        return image

    def reject_fullscreen_hint(self):
        path = "/sdcard/veilbreakers_review_ui.xml"
        self.run("shell", "uiautomator", "dump", path, timeout=25, check=False)
        document = self.run("shell", "cat", path, check=False)
        if "viewing full screen" in document.lower() or "to exit, swipe down" in document.lower():
            raise ValueError("The Android immersive confirmation is still visible; review screenshots are invalid")

    def saved_game(self):
        document = self.run("shell", "run-as", PACKAGE, "cat", "shared_prefs/veilbreakers_save.xml")
        values = {}
        for element in ET.fromstring(document):
            value = element.get("value", element.text or "")
            if element.tag == "boolean": value = value == "true"
            elif element.tag in ("int", "long"): value = int(value)
            elif element.tag == "float": value = float(value)
            values[element.get("name")] = value
        return values


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
    remote = "/sdcard/veilbreakers_v18_review.mp4"
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


def capture_normal_combat(android, output, dimensions, record_video=True):
    """Collect the sword, reload the save, enter the square and use real combat controls."""
    width, height = dimensions
    remote = '/sdcard/veilbreakers_v18_combat.mp4'
    process = None
    if record_video:
        process = subprocess.Popen(android.prefix + ['shell', 'screenrecord', '--time-limit', '35',
                                   '--bit-rate', '3000000', remote], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    images = []
    def snap(name):
        path = output / 'screenshots' / ('normal_' + name + '.png')
        images.append((name, android.screenshot(path)))

    def checkpoint():
        # Home invokes the real Activity pause/save path in the isolated emulator.
        android.run('shell', 'input', 'keyevent', '3')
        time.sleep(.18)
        values = android.saved_game()
        android.start()
        return values

    def walk_to(target):
        values = checkpoint()
        x = float(values.get('player_x_norm', .20))
        delta = (target - x) * width
        if abs(delta) < height * .06:
            return
        direction = 1 if delta > 0 else -1
        joyx, joyy, radius = width * .13, height * .79, height * .14
        duration = min(6000, max(100, round(abs(delta) / (height * .39) * 1000 + 110)))
        android.run('shell', 'input', 'swipe', str(round(joyx + direction * radius * .96)), str(round(joyy)),
                    str(round(joyx + direction * radius)), str(round(joyy)), str(duration))

    def tap(x, y):
        android.run('shell', 'input', 'tap', str(round(width*x)), str(round(height*y)))

    try:
        walk_to(.43)
        snap('approach_sword')
        tap(.515, .875)
        for _ in range(4):
            tap(.5, .8)
            time.sleep(.12)
        values = checkpoint()
        if not values.get('story_sword_found') or not values.get('story_intro_seen'):
            raise ValueError('Real controls did not complete the opening and recover the sword')
        snap('sword_recovered')
        android.run('shell', 'am', 'force-stop', PACKAGE)
        android.start(fresh=True)
        time.sleep(.45)
        android.run('shell', 'input', 'keyevent', '20')
        android.run('shell', 'input', 'keyevent', '66')
        time.sleep(.45)
        restored = checkpoint()
        if not restored.get('story_sword_found') or not restored.get('story_intro_seen') or restored.get('world_zone') != 0:
            raise ValueError('Continue did not restore the real campaign save after process restart')
        snap('continued_campaign')
        walk_to(.92)
        tap(.515, .875)
        time.sleep(.30)
        entered = checkpoint()
        if entered.get('world_zone') != 1:
            raise ValueError('The recovered sword did not unlock the real route into the central square')
        snap('entered_central_square')
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
        if process is not None:
            process.communicate(timeout=45)
            android.run('pull', remote, str(output/'normal_combat_smoke.mp4'))
        sheet = Image.new('RGB', (960, 290*len(images)), (20,18,23))
        draw = ImageDraw.Draw(sheet)
        for row, (name, screenshot) in enumerate(images):
            screenshot.thumbnail((900,255),Image.Resampling.LANCZOS)
            draw.text((20,row*290+8), 'Normal touch controls: '+name, fill=(241,217,222))
            sheet.paste(screenshot,(20,row*290+30))
        sheet.save(output/'contacts/runtime_normal_combat.jpg',quality=90,optimize=True)
        return {'video':'normal_combat_smoke.mp4' if record_video else None,'touchInputsExecuted':True,
                'openingCompleted':True,'swordRecovered':True,'saveReloadChecked':True,'centralSquareEntered':True,
                'note':'Actual gameplay capture for manual review; inputs alone do not prove every attempted strike hit.'}
    finally:
        if process is not None and process.poll() is None: process.terminate()


def capture_gameplay_scenes(android, output):
    scenes = []
    sheet = Image.new("RGB", (960, 290 * len(GAMEPLAY_SCENES)), (20, 18, 23))
    draw = ImageDraw.Draw(sheet)
    for row, scene in enumerate(GAMEPLAY_SCENES):
        android.start_scene(scene)
        time.sleep(0.45)
        name = f"gameplay_{scene}.png"
        screenshot = android.screenshot(output / "screenshots" / name)
        scenes.append({"scene": scene, "screenshot": name, "dimensions": list(screenshot.size)})
        preview = screenshot.copy()
        preview.thumbnail((900, 255), Image.Resampling.LANCZOS)
        draw.text((20, row * 290 + 8), "Actual gameplay renderer: " + scene, fill=(241, 217, 222))
        sheet.paste(preview, (20, row * 290 + 30))
    sheet.save(output / "contacts/runtime_gameplay_scenes.jpg", quality=92, optimize=True)
    return scenes


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
    summary = {"version": "1.8.0", "versionCode": 22, "package": PACKAGE, "expectedReviewFrames": 180,
               "capturedFrames": 0, "passed": False, "manualVisualReviewRequired": True,
               "scope": "Actual Android GameView rendering at fixed frame indices; menu and normal gameplay also captured"}
    try:
        android.run("wait-for-device")
        if android.run("shell", "getprop", "ro.kernel.qemu").strip() != "1":
            raise ValueError("This automated review is restricted to an Android emulator")
        android.run("shell", "wm", "size", "720x1280")
        android.run("shell", "settings", "put", "system", "accelerometer_rotation", "0")
        android.run("shell", "settings", "put", "system", "user_rotation", "1")
        # Android CTS uses this setting to prevent the first-fullscreen system
        # hint from covering application screenshots. Only the CI emulator is changed.
        android.run("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
        android.run("shell", "input", "keyevent", "82")
        android.run("install", "-r", str(args.apk), timeout=180)
        android.run("logcat", "-c")
        android.start(fresh=True)
        time.sleep(1.6)
        menu = android.screenshot(screenshots / "normal_menu.png")
        android.reject_fullscreen_hint()
        # New Game is initially selected; the real menu transition loads the
        # real gameplay view instead of a debug-only alternate scene.
        android.run("shell", "input", "keyevent", "66")
        time.sleep(1.0)
        opening = android.screenshot(screenshots / "normal_initial_dialogue.png")
        for _ in range(8):
            android.run("shell", "input", "tap", str(round(opening.width * .5)),
                        str(round(opening.height * .8)))
            time.sleep(.12)
        gameplay = android.screenshot(screenshots / "normal_gameplay.png")
        landscape_dimensions = gameplay.size
        overview = Image.new("RGB", (960, 580), (20, 18, 23))
        draw = ImageDraw.Draw(overview)
        for row, (label, image) in enumerate((("Normal menu", menu), ("Normal gameplay", gameplay))):
            preview = image.copy()
            preview.thumbnail((900, 255), Image.Resampling.LANCZOS)
            draw.text((20, row * 290 + 8), label, fill=(241, 217, 222))
            overview.paste(preview, (20, row * 290 + 30))
        (output / "contacts").mkdir(exist_ok=True)
        overview.save(output / "contacts/runtime_menu_gameplay.jpg", quality=92, optimize=True)
        summary['normalCombatSmoke'] = capture_normal_combat(android, output, landscape_dimensions, not args.no_video)
        summary["gameplayScenes"] = capture_gameplay_scenes(android, output)
        android.start_scene("selftest")
        time.sleep(.6)
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
        if not re.search(r"VEILBREAKERS_ASSETS.*v1\.8 loaded: kael_v17=96 kael_v18_run=24 enemy_v17=52 fx_v17=8", logcat):
            raise ValueError("Runtime did not confirm loading all 180 v1.8 sprites")
        for scene in GAMEPLAY_SCENES:
            if not re.search(r"VEILBREAKERS_SCENE.*scene=" + scene + r"\b", logcat):
                raise ValueError("Android did not acknowledge gameplay review scene: " + scene)
        if not re.search(r"VEILBREAKERS_GAMEPLAY_TEST.*passed:", logcat):
            raise ValueError("The real GameView reward/pause/combat regression checks did not pass")
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
                       realGameplayRegressionChecksPassed=True,
                       records=records, warnings=warnings, landscapeDimensions=list(landscape_dimensions),
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
