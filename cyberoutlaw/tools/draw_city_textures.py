"""Desenha por código as janelas das fachadas de Maré Baixa.

Nenhuma imagem é gerada por IA: cada janela é um retângulo calculado por regras
fixas (semente determinística). Cada quadro cobre 16 colunas de 6 studs e
8 andares de 14 studs, na escala de 8 pixels por stud.
"""
from pathlib import Path
import random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
COLUMNS, FLOORS = 16, 8
CELL_W, CELL_H = 48, 112  # 6 x 14 studs a 8 px por stud
SIZE = (COLUMNS * CELL_W, FLOORS * CELL_H)


def _mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _glow(draw, box, color, top, bottom):
    """Gradiente vertical simples, mais claro perto da luminária do teto."""
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        draw.line([(x0, y), (x1 - 1, y)], fill=_mix(top, bottom, t) + (color[3],))


WARM = [(255, 200, 128), (255, 182, 104), (255, 214, 158), (247, 168, 98)]
COOL = [(214, 234, 255), (196, 222, 250), (232, 242, 255)]
SCREEN = [(108, 152, 255), (150, 110, 255), (90, 220, 235)]
DARK = (14, 19, 30)


def residential(seed=7101):
    rng = random.Random(seed)
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for floor in range(FLOORS):
        busy = rng.uniform(0.18, 0.55)  # cada andar tem a sua ocupação
        for column in range(COLUMNS):
            x, y = column * CELL_W, floor * CELL_H
            box = (x + 7, y + 26, x + 41, y + 98)
            draw.rectangle((box[0] - 2, box[1] - 2, box[2] + 1, box[3] + 1), fill=(38, 40, 48, 255))
            roll = rng.random()
            if roll < busy:
                base = rng.choice(WARM)
                _glow(draw, box, base + (255,), _mix(base, (255, 240, 210), 0.35), _mix(base, (120, 70, 40), 0.35))
                if rng.random() < 0.45:  # cortina fechada pela metade
                    side = rng.choice((0, 1))
                    half = (box[0], box[1], box[0] + 17, box[3]) if side == 0 else (box[0] + 17, box[1], box[2], box[3])
                    draw.rectangle(half, fill=_mix(base, (70, 40, 34), 0.55) + (255,))
            elif roll < busy + 0.07:
                base = rng.choice(SCREEN)
                _glow(draw, box, base + (255,), _mix(base, (20, 24, 40), 0.55), _mix(base, (10, 12, 24), 0.75))
            else:
                _glow(draw, box, DARK + (150,), (26, 34, 52), (10, 13, 22))
                draw.line([(box[0] + 4, box[3] - 6), (box[2] - 8, box[1] + 6)], fill=(60, 72, 96, 90), width=2)
            draw.line([(box[0] + 17, box[1]), (box[0] + 17, box[3])], fill=(30, 32, 40, 255), width=2)
            if rng.random() < 0.16:  # ar-condicionado externo
                draw.rectangle((x + 12, y + 100, x + 30, y + 110), fill=(86, 90, 92, 255))
                draw.rectangle((x + 14, y + 102, x + 22, y + 108), fill=(48, 50, 54, 255))
        draw.rectangle((0, floor * CELL_H, SIZE[0], floor * CELL_H + 12), fill=(0, 0, 0, 0))
    return image


def office(seed=7202):
    rng = random.Random(seed)
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for floor in range(FLOORS):
        y = floor * CELL_H
        band = (0, y + 20, SIZE[0], y + 102)
        _glow(draw, band, DARK + (175,), (22, 30, 46), (9, 12, 20))
        column = 0
        while column < COLUMNS:
            run = rng.randint(2, 7)
            if rng.random() < 0.42:
                base = rng.choice(COOL) if rng.random() < 0.8 else rng.choice(WARM)
                x0, x1 = column * CELL_W, min(COLUMNS, column + run) * CELL_W
                _glow(draw, (x0, y + 22, x1, y + 100), base + (255,), _mix(base, (255, 255, 255), 0.5), _mix(base, (40, 52, 70), 0.45))
                draw.rectangle((x0, y + 23, x1 - 1, y + 25), fill=(255, 255, 255, 255))
                for _ in range(run):  # silhuetas de mesas e divisórias
                    px = rng.randint(x0, max(x0, x1 - 20))
                    draw.rectangle((px, y + 76, px + rng.randint(8, 18), y + 100), fill=_mix(base, (30, 36, 52), 0.7) + (255,))
            column += run
        for column in range(COLUMNS + 1):
            draw.line([(column * CELL_W, y + 20), (column * CELL_W, y + 102)], fill=(52, 58, 70, 255), width=3)
        draw.rectangle((0, y + 20, SIZE[0], y + 22), fill=(70, 78, 92, 255))
    return image


def glass(seed=7303):
    rng = random.Random(seed)
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for floor in range(FLOORS):
        for column in range(COLUMNS):
            x, y = column * CELL_W, floor * CELL_H
            box = (x + 2, y + 4, x + 46, y + 108)
            roll = rng.random()
            if roll < 0.13:
                base = rng.choice(COOL + [(120, 236, 255)])
                _glow(draw, box, base + (235,), _mix(base, (255, 255, 255), 0.4), _mix(base, (30, 40, 60), 0.55))
            elif roll < 0.17:
                base = (255, 70, 170)
                _glow(draw, box, base + (220,), _mix(base, (255, 210, 235), 0.3), _mix(base, (60, 10, 40), 0.6))
            else:
                shade = rng.randint(0, 10)
                _glow(draw, box, DARK + (110,), (30 + shade, 42 + shade, 64 + shade), (8, 11, 20))
        y = floor * CELL_H
        draw.rectangle((0, y, SIZE[0], y + 3), fill=(80, 92, 110, 255))
    for column in range(0, COLUMNS + 1, 2):
        draw.line([(column * CELL_W, 0), (column * CELL_W, SIZE[1])], fill=(64, 74, 92, 255), width=2)
    return image


def main():
    out = ROOT / "media" / "art"
    for name, painter in (("fachada_residencial", residential), ("fachada_escritorio", office), ("fachada_vidro", glass)):
        image = painter()
        image.save(out / f"{name}.png", optimize=True)
        print(name, image.size, (out / f"{name}.png").stat().st_size, "bytes")


if __name__ == "__main__":
    main()
