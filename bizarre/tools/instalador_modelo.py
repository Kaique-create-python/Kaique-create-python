#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BIZARRE BATTLEGROUNDS - instalador __REVISAO__ (Roblox Open Cloud, sem Roblox Studio)

Como usar no Termux:
    cp ~/storage/downloads/__NOME_ARQUIVO__ ~ && cd ~ && python __NOME_ARQUIVO__ install

Outros comandos:
    python __NOME_ARQUIVO__ testar     -> confere o pacote sem internet
    python __NOME_ARQUIVO__ recibos    -> mostra as publicações já feitas

O que ele faz (nessa ordem):
  1) confere o próprio pacote (sha256 de cada arquivo)
  2) salva uma versão de TESTE (não publicada) e roda o teste isolado na nuvem:
     monta a cidade, os 6 Stands e faz uma luta de teste com TODOS os golpes
  3) só se o teste passar: publica e confere
A chave da Open Cloud é pedida escondida, nunca aparece na tela e nunca é salva.
Nada aqui apaga o Place nem o DataStore dos jogadores (as estatísticas só somam).
Os sons são da biblioteca liberada do Roblox: não precisa enviar áudio nenhum.
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
PAYLOAD_SHA256 = "__PAYLOAD_SHA__"
PAYLOAD = """
__PAYLOAD__
"""

NOMES_STANDS = {"MARACATU": "MARACATU", "BOSSA_NOVA": "BOSSA NOVA", "FREVO": "FREVO", "AXE": "AXÉ", "CHORINHO": "CHORINHO", "FUNK": "FUNK"}


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


# --------------------------------------------------------------------- place / luau
def publicar(chave, universe, place, dados, tipo_versao):
    url = "%s/universes/v1/%s/places/%s/versions?versionType=%s" % (API, universe, place, tipo_versao)
    _, resp = http("POST", url, chave, dados, "application/xml", tentativas=3, espera_max=300)
    d = json.loads(resp.decode("utf-8"))
    return int(d["versionNumber"])


def rodar_luau(chave, universe, place, versao, script, limite_s=420, mensagem="...rodando na nuvem"):
    if len(script.encode("utf-8")) > LIMITE_TAREFA:
        raise Falha("Tarefa de teste maior que 200 kB.")
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
    ok("cidade: %s peças, %s quebráveis" % (inf.get("pecasMapa"), inf.get("quebraveis")))
    if inf.get("quebraTeste"):
        ok("quebrar e reconstruir: %s" % inf["quebraTeste"])
    stands = inf.get("stands") or {}
    for sid in ["MARACATU", "BOSSA_NOVA", "FREVO", "AXE", "CHORINHO", "FUNK"]:
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
    import xml.etree.ElementTree as ET
    xml = arquivos["place.rbxlx"]
    raiz = ET.fromstring(xml)
    itens = raiz.findall(".//Item")
    ok("place .rbxlx válido (%d instâncias, %d kB)" % (len(itens), len(xml) // 1024))
    scripts = [i for i in itens if i.get("class") in ("Script", "LocalScript", "ModuleScript")]
    ok("%d scripts dentro do place" % len(scripts))
    if b'"' + REVISAO.encode() + b'"' not in xml:
        raise Falha("a revisão %s não está no place" % REVISAO)
    ok("revisão %s confere" % REVISAO)
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
    for p in r["publicacoes"][-8:]:
        print("   %s: versão %s (teste %s) em %s" % (p.get("revisao"), p.get("versao"), p.get("teste"), time.strftime("%d/%m %H:%M", time.localtime(p.get("quando", 0)))))


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
    info = dono_do_universo(universe)
    if info:
        tipo, ident, nome_dono, nome_jogo = info
        ok("Experiência: %s (dono: %s %s)" % (nome_jogo, tipo, nome_dono))
        if tipo == "User" and ident != dono:
            aviso("O dono da experiência (%s) é diferente do UserId informado (%s)." % (ident, dono))
    else:
        aviso("Não consegui confirmar o dono da experiência (seguindo).")

    place_xml = arquivos["place.rbxlx"]
    recibos = ler_recibos()

    passo(3, "Teste isolado na nuvem (versão salva, NÃO publicada)")
    try:
        v_teste = publicar(chave, universe, place, place_xml, "Saved")
    except ErroHTTP as e:
        raise Falha(explicar(e, "publicar"))
    ok("versão de teste salva: %d" % v_teste)
    if pular_teste:
        aviso("Teste na nuvem PULADO a seu pedido (--pular-teste).")
    else:
        try:
            tarefa, logs = rodar_luau(chave, universe, place, v_teste, arquivos["teste_nuvem.luau"].decode("utf-8"),
                                      mensagem="...rodando na nuvem (a luta de teste com todos os golpes leva uns 2 minutos)")
        except ErroHTTP as e:
            if e.codigo == 403:
                raise Falha(explicar(e, "luau") + "\n   Nada foi publicado. Depois de ajustar a chave, rode de novo.")
            raise Falha("Teste na nuvem não rodou: " + explicar(e, "luau") + "\n   Nada foi publicado.")
        res, problema = resultado_teste(tarefa)
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

    passo(4, "Publicando")
    try:
        v_pub = publicar(chave, universe, place, place_xml, "Published")
    except ErroHTTP as e:
        raise Falha(explicar(e, "publicar"))
    ok("publicado! versão %d" % v_pub)
    recibos["publicacoes"].append({"revisao": REVISAO, "versao": v_pub, "teste": v_teste, "quando": int(time.time())})
    gravar_recibos(recibos)

    passo(5, "Conferindo a versão publicada")
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
