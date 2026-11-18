"""PROJETO BASTIAO :: testes do instalador da Etapa 2.

O patch so acrescenta/atualiza scripts Bastiao* (mapa, HUD e scripts Sector7 ficam iguais; um
script da Etapa 1 so e trocado se for exatamente o que a Etapa 1 instalou), os sons sao enviados
uma vez so e nunca travam, e o protocolo testar -> PUBLICAR ETAPA2 -> resume nunca repete envio.
So a fronteira com o Roblox e simulada.
Rodar da raiz do repositorio:  python3 -m unittest discover -s bastiao/tests -v
"""
import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch as trocar

RAIZ = Path(__file__).resolve().parents[1]
REPO = RAIZ.parent
sys.path[:0] = [str(RAIZ), str(RAIZ / 'ferramentas')]
from instalador.codec import Failure  # noqa: E402
from instalador.patcher import patch_place, validate  # noqa: E402
from instalador.package import Package  # noqa: E402
from instalador.runtime import Runtime  # noqa: E402
from instalador import midia  # noqa: E402
import gerar_etapa2  # noqa: E402

PLACE = Path(os.environ.get('BASTIAO_PLACE', '/tmp/claude-0/-home-user/8073e9e5-493c-555e-858a-2e1de54d2eed/scratchpad/bastiao/place/place_original.rbxl'))
LUNE = shutil.which('lune')
ARQUIVOS, PACOTE = gerar_etapa2.coletar()
N_SCRIPTS = len(PACOTE.entries)


def pacote_etapa1():
    """O pacote que o BASTIAO_ETAPA1.py entregue instala (lido do próprio arquivo)."""
    import ast, base64, io, zipfile, zlib
    arvore = ast.parse((RAIZ / 'dist' / 'BASTIAO_ETAPA1.py').read_text(encoding='utf-8'))
    carga = next(ast.literal_eval(n.value) for n in arvore.body if isinstance(n, ast.Assign) and n.targets[0].id == 'PAYLOAD')
    with zipfile.ZipFile(io.BytesIO(zlib.decompress(base64.b85decode(carga)))) as z:
        return Package({n[len('payload/'):]: z.read(n) for n in z.namelist() if n.startswith('payload/')})


def novo_pacote():
    return Package(dict(ARQUIVOS))


def fixture():
    """Place XML pequeno com os mesmos contêineres do jogo (e um HUD e um mapa para preservar)."""
    raiz = ET.Element('roblox', version='4')
    refs = iter(range(1000))

    def item(pai, classe, nome, fonte=None):
        it = ET.SubElement(pai, 'Item', {'class': classe, 'referent': 'R' + str(next(refs))})
        props = ET.SubElement(it, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = nome
        if fonte is not None:
            ET.SubElement(props, 'ProtectedString', name='Source').text = fonte
        return it

    item(raiz, 'ReplicatedStorage', 'ReplicatedStorage')
    sss = item(raiz, 'ServerScriptService', 'ServerScriptService')
    s7 = item(sss, 'Folder', 'Sector7')
    item(s7, 'Script', 'Server', 'print("sector7")')
    sp = item(raiz, 'StarterPlayer', 'StarterPlayer')
    sps = item(sp, 'StarterPlayerScripts', 'StarterPlayerScripts')
    cli = item(sps, 'LocalScript', 'Sector7Client', 'print("hud")')
    item(cli, 'ModuleScript', 'BodycamHUD', 'return "hud original"')
    ws = item(raiz, 'Workspace', 'Workspace')
    mundo = item(ws, 'Model', 'Sector7World')
    item(mundo, 'Part', 'CentralSpineFloor')
    return ET.tostring(raiz)


def patch(raw):
    return PACOTE.patch(raw)


class FakeCloud:
    def __init__(self):
        self.blobs = {8: fixture()}
        self.rows = [{'version': 8, 'isPublished': True}]
        self.writes = []
        self.fail_write = False
        self.report = {'package': 'BASTIAO-ETAPA-2', 'passed': True}
        self.tarefas = []

    def validate_destination(self):
        pass

    def team_empty(self):
        pass

    def history(self):
        return max(self.blobs), copy.deepcopy(self.rows)

    def download(self, version, path):
        raw = self.blobs[version]
        Path(path).write_bytes(raw)
        return raw

    def request(self, path, **kw):
        if kw.get('method') != 'POST':
            raise AssertionError('o fake só aceita envios')
        modo = path.rsplit('=', 1)[-1]
        self.writes.append(modo)
        versao = max(self.blobs) + 1
        self.blobs[versao] = kw['raw']
        self.rows.append({'version': versao, 'isPublished': modo == 'Published'})
        if self.fail_write:
            raise Failure('Conexao interrompida sem resposta')
        return {'versionNumber': versao}

    def task(self, version, source):
        # o teste nativo sempre roda na versão já com o pacote
        if patch(self.blobs[version]) != (self.blobs[version], False):
            raise Failure('teste rodou numa versão sem o pacote')
        self.tarefas.append(source)
        return dict(self.report)


class PacoteTests(unittest.TestCase):
    def test_pacote_so_tem_scripts_bastiao(self):
        caminhos = ['/'.join(r['path']) for r in PACOTE.entries]
        self.assertEqual(len(caminhos), 23)
        for r in PACOTE.entries:
            raiz = 2 if r['path'][0] == 'StarterPlayer' else 1
            self.assertTrue(r['path'][raiz].startswith('Bastiao'), r['path'])
        classes = sorted(r['cls'] for r in PACOTE.entries)
        self.assertEqual(classes.count('Script'), 1)
        self.assertEqual(classes.count('LocalScript'), 1)
        self.assertIn('ServerScriptService/BastiaoServidor/Cenario', caminhos)
        self.assertIn('StarterPlayer/StarterPlayerScripts/BastiaoCliente/Interface', caminhos)
        for novo in ('ReplicatedStorage/BastiaoCompartilhado/Audio', 'ServerScriptService/BastiaoServidor/Preferencias',
                     'StarterPlayer/StarterPlayerScripts/BastiaoCliente/Som', 'StarterPlayer/StarterPlayerScripts/BastiaoCliente/Idioma',
                     'StarterPlayer/StarterPlayerScripts/BastiaoCliente/Telas'):
            self.assertIn(novo, caminhos)
        self.assertEqual(PACOTE.name, 'BASTIAO-ETAPA-2')

    def test_validate_recusa_fora_do_bastiao_e_filho_antes_do_pai(self):
        ruins = [
            [dict(path=['StarterPlayer', 'StarterPlayerScripts', 'Sector7Client'], cls='LocalScript', source='x')],
            [dict(path=['Workspace', 'BastiaoMapa'], cls='ModuleScript', source='x')],
            [dict(path=['ServerScriptService', 'Sector7', 'Server'], cls='Script', source='x')],
            [dict(path=['ServerScriptService', 'BastiaoServidor', 'Filho'], cls='ModuleScript', source='x'),
             dict(path=['ServerScriptService', 'BastiaoServidor'], cls='Script', source='x')],
            [dict(path=['ReplicatedStorage', 'BastiaoX'], cls='Folder', source='x')],
        ]
        for linhas in ruins:
            with self.subTest(linhas=linhas), self.assertRaises(Failure):
                validate(linhas)

    def test_manifesto_adulterado_e_recusado(self):
        arquivos = dict(ARQUIVOS)
        arquivos['teste_nuvem.luau'] = arquivos['teste_nuvem.luau'] + b'\n-- mexido'
        with self.assertRaisesRegex(Failure, 'Integridade'):
            Package(arquivos)

    def test_teste_nativo_dentro_do_limite_com_destino(self):
        script = PACOTE.scripts(5)[0]
        self.assertLess(len(script.encode()), 200000)
        self.assertIn('"package":"BASTIAO-ETAPA-2"', script)
        self.assertIn('"place":89520940302906', script)
        self.assertIn('"universe":10776462844', script)
        self.assertIn('Sector7World', script)


class PatchTests(unittest.TestCase):
    def test_patch_xml_so_acrescenta_e_e_idempotente(self):
        raw = fixture()
        pronto, mudou = patch(raw)
        self.assertTrue(mudou)
        self.assertEqual(patch(pronto), (pronto, False))
        a, b = ET.fromstring(raw), ET.fromstring(pronto)
        for it in a.iter('Item'):
            ref = it.get('referent')
            igual = b.find(f".//Item[@referent='{ref}']")
            self.assertIsNotNone(igual, ref)
            self.assertEqual(ET.tostring(it.find('Properties')), ET.tostring(igual.find('Properties')))
        novos = [it for it in b.iter('Item') if it.get('referent').startswith('BASTIAO_')]
        self.assertEqual(len(novos), N_SCRIPTS)

    def test_etapa1_instalada_e_atualizada_e_mexida_bloqueia(self):
        e1 = pacote_etapa1()
        self.assertEqual(e1.name, 'BASTIAO-ETAPA-1')
        com_e1, mudou = e1.patch(fixture())
        self.assertTrue(mudou)
        pronto, mudou = patch(com_e1)
        self.assertTrue(mudou)
        self.assertEqual(patch(pronto), (pronto, False))
        fontes = {tuple(r['path']): r['source'] for r in PACOTE.entries}
        raiz = ET.fromstring(pronto)
        def achar(caminho):
            at = raiz
            for nome in caminho:
                at = next(i for i in at.findall('Item') if i.findtext("Properties/string[@name='Name']") == nome)
            return at.findtext("Properties/ProtectedString[@name='Source']")
        for caminho, fonte in fontes.items():
            self.assertEqual(achar(caminho), fonte, '/'.join(caminho))
        self.assertEqual(achar(('ServerScriptService', 'Sector7', 'Server')), 'print("sector7")')
        # alguém mexeu num script da Etapa 1 no Studio: nada é trocado
        mexido = com_e1.replace(b'PROJETO BASTI\xc3\x83O :: Cenario', b'PROJETO BASTI\xc3\x83O :: Cenario (mexido)', 1)
        self.assertNotEqual(mexido, com_e1)
        with self.assertRaisesRegex(Failure, 'desconhecida'):
            patch(mexido)

    def test_modulo_audio_gerado_e_trocado_mas_outro_bloqueia(self):
        if PACOTE.audio is None:
            self.skipTest('pacote sem sons')
        pronto, _ = patch(fixture())
        p2 = novo_pacote()
        ids = {n: 900000 + i for i, n in enumerate(sorted(PACOTE.audio['sprites']))}
        p2.usar_ids(ids)
        com_ids, mudou = p2.patch(pronto)
        self.assertTrue(mudou)
        self.assertIn(b'= 900000', com_ids)
        # voltar para IDs 0 também é aceito (o módulo é nosso, gerado)
        self.assertTrue(patch(com_ids)[1])
        # um módulo Audio que não foi gerado pelo instalador bloqueia
        estranho = pronto.replace(midia.CABECALHO.encode(), b'-- outro audio\n', 1)
        self.assertNotEqual(estranho, pronto)
        with self.assertRaisesRegex(Failure, 'desconhecida'):
            p2.patch(estranho)

    def test_mesmo_nome_com_fonte_desconhecida_bloqueia(self):
        pronto, _ = patch(fixture())
        alterado = pronto.replace(b'PROJETO BASTI\xc3\x83O :: Zonas', b'PROJETO BASTI\xc3\x83O :: Zonas (editado a mao)', 1)
        self.assertNotEqual(alterado, pronto)
        with self.assertRaisesRegex(Failure, 'desconhecida'):
            patch(alterado)

    @unittest.skipUnless(PLACE.is_file(), 'place real indisponível')
    def test_place_real_binario_preserva_tudo(self):
        raw = PLACE.read_bytes()
        self.assertTrue(raw.startswith(b'<roblox!'))
        pronto, mudou = patch(raw)
        self.assertTrue(mudou)
        self.assertEqual(patch(pronto), (pronto, False))
        if not LUNE:
            self.skipTest('lune indisponível para a conferência independente')
        with tempfile.TemporaryDirectory() as d:
            saida, fontes = Path(d) / 'patcheado.rbxl', Path(d) / 'sources.json'
            saida.write_bytes(pronto)
            fontes.write_bytes(ARQUIVOS['sources.json'])
            r = subprocess.run([LUNE, 'run', str(RAIZ / 'ferramentas' / 'conferir_patch.luau'), str(PLACE), str(saida), str(fontes)],
                               cwd=REPO, capture_output=True, text=True, timeout=600)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn('nenhuma instância original alterada', r.stdout)


class ProtocoloTests(unittest.TestCase):
    def rt(self, d):
        return Runtime(Path(d), 2, PACOTE.digest, patch, PACOTE.scripts)

    def test_instalar_pede_confirmacao_uma_vez_e_publica(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            with trocar('builtins.input', return_value='PUBLICAR ETAPA2') as perguntou:
                recibo = r.install(c)
            self.assertEqual(perguntou.call_count, 1)
            self.assertEqual(recibo['status'], 'VERIFIED')
            self.assertEqual(c.writes, ['Saved', 'Published'])
            self.assertEqual(len(c.tarefas), 1)
            self.assertIn('BASTIAO-ETAPA-2', c.tarefas[0])

    def test_confirmacao_errada_nao_publica_e_guarda_o_teste(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            for errado in ('sim', 'PUBLICAR AJUSTE19', 'PUBLICAR ETAPA1'):
                with trocar('builtins.input', return_value=errado), self.assertRaises(Failure):
                    r.install(c) if errado == 'sim' else r.publish(c)
            self.assertEqual(c.writes, ['Saved'])
            self.assertTrue((r.state / 'test.json').is_file())
            with trocar('builtins.input', return_value='PUBLICAR ETAPA2'):
                self.assertEqual(r.publish(c)['status'], 'VERIFIED')
            self.assertEqual(c.writes, ['Saved', 'Published'])

    def test_teste_reprovado_bloqueia_sem_perguntar(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            c.report = {'package': 'BASTIAO-ETAPA-2', 'passed': False, 'erros': ['Sector7World ausente']}
            with trocar('builtins.input', side_effect=AssertionError('não pode perguntar')), self.assertRaises(Failure) as e:
                r.install(c)
            self.assertIn('Publicacao bloqueada', str(e.exception))
            self.assertIn('Sector7World ausente', str(e.exception))
            self.assertEqual(c.writes, ['Saved'])
            self.assertFalse((r.state / 'test.json').exists())

    def test_resposta_perdida_resume_sem_repetir_envio(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            c.fail_write = True
            with self.assertRaises(Failure):
                r.test(c)
            self.assertIsNotNone(r.pending())
            c.fail_write = False
            r.resume(c)
            self.assertIsNone(r.pending())
            r.test(c)
            self.assertEqual(c.writes, ['Saved'])

    def test_envio_pendente_de_outra_etapa_e_preservado(self):
        with tempfile.TemporaryDirectory() as d:
            r = self.rt(d)
            r.active.write_text(json.dumps({'package': 'BASTIAO-ETAPA-1', 'intent': 'manter'}))
            with self.assertRaises(Failure) as e:
                r.pending()
            self.assertIn('BASTIAO_ETAPA1.py resume', str(e.exception))
            self.assertEqual(json.loads(r.active.read_text())['intent'], 'manter')


class ArquivoUnicoTests(unittest.TestCase):
    def test_instalador_offline_e_adulteracao(self):
        with tempfile.TemporaryDirectory() as d:
            alvo = gerar_etapa2.montar(Path(d) / 'BASTIAO_ETAPA2.py')
            r = subprocess.run([sys.executable, str(alvo), 'testar'], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=120)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn('Integridade offline OK: ETAPA2, %d scripts novos' % N_SCRIPTS, r.stdout)
            self.assertNotIn('Chave', r.stdout + r.stderr)
            texto = alvo.read_text()
            inicio = texto.index("PAYLOAD = b'") + len("PAYLOAD = b'") + 200
            ruim = texto[:inicio] + ('A' if texto[inicio] != 'A' else 'B') + texto[inicio + 1:]
            adulterado = Path(d) / 'adulterado.py'
            adulterado.write_text(ruim)
            r2 = subprocess.run([sys.executable, str(adulterado), 'testar'], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=120)
            self.assertNotEqual(r2.returncode, 0)
            self.assertIn('corrompido', (r2.stdout + r2.stderr).lower())


class FakeAssets:
    """Fronteira de envio de sons do Roblox: conta envios, responde operações, moderação e permissões."""
    def __init__(self, recusar=None, pronto_depois=1, estado='Approved'):
        self.posts, self.patches, self.ops = [], [], {}
        self.tentativas = 0
        self.recusar, self.pronto_depois, self.estado = recusar, pronto_depois, estado

    def request(self, path, body=None, method=None, raw=None, mime='application/json'):
        if path == '/assets/v1/assets' and method == 'POST':
            self.tentativas += 1
            if self.recusar:
                raise Failure('HTTP %d em %s' % (self.recusar, path), self.recusar)
            assert mime.startswith('multipart/form-data; boundary=')
            pedido = json.loads(raw.split(b'\r\n\r\n', 1)[1].split(b'\r\n', 1)[0])
            self.posts.append(pedido)
            op = 'op%d' % len(self.posts)
            self.ops[op] = {'n': 0, 'id': str(7000 + len(self.posts))}
            return {'path': 'operations/' + op, 'operationId': op}
        if path.startswith('/assets/v1/operations/'):
            op = self.ops[path.rsplit('/', 1)[1]]
            op['n'] += 1
            if op['n'] < self.pronto_depois:
                return {'done': False}
            return {'done': True, 'response': {'assetId': op['id'], 'moderationResult': {'moderationState': self.estado}}}
        if path.startswith('/assets/v1/assets/') and 'readMask=moderationResult' in path:
            return {'moderationResult': {'moderationState': self.estado}}
        if path == '/asset-permissions-api/v1/assets/permissions' and method == 'PATCH':
            self.patches.append(body)
            return {'successAssetIds': [r['assetId'] for r in body['requests']]}
        raise AssertionError('pedido inesperado: ' + path)


@unittest.skipIf(PACOTE.audio is None, 'pacote sem sons')
class SonsTests(unittest.TestCase):
    def midia(self, d, **kw):
        op = dict(espera=0, limite=5, dono=lambda u: ('User', '123'), perguntar=lambda m: '', dormir=lambda s: None)
        op.update(kw)
        return midia.Midia(Path(d), PACOTE.audio, ARQUIVOS, **op)

    def test_envia_uma_vez_e_reaproveita(self):
        n = len(PACOTE.audio['sprites'])
        with tempfile.TemporaryDirectory() as d:
            c = FakeAssets()
            ids = self.midia(d).preparar(c)
            presentes = [k for k in midia.SPRITES if k in PACOTE.audio['sprites']]
            self.assertTrue(all(ids[k] > 0 for k in presentes), ids)
            self.assertTrue(all(ids[k] == 0 for k in midia.SPRITES if k not in presentes))
            self.assertEqual(len(c.posts), n)
            self.assertTrue(all(p['creationContext']['creator'] == {'userId': '123'} and p['assetType'] == 'Audio' for p in c.posts))
            self.assertEqual(len(c.patches), n)
            de_novo = self.midia(d, dono=lambda u: self.fail('não precisa do dono')).preparar(c)
            self.assertEqual(de_novo, ids)
            self.assertEqual(len(c.posts), n, 'rodar de novo não reenvia')
            self.assertEqual(len(c.patches), n, 'liberação também fica no recibo')
            recibos = json.loads((Path(d) / 'midia-recibos.json').read_text())
            self.assertEqual(len(recibos['arquivos']), n)

    def test_chave_sem_permissao_nao_trava_e_nao_insiste(self):
        with tempfile.TemporaryDirectory() as d:
            c = FakeAssets(recusar=403)
            ids = self.midia(d).preparar(c)
            self.assertTrue(all(v == 0 for v in ids.values()))
            self.assertEqual(c.tentativas, 1, 'depois de um 403 não tenta enviar os outros')

    def test_ainda_processando_termina_na_proxima_sem_reenviar(self):
        with tempfile.TemporaryDirectory() as d:
            c = FakeAssets(pronto_depois=10 ** 9)
            ids = self.midia(d, limite=0.02).preparar(c)
            self.assertTrue(all(v == 0 for v in ids.values()))
            enviados = len(c.posts)
            self.assertGreater(enviados, 0)
            c.pronto_depois = 0
            ids = self.midia(d).preparar(c)
            self.assertTrue(any(v > 0 for v in ids.values()))
            self.assertEqual(len(c.posts), enviados)

    def test_recusado_na_moderacao_fica_sem_som(self):
        with tempfile.TemporaryDirectory() as d:
            ids = self.midia(d).preparar(FakeAssets(estado='Rejected'))
            self.assertTrue(all(v == 0 for v in ids.values()))

    def test_sem_dono_pula_sem_enviar(self):
        with tempfile.TemporaryDirectory() as d:
            c = FakeAssets()
            ids = self.midia(d, dono=lambda u: None, perguntar=lambda m: '').preparar(c)
            self.assertTrue(all(v == 0 for v in ids.values()))
            self.assertEqual(c.tentativas, 0)
            c2 = FakeAssets()
            ids = self.midia(d, dono=lambda u: None, perguntar=lambda m: '4242').preparar(c2)
            self.assertTrue(all(p['creationContext']['creator'] == {'userId': '4242'} for p in c2.posts))

    def test_ids_salvos_presos_a_entrega(self):
        with tempfile.TemporaryDirectory() as d:
            ids = {'voz_pt': 11, 'efeitos': 12}
            midia.salvar_ids(Path(d), PACOTE.digest, ids)
            self.assertEqual(midia.ids_salvos(Path(d), PACOTE.digest), ids)
            self.assertEqual(midia.ids_salvos(Path(d), 'outra-entrega'), {})

    def test_modulo_audio_igual_ao_do_src_e_ids_mudam_o_teste(self):
        fonte = (RAIZ / 'src' / 'ReplicatedStorage' / 'BastiaoCompartilhado' / 'Audio.luau').read_text(encoding='utf-8')
        self.assertEqual(midia.fonte_audio(PACOTE.audio, {}), fonte)
        p = novo_pacote()
        antes = p.scripts(3)[0]
        p.usar_ids({'efeitos': 555})
        self.assertNotEqual(p.scripts(3)[0], antes)
        self.assertIn('efeitos = 555', p._linha_audio()['source'])
        for ruim in ({'efeitos': -1}, {'efeitos': True}, {'outro': 1}):
            with self.subTest(ruim=ruim), self.assertRaises(Failure):
                midia.fonte_audio(PACOTE.audio, ruim)
        torto = json.loads(json.dumps(PACOTE.audio))
        nome = next(iter(torto['sfx']))
        seg = torto['sfx'][nome]
        (seg[0] if isinstance(seg[0], list) else seg)[0] = torto['sprites']['efeitos']['segundos'] + 1
        with self.assertRaisesRegex(Failure, 'fora do arquivo'):
            midia.fonte_audio(torto, {})


if __name__ == '__main__':
    unittest.main()
