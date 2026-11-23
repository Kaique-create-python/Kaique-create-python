"""CyberOutlaw 2D icons drawn by hand in vectors (SVG). No AI images.

Each weapon is a 192 x 96 silhouette with the barrel to the right: a light body, dark cutouts,
and neon details in the weapon's color. The interface glyphs are 64 x 64.
The same SVG goes to Figma (createNodeFromSvg) and to the atlas the game uses.

Usage: python design/icones.py <output folder>   (writes the SVGs and atlas.html for the render)
"""
from pathlib import Path
import sys

BODY = "#f1ecf8"
CUT = "#0b0912"
ACCENT = {
    "punhos": "#ffa65e", "lamina": "#ff485c", "vespa": "#ff2990",
    "enxame": "#3ae7ff", "trovao": "#8cff96", "agulha": "#b456fa",
}


def weapon_svg(wid: str) -> str:
    a = ACCENT[wid]
    if wid == "vespa":
        shapes = f"""
  <path d="M46 28 H148 Q151 28 151 31 V33 H158 V41 H151 V44 H140 V52 H104 L101 62 H88 L86 52 L84 52 L76 84 H46 L50 76 L58 52 H56 L46 44 Z" fill="{BODY}"/>
  <path d="M90 52 H100 L98 59 H90 Z" fill="{CUT}"/>
  <rect x="56" y="33" width="84" height="3.5" fill="{a}"/>
  <rect x="47" y="23" width="7" height="5" fill="{a}"/>
  <rect x="141" y="24" width="5" height="4" fill="{a}"/>
  <path d="M63 58 H73 L70 70 H60 Z" fill="{a}"/>
  <rect x="118" y="40" width="3" height="3" fill="{CUT}"/><rect x="124" y="40" width="3" height="3" fill="{CUT}"/><rect x="130" y="40" width="3" height="3" fill="{CUT}"/>
  <rect x="58" y="45" width="44" height="2" fill="{CUT}" opacity="0.55"/>"""
    elif wid == "enxame":
        shapes = f"""
  <path d="M24 32 H48 V30 H56 V26 H130 V30 H140 V34 H158 V37 H170 V43 H158 V46 H140 V50 H134 L132 68 H122 L124 50 H114 L118 84 H104 L100 50 H88 L82 74 H66 L70 50 H48 V44 H24 Z" fill="{BODY}"/>
  <path d="M30 36 H44 V40 H30 Z" fill="{CUT}"/>
  <rect x="52" y="35" width="84" height="3.5" fill="{a}"/>
  <rect x="76" y="41" width="14" height="5" fill="{a}"/>
  <rect x="143" y="38" width="12" height="2" fill="{CUT}"/><rect x="143" y="42" width="12" height="2" fill="{CUT}"/>
  <rect x="104" y="58" width="10" height="2" fill="{CUT}" opacity="0.6"/><rect x="105" y="66" width="10" height="2" fill="{CUT}" opacity="0.6"/>"""
    elif wid == "trovao":
        shapes = f"""
  <path d="M8 40 L46 35 V32 H96 V32 H176 Q184 32 184 36 Q184 40 176 40 H160 V48 H140 V52 H112 V48 H96 V52 H70 L64 72 H50 L54 52 H46 V52 L14 60 L8 58 Z" fill="{BODY}"/>
  <rect x="52" y="36" width="38" height="3.5" fill="{a}"/>
  <rect x="176" y="30" width="6" height="12" fill="{a}"/>
  <rect x="117" y="42" width="2" height="9" fill="{CUT}"/><rect x="123" y="42" width="2" height="9" fill="{CUT}"/><rect x="129" y="42" width="2" height="9" fill="{CUT}"/><rect x="135" y="42" width="2" height="9" fill="{CUT}"/>
  <path d="M16 44 L40 41 V47 L18 52 Z" fill="{CUT}" opacity="0.55"/>
  <rect x="100" y="41" width="58" height="1.5" fill="{CUT}" opacity="0.5"/>"""
    elif wid == "agulha":
        shapes = f"""
  <path d="M6 34 L40 36 V32 H62 V28 H76 V31 H88 V28 H104 V32 H112 V33 H150 V37 H182 V35 H188 V44 H182 V42 H150 V47 H112 V50 H96 L102 80 L88 82 L80 50 H66 L60 72 H46 L52 50 H40 L12 58 L6 56 Z" fill="{BODY}"/>
  <rect x="60" y="17" width="44" height="11" rx="3" fill="{BODY}"/>
  <rect x="104" y="19" width="3" height="7" fill="{a}"/>
  <rect x="44" y="38" width="64" height="2.5" fill="{a}"/>
  <rect x="118" y="38" width="7" height="3" fill="{a}"/><rect x="129" y="38" width="7" height="3" fill="{a}"/><rect x="140" y="38" width="7" height="3" fill="{a}"/>
  <path d="M10 40 L36 41 V46 L14 52 Z" fill="{CUT}" opacity="0.55"/>
  <rect x="66" y="21" width="32" height="2" fill="{CUT}" opacity="0.5"/>"""
    elif wid == "lamina":
        shapes = f"""
  <path d="M58 39 H172 L188 46.5 L172 54 H58 Z" fill="{a}" opacity="0.35"/>
  <path d="M58 41 H171 L185 46.5 L171 52 H58 Z" fill="{BODY}"/>
  <rect x="62" y="45.5" width="104" height="2.2" fill="{a}"/>
  <rect x="52" y="34" width="6" height="28" rx="1.5" fill="{BODY}"/>
  <rect x="53.5" y="36" width="3" height="24" fill="{a}"/>
  <path d="M16 44 H52 V52 H16 Z" fill="{BODY}"/>
  <path d="M22 44 L26 52 H29 L25 44 Z M32 44 L36 52 H39 L35 44 Z M42 44 L46 52 H49 L45 44 Z" fill="{CUT}"/>
  <rect x="8" y="42" width="9" height="12" rx="2" fill="{BODY}"/>"""
    else:  # punhos
        shapes = f"""
  <rect x="64" y="27" width="16" height="22" rx="5" fill="{BODY}"/>
  <rect x="81" y="24" width="16" height="25" rx="5" fill="{BODY}"/>
  <rect x="98" y="25" width="16" height="24" rx="5" fill="{BODY}"/>
  <rect x="115" y="29" width="15" height="20" rx="5" fill="{BODY}"/>
  <rect x="62" y="44" width="70" height="28" rx="8" fill="{BODY}"/>
  <path d="M60 54 Q60 50 66 50 H96 Q102 50 102 56 Q102 62 96 62 H70 Q62 62 60 58 Z" fill="{BODY}" stroke="{CUT}" stroke-width="2.2"/>
  <rect x="66" y="31" width="12" height="3" rx="1.5" fill="{a}"/><rect x="83" y="28" width="12" height="3" rx="1.5" fill="{a}"/>
  <rect x="100" y="29" width="12" height="3" rx="1.5" fill="{a}"/><rect x="117" y="33" width="11" height="3" rx="1.5" fill="{a}"/>
  <rect x="70" y="72" width="54" height="12" rx="2" fill="{BODY}"/>
  <rect x="70" y="74.5" width="54" height="3" fill="{a}"/>"""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="192" height="96" viewBox="0 0 192 96" fill="none">{shapes}\n</svg>'


def glyph_svg(name: str) -> str:
    w = "#f9f6ff"
    if name == "tiro":
        shapes = f"""
  <circle cx="32" cy="32" r="17" stroke="{w}" stroke-width="4"/>
  <circle cx="32" cy="32" r="5" fill="{w}"/>
  <rect x="30" y="4" width="4" height="9" fill="{w}"/><rect x="30" y="51" width="4" height="9" fill="{w}"/>
  <rect x="4" y="30" width="9" height="4" fill="{w}"/><rect x="51" y="30" width="9" height="4" fill="{w}"/>"""
    elif name == "mira":
        shapes = f"""
  <circle cx="32" cy="32" r="13" stroke="{w}" stroke-width="3"/>
  <rect x="30.5" y="6" width="3" height="16" fill="{w}"/><rect x="30.5" y="42" width="3" height="16" fill="{w}"/>
  <rect x="6" y="30.5" width="16" height="3" fill="{w}"/><rect x="42" y="30.5" width="16" height="3" fill="{w}"/>
  <circle cx="32" cy="32" r="2.5" fill="{w}"/>"""
    elif name == "recarga":
        shapes = f"""
  <path d="M48 24 A18 18 0 0 0 16 22" stroke="{w}" stroke-width="4.5" stroke-linecap="square"/>
  <path d="M8 16 L18 28 L23 15 Z" fill="{w}"/>
  <path d="M16 40 A18 18 0 0 0 48 42" stroke="{w}" stroke-width="4.5" stroke-linecap="square"/>
  <path d="M56 48 L46 36 L41 49 Z" fill="{w}"/>"""
    else:  # arsenal: wheel with six slots
        shapes = f"""
  <circle cx="32" cy="32" r="9" stroke="{w}" stroke-width="3"/>
  <rect x="27" y="4" width="10" height="10" rx="2" fill="{w}"/><rect x="27" y="50" width="10" height="10" rx="2" fill="{w}"/>
  <rect x="5" y="17" width="10" height="10" rx="2" fill="{w}"/><rect x="49" y="17" width="10" height="10" rx="2" fill="{w}"/>
  <rect x="5" y="37" width="10" height="10" rx="2" fill="{w}"/><rect x="49" y="37" width="10" height="10" rx="2" fill="{w}"/>"""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none">{shapes}\n</svg>'


WEAPONS = ["punhos", "lamina", "vespa", "enxame", "trovao", "agulha"]
GLYPHS = ["tiro", "mira", "recarga", "arsenal"]
# Atlas 1024 x 1024: weapons at 2x (384 x 192) in two columns; glyphs at 2x (128 x 128) below them.
ATLAS = {wid: (index % 2 * 384, index // 2 * 192, 384, 192) for index, wid in enumerate(WEAPONS)}
ATLAS.update({name: (index * 128, 576, 128, 128) for index, name in enumerate(GLYPHS)})


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    tiles = []
    for wid in WEAPONS:
        svg = weapon_svg(wid)
        (out / f"icone_{wid}.svg").write_text(svg, encoding="utf-8")
        x, y, w, h = ATLAS[wid]
        tiles.append(f'<img src="icone_{wid}.svg" style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px">')
    for name in GLYPHS:
        svg = glyph_svg(name)
        (out / f"glifo_{name}.svg").write_text(svg, encoding="utf-8")
        x, y, w, h = ATLAS[name]
        tiles.append(f'<img src="glifo_{name}.svg" style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px">')
    (out / "atlas.html").write_text(
        '<!doctype html><html><body style="margin:0;background:transparent">'
        '<div style="position:relative;width:1024px;height:1024px">' + "".join(tiles) + "</div></body></html>",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
