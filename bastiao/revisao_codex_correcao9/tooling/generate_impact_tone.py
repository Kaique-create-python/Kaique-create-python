"""Original DSP tinnitus, no external service, speech or third-party sample.

A short smooth, falling tone. Runtime applies a second severity envelope and a
0.20 sound gain; ffmpeg normalisation/limiting remains part of the release path.
"""
import math
from pathlib import Path
import struct
import wave


def generate(destination):
    rate, seconds = 44100, 5.6
    samples = bytearray()
    phase = 0.0
    for i in range(round(rate * seconds)):
        t = i / rate
        frequency = 1680 + 920 * math.exp(-t / 1.25)
        phase += 2 * math.pi * frequency / rate
        attack = min(1, t / 0.06)
        release = min(1, max(0, (seconds - t) / 0.7))
        envelope = attack * attack * (3 - 2 * attack) * release * release * (3 - 2 * release)
        amplitude = 0.10 * math.exp(-t / 6) * envelope
        value = amplitude * (0.85 * math.sin(phase) + 0.15 * math.sin(phase * 1.006))
        samples.extend(struct.pack('<h', round(max(-1,min(1,value)) * 32767)))
    path = Path(destination); path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate); output.writeframes(samples)
    return path


if __name__ == '__main__':
    print(generate(Path(__file__).resolve().parents[1] / 'audio/sources/impacto_zumbido_original.wav'))
