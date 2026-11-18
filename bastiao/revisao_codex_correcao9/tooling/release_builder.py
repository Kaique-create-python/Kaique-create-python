"""Build ETAPA 3 only from reviewed sources and approved, hash-bound asset receipts.

Importing and verifying this module never contacts Roblox or ElevenLabs. No ID is
guessed. Existing Claude modules and their previous-stage allowlists remain intact.
"""
from __future__ import annotations

import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import uuid

from instalador.midia import fonte_audio, validar_dados
from instalador.patcher import validate
from instalador.stamina import source_row as stamina_row

ROOT = Path(__file__).resolve().parents[1]
TARGET = {"userId": "10735737143", "universeId": "10776462844", "placeId": "89520940302906"}
STAGE = 3
LIGHTING_PATH = ["StarterPlayer", "StarterPlayerScripts", "BastiaoIluminacao"]
LIGHTING_SOURCE = "src/client/BastiaoIluminacao.client.luau"
_KEY = re.compile(r"[a-z][a-z0-9_]*\Z")
_SHA = re.compile(r"[0-9a-f]{64}\Z")
REPLACEMENTS = {
    "BastiaoServidor": "src/server/BastiaoServidor.luau",
    "Interacoes": "src/server/Interacoes.luau",
    "Sequencias": "src/server/Sequencias.luau",
    "BastiaoCliente": "src/client/BastiaoCliente.luau",
    "Interface": "src/client/Interface.luau",
    "Som": "src/client/Som.luau",
    "Pavel": "src/server/Pavel.luau",
}
EXTRAS = (
    (["ReplicatedStorage", "BastiaoCompartilhado", "AudioCatalog"], None),
    (["ReplicatedStorage", "BastiaoCompartilhado", "MonsterCatalog"], None),
    (["ServerScriptService", "BastiaoServidor", "MonsterImportContract"], "modelo/MonsterImportContract.luau"),
    (["ServerScriptService", "BastiaoServidor", "CriaturaCore"], "src/server/CriaturaCore.luau"),
    (["ServerScriptService", "BastiaoServidor", "Criatura"], "src/server/Criatura.luau"),
    (["StarterPlayer", "StarterPlayerScripts", "BastiaoCliente", "Foley"], "src/client/Foley.luau"),
    (["StarterPlayer", "StarterPlayerScripts", "BastiaoCliente", "Efeitos"], "src/client/Efeitos.luau"),
    (["StarterPlayer", "StarterPlayerScripts", "BastiaoCliente", "MonstroSom"], "src/client/MonstroSom.luau"),
)
# Fontes Bastiao* que já estiveram no Place: as versões do Claude (etapa 2, correções 3 a 8) e o
# Place versão 17, conferido script por script (as nossas publicadas + a Perseguição v2 e o
# MonstroSom do Antigravity, juntados no pacote). O instalador pode trocá-las; qualquer outra
# fonte desconhecida continua bloqueada.
REVISADAS = {
    ('ReplicatedStorage', 'BastiaoCompartilhado'): (
        '0b75886d1bf621cc4d550184a5d59e03d17eac133699415c571bf3c20e25e96a',
    ),
    ('ReplicatedStorage', 'BastiaoCompartilhado', 'Audio'): (
        '0ee8af436a4fb36a78e6c8db0c5dcaecd34c0c794552f1200f469b4dacd86dfb',
    ),
    ('ReplicatedStorage', 'BastiaoCompartilhado', 'AudioCatalog'): (
        '84df270f9977df0f7c52c67b167b98b6f944042798ea64dff58a037b7610096b',
    ),
    ('ReplicatedStorage', 'BastiaoCompartilhado', 'MonsterCatalog'): (
        'f330b25753d6bfb1b38d1b482862ec2c9f0d9c12774fcc6159aff2ee4785f2bb',
    ),
    ('ReplicatedStorage', 'BastiaoCompartilhado', 'Textos'): (
        'c4dd8bba1062859358e1b314aa8375d769220e691c9dcfdb40ba260aa9be6fe8',
    ),
    ('ServerScriptService', 'BastiaoServidor'): (
        '55d96d2dc59ddd0747e86351e83f857e02cf6618cca66a2c35f057016a11bb8c',
        '652f17600b6548f4be8e65f9cdb2ed46c47cfb60ccf5f4284e8a92a58c90a820',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Capitulo01'): (
        'd626534aa7079d8064a84b529f1acc9825043eff7859742c7a759a3c78b44f58',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Cenario'): (
        '4ab0cb8805ae76b7ae362921ed50715ef59512e3d003ee5a6139a075e3239e4b',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Checkpoint'): (
        '4c505e975bb7da5f21ba5a0c4e16d39cef5642f03f99437b10804c3bcdbf3adb',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Criatura'): (
        '55f9221fd34e407ed298bae137245622e7fa98eb31aef5988b92ae6f8c794c0f',
        '57534ab5b08836746b944f5002fc62041840a60cdbe277a858a652a778b3e69f',
        '99cc40970dc2da58b8911eb81b04d85e93b75cfcd7e2712661f15284b5e9904b',
        'bf9d9b847278c484c074257c099d2ec3a2b1a09fedc7f454e2eaa5658a5d476e',
        'deae663ac8b5de62ee19a393000d02cb6ca33ab33b7bd0be7f8993d4d4fc2ad3',
        'f3b6480aee2f94c73b2ee2108fab5f2edb0486ab726b54b128cd83c8ec499653',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'CriaturaCore'): (
        '4faa5d352f1037dba956ed86594d2243014b29ca9e4221a8f418560042b7317d',
        'dcc06c43edd75a21aac0adbf73825bbe6b37a2ce4e4bc3b93e1a3efcf3192deb',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Interacoes'): (
        '1c21bba4115946d2718f99ac7c47536b6d13d78413014c22a2f306fcc2b299ea',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Missao'): (
        '98aebbf6fe1c8be2e6d875d88f391dfeb047d2368328be40e8249dea0282d574',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'MonsterImportContract'): (
        'e5d67e6d1caa00e93f420d4595a7d2dc3eb3b9c01656d5139f81492ba7fcab72',
        'f3c01505b744e2a342ffbd58e94813a91bfceb9255000ea1c69add9f32e43dd3',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Mundo'): (
        '70250de9630b03b00297d87f9fb1b260345be661b98859cd144440032face126',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Pavel'): (
        '2c163ae560d565b2823296218e233a9af077c0a6740a7d5841fb78b5b65f7a2a',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Preferencias'): (
        'c72ebe6aafe2486779954edc631a6bc3956ee55ce9fba7e015bddc62f9f4983c',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Sequencias'): (
        'e0364c865a0c25557b94fce54496541b31a016f24a5d25a043a6fc37d6544269',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'StoryRunner'): (
        '7318655eb590fb221e422a6c0e180944900dd654495673d6736f7255a3ea9595',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'StoryValidator'): (
        'e3fcaeb4aa93da89269e5a246fa0836fbb38dc98a9d5cb07c22a352e35884e68',
    ),
    ('ServerScriptService', 'BastiaoServidor', 'Zonas'): (
        'c265c3aa290dd97a57274a23eaf8eb7f6500b1fe27ce9881105aede315d566c7',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente'): (
        '12f4322708c84f820b33f2dc1b7ea1f269355f7ce16d3e5abe4bd4f1a33db316',
        '769d35e69d661c8af243b00de6f011e79c36c4f28228eec96c76d347dc896127',
        'f27a4d0a47ad13f7c0a977194222de23cdc0d98ef5751e793f2bc867c401d463',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Efeitos'): (
        '775b9e0cd57feaa85fe37dd90e4244e3d090c707bac2391b582dd85d4ea1ef70',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Foley'): (
        '0772d929888633ed21c952fa45c900589ceb885c8d1a3dbe1b7d4b8a8c661bda',
        '5170f72665537b37307658061c11e3b39fe8fe0eae14b91221ab02e14c4c42e2',
        'd3219e362fba416e6e5e63f2f02b20c1ff37d3324ed5518d577b583dadea4c45',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Giroflex'): (
        'a37b9ad356460955bca3994772666760bbb41ed77f81e17b70d6edb6379b313c',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Idioma'): (
        '9e93af5bb91bb8102df824888eb100ea4bcceff33ed69505467d52f9833abe27',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Interface'): (
        '020f9cb55f8864d014905d7fe1e3c72043514db58551268231048a0e836b4a20',
        '3b1eaa6581112032bfe8294d55da6aa483a4fb287e8bc16121c3fbc9b3eed151',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'MonstroSom'): (
        '03b4f2a860f957c2a2e8f1c1858f8a558f3e70f321bc213b03562fdab48caca2',
        '6c1303567f0bd8f99441187cc37adf49df2fc8ace0e6e19195891728cfbc5510',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Prompts'): (
        '63a658eb42dce24193fdae1f3f4b660f112cf2581c74804e64a3e5b7eca2118e',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Som'): (
        '20cdf652f796045091608949a4dd32879156b82e486b5b4c327686937d94cccd',
        '56649bb86dc2afd4569c9cf78282244bbef864ce373937e8aeb8b5f6c104d3d3',
    ),
    ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Telas'): (
        'f127f5100ac3f1daa90e2a533e093030d0a46ec54f19d9c4aaf2ad4207cdd847',
    ),
}
# Fontes exatas recebidas na correcao 9; outras edicoes continuam bloqueadas.
for _path, _sha in {('ServerScriptService', 'BastiaoServidor'): '55d96d2dc59ddd0747e86351e83f857e02cf6618cca66a2c35f057016a11bb8c', ('ServerScriptService', 'BastiaoServidor', 'Criatura'): '9a26471b4ae9beebfd3e576007f94429ca1c2d86b3e4103dcb4698855a9e539c', ('ServerScriptService', 'BastiaoServidor', 'Pavel'): '647c2be83f68e9a0d542df8f56d49e7ae0d09d07ffcf2e121f5e21c9ef5bc101', ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Som'): 'b4fec94bcd76493485c7df73f9ae4a6af17855404d46e8f997415f80c394a949', ('StarterPlayer', 'StarterPlayerScripts', 'BastiaoCliente', 'Efeitos'): '69bae1e072d2041e59b16660c8b914682697f5584de7d9e07ceeb3aa57b19e14'}.items():
    REVISADAS[_path] = tuple(sorted(set(REVISADAS.get(_path, ())) | {_sha}))

SFX_ALIASES = {
    "radio_chiado": "estatica", "tres_toques": "toques_longe", "pressurizacao": "vapor",
    "passos_longe": "passos_monstro", "tres_toques_parede": "toques_perto",
}
LOOP_ALIASES = {"bunker_air": "ambiente", "alarme": "alarme", "radio_estatica_loop": "estatica",
                "bunker_fan_loop": "ventilador", "bunker_vehicle_loop": "motor"}


class BuildError(ValueError):
    """A local input or asset is not ready for a playable release."""


def _load(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"),
                          parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    except (OSError, ValueError, UnicodeError):
        raise BuildError("JSON ausente ou inválido: " + Path(path).name) from None


def _bytes(root, relative):
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise BuildError("Caminho deve ser relativo e permanecer no pacote.")
    path = (Path(root) / relative).resolve()
    if not path.is_relative_to(Path(root).resolve()) or not path.is_file():
        raise BuildError("Arquivo necessário ausente ou fora do pacote: " + relative)
    return path.read_bytes()


def _text(root, relative):
    try:
        value = _bytes(root, relative).decode("utf-8")
    except UnicodeError:
        raise BuildError("Fonte não é UTF-8: " + relative) from None
    if not value.strip():raise BuildError("Fonte vazia: " + relative)
    return value


def _target(data):
    if not isinstance(data, dict) or data.get("target") != TARGET:
        raise BuildError("Manifesto/recibo pertence a outro destino Roblox.")


def _finite(value, minimum=0, maximum=7200):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) and minimum <= value <= maximum


def _id(value):
    if isinstance(value, bool) or not re.fullmatch(r"[1-9][0-9]{0,15}", str(value)):
        raise BuildError("AssetId real ausente ou inválido.")
    result = int(value)
    if result > 2 ** 53 - 1:raise BuildError("AssetId ultrapassa o inteiro exato do Luau.")
    return result


def _check_assets(root, rows):
    seen = set()
    if not isinstance(rows, list) or not rows:raise BuildError("Manifesto sem assets obrigatórios.")
    for row in rows:
        key = row.get("key")
        if not isinstance(key, str) or key in seen:raise BuildError("Chave de asset ausente/duplicada.")
        seen.add(key)
        digest = row.get("sha256")
        if not isinstance(digest, str) or not _SHA.fullmatch(digest):raise BuildError("SHA-256 inválido: " + key)
        if hashlib.sha256(_bytes(root, row.get("path"))).hexdigest() != digest:
            raise BuildError("Asset local mudou: " + key)


def _ready(rows, receipts):
    _target(receipts)
    if not isinstance(receipts.get("assets"), list):raise BuildError("Recibo de assets inválido.")
    got = {}
    for result in receipts["assets"]:
        key = result.get("key")
        if not isinstance(key, str) or key in got:raise BuildError("Recibo ausente/duplicado.")
        got[key] = result
    ids = {}
    for row in rows:
        result = got.get(row["key"])
        if (not result or result.get("status") != "ready" or result.get("moderationState") != "Approved"
                or result.get("permissionStatus") != "granted"):
            raise BuildError("Asset não está pronto/aprovado/autorizado: " + row["key"])
        if any(result.get(key) != row.get(key) for key in ("sha256", "assetType", "contentType")):
            raise BuildError("Hash/tipo de asset mudou: " + row["key"])
        ids[row["key"]] = _id(result.get("assetId"))
    return ids


def lua_value(value):
    if value is None:return "nil"
    if value is True:return "true"
    if value is False:return "false"
    if isinstance(value, (int, float)):
        if not math.isfinite(value):raise BuildError("Número não finito no catálogo.")
        return repr(value)
    if isinstance(value, str):
        output = '"'
        for ch in value:
            if ch == '"':output += '\\"'
            elif ch == "\\":output += "\\\\"
            elif ch == "\n":output += "\\n"
            elif ch == "\r":output += "\\r"
            elif ch == "\t":output += "\\t"
            elif ord(ch) < 32:output += "\\" + str(ord(ch)).zfill(3)
            else:output += ch
        return output + '"'
    if isinstance(value, list):return "{" + ",".join(lua_value(item) for item in value) + "}"
    if isinstance(value, dict):
        if any(not isinstance(key, str) for key in value):raise BuildError("Chave de catálogo deve ser texto.")
        return "{" + ",".join("[" + lua_value(key) + "]=" + lua_value(item) for key, item in value.items()) + "}"
    raise BuildError("Tipo não suportado no catálogo.")


def audio_catalog(manifest, receipts):
    _target(manifest)
    ids = _ready(manifest["assets"], receipts)
    by_key = {row["key"]: row for row in manifest["assets"]}
    assets = {}
    for key, segment in manifest.get("segments", {}).items():
        if not isinstance(key, str) or not _KEY.fullmatch(key):raise BuildError("Chave de som inválida.")
        start, finish, duration = (segment.get(name) for name in ("start", "finish", "duration"))
        if (not _finite(start) or not _finite(finish, 0.001) or not _finite(duration, 0.025, 90)
                or finish <= start or abs(finish - start - duration) > 1 / 44100):
            raise BuildError("Limites/duração divergentes: " + key)
        file_key = segment.get("fileKey")
        if file_key not in ids or finish > by_key[file_key].get("durationSeconds", 0) + 1 / 44100:
            raise BuildError("Segmento fora do atlas enviado: " + key)
        if segment.get("category") not in {"Voice", "Foley", "UI", "Ambience"}:
            raise BuildError("Categoria de som inválida: " + key)
        if not _finite(segment.get("volume", 0.8), 0, 1):raise BuildError("Volume inválido: " + key)
        if any(name in segment and not isinstance(segment[name], bool) for name in ("spatial", "radio", "loop")):
            raise BuildError("Sinalizador de som inválido: " + key)
        entry = {name: copy.deepcopy(segment[name]) for name in
                 ("start", "finish", "duration", "category", "volume", "spatial", "radio", "loop") if name in segment}
        entry["id"] = ids[file_key]
        assets[key] = entry
    if not assets:raise BuildError("Catálogo de áudio vazio.")
    return {"version": 1, "assets": assets}


def monster_upload_plan(plan):
    rows = []
    def append(key, item):
        rows.append({"key": key, "path": item["file"], "assetType": item["assetType"],
                     "contentType": item["contentType"], "sha256": item["sha256"],
                     "displayName": ("Bastião " + key)[:100],
                     "description": "Projeto Bastião — asset original do criador."})
    try:
        append("monster_model", plan["model"])
        for item in plan["textures"]:append(item["name"], item)
        for item in plan["animations"]:append(item["name"], item)
    except (KeyError, TypeError):
        raise BuildError("Plano do monstro incompleto.") from None
    if len({row["key"] for row in rows}) != len(rows):raise BuildError("Chave duplicada no plano do monstro.")
    return {"schemaVersion": 1, "target": dict(TARGET), "assets": rows}


def monster_catalog(plan, receipts):
    ids = _ready(monster_upload_plan(plan)["assets"], receipts)
    animations = {}
    count = len(plan["animations"])
    if count not in (35, 36) or (count == 36 and not any(
            clip.get("name") == "36_CORRER_MEDONHO" for clip in plan["animations"])):
        raise BuildError("Esperadas 35 animacoes base, com 36_CORRER_MEDONHO opcional preservada.")
    for clip in plan["animations"]:
        duration = clip.get("duration_seconds")
        if not _finite(duration, 0.01, 120) or not isinstance(clip.get("loop"), bool):
            raise BuildError("Animação sem duração/loop válido: " + clip["name"])
        markers = clip.get("markers")
        if not isinstance(markers, list) or any(not isinstance(marker, dict) or
                not _finite(marker.get("time"), 0, duration) or not isinstance(marker.get("name"), str) for marker in markers):
            raise BuildError("Marcadores inválidos: " + clip["name"])
        animations[clip["name"]] = {"id": ids[clip["name"]], "duration": duration, "loop": clip["loop"],
                                     "priority": clip.get("priority", "Action"), "markers": copy.deepcopy(markers),
                                     "conversion": clip.get("conversion", "native")}
    scale = plan["scale"]
    if not _finite(scale.get("monster_rest_height_studs"), 1, 30):raise BuildError("Altura do monstro inválida.")
    return {"version": 1, "enabled": True, "modelId": ids["monster_model"],
            "heightStuds": scale["monster_rest_height_studs"],
            "visualFacingYawDegrees": scale["visual_facing_yaw_degrees"],
            "meshName": plan["model"]["canonical_mesh_name"], "rootBone": plan["model"]["canonical_root_bone"],
            "textures": {item["name"]: ids[item["name"]] for item in plan["textures"]}, "animations": animations}


def legacy_upload_plan(root=ROOT):
    root = Path(root)
    data = validar_dados(_load(root / "legado/audio.json"))
    rows = []
    for key in sorted(data["sprites"]):
        info = data["sprites"][key]
        raw = _bytes(root / "legado", info["arquivo"])
        rows.append({"key": key, "path": info["arquivo"], "assetType": "Audio", "contentType": "audio/ogg",
                     "sha256": hashlib.sha256(raw).hexdigest(), "displayName": "Bastião original " + key,
                     "durationSeconds": info["segundos"]})
    return {"schemaVersion": 1, "target": dict(TARGET), "assets": rows}


def _source_inputs(root):
    baseline = _load(root / "BASE_CLAUDE_ETAPA2.json")
    if not isinstance(baseline, list) or len(baseline) != 23:raise BuildError("Base Claude requer os 23 scripts revisados.")
    validate(baseline)
    for relative in (*REPLACEMENTS.values(), *(path for _, path in EXTRAS if path), LIGHTING_SOURCE, "src/teste_nuvem.luau"):
        _text(root, relative)
    return baseline


def _inputs(root):
    baseline = _source_inputs(root)
    legacy_plan = legacy_upload_plan(root)
    audio_manifest = _load(root / "audio/AUDIO_MANIFEST.json")
    _target(audio_manifest)
    if audio_manifest.get("production", {}).get("complete") is not True:
        raise BuildError("Produção de áudio ainda pendente. Execute preparar-audio no Termux.")
    _check_assets(root / "audio", audio_manifest.get("assets"))
    plan = _load(root / "audio/AUDIO_PLAN.json")
    _target(plan)
    required = {clip["key"] for clip in plan.get("clips", []) if clip.get("enabled", True)}
    if not required:raise BuildError("Plano de áudio sem clipes obrigatórios.")
    missing = required - set(audio_manifest.get("segments", {}))
    # Sons que o ElevenLabs não gerou ficam de fora (o jogo mostra a legenda), desde que o
    # manifesto declare exatamente quais faltam.
    declared = set(audio_manifest.get("production", {}).get("missing", []))
    if missing - declared:raise BuildError("Clipes obrigatórios ausentes: " + ", ".join(sorted(missing - declared)))
    monster_plan = _load(root / "modelo/MONSTER_ASSET_PLAN.json")
    _check_assets(root / "modelo", monster_upload_plan(monster_plan)["assets"])
    return baseline, legacy_plan, audio_manifest, monster_plan


def _combined_audio(root, legacy_plan, manifest):
    original = validar_dados(_load(root / "legado/audio.json"))
    data = copy.deepcopy(original)
    data["versao"] = 3
    for group in ("vozes", "sfx", "loops", "duracoes"):data.setdefault(group, {})
    data["vozes"].setdefault("pt", {})
    ids = _ready(legacy_plan["assets"], _load(root / "legado/UPLOADED_ASSETS.json"))
    new_ids = _ready(manifest["assets"], _load(root / "audio/UPLOADED_ASSETS.json"))
    files = {row["path"]: _bytes(root / "legado", row["path"]) for row in legacy_plan["assets"]}
    for row in manifest["assets"]:
        key = row["key"]
        if not _KEY.fullmatch(key) or key in data["sprites"]:
            raise BuildError("Atlas novo colide com sprite legado: " + str(key))
        data["sprites"][key] = {"arquivo": "audio/" + key + ".ogg", "segundos": row["durationSeconds"]}
        files["audio/" + key + ".ogg"] = _bytes(root / "audio", row["path"])
    ids.update(new_ids)
    for key, segment in manifest["segments"].items():
        value = [segment["start"], segment["duration"], segment["fileKey"]]
        if segment["category"] == "Voice":
            data["vozes"]["pt"].setdefault(key, value)
            data["duracoes"].setdefault(key, segment["duration"])
        else:
            group = "loops" if segment.get("loop") else "sfx"
            data[group].setdefault(key, value)
            if key in SFX_ALIASES:data["sfx"].setdefault(SFX_ALIASES[key], value)
            if key in LOOP_ALIASES:data["loops"].setdefault(LOOP_ALIASES[key], value)
    validar_dados(data)
    return original, data, ids, files


def _assemble(root):
    baseline, legacy_plan, audio_manifest, monster_plan = _inputs(root)
    audio = audio_catalog(audio_manifest, _load(root / "audio/UPLOADED_ASSETS.json"))
    monster = monster_catalog(monster_plan, _load(root / "modelo/UPLOADED_ASSETS.json"))
    old_audio, combined, ids, audio_files = _combined_audio(root, legacy_plan, audio_manifest)
    rows = copy.deepcopy(baseline)
    changed = []
    seen_names = set()
    for row in rows:
        name, before = row["path"][-1], row["source"]
        if name in REPLACEMENTS:
            row["source"] = _text(root, REPLACEMENTS[name]);seen_names.add(name)
        elif name == "BastiaoCompartilhado":
            row["source"] = before.replace('Compartilhado.ETAPA = "ETAPA-2"', 'Compartilhado.ETAPA = "ETAPA-3"')
        elif row["path"] == ["ReplicatedStorage", "BastiaoCompartilhado", "Audio"]:
            row["source"] = fonte_audio(combined, ids)
            row["generatedAudio"] = [old_audio, combined]
            row.pop("gerado", None)
        row["known"] = sorted(set(row.get("known", []) + [hashlib.sha256(before.encode()).hexdigest()]))
        if row["source"] != before:changed.append("/".join(row["path"]))
    if seen_names != set(REPLACEMENTS):raise BuildError("Base Claude não contém os destinos dos replacements.")
    occupied = {tuple(row["path"]) for row in rows}
    for path, relative in EXTRAS:
        if tuple(path) in occupied:raise BuildError("Novo módulo colide com a base: " + "/".join(path))
        source = _text(root, relative) if relative else "return " + lua_value(audio if path[-1] == "AudioCatalog" else monster) + "\n"
        rows.append({"path": path, "cls": "ModuleScript", "source": source})
        occupied.add(tuple(path))
    for row in rows:
        revisadas = REVISADAS.get(tuple(row["path"]))
        if revisadas:row["known"] = sorted(set(row.get("known", [])) | set(revisadas))
    rows.append(stamina_row())
    rows.append({"path": LIGHTING_PATH.copy(), "cls": "LocalScript", "source": _text(root, LIGHTING_SOURCE)})
    validate(rows)
    report = {"stage": STAGE, "replacedSources": changed,
              "addedSources": ["/".join(path) for path, _ in EXTRAS] + ["/".join(LIGHTING_PATH)],
              "sourceCount": len(rows), "preservedLegacyVoices": len(old_audio["vozes"].get("pt", {})),
              "audioClips": len(audio["assets"]), "monsterAnimations": len(monster["animations"]),
              "modelHeightStuds": monster["heightStuds"], "readyToBuild": True, "engineValidated": False,
              "sprintSeconds": 100 / 19, "staminaChange": "DrainRate 22 -> 19; all other Sector7 fields unchanged"}
    return rows, report, combined, ids, audio_files


def assemble_sources(root=ROOT):
    rows, report, _, _, _ = _assemble(Path(root))
    return rows, report


def build_files(root=ROOT):
    root = Path(root)
    rows, report, audio_data, ids, files = _assemble(root)
    encode = lambda value: json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode()
    files.update({"package.json": encode({"stage": STAGE, "legacyAudioIds": ids, "assetsReady": True}),
                  "sources.json": encode(rows), "audio.json": encode(audio_data),
                  "teste_nuvem.luau": _bytes(root, "src/teste_nuvem.luau")})
    files["manifest.json"] = encode({name: hashlib.sha256(raw).hexdigest() for name, raw in files.items()})
    return files, report


def build(root=ROOT):
    root = Path(root)
    files, report = build_files(root)
    persist_payload(root, files)
    folder = root / "payload"
    (folder / "BUILD_REPORT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return report


def verify(root=ROOT):
    """Read-only local verification. Missing production never becomes a fake ID."""
    root = Path(root)
    baseline = _source_inputs(root)
    legacy = legacy_upload_plan(root)
    model = _load(root / "modelo/MONSTER_ASSET_PLAN.json")
    _check_assets(root / "modelo", monster_upload_plan(model)["assets"])
    report = {"stage": STAGE, "baseScripts": len(baseline), "finalScripts": len(baseline) + len(EXTRAS) + 2,
              "sourceIntegrity": True, "legacySprites": len(legacy["assets"]),
              "readyToBuild": False, "engineValidated": False, "pending": []}
    try:
        files, ready_report = build_files(root)
        from instalador.package import Package
        Package(files).scripts(1)
        report.update(ready_report)
    except BuildError as exc:
        report["pending"].append(str(exc))
    return report


def _atomic_bytes(path, raw):
    from instalador.paths import guard, private_dir, sync_dir
    path = guard(path)
    private_dir(path.parent)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        with temporary.open("xb") as stream:
            os.chmod(temporary, 0o600)
            stream.write(raw);stream.flush();os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_dir(path.parent)
    finally:
        temporary.unlink(missing_ok=True)


def persist_payload(root, files):
    """Freeze the exact tested payload so resume never rebuilds a changed plan."""
    from instalador.package import Package
    Package(files)
    folder = Path(root) / "payload"
    for name, raw in files.items():
        if name == "manifest.json":continue
        if Path(name).is_absolute() or ".." in Path(name).parts:raise BuildError("Caminho de payload inválido.")
        _atomic_bytes(folder / name, raw)
    _atomic_bytes(folder / "manifest.json", files["manifest.json"])


def load_payload(root=ROOT):
    from instalador.package import Package
    folder = Path(root) / "payload"
    manifest = _load(folder / "manifest.json")
    if not isinstance(manifest, dict):raise BuildError("Manifesto congelado inválido.")
    files = {name: _bytes(folder, name) for name in manifest}
    files["manifest.json"] = _bytes(folder, "manifest.json")
    Package(files)
    return files


def upload_manifests(root=ROOT):
    """Normalize original model/legacy plans; validate all bytes before any key."""
    from . import assets_upload
    root = Path(root)
    _, legacy, _, model = _inputs(root)
    legacy_path, model_path = root / "legado/ASSET_MANIFEST.json", root / "modelo/ASSET_MANIFEST.json"
    for path, plan in ((legacy_path, legacy), (model_path, monster_upload_plan(model))):
        _atomic_bytes(path, json.dumps(plan, ensure_ascii=False, indent=2).encode())
    paths = (legacy_path, root / "audio/AUDIO_MANIFEST.json", model_path)
    for path in paths:assets_upload.validate_manifest(path)
    return paths


def seed_legacy_receipts(manifest_path, installer_state):
    """Migrate known Create operations from Claude's hash-indexed audio receipts.

    Approval and grants are refreshed by the uploader. A local old 'Approved'
    string never becomes a new ready receipt without consulting Roblox.
    """
    from . import assets_upload
    from instalador.paths import guard
    from instalador.runtime import read
    manifest_path = Path(manifest_path)
    plan = assets_upload.validate_manifest(manifest_path)
    old = read(Path(installer_state) / "midia-recibos.json", {})
    if not old:return 0
    if not isinstance(old, dict) or not isinstance(old.get("arquivos"), dict):
        raise BuildError("Recibos antigos de áudio inválidos; preserve midia-recibos.json.")
    state = guard(manifest_path.parent / ".asset_upload_state")
    migrated = 0
    with assets_upload._locked(state):
        for entry in plan["assets"]:
            digest = entry["sha256"]
            path = guard(state / (digest + ".json"))
            if path.exists():continue
            known = old["arquivos"].get(digest)
            if known is None:continue
            operation = known.get("operationId") if isinstance(known, dict) else None
            if (not isinstance(operation, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", operation)
                    or known.get("arquivo") != entry["key"]):
                raise BuildError("Recibo antigo sem operação confiável. Preserve os recibos; nenhum Create foi repetido.")
            asset_id = str(_id(known["assetId"])) if known.get("assetId") else None
            receipt = {"schemaVersion": 1, "target": dict(TARGET), "sha256": digest,
                       "assetType": entry["assetType"], "contentType": entry["contentType"],
                       "assetId": asset_id, "operationPath": "operations/" + operation,
                       "status": "pending_moderation" if asset_id else "uploading", "permissionStatus": "pending"}
            assets_upload._check_receipt(receipt, entry)
            assets_upload._atomic_json(path, receipt)
            migrated += 1
    return migrated
