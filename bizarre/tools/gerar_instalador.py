#!/usr/bin/env python3
"""BIZARRE BATTLEGROUNDS :: gera o instalador de um arquivo só (BIZARRE_AJUSTE<N>.py).

Passos: monta o place binário (Lune, em cima do mapa Morioh), deixa SEM compressão o pedaço do
arquivo onde fica o marcador das vozes (para o instalador trocar pelo número do áudio sem precisar
de Lune no celular), junta place + teste da nuvem + vozes num zip, calcula sha256 de cada arquivo,
codifica em base85 e injeta no modelo.
uso (na raiz do repositório): python3 bizarre/tools/gerar_instalador.py AJUSTE-2
"""
import base64
import hashlib
import io
import json
import os
import struct
import subprocess
import sys
import zipfile
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(RAIZ)
MARCADOR_VOZES = b"BBVOZ" + b"_" * 59  # igual ao de montar_place.luau (64 letras)
# AJUSTE-8: mais dois marcadores (sons do anime e imagens do Canva), todos no mesmo pedaço
MARCADORES = [MARCADOR_VOZES, b"BBVZA" + b"_" * 59, b"BBIMG" + b"_" * 59, b"BBSFX" + b"_" * 59]  # AJUSTE-13: + socos


def lz4_bloco(src, tamanho):
    """descompressor LZ4 (formato de bloco) - o mesmo que o Roblox usa nos pedaços do .rbxl"""
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
        raise SystemExit("LZ4: tamanho errado (%d != %d)" % (len(dst), tamanho))
    return bytes(dst)


def pedacos(dados):
    """lista (inicio, nome, comprimido, descomprimido, inicio_dos_dados) de cada pedaço do .rbxl"""
    if dados[:8] != b"<roblox!":
        raise SystemExit("o place não é binário")
    off = 32
    lista = []
    while off < len(dados):
        nome = dados[off:off + 4]
        clen, ulen, _ = struct.unpack_from("<III", dados, off + 4)
        ini = off + 16
        lista.append((off, nome, clen, ulen, ini))
        off = ini + (clen if clen else ulen)
        if nome == b"END\x00":
            break
    return lista


def descomprimir_marcador(dados):
    """deixa sem compressão os pedaços que têm os marcadores (o resto do arquivo fica igual)"""
    saida = bytearray(dados[:32])
    achou = {m: 0 for m in MARCADORES}
    for off, nome, clen, ulen, ini in pedacos(dados):
        bruto = dados[ini:ini + (clen if clen else ulen)]
        if clen and nome == b"PROP" and clen < 2_000_000:
            if bruto[:4] == b"\x28\xb5\x2f\xfd":
                raise SystemExit("pedaço em ZSTD: atualize o gerador")
            cru = lz4_bloco(bruto, ulen)
            if any(m in cru for m in MARCADORES):
                for m in MARCADORES:
                    achou[m] += cru.count(m)
                saida += nome + struct.pack("<III", 0, len(cru), 0) + cru
                continue
        saida += dados[off:ini] + bruto
    for m, n in achou.items():
        if n != 1:
            raise SystemExit("o marcador %s apareceu %d vezes (precisa ser 1)" % (m[:5].decode(), n))
        if bytes(saida).count(m) != 1:
            raise SystemExit("o marcador %s não ficou visível no arquivo" % m[:5].decode())
    return bytes(saida)


def nome_no_jogo(rel):
    """bizarre/src/StarterPlayerScripts/Main.client.luau -> StarterPlayer.StarterPlayerScripts.Main"""
    partes = rel.split("/")
    partes[-1] = partes[-1][:-5]
    for sufixo in (".server", ".client"):
        if partes[-1].endswith(sufixo):
            partes[-1] = partes[-1][:-len(sufixo)]
    if partes[0] in ("StarterPlayerScripts", "StarterCharacterScripts"):
        partes.insert(0, "StarterPlayer")
    return ".".join(partes)


def conhecidos():
    """tamanho:adler32 de cada script, em todas as versões já feitas (git) e na atual"""
    mapa = {}

    def juntar(rel, dados):
        mapa.setdefault(nome_no_jogo(rel), set()).add("%d:%d" % (len(dados), zlib.adler32(dados) & 0xFFFFFFFF))

    base = os.path.join(RAIZ, "src")
    for pasta, _, arquivos in os.walk(base):
        for arq in arquivos:
            if arq.endswith(".luau"):
                caminho = os.path.join(pasta, arq)
                juntar(os.path.relpath(caminho, base).replace(os.sep, "/"), open(caminho, "rb").read())
    try:
        commits = subprocess.run(["git", "log", "--format=%H", "--", "bizarre/src"], cwd=REPO, capture_output=True, text=True, check=True).stdout.split()
        for c in commits:
            lista = subprocess.run(["git", "ls-tree", "-r", "--name-only", c, "bizarre/src"], cwd=REPO, capture_output=True, text=True, check=True).stdout.split("\n")
            for a in lista:
                if a.endswith(".luau"):
                    dados = subprocess.run(["git", "show", "%s:%s" % (c, a)], cwd=REPO, capture_output=True, check=True).stdout
                    juntar(a[len("bizarre/src/"):], dados)
    except Exception as e:  # sem git (ZIP das fontes): só a versão atual
        print("aviso: sem histórico do git (%s); só a versão atual entra como conhecida" % type(e).__name__)
    return {k: sorted(v) for k, v in sorted(mapa.items())}


def main():
    revisao = sys.argv[1] if len(sys.argv) > 1 else "AJUSTE-2"
    if revisao == "AJUSTE-15":
        from gerar_ajuste15 import main as gerar15
        return gerar15([])
    if revisao == "AJUSTE-14":
        from gerar_ajuste14 import main as gerar14
        return gerar14([])
    numero = revisao.split("-")[-1]
    nome_arquivo = "BIZARRE_AJUSTE%s.py" % numero
    with open(os.path.join(RAIZ, "src", "ReplicatedStorage", "BB", "Config.luau"), encoding="utf-8") as f:
        if ('Config.REVISAO = "%s"' % revisao) not in f.read():
            sys.exit("Config.REVISAO não é %s" % revisao)
    subprocess.run(["lune", "run", "bizarre/tools/montar_place.luau"], cwd=REPO, check=True)

    with open(os.path.join(RAIZ, "dist", "BB_place.rbxl"), "rb") as f:
        place = descomprimir_marcador(f.read())
    entradas = [
        ("place.rbxl", place, {}),
        ("teste_nuvem.luau", open(os.path.join(RAIZ, "tools", "teste_nuvem.luau"), "rb").read(), {}),
    ]
    vozes = os.path.join(RAIZ, "assets", "vozes.ogg")
    if os.path.isfile(vozes):
        ordem = json.load(open(os.path.join(RAIZ, "assets", "vozes_ordem.json")))
        entradas.append(("vozes.ogg", open(vozes, "rb").read(), {"audio": "vozes", "rotulo": "vozes dos Stands", "trechos": len(ordem)}))
    # AJUSTE-8: sons do anime (áudio separado) e as artes do Canva (opcionais: nunca travam)
    anime = os.path.join(RAIZ, "assets", "vozes_anime.ogg")
    if os.path.isfile(anime):
        ordem = json.load(open(os.path.join(RAIZ, "assets", "vozes_anime_ordem.json")))
        entradas.append(("vozes_anime.ogg", open(anime, "rb").read(), {"audio": "anime", "rotulo": "sons do anime (ORA, MUDA, ZA WARUDO)", "trechos": len(ordem)}))
    # AJUSTE-13: socos do dono tratados (tools/sons_sfx.py), num áudio só
    sfx = os.path.join(RAIZ, "assets", "sfx.ogg")
    if os.path.isfile(sfx):
        ordem = json.load(open(os.path.join(RAIZ, "assets", "sfx_ordem.json")))
        entradas.append(("sfx.ogg", open(sfx, "rb").read(), {"audio": "sfx", "rotulo": "socos do dono (grave e estourado)", "trechos": len(ordem)}))
    for arq, chave, rotulo in (("logo.png", "logo", "logo do jogo"), ("fundo_menu.jpg", "fundo", "fundo do menu"), ("carregando.jpg", "carregando", "tela de carregamento")):
        caminho = os.path.join(RAIZ, "assets", "imagens", arq)
        if os.path.isfile(caminho):
            entradas.append((arq, open(caminho, "rb").read(), {"imagem": chave, "rotulo": rotulo}))
    manifesto = {}
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for nome, dados, extra in entradas:
            z.writestr(nome, dados)
            info = {"sha256": hashlib.sha256(dados).hexdigest(), "tamanho": len(dados)}
            info.update(extra)
            manifesto[nome] = info
    bruto = buf.getvalue()
    sha_zip = hashlib.sha256(bruto).hexdigest()
    b85 = base64.b85encode(bruto).decode("ascii")
    linhas = "\n".join(b85[i:i + 120] for i in range(0, len(b85), 120))

    with open(os.path.join(RAIZ, "tools", "instalador_modelo.py"), encoding="utf-8") as f:
        modelo = f.read()
    saida = (modelo.replace("__REVISAO__", revisao)
             .replace("__NOME_ARQUIVO__", nome_arquivo)
             .replace("__MANIFESTO__", json.dumps(manifesto, ensure_ascii=False, indent=1))
             .replace("__CONHECIDOS__", json.dumps(conhecidos(), ensure_ascii=False))
             .replace("__PAYLOAD_SHA__", sha_zip)
             .replace("__PAYLOAD__", linhas))
    destino = os.path.join(RAIZ, "dist", nome_arquivo)
    with open(destino, "w", encoding="utf-8") as f:
        f.write(saida)
    print("instalador: %s (%d kB, zip %d kB)" % (destino, os.path.getsize(destino) // 1024, len(bruto) // 1024))
    for nome, info in manifesto.items():
        print("  %-18s %8d bytes  %s" % (nome, info["tamanho"], info["sha256"][:16]))


if __name__ == "__main__":
    main()
