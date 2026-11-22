#!/usr/bin/env python3
"""Roblox Open Cloud uploads for the CyberOutlaw menu, with no external dependencies.

Only ``upload`` sends requests. CLI credentials are read with getpass on a TTY.
The media manifest and upload receipts bind assets to the fixed destination.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import timezone
from email.utils import parsedate_to_datetime
import fcntl
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import secrets
import struct
import tempfile
import time
from typing import Mapping
import urllib.error
import urllib.parse
import urllib.request
import wave
import xml.etree.ElementTree as ET


TARGET = {"userId": "1357078972", "universeId": "10774214423", "placeId": "122033314086516"}
ASSETS_URL = "https://apis.roblox.com/assets/v1"
GRANT_URL = "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions"
MAX_BYTES = 20_000_000  # Conservative decimal MB; audio docs require less than 20 MB.
_SHA = re.compile(r"[0-9a-f]{64}\Z")
_ID = re.compile(r"[1-9][0-9]{0,19}\Z")
_OPERATION = re.compile(r"operations/[A-Za-z0-9_-]{1,200}\Z")
_KEY = re.compile(r"[A-Za-z0-9_.:-]{1,128}\Z")
_TRANSIENT = {429, 500, 502, 503, 504}
_FORMATS = {
    "Audio": {".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".wav": "audio/wav", ".flac": "audio/flac"},
    "Image": {".png": "image/png", ".jpeg": "image/jpeg", ".jpg": "image/jpeg", ".bmp": "image/bmp", ".tga": "image/tga"},
    "Decal": {".png": "image/png", ".jpeg": "image/jpeg", ".jpg": "image/jpeg", ".bmp": "image/bmp", ".tga": "image/tga"},
    "Model": {".fbx": "model/fbx", ".gltf": "model/gltf+json", ".glb": "model/gltf-binary",
              ".rbxm": "model/x-rbxm", ".rbxmx": "model/x-rbxm"},
    "Animation": {".rbxm": "model/x-rbxm", ".rbxmx": "model/x-rbxm"},
}


@dataclass(frozen=True)
class HttpResponse:
    status: int
    headers: Mapping[str, str]
    body: bytes


def _safe_url(url: str) -> None:
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "https" or parsed.hostname != "apis.roblox.com"
            or parsed.port not in (None, 443) or parsed.username or parsed.password
            or parsed.query or parsed.fragment):
        raise ValueError("Only the fixed Roblox HTTPS API origin is allowed")
    path = parsed.path
    allowed = path in ("/assets/v1/assets", "/asset-permissions-api/v1/assets/permissions")
    allowed = allowed or bool(re.fullmatch(r"/assets/v1/assets/[1-9][0-9]{0,19}", path))
    allowed = allowed or bool(re.fullmatch(r"/assets/v1/operations/[A-Za-z0-9_-]{1,200}", path))
    if not allowed:
        raise ValueError("Unrecognized Roblox API path")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class UrllibTransport:
    """TLS verification enabled; redirects and environment proxies disabled.

    Injectable transports must expose this same request signature, returning an
    HttpResponse. Network errors should raise OSError or TimeoutError.
    """

    def request(self, method, url, headers, body=None, timeout=30):
        _safe_url(url)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect())
        request = urllib.request.Request(url, data=body, headers=dict(headers), method=method)
        try:
            response = opener.open(request, timeout=timeout)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            payload = response.read(2_000_001)
            if len(payload) > 2_000_000:
                raise OSError("Roblox response exceeds the local response limit")
            return HttpResponse(response.status, dict(response.headers), payload)


def _json(data: bytes):
    def reject_constant(_):
        raise ValueError("Non-finite JSON number")
    return json.loads(data.decode("utf-8"), parse_constant=reject_constant)


def _read_bytes(base: Path, entry: dict) -> bytes:
    path = Path(entry["path"])
    if path.is_absolute() or ".." in path.parts:
        raise ValueError("asset path must be relative and stay inside the manifest directory")
    resolved = (base / path).resolve()
    if not resolved.is_relative_to(base.resolve()) or not resolved.is_file():
        raise ValueError("asset path is missing or resolves outside the manifest directory")
    if not 0 < resolved.stat().st_size < MAX_BYTES:
        raise ValueError("asset size must be greater than zero and less than 20 MB")
    data = resolved.read_bytes()
    if len(data) >= MAX_BYTES or hashlib.sha256(data).hexdigest() != entry["sha256"]:
        raise ValueError("asset sha256 mismatch: regenerate the manifest after changing a file")
    return data


def _wav_info(data: bytes):
    try:
        with wave.open(io.BytesIO(data), "rb") as audio:
            frames, rate, channels = audio.getnframes(), audio.getframerate(), audio.getnchannels()
            if audio.getcomptype() != "NONE" or len(audio.readframes(frames)) < frames * channels * audio.getsampwidth():
                raise ValueError("WAV contains truncated or compressed samples")
            return frames / rate, rate, channels
    except (wave.Error, EOFError, ZeroDivisionError) as error:
        raise ValueError("Invalid WAV content") from error


def _audio_info(data: bytes, extension: str):
    if extension == ".wav":
        return _wav_info(data)
    if extension == ".flac":
        if len(data) < 42 or data[:4] != b"fLaC" or data[4] & 0x7F or int.from_bytes(data[5:8], "big") != 34:
            raise ValueError("Invalid FLAC STREAMINFO")
        packed = int.from_bytes(data[18:26], "big")
        rate = packed >> 44
        channels = ((packed >> 41) & 7) + 1
        samples = packed & ((1 << 36) - 1)
        return samples / rate if rate else 0, rate, channels
    if extension == ".ogg":
        cursor, packet, first, stream_id, granule = 0, bytearray(), None, None, 0
        while cursor < len(data):
            if data[cursor:cursor + 4] != b"OggS" or cursor + 27 > len(data) or data[cursor + 4] != 0:
                raise ValueError("Invalid OGG page")
            current_id = data[cursor + 14:cursor + 18]
            if stream_id is not None and current_id != stream_id:
                raise ValueError("OGG must contain a single audio stream")
            stream_id = current_id
            count = data[cursor + 26]
            segments = data[cursor + 27:cursor + 27 + count]
            offset = cursor + 27 + count
            end = offset + sum(segments)
            if len(segments) != count or end > len(data):
                raise ValueError("Truncated OGG page")
            for length in segments:
                if first is None:
                    packet.extend(data[offset:offset + length])
                    if length < 255:
                        first = bytes(packet)
                offset += length
            current_granule = int.from_bytes(data[cursor + 6:cursor + 14], "little")
            if current_granule != (1 << 64) - 1:
                granule = max(granule, current_granule)
            cursor = end
        if first and first.startswith(b"\x01vorbis") and len(first) >= 16:
            rate, channels, skip = int.from_bytes(first[12:16], "little"), first[11], 0
        elif first and first.startswith(b"OpusHead") and len(first) >= 19:
            rate, channels, skip = 48000, first[9], int.from_bytes(first[10:12], "little")
        else:
            raise ValueError("OGG must contain Vorbis or Opus audio")
        return (granule - skip) / rate if rate else 0, rate, channels
    # Parse MPEG Layer III frames rather than trusting filename or duration metadata.
    cursor, duration, max_rate, channels, frame_count = 0, 0.0, 0, 0, 0
    if data.startswith(b"ID3"):
        if len(data) < 10 or any(value & 128 for value in data[6:10]):
            raise ValueError("Invalid MP3 ID3 header")
        tag_size = sum(value << shift for value, shift in zip(data[6:10], (21, 14, 7, 0)))
        cursor = 10 + tag_size + (10 if data[5] & 0x10 else 0)
    while cursor < len(data):
        if len(data) - cursor == 128 and data[cursor:cursor + 3] == b"TAG":
            break
        if cursor + 4 > len(data):
            raise ValueError("Truncated MP3 frame")
        header = int.from_bytes(data[cursor:cursor + 4], "big")
        version, layer, bitrate_index, rate_index = (header >> 19) & 3, (header >> 17) & 3, (header >> 12) & 15, (header >> 10) & 3
        if header >> 21 != 0x7FF or version == 1 or layer != 1 or bitrate_index in (0, 15) or rate_index == 3:
            raise ValueError("Invalid MP3 frame header")
        rates = (44100, 48000, 32000)
        rate = rates[rate_index] // (1 if version == 3 else 2 if version == 2 else 4)
        bitrates = (0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320) if version == 3 else (0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160)
        size = (144000 if version == 3 else 72000) * bitrates[bitrate_index] // rate + ((header >> 9) & 1)
        if cursor + size > len(data):
            raise ValueError("Truncated MP3 frame")
        duration += (1152 if version == 3 else 576) / rate
        max_rate, channels = max(max_rate, rate), max(channels, 1 if (header >> 6) & 3 == 3 else 2)
        frame_count += 1
        cursor += size
    if not frame_count:
        raise ValueError("MP3 contains no audio frames")
    return duration, max_rate, channels


def _image_dimensions(data: bytes, extension: str):
    if extension == ".png":
        if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError("Invalid PNG content")
        return struct.unpack(">II", data[16:24])
    if extension == ".bmp":
        if len(data) < 26 or data[:2] != b"BM":
            raise ValueError("Invalid BMP content")
        if int.from_bytes(data[14:18], "little") == 12:
            return struct.unpack("<HH", data[18:22])
        width, height = struct.unpack("<ii", data[18:26])
        return width, abs(height)
    if extension == ".tga":
        if len(data) < 18 or data[2] not in (1, 2, 3, 9, 10, 11) or data[16] not in (8, 16, 24, 32):
            raise ValueError("Invalid TGA content")
        return struct.unpack("<HH", data[12:16])
    if not data.startswith(b"\xff\xd8"):
        raise ValueError("Invalid JPEG content")
    cursor = 2
    while cursor + 4 <= len(data):
        if data[cursor] != 255:
            raise ValueError("Invalid JPEG marker")
        while cursor < len(data) and data[cursor] == 255:
            cursor += 1
        if cursor + 3 > len(data):
            break
        marker = data[cursor]
        cursor += 1
        length = int.from_bytes(data[cursor:cursor + 2], "big")
        if length < 2 or cursor + length > len(data):
            break
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF) and length >= 7:
            height, width = struct.unpack(">HH", data[cursor + 3:cursor + 7])
            return width, height
        cursor += length
    raise ValueError("JPEG dimensions were not found")


def _validate_content(data: bytes, entry: dict) -> None:
    extension = Path(entry["path"]).suffix.lower()
    kind = entry["assetType"]
    if kind == "Audio":
        duration, rate, channels = _audio_info(data, extension)
        if not 0 < duration < 420:
            raise ValueError("Audio duration must be greater than zero and less than seven minutes")
        if rate > 48000 or channels not in (1, 2, 3, 6):
            raise ValueError("Audio must be at most 48 kHz and use 1, 2, 3 or 6 channels")
        declared = entry.get("durationSeconds", duration)
        if isinstance(declared, bool) or not isinstance(declared, (float, int)) or not math.isfinite(declared) or abs(declared - duration) > 0.1:
            raise ValueError("Audio durationSeconds does not match the file duration")
        entry["durationSeconds"] = duration
    elif kind in ("Image", "Decal"):
        dimensions = _image_dimensions(data, extension)
        if any(not 0 < dimension < 8000 for dimension in dimensions):
            raise ValueError("Image dimensions must both be smaller than 8000 pixels")
    elif extension in (".rbxmx", ".rbxm"):
        if extension == ".rbxm":
            if not data.startswith(b"<roblox!\x89\xff\r\n\x1a\n") or len(data) < 32:
                raise ValueError("Invalid binary RBXM content")
        else:
            if b"<!DOCTYPE" in data.upper() or b"<!ENTITY" in data.upper():
                raise ValueError("RBXMX declarations are not accepted")
            try:
                root = ET.fromstring(data)
            except ET.ParseError as error:
                raise ValueError("Invalid RBXMX content") from error
            if root.tag != "roblox" or not root.findall(".//Item"):
                raise ValueError("RBXMX must contain Roblox instances")
            if kind == "Animation" and not any(item.get("class") == "KeyframeSequence" for item in root.iter("Item")):
                raise ValueError("Animation RBXMX must contain a KeyframeSequence")
    elif extension == ".fbx":
        binary = data.startswith(b"Kaydara FBX Binary  \x00\x1a\x00") and len(data) >= 27
        ascii_fbx = data.lstrip().startswith(b"; FBX") and b"FBXHeaderExtension" in data[:4096]
        if not binary and not ascii_fbx:
            raise ValueError("Invalid FBX content")
    else:
        if extension == ".glb":
            if len(data) < 20 or data[:4] != b"glTF":
                raise ValueError("Invalid GLB header")
            version, total = struct.unpack("<II", data[4:12])
            length, chunk_type = struct.unpack("<I4s", data[12:20])
            if version != 2 or total != len(data) or chunk_type != b"JSON" or length % 4 or 20 + length > len(data):
                raise ValueError("Invalid GLB length, version or JSON chunk")
            try:
                gltf = _json(data[20:20 + length])
            except (ValueError, UnicodeError) as error:
                raise ValueError("Invalid GLB JSON") from error
            cursor = 20 + length
            while cursor < len(data):
                if cursor + 8 > len(data):
                    raise ValueError("Truncated GLB chunk header")
                chunk_length, next_type = struct.unpack("<I4s", data[cursor:cursor + 8])
                if chunk_length % 4 or cursor + 8 + chunk_length > len(data) or next_type == b"JSON":
                    raise ValueError("Invalid GLB chunk length or duplicate JSON chunk")
                cursor += 8 + chunk_length
        else:
            try:
                gltf = _json(data)
            except (ValueError, UnicodeError) as error:
                raise ValueError("Invalid glTF JSON") from error
        if not isinstance(gltf, dict) or gltf.get("asset", {}).get("version") != "2.0":
            raise ValueError("Model must contain glTF 2.0 metadata")
        for resource in gltf.get("buffers", []) + gltf.get("images", []):
            if "uri" in resource and not str(resource["uri"]).startswith("data:"):
                raise ValueError("glTF external resources must be embedded before upload")


def validate_manifest(manifest_path) -> dict:
    """Validate all local bytes before requests; never contacts Roblox or writes."""
    manifest = Path(manifest_path).resolve()
    try:
        plan = _json(manifest.read_bytes())
    except (ValueError, UnicodeError) as error:
        raise ValueError("Invalid JSON manifest") from error
    if not isinstance(plan, dict) or not isinstance(plan.get("target"), dict):
        raise ValueError("manifest target is required")
    target = {name: str(plan["target"].get(name, "")) for name in TARGET}
    if target != TARGET or any(name not in TARGET for name in plan["target"]):
        raise ValueError("manifest target must match the confirmed CyberOutlaw creator, universe and Place")
    if not isinstance(plan.get("assets"), list) or not plan["assets"]:
        raise ValueError("manifest assets must be a nonempty list")
    assets, keys, digests = [], set(), {}
    for raw in plan["assets"]:
        if not isinstance(raw, dict):
            raise ValueError("asset entry must be an object")
        key = raw.get("key")
        if not isinstance(key, str) or not _KEY.fullmatch(key) or key in keys:
            raise ValueError("asset key must be unique and use letters, numbers, _, ., :, or -")
        keys.add(key)
        kind, path = raw.get("assetType"), raw.get("path")
        if kind not in _FORMATS or not isinstance(path, str) or not path:
            raise ValueError("assetType or path is invalid")
        extension = Path(path).suffix.lower()
        if extension not in _FORMATS[kind] or raw.get("contentType") != _FORMATS[kind][extension]:
            raise ValueError("asset contentType does not match its assetType and file extension")
        digest = raw.get("sha256", "")
        if not isinstance(digest, str) or not _SHA.fullmatch(digest):
            raise ValueError("asset sha256 must be a lowercase SHA-256 digest")
        signature = (kind, raw["contentType"])
        if digest in digests and digests[digest] != signature:
            raise ValueError("The same sha256 cannot have conflicting asset types")
        digests[digest] = signature
        display_name, description = raw.get("displayName"), raw.get("description", "")
        if not isinstance(display_name, str) or not display_name.strip():
            raise ValueError("asset displayName is required")
        if not isinstance(description, str) or len(description) > 1000:
            raise ValueError("asset description must be at most 1000 characters")
        # The tool creates assets; any IDs in the source plan are informational only.
        entry = {"key": key, "path": path, "assetType": kind, "contentType": raw["contentType"],
                 "sha256": digest, "displayName": display_name, "description": description}
        if "durationSeconds" in raw:
            entry["durationSeconds"] = raw["durationSeconds"]
        _validate_content(_read_bytes(manifest.parent, entry), entry)
        assets.append(entry)
    return {"schemaVersion": 1, "target": target, "assets": assets}


def _atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            os.chmod(temporary, 0o600)
            json.dump(value, handle, ensure_ascii=False, indent=2, allow_nan=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


@contextmanager
def _locked(state: Path):
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / ".lock").open("a+") as handle:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError("Another asset uploader is using this state directory") from error
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def _multipart(entry: dict, data: bytes):
    boundary = "cyberoutlaw-" + secrets.token_hex(24)
    while boundary.encode() in data:
        boundary = "cyberoutlaw-" + secrets.token_hex(24)
    request = {"assetType": entry["assetType"], "displayName": entry["displayName"],
               "description": entry["description"],
               "creationContext": {"creator": {"userId": TARGET["userId"]}, "expectedPrice": 0}}
    encoded = json.dumps(request, ensure_ascii=False).encode("utf-8")
    opening = ("--" + boundary + '\r\nContent-Disposition: form-data; name="request"\r\n'
               'Content-Type: application/json; charset=utf-8\r\n\r\n').encode()
    file_header = ("\r\n--" + boundary + '\r\nContent-Disposition: form-data; name="fileContent"; filename="asset'
                   + Path(entry["path"]).suffix.lower() + '"\r\nContent-Type: ' + entry["contentType"] + '\r\n\r\n').encode()
    body = opening + encoded + file_header + data + ("\r\n--" + boundary + "--\r\n").encode()
    return body, "multipart/form-data; boundary=" + boundary


def _canonical_type(value):
    return str(value).removeprefix("ASSET_TYPE_").replace("_", "").lower()


def _apply_asset(receipt: dict, metadata: dict, entry: dict) -> None:
    creator = metadata.get("creationContext", {}).get("creator", {}) if isinstance(metadata, dict) else {}
    asset_id = str(metadata.get("assetId", "")) if isinstance(metadata, dict) else ""
    if not asset_id and isinstance(metadata, dict):
        path = str(metadata.get("path", ""))
        if re.fullmatch(r"assets/[1-9][0-9]{0,19}", path):
            asset_id = path.split("/")[1]
    valid = (bool(_ID.fullmatch(asset_id)) and str(creator.get("userId", "")) == TARGET["userId"]
             and "groupId" not in creator
             and _canonical_type(metadata.get("assetType")) == entry["assetType"].lower()
             and (not metadata.get("path") or metadata["path"] == "assets/" + asset_id)
             and (not receipt.get("assetId") or receipt["assetId"] == asset_id))
    if not valid:
        receipt.update(status="verification_failed", lastErrorCode="asset_metadata_mismatch")
        return
    receipt["assetId"] = asset_id
    state = str(metadata.get("moderationResult", {}).get("moderationState", "Unknown")).removeprefix("MODERATION_STATE_").lower()
    moderation = {"approved": "Approved", "rejected": "Rejected", "reviewing": "Reviewing"}.get(state, "Unknown")
    receipt["moderationState"] = moderation
    if moderation == "Approved":
        receipt["status"] = "ready" if receipt.get("permissionStatus") == "granted" else "pending_permission"
    else:
        receipt["status"] = "rejected" if moderation == "Rejected" else "pending_moderation"


def _ingest_operation(receipt: dict, operation: dict, entry: dict) -> None:
    if not isinstance(operation, dict) or not _OPERATION.fullmatch(str(operation.get("path", ""))):
        raise ValueError("Invalid operation path")
    if receipt.get("operationPath") and operation["path"] != receipt["operationPath"]:
        raise ValueError("Operation path changed")
    receipt["operationPath"] = operation["path"]
    receipt["status"] = "uploading"
    if operation.get("done") is True:
        if operation.get("error") is not None:
            receipt["status"] = "failed"
            code = operation["error"].get("code") if isinstance(operation["error"], dict) else None
            receipt["lastErrorCode"] = "operation_error_" + str(code) if isinstance(code, int) else "operation_error"
        elif isinstance(operation.get("response"), dict):
            _apply_asset(receipt, operation["response"], entry)
        else:
            raise ValueError("Completed operation has no asset response")


class _Session:
    def __init__(self, transport, key, max_polls, poll_interval, max_wait_seconds, sleep, now):
        self.transport, self.key = transport, key
        self.max_polls, self.interval, self.max_wait = max_polls, poll_interval, max_wait_seconds
        self.sleep, self.now = sleep, now
        self.started, self.slept = now(), 0.0

    def request(self, method, url, body=None, content_type=None):
        _safe_url(url)  # Apply the origin policy to injected transports too.
        headers = {"x-api-key": self.key, "Accept": "application/json", "User-Agent": "CyberOutlaw-Termux-Assets/2"}
        if content_type:
            headers["Content-Type"] = content_type
        return self.transport.request(method, url, headers, body=body, timeout=30)

    def delay(self, response):
        value = next((str(v) for k, v in response.headers.items() if k.lower() == "retry-after"), None)
        if value is None:
            return self.interval, False
        try:
            seconds = float(value)
            if math.isfinite(seconds) and seconds >= 0:
                return seconds, True
        except ValueError:
            try:
                date = parsedate_to_datetime(value)
                if date.tzinfo is None:
                    date = date.replace(tzinfo=timezone.utc)
                return max(0.0, date.timestamp() - self.now()), True
            except (ValueError, TypeError, OverflowError):
                pass
        return self.interval, False

    def wait(self, delay):
        elapsed = max(self.slept, self.now() - self.started)
        if delay > 60 or elapsed + delay > self.max_wait:
            return False
        self.sleep(delay)
        self.slept += delay
        return True


def _poll_or_refresh(receipt, entry, save, session, *, metadata=False):
    url = ASSETS_URL + ("/assets/" + receipt["assetId"] if metadata else "/" + receipt["operationPath"])
    attempts = min(3, session.max_polls) if metadata else session.max_polls
    for attempt in range(attempts):
        try:
            response = session.request("GET", url)
        except (OSError, TimeoutError):
            receipt["lastErrorCode"] = "read_network_error"
            save()
            return
        if response.status == 200:
            try:
                payload = _json(response.body)
                if metadata:
                    _apply_asset(receipt, payload, entry)
                else:
                    _ingest_operation(receipt, payload, entry)
            except (ValueError, UnicodeError, TypeError, AttributeError):
                receipt["lastErrorCode"] = "invalid_read_response"
                save()
                return
            if metadata or receipt["status"] != "uploading":
                save()
                return
        else:
            receipt["lastErrorCode"] = "http_" + str(response.status)
            if response.status not in _TRANSIENT:
                save()
                return
        delay, explicit = session.delay(response)
        if explicit:
            receipt["nextPollAt"] = session.now() + delay
        save()
        if attempt + 1 == attempts or not session.wait(delay):
            return
        receipt.pop("nextPollAt", None)


def _grant(receipt, save, session):
    receipt.update(status="pending_permission", permissionStatus="submitting")
    save()
    payload = {"subjectType": "Universe", "subjectId": TARGET["universeId"], "action": "Use",
               "requests": [{"assetId": int(receipt["assetId"]), "grantToDependencies": True}]}
    try:
        response = session.request("PATCH", GRANT_URL, json.dumps(payload).encode(), "application/json")
    except (OSError, TimeoutError):
        receipt.update(permissionStatus="uncertain", lastErrorCode="grant_network_error")
        save()
        return
    if response.status == 200:
        try:
            result = _json(response.body)
            successes = {str(value) for value in (result.get("successAssetIds") or [])}
            errors = {str(error.get("assetId")) for error in (result.get("errors") or [])}
            granted = receipt["assetId"] in successes and receipt["assetId"] not in errors
        except (ValueError, UnicodeError, AttributeError, TypeError):
            granted = False
        if granted:
            receipt.update(permissionStatus="granted", status="ready")
            receipt.pop("lastErrorCode", None)
        else:
            receipt.update(permissionStatus="error", lastErrorCode="grant_not_confirmed")
    else:
        receipt.update(permissionStatus="uncertain" if response.status >= 500 or 300 <= response.status < 400 else "error",
                       lastErrorCode="grant_http_" + str(response.status))
        delay, explicit = session.delay(response)
        if explicit:
            receipt["nextPollAt"] = session.now() + delay
    save()


def _catalog(plan, receipts):
    result = {"schemaVersion": 1, "target": dict(TARGET), "assets": [], "runtimeMap": {}}
    for entry in plan["assets"]:
        receipt = receipts.get(entry["sha256"], {})
        row = {"key": entry["key"], "sha256": entry["sha256"], "assetType": entry["assetType"],
               "contentType": entry["contentType"], "sourcePath": entry["path"],
               "assetId": receipt.get("assetId"), "status": receipt.get("status", "awaiting_upload"),
               "moderationState": receipt.get("moderationState", "Unknown"),
               "permissionStatus": receipt.get("permissionStatus", "pending"),
               "operationPath": receipt.get("operationPath")}
        for field in ("lastErrorCode", "nextPollAt"):
            if field in receipt:
                row[field] = receipt[field]
        result["assets"].append(row)
        if (row["status"] == "ready" and _ID.fullmatch(str(row["assetId"]))
                and row["moderationState"] == "Approved" and row["permissionStatus"] == "granted"):
            result["runtimeMap"][entry["key"]] = "rbxassetid://" + row["assetId"]
    return result


def _check_receipt(receipt, entry):
    statuses = {"submitting", "uncertain_upload", "uploading", "pending_moderation", "pending_permission",
                "ready", "failed", "rejected", "verification_failed"}
    valid = (isinstance(receipt, dict) and receipt.get("schemaVersion") == 1
             and receipt.get("sha256") == entry["sha256"] and receipt.get("target") == TARGET
             and receipt.get("assetType") == entry["assetType"] and receipt.get("contentType") == entry["contentType"]
             and receipt.get("status") in statuses)
    if valid and receipt.get("assetId") is not None:
        valid = isinstance(receipt["assetId"], str) and bool(_ID.fullmatch(receipt["assetId"]))
    if valid and receipt.get("operationPath") is not None:
        valid = isinstance(receipt["operationPath"], str) and bool(_OPERATION.fullmatch(receipt["operationPath"]))
    if valid and "nextPollAt" in receipt:
        timestamp = receipt["nextPollAt"]
        valid = isinstance(timestamp, (float, int)) and not isinstance(timestamp, bool) and math.isfinite(timestamp)
    if valid and receipt["status"] == "uploading":
        valid = bool(receipt.get("operationPath"))
    if valid and receipt["status"] in ("pending_moderation", "pending_permission", "ready", "rejected"):
        valid = bool(receipt.get("assetId")) and bool(receipt.get("operationPath"))
    if valid and receipt["status"] == "ready":
        valid = receipt.get("moderationState") == "Approved" and receipt.get("permissionStatus") == "granted"
    if not valid:
        raise ValueError("Receipt is invalid or does not match manifest context; preserve the original receipt")


def upload_manifest(manifest_path, key, transport=None, *, state_dir=None, max_polls=12,
                    poll_interval=2.0, max_wait_seconds=60.0, sleep=time.sleep, now=time.time,
                    grant_permissions=True, progress=None) -> dict:
    """Create once per SHA, resume operations, then grant Universe Use permission.

    Returns and atomically writes ``manifest.parent / UPLOADED_ASSETS.json``.
    Never logs/persists the key, response bodies, exceptions, or request headers.
    An uncertain Create response is terminal until its operation is recovered.
    """
    if not isinstance(key, str) or not key or not key.isascii() or any(ord(c) < 33 or ord(c) > 126 for c in key):
        raise ValueError("API key must be nonempty printable ASCII with no whitespace")
    if (isinstance(max_polls, bool) or not isinstance(max_polls, int) or not 1 <= max_polls <= 1000
            or not math.isfinite(poll_interval) or poll_interval < 0
            or not math.isfinite(max_wait_seconds) or max_wait_seconds < 0):
        raise ValueError("Polling limits must be finite, nonnegative and bounded")
    manifest = Path(manifest_path).resolve()
    plan = validate_manifest(manifest)
    state = Path(state_dir).resolve() if state_dir else manifest.parent / ".asset_upload_state"
    session = _Session(transport or UrllibTransport(), key, max_polls, poll_interval, max_wait_seconds, sleep, now)
    receipts = {}
    with _locked(state):
        total = len(plan["assets"])
        for index, entry in enumerate(plan["assets"], 1):
            digest = entry["sha256"]
            if digest in receipts:
                continue
            path = state / (digest + ".json")
            receipt = None
            existing = path.exists()
            if existing:
                receipt = _json(path.read_bytes())
                _check_receipt(receipt, entry)
                if receipt.get("status") == "submitting":
                    receipt.update(status="uncertain_upload", lastErrorCode="interrupted_create")
            if progress:
                action = "Conferindo" if existing else "Enviando"
                progress(f"[{index}/{total}] {action} {entry['key']}…")
            if receipt is None:
                # Persist before sending: a kill or lost response must not cause a duplicate.
                receipt = {"schemaVersion": 1, "target": dict(TARGET), "sha256": digest,
                           "assetType": entry["assetType"], "contentType": entry["contentType"],
                           "assetId": None, "status": "submitting", "permissionStatus": "pending"}
                data = _read_bytes(manifest.parent, entry)  # Close the validation-to-upload file change window.
                body, content_type = _multipart(entry, data)
                _atomic_json(path, receipt)
                try:
                    response = session.request("POST", ASSETS_URL + "/assets", body, content_type)
                except (OSError, TimeoutError):
                    receipt.update(status="uncertain_upload", lastErrorCode="create_network_error")
                else:
                    if response.status in (200, 201, 202):
                        try:
                            _ingest_operation(receipt, _json(response.body), entry)
                        except (ValueError, UnicodeError, TypeError, AttributeError):
                            receipt.update(status="uploading" if receipt.get("operationPath") else "uncertain_upload",
                                           lastErrorCode="invalid_create_response")
                    elif 400 <= response.status < 500 and response.status != 408:
                        receipt.update(status="failed", lastErrorCode="create_http_" + str(response.status))
                    else:
                        receipt.update(status="uncertain_upload", lastErrorCode="create_http_" + str(response.status))
                    delay, explicit = session.delay(response)
                    if explicit:
                        receipt["nextPollAt"] = session.now() + delay
                _atomic_json(path, receipt)
            save = lambda: _atomic_json(path, receipt)
            receipts[digest] = receipt
            if receipt.get("nextPollAt", 0) > now():
                save()
                continue
            receipt.pop("nextPollAt", None)
            if receipt.get("status") == "uploading":
                _poll_or_refresh(receipt, entry, save, session)
            elif existing and receipt.get("status") in ("pending_moderation", "pending_permission"):
                _poll_or_refresh(receipt, entry, save, session, metadata=True)
            if receipt.get("status") == "pending_permission" and grant_permissions:
                _grant(receipt, save, session)
            save()
        result = _catalog(plan, receipts)
        _atomic_json(manifest.parent / "UPLOADED_ASSETS.json", result)
        if progress:
            for row in result["assets"]:
                detail = f" ({row['lastErrorCode']})" if row.get("lastErrorCode") else ""
                progress(f"{row['key']}: {row['status']}{detail}")
    return result


def _recovery_context(manifest_path, sha256, state_dir):
    manifest = Path(manifest_path).resolve()
    plan = validate_manifest(manifest)
    entry = next((item for item in plan["assets"] if item["sha256"] == sha256), None)
    if entry is None:
        raise ValueError("sha256 must identify an unchanged asset in the manifest")
    state = Path(state_dir).resolve() if state_dir else manifest.parent / ".asset_upload_state"
    return entry, state, state / (sha256 + ".json")


def recover_operation(manifest_path, sha256, operation_path, *, state_dir=None):
    """Attach an already known official operation to an uncertain receipt.

    Local only: the next upload call verifies its result. Does not create an
    asset, accept an arbitrary URL, or reset a known completed asset.
    """
    if not isinstance(operation_path, str) or not _OPERATION.fullmatch(operation_path):
        raise ValueError("Use the official relative operations/ID path")
    entry, state, path = _recovery_context(manifest_path, sha256, state_dir)
    with _locked(state):
        receipt = _json(path.read_bytes())
        _check_receipt(receipt, entry)
        if receipt["status"] not in ("submitting", "uncertain_upload"):
            raise ValueError("Only an uncertain Create receipt can receive a recovered operation")
        receipt.update(status="uploading", operationPath=operation_path)
        receipt.pop("lastErrorCode", None)
        _atomic_json(path, receipt)
    return receipt


def reset_rejected(manifest_path, sha256, *, state_dir=None, now=time.time):
    """Allow an explicit retry only after a definitive HTTP 4xx Create refusal."""
    entry, state, path = _recovery_context(manifest_path, sha256, state_dir)
    with _locked(state):
        receipt = _json(path.read_bytes())
        _check_receipt(receipt, entry)
        code = receipt.get("lastErrorCode", "")
        if (receipt["status"] != "failed" or receipt.get("assetId") or receipt.get("operationPath")
                or not re.fullmatch(r"create_http_4[0-9]{2}", code) or code == "create_http_408"):
            raise ValueError("Only a definitive HTTP 4xx Create rejection can be reset")
        if receipt.get("nextPollAt", 0) > now():
            raise ValueError("Retry-After has not elapsed")
        archive = state / "rejected" / (sha256 + "-" + secrets.token_hex(8) + ".json")
        _atomic_json(archive, receipt)
        path.unlink()
        directory = os.open(state, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Valida ou envia assets do CyberOutlaw via Open Cloud.")
    parser.add_argument("command", choices=("check", "upload", "attach-operation", "retry-rejected"))
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--state-dir", type=Path)
    parser.add_argument("--max-polls", type=int, default=12)
    parser.add_argument("--sha256")
    parser.add_argument("--operation")
    args = parser.parse_args(argv)
    if args.command == "check":
        plan = validate_manifest(args.manifest)
        print(json.dumps({"valid": True, "assets": len(plan["assets"]), "target": plan["target"]}, ensure_ascii=False))
        return 0
    if args.command in ("attach-operation", "retry-rejected"):
        if not args.sha256:
            parser.error("--sha256 e obrigatorio para recuperar um recibo especifico")
        if args.command == "attach-operation":
            if not args.operation:
                parser.error("--operation operations/ID e obrigatorio")
            recover_operation(args.manifest, args.sha256, args.operation, state_dir=args.state_dir)
        else:
            reset_rejected(args.manifest, args.sha256, state_dir=args.state_dir)
        print(json.dumps({"updatedReceipt": args.sha256, "nextCommand": "upload"}))
        return 0
    import getpass
    import sys
    import warnings
    if not sys.stdin.isatty():
        parser.error("Execute upload em um terminal interativo; a chave so pode ser lida sem eco pelo getpass.")
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        try:
            key = getpass.getpass("Roblox Open Cloud API key (oculta): ")
        except getpass.GetPassWarning:
            parser.error("Este terminal nao oferece entrada oculta. Abra o Termux diretamente.")
    result = upload_manifest(args.manifest, key, state_dir=args.state_dir, max_polls=args.max_polls)
    del key
    print(json.dumps({"catalog": str(args.manifest.resolve().parent / "UPLOADED_ASSETS.json"),
                      "assets": [{"key": row["key"], "assetId": row["assetId"], "status": row["status"]}
                                 for row in result["assets"]]}, ensure_ascii=False, indent=2))
    return 0 if all(row["status"] == "ready" for row in result["assets"]) else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as error:
        # Local validation messages never contain API responses or credentials.
        print("Erro: " + str(error), file=__import__("sys").stderr)
        raise SystemExit(1)
