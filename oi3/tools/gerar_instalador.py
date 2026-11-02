#!/usr/bin/env python3
"""OI3 :: gera o instalador de um arquivo só (OI3_AJUSTE<N>.py).

Passos: monta o place (Lune), junta place + teste da nuvem + áudios num zip,
calcula sha256 de cada arquivo, codifica em base85 e injeta no modelo.
uso: python3 oi3/tools/gerar_instalador.py AJUSTE-1
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
    nome_arquivo = "OI3_AJUSTE%s.py" % numero
    # confere se a revisão do código bate
    with open(os.path.join(RAIZ, "src", "ReplicatedStorage", "OI3", "Config.luau"), encoding="utf-8") as f:
        if ('Config.REVISAO = "%s"' % revisao) not in f.read():
            sys.exit("Config.REVISAO não é %s" % revisao)
    subprocess.run(["lune", "run", "oi3/tools/montar_place.luau"], cwd=REPO, check=True)

    entradas = [
        ("place.rbxlx", os.path.join(RAIZ, "dist", "OI3_place.rbxlx"), {}),
        ("teste_nuvem.luau", os.path.join(RAIZ, "tools", "teste_nuvem.luau"), {}),
    ]
    with open(os.path.join(RAIZ, "src", "ReplicatedStorage", "OI3", "AudioMapa.luau"), encoding="utf-8") as f:
        mapa = f.read()
    for chave, arq, rotulo in [("sfx", "oi3_sfx.ogg", "efeitos"), ("vozes1", "oi3_vozes1.ogg", "vozes1"),
                               ("vozes2", "oi3_vozes2.ogg", "vozes2"), ("musica", "oi3_musica.ogg", "musica menu"),
                               ("ambiente", "oi3_ambiente.ogg", "ambiente"), ("passos", "oi3_passos.ogg", "passos gravados")]:
        caminho = os.path.join(RAIZ, "assets", arq)
        if os.path.exists(caminho) and ('"%s"' % chave) in mapa:
            entradas.append(("audio/" + arq, caminho, {"chave": chave, "rotulo": rotulo}))

    # AJUSTE-5: texturas realistas (feitas por código em tools/texturas.py)
    pasta_tex = os.path.join(RAIZ, "assets", "texturas")
    with open(os.path.join(pasta_tex, "texturas.json"), encoding="utf-8") as f:
        lista_tex = json.load(f)
    for t in lista_tex:
        for mapa, arq in t["mapas"].items():
            entradas.append(("textura/" + arq, os.path.join(pasta_tex, arq),
                             {"textura": arq[:-4], "material": t["nome"], "mapa": mapa,
                              "rotulo": "textura %s (%s)" % (t["nome"].replace("OI3_", ""), mapa)}))

    manifesto = {}
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for nome, caminho, extra in entradas:
            with open(caminho, "rb") as f:
                dados = f.read()
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
             .replace("__PAYLOAD_SHA__", sha_zip)
             .replace("__PAYLOAD__", linhas))
    destino = os.path.join(RAIZ, "dist", nome_arquivo)
    with open(destino, "w", encoding="utf-8") as f:
        f.write(saida)
    print("instalador: %s (%d kB, zip %d kB)" % (destino, os.path.getsize(destino) // 1024, len(bruto) // 1024))
    for nome, info in manifesto.items():
        print("  %-22s %8d bytes  %s" % (nome, info["tamanho"], info["sha256"][:16]))


if __name__ == "__main__":
    main()
