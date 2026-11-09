#!/usr/bin/env python3
"""Junta efeitos sonoros curtos num único arquivo de áudio ("sprite").

No Roblox cada envio de áudio conta no limite mensal da conta; com o sprite
basta UM envio. O jogo toca cada efeito pela região (Sound.PlaybackRegion).

Uso: python3 montar_sprite.py PASTA_MP3 SAIDA.ogg SAIDA.json nome:duracao_max ...
Requer ffmpeg/ffprobe.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

GAP = 0.3  # silêncio entre efeitos (s)
RATE = 44100


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def duration(path):
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)]).stdout
    return float(out.strip())


def peak_db(path):
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True).stderr
    for line in err.splitlines():
        if "max_volume:" in line:
            return float(line.split("max_volume:")[1].split("dB")[0])
    return 0.0


def main():
    src, out_audio, out_json = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    specs = [a.split(":") for a in sys.argv[4:]]
    tmp = Path(tempfile.mkdtemp())
    pieces, regions, t = [], {}, 0.0
    gap = tmp / "gap.wav"
    run(["ffmpeg", "-y", "-f", "lavfi", "-i", f"anullsrc=r={RATE}:cl=mono", "-t", str(GAP), str(gap)])
    for name, maxdur in specs:
        f = src / f"{name}.mp3"
        if not f.exists():
            print("faltando:", f)
            continue
        if peak_db(f) < -40:
            print("silencioso demais, ignorado:", name)
            continue
        clean = tmp / f"{name}.wav"
        trim = ("silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
                "silenceremove=start_periods=1:start_threshold=-45dB,areverse")
        run(["ffmpeg", "-y", "-i", str(f), "-ac", "1", "-ar", str(RATE), "-af", trim, "-t", maxdur, str(tmp / f"{name}_t.wav")])
        d = duration(tmp / f"{name}_t.wav")
        gain = -1.0 - peak_db(tmp / f"{name}_t.wav")
        fade = min(0.12, d / 4)
        run(["ffmpeg", "-y", "-i", str(tmp / f"{name}_t.wav"), "-af", f"volume={gain}dB,afade=t=out:st={max(d - fade, 0)}:d={fade}", str(clean)])
        d = duration(clean)
        regions[name] = [round(t, 3), round(t + d, 3)]
        pieces += [clean, gap]
        t += d + GAP
    lst = tmp / "lista.txt"
    lst.write_text("".join(f"file '{p}'\n" for p in pieces))
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c:a", "libvorbis", "-q:a", "5", str(out_audio)])
    out_json.write_text(json.dumps({"arquivo": out_audio.name, "duracao": round(t, 3), "regioes": regions}, indent=1, ensure_ascii=False))
    print(json.dumps(regions))


if __name__ == "__main__":
    main()
