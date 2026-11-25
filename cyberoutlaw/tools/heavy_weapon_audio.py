"""Versões "pesadas" dos tiros reais (CC0): mais grave, mais corpo e mais alto.

Lê media/audio/arma_<arma>.wav (gravações da Free Firearm Sound Library) e grava arma_<arma>_pesada.wav:
grave reforçado em duas faixas (corpo e peito), agudo áspero mais baixo, um baque subgrave no disparo e um estrondo de cauda (para o celular sentir o tiro),
saturação suave e pico em -0,3 dBFS. O original fica intacto; o jogo usa a pesada quando ela existir.
Uso: python tools/heavy_weapon_audio.py
"""
from pathlib import Path
import wave

import numpy as np

AUDIO = Path(__file__).resolve().parents[1] / "media" / "audio"
# arma: (reforço do grave, peso do baque subgrave, frequência inicial do baque)
GUNS = {
    "arma_glock": (2.2, 0.9, 85),
    "arma_deagle": (3.0, 1.35, 70),
    "arma_uzi": (1.9, 0.75, 90),
    "arma_ak47": (2.8, 1.25, 75),
    "arma_m4": (2.5, 1.1, 80),
    "arma_escopeta": (3.4, 1.6, 64),
    "arma_sniper": (3.6, 1.6, 56),
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
    # Grave em duas faixas: corpo (até ~180 Hz) e peito (até ~70 Hz), e um pouco menos de agudo áspero.
    body = lowpass(signal, rate, 180)
    chest = lowpass(signal, rate, 70, passes=3)
    bright = signal - lowpass(signal, rate, 3500)
    out = signal - bright * 0.35 + body * bass + chest * bass * 1.4
    t = np.arange(len(signal)) / rate
    onset = int(np.argmax(np.abs(signal) > 0.3))
    bt = np.clip(t - onset / rate, 0, None)
    on = t >= onset / rate
    # Baque subgrave que mergulha até 30 Hz (o "soco" no peito) e um segundo estrondo mais longo de cauda.
    freq = start_freq * (30 / start_freq) ** np.clip(bt / 0.22, 0, 1)
    sub = np.sin(2 * np.pi * np.cumsum(freq) / rate) * on * np.minimum(1, bt / 0.002) * np.exp(-bt * 8)
    tail_freq = 46 * (28 / 46) ** np.clip(bt / 0.6, 0, 1)
    rumble = np.sin(2 * np.pi * np.cumsum(tail_freq) / rate) * on * np.minimum(1, bt / 0.01) * np.exp(-bt * 3.2) * 0.45
    peak = np.abs(out).max()
    out = out + (sub * thump + rumble * thump) * peak
    out = np.tanh(out / np.abs(out).max() * 2.3) / np.tanh(2.3)
    return out / np.abs(out).max() * 0.97


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
