#!/usr/bin/env python3
"""OI3 :: gera os áudios do jogo.

- Efeitos e ambientes: sintetizados por código (numpy/scipy), sem IA.
- Vozes: recortadas das gravações do ElevenLabs (pasta de entrada), tratadas e
  juntadas num "sprite" (um arquivo só com vários trechos).
- Gera oi3/assets/*.ogg e o módulo Luau AudioMapa.luau com os tempos de cada trecho.

uso: python3 oi3/tools/audio.py <pasta_com_mp3_do_elevenlabs>
"""
import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(RAIZ, "assets")
MAPA_LUAU = os.path.join(RAIZ, "src", "ReplicatedStorage", "OI3", "AudioMapa.luau")
rng = np.random.default_rng(1983)


# ---------------------------------------------------------------- utilidades
def tt(d):
    return np.arange(int(round(d * SR))) / SR


def ruido(d):
    return rng.standard_normal(int(round(d * SR)))


def filtro(x, tipo, f, ordem=2):
    if isinstance(f, (list, tuple)):
        wn = [min(max(v / (SR / 2), 1e-4), 0.999) for v in f]
    else:
        wn = min(max(f / (SR / 2), 1e-4), 0.999)
    sos = signal.butter(ordem, wn, btype=tipo, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, o=2):
    return filtro(x, "lowpass", f, o)


def hp(x, f, o=2):
    return filtro(x, "highpass", f, o)


def bp(x, f1, f2, o=2):
    return filtro(x, "bandpass", [f1, f2], o)


def ressonante(x, f, q=12):
    b, a = signal.iirpeak(f / (SR / 2), q)
    return signal.lfilter(b, a, x)


def suave_aleatorio(d, taxa, semente=None):
    """curva aleatória suave entre 0 e 1 (para rajadas)."""
    g = np.random.default_rng(semente)
    n = max(4, int(d * taxa) + 4)
    pontos = g.random(n)
    x = np.linspace(0, n - 1, int(round(d * SR)))
    c = np.interp(x, np.arange(n), pontos)
    return lp(c, max(taxa, 0.5), 1)


def norm(x, pico=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * pico


def fade(x, ini=0.01, fim=0.02):
    y = x.copy()
    a = int(ini * SR)
    b = int(fim * SR)
    if a > 0:
        y[:a] *= np.linspace(0, 1, a)
    if b > 0:
        y[-b:] *= np.linspace(1, 0, b)
    return y


def reverb(x, dur=2.0, mistura=0.3, decai=3.0, corte=4500, semente=5):
    g = np.random.default_rng(semente)
    n = int(dur * SR)
    ir = g.standard_normal(n) * np.exp(-decai * np.arange(n) / SR)
    ir = lp(ir, corte)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    molhado = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - mistura) + molhado * mistura * 1.6


def emloop(x, xf=1.0):
    """deixa o som emendável (o fim desaparece dentro do começo)."""
    n = int(xf * SR)
    y = x[:-n].copy()
    ent = np.linspace(0, 1, n)
    y[:n] = y[:n] * np.sqrt(ent) + x[-n:] * np.sqrt(1 - ent)
    return y


def env_exp(d, tau, ataque=0.003):
    t = tt(d)
    e = np.exp(-t / tau)
    a = int(ataque * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def serra(freq_inst):
    fase = np.cumsum(freq_inst) / SR
    return 2 * (fase - np.floor(fase + 0.5))


def seno(freq_inst):
    return np.sin(2 * np.pi * np.cumsum(freq_inst) / SR)


def colocar(base, som, inicio, ganho=1.0):
    i = int(inicio * SR)
    j = min(len(base), i + len(som))
    base[i:j] += som[: j - i] * ganho


# ---------------------------------------------------------------- efeitos
def vento(d=14.0):
    base = lp(ruido(d + 1), 700, 2) * (0.35 + 0.65 * suave_aleatorio(d + 1, 0.35, 1))
    uivo = np.zeros(int((d + 1) * SR))
    for k, f in enumerate([340, 520, 760]):
        mod = suave_aleatorio(d + 1, 0.25, 10 + k) ** 2
        uivo += ressonante(ruido(d + 1), f, 30) * mod * (0.6 / (k + 1))
    x = base + uivo * 0.9
    x = hp(x, 60)
    return norm(emloop(x, 1.0), 0.6)


def rangido(d=2.4, base_f=170, semente=3):
    g = np.random.default_rng(semente)
    t = tt(d)
    f = base_f + 55 * np.sin(2 * np.pi * 0.35 * t) + 25 * g.standard_normal(len(t)).cumsum() / np.sqrt(len(t)) * 3
    f = lp(f, 30, 1)
    x = serra(np.clip(f, 60, 600))
    gr = (suave_aleatorio(d, 9, semente + 1) > 0.42).astype(float)
    gr = lp(gr, 40, 1)
    x = x * (0.3 + 0.7 * gr)
    y = ressonante(x, 620, 8) + 0.6 * ressonante(x, 1450, 10) + 0.3 * ressonante(x, 2600, 12)
    env = np.minimum(1, t / 0.25) * np.minimum(1, (d - t) / 0.5)
    y = y * env + 0.02 * hp(ruido(d), 2000) * env
    return norm(reverb(y, 1.2, 0.25, 4), 0.75)


def interior(d=12.0):
    x = lp(np.cumsum(ruido(d + 1)) * 0.02, 160) + 0.25 * lp(ruido(d + 1), 420) * suave_aleatorio(d + 1, 0.3, 21)
    x = norm(x, 0.25)
    colocar(x, rangido(1.8, 150, 7) * 0.22, 3.4)
    colocar(x, rangido(2.2, 210, 9) * 0.16, 8.6)
    return norm(emloop(x, 1.0), 0.45)


def nota_caixinha(freq, d=2.2, semente=0):
    g = np.random.default_rng(semente)
    det = 2 ** (g.uniform(-9, 9) / 1200)
    t = tt(d)
    y = np.zeros_like(t)
    for p, amp, tau in [(1, 1.0, 0.9), (2.0, 0.35, 0.45), (3.0, 0.12, 0.3), (4.16, 0.18, 0.25), (5.43, 0.08, 0.18)]:
        y += amp * np.sin(2 * np.pi * freq * det * p * t) * np.exp(-t / tau)
    y[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return y


def drone(d=16.0):
    t = tt(d + 1.5)
    x = np.zeros_like(t)
    for f, a, lfo in [(55, 0.5, 0.07), (82.4, 0.32, 0.11), (110.6, 0.22, 0.05)]:
        x += a * np.sin(2 * np.pi * f * t) * (0.7 + 0.3 * np.sin(2 * np.pi * lfo * t))
    x += 0.18 * lp(serra(np.full_like(t, 55.0)), 260)
    x += 0.035 * (np.sin(2 * np.pi * 1318.5 * t) + np.sin(2 * np.pi * 1396.9 * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.21 * t))
    x = norm(x, 0.5)
    caixa = np.zeros_like(t)
    hz = {"A4": 440.0, "B4": 493.9, "C5": 523.3, "D5": 587.3, "E5": 659.3, "G#4": 415.3}
    seq = ["E5", "C5", "B4", "A4", None, "E5", "D5", "C5", "B4", None, "A4", "C5", "B4", "G#4", None, None]
    for i, n in enumerate(seq):
        if n:
            colocar(caixa, nota_caixinha(hz[n], 2.2, i), 0.8 + i * 0.82)
    caixa = reverb(caixa, 2.5, 0.45, 2.2, 5000, 8)
    x = x + norm(caixa, 0.32)
    return norm(emloop(x, 1.5), 0.62)


def passo(semente):
    g = np.random.default_rng(semente)
    d = 0.32
    t = tt(d)
    thump = np.sin(2 * np.pi * (70 + g.uniform(-8, 8)) * t) * np.exp(-t / 0.035)
    corpo = bp(ruido(d), 120, 520) * np.exp(-t / 0.05)
    clique = hp(ruido(d), 2500) * np.exp(-t / 0.004)
    madeira = ressonante(ruido(d), g.uniform(240, 330), 6) * np.exp(-t / 0.07)
    y = thump * 0.8 + corpo * 0.6 + clique * 0.15 + madeira * 0.25
    return fade(norm(y, 0.85), 0.001, 0.05)


def susto(d=3.6):
    t = tt(d)
    x = np.zeros_like(t)
    for i, f in enumerate([880, 932, 988, 1046, 1108]):
        vib = 1 + 0.009 * np.sin(2 * np.pi * (5.5 + i * 0.4) * t + i)
        queda = 1 - 0.08 * np.clip((t - 1.8) / 1.5, 0, 1)
        x += serra(f * vib * queda) * (0.6 + 0.4 * np.random.default_rng(i).random())
    arco = bp(ruido(d), 1500, 6000) * 0.25
    env = np.minimum(1, t / 0.03) * np.exp(-np.maximum(t - 0.25, 0) / 1.1)
    cordas = lp(x + arco, 6500) * env
    boom = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t * 1.4) + 32) / SR) * np.exp(-t / 0.7)
    boom += lp(ruido(d), 180) * np.exp(-t / 0.3) * 0.8
    y = norm(cordas, 0.6) + norm(boom, 0.75)
    return norm(reverb(y, 2.4, 0.35, 2.5), 0.95)


def coracao():
    periodo = 0.667
    d = periodo * 2
    x = np.zeros(int(d * SR))
    for k in range(2):
        b = k * periodo
        for off, f, a in [(0.0, 52, 1.0), (0.2, 46, 0.75)]:
            tt_ = tt(0.25)
            batida = np.sin(2 * np.pi * f * tt_) * np.exp(-tt_ / 0.07) + lp(ruido(0.25), 120) * np.exp(-tt_ / 0.05) * 0.5
            colocar(x, batida * a, b + off)
    return norm(lp(x, 220), 0.9)


def impacto(d=4.6):
    t = tt(d)
    boom = np.sin(2 * np.pi * np.cumsum(70 * np.exp(-t * 0.9) + 26) / SR) * np.exp(-t / 1.4)
    sub = lp(ruido(d), 90) * np.exp(-t / 0.9) * 0.9
    brilho = np.zeros_like(t)
    for p, a in [(311, 0.2), (467, 0.12), (733, 0.09), (1123, 0.05)]:
        brilho += a * np.sin(2 * np.pi * p * t) * np.exp(-t / 0.9)
    y = norm(boom, 0.9) + sub + brilho * 0.5
    return norm(reverb(y, 3.8, 0.4, 1.6, 3000), 0.95)


def clique():
    d = 0.16
    t = tt(d)
    y = bp(ruido(d), 1500, 4500) * np.exp(-t / 0.004) * 0.8
    y += ressonante(ruido(d), 620, 5) * np.exp(-t / 0.02) * 1.2
    i = int(0.075 * SR)
    sol = bp(ruido(d), 1800, 5000) * np.exp(-t / 0.003) * 0.35
    y[i:] += sol[: len(y) - i]
    return fade(norm(y, 0.8), 0.0005, 0.02)


def estatica(d=1.2):
    x = ruido(d)
    x = np.round(x * 4) / 4
    portao = np.zeros_like(x)
    pos = 0
    g = np.random.default_rng(77)
    while pos < len(x):
        tam = int(g.uniform(0.01, 0.06) * SR)
        if g.random() < 0.7:
            portao[pos:pos + tam] = g.uniform(0.4, 1.0)
        pos += tam
    portao = lp(portao, 300, 1)
    y = bp(x, 400, 6000) * portao
    env = np.minimum(1, tt(d) / 0.02) * np.minimum(1, (d - tt(d)) / 0.25)
    return norm(y * env, 0.7)


def relogio():
    d = 2.0
    x = np.zeros(int(d * SR))
    for ini, f in [(0.0, 1250), (1.0, 820)]:
        tt_ = tt(0.12)
        tic = bp(ruido(0.12), 1800, 5200) * np.exp(-tt_ / 0.004) * 0.6 + ressonante(ruido(0.12), f, 18) * np.exp(-tt_ / 0.03)
        colocar(x, tic, ini)
    return norm(reverb(x, 0.8, 0.2, 6), 0.6)


def sussurro(d=1.7, semente=31):
    g = np.random.default_rng(semente)
    x = np.zeros(int(d * SR))
    pos = 0.08
    while pos < d - 0.2:
        dur = g.uniform(0.09, 0.2)
        f1 = g.uniform(500, 900)
        f2 = g.uniform(1300, 2400)
        n = ruido(dur)
        s = ressonante(n, f1, 4) + 0.8 * ressonante(n, f2, 5) + 0.3 * hp(n, 3500)
        s *= np.hanning(len(s))
        colocar(x, s, pos, g.uniform(0.5, 1.0))
        pos += dur * g.uniform(0.7, 1.1)
    x = hp(x, 300)
    return norm(reverb(x, 1.6, 0.45, 2.5), 0.6)


def respiracao(d=2.7):
    t = tt(d)
    ins = np.clip(t / 1.0, 0, 1) * np.clip((1.15 - t) / 0.15, 0, 1)
    exa = np.clip((t - 1.2) / 0.15, 0, 1) * np.clip((d - t) / 1.2, 0, 1)
    ar = bp(ruido(d), 300, 1500) * (ins * 0.6 + exa)
    rosnado = lp(serra(np.full_like(t, 46.0)) * (0.5 + 0.5 * suave_aleatorio(d, 30, 4)), 420) * exa
    y = ar + rosnado * 0.9
    return norm(reverb(y, 1.8, 0.35, 2.2), 0.8)


def whoosh(d=1.4):
    t = tt(d)
    x = ruido(d)
    centro = 300 + 2200 * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    y = np.zeros_like(x)
    bloco = 1024
    for i in range(0, len(x), bloco // 2):
        seg = x[i:i + bloco]
        if len(seg) < 32:
            break
        fc = centro[min(i + bloco // 2, len(centro) - 1)]
        s = bp(seg, fc * 0.6, fc * 1.4) * np.hanning(len(seg))
        y[i:i + len(s)] += s
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    return norm(y * env, 0.7)


def tensao(d=6.0):
    t = tt(d)
    cresce = (t / d) ** 2
    baixo = (np.sin(2 * np.pi * 49 * t) + 0.6 * np.sin(2 * np.pi * 73.5 * t)) * cresce
    cordas = np.zeros_like(t)
    for i, f in enumerate([1300, 1378, 1460, 1547]):
        cordas += serra(f * (1 + 0.04 * t / d) * (1 + 0.006 * np.sin(2 * np.pi * (6 + i) * t)))
    cordas = lp(cordas, 5000) * cresce ** 1.5 * 0.35
    ar = bp(ruido(d), 500, 3000) * cresce * 0.25
    y = norm(baixo, 0.6) + cordas + ar
    y[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))
    return norm(y, 0.85)


def efeitos():
    return [
        ("vento", vento(), True),
        ("interior", interior(), True),
        ("drone", drone(), True),
        ("coracao", coracao(), True),
        ("relogio", relogio(), True),
        ("passo1", passo(1), False),
        ("passo2", passo(2), False),
        ("passo3", passo(3), False),
        ("rangido", rangido(), False),
        ("susto", susto(), False),
        ("impacto", impacto(), False),
        ("clique", clique(), False),
        ("estatica", estatica(), False),
        ("sussurro", sussurro(), False),
        ("respiracao", respiracao(), False),
        ("whoosh", whoosh(), False),
        ("tensao", tensao(), False),
    ]


# ---------------------------------------------------------------- vozes
def ler_audio(caminho):
    with tempfile.TemporaryDirectory() as tmp:
        saida = os.path.join(tmp, "x.wav")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", caminho, "-ac", "1", "-ar", str(SR), saida], check=True)
        with wave.open(saida) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768


def gravar_wav(caminho, x):
    y = np.clip(x, -1, 1)
    with wave.open(caminho, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


def ajustar_tom(x, semitons):
    if abs(semitons) < 0.01:
        return x
    with tempfile.TemporaryDirectory() as tmp:
        a = os.path.join(tmp, "a.wav")
        b = os.path.join(tmp, "b.wav")
        gravar_wav(a, x)
        fator = 2 ** (semitons / 12)
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", a, "-af", f"rubberband=pitch={fator:.5f}", b], check=True)
        with wave.open(b) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768


def silencios(x, limiar_db=-38, minimo=0.25):
    hop = int(0.01 * SR)
    n = len(x) // hop
    rms = np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) + 1e-9 for i in range(n)])
    db = 20 * np.log10(rms / rms.max())
    quieto = db < limiar_db
    lacunas = []
    i = 0
    while i < n:
        if quieto[i]:
            j = i
            while j < n and quieto[j]:
                j += 1
            if (j - i) * 0.01 >= minimo:
                lacunas.append((i * 0.01, j * 0.01))
            i = j
        else:
            i += 1
    return lacunas, n * 0.01


def recortar(x, n_trechos):
    lacunas, dur = silencios(x)
    internas = [g for g in lacunas if g[0] > 0.05 and g[1] < dur - 0.05]
    maiores = sorted(sorted(internas, key=lambda g: g[1] - g[0], reverse=True)[: n_trechos - 1])
    ini = lacunas[0][1] if lacunas and lacunas[0][0] <= 0.05 else 0.0
    trechos = []
    for a, b in maiores:
        trechos.append((ini, a))
        ini = b
    fim = lacunas[-1][0] if lacunas and lacunas[-1][1] >= dur - 0.05 else dur
    trechos.append((ini, fim))
    return [x[int(max(0, a - 0.06) * SR):int(min(dur, b + 0.08) * SR)] for a, b in trechos]


def recortar_em(x, tempos_corte):
    """recorta nas pausas mais próximas dos tempos indicados (segundos)."""
    lacunas, dur = silencios(x, minimo=0.2)
    internas = [g for g in lacunas if g[0] > 0.05 and g[1] < dur - 0.05]
    escolhidas = []
    for t in tempos_corte:
        g = min(internas, key=lambda g: abs(g[0] - t))
        escolhidas.append(g)
    escolhidas = sorted(set(escolhidas))
    ini = lacunas[0][1] if lacunas and lacunas[0][0] <= 0.05 else 0.0
    trechos = []
    for a, b in escolhidas:
        trechos.append((ini, a))
        ini = b
    fim = lacunas[-1][0] if lacunas and lacunas[-1][1] >= dur - 0.05 else dur
    trechos.append((ini, fim))
    return [x[int(max(0, a - 0.06) * SR):int(min(dur, b + 0.08) * SR)] for a, b in trechos]


def tratar_voz(x, tom=0.0, alvo_rms_db=-17.0):
    x = hp(x, 80, 2)
    x = ajustar_tom(x, tom)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (10 ** (alvo_rms_db / 20) / rms)
    pico = np.max(np.abs(x))
    if pico > 0.85:
        x = np.tanh(x / pico * 1.4) / np.tanh(1.4) * 0.85
    return fade(x, 0.008, 0.03)


def embaralhar(x, grao=0.045, janela=4, semente=0):
    """embaralha a fala em grãos: continua soando como um grito, mas o nome some."""
    g = np.random.default_rng(semente)
    n = int(grao * SR)
    graos = [x[i:i + n] for i in range(0, len(x) - n, n // 2)]
    ordem = list(range(len(graos)))
    for i in range(0, len(ordem), janela):
        bloco = ordem[i:i + janela]
        g.shuffle(bloco)
        ordem[i:i + janela] = bloco
    y = np.zeros(len(x) + n)
    jan = np.hanning(n)
    for k, idx in enumerate(ordem):
        gr = graos[idx]
        y[k * (n // 2):k * (n // 2) + len(gr)] += gr * jan[: len(gr)]
    return y[: len(x)]


def censurar(grito, intensidade, semente):
    y = embaralhar(grito, 0.04, 5, semente)
    y = bp(y, 220, 2600) * 1.3
    if intensidade >= 2:
        grave = ajustar_tom(y, -6) * 0.55
        y = y + grave[: len(y)]
    est = estatica(len(y) / SR + 0.05)[: len(y)] * (0.18 + 0.12 * intensidade)
    y = y + est
    y = reverb(y, 1.2 + 0.4 * intensidade, 0.25 + 0.08 * intensidade, 2.6, 4000, semente + 3)
    cauda = int(0.5 * SR)
    y = np.concatenate([y, np.zeros(cauda)])
    return fade(norm(y, 0.8 + 0.05 * intensidade), 0.005, 0.25)


def vozes(pasta):
    itens = []
    me = os.path.join(pasta, "ME_all_a.mp3")
    if os.path.exists(me):
        partes = recortar(ler_audio(me), 5)
        for nome, x in zip(["ME_1", "ME_2", "ME_3"], partes[:3]):
            itens.append((nome, tratar_voz(x, 1.5)))
        grito = tratar_voz(partes[3], 1.5, -14)
        for nome, inten, sem in [("ME_4A", 1, 11), ("ME_4B", 2, 12), ("ME_4C", 3, 13)]:
            itens.append((nome, censurar(grito, inten, sem)))
        itens.append(("ME_5", tratar_voz(partes[4], 1.5, -14.5)))
    ni = os.path.join(pasta, "NI_all_a.mp3")
    if os.path.exists(ni):
        partes = recortar(ler_audio(ni), 3)
        for nome, x in zip(["NI_1", "NI_2", "NI_3"], partes):
            itens.append((nome, tratar_voz(x, 0.0, -19 if nome == "NI_2" else -17)))
    vo = os.path.join(pasta, "VO_1_a.mp3")
    if os.path.exists(vo):
        itens.append(("VO_1", tratar_voz(recortar(ler_audio(vo), 1)[0], 0.0)))
    # futuras falas (Keko, VO_2) entram aqui quando forem geradas
    for nome, arq in [("VO_2", "VO_2_a.mp3")]:
        caminho = os.path.join(pasta, arq)
        if os.path.exists(caminho):
            itens.append((nome, tratar_voz(recortar(ler_audio(caminho), 1)[0], 0.0)))
    ke = os.path.join(pasta, "KE_all_a.mp3")
    if os.path.exists(ke):
        partes = recortar(ler_audio(ke), 5)
        for nome, x in zip(["KE_1", "KE_2", "KE_3", "KE_4", "KE_5"], partes):
            itens.append((nome, tratar_voz(x, 2.0)))
    return itens


# ---------------------------------------------------------------- sprite
def montar_sprite(itens, nome_arquivo, folga=0.35):
    partes = [np.zeros(int(0.1 * SR))]
    mapa = {}
    pos = 0.1
    for nome, x in itens:
        mapa[nome] = {"inicio": round(pos, 4), "dur": round(len(x) / SR, 4)}
        partes.append(x)
        partes.append(np.zeros(int(folga * SR)))
        pos += len(x) / SR + folga
    y = np.concatenate(partes)
    os.makedirs(ASSETS, exist_ok=True)
    wav = os.path.join(ASSETS, nome_arquivo + ".wav")
    ogg = os.path.join(ASSETS, nome_arquivo + ".ogg")
    gravar_wav(wav, y)
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    return mapa, len(y) / SR, ogg


def escrever_mapa(arquivos):
    linhas = ["-- OI3 :: mapa dos \"sprites\" de áudio (gerado por tools/audio.py). Não edite à mão.", "return {", "\tarquivos = {"]
    for nome in arquivos:
        linhas.append(f'\t\t"{nome}",')
    linhas.append("\t},")
    linhas.append("\titens = {")
    for nome, (mapa, loops) in arquivos.items():
        for item, info in mapa.items():
            loop = "true" if item in loops else "false"
            linhas.append(f'\t\t{item} = {{ arquivo = "{nome}", inicio = {info["inicio"]}, dur = {info["dur"]}, loop = {loop} }},')
    linhas.append("\t},")
    linhas.append("}")
    with open(MAPA_LUAU, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")


def main():
    pasta_vozes = sys.argv[1] if len(sys.argv) > 1 else ""
    efs = efeitos()
    mapa_sfx, dur_sfx, ogg_sfx = montar_sprite([(n, x) for n, x, _ in efs], "oi3_sfx")
    loops_sfx = {n for n, _, lp_ in efs if lp_}
    arquivos = {"sfx": (mapa_sfx, loops_sfx)}
    print(f"sfx: {len(efs)} itens, {dur_sfx:.1f}s, {os.path.getsize(ogg_sfx) // 1024} KB")
    if pasta_vozes:
        vz = vozes(pasta_vozes)
        if vz:
            mapa_v, dur_v, ogg_v = montar_sprite(vz, "oi3_vozes1")
            arquivos["vozes1"] = (mapa_v, set())
            print(f"vozes1: {len(vz)} falas ({', '.join(n for n, _ in vz)}), {dur_v:.1f}s, {os.path.getsize(ogg_v) // 1024} KB")
    escrever_mapa(arquivos)
    resumo = {nome: {k: v for k, v in m.items()} for nome, (m, _) in arquivos.items()}
    with open(os.path.join(ASSETS, "audio_mapa.json"), "w", encoding="utf-8") as f:
        json.dump(resumo, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- AJUSTE-2
LOOPS = {"vento", "interior", "drone", "coracao", "relogio", "musica_menu"}


def vozes2(pasta):
    itens = []
    ke = os.path.join(pasta, "KE_all_a.mp3")
    if os.path.exists(ke):
        # pausas longas reais desta gravação: ~3.1s, ~7.3s, ~15.7s e a curta antes da risada (~18.0s)
        partes = recortar_em(ler_audio(ke), [3.14, 7.26, 15.68, 18.05])
        for nome, x in zip(["KE_1", "KE_2", "KE_3", "KE_4", "KE_5"], partes):
            itens.append((nome, tratar_voz(x, 4.0, -16.5 if nome == "KE_5" else -17.5)))
    vo = os.path.join(pasta, "VO_2_a.mp3")
    if os.path.exists(vo):
        itens.append(("VO_2", tratar_voz(recortar(ler_audio(vo), 1)[0], 0.0)))
    return itens


def ler_estereo(caminho):
    with tempfile.TemporaryDirectory() as tmp:
        saida = os.path.join(tmp, "x.wav")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", caminho, "-vn", "-ac", "2", "-ar", str(SR), saida], check=True)
        with wave.open(saida) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64).reshape(-1, 2) / 32768


def musica_menu(video, nome_arquivo="oi3_musica"):
    x = ler_estereo(video)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (10 ** (-17.5 / 20) / rms)
    pico = np.max(np.abs(x))
    if pico > 0.89:
        x = np.tanh(x / pico * 1.3) / np.tanh(1.3) * 0.89
    # loop emendado: os últimos 3 s se misturam no começo
    n = int(3.0 * SR)
    y = x[:-n].copy()
    ent = np.linspace(0, 1, n)[:, None]
    y[:n] = y[:n] * np.sqrt(ent) + x[-n:] * np.sqrt(1 - ent)
    os.makedirs(ASSETS, exist_ok=True)
    wav = os.path.join(ASSETS, nome_arquivo + ".wav")
    ogg = os.path.join(ASSETS, nome_arquivo + ".ogg")
    with wave.open(wav, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)
    return {"musica_menu": {"inicio": 0.0, "dur": round(len(y) / SR - 0.05, 3)}}, ogg


def escrever_mapa_json(resumo):
    """reescreve AudioMapa.luau a partir do resumo {arquivo: {item: {inicio, dur}}}."""
    linhas = ["-- OI3 :: mapa dos \"sprites\" de áudio (gerado por tools/audio.py). Não edite à mão.", "return {", "\tarquivos = {"]
    for nome in resumo:
        linhas.append(f'\t\t"{nome}",')
    linhas.append("\t},")
    linhas.append("\titens = {")
    for nome, mapa in resumo.items():
        for item, info in mapa.items():
            loop = "true" if item in LOOPS else "false"
            linhas.append(f'\t\t{item} = {{ arquivo = "{nome}", inicio = {info["inicio"]}, dur = {info["dur"]}, loop = {loop} }},')
    linhas.append("\t},")
    linhas.append("}")
    with open(MAPA_LUAU, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")


def ajuste2(pasta_vozes, video):
    caminho_json = os.path.join(ASSETS, "audio_mapa.json")
    with open(caminho_json, encoding="utf-8") as f:
        resumo = json.load(f)
    vz = vozes2(pasta_vozes)
    mapa_v, dur_v, ogg_v = montar_sprite(vz, "oi3_vozes2")
    resumo["vozes2"] = mapa_v
    print(f"vozes2: {len(vz)} falas ({', '.join(n for n, _ in vz)}), {dur_v:.1f}s, {os.path.getsize(ogg_v) // 1024} KB")
    if video:
        mapa_m, ogg_m = musica_menu(video)
        resumo["musica"] = mapa_m
        print(f"musica: {mapa_m['musica_menu']['dur']:.1f}s, {os.path.getsize(ogg_m) // 1024} KB")
    escrever_mapa_json(resumo)
    with open(caminho_json, "w", encoding="utf-8") as f:
        json.dump(resumo, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- AJUSTE-4
# Lanterna (liga/desliga) e ambientes do orfanato. Tudo sintetizado por código.
LOOPS.update({"grilos", "lareira", "assobio"})


def ressonante_varia(x, f_curva, q, bloco=256):
    """filtro ressonante cujo centro muda com o tempo (assobio do vento)."""
    y = np.zeros_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), bloco):
        f = float(np.mean(f_curva[i:i + bloco]))
        b, a = signal.iirpeak(min(max(f, 40.0), SR / 2 * 0.95) / (SR / 2), q)
        y[i:i + bloco], zi = signal.lfilter(b, a, x[i:i + bloco], zi=zi)
    return y


def _tique(d, f_corpo, brilho=(2500, 9000), tau_ping=0.018, semente=0):
    """clique mecânico curto: estalo do plástico + 'tim' do metal + corpo da mola."""
    g = np.random.default_rng(semente)
    t = tt(d)
    estalo = norm(bp(g.standard_normal(len(t)), *brilho) * np.exp(-t / 0.0012), 1.0)
    ping = np.sin(2 * np.pi * f_corpo * t + g.uniform(0, 6.28)) * np.exp(-t / tau_ping)
    ping2 = np.sin(2 * np.pi * f_corpo * 1.73 * t) * np.exp(-t / (tau_ping * 0.6))
    corpo = norm(ressonante(g.standard_normal(len(t)), f_corpo * 0.22, 6) * np.exp(-t / 0.008), 1.0)
    return estalo * 1.0 + ping * 0.2 + ping2 * 0.08 + corpo * 0.45


def lanterna(liga=True):
    d = 0.24 if liga else 0.21
    y = np.zeros(int(d * SR))
    a = _tique(0.08, 4200 if liga else 3600, semente=41 if liga else 43)
    b = _tique(0.06, 5100 if liga else 4300, brilho=(3000, 10000), tau_ping=0.012, semente=42 if liga else 44)
    colocar(y, a, 0.004, 1.0)  # apertar
    colocar(y, b, 0.085 if liga else 0.07, 0.55 if liga else 0.42)  # soltar
    t = tt(0.05)
    colocar(y, norm(lp(ruido(0.05), 600) * np.exp(-t / 0.006), 1.0), 0.0, 0.35)  # polegar na borracha
    y = reverb(y, 0.35, 0.12, 14, 6000, 47)
    return fade(norm(y, 0.8), 0.0005, 0.02)


def grilos(d=16.0):
    tot = d + 1.5
    y = np.zeros(int(tot * SR))
    g = np.random.default_rng(77)
    # três grilos perto, cada um com seu tom e ritmo (cri-cri-cri)
    for f, periodo, pulsos, ganho in [(4350, 0.62, 4, 0.55), (4720, 0.83, 3, 0.4), (4080, 1.07, 4, 0.3)]:
        t0 = g.uniform(0, periodo)
        while t0 < tot - 0.3:
            for p in range(pulsos):
                dur_p = 0.012 + g.uniform(-0.002, 0.002)
                tp = tt(dur_p)
                env = np.sin(np.pi * tp / dur_p) ** 2
                fp = f * (1 + g.uniform(-0.006, 0.006))
                pulso = (np.sin(2 * np.pi * fp * tp) + 0.12 * np.sin(4 * np.pi * fp * tp)) * env
                colocar(y, pulso, t0 + p * 0.028, ganho * g.uniform(0.8, 1.0))
            t0 += periodo * g.uniform(0.9, 1.15) * (2.2 if g.random() < 0.08 else 1.0)
    # coro distante (trinado contínuo) e o ar da noite
    t = tt(tot)
    coro = np.zeros(len(t))
    for k in range(7):  # vários grilos longe, cada um num tom e ritmo (dá o "batimento" natural)
        fk = g.uniform(3650, 4150)
        taxa = g.uniform(28, 46)
        trinado = (0.5 + 0.5 * np.sin(2 * np.pi * taxa * t + g.uniform(0, 6.28))) ** 3
        liga = (suave_aleatorio(tot, g.uniform(0.15, 0.4), 300 + k) > 0.35).astype(float)
        coro += np.sin(2 * np.pi * fk * t + g.uniform(0, 6.28)) * trinado * lp(liga, 3, 1) * g.uniform(0.4, 1.0)
    coro = bp(coro, 3000, 5200) * 0.05
    ar = lp(ruido(tot), 900) * 0.035 * (0.6 + 0.4 * suave_aleatorio(tot, 0.2, 79))
    y = reverb(y + coro + ar, 1.4, 0.22, 3.2, 7000, 80)
    return norm(emloop(hp(y, 120), 1.5), 0.5)


def lareira(d=14.0):
    tot = d + 1.5
    g = np.random.default_rng(91)
    ronco = hp(lp(np.cumsum(ruido(tot)) * 0.01, 300), 40)
    ronco = norm(ronco, 1.0) * (0.55 + 0.45 * suave_aleatorio(tot, 0.8, 92))
    chiado = norm(bp(ruido(tot), 2500, 7000), 1.0) * (0.15 + 0.85 * suave_aleatorio(tot, 1.5, 93) ** 3) * 0.1
    y = ronco * 0.35 + chiado
    tcur = 0.0
    while True:
        tcur += g.exponential(1 / 9.0)
        if tcur >= tot - 0.15:
            break
        amp = min(1.0, (g.pareto(2.2) + 0.15) * 0.25)  # muitos estalinhos, poucos grandes
        tc = tt(0.03)
        est = norm(ressonante(g.standard_normal(len(tc)), g.uniform(900, 4500), g.uniform(3, 9)) * np.exp(-tc / g.uniform(0.0015, 0.006)), 1.0)
        est += norm(hp(g.standard_normal(len(tc)), 2000) * np.exp(-tc / 0.0008), 1.0) * 0.6
        colocar(y, est, tcur, amp)
        if g.random() < 0.05:  # "pop" grave da lenha
            tp = tt(0.12)
            pop = np.sin(2 * np.pi * g.uniform(90, 160) * tp) * np.exp(-tp / 0.02)
            pop += norm(bp(g.standard_normal(len(tp)), 300, 1500) * np.exp(-tp / 0.01), 1.0) * 0.6
            colocar(y, pop, tcur, 0.5)
    y = reverb(y, 0.9, 0.18, 5, 6000, 94)
    return norm(emloop(hp(y, 35), 1.5), 0.6)


def goteira(semente, f0=1100.0):
    d = 1.1
    t = tt(d)
    f = f0 * (1 + 1.4 * np.minimum(t / 0.035, 1.0))  # o "plim" sobe de tom
    plim = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.018)
    tic = norm(hp(ruido(d), 3000) * np.exp(-t / 0.0007), 1.0) * 0.3
    y = reverb(plim + tic, 1.0, 0.45, 4.5, 5000, semente + 1)
    return fade(norm(y, 0.7), 0.0003, 0.05)


def estalo_madeira(semente):
    g = np.random.default_rng(semente)
    d = 0.8
    t = tt(d)
    batida = sum(ressonante(ruido(d), f, 10) * a for f, a in
                 [(g.uniform(180, 240), 1.0), (g.uniform(420, 520), 0.6), (g.uniform(900, 1200), 0.3)])
    y = norm(batida * np.exp(-t / 0.045), 1.0) + norm(bp(ruido(d), 1500, 6000) * np.exp(-t / 0.002), 1.0) * 0.5
    colocar(y, rangido(0.35, g.uniform(150, 220), semente + 5), 0.05, 0.25)
    y = reverb(y, 1.2, 0.35, 3.5, 4000, semente + 2)
    return fade(norm(y, 0.7), 0.0005, 0.08)


def assobio(d=16.0):
    tot = d + 1.5
    rajada = suave_aleatorio(tot, 0.22, 102) ** 1.6
    f1 = 620 + 520 * rajada
    w1 = ressonante_varia(ruido(tot), f1, 60) * rajada
    w2 = ressonante_varia(ruido(tot), f1 * 1.5, 70) * rajada ** 2
    ronco = lp(ruido(tot), 220, 2) * (0.25 + 0.75 * rajada)
    y = norm(w1, 1.0) * 0.6 + norm(w2, 1.0) * 0.22 + norm(ronco, 1.0) * 0.5
    y = reverb(y, 1.5, 0.3, 3, 4000, 103)
    return norm(emloop(hp(y, 50), 1.5), 0.55)


def galhos(semente=111):
    g = np.random.default_rng(semente)
    d = 1.8
    y = np.zeros(int(d * SR))
    tcur = 0.05
    for _ in range(int(g.integers(3, 5))):
        tc = tt(0.08)
        f = g.uniform(2600, 3400)
        toque = np.sin(2 * np.pi * f * tc) * np.exp(-tc / 0.012) * 0.6 + np.sin(2 * np.pi * f * 2.3 * tc) * np.exp(-tc / 0.006) * 0.3
        toque += norm(hp(g.standard_normal(len(tc)), 2500) * np.exp(-tc / 0.0012), 1.0) * 0.8
        toque += norm(ressonante(g.standard_normal(len(tc)), g.uniform(500, 800), 4) * np.exp(-tc / 0.01), 1.0) * 0.5
        colocar(y, toque, tcur, g.uniform(0.5, 1.0))
        tcur += g.uniform(0.18, 0.45)
    t = tt(d)
    y += norm(bp(ruido(d), 3500, 8000), 1.0) * (suave_aleatorio(d, 3, semente + 1) ** 3) * 0.08 * np.minimum(1, t / 0.3)
    y = reverb(y, 1.0, 0.3, 4, 6000, semente + 2)
    return fade(norm(y, 0.6), 0.001, 0.1)


def passo_madeira(semente):
    g = np.random.default_rng(semente)
    d = 0.42
    t = tt(d)
    calcanhar = np.sin(2 * np.pi * g.uniform(62, 78) * t) * np.exp(-t / 0.03)
    tabua = sum(ressonante(ruido(d), f, 7) * a for f, a in
                [(g.uniform(150, 190), 1.0), (g.uniform(310, 380), 0.7), (g.uniform(700, 850), 0.35)])
    tabua = norm(tabua, 1.0) * np.exp(-t / 0.06)
    sola = norm(bp(ruido(d), 900, 4000) * np.exp(-t / 0.012), 1.0) * 0.25
    y = calcanhar * 0.7 + tabua * 0.8 + sola
    i = int(g.uniform(0.06, 0.09) * SR)  # ponta do pé, mais fraca
    y[i:] += (norm(bp(ruido(d), 300, 2500) * np.exp(-t / 0.02), 1.0) * 0.3)[: len(y) - i]
    if semente % 3 == 2:  # tábua que range de leve
        colocar(y, rangido(0.3, g.uniform(180, 260), semente + 9), 0.05, 0.12)
    y = reverb(y, 0.6, 0.18, 7, 5000, semente + 3)
    return fade(norm(y, 0.85), 0.0005, 0.06)


def passo_grama(semente):
    g = np.random.default_rng(semente)
    d = 0.42
    t = tt(d)
    y = np.zeros(len(t))
    for _ in range(int(g.integers(40, 70))):  # folhinhas amassando
        tg = tt(0.006)
        grao = bp(g.standard_normal(len(tg)), g.uniform(1500, 3000), g.uniform(5000, 9000)) * np.exp(-tg / 0.0015)
        colocar(y, grao, g.uniform(0, 0.16) ** 1.3, g.uniform(0.2, 1.0))
    baque = lp(ruido(d), 300) * np.exp(-t / 0.03) + np.sin(2 * np.pi * 55 * t) * np.exp(-t / 0.025) * 0.5
    y = norm(y, 1.0) * 0.8 + norm(baque, 1.0) * 0.45
    return fade(norm(y, 0.8), 0.001, 0.06)


def ambiente_itens():
    return [
        ("lanterna_liga", lanterna(True)),
        ("lanterna_desliga", lanterna(False)),
        ("grilos", grilos()),
        ("lareira", lareira()),
        ("assobio", assobio()),
        ("goteira1", goteira(201, 1050.0)),
        ("goteira2", goteira(202, 1320.0)),
        ("estalo1", estalo_madeira(211)),
        ("estalo2", estalo_madeira(212)),
        ("galhos", galhos(111)),
        ("passo_madeira1", passo_madeira(221)),
        ("passo_madeira2", passo_madeira(222)),
        ("passo_madeira3", passo_madeira(223)),
        ("passo_grama1", passo_grama(231)),
        ("passo_grama2", passo_grama(232)),
        ("passo_grama3", passo_grama(233)),
    ]


def ajuste4():
    caminho_json = os.path.join(ASSETS, "audio_mapa.json")
    with open(caminho_json, encoding="utf-8") as f:
        resumo = json.load(f)
    itens = ambiente_itens()
    mapa_a, dur_a, ogg_a = montar_sprite(itens, "oi3_ambiente")
    resumo["ambiente"] = mapa_a
    print(f"ambiente: {len(itens)} itens, {dur_a:.1f}s, {os.path.getsize(ogg_a) // 1024} KB")
    escrever_mapa_json(resumo)
    with open(caminho_json, "w", encoding="utf-8") as f:
        json.dump(resumo, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- AJUSTE-5
# Passos GRAVADOS de verdade: pacote "Impact Sounds" do Kenney (licença CC0, domínio público).
# Madeira (assoalho), grama (lá fora), carpete (tapetes) e concreto (pedra/caminho).
def preparar_pisada(x, tipo):
    pico = np.max(np.abs(x)) + 1e-9
    acima = np.where(np.abs(x) > pico * 10 ** (-45 / 20))[0]
    ini = max(0, acima[0] - int(0.005 * SR)) if len(acima) else 0
    fim = min(len(x), (acima[-1] + int(0.03 * SR)) if len(acima) else len(x))
    y = x[ini:fim]
    if len(y) < int(0.2 * SR):
        y = np.concatenate([y, np.zeros(int(0.2 * SR) - len(y))])
    y = hp(y, 45, 2)
    ativo = y[: int(0.25 * SR)]
    alvo = {"madeira": -17.0, "grama": -19.0, "tapete": -20.0, "pedra": -17.5}[tipo]
    y = y * (10 ** (alvo / 20) / (np.sqrt(np.mean(ativo ** 2)) + 1e-9))
    if tipo == "madeira":  # sala de madeira: um pouquinho de ambiente
        y = reverb(np.concatenate([y, np.zeros(int(0.25 * SR))]), 0.45, 0.1, 9, 5000, 61)
    p = np.max(np.abs(y))
    if p > 0.85:
        y = np.tanh(y / p * 1.3) / np.tanh(1.3) * 0.85
    return fade(y, 0.001, 0.015)


def ajuste5(pasta):
    caminho_json = os.path.join(ASSETS, "audio_mapa.json")
    with open(caminho_json, encoding="utf-8") as f:
        resumo = json.load(f)
    itens = []
    for tipo, arquivo in [("madeira", "wood"), ("grama", "grass"), ("tapete", "carpet"), ("pedra", "concrete")]:
        for i in range(5):
            x = ler_audio(os.path.join(pasta, "footstep_%s_%03d.ogg" % (arquivo, i)))
            itens.append(("pisada_%s%d" % (tipo, i + 1), preparar_pisada(x, tipo)))
    mapa_p, dur_p, ogg_p = montar_sprite(itens, "oi3_passos", folga=0.25)
    resumo["passos"] = mapa_p
    print(f"passos: {len(itens)} pisadas gravadas, {dur_p:.1f}s, {os.path.getsize(ogg_p) // 1024} KB")
    escrever_mapa_json(resumo)
    with open(caminho_json, "w", encoding="utf-8") as f:
        json.dump(resumo, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- AJUSTE-8
# O resto da história: vozes novas (Keko com voz de criança de verdade, a mulher do final, a criança
# misteriosa contando até dez) e os sons novos (caixinha de música, lavanderia, batidas na parede,
# projetor, carro, rádio, as três batidas do final). Tudo num arquivo só ("historia") para gastar
# só UM envio de áudio do mês.
LOOPS.update({"maquina", "projetor", "motor", "radio", "desmoronar"})


def caixinha_parabens():
    """'Parabéns a você' (melodia de domínio público) numa caixinha de música desafinada e lenta."""
    hz = {"G4": 392.0, "A4": 440.0, "B4": 493.9, "C5": 523.3, "D5": 587.3, "E5": 659.3, "F5": 698.5, "G5": 784.0}
    seq = [("G4", .5), ("G4", .5), ("A4", 1), ("G4", 1), ("C5", 1), ("B4", 2),
           ("G4", .5), ("G4", .5), ("A4", 1), ("G4", 1), ("D5", 1), ("C5", 2),
           ("G4", .5), ("G4", .5), ("G5", 1), ("E5", 1), ("C5", 1), ("B4", 1), ("A4", 2)]
    batida = 0.42
    total = sum(d for _, d in seq) * batida + 3.0
    y = np.zeros(int(total * SR))
    t0 = 0.3
    for i, (n, d) in enumerate(seq):
        # a mola vai perdendo força: cada nota atrasa um pouquinho e desafina
        f = hz[n] * 2 ** (-(i * 1.2) / 1200)
        colocar(y, nota_caixinha(f, 2.4, 100 + i), t0)
        t0 += d * batida * (1 + i * 0.012)
    y = reverb(y, 2.2, 0.4, 2.4, 5200, 11)
    return fade(norm(y, 0.7), 0.01, 1.2)


def maquina_lavar(d=6.0):
    t = tt(d + 1.0)
    motor_ = np.zeros_like(t)
    for f, a in [(48, 0.6), (96, 0.3), (144, 0.12)]:
        motor_ += a * np.sin(2 * np.pi * f * t + f)
    agua = lp(ruido(d + 1.0), 700) * (0.55 + 0.45 * np.sin(2 * np.pi * 0.9 * t) ** 2)
    batidas = np.zeros_like(t)
    for k in range(int((d + 1.0) / 0.95)):
        tb = tt(0.2)
        colocar(batidas, np.sin(2 * np.pi * 60 * tb) * np.exp(-tb / 0.05) * 0.5, 0.2 + k * 0.95)
    y = norm(motor_, 0.35) + norm(agua, 0.3) + batidas
    return norm(emloop(lp(y, 2500), 1.0), 0.6)


def batida_parede(oca, semente=0):
    g = np.random.default_rng(semente)
    d = 0.9 if oca else 0.35
    t = tt(d)
    golpe = bp(ruido(d), 300, 3000) * np.exp(-t / 0.006)
    if oca:
        corpo = ressonante(ruido(d), g.uniform(170, 200), 18) * np.exp(-t / 0.22) * 2.2
        corpo += ressonante(ruido(d), g.uniform(390, 430), 14) * np.exp(-t / 0.12)
    else:
        corpo = lp(ruido(d), 260) * np.exp(-t / 0.03) * 1.4
    y = np.zeros(int(d * 2 * SR) + int(0.25 * SR))
    colocar(y, golpe + corpo, 0.0)
    colocar(y, (golpe + corpo) * 0.85, 0.24)  # toc-toc
    return fade(norm(y, 0.85), 0.001, 0.05)


def arrastar(d=1.7, semente=4):
    g = np.random.default_rng(semente)
    t = tt(d)
    gr = (suave_aleatorio(d, 22, semente) > 0.35).astype(float)
    gr = lp(gr, 70, 1)
    x = bp(ruido(d), 120, 1600) * (0.25 + 0.75 * gr)
    x += 0.4 * ressonante(ruido(d), g.uniform(140, 180), 9) * gr
    env = np.minimum(1, t / 0.08) * np.minimum(1, (d - t) / 0.15)
    return fade(norm(x * env, 0.75), 0.005, 0.05)


def projetor(d=4.0):
    t = tt(d + 1.0)
    cliques = np.zeros_like(t)
    tb = tt(0.012)
    c = bp(ruido(0.012), 1200, 5000) * np.exp(-tb / 0.002)
    for k in range(int((d + 1.0) * 24)):
        colocar(cliques, c * (0.7 + 0.3 * np.sin(k)), k / 24)
    motor_ = 0.25 * np.sin(2 * np.pi * 110 * t) + 0.1 * np.sin(2 * np.pi * 220 * t) + 0.12 * lp(ruido(d + 1), 400)
    return norm(emloop(cliques * 0.6 + motor_, 1.0), 0.5)


def motor_carro(d=5.0):
    t = tt(d + 1.0)
    f = 34 + 2 * np.sin(2 * np.pi * 0.3 * t)
    x = np.zeros_like(t)
    for h, a in [(1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (6, 0.08)]:
        x += a * np.sin(2 * np.pi * np.cumsum(f * h) / SR)
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * f * 0.5 * t) ** 2
    x += 0.15 * lp(ruido(d + 1), 300)
    return norm(emloop(lp(x, 900), 1.0), 0.55)


def partida_carro():
    d = 2.2
    t = tt(d)
    giro = np.zeros_like(t)
    for k in range(9):
        tb = tt(0.13)
        colocar(giro, bp(ruido(0.13), 200, 1500) * np.exp(-tb / 0.05), 0.05 + k * 0.12)
    pega = np.zeros_like(t)
    t2 = t[t >= 1.1] - 1.1
    f = 60 * np.exp(-t2 * 2) + 34
    ronco = sum(a * np.sin(2 * np.pi * np.cumsum(f * h) / SR) for h, a in [(1, 1.0), (2, 0.5), (3, 0.25)])
    pega[len(t) - len(t2):] = ronco * np.minimum(1, t2 / 0.05)
    return fade(norm(giro * 0.6 + lp(pega, 900), 0.8), 0.002, 0.1)


def tres_batidas():
    d = 3.2
    y = np.zeros(int(d * SR))
    for k in range(3):
        tb = tt(0.6)
        bum = np.sin(2 * np.pi * 62 * tb) * np.exp(-tb / 0.09) + lp(ruido(0.6), 400) * np.exp(-tb / 0.05) * 0.8
        bum += bp(ruido(0.6), 600, 2500) * np.exp(-tb / 0.01) * 0.4
        colocar(y, bum, 0.3 + k * 0.85)
    return norm(reverb(y, 2.0, 0.3, 2.2, 3000, 21), 0.95)


def vela_apaga():
    d = 0.7
    t = tt(d)
    sopro = bp(ruido(d), 300, 2400) * np.exp(-((t - 0.18) / 0.12) ** 2)
    return fade(norm(sopro, 0.5), 0.01, 0.1)


def radio_chiado(d=3.0):
    t = tt(d + 1.0)
    x = bp(ruido(d + 1), 400, 4200) * (0.6 + 0.4 * suave_aleatorio(d + 1, 6, 77))
    x += 0.15 * np.sin(2 * np.pi * 1000 * t) * (suave_aleatorio(d + 1, 3, 78) > 0.6)
    return norm(emloop(x, 1.0), 0.35)


def desmoronar(d=6.0):
    t = tt(d + 1.0)
    x = lp(ruido(d + 1), 120) * 1.2
    for k in range(10):
        colocar(x, impacto(1.2)[: int(1.0 * SR)] * 0.35, 0.2 + k * 0.6 + 0.2 * np.sin(k * 3.1))
    x += 0.2 * bp(ruido(d + 1), 800, 3000) * suave_aleatorio(d + 1, 4, 91)
    return norm(emloop(x, 1.0), 0.8)


def criancas_risada_radio(pasta):
    """a 'risadinha' do rádio: o começo da risada do Keko (antes do 'Que medroso'), bem baixinho."""
    x = ler_audio(os.path.join(pasta, "KE2_a.mp3"))
    partes = recortar(x, 7)
    risada = partes[4]
    lac, dur = silencios(risada, limiar_db=-30, minimo=0.12)
    internas = [g for g in lac if g[0] > 0.2 and g[1] < dur - 0.05]
    corte = internas[0][0] if internas else min(dur, 0.9)
    r = risada[: int(min(corte, 1.2) * SR)]
    return tratar_voz(lp(r, 3500), 0.0, -24)


def ajuste8(pasta):
    caminho_json = os.path.join(ASSETS, "audio_mapa.json")
    with open(caminho_json, encoding="utf-8") as f:
        resumo = json.load(f)
    itens = []
    # Keko: voz de CRIANÇA de verdade, sem mudar o tom (o usuário achou estranho o tom alterado)
    ke = recortar(ler_audio(os.path.join(pasta, "KE2_a.mp3")), 7)
    for nome, x in zip(["KE_1", "KE_2", "KE_3", "KE_4", "KE_5", "KE_6"], ke[:6]):
        itens.append((nome, tratar_voz(x, 0.0, -16.5 if nome == "KE_5" else -17.5)))
    keb = recortar(ler_audio(os.path.join(pasta, "KE2_b.mp3")), 7)
    itens.append(("KE_8", tratar_voz(keb[6], 0.0, -19)))
    itens.append(("RISADA_RADIO", criancas_risada_radio(pasta)))
    itens.append(("MU_1", tratar_voz(recortar(ler_audio(os.path.join(pasta, "MU_a.mp3")), 1)[0], 0.0)))
    cr = recortar(ler_audio(os.path.join(pasta, "CR_a.mp3")), 11)
    itens.append(("CR_1", tratar_voz(cr[0], 0.0, -18)))
    for i in range(1, 11):
        itens.append(("CONTA_%d" % i, tratar_voz(cr[i], 0.0, -18)))
    sons = [("caixinha", caixinha_parabens()), ("maquina", maquina_lavar()), ("batida_oca", batida_parede(True, 1)),
            ("batida_macica", batida_parede(False, 2)), ("arrastar", arrastar()), ("projetor", projetor()),
            ("motor", motor_carro()), ("partida", partida_carro()), ("tres_batidas", tres_batidas()),
            ("vela_apaga", vela_apaga()), ("radio", radio_chiado()), ("desmoronar", desmoronar())]
    itens += sons
    mapa_h, dur_h, ogg_h = montar_sprite(itens, "oi3_historia")
    # as falas antigas do Keko (voz adulta com tom mudado) saem do mapa: agora vêm de "historia"
    for k in list(resumo.get("vozes2", {})):
        if k.startswith("KE_"):
            del resumo["vozes2"][k]
    resumo["historia"] = mapa_h
    print(f"historia: {len(itens)} itens, {dur_h:.1f}s, {os.path.getsize(ogg_h) // 1024} KB")
    escrever_mapa_json(resumo)
    with open(caminho_json, "w", encoding="utf-8") as f:
        json.dump(resumo, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--ajuste8":
        ajuste8(sys.argv[2])
    elif len(sys.argv) > 1 and sys.argv[1] == "--ajuste5":
        ajuste5(sys.argv[2])
    elif len(sys.argv) > 1 and sys.argv[1] == "--ajuste4":
        ajuste4()
    elif len(sys.argv) > 1 and sys.argv[1] == "--ajuste2":
        ajuste2(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
    else:
        main()
