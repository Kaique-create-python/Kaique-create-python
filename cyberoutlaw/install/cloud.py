"""Fixed-destination Roblox Open Cloud transport."""

from dataclasses import dataclass
import gzip
import io
import json
import re
import time
from http.client import HTTPException
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener
import zlib

from .codec import Failure, MAX_FILE
from .patcher import BINARY_MAGIC


API = "https://apis.roblox.com"
PLACE_ID = 122033314086516
UNIVERSE_ID = 10774214423
CREATOR_ID = 1357078972
TARGET = {"place": PLACE_ID, "universe": UNIVERSE_ID, "creator": CREATOR_ID}
PUBLISH_ROUTE = f"/universes/v1/{UNIVERSE_ID}/places/{PLACE_ID}/versions?versionType=Published"
MAX_JSON = 2 * 1024 * 1024
TRANSIENT = {408, 429, 500, 502, 503, 504}
DEFINITE_REJECTIONS = {400, 401, 403, 404, 405, 413, 415, 422}
REDIRECTS = {301, 302, 303, 307, 308}


@dataclass(frozen=True)
class Version:
    number: int
    published: bool


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def unique_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("campo JSON repetido")
        result[key] = value
    return result


def _json(raw):
    try:
        return json.loads(raw, object_pairs_hook=unique_fields)
    except (ValueError, RecursionError):
        raise Failure("O Roblox devolveu uma resposta JSON inválida.") from None


def version_number(value):
    if type(value) not in (int, str) or not re.fullmatch(r"[1-9][0-9]{0,18}", str(value)):
        raise Failure("A API não forneceu um número de versão válido.")
    number = int(value)
    if number > 2**63 - 1:
        raise Failure("A API forneceu um número de versão acima do limite.")
    return number


def _validate_cdn(url):
    try:
        parsed = urlsplit(url)
        host = parsed.hostname or ""
        allowed = host == "rbxcdn.com" or host.endswith(".rbxcdn.com")
        if host == "assetdelivery.roblox.com":
            allowed = parsed.path in ("/v1/asset", "/v1/asset/") and re.fullmatch(
                r"(?:id=[1-9][0-9]*(?:&version=[1-9][0-9]*)?|assetversionid=[1-9][0-9]*)",
                parsed.query,
            )
        if (
            parsed.scheme == "https" and parsed.port in (None, 443) and allowed
            and parsed.username is None and parsed.password is None and not parsed.fragment
            and not any(ord(char) < 32 for char in url)
        ):
            return
    except ValueError:
        pass
    raise Failure("O Roblox retornou um endereço de download fora dos servidores permitidos.")


def _unpack(raw, encoding, limit):
    if raw.startswith(b"\x1f\x8b"):
        with gzip.GzipFile(fileobj=io.BytesIO(raw)) as stream:
            raw = stream.read(limit + 1)
    elif encoding == "deflate":
        decoder = zlib.decompressobj()
        raw = decoder.decompress(raw, limit + 1)
        if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
            raise Failure("A resposta comprimida do Roblox está incompleta.")
    elif encoding not in ("", "identity"):
        raise Failure("O Roblox usou uma compressão HTTP incompatível.")
    if len(raw) > limit:
        raise Failure("O arquivo recebido do Roblox excede o limite de tamanho.")
    return raw


class Cloud:
    def __init__(self, key, opener=None, sleeper=time.sleep):
        self.key = key
        self.opener = opener if opener is not None else build_opener(ProxyHandler({}), _NoRedirect())
        self.sleep = sleeper

    def _request(self, url, description, *, authenticated=False, body=None, media="application/json",
                 limit=MAX_JSON, redirect=False):
        writing = body is not None
        if authenticated and not url.startswith(API + "/"):
            raise Failure("Destino autenticado fora da API do Roblox.")
        headers = {"User-Agent": "CyberOutlaw-Termux/1.0", "Accept-Encoding": "identity"}
        if authenticated:
            headers["X-Api-Key"] = self.key
        if writing:
            headers["Content-Type"] = media
        if limit == MAX_JSON:
            headers["Accept"] = "application/json"
        request = Request(url, data=body, headers=headers, method="POST" if writing else "GET")
        attempts = 1 if writing else 3
        for attempt in range(attempts):
            try:
                with self.opener.open(request, timeout=60) as response:
                    raw = response.read(limit + 1)
                    encoding = response.headers.get("Content-Encoding", "").strip().lower()
                if len(raw) > limit:
                    raise Failure("A resposta do Roblox excede o limite de tamanho.")
                return _unpack(raw, encoding, limit), None
            except HTTPError as exc:
                status = exc.code
                location = exc.headers.get("Location") if exc.headers is not None else None
                exc.close()
                if not writing and redirect and status in REDIRECTS and isinstance(location, str):
                    return None, location
                if status not in TRANSIENT or attempt + 1 == attempts:
                    raise Failure(f"HTTP {status} ao {description}.", code=status) from None
            except (URLError, TimeoutError, HTTPException, EOFError, OSError, zlib.error):
                if attempt + 1 == attempts:
                    raise Failure(f"A conexão falhou ao {description}.") from None
            self.sleep(2)
        raise AssertionError("request exhausted")

    def _get_json(self, url, description, authenticated=False):
        raw, _ = self._request(url, description, authenticated=authenticated)
        return _json(raw)

    def validate_destination(self):
        mapping = self._get_json(
            f"{API}/universes/v1/places/{PLACE_ID}/universe", "identificar o place"
        )
        if not isinstance(mapping, dict) or mapping.get("universeId") != UNIVERSE_ID:
            raise Failure("A API pública não confirmou o universo do place CyberOutlaw.")
        data = self._get_json(
            f"https://games.roblox.com/v1/games?universeIds={UNIVERSE_ID}",
            "confirmar o place inicial e o criador",
        )
        games = data.get("data") if isinstance(data, dict) else None
        game = games[0] if isinstance(games, list) and len(games) == 1 else None
        creator = game.get("creator") if isinstance(game, dict) else None
        if (
            not isinstance(game, dict) or game.get("id") != UNIVERSE_ID
            or game.get("rootPlaceId") != PLACE_ID or not isinstance(creator, dict)
            or creator.get("id") != CREATOR_ID or creator.get("type") != "User"
        ):
            raise Failure("A API pública não confirmou o place inicial e o criador de CyberOutlaw.")

    def history(self):
        rows = []
        token = ""
        seen = set()
        pattern = re.compile(rf"assets/{PLACE_ID}/versions/([1-9][0-9]{{0,18}})")
        for _ in range(100):
            query = {"maxPageSize": 50}
            if token:
                query["pageToken"] = token
            data = self._get_json(
                f"{API}/assets/v1/assets/{PLACE_ID}/versions?{urlencode(query)}",
                "ler o histórico do place",
                authenticated=True,
            )
            if isinstance(data, list) and len(data) < 50:
                page, token = data, ""
            elif isinstance(data, dict) and isinstance(data.get("assetVersions"), list):
                if data.get("errors"):
                    raise Failure("A API relatou um erro no histórico do place.")
                page, token = data["assetVersions"], data.get("nextPageToken", "")
            else:
                raise Failure("O Roblox retornou um histórico do place incompleto ou inválido.")
            if len(page) > 50 or not isinstance(token, str) or len(token) > 4096:
                raise Failure("A página do histórico do place é inválida.")
            for entry in page:
                path = entry.get("path") if isinstance(entry, dict) else None
                match = pattern.fullmatch(path) if isinstance(path, str) else None
                if match is None:
                    raise Failure("O histórico contém uma versão de destino desconhecido.")
                version = version_number(match[1])
                published = entry.get("published", False)
                if type(published) is not bool or (rows and version >= rows[-1].number):
                    raise Failure("O histórico contém versões repetidas ou fora de ordem.")
                rows.append(Version(version, published))
            if not token:
                return rows
            if token in seen:
                raise Failure("A API repetiu uma página no histórico do place.")
            seen.add(token)
        raise Failure("O histórico não pôde ser lido por completo.")

    def download(self, version):
        version = version_number(version)
        url = f"{API}/asset-delivery-api/v1/assetId/{PLACE_ID}/version/{version}"
        raw, location = self._request(
            url, f"baixar a versão {version}", authenticated=True, limit=MAX_FILE, redirect=True
        )
        if raw is not None and raw.removeprefix(b"\xef\xbb\xbf").lstrip().startswith(b"{"):
            if len(raw) > MAX_JSON:
                raise Failure("Os metadados do backup excedem o limite de tamanho.")
            response = _json(raw)
            if not isinstance(response, dict) or response.get("errors"):
                raise Failure("O Roblox não devolveu os dados do backup.")
            if "assetTypeId" in response and str(response["assetTypeId"]) != "9":
                raise Failure("O Roblox identificou o arquivo como um tipo diferente de Place.")
            location = response.get("location")
            locations = response.get("locations")
            if not location and isinstance(locations, list):
                location = next(
                    (item["location"] for item in locations if isinstance(item, dict) and item.get("location")),
                    None,
                )
            if not isinstance(location, str) or not location:
                raise Failure("A API não forneceu o endereço do arquivo do place.")
            raw = None
        for _ in range(5):
            if raw is not None:
                return raw
            _validate_cdn(location)
            raw, location = self._request(
                location, f"transferir a versão {version}", limit=MAX_FILE, redirect=True
            )
        if raw is None:
            raise Failure("O download passou por redirecionamentos demais.")
        return raw

    def publish(self, raw):
        response, _ = self._request(
            API + PUBLISH_ROUTE, "enviar a publicação", authenticated=True, body=raw,
            media="application/octet-stream" if raw.startswith(BINARY_MAGIC) else "application/xml",
        )
        data = _json(response)
        return version_number(data.get("versionNumber") if isinstance(data, dict) else None)
