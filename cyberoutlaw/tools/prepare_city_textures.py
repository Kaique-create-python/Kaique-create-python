"""Baixa e prepara as texturas de foto (Poly Haven, CC0) da cidade jogável de Maré Baixa.

Cada material traz cor e relevo (normal map no padrão OpenGL, o que o Roblox usa). As cores são
escurecidas e dessaturadas para receber a luz de néon da noite. Os arquivos de origem são conferidos
pelo SHA-256 registrado em CREDITOS.md depois da primeira preparação.
Uso: python tools/prepare_city_textures.py [pasta de cache]
"""
from pathlib import Path
import hashlib
import io
import json
import sys
import urllib.request

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
API = "https://api.polyhaven.com/files/"
# chave no jogo: (asset Poly Haven, brilho, saturação)
MATERIALS = {
    "tijolo": ("dark_brick_wall", 0.82, 0.7),
    "metal_ondulado": ("corrugated_iron_02", 0.8, 0.5),
    "piso_hexagonal": ("hexagonal_concrete_paving", 0.78, 0.55),
    "concreto_rachado": ("cracked_concrete", 0.8, 0.5),
}


HEADERS = {"User-Agent": "mare-baixa-texturas/1.0"}


def get(url, timeout=120):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=timeout) as response:
        return response.read()


def fetch(url, cache):
    target = cache / url.rsplit("/", 1)[-1]
    if not target.exists():
        target.write_bytes(get(url))
    return target.read_bytes()


def grade(image, brightness, saturation):
    arr = np.asarray(image.convert("RGB"), float)
    gray = arr.mean(axis=2, keepdims=True)
    arr = gray + (arr - gray) * saturation
    return Image.fromarray(np.clip(arr * brightness, 0, 255).astype("uint8"))


def main():
    cache = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".cache" / "polyhaven"
    cache.mkdir(parents=True, exist_ok=True)
    out = ROOT / "media" / "art"
    report = {}
    for key, (asset, brightness, saturation) in MATERIALS.items():
        files = json.loads(get(API + asset, timeout=60))
        color = fetch(files["Diffuse"]["1k"]["png"]["url"], cache)
        normal = fetch(files["nor_gl"]["1k"]["png"]["url"], cache)
        report[key] = {"asset": asset, "diffuse_sha256": hashlib.sha256(color).hexdigest(),
                       "normal_sha256": hashlib.sha256(normal).hexdigest()}
        grade(Image.open(io.BytesIO(color)), brightness, saturation).resize((768, 768), Image.LANCZOS).save(out / f"{key}.png", optimize=True)
        Image.open(io.BytesIO(normal)).convert("RGB").resize((512, 512), Image.LANCZOS).save(out / f"{key}_normal.png", optimize=True)
        print(key, asset, (out / f"{key}.png").stat().st_size, (out / f"{key}_normal.png").stat().st_size)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
