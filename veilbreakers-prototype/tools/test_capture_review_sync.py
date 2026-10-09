#!/usr/bin/env python3
"""Prevent stale Android surfaces or setter acknowledgements passing visual QA."""
from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw
from capture_android_review import Android, java_token_hash, scene_stamp


def screen(bits):
    image = Image.new("RGB", (800, 450), (85, 45, 30))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 445, 5, 448), fill=(0, 255, 255))
    for bit in range(32):
        value = 230 if (bits >> (31 - bit)) & 1 else 15
        draw.rectangle((8 + bit * 2, 445, 9 + bit * 2, 448), fill=(value,) * 3)
    data = BytesIO()
    image.save(data, "PNG")
    return data.getvalue()


class RenderSynchronizationTest(unittest.TestCase):
    def test_waits_for_current_draw_token_for_gameplay_and_art(self):
        for art in (False, True):
            android = Android("ci-emulator")
            scene = "art_cast_3_2" if art else "map6"
            commands = []
            logs = iter((
                f"I/VEILBREAKERS_SCENE_RENDERED: scene={scene} token=stale",
                f"I/VEILBREAKERS_SCENE: scene={scene} token=Aa",
                f"I/VEILBREAKERS_SCENE_RENDERED: scene={scene} token=Aa",
            ))

            def run(*args, **kwargs):
                commands.append(args)
                return next(logs) if args[0] == "logcat" else "Status: ok"

            with patch.object(android, "run", side_effect=run), patch("capture_android_review.uuid.uuid4", return_value="Aa"), patch("capture_android_review.time.sleep"):
                token = android.start("cast", 3, 2) if art else android.start_scene("map6")
            self.assertEqual(token, "Aa")
            self.assertEqual(sum(command[0] == "logcat" for command in commands), 3)
            self.assertIn("review_token", commands[0])

    def test_stale_gpu_surface_is_retried_and_current_hash_proven(self):
        # Aa and BB have Java's documented polynomial hash 2112.
        self.assertEqual(java_token_hash("Aa"), 2112)
        self.assertEqual(java_token_hash("BB"), 2112)
        results = [subprocess.CompletedProcess([], 0, screen(bits)) for bits in (0x12345678, 2112)]
        with tempfile.TemporaryDirectory() as directory, patch("capture_android_review.subprocess.run", side_effect=results) as run, patch("capture_android_review.time.sleep"):
            image = Android(None).screenshot(Path(directory) / "map.png", expected_token="Aa")
            self.assertEqual(run.call_count, 2)
            self.assertEqual(scene_stamp(image), 2112)

    def test_stale_gpu_surface_never_becomes_a_pass(self):
        result = subprocess.CompletedProcess([], 0, screen(0x12345678))
        with tempfile.TemporaryDirectory() as directory, patch("capture_android_review.subprocess.run", return_value=result) as run, patch("capture_android_review.time.sleep"):
            path = Path(directory) / "inventory.png"
            with self.assertRaisesRegex(ValueError, "stamp missing/mismatched"):
                Android(None).screenshot(path, expected_token="Aa")
            self.assertEqual(run.call_count, 3)
            self.assertFalse(path.exists())
            self.assertTrue(path.with_name("inventory_failed.png").is_file())


if __name__ == "__main__":
    unittest.main()
