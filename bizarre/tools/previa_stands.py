#!/usr/bin/env python3
"""BIZARRE BATTLEGROUNDS :: cartões de prévia dos 6 Stands.
Baixa a miniatura do corpo musculoso (catálogo do Roblox) e pinta com as cores de cada Stand,
mais ou menos como o jogo faz (no jogo o corpo fica liso, brilhando e com acessórios).
uso (na raiz): python3 bizarre/tools/previa_stands.py
"""
import io
import json
import re
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

SAIDA = "bizarre/previas/5_stands.png"
FONTE = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
FONTE_TXT = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"

# (id, nome, titulo, tipo, bundle do corpo, cor, cor2, corPernas, acessorios)
STANDS = [
    ("MARACATU", "MARACATU", "Punho dos Tambores", "Força", 5802551313168, (64, 54, 178), (246, 196, 44), (40, 34, 120), [117863952882880]),
    ("BOSSA_NOVA", "BOSSA NOVA", "O Compasso Dourado", "Tempo", 109351509547858, (236, 186, 40), (36, 168, 160), (196, 146, 26), [14012017490, 13327536349]),
    ("FREVO", "FREVO", "A Sombrinha Veloz", "Velocidade", 150753842880676, (232, 44, 70), (36, 200, 96), (40, 120, 230), [123031145668425]),
    ("AXE", "AXÉ", "O Sol da Bahia", "Fogo", 149139946992979, (255, 112, 28), (255, 214, 60), (196, 40, 22), [125093887001578, 84965512650204]),
    ("CHORINHO", "CHORINHO", "O Remendo", "Restauração", 255575209700312, (255, 132, 196), (150, 236, 255), (214, 88, 160), [7331284875]),
    ("FUNK", "FUNK", "O Paredão do Grave", "Som", 115720883611504, (130, 46, 220), (36, 36, 44), (28, 26, 36), [81576078203849, 124853841101197]),
]


def get(url, binario=False):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for t in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                dados = r.read()
                return dados if binario else json.loads(dados.decode())
        except Exception:
            if t == 2:
                raise
            time.sleep(1.5)


def miniaturas(tipo, ids, tam="420x420"):
    chave = "bundleIds" if tipo == "bundles" else "assetIds"
    caminho = "bundles/thumbnails" if tipo == "bundles" else "assets"
    d = get("https://thumbnails.roblox.com/v1/%s?%s" % (caminho, urllib.parse.urlencode({chave: ",".join(map(str, ids)), "size": tam, "format": "Png", "returnPolicy": "PlaceHolder"})))
    out = {}
    for x in d.get("data", []):
        if x.get("imageUrl"):
            out[x["targetId"]] = Image.open(io.BytesIO(get(x["imageUrl"], True))).convert("RGBA")
    return out


def pintar(img, escuro, cor, claro):
    alfa = img.getchannel("A")
    cinza = ImageOps.grayscale(img)
    cinza = ImageOps.autocontrast(cinza, cutoff=2)
    pintado = ImageOps.colorize(cinza, black=escuro, mid=cor, white=claro).convert("RGBA")
    pintado.putalpha(alfa)
    return pintado


def main():
    corpos = miniaturas("bundles", [s[4] for s in STANDS])
    todos_acess = [a for s in STANDS for a in s[8]]
    acess = miniaturas("assets", todos_acess, "150x150")
    W, H = 1500, 900
    tela = Image.new("RGB", (W, H), (16, 8, 32))
    fundo = Image.new("RGB", (W, H))
    dr = ImageDraw.Draw(fundo)
    for y in range(H):
        k = y / H
        dr.line([(0, y), (W, y)], fill=(int(60 - 40 * k), int(24 - 14 * k), int(110 - 70 * k)))
    tela.paste(fundo)
    d = ImageDraw.Draw(tela)
    f_titulo = ImageFont.truetype(FONTE, 54)
    f_nome = ImageFont.truetype(FONTE, 40)
    f_sub = ImageFont.truetype(FONTE_TXT, 22)
    d.text((40, 24), "BIZARRE BATTLEGROUNDS", font=f_titulo, fill=(255, 206, 64), stroke_width=4, stroke_fill=(20, 8, 30))
    d.text((44, 92), "os 6 Stands (corpo musculoso do catálogo, pintado pelo jogo)", font=f_sub, fill=(220, 200, 255))
    cw, ch = 460, 360
    for i, s in enumerate(STANDS):
        sid, nome, titulo, tipo, bundle, cor, cor2, pernas, acs = s
        x = 40 + (i % 3) * (cw + 20)
        y = 140 + (i // 3) * (ch + 20)
        cartao = Image.new("RGBA", (cw, ch), (24, 16, 44, 255))
        cd = ImageDraw.Draw(cartao)
        cd.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=22, outline=cor, width=5)
        # brilho da aura atrás do corpo
        aura = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        ad = ImageDraw.Draw(aura)
        ad.ellipse([cw // 2 - 150, 30, cw // 2 + 150, 330], fill=cor + (120,))
        aura = aura.filter(ImageFilter.GaussianBlur(40))
        cartao = Image.alpha_composite(cartao, aura)
        corpo = corpos.get(bundle)
        if corpo:
            escuro = tuple(max(0, int(c * 0.25)) for c in pernas)
            claro = tuple(min(255, int(c + (255 - c) * 0.55)) for c in cor)
            p = pintar(corpo, escuro, cor, claro).resize((300, 300), Image.LANCZOS)
            cartao.alpha_composite(p, (cw // 2 - 150 - 40, 34))
        for k, aid in enumerate(acs):
            a = acess.get(aid)
            if a:
                cartao.alpha_composite(a.resize((96, 96), Image.LANCZOS), (cw - 112, 20 + k * 100))
        cd = ImageDraw.Draw(cartao)
        cd.text((22, ch - 104), nome, font=f_nome, fill=cor, stroke_width=3, stroke_fill=(10, 4, 20))
        cd.text((24, ch - 56), "%s  ·  %s" % (titulo, tipo), font=f_sub, fill=(240, 236, 255))
        tela.paste(cartao.convert("RGB"), (x, y), cartao)
    tela.save(SAIDA)
    print("ok", SAIDA)


if __name__ == "__main__":
    main()
