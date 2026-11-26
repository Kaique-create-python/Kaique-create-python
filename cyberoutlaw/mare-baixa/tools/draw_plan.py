"""Draw the editable block layout guide from the actual map build statistics."""
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont


data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
image = Image.new("RGB", (1600, 1000), "#0B101B")
draw = ImageDraw.Draw(image)
font_dir = Path("/usr/share/fonts/truetype/dejavu")


def font(size, bold=False, mono=False):
    face = "DejaVuSansMono" if mono else "DejaVuSans"
    return ImageFont.truetype(str(font_dir / (face + ("-Bold" if bold else "") + ".ttf")), size)


def text(x, y, message, size, fill="#DCE6F5", bold=False, mono=False):
    draw.text((x, y), message, fill=fill, font=font(size, bold, mono))


palette = {
    "Residencial": ("#18273D", "#5A7BAB"),
    "Torres": ("#11303C", "#65BDD3"),
    "Comércio": ("#2B1D37", "#E67FAC"),
    "Indústria": ("#342922", "#C99967"),
    "Orla e praças": ("#1B3130", "#72B39E"),
    "Transporte": ("#302642", "#BDA9F2"),
    "Infraestrutura": ("#282D3A", "#8597B4"),
}
areas = {
    "apartments": "Residencial", "towers": "Residencial", "mixed": "Residencial",
    "tech": "Torres", "finance": "Torres", "hotel": "Torres", "vertice": "Torres",
    "arcade": "Comércio", "sodio": "Comércio",
    "warehouse": "Indústria", "docks": "Indústria",
    "park": "Orla e praças", "levee": "Orla e praças", "spawn": "Orla e praças",
    "station": "Transporte", "grid": "Infraestrutura",
}
points = {
    "B7": ("Doca do Sal", "Galpão, pátio e guindaste"),
    "D4": ("Mercado Sódio", "Bancas cobertas e quatro acessos"),
    "E4": ("Praça do Dique", "Nascimento do jogador"),
    "F4": ("Estação do Dique", "Plataformas e trem da Linha 07"),
    "G3": ("Torre Vértice", "Entrada térrea e pico de 575 studs"),
}

text(64, 47, "CYBEROUTLAW", 18, "#FF77B0", True, True)
text(64, 76, "MARÉ BAIXA", 56, "#EDF4FC", True)
text(64, 149, "Planta das quadras e pontos de entrada", 20, "#A3ADBF")
text(1140, 80, "2400 × 1920 STUDS", 25, "#90DDE7", True, True)
text(1140, 120, "Malha principal · 80 quadras", 18, "#A3ADBF")

draw.line((64, 194, 1536, 194), fill="#394459", width=1)
origin_x, origin_y, tile_x, tile_y, river = 80, 272, 108, 70, 38
x_middle = origin_x + tile_x * 5 + river / 2
draw.rectangle((x_middle - 18, origin_y - 13, x_middle + 18, origin_y + tile_y * 8 + 7), fill="#14324D")
for i in range(9):
    crossing = origin_y + i * tile_y - 3
    width = 4 if i in (2, 5, 7) else 9
    draw.rectangle((x_middle - 24, crossing - width/2, x_middle + 24, crossing + width/2), fill="#81DBEB")
draw.line((origin_x, origin_y + tile_y * 4 - 3, origin_x + 10*tile_x + river - 7, origin_y + tile_y * 4 - 3),
          fill="#C3A0F3", width=5)

for row in data["cells"]:
    x = origin_x + (row["column"] - 1) * tile_x + (river if row["column"] > 5 else 0)
    y = origin_y + (row["row"] - 1) * tile_y
    fill, stroke = palette[areas[row["kind"]]]
    draw.rounded_rectangle((x, y, x + tile_x - 7, y + tile_y - 7), radius=4, fill=fill, outline=stroke, width=1)
    marked = row["id"] in points
    text(x + 9, y + 13, row["id"], 19, "#FCF5FF" if marked else stroke, marked, True)
    if marked:
        draw.ellipse((x + 76, y + 15, x + 87, y + 26), fill="#FF7CB4")
    if row["row"] == 1:
        text(x + 42, 237, chr(64 + row["column"]), 16, "#8998B3", True, True)
for index in range(8):
    text(54, origin_y + index * tile_y + 23, str(index+1), 16, "#8998B3", True, True)

x_legend = 1234
text(x_legend, 233, "PONTOS DE REFERÊNCIA", 16, "#FF81B9", True, True)
for index, (code, entry) in enumerate(points.items()):
    y = 277 + index * 75
    text(x_legend, y, code, 19, "#FF87BF", True, True)
    text(x_legend + 42, y, entry[0], 17, "#E8F0FA", True)
    text(x_legend + 42, y + 24, entry[1], 13, "#9FADBE")

text(x_legend, 662, "NORTE", 16, "#90DDE7", True, True)
draw.line((1257, 715, 1257, 692), width=2, fill="#90DDE7")
draw.polygon([(1257, 684), (1250, 696), (1264, 696)], fill="#90DDE7")
text(x_legend + 38, 698, "−Z", 14, "#9FADBE", True, True)
text(x_legend, 752, "Cada quadra tem passo", 15, "#A3ADBF")
text(x_legend, 773, "de 240 × 240 studs.", 15, "#A3ADBF")

draw.line((64, 855, 1536, 855), fill="#394459", width=1)
for index, (name, (fill, stroke)) in enumerate(palette.items()):
    x = 66 + (index % 4) * 340
    y = 882 + (index // 4) * 40
    draw.rounded_rectangle((x, y, x + 18, y + 18), radius=3, fill=fill, outline=stroke, width=2)
    text(x + 28, y - 1, name, 16, "#B6C2D6")
draw.line((1086, 927, 1110, 927), width=4, fill="#C3A0F3")
text(1120, 917, "Monotrilho Linha 07", 16, "#B6C2D6")
image.save(sys.argv[2], optimize=True)
