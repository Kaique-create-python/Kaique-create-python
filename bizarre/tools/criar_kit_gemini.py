#!/usr/bin/env python3
"""Exporta o snapshot BIZARRE19 para Gemini, sem acessar Roblox ou estado local."""
import argparse
import hashlib
import json
import shutil
import stat
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

REPO = 'Kaique-create-python/Kaique-create-python'
COMMIT = 'ccae5633142efb3195db8d32c6f641dee43992b8'
INSTALLER_SHA = '1b045b98512ba65d1a049409c149f92af7915a7a3b8239d1f6888900a50a8af4'
CONTEXTO = 'BIZARRE BATTLEGROUNDS — CONTEXTO PARA CONTINUAR SEM ACESSO AO GITHUB\nAtualizado em 13/11/2026. Leia inteiro antes de propor alteracoes.\n\n1. DONO, PROJETO E ENTREGA\nSou Kaique. Falo portugues, uso Android/Termux e nao tenho PC nem Roblox Studio.\nQuero arquivos completos, instalador autocontido e comandos curtos para copiar.\nEste projeto e BIZARRE/JoJo. Nao confundir com Vesper, IRETTA ou Ideias Sem Limites.\nUniverse: 10774214555. Place: 108061345551908. Nunca operar outro destino.\nRepo privado: Kaique-create-python/Kaique-create-python.\nBranch: claude/context-capture-w0uo2t. Pasta: bizarre/.\nSnapshot dos fontes deste kit: ccae5633142efb3195db8d32c6f641dee43992b8.\nV19 original do Claude: 7a6f49f088b291542ce8ce3751c827c10d0b081f.\nO kit permite ler os fontes e reconstruir o instalador sem acesso ao GitHub.\nEle nao contem backup do Place atual nem credenciais do meu celular.\n\n2. ESTADO REAL, NAO PRESUMIR PUBLICACAO\nA ultima revisao que confirmei publicada e funcionando no chat foi AJUSTE-16.\nV18 Saved40 e V19 Saved41 falharam: "Destino/pacote incorreto".\nA correcao posterior da V19 esta neste kit. Ainda nao enviei resultado de teste\nRoblox/publicacao depois dessa correcao. Nao diga que V19 ja foi aprovada no motor.\nA correcao passou 50 verificacoes locais, incluindo 85 testes Python; nao houve\nchamada autenticada ao Roblox, publicacao ou medicao de FPS pela IA.\nSomente Validacao14 mudou entre a V19 original e a corrigida: os outros 67 fontes,\nincluindo HUD, camera, VFX, mapa e valores de combate, foram preservados.\nInstalador corrigido: BIZARRE_AJUSTE19.py, 427717 bytes.\nSHA256: 1b045b98512ba65d1a049409c149f92af7915a7a3b8239d1f6888900a50a8af4.\nO JSON de correcao registra os testes locais; previas sao locais, nao capturas do Roblox.\n\n3. O QUE AS ULTIMAS REVISOES FIZERAM\nAJ17: feedback de contato confirmado pelo servidor, deduplicacao de efeitos,\ncronologia remota ORA/MUDA sem reiniciar ao receber ACK, preferencias persistidas,\nbotoes mobile personalizaveis e laboratorio de treino particular. Iluminacao com\nmais contraste. O boneco de treino oferece bloqueio, esquiva e contra-ataque;\no reset afeta o treino do dono. Ha relatorio de dano, acertos e escapadas.\nAJ18 do Claude: VFX de contato em camadas a cada 0,025-0,05s, luz breve de impacto,\npico visual sincronizado com hitstop de 0,04/0,08s (nunca na rajada/defesa), impulso\nde FOV desligado com tremor e suporte de Animador a AnimationConstraint.\nO comando instalar junta teste Saved e publicacao com confirmacao explicita.\nAJ19 do Claude: HUD de battleground original, referencia de genero Jujutsu\nShenanigans: vida inclinada com trilha, aba do Stand, despertar com 10 segmentos,\nindicador de esquiva, cards de golpes numerados, recarga visivel, controles mobile\nperto do pulo e utilitarios discretos. Usa Bangers/Roboto Condensed, primitivas\nnativas; nao precisou reenviar assets. Layouts personalizados continuam aceitos.\nCorrecao19: Python aceitava18/19 mas Validacao14.luau aceitava so14..17. O gate\nLuau passou a aceitar explicitamente18/19 sem remover verificacoes de destino,\npacote, revisao ou integridade. Gerador19 aceita tambem a baseline19 original.\n\n4. ARQUITETURA E O QUE PRESERVAR\n68 fontes Luau em src/. Cliente cuida de entrada, camera, HUD, animacao e VFX.\nServidor valida combate, alvo, alcance/linha de visada, cooldown, bloqueio/parry,\ndano e estado. Jogadores nunca enviam codigo Luau para executar.\nSeis kits: STAR_PLATINUM, THE_WORLD, CRAZY_DIAMOND, KILLER_QUEEN,\nMAGICIANS_RED e SILVER_CHARIOT. Preserve Golpes/Regras e numeros sem pedido meu.\nPreserve R6 obrigatorio, locomocao, ShiftLock e mira manual que funcionam.\nCamera deve acompanhar o alvo; nao basta girar o personagem. Lock deve sobreviver\na impacto/ragdoll valido e liberar alvo morto/invalido. Nao refazer sem necessidade.\nORA/MUDA duram 4,6s com final em4,35s; nao acrescentar cancelamento voluntario.\nSom deve acompanhar a habilidade e parar junto. Audio To Be Continued foi\nrejeitado e removido: nao reenviar nem restaurar. Reutilize IDs e midias existentes.\nMapa Morioh, colisoes e artes/sons aprovados devem ser preservados.\nEstatisticas: BB_Jogadores_v1; preferencias separadas em BB_Preferencias_v1.\nNao apagar dados, inventar IDs, rodar setup ou assets-upload de novo.\nMeu foco e qualidade visual e combate; nao inserir reducao automatica de qualidade\npor FPS sem pedido. Nao afirmar desempenho sem medir no cliente Roblox.\n\n5. SEGURANCA, INSTALADOR E PUBLICACAO\nNunca pedir senha, cookie .ROBLOSECURITY, chave Open Cloud ou token no chat.\nChave Roblox digitada oculta com getpass somente no Termux; nunca salvar/logar.\nNunca ler/exportar ~/.bizarre_instalador, recibos e chaves no kit de contexto.\nPreservar integralmente esse estado local, backups e active-write.json.\nO instalador baixa o Place inteiro e edita apenas Sources conhecidos. Preserva\nmapa, chunks opacos e propriedades externas. Fonte desconhecida bloqueia: nao\nforcar, retirar a trava ou adicionar hashes desconhecidos so para passar.\nNao reconstruir o Place atual de um fixture antigo e nao usar SavePlaceAsync.\nNao inventar endpoints/metodos; confirmar documentacao e codigo existente.\nResposta de upload incerta: executar resume, que consulta; nunca repetir o POST,\nrepublicar automaticamente ou apagar active-write.json.\nNao publicar apenas porque leu este arquivo ou porque um teste local passou.\nFluxo atual no celular:\n  python ~/BIZARRE_AJUSTE19.py testar\n  python ~/BIZARRE_AJUSTE19.py testar-nuvem\nSomente apos TESTE APROVADO, sem salvamento concorrente e com minha autorizacao:\n  python ~/BIZARRE_AJUSTE19.py publicar\nConfirmacao humana: PUBLICAR AJUSTE19. Esperar PUBLICADO E VERIFICADO.\nO comando instalar tambem exige confirmacao explicita antes de publicar.\nPergunte o ultimo resultado real quando necessario; leitura/revisao de codigo\nnao exige que eu teste ou publique primeiro.\n\n6. COMO LER E RECONSTRUIR ESTE KIT\nComece por este TXT, depois 01_COMPARTILHADO_LUAU.txt, 02_CLIENTE_LUAU.txt e\n03_SERVIDOR_LUAU.txt. Cada bloco informa o caminho real dentro de bizarre/.\n04_INSTALADOR_FERRAMENTAS.txt contem Python e geradores; 05_TESTES_E_NOTAS.txt\ncontem verificacoes e documentacao. PLANO.md tem historia: este guia e os docs\nAJ19/CORRECAO_AJUSTE19 prevalecem quando houver conflito.\n06_PROJETO_FONTE.json guarda os arquivos de texto exatos por caminho relativo.\n07_BIZARRE_AJUSTE19.py e o instalador corrigido original, sem alteracao.\n08_RECONSTRUIR_PROJETO.py reconstroi uma pasta nova sem executar codigo do jogo,\nsem rede e sem chave: le o JSON e extrai quatro catalogos do payload validado.\nSe voce tiver ambiente Python, revise o script antes de executar:\n  python 08_RECONSTRUIR_PROJETO.py --saida trabalho\n  python trabalho/bizarre/tools/gerar_ajuste19.py --output BIZARRE_AJUSTE19_reconstruido.py\nO resultado deve ter o mesmo SHA256 acima. Nao editar PAYLOAD comprimido a mao:\neditar src/ e geradores e gerar novamente. Midias completas e antigos instaladores\nnao acompanham o kit; catalogos necessarios ao build19 sao recuperados do payload.\nAlguns testes de migracao antigos dependem de fixture/Git historico nao incluido.\nNao dizer que rodou teste nativo ou migracao historica se nao possui esse ambiente.\nSe nao conseguir ler todos os anexos, diga exatamente qual arquivo faltou.\nSe o app recusar ZIP, anexar os TXT individuais (o exportador tambem os deixa soltos).\n\n7. SE FORMOS CRIAR AJUSTE-20\nPrimeiro combinar comigo a alteracao. Nao implementar itens antigos do PLANO\ncomo se fossem meu pedido atual. Preservar instalador19 e gerar arquivo20 separado.\nSincronizar PACKAGE/stage, Config.REVISAO, gate Luau Validacao14, runtime/package\nPython, gerador, teste_nuvem, nomes das saidas, estado e confirmacao PUBLICAR AJUSTE20.\nbaseline19.json registra a19 original: aceitar TAMBEM o hash do validador19\ncorrigido deste kit, preservando a original. Senao bloqueara usuarios ja corrigidos.\nExtrair e testar o validador do instalador REAL gerado, nao so o src/ do checkout.\nManter testes que rejeitam universe/place/pacote incorretos e futuras revisoes\nnao suportadas. Verificar patch completo, determinismo, idempotencia e preservacao.\nRodar testes adequados a mudanca; separar evidencia local do teste autenticado.\nEntregar arquivos completos, instalador real e comandos Termux. Se nao tiver GitHub,\nentregar para eu baixar/substituir sem depender de Studio ou fragmentos no chat.\nNao afirmar que enviou arquivo ao GitHub/Drive ou publicou sem comprovacao real.\n\n8. PRIMEIRA RESPOSTA ESPERADA DA GEMINI\nResuma em cinco linhas o estado, a arquitetura e as restricoes que entendeu.\nDiga se conseguiu ler os fontes. Aguarde minha proxima alteracao especifica.\nNao execute, publique, reescreva combate ou invente features por conta propria.\nSeja direta e economize: investigue o problema especifico, preserve o que funciona,\nvalide a mudanca e informe honestamente o que ficou sem verificacao no Roblox.\n'
RECONSTRUIR = '#!/usr/bin/env python3\n"""Reconstruct the attached project without importing or executing its code."""\nimport argparse, ast, base64, hashlib, io, json, stat, zipfile, zlib\nfrom pathlib import Path, PurePosixPath\nSHA = \'1b045b98512ba65d1a049409c149f92af7915a7a3b8239d1f6888900a50a8af4\'\nCATALOGS = {\'catalogo.rbxm\': \'assets/vfx14/catalogo.rbxm\', \'catalogo.rbxmx\': \'assets/vfx14/catalogo.rbxmx\', \'catalogo15.rbxm\': \'assets/vfx15/catalogo.rbxm\', \'catalogo15.rbxmx\': \'assets/vfx15/catalogo.rbxmx\'}\n\ndef safe(name):\n    p = PurePosixPath(name)\n    if not name or p.is_absolute() or \'\\\\\' in name or any(x in (\'\', \'.\', \'..\') for x in name.split(\'/\')):\n        raise ValueError(\'Caminho invalido no kit.\')\n    return p\n\ndef main():\n    parser = argparse.ArgumentParser(description=__doc__)\n    parser.add_argument(\'--saida\', type=Path, default=Path(\'BIZARRE_FONTE\'))\n    args = parser.parse_args()\n    here = Path(__file__).resolve().parent\n    raw = (here / \'07_BIZARRE_AJUSTE19.py\').read_bytes()\n    if hashlib.sha256(raw).hexdigest() != SHA:\n        raise ValueError(\'Instalador19 nao corresponde ao snapshot validado.\')\n    constants = {}\n    for node in ast.parse(raw.decode()).body:\n        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and node.targets[0].id in (\'PAYLOAD\', \'SHA256\'):\n            constants[node.targets[0].id] = ast.literal_eval(node.value)\n    encoded = base64.b85decode(constants[\'PAYLOAD\'])\n    if hashlib.sha256(encoded).hexdigest() != constants[\'SHA256\']:\n        raise ValueError(\'Integridade do payload invalida.\')\n    dec = zlib.decompressobj()\n    blob = dec.decompress(encoded, 16 * 1024 * 1024 + 1)\n    if len(blob) > 16 * 1024 * 1024 or not dec.eof or dec.unused_data or dec.unconsumed_tail:\n        raise ValueError(\'Payload invalido.\')\n    project = json.loads((here / \'06_PROJETO_FONTE.json\').read_text(encoding=\'utf-8\'))\n    files = {}\n    for name, content in project[\'files\'].items():\n        path = safe(name)\n        data = content.encode(\'utf-8\')\n        if hashlib.sha256(data).hexdigest() != project[\'sha256\'][name]:\n            raise ValueError(\'Fonte alterado: \' + name)\n        files[path.as_posix()] = data\n    with zipfile.ZipFile(io.BytesIO(blob)) as z:\n        infos = z.infolist()\n        if len(infos) > 256 or sum(i.file_size for i in infos) > 16 * 1024 * 1024 or len({i.filename for i in infos}) != len(infos):\n            raise ValueError(\'Catalogo invalido.\')\n        for item in infos:\n            safe(item.filename)\n            if stat.S_ISLNK(item.external_attr >> 16):\n                raise ValueError(\'Link invalido.\')\n        manifest = json.loads(z.read(\'bundle-manifest.json\'))\n        for source, target in CATALOGS.items():\n            name = \'payload/\' + source\n            data = z.read(name)\n            if hashlib.sha256(data).hexdigest() != manifest[name]:\n                raise ValueError(\'Catalogo alterado.\')\n            files[target] = data\n    files[\'dist/BIZARRE_AJUSTE19.py\'] = raw\n    dest = args.saida.expanduser()\n    if dest.exists() or dest.is_symlink():\n        raise ValueError(\'Escolha uma pasta nova; nada foi sobrescrito.\')\n    dest.mkdir(parents=True)\n    for name, data in files.items():\n        p = dest / \'bizarre\' / safe(name)\n        p.parent.mkdir(parents=True, exist_ok=True)\n        p.write_bytes(data)\n    print(\'Fontes reconstruidos em \' + str(dest / \'bizarre\') + \'. Nenhum codigo do jogo executado; nenhuma conexao.\')\n\nif __name__ == \'__main__\':\n    try:\n        main()\n    except (ValueError, OSError, KeyError, zipfile.BadZipFile, zlib.error) as exc:\n        raise SystemExit(\'ERRO: \' + str(exc)) from None\n'
TEXT_EXT = {'.luau', '.py', '.txt', '.md', '.json', '.html', '.js'}
FOLDERS = {'src', 'installer14', 'tools', 'tests', 'docs'}
ROOT_FILES = {'LEIA_CHATGPT.md', 'PLANO.md', 'README.md'}
LIMIT = 128 * 1024 * 1024


def caminho(name):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or '\\' in name or any(p in ('', '.', '..') for p in name.rstrip('/').split('/')):
        raise ValueError('Caminho invalido no ZIP; nada sera extraido.')
    return path


def selecionado(parts):
    if any(p.startswith('.') or p == '__pycache__' for p in parts):
        return False
    return parts[0] in FOLDERS and PurePosixPath(*parts).suffix in TEXT_EXT or len(parts) == 1 and parts[0] in ROOT_FILES


def blocos(files, predicate):
    return ''.join('\n' + '=' * 72 + '\nARQUIVO: bizarre/' + name + '\n' + '=' * 72 + '\n' + text + '\n' for name, text in sorted(files.items()) if predicate(name))


def exportar(archive, output):
    """Read a scoped repo snapshot and emit nine attachments; never execute it."""
    files = {}
    installer = None
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        if len(infos) > 20000 or sum(i.file_size for i in infos) > LIMIT:
            raise ValueError('ZIP excedeu o limite de leitura.')
        names = set()
        roots = set()
        for item in infos:
            path = caminho(item.filename)
            if stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError('Link no ZIP nao e permitido.')
            if item.filename in names:
                raise ValueError('Arquivo duplicado no ZIP.')
            names.add(item.filename)
            if len(path.parts) < 3 or path.parts[1] != 'bizarre' or item.is_dir():
                continue
            roots.add(path.parts[0])
            parts = path.parts[2:]
            name = '/'.join(parts)
            if name == 'dist/BIZARRE_AJUSTE19.py':
                installer = z.read(item)
            elif selecionado(parts):
                files[name] = z.read(item).decode('utf-8')
        if len(roots) != 1 or installer is None or hashlib.sha256(installer).hexdigest() != INSTALLER_SHA:
            raise ValueError('ZIP nao corresponde ao instalador19 corrigido; nenhum arquivo criado.')
    if sum(n.startswith('src/') and n.endswith('.luau') for n in files) != 68:
        raise ValueError('Snapshot incompleto: esperados 68 fontes Luau.')
    files['CONTEXTO_GEMINI.txt'] = CONTEXTO
    project = {'commit': COMMIT, 'repository': REPO, 'files': files,
               'sha256': {n: hashlib.sha256(t.encode('utf-8')).hexdigest() for n, t in files.items()}}
    attachments = {
        '00_CONTEXTO_GEMINI.txt': CONTEXTO.encode('utf-8'),
        '01_COMPARTILHADO_LUAU.txt': blocos(files, lambda n: n.startswith('src/ReplicatedStorage/')).encode('utf-8'),
        '02_CLIENTE_LUAU.txt': blocos(files, lambda n: n.startswith('src/Starter')).encode('utf-8'),
        '03_SERVIDOR_LUAU.txt': blocos(files, lambda n: n.startswith('src/') and not n.startswith(('src/ReplicatedStorage/', 'src/Starter'))).encode('utf-8'),
        '04_INSTALADOR_FERRAMENTAS.txt': blocos(files, lambda n: n.startswith(('installer14/', 'tools/')) and not PurePosixPath(n).name.startswith(('tests_', 'teste_'))).encode('utf-8'),
        '05_TESTES_E_NOTAS.txt': blocos(files, lambda n: not n.startswith('src/') and not (n.startswith(('installer14/', 'tools/')) and not PurePosixPath(n).name.startswith(('tests_', 'teste_')))).encode('utf-8'),
        '06_PROJETO_FONTE.json': json.dumps(project, ensure_ascii=False, indent=1).encode('utf-8'),
        '07_BIZARRE_AJUSTE19.py': installer,
        '08_RECONSTRUIR_PROJETO.py': RECONSTRUIR.encode('utf-8'),
    }
    output = Path(output).expanduser()
    output.mkdir(parents=True, exist_ok=True)
    dest = output / 'BIZARRE_GEMINI_AJUSTE19'
    if dest.exists() or dest.is_symlink():
        raise ValueError('Pasta BIZARRE_GEMINI_AJUSTE19 ja existe. Use --saida com outra pasta.')
    with tempfile.TemporaryDirectory(prefix='.gemini-', dir=output) as temporary:
        stage = Path(temporary)
        for name, data in attachments.items():
            (stage / name).write_bytes(data)
        with zipfile.ZipFile(stage / 'BIZARRE_KIT_GEMINI.zip', 'w', zipfile.ZIP_DEFLATED) as z:
            for name, data in attachments.items():
                z.writestr(name, data)
        stage.rename(dest)
    return {'zip': str(dest / 'BIZARRE_KIT_GEMINI.zip'), 'contexto': str(dest / '00_CONTEXTO_GEMINI.txt')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arquivo', '--archive', type=Path, help='ZIP do snapshot ja baixado; sem rede')
    parser.add_argument('--saida', type=Path, default=Path.home() / 'storage/downloads')
    args = parser.parse_args()
    if args.arquivo:
        result = exportar(args.arquivo, args.saida)
    else:
        if not shutil.which('gh'):
            raise ValueError('gh nao instalado. Use o GitHub CLI ja autenticado no seu Termux.')
        with tempfile.TemporaryDirectory(prefix='bizarre-gemini-') as temporary:
            archive = Path(temporary) / 'repo.zip'
            print('Baixando somente o snapshot de referencia pelo seu gh...')
            with archive.open('wb') as stream:
                result = subprocess.run(['gh', 'api', 'repos/' + REPO + '/zipball/' + COMMIT], stdout=stream, stderr=subprocess.PIPE, timeout=240)
            if result.returncode:
                raise ValueError('Download pelo gh falhou. Confira gh auth status e sua conexao; nenhuma chave Roblox e necessaria.')
            result = exportar(archive, args.saida)
    print('Kit pronto: ' + result['zip'])
    print('Contexto: ' + result['contexto'])
    print('Anexe o ZIP ao Gemini. Se recusar, anexe os TXT soltos da mesma pasta.')
    print('Nenhuma chamada ao Roblox, alteracao no jogo ou leitura do estado do instalador.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.TimeoutExpired) as exc:
        raise SystemExit('ERRO: ' + str(exc)) from None
