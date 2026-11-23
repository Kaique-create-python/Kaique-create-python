"""HUD v2 do CyberOutlaw desenhado à mão em vetores (SVG), sem imagens geradas por IA.

Gera as pranchetas de PC (1280 x 720) e celular (844 x 390) e uma prancheta de estados.
O minimapa usa o mesmo traçado de src/world.server.luau (eixos a cada 200 studs).
O fundo é uma renderização da própria cidade, apenas para dar contexto.

Uso: python design/hud_v2.py <pasta de saída> [imagem de fundo do PC] [imagem de fundo do celular]
"""
from pathlib import Path
import sys

INK = "#08070c"
SURFACE = "#100e19"
MAGENTA = "#ff2085"
PINK = "#ff84c3"
PINK_LABEL = "#ff92bf"
CYAN = "#8edee4"
CYAN_CITY = "#3ae7ff"
WHITE = "#f9f6ff"
HALF, STEP, QUAY = 1000, 200, 1070
DISTRICTS = [  # mesma prioridade do servidor
    ("Docas da Maré", "#8cff96", (-HALF, 600, HALF, QUAY)),
    ("Distrito Prisma", "#ff2990", (-400, -400, 400, 400)),
    ("Mercado Fosso", "#ffa65e", (-HALF, -HALF, -400, 600)),
    ("Alto Vértice", "#3ae7ff", (400, -HALF, HALF, 600)),
    ("Colmeia", "#b456fa", (-400, -HALF, 400, 600)),
]
RING = [(400, -340), (400, 340), (340, 400), (-340, 400), (-400, 340), (-400, -340), (-340, -400), (340, -400)]


def road(p):
    return 56 if p % 400 == 0 else 28


def fonts(root):
    return f"""
    @font-face {{ font-family: Michroma; src: url('{root}/Michroma-Regular.ttf'); }}
    @font-face {{ font-family: Montserrat; src: url('{root}/Montserrat[wght].ttf'); font-weight: 100 900; }}
    @font-face {{ font-family: RobotoMono; src: url('{root}/RobotoMono[wght].ttf'); font-weight: 100 700; }}
    @font-face {{ font-family: Sarpanch; src: url('{root}/Sarpanch-Bold.ttf'); }}
    """


def bevel(x, y, w, h, cut):
    """Retângulo com cantos chanfrados no topo esquerdo e na base direita."""
    return f"M{x + cut},{y} H{x + w} V{y + h - cut} L{x + w - cut},{y + h} H{x} V{y + cut} Z"


def district_at(x, z):
    for name, color, (x0, z0, x1, z1) in DISTRICTS:
        if x0 <= x <= x1 and z0 <= z <= z1:
            return name, color
    return DISTRICTS[-1][:2]


def map_content(px, pz):
    parts = [f'<rect x="-1600" y="-1600" width="3200" height="3200" fill="#07080f"/>']
    parts.append(f'<rect x="{-HALF - 14}" y="{-HALF - 14}" width="{2 * HALF + 28}" height="{QUAY + HALF + 14}" fill="#2c3249"/>')
    parts.append(f'<rect x="-1600" y="{QUAY}" width="3200" height="1600" fill="#0c2a3a"/>')
    lines = list(range(-HALF, HALF + 1, STEP))
    for a, b in zip(lines, lines[1:]):
        for c, d in zip(lines, lines[1:]):
            x0, x1, z0, z1 = a + road(a) / 2, b - road(b) / 2, c + road(c) / 2, d - road(d) / 2
            _, color = district_at((a + b) / 2, (c + d) / 2)
            parts.append(f'<rect x="{x0}" y="{z0}" width="{x1 - x0}" height="{z1 - z0}" fill="#12141f"/>')
            parts.append(f'<rect x="{x0}" y="{z0}" width="{x1 - x0}" height="{z1 - z0}" fill="{color}" fill-opacity="0.16"/>')
    for p in lines:
        if road(p) == 56:
            parts.append(f'<rect x="{-HALF - 14}" y="{p - 2}" width="{2 * HALF + 28}" height="4" fill="#59628a"/>')
            parts.append(f'<rect x="{p - 2}" y="{-HALF - 14}" width="4" height="{QUAY + HALF + 14}" fill="#59628a"/>')
    ring = " ".join(f"{x},{z}" for x, z in RING)
    parts.append(f'<polygon points="{ring}" fill="none" stroke="{MAGENTA}" stroke-width="9" stroke-opacity="0.9"/>')
    parts.append(f'<rect x="392" y="-60" width="16" height="120" fill="{CYAN_CITY}"/>')
    parts.append(f'<rect x="95" y="95" width="24" height="24" fill="{MAGENTA}" transform="rotate(45 107 107)"/>')
    return "\n".join(parts)


def minimap(x, y, w, h, scale, heading, district, clock, footer=24, label=11):
    """Minimapa girando com a câmera: o norte da cidade é -Z, para cima no mapa."""
    px, pz = 107, 139
    view_h = h - footer
    cx, cy = x + w / 2, y + view_h * 0.55
    clip = f"clip{x}{y}"
    import math
    radius = min(w, view_h) / 2 - 10
    nx = cx + math.sin(math.radians(-heading)) * radius
    ny = cy - math.cos(math.radians(-heading)) * radius
    nx = min(max(nx, x + 10), x + w - 10)
    ny = min(max(ny, y + 10), y + view_h - 6)
    color = dict((n, c) for n, c, _ in DISTRICTS)[district]
    return f"""
  <g id="Minimapa">
    <clipPath id="{clip}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/></clipPath>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{INK}" fill-opacity="0.92"/>
    <g clip-path="url(#{clip})">
      <g transform="translate({cx} {cy}) rotate({heading}) scale({scale}) translate({-px} {-pz})">
        {map_content(px, pz)}
      </g>
      <rect x="{x}" y="{y + view_h}" width="{w}" height="{footer}" fill="{SURFACE}" fill-opacity="0.96"/>
      <rect x="{x}" y="{y + view_h}" width="{w}" height="1" fill="#ffffff" fill-opacity="0.10"/>
    </g>
    <g id="Jogador">
      <path d="M{cx},{cy - 9} L{cx + 7},{cy + 7} L{cx},{cy + 3} L{cx - 7},{cy + 7} Z" fill="{WHITE}" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>
    </g>
    <g id="Norte">
      <circle cx="{nx}" cy="{ny}" r="8" fill="{INK}" stroke="{WHITE}" stroke-opacity="0.5"/>
      <text x="{nx}" y="{ny + 3.6}" font-family="Montserrat" font-weight="800" font-size="10" fill="{WHITE}" text-anchor="middle">N</text>
    </g>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="none" stroke="#ffffff" stroke-opacity="0.14"/>
    <path d="M{x + 1},{y + 22} V{y + 12} Q{x + 1},{y + 1} {x + 12},{y + 1} H{x + 34}" fill="none" stroke="{MAGENTA}" stroke-width="2"/>
    <path d="M{x + w - 1},{y + h - 20} V{y + h - 12} Q{x + w - 1},{y + h - 1} {x + w - 12},{y + h - 1} H{x + w - 30}" fill="none" stroke="{CYAN}" stroke-width="2"/>
    <circle cx="{x + 13}" cy="{y + view_h + footer / 2}" r="3.2" fill="{color}"/>
    <text x="{x + 22}" y="{y + view_h + footer / 2 + label * 0.36}" font-family="Michroma" font-size="{label - 1}" letter-spacing="{1 if label > 10 else 0.4}" fill="{WHITE}">{district.upper()}</text>
    <text x="{x + w - 10}" y="{y + view_h + footer / 2 + label * 0.38}" font-family="RobotoMono" font-weight="600" font-size="{label + 1}" fill="{PINK_LABEL}" text-anchor="end">{clock}</text>
  </g>"""


def vitals(x, y, w, h, health, maximum, portrait, trail=None, low=False):
    cut = 9 if h > 54 else 7
    pad = 9 if h > 54 else 8
    left = pad + portrait + 10
    bar_y = y + h - (17 if h > 54 else 15)
    bar_w = w - left - 12
    ratio = health / maximum
    edge = "#ff3b5c" if low else "#52344c"
    segments = "".join(
        f'<rect x="{x + left + bar_w * k / 10 - 1}" y="{bar_y}" width="2" height="7" fill="{SURFACE}"/>' for k in range(1, 10)
    )
    trail_rect = ""
    if trail:
        trail_rect = f'<rect x="{x + left + bar_w * ratio}" y="{bar_y}" width="{bar_w * (trail - ratio)}" height="7" fill="{WHITE}" fill-opacity="0.55"/>'
    label_y = y + (21 if h > 54 else 18)
    return f"""
  <g id="Vitais">
    <path d="{bevel(x, y, w, h, cut)}" fill="{SURFACE}" fill-opacity="0.9" stroke="{edge}" stroke-width="{2 if low else 1}"/>
    <rect x="{x + 1}" y="{y}" width="{56 if h > 54 else 43}" height="1.5" fill="{MAGENTA}"/>
    <rect x="{x + w - 30}" y="{y + h - 1.5}" width="30" height="1.5" fill="{CYAN}"/>
    <g id="Retrato">
      <path d="{bevel(x + pad, y + pad, portrait, portrait, 6)}" fill="#3a2340" stroke="#57324c"/>
      <circle cx="{x + pad + portrait / 2}" cy="{y + pad + portrait * 0.40}" r="{portrait * 0.19}" fill="#c9b8d6"/>
      <path d="M{x + pad + portrait * 0.18},{y + pad + portrait} Q{x + pad + portrait / 2},{y + pad + portrait * 0.52} {x + pad + portrait * 0.82},{y + pad + portrait} Z" fill="#c9b8d6"/>
      <rect x="{x + pad}" y="{y + pad + portrait - 1.5}" width="12" height="1.5" fill="#ff6eab"/>
    </g>
    <text x="{x + left}" y="{label_y}" font-family="Montserrat" font-weight="800" font-size="{11 if h > 54 else 10}" letter-spacing="1.6" fill="{'#ff5c7a' if low else PINK_LABEL}">VIDA</text>
    <text x="{x + w - 12}" y="{label_y}" font-family="RobotoMono" font-weight="600" font-size="{13 if h > 54 else 11}" fill="{WHITE}" text-anchor="end">{health} / {maximum}</text>
    <rect x="{x + left}" y="{bar_y}" width="{bar_w}" height="7" fill="#2c2034"/>
    {trail_rect}
    <rect x="{x + left}" y="{bar_y}" width="{bar_w * ratio}" height="7" fill="url(#vida)"/>
    {segments}
  </g>"""


def toast(cx, y, name, color, big=28, small=11):
    width = 280 if big > 20 else 200
    return f"""
  <g id="Aviso de distrito">
    <rect x="{cx - width * 1.1}" y="{y - small - 10}" width="{width * 2.2}" height="{big + small + 40}" fill="url(#faixa)"/>
    <text x="{cx}" y="{y}" font-family="Montserrat" font-weight="700" font-size="{small}" letter-spacing="6" fill="{PINK_LABEL}" text-anchor="middle">MARÉ BAIXA</text>
    <text x="{cx}" y="{y + big + 6}" font-family="Michroma" font-size="{big}" letter-spacing="3" fill="{WHITE}" text-anchor="middle">{name.upper()}</text>
    <rect x="{cx - width / 2}" y="{y + big + 18}" width="{width}" height="2" fill="url(#linha)"/>
    <circle cx="{cx}" cy="{y + big + 19}" r="3" fill="{color}"/>
  </g>"""


def crosshair(cx, cy):
    return f"""
  <g id="Mira">
    <circle cx="{cx}" cy="{cy}" r="7" fill="none" stroke="{INK}" stroke-width="3" stroke-opacity="0.8"/>
    <circle cx="{cx}" cy="{cy}" r="6" fill="none" stroke="{WHITE}" stroke-width="1.5"/>
    <circle cx="{cx}" cy="{cy}" r="2" fill="{INK}"/>
    <circle cx="{cx}" cy="{cy}" r="1" fill="{WHITE}"/>
  </g>"""


DEFS = f"""
  <defs>
    <linearGradient id="vida" x1="0" x2="1"><stop offset="0" stop-color="{MAGENTA}"/><stop offset="1" stop-color="#ff7da8"/></linearGradient>
    <linearGradient id="linha" x1="0" x2="1">
      <stop offset="0" stop-color="{MAGENTA}" stop-opacity="0"/><stop offset="0.5" stop-color="{MAGENTA}"/>
      <stop offset="1" stop-color="{MAGENTA}" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="faixa" x1="0" x2="1">
      <stop offset="0" stop-color="{INK}" stop-opacity="0"/><stop offset="0.3" stop-color="{INK}" stop-opacity="0.62"/>
      <stop offset="0.7" stop-color="{INK}" stop-opacity="0.62"/><stop offset="1" stop-color="{INK}" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="sombra" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#000" stop-opacity="0.45"/><stop offset="0.3" stop-color="#000" stop-opacity="0"/>
      <stop offset="0.7" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.55"/>
    </linearGradient>
  </defs>"""


def svg(width, height, body, background, font_root):
    image = f'<image href="{background}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid slice"/>' if background else f'<rect width="{width}" height="{height}" fill="#14111f"/>'
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <style>{fonts(font_root)}</style>
  {DEFS}
  {image}
  <rect width="{width}" height="{height}" fill="url(#sombra)"/>
  {body}
</svg>
"""


def pc(background, font_root):
    body = "".join([
        toast(640, 86, "Distrito Prisma", "#ff2990"),
        crosshair(640, 360),
        vitals(24, 452, 268, 62, 78, 100, 46, trail=0.86),
        minimap(24, 522, 268, 174, 0.30, -18, "Distrito Prisma", "00:36"),
    ])
    return svg(1280, 720, body, background, font_root)


def phone(background, font_root):
    topbar = """
  <g id="Barra do Roblox (referência)" opacity="0.85">
    <circle cx="34" cy="29" r="16" fill="#000" fill-opacity="0.5"/><circle cx="74" cy="29" r="16" fill="#000" fill-opacity="0.5"/>
    <circle cx="810" cy="29" r="16" fill="#000" fill-opacity="0.5"/>
  </g>
  <g id="Controles de toque (referência)" opacity="0.5">
    <circle cx="112" cy="298" r="56" fill="#fff" fill-opacity="0.08" stroke="#fff" stroke-opacity="0.35"/>
    <circle cx="112" cy="298" r="22" fill="#fff" fill-opacity="0.25"/>
    <circle cx="768" cy="314" r="38" fill="#fff" fill-opacity="0.12" stroke="#fff" stroke-opacity="0.35"/>
  </g>"""
    body = "".join([
        topbar,
        toast(422, 66, "Distrito Prisma", "#ff2990", big=17, small=8),
        crosshair(422, 195),
        vitals(14, 66, 194, 50, 78, 100, 34, trail=0.86),
        minimap(670, 66, 160, 116, 0.22, -18, "Distrito Prisma", "00:36", footer=20, label=8),
    ])
    return svg(844, 390, body, background, font_root)


def states(font_root):
    body = "".join([
        '<text x="24" y="34" font-family="Michroma" font-size="14" fill="#f9f6ff">ESTADOS DO HUD</text>',
        vitals(24, 56, 268, 62, 78, 100, 46, trail=0.86),
        '<text x="300" y="92" font-family="Montserrat" font-size="11" fill="#bcb3cc">Dano recente: rastro branco por 0,4 s</text>',
        vitals(24, 134, 268, 62, 21, 100, 46, low=True),
        '<text x="300" y="170" font-family="Montserrat" font-size="11" fill="#bcb3cc">Vida abaixo de 30%: borda vermelha pulsando</text>',
        toast(160, 236, "Mercado Fosso", "#ffa65e", big=18, small=8),
        toast(460, 236, "Docas da Maré", "#8cff96", big=18, small=8),
        minimap(24, 310, 268, 174, 0.30, 35, "Alto Vértice", "23:58"),
        minimap(320, 310, 268, 174, 0.30, -110, "Docas da Maré", "01:12"),
    ])
    return svg(620, 510, body, None, font_root)


def main():
    out = Path(sys.argv[1])
    font_root = sys.argv[4] if len(sys.argv) > 4 else "fonts"
    out.mkdir(parents=True, exist_ok=True)
    (out / "CyberOutlaw-HUD-v2-PC.svg").write_text(pc(sys.argv[2] if len(sys.argv) > 2 else None, font_root), encoding="utf-8")
    (out / "CyberOutlaw-HUD-v2-Celular.svg").write_text(phone(sys.argv[3] if len(sys.argv) > 3 else None, font_root), encoding="utf-8")
    (out / "CyberOutlaw-HUD-v2-Estados.svg").write_text(states(font_root), encoding="utf-8")


if __name__ == "__main__":
    main()
