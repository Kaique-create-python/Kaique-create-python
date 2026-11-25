"""Gera um instalador único com arquivo ZIP verificado e arquivos de mídia aprováveis."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = r'''
import fcntl
import hashlib
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
    target = checked(storage / ("pacote-" + PACKAGE_SHA[:16]))
    if target.is_dir():
        return target
    print("Abrindo o pacote do CyberOutlaw…", flush=True)
    stage = Path(tempfile.mkdtemp(prefix="preparando-", dir=storage))
    try:
        with zipfile.ZipFile(sys.argv[0]) as package:
            infos = [row for row in package.infolist() if row.filename != "__main__.py"]
            if (len(infos) != len(FILE_HASHES) or {row.filename for row in infos} != FILE_HASHES.keys()
                    or sum(row.file_size for row in infos) > 48_000_000):
                raise ValueError("Pacote incompleto. Baixe o arquivo outra vez.")
            for row in infos:
                name = PurePosixPath(row.filename)
                if name.is_absolute() or ".." in name.parts or "\\" in row.filename or stat.S_ISLNK(row.external_attr >> 16):
                    raise ValueError("Caminho de pacote inválido.")
                dest = stage.joinpath(*name.parts)
                dest.parent.mkdir(mode=0o700, exist_ok=True, parents=True)
                digest = hashlib.sha256()
                with package.open(row) as source, dest.open("xb") as sink:
                    while block := source.read(128 * 1024):
                        digest.update(block)
                        sink.write(block)
                if digest.hexdigest() != FILE_HASHES[row.filename]:
                    raise ValueError("Arquivo danificado no pacote. Baixe outra vez.")
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
        print("CyberOutlaw · pacote pronto.", flush=True)
        sys.path.insert(0, str(folder))
        from launcher import main
        return main(sys.argv[1:] or ["verificar"], root=folder, storage=storage)


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except (ValueError, OSError, EOFError, KeyboardInterrupt, zipfile.BadZipFile) as error:
        print("Interrompido.", error, file=sys.stderr)
        raise SystemExit(1)
'''

def build(output):
    required = ["launcher.py", "src/menu.client.luau", "src/city.luau", "src/scene.luau", "src/hud.luau",
                "src/world.server.luau", "src/r6_guard.server.luau", "src/arsenal.server.luau", "src/life.server.luau", "src/life.client.luau", "src/play.client.luau",
                "media/ASSET_PLAN.json", "media/capri/capri_clips.json", "install/cyber_installer.py"]
    for item in required:
        if not (ROOT / item).is_file():
            raise ValueError("Falta parte do pacote: " + item)
    files = [ROOT / "launcher.py"]
    if (ROOT / "README.md").is_file():
        files.append(ROOT / "README.md")
    for folder in ("install", "media_tools", "src", "media/capri", "media/art"):
        files.extend(path for path in (ROOT / folder).rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts and path.suffix.lower()
                     in {".py", ".luau", ".json", ".png", ".wav", ".md", ".txt"})
    plan_path = ROOT / "media/ASSET_PLAN.json"
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    files.extend(ROOT / "media" / entry["path"] for entry in plan["assets"] if entry["assetType"] == "Audio")
    files.extend((plan_path, ROOT / "media/audio/CREDITOS.json"))
    for p in files:
        if p.is_symlink() or p.stat().st_size > 20_000_000:
            raise ValueError("Arquivo de pacote inválido: " + p.name)
    files = {path.relative_to(ROOT).as_posix(): path for path in sorted(set(files))}
    hashes = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()}
    package_sha = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode("utf-8")).hexdigest()
    main = f"PACKAGE_SHA = {package_sha!r}\nFILE_HASHES = {hashes!r}\n" + BOOTSTRAP
    compile(main, "__main__.py", "exec")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=7) as package:
        package.writestr(zipfile.ZipInfo("__main__.py"), main)
        for name, path in files.items():
            entry = zipfile.ZipInfo(name)
            entry.external_attr = 0o600 << 16
            package.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=7)
    print(f"Instalador: {output} · {output.stat().st_size:,} bytes · SHA-256 {hashlib.sha256(output.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    build(parser.parse_args().output)
