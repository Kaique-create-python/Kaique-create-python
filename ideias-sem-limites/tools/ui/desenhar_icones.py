# Ícones no estilo da referência: azulejo quadrado arredondado com contorno escuro
# grosso, aro claro, face colorida, brilho; desenho cartoon com contorno escuro,
# sombra e brilho. Tudo em formas vetoriais (desenho manual), célula 256x256.
import json, math, re, sys

INK = "#1B120E"
CELL = 256

def f(v): return f"{v:.1f}".rstrip("0").rstrip(".")
def rrect(x, y, w, h, r):
    return (f"M {f(x+r)} {f(y)} L {f(x+w-r)} {f(y)} A {f(r)} {f(r)} 0 0 1 {f(x+w)} {f(y+r)} L {f(x+w)} {f(y+h-r)} "
            f"A {f(r)} {f(r)} 0 0 1 {f(x+w-r)} {f(y+h)} L {f(x+r)} {f(y+h)} A {f(r)} {f(r)} 0 0 1 {f(x)} {f(y+h-r)} "
            f"L {f(x)} {f(y+r)} A {f(r)} {f(r)} 0 0 1 {f(x+r)} {f(y)} Z")
def ell(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    return f"M {f(cx-rx)} {f(cy)} A {f(rx)} {f(ry)} 0 1 0 {f(cx+rx)} {f(cy)} A {f(rx)} {f(ry)} 0 1 0 {f(cx-rx)} {f(cy)} Z"
def poly(*pts):
    return "M " + " L ".join(f"{f(x)} {f(y)}" for x, y in pts) + " Z"
def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot) + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(*pts)
def gear(cx, cy, ro, ri, teeth):
    pts = []
    for i in range(teeth):
        a0 = i * 2 * math.pi / teeth
        w = math.pi / teeth * 0.5
        for a, r in ((a0 - w * 1.25, ri), (a0 - w * 0.7, ro), (a0 + w * 0.7, ro), (a0 + w * 1.25, ri)):
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(*pts)

TOK = re.compile(r"[MLHVCSAZ]|-?\d*\.?\d+(?:e-?\d+)?")
def move(d, dx, dy):
    out, toks, i, cmd = [], TOK.findall(d), 0, None
    nargs = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "A": 7, "Z": 0}
    while i < len(toks):
        t = toks[i]
        if t.isalpha():
            cmd = t; out.append(t); i += 1
            if cmd == "Z": continue
        a = [float(x) for x in toks[i:i + nargs[cmd]]]; i += nargs[cmd]
        if cmd == "H": a[0] += dx
        elif cmd == "V": a[0] += dy
        elif cmd == "A": a[5] += dx; a[6] += dy
        else:
            for k in range(0, len(a), 2): a[k] += dx; a[k + 1] += dy
        out.append(" ".join(f(v) for v in a))
    return " ".join(out)

# part: (d, fill, kind, opacity)  kind: o=contorno grosso por baixo, s=traço próprio, n=sem contorno
def P(d, fill, kind="o", op=1.0): return (d, fill, kind, op)
W = "#FFFFFF"
HI = 0.75  # brilho

def bulb():
    glass = "M 128 40 C 172 40 198 72 198 108 C 198 134 184 150 172 164 C 164 173 160 180 160 190 L 96 190 C 96 180 92 173 84 164 C 72 150 58 134 58 108 C 58 72 84 40 128 40 Z"
    return [
        P(glass, "#FFE45C"),
        P(rrect(88, 186, 80, 18, 8), "#C9D1DA"), P(rrect(92, 202, 72, 16, 8), "#A9B4C0"), P(rrect(108, 216, 40, 14, 7), "#4A4A58"),
        P("M 168 66 C 188 88 192 124 174 148 C 166 158 160 168 158 182 L 148 182 C 150 166 160 152 166 140 C 176 118 178 92 168 66 Z", "#F5B400", "n"),
        P(poly((112, 188), (112, 142), (120, 142), (120, 188)), "#E8890C", "n"), P(poly((136, 188), (136, 142), (144, 142), (144, 188)), "#E8890C", "n"),
        P(rrect(102, 124, 52, 18, 9), "#E8890C", "s"),
        P(ell(100, 82, 12, 18), W, "n", HI), P(ell(88, 114, 6, 8), W, "n", HI),
    ]

def star_icon():
    s = star(128, 136, 96, 44)
    cx, cy, r1, r2 = 128, 136, 96, 44
    v = [(cx + (r1 if i % 2 == 0 else r2) * math.cos(math.radians(-90) + i * math.pi / 5), cy + (r1 if i % 2 == 0 else r2) * math.sin(math.radians(-90) + i * math.pi / 5)) for i in range(10)]
    shade = poly((cx, cy), v[2], v[3], v[4], v[5])
    return [
        P(s, "#FFD43B"),
        P(shade, "#F5A30B", "n"),
        P(ell(112, 132, 8, 12), INK, "n"), P(ell(146, 132, 8, 12), INK, "n"),
        P("M 114 160 C 122 170 134 170 142 160 L 136 158 C 132 163 124 163 120 158 Z", INK, "n"),
        P(ell(108, 92, 8, 12), W, "n", HI), P(ell(110, 126, 3, 4), W, "n", 1), P(ell(144, 126, 3, 4), W, "n", 1),
    ]

def clock():
    return [
        P(ell(78, 70, 24), "#EF4444"), P(ell(178, 70, 24), "#EF4444"),
        P(poly((70, 196), (88, 182), (100, 194), (82, 212)), "#4A4A58"), P(poly((186, 196), (168, 182), (156, 194), (174, 212)), "#4A4A58"),
        P(ell(128, 138, 80), "#EF4444"),
        P(ell(128, 138, 60), "#FFF7E6", "s"),
        P(rrect(123, 84, 10, 16, 4), INK, "n"), P(rrect(123, 176, 10, 16, 4), INK, "n"), P(rrect(74, 133, 16, 10, 4), INK, "n"), P(rrect(166, 133, 16, 10, 4), INK, "n"),
        P(rrect(122, 98, 12, 44, 6), INK, "n"), P(rrect(124, 132, 40, 12, 6), INK, "n"),
        P(ell(128, 138, 8), "#EF4444", "n"),
        P(ell(70, 62, 7, 9), W, "n", HI), P(ell(170, 62, 7, 9), W, "n", HI), P(ell(86, 96, 7, 11), W, "n", HI),
    ]

def trophy():
    cup = "M 74 52 L 182 52 L 178 110 C 174 144 154 162 128 162 C 102 162 82 144 78 110 Z"
    hl = "M 80 70 C 40 70 40 132 92 136 L 92 120 C 62 116 62 86 80 86 Z"
    hr = "M 176 70 C 216 70 216 132 164 136 L 164 120 C 194 116 194 86 176 86 Z"
    return [
        P(hl, "#FFC83D"), P(hr, "#FFC83D"),
        P(rrect(114, 158, 28, 26, 4), "#F2A516"),
        P(rrect(78, 180, 100, 30, 8), "#7B4BC9"),
        P(cup, "#FFC83D"),
        P("M 150 56 L 180 56 L 176 110 C 172 138 158 154 138 160 C 152 140 158 120 158 96 Z", "#F2A516", "n"),
        P(rrect(98, 188, 60, 12, 5), "#FFD86B", "s"),
        P(star(126, 100, 26, 11), W, "n", 0.95),
        P(rrect(88, 62, 12, 48, 6), W, "n", HI),
    ]

def bag():
    body = poly((62, 98), (194, 98), (208, 214), (48, 214))
    handle = "M 90 102 L 90 78 C 90 36 166 36 166 78 L 166 102 L 150 102 L 150 78 C 150 56 106 56 106 78 L 106 102 Z"
    heart = "M 128 184 C 92 160 98 128 118 132 C 124 133 128 142 128 142 C 128 142 132 133 138 132 C 158 128 164 160 128 184 Z"
    return [
        P(handle, "#FFC83D"),
        P(body, "#FF6FAE"),
        P(poly((64, 98), (192, 98), (194, 116), (62, 116)), "#FF9CC8", "n"),
        P(poly((176, 116), (194, 116), (208, 214), (188, 214)), "#E04A8A", "n"),
        P(heart, W, "s"),
        P(rrect(72, 124, 10, 52, 5), W, "n", HI),
    ]

def cog():
    return [
        P(gear(128, 128, 96, 74, 8), "#DCE2EA"),
        P(ell(128, 128, 44), "#AEB8C6", "s"),
        P(ell(128, 128, 22), "#3A4150", "s"),
        P(ell(94, 84, 9, 13), W, "n", HI),
    ]

def monster():
    return [
        P(poly((82, 92), (66, 38), (112, 74)), "#FFF1D0"), P(poly((174, 92), (190, 38), (144, 74)), "#FFF1D0"),
        P(ell(92, 206, 22, 14), "#6D3FD0"), P(ell(164, 206, 22, 14), "#6D3FD0"),
        P(ell(128, 140, 80, 72), "#9B6BFF"),
        P("M 176 86 C 206 112 210 160 182 190 C 196 158 196 120 176 86 Z", "#7A4DE0", "n"),
        P(ell(128, 120, 36), W, "s"),
        P(ell(134, 124, 18), INK, "n"),
        P("M 88 160 C 98 200 158 200 168 160 Z", "#3A0D1F", "s"),
        P(poly((100, 161), (114, 161), (107, 176)), W, "n"), P(poly((142, 161), (156, 161), (149, 176)), W, "n"),
        P(ell(126, 116, 7), W, "n", 1), P(ell(84, 98, 8, 12), W, "n", HI),
    ]

def meteor():
    tail = "M 212 42 C 190 76 172 98 152 116 L 120 172 C 96 154 88 120 108 100 C 134 76 170 58 212 42 Z"
    inner = "M 200 56 C 180 84 162 100 144 114 L 122 150 C 110 136 110 118 122 108 C 144 90 170 74 200 56 Z"
    return [
        P(tail, "#FF7A1A"),
        P(inner, "#FFD43B", "n"),
        P(ell(102, 160, 54), "#8B5A3C"),
        P("M 58 150 C 62 124 84 108 106 108 C 88 116 74 132 72 156 Z", "#B07850", "n"),
        P(ell(88, 150, 11), "#5E3A24", "n"), P(ell(122, 182, 13), "#5E3A24", "n"), P(ell(124, 142, 7), "#5E3A24", "n"),
        P(ell(196, 128, 6), "#FFD43B", "n"), P(ell(174, 150, 4), "#FF7A1A", "n"), P(ell(212, 98, 5), "#FFD43B", "n"),
        P(ell(78, 128, 6, 9), W, "n", HI),
    ]

def car():
    body = "M 34 164 L 44 132 C 48 122 56 118 66 118 L 98 118 L 120 92 C 126 86 134 84 144 84 L 172 84 C 182 84 190 90 194 98 L 206 122 C 216 124 224 132 224 142 L 224 164 Z"
    return [
        P(body, "#EF3B3B"),
        P(ell(80, 168, 26), "#2A2A33"), P(ell(184, 168, 26), "#2A2A33"),
        P("M 126 118 L 146 96 L 170 96 C 176 96 180 100 182 104 L 190 118 Z", "#9FE3FF", "s"),
        P(rrect(40, 140, 182, 9, 4), W, "n", 0.9),
        P(ell(80, 168, 11), "#C9CED6", "n"), P(ell(184, 168, 11), "#C9CED6", "n"),
        P(ell(214, 136, 6), "#FFE45C", "n"),
        P(rrect(60, 124, 40, 7, 3), W, "n", HI),
    ]

def castle():
    return [
        P(poly((34, 92), (64, 34), (94, 92)), "#E5483A"), P(poly((162, 92), (192, 34), (222, 92)), "#E5483A"),
        P(poly((98, 84), (128, 26), (158, 84)), "#3B82F6"),
        P(rrect(42, 88, 44, 124, 4), "#D8DCE4"), P(rrect(170, 88, 44, 124, 4), "#D8DCE4"),
        P(rrect(84, 112, 88, 100, 4), "#C3C8D3"),
        P(rrect(104, 78, 48, 38, 4), "#D8DCE4"),
        P("M 108 212 L 108 176 C 108 150 148 150 148 176 L 148 212 Z", "#7A4A2A", "s"),
        P(rrect(58, 116, 12, 22, 6), INK, "n"), P(rrect(186, 116, 12, 22, 6), INK, "n"), P(rrect(122, 86, 12, 20, 6), INK, "n"),
        P(rrect(58, 156, 12, 22, 6), INK, "n"), P(rrect(186, 156, 12, 22, 6), INK, "n"),
        P(poly((96, 112), (96, 100), (108, 100), (108, 112)), "#C3C8D3", "s"), P(poly((148, 112), (148, 100), (160, 100), (160, 112)), "#C3C8D3", "s"),
        P(ell(56, 72, 5, 8), W, "n", HI),
    ]

def pizza():
    cheese = "M 48 84 C 96 58 160 58 208 84 L 128 228 Z"
    crust = "M 36 70 C 92 38 164 38 220 70 L 210 94 C 158 66 98 66 46 94 Z"
    return [
        P(cheese, "#FFD54A"),
        P(crust, "#E8A65A"),
        P("M 170 76 L 208 84 L 128 228 L 140 190 Z", "#F5B82E", "n"),
        P(ell(102, 106, 17), "#E0442F", "s"), P(ell(152, 110, 16), "#E0442F", "s"), P(ell(126, 154, 15), "#E0442F", "s"),
        P(poly((84, 136), (100, 128), (96, 146)), "#3BAA4A", "n"), P(poly((150, 150), (166, 144), (160, 160)), "#3BAA4A", "n"),
        P(ell(96, 100, 4, 6), W, "n", HI), P(ell(146, 104, 4, 6), W, "n", HI), P(ell(120, 148, 4, 6), W, "n", HI),
        P(rrect(70, 56, 40, 8, 4), W, "n", 0.5),
    ]

def wand():
    stick = poly((50, 200), (138, 112), (156, 130), (68, 218))
    return [
        P(stick, "#4A2F8A"),
        P(star(162, 94, 54, 24, 5, -80), "#FFD43B"),
        P(poly((126, 124), (138, 112), (156, 130), (144, 142)), W, "s"),
        P(star(66, 66, 20, 6, 4, -90), "#7DF9FF"), P(star(208, 178, 16, 5, 4, -90), "#7DF9FF"), P(star(208, 44, 10, 3, 4, -90), W),
        P("M 162 98 L 198 82 L 188 116 Z", "#F5A30B", "n"),
        P(ell(148, 74, 6, 10), W, "n", HI),
    ]

ICONS = [
    ("ideias", "#F7B32B", bulb), ("favoritos", "#EC4F7A", star_icon), ("historico", "#4C8DF0", clock), ("progresso", "#F28A22", trophy),
    ("loja", "#A35DE0", bag), ("ajustes", "#6F7D99", cog), ("creature", "#42B95B", monster), ("disaster", "#E5483A", meteor),
    ("vehicle", "#22B7C7", car), ("building", "#7C6CF0", castle), ("food", "#8CC63F", pizza), ("power", "#D24CD9", wand),
]

def shade(hexc, k):
    r, g, b = int(hexc[1:3], 16), int(hexc[3:5], 16), int(hexc[5:7], 16)
    if k < 0: r, g, b = (int(c * (1 + k)) for c in (r, g, b))
    else: r, g, b = (int(c + (255 - c) * k) for c in (r, g, b))
    return f"#{r:02X}{g:02X}{b:02X}"

def row_ops(names):
    """lista de camadas (d, fill, opacity, stroke_w) para uma fileira de 4 ícones, já mescladas"""
    L = []
    def add(d, fill, op=1.0, sw=0):
        if L and L[-1] is not None and L[-1][1] == fill and L[-1][2] == op and L[-1][3] == sw and L[-1][4]:
            L[-1] = (L[-1][0] + " " + d, fill, op, sw, True)
        else:
            L.append((d, fill, op, sw, True))
    tiles = [(i, n, c, fn) for i, (n, c, fn) in enumerate(names)]
    for i, n, c, fn in tiles:
        add(move(rrect(6, 6, 244, 244, 48), i * CELL, 0), INK)
    for i, n, c, fn in tiles:
        L.append((move(rrect(16, 16, 224, 224, 38), i * CELL, 0), shade(c, -0.32), 1.0, 0, False))
        L.append((move(rrect(16, 16, 224, 210, 38), i * CELL, 0), shade(c, 0.45), 1.0, 0, False))
        L.append((move(rrect(26, 26, 204, 190, 30), i * CELL, 0), c, 1.0, 0, False))
    for i, n, c, fn in tiles:
        add(move(rrect(34, 32, 188, 70, 26), i * CELL, 0), W, 0.18)
    parts = {i: fn() for i, n, c, fn in tiles}
    for i in parts:
        for d, fill, kind, op in parts[i]:
            if kind == "o": add(move(d, i * CELL, 0), INK, 1.0, 14)
    # partes coloridas: ícone por ícone, mesclando cores iguais seguidas
    for i in parts:
        L.append(None)  # quebra de mescla entre ícones
        for d, fill, kind, op in parts[i]:
            add(move(d, i * CELL, 0), fill, op, 6 if kind == "s" else 0)
    return [x for x in L if x is not None]

def svg(rows):
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="{256*len(rows)}" viewBox="0 0 1024 {256*len(rows)}">']
    for r, layers in enumerate(rows):
        out.append(f'<g transform="translate(0,{r*256})">')
        for d, fill, op, sw, _ in layers:
            st = f' stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"' if sw else ""
            out.append(f'<path d="{d}" fill="{fill}" opacity="{op}"{st}/>')
        out.append("</g>")
    out.append("</svg>")
    return "\n".join(out)

if __name__ == "__main__":
    rows = [row_ops(ICONS[0:4]), row_ops(ICONS[4:8]), row_ops(ICONS[8:12])]
    open(sys.argv[1], "w").write(svg(rows))
    print("camadas por fileira:", [len(r) for r in rows])
    json.dump([[list(l[:4]) for l in r] for r in rows], open(sys.argv[2], "w"))
