"""Desenha por código a arte nova de Maré Baixa (sem IA).

Gera, em media/art:
- fachada_painel.png: painéis modulares dos megaprédios (mesma grade das janelas: 16 colunas de 6 studs,
  8 andares de 14 studs, 8 px por stud);
- vitrines.png: oito interiores de loja vistos pela vitrine (atlas 1024 x 1024, células de 512 x 256);
- anuncios.png: oito anúncios das marcas inventadas da cidade (quatro verticais de 256 x 512 em cima,
  quatro horizontais de 512 x 256 embaixo);
- poca_1..4.png: ladrilhos do asfalto (Poly Haven, CC0) com a água da poça recortada no canal alfa.

Tudo é desenhado com formas, gradientes e tipografia; a semente fixa repete o mesmo resultado.
Uso: python tools/draw_city_art.py
"""
from pathlib import Path
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "media" / "art"
FONT_DIRS = [Path("/usr/share/fonts/opentype/inter"), Path("/usr/share/fonts/truetype/dejavu"), ROOT / "tools" / "fonts"]


def font(name, size):
    for folder in FONT_DIRS:
        path = folder / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.truetype("DejaVuSans-Bold.ttf", size)


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vgradient(size, top, bottom):
    w, h = size
    t = np.linspace(0, 1, h)[:, None, None]
    a, b = np.array(top, float), np.array(bottom, float)
    rows = a + (b - a) * t
    return Image.fromarray(np.repeat(rows, w, axis=1).astype("uint8"), "RGB")


def glow(image, box, color, radius, strength=1.0):
    """Brilho suave somado à imagem (luz de néon, luminárias)."""
    layer = Image.new("RGB", image.size, (0, 0, 0))
    ImageDraw.Draw(layer).rectangle(box, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(radius))
    arr = np.asarray(image, float) + np.asarray(layer, float) * strength
    image.paste(Image.fromarray(np.clip(arr, 0, 255).astype("uint8")))


def spaced(draw, xy, text, fnt, fill, spacing, anchor="la"):
    """Texto com espaçamento entre letras (tracking)."""
    x, y = xy
    widths = [draw.textlength(ch, font=fnt) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    if anchor[0] == "m":
        x -= total / 2
    elif anchor[0] == "r":
        x -= total
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=fnt, fill=fill, anchor="l" + anchor[1])
        x += w + spacing
    return total


# Fachada de painéis -----------------------------------------------------------------------------------
def painel(seed=8101):
    rng = random.Random(seed)
    cols, floors, cw, ch = 16, 8, 48, 112
    image = Image.new("RGBA", (cols * cw, floors * ch), (26, 27, 32, 255))
    draw = ImageDraw.Draw(image)
    accents = [(132, 92, 30), (150, 102, 34), (126, 70, 30), (104, 96, 84)]
    # Colunas de painéis de destaque formam faixas verticais, como nos blocos modulares.
    stripe = [rng.random() < 0.38 for _ in range(cols // 2)]
    for floor in range(floors):
        for pair in range(cols // 2):
            x0, y0 = pair * cw * 2, floor * ch
            box = (x0 + 3, y0 + 3, x0 + cw * 2 - 4, y0 + ch - 4)
            accent = stripe[pair] and rng.random() < 0.85
            if accent:
                tone = rng.choice(accents)
                panel = vgradient((box[2] - box[0], box[3] - box[1]), mix(tone, (200, 150, 60), 0.12), mix(tone, (20, 14, 8), 0.35))
                image.paste(panel, box[:2])
                for k in (0.33, 0.66):
                    y = box[1] + int((box[3] - box[1]) * k)
                    draw.line([(box[0] + 6, y), (box[2] - 6, y)], fill=mix(tone, (0, 0, 0), 0.55), width=2)
                if rng.random() < 0.35:
                    draw.rectangle((box[0] + 10, box[1] + 10, box[0] + 26, box[1] + 18), fill=mix(tone, (255, 230, 160), 0.25))
            else:
                base = rng.choice([(40, 42, 50), (34, 36, 42), (46, 46, 52)])
                draw.rectangle(box, fill=base + (255,))
                kind = rng.random()
                if kind < 0.62:
                    # Janela em fenda: acesa (quente ou fria), com tela ou apagada.
                    wy0, wy1 = box[1] + 34, box[1] + 64
                    roll = rng.random()
                    if roll < 0.42:
                        warm = rng.choice([(255, 196, 120), (255, 214, 160), (247, 170, 98)])
                        win = vgradient((box[2] - box[0] - 16, wy1 - wy0), mix(warm, (255, 245, 220), 0.3), mix(warm, (110, 60, 30), 0.4))
                    elif roll < 0.52:
                        cool = rng.choice([(120, 200, 255), (170, 130, 255), (90, 230, 220)])
                        win = vgradient((box[2] - box[0] - 16, wy1 - wy0), mix(cool, (255, 255, 255), 0.2), mix(cool, (10, 20, 40), 0.6))
                    else:
                        win = vgradient((box[2] - box[0] - 16, wy1 - wy0), (24, 30, 44), (10, 12, 20))
                    image.paste(win, (box[0] + 8, wy0))
                    for m in range(1, 4):
                        mx = box[0] + 8 + (box[2] - box[0] - 16) * m // 4
                        draw.line([(mx, wy0), (mx, wy1)], fill=(20, 20, 24), width=2)
                elif kind < 0.85:
                    # Painel de venezianas.
                    for y in range(box[1] + 14, box[3] - 10, 7):
                        draw.line([(box[0] + 8, y), (box[2] - 8, y)], fill=mix(base, (0, 0, 0), 0.5), width=3)
                else:
                    # Respiros e um ar-condicionado.
                    draw.rectangle((box[0] + 22, box[1] + 70, box[0] + 60, box[1] + 92), fill=(92, 94, 98))
                    draw.ellipse((box[0] + 28, box[1] + 73, box[0] + 46, box[1] + 89), fill=(54, 56, 60))
            draw.rectangle(box, outline=(16, 16, 20), width=2)
        draw.rectangle((0, floor * ch, image.width, floor * ch + 3), fill=(18, 18, 22))
    return image


# Interiores das lojas ------------------------------------------------------------------------------------
CELL = (512, 256)


def room(wall_top, wall_bottom, floor_color, light=(255, 236, 200)):
    image = vgradient(CELL, wall_top, wall_bottom)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 214, 512, 256), fill=floor_color)
    for x in range(0, 512, 64):
        draw.line([(x, 214), (x - 30, 256)], fill=mix(floor_color, (0, 0, 0), 0.25), width=1)
    glow(image, (40, 0, 472, 6), light, 18, 0.55)
    return image, draw


def shelves(draw, rng, x0, x1, rows, top, step, palette, depth=(9, 22)):
    for row in range(rows):
        y = top + row * step
        draw.rectangle((x0, y + step - 8, x1, y + step - 4), fill=(70, 70, 76))
        x = x0 + 3
        while x < x1 - 6:
            w = rng.randint(*depth)
            h = rng.randint(step - 30, step - 12)
            color = rng.choice(palette)
            draw.rectangle((x, y + step - 8 - h, min(x1 - 3, x + w), y + step - 8), fill=color)
            draw.line([(x, y + step - 8 - h), (min(x1 - 3, x + w), y + step - 8 - h)], fill=mix(color, (255, 255, 255), 0.4))
            x += w + rng.randint(1, 4)


def mercadinho(rng):
    image, draw = room((214, 216, 210), (176, 180, 178), (120, 118, 112))
    shelves(draw, rng, 18, 330, 4, 26, 46, [(200, 50, 50), (240, 190, 40), (40, 120, 200), (60, 160, 80), (230, 120, 40), (240, 240, 236)])
    fridge = vgradient((150, 190), (210, 236, 255), (120, 170, 220))
    image.paste(fridge, (346, 20))
    draw.rectangle((346, 20, 496, 210), outline=(80, 84, 92), width=4)
    draw.line([(421, 20), (421, 210)], fill=(80, 84, 92), width=3)
    for row in range(4):
        for col in range(10):
            x, y = 354 + col * 14, 34 + row * 44
            draw.rectangle((x, y, x + 9, y + 30), fill=rng.choice([(200, 40, 50), (40, 150, 60), (230, 200, 60), (60, 90, 200)]))
    draw.rectangle((30, 168, 190, 214), fill=(60, 62, 70))
    draw.rectangle((30, 164, 190, 170), fill=(200, 200, 204))
    draw.rectangle((60, 140, 96, 164), fill=(30, 32, 36))
    return image


def bar(rng):
    image, draw = room((70, 40, 32), (34, 20, 18), (40, 26, 22), light=(255, 180, 110))
    backlit = vgradient((400, 130), (255, 186, 100), (150, 70, 30))
    image.paste(backlit, (56, 22))
    for row in range(3):
        y = 22 + row * 44
        draw.rectangle((56, y + 38, 456, y + 42), fill=(60, 36, 24))
        x = 62
        while x < 446:
            color = rng.choice([(60, 120, 60), (140, 70, 30), (180, 150, 80), (40, 40, 44), (120, 30, 40)])
            h = rng.randint(22, 34)
            draw.rectangle((x, y + 38 - h, x + 8, y + 38), fill=color)
            draw.rectangle((x + 2, y + 38 - h - 7, x + 6, y + 38 - h), fill=color)
            draw.line([(x + 2, y + 40 - h), (x + 2, y + 34)], fill=mix(color, (255, 255, 255), 0.5))
            x += rng.randint(11, 16)
    draw.rectangle((0, 170, 512, 214), fill=(46, 26, 20))
    draw.rectangle((0, 166, 512, 172), fill=(170, 110, 60))
    for x in (60, 150, 240, 330, 420):
        draw.ellipse((x - 16, 196, x + 16, 208), fill=(30, 20, 18))
        draw.rectangle((x - 3, 172, x + 3, 200), fill=(30, 20, 18))
    sign = font("Inter-Bold.otf", 30)
    draw.text((470, 40), "BAR", font=sign, fill=(255, 120, 190), anchor="mm")
    glow(image, (440, 26, 500, 54), (255, 60, 150), 10, 0.8)
    return image


def farmacia(rng):
    image, draw = room((236, 246, 242), (196, 214, 210), (170, 178, 176), light=(240, 255, 250))
    shelves(draw, rng, 18, 360, 4, 24, 46, [(250, 250, 250), (90, 150, 220), (80, 190, 130), (230, 230, 236), (200, 80, 90)], depth=(8, 16))
    cross = Image.new("RGB", (80, 80), (0, 0, 0))
    cd = ImageDraw.Draw(cross)
    cd.rectangle((28, 6, 52, 74), fill=(60, 230, 130))
    cd.rectangle((6, 28, 74, 52), fill=(60, 230, 130))
    image.paste(cross, (400, 30), cross.convert("L").point(lambda v: 255 if v else 0))
    glow(image, (400, 30, 480, 110), (40, 220, 120), 14, 0.6)
    draw.rectangle((380, 160, 500, 214), fill=(220, 226, 224))
    draw.rectangle((380, 156, 500, 162), fill=(60, 190, 120))
    return image


def eletronicos(rng):
    image, draw = room((24, 32, 50), (12, 16, 28), (22, 26, 36), light=(160, 200, 255))
    for row in range(3):
        for col in range(6):
            x, y = 22 + col * 80, 18 + row * 58
            tone = rng.choice([(60, 160, 255), (40, 220, 230), (220, 70, 170), (120, 90, 255)])
            screen = vgradient((70, 46), mix(tone, (255, 255, 255), 0.35), mix(tone, (0, 0, 20), 0.55))
            image.paste(screen, (x, y))
            sd = ImageDraw.Draw(image)
            for k in range(3):
                sd.rectangle((x + 8, y + 10 + k * 10, x + 8 + rng.randint(16, 54), y + 14 + k * 10), fill=mix(tone, (255, 255, 255), 0.6))
            sd.rectangle((x - 2, y - 2, x + 72, y + 48), outline=(8, 10, 16), width=3)
    draw.rectangle((0, 196, 512, 214), fill=(40, 44, 56))
    for x in range(30, 500, 38):
        draw.rectangle((x, 184, x + 20, 196), fill=rng.choice([(200, 200, 210), (40, 40, 48), (90, 160, 220)]))
    return image


def lanchonete(rng):
    image, draw = room((232, 178, 120), (170, 110, 70), (90, 60, 50), light=(255, 220, 170))
    menu = font("Inter-Bold.otf", 13)
    for k in range(3):
        x = 40 + k * 150
        board = vgradient((130, 70), (30, 28, 34), (20, 18, 22))
        image.paste(board, (x, 18))
        bd = ImageDraw.Draw(image)
        bd.rectangle((x, 18, x + 130, 88), outline=(250, 200, 120), width=2)
        for line in range(4):
            bd.rectangle((x + 10, 30 + line * 14, x + 10 + rng.randint(50, 90), 36 + line * 14), fill=(250, 240, 220))
            bd.rectangle((x + 106, 30 + line * 14, x + 120, 36 + line * 14), fill=(255, 190, 90))
        bd.text((x + 65, 102), ["LANCHES", "BEBIDAS", "COMBOS"][k], font=menu, fill=(255, 210, 140), anchor="mb")
    draw.rectangle((0, 150, 512, 214), fill=(196, 60, 50))
    draw.rectangle((0, 146, 512, 152), fill=(240, 230, 220))
    for x in range(40, 500, 70):
        draw.rectangle((x - 2, 176, x + 2, 214), fill=(60, 60, 64))
        draw.ellipse((x - 14, 170, x + 14, 182), fill=(220, 50, 50))
    draw.rectangle((380, 100, 470, 146), fill=(170, 172, 178))
    return image


def roupas(rng):
    image, draw = room((214, 204, 196), (168, 156, 150), (110, 96, 90), light=(255, 240, 225))
    for rack in range(3):
        x0 = 24 + rack * 160
        draw.rectangle((x0, 60, x0 + 130, 64), fill=(60, 60, 66))
        x = x0 + 4
        while x < x0 + 124:
            color = rng.choice([(30, 30, 36), (180, 40, 60), (40, 80, 160), (230, 220, 210), (90, 120, 80), (200, 150, 60)])
            h = rng.randint(70, 110)
            draw.polygon([(x, 64), (x + 10, 64), (x + 12, 64 + h), (x - 2, 64 + h)], fill=color)
            x += rng.randint(8, 12)
        draw.rectangle((x0 + 60, 64, x0 + 66, 214), fill=(60, 60, 66))
    for x in (90, 250, 410):
        glow(image, (x - 6, 0, x + 6, 10), (255, 230, 190), 10, 0.7)
    return image


def fliperama(rng):
    image, draw = room((34, 14, 52), (14, 6, 24), (30, 14, 40), light=(255, 80, 200))
    for k in range(5):
        x = 22 + k * 98
        draw.rectangle((x, 40, x + 70, 214), fill=(26, 24, 40))
        tone = rng.choice([(255, 60, 160), (60, 220, 255), (255, 190, 60), (140, 90, 255)])
        marquee = vgradient((62, 20), mix(tone, (255, 255, 255), 0.4), tone)
        image.paste(marquee, (x + 4, 44))
        screen = vgradient((52, 50), mix(tone, (255, 255, 255), 0.25), mix(tone, (0, 0, 30), 0.6))
        image.paste(screen, (x + 9, 76))
        sd = ImageDraw.Draw(image)
        sd.rectangle((x + 14, 140, x + 56, 150), fill=(60, 58, 70))
        sd.ellipse((x + 18, 132, x + 26, 140), fill=(250, 60, 80))
        sd.ellipse((x + 40, 136, x + 46, 142), fill=(60, 200, 255))
        glow(image, (x + 9, 76, x + 61, 126), tone, 10, 0.5)
    glow(image, (0, 0, 512, 4), (60, 220, 255), 6, 0.9)
    for x in range(0, 512, 24):
        draw.ellipse((x + 6, 226, x + 12, 232), fill=(90, 40, 120))
    return image


def saguao(rng):
    image, draw = room((196, 186, 172), (150, 142, 132), (120, 112, 104), light=(255, 240, 220))
    for k in range(9):
        x = rng.randint(0, 512)
        draw.line([(x, 0), (x + rng.randint(-60, 60), 214)], fill=(214, 206, 196), width=1)
    for x in (300, 380):
        door = vgradient((64, 170), (170, 176, 186), (110, 116, 126))
        image.paste(door, (x, 44))
        draw.line([(x + 32, 44), (x + 32, 214)], fill=(80, 84, 92), width=2)
    draw.rectangle((40, 140, 240, 214), fill=(40, 40, 46))
    draw.rectangle((40, 136, 240, 142), fill=(220, 200, 160))
    logo = font("Inter-Bold.otf", 18)
    draw.text((140, 174), "RECEPÇÃO", font=logo, fill=(220, 200, 160), anchor="mm")
    for x in (470, 20):
        draw.rectangle((x - 10, 180, x + 10, 214), fill=(70, 60, 54))
        draw.ellipse((x - 26, 120, x + 26, 186), fill=(50, 96, 64))
    for x in range(60, 500, 90):
        glow(image, (x - 4, 0, x + 4, 6), (255, 240, 210), 12, 0.8)
    return image


def vitrines():
    rng = random.Random(8202)
    atlas = Image.new("RGB", (1024, 1024), (0, 0, 0))
    order = [("mercadinho", mercadinho), ("bar", bar), ("farmacia", farmacia), ("eletronicos", eletronicos),
             ("lanchonete", lanchonete), ("roupas", roupas), ("fliperama", fliperama), ("saguao", saguao)]
    for index, (_, painter) in enumerate(order):
        cell = painter(rng)
        # Vidro visto de fora: um pouco de reflexo e um degradê escuro na base.
        arr = np.asarray(cell, float)
        y = np.linspace(0, 1, cell.height)[:, None, None]
        arr = arr * (1 - 0.22 * y) + 10
        cell = Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))
        atlas.paste(cell, ((index % 2) * 512, (index // 2) * 256))
    return atlas


# Anúncios ------------------------------------------------------------------------------------------------
def ad_canvas(size, top, bottom):
    return vgradient(size, top, bottom)


def can(draw, image, box, body, accent):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=(x1 - x0) // 5, fill=body)
    draw.rectangle((x0 + 4, y0 + 10, x1 - 4, y0 + 18), fill=(200, 200, 210))
    draw.rectangle((x0 + 4, y1 - 18, x1 - 4, y1 - 10), fill=(200, 200, 210))
    draw.rectangle((x0 + (x1 - x0) * 0.2, y0 + 24, x0 + (x1 - x0) * 0.3, y1 - 24), fill=mix(body, (255, 255, 255), 0.35))
    mid = (x0 + x1) / 2
    bolt = [(mid + 10, y0 + 40), (mid - 14, (y0 + y1) / 2 + 4), (mid + 2, (y0 + y1) / 2 + 4), (mid - 10, y1 - 40),
            (mid + 16, (y0 + y1) / 2 - 8), (mid, (y0 + y1) / 2 - 8)]
    draw.polygon(bolt, fill=accent)


def alvor_h():
    image = ad_canvas((512, 256), (120, 10, 80), (24, 4, 30))
    draw = ImageDraw.Draw(image)
    glow(image, (280, 30, 470, 230), (255, 60, 170), 40, 0.7)
    can(draw, image, (330, 30, 430, 226), (232, 40, 130), (255, 236, 120))
    spaced(draw, (36, 58), "ALVOR", font("Michroma-Regular.ttf", 52), (255, 255, 255), 6)
    draw.rectangle((38, 128, 110, 132), fill=(255, 120, 200))
    draw.text((38, 146), "ENERGIA QUE", font=font("Inter-Bold.otf", 24), fill=(255, 210, 236))
    draw.text((38, 174), "NÃO DORME", font=font("Inter-Bold.otf", 24), fill=(255, 210, 236))
    return image


def limiar_h():
    image = ad_canvas((512, 256), (8, 46, 70), (4, 12, 26))
    draw = ImageDraw.Draw(image)
    cx, cy = 390, 128
    for k in range(18):
        y = 40 + k * 10
        half = 30 * math.sin(math.pi * (k + 0.5) / 18) + (14 if 6 < k < 12 else 0)
        draw.line([(cx - half, y), (cx + half, y)], fill=(70, 230, 255), width=2)
    draw.ellipse((cx - 16, 20, cx + 16, 52), outline=(70, 230, 255), width=2)
    glow(image, (cx - 40, 20, cx + 40, 230), (40, 200, 255), 26, 0.45)
    spaced(draw, (36, 60), "LIMIAR", font("Michroma-Regular.ttf", 46), (255, 255, 255), 6)
    draw.text((38, 130), "SEGUROS PARA", font=font("Inter-Bold.otf", 22), fill=(170, 236, 255))
    draw.text((38, 156), "CORPOS NOVOS", font=font("Inter-Bold.otf", 22), fill=(170, 236, 255))
    draw.rectangle((38, 196, 160, 200), fill=(70, 230, 255))
    return image


def kairos_h():
    image = ad_canvas((512, 256), (60, 26, 6), (10, 6, 4))
    draw = ImageDraw.Draw(image)
    cx, cy = 424, 128
    for r_, w in ((84, 3), (64, 2), (44, 8), (20, 20)):
        draw.ellipse((cx - r_, cy - r_, cx + r_, cy + r_), outline=(255, 170, 70), width=w)
    for k in range(12):
        a = k / 12 * math.tau
        draw.line([(cx + math.cos(a) * 48, cy + math.sin(a) * 48), (cx + math.cos(a) * 62, cy + math.sin(a) * 62)], fill=(255, 200, 120), width=2)
    glow(image, (cx - 30, cy - 30, cx + 30, cy + 30), (255, 150, 40), 20, 0.8)
    spaced(draw, (36, 52), "KAIROS", font("Michroma-Regular.ttf", 38), (255, 255, 255), 5)
    draw.text((38, 120), "IMPLANTES NEURAIS", font=font("Inter-Bold.otf", 22), fill=(255, 214, 160))
    draw.text((38, 156), "0%", font=font("Inter-Black.otf", 54), fill=(255, 170, 70))
    draw.text((140, 170), "DE JUROS", font=font("Inter-Bold.otf", 20), fill=(255, 214, 160))
    return image


def novachuva_h():
    image = ad_canvas((512, 256), (90, 8, 20), (20, 4, 8))
    draw = ImageDraw.Draw(image)
    rng = random.Random(9)
    for _ in range(70):
        x, y = rng.randint(250, 500), rng.randint(0, 256)
        draw.line([(x, y), (x - 6, y + 22)], fill=(255, 120, 130), width=1)
    bottle = [(420, 30), (440, 30), (442, 60), (470, 96), (470, 226), (390, 226), (390, 96), (418, 60)]
    draw.polygon(bottle, fill=(236, 60, 70))
    draw.rectangle((392, 130, 468, 176), fill=(250, 240, 240))
    draw.text((430, 153), "NC", font=font("Inter-Black.otf", 30), fill=(200, 30, 40), anchor="mm")
    glow(image, (380, 40, 480, 230), (255, 60, 70), 30, 0.4)
    spaced(draw, (34, 62), "NOVA CHUVA", font("Michroma-Regular.ttf", 28), (255, 255, 255), 3)
    draw.text((36, 122), "REFRIGERANTE", font=font("Inter-Bold.otf", 22), fill=(255, 200, 200))
    draw.text((36, 148), "SINTÉTICO", font=font("Inter-Bold.otf", 22), fill=(255, 200, 200))
    return image


def estuario_v():
    image = ad_canvas((256, 512), (52, 18, 96), (10, 4, 26))
    draw = ImageDraw.Draw(image)
    cx, cy = 128, 210
    for k in range(5):
        r_ = 30 + k * 24
        draw.arc((cx - r_, cy - r_, cx + r_, cy + r_), 200, 340, fill=(200, 160, 255), width=6 - k)
    draw.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), fill=(255, 255, 255))
    glow(image, (cx - 20, cy - 20, cx + 20, cy + 20), (180, 120, 255), 18, 0.8)
    draw.text((128, 300), "9G", font=font("Inter-Black.otf", 96), fill=(255, 255, 255), anchor="mm")
    draw.text((128, 380), "EM TODA A MARÉ", font=font("Inter-Bold.otf", 18), fill=(214, 190, 255), anchor="mm")
    spaced(draw, (128, 452), "ESTUÁRIO NET", font("Michroma-Regular.ttf", 17), (255, 255, 255), 2, anchor="mm")
    return image


def limiar_v():
    image = ad_canvas((256, 512), (6, 50, 76), (2, 10, 22))
    draw = ImageDraw.Draw(image)
    cx = 128
    for k in range(30):
        y = 70 + k * 10
        t = (k + 0.5) / 30
        half = 18 + 34 * math.sin(math.pi * min(1, t * 1.6)) * (1 - 0.4 * t)
        if 4 < k < 8:
            half *= 0.55
        draw.line([(cx - half, y), (cx + half, y)], fill=(80, 230, 255), width=2)
    draw.ellipse((cx - 22, 30, cx + 22, 74), outline=(80, 230, 255), width=3)
    glow(image, (cx - 50, 40, cx + 50, 360), (40, 200, 255), 30, 0.35)
    spaced(draw, (128, 410), "LIMIAR", font("Michroma-Regular.ttf", 30), (255, 255, 255), 4, anchor="mm")
    draw.text((128, 450), "SEGUROS PARA CORPOS NOVOS", font=font("Inter-Bold.otf", 12), fill=(170, 236, 255), anchor="mm")
    return image


def alvor_v():
    image = ad_canvas((256, 512), (130, 12, 86), (22, 4, 30))
    draw = ImageDraw.Draw(image)
    glow(image, (60, 60, 196, 360), (255, 70, 180), 46, 0.7)
    can(draw, image, (78, 80, 178, 330), (232, 40, 130), (255, 236, 120))
    spaced(draw, (128, 404), "ALVOR", font("Michroma-Regular.ttf", 38), (255, 255, 255), 5, anchor="mm")
    draw.text((128, 452), "ENERGIA QUE NÃO DORME", font=font("Inter-Bold.otf", 14), fill=(255, 210, 236), anchor="mm")
    return image


def kairos_v():
    image = ad_canvas((256, 512), (64, 28, 6), (8, 4, 2))
    draw = ImageDraw.Draw(image)
    cx, cy = 128, 190
    for r_, w in ((100, 3), (76, 2), (52, 9), (24, 24)):
        draw.ellipse((cx - r_, cy - r_, cx + r_, cy + r_), outline=(255, 170, 70), width=w)
    for k in range(16):
        a = k / 16 * math.tau
        draw.line([(cx + math.cos(a) * 58, cy + math.sin(a) * 58), (cx + math.cos(a) * 72, cy + math.sin(a) * 72)], fill=(255, 210, 130), width=2)
    glow(image, (cx - 30, cy - 30, cx + 30, cy + 30), (255, 150, 40), 22, 0.9)
    spaced(draw, (128, 360), "KAIROS", font("Michroma-Regular.ttf", 30), (255, 255, 255), 4, anchor="mm")
    draw.text((128, 410), "0% DE JUROS", font=font("Inter-Black.otf", 26), fill=(255, 170, 70), anchor="mm")
    draw.text((128, 448), "IMPLANTES NEURAIS", font=font("Inter-Bold.otf", 14), fill=(255, 214, 160), anchor="mm")
    return image


def anuncios():
    atlas = Image.new("RGB", (1024, 1024), (0, 0, 0))
    for index, painter in enumerate((estuario_v, limiar_v, alvor_v, kairos_v)):
        atlas.paste(painter(), (index * 256, 0))
    for index, painter in enumerate((alvor_h, limiar_h, kairos_h, novachuva_h)):
        atlas.paste(painter(), ((index % 2) * 512, 512 + (index // 2) * 256))
    return atlas


# Poças ---------------------------------------------------------------------------------------------------
def fbm(size, seed, octaves=5):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amplitude, total = 1.0, 0.0
    for o in range(octaves):
        cells = 4 * 2 ** o
        grid = rng.random((cells + 1, cells + 1))
        small = Image.fromarray((grid * 255).astype("uint8")).resize((size, size), Image.BICUBIC)
        out += np.asarray(small, float) / 255 * amplitude
        total += amplitude
        amplitude *= 0.5
    return out / total


def poca(seed, asphalt):
    size = 512
    rng = random.Random(seed)
    y, x = np.mgrid[0:size, 0:size] / size
    # Duas ou três manchas alongadas que se juntam, mais respingos menores em volta.
    shape = np.full((size, size), -1.0)
    lobes = rng.randint(2, 3)
    cx, cy = rng.uniform(0.4, 0.6), rng.uniform(0.4, 0.6)
    angle = rng.uniform(0, math.pi)
    for k in range(lobes):
        ox, oy = cx + rng.uniform(-0.12, 0.12), cy + rng.uniform(-0.12, 0.12)
        ax, ay = rng.uniform(0.2, 0.32), rng.uniform(0.1, 0.18)
        a = angle + rng.uniform(-0.6, 0.6)
        u = (x - ox) * math.cos(a) + (y - oy) * math.sin(a)
        v = -(x - ox) * math.sin(a) + (y - oy) * math.cos(a)
        shape = np.maximum(shape, 1 - ((u / ax) ** 2 + (v / ay) ** 2))
    for _ in range(rng.randint(2, 4)):
        ox, oy = rng.uniform(0.18, 0.82), rng.uniform(0.18, 0.82)
        radius = rng.uniform(0.035, 0.07)
        shape = np.maximum(shape, 1 - (((x - ox) ** 2 + (y - oy) ** 2) / radius ** 2))
    noise = fbm(size, seed) - 0.5
    fine = fbm(size, seed + 1, octaves=7) - 0.5
    field = shape + noise * 1.3 + fine * 0.5
    # A borda da célula fica sempre seca: emenda perfeita com o asfalto vizinho.
    edge = np.minimum.reduce([x, y, 1 - x, 1 - y])
    field = np.where(edge < 0.08, -1, field)
    water = np.clip(field * 6, 0, 1)
    soft = np.asarray(Image.fromarray((water * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(3)), float) / 255
    wet = np.asarray(Image.fromarray((np.clip(field * 2 + 0.6, 0, 1) * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(10)), float) / 255
    wet = np.where(edge < 0.05, 0, wet * np.clip((edge - 0.05) / 0.05, 0, 1))
    base = np.asarray(asphalt.resize((size, size), Image.LANCZOS).convert("RGB"), float)
    # O chão mistura 12% da cor da peça por baixo da textura; a poça traz essa mistura pronta.
    base = base * 0.88 + np.array([44, 45, 48]) * 0.12
    color = base * (1 - 0.42 * wet[..., None])
    alpha = 255 * (1 - soft)
    rgba = np.dstack([np.clip(color, 0, 255), alpha]).astype("uint8")
    return Image.fromarray(rgba, "RGBA")


def main():
    ART.mkdir(parents=True, exist_ok=True)
    outputs = {"fachada_painel": painel(), "vitrines": vitrines(), "anuncios": anuncios()}
    asphalt = Image.open(ART / "asphalt.png")
    for k in range(1, 5):
        outputs[f"poca_{k}"] = poca(4100 + k * 17, asphalt)
    for name, image in outputs.items():
        path = ART / f"{name}.png"
        image.save(path, optimize=True)
        print(name, image.size, path.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
