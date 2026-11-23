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


def write(name, signal):
    signal = signal / max(1e-9, np.abs(signal).max()) * 0.89  # peak at -1 dBFS
    fade = min(len(signal), int(RATE * 0.01))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(data)
    return len(signal) / RATE


SOUNDS = {
    "arma_vespa": lambda: shot(0.45, 1.0, 1300, 22, 95, 20, 1800, 101, 5200),
    "arma_enxame": lambda: shot(0.26, 0.8, 1700, 34, 120, 32, 2400, 111, 6000),
    "arma_trovao": lambda: shot(0.85, 1.3, 600, 9, 62, 7, 900, 121, 2600),
    "arma_agulha": lambda: shot(0.55, 1.2, 2000, 18, 85, 16, 3000, 131, 6800),
    "arma_soco": punch,
    "arma_lamina": blade,
    "arma_recarga": reload,
    "arma_vazia": empty,
    "arma_troca": equip,
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, build in SOUNDS.items():
        seconds = write(name, build())
        print(f"{name}: {seconds:.3f} s")


if __name__ == "__main__":
    main()
