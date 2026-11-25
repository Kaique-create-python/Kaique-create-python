"""Resolve os recursos do menu para IDs aprovados no universo correto."""
from __future__ import annotations

import getpass
import hashlib
import math
from pathlib import Path
import shutil
import subprocess
import urllib.request
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
import warnings

from . import upload

SOUNDS = ("click", "confirm", "glitch", "react", "hello_morning", "hello_late", "hello_miss")
# Weapon, footstep, and interface sounds (tools/prepare_weapon_audio.py and tools/synth_weapon_fx.py).
# The game runs without them while they await approval.
OPTIONAL_SOUNDS = ("arma_glock", "arma_deagle", "arma_uzi", "arma_ak47", "arma_m4", "arma_escopeta", "arma_sniper",
                   "arma_bomba", "arma_ferrolho", "arma_soco", "arma_lamina",
                   "arma_recarga", "arma_vazia", "arma_troca", "arma_recarga_fuzil", "arma_recarga_escopeta",
                   "passo_1", "passo_2", "passo_3", "passo_4", "ui_tick", "ui_abrir", "ui_fechar", "ui_confirmar", "ui_negado",
                   "pulo", "aterrissar",
                   # Implantes: ativação do Sandevistan, ciberpsicose e encaixe (tools/synth_weapon_fx.py).
                   "habilidade_lenta", "surto", "implante_encaixe", "pulo_duplo", "soco_gorila", "kiroshi_scan",
                   "parar_tempo", "acerto", "acerto_cabeca", "chamada", "dinheiro", "alarme",
                   "arma_glock_pesada", "arma_deagle_pesada", "arma_uzi_pesada", "arma_ak47_pesada", "arma_m4_pesada",
                   "arma_escopeta_pesada", "arma_sniper_pesada")
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
    from install.chave import clean_key, fingerprint
    result, notes = clean_key(result)
    if not result:
        raise ValueError("A chave está vazia.")
    for note in notes:
        print("Chave: " + note + ".", flush=True)
    print("Chave lida: " + fingerprint(result) + ". Compare com a que você copiou do site.", flush=True)
    return result


REQUIRED_SCOPES = "asset:read, asset:write e asset-permissions:write"


def auth_advice(status, detail, length):
    said = f" O Roblox respondeu: {detail}." if detail else ""
    if status == 403:
        return (f"O Roblox aceitou a chave, mas ela não tem permissão (HTTP 403).{said} "
                f"Na chave, habilite {REQUIRED_SCOPES} e confira se ela é da mesma conta dona do jogo. "
                "Nada foi enviado. Depois rode midia de novo.")
    return (f"O Roblox não aceitou a chave (HTTP 401).{said} A chave colada tem {length} caracteres. "
            "Confira se ela está ativa e não expirou, se o IP aceito é 0.0.0.0/0, "
            f"se tem {REQUIRED_SCOPES} e se é da conta dona do jogo. "
            "Se tiver dúvida, gere uma chave nova e use o botão de copiar do site. "
            "Nada foi enviado. Depois rode midia de novo.")


def owned_asset(state):
    """Any approved asset from the local receipts, used only to test that the key can read assets."""
    for path in sorted(Path(state).glob("*.json")) if Path(state).is_dir() else ():
        try:
            receipt = _read(path)
        except (ValueError, OSError, UnicodeError):
            continue
        asset = str(receipt.get("assetId") or "")
        if receipt.get("status") == "ready" and upload._ID.fullmatch(asset):
            return asset
    return None


def test_key(state, *, transport=None, key=None):
    """Read one approved asset with the key; creates nothing on Roblox."""
    asset = owned_asset(state)
    if asset is None:
        print("Ainda não há mídia aprovada para testar a leitura. Rode midia: ele para no primeiro erro da chave.")
        return 1
    key = key if key is not None else key_prompt()
    session = upload._Session(transport or upload.UrllibTransport(), key, 1, 0, 0, lambda _: None, lambda: 0.0)
    try:
        response = session.request("GET", upload.ASSETS_URL + "/assets/" + asset)
    except (OSError, TimeoutError):
        print("Sem conexão com apis.roblox.com. Confira a internet e tente de novo.")
        return 1
    if response.status == 200:
        print(f"Chave OK: o Roblox deixou ler o asset {asset}. Rode midia para enviar o resto.")
        return 0
    detail = upload.error_detail(response.body)
    if response.status in (401, 403):
        print(auth_advice(response.status, detail, len(key)))
    else:
        print(f"O Roblox respondeu HTTP {response.status}. {detail}".strip())
    return 1


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


def make_config(root, *, video=None, state_dir=None, music=None):
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
    if music is not None:
        output["sounds"][MUSIC_KEY] = _asset_id(music, label="música do menu")
    upload._atomic_json(path, output)
    return output


# Música do menu ------------------------------------------------------------------------------------
# O dono escolhe um vídeo ou áudio do celular. O ffmpeg do Termux tira a trilha (até 6 min 55 s) e ela
# vai para o Roblox como Audio, pelo mesmo envio com recibos da mídia. No menu ela toca em loop.
MUSIC_KEY = "musica_menu"


def _music_folder(storage):
    return Path(storage) / "musica"


def prepare_music(source, folder):
    source = Path(source).expanduser()
    if not source.is_file():
        raise ValueError(f"Arquivo não encontrado: {source}. No Termux, rode termux-setup-storage uma vez e use o "
                         "caminho dentro de ~/storage (por exemplo ~/storage/downloads/video.mp4).")
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("musica_menu.*"):
        old.unlink()
    ffmpeg = shutil.which("ffmpeg")
    extension = source.suffix.lower()
    if not ffmpeg:
        if extension in (".ogg", ".wav", ".flac"):
            target = folder / ("musica_menu" + extension)
            shutil.copyfile(source, target)
            return target
        raise ValueError("Para tirar a música do vídeo, instale o ffmpeg no Termux com: pkg install ffmpeg "
                         "e rode este comando de novo.")
    attempts = (
        ("musica_menu.ogg", ["-c:a", "libvorbis", "-q:a", "5", "-ar", "44100", "-ac", "2"]),
        ("musica_menu.ogg", ["-c:a", "libopus", "-b:a", "128k", "-ac", "2"]),
        ("musica_menu.wav", ["-c:a", "pcm_s16le", "-ar", "32000", "-ac", "1"]),
    )
    for name, codec in attempts:
        target = folder / name
        command = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(source), "-vn", "-sn", "-dn",
                   "-t", "415", *codec, str(target)]
        done = subprocess.run(command, check=False)
        if done.returncode == 0 and target.is_file() and target.stat().st_size > 2000:
            return target
        if target.exists():
            target.unlink()
    raise ValueError("O ffmpeg não conseguiu tirar o áudio desse arquivo. Confira se o vídeo tem som.")


def _music_plan(folder):
    manifest = Path(folder) / "ASSET_PLAN.json"
    return manifest if manifest.is_file() else None


def import_music(root, storage, source):
    folder = _music_folder(storage)
    print("Preparando a música…", flush=True)
    audio = prepare_music(source, folder)
    data = audio.read_bytes()
    if len(data) > upload.MAX_BYTES:
        raise ValueError("A música ficou maior que 20 MB. Use um trecho menor do vídeo.")
    duration, _, _ = upload._audio_info(data, audio.suffix.lower())
    manifest = folder / "ASSET_PLAN.json"
    upload._atomic_json(manifest, {"schemaVersion": 1, "target": dict(upload.TARGET), "assets": [{
        "key": MUSIC_KEY, "path": audio.name, "assetType": "Audio",
        "contentType": upload._FORMATS["Audio"][audio.suffix.lower()], "sha256": hashlib.sha256(data).hexdigest(),
        "displayName": "CyberOutlaw musica do menu", "description": "Música do menu do CyberOutlaw, enviada pelo dono do jogo.",
        "durationSeconds": duration,
    }]})
    print(f"Música pronta: {audio.name}, {duration:.0f} s.", flush=True)
    game = verificar_destino_publico()
    print(f"CyberOutlaw · {game} · Place {upload.TARGET['placeId']}", flush=True)
    key = key_prompt()
    try:
        result = _send_music(manifest, storage, key)
    finally:
        del key
    row = result["assets"][0]
    print(f"Música do menu: {row['status']}" + (f" ({row['lastErrorCode']})" if row.get("lastErrorCode") else ""))
    print("Quando estiver aprovada (ready), rode instalar para ela tocar no menu.")
    return row


def _send_music(manifest, storage, key):
    try:
        return upload.upload_manifest(manifest, key, state_dir=Path(storage) / "recibos-musica",
                                      max_polls=6, max_wait_seconds=20, progress=lambda line: print(line, flush=True))
    except upload.AuthRejected as refused:
        raise ValueError(auth_advice(refused.status, refused.detail, len(key))) from None


def saved_music(storage):
    """ID da música do menu já aprovada (ou None), lido só dos recibos locais."""
    manifest = _music_plan(_music_folder(storage))
    if manifest is None:
        return None
    plan = upload.validate_manifest(manifest)
    result = upload.read_saved_catalog(plan, Path(storage) / "recibos-musica")
    for row in (result or {}).get("assets", []):
        if (row.get("key") == MUSIC_KEY and row.get("status") == "ready" and row.get("moderationState") == "Approved"
                and row.get("permissionStatus") == "granted"):
            return _asset_id(row["assetId"], label="música do menu")
    return None


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
    key = key_prompt()
    try:
        upload.upload_manifest(root / "media/ASSET_PLAN.json", key,
                               state_dir=state, max_polls=5, max_wait_seconds=18,
                               progress=lambda line: print(line, flush=True))
        music = _music_plan(_music_folder(Path(state).parent))
        if music is not None:
            print("Conferindo a música do menu…", flush=True)
            _send_music(music, Path(state).parent, key)
    except upload.AuthRejected as refused:
        raise ValueError(auth_advice(refused.status, refused.detail, len(key))) from None
    finally:
        del key
    config = make_config(root, video=video, music=saved_music(Path(state).parent))
    print(f"Mídia vinculada: {len(config['clips'])} animações, {len(config['sounds'])} sons e {len(config['art'])} artes.")
    return config
