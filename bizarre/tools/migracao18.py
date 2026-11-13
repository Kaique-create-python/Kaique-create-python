#!/usr/bin/env python3
"""AJ18: prova offline de que o instalador migra o Place sem estragar nada. Sem rede e sem chave.

Pega o Place AJ13 do repositorio (dist/BB_place.rbxl), aplica em cadeia os instaladores de cada
etapa tirados do git (AJ14 -> AJ15 -> AJ16 -> AJ17) e depois o AJ18 da arvore atual sobre cada
ponto de partida. Confere: patch idempotente, 68 fontes do AJ18 no fim, nenhum objeto fora dos
scripts removido e blocos de propriedade dos grupos que ja existiam iguais byte a byte.
Os Places sao montados a partir do repositorio; nao sao um backup do jogo ao vivo.

uso: python3 bizarre/tools/migracao18.py [--saida resultado.json] [--place outro.rbxl]
Para a proxima etapa: acrescente (18, '<commit do AJ18>') em ETAPAS e troque FINAL."""
import argparse, collections, hashlib, io, json, subprocess, sys, tarfile, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
ETAPAS = [(14, 'b39b17d'), (15, '0bf3abe'), (16, '39f5801'), (17, '87c3acf')]
FINAL = 18
SCRIPTS = {'Script', 'LocalScript', 'ModuleScript'}


def _etapa(tree, stage, src, dst):
    sys.path[:0] = [tree, tree + '/tools']
    gen = __import__('gerar_ajuste%d' % int(stage))
    from installer14.package import Package
    package = Package(gen.collect())
    raw = Path(src).read_bytes()
    out, changed = package.patch(raw)
    again, changed2 = package.patch(out)
    Path(dst).write_bytes(out)
    print(json.dumps({'stage': int(stage), 'changed': changed, 'idempotent': again == out and not changed2,
                      'base_bytes': len(raw), 'patched_bytes': len(out), 'sha256': hashlib.sha256(out).hexdigest()}))


def _comparar(src, dst):
    sys.path[:0] = [str(ROOT), str(ROOT / 'tools')]
    from installer14.codec import Binary
    import gerar_ajuste14 as core
    base, after = Binary(Path(src).read_bytes()), Binary(Path(dst).read_bytes())

    def paths(doc):
        memo = {}
        def path(ref):
            if ref == -1:
                return ()
            if ref not in memo:
                memo[ref] = path(doc.parents[ref]) + (doc.objects[ref]['name'],)
            return memo[ref]
        return collections.Counter((path(r), o['class']) for r, o in doc.objects.items() if o['class'] not in SCRIPTS)

    fontes_ok, fontes_erradas = 0, []
    for file in sorted((ROOT / 'src').rglob('*.luau')):
        rel = file.relative_to(ROOT / 'src')
        gamepath, cls = core.identity(rel)
        ref = after.locate(gamepath)
        if after.objects[ref]['class'] == cls and after.value(ref, 'Source') == file.read_text().encode():
            fontes_ok += 1
        else:
            fontes_erradas.append(rel.as_posix())
    antes, depois = paths(base), paths(after)
    # o patch so acrescenta grupos no fim: os grupos antigos mantem o mesmo id
    iguais, mudaram = 0, []
    for (gid, name), (chunk, typ, q) in base.props.items():
        cname = base.groups[gid]['name']
        if cname in SCRIPTS:
            continue
        other = after.props.get((gid, name))
        if other and after.groups[gid]['name'] == cname and other[1] == typ and bytes(other[0].data[other[2]:]) == bytes(chunk.data[q:]):
            iguais += 1
        else:
            mudaram.append(cname + '.' + name)
    contar = lambda doc, cls: sum(1 for o in doc.objects.values() if o['class'] == cls)
    print(json.dumps({'original_instances': len(base.objects), 'patched_instances': len(after.objects),
                      'parts': [contar(base, 'Part'), contar(after, 'Part')],
                      'sources_aj%d' % FINAL: fontes_ok, 'sources_wrong': fontes_erradas,
                      'non_script_removed': sum((antes - depois).values()), 'non_script_added': sum((depois - antes).values()),
                      'opaque_property_chunks_preserved': iguais, 'property_chunks_changed': mudaram[:10]}))


def _rodar(*args):
    out = subprocess.run([sys.executable, '-I', __file__, *map(str, args)], capture_output=True, text=True)
    if out.returncode:
        raise SystemExit(out.stdout + out.stderr)
    return json.loads(out.stdout.strip().splitlines()[-1])


def _arvore(stage, commit, dest):
    pastas = ['bizarre/installer14', 'bizarre/tools', 'bizarre/src', 'bizarre/assets/vfx14'] + (['bizarre/assets/vfx15'] if stage >= 15 else [])
    raw = subprocess.run(['git', 'archive', commit, *pastas], cwd=REPO, capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
        tar.extractall(dest, filter='data')
    return dest / 'bizarre'


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--place', type=Path, default=ROOT / 'dist/BB_place.rbxl')
    p.add_argument('--saida', type=Path)
    args = p.parse_args(argv)
    result = {'fixture': 'Place AJ13 do repositorio migrado pelos instaladores de cada etapa (git); nao e backup ao vivo',
              'chain': [], 'migration': []}
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        place = args.place
        stages = {}
        for stage, commit in ETAPAS:
            tree = _arvore(stage, commit, temp / ('aj%d' % stage))
            out = temp / ('p%d.rbxl' % stage)
            row = _rodar('_etapa', tree, stage, place, out)
            row['commit'] = commit
            result['chain'].append(row)
            print('AJ%d: %s' % (stage, 'ok' if row['idempotent'] else 'NAO IDEMPOTENTE'), flush=True)
            stages[stage] = place = out
        for stage, start in stages.items():
            out = temp / ('p%d_de%d.rbxl' % (FINAL, stage))
            row = _rodar('_etapa', ROOT, FINAL, start, out)
            row.update(_rodar('_comparar', start, out))
            row['from_stage'] = stage
            result['migration'].append(row)
            print('AJ%d -> AJ%d: fontes %d, removidos %d' % (stage, FINAL, row['sources_aj%d' % FINAL], row['non_script_removed']), flush=True)
    finals = {r['sha256'] for r in result['migration'] if r['from_stage'] >= 16}
    ok = all(r['idempotent'] for r in result['chain'] + result['migration']) and all(
        not r['sources_wrong'] and r['non_script_removed'] == 0 and not r['property_chunks_changed'] for r in result['migration'])
    result['ok'] = ok
    result['same_bytes_from_16_and_17'] = len(finals) == 1
    text = json.dumps(result, ensure_ascii=False, indent=1)
    if args.saida:
        args.saida.write_text(text + '\n')
    print(text)
    return 0 if ok else 1


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '_etapa':
        _etapa(*sys.argv[2:6])
    elif len(sys.argv) > 1 and sys.argv[1] == '_comparar':
        _comparar(*sys.argv[2:4])
    else:
        sys.exit(main())
