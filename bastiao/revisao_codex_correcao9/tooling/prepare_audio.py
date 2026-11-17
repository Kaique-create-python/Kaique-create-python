#!/usr/bin/env python3
"""Deferred ElevenLabs production. Standard library + ffmpeg; never retries a POST.

Importing this module and --inspect are offline. ``prepare`` is the explicit
generation entry point; ``build_atlases`` only processes already verified media.
No production audio is synthesized by this code without a supplied API key.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
import getpass
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
import wave
import warnings

API_BASE = "https://api.elevenlabs.io"
PROFILE_VERSION = 1
TAGS = {"whispers", "sighs", "exhales", "sarcastic", "curious", "excited", "crying"}
PROFILES = {"local", "radio", "pa", "foley", "ui", "ambience", "roar"}
MAX_RESPONSE = 64 * 1024 * 1024


class AudioProductionError(RuntimeError):
    """Actionable production failure; messages never contain an API key/body."""


def hidden_key():
    if not sys.stdin.isatty():
        raise AudioProductionError("Abra esta ação no terminal Termux para digitar a chave de forma oculta.")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            key = getpass.getpass("Chave ElevenLabs (oculta; não será salva): ").strip()
    except (getpass.GetPassWarning, EOFError, KeyboardInterrupt):
        raise AudioProductionError("Não foi possível ocultar a chave; nenhuma solicitação foi enviada.") from None
    if not key:
        raise AudioProductionError("Chave ElevenLabs vazia.")
    return key


@dataclass
class HTTPResponse:
    status: int
    headers: dict
    body: bytes


def _now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _digest(data):
    return hashlib.sha256(data).hexdigest()


def _json_hash(data):
    return _digest(json.dumps(data, ensure_ascii=False, sort_keys=True, allow_nan=False).encode())


def _file_hash(path):
    result = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def _write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        raise AudioProductionError(f"JSON ausente ou inválido: {Path(path).name}") from None


def _finite(value, low, high):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) and low <= value <= high


def _inside(root, relative):
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise AudioProductionError("Caminho de áudio deve ser relativo ao plano.")
    result = (root / relative).resolve()
    if not result.is_relative_to(root.resolve()):
        raise AudioProductionError("Caminho fora da pasta de áudio foi recusado.")
    return result


def load_plan(plan_path):
    """Validate every request and path before any paid operation."""
    plan = _read_json(plan_path)
    if not isinstance(plan, dict) or plan.get("schemaVersion") != 1:
        raise AudioProductionError("AUDIO_PLAN requer schemaVersion 1.")
    target = plan.get("target", {})
    if not isinstance(target, dict) or any(not re.fullmatch(r"[1-9][0-9]*", str(target.get(k, "")))
                                           for k in ("userId", "universeId", "placeId")):
        raise AudioProductionError("Destino Roblox inválido no plano de áudio.")
    atlas = plan.get("atlas", {})
    if atlas.get("sampleRate", 44100) != 44100 or not _finite(atlas.get("paddingSeconds", 0.24), 0.12, 1):
        raise AudioProductionError("Atlas requer 44100 Hz e intervalo entre 0,12 e 1 s.")
    clips = plan.get("clips")
    if not isinstance(clips, list) or not clips:
        raise AudioProductionError("Plano sem clipes.")
    seen = set()
    root = Path(plan_path).resolve().parent
    for clip in clips:
        if not isinstance(clip, dict):
            raise AudioProductionError("Clipe inválido no plano.")
        name = clip.get("key", "")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_]{0,79}", name) or name in seen:
            raise AudioProductionError("Chave de áudio inválida ou duplicada.")
        seen.add(name)
        if clip.get("kind") not in {"tts", "sfx", "reuse"} or clip.get("profile") not in PROFILES:
            raise AudioProductionError(f"Tipo/perfil inválido: {name}")
        if clip.get("category") not in {"Voice", "Foley", "UI", "Ambience"} or not _finite(clip.get("volume", 0.8), 0, 1):
            raise AudioProductionError(f"Categoria/volume inválido: {name}")
        for flag in ("loop", "spatial", "radio", "enabled"):
            if flag in clip and not isinstance(clip[flag], bool):
                raise AudioProductionError(f"Campo booleano inválido: {name}/{flag}")
        if clip.get("kind") in {"tts", "sfx"}:
            if not isinstance(clip.get("text"), str) or not clip["text"].strip() or len(clip["text"]) > 4500:
                raise AudioProductionError(f"Texto de geração inválido: {name}")
        if clip["kind"] == "tts":
            if clip.get("role") not in plan.get("voices", {}):
                raise AudioProductionError(f"Papel sem voz planejada: {name}")
            tags = clip.get("tags", [])
            if not isinstance(tags, list) or any(tag not in TAGS for tag in tags):
                raise AudioProductionError(f"Tag de direção não documentada: {name}")
            if clip.get("radio", False) != (clip["profile"] in {"radio", "pa"}):
                raise AudioProductionError(f"Sinalizador radio deve corresponder ao DSP já aplicado: {name}")
        elif clip["kind"] == "sfx":
            if not _finite(clip.get("durationSeconds"), 0.5, 30) or not _finite(clip.get("promptInfluence", 0.5), 0, 1):
                raise AudioProductionError(f"SFX requer duração finita 0,5–30 s e influência 0–1: {name}")
        else:
            _inside(root, clip.get("sourcePath"))
            if not re.fullmatch(r"[a-f0-9]{64}", str(clip.get("sha256", ""))):
                raise AudioProductionError(f"Fonte reutilizada sem SHA-256: {name}")
    return plan


def _enabled(plan):
    return [c for c in plan["clips"] if c.get("enabled", True)]


def _receipt_path(root, clip):
    return root / "receipts" / (clip["key"] + ".json")


def _source_status(root, clip):
    if clip["kind"] == "reuse":
        path = _inside(root, clip["sourcePath"])
        state = "completed" if path.is_file() and _file_hash(path) == clip["sha256"] else "corrupt"
        return {"status": state, "rawPath": clip["sourcePath"], "sha256": clip["sha256"]}
    path = _receipt_path(root, clip)
    if not path.exists():
        return {"status": "missing"}
    receipt = _read_json(path)
    if receipt.get("clipHash") != _json_hash(clip):
        return {**receipt, "status": "plan_changed"}
    if receipt.get("status") == "completed":
        raw = _inside(root, receipt.get("rawPath"))
        if not raw.is_file() or _file_hash(raw) != receipt.get("sha256"):
            return {**receipt, "status": "corrupt"}
    return receipt


def inspect_plan(plan_path):
    """Offline status. A plan or copied roar never counts as completed voices."""
    plan = load_plan(plan_path)
    root = Path(plan_path).resolve().parent
    clips = {c["key"]: _source_status(root, c) for c in _enabled(plan)}
    report = {"schemaVersion": 1, "complete": False, "clips": clips,
              "requiredClips": len(clips), "completedSources": sum(c["status"] == "completed" for c in clips.values())}
    manifest = root / "AUDIO_MANIFEST.json"
    if manifest.exists() and all(c["status"] == "completed" for c in clips.values()):
        try:
            data = _read_json(manifest)
            validate_manifest(data, root, probe=False)
            report["complete"] = data.get("planHash") == _json_hash(plan)
        except AudioProductionError:
            pass
    return report


@contextmanager
def _lock(root):
    path = root / ".production.lock"
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        raise AudioProductionError("Produção bloqueada por .production.lock. Verifique se outra execução está ativa; após interrupção, remova apenas esse lock com o processo parado.") from None
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(json.dumps({"pid": os.getpid(), "createdAt": _now()}))
        yield
    finally:
        path.unlink(missing_ok=True)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _transport(method, url, headers, body):
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    opener = urllib.request.build_opener(_NoRedirect)
    try:
        response = opener.open(request, timeout=180)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        payload = response.read(MAX_RESPONSE + 1)
        if len(payload) > MAX_RESPONSE:
            raise AudioProductionError("Resposta excedeu o limite de 64 MiB; recuperação manual necessária.")
        return HTTPResponse(response.status, dict(response.headers), payload)


class _Client:
    def __init__(self, key, transport=None):
        if not isinstance(key, str) or not key.strip() or "\n" in key or "\r" in key:
            raise AudioProductionError("Chave ElevenLabs vazia ou inválida.")
        self.key = key
        self.transport = transport or _transport

    def request(self, method, path, payload=None):
        headers = {"xi-api-key": self.key, "Accept": "application/json" if method == "GET" and not path.endswith("/audio") else "audio/mpeg"}
        body = None
        if payload is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(payload, ensure_ascii=False, allow_nan=False).encode()
        # No retries here, in urllib, or at the calling layer.
        response = self.transport(method, API_BASE + path, headers, body)
        if not isinstance(response, HTTPResponse) or not isinstance(response.body, bytes):
            raise AudioProductionError("Estrutura de resposta HTTP inválida.")
        response.headers = {str(k).lower(): str(v) for k, v in response.headers.items()}
        return response

    def get_json(self, path):
        try:
            response = self.request("GET", path)
        except Exception:
            raise AudioProductionError("Falha de rede em consulta ElevenLabs; nenhuma geração iniciada por esta consulta.") from None
        if response.status != 200:
            raise AudioProductionError(f"Consulta ElevenLabs recusada (HTTP {response.status}). Confira chave e permissões de leitura.")
        try:
            return json.loads(response.body)
        except (ValueError, UnicodeError):
            raise AudioProductionError("Resposta JSON inválida em consulta ElevenLabs.") from None


def _voice_eligible(voice, tier, model):
    if not isinstance(voice, dict) or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", str(voice.get("voice_id", ""))):
        return False
    verify = voice.get("voice_verification") or {}
    if verify.get("requires_verification") and not verify.get("is_verified"):
        return False
    sharing = voice.get("sharing") or {}
    category = voice.get("category", sharing.get("category", ""))
    tiers = voice.get("available_for_tiers") or []
    if tiers and tier and tier not in tiers:
        return False
    if category == "professional":
        if not model.get("serves_pro_voices"):
            return False
        if tier == "free" and sharing.get("free_users_allowed") is not True:
            return False
        if not tier or (tier != "free" and tier not in tiers):
            return False
    supported = voice.get("high_quality_base_model_ids") or []
    verified = voice.get("verified_languages") or []
    supports_v3 = "eleven_v3" in supported or any(v.get("model_id") == "eleven_v3" for v in verified if isinstance(v, dict))
    # Premade voices are documented general-purpose multilingual TTS voices.
    return supports_v3 or category in {"premade", "default"}


def _rank_voice(voice, role):
    labels = voice.get("labels") or {}
    detail = " ".join(str(v) for v in labels.values()).lower() + " " + str(voice.get("description", "")).lower()
    score = 0
    if any(word in detail for word in ("brazil", "brasil", "brasileir")):
        score += 40
    if str(labels.get("language", "")).lower() in {"pt", "pt-br", "portuguese", "português"}:
        score += 25
    if role.get("mature") and any(word in detail for word in ("middle_aged", "middle aged", "mature", "old", "adult")):
        score += 8
    if role.get("gender") == "male" and any(word in detail for word in ("deep", "grave", "baritone", "low")):
        score += 6
    return (-score, str(voice.get("name", "")).casefold(), voice["voice_id"])


def _select_voices(plan, root, client):
    response = client.get_json("/v1/voices")
    voices = response.get("voices") if isinstance(response, dict) else None
    models = client.get_json("/v1/models")
    if not isinstance(voices, list) or not isinstance(models, list):
        raise AudioProductionError("Catálogo de vozes/modelos inválido; nenhuma geração iniciada.")
    model = next((m for m in models if isinstance(m, dict) and m.get("model_id") == "eleven_v3"), {})
    languages = model.get("languages") or []
    if not model.get("can_do_text_to_speech") or not any(l.get("language_id") == "pt" for l in languages if isinstance(l, dict)):
        raise AudioProductionError("eleven_v3 com português não confirmado pelo catálogo de modelos desta conta.")
    try:
        subscription = client.get_json("/v1/user/subscription")
        tier = subscription.get("tier") if isinstance(subscription, dict) else None
    except AudioProductionError:
        tier = None
    eligible = [v for v in voices if _voice_eligible(v, tier, model)]
    by_id = {v["voice_id"]: v for v in eligible}
    selected_path = root / "VOICES_SELECTED.json"
    previous = _read_json(selected_path).get("roles", {}) if selected_path.exists() else {}
    required = {c["role"] for c in _enabled(plan) if c["kind"] == "tts"}
    groups = {}
    for role in plan.get("voices", {}):
        if role in required:
            groups.setdefault(plan["voices"][role].get("voiceGroup", role), []).append(role)
    selected, group_choices = {}, {}
    for group, roles in groups.items():
        role_plan = plan["voices"][roles[0]]
        candidates = [v for v in eligible if str((v.get("labels") or {}).get("gender", "")).lower() == role_plan.get("gender")]
        forbidden = set()
        for distinct in role_plan.get("distinctFrom", []):
            if distinct in group_choices:
                forbidden.add(group_choices[distinct]["voiceId"])
        candidates = [v for v in candidates if v["voice_id"] not in forbidden]
        pin = next((previous[r]["voiceId"] for r in roles if r in previous), None)
        preferred = role_plan.get("voiceId")
        if pin:
            chosen = next((v for v in candidates if v["voice_id"] == pin), None)
            if chosen is None:
                raise AudioProductionError(f"Voz já fixada para {group} indisponível ou sem permissão comprovada. Preserve a voz para manter consistência.")
        else:
            chosen = next((v for v in candidates if v["voice_id"] == preferred), None)
            if chosen is None and candidates:
                # Prefer unused actors, then Brazilian accent / mature timbre.
                used = {c["voiceId"] for c in group_choices.values()}
                chosen = sorted(candidates, key=lambda v: (v["voice_id"] in used, _rank_voice(v, role_plan)))[0]
        if chosen is None:
            available = ", ".join(f"{v.get('name', '?')} ({v['voice_id']})" for v in eligible[:12]) or "nenhuma voz com capacidade/permissão confirmada"
            raise AudioProductionError(f"Sem voz apropriada para {group}; alternativas reais: {available}.")
        choice = {"voiceId": chosen["voice_id"], "name": chosen.get("name", chosen["voice_id"]), "group": group,
                  "preferredVoiceId": preferred, "fallbackReason": None if chosen["voice_id"] == preferred else
                  "Voz preferida ausente, sem permissão comprovada ou incompatível; escolha determinística do GET /v1/voices, mantendo gênero e priorizando pt-BR/timbre maduro."}
        group_choices[group] = choice
        for role in roles:
            selected[role] = choice
        print(f"Voz {group}: {choice['name']} ({choice['voiceId']})" + (" · alternativa disponível na conta" if choice["fallbackReason"] else ""), flush=True)
    _write_json(selected_path, {"schemaVersion": 1, "validatedAt": _now(), "accountTier": tier, "modelId": "eleven_v3", "roles": selected})
    return selected


def _request_for(clip, choices):
    if clip["kind"] == "tts":
        text = " ".join("[" + tag + "]" for tag in clip.get("tags", []))
        text = (text + " " if text else "") + clip["text"]
        voice = choices[clip["role"]]
        return "/v1/text-to-speech/" + voice["voiceId"] + "?output_format=mp3_44100_128", {
            "text": text, "model_id": "eleven_v3", "language_code": "pt",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.75, "speed": 1.0}}, voice
    return "/v1/sound-generation?output_format=mp3_44100_128", {
        "text": clip["text"], "model_id": "eleven_text_to_sound_v2", "duration_seconds": clip["durationSeconds"],
        "prompt_influence": clip.get("promptInfluence", 0.5), "loop": clip.get("loop", False)}, None


def _run(command, step):
    try:
        return subprocess.run(command, check=True, capture_output=True, timeout=300)
    except (OSError, subprocess.SubprocessError):
        raise AudioProductionError(f"Falha em {step}. Confira ffmpeg/ffprobe e o arquivo de entrada; nenhuma nova geração é necessária para repetir DSP.") from None


def _probe(path, ffprobe="ffprobe", maximum=7300):
    result = _run([ffprobe, "-v", "error", "-show_entries", "format=duration:stream=codec_type,codec_name,sample_rate,channels", "-of", "json", str(path)], "ffprobe")
    try:
        data = json.loads(result.stdout)
        duration = float(data["format"]["duration"])
        streams = data["streams"]
        if not _finite(duration, 0.025, maximum) or not any(s.get("codec_type") == "audio" for s in streams):
            raise ValueError()
    except (ValueError, KeyError, TypeError):
        raise AudioProductionError("Mídia sem duração de áudio válida.") from None
    return duration


def _safe_header(headers, key, secret):
    value = headers.get(key, "")
    if not isinstance(value, str) or secret in value or not re.fullmatch(r"[A-Za-z0-9_.:+-]{1,200}", value):
        return None
    return value


def _accept_audio(root, clip, receipt, response, secret, ffprobe):
    if response.status != 200 or not response.headers.get("content-type", "").lower().startswith("audio/"):
        raise AudioProductionError(f"Resposta de geração não contém áudio válido (HTTP {response.status}); não reenviar automaticamente.")
    data = response.body
    if len(data) < 32 or len(data) > MAX_RESPONSE or secret.encode() in data or not (data.startswith(b"ID3") or (data[0] == 255 and data[1] & 224 == 224)):
        raise AudioProductionError("Resposta MP3 malformada; geração permanece bloqueada para evitar cobrança duplicada.")
    raw = _inside(root, receipt["rawPath"])
    raw.parent.mkdir(parents=True, exist_ok=True)
    temporary = raw.with_suffix(".mp3.part")
    try:
        with temporary.open("wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        duration = _probe(temporary, ffprobe, maximum=90)
        os.replace(temporary, raw)
    finally:
        temporary.unlink(missing_ok=True)
    receipt.update(status="completed", completedAt=_now(), sha256=_digest(data), durationSeconds=duration,
                   requestId=_safe_header(response.headers, "request-id", secret) or receipt.get("requestId"),
                   historyItemId=_safe_header(response.headers, "history-item-id", secret) or receipt.get("historyItemId"),
                   characterCount=_safe_header(response.headers, "x-character-count", secret))
    _write_json(_receipt_path(root, clip), receipt)
    return receipt


def _ensure_tools(ffmpeg, ffprobe):
    if not shutil.which(ffmpeg) or not shutil.which(ffprobe):
        raise AudioProductionError("Instale as dependências no Termux: pkg install python ffmpeg")


def prepare(plan_path, key=None, *, ffmpeg="ffmpeg", ffprobe="ffprobe", transport=None):
    """Generate missing sources once, then return a COMPLETE upload manifest.

    ``transport(method, full_url, headers, body_bytes_or_none) -> HTTPResponse``
    is injectable for offline tests. A completed, hash-valid source is never POSTed
    again. A pending/uncertain POST blocks the batch until explicit recovery.
    """
    plan_path = Path(plan_path).resolve()
    plan, root = load_plan(plan_path), plan_path.parent
    _ensure_tools(ffmpeg, ffprobe)
    with _lock(root):
        statuses = {c["key"]: _source_status(root, c) for c in _enabled(plan)}
        if any(s["status"] != "completed" for s in statuses.values()):
            (root / "AUDIO_MANIFEST.json").unlink(missing_ok=True)
        for name, state in statuses.items():
            if state["status"] in {"pending", "uncertain"}:
                raise AudioProductionError(f"{name}: pedido anterior incerto. Use --recover-history ou --recover-file; não há repetição automática de POST.")
            if state["status"] not in {"missing", "completed"}:
                raise AudioProductionError(f"{name}: fonte {state['status']}; restaure o arquivo/recibo ou reverta a alteração do plano. Regeneração paga automática recusada.")
        missing = [c for c in _enabled(plan) if statuses[c["key"]]["status"] == "missing"]
        if missing:
            key = key if key is not None else hidden_key()
            client = _Client(key, transport)
            choices = _select_voices(plan, root, client) if any(c["kind"] == "tts" for c in missing) else {}
            for clip in missing:
                path, payload, voice = _request_for(clip, choices)
                receipt = {"schemaVersion": 1, "key": clip["key"], "status": "pending", "createdAt": _now(),
                           "provider": "ElevenLabs", "clipHash": _json_hash(clip), "requestHash": _json_hash(payload),
                           "endpoint": path, "payload": payload, "voice": voice, "rawPath": "raw/" + clip["key"] + ".mp3"}
                # Durable journal BEFORE POST: even SIGKILL cannot cause a blind retry.
                _write_json(_receipt_path(root, clip), receipt)
                print(f"Gerando uma vez: {clip['key']}", flush=True)
                try:
                    response = client.request("POST", path, payload)
                    receipt["requestId"] = _safe_header(response.headers, "request-id", key)
                    receipt["historyItemId"] = _safe_header(response.headers, "history-item-id", key)
                    receipt["httpStatus"] = response.status
                    _accept_audio(root, clip, receipt, response, key, ffprobe)
                except Exception:
                    receipt.update(status="uncertain", interruptedAt=_now(), error="Resposta ausente, recusada ou inválida; consultar histórico antes de qualquer novo POST.")
                    _write_json(_receipt_path(root, clip), receipt)
                    raise AudioProductionError(f"{clip['key']}: geração incerta; execução pausada e pedido NÃO repetido. Consulte o histórico ElevenLabs e recupere o áudio.") from None
        return _build_atlases(plan, root, ffmpeg, ffprobe)


def _metrics(path):
    with wave.open(str(path), "rb") as source:
        if source.getnchannels() != 1 or source.getsampwidth() != 2 or source.getframerate() != 44100:
            raise AudioProductionError("PCM de trabalho deve ser mono, 16 bits e 44100 Hz.")
        frames = source.getnframes()
        data = source.readframes(frames)
    values = [v[0] for v in struct.iter_unpack("<h", data)]
    if not values:
        raise AudioProductionError("Áudio vazio após processamento.")
    peak = max(abs(v) for v in values) / 32768
    rms = math.sqrt(sum(v * v for v in values) / len(values)) / 32768
    if peak >= 32767 / 32768 or rms < 10 ** (-65 / 20):
        raise AudioProductionError("Áudio recusado por clipping ou silêncio integral.")
    return {"frames": frames, "durationSeconds": frames / 44100, "peak": peak,
            "rmsDbfs": 20 * math.log10(rms), "loopBoundaryJump": abs(values[0] - values[-1]) / 32768}


def _filter(clip):
    profile = clip["profile"]
    filters = []
    if not clip.get("loop"):
        # Trim only OUTER silence. Reverse avoids deleting meaningful internal pauses.
        trim = "silenceremove=start_periods=1:start_duration=0.008:start_threshold=-55dB:start_silence=0.03"
        filters += [trim, "areverse", trim, "areverse"]
    if profile == "local":
        filters += ["highpass=f=100", "lowpass=f=11000", "equalizer=f=2700:t=q:w=0.9:g=1.8",
                    "acompressor=threshold=-18dB:ratio=2:attack=8:release=80", "aecho=0.8:0.75:28|53:0.055|0.025"]
    elif profile == "radio":
        filters += ["highpass=f=240", "lowpass=f=4200", "equalizer=f=1800:t=q:w=1:g=2",
                    "acompressor=threshold=-20dB:ratio=3:attack=3:release=70", "aecho=0.8:0.75:16|42:0.06|0.028"]
    elif profile == "pa":
        filters += ["highpass=f=180", "lowpass=f=6000", "equalizer=f=2200:t=q:w=1:g=2",
                    "acompressor=threshold=-20dB:ratio=2.5:attack=4:release=90", "aecho=0.8:0.75:55|110:0.12|0.06"]
    else:
        filters += ["highpass=f=30", "lowpass=f=13000"]
    loudness = -17 if clip["category"] == "Voice" else -25 if profile == "ambience" else -20
    filters += [f"loudnorm=I={loudness}:TP=-2:LRA=7", "aresample=44100", "alimiter=limit=0.88:level=0"]
    if not clip.get("loop"):
        filters += ["afade=t=in:d=0.003", "areverse", "afade=t=in:d=0.006", "areverse"]
    return ",".join(filters)


def _process(root, clip, source, cache, ffmpeg, ffprobe):
    output = root / "processed" / (clip["key"] + ".wav")
    old = cache.get(clip["key"], {})
    signature = _json_hash({"source": source["sha256"], "clip": clip, "profileVersion": PROFILE_VERSION})
    if not (old.get("signature") == signature and output.is_file() and old.get("sha256") == _file_hash(output)):
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_suffix(".tmp.wav")
        try:
            _run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(_inside(root, source["rawPath"])), "-vn", "-ac", "1",
                  "-af", _filter(clip), "-ar", "44100", "-c:a", "pcm_s16le", str(temporary)], "traitement DSP")
            _probe(temporary, ffprobe, maximum=90)
            metrics = _metrics(temporary)
            if clip.get("loop") and metrics["loopBoundaryJump"] > 0.2:
                raise AudioProductionError(f"{clip['key']}: raccord de boucle trop abrupt; revisar o áudio antes de publicar.")
            os.replace(temporary, output)
        finally:
            temporary.unlink(missing_ok=True)
        old = {"signature": signature, "sha256": _file_hash(output), "metrics": metrics}
    provider = clip.get("provider", "User-provided" if clip["kind"] == "reuse" else "ElevenLabs")
    return {**old, "status": "ready", "rawPath": source["rawPath"], "processedPath": output.relative_to(root).as_posix(),
            "provider": provider, "profile": clip["profile"], "radioProcessed": clip["profile"] in {"radio", "pa"}}


def _concat_wave(output, clips, root, padding_frames):
    output.parent.mkdir(parents=True, exist_ok=True)
    locations, cursor = {}, 0
    with wave.open(str(output), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(44100)
        for index, (clip, info) in enumerate(clips):
            if index:
                target.writeframes(b"\0\0" * padding_frames)
                cursor += padding_frames
            with wave.open(str(_inside(root, info["processedPath"])), "rb") as source:
                count = source.getnframes()
                target.writeframes(source.readframes(count))
            locations[clip["key"]] = (cursor / 44100, (cursor + count) / 44100)
            cursor += count
    return locations


def _build_atlases(plan, root, ffmpeg, ffprobe):
    clips = _enabled(plan)
    sources = {c["key"]: _source_status(root, c) for c in clips}
    not_ready = [k for k, v in sources.items() if v["status"] != "completed"]
    if not_ready:
        (root / "AUDIO_MANIFEST.json").unlink(missing_ok=True)
        raise AudioProductionError("Fontes ainda pendentes/alteradas: " + ", ".join(not_ready))
    report_path = root / "PROCESSING_REPORT.json"
    cached = _read_json(report_path).get("clips", {}) if report_path.exists() else {}
    processed = {}
    for clip in clips:
        processed[clip["key"]] = _process(root, clip, sources[clip["key"]], cached, ffmpeg, ffprobe)
        _write_json(report_path, {"schemaVersion": 1, "updatedAt": _now(), "clips": {**cached, **processed}})
    groups = {}
    for clip in clips:
        group = "voices_atlas" if clip["category"] == "Voice" else clip["key"] if clip.get("loop") or clip["profile"] == "roar" else "foley_atlas"
        groups.setdefault(group, []).append((clip, processed[clip["key"]]))
    assets, segments = [], {}
    padding_frames = round(plan.get("atlas", {}).get("paddingSeconds", 0.24) * 44100)
    for group, members in groups.items():
        wav = root / "atlases" / (group + ".wav")
        locations = _concat_wave(wav, members, root, padding_frames)
        metrics = _metrics(wav)
        final = root / "publish" / (group + ".ogg")
        final.parent.mkdir(parents=True, exist_ok=True)
        temporary = final.with_suffix(".tmp.ogg")
        try:
            _run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-vn", "-ac", "1", "-ar", "44100",
                  "-c:a", "libvorbis", "-q:a", "5", str(temporary)], "codificação OGG Vorbis")
            duration = _probe(temporary, ffprobe)
            if abs(duration - metrics["durationSeconds"]) > 0.01:
                raise AudioProductionError("Duração OGG diverge dos limites PCM dos segmentos.")
            # Check the actual publish codec, including overshoot caused by lossy encoding.
            check = root / "processed" / ("_check_" + group + ".wav")
            try:
                _run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(temporary), "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le", str(check)], "validação OGG")
                _metrics(check)
            finally:
                check.unlink(missing_ok=True)
            os.replace(temporary, final)
        finally:
            temporary.unlink(missing_ok=True)
        assets.append({"key": group, "path": final.relative_to(root).as_posix(), "assetType": "Audio", "contentType": "audio/ogg",
                       "sha256": _file_hash(final), "displayName": "Bastião · " + group, "durationSeconds": duration})
        for clip, info in members:
            start, finish = locations[clip["key"]]
            segments[clip["key"]] = {"fileKey": group, "start": start, "finish": finish, "duration": finish - start,
                                     "category": clip["category"], "volume": clip.get("volume", 0.8), "spatial": clip.get("spatial", False),
                                     "radio": clip.get("radio", False), "loop": clip.get("loop", False)}
    providers = sorted({item["provider"] for item in processed.values()})
    manifest = {"schemaVersion": 1, "target": plan["target"], "assets": assets, "segments": segments,
                "planHash": _json_hash(plan), "clips": processed, "production": {"complete": True,
                "provider": providers[0] if len(providers) == 1 else "Mixed", "providers": providers, "profileVersion": PROFILE_VERSION}}
    validate_manifest(manifest, root, ffprobe=ffprobe)
    _write_json(root / "AUDIO_MANIFEST.json", manifest)
    _write_json(root / "PRODUCTION_STATUS.json", {"schemaVersion": 1, "complete": True, "completedSources": len(sources), "requiredClips": len(sources), "updatedAt": _now()})
    return manifest


def build_atlases(plan_path, *, ffmpeg="ffmpeg", ffprobe="ffprobe"):
    """Offline DSP and manifest construction; safe to retry without any API key."""
    plan_path = Path(plan_path).resolve()
    plan = load_plan(plan_path)
    _ensure_tools(ffmpeg, ffprobe)
    with _lock(plan_path.parent):
        return _build_atlases(plan, plan_path.parent, ffmpeg, ffprobe)


def validate_manifest(manifest, audio_root, *, ffprobe="ffprobe", probe=True):
    """Verify hashes, ffprobe durations, and exact atlas segment boundaries."""
    root, by_key = Path(audio_root).resolve(), {}
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1 or not isinstance(manifest.get("assets"), list):
        raise AudioProductionError("Manifesto de áudio inválido.")
    for asset in manifest["assets"]:
        key = asset.get("key")
        if not key or key in by_key or asset.get("assetType") != "Audio" or asset.get("contentType") not in {"audio/ogg", "audio/wav"}:
            raise AudioProductionError("Asset de áudio inválido ou duplicado.")
        path = _inside(root, asset.get("path"))
        if not path.is_file() or _file_hash(path) != asset.get("sha256") or not _finite(asset.get("durationSeconds"), 0.025, 7200):
            raise AudioProductionError("Arquivo publicado ausente, corrompido ou sem duração válida.")
        if probe and abs(_probe(path, ffprobe) - asset["durationSeconds"]) > 0.015:
            raise AudioProductionError("Duração declarada diverge do arquivo publicado.")
        by_key[key] = asset
    for name, segment in manifest.get("segments", {}).items():
        asset = by_key.get(segment.get("fileKey"))
        if asset is None or not _finite(segment.get("start"), 0, 7200) or not _finite(segment.get("finish"), 0.001, 7200):
            raise AudioProductionError(f"Segmento sem arquivo ou limites finitos: {name}")
        if segment["finish"] <= segment["start"] or segment["finish"] > asset["durationSeconds"] + 1 / 44100:
            raise AudioProductionError(f"Segmento ultrapassa a duração do arquivo: {name}")
        if not _finite(segment.get("duration"), 0.025, 90) or abs(segment["finish"] - segment["start"] - segment["duration"]) > 1 / 44100:
            raise AudioProductionError(f"Duração de segmento inconsistente: {name}")
    return True


def recover_history(plan_path, clip_key, history_id, key, *, transport=None, ffprobe="ffprobe"):
    """Recover a documented TTS history item via GET only; validate exact text/voice."""
    plan_path = Path(plan_path).resolve()
    root, plan = plan_path.parent, load_plan(plan_path)
    clip = next((c for c in _enabled(plan) if c["key"] == clip_key), None)
    if clip is None or clip["kind"] != "tts" or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", history_id):
        raise AudioProductionError("Recuperação de histórico requer uma chave TTS e um ID de histórico válido.")
    with _lock(root):
        receipt = _source_status(root, clip)
        if receipt["status"] not in {"pending", "uncertain"}:
            raise AudioProductionError("Não há pedido TTS incerto correspondente para recuperar.")
        client = _Client(key, transport)
        entry = client.get_json("/v1/history/" + history_id)
        if not isinstance(entry, dict) or entry.get("text") != receipt["payload"]["text"] or entry.get("voice_id") != receipt["voice"]["voiceId"] or entry.get("model_id") != "eleven_v3":
            raise AudioProductionError("Histórico não corresponde ao texto, voz e modelo do pedido; recuperação recusada.")
        response = client.request("GET", "/v1/history/" + history_id + "/audio")
        receipt["historyItemId"] = history_id
        return _accept_audio(root, clip, receipt, response, key, ffprobe)


def recover_file(plan_path, clip_key, file_path, *, ffprobe="ffprobe"):
    """Explicitly restore an original downloaded MP3; does not contact ElevenLabs."""
    plan_path = Path(plan_path).resolve()
    root, plan = plan_path.parent, load_plan(plan_path)
    clip = next((c for c in _enabled(plan) if c["key"] == clip_key), None)
    if clip is None or clip["kind"] == "reuse":
        raise AudioProductionError("Chave de recuperação desconhecida.")
    with _lock(root):
        receipt = _source_status(root, clip)
        if receipt["status"] not in {"pending", "uncertain", "corrupt"}:
            raise AudioProductionError("Não há fonte incerta/corrompida correspondente para restaurar.")
        receipt["manualRecovery"] = {"confirmedOriginalDownload": True, "at": _now()}
        response = HTTPResponse(200, {"content-type": "audio/mpeg"}, Path(file_path).read_bytes())
        return _accept_audio(root, clip, receipt, response, "__no_key_in_offline_recovery__", ffprobe)


def clear_pending(plan_path, clip_key, *, no_charge_confirmed=False):
    """Explicit operator override after checking provider history/billing. Never automatic."""
    if no_charge_confirmed is not True:
        raise AudioProductionError("Confira histórico e cobrança; depois use --confirm-no-charge. Pedido incerto não será limpo automaticamente.")
    plan_path = Path(plan_path).resolve()
    root, plan = plan_path.parent, load_plan(plan_path)
    clip = next((c for c in _enabled(plan) if c["key"] == clip_key), None)
    if clip is None:
        raise AudioProductionError("Chave de áudio desconhecida.")
    with _lock(root):
        receipt = _source_status(root, clip)
        if receipt["status"] not in {"pending", "uncertain"}:
            raise AudioProductionError("Somente pedido incerto pode ser liberado desta forma.")
        receipt.update(manualNoChargeVerification=True, clearedAt=_now())
        audit = root / "receipts" / "cleared" / (clip_key + "_" + uuid.uuid4().hex + ".json")
        _write_json(audit, receipt)
        _receipt_path(root, clip).unlink()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", default=str(Path(__file__).resolve().parents[1] / "audio" / "AUDIO_PLAN.json"))
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--inspect", action="store_true", help="Somente status local, sem chave/rede")
    actions.add_argument("--build-only", action="store_true", help="Somente DSP/atlas após todas as fontes estarem salvas")
    actions.add_argument("--recover-history", nargs=2, metavar=("CLIP", "HISTORY_ID"))
    actions.add_argument("--recover-file", nargs=2, metavar=("CLIP", "MP3_ORIGINAL"))
    actions.add_argument("--clear-pending", metavar="CLIP")
    parser.add_argument("--confirm-no-charge", action="store_true", help="Afirmação explícita de que histórico/cobrança foram conferidos")
    args = parser.parse_args(argv)
    try:
        if args.inspect:
            print(json.dumps(inspect_plan(args.plan), ensure_ascii=False, indent=2))
        elif args.build_only:
            manifest = build_atlases(args.plan)
            print(f"Áudio completo: {len(manifest['assets'])} assets, {len(manifest['segments'])} segmentos.")
        elif args.recover_history:
            recover_history(args.plan, *args.recover_history, hidden_key())
            print("Fonte recuperada via GET, sem nova geração.")
        elif args.recover_file:
            recover_file(args.plan, *args.recover_file)
            print("Fonte original recuperada localmente, sem nova geração.")
        elif args.clear_pending:
            clear_pending(args.plan, args.clear_pending, no_charge_confirmed=args.confirm_no_charge)
            print("Pedido liberado após confirmação explícita de ausência de cobrança; recibo anterior arquivado.")
        else:
            manifest = prepare(args.plan)
            print(f"Áudio completo: {len(manifest['assets'])} assets, {len(manifest['segments'])} segmentos.")
        return 0
    except (AudioProductionError, KeyboardInterrupt, EOFError) as error:
        print(str(error) if isinstance(error, AudioProductionError) else "Execução interrompida; recibos preservados. Use --inspect antes de retomar.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
