"""Gera um instalador único com arquivo ZIP verificado e arquivos de mídia aprováveis."""
from pathlib import Path
import argparse
import base64
import hashlib
import io
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXTRACT = r'''
import base64
import fcntl
import hashlib
import io
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import sys
import tempfile
import zipfile


def checked(path):
    for piece in (path, *path.parents):
        if piece.is_symlink():
            raise ValueError("Caminho com link simbólico recusado: " + str(piece))
    return path


def extract(storage):
    archive = base64.b85decode(PAYLOAD)
    if hashlib.sha256(archive).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Arquivo do instalador incompleto. Baixe outra vez.")
    target = checked(storage / ("pacote-" + ARCHIVE_SHA[:16]))
    if target.is_dir():
        return target
    stage = Path(tempfile.mkdtemp(prefix="preparando-", dir=storage))
    try:
        with zipfile.ZipFile(io.BytesIO(archive)) as package:
            infos = package.infolist()
            if not infos or len(infos) > 140 or sum(row.file_size for row in infos) > 48_000_000:
                raise ValueError("Pacote acima do tamanho permitido.")
            seen = set()
            for row in infos:
                name = PurePosixPath(row.filename)
                if name.is_absolute() or ".." in name.parts or "\\" in row.filename or row.filename in seen or stat.S_ISLNK(row.external_attr >> 16):
                    raise ValueError("Caminho de pacote inválido.")
                seen.add(row.filename)
                dest = stage.joinpath(*name.parts)
                dest.parent.mkdir(mode=0o700, exist_ok=True, parents=True)
                with package.open(row) as source, dest.open("xb") as sink:
                    shutil.copyfileobj(source, sink)
                dest.chmod(0o600)
        stage.rename(target)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return target


def run():
    os.umask(0o077)
    storage = checked(Path.home() / ".cyberoutlaw-menu")
    storage.mkdir(mode=0o700, exist_ok=True)
    lock = checked(storage / "execucao.lock")
    with lock.open("a") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Já existe uma execução do instalador aberta.") from None
        folder = extract(storage)
        sys.path.insert(0, str(folder))
        from launcher import main
        return main(sys.argv[1:] or ["verificar"], root=folder, storage=storage)


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except (ValueError, OSError, EOFError, KeyboardInterrupt) as error:
        print("Interrompido.", error, file=sys.stderr)
        raise SystemExit(1)
'''

def build(output):
    required = ["launcher.py", "src/menu.client.luau", "src/city.luau", "src/scene.luau", "media/ASSET_PLAN.json", "media/capri/capri_clips.json", "install/cyber_installer.py"]
    for item in required:
        if not (ROOT / item).is_file():
            raise ValueError("Falta parte do pacote: " + item)
    files = [ROOT / "launcher.py"]
    if (ROOT / "README.md").is_file():
        files.append(ROOT / "README.md")
    for folder in ("install", "media_tools", "src", "media/audio", "media/capri", "media/art"):
        files.extend(path for path in (ROOT / folder).rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts and path.suffix.lower()
                     in {".py", ".luau", ".json", ".png", ".wav", ".md", ".txt"})
    files.append(ROOT / "media/ASSET_PLAN.json")
    for p in files:
        if p.is_symlink() or p.stat().st_size > 20_000_000:
            raise ValueError("Arquivo de pacote inválido: " + p.name)
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=7) as package:
        for path in sorted(set(files)):
            entry = zipfile.ZipInfo(path.relative_to(ROOT).as_posix())
            entry.external_attr = 0o600 << 16
            package.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=7)
    raw = archive.getvalue()
    pack = "#!/usr/bin/env python3\n"
    pack += "ARCHIVE_SHA = " + repr(hashlib.sha256(raw).hexdigest()) + "\n"
    encoded = base64.b85encode(raw).decode("ascii")
    pack += "PAYLOAD = (\n" + "\n".join(repr(encoded[i:i+120]) for i in range(0, len(encoded), 120)) + "\n)\n"
    pack += EXTRACT
    compile(pack, str(output), "exec")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(pack, encoding="utf-8")
    print(f"Instalador: {output} · {output.stat().st_size:,} bytes · SHA-256 {hashlib.sha256(output.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    build(parser.parse_args().output)
