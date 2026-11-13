#!/usr/bin/env python3
"""OI3 :: transforma a imagem enviada pelos criadores numa FOTO ANTIGA do orfanato:
recorte (sem a marca d'água de baixo), sépia, grão de filme, arranhões, bordas escuras,
papel de foto com borda e o rosto do menino RABISCADO à caneta.
uso: python3 oi3/tools/foto_antiga.py <imagem_original> <saida.jpg>
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

orig, saida = sys.argv[1], sys.argv[2]
img = Image.open(orig).convert("RGB")
W, H = img.size
# recorte da família (a marca d'água fica embaixo, abaixo de ~70% da altura)
caixa = (int(W * 0.03), int(H * 0.22), int(W * 0.98), int(H * 0.685))
foto = img.crop(caixa)
fw, fh = foto.size
foto = foto.resize((int(fw * 1.6), int(fh * 1.6)), Image.LANCZOS)
fw, fh = foto.size

g = np.random.default_rng(7)
# envelhecer: tons de sépia, contraste baixo, desfoque leve
a = np.asarray(foto).astype(np.float32) / 255.0
lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
lum = 0.12 + lum * 0.78  # contraste lavado
sepia = np.stack([lum * 1.07, lum * 0.92, lum * 0.72], -1)
# vinheta
yy, xx = np.mgrid[0:fh, 0:fw]
dist = np.sqrt(((xx - fw / 2) / (fw / 2)) ** 2 + ((yy - fh / 2) / (fh / 2)) ** 2)
sepia *= (1 - 0.45 * np.clip(dist - 0.45, 0, 1) ** 1.5)[..., None]
# grão de filme
sepia += g.normal(0, 0.035, (fh, fw, 1))
foto = Image.fromarray((np.clip(sepia, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9))
# arranhões curtos (direções soltas), um vinco de dobra e poeira
riscos = Image.new("L", (fw, fh), 0)
dr = ImageDraw.Draw(riscos)
for _ in range(7):
    x, y = g.uniform(0, fw), g.uniform(0, fh)
    ang, comp = g.uniform(0, np.pi), g.uniform(25, 110)
    dr.line([(x, y), (x + np.cos(ang) * comp, y + np.sin(ang) * comp)], fill=int(g.uniform(60, 110)), width=1)
for _ in range(55):
    x, y = g.uniform(0, fw), g.uniform(0, fh)
    s = g.uniform(0.5, 1.6)
    dr.ellipse([x - s, y - s, x + s, y + s], fill=int(g.uniform(80, 170)))
# vinco: uma dobra atravessando o canto de cima à direita
vinco = [(fw * 0.62 + k * fw * 0.04, k * fh * 0.05 + g.uniform(-2, 2)) for k in range(11)]
dr.line(vinco, fill=95, width=2)
foto = Image.composite(Image.new("RGB", (fw, fh), (236, 226, 204)), foto, riscos)
sombra = Image.new("L", (fw, fh), 0)
ImageDraw.Draw(sombra).line([(x + 2, y + 1) for x, y in vinco], fill=70, width=2)
foto = Image.composite(Image.new("RGB", (fw, fh), (40, 30, 22)), foto, sombra.filter(ImageFilter.GaussianBlur(1)))

# RABISCO de caneta por cima da foto já velha (alguém rabiscou depois): vai e volta com força
cx, cy = (W * 0.63 - caixa[0]) * 1.6, (H * 0.474 - caixa[1]) * 1.6
r = W * 0.085 * 1.6
tinta = Image.new("L", (fw, fh), 0)
dt = ImageDraw.Draw(tinta)
def girar(pts, ang):
    c, s_ = np.cos(ang), np.sin(ang)
    return [(cx + (x - cx) * c - (y - cy) * s_, cy + (x - cx) * s_ + (y - cy) * c) for x, y in pts]
def suave(n, nos=7):  # ruído suave (a mão não é régua)
    return np.interp(np.linspace(0, nos - 1, n), np.arange(nos), g.normal(0, 1, nos))
for passada, ang in enumerate((-0.25, 1.05, -1.3)):
    n = 1200
    t = np.linspace(0, 1, n)
    y = cy - r * 0.92 + 2 * r * 0.92 * t
    meia = np.sqrt(np.clip(r * r - (y - cy) ** 2, 0, None)) * (1 + 0.12 * suave(n))
    x = cx + meia * np.sin(2 * np.pi * (15, 11, 8)[passada] * t + 0.4 * suave(n))
    y = y + 3 * suave(n)
    dt.line(girar(list(zip(x, y)), ang), fill=int(g.uniform(215, 245)), width=3)
for _ in range(3):  # voltas nervosas
    n = 700
    t = np.linspace(0, 2 * np.pi * g.uniform(3, 5), n)
    rr = r * g.uniform(0.35, 0.8) * (1 + 0.15 * suave(n))
    x = cx + r * 0.18 * suave(n) + np.cos(t) * rr
    y = cy + r * 0.18 * suave(n) + np.sin(t) * rr * 1.08
    dt.line(list(zip(x, y)), fill=230, width=2)
foto = Image.composite(Image.new("RGB", (fw, fh), (14, 11, 16)), foto, tinta.filter(ImageFilter.GaussianBlur(0.6)))

# papel de foto com borda (amarelado e manchado)
borda = int(fw * 0.06)
papel = Image.new("RGB", (fw + borda * 2, fh + borda * 2 + int(borda * 0.8)), (226, 214, 188))
pa = np.asarray(papel).astype(np.float32)
pa *= (0.92 + 0.08 * g.random((papel.size[1], papel.size[0], 1)))
papel = Image.fromarray(np.clip(pa, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
papel.paste(foto, (borda, borda))
papel = papel.resize((min(1024, papel.size[0]), int(papel.size[1] * min(1024, papel.size[0]) / papel.size[0])), Image.LANCZOS)
papel.save(saida, quality=88)
print("ok", saida, papel.size)
