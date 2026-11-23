"""Abre no Termux o pacote CyberOutlaw v3: armas reais, animação do catálogo em R6, HUD v4, Capri completa e música do menu."""

import hashlib
from http.client import HTTPException
import os
from pathlib import Path
import sys
import tempfile
from urllib.request import urlopen


RELEASE = "413eb23a0397a6bb7b1548fd3fb25fb6d611d9f3"
PACKAGE = "CYBEROUTLAW_TERMUX.pyz"
PACKAGE_BYTES = 27_098_456
PACKAGE_SHA256 = "10d2aabbbb69838a474a3d66c69d6a902775122e0720229a8f2551d066d2f1fb"
PACKAGE_URL = f"https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/{RELEASE}/cyberoutlaw/dist/{PACKAGE}"
BLOCK_SIZE = 128 * 1024


def is_release(path):
    if not path.is_file() or path.stat().st_size != PACKAGE_BYTES:
        return False
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while block := file.read(BLOCK_SIZE):
            digest.update(block)
    return digest.hexdigest() == PACKAGE_SHA256


def download_release(path):
    print("Baixando a atualização do CyberOutlaw…", flush=True)
    temporary = None
    digest = hashlib.sha256()
    size = 0
    progress = 25
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".cyberoutlaw-", delete=False) as file:
            temporary = Path(file.name)
            with urlopen(PACKAGE_URL, timeout=30) as response:
                while block := response.read(BLOCK_SIZE):
                    size += len(block)
                    if size > PACKAGE_BYTES:
                        raise ValueError("O pacote excedeu o tamanho da versão publicada.")
                    file.write(block)
                    digest.update(block)
                    if size * 100 >= progress * PACKAGE_BYTES:
                        print(f"CyberOutlaw · {progress}% baixado", flush=True)
                        progress += 25
        if size != PACKAGE_BYTES or digest.hexdigest() != PACKAGE_SHA256:
            raise ValueError("O pacote baixado não corresponde à versão publicada. Rode o comando novamente.")
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    folder = Path(__file__).resolve().parent
    if is_release(folder / PACKAGE):
        path = folder / PACKAGE
    else:
        path = folder / f"CYBEROUTLAW_HUD_{RELEASE[:7]}.pyz"
        if not is_release(path):
            download_release(path)
    commands = sys.argv[1:] or ["verificar"]
    os.execv(sys.executable, [sys.executable, "-u", str(path), *commands])


if __name__ == "__main__":
    try:
        main()
    except (OSError, HTTPException, ValueError) as error:
        print(f"CyberOutlaw · {error}", file=sys.stderr)
        raise SystemExit(1) from None
    except KeyboardInterrupt:
        raise SystemExit(130) from None
