"""Troca os sons sintéticos de interface e de pulo por gravações reais (CC0, sem IA).

Cliques da interface: LFA, "Equipment Clicks II" (OpenGameArt, CC0) — cliques de botões e travas de verdade.
Pulo, aterrissagem e pulo duplo: passos em pedra de Fantozzi (OpenGameArt, CC0), sobrepostos e com o tom
ajustado (impulso mais seco, queda mais pesada), e o pulo duplo leva também um clique de trava (o tendão).
Uso: python tools/real_foley_audio.py <pasta com equipmentclicks.wav e Fantozzi-footsteps.7z>
"""
from pathlib import Path
import hashlib
import json
import sys
import tempfile

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_weapon_audio as base  # noqa: E402

RATE = base.RATE
OUT = base.OUT


def pitch(signal, factor):
    """Muda o tom (e a duração) por reamostragem: factor < 1 deixa mais grave."""
    t = np.arange(int(len(signal) / factor)) * factor
    return np.interp(t, np.arange(len(signal)), signal)


def lowpass(signal, freq):
    alpha = 1 - np.exp(-2 * np.pi * freq / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha * (x - acc)
        out[i] = acc
    return out


def mix(*layers):
    length = max(len(layer[0]) + int(layer[1] * RATE) for layer in layers)
    out = np.zeros(length)
    for signal, delay, gain in layers:
        start = int(delay * RATE)
        out[start:start + len(signal)] += signal * gain
    return out


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else base.ROOT / ".cache" / "audio"
    clicks_path = source / "equipmentclicks.wav"
    clicks = base.read_wav(clicks_path)
    parts = sorted(base.segments(clicks, threshold=0.12, gap=0.05), key=lambda p: p[1] - p[0])
    def click(index, length=0.12):
        start, _ = parts[index % len(parts)]
        return base.cut(clicks, max(0, start - 120), length, 0.03)
    short, mid, long = click(0), click(len(parts) // 2), click(len(parts) - 1, 0.22)
    archive = source / "Fantozzi-footsteps.7z"
    import py7zr
    steps = []
    with tempfile.TemporaryDirectory() as tmp:
        with py7zr.SevenZipFile(archive) as z:
            names = [f"Fantozzi-footsteps/flac/Fantozzi-Stone{side}{n}.flac" for side, n in (("L", 3), ("R", 3), ("L", 1), ("R", 2))]
            z.extract(path=tmp, targets=names)
        for name in names:
            signal = base.decode(Path(tmp) / name)
            start = base.onset(signal)
            steps.append(base.cut(signal, start, min(0.35, len(signal) / RATE - start / RATE), 0.12))
    sounds = {
        # Interface: cliques reais, baixos e curtos (nada de bipe).
        "ui_tick": (base.highpass(short, 400), 0.45),
        "ui_abrir": (mix((pitch(mid, 0.9), 0, 1), (short, 0.06, 0.7)), 0.6),
        "ui_fechar": (mix((short, 0, 0.7), (pitch(mid, 0.82), 0.05, 1)), 0.6),
        "ui_confirmar": (mix((mid, 0, 1), (pitch(short, 1.1), 0.08, 0.9)), 0.65),
        "ui_negado": (lowpass(pitch(long, 0.7), 1800), 0.55),
        # Menu: os cliques que eram gerados por IA viram cliques gravados também.
        "click": (base.highpass(pitch(short, 0.95), 300), 0.5),
        "confirm": (mix((mid, 0, 1), (pitch(mid, 0.85), 0.07, 0.8)), 0.7),
        # Pulo: dois pés saindo do chão juntos, seco; aterrissagem: os dois pés batendo, mais grave e com corpo.
        "pulo": (mix((pitch(steps[0], 1.08), 0, 1), (pitch(steps[1], 1.12), 0.035, 0.8)), 0.7),
        "aterrissar": (mix((pitch(steps[2], 0.78), 0, 1), (pitch(steps[3], 0.74), 0.02, 0.9), (lowpass(pitch(steps[2], 0.6), 300), 0, 1.6)), 0.85),
        # Pulo duplo dos Tendões: pisada no ar + a trava mecânica do implante.
        "pulo_duplo": (mix((pitch(steps[1], 1.25), 0, 0.9), (pitch(long, 0.75), 0.01, 0.8), (lowpass(pitch(steps[0], 0.6), 260), 0, 1.4)), 0.8),
    }
    credits_path = OUT / "CREDITOS.json"
    credits = json.loads(credits_path.read_text(encoding="utf-8"))
    clicks_meta = {
        "provider": "OpenGameArt", "license": "CC0 1.0", "authors": "LFA",
        "source": "https://opengameart.org/content/equipment-clicks-ii", "file": "equipmentclicks.wav",
        "sourceSha256": hashlib.sha256(clicks_path.read_bytes()).hexdigest(), "process": "tools/real_foley_audio.py",
    }
    steps_meta = {
        "provider": "OpenGameArt", "license": "CC0 1.0", "authors": "Fantozzi (OpenGameArt)",
        "source": "https://opengameart.org/content/fantozzis-footsteps-grasssand-stone", "file": "Fantozzi-footsteps.7z (Stone)",
        "sourceSha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "process": "tools/real_foley_audio.py",
    }
    for key, (signal, peak) in sounds.items():
        path, seconds = base.write(key, signal, peak)
        meta = dict(steps_meta if key.startswith("pulo") or key == "aterrissar" else clicks_meta)
        if key == "pulo_duplo":
            meta["authors"] = "Fantozzi e LFA (OpenGameArt)"
        meta["durationSeconds"] = round(seconds, 3)
        meta["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        credits[key] = meta
        print(f"{key}: {seconds:.3f} s")
    credits_path.write_text(json.dumps(credits, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
