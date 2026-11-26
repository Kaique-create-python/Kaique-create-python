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
from .patcher import CITY_SCRIPT, CLIENT_HEADER, SERVER_HEADER, menu_source, patch_place, place_format, same_binary_place, source_digest
from .chave import clean_key, fingerprint
from .paths import guard, locked_state, read_json, read_place, remove, write_json, write_offline, write_once
from media_tools.mare_art import ARCHIVED_ART, PBR_ART, material_maps, material_properties


CONFIG_MARKER = "__CYBEROUTLAW_CONFIG__"
CITY_MARKER = "-- __CYBEROUTLAW_CITY__"
SCENE_MARKER = "-- __CYBEROUTLAW_SCENE__"
HUD_MARKER = "-- __CYBEROUTLAW_HUD__"
ART_MARKER = "__CYBEROUTLAW_ART__"
MEDIA_MARKER = "__CYBEROUTLAW_MEDIA__"
MARE_MODULES_MARKER = "-- __CYBEROUTLAW_MARE_MODULES__"
MARE_MODULES = (
    ("Context", "context"), ("Layout", "layout"), ("Streets", "streets"), ("Transit", "transit"),
    ("PublicSpace", "public_space"), ("Buildings", "buildings"), ("Commerce", "commerce"),
)
# Server scripts installed in ServerScriptService, in this order.
SERVER_SCRIPTS = (
    ("CyberOutlawR6", "r6_guard.server.luau"),
    ("CyberOutlawCity", "world.server.luau"),
    ("CyberOutlawArsenal", "arsenal.server.luau"),
    ("CyberOutlawVida", "life.server.luau"),
)
# Poly Haven scans (CC0) shared with the menu. The city uses no generated images.
# Imagens que o script da cidade recebe: fotos CC0 e arte desenhada por código. As artes geradas do menu
# (billboard, facades) ficam fora da cidade jogável.
CITY_ART = ("asphalt", "asphalt_normal", "asphalt_rough", "concrete", "concrete_normal",
            "fachada_residencial", "fachada_escritorio", "fachada_vidro", "fachada_painel", "anuncios",
            "poca_1", "poca_2", "poca_3", "poca_4", "ceu_bk", "ceu_dn", "ceu_ft", "ceu_lf", "ceu_rt", "ceu_up",
            "tijolo", "tijolo_normal", "metal_ondulado", "metal_ondulado_normal", "piso_hexagonal", "piso_hexagonal_normal",
            "concreto_rachado", "concreto_rachado_normal", *PBR_ART)
CONFIRMATION = "PUBLICAR CYBEROUTLAW"
CLIENT_SCRIPTS = (("CyberOutlawPlay", "play.client.luau"), ("CyberOutlawVidaCliente", "life.client.luau"))
V1_ASSET_TYPES = {"video", "sounds", "clips"}
ASSET_TYPES = V1_ASSET_TYPES | {"art"}
ASSET_NAME = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}")
ASSET_LINE = re.compile(r"(?m)^local ASSETS = ([^\r\n]*)$")
SHA256 = re.compile(r"[0-9a-f]{64}")
# Commit ba81f89, with the v1 city embedded and the ASSETS marker left unbound.
V1_TEMPLATE_SHA256 = "e10acc19da074d939ef706812a9ac56260af271379e39f7193ad29247b7dcd0c"
V2_TEMPLATE_SHA256 = "2a63e2015b3118d75ccc77a114b5126ee8f9d40ae4426096b55d91e95cd4e05a"
V3_TEMPLATE_SHA256 = "72e38fc5fbb1b0486ed74bb41c230b95b179c2f18a3bba1583421bff52ae0ef0"
CAMERA_TEMPLATE_SHA256 = "0aef4b6f02298843c6116cd43cac22eae2d6ad035cbce6d470ed29b4e7b67c62"
# Commit 141e572: menu with HUD v1 and R6 avatar settings.
HUD_TEMPLATE_SHA256 = "07c374ea84796a775353015704c2b3c90a72effa6e36a3bba8e8ff83e4d661c6"
# Menu template in 3bcfa32 on ccr-b4068ef4-7ky9v8.
V121_TEMPLATE_SHA256 = "c0d8020bca9e73afe391c58111dd13452a463337882a4e602ff0b0df397bf2ad"


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
    return _normalize_config(data)


def _normalize_config(data):
    if not isinstance(data, dict) or data.keys() - ASSET_TYPES:
        raise Failure("O arquivo ASSETS.json contém campos desconhecidos.")

    config = {"video": _integer(data.get("video", 0), "video")}
    for field in ("sounds", "art"):
        config[field] = {
            name: _integer(value, f"{field}.{name}")
            for name, value in _entries(data.get(field, {}), field)
        }
    config["sounds"].pop("rain", None)
    for key in ARCHIVED_ART:
        config["art"].pop(key, None)
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
    fragments = ((CITY_MARKER, "city.luau"), (SCENE_MARKER, "scene.luau"), (HUD_MARKER, "hud.luau"))
    markers = (CONFIG_MARKER, *(tag for tag, _ in fragments))
    if any(menu.count(marker) != 1 for marker in markers):
        raise Failure("O script deve conter um marcador para configuração, cidade, cena e HUD.")
    positions = [menu.index(marker) for marker in markers]
    if positions != sorted(positions):
        raise Failure("Os marcadores devem seguir a ordem de configuração, cidade, cena e HUD.")
    slot = ASSET_LINE.search(menu)
    if slot is None or slot[1] != CONFIG_MARKER:
        raise Failure("O marcador de mídia deve definir local ASSETS em sua própria linha.")
    for marker, filename in fragments:
        fragment = (root / "src" / filename).read_text(encoding="utf-8-sig")
        if not fragment.strip() or any(tag in fragment for tag in markers):
            raise Failure(f"O código em {filename} está vazio ou contém marcadores do menu.")
        fragment = fragment.rstrip("\n")
        if marker == SCENE_MARKER:
            fragment = f"local openCyberOutlawScene = (function()\n{fragment}\nreturn openCyberOutlawScene\nend)()"
        menu = menu.replace(marker, fragment)
    config = load_config(root / "config" / "ASSETS.json")
    return menu.replace(CONFIG_MARKER, _luau(config)), config


def _bind_mare_modules(root, code):
    if code.count(MARE_MODULES_MARKER) != 1:
        raise Failure("O script da cidade precisa de um marcador de módulos.")
    fragments = ["local Mare = {}"]
    for name, file in MARE_MODULES:
        module = (root / "src" / "mare-baixa" / f"{file}.luau").read_text(encoding="utf-8-sig")
        if not module.strip() or MARE_MODULES_MARKER in module or ART_MARKER in module:
            raise Failure(f"Módulo de Maré Baixa vazio ou com marcador inválido. {file}")
        fragments.append(f"Mare.{name} = (function()\n{module.rstrip()}\nend)()")
    return code.replace(MARE_MODULES_MARKER, "\n".join(fragments), 1)


def server_from_package(root, config):
    """Build each managed server script, binding the city to the approved texture IDs."""
    art = {name: config["art"][name] for name in CITY_ART if config["art"].get(name)}
    maps = material_maps(art)
    if maps:
        art["mare_tints"] = {material: int(bool(ids["color"])) for material, ids in maps.items()}
    scripts = {}
    for name, filename in SERVER_SCRIPTS:
        code = (root / "src" / filename).read_text(encoding="utf-8-sig")
        if not code.strip() or SERVER_HEADER in code or code.count(ART_MARKER) > 1:
            raise Failure(f"O código em {filename} está vazio ou tem marcadores repetidos.")
        if ART_MARKER in code:
            if not re.search(r"(?m)^local ART = " + ART_MARKER + r"$", code):
                raise Failure(f"O marcador de arte em {filename} deve definir local ART em sua própria linha.")
            code = code.replace(ART_MARKER, _luau(art), 1)
        if filename == "world.server.luau":
            code = _bind_mare_modules(root, code)
        scripts[name] = f"{SERVER_HEADER}{name}\n{code}"
    # Client scripts (StarterPlayerScripts) receive the approved icons and sounds.
    media = {
        "icones": config["art"].get("icones_interface") or 0,
        "sons": {key: asset for key, asset in config["sounds"].items() if asset},
    }
    for name, filename in CLIENT_SCRIPTS:
        code = (root / "src" / filename).read_text(encoding="utf-8-sig")
        if (not code.strip() or SERVER_HEADER in code or CLIENT_HEADER in code or code.count(MEDIA_MARKER) != 1
                or not re.search(r"(?m)^local MEDIA = " + MEDIA_MARKER + r"$", code)):
            raise Failure(f"O código em {filename} está vazio ou sem o marcador de mídia.")
        scripts[name] = f"{CLIENT_HEADER}{name}\n" + code.replace(MEDIA_MARKER, _luau(media), 1)
    return scripts


def _place_content(builder, source):
    if builder is None:
        return {}
    parts = _split_assets(source)
    config = _asset_table(parts[1], None) if parts else None
    config = config if config is not None else _normalize_config({})
    scripts = builder(config)
    materials = material_properties(config["art"]) if CITY_SCRIPT in scripts else {}
    return {"server": scripts, "materials": materials}


class _AssetLiteral:
    """Parse only the deterministic tables and numbers emitted by _luau."""

    KEY = re.compile(r'\["([A-Za-z0-9_][A-Za-z0-9_.-]{0,63})"\] = ')
    NUMBER = re.compile(r"(?:0|[1-9][0-9]{0,15})(?:\.[0-9]{1,17})?(?:e[+-][0-9]{2,3})?")

    def __init__(self, text):
        self.text = text
        self.position = 0

    def take(self, token):
        if not self.text.startswith(token, self.position):
            return False
        self.position += len(token)
        return True

    def value(self, depth=0):
        if depth >= 8:
            raise ValueError("table nesting")
        if not self.take("{"):
            match = self.NUMBER.match(self.text, self.position)
            if match is None:
                raise ValueError("number expected")
            self.position = match.end()
            token = match[0]
            return float(token) if "." in token or "e" in token else int(token)
        if self.take("}"):
            return {}
        keyed = self.text.startswith("[", self.position)
        values = {} if keyed else []
        while True:
            if keyed:
                key = self.KEY.match(self.text, self.position)
                if key is None or key[1] in values:
                    raise ValueError("invalid key")
                self.position = key.end()
                values[key[1]] = self.value(depth + 1)
            else:
                values.append(self.value(depth + 1))
            if self.take("}"):
                return values
            if not self.take(", "):
                raise ValueError("separator expected")


def _asset_table(literal, required):
    if len(literal) > 2 * 1024 * 1024:
        return None
    parser = _AssetLiteral(literal)
    try:
        raw = parser.value()
        if not isinstance(raw, dict) or (required is not None and raw.keys() != required):
            return None
        if parser.position != len(literal) or _luau(raw) != literal:
            return None
        return _normalize_config(raw)
    except (Failure, ValueError):
        return None


def _split_assets(source):
    first = ASSET_LINE.search(source)
    if first is None or ASSET_LINE.search(source, first.end()) is not None:
        return None
    start, end = first.span(1)
    return source[:start] + CONFIG_MARKER + source[end:], first[1]


def _merge_assets(older, newer):
    return {
        "video": newer["video"] or older["video"],
        "clips": dict(older["clips"], **newer["clips"]),
        **{
            field: {
                **older[field],
                **{name: value for name, value in newer[field].items() if value or name not in older[field]},
            }
            for field in ("sounds", "art")
        },
    }


def _prepare_update(raw, source, known=frozenset(), published_raw=None, *, force_r6=False, server=None):
    target = _split_assets(source)
    if target is None:
        ready, changed = patch_place(raw, source, known, force_r6=force_r6, **_place_content(server, source))
        return ready, changed, source
    template, literal = target
    target_config = _asset_table(literal, ASSET_TYPES)
    if target_config is None:
        raise Failure("O menu preparado contém uma tabela de mídia inválida.")
    template_sha = source_digest(template)
    allowed = set(known)
    recovered = _normalize_config({})
    live = None
    if published_raw is not None and published_raw is not raw:
        try:
            live = menu_source(published_raw)
        except Failure:
            pass  # An older publication's menu is optional for recovering media.
    for old in (live, menu_source(raw)):
        if not old:
            continue
        parts = _split_assets(old)
        if parts is None:
            continue
        old_template_sha = source_digest(parts[0])
        old_sha = source_digest(old)
        if old_template_sha == V1_TEMPLATE_SHA256:
            required = V1_ASSET_TYPES
        elif old_template_sha in (V2_TEMPLATE_SHA256, V3_TEMPLATE_SHA256, CAMERA_TEMPLATE_SHA256, HUD_TEMPLATE_SHA256, V121_TEMPLATE_SHA256,
                                  template_sha):
            required = ASSET_TYPES
        elif old_sha in known:
            required = None
        else:
            continue
        old_assets = _asset_table(parts[1], required)
        if old_assets is not None:
            allowed.add(old_sha)
            recovered = _merge_assets(recovered, old_assets)
    source = template.replace(CONFIG_MARKER, _luau(_merge_assets(recovered, target_config)), 1)
    ready, changed = patch_place(raw, source, allowed, force_r6=force_r6, **_place_content(server, source))
    return ready, changed, source


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
    def __init__(self, state, *, report=print, sleeper=time.sleep, force_r6=False, server=None):
        self.state = state
        self.active = state / "active-write.json"
        self.report = report
        self.sleep = sleeper
        self.force_r6 = force_r6
        self.server = server

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
        ready, changed, effective = _prepare_update(
            base_raw, source, self._known_sources(), live_raw, force_r6=self.force_r6, server=self.server
        )
        if effective != source:
            self.report("A atualização reutiliza IDs de mídia do menu já instalado.")
        source = effective
        content = _place_content(self.server, source)
        if patch_place(ready, source, force_r6=self.force_r6, **content) != (ready, False):
            raise Failure("A segunda aplicação alterou o arquivo preparado.")
        server = content.get("server", {})
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
            "server_sha256": {name: source_digest(code) for name, code in sorted(server.items())},
            "ready_sha256": ready_sha,
            "bytes": len(ready),
            "backups": [live] if published == latest else [live, base],
        }
        self.report(f"Backup da publicação em {self.state / live['file']}")
        if latest != published:
            self.report(f"Backup da gravação mais recente em {self.state / base['file']}")
            self.report(f"A publicação incluirá as alterações já gravadas na versão {latest}.")
        self.report(f"Place preparado em {ready_path}")
        if self.force_r6:
            self.report("HUD de jogo com retrato e mira central. Configuração de avatar do Place em R6.")
        for name in sorted(server):
            self.report(f"Script de servidor {name} em ServerScriptService.")
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
                downloaded_sha = digest(downloaded)
                comparison = "bytes"
                if downloaded_sha != entry["ready_sha256"]:
                    if not same_binary_place(raw, downloaded):
                        continue
                    comparison = "binary_chunks"
                if _current(cloud.history()) != head:
                    break
                receipt = self._finish(
                    entry, "VERIFIED", version=version, current_published=head[1], current_latest=head[0],
                    comparison=comparison, download_sha256=downloaded_sha,
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
            key = getpass.getpass("Chave Roblox Open Cloud (entrada oculta). ")
            key, notes = clean_key(key)
    except (EOFError, getpass.GetPassWarning):
        raise Failure("Use o terminal interativo do Termux para digitar a chave com entrada oculta.") from None
    if not key or not key.isascii() or not key.isprintable() or any(char.isspace() for char in key):
        raise Failure("A chave Roblox Open Cloud está vazia ou tem caracteres inválidos.")
    for note in notes:
        print("Chave: " + note + ".")
    print("Chave lida: " + fingerprint(key) + ". Compare com a que você copiou do site.")
    return key


def _info(source, config, server=None):
    clips = len(config["clips"])
    sounds = sum(asset > 0 for asset in config["sounds"].values())
    art = sum(asset > 0 for asset in config["art"].values())
    video = "ID configurado" if config["video"] else "sequência de abertura local"
    print(f"Código do menu, cena 3D e HUD preparados. SHA-256 {source_digest(source)}")
    print(f"Abertura com {video} · {clips} clipes, {sounds} sons e {art} imagens com IDs no pacote.")
    for name, code in sorted((server or {}).items()):
        print(f"Servidor · {name} preparado. SHA-256 {source_digest(code)}")


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
        def server(config):
            return server_from_package(root, config)

        if args.command != "resume":
            source, config = source_from_package(root)
            _info(source, config, server(config))
        if args.command == "verificar":
            return 0
        if args.command == "preparar-offline":
            raw = read_place(args.original.expanduser())
            ready, _, source = _prepare_update(raw, source, force_r6=True, server=server)
            if patch_place(ready, source, force_r6=True, **_place_content(server, source)) != (ready, False):
                raise Failure("A segunda aplicação alterou o arquivo preparado.")
            write_offline(args.destino.expanduser(), ready)
            print(f"Place preparado em {args.destino}. SHA-256 {digest(ready)}")
            return 0
        with locked_state(Path.home() / ".cyberoutlaw-installer") as state:
            installer = Installer(state, force_r6=True, server=server)
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
