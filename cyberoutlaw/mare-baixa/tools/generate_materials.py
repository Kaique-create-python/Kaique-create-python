"""Generate the original, tileable Maré Baixa materials with NumPy, SciPy and Pillow."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, zoom


OUTPUT = Path(__file__).resolve().parents[1] / "materials"
Array = np.ndarray
Material = tuple[Array, Array, Array, Array | None]


class Surface:
    def __init__(self, size: int, seed: int):
        self.size = size
        self.rng = np.random.default_rng(seed)
        coord = np.arange(size, dtype=np.float32) / size
        self.x = coord[None, :]
        self.y = coord[:, None]

    def noise(self, columns: int, rows: int | None = None) -> Array:
        rows = rows or columns
        samples = self.rng.standard_normal((rows, columns), dtype=np.float32)
        return zoom(
            samples,
            (self.size / rows, self.size / columns),
            order=3,
            mode="grid-wrap",
            grid_mode=True,
        )

    def blocks(self, columns: int, rows: int, stagger: bool = False):
        row = np.floor(self.y * rows).astype(np.int32)
        horizontal = self.x * columns + (row % 2) * (0.5 if stagger else 0.0)
        column = np.floor(horizontal).astype(np.int32)
        center_x = horizontal % 1 - 0.5
        center_y = self.y * rows % 1 - 0.5
        return center_x, center_y, row % rows, column % columns

    def points(self, x: Array, y: Array, places: list[tuple[float, float]]) -> Array:
        distance = np.full((self.size, self.size), np.inf, dtype=np.float32)
        for point_x, point_y in places:
            dx = (x - point_x + 0.5) % 1 - 0.5
            dy = (y - point_y + 0.5) % 1 - 0.5
            distance = np.minimum(distance, np.hypot(dx, dy))
        return distance * self.size

    def cracks(self, paths: list[list[tuple[float, float]]]) -> Array:
        canvas = Image.new("L", (self.size, self.size))
        draw = ImageDraw.Draw(canvas)
        for path in paths:
            for offset_x in (-1, 0, 1):
                for offset_y in (-1, 0, 1):
                    draw.line(
                        [
                            (
                                round((x + offset_x) * self.size),
                                round((y + offset_y) * self.size),
                            )
                            for x, y in path
                        ],
                        fill=255,
                        width=max(1, round(self.size / 600)),
                    )
        mask = np.asarray(canvas, dtype=np.float32) / 255
        return gaussian_filter(mask, 0.55 * self.size / 1024, mode="wrap")


def smooth(low: float, high: float, value: Array) -> Array:
    amount = np.clip((value - low) / (high - low), 0, 1)
    return amount * amount * (3 - 2 * amount)


def color(rgb: tuple[int, int, int], level: Array) -> Array:
    return np.asarray(rgb, dtype=np.float32) + level[..., None]


def tint(base: Array, rgb: tuple[int, int, int], amount: Array) -> Array:
    return base + (np.asarray(rgb, dtype=np.float32) - base) * amount[..., None]


def rounded_box(x: Array, y: Array, width: float, height: float, radius: float) -> Array:
    dx = np.abs(x) - width / 2 + radius
    dy = np.abs(y) - height / 2 + radius
    return np.hypot(np.maximum(dx, 0), np.maximum(dy, 0)) + np.minimum(np.maximum(dx, dy), 0) - radius


def asphalt(s: Surface) -> Material:
    cloud = s.noise(7)
    grit = s.noise(255)
    grit_fine = s.noise(530)
    clumps = s.noise(72)
    pits = smooth(0.95, 2.05, -grit)
    stone = smooth(0.30, 1.65, grit + clumps * 0.23)
    flecks = smooth(1.45, 2.8, grit_fine + grit * 0.35)
    wet = smooth(0.1, 1.65, cloud + s.noise(23) * 0.28)
    cracks = s.cracks([
        [(0.14, 0.37), (0.17, 0.39), (0.18, 0.42), (0.212, 0.437), (0.223, 0.46), (0.26, 0.47), (0.275, 0.501)],
        [(0.18, 0.42), (0.164, 0.446), (0.176, 0.461), (0.152, 0.488)],
        [(0.68, 0.78), (0.698, 0.807), (0.69, 0.83), (0.72, 0.852), (0.729, 0.88)],
        [(0.69, 0.83), (0.67, 0.839), (0.65, 0.868)],
        [(0.95, 0.16), (0.979, 0.185), (0.992, 0.182), (1.011, 0.221), (1.045, 0.233)],
    ])
    salt = smooth(0.8, 1.7, s.noise(31) + flecks * 0.5)
    level = 5 * cloud + 4 * clumps + 20 * stone - 13 * pits + 15 * flecks - 17 * wet - 22 * cracks
    base = tint(color((57, 61, 67), level), (107, 103, 94), salt * flecks * 0.28)
    height = (2.4 * stone - 1.1 * pits + 0.45 * grit_fine + 0.45 * clumps) * (1 - 0.62 * wet) - 2.0 * cracks
    rough = 0.80 + 0.08 * pits - 0.10 * stone - 0.43 * wet + 0.044 * grit_fine
    return base, height, rough, None


def cement(s: Surface) -> Material:
    center_x, center_y, row, column = s.blocks(2, 2)
    cloud = s.noise(15)
    coarse = s.noise(41)
    pore_noise = s.noise(280)
    pores = smooth(1.00, 2.35, pore_noise + 0.25 * coarse)
    dark_spots = smooth(0.75, 1.95, -cloud + 0.26 * coarse)
    streaks = 0.58 * s.noise(93, 7) + 0.42 * s.noise(191, 15)
    streaks *= 0.48 + 0.52 * smooth(-1.0, 1.7, s.noise(8, 16))
    panel_light = np.array([[4, -5], [-2, 2]], dtype=np.float32)[row, column]
    joint_x = (0.5 - np.abs(center_x)) * s.size / 2 - 0.62 * coarse
    joint_y = (0.5 - np.abs(center_y)) * s.size / 2 + 0.54 * coarse
    joint = 1 - smooth(0.65, 3.1, np.minimum(joint_x, joint_y))
    line = 1 - smooth(0.5, 1.1, np.abs(joint_y - 6.0))
    ties = s.points(
        s.x, s.y,
        [(x, y) for x in (0.10, 0.40, 0.60, 0.90) for y in (0.125, 0.375, 0.62, 0.875)],
    )
    tie_hole = 1 - smooth(3.7, 5.7, ties + 0.62 * coarse)
    tie_ring = smooth(4.1, 5.0, ties) * (1 - smooth(6.0, 9.4, ties + coarse))
    sea_salt = smooth(0.70, 1.85, s.noise(10, 22) + 0.32 * streaks) * (0.55 + 0.45 * dark_spots)
    level = panel_light + 10 * cloud + 4.4 * coarse + 7.2 * streaks - 22 * pores
    level += -19 * joint - 38 * tie_hole + 11 * tie_ring - 8 * dark_spots + 12 * sea_salt - 3 * line
    base = tint(color((110, 112, 111), level), (100, 91, 78), dark_spots * 0.18)
    height = 0.60 * coarse + 0.25 * streaks - 1.75 * pores - 2.7 * joint - 5.2 * tie_hole + 1.45 * tie_ring - 0.4 * line
    rough = 0.78 + 0.09 * pores + 0.03 * coarse + 0.10 * joint - 0.19 * dark_spots
    return base, height, rough, None


def sidewalk(s: Surface) -> Material:
    center_x, center_y, row, column = s.blocks(4, 4, stagger=True)
    cloudy = s.noise(12)
    fine = s.noise(247)
    micro = s.noise(460)
    edges = s.noise(66)
    distance = rounded_box(center_x * s.size / 4, center_y * s.size / 4, 248, 248, 6)
    distance += 1.10 * edges
    block = 1 - smooth(-3, 0.5, distance)
    bevel = 1 - smooth(-5.0, 0.8, distance)
    lip = smooth(-12.0, -6.5, distance) * bevel
    damp = smooth(-0.5, 1.6, cloudy + s.noise(38) * 0.42)
    grit = smooth(0.85, 2.5, fine)
    scuffs = smooth(0.9, 2.2, s.noise(27, 58))
    bloom = smooth(0.8, 2.15, s.noise(33) + fine * 0.28)
    slab_tone = s.rng.normal(0, 6, (4, 4)).astype(np.float32)[row, column]
    cracks = s.cracks([
        [(0.33, 0.385), (0.322, 0.424), (0.345, 0.452), (0.34, 0.476), (0.356, 0.5)],
        [(0.702, 0.785), (0.707, 0.802), (0.695, 0.834), (0.705, 0.847)],
    ]) * block
    level = slab_tone + 7 * cloudy + 4.5 * fine + 2.7 * micro - 18 * damp + 11 * scuffs + 9 * lip - 23 * cracks
    concrete = tint(color((105, 110, 113), level), (137, 134, 121), bloom * 0.22)
    mulch = smooth(0.05, 0.95, s.noise(36) + 0.22 * edges)
    seam = tint(color((50, 49, 47), micro * 7 + 8 * grit), (67, 73, 54), mulch * 0.61)
    base = seam + (concrete - seam) * bevel[..., None]
    height = 5.1 * bevel + (fine * 0.39 + micro * 0.27 - 1.3 * cracks) * block + (1 - block) * grit * 0.9
    rough = 0.90 - block * (0.14 + 0.28 * damp) + 0.05 * fine + 0.10 * cracks
    return base, height, rough, None


def glass(s: Surface) -> Material:
    center_x, center_y, row, column = s.blocks(3, 2)
    x = center_x + 0.5
    y = center_y + 0.5
    fine = s.noise(125)
    rain = s.noise(160, 11) * (0.42 + 0.58 * smooth(-1.1, 1.25, s.noise(8, 18)))
    tone = s.noise(15)
    cloud = s.noise(6)
    spandrel = smooth(0.765, 0.776, y)
    pane_tone = np.array([[4, -3, 6], [-6, 5, 0]], dtype=np.float32)[row, column]
    reflected_clouds = smooth(-0.24, 1.25, cloud + 0.29 * np.sin(2 * np.pi * (2 * s.x + s.y)))
    vertical_reflection = smooth(0.3, 1.5, s.noise(21, 3) + 0.23 * tone)
    glass_tone = pane_tone + 12 * reflected_clouds + 5.7 * vertical_reflection + 3.1 * rain + 1.32 * fine
    glazing = color((24, 41, 56), glass_tone)
    glazing = tint(glazing, (55, 65, 72), spandrel * 0.82)
    warm = (row == 0) & (column == 1)
    cool = (row == 1) & (column == 2)
    dim = (row == 0) & (column == 0)
    light = 0.66 * warm + 0.57 * cool + 0.18 * dim
    lit_panel = (1 - spandrel) * light
    overhead = np.exp(-((y - 0.16) / 0.21) ** 2 - ((x - 0.55) / 0.52) ** 2)
    rear_light = smooth(0.14, 0.18, x) * (1 - smooth(0.47, 0.49, x))
    rear_light *= smooth(0.18, 0.208, y) * (1 - smooth(0.28, 0.309, y))
    lit_window = color((150, 105, 59), 33 * overhead + 13 * rear_light + 4 * tone)
    lit_window = tint(lit_window, (102, 143, 148), cool * (0.82 + 0.1 * overhead))
    blinds = np.sin(y * 108 * np.pi) * 0.5 + 0.5
    blinds = blinds * (1 - smooth(0.36, 0.38, y)) * (0.32 + 0.42 * cool)
    desk = (1 - smooth(-0.005, 0.01, rounded_box(x - 0.58, y - 0.655, 0.69, 0.055, 0.004)))
    screen = 1 - smooth(-0.002, 0.005, rounded_box(x - 0.66, y - 0.594, 0.15, 0.073, 0.005))
    screen *= 0.70 + 0.30 * cool
    fixture = np.maximum(desk, screen) * 0.88
    lit_window = tint(lit_window, (39, 47, 52), blinds * 0.33 + fixture * 0.79)
    glazing += (lit_window - glazing) * lit_panel[..., None]
    frame_x = (0.5 - np.abs(center_x)) * s.size / 3
    frame_y = (0.5 - np.abs(center_y)) * s.size / 2
    transom = np.abs(y - 0.775) * s.size / 2
    center_mullion = np.abs(x - 0.52) * s.size / 3 + 3.5
    joint = np.minimum(np.minimum(frame_x, frame_y), np.minimum(transom + 1.0, center_mullion))
    gasket = 1 - smooth(6.6, 9.6, joint)
    frame = 1 - smooth(4.8, 6.7, joint)
    edge = smooth(2.0, 4.3, joint) * frame * 0.84
    frame_color = color((54, 62, 66), 3.4 * fine + 3.0 * rain + 19 * edge)
    base = tint(glazing, (17, 23, 30), gasket)
    base += (frame_color - base) * frame[..., None]
    height = 6.0 * frame - 1.2 * gasket + 0.10 * rain + 0.08 * fine
    rough = 0.17 + 0.07 * tone + 0.23 * spandrel + 0.23 * frame + 0.11 * gasket
    metal = 0.84 * frame
    return base, height, rough, metal


def steel(s: Surface) -> Material:
    phase = s.x * 12 % 1
    distance = np.abs(phase - 0.5)
    rib = 1 - smooth(0.153, 0.342, distance)
    step = 1 - smooth(0.43, 0.49, distance)
    channel = smooth(0.32, 0.42, distance) * step
    coarse = s.noise(34, 12)
    brushed = 0.60 * s.noise(260, 21) + 0.40 * s.noise(470, 78)
    grain = s.noise(240)
    groove = np.abs((s.y * 2 + 0.5) % 1 - 0.5) * s.size / 2
    seam = 1 - smooth(0.7, 3.8, groove)
    seam_edge = smooth(2.0, 3.8, groove) * (1 - smooth(4.5, 7.0, groove))
    studs = s.points(
        s.x, s.y,
        [(x, y) for x in (0.04167, 0.29167, 0.54167, 0.79167) for y in (0.016, 0.516)],
    )
    screw = 1 - smooth(2.4, 4.2, studs)
    screw_ring = smooth(2.8, 3.8, studs) * (1 - smooth(4.3, 6.3, studs))
    panel = (s.x * 4).astype(np.int32)
    panel_tone = np.array([2, -6, 5, -3], dtype=np.float32)[panel]
    rust_run = smooth(0.65, 1.65, s.noise(37, 13) + coarse * 0.48 + 0.16 * grain)
    rust_accent = (1 - smooth(6.0, 29.0, groove)) * smooth(-0.32, 1.1, coarse + 0.28 * grain)
    rust = np.clip(rust_run * (0.13 + 0.57 * channel) + rust_accent * 0.79 + 0.48 * screw_ring, 0, 1)
    scratches = smooth(1.10, 2.5, brushed + 0.24 * grain) * (0.45 + 0.55 * rib)
    level = panel_tone + 8 * coarse + 4 * brushed + 3 * grain + 14 * rib - 13 * seam + 12 * seam_edge + 27 * scratches
    base = tint(color((77, 92, 99), level), (120, 73, 50), rust * 0.77)
    base = tint(base, (137, 141, 137), screw * 0.86)
    height = 5.8 * rib + 0.8 * step - 1.3 * seam + 0.95 * seam_edge
    height = height + 0.32 * brushed + 0.12 * grain + 2.0 * screw - 0.8 * screw_ring
    rough = 0.38 + 0.12 * channel + 0.33 * rust + 0.045 * brushed - 0.09 * scratches
    metal = (0.73 + 0.19 * scratches + 0.10 * screw) * (1 - 0.91 * rust)
    return base, height, rough, metal


def brick(s: Surface) -> Material:
    center_x, center_y, row, column = s.blocks(8, 16, stagger=True)
    porous = s.noise(276)
    fine = s.noise(430)
    break_up = s.noise(130, 100)
    grain = s.noise(86, 170)
    large = s.noise(13)
    stain = smooth(-0.5, 1.7, large + 0.29 * s.noise(22, 13))
    unit_tones = s.rng.normal(0, 13, (16, 8)).astype(np.float32)[row, column]
    distance = rounded_box(center_x * 128, center_y * 64, 119.5, 57.5, 3.6) + 0.95 * break_up + 0.55 * porous
    face = 1 - smooth(-2.5, 1.2, distance)
    edge = smooth(-6.1, -3.0, distance) * face
    spall = smooth(0.75, 1.95, break_up + 0.33 * porous)
    soot = smooth(-0.30, 2.1, -unit_tones / 13 + 1.0 * stain + 0.35 * large)
    level = 9.4 * grain + 6.3 * porous + 2.7 * fine + unit_tones - 9 * stain + 12 * edge
    clay = tint(color((116, 79, 72), level), (65, 63, 64), soot * 0.55)
    clay = tint(clay, (145, 108, 86), spall * edge * 0.37)
    grout = tint(color((74, 73, 72), 8 * porous + 4 * fine), (59, 64, 61), stain * 0.43)
    base = grout + (clay - grout) * face[..., None]
    height = face * (4.7 + 0.52 * grain + 0.46 * porous - 0.8 * spall) + (1 - face) * (0.3 * fine + 0.5 * porous)
    rough = 0.88 - 0.13 * face + 0.05 * grain + 0.045 * spall - 0.12 * stain
    return base, height, rough, None


def roof(s: Surface) -> Material:
    center_x, center_y, row, column = s.blocks(3, 2, stagger=True)
    grain = s.noise(188)
    tar = s.noise(43, 21)
    cloud = s.noise(8)
    specks = smooth(0.8, 2.4, grain)
    worn = smooth(-0.60, 1.65, cloud + 0.23 * tar)
    stripe = (0.5 - np.abs(center_y)) * s.size / 2 + 0.7 * tar
    butt = (0.5 - np.abs(center_x)) * s.size / 3 + 0.60 * tar
    weld = np.maximum(1 - smooth(2.35, 4.6, stripe), 1 - smooth(1.5, 3.1, butt))
    bead = np.maximum(1 - smooth(0.38, 1.45, np.abs(stripe - 4.25)), 1 - smooth(0.45, 1.5, np.abs(butt - 3.2)))
    patch_edge = rounded_box((s.x - 0.72) * s.size, (s.y - 0.71) * s.size, 48, 24, 3) + 0.88 * grain
    patch = 1 - smooth(-1.5, 1.2, patch_edge)
    tone = np.array([[3, -4, -2], [-3, 5, 1]], dtype=np.float32)[row, column]
    level = tone + 4.1 * cloud + 5.0 * tar + 8 * grain + 15 * specks - 10 * worn - 22 * weld + 9 * bead
    base = tint(color((59, 60, 64), level), (46, 50, 54), patch * 0.59)
    height = 1.34 * weld + 1.02 * bead + 0.75 * patch + 0.75 * specks - 0.32 * np.abs(grain) + 0.19 * tar
    rough = 0.87 - 0.26 * worn - 0.25 * weld + 0.06 * specks - 0.17 * patch
    return base, height, rough, None


def tile(s: Surface) -> Material:
    center_x, center_y, row, column = s.blocks(8, 8)
    glaze = s.noise(62)
    fine = s.noise(225)
    grime = s.noise(31, 15)
    cloud = s.noise(8)
    distance = rounded_box(center_x * 64, center_y * 64, 59.5, 59.5, 2.7) + 0.52 * grime
    body = 1 - smooth(-2.1, 1.0, distance)
    lip = smooth(-4.25, -1.5, distance) * body
    grime = smooth(0.4, 2.0, grime + 0.40 * cloud)
    salt = smooth(0.22, 1.65, s.noise(45) + 0.48 * glaze) * lip
    chips = smooth(1.4, 2.65, glaze + 0.81 * fine) * lip
    tone = s.rng.normal(0, 9, (8, 8)).astype(np.float32)[row, column]
    tone -= 7 * ((column == 2) | (row == 6))
    weathered = 8 * glaze + 2.2 * fine + 5.3 * cloud + tone - 14 * grime + 9.5 * lip
    ceramic = tint(color((65, 89, 93), weathered), (126, 140, 126), salt * 0.45)
    ceramic = tint(ceramic, (97, 90, 79), chips * 0.82)
    cement_grout = tint(color((52, 59, 59), 6 * fine), (70, 76, 60), grime * 0.48)
    base = cement_grout + (ceramic - cement_grout) * body[..., None]
    height = 3.4 * body + 0.27 * glaze * body - 0.8 * chips + 0.24 * fine * (1 - body)
    rough = (0.81 + 0.07 * fine) * (1 - body) + (0.25 + 0.24 * grime + 0.31 * chips + 0.13 * salt) * body
    return base, height, rough, None


def normals(height: Array) -> Array:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    inverse_length = 1 / np.sqrt(1 + dx * dx + dy * dy)
    # Image rows increase downwards. The OpenGL tangent-space green channel points up.
    return np.stack((-dx * inverse_length, dy * inverse_length, inverse_length), axis=-1)


def as_bytes(values: Array) -> Array:
    return np.clip(np.rint(values), 0, 255).astype(np.uint8)


def light_preview(base: Array, normal: Array, roughness: Array, metalness: Array | None, size: int) -> Image.Image:
    diffuse_part = np.maximum(np.sum(normal * [0.54, 0.36, 0.76], axis=-1), 0)
    halfway = np.array([0.32, 0.21, 0.924])
    gloss = np.maximum(np.sum(normal * halfway, axis=-1), 0) ** (5 + (1 - roughness) * 28)
    metallic = 0 if metalness is None else metalness
    reflection = gloss * (1 - roughness) ** 2 * (23 + metallic * 28)
    image = as_bytes(base * (0.81 + 0.45 * diffuse_part[..., None]) + reflection[..., None])
    return Image.fromarray(image).resize((size, size), Image.Resampling.LANCZOS)


def contact_sheet(swatches: list[tuple[str, str, Image.Image]]) -> None:
    margin, gap, card, top, row_height = 38, 20, 304, 136, 374
    width = margin * 2 + card * 4 + gap * 3
    height = top + row_height * 2 + 9
    sheet = Image.new("RGB", (width, height), "#10161b")
    draw = ImageDraw.Draw(sheet)

    def font(size: int, bold: bool = False):
        name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
        path = Path("/usr/share/fonts/truetype/dejavu") / name
        return ImageFont.truetype(path, size) if path.exists() else ImageFont.load_default(size=size)

    draw.text((38, 31), "Maré Baixa", font=font(47, bold=True), fill="#f0f4f4", anchor="lt")
    draw.text((39, 89), "Materiais PBR", font=font(19), fill="#aebdc4", anchor="lt")
    draw.text(
        (width - margin, 87),
        "Amostras sob luz rasante",
        font=font(17),
        fill="#aebdc4",
        anchor="rt",
    )
    for index, (name, metadata, image) in enumerate(swatches):
        x = margin + index % 4 * (card + gap)
        y = top + index // 4 * row_height
        sheet.paste(image, (x, y))
        draw.rectangle((x, y, x + card - 1, y + card - 1), outline="#485861")
        draw.text((x, y + card + 12), name, font=font(20, bold=True), fill="#edf0f0", anchor="lt")
        draw.text((x, y + card + 40), metadata, font=font(15), fill="#aebdc4", anchor="lt")
    sheet.save(OUTPUT / "Texturas-Mare-Baixa.jpg", quality=92, subsampling=0, optimize=True)


def main() -> None:
    recipes: list[tuple[str, str, int, int, Callable[[Surface], Material]]] = [
        ("asphalt", "Asfalto molhado", 1024, 16, asphalt),
        ("cement", "Concreto aparente", 1024, 12, cement),
        ("sidewalk", "Pavimento modular", 1024, 8, sidewalk),
        ("glass", "Fachada envidraçada", 1024, 16, glass),
        ("steel", "Aço corrugado", 512, 12, steel),
        ("brick", "Tijolo escurecido", 1024, 10, brick),
        ("roof", "Manta asfáltica", 512, 12, roof),
        ("tile", "Cerâmica esmaltada", 512, 8, tile),
    ]
    manifest = {}
    swatches = []
    for index, (key, label, pixels, studs, recipe) in enumerate(recipes):
        base, height, rough, metal = recipe(Surface(pixels, 20568 + index * 397))
        normal = normals(height)
        base = np.clip(base, 0, 255)
        rough = np.clip(rough, 0.06, 0.98)
        maps = {
            "color": as_bytes(base),
            "normal": as_bytes((normal + 1) * 127.5),
            "roughness": as_bytes(rough * 255),
        }
        if metal is not None:
            maps["metalness"] = as_bytes(metal * 255)
        directory = OUTPUT / key
        directory.mkdir(parents=True, exist_ok=True)
        manifest[key] = {"tileStuds": studs, "maps": {}}
        for map_name, data in maps.items():
            output = directory / f"{map_name}.png"
            Image.fromarray(data).save(output, compress_level=8)
            manifest[key]["maps"][map_name] = output.relative_to(OUTPUT).as_posix()
        swatches.append((label, f"{pixels} × {pixels} px   ·   {studs} studs", light_preview(base, normal, rough, metal, 304)))
        print(f"{key}: {pixels} × {pixels}, {studs} studs, {len(maps)} maps", flush=True)
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    contact_sheet(swatches)


if __name__ == "__main__":
    main()
