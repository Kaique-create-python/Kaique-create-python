"""Resolve os recursos do menu para IDs aprovados no universo correto."""
from __future__ import annotations

import getpass
import math
from pathlib import Path
import urllib.request
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
import warnings

from . import upload

SOUNDS = ("click", "confirm", "glitch", "react", "hello_morning", "hello_late", "hello_miss")
# Weapon, footstep, and interface sounds (tools/prepare_weapon_audio.py and tools/synth_weapon_fx.py).
# The game runs without them while they await approval.
OPTIONAL_SOUNDS = ("arma_vespa", "arma_enxame", "arma_trovao", "arma_agulha", "arma_soco", "arma_lamina",
                   "arma_recarga", "arma_vazia", "arma_troca", "arma_recarga_fuzil", "arma_recarga_escopeta",
                   "passo_1", "passo_2", "passo_3", "passo_4", "ui_tick", "ui_abrir", "ui_fechar", "ui_confirmar")
ART = {
    "title": (1020, 258), "billboard": (1020, 1020),
    "concrete": (1024, 1024), "concrete_normal": (768, 768),
    "asphalt": (1024, 1024), "asphalt_normal": (768, 768), "asphalt_rough": (768, 768),
    "facades": (1024, 1024),
    # Janelas da cidade jogável, desenhadas por tools/draw_city_textures.py (sem IA).
    "fachada_residencial": (768, 896), "fachada_escritorio": (768, 896), "fachada_vidro": (768, 896),
    # 2D icons for the wheel, the weapon card, and the touch buttons (design/icones.py, vector by hand).
    "icones_interface": (1024, 1024),
    # Cidade v2: painéis, vitrines, anúncios e céu desenhados por código (tools/draw_city_art.py, tools/draw_sky.py);
    # poças sobre o asfalto Poly Haven; tijolo, metal ondulado, piso hexagonal e concreto rachado Poly Haven (CC0).
    "fachada_painel": (768, 896), "vitrines": (1024, 1024), "anuncios": (1024, 1024),
    "poca_1": (512, 512), "poca_2": (512, 512), "poca_3": (512, 512), "poca_4": (512, 512),
    "ceu_bk": (512, 512), "ceu_dn": (512, 512), "ceu_ft": (512, 512), "ceu_lf": (512, 512), "ceu_rt": (512, 512), "ceu_up": (512, 512),
    "tijolo": (768, 768), "tijolo_normal": (512, 512), "metal_ondulado": (768, 768), "metal_ondulado_normal": (512, 512),
    "piso_hexagonal": (768, 768), "piso_hexagonal_normal": (512, 512), "concreto_rachado": (768, 768), "concreto_rachado_normal": (512, 512),
}
# A cidade usa cores e faixas de luz em geometria enquanto estas imagens aguardam aprovação.
CITY_V2_ART = ("fachada_painel", "vitrines", "anuncios", "poca_1", "poca_2", "poca_3", "poca_4",
               "ceu_bk", "ceu_dn", "ceu_ft", "ceu_lf", "ceu_rt", "ceu_up", "tijolo", "tijolo_normal", "metal_ondulado",
               "metal_ondulado_normal", "piso_hexagonal", "piso_hexagonal_normal", "concreto_rachado", "concreto_rachado_normal")
OPTIONAL_ART = frozenset({"fachada_residencial", "fachada_escritorio", "fachada_vidro", "icones_interface", *CITY_V2_ART})


def _read(path):
    return upload._json(Path(path).read_bytes())


def _asset_id(value, *, label):
    if isinstance(value, bool) or not upload._ID.fullmatch(str(value)):
        raise ValueError(f"ID de {label} deve ser positivo, sem URL ou texto.")
    result = int(value)
    if result >= 2**53:
        raise ValueError(f"ID de {label} excede o limite inteiro exato do Roblox.")
    return result


def remember_video(path, value):
    asset_id = _asset_id(value, label="vídeo")
    upload._atomic_json(path, {"video": asset_id})
    return asset_id


def saved_video(path):
    if not path.is_file():
        return None
    return _asset_id(_read(path).get("video"), label="vídeo")


def verificar_destino_publico():
    """Conferir o mesmo Place e a conta criadora antes de criar qualquer asset."""
    opener = urllib.request.build_opener(upload._NoRedirect())
    paths = (
        f"https://apis.roblox.com/universes/v1/places/{upload.TARGET['placeId']}/universe",
        "https://games.roblox.com/v1/games?" + urlencode({"universeIds": upload.TARGET["universeId"]}),
    )
    results = []
    for url in paths:
        try:
            with opener.open(url, timeout=12) as response:
                results.append(upload._json(response.read(128 * 1024)))
        except (URLError, TimeoutError) as error:
            host = urlsplit(url).hostname
            reason = f"HTTP {error.code}" if isinstance(error, HTTPError) else "falha de conexão ou tempo esgotado"
            raise ValueError(f"O Termux não conseguiu consultar {host} ({reason}). Confira a conexão e rode midia novamente.") from None
    mapping, universes = results
    rows = universes.get("data", [])
    universe, place, creator = (int(upload.TARGET[name]) for name in ("universeId", "placeId", "userId"))
    if mapping.get("universeId") != universe or len(rows) != 1:
        raise ValueError("O Roblox não confirmou o universo do Place do CyberOutlaw.")
    metadata = rows[0]
    if metadata.get("id") != universe or metadata.get("rootPlaceId") != place:
        raise ValueError("O Roblox não confirmou este Place como local inicial.")
    owner = metadata.get("creator", {})
    if owner.get("id") != creator or owner.get("type") != "User":
        raise ValueError("O dono do jogo mudou. Revise o destino antes de enviar mídia.")
    return metadata.get("name", "CyberOutlaw")


def key_prompt():
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        result = getpass.getpass("Chave Roblox Open Cloud (oculta): ")
    result = "".join(c for c in result if c.isascii() and c.isprintable() and not c.isspace())
    if not result:
        raise ValueError("A chave está vazia.")
    return result


def sprite_catalog(root, plan):
    capri = _read(root / "media/capri/capri_clips.json")
    definitions = capri.get("clips")
    if not isinstance(definitions, dict) or "idle" not in definitions:
        raise ValueError("A animação base da Capri está ausente.")
    atlas_entries = {row["key"]: row for row in plan["assets"]
                     if row["assetType"] == "Image" and row["key"] in capri["images"]}
    dimensions = {}
    for key, row in atlas_entries.items():
        raw = upload._read_bytes(root / "media", row)
        dimensions[key] = upload._image_dimensions(raw, Path(row["path"]).suffix.lower())
    for name, clip in definitions.items():
        fps, frames = clip.get("fps"), clip.get("frames")
        if (type(fps) not in (int, float) or not math.isfinite(fps) or not 1 <= fps <= 60
            or not isinstance(frames, list) or not 1 <= len(frames) <= 240):
            raise ValueError(f"Animação inválida: {name}")
        for frame in frames:
            atlas = frame.get("assetKey")
            rect = [frame.get(field) for field in ("x", "y", "w", "h")]
            if atlas not in dimensions or any(type(value) is not int for value in rect):
                raise ValueError(f"Quadro inválido: {name}")
            x, y, w, h = rect
            aw, ah = dimensions[atlas]
            if min(x, y) < 0 or min(w, h) < 1 or x + w > aw or y + h > ah:
                raise ValueError(f"Quadro fora da textura: {name}")
    return capri


def resolved_config(root, plan, result, video=None):
    if result.get("target") != upload.TARGET:
        raise ValueError("Os recibos de mídia pertencem a outro destino.")
    rows = result.get("assets", [])
    if not isinstance(rows, list):
        raise ValueError("Recibos de mídia inválidos.")
    by_key = {r["key"]: r for r in rows}
    if len(by_key) != len(rows):
        raise ValueError("Recibo de mídia repetido.")
    selected = {}
    pending = []
    for expected in plan["assets"]:
        key = expected["key"]
        row = by_key.get(key, {})
        if row and any(row.get(k) != expected[k] for k in ("sha256", "assetType", "contentType")):
            raise ValueError(f"O recibo de {key} pertence a outra versão do arquivo.")
        if not (row.get("status") == "ready" and row.get("moderationState") == "Approved" and row.get("permissionStatus") == "granted"):
            if key not in OPTIONAL_ART and key not in OPTIONAL_SOUNDS:
                pending.append(key)
            continue
        selected[key] = _asset_id(row["assetId"], label=key)
    if pending:
        raise ValueError("Mídia aguardando aprovação ou acesso: " + ", ".join(pending))
    sprites = sprite_catalog(root, plan)
    sounds = {name: selected[name] for name in SOUNDS}
    sounds.update({name: selected[name] for name in OPTIONAL_SOUNDS if name in selected})
    output = {"sounds": sounds, "clips": {},
              "art": {name: selected[name] for name in ART if name in selected}}
    for name, clip in sprites["clips"].items():
        output["clips"][name] = {
            "fps": clip["fps"],
            "frames": [
                {"id": selected[frame["assetKey"]], **{k: frame[k] for k in ("x", "y", "w", "h")}}
                for frame in clip["frames"]
            ],
        }
    if video is not None:
        output["video"] = _asset_id(video, label="vídeo")
    return output


def verify_media(root):
    root = Path(root)
    manifest = root / "media/ASSET_PLAN.json"
    plan = upload.validate_manifest(manifest)
    capri = sprite_catalog(root, plan)
    by_key = {row["key"]: row for row in plan["assets"]}
    for key, size in ART.items():
        row = by_key.get(key, {})
        if (row.get("assetType") != "Image" or row.get("path") != f"art/{key}.png"
                or upload._image_dimensions(upload._read_bytes(root / "media", row), ".png") != size):
            raise ValueError(f"Imagem do menu com resolução incompatível. {key}")
    return plan, capri


def make_config(root, *, video=None, state_dir=None):
    root = Path(root)
    plan, _ = verify_media(root)
    result = upload.read_saved_catalog(plan, state_dir) if state_dir is not None else None
    if result is None:
        receipt = root / "media/UPLOADED_ASSETS.json"
        if not receipt.is_file():
            raise ValueError("Use o comando midia para importar e aprovar os assets antes de instalar.")
        result = _read(receipt)
    path = root / "config/ASSETS.json"
    old = _read(path) if path.is_file() else {}
    output = resolved_config(root, plan, result, video if video is not None else old.get("video"))
    upload._atomic_json(path, output)
    return output


def import_media(root, state, *, video=None):
    root = Path(root)
    print("Conferindo os arquivos de mídia…", flush=True)
    plan, _ = verify_media(root)
    if video is not None:
        _asset_id(video, label="vídeo")
    print("Conferindo o Place na API pública do Roblox…", flush=True)
    game = verificar_destino_publico()
    print(f"CyberOutlaw · {game} · Place {upload.TARGET['placeId']}", flush=True)
    print(f"{len(plan['assets'])} imagens e sons. Envio retomável pelos recibos locais.", flush=True)
    upload.upload_manifest(root / "media/ASSET_PLAN.json", key_prompt(),
                           state_dir=state, max_polls=5, max_wait_seconds=18,
                           progress=lambda line: print(line, flush=True))
    config = make_config(root, video=video)
    print(f"Mídia vinculada: {len(config['clips'])} animações, {len(config['sounds'])} sons e {len(config['art'])} artes.")
    return config
