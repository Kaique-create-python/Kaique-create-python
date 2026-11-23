#!/usr/bin/env python3
"""Pack the licensed Capri Desktop sprite strips into Roblox-sized PNG atlases."""

import argparse
from collections.abc import Callable
from contextlib import ExitStack
from dataclasses import dataclass
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile

from PIL import Image


PROJECT = Path(__file__).resolve().parents[1]
SOURCE = "https://github.com/lachydotmcg/capri-desktop"
COMMIT = "60df4a9fea49348faa5b839541a563cffbbeb582"
LICENSE_FILES = ("LICENSE.md", "THIRD-PARTY-NOTICES.md")
GUTTER = 2
ATLAS_LIMIT = 1024
BODY_SIZE = (142, 200)
BODY_ORIGIN = (73, 96)
BODY_SCALE = 7 / 16
EFFECT_SIZE = (64, 64)
BODY_PITCH = tuple(size + 2 * GUTTER for size in BODY_SIZE)
EFFECT_PITCH = tuple(size + 2 * GUTTER for size in EFFECT_SIZE)
BODY_COLUMNS, BODY_ROWS = (ATLAS_LIMIT // pitch for pitch in BODY_PITCH)
EFFECT_COLUMNS, EFFECT_ROWS = (
    body // effect for body, effect in zip(BODY_PITCH, EFFECT_PITCH)
)
EFFECTS_PER_CELL = EFFECT_COLUMNS * EFFECT_ROWS


@dataclass(frozen=True)
class Pose:
    scale: float
    shift_x: float = 0
    shift_y: float = 0


# DrawImage placement from app/Capri.cs, expressed in 384 px desktop units.
STANDING = Pose(1.11)
IDLE = Pose(1.11, 11 * 1.11)
PERCH = Pose(1, -26, 36)
LIE_SCALE = 0.85
LIE_SHIFT_Y = (0.79 - 0.5) * (1 - LIE_SCALE) * 384 + 94 * LIE_SCALE
LAYDOWN = Pose(LIE_SCALE, 0, LIE_SHIFT_Y)
POINTER = Pose(1)


@dataclass(frozen=True)
class Clip:
    name: str
    cell_size: tuple[int, int]
    source_count: int
    source_fps: int
    pose: Pose = STANDING
    sample_count: int | None = None
    # Quadros mais largos que a tela do corpo (saída e glitch deitada): recorta a sobra em vez de falhar.
    crop_overflow: bool = False


# Keep each clip on one page, with the modern idle/perch and their blinks together.
# Body cell counts and timings come from app/Capri.cs and cross/Pet.cs.
# Pointer click comes from app/Talk.cs, and goes after the body cells on its page.
ATLAS_CLIPS = (
    (
        Clip("perch", (196, 384), 60, 30, PERCH, 26),
        Clip("perch_blink", (196, 384), 8, 30, PERCH),
    ),
    (
        Clip("idle", (116, 384), 60, 24, IDLE, 25),
        Clip("idle_blink", (116, 384), 8, 24, IDLE),
    ),
    (
        Clip("arrive", (240, 384), 14, 15),
        Clip("leave", (240, 384), 12, 15),
        Clip("glitch", (240, 384), 10, 15),
    ),
    (
        Clip("perch_arrive", (288, 384), 14, 15, PERCH),
        Clip("perch_leave", (288, 384), 12, 15, PERCH),
        Clip("laydown_blink", (372, 250), 8, 30, LAYDOWN),
    ),
    (
        Clip("laydown", (372, 250), 60, 30, LAYDOWN, 18),
        Clip("dangle", (240, 384), 24, 10),
    ),
    (
        Clip("laydown_sleep", (372, 250), 60, 30, LAYDOWN, 18),
        Clip("sleep", (240, 384), 16, 6),
    ),
    (
        Clip("grin", (240, 384), 16, 8),
        Clip("dance", (240, 384), 16, 16),
    ),
    (
        Clip("wake", (240, 384), 13, 15),
        Clip("walk", (240, 384), 12, 12),
        Clip("blink", (240, 384), 4, 8),
        Clip("click", (144, 144), 20, 60, POINTER),
    ),
    # Reações novas (v3): ouvindo música e falando sentada, falando deitada, os glitches de cada pose,
    # a saída deitada, as piscadas com glitch e a boca falando em pé. Contagens e taxas de app/Capri.cs.
    (
        Clip("perch_music", (196, 384), 60, 30, PERCH, 26),
        Clip("perch_blink_glitch", (196, 384), 8, 30, PERCH),
    ),
    (
        Clip("perch_talk", (196, 384), 60, 30, PERCH, 20),
        Clip("perch_glitch", (288, 384), 10, 15, PERCH),
        Clip("idle_mouth", (116, 384), 5, 12, IDLE),
    ),
    (
        Clip("laydown_talk", (372, 250), 60, 30, LAYDOWN, 18),
        Clip("laydown_leave", (440, 250), 12, 15, LAYDOWN, crop_overflow=True),
        Clip("blink_glitch", (240, 384), 4, 8),
    ),
    (
        Clip("laydown_glitch", (440, 250), 10, 15, LAYDOWN, crop_overflow=True),
        Clip("laydown_blink_glitch", (372, 250), 8, 30, LAYDOWN),
        Clip("idle_blink_glitch", (116, 384), 8, 24, IDLE),
        Clip("mouth", (240, 384), 5, 12),
    ),
)


def clip_frames(clip: Clip, raw: bytes, indices: list[int]):
    width, height = clip.cell_size
    expected = (width * clip.source_count, height)
    with Image.open(BytesIO(raw)) as source:
        if source.size != expected:
            raise ValueError(f"{clip.name}.png measures {source.size}, expected {expected}")
        strip = source.convert("RGBA")

    if clip.pose is POINTER:
        canvas_size = EFFECT_SIZE
        origin_x = EFFECT_SIZE[0] / 2
        origin_y = EFFECT_SIZE[1] / 2
    else:
        canvas_size = BODY_SIZE
        origin_x, origin_y = BODY_ORIGIN
    scale = clip.pose.scale * BODY_SCALE
    size = (round(width * scale), round(height * scale))
    left = round(origin_x + clip.pose.shift_x * BODY_SCALE - size[0] / 2)
    top = round(origin_y + clip.pose.shift_y * BODY_SCALE - size[1] / 2)

    for index in indices:
        sprite = strip.crop((index * width, 0, (index + 1) * width, height))
        sprite = sprite.resize(size, Image.Resampling.LANCZOS)
        bounds = sprite.getchannel("A").getbbox()
        if bounds and not clip.crop_overflow and (
            left + bounds[0] < 0
            or top + bounds[1] < 0
            or left + bounds[2] > canvas_size[0]
            or top + bounds[3] > canvas_size[1]
        ):
            raise ValueError(f"{clip.name} frame {index + 1} extends beyond its canvas")

        canvas = Image.new("RGBA", canvas_size)
        canvas.paste(sprite, (left, top))
        yield canvas


def pack_atlas(group: tuple[Clip, ...], asset_key: str, read: Callable[[str], bytes]):
    atlas = Image.new("RGBA", (ATLAS_LIMIT, ATLAS_LIMIT))
    placements = {}
    clips = {}
    body_cells = effect_cells = used_width = used_height = 0

    for clip in group:
        path = f"assets/sprites/{clip.name}.png"
        raw = read(path)
        count = clip.sample_count or clip.source_count
        indices = [index * clip.source_count // count for index in range(count)]
        is_effect = clip.pose is POINTER
        frames = []

        for sprite in clip_frames(clip, raw, indices):
            digest = sha256(sprite.tobytes()).digest()
            if digest not in placements:
                if is_effect:
                    cell = body_cells + effect_cells // EFFECTS_PER_CELL
                    subcell = effect_cells % EFFECTS_PER_CELL
                    dx = subcell % EFFECT_COLUMNS * EFFECT_PITCH[0]
                    dy = subcell // EFFECT_COLUMNS * EFFECT_PITCH[1]
                    effect_cells += 1
                else:
                    cell = body_cells
                    dx = dy = 0
                    body_cells += 1

                if cell >= BODY_COLUMNS * BODY_ROWS:
                    raise ValueError(f"{asset_key} ran out of space for {clip.name}")
                x = cell % BODY_COLUMNS * BODY_PITCH[0] + GUTTER + dx
                y = cell // BODY_COLUMNS * BODY_PITCH[1] + GUTTER + dy
                atlas.paste(sprite, (x, y))
                w, h = sprite.size
                placements[digest] = {"assetKey": asset_key, "x": x, "y": y, "w": w, "h": h}
                used_width = max(used_width, x + w + GUTTER)
                used_height = max(used_height, y + h + GUTTER)
            frames.append(placements[digest])

        clips[clip.name] = {
            "fps": clip.source_fps * count / clip.source_count,
            "kind": "effect" if is_effect else "body",
            "frames": frames,
            "source": {
                "path": path,
                "sha256": sha256(raw).hexdigest(),
                "count": clip.source_count,
                "fps": clip.source_fps,
                "cell": {"w": clip.cell_size[0], "h": clip.cell_size[1]},
                "sampleIndices": indices,
            },
        }

    return atlas.crop((0, 0, used_width, used_height)), clips


def prepare(source: Path, output: Path) -> None:
    provenance = {
        "source": SOURCE,
        "commit": COMMIT,
        "license": "PolyForm Noncommercial 1.0.0",
        "notices": list(LICENSE_FILES),
        "bodyCanvas": {"w": BODY_SIZE[0], "h": BODY_SIZE[1], "origin": list(BODY_ORIGIN)},
        "effectCanvas": {"w": EFFECT_SIZE[0], "h": EFFECT_SIZE[1]},
        "artScale": BODY_SCALE,
        "transparentGutter": GUTTER,
    }
    manifest = {"clips": {}, "images": {}, "provenance": provenance}
    output.parent.mkdir(parents=True, exist_ok=True)

    with ExitStack() as stack:
        staging = Path(stack.enter_context(TemporaryDirectory(dir=output.parent)))
        if source.is_dir():
            def read(path: str) -> bytes:
                return (source / path).read_bytes()
        else:
            archive = stack.enter_context(ZipFile(source))
            read = archive.read

        for filename in LICENSE_FILES:
            (staging / filename).write_bytes(read(filename))

        for index, group in enumerate(ATLAS_CLIPS, start=1):
            key = f"capri_{index:02d}"
            atlas, clips = pack_atlas(group, key, read)
            filename = f"{key}.png"
            atlas.save(staging / filename, optimize=True)
            manifest["images"][key] = f"media/capri/{filename}"
            manifest["clips"].update(clips)

        output.mkdir(parents=True, exist_ok=True)
        (staging / "capri_clips.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        for filename in (*LICENSE_FILES, *(f"{key}.png" for key in manifest["images"])):
            (staging / filename).replace(output / filename)
        (staging / "capri_clips.json").replace(output / "capri_clips.json")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        required=True,
        help="pinned Capri Desktop checkout or CyberOutlaw-Capri-Assets.zip",
    )
    parser.add_argument("--output", type=Path, default=PROJECT / "media" / "capri")
    args = parser.parse_args()
    prepare(args.source, args.output)


if __name__ == "__main__":
    main()
