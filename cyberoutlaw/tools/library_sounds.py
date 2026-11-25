"""Busca e mede sons da biblioteca licenciada do Roblox (Roblox, ProSoundEffects, APM).

O catálogo licenciado é público para qualquer jogo (post da equipe do Roblox sobre privacidade de áudio, 2022):
o jogo usa os IDs direto, sem reenviar nada. Este script só baixa para medir (duração, pico, RMS dos 50 ms
mais altos, brilho e grave) e escolher o volume de cada som; os arquivos ficam na pasta temporária.

  python tools/library_sounds.py buscar PSE "telephone ring" "body hit"
  python tools/library_sounds.py medir 17208308857 9116343569
"""
import gzip
import json
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np

CREATORS = {"PSE": 7462895450, "APM": 7462718749, "RBX": 1}
TOOLBOX = "https://apis.roblox.com/toolbox-service/v1"
RATE = 48000


def _get(url, raw=False):
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read() if raw else json.load(response)
        except OSError:
            time.sleep(1.5 * (attempt + 1))
    return b"" if raw else {}


def search(creator, keyword, num=30):
    query = urllib.parse.urlencode({"keyword": keyword, "num": num, "creatorTargetId": CREATORS[creator]})
    ids = [row["id"] for row in _get(f"{TOOLBOX}/marketplace/3?{query}").get("data", [])]
    rows = _get(f"{TOOLBOX}/items/details?assetIds=" + ",".join(map(str, ids))).get("data", []) if ids else []
    return [(row["asset"]["id"], row["asset"]["name"], (row["asset"].get("description") or "").split("\n")[0]) for row in rows]


def download(asset, folder):
    target = Path(folder) / f"{asset}.ogg"
    if not target.exists():
        location = _get(f"https://assetdelivery.roblox.com/v2/assetId/{asset}")["locations"][0]["location"]
        data = _get(location, raw=True)
        target.write_bytes(gzip.decompress(data) if data[:2] == b"\x1f\x8b" else data)
    return target


def measure(path):
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(pcm, "<i2").astype(float) / 32768
    window = int(0.05 * RATE)
    rms = np.sqrt(np.convolve(x * x, np.ones(window) / window, mode="valid").max()) + 1e-9
    spectrum, freqs = np.abs(np.fft.rfft(x)), np.fft.rfftfreq(len(x), 1 / RATE)
    return {"segundos": round(len(x) / RATE, 2), "pico_db": round(20 * np.log10(np.abs(x).max() + 1e-9), 1),
            "rms50_db": round(20 * np.log10(rms), 1), "centro_hz": int((spectrum * freqs).sum() / spectrum.sum()),
            "grave_pct": int(100 * spectrum[freqs < 150].sum() / spectrum.sum())}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    if sys.argv[1] == "buscar":
        for keyword in sys.argv[3:]:
            print(f"== {sys.argv[2]} '{keyword}'")
            for asset, name, first in search(sys.argv[2], keyword)[:10]:
                print(f"  {asset}  {name[:50]}  |  {first[:60]}")
    else:
        with tempfile.TemporaryDirectory() as folder:
            for asset in sys.argv[2:]:
                print(asset, measure(download(int(asset), folder)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
