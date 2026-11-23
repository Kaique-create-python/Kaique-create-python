"""Weapon wheel and weapon HUD for CyberOutlaw, drawn by hand in vectors (SVG).

The weapon icons are renders of the 3D models in src/arsenal.server.luau (parts, no AI).
In game, each card shows the same model rotating inside a ViewportFrame.

Usage: python design/arsenal_v1.py <output folder> <PC background> <phone background> <icon folder> <font folder>
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hud_v2 import DEFS, INK, SURFACE, MAGENTA, PINK_LABEL, CYAN, WHITE, bevel, crosshair, fonts, minimap, vitals  # noqa: E402

WEAPONS = [  # same order and values as the server
    ("punhos", "Punhos", "CORPO A CORPO", "#ffa65e", (0.22, 0.82, 0.08, 1.0), None),
    ("lamina", "Lâmina Térmica", "CORPO A CORPO · PLASMA", "#ff485c", (0.74, 0.46, 0.14, 0.82), None),
    ("vespa", "Pistola Vespa", "ARMA LEVE · SEMIAUTOMÁTICA", "#ff2990", (0.42, 0.5, 0.62, 0.86), (12, 96)),
    ("enxame", "SMG Enxame", "SUBMETRALHADORA · AUTOMÁTICA", "#3ae7ff", (0.3, 0.96, 0.44, 0.58), (32, 192)),
    ("trovao", "Escopeta Trovão", "ESCOPETA · CARTUCHO", "#8cff96", (0.95, 0.22, 0.18, 0.4), (6, 36)),
    ("agulha", "Fuzil Agulha", "FUZIL · AUTOMÁTICO", "#b456fa", (0.62, 0.74, 0.95, 0.7), (28, 140)),
]
STATS = ("DANO", "CADÊNCIA", "ALCANCE", "CONTROLE")
MUTED = "#bcb3cc"


def slot_angle(index, count=6):
    """Slot 0 at the top, the rest clockwise (screen degrees, 0 = right)."""
    return -90 + index * 360 / count


def card(cx, cy, w, h, weapon, index, icons, selected=False, compact=False):
    wid, name, kind, color, stats, ammo = weapon
    scale = 1.12 if selected else 1.0
    w2, h2 = w * scale, h * scale
    x, y = cx - w2 / 2, cy - h2 / 2
    cut = 12 if not compact else 9
    stroke = color if selected else "#ffffff"
    stroke_opacity = 1 if selected else 0.12
    glow = f'<path d="{bevel(x - 3, y - 3, w2 + 6, h2 + 6, cut + 2)}" fill="{color}" opacity="0.28" filter="url(#brilho)"/>' if selected else ""
    icon_h = h2 * (0.66 if not compact else 0.7)
    icon_w = icon_h * 1.6
    label = 9.5 if not compact else 7.2
    ammo_text = f"{ammo[0]}/{ammo[1]}" if ammo else "∞"
    key = "" if compact else f"""
      <rect x="{x + 10}" y="{y + 10}" width="15" height="15" fill="{INK}" stroke="#ffffff" stroke-opacity="0.22"/>
      <text x="{x + 17.5}" y="{y + 21}" font-family="Montserrat" font-weight="800" font-size="9" fill="{WHITE}" text-anchor="middle">{index + 1}</text>"""
    return f"""
    <g id="Cartão {name}" opacity="{1 if selected else 0.9}">
      {glow}
      <path d="{bevel(x, y, w2, h2, cut)}" fill="{SURFACE}" fill-opacity="0.95" stroke="{stroke}" stroke-opacity="{stroke_opacity}" stroke-width="{2 if selected else 1}"/>
      <rect x="{x + cut}" y="{y}" width="{w2 * 0.34}" height="2" fill="{color}"/>
      <image href="{icons}/icon_{wid}.png" x="{cx - icon_w / 2}" y="{y + h2 * 0.08}" width="{icon_w}" height="{icon_h}" opacity="{1 if selected else 0.78}"/>
      {key}
      <text x="{x + 12}" y="{y + h2 - 11}" font-family="Michroma" font-size="{label if len(name) < 14 else label * 0.86:.1f}" fill="{WHITE if selected else '#d9d2e6'}">{name.upper()}</text>
      <text x="{x + w2 - 12}" y="{y + (21 if not compact else 15)}" font-family="RobotoMono" font-weight="600" font-size="{label + 1}" fill="{color}" text-anchor="end">{ammo_text}</text>
    </g>"""


def hub(cx, cy, r, weapon, compact=False, hint="SOLTE  Q  PARA EQUIPAR"):
    wid, name, kind, color, stats, ammo = weapon
    ticks = []
    for k in range(60):
        a = math.radians(k * 6)
        long = k % 5 == 0
        r0, r1 = r + 4, r + (11 if long else 7)
        ticks.append(f'<line x1="{cx + math.cos(a) * r0:.1f}" y1="{cy + math.sin(a) * r0:.1f}" x2="{cx + math.cos(a) * r1:.1f}" '
                     f'y2="{cy + math.sin(a) * r1:.1f}" stroke="#ffffff" stroke-opacity="{0.4 if long else 0.16}" stroke-width="{1.4 if long else 1}"/>')
    s = 0.62 if compact else 1.0
    bars = []
    top = cy - (2 if not compact else 4) * s
    for row, (label, value) in enumerate(zip(STATS, stats)):
        y = top + row * 13 * s
        bars.append(f'<text x="{cx - 62 * s}" y="{y + 4 * s}" font-family="Montserrat" font-weight="700" font-size="{7.5 * s:.1f}" letter-spacing="1" fill="{MUTED}">{label}</text>')
        for seg in range(10):
            on = seg < round(value * 10)
            bars.append(f'<rect x="{cx + (2 + seg * 6.4) * s:.1f}" y="{y - 1 * s:.1f}" width="{5 * s:.1f}" height="{4.5 * s:.1f}" fill="{color if on else "#2c2836"}"/>')
    ammo_line = (f'<text x="{cx}" y="{cy + 66 * s}" font-family="RobotoMono" font-weight="700" font-size="{24 * s:.1f}" fill="{WHITE}" text-anchor="middle">{ammo[0]}'
                 f'<tspan font-size="{13 * s:.1f}" fill="{MUTED}">  |  {ammo[1]}</tspan></text>') if ammo else \
        f'<text x="{cx}" y="{cy + 64 * s}" font-family="Michroma" font-size="{11 * s:.1f}" fill="{MUTED}" text-anchor="middle">CORPO A CORPO</text>'
    return f"""
    <g id="Centro">
      <circle cx="{cx}" cy="{cy}" r="{r}" fill="#0b0912" fill-opacity="0.94" stroke="#ffffff" stroke-opacity="0.12"/>
      <circle cx="{cx}" cy="{cy}" r="{r - 7}" fill="none" stroke="{color}" stroke-width="2" stroke-dasharray="{r * 0.5} {r * 0.12}"/>
      {''.join(ticks)}
      <text x="{cx}" y="{cy - 52 * s}" font-family="Montserrat" font-weight="700" font-size="{6.4 * s:.1f}" letter-spacing="0.8" fill="{color}" text-anchor="middle">{kind}</text>
      <text x="{cx}" y="{cy - 30 * s}" font-family="Michroma" font-size="{15 * s:.1f}" fill="{WHITE}" text-anchor="middle">{name.upper()}</text>
      {''.join(bars)}
      {ammo_line}
      <text x="{cx}" y="{cy + r - 22 * s}" font-family="Montserrat" font-weight="700" font-size="{7 * s:.1f}" letter-spacing="1.5" fill="{MUTED}" text-anchor="middle">{hint}</text>
    </g>"""


def wheel(cx, cy, ring, hub_r, w, h, selected, icons, compact=False, hint="SOLTE  Q  PARA EQUIPAR"):
    parts = [f'<circle cx="{cx}" cy="{cy}" r="{ring + w * 0.62}" fill="none" stroke="#ffffff" stroke-opacity="0.07" stroke-dasharray="2 9"/>',
             f'<circle cx="{cx}" cy="{cy}" r="{ring}" fill="none" stroke="{MAGENTA}" stroke-opacity="0.18"/>']
    color = WEAPONS[selected][3]
    angle = math.radians(slot_angle(selected))
    tip_r = hub_r + 13
    px, py = cx + math.cos(angle) * tip_r, cy + math.sin(angle) * tip_r
    side = 7 if not compact else 5
    left = (cx + math.cos(angle) * (tip_r - side * 1.6) + math.cos(angle + math.pi / 2) * side,
            cy + math.sin(angle) * (tip_r - side * 1.6) + math.sin(angle + math.pi / 2) * side)
    right = (cx + math.cos(angle) * (tip_r - side * 1.6) - math.cos(angle + math.pi / 2) * side,
             cy + math.sin(angle) * (tip_r - side * 1.6) - math.sin(angle + math.pi / 2) * side)
    end_r = ring - (h * 0.62 if not compact else h * 0.6)
    parts.append(f'<line x1="{px:.1f}" y1="{py:.1f}" x2="{cx + math.cos(angle) * end_r:.1f}" y2="{cy + math.sin(angle) * end_r:.1f}" '
                 f'stroke="{color}" stroke-width="2" stroke-opacity="0.7"/>')
    parts.append(f'<polygon points="{px + math.cos(angle) * 4:.1f},{py + math.sin(angle) * 4:.1f} {left[0]:.1f},{left[1]:.1f} {right[0]:.1f},{right[1]:.1f}" fill="{color}"/>')
    for index, weapon in enumerate(WEAPONS):
        if index == selected:
            continue
        a = math.radians(slot_angle(index))
        parts.append(card(cx + math.cos(a) * ring, cy + math.sin(a) * ring, w, h, weapon, index, icons, False, compact))
    parts.append(card(cx + math.cos(angle) * ring, cy + math.sin(angle) * ring, w, h, WEAPONS[selected], selected, icons, True, compact))
    parts.append(hub(cx, cy, hub_r, WEAPONS[selected], compact, hint))
    return "".join(parts)


def weapon_card(x, y, w, h, weapon, mag, icons, compact=False, reloading=None):
    wid, name, kind, color, stats, ammo = weapon
    cut = 9 if not compact else 7
    icon_w = h * 1.28
    pips = []
    size = ammo[0] if ammo else 0
    if size:
        span = w - icon_w - 30
        step = span / size
        for k in range(size):
            pips.append(f'<rect x="{x + icon_w + 16 + k * step:.1f}" y="{y + h - 13}" width="{max(1.2, step - 1.6):.1f}" height="5" '
                        f'fill="{color if k < mag else "#2c2836"}"/>')
    big = 26 if not compact else 18
    small = 12 if not compact else 9
    reload_bar = ""
    if reloading is not None:
        reload_bar = (f'<rect x="{x + icon_w + 16}" y="{y + h - 13}" width="{(w - icon_w - 30) * reloading:.1f}" height="5" fill="{WHITE}"/>'
                      f'<text x="{x + w - 12}" y="{y + 16}" font-family="Montserrat" font-weight="800" font-size="8" letter-spacing="1.5" fill="{WHITE}" text-anchor="end">RECARREGANDO</text>')
    return f"""
  <g id="Arma equipada">
    <path d="{bevel(x, y, w, h, cut)}" fill="{SURFACE}" fill-opacity="0.9" stroke="#52344c"/>
    <rect x="{x + w - 56}" y="{y}" width="56" height="1.5" fill="{color}"/>
    <rect x="{x}" y="{y + h - 1.5}" width="30" height="1.5" fill="{CYAN}"/>
    <image href="{icons}/icon_{wid}.png" x="{x + 6}" y="{y + 4}" width="{icon_w}" height="{h - 8}"/>
    <text x="{x + icon_w + 16}" y="{y + 17 if not compact else y + 14}" font-family="Michroma" font-size="{9 if not compact else 7}" fill="{PINK_LABEL}">{name.upper()}</text>
    <text x="{x + icon_w + 16}" y="{y + h - 20}" font-family="RobotoMono" font-weight="700" font-size="{big}" fill="{WHITE}">{mag}<tspan font-size="{small}" fill="{MUTED}"> / {ammo[1] if ammo else ''}</tspan></text>
    {''.join(pips)}
    {reload_bar}
  </g>"""


def hitmarker(cx, cy):
    lines = []
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        lines.append(f'<line x1="{cx + sx * 6}" y1="{cy + sy * 6}" x2="{cx + sx * 12}" y2="{cy + sy * 12}" stroke="{WHITE}" stroke-width="2.2"/>')
    return f'<g id="Acerto">{"".join(lines)}</g>'


def frame_svg(width, height, body, background, font_root, blur=False):
    filt = '<filter id="desfoque"><feGaussianBlur stdDeviation="5"/></filter>' if blur else ""
    image = (f'<image href="{background}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid slice" '
             f'{"filter=\"url(#desfoque)\"" if blur else ""}/>')
    overlay = f'<rect width="{width}" height="{height}" fill="#06050a" fill-opacity="0.6"/>' if blur else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <style>{fonts(font_root)}</style>
  {DEFS}
  <defs>{filt}<filter id="brilho" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="8"/></filter></defs>
  {image}
  {overlay}
  {body}
</svg>
"""


def main():
    out, pc_bg, phone_bg, icons, font_root = sys.argv[1:6]
    out = Path(out)
    header = f"""
    <text x="640" y="40" font-family="Michroma" font-size="13" letter-spacing="7" fill="{WHITE}" text-anchor="middle">ARSENAL</text>
    <rect x="560" y="50" width="160" height="1.5" fill="url(#linha)"/>
    <text x="640" y="68" font-family="Montserrat" font-weight="600" font-size="9" letter-spacing="1.5" fill="{MUTED}" text-anchor="middle">MOUSE ESCOLHE · 1–6 ATALHO · RODA TROCA</text>"""
    pc = frame_svg(1280, 720, header + wheel(640, 384, 236, 112, 180, 116, 2, icons), pc_bg, font_root, blur=True)
    (out / "CyberOutlaw-Roleta-PC.svg").write_text(pc, encoding="utf-8")
    phone_header = f'<text x="422" y="18" font-family="Michroma" font-size="9" letter-spacing="5" fill="{WHITE}" text-anchor="middle">ARSENAL</text>'
    phone = frame_svg(844, 390, phone_header + wheel(422, 208, 136, 70, 112, 72, 2, icons, compact=True, hint="TOQUE PARA EQUIPAR"),
                      phone_bg, font_root, blur=True)
    (out / "CyberOutlaw-Roleta-Celular.svg").write_text(phone, encoding="utf-8")
    hud = "".join([
        vitals(24, 452, 268, 62, 100, 100, 46),
        minimap(24, 522, 268, 174, 0.30, -18, "Distrito Prisma", "00:41"),
        crosshair(640, 360), hitmarker(640, 360),
        weapon_card(988, 622, 268, 74, WEAPONS[2], 9, icons),
    ])
    (out / "CyberOutlaw-Arma-PC.svg").write_text(frame_svg(1280, 720, hud, pc_bg, font_root), encoding="utf-8")
    buttons = f"""
    <g id="Botões de toque" font-family="Montserrat" font-weight="800">
      <circle cx="768" cy="314" r="38" fill="#fff" fill-opacity="0.1" stroke="#fff" stroke-opacity="0.35"/>
      <circle cx="112" cy="298" r="56" fill="#fff" fill-opacity="0.06" stroke="#fff" stroke-opacity="0.3"/>
      <circle cx="112" cy="298" r="22" fill="#fff" fill-opacity="0.22"/>
      <circle cx="674" cy="304" r="36" fill="{INK}" fill-opacity="0.78" stroke="{MAGENTA}" stroke-width="2"/>
      <circle cx="674" cy="304" r="13" fill="none" stroke="{WHITE}" stroke-width="2"/><circle cx="674" cy="304" r="3" fill="{WHITE}"/>
      <text x="674" y="354" font-size="8" letter-spacing="1" fill="{WHITE}" text-anchor="middle">ATIRAR</text>
      <circle cx="768" cy="224" r="25" fill="{INK}" fill-opacity="0.78" stroke="{CYAN}" stroke-width="1.5"/>
      <line x1="756" y1="224" x2="780" y2="224" stroke="{WHITE}" stroke-width="1.5"/><line x1="768" y1="212" x2="768" y2="236" stroke="{WHITE}" stroke-width="1.5"/>
      <circle cx="768" cy="224" r="7" fill="none" stroke="{WHITE}" stroke-width="1.5"/>
      <text x="768" y="262" font-size="7" letter-spacing="1" fill="{WHITE}" text-anchor="middle">MIRAR</text>
      <circle cx="690" cy="226" r="19" fill="{INK}" fill-opacity="0.78" stroke="#ffffff" stroke-opacity="0.4"/>
      <text x="690" y="230" font-family="Michroma" font-size="11" fill="{WHITE}" text-anchor="middle">R</text>
    </g>"""
    phone_hud = "".join([
        '<g opacity="0.85"><circle cx="34" cy="29" r="16" fill="#000" fill-opacity="0.5"/><circle cx="74" cy="29" r="16" fill="#000" fill-opacity="0.5"/>'
        '<circle cx="810" cy="29" r="16" fill="#000" fill-opacity="0.5"/></g>',
        vitals(14, 66, 194, 50, 100, 100, 34),
        minimap(670, 66, 160, 116, 0.22, -18, "Distrito Prisma", "00:41", footer=20, label=8),
        weapon_card(14, 124, 194, 50, WEAPONS[2], 9, icons, compact=True),
        crosshair(422, 195),
        buttons,
    ])
    (out / "CyberOutlaw-Arma-Celular.svg").write_text(frame_svg(844, 390, phone_hud, phone_bg, font_root), encoding="utf-8")


if __name__ == "__main__":
    main()
