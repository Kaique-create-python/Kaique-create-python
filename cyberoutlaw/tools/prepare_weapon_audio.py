"""Prepara os sons de arma, recarga, passos e interface do CyberOutlaw (sem IA).

Tiros: gravações reais da Free Firearm Sound Library (CC0, OpenGameArt). Recargas: zer0_sol e
SpringySpringo (CC0). Cliques: LFA, Equipment Clicks II (CC0). Passos: Fantozzi's Footsteps (CC0).
Os sons de interface são sintetizados aqui. Cada som é recortado no primeiro disparo, ganha um final
suave e sai em WAV mono 16 bits, com pico em -1 dBFS.

Uso: python tools/prepare_weapon_audio.py <pasta com os downloads>
A pasta precisa de: "Prepared SFX Library.7z", reload.wav, assaultriflereload1_0.wav, gunreload1.wav,
shotguncock_0.wav, equipmentclicks.wav e Fantozzi-footsteps.7z (links em media/audio/CREDITOS.json).
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "media" / "audio"
RATE = 48000

# chave: (arquivo dentro do pacote, segundos depois do ataque, decaimento final, tom)
# Tomadas com um disparo isolado (o seguinte vem segundos depois). Tom < 1 deixa o tiro mais grave.
SHOTS = {
    "arma_glock": ("Prepared SFX Library/Walther PPQ/X_39P.wav", 0.62, 0.35, 1.0),
    "arma_deagle": ("Prepared SFX Library/1911/A_42P.wav", 0.85, 0.45, 0.86),
    "arma_uzi": ("Prepared SFX Library/Carl Gustav M45/G_31P.wav", 0.38, 0.22, 1.04),
    "arma_ak47": ("Prepared SFX Library/AK-47/C_31P.wav", 0.8, 0.45, 1.0),
    "arma_m4": ("Prepared SFX Library/AR-15/D_32P.wav", 0.7, 0.4, 1.0),
    "arma_escopeta": ("Prepared SFX Library/Mossberg/N_30P.wav", 1.0, 0.5, 1.0),
    "arma_sniper": ("Prepared SFX Library/Tikka/W_29P.wav", 1.5, 0.85, 0.94),
}


def read_wav(path):
    with wave.open(str(path)) as w:
        channels, width, rate, frames = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        data = w.readframes(frames)
    if width == 2:
        samples = np.frombuffer(data, "<i2").astype(float) / 32768
    elif width == 3:
        raw = np.frombuffer(data, np.uint8).reshape(-1, 3)
        value = raw[:, 0].astype(np.int32) | (raw[:, 1].astype(np.int32) << 8) | (raw[:, 2].astype(np.int32) << 16)
        value = np.where(value >= 1 << 23, value - (1 << 24), value)
        samples = value.astype(float) / (1 << 23)
    elif width == 4:
        samples = np.frombuffer(data, "<i4").astype(float) / (1 << 31)
    else:
        raise ValueError(f"profundidade não suportada: {width * 8} bits")
    mono = samples.reshape(-1, channels).mean(axis=1)
    return resample(mono, rate, RATE)


def resample(signal, source, target):
    if source == target:
        return signal
    # Filtro passa-baixa simples antes de reamostrar por interpolação linear.
    if target < source:
        cutoff = 0.45 * target / source
        taps = np.arange(-64, 65)
        kernel = np.sinc(2 * cutoff * taps) * np.hamming(len(taps))
        signal = np.convolve(signal, kernel / kernel.sum(), mode="same")
    t = np.arange(int(len(signal) * target / source)) * source / target
    return np.interp(t, np.arange(len(signal)), signal)


def decode(path):
    """FLAC ou OGG via ffmpeg, para WAV mono no tamanho de amostra do jogo."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "out.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-sample_fmt", "s16", str(out)], check=True)
        return read_wav(out)


def onset(signal, threshold=0.12):
    peak = np.abs(signal).max()
    index = int(np.argmax(np.abs(signal) > peak * threshold))
    return max(0, index - int(0.004 * RATE))


def cut(signal, start, length, fade):
    piece = signal[start:start + int(length * RATE)].copy()
    tail = min(len(piece), int(fade * RATE))
    piece[-tail:] *= np.linspace(1, 0, tail) ** 2
    piece[: int(0.0015 * RATE)] *= np.linspace(0, 1, int(0.0015 * RATE))
    return piece


def highpass(signal, freq):
    rc = 1 / (2 * np.pi * freq)
    alpha = rc / (rc + 1 / RATE)
    out = np.zeros_like(signal)
    for i in range(1, len(signal)):
        out[i] = alpha * (out[i - 1] + signal[i] - signal[i - 1])
    return out


def segments(signal, threshold=0.18, gap=0.08):
    """Trechos com som (para separar cliques e passos de uma gravação com vários)."""
    env = np.convolve(np.abs(signal), np.ones(256) / 256, mode="same")
    peak = env.max()
    active = env > peak * threshold
    found, start, quiet = [], None, 0
    for i, on in enumerate(active):
        if on:
            if start is None:
                start = i
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet > gap * RATE:
                found.append((start, i - quiet))
                start = None
    if start is not None:
        found.append((start, len(signal) - 1))
    return found


def write(name, signal, peak=0.89):
    signal = signal / max(1e-9, np.abs(signal).max()) * peak
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(data)
    return path, len(signal) / RATE


def ui_sounds():
    t = lambda seconds: np.arange(int(RATE * seconds)) / RATE
    tick = t(0.05)
    ui_tick = (np.sin(2 * np.pi * 2350 * tick) * np.exp(-tick * 160) * 0.6
               + np.random.default_rng(3).uniform(-1, 1, len(tick)) * np.exp(-tick * 900) * 0.25)
    whoosh_t = t(0.22)
    noise = np.random.default_rng(5).uniform(-1, 1, len(whoosh_t))
    band = np.convolve(noise, np.ones(18) / 18, mode="same") - np.convolve(noise, np.ones(90) / 90, mode="same")
    shape = np.sin(np.pi * np.clip(whoosh_t / 0.22, 0, 1)) ** 1.5
    rise = np.sin(2 * np.pi * (380 * whoosh_t + 900 * whoosh_t ** 2)) * 0.12
    fall = np.sin(2 * np.pi * (760 * whoosh_t - 800 * whoosh_t ** 2)) * 0.12
    ui_open = band * shape + rise * shape
    ui_close = band[::-1] * shape + fall * shape
    chime_t = t(0.32)
    chime = np.zeros_like(chime_t)
    for start, freq in ((0.0, 1320), (0.07, 1760)):
        tt = np.clip(chime_t - start, 0, None)
        chime += (np.sin(2 * np.pi * freq * tt) + 0.3 * np.sin(2 * np.pi * freq * 2 * tt)) * np.exp(-tt * 14) * (chime_t >= start)
    return {"ui_tick": ui_tick, "ui_abrir": ui_open, "ui_fechar": ui_close, "ui_confirmar": chime}


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".cache" / "audio"
    OUT.mkdir(parents=True, exist_ok=True)
    credits_path = OUT / "CREDITOS.json"
    credits = json.loads(credits_path.read_text(encoding="utf-8"))
    entries = {entry["key"]: entry for entry in credits["entries"]} if isinstance(credits, dict) and "entries" in credits else None
    results = {}

    import py7zr
    library = source / "Prepared SFX Library.7z"
    with tempfile.TemporaryDirectory() as tmp:
        with py7zr.SevenZipFile(library) as archive:
            archive.extract(path=tmp, targets=[item[0] for item in SHOTS.values()])
        for key, (inner, length, fade, pitch) in SHOTS.items():
            raw_path = Path(tmp) / inner
            raw = raw_path.read_bytes()
            signal = highpass(read_wav(raw_path), 35)
            if pitch != 1.0:
                # Mais amostras tocadas na mesma taxa: o som fica mais grave e um pouco mais longo.
                signal = resample(signal, RATE, int(RATE / pitch))
            start = onset(signal)
            shot = cut(signal, start, length, fade)
            # Compressão suave: o estalo perde um pouco do pico e o corpo do tiro aparece no celular.
            shot = np.tanh(3.2 * shot / np.abs(shot).max())
            results[key] = (shot, {
                "provider": "The Free Firearm Sound Library (OpenGameArt)", "license": "CC0 1.0",
                "authors": "Ben Jaszczak, Brian Nelson, Kevin Heras e Matthew Nanney",
                "source": "https://opengameart.org/content/the-free-firearm-sound-library", "file": inner,
                "sourceSha256": hashlib.sha256(raw).hexdigest(),
            })
    reloads = {
        "arma_recarga": ("reload.wav", "zer0_sol", "https://opengameart.org/content/handgun-reload-sound-effect"),
        "arma_recarga_fuzil": ("assaultriflereload1_0.wav", "SpringySpringo", "https://opengameart.org/content/gun-reload-sounds"),
        "arma_recarga_escopeta": ("shotguncock_0.wav", "SpringySpringo", "https://opengameart.org/content/gun-reload-sounds"),
    }
    for key, (name, author, url) in reloads.items():
        path = source / name
        signal = read_wav(path)
        start = onset(signal, 0.05)
        results[key] = (cut(signal, start, len(signal) / RATE, 0.08), {
            "provider": "OpenGameArt", "license": "CC0 1.0", "authors": author, "source": url, "file": name,
            "sourceSha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    # Ações depois do tiro: bomba da escopeta (só o puxa-empurra) e ferrolho da sniper (abre e fecha).
    cock_path = source / "shotguncock_0.wav"
    cock = read_wav(cock_path)
    start = onset(cock, 0.05)
    results["arma_bomba"] = (cut(cock, start, 0.3, 0.05), {
        "provider": "OpenGameArt", "license": "CC0 1.0", "authors": "SpringySpringo",
        "source": "https://opengameart.org/content/gun-reload-sounds", "file": "shotguncock_0.wav",
        "sourceSha256": hashlib.sha256(cock_path.read_bytes()).hexdigest(),
    })
    bolt_path = source / "gunreload1.wav"
    bolt = read_wav(bolt_path)
    events = segments(bolt, threshold=0.06)
    if len(events) >= 2:
        first, last = events[0], events[-1]
        opening = cut(bolt, max(0, first[0] - 240), 0.3, 0.06)
        closing = cut(bolt, max(0, last[0] - 240), 0.32, 0.08)
        gap = np.zeros(int(0.14 * RATE))
        results["arma_ferrolho"] = (np.concatenate([opening, gap, closing]), {
            "provider": "OpenGameArt", "license": "CC0 1.0", "authors": "SpringySpringo",
            "source": "https://opengameart.org/content/gun-reload-sounds", "file": "gunreload1.wav",
            "sourceSha256": hashlib.sha256(bolt_path.read_bytes()).hexdigest(),
        })
    clicks_path = source / "equipmentclicks.wav"
    clicks = read_wav(clicks_path)
    parts = segments(clicks)
    meta = {"provider": "OpenGameArt", "license": "CC0 1.0", "authors": "LFA",
            "source": "https://opengameart.org/content/equipment-clicks-ii", "file": "equipmentclicks.wav",
            "sourceSha256": hashlib.sha256(clicks_path.read_bytes()).hexdigest()}
    shortest = min(parts, key=lambda p: p[1] - p[0])
    longest = max(parts, key=lambda p: p[1] - p[0])
    results["arma_vazia"] = (cut(clicks, max(0, shortest[0] - 200), min(0.16, (shortest[1] - shortest[0]) / RATE + 0.06), 0.04), dict(meta))
    results["arma_troca"] = (cut(clicks, max(0, longest[0] - 200), min(0.45, (longest[1] - longest[0]) / RATE + 0.08), 0.1), dict(meta))
    # Passos em pedra (Fantozzi): quatro variações para não repetir.
    steps_archive = source / "Fantozzi-footsteps.7z"
    with tempfile.TemporaryDirectory() as tmp:
        with py7zr.SevenZipFile(steps_archive) as archive:
            names = [f"Fantozzi-footsteps/flac/Fantozzi-Stone{side}{n}.flac" for side, n in (("L", 1), ("R", 1), ("L", 2), ("R", 2))]
            archive.extract(path=tmp, targets=names)
        for index, inner in enumerate(names, start=1):
            signal = highpass(decode(Path(tmp) / inner), 60)
            start = onset(signal, 0.08)
            results[f"passo_{index}"] = (cut(signal, start, min(0.32, len(signal) / RATE - start / RATE), 0.12), {
                "provider": "OpenGameArt", "license": "CC0 1.0", "authors": "Fantozzi (OpenGameArt)",
                "source": "https://opengameart.org/content/fantozzis-footsteps-grasssand-stone", "file": inner,
                "sourceSha256": hashlib.sha256(steps_archive.read_bytes()).hexdigest(),
            })
    for key, signal in {}.items():  # interface e pulo: gravações reais em tools/real_foley_audio.py
        results[key] = (signal, {"provider": "Síntese própria", "license": "Original do projeto", "source": "tools/prepare_weapon_audio.py"})

    for key, (signal, info) in results.items():
        peak = 0.7 if key.startswith("passo_") or key.startswith("ui_") else 0.89
        path, seconds = write(key, signal, peak)
        info = {**info, "durationSeconds": round(seconds, 3), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        print(f"{key}: {seconds:.3f} s · {info.get('authors', info['provider'])}")
        results[key] = info
    (OUT / "CREDITOS_ARMAS.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _ = entries


if __name__ == "__main__":
    main()
