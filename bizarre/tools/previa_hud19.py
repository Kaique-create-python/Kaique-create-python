#!/usr/bin/env python3
"""BIZARRE AJUSTE-19 :: desenha a árvore de GUI exportada por previa_hud19.luau (Chromium).

Monta a tela do celular: cenário de tarde (claro e escuro, para testar contraste), barra do
Roblox em cima, joystick e botão de pulo do Roblox em fantasma, e por cima as ScreenGuis do
jogo, com UIScale, UICorner, UIStroke, UIGradient (Scale/Repeat), UIListLayout, rotação,
recorte (ClipsDescendants), Path2D e texto TextScaled ajustado ao quadro. Não é o renderizador do
Roblox (fontes da web, sem bloom): serve para ver layout, tamanhos, cores e sobreposição.

uso: python3 -I bizarre/tools/previa_hud19.py <pasta_fontes> <saida.png> <hud.json> [hud2.json ...]
  pasta_fontes: fontes_local.css + .woff2 (Bangers, Montserrat, Roboto Condensed, Oswald),
  baixadas do Google Fonts para uma pasta FORA do repositório. Sem elas usa fontes do sistema.
"""
import html
import json
import os
import re
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter

PESOS = {"Thin": 100, "ExtraLight": 200, "Light": 300, "Regular": 400, "Medium": 500,
         "SemiBold": 600, "Bold": 700, "ExtraBold": 800, "Heavy": 900}
FAMILIAS = {"Bangers": "Bangers", "GothamSSm": "Montserrat", "Montserrat": "Montserrat",
            "RobotoCondensed": "Roboto Condensed", "Oswald": "Oswald", "BuilderSans": "Inter",
            "Roboto": "Roboto Condensed", "SourceSansPro": "Inter", "Arimo": "Inter"}


def lado(largura):
    return 48 if largura <= 760 else 62


# ---------------------------------------------------------------- cenário (fundo de teste)
def cenario(caminho, w, h):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    horizonte = int(h * 0.56)
    for y in range(horizonte):
        k = y / horizonte
        d.line([(0, y), (w, y)], fill=(int(120 + 110 * k), int(170 + 70 * k), int(225 + 20 * k)))
    d.ellipse([w * 0.72, h * 0.06, w * 0.72 + h * 0.2, h * 0.26], fill=(255, 250, 225))
    blocos = [(0.00, 0.30, (214, 200, 178)), (0.08, 0.18, (238, 233, 222)), (0.15, 0.36, (186, 176, 160)),
              (0.24, 0.22, (245, 240, 228)), (0.33, 0.42, (160, 150, 140)), (0.43, 0.26, (226, 214, 190)),
              (0.52, 0.34, (250, 247, 240)), (0.62, 0.20, (200, 186, 166)), (0.70, 0.40, (230, 222, 205)),
              (0.80, 0.28, (176, 168, 156)), (0.88, 0.33, (244, 238, 226))]
    for x0, alt, c in blocos:
        x1 = x0 + 0.105
        topo = horizonte - alt * h
        d.rectangle([x0 * w, topo, x1 * w, horizonte], fill=c)
        for jy in range(int(topo) + 8, horizonte - 6, 14):
            for jx in range(int(x0 * w) + 6, int(x1 * w) - 8, 13):
                d.rectangle([jx, jy, jx + 6, jy + 7], fill=tuple(max(0, v - 55) for v in c))
    d.rectangle([0, horizonte, w, h], fill=(96, 98, 104))
    d.polygon([(0, horizonte + 8), (w, horizonte + 8), (w, horizonte + 22), (0, horizonte + 22)], fill=(190, 186, 176))
    for i in range(0, w, 70):
        d.rectangle([i, int(h * 0.80), i + 34, int(h * 0.80) + 4], fill=(235, 230, 210))

    def boneco(cx, base, k, cor):
        d.rectangle([cx - 9 * k, base - 52 * k, cx + 9 * k, base - 26 * k], fill=cor)
        d.rectangle([cx - 7 * k, base - 66 * k, cx + 7 * k, base - 52 * k], fill=(245, 205, 160))
        d.rectangle([cx - 9 * k, base - 26 * k, cx - 1 * k, base], fill=(40, 40, 60))
        d.rectangle([cx + 1 * k, base - 26 * k, cx + 9 * k, base], fill=(40, 40, 60))
        d.rectangle([cx - 15 * k, base - 52 * k, cx - 9 * k, base - 30 * k], fill=cor)
        d.rectangle([cx + 9 * k, base - 52 * k, cx + 15 * k, base - 30 * k], fill=cor)

    boneco(w * 0.47, h * 0.86, h / 300, (50, 46, 90))
    boneco(w * 0.64, h * 0.70, h / 520, (150, 40, 50))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(caminho)


# ---------------------------------------------------------------- tradução GUI -> HTML
def rgba(c, t=0.0):
    return f"rgba({c[0]},{c[1]},{c[2]},{max(0.0, min(1.0, 1 - t)):.3f})"


def mistura(cs, ts, base, base_t):
    """Paradas do UIGradient: cor = base x gradiente; alfa = (1-base_t)(1-t)."""
    tempos = sorted({round(k[0], 4) for k in cs} | {round(k[0], 4) for k in ts})

    def interp(seq, t, idx):
        for i in range(len(seq) - 1):
            a, b = seq[i], seq[i + 1]
            if a[0] <= t <= b[0]:
                f = 0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
                if idx:
                    return [a[1][j] + (b[1][j] - a[1][j]) * f for j in range(3)]
                return a[1] + (b[1] - a[1]) * f
        return seq[-1][1]

    paradas = []
    for t in tempos:
        c = interp(cs, t, True)
        tr = interp(ts, t, False)
        cor = [round(base[j] * c[j] / 255) for j in range(3)]
        alfa = (1 - base_t) * (1 - tr)
        paradas.append((t, f"rgba({cor[0]},{cor[1]},{cor[2]},{alfa:.3f})"))
    return paradas


def gradiente_css(g, base, base_t):
    paradas = mistura(g["cores"], g["transp"], base, base_t)
    angulo = 90 + g.get("rot", 0)
    k = g.get("escala", 1) or 1
    if g.get("modo") in ("Repeat", "Mirror") and k < 1:
        lista = ", ".join(f"{c} {t * k * 100:.2f}%" for t, c in paradas)
        return f"repeating-linear-gradient({angulo}deg, {lista})"
    lista = ", ".join(f"{c} {t * 100:.2f}%" for t, c in paradas)
    return f"linear-gradient({angulo}deg, {lista})"


def rico(texto):
    saida = html.escape(texto, quote=False)
    saida = re.sub(r'&lt;font color="#?([0-9A-Fa-f]{6})"&gt;', r'<span style="color:#\1">', saida)
    saida = re.sub(r"&lt;/font&gt;", "</span>", saida)
    saida = re.sub(r"&lt;(/?)(b|i)&gt;", r"<\1\2>", saida)
    saida = saida.replace("&lt;br/&gt;", "<br>")
    return saida


def fonte_css(f):
    fam, peso, estilo = f
    nome = re.sub(r".*/|\.json$", "", fam) if "/" in fam else fam.replace("Enum.Font.", "")
    if "Bold" in nome and nome not in FAMILIAS:
        nome, peso = nome.replace("Bold", ""), "Bold"
    familia = FAMILIAS.get(nome, nome)
    return f"font-family:'{familia}','Inter',sans-serif;font-weight:{PESOS.get(peso, 400)};font-style:{'italic' if estilo == 'Italic' else 'normal'}"


def mods(d):
    m = {}
    for f in d.get("filhos", []):
        m.setdefault(f["classe"], []).append(f)
    return m


def gui(d, pw, ph, s, lista_pos=None):
    if d.get("visivel") is False:
        return ""
    m = mods(d)
    w = d["tam"][0] * pw + d["tam"][1]
    h = d["tam"][2] * ph + d["tam"][3]
    if lista_pos is not None:
        x, y = lista_pos
    else:
        x = d["pos"][0] * pw + d["pos"][1] - d["ancora"][0] * w
        y = d["pos"][2] * ph + d["pos"][3] - d["ancora"][1] * h
    est = [f"left:{x * s:.2f}px", f"top:{y * s:.2f}px", f"width:{max(0, w) * s:.2f}px", f"height:{max(0, h) * s:.2f}px",
           f"z-index:{d.get('z', 1)}"]
    sombras = []
    raio = 0
    if "UICorner" in m:
        r = m["UICorner"][0]["raio"]
        raio = r[0] * min(w, h) + r[1]
        est.append(f"border-radius:{raio * s:.2f}px")
    eh_texto = "texto" in d
    fundo_t = d.get("fundoT", 1)
    grads = m.get("UIGradient", [])
    if fundo_t < 1:
        if grads and not (eh_texto and fundo_t >= 1):
            est.append("background:" + ", ".join(gradiente_css(g, d["fundo"], fundo_t) for g in grads[:1]))
        else:
            est.append(f"background:{rgba(d['fundo'], fundo_t)}")
    for st in m.get("UIStroke", []):
        if st["modo"] == "Border" or not eh_texto:
            e = st["esp"] * s
            pos = st.get("posicao", "Outer")
            if pos == "Inner":
                sombras.append(f"inset 0 0 0 {e:.2f}px {rgba(st['cor'], st['t'])}")
            else:
                sombras.append(f"0 0 0 {e if pos == 'Outer' else e / 2:.2f}px {rgba(st['cor'], st['t'])}")
    if sombras:
        est.append("box-shadow:" + ", ".join(sombras))
    if d.get("rot"):
        est.append(f"transform:rotate({d['rot']}deg)")
    if d.get("clip"):
        est.append("overflow:hidden")
    if d["classe"] == "CanvasGroup":
        est.append(f"opacity:{1 - d.get('grupoT', 0):.3f}")
    for sc in m.get("UIScale", []):
        if abs(sc["escala"] - 1) > 1e-3:
            est.append(f"transform:scale({sc['escala']})")
    dentro = ""
    if eh_texto and d["texto"]:
        contorno = [st for st in m.get("UIStroke", []) if st["modo"] != "Border"]
        alin = {"Left": "flex-start", "Center": "center", "Right": "flex-end"}
        alinv = {"Top": "flex-start", "Center": "center", "Bottom": "flex-end"}
        ts = []
        for st in contorno[:1]:
            e = max(0.6, st["esp"] * s)
            cor = rgba(st["cor"], max(st["t"], d.get("textoT", 0)))
            for i in range(16):
                import math
                a = i * math.pi / 8
                ts.append(f"{math.cos(a) * e:.2f}px {math.sin(a) * e:.2f}px 0 {cor}")
        lim = m.get("UITextSizeConstraint", [{}])[0].get("max", 100)
        cor_txt = rgba(d["textoCor"], d.get("textoT", 0))
        grad_txt = ""
        if grads and eh_texto and fundo_t >= 1:
            grad_txt = ""
        t_est = [fonte_css(d["fonte"]), f"color:{cor_txt}", f"text-align:{d['alinX'].lower()}",
                 "white-space:" + ("normal" if d.get("quebra") else "nowrap")]
        if ts:
            t_est.append("text-shadow:" + ",".join(ts))
        atributos = f'data-escalado="{1 if d.get("escalado") else 0}" data-max="{lim}" data-tam="{d.get("textoTam", 14)}" data-s="{s}"'
        conteudo = rico(d["texto"]) if d.get("rico") else html.escape(d["texto"])
        dentro += (f'<div class="txt" style="justify-content:{alin.get(d["alinX"], "center")};align-items:{alinv.get(d["alinY"], "center")}">'
                   f'<span {atributos} style="{";".join(t_est)}{grad_txt}">{conteudo}</span></div>')
    # filhos
    filhos = [f for f in d.get("filhos", []) if f["classe"] not in ("UICorner", "UIStroke", "UIGradient", "UIScale",
                                                                      "UITextSizeConstraint", "UIListLayout", "UIPadding",
                                                                      "UIAspectRatioConstraint", "Path2D")]
    filhos = [f for f in filhos if "tam" in f]
    pad = m.get("UIPadding", [{"pad": [0, 0, 0, 0]}])[0]["pad"]
    iw, ih = w - pad[0] - pad[1], h - pad[2] - pad[3]
    posicoes = {}
    if "UIListLayout" in m:
        L = m["UIListLayout"][0]
        vis = [f for f in filhos if f.get("visivel", True)]
        if L["ordenar"] == "LayoutOrder":
            vis.sort(key=lambda f: f.get("ordem", 0))
        esp = L["espaco"][0] * (ih if L["dir"] == "Vertical" else iw) + L["espaco"][1]
        tams = [(f["tam"][0] * iw + f["tam"][1], f["tam"][2] * ih + f["tam"][3]) for f in vis]
        if L["dir"] == "Vertical":
            total = sum(t[1] for t in tams) + esp * max(0, len(tams) - 1)
            y0 = {"Top": 0, "Center": (ih - total) / 2, "Bottom": ih - total}[L["alinV"]]
            for f, (fw, fh) in zip(vis, tams):
                x0 = {"Left": 0, "Center": (iw - fw) / 2, "Right": iw - fw}[L["alinH"]]
                posicoes[id(f)] = (pad[0] + x0, pad[2] + y0)
                y0 += fh + esp
        else:
            total = sum(t[0] for t in tams) + esp * max(0, len(tams) - 1)
            x0 = {"Left": 0, "Center": (iw - total) / 2, "Right": iw - total}[L["alinH"]]
            for f, (fw, fh) in zip(vis, tams):
                y0 = {"Top": 0, "Center": (ih - fh) / 2, "Bottom": ih - fh}[L["alinV"]]
                posicoes[id(f)] = (pad[0] + x0, pad[2] + y0)
                x0 += fw + esp
    ordem = sorted(range(len(filhos)), key=lambda i: (filhos[i].get("z", 1), i))
    for i in ordem:
        f = filhos[i]
        dentro += gui(f, iw, ih, s, posicoes.get(id(f)))
    for p in m.get("Path2D", []):
        pts = json.loads(p["pontos"] or "[]")
        if pts:
            xy = " ".join(f"{(a * w + b) * s:.2f},{(c * h + e) * s:.2f}" for a, b, c, e in pts)
            forma = "polygon" if p.get("fechado") else "polyline"
            dentro += (f'<svg class="p2d" width="{w * s:.2f}" height="{h * s:.2f}"><{forma} points="{xy}" fill="none" '
                       f'stroke="{rgba(p["cor"])}" stroke-width="{p["esp"] * s:.2f}" stroke-linejoin="miter"/></svg>')
    return f'<div class="g" style="{";".join(est)}">{dentro}</div>'


def retangulos(d, ox, oy, pw, ph, s, clip, saida, lista_pos=None):
    """Retângulos pintados (fundo visível ou texto) em px da área segura, recortados como no motor."""
    if d.get("visivel") is False or "tam" not in d:
        return
    m = mods(d)
    w = d["tam"][0] * pw + d["tam"][1]
    h = d["tam"][2] * ph + d["tam"][3]
    if lista_pos is not None:
        x, y = lista_pos
    else:
        x = d["pos"][0] * pw + d["pos"][1] - d["ancora"][0] * w
        y = d["pos"][2] * ph + d["pos"][3] - d["ancora"][1] * h
    ax, ay = ox + x * s, oy + y * s
    r = [ax, ay, ax + w * s, ay + h * s]
    if clip:
        r = [max(r[0], clip[0]), max(r[1], clip[1]), min(r[2], clip[2]), min(r[3], clip[3])]
    pinta = d.get("fundoT", 1) < 0.98 or d["classe"] == "CanvasGroup" or (d.get("texto") and d.get("textoT", 0) < 0.98)
    if pinta and r[2] > r[0] and r[3] > r[1] and not d.get("rot"):
        saida.append(r)
    elif pinta and d.get("rot") and clip:
        saida.append(list(clip))
    novo_clip = r if (d.get("clip") or d["classe"] == "CanvasGroup") else clip
    filhos = [f for f in d.get("filhos", []) if "tam" in f]
    pad = m.get("UIPadding", [{"pad": [0, 0, 0, 0]}])[0]["pad"]
    for f in filhos:
        retangulos(f, ax + pad[0] * s, ay + pad[2] * s, w - pad[0] - pad[1], h - pad[2] - pad[3], s, novo_clip, saida)


def cobertura(dados):
    """(HUD sem botões %, botões de toque %, centro 50%x50% coberto por qualquer um %), medida da skill
    roblox-ui-layout. Use a cena 'medir' (sem combo/abates, que somem sozinhos)."""
    import numpy as np
    W, H = dados["largura"], dados["altura"]
    mascaras = {}
    for g in dados["telas"]:
        if not g.get("ativo", True):
            continue
        m = mods(g)
        s = m["UIScale"][0]["escala"] if "UIScale" in m else 1.0
        rs = []
        for f in g["filhos"]:
            retangulos(f, 0, 0, W / s, H / s, s, None, rs)
        mask = mascaras.setdefault("botoes" if g["nome"] == "BB_Botoes" else "hud", np.zeros((H, W), dtype=bool))
        for r in rs:
            x0, y0, x1, y1 = (int(max(0, min(W, v))) if i % 2 == 0 else int(max(0, min(H, v))) for i, v in enumerate(r))
            mask[y0:y1, x0:x1] = True
    hud = mascaras.get("hud", np.zeros((H, W), dtype=bool))
    bot = mascaras.get("botoes", np.zeros((H, W), dtype=bool))
    tudo = hud | bot
    centro = tudo[H // 4: 3 * H // 4, W // 4: 3 * W // 4]
    return 100 * hud.mean(), 100 * bot.mean(), 100 * centro.mean()


def tela(dados, fundo_png):
    W, H = dados["largura"], dados["altura"]
    L = lado(W)
    T, B = 58, 22
    SW, SH = W + 2 * L, H + T + B
    corpo = []
    for g in sorted(dados["telas"], key=lambda t: t.get("ordemTela", 0)):
        if not g.get("ativo", True):
            continue
        m = mods(g)
        s = m["UIScale"][0]["escala"] if "UIScale" in m else 1.0
        vw, vh = W / s, H / s
        filhos = [f for f in g["filhos"] if "tam" in f]
        ordem = sorted(range(len(filhos)), key=lambda i: (filhos[i].get("z", 1), i))
        dentro = "".join(gui(filhos[i], vw, vh, s) for i in ordem)
        corpo.append(f'<div class="tela" style="left:{L}px;top:{T}px;width:{W}px;height:{H}px">{dentro}</div>')
    # Roblox: barra de cima, joystick e pulo (área segura)
    roblox = (f'<div class="rbx" style="left:{L + 12}px;top:9px;width:40px;height:40px;border-radius:10px"></div>'
              f'<div class="rbx" style="left:{L + 60}px;top:9px;width:104px;height:40px;border-radius:20px"></div>')
    if not dados.get("pc"):
        grande = min(W, H) > 500
        if grande:  # controles grandes do Roblox (lado curto da área segura > 500)
            roblox += (f'<div class="stick" style="left:{L + 132 - 74}px;top:{T + H - 112 - 74}px;width:148px;height:148px"></div>'
                       f'<div class="pulo" style="left:{L + W - 50 - 120}px;top:{T + H - 90 - 120}px;width:120px;height:120px">&#8679;</div>')
        else:
            roblox += (f'<div class="stick" style="left:{L + 66 - 37}px;top:{T + H - 56 - 37}px"></div>'
                       f'<div class="pulo" style="left:{L + W - 25 - 70}px;top:{T + H - 20 - 70}px">&#8679;</div>')
    return (f'<div class="cel" style="width:{SW}px;height:{SH}px;background-image:url({fundo_png})">'
            f'{"".join(corpo)}{roblox}</div>')


CSS = """
body{margin:0;background:#0d0d12;font-family:Inter,sans-serif}
.rot{color:#d9d4e8;font:600 14px Inter,sans-serif;margin:14px 16px 6px}
.cel{position:relative;overflow:hidden;background-size:cover;margin:0 16px 10px;border-radius:26px;box-shadow:0 0 0 6px #22202b}
.tela{position:absolute}
.g{position:absolute;box-sizing:border-box}
.txt{position:absolute;inset:0;display:flex;overflow:visible}
.txt>span{display:block;max-width:100%}
.p2d{position:absolute;left:0;top:0;overflow:visible;z-index:50}
.rbx{position:absolute;background:rgba(18,18,22,.62);box-shadow:0 0 0 1px rgba(255,255,255,.14)}
.stick{position:absolute;width:74px;height:74px;border-radius:50%;box-shadow:inset 0 0 0 3px rgba(255,255,255,.45);background:rgba(0,0,0,.18)}
.stick::after{content:'';position:absolute;left:24px;top:24px;width:26px;height:26px;border-radius:50%;background:rgba(255,255,255,.55)}
.pulo{position:absolute;width:70px;height:70px;border-radius:50%;background:rgba(0,0,0,.30);box-shadow:inset 0 0 0 3px rgba(255,255,255,.55);color:rgba(255,255,255,.8);font:700 34px Inter;display:flex;align-items:center;justify-content:center}
"""

JS = """
async function ajustar(){
  await document.fonts.ready;
  for (const sp of document.querySelectorAll('.txt>span')){
    const box=sp.parentElement; const s=+sp.dataset.s; const bw=box.clientWidth, bh=box.clientHeight;
    const quebra=sp.style.whiteSpace==='normal';
    const aplicar=(t)=>{sp.style.fontSize=(t*s/1.215)+'px';sp.style.lineHeight=(t*s)+'px';};
    if(sp.dataset.escalado==='1'){
      let lo=1, hi=Math.min(100,+sp.dataset.max||100);
      while(lo<hi){const mid=Math.ceil((lo+hi)/2);aplicar(mid);
        const ok=sp.scrollWidth<=bw+0.5 && sp.scrollHeight<=bh+0.5 && (!quebra || sp.offsetWidth<=bw+0.5);
        if(ok) lo=mid; else hi=mid-1;}
      aplicar(lo);
    } else { aplicar(Math.min(+sp.dataset.tam, +sp.dataset.max||100)); }
    if(quebra) sp.style.width='100%';
  }
  document.body.dataset.pronto='1';
}
ajustar();
"""


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    pasta, saida, jsons = argv[1], argv[2], argv[3:]
    css_fontes = ""
    caminho_css = os.path.join(pasta, "fontes_local.css")
    if os.path.isfile(caminho_css):
        css_fontes = open(caminho_css).read()
        css_fontes = re.sub(r"url\(([0-9a-f]+\.woff2)\)", lambda mt: f"url(file://{os.path.abspath(os.path.join(pasta, mt.group(1)))})", css_fontes)
    with tempfile.TemporaryDirectory() as tmp:
        partes = []
        largura_max = 0
        for caminho in jsons:
            dados = json.load(open(caminho))
            W, H = dados["largura"], dados["altura"]
            SW, SH = W + 2 * lado(W), H + 80
            fundo = os.path.join(tmp, f"fundo_{SW}x{SH}.png")
            if not os.path.exists(fundo):
                cenario(fundo, SW, SH)
            hud, bot, centro = cobertura(dados)
            rot = f"{os.path.basename(caminho)} · {dados['stand']} · cena {dados['cena']} · área segura {W}x{H}"
            print(f"{os.path.basename(caminho)} ({dados['cena']}): HUD {hud:.1f}% da tela · botões {bot:.1f}% · centro coberto {centro:.1f}%")
            partes.append(f'<div class="rot">{html.escape(rot)}</div>' + tela(dados, "file://" + fundo))
            largura_max = max(largura_max, SW + 32)
        pagina = f"<!doctype html><meta charset='utf-8'><style>{css_fontes}{CSS}</style><body>{''.join(partes)}<script>{JS}</script>"
        arq = os.path.join(tmp, "hud.html")
        open(arq, "w").write(pagina)
        if saida.endswith(".html"):
            open(saida, "w").write(pagina)
            return 0
        # Playwright de Node (já instalado no ambiente); o Python não precisa do pacote
        script = ("const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();"
                  f"const p=await b.newPage({{viewport:{{width:{largura_max},height:400}},deviceScaleFactor:2}});"
                  f"await p.goto({json.dumps('file://' + arq)});"
                  "await p.waitForSelector(\"body[data-pronto='1']\",{timeout:20000});"
                  f"await p.screenshot({{path:{json.dumps(os.path.abspath(saida))},fullPage:true}});await b.close();}})()"
                  ".catch(e=>{console.error(e);process.exit(1)});")
        import subprocess
        subprocess.run(["node", "-e", script], check=True)
    print("prévia:", saida)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
