#!/usr/bin/env python3
"""OI3 :: texturas PBR feitas por código (sem IA, sem foto).

Gera, para cada material, mapas que repetem sem emenda (tileable):
  cor (luminância quase neutra: a cor da peça no Roblox tinge a textura),
  normal (relevo, padrão OpenGL) e rugosidade.
Saída: oi3/assets/texturas/<material>_<mapa>.jpg  +  texturas.json (lista e parâmetros)

uso: python3 oi3/tools/texturas.py [--previa caminho.png]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "assets", "texturas")


# ------------------------------------------------------------ ferramentas
def ruido(n, beta, semente, anis=(1.0, 1.0)):
    """ruído 1/f^beta periódico (repete sem emenda). anis estica (x, y)."""
    g = np.random.default_rng(semente)
    w = g.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * anis[1]
    fx = np.fft.fftfreq(n)[None, :] * anis[0]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    esp = np.fft.fft2(w) / f ** beta
    esp[0, 0] = 0
    r = np.real(np.fft.ifft2(esp))
    r -= r.min()
    return r / (r.max() + 1e-9)


def suave(x, a, b):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def borrar(x, raio):
    """desfoque gaussiano periódico via FFT."""
    n = x.shape[0]
    f = np.fft.fftfreq(n)
    g = np.exp(-(f[:, None] ** 2 + f[None, :] ** 2) * (2 * np.pi * raio) ** 2 / 2)
    return np.real(np.fft.ifft2(np.fft.fft2(x) * g))


def normal_de(altura, forca):
    """mapa de normal (OpenGL: verde = para cima) a partir da altura, periódico."""
    dx = (np.roll(altura, -1, 1) - np.roll(altura, 1, 1)) * 0.5
    dy = (np.roll(altura, -1, 0) - np.roll(altura, 1, 0)) * 0.5
    nx, ny, nz = -dx * forca, dy * forca, np.ones_like(altura)
    m = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    n = np.stack([nx / m, ny / m, nz / m], -1)
    return ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)


def cor_de(lum, tinta=(1.0, 0.97, 0.93)):
    rgb = np.stack([lum * tinta[0], lum * tinta[1], lum * tinta[2]], -1)
    return (rgb.clip(0, 1) * 255).astype(np.uint8)


def cinza(x):
    return (np.clip(x, 0, 1) * 255).astype(np.uint8)


def voronoi(n, pontos, semente):
    """distância à borda das células (periódico) e id da célula."""
    g = np.random.default_rng(semente)
    p = g.random((pontos, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    ident = np.zeros((n, n), np.int32)
    for i, (px, py) in enumerate(p):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, n - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        menor = d < d1
        d2 = np.where(menor, d1, np.minimum(d2, d))
        ident = np.where(menor, i, ident)
        d1 = np.where(menor, d, d1)
    return d2 - d1, ident


# ------------------------------------------------------------ materiais
def veio(n, semente, aneis, contraste, fibra_forca):
    """veio de madeira serrada: anéis que serpenteiam devagar ao longo do X,
    faixa escura estreita (lenho tardio), fibras e poros compridos no X."""
    yy, xx = np.mgrid[0:n, 0:n] / n
    torto = ruido(n, 2.2, semente, anis=(1.0, 0.35)) - 0.5        # devagar no X
    largo = ruido(n, 2.6, semente + 1, anis=(1.0, 0.6)) - 0.5
    t = yy * aneis + torto * 2.6 + largo * 1.4
    p = t - np.floor(t)
    tardio = np.exp(-((p - 0.12) / 0.05) ** 2) + 0.35 * np.exp(-((p - 0.2) / 0.12) ** 2)
    gradiente = 1 - p * 0.25
    fibras = ruido(n, 0.9, semente + 2, anis=(1.0, 0.07))          # riscas finas e longas no X
    poros = (ruido(n, 0.3, semente + 3, anis=(1.0, 0.25)) > 0.78).astype(float)
    nuvem = ruido(n, 2.4, semente + 4)
    lum = 0.66 * gradiente + 0.12 * (nuvem - 0.5) - contraste * tardio + fibra_forca * (fibras - 0.5) - 0.06 * poros
    altura = 0.45 * fibras - 0.35 * tardio - 0.25 * poros
    return lum, altura, fibras, nuvem


def tabua(n=1024):
    """assoalho envernizado e gasto (o veio corre no eixo X)."""
    lum, altura, fibras, nuvem = veio(n, 11, 7.0, 0.2, 0.12)
    riscos = (ruido(n, 0.8, 16, anis=(1.0, 0.05)) > 0.9).astype(float) * ruido(n, 1.5, 17)
    gasto = ruido(n, 2.6, 18)
    lum = lum + 0.08 * suave(gasto, 0.55, 0.85) - 0.05 * riscos
    rug = 0.34 + 0.14 * suave(gasto, 0.5, 0.85) + 0.1 * (fibras - 0.5) + 0.2 * riscos
    return cor_de(lum + 0.12, (1.0, 0.95, 0.9)), normal_de(altura - 0.3 * riscos, 3.2), cinza(rug)


def madeira(n=512):
    """madeira escura de móveis, vigas e rodapés (menos verniz)."""
    lum, altura, fibras, nuvem = veio(n, 21, 5.0, 0.16, 0.14)
    rug = 0.5 + 0.18 * nuvem + 0.1 * (fibras - 0.5)
    return cor_de(lum + 0.1, (1.0, 0.95, 0.9)), normal_de(altura, 2.6), cinza(rug)


def papel(n=1024):
    """papel de parede adamascado, envelhecido, com manchas de umidade."""
    rep = 4  # o motivo repete 4x por tile
    yy, xx = np.mgrid[0:n, 0:n] / n * rep
    linha = np.floor(yy)
    xx2 = xx + 0.5 * (linha % 2)  # repetição meio-deslocada
    u = (xx2 % 1) * 2 - 1
    v = (yy % 1) * 2 - 1
    au = np.abs(u)
    r = np.sqrt((au * 1.25) ** 2 + (v * 0.95) ** 2)
    th = np.arctan2(v, au + 1e-6)
    petalas = 0.5 + 0.5 * np.cos(5 * th + 1.2 * r)
    flor = suave(0.75 - r + 0.22 * petalas, 0.0, 0.06)
    miolo = suave(0.22 - np.sqrt(au ** 2 + (v + 0.05) ** 2), 0, 0.04)
    gavinha = suave(0.05 - np.abs(np.sin(3.2 * (au + 0.15 * np.sin(4 * v))) * 0.22 - v * 0.12 - 0.06), 0, 0.02) * (r > 0.55)
    motivo = np.clip(flor - 0.55 * miolo + 0.7 * gavinha, 0, 1)
    listra = suave(0.025 - np.abs((xx % 0.5) - 0.25) + 0.22, 0.2, 0.22) * 0.0
    fibra = ruido(n, 0.9, 31)
    mancha = ruido(n, 2.6, 32)
    umidade = suave(mancha, 0.62, 0.9)
    escorrido = suave(ruido(n, 1.6, 33, anis=(0.08, 1.0)), 0.6, 0.95)  # escorridos verticais (periódico)
    lum = 0.74 + 0.1 * motivo - 0.04 * listra + 0.04 * (fibra - 0.5) - 0.06 * umidade - 0.04 * escorrido
    altura = 0.6 * motivo + 0.25 * fibra
    rug = 0.84 - 0.12 * motivo + 0.04 * umidade
    return cor_de(lum, (1.0, 0.97, 0.9)), normal_de(borrar(altura, 0.7), 2.0), cinza(rug)


def tijolo(n=512):
    """tijolo à vista, assentamento corrido, rejunte fundo."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    alt_t, larg_t, rej = n / 8, n / 4, 7.0
    linha = np.floor(yy / alt_t)
    xs = xx + (linha % 2) * larg_t / 2
    coluna = np.floor(xs / larg_t)
    by = yy - linha * alt_t
    bx = xs - coluna * larg_t
    borda = np.minimum(np.minimum(by, alt_t - by), np.minimum(bx, larg_t - bx))
    lasca = (ruido(n, 1.5, 41) - 0.5) * 5
    face = suave(borda + lasca, rej * 0.5, rej * 1.3)
    g = np.random.default_rng(42)
    tons = g.normal(0, 0.09, (16, 8))
    tom = tons[(linha % 16).astype(int), (coluna % 8).astype(int)]
    sujeira = ruido(n, 2.0, 43)
    poros = ruido(n, 0.6, 44)
    lum = np.where(face > 0.5, 0.62 + tom + 0.08 * (sujeira - 0.5) + 0.06 * (poros - 0.5), 0.5 + 0.06 * poros)
    altura = face * 0.8 + 0.2 * poros * face
    rug = 0.86 + 0.08 * (1 - face)
    return cor_de(lum, (1.0, 0.95, 0.92)), normal_de(borrar(altura, 0.8), 6.0), cinza(rug)


def pedra(n=512):
    """pedras irregulares (lareira, fundação, caminho)."""
    borda, ident = voronoi(n, 22, 51)
    g = np.random.default_rng(52)
    tons = g.normal(0, 0.08, 64)
    face = suave(borda, 2.0, 9.0)
    aspereza = ruido(n, 1.3, 53)
    lum = 0.55 + tons[ident % 64] + 0.12 * (aspereza - 0.5)
    lum = lum * (0.55 + 0.45 * face)
    altura = face * 0.7 + 0.35 * aspereza
    rug = 0.8 + 0.1 * (aspereza - 0.5)
    return cor_de(lum, (1.0, 0.98, 0.95)), normal_de(borrar(altura, 0.8), 5.0), cinza(rug)


def gesso(n=512):
    """reboco/gesso do teto: manchado, com rachaduras e marcas de infiltração."""
    base = ruido(n, 2.4, 61)
    grao = ruido(n, 0.8, 62)
    # rachaduras: linhas finas onde um ruído cruza um valor
    r1 = ruido(n, 2.0, 63)
    rach = suave(0.012 - np.abs(r1 - 0.5), 0, 0.012) * suave(ruido(n, 2.2, 64), 0.55, 0.75)
    anel = ruido(n, 2.8, 65)
    mancha = suave(anel, 0.66, 0.72) - suave(anel, 0.74, 0.8)
    lum = 0.8 + 0.07 * (base - 0.5) + 0.04 * (grao - 0.5) - 0.18 * rach - 0.05 * np.clip(mancha, 0, 1) - 0.05 * suave(anel, 0.74, 0.95)
    altura = 0.4 * base + 0.25 * grao - 0.8 * rach
    rug = 0.9 - 0.05 * base
    return cor_de(lum, (1.0, 0.98, 0.94)), normal_de(borrar(altura, 0.6), 3.0), cinza(rug)


def telhado(n=512):
    """telhas de ardósia em fileiras sobrepostas."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    alt_f, larg_t = n / 8, n / 6
    linha = np.floor(yy / alt_f)
    xs = xx + (linha % 2) * larg_t / 2 + (ruido(n, 2.0, 71) - 0.5) * 4
    coluna = np.floor(xs / larg_t)
    by = (yy - linha * alt_f) / alt_f
    bx = xs - coluna * larg_t
    fresta = suave(np.minimum(bx, larg_t - bx), 1.5, 4.0)
    degrau = by  # cada fileira sobe até cobrir a próxima
    g = np.random.default_rng(72)
    tons = g.normal(0, 0.07, (8, 6))
    tom = tons[(linha % 8).astype(int), (coluna % 6).astype(int)]
    musgo = suave(ruido(n, 2.3, 73), 0.6, 0.85)
    lascas = ruido(n, 0.9, 74)
    lum = (0.5 + tom + 0.06 * (lascas - 0.5) + 0.1 * musgo) * (0.65 + 0.35 * fresta) * (0.8 + 0.2 * degrau)
    altura = degrau * 0.9 * fresta + 0.15 * lascas
    rug = 0.62 + 0.15 * lascas + 0.15 * musgo
    return cor_de(lum, (0.97, 1.0, 0.98)), normal_de(borrar(altura, 0.7), 4.0), cinza(rug)


def tecido(n=512):
    """tecido de tapete/cortina: trama + ornamento em losangos."""
    yy, xx = np.mgrid[0:n, 0:n] / n
    trama = 0.5 + 0.25 * np.sin(2 * np.pi * xx * 128) * np.sin(2 * np.pi * yy * 128)
    rep = 4
    u = (xx * rep) % 1 - 0.5
    v = (yy * rep) % 1 - 0.5
    losango = np.abs(u) + np.abs(v)
    orn = suave(0.03 - np.abs(losango - 0.32), 0, 0.03) + 0.7 * suave(0.12 - losango, 0, 0.04)
    pelo = ruido(n, 0.7, 81)
    gasto = ruido(n, 2.2, 82)
    lum = 0.6 + 0.16 * orn + 0.08 * (trama - 0.5) + 0.06 * (pelo - 0.5) - 0.04 * suave(gasto, 0.6, 0.9)
    altura = 0.5 * trama + 0.3 * pelo + 0.2 * orn
    rug = 0.95 - 0.03 * orn
    return cor_de(lum, (1.0, 0.97, 0.95)), normal_de(altura, 1.6), cinza(rug)


# nome no jogo, função, material base no Roblox, studs por repetição, padrão
MATERIAIS = [
    ("OI3_Tabua", tabua, "Wood", 6.0, "Regular"),
    ("OI3_Madeira", madeira, "Wood", 4.0, "Regular"),
    ("OI3_Papel", papel, "Fabric", 6.0, "Regular"),
    ("OI3_Tecido", tecido, "Fabric", 5.0, "Regular"),
    ("OI3_Tijolo", tijolo, "Brick", 4.0, "Regular"),
    ("OI3_Pedra", pedra, "Slate", 7.0, "Organic"),
    ("OI3_Gesso", gesso, "Plaster", 10.0, "Organic"),
    ("OI3_Telhado", telhado, "Slate", 8.0, "Regular"),
]


def main():
    os.makedirs(SAIDA, exist_ok=True)
    lista = []
    for nome, fn, base, studs, padrao in MATERIAIS:
        cor, nor, rug = fn()
        arquivos = {}
        for mapa, img, q in (("cor", cor, 88), ("normal", nor, 92), ("rugosidade", rug, 85)):
            arq = "%s_%s.jpg" % (nome, mapa)
            Image.fromarray(img).save(os.path.join(SAIDA, arq), quality=q, optimize=True)
            arquivos[mapa] = arq
        lista.append({"nome": nome, "base": base, "studs": studs, "padrao": padrao, "mapas": arquivos,
                      "tamanho": cor.shape[0]})
        kb = sum(os.path.getsize(os.path.join(SAIDA, a)) for a in arquivos.values()) // 1024
        print("%-12s %4dpx  %4d KB  (base %s, %.0f studs)" % (nome, cor.shape[0], kb, base, studs))
    with open(os.path.join(SAIDA, "texturas.json"), "w", encoding="utf-8") as f:
        json.dump(lista, f, ensure_ascii=False, indent=1)
    if "--previa" in sys.argv:
        destino = sys.argv[sys.argv.index("--previa") + 1]
        folha = Image.new("RGB", (3 * 256 + 40, len(lista) * 266 + 10), (20, 20, 22))
        for i, m in enumerate(lista):
            for j, mapa in enumerate(("cor", "normal", "rugosidade")):
                img = Image.open(os.path.join(SAIDA, m["mapas"][mapa])).convert("RGB")
                # mostra 2x2 repetições para conferir que emenda sem costura
                t = Image.new("RGB", (img.width * 2, img.height * 2))
                for a in range(2):
                    for b in range(2):
                        t.paste(img, (a * img.width, b * img.height))
                folha.paste(t.resize((256, 256)), (10 + j * 266, 10 + i * 266))
        folha.save(destino)
        print("prévia:", destino)


if __name__ == "__main__":
    main()
