#!/usr/bin/env python3
"""BIZARRE BATTLEGROUNDS :: gera o instalador de um arquivo só (BIZARRE_AJUSTE<N>.py).

Passos: monta o place (Lune), junta place + teste da nuvem num zip, calcula sha256 de cada
arquivo, codifica em base85 e injeta no modelo.
uso (na raiz do repositório): python3 bizarre/tools/gerar_instalador.py AJUSTE-1
"""
import base64
import hashlib
import io
import json
import os
import subprocess
import sys
import zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(RAIZ)


def main():
    revisao = sys.argv[1] if len(sys.argv) > 1 else "AJUSTE-1"
    numero = revisao.split("-")[-1]
    nome_arquivo = "BIZARRE_AJUSTE%s.py" % numero
    with open(os.path.join(RAIZ, "src", "ReplicatedStorage", "BB", "Config.luau"), encoding="utf-8") as f:
        if ('Config.REVISAO = "%s"' % revisao) not in f.read():
            sys.exit("Config.REVISAO não é %s" % revisao)
    subprocess.run(["lune", "run", "bizarre/tools/montar_place.luau"], cwd=REPO, check=True)

    entradas = [
        ("place.rbxlx", os.path.join(RAIZ, "dist", "BB_place.rbxlx")),
        ("teste_nuvem.luau", os.path.join(RAIZ, "tools", "teste_nuvem.luau")),
    ]
    manifesto = {}
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for nome, caminho in entradas:
            with open(caminho, "rb") as f:
                dados = f.read()
            z.writestr(nome, dados)
            manifesto[nome] = {"sha256": hashlib.sha256(dados).hexdigest(), "tamanho": len(dados)}
    bruto = buf.getvalue()
    sha_zip = hashlib.sha256(bruto).hexdigest()
    b85 = base64.b85encode(bruto).decode("ascii")
    linhas = "\n".join(b85[i:i + 120] for i in range(0, len(b85), 120))

    with open(os.path.join(RAIZ, "tools", "instalador_modelo.py"), encoding="utf-8") as f:
        modelo = f.read()
    saida = (modelo.replace("__REVISAO__", revisao)
             .replace("__NOME_ARQUIVO__", nome_arquivo)
             .replace("__MANIFESTO__", json.dumps(manifesto, ensure_ascii=False, indent=1))
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
