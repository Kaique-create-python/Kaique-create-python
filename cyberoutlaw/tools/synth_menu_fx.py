"""Sinalização original para as reações visuais. Os cliques vêm do ElevenLabs."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "media" / "audio"
RATE = 44100

def emit(name, length, sound):
    samples = bytearray()
    for index in range(round(RATE * length)):
        t = index / RATE
        soften = min(1.0, t / 0.006, (length - t) / 0.035)
        y = sound(t, index) * max(0.0, soften)
        samples.extend(struct.pack("<h", round(32767 * max(-1, min(y, 1)))))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(samples)

_noise = random.Random(9917)
_steps = (0.20, 1.00, 0.15, 0.70, 0.25, 0.40, 0.08, 0.01, 0.00, 0.00)

def glitch(t, i):
    stepped = math.floor(i / 6) * (6 / RATE)
    phase = math.tau * (172 * stepped + 2100 * stepped**2)
    envelope = _steps[min(9, int(t / 0.035))]
    tail = .13 * math.sin(math.tau * 940 * t) * math.exp(-max(0.0, t - .137) * 27) if t >= .137 else 0
    return (0.24 * math.sin(phase) + 0.07 * _noise.uniform(-1, 1)) * envelope + tail

def react(t, _):
    if t < .091:
        delta, f = t, 680
    else:
        delta, f = t - .091, 1140
    return .29 * math.sin(math.tau * (f * delta - 315 * delta**2)) * math.exp(-delta * 22) * min(1, delta / .008)

if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    emit("glitch", .35, glitch)
    emit("react", .255, react)
