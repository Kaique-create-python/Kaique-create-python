"""Build the portable correction from literal C9 payloads + reviewed files.
No network, no downloaded-code execution, no home mutations.
"""
import argparse
import ast
import base64
import hashlib
import json
from pathlib import Path
import zlib

ROOT=Path(__file__).resolve().parents[1]


def read_rows(path):
    tree=ast.parse(Path(path).read_text())
    return next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign)
                and any(isinstance(x,ast.Name) and x.id=='ARQUIVOS' for x in n.targets))


def build(incoming,output):
    original=read_rows(incoming);rows={}
    previous=json.loads((ROOT/'EXPECTED_BEFORE.json').read_text())
    selected=set(original)|{
        'instalador/patcher.py','instalador/stamina.py','tooling/patch_install.py',
        'tooling/generate_impact_tone.py','audio/sources/impacto_zumbido_original.wav',
        'docs/CAMERA.md','docs/AUDITORIA_HISTORIA.md','docs/INSTALADOR.md',
        'docs/CORRECAO10_CODEX.md','docs/PROMPT_PARA_CLAUDE_CORRECAO10.md',
    }
    selected.update(str(p.relative_to(ROOT)) for p in (ROOT/'tests').rglob('*')
                    if p.is_file() and '__pycache__' not in p.parts)
    for name in sorted(selected):
        raw=(ROOT/name).read_bytes()
        item=dict(original.get(name,{}));known=set(item.get('antes',[]))
        if name in original:
            old=original[name];decoded=zlib.decompress(base64.b85decode(old['dados']))
            if hashlib.sha256(decoded).hexdigest()!=old['novo']:raise ValueError('C9 payload corrupted: '+name)
            known.add(old['novo'])
        elif name.startswith('tests/'):
            item['modo']='teste' if name in previous else 'criar_teste'
        else:item['modo']='trocar' if name in previous else 'criar'
        if name in previous:known.add(previous[name])
        item.update(antes=sorted(known),novo=hashlib.sha256(raw).hexdigest(),
                    dados=base64.b85encode(zlib.compress(raw,9)).decode())
        if name=='audio/AUDIO_PLAN.json':
            item['modo']='plano';item['clipes']=[
                'inspiracao','monster_step_01','monster_step_02','monster_breath',
                'impacto_porta','lanterna_liga','lanterna_desliga','menu_abre',
                'legenda_quebra','jumpscare','impacto_zumbido']
        rows[name]=item
    header='#!/usr/bin/env python3\n"""Bastiao: revisao Codex da correcao 9. Local/offline; nunca publica Roblox."""\n'
    wrapper='''
def executar_correcao():
    # Share the base installer's lock; never modify its package while it runs.
    import fcntl
    cache = Path.home() / '.bastiao_etapa3'
    lock_path = cache / 'execucao.lock'
    lock = None
    try:
        if cache.exists():
            _safe(lock_path)
            lock = lock_path.open('a')
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print('ERRO: outro instalador Etapa3 esta aberto; aguarde antes de corrigir.')
                return 1
        result = main(ARQUIVOS)
        if result == 0:
            print('Nenhuma publicacao no Roblox foi feita por esta correcao.')
            print('Depois de aplicar: python ~/storage/downloads/BASTIAO_ETAPA3.py instalar')
        return result
    finally:
        if lock is not None: lock.close()

if __name__ == '__main__':
    try:
        raise SystemExit(executar_correcao())
    except (PatchError, OSError, KeyboardInterrupt, EOFError) as exc:
        raise SystemExit('BLOQUEADO: ' + str(exc)) from None
'''
    content=header+(ROOT/'tooling/patch_install.py').read_text()+'\nARQUIVOS = '+repr(rows)+'\n'+wrapper
    compile(content,str(output),'exec')
    output=Path(output);output.parent.mkdir(parents=True,exist_ok=True);output.write_text(content)
    return {'files':len(rows),'bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--incoming',type=Path,default=ROOT.parent/'dist/CORRIGIR_ETAPA3_9.py')
    parser.add_argument('--output',type=Path,default=ROOT.parent/'dist/CORRIGIR_ETAPA3_10_CODEX.py')
    args=parser.parse_args();print(json.dumps(build(args.incoming,args.output),indent=2))
