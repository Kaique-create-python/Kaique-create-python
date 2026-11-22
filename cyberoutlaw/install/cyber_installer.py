"""Prepare and install CyberOutlaw on its existing Roblox place from Termux."""

import argparse
from datetime import datetime, timezone
import getpass
from hashlib import sha256
import json
import math
from pathlib import Path
import re
import sys
import time
from uuid import uuid4
import warnings

# The standalone verification command should also leave no bytecode behind.
sys.dont_write_bytecode = True
if not __package__:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "install"

from .cloud import Cloud, DEFINITE_REJECTIONS, PLACE_ID, TARGET, UNIVERSE_ID, unique_fields
from .codec import Failure
from .patcher import menu_source, patch_place, place_format, source_digest
from .paths import guard, locked_state, read_json, read_place, remove, write_json, write_offline, write_once


CONFIG_MARKER = "__CYBEROUTLAW_CONFIG__"
CITY_MARKER = "-- __CYBEROUTLAW_CITY__"
CONFIRMATION = "PUBLICAR CYBEROUTLAW"
ASSET_TYPES = {"video", "sounds", "clips"}
ASSET_NAME = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}")
SHA256 = re.compile(r"[0-9a-f]{64}")


def digest(raw):
    return sha256(raw).hexdigest()


def timestamp():
    return datetime.now(timezone.utc).isoformat()


def _integer(value, field, low=0, high=2**53 - 1):
    if type(value) is not int or not low <= value <= high:
        raise Failure(f"Valor inteiro inválido em ASSETS.json. {field}")
    return value


def _entries(value, field):
    if not isinstance(value, dict) or any(not ASSET_NAME.fullmatch(name) for name in value):
        raise Failure(f"Lista de nomes inválida em ASSETS.json. {field}")
    return value.items()


def load_config(path):
    try:
        with path.open(encoding="utf-8-sig") as stream:
            raw = stream.read(2 * 1024 * 1024 + 1)
        if len(raw) > 2 * 1024 * 1024:
            raise Failure("ASSETS.json excede o tamanho esperado.")
        data = json.loads(raw, object_pairs_hook=unique_fields)
    except FileNotFoundError:
        data = {}
    except (ValueError, RecursionError):
        raise Failure("O arquivo ASSETS.json está inválido.") from None
    if not isinstance(data, dict) or data.keys() - ASSET_TYPES:
        raise Failure("O arquivo ASSETS.json contém campos desconhecidos.")

    config = {"video": _integer(data.get("video", 0), "video")}
    config["sounds"] = {
        name: _integer(value, f"sounds.{name}")
        for name, value in _entries(data.get("sounds", {}), "sounds")
    }
    clips = {}
    for name, clip in _entries(data.get("clips", {}), "clips"):
        field = f"clips.{name}"
        if not isinstance(clip, dict) or set(clip) != {"fps", "frames"}:
            raise Failure(f"O clipe em ASSETS.json precisa de fps e frames. {field}")
        fps = clip["fps"]
        if type(fps) not in (int, float) or not 0 < fps <= 120 or not math.isfinite(fps):
            raise Failure(f"Taxa de quadros inválida em ASSETS.json. {field}")
        if not isinstance(clip["frames"], list) or not clip["frames"]:
            raise Failure(f"O clipe precisa de ao menos um quadro. {field}")
        frames = []
        for frame in clip["frames"]:
            if not isinstance(frame, dict) or set(frame) != {"id", "x", "y", "w", "h"}:
                raise Failure(f"Quadro incompleto em ASSETS.json. {field}")
            frames.append({
                "id": _integer(frame["id"], f"{field}.id", low=1),
                **{
                    axis: _integer(frame[axis], f"{field}.{axis}", low=int(axis in ("w", "h")), high=2**31 - 1)
                    for axis in ("x", "y", "w", "h")
                },
            })
        clips[name] = {"fps": fps, "frames": frames}
    config["clips"] = clips
    return config


def _luau(value):
    if isinstance(value, dict):
        return "{" + ", ".join(
            f"[{json.dumps(key)}] = {_luau(item)}" for key, item in sorted(value.items())
        ) + "}"
    if isinstance(value, list):
        return "{" + ", ".join(_luau(item) for item in value) + "}"
    return repr(value)


def source_from_package(root):
    menu = (root / "src" / "menu.client.luau").read_text(encoding="utf-8-sig")
    city = (root / "src" / "city.luau").read_text(encoding="utf-8-sig")
    if menu.count(CONFIG_MARKER) != 1 or menu.count(CITY_MARKER) != 1:
        raise Failure("Os marcadores de configuração e cidade devem aparecer uma vez no script do menu.")
    if not city.strip() or CONFIG_MARKER in city or CITY_MARKER in city:
        raise Failure("O código da cidade está vazio ou contém marcadores do menu.")
    config = load_config(root / "config" / "ASSETS.json")
    source = menu.replace(CONFIG_MARKER, _luau(config)).replace(CITY_MARKER, city.rstrip("\n"))
    return source, config


def _current(rows):
    published = next((row.number for row in rows if row.published), None)
    if not rows or published is None:
        raise Failure("A API não confirmou uma versão publicada para guardar como backup.")
    return rows[0].number, published


def _first_possible_published_version(entry):
    latest = entry["latest"]
    if entry["published"] < latest and entry["base_sha256"] == entry["ready_sha256"]:
        return latest
    return latest + 1


class Installer:
    def __init__(self, state, *, report=print, sleeper=time.sleep):
        self.state = state
        self.active = state / "active-write.json"
        self.report = report
        self.sleep = sleeper

    def pending(self):
        return read_json(self.active)

    def _candidate(self, entry):
        if (
            not isinstance(entry, dict) or entry.get("target") != TARGET
            or not re.fullmatch(r"[0-9a-f]{32}", str(entry.get("intent", "")))
            or entry.get("format") not in ("rbxl", "rbxlx")
            or not SHA256.fullmatch(str(entry.get("ready_sha256", "")))
            or not SHA256.fullmatch(str(entry.get("source_sha256", "")))
            or type(entry.get("bytes")) is not int
        ):
            raise Failure("Recibo do CyberOutlaw inválido. Preserve o arquivo para revisão.")
        name = f"candidate-{entry['ready_sha256']}.{entry['format']}"
        raw = read_place(guard(self.state / name))
        if len(raw) != entry["bytes"] or digest(raw) != entry["ready_sha256"]:
            raise Failure("O arquivo preparado do CyberOutlaw foi alterado.")
        return raw

    def _known_sources(self):
        known = set()
        for path in self.state.glob("receipt-*.json"):
            try:
                receipt = read_json(path)
                if not receipt or receipt.get("status") != "VERIFIED":
                    continue
                entry = receipt.get("request")
                source = menu_source(self._candidate(entry))
                if source and source_digest(source) == entry["source_sha256"]:
                    known.add(entry["source_sha256"])
            except (Failure, OSError):
                continue
        return known

    def _backup(self, cloud, version):
        raw = cloud.download(version)
        format_name = place_format(raw)
        name = f"backup-v{version}.{format_name}"
        write_once(self.state / name, raw)
        return raw, {"version": version, "file": name, "sha256": digest(raw), "bytes": len(raw)}

    def _receipt_path(self, entry):
        return self.state / f"receipt-{entry['intent']}.json"

    def _finish(self, entry, status, **details):
        if self.pending() != entry:
            raise Failure("O recibo pendente mudou durante a verificação.")
        path = self._receipt_path(entry)
        receipt = read_json(path)
        if receipt is None:
            receipt = {"status": status, "request": entry, "checked_at": timestamp(), **details}
            write_json(path, receipt, replace=False)
        elif receipt.get("request") != entry or receipt.get("status") != status:
            raise Failure("Já existe um recibo final diferente. Preserve os arquivos para revisão.")
        remove(self.active)
        return path

    def install(self, cloud, source, confirm=input):
        if self.pending() is not None:
            raise Failure("Há uma publicação pendente. Execute resume para consultar o resultado.")
        cloud.validate_destination()
        latest, published = _current(cloud.history())
        self.report(f"Place {PLACE_ID} · universo {UNIVERSE_ID}")
        self.report(f"Baixando a versão publicada {published} e conferindo a versão mais recente {latest}.")
        live_raw, live = self._backup(cloud, published)
        base_raw, base = (live_raw, live) if published == latest else self._backup(cloud, latest)
        ready, changed = patch_place(base_raw, source, self._known_sources())
        if patch_place(ready, source) != (ready, False):
            raise Failure("A segunda aplicação alterou o arquivo preparado.")
        if not changed and latest == published:
            if _current(cloud.history()) != (latest, published):
                raise Failure("O place mudou durante a conferência. Execute instalar novamente.")
            self.report(f"CyberOutlaw já está publicado na versão {published}. Backup em {self.state / live['file']}")
            return
        ready_sha = digest(ready)
        format_name = base["file"].rsplit(".", 1)[-1]
        ready_path = write_once(self.state / f"candidate-{ready_sha}.{format_name}", ready)
        entry = {
            "target": dict(TARGET),
            "intent": uuid4().hex,
            "started_at": timestamp(),
            "latest": latest,
            "published": published,
            "base_sha256": base["sha256"],
            "format": format_name,
            "source_sha256": source_digest(source),
            "ready_sha256": ready_sha,
            "bytes": len(ready),
            "backups": [live] if published == latest else [live, base],
        }
        self.report(f"Backup da publicação em {self.state / live['file']}")
        if latest != published:
            self.report(f"Backup da gravação mais recente em {self.state / base['file']}")
            self.report(f"A publicação incluirá as alterações já gravadas na versão {latest}.")
        self.report(f"Place preparado em {ready_path}")
        self.report(f"SHA-256 {ready_sha}")
        self.report("Pause outras gravações neste place até o fim da publicação.")
        if confirm(f"Para publicar neste place, digite {CONFIRMATION} e pressione Enter. ").strip() != CONFIRMATION:
            raise Failure("Publicação cancelada.")

        for backup in entry["backups"]:
            if digest(read_place(guard(self.state / backup["file"]))) != backup["sha256"]:
                raise Failure("Um dos backups foi alterado durante a revisão.")
        if self._candidate(entry) != ready:
            raise Failure("O arquivo preparado mudou durante a revisão.")
        cloud.validate_destination()
        if _current(cloud.history()) != (latest, published):
            raise Failure("O place mudou durante a revisão. Execute instalar para preparar a nova versão.")
        write_json(self.active, entry, replace=False)
        self.report("Enviando a publicação ao Roblox.")
        try:
            accepted = cloud.publish(ready)
        except KeyboardInterrupt:
            raise Failure("O envio foi interrompido. Execute resume para conferir o resultado.") from None
        except Failure as exc:
            if exc.code in DEFINITE_REJECTIONS:
                self._finish(entry, "REJECTED", http_status=exc.code)
                raise
            self.report("O envio terminou sem resposta conclusiva. Conferindo o histórico do Roblox.")
        else:
            if type(accepted) is int and accepted >= _first_possible_published_version(entry):
                entry["response_version"] = accepted
                write_json(self.active, entry, replace=True)
        return self.resume(cloud, attempts=3)

    def resume(self, cloud, attempts=1):
        entry = self.pending()
        if entry is None:
            self.report("Não há publicação pendente do CyberOutlaw neste aparelho.")
            return
        raw = self._candidate(entry)
        latest, published = entry.get("latest"), entry.get("published")
        response_version = entry.get("response_version")
        if (
            type(latest) is not int or type(published) is not int or not 0 < published <= latest
            or (response_version is not None and (type(response_version) is not int or response_version < latest))
        ):
            raise Failure("O recibo tem versões inválidas. Preserve o arquivo para revisão.")
        source = menu_source(raw)
        if not source or source_digest(source) != entry["source_sha256"]:
            raise Failure("O código do arquivo preparado divergiu do recibo.")
        if not SHA256.fullmatch(str(entry.get("base_sha256", ""))):
            raise Failure("O recibo não identifica o arquivo de referência.")
        minimum = _first_possible_published_version(entry)
        cloud.validate_destination()
        for attempt in range(attempts):
            rows = cloud.history()
            head = _current(rows)
            candidates = [
                row.number for row in rows if row.published and row.number >= minimum
                and (response_version is None or row.number == response_version)
            ][:8]
            for version in candidates:
                downloaded = cloud.download(version)
                if len(downloaded) != len(raw) or digest(downloaded) != entry["ready_sha256"]:
                    continue
                if _current(cloud.history()) != head:
                    break
                receipt = self._finish(
                    entry, "VERIFIED", version=version, current_published=head[1], current_latest=head[0],
                )
                if head[1] != version:
                    raise Failure(
                        f"Versão {version} verificada. A publicação atual é a versão {head[1]}. "
                        f"Recibo em {receipt}"
                    )
                self.report(f"CyberOutlaw publicado e verificado na versão {version}. Recibo em {receipt}")
                return
            if attempt + 1 < attempts:
                self.sleep(2)
        observed = f"O Roblox mostra a versão publicada {head[1]} e a versão mais recente {head[0]}."
        raise Failure(f"{observed} O arquivo enviado ainda está pendente de verificação. Execute resume.")


def _hidden_key():
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            key = getpass.getpass("Chave Roblox Open Cloud (entrada oculta). ").strip()
    except (EOFError, getpass.GetPassWarning):
        raise Failure("Use o terminal interativo do Termux para digitar a chave com entrada oculta.") from None
    if not key or not key.isascii() or not key.isprintable() or any(char.isspace() for char in key):
        raise Failure("A chave Roblox Open Cloud está vazia ou tem caracteres inválidos.")
    return key


def _info(source, config):
    clips = len(config["clips"])
    sounds = sum(asset > 0 for asset in config["sounds"].values())
    video = "ID configurado" if config["video"] else "sequência de abertura local"
    print(f"Código do menu e cidade 3D preparados. SHA-256 {source_digest(source)}")
    print(f"Abertura com {video} · {clips} clipes e {sounds} sons com IDs no pacote.")


def main(argv=None, root=None):
    parser = argparse.ArgumentParser(description="Instalador CyberOutlaw para o place existente no Roblox.")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("verificar", help="conferir o código e ASSETS.json localmente")
    offline = commands.add_parser("preparar-offline", help="gerar uma cópia editada de um place local")
    offline.add_argument("original", type=Path)
    offline.add_argument("destino", type=Path)
    commands.add_parser("instalar", help="preparar, revisar e publicar no Roblox")
    commands.add_parser("resume", help="verificar uma publicação pendente no Roblox")
    args = parser.parse_args(argv)
    root = Path(root) if root is not None else Path(__file__).resolve().parents[1]
    try:
        if args.command != "resume":
            source, config = source_from_package(root)
            _info(source, config)
        if args.command == "verificar":
            return 0
        if args.command == "preparar-offline":
            raw = read_place(args.original.expanduser())
            ready, _ = patch_place(raw, source)
            if patch_place(ready, source) != (ready, False):
                raise Failure("A segunda aplicação alterou o arquivo preparado.")
            write_offline(args.destino.expanduser(), ready)
            print(f"Place preparado em {args.destino}. SHA-256 {digest(ready)}")
            return 0
        with locked_state(Path.home() / ".cyberoutlaw-installer") as state:
            installer = Installer(state)
            pending = installer.pending()
            if args.command == "instalar" and pending is not None:
                raise Failure("Há uma publicação pendente. Execute resume para consultar o resultado.")
            if args.command == "resume" and pending is None:
                installer.resume(None)
                return 0
            cloud = Cloud(_hidden_key())
            try:
                if args.command == "instalar":
                    installer.install(cloud, source)
                else:
                    installer.resume(cloud)
            finally:
                cloud.key = ""
        return 0
    except (Failure, OSError, ValueError) as exc:
        print(f"CyberOutlaw | {exc}", file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt):
        print("CyberOutlaw | Operação interrompida.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
