#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BIZARRE BATTLEGROUNDS - instalador __REVISAO__ (Roblox Open Cloud, sem Roblox Studio)

Como usar no Termux:
    cp ~/storage/downloads/__NOME_ARQUIVO__ ~ && cd ~ && python __NOME_ARQUIVO__ install

Outros comandos:
    python __NOME_ARQUIVO__ testar        -> confere o pacote sem internet
    python __NOME_ARQUIVO__ testar-nuvem  -> só o teste dentro do Roblox (NÃO publica)
    python __NOME_ARQUIVO__ publicar      -> publica o que o testar-nuvem aprovou
    python __NOME_ARQUIVO__ recibos       -> mostra as publicações já feitas
(install = testar-nuvem + pergunta se publica)

O que ele faz (nessa ordem):
  1) confere o próprio pacote (sha256 de cada arquivo)
  1b) confere a versão que está NO AR: se tiver script que este instalador não conhece
      (feito em outro lugar), ele PARA e avisa, para não apagar trabalho de ninguém
  2) envia as vozes dos Stands (ORA, ZA WARUDO, DORA...) - OPCIONAL: se o Roblox recusar,
     demorar ou a chave não tiver permissão, o jogo segue com o grito da biblioteca
  3) salva uma versão de TESTE (não publicada) e roda o teste isolado na nuvem:
     abre Morioh, monta os 6 Stands e faz uma luta de teste com TODOS os golpes
  4) só se o teste passar: publica e confere
A chave da Open Cloud é pedida escondida, nunca aparece na tela e nunca é salva.
Nada aqui apaga o Place nem o DataStore dos jogadores (as estatísticas só somam).
Os outros sons são da biblioteca liberada do Roblox (não precisam de envio).
"""
import base64
import getpass
import gzip
import hashlib
import io
import json
import os
import sys
import struct
import time
import urllib.error
import urllib.request
import uuid
import zipfile

REVISAO = "__REVISAO__"
JOGO = "BIZARRE BATTLEGROUNDS"
UNIVERSE_PADRAO = "10774214555"
PLACE_PADRAO = "108061345551908"
DONO_PADRAO = "1357078972"
API = os.environ.get("BB_API_BASE", "https://apis.roblox.com")
GAMES = os.environ.get("BB_GAMES_BASE", "https://games.roblox.com")
PASTA_RECIBOS = os.environ.get("BB_RECIBOS_DIR") or os.path.join(os.path.expanduser("~"), ".bizarre_instalador")
ARQ_RECIBOS = os.path.join(PASTA_RECIBOS, "recibos.json")
LIMITE_TAREFA = 200 * 1024

MANIFESTO = __MANIFESTO__
# impressões digitais (tamanho:adler32) de todos os scripts de todas as versões deste jogo
CONHECIDOS = __CONHECIDOS__
SEMPRE_CONHECIDOS = ("ReplicatedStorage.MoriohManifest",)
# AJUSTE-8: o servidor do Roblox coloca sozinho os scripts padrão do jogador (câmera, controles, sons
# do personagem) em StarterPlayerScripts quando o jogo não traz os seus. Não são de ninguém: ignorar.
PADRAO_DO_ROBLOX = (
    "StarterPlayer.StarterPlayerScripts.PlayerModule",
    "StarterPlayer.StarterPlayerScripts.PlayerScriptsLoader",
    "StarterPlayer.StarterPlayerScripts.RbxCharacterSounds",
    "StarterPlayer.StarterCharacterScripts.Health",
)


def do_roblox(nome):
    return any(nome == p or nome.startswith(p + ".") for p in PADRAO_DO_ROBLOX)
PAYLOAD_SHA256 = "__PAYLOAD_SHA__"
PAYLOAD = """
__PAYLOAD__
"""

NOMES_STANDS = {
    "STAR_PLATINUM": "STAR PLATINUM",
    "THE_WORLD": "THE WORLD",
    "MAGICIANS_RED": "MAGICIAN'S RED",
    "SILVER_CHARIOT": "SILVER CHARIOT",
    "CRAZY_DIAMOND": "CRAZY DIAMOND",
    "KILLER_QUEEN": "KILLER QUEEN",
}
MARCADOR_VOZES = b"BBVOZ" + b"_" * 59  # o place guarda o número do áudio das vozes aqui
MARCADOR_ANIME = b"BBVZA" + b"_" * 59  # AJUSTE-8: áudio dos sons do anime (separado)
MARCADOR_IMAGENS = b"BBIMG" + b"_" * 59  # AJUSTE-8: artes do Canva ("logo fundo carregando")
MARCADOR_SFX = b"BBSFX" + b"_" * 59  # AJUSTE-13: socos do dono (grave/estourado)
ARQ_VFX = "BIZARRE_VFX_PACOTES.zip"  # AJUSTE-13: pacotes de VFX + descrição, para mandar no chat


# --------------------------------------------------------------------- saída
def titulo(msg):
    print("")
    print("=" * 52)
    print("  " + msg)
    print("=" * 52)


def passo(n, msg):
    print("")
    print(str(n) + ") " + msg)


def ok(msg):
    print("   [ok] " + msg)


def aviso(msg):
    print("   [!]  " + msg)


def erro(msg):
    print("   [ERRO] " + msg)


class Falha(Exception):
    pass


class ErroHTTP(Exception):
    def __init__(self, codigo, corpo, url):
        Exception.__init__(self, "HTTP %s" % codigo)
        self.codigo = codigo
        self.corpo = corpo
        self.url = url

    def resumo(self):
        texto = (self.corpo or "").strip().replace("\n", " ")
        if len(texto) > 300:
            texto = texto[:300] + "..."
        return "HTTP %s: %s" % (self.codigo, texto)


# --------------------------------------------------------------------- pacote
def carregar_pacote():
    bruto = base64.b85decode("".join(PAYLOAD.split()))
    if hashlib.sha256(bruto).hexdigest() != PAYLOAD_SHA256:
        raise Falha("Pacote corrompido (sha256 não confere). Baixe o arquivo de novo.")
    arquivos = {}
    with zipfile.ZipFile(io.BytesIO(bruto)) as z:
        for nome, info in MANIFESTO.items():
            dados = z.read(nome)
            if len(dados) != info["tamanho"] or hashlib.sha256(dados).hexdigest() != info["sha256"]:
                raise Falha("Arquivo do pacote alterado: %s. Baixe o instalador de novo." % nome)
            arquivos[nome] = dados
    return arquivos


# --------------------------------------------------------------------- http
def http(metodo, url, chave=None, corpo=None, tipo=None, tentativas=4, espera_max=120):
    for i in range(tentativas):
        req = urllib.request.Request(url, data=corpo, method=metodo)
        if chave:
            req.add_header("x-api-key", chave)
        if tipo:
            req.add_header("Content-Type", tipo)
        req.add_header("User-Agent", "BIZARRE-Instalador/" + REVISAO)
        req.add_header("Accept", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=espera_max) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            try:
                texto = e.read()[:3000].decode("utf-8", "replace")
            except Exception:
                texto = ""
            if e.code in (429, 500, 502, 503, 504) and i < tentativas - 1:
                espera = 2 ** (i + 1)
                aviso("Roblox respondeu %s; tentando de novo em %ss..." % (e.code, espera))
                time.sleep(espera)
                continue
            raise ErroHTTP(e.code, texto, url)
        except Exception as e:  # rede caiu, DNS, tempo esgotado...
            if i < tentativas - 1:
                espera = 2 ** (i + 1)
                aviso("Falha de rede (%s); tentando de novo em %ss..." % (type(e).__name__, espera))
                time.sleep(espera)
                continue
            raise Falha("Sem conexão com o Roblox (%s). Confira a internet e rode de novo." % type(e).__name__)
    raise Falha("Não consegui falar com o Roblox.")


def http_json(metodo, url, chave=None, dados=None, tentativas=4, espera_max=120):
    corpo = None
    tipo = None
    if dados is not None:
        corpo = json.dumps(dados).encode("utf-8")
        tipo = "application/json"
    _, resp = http(metodo, url, chave, corpo, tipo, tentativas, espera_max)
    if not resp:
        return {}
    return json.loads(resp.decode("utf-8"))


PERMISSOES = {
    "publicar": "Place Publishing (universe-places) -> write, com a experiência BIZARRE marcada",
    "luau": "Luau Execution Sessions (universe.place.luau-execution-session) -> read e write, com a experiência marcada",
    "reiniciar": "Universes -> universe:write (opcional)",
    "audio": "Assets (asset:read e asset:write) - opcional, só para as vozes",
    "liberar": "Asset Permissions (asset-permissions:write) - opcional, libera as vozes para o jogo",
    "vfx": "Legacy Assets (legacy-asset:manage) - opcional, só para baixar e conferir os pacotes de VFX",
}

# AJUSTE-11: pacotes de VFX que o dono pegou na Creator Store ("Obter modelo"). O JOGO carrega cada
# um sozinho (servidor, sem rodar os scripts deles); aqui o instalador só baixa com a sua chave pelo
# caminho oficial (Open Cloud Asset Delivery) para conferir o que tem dentro.
PACOTES_VFX = [
    (112672322113504, "VFX PACK (Euphoric Games)"),
    (102139885640916, "Explosões, lasers, fogo e fumaça"),
    (83841806206726, "saythrt's Mega Pack"),
    (107474757639811, "Simple VFX Pack"),
    (94340858809782, "Anime Sword Slash"),
    (10153386313, "Sword Slash Effect"),
]


def lz4_bloco(src, tamanho):
    """descompressor LZ4 (formato de bloco), o mesmo dos pedaços dos arquivos .rbxm/.rbxl"""
    dst = bytearray()
    i, n = 0, len(src)
    while i < n:
        token = src[i]
        i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]
                i += 1
                lit += b
                if b != 255:
                    break
        dst += src[i:i + lit]
        i += lit
        if i >= n:
            break
        desloc = src[i] | (src[i + 1] << 8)
        i += 2
        mlen = token & 15
        if mlen == 15:
            while True:
                b = src[i]
                i += 1
                mlen += b
                if b != 255:
                    break
        mlen += 4
        ini = len(dst) - desloc
        if desloc >= mlen:
            dst += dst[ini:ini + mlen]
        else:
            for k in range(mlen):
                dst.append(dst[ini + k])
    if len(dst) != tamanho:
        raise ValueError("LZ4: tamanho errado")
    return bytes(dst)


def listar_classes(dados):
    """conta as peças de um .rbxm (binário ou XML): {classe: quantidade}"""
    contagem = {}
    if dados[:8] == b"<roblox!":
        off = 32
        while off + 16 <= len(dados):
            nome = dados[off:off + 4]
            clen, ulen, _ = struct.unpack_from("<III", dados, off + 4)
            ini = off + 16
            bruto = dados[ini:ini + (clen if clen else ulen)]
            off = ini + (clen if clen else ulen)
            if nome == b"END\x00":
                break
            if nome != b"INST":
                continue
            if clen:
                if bruto[:4] == b"\x28\xb5\x2f\xfd":
                    contagem["(parte em formato novo)"] = contagem.get("(parte em formato novo)", 0) + 1
                    continue
                bruto = lz4_bloco(bruto, ulen)
            n_nome = struct.unpack_from("<I", bruto, 4)[0]
            classe = bruto[8:8 + n_nome].decode("utf-8", "replace")
            qtd = struct.unpack_from("<I", bruto, 8 + n_nome + 1)[0]
            contagem[classe] = contagem.get(classe, 0) + qtd
        return contagem
    import re
    for classe in re.findall(rb'<Item class="([A-Za-z]+)"', dados):
        c = classe.decode("ascii", "replace")
        contagem[c] = contagem.get(c, 0) + 1
    return contagem


def salvar_vfx(pacotes, detalhes):
    """AJUSTE-13: junta os pacotes baixados e a descrição de cada efeito num zip na pasta atual
    (Downloads), para o dono mandar no chat. Opcional: nunca trava."""
    if not pacotes and not detalhes:
        return
    try:
        with zipfile.ZipFile(ARQ_VFX, "w", zipfile.ZIP_DEFLATED) as z:
            for nome_arq, dados in (pacotes or {}).items():
                z.writestr(nome_arq, dados)
            if detalhes:
                z.writestr("no_jogo.json", json.dumps(detalhes, ensure_ascii=False, indent=1))
        ok("arquivo dos VFX salvo: %s (%d KB)" % (os.path.abspath(ARQ_VFX), os.path.getsize(ARQ_VFX) // 1024))
        print("      -> mande esse arquivo no chat para eu ver cada efeito e escolher o melhor de cada golpe")
    except Exception as e:
        aviso("não deu para salvar o arquivo dos VFX (%s)" % type(e).__name__)


def auditar_vfx(chave):
    """baixa cada pacote com a sua chave (Open Cloud Asset Delivery) e mostra o que tem dentro. Opcional.
    AJUSTE-13: devolve {nome do arquivo: bytes} para salvar no zip dos VFX."""
    baixados = {}
    for asset_id, nome in PACOTES_VFX:
        try:
            info = http_json("GET", "%s/asset-delivery-api/v1/assetId/%d" % (API, asset_id), chave, tentativas=2, espera_max=60)
            local = info.get("location") if isinstance(info, dict) else None
            if not local:
                aviso("%s: o Roblox não mandou o endereço para baixar." % nome)
                continue
            _, dados = http("GET", local, None, tentativas=2, espera_max=180)
            if dados[:2] == b"\x1f\x8b":
                dados = gzip.decompress(dados)
            baixados["%d_%s.rbxm" % (asset_id, "".join(ch if ch.isalnum() else "_" for ch in nome)[:30])] = dados
            c = listar_classes(dados)
            scripts = sum(v for k, v in c.items() if k in ("Script", "LocalScript", "ModuleScript"))
            ok("%s: baixado (%d KB) - %d partículas, %d feixes, %d rastros, %d peças; %d scripts (o jogo NÃO roda)" % (
                nome, len(dados) // 1024, c.get("ParticleEmitter", 0), c.get("Beam", 0), c.get("Trail", 0),
                c.get("Part", 0) + c.get("MeshPart", 0), scripts))
        except ErroHTTP as e:
            if e.codigo in (401, 403):
                aviso("a chave não tem a permissão para baixar modelos: %s." % PERMISSOES["vfx"])
                aviso("   (é opcional: o JOGO carrega os pacotes sozinho; isso aqui é só para conferir)")
                return baixados
            aviso("%s: o Roblox respondeu %s (%s)" % (nome, e.codigo, e.resumo()))
        except Falha as f:
            aviso("%s: %s" % (nome, f))
        except Exception as e:
            aviso("%s: não deu para ler o arquivo (%s)" % (nome, type(e).__name__))
    return baixados


def explicar(e, etapa):
    c = e.codigo
    if c == 401:
        return "A chave foi recusada (inválida, expirada ou com restrição de IP). Confira a chave no Creator Hub > Open Cloud > API Keys."
    if c == 403:
        return ("A chave não tem permissão para esta etapa. No Creator Hub > Open Cloud > API Keys, edite a chave e adicione: "
                + PERMISSOES.get(etapa, etapa) + ". (" + e.resumo() + ")")
    if c == 404:
        return "Não encontrei o universo/place. Confira o Universe ID e o Place ID. (" + e.resumo() + ")"
    if c == 429:
        return "Muitos pedidos seguidos (limite do Roblox). Espere alguns minutos e rode de novo."
    return e.resumo()


# --------------------------------------------------------------------- recibos
def ler_recibos():
    try:
        with open(ARQ_RECIBOS, "r", encoding="utf-8") as f:
            r = json.load(f)
            if isinstance(r, dict):
                r.setdefault("publicacoes", [])
                return r
    except Exception:
        pass
    return {"publicacoes": []}


def gravar_recibos(r):
    os.makedirs(PASTA_RECIBOS, exist_ok=True)
    tmp = ARQ_RECIBOS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=1)
    os.replace(tmp, ARQ_RECIBOS)


def dono_do_universo(universe):
    try:
        d = http_json("GET", GAMES + "/v1/games?universeIds=" + universe, tentativas=2, espera_max=20)
        c = d["data"][0]["creator"]
        return c.get("type"), str(c.get("id")), c.get("name"), d["data"][0].get("name")
    except Exception:
        return None


# --------------------------------------------------------------------- vozes (opcionais)
def multipart(campos):
    limite = "----BB" + uuid.uuid4().hex
    partes = []
    for nome, valor, arquivo, tipo in campos:
        cab = '--%s\r\nContent-Disposition: form-data; name="%s"' % (limite, nome)
        if arquivo:
            cab += '; filename="%s"' % arquivo
        cab += "\r\n"
        if tipo:
            cab += "Content-Type: %s\r\n" % tipo
        cab += "\r\n"
        partes.append(cab.encode("utf-8"))
        partes.append(valor)
        partes.append(b"\r\n")
    partes.append(("--%s--\r\n" % limite).encode("utf-8"))
    return b"".join(partes), "multipart/form-data; boundary=" + limite


def ler_operacao(chave, op_id):
    d = http_json("GET", API + "/assets/v1/operations/" + op_id, chave, tentativas=3)
    if not d.get("done"):
        return None, None
    if d.get("error"):
        raise Falha("O Roblox recusou o áudio: %s" % json.dumps(d.get("error"))[:300])
    resp = d.get("response") or {}
    estado = ((resp.get("moderationResult") or {}).get("moderationState")) or ""
    return resp.get("assetId"), estado


def consultar_moderacao(chave, asset_id):
    try:
        d = http_json("GET", "%s/assets/v1/assets/%s?readMask=moderationResult" % (API, asset_id), chave, tentativas=2, espera_max=30)
        return ((d.get("moderationResult") or {}).get("moderationState")) or ""
    except Exception:
        return ""


TRADUZ = {"Approved": "APROVADO", "Reviewing": "em análise", "Rejected": "RECUSADO"}


def enviar_audio(chave, criador, nome, info, dados, recibos, tipo="Audio", mime="audio/ogg", gaveta_nome="audio"):
    """Envia um áudio ou imagem (uma vez só: o recibo guarda o ID). Nunca trava: devolve 0 se não deu."""
    sha = info["sha256"]
    gaveta = recibos.setdefault(gaveta_nome, {})
    r = gaveta.get(sha) or {}
    rotulo = info.get("rotulo", nome)
    if r.get("assetId"):
        estado = consultar_moderacao(chave, r["assetId"]) or r.get("estado", "")
        if estado and estado != r.get("estado"):
            r["estado"] = estado
            gaveta[sha] = r
            gravar_recibos(recibos)
        if estado == "Rejected":
            aviso("%s: o Roblox RECUSOU na moderação (ID %s); o jogo segue sem isso." % (rotulo, r["assetId"]))
            return 0
        ok("%s: já enviado antes (ID %s) - moderação: %s" % (rotulo, r["assetId"], TRADUZ.get(estado, estado or "?")))
        return int(r["assetId"])
    if r.get("operationId"):
        try:
            asset_id, estado = ler_operacao(chave, r["operationId"])
        except Falha as f:
            aviso(str(f))
            return 0
        except ErroHTTP as e:
            aviso("%s: %s" % (rotulo, explicar(e, "audio")))
            return 0
        if asset_id:
            r.update({"assetId": str(asset_id), "estado": estado})
            gaveta[sha] = r
            gravar_recibos(recibos)
            ok("%s: pronto (ID %s, moderação: %s)" % (rotulo, asset_id, TRADUZ.get(estado, estado or "?")))
            return 0 if estado == "Rejected" else int(asset_id)
        aviso("%s: o Roblox ainda está processando o envio anterior; seguindo sem ele por enquanto." % rotulo)
        return 0
    pedido = {
        "assetType": tipo,
        "displayName": ("BIZARRE %s %s" % (rotulo, REVISAO))[:50],
        "description": "BIZARRE BATTLEGROUNDS: %s. Enviado pelo instalador." % rotulo,
        "creationContext": {"creator": criador},
    }
    corpo, tipo_corpo = multipart([
        ("request", json.dumps(pedido).encode("utf-8"), None, "application/json"),
        ("fileContent", dados, nome.split("/")[-1], mime),
    ])
    try:
        _, resp = http("POST", API + "/assets/v1/assets", chave, corpo, tipo_corpo, tentativas=3, espera_max=300)
    except ErroHTTP as e:
        aviso("%s: %s" % (rotulo, explicar(e, "audio")))
        aviso("Seguindo sem isso por enquanto (é opcional: o jogo funciona sem).")
        return 0
    except Falha as f:
        aviso(str(f))
        return 0
    try:
        op = json.loads(resp.decode("utf-8") or "{}")
    except Exception:
        op = {}
    op_id = op.get("operationId") or (op.get("path") or "").split("/")[-1]
    if not op_id:
        aviso("%s: resposta inesperada do Roblox; seguindo sem isso." % rotulo)
        return 0
    r = {"nome": nome, "operationId": op_id, "enviadoEm": int(time.time()), "trechos": info.get("trechos", 0)}
    gaveta[sha] = r
    gravar_recibos(recibos)
    print("   ...%s enviado, esperando o Roblox processar" % rotulo, end="", flush=True)
    inicio = time.time()
    while time.time() - inicio < 120:
        time.sleep(4)
        print(".", end="", flush=True)
        try:
            asset_id, estado = ler_operacao(chave, op_id)
        except (Falha, ErroHTTP) as f:
            print("")
            aviso(str(f) if isinstance(f, Falha) else explicar(f, "audio"))
            return 0
        if asset_id:
            print("")
            r.update({"assetId": str(asset_id), "estado": estado})
            gravar_recibos(recibos)
            if estado == "Rejected":
                aviso("%s: o Roblox recusou na moderação; seguindo sem isso." % rotulo)
                return 0
            ok("%s: ID %s (moderação: %s)" % (rotulo, asset_id, TRADUZ.get(estado, estado or "em análise")))
            if estado != "Approved":
                aviso("   enquanto estiver 'em análise' o jogo usa o que já tem (o Roblox libera sozinho depois).")
            return int(asset_id)
    print("")
    aviso("%s: ainda processando. Rode o instalador de novo daqui a uns minutos para incluir." % rotulo)
    return 0


def liberar_audio(chave, universe, asset_id, recibos, rotulo="vozes"):
    """Dá ao jogo a permissão de USAR o áudio (sem isso o Roblox deixa mudo). Nunca trava."""
    lib = recibos.setdefault("liberados", {})
    if int(asset_id) in lib.get(str(universe), []):
        ok("%s: já liberado para o jogo" % rotulo)
        return True
    pedido = {"subjectType": "Universe", "subjectId": str(universe), "action": "Use", "requests": [{"assetId": int(asset_id)}]}
    corpo = json.dumps(pedido).encode("utf-8")
    url = API + "/asset-permissions-api/v1/assets/permissions"
    try:
        try:
            _, resp = http("PATCH", url, chave, corpo, "application/json", tentativas=3, espera_max=60)
        except ErroHTTP as e:
            if e.codigo != 415:
                raise
            _, resp = http("PATCH", url, chave, corpo, "application/json-patch+json", tentativas=2, espera_max=60)
    except ErroHTTP as e:
        if e.codigo == 403:
            aviso("A chave não tem a permissão de liberar áudios para o jogo (%s)." % PERMISSOES["liberar"])
        else:
            aviso("O Roblox não deixou liberar %s agora (%s)." % (rotulo, e.resumo()))
        return False
    except Falha as f:
        aviso(str(f))
        return False
    try:
        d = json.loads(resp.decode("utf-8") or "{}")
    except Exception:
        d = {}
    feitos = {int(a) for a in (d.get("successAssetIds") or []) if str(a).isdigit()}
    for e in d.get("errors") or []:
        if str(e.get("code", "")) in ("AlreadyGranted", "PermissionAlreadyExists"):
            feitos.add(int(e.get("assetId") or 0))
    if int(asset_id) in feitos:
        lib[str(universe)] = sorted(set(lib.get(str(universe), [])) | {int(asset_id)})
        gravar_recibos(recibos)
        ok("%s: LIBERADO para o jogo" % rotulo)
        return True
    aviso("o Roblox não confirmou a liberação de %s (o jogo segue sem isso se ficar mudo)." % rotulo)
    return False


def vozes_antigas(recibos):
    """o áudio de vozes enviado antes (se o novo não deu certo): (id, quantos trechos)"""
    melhor = None
    for r in (recibos.get("audio") or {}).values():
        if r.get("assetId") and r.get("estado") != "Rejected" and r.get("trechos"):
            if not melhor or r.get("enviadoEm", 0) > melhor.get("enviadoEm", 0):
                melhor = r
    if melhor:
        return int(melhor["assetId"]), int(melhor["trechos"])
    return 0, 0


def colocar_marcador(place, marcador, texto):
    """troca um marcador do place por um texto do mesmo tamanho (o arquivo continua válido)"""
    if place.count(marcador) != 1:
        raise Falha("o marcador %s não está no place (pacote estranho)" % marcador[:5].decode())
    valor = texto.encode("ascii")
    if len(valor) > len(marcador):
        raise Falha("texto grande demais para o marcador %s" % marcador[:5].decode())
    return place.replace(marcador, valor.ljust(len(marcador), b" "))


def colocar_extras(place, anime, trechos_anime, imagens, sfx=0, trechos_sfx=0):
    """AJUSTE-8: sons do anime e artes do Canva no place (0 = sem). AJUSTE-13: socos do dono"""
    if sfx and MARCADOR_SFX in place:
        place = colocar_marcador(place, MARCADOR_SFX, "%d %d" % (int(sfx), int(trechos_sfx or 0)))
    if anime:
        place = colocar_marcador(place, MARCADOR_ANIME, "%d %d" % (int(anime), int(trechos_anime or 0)))
    if imagens and any(imagens):
        place = colocar_marcador(place, MARCADOR_IMAGENS, " ".join(str(int(i or 0)) for i in imagens))
    return place


def colocar_vozes(place, asset_id, trechos=0):
    """troca o marcador do place pelo número do áudio (mesmo tamanho: o arquivo continua válido)"""
    if place.count(MARCADOR_VOZES) != 1:
        raise Falha("o marcador das vozes não está no place (pacote estranho)")
    texto = str(int(asset_id)) + ((" %d" % int(trechos)) if trechos else "")
    valor = texto.encode("ascii").ljust(len(MARCADOR_VOZES), b" ")
    return place.replace(MARCADOR_VOZES, valor)


def conferir_binario(place):
    """confere a estrutura do .rbxl (cabeçalho e pedaços) sem precisar do Roblox"""
    if place[:8] != b"<roblox!":
        raise Falha("o place não é um arquivo binário do Roblox")
    off = 32
    n = 0
    while off < len(place):
        nome = place[off:off + 4]
        clen, ulen, _ = struct.unpack_from("<III", place, off + 4)
        off += 16 + (clen if clen else ulen)
        n += 1
        if nome == b"END\x00":
            break
    if off > len(place) or n < 4:
        raise Falha("o place está cortado (pedaços: %d)" % n)
    return n


# --------------------------------------------------------------------- place / luau
def publicar(chave, universe, place, dados, tipo_versao):
    url = "%s/universes/v1/%s/places/%s/versions?versionType=%s" % (API, universe, place, tipo_versao)
    tipo = "application/octet-stream" if dados[:8] == b"<roblox!" else "application/xml"
    _, resp = http("POST", url, chave, dados, tipo, tentativas=3, espera_max=300)
    d = json.loads(resp.decode("utf-8"))
    return int(d["versionNumber"])


def rodar_luau(chave, universe, place, versao, script, limite_s=420, mensagem="...rodando na nuvem"):
    if len(script.encode("utf-8")) > LIMITE_TAREFA:
        raise Falha("Tarefa de teste maior que 200 kB.")
    if versao is None:  # a versão que está no ar agora
        url = "%s/cloud/v2/universes/%s/places/%s/luau-execution-session-tasks" % (API, universe, place)
    else:
        url = "%s/cloud/v2/universes/%s/places/%s/versions/%s/luau-execution-session-tasks" % (API, universe, place, versao)
    tarefa = http_json("POST", url, chave, {"script": script, "timeout": "300s"}, tentativas=3)
    caminho = tarefa.get("path")
    if not caminho:
        raise Falha("Resposta estranha do Luau Execution.")
    inicio = time.time()
    print("   " + mensagem, end="", flush=True)
    while tarefa.get("state") not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() - inicio > limite_s:
            print("")
            raise Falha("O teste demorou demais na nuvem. Tente de novo em alguns minutos.")
        time.sleep(4)
        print(".", end="", flush=True)
        tarefa = http_json("GET", "%s/cloud/v2/%s" % (API, caminho), chave, tentativas=4)
    print("")
    logs = []
    try:
        d = http_json("GET", "%s/cloud/v2/%s/logs?maxPageSize=200" % (API, caminho), chave, tentativas=2)
        for bloco in d.get("luauExecutionSessionTaskLogs", []):
            logs.extend(bloco.get("messages", []))
    except Exception:
        pass
    return tarefa, logs


def resultado_teste(tarefa):
    if tarefa.get("state") != "COMPLETE":
        err = tarefa.get("error") or {}
        return None, "%s: %s" % (err.get("code", tarefa.get("state")), err.get("message", ""))
    resultados = (tarefa.get("output") or {}).get("results") or []
    if not resultados:
        return None, "o teste não devolveu resultado"
    try:
        return json.loads(resultados[0]), None
    except Exception:
        return None, "resultado ilegível: %s" % str(resultados[0])[:200]


def mostrar_relatorio(res):
    inf = res.get("info", {})
    ok("teste passou: %s módulos carregados (revisão %s)" % (inf.get("modulos"), inf.get("revisao")))
    ok("Morioh: %s peças quebráveis, %s pontos de nascer" % (inf.get("quebraveis"), inf.get("spawns")))
    if inf.get("quebraTeste"):
        ok("quebrar e reconstruir: %s" % inf["quebraTeste"])
    if inf.get("simplificado"):
        ok("Morioh: %s" % inf["simplificado"])
    if inf.get("clash"):
        ok("ORA x MUDA (rajadas se anulam): %s" % inf["clash"])
    if inf.get("congelamentos"):
        ok("tempo parado: %s" % inf["congelamentos"])
    if inf.get("estresse"):
        ok("servidor do Roblox: %s" % inf["estresse"])
        print("        (isso é o SERVIDOR; o FPS do seu celular só dá para ver jogando)")
    if inf.get("vozes"):
        ok("vozes: %s" % inf["vozes"])
    if inf.get("vozesAnime"):
        ok("sons do anime: %s" % inf["vozesAnime"])
    if inf.get("imagens"):
        ok("artes: %s" % inf["imagens"])
    if inf.get("vfxLoja"):
        ok("VFX da loja dentro do jogo: %s" % inf["vfxLoja"])
    if inf.get("sfx"):
        ok("socos do dono: %s" % inf["sfx"])
    stands = inf.get("stands") or {}
    for sid in NOMES_STANDS:
        txt = stands.get(sid)
        if not txt:
            continue
        if "reserva" in str(txt):
            aviso("Stand %s: %s (o catálogo não respondeu; ele aparece com o corpo reserva)" % (NOMES_STANDS[sid], txt))
        else:
            ok("Stand %s: corpo do %s" % (NOMES_STANDS[sid], txt))
    if inf.get("m1"):
        ok("combo de M1 no boneco de teste: %s" % inf["m1"])
    golpes = inf.get("golpes") or {}
    if golpes:
        partes = ["%s %s" % (k, v) for k, v in sorted(golpes.items())]
        ok("golpes testados (%d): %s" % (len(golpes), ", ".join(partes)))
    if inf.get("sons"):
        ok("sons da biblioteca do Roblox que carregaram no teste: %s" % inf["sons"])
    for a in (res.get("avisos") or [])[:12]:
        aviso(str(a)[:300])


# --------------------------------------------------------------------- comandos
def perguntar(texto, padrao):
    try:
        r = input("   %s [%s]: " % (texto, padrao)).strip()
    except EOFError:
        r = ""
    return r or padrao


def so_digitos(x, nome):
    x = x.strip()
    if not x.isdigit():
        raise Falha("%s precisa ser só números." % nome)
    return x


def cmd_testar():
    titulo("%s %s - teste offline do pacote" % (JOGO, REVISAO))
    arquivos = carregar_pacote()
    ok("pacote íntegro: %d arquivos conferidos por sha256" % len(arquivos))
    place = arquivos["place.rbxl"]
    n = conferir_binario(place)
    ok("place binário válido (mapa Morioh + jogo: %d pedaços, %d kB)" % (n, len(place) // 1024))
    teste = colocar_vozes(place, 123456789)
    if len(teste) != len(place) or conferir_binario(teste) != n:
        raise Falha("trocar o número das vozes estragaria o place")
    ok("lugar do número das vozes confere")
    if "vozes.ogg" in arquivos:
        ok("vozes dos Stands: %d kB (opcional)" % (len(arquivos["vozes.ogg"]) // 1024))
    script = arquivos["teste_nuvem.luau"].decode("utf-8")
    tam = len(script.encode("utf-8"))
    if tam > LIMITE_TAREFA:
        raise Falha("tarefa de teste grande demais (%d bytes)" % tam)
    ok("tarefa do teste na nuvem: %d bytes (limite 200 kB)" % tam)
    ok("instalador compila (este próprio arquivo rodou)")
    print("\nTUDO OK (nada foi enviado ao Roblox).")


def cmd_recibos():
    r = ler_recibos()
    titulo("Publicações (%s)" % ARQ_RECIBOS)
    if not r["publicacoes"]:
        print("   nenhuma publicação ainda")
    if r.get("pendente"):
        p = r["pendente"]
        print("   PENDENTE: %s testada e aprovada (versão de teste %s), ainda não publicada -> rode 'publicar'" % (p.get("revisao"), p.get("teste")))
    for p in r["publicacoes"][-8:]:
        print("   %s: versão %s (teste %s) em %s" % (p.get("revisao"), p.get("versao"), p.get("teste"), time.strftime("%d/%m %H:%M", time.localtime(p.get("quando", 0)))))


PREFLIGHT = """
-- BB_PREFLIGHT: lista os scripts da versão que está no ar (nome, tamanho e soma do texto)
local HttpService = game:GetService("HttpService")
local r = { revisao = nil, scripts = {}, legivel = true }
pcall(function()
	r.revisao = require(game:GetService("ReplicatedStorage").BB.Config).REVISAO
end)
local function adler(s)
	local a, b = 1, 0
	for i = 1, #s, 4096 do
		for _, x in { string.byte(s, i, math.min(#s, i + 4095)) } do
			a = (a + x) % 65521
			b = (b + a) % 65521
		end
	end
	return b * 65536 + a
end
for _, nome in { "Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" } do
	local ok, svc = pcall(function()
		return game:GetService(nome)
	end)
	if ok and svc then
		for _, d in svc:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				local item = { c = d:GetFullName(), n = -1, h = 0 }
				local okS, fonte = pcall(function()
					return d.Source
				end)
				if okS and type(fonte) == "string" then
					item.n = #fonte
					item.h = adler(fonte)
				else
					r.legivel = false
				end
				table.insert(r.scripts, item)
			end
		end
	end
end
return HttpService:JSONEncode(r)
"""


def analisar_no_ar(dados):
    """separa os scripts da versão no ar em conhecidos e desconhecidos (nome novo ou texto alterado)"""
    desconhecidos = []
    for item in dados.get("scripts") or []:
        nome = str(item.get("c"))
        if nome in SEMPRE_CONHECIDOS or do_roblox(nome):
            continue
        digitais = CONHECIDOS.get(nome)
        if digitais is None:
            desconhecidos.append(nome + "  (script que este instalador nunca criou)")
        elif int(item.get("n", -1)) >= 0 and ("%d:%d" % (int(item["n"]), int(item["h"]))) not in digitais:
            desconhecidos.append(nome + "  (alterado fora deste instalador)")
    return desconhecidos


def conferir_no_ar(chave, universe, place, substituir):
    """AJUSTE7: antes de mexer, olha a versão que está no ar. Fonte desconhecida = para tudo."""
    try:
        tarefa, _ = rodar_luau(chave, universe, place, None, PREFLIGHT, 180, "...olhando a versão que está no ar")
    except ErroHTTP as e:
        if e.codigo in (400, 404):
            ok("ainda não tem versão no ar para conferir (primeira instalação)")
            return
        if e.codigo == 403:
            raise Falha(explicar(e, "luau") + "\n   Nada foi enviado.")
        raise Falha("Não consegui conferir a versão no ar: " + explicar(e, "luau") + "\n   Nada foi enviado.")
    resultados = (tarefa.get("output") or {}).get("results") or []
    try:
        dados = json.loads(resultados[0])
    except Exception:
        dados = None
    if tarefa.get("state") != "COMPLETE" or not isinstance(dados, dict):
        aviso("Não consegui ler a versão que está no ar.")
        if not substituir and not perguntar("Continuar mesmo sem conferir? (s/n)", "n").lower().startswith("s"):
            raise Falha("Parei para não apagar nada por engano. Nada foi enviado.")
        return
    n = len(dados.get("scripts") or [])
    padrao = sum(1 for item in dados.get("scripts") or [] if do_roblox(str(item.get("c"))))
    if padrao:
        ok("%d scripts padrão do próprio Roblox (câmera e controles do jogador): ignorados" % padrao)
        n -= padrao
    desconhecidos = analisar_no_ar(dados)
    if not dados.get("legivel", True):
        aviso("o Roblox não deixou ler o texto dos scripts: conferi só pelos nomes.")
    if not desconhecidos:
        ok("versão no ar: %s (%d scripts, todos feitos por este instalador)" % (dados.get("revisao") or "sem o jogo ainda", n))
        return
    erro("A versão que está no ar (%s) tem %d script(s) que este instalador NÃO conhece:" % (dados.get("revisao") or "?", len(desconhecidos)))
    for nome in desconhecidos[:15]:
        print("      - " + nome)
    print("   Se eu publicar, esses scripts somem do jogo (o Roblox guarda a versão antiga no histórico,")
    print("   em create.roblox.com > Experiência > Place > Version History, e dá para voltar).")
    if substituir:
        aviso("Você pediu --substituir: sigo e troco tudo pela versão %s." % REVISAO)
        return
    print("   Parei aqui. Nada foi enviado. Para trocar mesmo assim, rode:")
    print("      python %s install --substituir" % os.path.basename(sys.argv[0]))
    sys.exit(3)


def preparar(args):
    """passos 1 a 4: pacote, IDs e chave, versão no ar, vozes e teste na nuvem. Devolve o contexto."""
    passo(1, "Conferindo o pacote")
    arquivos = carregar_pacote()
    ok("%d arquivos íntegros (sha256 conferido)" % len(arquivos))

    passo(2, "IDs do jogo (Enter = usar o que está entre colchetes)")
    universe = so_digitos(perguntar("Universe ID", UNIVERSE_PADRAO), "Universe ID")
    place = so_digitos(perguntar("Place ID", PLACE_PADRAO), "Place ID")
    dono = so_digitos(perguntar("Seu UserId (dono)", DONO_PADRAO), "UserId")
    print("")
    chave = getpass.getpass("   Cole a chave da Open Cloud (fica escondida) e Enter: ").strip()
    if not chave:
        raise Falha("Nenhuma chave informada.")
    info = dono_do_universo(universe)
    if info:
        tipo, ident, nome_dono, nome_jogo = info
        ok("Experiência: %s (dono: %s %s)" % (nome_jogo, tipo, nome_dono))
        if tipo == "User" and ident != dono:
            aviso("O dono da experiência (%s) é diferente do UserId informado (%s)." % (ident, dono))
    else:
        aviso("Não consegui confirmar o dono da experiência (seguindo).")
    criador = {"userId": dono}
    if info and info[0] == "Group":
        criador = {"groupId": info[1]}
    recibos = ler_recibos()
    place_bin = arquivos["place.rbxl"]
    conferir_binario(place_bin)

    passo(3, "Conferindo a versão que está no ar (para não apagar nada sem querer)")
    conferir_no_ar(chave, universe, place, "--substituir" in args)

    passo(4, "Vozes dos Stands (opcional: não trava a instalação)")
    id_vozes, trechos = 0, 0
    if "vozes.ogg" in arquivos:
        try:
            id_vozes = enviar_audio(chave, criador, "vozes.ogg", MANIFESTO["vozes.ogg"], arquivos["vozes.ogg"], recibos)
        except Exception as e:  # nada das vozes pode travar a instalação
            aviso("vozes: %s (seguindo sem elas)" % type(e).__name__)
            id_vozes = 0
        trechos = MANIFESTO["vozes.ogg"].get("trechos", 0)
        if not id_vozes:
            # o envio novo não deu: usa o áudio que já foi enviado antes (com as vozes que ele tem)
            id_vozes, trechos = vozes_antigas(recibos)
            if id_vozes:
                aviso("usando as vozes enviadas antes (áudio %s, %d vozes)." % (id_vozes, trechos))
        if id_vozes:
            try:
                liberar_audio(chave, universe, id_vozes, recibos)
            except Exception as e:
                aviso("liberar vozes: %s (seguindo)" % type(e).__name__)
            place_bin = colocar_vozes(place_bin, id_vozes, trechos)
            ok("place com as vozes (áudio %s)" % id_vozes)
        else:
            aviso("sem as vozes por enquanto: o jogo usa o grito da biblioteca do Roblox.")

    passo("4b", "Sons do anime e artes do Canva (opcionais: não travam a instalação)")
    id_anime, trechos_anime = 0, 0
    if "vozes_anime.ogg" in arquivos:
        info_a = MANIFESTO["vozes_anime.ogg"]
        try:
            id_anime = enviar_audio(chave, criador, "vozes_anime.ogg", info_a, arquivos["vozes_anime.ogg"], recibos, gaveta_nome="audio_anime")
        except Exception as e:
            aviso("sons do anime: %s (seguindo sem eles)" % type(e).__name__)
            id_anime = 0
        trechos_anime = info_a.get("trechos", 0)
        if id_anime:
            try:
                liberar_audio(chave, universe, id_anime, recibos, "sons do anime")
            except Exception as e:
                aviso("liberar sons do anime: %s (seguindo)" % type(e).__name__)
        else:
            aviso("sem os sons do anime por enquanto: o jogo usa as vozes geradas no lugar.")
    imagens = [0, 0, 0]
    ordem_img = {"logo": 0, "fundo": 1, "carregando": 2}
    for nome, info_i in MANIFESTO.items():
        if info_i.get("imagem") in ordem_img and nome in arquivos:
            mime = "image/png" if nome.endswith(".png") else "image/jpeg"
            try:
                imagens[ordem_img[info_i["imagem"]]] = enviar_audio(chave, criador, nome, info_i, arquivos[nome], recibos,
                                                                    tipo="Image", mime=mime, gaveta_nome="imagem")
            except Exception as e:
                aviso("%s: %s (seguindo sem)" % (info_i.get("rotulo", nome), type(e).__name__))
    if not any(imagens):
        aviso("sem as artes do Canva por enquanto: o menu usa o visual de texto.")
    # AJUSTE-13: socos do dono (grave e estourado), num áudio só
    id_sfx, trechos_sfx = 0, 0
    if "sfx.ogg" in arquivos:
        info_s = MANIFESTO["sfx.ogg"]
        try:
            id_sfx = enviar_audio(chave, criador, "sfx.ogg", info_s, arquivos["sfx.ogg"], recibos, gaveta_nome="audio_sfx")
        except Exception as e:
            aviso("socos do dono: %s (seguindo sem eles)" % type(e).__name__)
            id_sfx = 0
        trechos_sfx = info_s.get("trechos", 0)
        if id_sfx:
            try:
                liberar_audio(chave, universe, id_sfx, recibos, "socos do dono")
            except Exception as e:
                aviso("liberar socos: %s (seguindo)" % type(e).__name__)
        else:
            aviso("sem os socos novos por enquanto: o jogo usa os socos da biblioteca do Roblox.")
    place_bin = colocar_extras(place_bin, id_anime, trechos_anime, imagens, id_sfx, trechos_sfx)

    passo("4c", "Pacotes de VFX que você pegou na loja (opcional: baixa para eu poder ver)")
    pacotes_vfx = {}
    try:
        pacotes_vfx = auditar_vfx(chave) or {}
    except Exception as e:  # nada daqui pode travar a instalação
        aviso("conferir VFX: %s (seguindo)" % type(e).__name__)

    passo(5, "Teste isolado na nuvem (versão salva, NÃO publicada)")
    try:
        v_teste = publicar(chave, universe, place, place_bin, "Saved")
    except ErroHTTP as e:
        raise Falha(explicar(e, "publicar"))
    ok("versão de teste salva: %d" % v_teste)
    if "--pular-teste" in args:
        aviso("Teste na nuvem PULADO a seu pedido (--pular-teste).")
        salvar_vfx(pacotes_vfx, None)
    else:
        try:
            tarefa, logs = rodar_luau(chave, universe, place, v_teste, arquivos["teste_nuvem.luau"].decode("utf-8"),
                                      mensagem="...rodando na nuvem (abre Morioh, luta com todos os golpes e 12 lutadores juntos; uns 4 minutos)")
        except ErroHTTP as e:
            if e.codigo == 403:
                raise Falha(explicar(e, "luau") + "\n   Nada foi publicado. Depois de ajustar a chave, rode de novo.")
            raise Falha("Teste na nuvem não rodou: " + explicar(e, "luau") + "\n   Nada foi publicado.")
        res, problema = resultado_teste(tarefa)
        salvar_vfx(pacotes_vfx, (res or {}).get("vfxDetalhes"))
        if problema or not res or not res.get("ok"):
            erro("O teste isolado FALHOU. Nada foi publicado.")
            if problema:
                print("      " + problema)
            for e in (res or {}).get("erros", [])[:14]:
                print("      - " + str(e)[:300])
            for a in (res or {}).get("avisos", [])[:6]:
                print("      aviso: " + str(a)[:300])
            for linha in logs[-15:]:
                print("      log: " + str(linha)[:300])
            print("\n   Copie estas mensagens e mande no chat para eu corrigir.")
            sys.exit(2)
        mostrar_relatorio(res)
    # teste aprovado: fica anotado. Se a publicação cair no meio, "publicar" termina sem refazer tudo
    recibos["pendente"] = {"revisao": REVISAO, "pacote": PAYLOAD_SHA256, "teste": v_teste, "vozes": id_vozes,
                           "trechos": trechos, "anime": id_anime, "trechos_anime": trechos_anime, "imagens": imagens,
                           "sfx": id_sfx, "trechos_sfx": trechos_sfx,
                           "universe": universe, "place": place, "quando": int(time.time())}
    gravar_recibos(recibos)
    return {"chave": chave, "universe": universe, "place": place, "place_bin": place_bin, "recibos": recibos,
            "v_teste": v_teste, "id_vozes": id_vozes}


def publicar_aprovado(ctx):
    """passos 6 e 7: publica o que o teste aprovou e confere."""
    chave, universe, place, recibos = ctx["chave"], ctx["universe"], ctx["place"], ctx["recibos"]
    passo(6, "Publicando")
    try:
        v_pub = publicar(chave, universe, place, ctx["place_bin"], "Published")
    except ErroHTTP as e:
        raise Falha(explicar(e, "publicar") + "\n   O teste já passou: rode 'publicar' para tentar só a publicação de novo.")
    ok("publicado! versão %d" % v_pub)
    recibos["publicacoes"].append({"revisao": REVISAO, "versao": v_pub, "teste": ctx["v_teste"], "vozes": ctx["id_vozes"], "quando": int(time.time())})
    recibos.pop("pendente", None)
    gravar_recibos(recibos)

    passo(7, "Conferindo a versão publicada")
    conferencia = (
        'local RS = game:GetService("ReplicatedStorage")\n'
        'local C = require(RS.BB.Config)\n'
        'return game:GetService("HttpService"):JSONEncode({revisao = C.REVISAO})\n'
    )
    try:
        tarefa, _ = rodar_luau(chave, universe, place, v_pub, conferencia, 180)
        resultados = (tarefa.get("output") or {}).get("results") or []
        dados = json.loads(resultados[0]) if resultados else {}
        if dados.get("revisao") == REVISAO:
            ok("versão no ar: %s" % dados.get("revisao"))
        else:
            aviso("Não consegui confirmar a revisão publicada (%s)." % json.dumps(dados)[:200])
    except (Falha, ErroHTTP) as e:
        aviso("Conferência não rodou (%s). A publicação já foi feita." % (e.resumo() if isinstance(e, ErroHTTP) else e))

    resp = perguntar("Reiniciar servidores abertos para já pegar a versão nova? (s/n)", "s")
    if resp.lower().startswith("s"):
        try:
            http("POST", "%s/cloud/v2/universes/%s:restartServers" % (API, universe), chave, b"{}", "application/json", tentativas=2)
            ok("servidores reiniciados")
        except ErroHTTP as e:
            aviso("Não deu para reiniciar (%s). É só entrar num servidor novo." % explicar(e, "reiniciar"))
        except Falha as e:
            aviso(str(e))

    titulo("PRONTO! %s %s no ar" % (JOGO, REVISAO))
    print("   Abra: https://www.roblox.com/games/%s" % place)
    print("   Você é ADM (botão vermelho ADM no canto de cima): crie bots, encha o DESPERTAR,")
    print("   tire as recargas e restaure o mapa para testar tudo rápido.")
    if not ctx["id_vozes"]:
        print("   (sem as vozes desta vez: rode o instalador de novo mais tarde para tentar enviar)")


def cmd_testar_nuvem(args):
    titulo("%s %s - teste na nuvem (NÃO publica)" % (JOGO, REVISAO))
    preparar(args)
    print("\n   Teste aprovado e anotado. Para colocar no ar:")
    print("      python %s publicar" % os.path.basename(sys.argv[0]))


def cmd_publicar(args):
    titulo("%s %s - publicar o que o teste aprovou" % (JOGO, REVISAO))
    recibos = ler_recibos()
    p = recibos.get("pendente")
    if not p or p.get("pacote") != PAYLOAD_SHA256 or p.get("revisao") != REVISAO:
        raise Falha("Não tem teste aprovado deste arquivo. Rode primeiro: python %s testar-nuvem" % os.path.basename(sys.argv[0]))
    if time.time() - p.get("quando", 0) > 24 * 3600:
        raise Falha("O teste aprovado tem mais de 24 horas. Rode o testar-nuvem de novo.")
    arquivos = carregar_pacote()
    place_bin = arquivos["place.rbxl"]
    if p.get("vozes"):
        place_bin = colocar_vozes(place_bin, p["vozes"], p.get("trechos", 0))
    place_bin = colocar_extras(place_bin, p.get("anime", 0), p.get("trechos_anime", 0), p.get("imagens") or [],
                               p.get("sfx", 0), p.get("trechos_sfx", 0))
    ok("teste aprovado em %s (versão de teste %s)" % (time.strftime("%d/%m %H:%M", time.localtime(p["quando"])), p.get("teste")))
    chave = getpass.getpass("   Cole a chave da Open Cloud (fica escondida) e Enter: ").strip()
    if not chave:
        raise Falha("Nenhuma chave informada.")
    publicar_aprovado({"chave": chave, "universe": p["universe"], "place": p["place"], "place_bin": place_bin,
                       "recibos": recibos, "v_teste": p.get("teste"), "id_vozes": p.get("vozes", 0)})


def cmd_install(args):
    titulo("%s %s - instalador" % (JOGO, REVISAO))
    ctx = preparar(args)
    print("")
    if not perguntar("Teste aprovado. Publicar agora? (s/n)", "s").lower().startswith("s"):
        print("   Tudo bem: nada foi publicado. Quando quiser: python %s publicar" % os.path.basename(sys.argv[0]))
        return
    publicar_aprovado(ctx)


def main():
    args = [a.lower() for a in sys.argv[1:]]
    cmd = args[0] if args else "install"
    try:
        if cmd in ("install", "instalar"):
            cmd_install(args)
        elif cmd in ("testar-nuvem", "testar_nuvem", "nuvem"):
            cmd_testar_nuvem(args)
        elif cmd in ("publicar", "publish"):
            cmd_publicar(args)
        elif cmd in ("testar", "check", "teste"):
            cmd_testar()
        elif cmd in ("recibos", "status"):
            cmd_recibos()
        else:
            print("Comandos: install | testar | testar-nuvem | publicar | recibos")
    except Falha as f:
        print("")
        erro(str(f))
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n   Cancelado.")
        sys.exit(130)


if __name__ == "__main__":
    main()
