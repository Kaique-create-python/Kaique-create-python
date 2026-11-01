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
        mapa[nome] = {"inicio": round(pos, 3), "dur": round(len(x) / SR, 3)}
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


if __name__ == "__main__":
    main()
