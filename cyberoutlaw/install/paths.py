"""Durable state in the device's private filesystem."""

from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import stat
import tempfile

from .codec import Failure, MAX_FILE
from .cloud import unique_fields


def guard(path):
    path = Path(path).absolute()
    if ".." in path.parts or any(parent.is_symlink() for parent in (path, *path.parents)):
        raise Failure(f"Caminho inesperado na pasta privada do instalador. {path}")
    return path


def read_place(path):
    with Path(path).open("rb") as stream:
        raw = stream.read(MAX_FILE + 1)
    if not 0 < len(raw) <= MAX_FILE:
        raise Failure("O arquivo do place está vazio ou acima do limite de tamanho.")
    return raw


def read_json(path):
    path = guard(path)
    try:
        with path.open(encoding="utf-8") as stream:
            raw = stream.read(2 * 1024 * 1024 + 1)
        if len(raw) > 2 * 1024 * 1024:
            raise Failure(f"O recibo local é maior que o esperado. {path.name}")
        result = json.loads(raw, object_pairs_hook=unique_fields)
    except FileNotFoundError:
        return None
    except (ValueError, RecursionError):
        raise Failure(f"O recibo local está inválido. {path.name}") from None
    if not isinstance(result, dict):
        raise Failure(f"O recibo local está inválido. {path.name}")
    return result


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


@contextmanager
def locked_state(path):
    path = guard(path)
    try:
        path.mkdir(mode=0o700)
    except FileExistsError:
        pass
    info = path.stat(follow_symlinks=False)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise Failure("A pasta do instalador deve ser privada e pertencer ao usuário do Termux.")
    if stat.S_IMODE(info.st_mode) != 0o700:
        path.chmod(0o700)
    sync_directory(path.parent)
    fd = os.open(path / "lock", os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Failure("Já há um instalador CyberOutlaw em execução neste aparelho.") from None
        yield path


def _stage(path, raw):
    fd, name = tempfile.mkstemp(prefix=".cyberoutlaw-", suffix=".tmp", dir=path.parent)
    temp = Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        temp.unlink()
        raise
    return temp


def _replace_file(path, raw):
    temp = _stage(path, raw)
    try:
        temp.replace(path)
        sync_directory(path.parent)
    finally:
        temp.unlink(missing_ok=True)
    return path


def write_once(path, raw):
    # The caller holds locked_state across the existence check and the rename.
    path = guard(path)
    if path.exists():
        if read_place(path) != raw:
            raise Failure(f"Já existe um arquivo diferente para essa versão. {path.name}")
        return path
    return _replace_file(path, raw)


def write_json(path, value, *, replace):
    path = guard(path)
    content = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()
    if not replace:
        return write_once(path, content)
    return _replace_file(path, content)


def remove(path):
    path = guard(path)
    path.unlink()
    sync_directory(path.parent)


def write_offline(path, raw):
    # Android's shared Downloads filesystem need not support hard links.
    path = Path(path).absolute()
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    identity = os.fstat(fd)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        try:
            partial = path.stat(follow_symlinks=False)
            if (partial.st_dev, partial.st_ino) == (identity.st_dev, identity.st_ino):
                path.unlink()
        except FileNotFoundError:
            pass
        raise
