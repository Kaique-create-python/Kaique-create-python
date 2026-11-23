"""Ícones 2D do CyberOutlaw, em vetor e sem imagem gerada por IA.

As armas são desenhadas a partir dos próprios modelos 3D do jogo: cada peça é projetada de lado (cano
para a direita) e vira um polígono claro, com contorno escuro fino entre as peças e uma borda externa
para ler sobre qualquer fundo. Os glifos dos botões (atirar, mirar, recarregar...) são desenhados à mão.
O mesmo SVG vai para o Figma (createNodeFromSvg) e para o atlas que o jogo usa.

Uso:
  lune run tools/export_weapons.luau armas.json
  python design/icones.py armas.json <pasta de saída>   (SVGs, atlas.html e layout.json)
"""
from pathlib import Path
import json
import math
import sys

CELL_W, CELL_H = 384, 192
GLYPH = 128
WEAPONS = ["punhos", "faca", "glock", "deagle", "uzi", "ak47", "m4", "escopeta", "sniper"]
GLYPHS = ["tiro", "mira", "recarga", "arsenal", "correr", "golpe", "teleporte", "fechar"]
# Atlas 1024 x 1024: armas em duas colunas de 384 x 192 (até 10); glifos de 128 x 128 na faixa da direita.
ATLAS = {wid: (index % 2 * CELL_W, index // 2 * CELL_H, CELL_W, CELL_H) for index, wid in enumerate(WEAPONS)}
ATLAS.update({name: (768 + index % 2 * GLYPH, index // 2 * GLYPH, GLYPH, GLYPH) for index, name in enumerate(GLYPHS)})

INK = "#08080c"


# Geometria ------------------------------------------------------------------------------------------
def transform(cframe, point):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe
    px, py, pz = point
    return (x + r00 * px + r01 * py + r02 * pz,
            y + r10 * px + r11 * py + r12 * pz,
            z + r20 * px + r21 * py + r22 * pz)


def hull(points):
    pts = sorted(set((round(a, 5), round(b, 5)) for a, b in points))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def side(point):
    # Vista do lado direito (+X): o cano (-Z) aponta para a direita e +Y sobe.
    x, y, z = point
    return (-z, -y)


def outline(part):
    """Polígono (ou círculo) da peça vista de lado, no espaço da arma."""
    sx, sy, sz = part["size"]
    cf = part["cframe"]
    shape = part["shape"]
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    if shape == "Ball":
        cx, cy = side(transform(cf, (0, 0, 0)))
        return ("circle", (cx, cy, sx / 2))
    if shape == "Cylinder":
        axis = (cf[3], cf[6], cf[9])  # eixo X da peça
        if abs(axis[0]) > 0.9:  # olhando ao longo do eixo: um círculo
            cx, cy = side(transform(cf, (0, 0, 0)))
            return ("circle", (cx, cy, sy / 2))
    if shape == "Wedge":
        corners = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
    else:
        corners = [(a, b, c) for a in (-hx, hx) for b in (-hy, hy) for c in (-hz, hz)]
    return ("poly", hull([side(transform(cf, p)) for p in corners]))


def tone(color):
    r, g, b = color
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    v = 0.7 + 0.3 * min(1.0, luminance / 0.35)
    level = round(255 * v)
    return f"#{level:02x}{level:02x}{min(255, level + 4):02x}"


def weapon_svg(weapon, width=CELL_W, height=CELL_H, pad=18, stroke=1.3, rim=5.0):
    shapes = []
    for part in weapon["parts"]:
        if part.get("transparency", 0) > 0.5:
            continue
        kind, data = outline(part)
        # Pintor: o que está mais perto do olho (maior X) é desenhado por último.
        sx, sy, sz = part["size"]
        depth = part["cframe"][0] + max(sx, sy, sz) * 0.0 + sx / 2
        shapes.append((depth, kind, data, tone(part["color"])))
    xs, ys = [], []
    for _, kind, data, _ in shapes:
        if kind == "circle":
            cx, cy, r = data
            xs += [cx - r, cx + r]
            ys += [cy - r, cy + r]
        else:
            xs += [p[0] for p in data]
            ys += [p[1] for p in data]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    scale = min((width - 2 * pad) / (x1 - x0), (height - 2 * pad) / (y1 - y0))
    ox = (width - (x1 - x0) * scale) / 2 - x0 * scale
    oy = (height - (y1 - y0) * scale) / 2 - y0 * scale

    def element(kind, data, fill, extra=""):
        if kind == "circle":
            cx, cy, r = data
            return f'<circle cx="{cx * scale + ox:.2f}" cy="{cy * scale + oy:.2f}" r="{max(r * scale, 0.8):.2f}" fill="{fill}"{extra}/>'
        points = " ".join(f"{x * scale + ox:.2f},{y * scale + oy:.2f}" for x, y in data)
        return f'<polygon points="{points}" fill="{fill}"{extra}/>'

    ordered = sorted(shapes, key=lambda item: item[0])
    rim_layer = "".join(element(k, d, INK, f' stroke="{INK}" stroke-width="{rim}" stroke-linejoin="round"') for _, k, d, _ in ordered)
    body = "".join(element(k, d, f, f' stroke="{INK}" stroke-opacity="0.55" stroke-width="{stroke}" stroke-linejoin="round"')
                   for _, k, d, f in ordered)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" fill="none">'
            f'<g opacity="0.55">{rim_layer}</g>{body}\n</svg>')


# Punhos: desenho à mão (a luva 3D de lado vira só um bloco).
FIST = """
  <rect x="64" y="27" width="16" height="22" rx="5" fill="{b}"/>
  <rect x="81" y="24" width="16" height="25" rx="5" fill="{b}"/>
  <rect x="98" y="25" width="16" height="24" rx="5" fill="{b}"/>
  <rect x="115" y="29" width="15" height="20" rx="5" fill="{b}"/>
  <rect x="62" y="44" width="70" height="28" rx="8" fill="{b}"/>
  <path d="M60 54 Q60 50 66 50 H96 Q102 50 102 56 Q102 62 96 62 H70 Q62 62 60 58 Z" fill="{b}" stroke="{ink}" stroke-width="2.2"/>
  <rect x="66" y="31" width="12" height="3" rx="1.5" fill="{d}"/><rect x="83" y="28" width="12" height="3" rx="1.5" fill="{d}"/>
  <rect x="100" y="29" width="12" height="3" rx="1.5" fill="{d}"/><rect x="117" y="33" width="11" height="3" rx="1.5" fill="{d}"/>
  <rect x="70" y="72" width="54" height="12" rx="2" fill="{b}"/>
  <rect x="70" y="74.5" width="54" height="3" fill="{d}"/>"""


def fist_svg(width=CELL_W, height=CELL_H):
    inner = FIST.format(b="#f2f2f5", d="#b9bcc4", ink=INK)
    rim = FIST.format(b=INK, d=INK, ink=INK)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 192 96" fill="none">'
            f'<g opacity="0.5" stroke="{INK}" stroke-width="5" stroke-linejoin="round">{rim}</g>{inner}\n</svg>')


def glyph_svg(name, pistol_svg_inner):
    w = "#ffffff"
    if name == "tiro":
        # Símbolo de arma (a mesma Glock do jogo), em vez da palavra ATIRAR.
        return pistol_svg_inner
    if name == "golpe":
        inner = FIST.format(b=w, d="#c9cbd2", ink=INK)
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="52 12 92 84" fill="none">{inner}\n</svg>'
    if name == "mira":
        shapes = f"""
  <circle cx="32" cy="32" r="13" stroke="{w}" stroke-width="3.2"/>
  <rect x="30.4" y="5" width="3.2" height="16" rx="1" fill="{w}"/><rect x="30.4" y="43" width="3.2" height="16" rx="1" fill="{w}"/>
  <rect x="5" y="30.4" width="16" height="3.2" rx="1" fill="{w}"/><rect x="43" y="30.4" width="16" height="3.2" rx="1" fill="{w}"/>
  <circle cx="32" cy="32" r="2.6" fill="{w}"/>"""
    elif name == "recarga":
        # Pente entre duas setas em círculo.
        shapes = f"""
  <path d="M50 22 A20 20 0 0 0 14 21" stroke="{w}" stroke-width="4" stroke-linecap="round"/>
  <path d="M7 14 L16 27 L22 14 Z" fill="{w}"/>
  <path d="M14 42 A20 20 0 0 0 50 43" stroke="{w}" stroke-width="4" stroke-linecap="round"/>
  <path d="M57 50 L48 37 L42 50 Z" fill="{w}"/>
  <path d="M27 20 H37 V34 Q37 42 41 47 H31 Q27 42 27 34 Z" fill="{w}"/>
  <rect x="29" y="24" width="6" height="2" fill="{INK}" opacity="0.6"/><rect x="29" y="29" width="6" height="2" fill="{INK}" opacity="0.6"/>"""
    elif name == "arsenal":
        # Roleta: anel cortado em oito fatias, uma acesa.
        slices = []
        for k in range(8):
            a0, a1 = math.radians(-90 - 20 + k * 45 + 3), math.radians(-90 + 20 + k * 45 - 3)
            r0, r1 = 12, 27
            p = [(32 + r1 * math.cos(a0), 32 + r1 * math.sin(a0)), (32 + r1 * math.cos(a1), 32 + r1 * math.sin(a1)),
                 (32 + r0 * math.cos(a1), 32 + r0 * math.sin(a1)), (32 + r0 * math.cos(a0), 32 + r0 * math.sin(a0))]
            d = (f"M{p[0][0]:.2f} {p[0][1]:.2f} A{r1} {r1} 0 0 1 {p[1][0]:.2f} {p[1][1]:.2f} "
                 f"L{p[2][0]:.2f} {p[2][1]:.2f} A{r0} {r0} 0 0 0 {p[3][0]:.2f} {p[3][1]:.2f} Z")
            slices.append(f'<path d="{d}" fill="{w}" opacity="{1 if k == 0 else 0.55}"/>')
        shapes = "".join(slices) + f'<circle cx="32" cy="32" r="6" fill="{w}"/>'
    elif name == "correr":
        shapes = f"""
  <circle cx="38" cy="10" r="5.5" fill="{w}"/>
  <path d="M34 18 L25 34 L35 40 L32 56" stroke="{w}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M25 34 L15 44 L8 42" stroke="{w}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M33 21 L44 30 L53 26" stroke="{w}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M31 20 L20 24 L14 32" stroke="{w}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>"""
    elif name == "teleporte":
        shapes = f"""
  <path d="M32 58 C24 46 15 38 15 26 A17 17 0 0 1 49 26 C49 38 40 46 32 58 Z" fill="{w}"/>
  <circle cx="32" cy="26" r="7" fill="{INK}"/>
  <ellipse cx="32" cy="58" rx="14" ry="3.5" stroke="{w}" stroke-width="2.5" opacity="0.7"/>"""
    else:  # fechar
        shapes = f"""
  <path d="M16 16 L48 48 M48 16 L16 48" stroke="{w}" stroke-width="6" stroke-linecap="round"/>"""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none">{shapes}\n</svg>'


def main():
    weapons = {w["id"]: w for w in json.loads(Path(sys.argv[1]).read_text())}
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    tiles = []
    svgs = {}
    for wid in WEAPONS:
        svg = fist_svg() if wid == "punhos" else weapon_svg(weapons[wid])
        svgs[wid] = svg
        (out / f"icone_{wid}.svg").write_text(svg, encoding="utf-8")
        x, y, w, h = ATLAS[wid]
        tiles.append(f'<img src="icone_{wid}.svg" style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px">')
    pistol = weapon_svg(weapons["glock"], width=64, height=64, pad=4, stroke=0.6, rim=2.2)
    for name in GLYPHS:
        svg = glyph_svg(name, pistol)
        (out / f"glifo_{name}.svg").write_text(svg, encoding="utf-8")
        x, y, w, h = ATLAS[name]
        tiles.append(f'<img src="glifo_{name}.svg" style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px">')
    (out / "atlas.html").write_text(
        '<!doctype html><html><body style="margin:0;background:transparent">'
        '<div style="position:relative;width:1024px;height:1024px">' + "".join(tiles) + "</div></body></html>",
        encoding="utf-8",
    )
    (out / "layout.json").write_text(json.dumps(ATLAS, indent=1), encoding="utf-8")
    print(f"{len(WEAPONS)} armas e {len(GLYPHS)} glifos em {out}")


if __name__ == "__main__":
    main()
