"""Prepare the wordmark and three texture crops for the in-world signs."""
from argparse import ArgumentParser
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


def wordmark(source, output):
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= 18 else 0).getbbox()
    if not bounds or alpha.getextrema()[0] != 0:
        raise ValueError("A arte do letreiro precisa de fundo transparente.")
    mark = ImageOps.contain(image.crop(bounds), (999, 231), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (1020, 258))
    canvas.alpha_composite(mark, (9, (258 - mark.height) // 2))
    canvas.save(output, optimize=True)


def billboard(atlas_file, output):
    full = Image.open(atlas_file).convert("RGB")
    atlas = Image.new("RGB", (1020, 1020))
    size = (340, 1020)
    colors = ((246, 10, 98), (9, 200, 247), (174, 63, 240))
    tags = ("VERTICE", "SINCRONIA", "PORTO // 03")
    for index, accent in enumerate(colors):
        tile = full.crop((round(index * full.width / 3) + 2, 0, round((index + 1) * full.width / 3) - 2, full.height))
        backdrop = ImageOps.fit(tile, size, Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(24))
        base = Image.blend(backdrop, Image.new("RGB", size, (13, 8, 26)), 0.62)
        hero = ImageOps.fit(tile, (340, 555), Image.Resampling.LANCZOS, centering=(0.52, 0.39))
        fade = Image.new("L", hero.size)
        fd = ImageDraw.Draw(fade)
        for y in range(hero.height):
            fd.line((0, y, 339, y), fill=int(255 * min(1, y / 49, (hero.height - 1 - y) / 115)))
        base.paste(hero, (0, 204), fade)
        over = Image.new("RGBA", size)
        d = ImageDraw.Draw(over)
        d.polygon([(0, 149), (340, 19), (340, 63), (0, 180)], fill=(*accent, 49))
        d.polygon([(0, 821), (340, 732), (340, 786), (0, 874)], fill=(*accent, 55))
        d.line((7, 13, 333, 13), fill=(*accent, 220), width=3)
        d.line((7, 1004, 333, 1004), fill=(*accent, 220), width=3)
        for y in range(20, 1000, 4):
            d.line((0, y, 339, y), fill=(9, 6, 21, 28))
        for y in (188, 802):
            for j in range(15):
                x = 17 + j * 15
                d.line((x, y + 12, x + 8, y), fill=(*accent, 178), width=3)
        d.text((18, 865), tags[index], fill=(242, 246, 255, 231), font=ImageFont.load_default(size=28))
        d.text((19, 909), "MARÉ BAIXA", fill=(*accent, 228), font=ImageFont.load_default(size=19))
        d.line((19, 954, 317, 954), fill=(*accent, 147), width=2)
        atlas.paste(Image.alpha_composite(base.convert("RGBA"), over).convert("RGB"), (index * 340, 0))
    atlas.save(output, optimize=True)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("logo", type=Path)
    parser.add_argument("posters", type=Path)
    args = parser.parse_args()
    dest = Path(__file__).resolve().parents[1] / "media/art"
    dest.mkdir(exist_ok=True)
    wordmark(args.logo, dest / "title.png")
    billboard(args.posters, dest / "billboard.png")
    print("Poster source SHA-256", hashlib.sha256(args.posters.read_bytes()).hexdigest())
