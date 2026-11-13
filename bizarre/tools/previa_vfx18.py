#!/usr/bin/env python3
"""BIZARRE AJUSTE-18 :: prévia dos VFX com as texturas reais dos pacotes (sem Roblox Studio).

Lê o catálogo curado (assets/vfx14|15/catalogo.rbxmx), simula as partículas de uma receita
(tempos, EmitCount/EmitDelay, tamanho/transparência/cor por idade, velocidade, Drag, flipbook,
LightEmission, Brightness, ZOffset) e desenha da câmera do jogador sobre um cenário de tarde.
As texturas vêm da API pública de miniaturas do Roblox para uma pasta de cache FORA do repo
(nunca são commitadas). É uma aproximação para comparar composição, cor, valor e tempo; não é
o renderizador do Roblox (sem física, sombras ou bloom exato).

uso: python3 -I bizarre/tools/previa_vfx18.py <cache_texturas> <saida.png> [cena ...]
"""
import base64
import json
import math
import os
import random
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NORMAL = {0: (1, 0, 0), 1: (0, 1, 0), 2: (0, 0, 1), 3: (-1, 0, 0), 4: (0, -1, 0), 5: (0, 0, -1)}
GRADE = {0: 1, 1: 2, 2: 4, 3: 8}  # FlipbookLayout: None, Grid2x2, Grid4x4, Grid8x8


# ------------------------------------------------------------------ catálogo (rbxmx)
def _cf(el):
    v = {c.tag: float(c.text) for c in el}
    pos = np.array([v["X"], v["Y"], v["Z"]])
    rot = np.array([[v["R00"], v["R01"], v["R02"]], [v["R10"], v["R11"], v["R12"]], [v["R20"], v["R21"], v["R22"]]])
    return pos, rot


def _seq(texto, cor=False):
    n = [float(x) for x in (texto or "").split()]
    passo = 5 if cor else 3
    return [tuple(n[i:i + passo]) for i in range(0, len(n), passo)]


def _atributos(b64):
    out = {}
    try:
        raw = base64.b64decode(b64)
        (qtd,) = struct.unpack_from("<I", raw, 0)
        o = 4
        for _ in range(qtd):
            (ln,) = struct.unpack_from("<I", raw, o)
            o += 4
            nome = raw[o:o + ln].decode("utf-8", "replace")
            o += ln
            tipo = raw[o]
            o += 1
            if tipo == 6:
                (val,) = struct.unpack_from("<d", raw, o)
                o += 8
            elif tipo == 3:
                val = raw[o] != 0
                o += 1
            elif tipo == 2:
                (sl,) = struct.unpack_from("<I", raw, o)
                o += 4
                val = raw[o:o + sl].decode("utf-8", "replace")
                o += sl
            else:
                break
            out[nome] = val
    except Exception:
        pass
    return out


def _props(item):
    p = {"_class": item.get("class")}
    pr = item.find("Properties")
    if pr is None:
        return p
    for c in pr:
        n = c.get("name")
        if c.tag in ("float", "double", "int", "int64"):
            p[n] = float(c.text)
        elif c.tag == "bool":
            p[n] = c.text == "true"
        elif c.tag == "token":
            p[n] = int(c.text)
        elif c.tag == "string":
            p[n] = c.text or ""
        elif c.tag in ("Content", "ContentId"):
            u = c.find("uri")
            if u is None:
                u = c.find("url")
            if u is not None and u.text:
                p[n] = u.text
        elif c.tag == "NumberSequence":
            p[n] = _seq(c.text)
        elif c.tag == "ColorSequence":
            p[n] = _seq(c.text, cor=True)
        elif c.tag == "NumberRange":
            a = [float(x) for x in (c.text or "0 0").split()]
            p[n] = (a[0], a[1] if len(a) > 1 else a[0])
        elif c.tag == "Vector3":
            p[n] = np.array([float(c.find(k).text) for k in "XYZ"])
        elif c.tag == "Vector2":
            p[n] = (float(c.find("X").text), float(c.find("Y").text))
        elif c.tag == "CoordinateFrame":
            p[n] = _cf(c)
        elif c.tag == "BinaryString" and n == "AttributesSerialize" and c.text:
            p["_attr"] = _atributos(c.text.strip())
    return p


def ler_catalogo():
    moldes = {}
    for arq in ("assets/vfx14/catalogo.rbxmx", "assets/vfx15/catalogo.rbxmx"):
        caminho = os.path.join(RAIZ, arq)
        if not os.path.isfile(caminho):
            continue
        raiz = ET.parse(caminho).getroot()
        for pasta in raiz.findall("Item"):
            for molde in pasta.findall("Item"):
                nome = _props(molde).get("Name")
                moldes[nome] = molde
    return moldes


def emissores(molde):
    """lista de (props do emissor, posição relativa ao pivô, rotação mundial) do molde"""
    saida = []
    pivo = None

    def andar(item, cf_pai):
        nonlocal pivo
        p = _props(item)
        cls = p["_class"]
        cf = cf_pai
        if cls in ("Part", "MeshPart") and "CFrame" in p:
            cf = p["CFrame"]
            if pivo is None:
                pivo = cf
        elif cls == "Attachment" and "CFrame" in p and cf_pai is not None:
            pos, rot = p["CFrame"]
            cf = (cf_pai[0] + cf_pai[1] @ pos, cf_pai[1] @ rot)
        if cls == "ParticleEmitter" and cf is not None:
            saida.append((p, cf))
        for filho in item.findall("Item"):
            andar(filho, cf)

    andar(molde, None)
    if pivo is None:
        return []
    inv = pivo[1].T
    return [(p, inv @ (cf[0] - pivo[0]), inv @ cf[1]) for p, cf in saida]


# ------------------------------------------------------------------ sequências
def avaliar(seq, t):
    if not seq:
        return 0.0
    if t <= seq[0][0]:
        return seq[0][1]
    for a, b in zip(seq, seq[1:]):
        if t <= b[0]:
            k = (t - a[0]) / max(1e-6, b[0] - a[0])
            return a[1] + (b[1] - a[1]) * k
    return seq[-1][1]


def avaliar_cor(seq, t):
    if not seq:
        return np.ones(3)
    if t <= seq[0][0]:
        return np.array(seq[0][1:4])
    for a, b in zip(seq, seq[1:]):
        if t <= b[0]:
            k = (t - a[0]) / max(1e-6, b[0] - a[0])
            return np.array(a[1:4]) + (np.array(b[1:4]) - np.array(a[1:4])) * k
    return np.array(seq[-1][1:4])


def tingir(seq, cor, nome):
    """mesma regra do VFXPiloto.tintSequence (AJ14)"""
    core = "core" in nome.lower() or nome.lower() == "light"
    misto = any(max(k[1:4]) - min(k[1:4]) > 0.12 for k in seq)
    out = []
    for k in seq:
        c = k[1:4]
        alto, baixo = max(c), min(c)
        branco = alto > 0.86 and alto - baixo < 0.1
        if baixo < 0.12 and alto < 0.18:
            v = c
        elif branco and (core or misto):
            v = (1.0, 1.0, 1.0)
        else:
            lum = max(0.28, c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722)
            v = (cor[0] * lum, cor[1] * lum, cor[2] * lum)
        out.append((k[0], v[0], v[1], v[2], 0))
    return out


# ------------------------------------------------------------------ câmera e cenário
class Camera:
    def __init__(self, pos, alvo, larg=960, alt=540, fov=70):
        self.pos = np.array(pos, float)
        f = np.array(alvo, float) - self.pos
        f /= np.linalg.norm(f)
        r = np.cross(f, [0, 1, 0])
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.larg, self.alt = larg, alt
        self.foco = (alt / 2) / math.tan(math.radians(fov) / 2)

    def projetar(self, p):
        d = np.array(p, float) - self.pos
        z = d @ self.f
        if z <= 0.1:
            return None
        x = d @ self.r
        y = d @ self.u
        return (self.larg / 2 + x * self.foco / z, self.alt / 2 - y * self.foco / z, z)


def cenario(cam, claro=True):
    img = Image.new("RGB", (cam.larg, cam.alt))
    d = ImageDraw.Draw(img)
    hz = cam.projetar(cam.pos + cam.f * 1000 * np.array([1, 0, 1]))
    hy = int(hz[1]) if hz else cam.alt // 2
    topo = np.array([150, 185, 230]) if claro else np.array([60, 66, 84])
    base = np.array([238, 226, 206]) if claro else np.array([92, 88, 96])
    for y in range(cam.alt):
        if y < hy:
            k = y / max(1, hy)
            c = topo * (1 - k) + base * k
        else:
            k = min(1, (y - hy) / max(1, cam.alt - hy))
            c = np.array([118, 116, 118]) * (1 - k) + np.array([72, 74, 82]) * k
            if not claro:
                c = c * 0.75
        d.line([(0, y), (cam.larg, y)], fill=tuple(int(v) for v in c))
    # prédios ao fundo (silhuetas de Morioh, só referência de valor)
    rnd = random.Random(7)
    x = -60
    while x < 60:
        w = rnd.uniform(6, 14)
        h = rnd.uniform(10, 34)
        caixa(d, cam, (x, 0, -70), (w, h, 8), (196, 180, 162) if claro else (70, 66, 74))
        x += w + rnd.uniform(1, 5)
    return img


def caixa(d, cam, centro, tam, cor, base_y=True):
    cx, cy, cz = centro
    w, h, p = tam
    y0 = cy if base_y else cy - h / 2
    pts = [(cx + sx * w / 2, y0 + sy * h, cz + sz * p / 2) for sx in (-1, 1) for sy in (0, 1) for sz in (-1, 1)]
    proj = [cam.projetar(q) for q in pts]
    if any(p is None for p in proj):
        return
    faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (1, 3, 7, 5), (0, 2, 6, 4)]
    luz = [0.82, 0.9, 0.7, 1.0, 1.08, 0.6]
    ordem = sorted(range(6), key=lambda i: -sum(proj[j][2] for j in faces[i]))
    for i in ordem:
        c = tuple(int(min(255, v * luz[i])) for v in cor)
        d.polygon([(proj[j][0], proj[j][1]) for j in faces[i]], fill=c)


def boneco(img, cam, pos, cor=(178, 168, 160)):
    """R6 simples de pé em pos (pés no chão)"""
    d = ImageDraw.Draw(img)
    x, _, z = pos
    for c, t, k in (((x - 0.5, 0, z), (1, 2, 1), 0.9), ((x + 0.5, 0, z), (1, 2, 1), 0.9), ((x, 2, z), (2, 2, 1), 1.0),
                    ((x - 1.5, 2, z), (1, 2, 1), 0.95), ((x + 1.5, 2, z), (1, 2, 1), 0.95), ((x, 4, z), (1.2, 1, 1.2), 1.05)):
        caixa(d, cam, c, t, tuple(int(v * k) for v in cor))


# ------------------------------------------------------------------ partículas
class Textura:
    cache = {}

    def __init__(self, pasta, uri):
        self.ok = False
        tid = "".join(ch for ch in (uri or "") if ch.isdigit())
        caminho = os.path.join(pasta, tid + ".png")
        if tid and os.path.isfile(caminho):
            im = Image.open(caminho).convert("RGBA")
            a = np.asarray(im).astype(np.float32) / 255.0
            # textura sem alfa (fundo preto): o brilho vira alfa (é assim que ela aparece aditiva)
            if a[..., 3].min() > 0.99:
                lum = a[..., :3].max(axis=2)
                a[..., 3] = lum
            self.arr = a
            self.ok = True

    @classmethod
    def de(cls, pasta, uri):
        if uri not in cls.cache:
            cls.cache[uri] = Textura(pasta, uri)
        return cls.cache[uri]

    def quadro(self, grade, i):
        if grade <= 1:
            return self.arr
        h, w = self.arr.shape[:2]
        cw, ch = w // grade, h // grade
        i = int(i) % (grade * grade)
        x, y = (i % grade) * cw, (i // grade) * ch
        return self.arr[y:y + ch, x:x + cw]


def direcao_aleatoria(base, spread, rnd):
    if spread[0] <= 0 and spread[1] <= 0:
        return base
    ax = math.radians(rnd.uniform(-spread[0], spread[0]))
    ay = math.radians(rnd.uniform(-spread[1], spread[1]))
    v = np.array(base, float)
    # gira em volta de dois eixos perpendiculares à direção
    tmp = np.array([0, 1, 0]) if abs(v[1]) < 0.9 else np.array([1, 0, 0])
    e1 = np.cross(v, tmp)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(v, e1)
    for eixo, ang in ((e1, ax), (e2, ay)):
        v = v * math.cos(ang) + np.cross(eixo, v) * math.sin(ang) + eixo * (eixo @ v) * (1 - math.cos(ang))
    return v / np.linalg.norm(v)


class Particula:
    __slots__ = ("emissor", "t0", "vida", "pos", "vel", "rot", "rotv", "cor", "brilho", "tex", "grade", "frame0", "escala")


def politica_contato(nome, vmin, vmax):
    """igual ao VFXPiloto._politicaContato (AJ18)"""
    n = (nome or "").lower()
    if vmax > 0.6 and (n == "light" or n.startswith("core")):
        return True, vmin, vmax
    if vmax > 0.6:
        k = 0.45 / vmax
        return False, vmin * k, vmax * k
    return False, vmin, vmax


def emitir(lista, em, cf_mundo, t0, escala, cor, rnd, contar=None, brilho_mult=1.0, contato18=False):
    p = dict(em)
    if contato18:
        pular, a, b = politica_contato(p.get("Name"), *p.get("Lifetime", (1, 1)))
        if pular:
            return
        p["Lifetime"] = (a, b)
    if brilho_mult != 1.0 and float(p.get("LightEmission", 0)) >= 0.9 and float(p.get("Brightness", 1)) <= 1.5:
        p["Brightness"] = float(p.get("Brightness", 1)) * brilho_mult
        brilho_mult = 1.0
    n = int(contar if contar is not None else (p.get("_attr", {}).get("EmitCount") or max(1, math.ceil(p.get("Rate", 0) * 0.2))))
    pos_m, rot_m = cf_mundo
    dir_local = NORMAL.get(int(p.get("EmissionDirection", 1)), (0, 1, 0))
    seq_cor = tingir(p.get("Color", [(0, 1, 1, 1, 0), (1, 1, 1, 1, 0)]), cor, p.get("Name", "")) if cor is not None else p.get("Color", [])
    for _ in range(n):
        q = Particula()
        q.emissor = p
        q.t0 = t0
        a, b = p.get("Lifetime", (1, 1))
        q.vida = rnd.uniform(a, b)
        d = direcao_aleatoria(rot_m @ np.array(dir_local, float), p.get("SpreadAngle", (0, 0)), rnd)
        sa, sb = p.get("Speed", (0, 0))
        q.vel = d * rnd.uniform(sa, sb) * escala
        q.pos = np.array(pos_m, float)
        ra, rb = p.get("Rotation", (0, 0))
        q.rot = rnd.uniform(ra, rb)
        va, vb = p.get("RotSpeed", (0, 0))
        q.rotv = rnd.uniform(va, vb)
        q.cor = seq_cor
        q.brilho = p.get("Brightness", 1) * brilho_mult
        q.tex = p.get("TextureContent") or p.get("Texture")
        q.grade = GRADE.get(int(p.get("FlipbookLayout", 0)), 1)
        q.frame0 = rnd.randrange(q.grade * q.grade) if p.get("FlipbookStartRandom") else 0
        q.escala = escala
        lista.append(q)


def estado(q, t):
    """posição, idade normalizada e tamanho em t (ou None se morta/não nasceu)"""
    idade = t - q.t0
    if idade < 0 or idade > q.vida:
        return None
    p = q.emissor
    drag = p.get("Drag", 0)
    acel = p.get("Acceleration", np.zeros(3)) * q.escala
    # integra em passos de 1/120 s (Drag = meias-vidas por segundo)
    pos = q.pos.copy()
    vel = q.vel.copy()
    passos = max(1, int(idade * 120))
    dt = idade / passos
    for _ in range(passos):
        vel = vel * (2 ** (-drag * dt)) + acel * dt
        pos = pos + vel * dt
    k = idade / max(1e-6, q.vida)
    tam = avaliar(p.get("Size", [(0, 1, 0), (1, 1, 0)]), k) * q.escala
    transp = avaliar(p.get("Transparency", [(0, 0, 0), (1, 0, 0)]), k)
    return pos, vel, k, tam, transp


def desenhar(base, cam, particulas, t, pasta, bloom=True):
    img = np.asarray(base).astype(np.float32) / 255.0
    luz = np.zeros_like(img)
    itens = []
    for q in particulas:
        e = estado(q, t)
        if e is None:
            continue
        pos, vel, k, tam, transp = e
        pr = cam.projetar(pos)
        if pr is None or tam <= 0.01 or transp >= 0.999:
            continue
        z = pr[2] - q.emissor.get("ZOffset", 0)
        itens.append((z, q, pr, vel, k, tam, transp))
    itens.sort(key=lambda it: -it[0])
    for z, q, pr, vel, k, tam, transp in itens:
        tex = Textura.de(pasta, q.tex)
        if not tex.ok:
            continue
        p = q.emissor
        px = tam * cam.foco / pr[2]
        if px < 1.5:
            continue
        modo = int(p.get("FlipbookMode", 0))
        if q.grade > 1:
            total = q.grade * q.grade
            if modo == 1:  # OneShot: todos os quadros na vida
                quadro = min(total - 1, int(k * total))
            else:
                fa, fb = p.get("FlipbookFramerate", (1, 1))
                quadro = q.frame0 + int((t - q.t0) * fa)
        else:
            quadro = 0
        arr = tex.quadro(q.grade, quadro)
        orient = int(p.get("Orientation", 0))
        sx, sy = px, px
        sq = avaliar(p.get("Squash", [(0, 0, 0), (1, 0, 0)]), k)
        if sq > 0:
            sy *= 1 + sq
            sx /= 1 + sq * 0.5
        elif sq < 0:
            sx *= 1 - sq
            sy /= 1 - sq * 0.5
        ang = q.rot + q.rotv * (t - q.t0)
        if orient in (2, 3) and np.linalg.norm(vel) > 1e-3:  # VelocityParallel / Perpendicular
            v2 = np.array([vel @ cam.r, -(vel @ cam.u)])
            ang = math.degrees(math.atan2(v2[1], v2[0])) + q.rot
            if orient == 3:
                cosv = abs((vel / np.linalg.norm(vel)) @ cam.f)
                sy *= max(0.18, cosv)
        w = max(2, int(sx))
        h = max(2, int(sy))
        im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w, h), Image.BILINEAR)
        im = im.rotate(-ang, expand=True, resample=Image.BILINEAR)
        a = np.asarray(im).astype(np.float32) / 255.0
        cx, cy = pr[0], pr[1]
        x0, y0 = int(cx - a.shape[1] / 2), int(cy - a.shape[0] / 2)
        x1, y1 = x0 + a.shape[1], y0 + a.shape[0]
        ix0, iy0 = max(0, x0), max(0, y0)
        ix1, iy1 = min(img.shape[1], x1), min(img.shape[0], y1)
        if ix1 <= ix0 or iy1 <= iy0:
            continue
        sub = a[iy0 - y0:iy1 - y0, ix0 - x0:ix1 - x0]
        cor = avaliar_cor(q.cor, k)
        rgb = sub[..., :3] * cor
        alfa = sub[..., 3:4] * (1 - transp)
        le = float(p.get("LightEmission", 0))
        br = float(q.brilho)
        reg = img[iy0:iy1, ix0:ix1]
        if le >= 0:
            le = min(1.0, le)
            aditivo = rgb * alfa * br
            normal = reg * (1 - alfa) + np.clip(rgb * min(br, 6) ** 0.5, 0, 4) * alfa
            novo = reg * (1 - le) + (reg + aditivo) * le
            novo = normal * (1 - le) + novo * le
        else:
            novo = reg * (1 - alfa) + np.clip(rgb * br, 0, 4) * alfa
        img[iy0:iy1, ix0:ix1] = novo
        luz[iy0:iy1, ix0:ix1] += np.maximum(0, novo - 1.0)
    if bloom:
        excesso = np.maximum(0, img - 1.0)
        b = Image.fromarray(np.clip(excesso * 255, 0, 255).astype(np.uint8))
        b = np.asarray(b.filter(ImageFilter.GaussianBlur(10))).astype(np.float32) / 255.0
        img = img + b * 0.6
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


# ------------------------------------------------------------------ receitas (iguais ao Luau)
def receita_hit(n, forte, versao):
    """AJ17 (antes) ou AJ18 (depois): mesma lista de VFXReceitas.hit"""
    soco = "E_Anime_Punch_0%d" % ((n - 1) % 3 + 1)
    camadas = [
        (soco, 1.65 if forte else 0.85, 0.0),
        ("S_vfxpack_premade_direction_all", 0.9 if forte else 0.5, 0.0),
        ("E_Anime_Stars_01", 1.2 if forte else 0.65, 0.0),
        ("E_Anime_Wind_01", 1.2 if forte else 0.55, 0.0),
    ]
    if versao >= 18:
        # AJ18: clarão primeiro, depois o soco, estrelas, direção e vento escalonados (skill VFX §6)
        camadas = [
            ("S_vfxpack_premade_direction_all", 0.9 if forte else 0.5, 0.0),
            (soco, 1.65 if forte else 0.85, 0.025),
            ("E_Anime_Stars_01", 1.2 if forte else 0.65, 0.04),
            ("E_Anime_Wind_01", 1.2 if forte else 0.55, 0.05),
        ]
    return camadas


def simular(moldes, camadas, pos, direcao, cor, semente=3, brilho_soco=1.0, contato18=False):
    rnd = random.Random(semente)
    d = np.array(direcao, float)
    d /= np.linalg.norm(d)
    up = np.array([0, 1, 0])
    # frame lookAt(pos, pos+dir) e eixo "front" (gira -90° em X: Y do molde aponta para dir)
    zf = -d
    xf = np.cross(up, zf)
    xf /= np.linalg.norm(xf)
    yf = np.cross(zf, xf)
    base = np.column_stack([xf, yf, zf])
    rx = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float)  # Angles(-pi/2,0,0)
    rot = base @ rx
    parts = []
    for nome, escala, quando in camadas:
        molde = moldes.get(nome)
        if molde is None:
            continue
        for em, rel, rotl in emissores(molde):
            atraso = float(em.get("_attr", {}).get("EmitDelay") or 0)
            mundo = (np.array(pos, float) + rot @ (rel * escala), rot @ rotl)
            mult = brilho_soco if nome.startswith("E_Anime_Punch") else 1.0
            emitir(parts, em, mundo, quando + atraso, escala, cor, rnd, brilho_mult=mult, contato18=contato18)
    return parts


def main():
    pasta = sys.argv[1]
    saida = sys.argv[2]
    moldes = ler_catalogo()
    roxo = (155 / 255, 92 / 255, 1.0)
    cam = Camera((1.7, 5.3, 6), (0, 3.2, -6))
    alvo = (0, 0, -5)
    impacto = (0, 3.2, -4.4)
    tempos = (0.03, 0.07, 0.12, 0.25, 0.5)
    linhas = []
    for versao, brilho in ((17, 1.0), (18, 2.4)):
        for forte in (False, True):
            parts = simular(moldes, receita_hit(1 if not forte else 4, forte, versao), impacto, (0, 0, -1), roxo, brilho_soco=brilho, contato18=versao >= 18)
            quadros = []
            for t in tempos:
                fundo = cenario(cam, claro=True)
                boneco(fundo, cam, alvo)
                quadros.append(desenhar(fundo, cam, parts, t, pasta))
            linhas.append(("AJ%d %s" % (versao, "4o soco (forte)" if forte else "soco leve"), quadros))
    w, h = cam.larg // 2, cam.alt // 2
    folha = Image.new("RGB", (w * len(tempos), (h + 18) * len(linhas)), (20, 18, 26))
    dd = ImageDraw.Draw(folha)
    for li, (rot, qs) in enumerate(linhas):
        for ci, q in enumerate(qs):
            folha.paste(q.resize((w, h)), (ci * w, li * (h + 18) + 18))
            dd.text((ci * w + 4, li * (h + 18) + 3), "%s  t=%.2fs" % (rot, tempos[ci]), fill=(255, 214, 90))
    folha.save(saida, quality=88)
    print("prévia:", saida, folha.size)


if __name__ == "__main__":
    main()
