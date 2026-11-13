#!/usr/bin/env python3
"""BIZARRE BATTLEGROUNDS :: sons de golpe (AJUSTE-13) -> assets/sfx.ogg + tabela Sons.SFX

Pega os sons que o dono mandou (assets/sfx_fontes) e trata para luta:
  - corta o silêncio do começo (o estalo do soco sai NA HORA do acerto);
  - grave mais forte que aparece até em alto-falante de celular: o grave fundo (40-60 Hz, que
    celular não toca) passa por saturação e vira harmônicos de 100-500 Hz ("grave de verdade");
  - estalo do impacto mais nítido e um pouco "estourado" (saturação suave no fim);
  - volume alto e igual entre as variações.
Junta tudo num áudio só (cada som é um trecho, como as vozes) para enviar UMA vez ao Roblox.
Ordem fixa: som novo entra SEMPRE no fim (um áudio antigo com menos trechos continua valendo).
uso (na raiz do repositório): python3 bizarre/tools/sons_sfx.py
"""
import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTES = os.path.join(RAIZ, "assets", "sfx_fontes")
SAIDA = os.path.join(RAIZ, "assets", "sfx.ogg")
ORDEM = os.path.join(RAIZ, "assets", "sfx_ordem.json")
SR = 48000
INTERVALO = 0.25  # silêncio entre os trechos


def rodar(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("falhou: " + " ".join(cmd) + "\n" + r.stderr[-600:])


def ler(caminho):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        rodar(["ffmpeg", "-y", "-v", "error", "-i", caminho, "-ac", "1", "-ar", str(SR), "-sample_fmt", "s16", wav])
        with wave.open(wav) as w:
            d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return d


def gravar(caminho, x):
    y = np.clip(x, -1, 1)
    with wave.open(caminho, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


# ------------------------------------------------------------------ filtros (biquads RBJ)
def biquad(x, b, a):
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x)


def shelf_grave(x, f0, ganho_db):
    A = 10 ** (ganho_db / 40)
    w0 = 2 * np.pi * f0 / SR
    c, s = np.cos(w0), np.sin(w0)
    alfa = s / 2 * np.sqrt(2)
    raiz = 2 * np.sqrt(A) * alfa
    b = [A * ((A + 1) - (A - 1) * c + raiz), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - raiz)]
    a = [(A + 1) + (A - 1) * c + raiz, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - raiz]
    return biquad(x, b, a)


def pico_eq(x, f0, q, ganho_db):
    A = 10 ** (ganho_db / 40)
    w0 = 2 * np.pi * f0 / SR
    alfa = np.sin(w0) / (2 * q)
    b = [1 + alfa * A, -2 * np.cos(w0), 1 - alfa * A]
    a = [1 + alfa / A, -2 * np.cos(w0), 1 - alfa / A]
    return biquad(x, b, a)


def passa(x, tipo, f, ordem=4):
    sos = signal.butter(ordem, f, btype=tipo, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def norm(x, pico_db=-0.6):
    p = np.max(np.abs(x)) or 1.0
    return x / p * (10 ** (pico_db / 20))


def inicio_do_golpe(x, depois=0.0, limiar=0.12):
    """primeira amostra acima de limiar*pico (depois de 'depois' segundos), recuada 3 ms"""
    i0 = int(depois * SR)
    seg = np.abs(x[i0:])
    pk = seg.max()
    i = i0 + int(np.argmax(seg > pk * limiar))
    return max(0, i - int(0.003 * SR))


def fade(x, ini, dur, curva=2.0):
    """fade-out a partir de 'ini' segundos durante 'dur' (curva > 1 = cai rápido no começo)"""
    y = x.copy()
    a = int(ini * SR)
    b = min(len(y), a + int(dur * SR))
    if a < len(y):
        n = b - a
        y[a:b] *= (1 - np.linspace(0, 1, n)) ** curva
        y[b:] = 0
    return y[:b]


def entrada(x, dur):
    y = x.copy()
    n = min(len(y), int(dur * SR))
    y[:n] *= np.linspace(0, 1, n) ** 2
    return y


def bandas(x, cortes=(70.0, 250.0, 2000.0)):
    """separa em 4 faixas que somam o sinal original: sub, grave, médio e agudo"""
    sub = passa(x, "lowpass", cortes[0])
    resto = x - sub
    grave = passa(resto, "lowpass", cortes[1])
    resto = resto - grave
    medio = passa(resto, "lowpass", cortes[2])
    return sub, grave, medio, resto - medio


def estourar(x, drive):
    """saturação suave (tanh): segura os picos, sobe o corpo e deixa o som 'estourado'"""
    p = np.max(np.abs(x)) or 1.0
    y = np.tanh(drive * x / p)
    return passa(y, "lowpass", 12500, 6)


def peso(x, ganhos, forca, harm, faixa_harm, drive):
    """o tratamento de soco: o grave fundo (que celular não toca) vira harmônicos audíveis,
    cada faixa ganha seu volume e tudo passa por uma saturação no fim (o 'estourado')"""
    x = passa(x, "highpass", 28, 2)
    sub, grave, medio, agudo = bandas(x)
    baixo = sub + grave
    pk = np.max(np.abs(baixo)) or 1.0
    sat = np.tanh(forca * baixo / pk) * pk
    harmonicos = passa(passa(sat, "highpass", faixa_harm[0], 2), "lowpass", faixa_harm[1], 4)
    y = ganhos[0] * sub + ganhos[1] * grave + ganhos[2] * medio + ganhos[3] * agudo + harm * harmonicos
    return estourar(y, drive)


# ------------------------------------------------------------------ cada som
def soco_a(bruto):
    """'big punch with whoosh': o golpe começa em ~0,7 s (antes é o whoosh)"""
    i = inicio_do_golpe(bruto, depois=0.6)
    x = peso(bruto[i:i + int(0.62 * SR)], (0.35, 2.2, 1.8, 1.5), 12.0, 2.4, (110, 900), 5.0)
    return norm(fade(x, 0.30, 0.30, 1.6))


def soco_b(bruto):
    """'hard punch': quase tudo é grave fundo (40-60 Hz); vira grave audível, estalo e sujeira"""
    i = inicio_do_golpe(bruto, 0.0)
    x = peso(bruto[i:i + int(0.85 * SR)], (0.2, 1.6, 3.5, 3.0), 30.0, 3.5, (180, 2500), 6.5)
    return norm(fade(x, 0.32, 0.42, 2.2))


def soco_mega(bruto_a, bruto_b):
    """as duas camadas juntas (estalo do A + peso do B): para golpe forte e finalização"""
    ia = inicio_do_golpe(bruto_a, depois=0.6)
    ib = inicio_do_golpe(bruto_b, 0.0)
    n = int(0.9 * SR)
    a = np.zeros(n)
    b = np.zeros(n)
    pa = bruto_a[ia:ia + n]
    pb = bruto_b[ib:ib + n]
    a[:len(pa)] = pa / (np.max(np.abs(pa)) or 1)
    b[:len(pb)] = pb / (np.max(np.abs(pb)) or 1)
    x = peso(0.85 * a + 0.95 * b, (0.3, 2.0, 2.5, 2.0), 20.0, 3.0, (130, 1800), 7.0)
    return norm(fade(x, 0.40, 0.48, 2.0))


def whoosh_soco(bruto):
    """o whoosh que vem antes do golpe no som A (para o braço indo forte)"""
    i = inicio_do_golpe(bruto, depois=0.6)
    ini = max(0, i - int(0.42 * SR))
    x = bruto[ini:i]
    x = passa(x, "highpass", 70, 2)
    x = pico_eq(x, 900, 0.8, 2.0)
    x = entrada(x, 0.14)
    n = len(x)
    k = int(0.025 * SR)
    x[n - k:] *= np.linspace(1, 0, k)
    return norm(x, -2.0)


SONS = {
    # nome -> (função, volume no jogo)
    "SOCO_A": (lambda f: soco_a(f["a"]), 1.6),
    "SOCO_B": (lambda f: soco_b(f["b"]), 1.6),
    "SOCO_MEGA": (lambda f: soco_mega(f["a"], f["b"]), 1.9),
    "WHOOSH_SOCO": (lambda f: whoosh_soco(f["a"]), 1.1),
}


def medir(nome, x):
    sp = np.abs(np.fft.rfft(x)) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    tot = sp.sum() or 1
    faixa = lambda a, b: 100 * sp[(fr >= a) & (fr < b)].sum() / tot
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    print("  %-12s %.2fs  rms %5.1f dB  | <80Hz %4.1f%%  80-250 %4.1f%%  250-600 %4.1f%%  0.6-4k %4.1f%%  >4k %4.1f%%" % (
        nome, len(x) / SR, rms, faixa(0, 80), faixa(80, 250), faixa(250, 600), faixa(600, 4000), faixa(4000, 24000)))


def main():
    fontes = {
        "a": ler(os.path.join(FONTES, "soco_whoosh_dono.mp3")),
        "b": ler(os.path.join(FONTES, "soco_forte_dono.mp3")),
    }
    ordem = json.load(open(ORDEM)) if os.path.isfile(ORDEM) else []
    for nome in SONS:
        if nome not in ordem:
            ordem.append(nome)
    faltam = [n for n in ordem if n not in SONS]
    if faltam:
        sys.exit("trechos sumiram da lista (a ordem é fixa): %s" % faltam)
    json.dump(ordem, open(ORDEM, "w"))
    pedacos = []
    trechos = {}
    t = 0.0
    silencio = np.zeros(int(INTERVALO * SR))
    print("sons tratados:")
    for i, nome in enumerate(ordem):
        x = SONS[nome][0](fontes)
        medir(nome, x)
        trechos[nome] = (round(t, 3), round(len(x) / SR, 3), SONS[nome][1], i + 1)
        pedacos += [x, silencio]
        t += len(x) / SR + INTERVALO
    tudo = np.concatenate(pedacos)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "sfx.wav")
        gravar(wav, tudo)
        if len(sys.argv) > 1 and sys.argv[1] == "--wav":
            gravar(sys.argv[2], tudo)
        rodar(["ffmpeg", "-y", "-v", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "7", "-ac", "1", "-ar", str(SR), SAIDA])
    print("áudio: %s (%.2f s, %d bytes)" % (SAIDA, len(tudo) / SR, os.path.getsize(SAIDA)))
    print("\nSons.SFX = {")
    for nome in sorted(trechos):
        ini, d, vol, n = trechos[nome]
        print("\t%s = { %.3f, %.3f, %.2f, %d }," % (nome, ini, d, vol, n))
    print("} :: { [string]: { number } }")


if __name__ == "__main__":
    main()
