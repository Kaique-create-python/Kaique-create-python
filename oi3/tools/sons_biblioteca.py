#!/usr/bin/env python3
"""OI3 :: sons GRAVADOS das bibliotecas licenciadas do Roblox (AJUSTE-9).

Os sons do ProSoundEffects (PSE), da APM Music e do próprio Roblox são públicos: funcionam em
qualquer jogo pelo ID, sem upload e sem liberar permissão. Este script:
  * baixa cada som (assetdelivery), mede o volume do trecho usado e
  * gera o módulo Luau SonsBiblioteca.luau com o trecho e o ganho de cada um.

O ganho deixa cada som real no mesmo volume do som antigo que ele substitui (assim os volumes já
ajustados no código continuam certos). Sons novos usam um volume de referência.

uso: python3 -I tools/sons_biblioteca.py <pasta_cache>
"""
import gzip
import json
import math
import os
import subprocess
import sys
import urllib.request
import wave

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
ASSETS = os.path.join(RAIZ, "assets")
SAIDA = os.path.join(RAIZ, "src", "ReplicatedStorage", "OI3", "SonsBiblioteca.luau")
SR = 22050

# nome -> (variantes [(id, inicio, fim)], loop, referência)
# referência: nome de um item antigo (mesmo volume que ele) ou um nível em dB RMS
SONS = {
    # --- substituem os sons sintetizados (mesmo nome, mesmo volume de antes) ---
    "vento": ([(9114625414, 0.5, 35.5)], True, "vento"),  # PSE Gods Wind Spooky Eerie 1
    "interior": ([(9112775624, 0.2, 73.5)], True, "interior"),  # PSE Eerie Presence 3
    "drone": ([(9125400975, 0.2, 28.4)], True, "drone"),  # PSE Body Interior Big Rumbly Presence Low Drone
    "coracao": ([(9043365842, 0.0, 0.94)], True, "coracao"),  # APM Heartbeat 02 (uma batida)
    "relogio": ([(9116463812, 0.4, 8.0)], True, "relogio"),  # PSE Mantle Clock 1 (só o tique-taque)
    "rangido": ([(9120838740, 0.2, 4.8), (9120839010, 0.15, 1.7), (9120839364, 0.2, 1.75)], False, "rangido"),  # PSE Wood Door Creak
    "susto": ([(9047014318, 0.0, 3.2)], False, "susto"),  # APM Beautiful Horror - Stinger 1
    "impacto": ([(9113435763, 0.1, 4.5)], False, "impacto"),  # PSE Big Low-End Impacts 1
    "clique": ([(9120489267, 0.0, 0.2)], False, "clique"),  # PSE Wall Switch Click 7
    "estatica": ([(9118026602, 0.05, 1.3)], False, "estatica"),  # PSE Radio Static 1
    "sussurro": ([(9126213995, 0.2, 1.9), (9114228524, 0.15, 1.5)], False, "sussurro"),  # PSE Whisper Bursts / Eerie Whispering
    "respiracao": ([(9114663862, 0.2, 2.1)], False, "respiracao"),  # PSE Gross Snoring Breathing Inhale Exhale 8
    "whoosh": ([(9119227612, 0.05, 0.6)], False, "whoosh"),  # PSE Slow Whoosh Beefy Airy Pass By 1
    "tensao": ([(1841353932, 0.1, 4.2)], False, "tensao"),  # APM Rising Fear Hit 2
    "lanterna_liga": ([(9114479678, 0.25, 0.5)], False, "lanterna_liga"),  # PSE Flashlight On Off Clicks 1
    "lanterna_desliga": ([(9114480271, 0.1, 0.3)], False, "lanterna_desliga"),  # PSE Flashlight On Off Clicks 13
    "grilos": ([(9112764546, 0.1, 35.8)], True, "grilos"),  # PSE Crickets Night 1
    "lareira": ([(9112780438, 0.1, 35.8)], True, "lareira"),  # PSE Fireplace Constant Burning Flame 2
    "assobio": ([(9114057104, 0.2, 36.4)], True, "assobio"),  # PSE Desert Wind Whistley Light Gusts 1
    "goteira1": ([(9126181980, 0.0, 0.4)], False, "goteira1"),  # PSE Water Drip Distant Single Drops
    "goteira2": ([(9126179016, 0.18, 0.6)], False, "goteira2"),
    "estalo1": ([(9120881979, 0.05, 0.7)], False, "estalo1"),  # PSE Wood Groan Creak Chest 9
    "estalo2": ([(9120806410, 0.05, 0.8)], False, "estalo2"),  # PSE Wood Chair Creak 2
    "galhos": ([(9113581430, 1.0, 2.8)], False, "galhos"),  # PSE Branch Movement 1
    "maquina": ([(1839026975, 0.5, 29.5)], True, "maquina"),  # APM Washing Machine OL
    "batida_oca": ([(9120918417, 0.18, 0.75)], False, "batida_oca"),  # PSE Wood Knock On Wooden Door 3
    "batida_macica": ([(9114141047, 0.08, 0.45)], False, "batida_macica"),  # PSE Door Knock 2
    "arrastar": ([(9119601353, 0.05, 1.0)], False, "arrastar"),  # PSE drag
    "projetor": ([(9126093755, 1.0, 10.8)], True, "projetor"),  # PSE Tape Machine Flutter Moviola
    "motor": ([(9125345260, 1.6, 6.2)], True, "motor"),  # PSE 1987 Jeep Wrangler idle
    "partida": ([(9125345260, 0.4, 2.2)], False, "partida"),  # PSE 1987 Jeep Wrangler start
    "tres_batidas": ([(9114140488, 0.1, 1.6)], False, "tres_batidas"),  # PSE Door Knock 6 (três batidas)
    "vela_apaga": ([(9113702967, 0.0, 0.6)], False, "vela_apaga"),  # PSE Candles Blow Out
    "radio": ([(9118026602, 0.05, 2.3)], True, "radio"),  # PSE Radio Static 1
    "desmoronar": ([(9112775181, 0.2, 48.5)], True, "desmoronar"),  # PSE Earthquake Rumble 2
    # --- sons novos (AJUSTE-9) ---
    "coracao_batida": ([(9043365842, 0.0, 0.7)], False, -14),  # APM Heartbeat 02: um "tum-tum"
    "passo_monstro": ([(9125404796, 0.0, 1.3), (9125404796, 1.36, 2.6), (9125404796, 4.0, 5.4), (9125404796, 5.55, 7.0),
                       (9125404769, 0.0, 1.5), (9125404774, 0.0, 1.5)], False, -16),  # PSE Boomy Footsteps Giant Dinosaur
    "osso": ([(9113546532, 0.0, 0.7), (9113542363, 0.05, 0.4), (9119559518, 0.0, 0.7), (9113542383, 0.08, 0.4),
              (9113538757, 0.05, 0.5), (9119558965, 0.05, 1.5)], False, -17),  # PSE Bone Cracks
    "contorcer": ([(9119560554, 0.5, 6.0), (9119560554, 6.0, 11.8), (9119560549, 0.45, 9.4)], False, -19),  # PSE Squishy Bone Cracks
    "gemido": ([(9114628620, 0.05, 2.1), (9114628598, 0.05, 1.7), (9114628818, 0.05, 1.9), (9114630281, 0.05, 2.0),
                (9116966503, 0.25, 1.95), (9116966525, 0.55, 2.5), (9125628981, 0.2, 2.1)], False, -16),  # PSE Goliath / Monster Vocals
    "rosnado": ([(9113985451, 0.2, 15.0)], True, -20),  # PSE Creature Roar Constant Deep Throaty Growls 1
    "respira_monstro": ([(9114663862, 0.2, 2.1)], True, -18),  # PSE Gross Snoring Breathing (em loop)
    "farejar": ([(9113635074, 0.05, 0.9), (9113634952, 0.0, 1.1)], False, -18),  # PSE sniffs
    "grito_monstro": ([(9114037660, 2.0, 8.5), (9113987655, 0.85, 3.2), (9113987787, 0.5, 2.8)], False, -13),  # PSE Demon Scream 2 / spider screech
    "grito_crianca": ([(9125436512, 0.0, 0.55)], False, -14),  # PSE Children Scream 4 To 8
    "ofegar": ([(9114556036, 0.05, 1.6), (9114555699, 0.0, 1.45), (9114555843, 0.0, 0.6)], False, -20),  # PSE Gasp Trouble Breathing
    "choramingo": ([(9113580140, 0.4, 7.7)], False, -22),  # PSE Boy Whimpers 2
    "madeira_tensao": ([(9126282474, 0.5, 4.5), (9126282061, 0.6, 4.0)], False, -19),  # PSE Wood Strain Stress Creaking
    "queda": ([(9113481839, 0.05, 0.6)], False, -16),  # PSE Body Fall Wood 2
    "destrocos": ([(9114221327, 0.1, 2.4)], False, -16),  # PSE collapse debris
    "raspar": ([(9116908825, 0.1, 3.0)], False, -20),  # PSE Metal Wood Scrapes 1
    "risadas": ([(9113785567, 0.85, 18.2)], False, -22),  # PSE Children Giggle 3
    "caixinha_nota": ([(9117040377, 0.1, 1.9)], False, -18),  # PSE Music Box Single Note (829 Hz)
    # o grito do menino no espelho: uma criança gritando de verdade (até a fala nova ficar pronta)
    "ME_5": ([(9125436512, 0.0, 0.55)], False, "ME_5"),  # PSE Children Scream 4 To 8
}

# nota da caixinha de música (para tocar "Parabéns" com uma caixinha DE VERDADE, nota por nota)
CAIXINHA_HZ = 829.0


def get(url, binario=False):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = r.read()
    return d if binario else json.loads(d.decode())


def baixar(aid, pasta):
    destino = os.path.join(pasta, "%s.wav" % aid)
    if os.path.exists(destino):
        return destino
    loc = get("https://assetdelivery.roblox.com/v2/assetId/%s" % aid)
    dados = get(loc["locations"][0]["location"], True)
    if dados[:2] == b"\x1f\x8b":
        dados = gzip.decompress(dados)
    bruto = os.path.join(pasta, "%s.bin" % aid)
    with open(bruto, "wb") as f:
        f.write(dados)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", bruto, "-ac", "1", "-ar", str(SR), destino], check=True)
    os.remove(bruto)
    return destino


def ler_wav(caminho):
    with wave.open(caminho) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768


def ler_ogg(caminho, pasta):
    destino = os.path.join(pasta, os.path.basename(caminho) + ".wav")
    if not os.path.exists(destino):
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", caminho, "-ac", "1", "-ar", str(SR), destino], check=True)
    return ler_wav(destino)


def rms_ativo(x):
    """RMS (dB) só das partes com som (ignora o silêncio)."""
    if len(x) == 0:
        return -90.0
    b = int(SR * 0.05)
    nb = max(1, len(x) // b)
    env = np.sqrt(np.mean(x[: nb * b].reshape(nb, b) ** 2, axis=1)) if len(x) >= b else np.array([np.sqrt(np.mean(x ** 2))])
    lim = env.max() * 0.25
    ativos = env[env >= lim]
    r = float(np.sqrt(np.mean(ativos ** 2))) if len(ativos) else 1e-6
    return 20 * math.log10(max(r, 1e-6))


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, "out", "sons_lib")
    os.makedirs(cache, exist_ok=True)
    mapa = json.load(open(os.path.join(ASSETS, "audio_mapa.json")))
    sprites = {}
    ref_db = {}
    for arquivo, itens in mapa.items():
        for nome, it in itens.items():
            ref_db[nome] = (arquivo, it["inicio"], it["dur"])
    linhas = []
    for nome, (variantes, loop, ref) in SONS.items():
        if isinstance(ref, str):
            arquivo, ini, dur = ref_db[ref]
            if arquivo not in sprites:
                sprites[arquivo] = ler_ogg(os.path.join(ASSETS, "oi3_%s.ogg" % arquivo), cache)
            x = sprites[arquivo]
            alvo = rms_ativo(x[int(ini * SR): int((ini + dur) * SR)])
        else:
            alvo = float(ref)
        vs = []
        for aid, a, b in variantes:
            y = ler_wav(baixar(aid, cache))
            nivel = rms_ativo(y[int(a * SR): int(b * SR)])
            ganho = 10 ** ((alvo - nivel) / 20)
            ganho = min(max(ganho, 0.15), 8.0)
            vs.append((aid, a, b - a, ganho, nivel))
        linhas.append((nome, vs, loop, alvo))
        print("%-16s alvo %6.1f dB  " % (nome, alvo) + "  ".join("%d:%.1fdB→x%.2f" % (v[0], v[4], v[3]) for v in vs))
    with open(SAIDA, "w", encoding="utf-8") as f:
        f.write("-- OI3 :: sons GRAVADOS de verdade, das bibliotecas licenciadas do próprio Roblox (AJUSTE-9).\n")
        f.write("-- Gerado por tools/sons_biblioteca.py. Não edite à mão.\n")
        f.write("-- ProSoundEffects, APM Music e Roblox: públicos, tocam em qualquer jogo pelo ID (sem upload e\n")
        f.write("-- sem liberar permissão). Se algum não carregar, o jogo usa o som antigo do mesmo nome.\n")
        f.write("-- Cada som: variantes { id, inicio, dur, ganho } (uma é sorteada a cada vez) e loop.\n")
        f.write("return {\n")
        f.write("\tcaixinhaHz = %.1f,\n" % CAIXINHA_HZ)
        f.write("\tsons = {\n")
        for nome, vs, loop, _ in linhas:
            f.write("\t\t%s = {\n" % nome)
            f.write("\t\t\tloop = %s,\n" % ("true" if loop else "false"))
            f.write("\t\t\tvariantes = {\n")
            for aid, a, d, g, _ in vs:
                f.write("\t\t\t\t{ id = %d, inicio = %.2f, dur = %.2f, ganho = %.2f },\n" % (aid, a, d, g))
            f.write("\t\t\t},\n")
            f.write("\t\t},\n")
        f.write("\t},\n")
        f.write("}\n")
    print("escrito:", SAIDA)


if __name__ == "__main__":
    main()
