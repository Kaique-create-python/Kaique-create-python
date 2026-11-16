#!/usr/bin/env python3
"""PROJETO BASTIAO :: gera bastiao/dist/BASTIAO_ETAPA2.py (instalador de arquivo unico).

Le bastiao/src (mesmo formato do Rojo: X.server.luau = Script, X.client.luau = LocalScript,
X.luau = ModuleScript, pasta X/ = filhos de X), monta o pacote da etapa (fontes, sons, teste
nativo da nuvem e manifesto com SHA-256) e embute o instalador. So entram scripts com nome
"Bastiao..." logo abaixo de ServerScriptService, ReplicatedStorage ou StarterPlayerScripts.

Etapa 2: os scripts da Etapa 1 que ja estao no jogo so sao trocados se a fonte for exatamente a
que a Etapa 1 instalou (lida do proprio dist/BASTIAO_ETAPA1.py); qualquer outra fonte bloqueia.
"""
import argparse
import base64
import hashlib
import io
import json
import sys
import zipfile
import zlib
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))
from instalador.codec import Failure  # noqa: E402
from instalador.package import Package  # noqa: E402

ETAPA = 2
ANTERIOR = RAIZ / 'dist' / 'BASTIAO_ETAPA1.py'
AUDIO = RAIZ / 'assets' / 'audio'
DATA_ZIP = (2026, 11, 16, 0, 0, 0)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def identidade(rel):
    """Caminho no jogo e classe a partir do caminho do arquivo em bastiao/src."""
    partes = list(rel.parts)
    nome = partes[-1]
    for sufixo, classe in (('.server.luau', 'Script'), ('.client.luau', 'LocalScript'), ('.luau', 'ModuleScript')):
        if nome.endswith(sufixo):
            return partes[:-1] + [nome[: -len(sufixo)]], classe
    raise Failure('Arquivo fora do formato: ' + rel.as_posix())


def fontes_anteriores(caminho=ANTERIOR):
    """Fontes que o instalador da etapa anterior colocou no jogo (lidas do arquivo entregue)."""
    import ast
    texto = caminho.read_text(encoding='utf-8')
    arvore = ast.parse(texto)
    valores = {}
    for no in arvore.body:
        if isinstance(no, ast.Assign) and len(no.targets) == 1 and isinstance(no.targets[0], ast.Name):
            if no.targets[0].id in ('PAYLOAD', 'SHA256'):
                valores[no.targets[0].id] = ast.literal_eval(no.value)
    carga = base64.b85decode(valores['PAYLOAD'])
    if sha(carga) != valores['SHA256']:
        raise Failure('Instalador anterior corrompido: ' + caminho.name)
    with zipfile.ZipFile(io.BytesIO(zlib.decompress(carga))) as z:
        linhas = json.loads(z.read('payload/sources.json'))
    return {tuple(r['path']): r['source'] for r in linhas}


def coletar():
    anteriores = fontes_anteriores()
    linhas = []
    for arquivo in sorted((RAIZ / 'src').rglob('*.luau')):
        caminho, classe = identidade(arquivo.relative_to(RAIZ / 'src'))
        fonte = arquivo.read_text(encoding='utf-8')
        if '\r' in fonte:
            raise Failure('Fim de linha CRLF em ' + arquivo.name)
        linha = dict(path=caminho, cls=classe, source=fonte)
        velha = anteriores.get(tuple(caminho))
        if velha is not None and velha != fonte:
            linha['known'] = [sha(velha.encode())]
        linhas.append(linha)
    # pais antes dos filhos (o patcher exige)
    linhas.sort(key=lambda r: (len(r['path']), r['path']))
    sumiram = sorted('/'.join(p) for p in anteriores if list(p) not in [r['path'] for r in linhas])
    if sumiram:
        raise Failure('Scripts da etapa anterior sem substituto (o patch nao apaga nada): ' + ', '.join(sumiram))
    arquivos = {
        'sources.json': json.dumps(linhas, ensure_ascii=False, separators=(',', ':')).encode(),
        'package.json': json.dumps({'stage': ETAPA}).encode(),
        'teste_nuvem.luau': (RAIZ / 'ferramentas' / 'teste_nuvem.luau').read_bytes(),
    }
    # sons da etapa (opcionais): audio.json + os arquivos .ogg que ele cita
    if (AUDIO / 'audio.json').exists():
        dados = json.loads((AUDIO / 'audio.json').read_text(encoding='utf-8'))
        arquivos['audio.json'] = (AUDIO / 'audio.json').read_bytes()
        for info in dados['sprites'].values():
            arquivos[info['arquivo']] = (AUDIO / Path(info['arquivo']).name).read_bytes()
    arquivos['manifest.json'] = json.dumps({k: sha(v) for k, v in sorted(arquivos.items())}, sort_keys=True).encode()
    pacote = Package(arquivos)
    pacote.scripts(1)  # confere o limite de 200 KB do teste nativo
    return arquivos, pacote


def montar(saida=None):
    arquivos, pacote = coletar()
    pacote_zip = {'payload/' + n: v for n, v in arquivos.items()}
    for caminho in sorted((RAIZ / 'instalador').glob('*.py')):
        pacote_zip['instalador/' + caminho.name] = caminho.read_bytes()
    pacote_zip['bundle-manifest.json'] = json.dumps({n: sha(v) for n, v in sorted(pacote_zip.items())}, sort_keys=True).encode()
    fluxo = io.BytesIO()
    with zipfile.ZipFile(fluxo, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for nome, valor in sorted(pacote_zip.items()):
            info = zipfile.ZipInfo(nome, DATA_ZIP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o600 << 16
            z.writestr(info, valor)
    carga = zlib.compress(fluxo.getvalue(), 9)
    script = (RAIZ / 'instalador' / 'bootstrap.py.txt').read_text(encoding='utf-8')
    script = script.replace('__PAYLOAD__', repr(base64.b85encode(carga))).replace('__SHA256__', repr(sha(carga)))
    alvo = Path(saida) if saida else RAIZ / 'dist' / f'BASTIAO_ETAPA{ETAPA}.py'
    alvo.parent.mkdir(parents=True, exist_ok=True)
    alvo.write_text(script, encoding='utf-8')
    alvo.chmod(0o644)
    sons = len(pacote.audio['sprites']) if pacote.audio else 0
    print(f'{alvo} | {len(pacote.entries)} scripts | {sons} arquivos de som | SHA256 {sha(script.encode())} | {len(script.encode())} bytes')
    return alvo


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--saida', type=Path)
    args = p.parse_args(argv)
    return montar(args.saida)


if __name__ == '__main__':
    main()
