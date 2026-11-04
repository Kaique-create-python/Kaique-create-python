#!/usr/bin/env python3
"""BIZARRE BATTLEGROUNDS :: junta as vozes dos Stands num áudio só ("sprite").

As vozes são geradas no ElevenLabs com vozes do banco deles (não são os dubladores do anime).
Este script corta o silêncio, acelera as rajadas (ORA ORA / DORA DORA cabem no tempo do golpe),
iguala o volume, junta tudo em bizarre/assets/vozes.ogg e escreve os tempos de cada trecho em
Sons.VOZES (bizarre/src/ReplicatedStorage/BB/Sons.luau).

uso (na raiz): python3 bizarre/tools/vozes.py <pasta_com_os_mp3>
Cada arquivo se chama NOME.mp3 (ORA.mp3, ORA_FINAL.mp3, ZA_WARUDO.mp3...).
"""
import json
import os
import re
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "assets", "vozes.ogg")
SONS = os.path.join(RAIZ, "src", "ReplicatedStorage", "BB", "Sons.luau")
# ordem fixa dos trechos: voz nova entra SEMPRE no fim. Assim um áudio antigo (já enviado ao
# Roblox) continua certo para as vozes que ele tem, se o envio do novo falhar.
ORDEM = os.path.join(RAIZ, "assets", "vozes_ordem.json")
SR = 44100
INTERVALO = 0.25  # silêncio entre um trecho e outro (o celular nunca "vaza" para o vizinho)

# nome -> (aceleração, duração máxima em s, volume no jogo)
# As rajadas tocam junto com a barragem: começam em 0,18 s e o golpe final é em 1,52 s.
REGRAS = {
    "ORA": (2.2, 1.42, 1.0),
    "MUDA": (2.0, 1.42, 1.0),
    "DORA": (1.45, 1.42, 1.0),
    "HORA": (1.6, 0.9, 1.0),
}
# gritos que não têm gravação própria usam o de outro
APELIDOS = {"FOGO": "CROSSFIRE", "KQ": "KQ_BOMBA"}


def rodar(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("ffmpeg falhou: " + " ".join(cmd) + "\n" + r.stderr[-800:])
    return r


def duracao(caminho):
    r = rodar(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", caminho])
    return float(r.stdout.strip())


def tratar(entrada, saida_wav, nome):
    acel, maximo, _ = REGRAS.get(nome, (1.0, 9.0, 1.0))
    filtros = [
        # tira o silêncio do começo e do fim
        "silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.02",
        "areverse",
        "silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.04",
        "areverse",
    ]
    if acel != 1.0:
        a = acel
        while a > 2.0:  # atempo aceita até 2.0 por vez
            filtros.append("atempo=2.0")
            a /= 2.0
        filtros.append("atempo=%.4f" % a)
    filtros.append("loudnorm=I=-14:TP=-1.5:LRA=11")
    filtros.append("aresample=%d" % SR)
    rodar(["ffmpeg", "-y", "-v", "error", "-i", entrada, "-af", ",".join(filtros), "-ac", "1", "-ar", str(SR), saida_wav])
    d = duracao(saida_wav)
    if d > maximo:
        cortado = saida_wav + ".corte.wav"
        rodar(["ffmpeg", "-y", "-v", "error", "-i", saida_wav, "-af", "afade=t=out:st=%.3f:d=0.08" % (maximo - 0.08), "-t", "%.3f" % maximo, cortado])
        os.replace(cortado, saida_wav)
        d = maximo
    return d


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    pasta = sys.argv[1]
    achados = {os.path.splitext(f)[0].upper(): f for f in os.listdir(pasta) if f.lower().endswith(".mp3")}
    if not achados:
        raise SystemExit("nenhum .mp3 em " + pasta)
    ordem = json.load(open(ORDEM)) if os.path.isfile(ORDEM) else []
    for nome in sorted(achados):
        if nome not in ordem:
            ordem.append(nome)
    faltam = [n for n in ordem if n not in achados]
    if faltam:
        raise SystemExit("faltam gravações que já estavam no áudio: %s" % ", ".join(faltam))
    json.dump(ordem, open(ORDEM, "w"))
    arquivos = [achados[n] for n in ordem]
    trechos = {}
    with tempfile.TemporaryDirectory() as tmp:
        lista = []
        silencio = os.path.join(tmp, "silencio.wav")
        rodar(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "anullsrc=r=%d:cl=mono" % SR, "-t", str(INTERVALO), silencio])
        t = 0.0
        for arq in arquivos:
            nome = os.path.splitext(arq)[0].upper()
            if not re.match(r"^[A-Z_]+$", nome):
                continue
            wav = os.path.join(tmp, nome + ".wav")
            d = tratar(os.path.join(pasta, arq), wav, nome)
            vol = REGRAS.get(nome, (1, 9, 1.0))[2]
            trechos[nome] = (round(t, 3), round(d, 3), vol, len(trechos) + 1)
            lista += [wav, silencio]
            t += d + INTERVALO
        juntar = os.path.join(tmp, "lista.txt")
        with open(juntar, "w") as f:
            for w in lista:
                f.write("file '%s'\n" % w)
        os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
        rodar(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", juntar, "-c:a", "libvorbis", "-q:a", "5", "-ac", "1", "-ar", str(SR), SAIDA])
    for apelido, alvo in APELIDOS.items():
        if alvo in trechos and apelido not in trechos:
            trechos[apelido] = trechos[alvo]
    # escreve a tabela no Sons.luau
    linhas = ["Sons.VOZES = {"]
    for nome in sorted(trechos):
        ini, d, vol, ordem_n = trechos[nome]
        linhas.append("\t%s = { %.3f, %.3f, %.2f, %d }," % (nome, ini, d, vol, ordem_n))
    linhas.append("} :: { [string]: { number } }")
    texto = open(SONS, encoding="utf-8").read()
    novo, n = re.subn(r"Sons\.VOZES = \{.*?\} :: \{ \[string\]: \{ number \} \}", "\n".join(linhas), texto, flags=re.S)
    if n != 1:
        raise SystemExit("não achei a tabela Sons.VOZES em " + SONS)
    open(SONS, "w", encoding="utf-8").write(novo)
    total = duracao(SAIDA)
    print("vozes: %s (%.1f s, %d bytes)" % (SAIDA, total, os.path.getsize(SAIDA)))
    print(json.dumps(trechos, indent=1))


if __name__ == "__main__":
    main()
