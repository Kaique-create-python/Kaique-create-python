"""Build phone-sized, non-generative artwork for the Maré Baixa package."""
import argparse
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from media_tools.mare_art import PBR_ART

ART = ROOT / "media/art"
FONT = ROOT / "tools/fonts/Michroma-Regular.ttf"
SAMPLE = Image.Resampling.LANCZOS


def letters(text, size):
    face = ImageFont.truetype(str(FONT), size)
    left, top, right, bottom = face.getbbox(text, stroke_width=2)
    mask = Image.new("L", (right - left, bottom - top))
    ImageDraw.Draw(mask).text((-left, -top), text, fill=255, font=face, stroke_width=2)
    return mask


def wordmark():
    face = letters("CYBEROUTLAW", 100).resize((904, 110), SAMPLE)
    mask = Image.new("L", (1020, 258))
    mask.paste(face, (32, 68))
    mask = mask.transform(mask.size, Image.Transform.AFFINE, (1, .28, -46, 0, 1, 0), Image.Resampling.BICUBIC)
    cut = ImageDraw.Draw(mask)
    cut.polygon([(112, 116), (697, 114), (684, 118), (102, 120)], fill=0)
    cut.polygon([(720, 155), (988, 155), (961, 158), (708, 160)], fill=0)
    ink = Image.new("RGBA", mask.size)
    ink.paste((244, 33, 107, 42), (0, 0, ink.width, ink.height), mask.filter(ImageFilter.GaussianBlur(8)))
    shadow = Image.new("L", ink.size)
    shadow.paste(mask, (-7, 7))
    ink.paste((101, 18, 75, 255), (0, 0, ink.width, ink.height), shadow)
    shine = Image.new("RGBA", ink.size)
    draw = ImageDraw.Draw(shine)
    for y in range(shine.height):
        f = max(0, min(1, (y - 66) / 106))
        draw.line((0, y, shine.width, y), fill=(255, round(110 - 74*f), round(171 - 68*f), 255))
    shine.putalpha(mask)
    ink.alpha_composite(shine)
    draw = ImageDraw.Draw(ink)
    draw.polygon([(40, 205), (774, 191), (731, 199), (35, 209)], fill=(247, 39, 117, 245))
    draw.polygon([(788, 191), (930, 189), (909, 195), (774, 198)], fill=(255, 133, 178, 200))
    ink.save(ART / "titulo_vetor.png", optimize=True)


def panels():
    atlas = Image.new("RGB", (1020, 1020))
    for index, (name, subtitle, color) in enumerate((
        ("VÉRTICE", "MOTORES ELÉTRICOS", (255, 62, 143)),
        ("SINCRONIA", "REDE DE TRANSMISSÃO", (74, 208, 244)),
        ("PORTO 03", "TERMINAL DO DIQUE", (180, 108, 251)),
    )):
        panel = Image.new("RGB", (340, 1020), (10, 15, 26))
        draw = ImageDraw.Draw(panel)
        for y in range(0, 1020, 4):
            power = max(0, 1 - abs(y - 505) / 530)
            tone = tuple(round(low + b * power * .27) for low, b in zip((12, 16, 26), color))
            draw.rectangle((0, y, 339, y + 2), fill=tone)
        draw.rectangle((12, 16, 326, 1003), outline=color, width=3)
        for i in range(5):
            inset = i * 15
            if index == 0:
                draw.line(((40+inset, 625), (169, 261+inset), (298-inset, 625), (40+inset, 625)),
                          fill=color, width=5)
            elif index == 1:
                draw.ellipse((42+inset, 327+inset, 298-inset, 583-inset), outline=color, width=5)
                draw.line(((57, 598-inset), (170, 733-inset), (283, 598-inset)), fill=color, width=3)
            else:
                draw.line(((49+inset, 627), (49+inset, 325+inset), (292-inset, 325+inset), (292-inset, 627)),
                          fill=color, width=5)
        draw.rectangle((30, 768, 310, 942), fill=(14, 19, 32))
        draw.line((29, 769, 310, 769), fill=color, width=4)
        draw.text((32, 798), name, font=ImageFont.truetype(str(FONT), 32), fill=color)
        draw.text((34, 874), subtitle, font=ImageFont.truetype(str(FONT), 13), fill=(214, 229, 244))
        atlas.paste(panel, (340 * index, 0))
    atlas.save(ART / "teloes_vetor.png", optimize=True)


def facades():
    atlas = Image.new("RGB", (1024, 1024))
    for index, kind in enumerate(("escritorio", "residencial", "vidro", "painel")):
        with Image.open(ART / f"fachada_{kind}.png") as image:
            panel = ImageOps.fit(image.convert("RGB"), (512, 512), method=SAMPLE)
        atlas.paste(panel, (index % 2 * 512, index // 2 * 512))
    atlas.save(ART / "fachadas_vetor.png", optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("materials", type=Path, help="pasta materials do mapa original")
    args = parser.parse_args()
    for key, dimensions in PBR_ART.items():
        _, material, channel = key.split("_")
        with Image.open(args.materials / material / f"{channel}.png") as image:
            image.resize(dimensions, SAMPLE).save(ART / f"{key}.png", optimize=True)
    wordmark()
    panels()
    facades()


if __name__ == "__main__":
    main()
