#!/usr/bin/env python3
"""PROJETO BASTIÃO :: trata os áudios brutos do ElevenLabs e monta os arquivos de som do jogo.

Entrada (pasta bastiao/assets/audio/brutos, ou --brutos):
  {pt,en,ru}_{chave}.mp3   uma voz por fala e língua
  sfx_{nome}.mp3           efeitos curtos (nomes do Som.luau: trava, impacto_porta, ...)
  loop_{nome}.mp3          ambientes em loop (ambiente, ventilador, motor, alarme, estatica)
  passos_concreto.mp3      sequência de passos; é fatiada em variações
Saída (bastiao/assets/audio):
  voz_pt.ogg, voz_en.ogg, voz_ru.ogg, efeitos.ogg  (cada fala/efeito é um trecho do arquivo)
  audio.json                                        (trechos, durações; entra no instalador)
e o módulo bastiao/src/ReplicatedStorage/BastiaoCompartilhado/Audio.luau com IDs 0 (o instalador
põe os IDs depois de enviar). Falta de arquivo bruto nunca trava: aquela fala fica só na legenda.

Tratamento por canal (Textos.CANAL de quem fala):
  pessoa   : Pavel ao vivo, limpo (o eco vem do lugar onde o jogador está, no jogo);
  radio    : banda de rádio 320-3400 Hz, saturação do microfone, chiado e estalos;
  gravacao : fita velha (oscilação, chiado, zumbido de 50 Hz) tocada pelo rádio;
  pa       : alto-falante da base (corneta saturada); o eco é feito no jogo.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from scipy.ndimage import maximum_filter1d, minimum_filter1d, uniform_filter1d
from scipy.signal import butter, find_peaks, sosfilt

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))
from instalador.midia import fonte_audio, validar_dados  # noqa: E402

SR = 44100
INTERVALO = 0.35  # silêncio entre trechos de um mesmo arquivo (nada vaza de um som para o outro)
VERSAO = 2
EFEITOS = ['estatica', 'squelch', 'toques_longe', 'toques_perto', 'inspiracao', 'vapor', 'impacto_porta', 'portas',
           'passos_monstro', 'trava', 'porta_desliza', 'alavanca', 'modulo_encaixe', 'modulo_pegar', 'terminal_bip',
           'terminal_liga', 'chime_pa']
LOOPS = {'ambiente': 24.0, 'ventilador': 8.0, 'motor': 8.0, 'alarme': 6.0, 'estatica': 6.0}
LIMITE_EFEITO = 9.0


# ------------------------------------------------------------------ entrada e saída
def ler(caminho):
    saida = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(caminho), '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                           capture_output=True, check=True).stdout
    return np.frombuffer(saida, dtype=np.float32).astype(np.float64)


def escrever_ogg(caminho, x, qualidade=4):
    dados = np.clip(x, -1.0, 1.0).astype(np.float32).tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', str(qualidade), '-map_metadata', '-1',
                    '-fflags', '+bitexact', '-flags:a', '+bitexact', str(caminho)], input=dados, check=True)


def semente(*partes):
    return int(hashlib.sha256('|'.join(partes).encode()).hexdigest()[:8], 16)


# ------------------------------------------------------------------ dinâmica
def db(v):
    return 10 ** (v / 20)


def aparar(x, antes=0.03, depois=0.18, limiar=-40.0):
    if len(x) == 0:
        return x
    env = maximum_filter1d(np.abs(x), size=int(0.01 * SR))
    pico = env.max()
    if pico < 1e-5:
        return x[:0]
    ativo = np.nonzero(env > pico * db(limiar))[0]
    a = max(0, ativo[0] - int(antes * SR))
    b = min(len(x), ativo[-1] + int(depois * SR))
    return suavizar_pontas(x[a:b].copy())


def suavizar_pontas(y, entrada=0.004, saida=0.025):
    n1, n2 = min(len(y), int(entrada * SR)), min(len(y), int(saida * SR))
    if n1:
        y[:n1] *= np.linspace(0, 1, n1)
    if n2:
        y[-n2:] *= np.linspace(1, 0, n2)
    return y


def rms_ativo(x):
    """RMS só dos trechos com som (blocos de 50 ms a até 30 dB do mais alto)."""
    bloco = int(0.05 * SR)
    if len(x) < bloco:
        return float(np.sqrt(np.mean(x ** 2))) if len(x) else 0.0
    n = len(x) // bloco
    r = np.sqrt(np.mean(x[: n * bloco].reshape(n, bloco) ** 2, axis=1))
    vivos = r[r > r.max() * db(-30)]
    return float(np.sqrt(np.mean(vivos ** 2))) if len(vivos) else 0.0


def limitar(x, teto=-1.0):
    """Limitador com antecipação: o ganho nunca passa do necessário para o pico não estourar."""
    alvo = np.minimum(1.0, db(teto) / np.maximum(np.abs(x), 1e-9))
    w = int(0.006 * SR) | 1
    g = minimum_filter1d(alvo, size=w)
    g = uniform_filter1d(g, size=w)
    w2 = int(0.05 * SR) | 1
    g = np.minimum(g, uniform_filter1d(minimum_filter1d(g, size=w2), size=w2))
    return x * g


def nivelar(x, alvo_db, teto=-1.0):
    r = rms_ativo(x)
    if r <= 1e-6:
        return x
    return limitar(x * (db(alvo_db) / r), teto)


# ------------------------------------------------------------------ filtros e canais
def banda(x, baixo, alto, ordem=4):
    return sosfilt(butter(ordem, [baixo, alto], btype='band', fs=SR, output='sos'), x)


def passa_alta(x, f, ordem=2):
    return sosfilt(butter(ordem, f, btype='high', fs=SR, output='sos'), x)


def passa_baixa(x, f, ordem=2):
    return sosfilt(butter(ordem, f, btype='low', fs=SR, output='sos'), x)


def saturar(x, forca):
    return np.tanh(x * forca) / np.tanh(forca)


def pico1(x):
    p = np.max(np.abs(x)) if len(x) else 0
    return x / p * 0.9 if p > 1e-6 else x


def estalos(n, rng, por_segundo, forca):
    """Estalos curtos de estática (rajadas de ruído de 1 a 5 ms com queda rápida)."""
    y = np.zeros(n)
    for _ in range(rng.poisson(por_segundo * n / SR)):
        tam = int(rng.uniform(0.001, 0.005) * SR)
        p = int(rng.integers(0, max(1, n - tam)))
        y[p:p + tam] += rng.normal(0, 1, tam) * np.exp(-np.linspace(0, 6, tam)) * rng.uniform(0.3, 1.0) * forca
    return y


def radio(x, rng, forte=1.0):
    y = pico1(passa_alta(x, 140))
    y = saturar(y, 2.0 + 1.2 * forte)
    y = banda(y, 320, 3200, 4)
    t = np.arange(len(y)) / SR
    y *= 1 + 0.05 * forte * np.sin(2 * np.pi * rng.uniform(5.5, 8.5) * t + rng.uniform(0, 6.3))
    chiado = banda(rng.normal(0, 1, len(y)), 700, 4200, 2) * db(-43)
    y = pico1(y) * 0.85 + chiado + estalos(len(y), rng, 4 * forte, 0.10)
    return banda(y, 280, 3500, 2)


def fita(x, rng):
    n = len(x)
    t = np.arange(n) / SR
    desvio = 0.0016 * np.sin(2 * np.pi * 0.55 * t + rng.uniform(0, 6.3)) + 0.00022 * np.sin(2 * np.pi * 6.3 * t)
    pos = np.clip((t + desvio + 0.0025) * SR, 0, n - 1)
    y = np.interp(pos, np.arange(n), x)
    y = banda(y, 170, 5200, 2)
    y = saturar(pico1(y), 1.7)
    chiado = passa_baixa(rng.normal(0, 1, n), 6000, 1) * db(-36)
    zumbido = (np.sin(2 * np.pi * 50 * t) + 0.4 * np.sin(2 * np.pi * 150 * t)) * db(-44)
    return radio(y * 0.9 + chiado + zumbido, rng, forte=0.45)


def alto_falante(x, rng):
    y = banda(pico1(x), 260, 5400, 3)
    y = saturar(y, 1.9)
    y = y + 0.35 * banda(y, 1500, 2500, 2)
    d = int(0.0011 * SR)
    y[d:] = y[d:] + 0.22 * y[:-d]
    y = passa_alta(y, 320, 4)  # corneta pequena: quase sem grave
    return pico1(y) + banda(rng.normal(0, 1, len(y)), 300, 3000, 2) * db(-52)


def pessoa(x, rng):
    return passa_alta(x, 70)


CANAIS = {'pessoa': pessoa, 'radio': radio, 'gravacao': fita, 'pa': alto_falante}
ALVO_VOZ = {'pessoa': -19.0, 'radio': -18.0, 'gravacao': -19.0, 'pa': -18.0}


# ------------------------------------------------------------------ peças
def tratar_voz(caminho, canal, chave, idioma):
    rng = np.random.default_rng(semente(idioma, chave))
    x = aparar(ler(caminho), antes=0.02, depois=0.12)
    if len(x) == 0:
        return x
    y = CANAIS[canal](x, rng)
    return suavizar_pontas(nivelar(y, ALVO_VOZ[canal], teto=-1.5))


def tratar_efeito(caminho, nome):
    x = aparar(ler(caminho), antes=0.01, depois=0.35, limiar=-48.0)
    x = x[: int(LIMITE_EFEITO * SR)]
    return suavizar_pontas(nivelar(x, -17.0, teto=-1.0), saida=0.08)


def fazer_laco(x, segundos, fade=0.7):
    """Loop sem emenda: o começo é misturado com o que viria depois do fim (potência constante)."""
    inicio = min(int(0.3 * SR), max(0, len(x) - int((segundos + fade) * SR)))
    x = x[inicio:]
    F = int(fade * SR)
    L = min(int(segundos * SR), len(x) - F)
    if L <= F:
        raise ValueError('loop curto demais')
    r = x[:L].copy()
    th = np.linspace(0, np.pi / 2, F)
    r[:F] = x[:F] * np.sin(th) + x[L:L + F] * np.cos(th)
    return r


def tratar_laco(caminho, nome):
    x = ler(caminho)
    r = fazer_laco(x, LOOPS[nome])
    return nivelar(r, -21.0 if nome != 'alarme' else -16.0, teto=-1.5)


def fatiar_passos(caminho, maximo=6):
    x = ler(caminho)
    env = uniform_filter1d(np.abs(x), size=int(0.005 * SR))
    picos, _ = find_peaks(env, height=env.max() * 0.25, distance=int(0.22 * SR))
    pedacos = []
    for p in picos:
        a = max(0, p - int(0.025 * SR))
        y = x[a:a + int(0.42 * SR)].copy()
        y = aparar(y, antes=0.0, depois=0.06, limiar=-36.0)
        if 0.06 * SR < len(y):
            pedacos.append(suavizar_pontas(y, 0.002, 0.04))
    # os mais fortes e parecidos entre si (sem passo arrastado nem pisada fraca)
    pedacos.sort(key=lambda y: -rms_ativo(y))
    pedacos = pedacos[:maximo]
    return [nivelar(y, -19.0, teto=-1.0) for y in pedacos]


def montar(trechos):
    """Junta os trechos num arquivo com silêncio entre eles. Devolve (áudio, {nome: [início, duração]})."""
    partes = [np.zeros(int(0.05 * SR))]
    pos = len(partes[0])
    mapa = {}
    for nome, y in trechos:
        if isinstance(y, list):
            lista = []
            for parte in y:
                lista.append([round(pos / SR, 3), round(len(parte) / SR, 3)])
                partes += [parte, np.zeros(int(INTERVALO * SR))]
                pos += len(parte) + int(INTERVALO * SR)
            mapa[nome] = lista
        else:
            mapa[nome] = [round(pos / SR, 3), round(len(y) / SR, 3)]
            partes += [y, np.zeros(int(INTERVALO * SR))]
            pos += len(y) + int(INTERVALO * SR)
    return np.concatenate(partes), mapa


def textos():
    saida = subprocess.run(['lune', 'run', str(RAIZ / 'ferramentas' / 'textos_json.luau')], capture_output=True,
                           check=True, cwd=RAIZ.parent).stdout
    return json.loads(saida)


def principal(brutos, destino, modulo):
    T = textos()
    destino.mkdir(parents=True, exist_ok=True)
    dados = {'versao': VERSAO, 'sprites': {}, 'vozes': {}, 'sfx': {}, 'loops': {}, 'duracoes': {}}
    faltando = []
    for idioma in T['idiomas']:
        trechos = []
        for chave in sorted(T['falas'][idioma]):
            arq = brutos / ('%s_%s.mp3' % (idioma, chave))
            if not arq.exists():
                faltando.append(arq.name)
                continue
            canal = T['canal'][T['falante'][chave]]
            y = tratar_voz(arq, canal, chave, idioma)
            if len(y):
                trechos.append((chave, y))
        if not trechos:
            continue
        audio, mapa = montar(trechos)
        nome = 'voz_' + idioma
        escrever_ogg(destino / (nome + '.ogg'), audio)
        dados['sprites'][nome] = {'arquivo': 'audio/%s.ogg' % nome, 'segundos': round(len(audio) / SR, 3)}
        dados['vozes'][idioma] = mapa
        for chave, (_, d) in mapa.items():
            dados['duracoes'][chave] = max(dados['duracoes'].get(chave, 0), round(d + 0.005, 2))
    efeitos = []
    for nome in EFEITOS:
        arq = brutos / ('sfx_%s.mp3' % nome)
        if arq.exists():
            efeitos.append(('sfx', nome, tratar_efeito(arq, nome)))
        else:
            faltando.append(arq.name)
    passos = brutos / 'passos_concreto.mp3'
    if passos.exists():
        efeitos.append(('sfx', 'passo_concreto', fatiar_passos(passos)))
    else:
        faltando.append(passos.name)
    for nome in LOOPS:
        arq = brutos / ('loop_%s.mp3' % nome)
        if arq.exists():
            efeitos.append(('loops', nome, tratar_laco(arq, nome)))
        else:
            faltando.append(arq.name)
    if efeitos:
        audio, mapa = montar([('%s:%s' % (g, n), y) for g, n, y in efeitos])
        escrever_ogg(destino / 'efeitos.ogg', audio)
        dados['sprites']['efeitos'] = {'arquivo': 'audio/efeitos.ogg', 'segundos': round(len(audio) / SR, 3)}
        for chave, seg in mapa.items():
            grupo, nome = chave.split(':')
            dados[grupo][nome] = seg
    for velho in destino.glob('*.ogg'):
        if velho.stem not in dados['sprites']:
            velho.unlink()
    validar_dados(dados)
    (destino / 'audio.json').write_text(json.dumps(dados, ensure_ascii=False, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    modulo.write_text(fonte_audio(dados, {}), encoding='utf-8')
    total = sum(len(v) for v in dados['vozes'].values())
    print('[Audio] vozes: %d trechos (%s) | efeitos: %d | loops: %d' % (
        total, ', '.join('%s=%d' % (k, len(v)) for k, v in sorted(dados['vozes'].items())), len(dados['sfx']), len(dados['loops'])))
    for nome, info in sorted(dados['sprites'].items()):
        tam = (destino / (nome + '.ogg')).stat().st_size
        print('[Audio] %s.ogg: %.1f s, %d KB' % (nome, info['segundos'], tam // 1024))
    if faltando:
        print('[Audio] sem arquivo bruto (fica só a legenda): ' + ', '.join(sorted(faltando)))
    return dados


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--brutos', type=Path, default=RAIZ / 'assets' / 'audio' / 'brutos')
    p.add_argument('--destino', type=Path, default=RAIZ / 'assets' / 'audio')
    p.add_argument('--modulo', type=Path, default=RAIZ / 'src' / 'ReplicatedStorage' / 'BastiaoCompartilhado' / 'Audio.luau')
    a = p.parse_args(argv)
    return principal(a.brutos, a.destino, a.modulo)


if __name__ == '__main__':
    main()
