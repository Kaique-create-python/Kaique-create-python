#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OI3 - instalador __REVISAO__ (Roblox Open Cloud, sem Roblox Studio)

Como usar no Termux:
    cd ~/storage/downloads
    python __NOME_ARQUIVO__ install

Outros comandos:
    python __NOME_ARQUIVO__ testar     -> confere o pacote sem internet
    python __NOME_ARQUIVO__ recibos    -> mostra os áudios já enviados

O que ele faz (nessa ordem):
  1) confere o próprio pacote (sha256 de cada arquivo)
  2) envia os áudios (com recibos: não reenvia o que já foi enviado)
  3) monta o place com os IDs dos áudios
  4) salva uma versão de TESTE (não publicada) e roda o teste isolado na nuvem
  5) só se o teste passar: publica e confere
A chave da Open Cloud é pedida escondida, nunca aparece na tela e nunca é salva.
Nada aqui apaga o Place nem o DataStore dos jogadores.
"""
import base64
import getpass
import hashlib
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
import zipfile

REVISAO = "__REVISAO__"
JOGO = "OI3"
UNIVERSE_PADRAO = "10774214680"
PLACE_PADRAO = "128842336879717"
DONO_PADRAO = "1357078972"
API = os.environ.get("OI3_API_BASE", "https://apis.roblox.com")
GAMES = os.environ.get("OI3_GAMES_BASE", "https://games.roblox.com")
PASTA_RECIBOS = os.environ.get("OI3_RECIBOS_DIR") or os.path.join(os.path.expanduser("~"), ".oi3_instalador")
ARQ_RECIBOS = os.path.join(PASTA_RECIBOS, "recibos.json")
LIMITE_TAREFA = 200 * 1024
MARCA_INI = "--@@OI3_RECURSOS_INICIO@@"
MARCA_FIM = "--@@OI3_RECURSOS_FIM@@"

MANIFESTO = __MANIFESTO__
PAYLOAD_SHA256 = "__PAYLOAD_SHA__"
PAYLOAD = """
__PAYLOAD__
"""


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


def materiais_texturas():
    """{material: {"cor": arquivo, "normal": arquivo, "rugosidade": arquivo}} a partir do manifesto."""
    mats = {}
    for nome, inf in MANIFESTO.items():
        if inf.get("textura"):
            mats.setdefault(inf["material"], {})[inf["mapa"]] = inf["textura"]
    return mats


def montar_place(xml_bytes, ids_audio, ids_tex=None):
    ids_tex = ids_tex or {}
    txt = xml_bytes.decode("utf-8")
    # texturas: troca os marcadores pelos IDs; a variante só "liga" se os 3 mapas existem
    ligados = {}
    for material, mapas in materiais_texturas().items():
        completo = all(ids_tex.get(arq) for arq in mapas.values()) and len(mapas) == 3
        for arq in mapas.values():
            txt = txt.replace("rbxassetid://OI3TEX_" + arq + "<", ("rbxassetid://%d<" % ids_tex[arq]) if ids_tex.get(arq) else "<")
        if completo:
            txt = txt.replace(">OI3TEXNOME_" + material + "<", ">" + material + "<")
            ligados[material] = {m: int(ids_tex[a]) for m, a in mapas.items()}
    a = txt.index(MARCA_INI) + len(MARCA_INI)
    b = txt.index(MARCA_FIM, a)
    linhas = ["", "return {", '\trevisao = "%s",' % REVISAO, "\taudio = {"]
    for chave in sorted(ids_audio):
        linhas.append("\t\t%s = %d," % (chave, int(ids_audio[chave])))
    linhas += ["\t},", "\ttexturas = {"]
    for material in sorted(ligados):
        m = ligados[material]
        linhas.append("\t\t%s = { cor = %d, normal = %d, rugosidade = %d }," % (material, m["cor"], m["normal"], m["rugosidade"]))
    linhas += ["\t},", "}", ""]
    bloco = "\n".join(linhas)
    if "]]>" in bloco:
        raise Falha("bloco de recursos inválido")
    return (txt[:a] + bloco + txt[b:]).encode("utf-8")


# --------------------------------------------------------------------- http
def http(metodo, url, chave=None, corpo=None, tipo=None, tentativas=4, espera_max=120):
    for i in range(tentativas):
        req = urllib.request.Request(url, data=corpo, method=metodo)
        if chave:
            req.add_header("x-api-key", chave)
        if tipo:
            req.add_header("Content-Type", tipo)
        req.add_header("User-Agent", "OI3-Instalador/" + REVISAO)
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
    "audio": "Assets API -> asset:read e asset:write",
    "publicar": "Place Publishing (universe-places) -> write, com a experiência OI3 marcada",
    "luau": "Luau Execution Sessions (universe.place.luau-execution-session) -> read e write, com a experiência OI3 marcada",
    "reiniciar": "Universes -> universe:write (opcional)",
}


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
                r.setdefault("audio", {})
                r.setdefault("imagem", {})
                r.setdefault("publicacoes", [])
                return r
    except Exception:
        pass
    return {"audio": {}, "imagem": {}, "publicacoes": []}


def gravar_recibos(r):
    os.makedirs(PASTA_RECIBOS, exist_ok=True)
    tmp = ARQ_RECIBOS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=1)
    os.replace(tmp, ARQ_RECIBOS)


# --------------------------------------------------------------------- áudio
def multipart(campos):
    limite = "----OI3" + uuid.uuid4().hex
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
    asset_id = resp.get("assetId")
    estado = ((resp.get("moderationResult") or {}).get("moderationState")) or ""
    return asset_id, estado


def consultar_moderacao(chave, asset_id):
    """pergunta ao Roblox o estado de moderação de um áudio já enviado."""
    try:
        d = http_json("GET", "%s/assets/v1/assets/%s?readMask=moderationResult" % (API, asset_id), chave, tentativas=2, espera_max=30)
        return ((d.get("moderationResult") or {}).get("moderationState")) or ""
    except Exception:
        return ""


TRADUZ = {"Approved": "APROVADO", "Reviewing": "em análise", "Rejected": "RECUSADO"}


NOMES_AUDIO = {"sfx": "efeitos", "vozes1": "vozes 1", "vozes2": "vozes 2", "musica": "música do menu", "ambiente": "ambiente e lanterna", "passos": "passos gravados"}


def conferir_sons(sons):
    """Mostra se cada áudio carregou no servidor de teste do Roblox.
    '_controle' é um som público do próprio Roblox: se ele carrega e o nosso não, é falta de permissão.
    Retorna True (todos ok), False (algum bloqueado) ou None (não deu para saber)."""
    if not isinstance(sons, dict):
        return None
    def num(v):
        try:
            return float(v)
        except Exception:
            return -1.0
    resto = {k: num(v) for k, v in sons.items() if k != "_controle"}
    if not resto:
        return None
    if num(sons.get("_controle")) <= 0:
        aviso("não deu para conferir os sons no servidor de teste (nem o som padrão do Roblox carregou). Confira ouvindo no jogo.")
        return None
    bloqueados = []
    for k in sorted(resto):
        if resto[k] > 0:
            ok("som %s: carregou no Roblox (%.1f s)" % (NOMES_AUDIO.get(k, k), resto[k]))
        else:
            bloqueados.append(k)
            aviso("som %s: NÃO carregou no Roblox (bloqueado: falta liberar para o jogo)" % NOMES_AUDIO.get(k, k))
    return not bloqueados


def explicar_liberacao_manual(universe, lista):
    print("   COMO LIBERAR NA MÃO (no navegador do celular, uma vez por áudio):")
    print("     1. Abra create.roblox.com e entre na sua conta")
    print("     2. Creations > Development Items > Audio")
    print("     3. Toque no áudio (IDs abaixo) > Permissions")
    print("     4. Aba Experiences > Add experiences > digite %s > Add > Done" % universe)
    print("   Áudios: " + ", ".join(str(a) for a in lista))
    print("   OU: edite a chave da Open Cloud e adicione a permissão 'asset-permissions' (write);")
    print("       depois rode este instalador de novo que ele libera sozinho.")


def liberar_audios(chave, universe, ids, recibos):
    """Dá ao jogo (universe) a permissão de USAR cada áudio.
    Sem isso o Roblox deixa o áudio MUDO no jogo, mesmo aprovado e mesmo sendo seu."""
    lista = sorted({int(v) for v in ids.values() if v})
    if not lista:
        return "sem_audio", lista
    pedido = {
        "subjectType": "Universe",
        "subjectId": str(universe),
        "action": "Use",
        "requests": [{"assetId": a} for a in lista],
    }
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
            aviso("A chave não tem a permissão de LIBERAR sons e texturas para o jogo (asset-permissions).")
        else:
            aviso("O Roblox não deixou liberar os áudios agora (%s)." % e.resumo())
        return "falhou", lista
    except Falha as f:
        aviso(str(f))
        return "falhou", lista
    try:
        d = json.loads(resp.decode("utf-8") or "{}")
    except Exception:
        d = {}
    feitos = {int(a) for a in (d.get("successAssetIds") or []) if str(a).isdigit()}
    erros = d.get("errors") or []
    for e in erros:
        codigo = str(e.get("code", "?"))
        if codigo in ("AlreadyGranted", "PermissionAlreadyExists"):
            feitos.add(int(e.get("assetId") or 0))
        else:
            aviso("áudio %s: não liberou (%s)" % (e.get("assetId"), codigo))
    lib = recibos.setdefault("liberados", {})
    lib[str(universe)] = sorted(set(lib.get(str(universe), [])) | feitos)
    gravar_recibos(recibos)
    if feitos and len(feitos) >= len(lista):
        ok("sons e texturas LIBERADOS para o jogo (%d de %d)" % (len(feitos), len(lista)))
        return "ok", lista
    if feitos:
        aviso("só %d de %d recursos foram liberados para o jogo." % (len(feitos), len(lista)))
        return "parcial", lista
    aviso("o Roblox não confirmou a liberação dos áudios.")
    return "falhou", lista


def enviar_audio(chave, criador, nome, info, dados, recibos, tipo="Audio", mime="audio/ogg", gaveta="audio", silencioso=False):
    sha = info["sha256"]
    recibos.setdefault(gaveta, {})
    r = recibos[gaveta].get(sha) or {}
    rotulo = info.get("rotulo", nome)
    if r.get("assetId") and silencioso and r.get("estado") == "Approved":
        return int(r["assetId"])  # textura já aprovada: nem pergunta de novo
    if r.get("assetId"):
        estado = consultar_moderacao(chave, r["assetId"]) or r.get("estado", "")
        if estado and estado != r.get("estado"):
            r["estado"] = estado
            recibos[gaveta][sha] = r
            gravar_recibos(recibos)
        if estado == "Rejected":
            aviso("%s: o Roblox RECUSOU na moderação (ID %s); o jogo segue sem ele." % (rotulo, r["assetId"]))
            return 0
        if not silencioso:
            ok("%s: já enviado (ID %s) - moderação: %s" % (rotulo, r["assetId"], TRADUZ.get(estado, estado or "?")))
            if estado == "Reviewing":
                aviso("   enquanto estiver 'em análise' esse som fica MUDO no jogo (o Roblox libera sozinho depois).")
        return int(r["assetId"])
    if r.get("operationId"):
        try:
            asset_id, estado = ler_operacao(chave, r["operationId"])
        except Falha as f:
            aviso(str(f))
            return 0
        except ErroHTTP as e:
            aviso(explicar(e, "audio"))
            return 0
        if asset_id:
            r.update({"assetId": str(asset_id), "estado": estado})
            recibos[gaveta][sha] = r
            gravar_recibos(recibos)
            ok("%s: pronto (ID %s, moderação: %s)" % (rotulo, asset_id, TRADUZ.get(estado, estado or "?")))
            return 0 if estado == "Rejected" else int(asset_id)
        aviso("%s: o Roblox ainda está processando o envio anterior; seguindo sem ele por enquanto." % rotulo)
        return 0
    pedido = {
        "assetType": tipo,
        "displayName": ("%s %s %s" % (JOGO, rotulo, REVISAO))[:50],
        "description": "Audio do jogo OI3 (%s). Gerado pelo instalador." % rotulo,
        "creationContext": {"creator": criador},
    }
    corpo, tipo = multipart([
        ("request", json.dumps(pedido).encode("utf-8"), None, "application/json"),
        ("fileContent", dados, nome.split("/")[-1], mime),
    ])
    try:
        _, resp = http("POST", API + "/assets/v1/assets", chave, corpo, tipo, tentativas=3, espera_max=300)
    except ErroHTTP as e:
        if e.codigo == 401:
            raise Falha(explicar(e, "audio") + "\n   Nada foi publicado.")
        aviso("%s: %s" % (rotulo, explicar(e, "audio")))
        aviso("Seguindo sem esse áudio (o jogo funciona com legendas).")
        return 0
    op = json.loads(resp.decode("utf-8") or "{}")
    op_id = op.get("operationId") or (op.get("path") or "").split("/")[-1]
    if not op_id:
        aviso("%s: resposta inesperada do Roblox; seguindo sem o áudio." % rotulo)
        return 0
    r = {"nome": nome, "operationId": op_id, "enviadoEm": int(time.time())}
    recibos[gaveta][sha] = r
    gravar_recibos(recibos)
    print("   ...enviado, esperando o Roblox processar %s" % rotulo, end="", flush=True)
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
                aviso("%s: o Roblox recusou na moderação; seguindo sem ele." % rotulo)
                return 0
            ok("%s: ID %s (moderação: %s)" % (rotulo, asset_id, TRADUZ.get(estado, estado or "em análise")))
            if estado != "Approved" and not silencioso:
                aviso("   enquanto estiver 'em análise' esse som fica MUDO no jogo (o Roblox libera sozinho depois).")
            return int(asset_id)
    print("")
    aviso("%s: ainda processando. Rode o instalador de novo daqui a uns minutos para incluir este áudio." % rotulo)
    return 0


def dono_do_universo(universe):
    try:
        d = http_json("GET", GAMES + "/v1/games?universeIds=" + universe, tentativas=2, espera_max=20)
        c = d["data"][0]["creator"]
        return c.get("type"), str(c.get("id")), c.get("name"), d["data"][0].get("name")
    except Exception:
        return None


# --------------------------------------------------------------------- place / luau
def publicar(chave, universe, place, dados, tipo_versao):
    url = "%s/universes/v1/%s/places/%s/versions?versionType=%s" % (API, universe, place, tipo_versao)
    _, resp = http("POST", url, chave, dados, "application/xml", tentativas=3, espera_max=300)
    d = json.loads(resp.decode("utf-8"))
    return int(d["versionNumber"])


def rodar_luau(chave, universe, place, versao, script, limite_s=300):
    if len(script.encode("utf-8")) > LIMITE_TAREFA:
        raise Falha("Tarefa de teste maior que 200 kB.")
    url = "%s/cloud/v2/universes/%s/places/%s/versions/%s/luau-execution-session-tasks" % (API, universe, place, versao)
    tarefa = http_json("POST", url, chave, {"script": script, "timeout": "240s"}, tentativas=3)
    caminho = tarefa.get("path")
    if not caminho:
        raise Falha("Resposta estranha do Luau Execution.")
    inicio = time.time()
    print("   ...rodando na nuvem", end="", flush=True)
    while tarefa.get("state") not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() - inicio > limite_s:
            print("")
            raise Falha("O teste demorou demais na nuvem. Tente de novo em alguns minutos.")
        time.sleep(3)
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
    import xml.etree.ElementTree as ET
    xml = arquivos["place.rbxlx"]
    raiz = ET.fromstring(xml)
    itens = raiz.findall(".//Item")
    ok("place .rbxlx válido (%d instâncias, %d kB)" % (len(itens), len(xml) // 1024))
    for ids in ({}, {"sfx": 123, "vozes1": 456}):
        teste = montar_place(xml, ids)
        ET.fromstring(teste)
    ok("troca dos IDs de áudio funciona")
    mats = materiais_texturas()
    falsos = {}
    k = 900000
    for material, mapas in mats.items():
        for arq in mapas.values():
            k += 1
            falsos[arq] = k
    for teste_ids in (falsos, {}):
        t = montar_place(xml, {"sfx": 1}, teste_ids)
        ET.fromstring(t)
        if b"rbxassetid://OI3TEX" in t:
            raise Falha("sobrou marcador de textura no place")
    t = montar_place(xml, {"sfx": 1}, falsos).decode("utf-8")
    ligados = sum(1 for m in mats if (">" + m + "<") in t)
    if ligados != len(mats):
        raise Falha("texturas não ligaram (%d de %d)" % (ligados, len(mats)))
    ok("texturas: %d materiais (%d imagens) se ligam no place" % (len(mats), len(falsos)))
    script = arquivos["teste_nuvem.luau"].decode("utf-8")
    tam = len(script.encode("utf-8"))
    if tam > LIMITE_TAREFA:
        raise Falha("tarefa de teste grande demais (%d bytes)" % tam)
    ok("tarefa do teste na nuvem: %d bytes (limite 200 kB)" % tam)
    for nome, info in MANIFESTO.items():
        if info.get("chave"):
            ok("áudio %s: %d kB" % (info.get("rotulo", nome), info["tamanho"] // 1024))
    ok("instalador compila (este próprio arquivo rodou)")
    print("\nTUDO OK (nada foi enviado ao Roblox).")


def cmd_recibos():
    r = ler_recibos()
    titulo("Recibos (%s)" % ARQ_RECIBOS)
    if not r["audio"]:
        print("   nenhum áudio enviado ainda")
    for sha, info in r["audio"].items():
        print("   %s -> ID %s (%s) op=%s" % (info.get("nome"), info.get("assetId", "-"), info.get("estado", "?"), info.get("operationId", "-")))
    for p in r["publicacoes"][-5:]:
        print("   publicado: %s versão %s em %s" % (p.get("revisao"), p.get("versao"), time.strftime("%d/%m %H:%M", time.localtime(p.get("quando", 0)))))


def cmd_install(pular_teste=False):
    titulo("%s %s - instalador" % (JOGO, REVISAO))
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

    criador = {"userId": dono}
    info = dono_do_universo(universe)
    if info:
        tipo, ident, nome_dono, nome_jogo = info
        ok("Experiência: %s (dono: %s %s)" % (nome_jogo, tipo, nome_dono))
        if tipo == "Group":
            criador = {"groupId": ident}
            aviso("A experiência é de um GRUPO: os áudios serão enviados em nome do grupo %s." % ident)
        elif ident != dono:
            aviso("O dono da experiência (%s) é diferente do UserId informado (%s)." % (ident, dono))
    else:
        aviso("Não consegui confirmar o dono da experiência (seguindo).")

    passo(3, "Enviando áudios (opcionais: não travam a instalação)")
    recibos = ler_recibos()
    ids = {}
    for nome, inf in MANIFESTO.items():
        if inf.get("chave"):
            ids[inf["chave"]] = enviar_audio(chave, criador, nome, inf, arquivos[nome], recibos)
    sem = [k for k, v in ids.items() if not v]
    if sem:
        aviso("Sem áudio por enquanto: %s (o jogo usa legendas no lugar)." % ", ".join(sem))
    ids_tex = {}
    texturas = [(nome, inf) for nome, inf in MANIFESTO.items() if inf.get("textura")]
    if texturas:
        print("   Enviando texturas realistas (%d imagens, opcionais; só na 1ª vez demora)..." % len(texturas))
        for nome, inf in texturas:
            ids_tex[inf["textura"]] = enviar_audio(chave, criador, nome, inf, arquivos[nome], recibos,
                                                   "Image", "image/jpeg", "imagem", silencioso=True)
        prontas = sum(1 for v in ids_tex.values() if v)
        if prontas == len(texturas):
            ok("texturas prontas: %d de %d" % (prontas, len(texturas)))
        else:
            aviso("texturas prontas: %d de %d (as que faltam usam o material normal do Roblox)" % (prontas, len(texturas)))
    print("   Liberando sons e texturas para o jogo usar (sem isso o Roblox bloqueia)...")
    todos = dict(ids)
    todos.update({"tex_" + k: v for k, v in ids_tex.items()})
    liberacao, _ = liberar_audios(chave, universe, todos, recibos)
    lista_audio = sorted({int(v) for v in ids.values() if v})
    if liberacao in ("falhou", "parcial"):
        aviso("   (o passo a passo para liberar na mão aparece no FINAL)")

    passo(4, "Montando o place")
    place_xml = montar_place(arquivos["place.rbxlx"], ids, ids_tex)
    ok("place pronto (%d kB) com áudios: %s" % (len(place_xml) // 1024, json.dumps(ids)))

    som_ok = None
    passo(5, "Teste isolado na nuvem (versão salva, NÃO publicada)")
    try:
        v_teste = publicar(chave, universe, place, place_xml, "Saved")
    except ErroHTTP as e:
        raise Falha(explicar(e, "publicar"))
    ok("versão de teste salva: %d" % v_teste)
    if pular_teste:
        aviso("Teste na nuvem PULADO a seu pedido (--pular-teste).")
    else:
        try:
            tarefa, logs = rodar_luau(chave, universe, place, v_teste, arquivos["teste_nuvem.luau"].decode("utf-8"))
        except ErroHTTP as e:
            if e.codigo == 403:
                raise Falha(explicar(e, "luau") + "\n   Nada foi publicado. Depois de ajustar a chave, rode de novo.")
            raise Falha("Teste na nuvem não rodou: " + explicar(e, "luau") + "\n   Nada foi publicado.")
        res, problema = resultado_teste(tarefa)
        if problema or not res or not res.get("ok"):
            erro("O teste isolado FALHOU. Nada foi publicado.")
            if problema:
                print("      " + problema)
            for e in (res or {}).get("erros", [])[:12]:
                print("      - " + str(e)[:300])
            for linha in logs[-15:]:
                print("      log: " + str(linha)[:300])
            print("\n   Copie estas mensagens e mande no chat para eu corrigir.")
            sys.exit(2)
        inf = res.get("info", {})
        ok("teste passou: %s módulos, mapa com %s peças, menu com %s peças, animações R6 carregadas: %s" % (
            inf.get("modulos"), inf.get("pecasMapa"), inf.get("pecasMenu"), inf.get("animacoesCarregadas")))
        if inf.get("pecasLanterna"):
            ok("lanterna da primeira pessoa montada (%s peças)" % inf.get("pecasLanterna"))
        nomes = {"VO": "Vô", "KE": "Keko", "NI": "Nina", "ME": "menino"}
        for cod, txt in sorted((inf.get("atores") or {}).items()):
            if str(txt).startswith("falhou"):
                aviso("avatar %s: %s" % (nomes.get(cod, cod), txt))
            else:
                ok("avatar %s (itens do catálogo): %s" % (nomes.get(cod, cod), txt))
        som_ok = conferir_sons(inf.get("sons"))
        if som_ok is False and liberacao == "ok":
            aviso("   (a liberação pode levar alguns minutos para valer no Roblox)")

    passo(6, "Publicando")
    try:
        v_pub = publicar(chave, universe, place, place_xml, "Published")
    except ErroHTTP as e:
        raise Falha(explicar(e, "publicar"))
    ok("publicado! versão %d" % v_pub)
    recibos["publicacoes"].append({"revisao": REVISAO, "versao": v_pub, "teste": v_teste, "quando": int(time.time()), "audio": ids})
    gravar_recibos(recibos)

    passo(7, "Conferindo a versão publicada")
    conferencia = (
        'local RS = game:GetService("ReplicatedStorage")\n'
        'local C = require(RS.OI3.Config)\n'
        'local R = require(RS.OI3.Recursos)\n'
        'return game:GetService("HttpService"):JSONEncode({revisao = C.REVISAO, audio = R.audio})\n'
    )
    try:
        tarefa, _ = rodar_luau(chave, universe, place, v_pub, conferencia, 180)
        resultados = (tarefa.get("output") or {}).get("results") or []
        dados = json.loads(resultados[0]) if resultados else {}
        if dados.get("revisao") == REVISAO:
            ok("versão no ar: %s, áudios %s" % (dados.get("revisao"), json.dumps(dados.get("audio"))))
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
    if lista_audio and (som_ok is False or (liberacao != "ok" and som_ok is not True)):
        print("")
        aviso("IMPORTANTE: os sons só tocam depois que os áudios forem LIBERADOS para o jogo.")
        explicar_liberacao_manual(universe, lista_audio)
    elif som_ok is True:
        ok("sons conferidos no servidor do Roblox: todos carregam.")
    if sem:
        print("   Áudio ainda pendente: %s. Rode este instalador de novo mais tarde para incluir." % ", ".join(sem))


def main():
    args = [a.lower() for a in sys.argv[1:]]
    cmd = args[0] if args else "install"
    try:
        if cmd in ("install", "instalar"):
            cmd_install(pular_teste="--pular-teste" in args)
        elif cmd in ("testar", "check", "teste"):
            cmd_testar()
        elif cmd in ("recibos", "status"):
            cmd_recibos()
        else:
            print("Comandos: install | testar | recibos")
    except Falha as f:
        print("")
        erro(str(f))
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n   Cancelado.")
        sys.exit(130)


if __name__ == "__main__":
    main()
