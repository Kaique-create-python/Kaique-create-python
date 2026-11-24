"""CyberOutlaw weapon sounds synthesized by code (no AI, no samples).

Each sound combines filtered noise, oscillators, and envelopes. The seed is fixed, so the
file comes out identical every time. Usage: python tools/synth_weapon_fx.py
"""
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1] / "media" / "audio"
RATE = 44100


def biquad(signal, kind, freq, q=0.707):
    """RBJ Cookbook filter (lowpass, highpass, or bandpass), sample by sample."""
    w0 = 2 * np.pi * freq / RATE
    alpha = np.sin(w0) / (2 * q)
    cos = np.cos(w0)
    if kind == "low":
        b = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2]
    elif kind == "high":
        b = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2]
    else:
        b = [alpha, 0, -alpha]
    a = [1 + alpha, -2 * cos, 1 - alpha]
    b = [x / a[0] for x in b]
    a1, a2 = a[1] / a[0], a[2] / a[0]
    out = np.zeros_like(signal)
    x1 = x2 = y1 = y2 = 0.0
    for i, x in enumerate(signal):
        y = b[0] * x + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        out[i] = y
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def env(t, attack, decay):
    return np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t * decay)


def noise(n, seed):
    return np.random.default_rng(seed).uniform(-1, 1, n)


def tail(signal, seed, decay=9.0, amount=0.25):
    """Short reverb: convolution with decaying, filtered noise."""
    length = int(RATE * 0.35)
    t = np.arange(length) / RATE
    impulse = noise(length, seed) * np.exp(-t * decay)
    impulse = biquad(impulse, "low", 3200)
    wet = np.convolve(signal, impulse)[: len(signal)]
    wet /= max(1e-9, np.abs(wet).max())
    return signal + wet * amount * np.abs(signal).max()


def shot(length, crack, body_freq, body_decay, thump, thump_decay, laser, seed, cutoff):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    burst = biquad(noise(n, seed), "high", 1800) * env(t, 0.0005, 260) * crack * 0.4
    body = biquad(noise(n, seed + 1), "band", body_freq, 0.9) * env(t, 0.001, body_decay)
    low = np.sin(2 * np.pi * (thump * t - 18 * t**2)) * env(t, 0.002, thump_decay) * 1.6
    # Cyberpunk signature: a falling electric "pew", subtle.
    sweep = np.sin(2 * np.pi * (laser * t - laser * 1.3 * t**2)) * env(t, 0.002, 30) * 0.14
    mix = biquad(biquad(burst + body + low + sweep, "low", cutoff), "low", cutoff * 1.3)
    return tail(mix, seed + 2, amount=0.18)


def punch():
    n = int(RATE * 0.3)
    t = np.arange(n) / RATE
    whoosh = biquad(noise(n, 11), "band", 900, 1.4) * np.sin(np.pi * np.clip(t / 0.16, 0, 1)) * 0.7
    hit_t = np.clip(t - 0.12, 0, None)
    thud = np.sin(2 * np.pi * 110 * hit_t) * env(hit_t, 0.002, 26) * (t > 0.12) * 1.1
    snap = biquad(noise(n, 12), "high", 1800) * env(hit_t, 0.0005, 160) * (t > 0.12) * 0.5
    return biquad(whoosh + thud + snap, "low", 3400)


def blade():
    n = int(RATE * 0.45)
    t = np.arange(n) / RATE
    sweep = np.zeros(n)
    raw = noise(n, 21)
    for start, freq in ((0, 700), (0.1, 1600), (0.2, 2600)):
        part = biquad(raw, "band", freq, 2.0)
        sweep += part * np.exp(-((t - start - 0.08) ** 2) / 0.004)
    buzz = np.sign(np.sin(2 * np.pi * (140 + 18 * np.sin(2 * np.pi * 9 * t)) * t)) * 0.12 * np.sin(np.pi * np.clip(t / 0.42, 0, 1))
    sizzle = biquad(noise(n, 22), "high", 4200) * 0.06 * np.sin(np.pi * np.clip(t / 0.45, 0, 1))
    return biquad(sweep * 0.9 + biquad(buzz, "low", 2400) + sizzle, "low", 6000)


def click(n, start, freq, seed, gain=1.0):
    t = np.arange(n) / RATE - start
    on = t >= 0
    tt = np.clip(t, 0, None)
    ping = (np.sin(2 * np.pi * freq * tt) + 0.6 * np.sin(2 * np.pi * freq * 1.47 * tt)) * env(tt, 0.0003, 90)
    tick = biquad(noise(n, seed), "high", 3000) * env(tt, 0.0002, 400)
    return (ping * 0.5 + tick) * on * gain


def reload():
    n = int(RATE * 0.75)
    t = np.arange(n) / RATE
    slide = biquad(noise(n, 31), "band", 1400, 1.1) * np.exp(-((t - 0.28) ** 2) / 0.006) * 0.35
    return click(n, 0.04, 2200, 32) + slide + click(n, 0.48, 3100, 33, 1.2)


def empty():
    n = int(RATE * 0.12)
    return click(n, 0.005, 2600, 41, 0.8)


def equip():
    n = int(RATE * 0.28)
    t = np.arange(n) / RATE
    chirp = np.sin(2 * np.pi * (500 * t + 2600 * t**2)) * env(t, 0.01, 12) * 0.35
    return click(n, 0.0, 1900, 51) + chirp


def reverb(signal, seed, seconds=2.2, decay=2.6, amount=0.45, cutoff=5000):
    """Reverb longo: convolução com ruído filtrado que decai (sala grande/metálica)."""
    length = int(RATE * seconds)
    t = np.arange(length) / RATE
    impulse = biquad(noise(length, seed), "low", cutoff) * np.exp(-t * decay)
    wet = np.convolve(signal, impulse)[: len(signal)]
    wet /= max(1e-9, np.abs(wet).max())
    return signal + wet * amount * np.abs(signal).max()


def glide(f0, f1, seconds, t):
    """Frequência que desliza de f0 a f1 (exponencial) em `seconds`, e a fase acumulada."""
    k = np.clip(t / seconds, 0, 1)
    freq = f0 * (f1 / f0) ** k
    return 2 * np.pi * np.cumsum(freq) / RATE


def sandevistan():
    """Ativação do Sandevistan, sem onda quadrada: sopro ao contrário que suga o ar, estrondo subgrave que
    mergulha de 95 Hz a 26 Hz (com harmônicos para o celular tocar), anel metálico de tempo congelado,
    zumbido grave que desacelera, coração lento e reverb longo."""
    n = int(RATE * 3.8)
    t = np.arange(n) / RATE
    hit = 0.32
    pre = np.clip(t / hit, 0, 1) ** 3 * (t < hit + 0.02)
    swell = np.zeros(n)
    hiss = noise(n, 91)
    for cutoff, weight in ((500, 0.5), (1600, 0.35), (4800, 0.25)):
        swell += biquad(hiss, "low", cutoff) * weight
    swell *= pre * 0.7
    suck = np.sin(glide(140, 900, hit, t)) * pre * 0.25
    after = np.clip(t - hit, 0, None)
    on = t >= hit
    boom = np.sin(glide(95, 26, 1.4, after)) * on * env(after, 0.005, 1.15)
    boom = np.tanh(boom * 2.2) * 0.9
    thud = biquad(noise(n, 92), "low", 220) * on * env(after, 0.002, 9) * 1.4
    ring = np.zeros(n)
    for freq, gain, dec in ((523.0, 0.16, 1.1), (1307.0, 0.09, 1.5), (2131.0, 0.05, 1.9)):
        bend = 1 - 0.3 * np.clip(after / 3.0, 0, 1)
        ring += np.sin(2 * np.pi * np.cumsum(freq * bend) / RATE) * on * env(after, 0.004, dec) * gain
    drone = np.zeros(n)
    slow = 1 - 0.2 * np.clip(after / 3.2, 0, 1)
    for freq, gain in ((55.0, 0.5), (82.4, 0.32), (110.2, 0.24), (164.8, 0.12)):
        drone += np.sin(2 * np.pi * np.cumsum(freq * slow) / RATE) * gain
    drone = biquad(drone, "low", 420) * on * np.minimum(1, after / 0.5) * np.exp(-after * 0.55)
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.7 * after)
    heart = np.zeros(n)
    for beat in (1.15, 2.05, 2.95):
        for offset, gain in ((0.0, 1.0), (0.16, 0.7)):
            bt = np.clip(t - beat - offset, 0, None)
            heart += np.tanh(np.sin(2 * np.pi * 48 * bt) * 1.6) * (t >= beat + offset) * env(bt, 0.004, 15) * gain
    shimmer = np.zeros(n)
    for detune in (0.997, 1.0, 1.004):
        vib = 1 + 0.003 * np.sin(2 * np.pi * 5.2 * after)
        shimmer += np.sin(2 * np.pi * np.cumsum(1760 * detune * vib * slow) / RATE)
    shimmer *= on * env(after, 0.08, 1.0) * 0.025
    mix = swell + suck + boom + thud + ring + drone * 0.9 + heart * 0.7 + shimmer
    return reverb(mix, 93, seconds=2.4, decay=2.2, amount=0.5)


def frenzy():
    """Ciberpsicose: coração disparando com distorção, grito sintético (harmônicos com formantes, saturado),
    estalos elétricos e um mergulho subgrave. Tudo com ondas suaves, sem som de 8 bits."""
    n = int(RATE * 3.0)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(101)
    heart = np.zeros(n)
    beat = 0.05
    gap = 0.62
    while beat < 2.6:
        for offset, gain in ((0.0, 1.0), (0.13, 0.75)):
            bt = np.clip(t - beat - offset, 0, None)
            heart += np.tanh(np.sin(2 * np.pi * 52 * bt) * 2.5) * (t >= beat + offset) * env(bt, 0.003, 14) * gain
        beat += gap
        gap = max(0.28, gap * 0.8)
    f0 = 180 + 260 * np.clip(t / 1.6, 0, 1)
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    voice = sum(np.sin(phase * k) / k for k in range(1, 14))
    formant = biquad(voice, "band", 900, 3.0) * 2.5 + biquad(voice, "band", 2600, 4.0) * 1.6
    scream = np.tanh(formant * 2.8) * env(t, 0.12, 0.9) * 0.4
    crackle = np.zeros(n)
    for start in rng.uniform(0.0, 2.6, 26):
        bt = np.clip(t - start, 0, None)
        crackle += (t >= start) * env(bt, 0.0005, 70) * rng.uniform(0.3, 1.0)
    crackle = biquad(noise(n, 102) * crackle, "high", 2200) * 0.5
    drop = np.tanh(np.sin(glide(70, 28, 1.8, t)) * 2) * env(t, 0.01, 1.2) * 0.8
    return reverb(heart * 0.9 + scream + crackle + drop, 103, seconds=1.6, decay=3.5, amount=0.35)


def double_jump():
    """Segundo pulo dos Tendões: sopro que sobe, servo e um baque leve."""
    n = int(RATE * 0.5)
    t = np.arange(n) / RATE
    whoosh = biquad(noise(n, 111), "band", 1400, 0.9) * np.sin(np.pi * np.clip(t / 0.35, 0, 1)) * 0.5
    servo = np.sin(glide(320, 980, 0.18, t)) * env(t, 0.005, 9) * 0.25
    thump = np.tanh(np.sin(2 * np.pi * 70 * t) * 2) * env(t, 0.002, 18) * 0.7
    return whoosh + servo + thump


def gorilla_punch():
    """Soco dos Braços de Gorila: impacto grave, estalo e o tinido metálico dos punhos."""
    n = int(RATE * 0.6)
    t = np.arange(n) / RATE
    boom = np.tanh(np.sin(glide(110, 40, 0.3, t)) * 2.4) * env(t, 0.002, 7) * 0.9
    crack = biquad(noise(n, 121), "high", 1800) * env(t, 0.0005, 45) * 0.6
    clank = sum(np.sin(2 * np.pi * f * t) * g for f, g in ((610, 0.12), (1590, 0.07), (2770, 0.04))) * env(t, 0.001, 12)
    return reverb(boom + crack + clank, 122, seconds=0.6, decay=8, amount=0.25)


def kiroshi_scan():
    """Varredura dos Ópticos Kiroshi: dois bipes suaves e uma subida de vidro."""
    n = int(RATE * 0.6)
    t = np.arange(n) / RATE
    beeps = sum(np.sin(2 * np.pi * 1320 * np.clip(t - s, 0, None)) * (t >= s) * env(np.clip(t - s, 0, None), 0.003, 30)
                for s in (0.0, 0.09)) * 0.25
    sweep = sum(np.sin(glide(1100 * d, 2600 * d, 0.45, np.clip(t - 0.15, 0, None))) for d in (0.996, 1.0, 1.005))
    sweep *= (t >= 0.15) * env(np.clip(t - 0.15, 0, None), 0.02, 5) * 0.06
    return reverb(beeps + sweep, 131, seconds=0.5, decay=9, amount=0.3)


def implant_lock():
    """Encaixe do implante: servo que gira, duas travas e um bipe de confirmação."""
    n = int(RATE * 0.55)
    t = np.arange(n) / RATE
    whir_f = 180 + 240 * np.clip(t / 0.22, 0, 1)
    saw = ((np.cumsum(whir_f) / RATE) % 1 - 0.5)
    whir = biquad(saw, "band", 900, 1.8) * np.exp(-((t - 0.12) ** 2) / 0.006) * 0.9
    beep_t = np.clip(t - 0.34, 0, None)
    beep = np.sin(2 * np.pi * 1320 * beep_t) * (t >= 0.34) * env(beep_t, 0.004, 14) * 0.25
    return whir + click(n, 0.24, 2400, 81, 1.1) + click(n, 0.3, 3200, 82, 0.9) + beep


def write(name, signal):
    signal = signal / max(1e-9, np.abs(signal).max()) * 0.89  # peak at -1 dBFS
    fade = min(len(signal), int(RATE * 0.01))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(data)
    return len(signal) / RATE


# Tiros, recargas, cliques e passos agora são gravações CC0 (tools/prepare_weapon_audio.py);
# o soco e a lâmina continuam sintetizados aqui.
SOUNDS = {
    "arma_soco": punch,
    "arma_lamina": blade,
    "habilidade_lenta": sandevistan,
    "surto": frenzy,
    "implante_encaixe": implant_lock,
    "pulo_duplo": double_jump,
    "soco_gorila": gorilla_punch,
    "kiroshi_scan": kiroshi_scan,
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, build in SOUNDS.items():
        seconds = write(name, build())
        print(f"{name}: {seconds:.3f} s")


if __name__ == "__main__":
    main()
