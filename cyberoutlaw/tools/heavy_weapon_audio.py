"""Versões "pesadas" dos tiros reais (CC0): mais grave, mais corpo e mais alto.

Lê media/audio/arma_<arma>.wav (gravações da Free Firearm Sound Library) e grava arma_<arma>_pesada.wav:
grave reforçado abaixo de ~160 Hz, um baque subgrave curto no disparo (para o celular sentir o tiro),
saturação suave e pico em -0,3 dBFS. O original fica intacto; o jogo usa a pesada quando ela existir.
Uso: python tools/heavy_weapon_audio.py
"""
from pathlib import Path
import wave

import numpy as np

AUDIO = Path(__file__).resolve().parents[1] / "media" / "audio"
# arma: (reforço do grave, peso do baque subgrave, frequência inicial do baque)
GUNS = {
    "arma_glock": (1.3, 0.55, 90),
    "arma_deagle": (1.8, 0.85, 75),
    "arma_uzi": (1.1, 0.45, 95),
    "arma_ak47": (1.7, 0.8, 80),
    "arma_m4": (1.5, 0.7, 85),
    "arma_escopeta": (2.0, 1.0, 70),
    "arma_sniper": (2.2, 1.0, 62),
}


def read(path):
    with wave.open(str(path)) as stream:
        rate = stream.getframerate()
        data = np.frombuffer(stream.readframes(stream.getnframes()), "<i2").astype(np.float64) / 32768
    return data, rate


def lowpass(signal, rate, freq, passes=2):
    """Passa-baixa de um polo aplicado algumas vezes (sem SciPy)."""
    alpha = 1 - np.exp(-2 * np.pi * freq / rate)
    out = signal
    for _ in range(passes):
        y = np.empty_like(out)
        acc = 0.0
        for i, x in enumerate(out):
            acc += alpha * (x - acc)
            y[i] = acc
        out = y
    return out


def heavy(signal, rate, bass, thump, start_freq):
    signal = signal / max(1e-9, np.abs(signal).max())
    low = lowpass(signal, rate, 160)
    out = signal + low * bass
    t = np.arange(len(signal)) / rate
    onset = int(np.argmax(np.abs(signal) > 0.3))
    bt = np.clip(t - onset / rate, 0, None)
    freq = start_freq * (38 / start_freq) ** np.clip(bt / 0.18, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq) / rate
    sub = np.sin(phase) * (t >= onset / rate) * np.minimum(1, bt / 0.002) * np.exp(-bt * 11)
    out = out + sub * thump * np.abs(out).max()
    out = np.tanh(out / np.abs(out).max() * 1.9) / np.tanh(1.9)
    return out / np.abs(out).max() * 0.965


def main():
    for name, (bass, thump, start) in GUNS.items():
        signal, rate = read(AUDIO / f"{name}.wav")
        out = heavy(signal, rate, bass, thump, start)
        data = (np.clip(out, -1, 1) * 32767).astype("<i2").tobytes()
        with wave.open(str(AUDIO / f"{name}_pesada.wav"), "wb") as stream:
            stream.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            stream.writeframes(data)
        print(f"{name}_pesada: {len(out) / rate:.2f} s")


if __name__ == "__main__":
    main()
