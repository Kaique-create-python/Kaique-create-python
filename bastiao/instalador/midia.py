"""Sons da etapa (opcionais): envio pela Open Cloud com recibo e o modulo Audio com os IDs.

Regras: nada aqui trava a instalacao (sem som o jogo segue com as legendas); cada arquivo e
enviado uma vez so (o recibo guarda o ID pelo SHA-256, entao rodar de novo nao reenvia); a chave
so vai para apis.roblox.com (o dono do jogo e lido na API publica de jogos, sem chave).
"""
import json
import re
import time
import urllib.request
import uuid

from .codec import Failure
from .runtime import read, save, sha, stamp, TARGET

CABECALHO = '-- PROJETO BASTIÃO :: áudio (gerado pelo instalador; não editar à mão)\n'
CAMINHO = ['ReplicatedStorage', 'BastiaoCompartilhado', 'Audio']
SPRITES = ('voz_pt', 'voz_en', 'voz_ru', 'efeitos')
IDIOMAS = ('pt', 'en', 'ru')
GAMES = 'https://games.roblox.com'
ESTADOS = {'Approved': 'APROVADO', 'Reviewing': 'em análise', 'Rejected': 'RECUSADO'}
PERMISSAO_ENVIO = 'Assets -> asset:read e asset:write'
PERMISSAO_LIBERAR = 'Asset Permissions -> asset-permissions:write'
NOME = re.compile(r'^[a-z][a-z0-9_]*$')


def aviso(msg):
    print('   [sons] ' + msg, flush=True)


# ------------------------------------------------------------------ módulo Audio (Luau)
def _numero(x):
    if isinstance(x, bool) or not isinstance(x, (int, float)) or x != x or x < 0 or x > 3600:
        raise Failure('Tempo de áudio inválido no pacote.')
    texto = ('%.3f' % x).rstrip('0').rstrip('.')
    return texto or '0'


def _trecho(seg):
    if not isinstance(seg, list) or len(seg) != 2:
        raise Failure('Trecho de áudio inválido no pacote.')
    if seg[1] <= 0:
        raise Failure('Trecho de áudio com duração zero.')
    return '{ %s, %s }' % (_numero(seg[0]), _numero(seg[1]))


def _chave(k):
    if not isinstance(k, str) or not NOME.match(k):
        raise Failure('Nome de som inválido no pacote: ' + repr(k))
    return k


def validar_dados(dados):
    """Confere o audio.json: só os arquivos conhecidos, trechos dentro de cada arquivo."""
    if not isinstance(dados, dict) or not isinstance(dados.get('sprites'), dict):
        raise Failure('audio.json inválido.')
    for nome, info in dados['sprites'].items():
        if nome not in SPRITES or not isinstance(info, dict) or info.get('arquivo') != 'audio/' + nome + '.ogg':
            raise Failure('Arquivo de som desconhecido no pacote: ' + str(nome))
        _numero(info.get('segundos'))

    def dentro(sprite, seg, rotulo):
        _trecho(seg)
        total = dados['sprites'].get(sprite, {}).get('segundos')
        if total is None or seg[0] + seg[1] > total + 0.01:
            raise Failure('Trecho fora do arquivo de som: ' + rotulo)

    for idioma, falas in (dados.get('vozes') or {}).items():
        if idioma not in IDIOMAS or not isinstance(falas, dict):
            raise Failure('Língua inválida no áudio: ' + str(idioma))
        for k, seg in falas.items():
            dentro('voz_' + idioma, seg, idioma + '.' + _chave(k))
    for grupo in ('sfx', 'loops'):
        for k, seg in (dados.get(grupo) or {}).items():
            _chave(k)
            lista = seg if seg and isinstance(seg[0], list) else [seg]
            for s in lista:
                dentro('efeitos', s, grupo + '.' + k)
    for k, d in (dados.get('duracoes') or {}).items():
        _chave(k)
        _numero(d)
    return dados


def fonte_audio(dados, ids):
    """Fonte Luau do módulo Audio (determinística: mesmas entradas, mesmo texto)."""
    validar_dados(dados)
    for k, v in ids.items():
        if k not in SPRITES or isinstance(v, bool) or not isinstance(v, int) or v < 0 or v >= 10 ** 19:
            raise Failure('ID de som inválido: ' + str(k))
    linhas = [
        CABECALHO.rstrip('\n'),
        '-- Trechos (início, duração em segundos) dentro de cada arquivo de som e o ID de cada arquivo',
        '-- no Roblox. ID 0 = ainda sem som (o jogo mostra só as legendas).',
        'return {',
        '\tversao = %d,' % int(dados.get('versao', 1)),
        '\tids = { ' + ', '.join('%s = %d' % (s, int(ids.get(s, 0))) for s in SPRITES) + ' },',
        '\tvozes = {',
    ]
    vozes = dados.get('vozes') or {}
    for idioma in IDIOMAS:
        falas = vozes.get(idioma) or {}
        linhas.append('\t\t%s = {' % idioma)
        for k in sorted(falas):
            linhas.append('\t\t\t%s = %s,' % (_chave(k), _trecho(falas[k])))
        linhas.append('\t\t},')
    linhas.append('\t},')
    for grupo in ('sfx', 'loops'):
        linhas.append('\t%s = {' % grupo)
        tabela = dados.get(grupo) or {}
        for k in sorted(tabela):
            seg = tabela[k]
            if seg and isinstance(seg[0], list):
                linhas.append('\t\t%s = { %s },' % (_chave(k), ', '.join(_trecho(s) for s in seg)))
            else:
                linhas.append('\t\t%s = %s,' % (_chave(k), _trecho(seg)))
        linhas.append('\t},')
    linhas.append('\tduracoes = {')
    duracoes = dados.get('duracoes') or {}
    for k in sorted(duracoes):
        linhas.append('\t\t%s = %s,' % (_chave(k), _numero(duracoes[k])))
    linhas.append('\t},')
    linhas.append('}')
    return '\n'.join(linhas) + '\n'


# ------------------------------------------------------------------ IDs usados no teste
def salvar_ids(state, digest, ids):
    save(state / 'audio-ids.json', dict(digest=digest, ids=ids, at=stamp()))


def ids_salvos(state, digest):
    """IDs gravados no teste desta entrega (publish/resume montam exatamente o mesmo place)."""
    r = read(state / 'audio-ids.json', {})
    if not isinstance(r, dict) or r.get('digest') != digest or not isinstance(r.get('ids'), dict):
        return {}
    return {k: v for k, v in r['ids'].items() if k in SPRITES and isinstance(v, int) and not isinstance(v, bool) and v >= 0}


# ------------------------------------------------------------------ envio
def multipart(campos):
    limite = '----BASTIAO' + uuid.uuid4().hex
    partes = []
    for nome, valor, arquivo, tipo in campos:
        cab = '--%s\r\nContent-Disposition: form-data; name="%s"' % (limite, nome)
        if arquivo:
            cab += '; filename="%s"' % arquivo
        cab += '\r\n'
        if tipo:
            cab += 'Content-Type: %s\r\n' % tipo
        partes += [(cab + '\r\n').encode(), valor, b'\r\n']
    partes.append(('--%s--\r\n' % limite).encode())
    return b''.join(partes), 'multipart/form-data; boundary=' + limite


def explicar(e, etapa):
    codigo = getattr(e, 'code', None)
    if codigo == 401:
        return 'a chave foi recusada (inválida, expirada ou com restrição de IP).'
    if codigo == 403:
        permissao = PERMISSAO_LIBERAR if etapa == 'liberar' else PERMISSAO_ENVIO
        return ('a chave não tem permissão para isso. No Creator Hub > Open Cloud > API Keys, edite a chave e '
                'adicione: ' + permissao + '.')
    if codigo == 429:
        return 'muitos pedidos seguidos (limite do Roblox, inclusive o limite mensal de envios de som).'
    if codigo == 400:
        return 'o Roblox recusou o pedido: ' + str(e)[:300]
    return str(e)[:300]


def dono_do_jogo(universe, abrir=None):
    """Dono da experiência pela API pública de jogos (sem chave). None se não der."""
    abrir = abrir or urllib.request.urlopen
    try:
        pedido = urllib.request.Request(GAMES + '/v1/games?universeIds=' + str(int(universe)),
                                        headers={'Accept': 'application/json', 'User-Agent': 'BASTIAO-ETAPA/2.0'})
        with abrir(pedido, timeout=30) as r:
            d = json.loads(r.read(200000))
        c = d['data'][0]['creator']
        tipo, ident = c.get('type'), str(c.get('id'))
        if tipo in ('User', 'Group') and ident.isdigit():
            return tipo, ident
    except Exception:
        pass
    return None


class Midia:
    def __init__(self, root, dados, arquivos, espera=4.0, limite=120.0, perguntar=input, dono=dono_do_jogo, dormir=time.sleep):
        self.recibos_path = root / 'midia-recibos.json'
        recibos = read(self.recibos_path, {})
        self.recibos = recibos if isinstance(recibos, dict) else {}
        self.recibos.setdefault('arquivos', {})
        self.recibos.setdefault('liberados', [])
        self.dados = dados
        self.arquivos = arquivos
        self.espera, self.limite = espera, limite
        self.perguntar, self.dono, self.dormir = perguntar, dono, dormir
        self.sem_permissao = False

    def _gravar(self):
        save(self.recibos_path, self.recibos)

    def criador(self):
        info = self.dono(TARGET['universe'])
        if info:
            tipo, ident = info
            print('   [sons] dono do jogo: %s %s' % ('grupo' if tipo == 'Group' else 'usuário', ident), flush=True)
            return {'groupId': ident} if tipo == 'Group' else {'userId': ident}
        try:
            texto = self.perguntar('   Não achei o dono do jogo. Digite o seu UserId do Roblox (número) para enviar os sons, ou Enter para pular: ').strip()
        except (EOFError, KeyboardInterrupt):
            texto = ''
        if texto.isdigit() and 0 < len(texto) < 20:
            return {'userId': texto}
        aviso('sem o dono do jogo não dá para enviar os sons agora; o jogo segue com as legendas.')
        return None

    def _operacao(self, cloud, op_id):
        d = cloud.request('/assets/v1/operations/' + op_id)
        if not d.get('done'):
            return None, None
        if d.get('error'):
            raise Failure('o Roblox recusou o som: ' + json.dumps(d.get('error'))[:300])
        resposta = d.get('response') or {}
        estado = (resposta.get('moderationResult') or {}).get('moderationState') or ''
        asset = str(resposta.get('assetId') or '')
        return (asset if asset.isdigit() else None), estado

    def _moderacao(self, cloud, asset_id):
        try:
            d = cloud.request('/assets/v1/assets/%s?readMask=moderationResult' % asset_id)
            return (d.get('moderationResult') or {}).get('moderationState') or ''
        except Failure:
            return ''

    def _esperar(self, cloud, nome, rec):
        inicio = time.monotonic()
        while time.monotonic() - inicio < self.limite:
            self.dormir(self.espera)
            asset, estado = self._operacao(cloud, rec['operationId'])
            if asset:
                rec.update(assetId=asset, estado=estado)
                self._gravar()
                return asset, estado
        return None, None

    def enviar(self, cloud, nome, criador):
        info = self.dados['sprites'][nome]
        raw = self.arquivos[info['arquivo']]
        h = sha(raw)
        rec = self.recibos['arquivos'].get(h) or {}
        try:
            if rec.get('assetId'):
                estado = self._moderacao(cloud, rec['assetId']) or rec.get('estado', '')
                if estado != rec.get('estado'):
                    rec['estado'] = estado
                    self._gravar()
                if estado == 'Rejected':
                    aviso('%s: o Roblox RECUSOU na moderação (ID %s); fica sem esse som.' % (nome, rec['assetId']))
                    return 0
                print('   [sons] %s: já enviado antes (ID %s, moderação: %s)' % (nome, rec['assetId'], ESTADOS.get(estado, estado or '?')), flush=True)
                return int(rec['assetId'])
            if rec.get('operationId'):
                asset, estado = self._esperar(cloud, nome, rec)
            else:
                if criador is None or self.sem_permissao:
                    return 0
                pedido = {
                    'assetType': 'Audio',
                    'displayName': ('BASTIAO %s' % nome)[:50],
                    'description': 'Projeto Bastiao: %s. Enviado pelo instalador.' % nome,
                    'creationContext': {'creator': criador},
                }
                corpo, tipo = multipart([
                    ('request', json.dumps(pedido).encode(), None, 'application/json'),
                    ('fileContent', raw, nome + '.ogg', 'audio/ogg'),
                ])
                op = cloud.request('/assets/v1/assets', raw=corpo, mime=tipo, method='POST')
                op_id = str(op.get('operationId') or str(op.get('path') or '').split('/')[-1])
                if not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', op_id):
                    aviso('%s: resposta inesperada do Roblox; fica sem esse som por enquanto.' % nome)
                    return 0
                rec = dict(arquivo=nome, operationId=op_id, enviadoEm=stamp(), bytes=len(raw))
                self.recibos['arquivos'][h] = rec
                self._gravar()
                print('   [sons] %s enviado (%d KB); esperando o Roblox processar...' % (nome, len(raw) // 1024), flush=True)
                asset, estado = self._esperar(cloud, nome, rec)
        except Failure as e:
            if getattr(e, 'code', None) in (401, 403):
                self.sem_permissao = True
            aviso('%s: %s Seguindo sem esse som (é opcional).' % (nome, explicar(e, 'envio')))
            return 0
        if not asset:
            aviso('%s: o Roblox ainda está processando. Rode o instalador de novo daqui a alguns minutos para incluir.' % nome)
            return 0
        if estado == 'Rejected':
            aviso('%s: o Roblox recusou na moderação; fica sem esse som.' % nome)
            return 0
        print('   [sons] %s: ID %s (moderação: %s)' % (nome, asset, ESTADOS.get(estado, estado or 'em análise')), flush=True)
        return int(asset)

    def liberar(self, cloud, asset_id):
        """Permissão do jogo para usar o som (o dono já pode; isto cobre jogo de grupo). Nunca trava."""
        chave = '%s:%s' % (TARGET['universe'], asset_id)
        if chave in self.recibos['liberados']:
            return True
        pedido = {'subjectType': 'Universe', 'subjectId': str(TARGET['universe']), 'action': 'Use',
                  'requests': [{'assetId': int(asset_id)}]}
        try:
            d = cloud.request('/asset-permissions-api/v1/assets/permissions', body=pedido, method='PATCH')
        except Failure as e:
            if getattr(e, 'code', None) != 403:
                aviso('não deu para liberar o som %s para o jogo agora (%s).' % (asset_id, explicar(e, 'liberar')))
            return False
        feitos = {str(a) for a in (d.get('successAssetIds') or [])}
        for erro in d.get('errors') or []:
            if str(erro.get('code', '')) in ('AlreadyGranted', 'PermissionAlreadyExists'):
                feitos.add(str(erro.get('assetId') or ''))
        if str(asset_id) in feitos:
            self.recibos['liberados'].append(chave)
            self._gravar()
            return True
        return False

    def preparar(self, cloud):
        """Envia (ou reaproveita) cada arquivo de som. Devolve {sprite: id}; 0 = sem som."""
        ids = {nome: 0 for nome in SPRITES}
        presentes = [n for n in SPRITES if n in self.dados['sprites']]
        if not presentes:
            return ids
        print('Sons e vozes (opcional: nada aqui trava a instalação)', flush=True)
        precisa_enviar = any(not (self.recibos['arquivos'].get(sha(self.arquivos[self.dados['sprites'][n]['arquivo']])) or {}).get('operationId')
                             and not (self.recibos['arquivos'].get(sha(self.arquivos[self.dados['sprites'][n]['arquivo']])) or {}).get('assetId')
                             for n in presentes)
        criador = self.criador() if precisa_enviar else None
        for nome in presentes:
            try:
                ids[nome] = self.enviar(cloud, nome, criador)
            except Exception as e:  # nada dos sons pode travar a instalação
                aviso('%s: %s; seguindo sem esse som.' % (nome, type(e).__name__))
                ids[nome] = 0
            if ids[nome]:
                try:
                    self.liberar(cloud, ids[nome])
                except Exception:
                    pass
        faltando = [n for n in presentes if not ids[n]]
        if faltando:
            aviso('sem som por enquanto: %s (as legendas aparecem igual).' % ', '.join(faltando))
            if self.sem_permissao:
                aviso('para os sons: dê à chave a permissão ' + PERMISSAO_ENVIO + ' e rode de novo.')
        return ids
