"""PROJETO BASTIAO :: testes do instalador da Etapa 1.

O patch so acrescenta scripts Bastiao* (mapa, HUD e scripts Sector7 ficam iguais), e o protocolo
testar -> PUBLICAR ETAPA1 -> resume nunca repete envio. So a fronteira com o Roblox e simulada.
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
import gerar_etapa1  # noqa: E402

PLACE = Path(os.environ.get('BASTIAO_PLACE', '/tmp/claude-0/-home-user/8073e9e5-493c-555e-858a-2e1de54d2eed/scratchpad/bastiao/place/place_original.rbxl'))
LUNE = shutil.which('lune')
ARQUIVOS, PACOTE = gerar_etapa1.coletar()


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
        self.report = {'package': 'BASTIAO-ETAPA-1', 'passed': True}
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
        self.assertEqual(len(caminhos), 18)
        for r in PACOTE.entries:
            raiz = 2 if r['path'][0] == 'StarterPlayer' else 1
            self.assertTrue(r['path'][raiz].startswith('Bastiao'), r['path'])
        classes = sorted(r['cls'] for r in PACOTE.entries)
        self.assertEqual(classes.count('Script'), 1)
        self.assertEqual(classes.count('LocalScript'), 1)
        self.assertIn('ServerScriptService/BastiaoServidor/Cenario', caminhos)
        self.assertIn('StarterPlayer/StarterPlayerScripts/BastiaoCliente/Interface', caminhos)
        self.assertEqual(PACOTE.name, 'BASTIAO-ETAPA-1')

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
        self.assertIn('"package":"BASTIAO-ETAPA-1"', script)
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
        self.assertEqual(len(novos), 18)

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
        return Runtime(Path(d), 1, PACOTE.digest, patch, PACOTE.scripts)

    def test_instalar_pede_confirmacao_uma_vez_e_publica(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            with trocar('builtins.input', return_value='PUBLICAR ETAPA1') as perguntou:
                recibo = r.install(c)
            self.assertEqual(perguntou.call_count, 1)
            self.assertEqual(recibo['status'], 'VERIFIED')
            self.assertEqual(c.writes, ['Saved', 'Published'])
            self.assertEqual(len(c.tarefas), 1)
            self.assertIn('BASTIAO-ETAPA-1', c.tarefas[0])

    def test_confirmacao_errada_nao_publica_e_guarda_o_teste(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            for errado in ('sim', 'PUBLICAR AJUSTE19', 'PUBLICAR ETAPA2'):
                with trocar('builtins.input', return_value=errado), self.assertRaises(Failure):
                    r.install(c) if errado == 'sim' else r.publish(c)
            self.assertEqual(c.writes, ['Saved'])
            self.assertTrue((r.state / 'test.json').is_file())
            with trocar('builtins.input', return_value='PUBLICAR ETAPA1'):
                self.assertEqual(r.publish(c)['status'], 'VERIFIED')
            self.assertEqual(c.writes, ['Saved', 'Published'])

    def test_teste_reprovado_bloqueia_sem_perguntar(self):
        with tempfile.TemporaryDirectory() as d:
            r, c = self.rt(d), FakeCloud()
            c.report = {'package': 'BASTIAO-ETAPA-1', 'passed': False, 'erros': ['Sector7World ausente']}
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
            r.active.write_text(json.dumps({'package': 'BASTIAO-ETAPA-2', 'intent': 'manter'}))
            with self.assertRaises(Failure) as e:
                r.pending()
            self.assertIn('BASTIAO_ETAPA2.py resume', str(e.exception))
            self.assertEqual(json.loads(r.active.read_text())['intent'], 'manter')


class ArquivoUnicoTests(unittest.TestCase):
    def test_instalador_offline_e_adulteracao(self):
        with tempfile.TemporaryDirectory() as d:
            alvo = gerar_etapa1.montar(Path(d) / 'BASTIAO_ETAPA1.py')
            r = subprocess.run([sys.executable, str(alvo), 'testar'], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=120)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn('Integridade offline OK: ETAPA1, 18 scripts novos', r.stdout)
            self.assertNotIn('Chave', r.stdout + r.stderr)
            texto = alvo.read_text()
            inicio = texto.index("PAYLOAD = b'") + len("PAYLOAD = b'") + 200
            ruim = texto[:inicio] + ('A' if texto[inicio] != 'A' else 'B') + texto[inicio + 1:]
            adulterado = Path(d) / 'adulterado.py'
            adulterado.write_text(ruim)
            r2 = subprocess.run([sys.executable, str(adulterado), 'testar'], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=120)
            self.assertNotEqual(r2.returncode, 0)
            self.assertIn('corrompido', (r2.stdout + r2.stderr).lower())


if __name__ == '__main__':
    unittest.main()
