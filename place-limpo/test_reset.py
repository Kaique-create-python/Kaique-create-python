"""Verifica a limpeza com transporte simulado e arquivos locais reais."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("reset", ROOT / "LIMPAR_PLACE_ROBLOX.py")
reset = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reset)


class CloudFixture:
    def __init__(self):
        self.posts = []
        self.versions = {1: b"original publicado", 2: b"original salvo"}
        self.published = 1

    def history(self):
        return max(self.versions), [dict(version=v, isPublished=v == self.published) for v in self.versions]

    def validate_destination(self):
        pass

    def download(self, version, path):
        raw = self.versions[version]
        path.write_bytes(raw)
        return raw

    def request(self, path, method, raw, mime):
        self.posts.append((path, method, mime))
        self.versions[3] = raw
        self.published = 3
        return {"versionNumber": 3}


class ResetTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        reset.STATE = Path(temporary.name)
        output = contextlib.redirect_stdout(io.StringIO())
        output.__enter__()
        self.addCleanup(output.__exit__, None, None, None)
        self.cloud = CloudFixture()

    def test_confirmation_and_backup_are_required_before_the_single_place_write(self):
        def confirm(prompt):
            self.assertFalse(self.cloud.posts)
            originals = sorted(reset.STATE.glob('Backup*'))
            self.assertEqual([p.read_bytes() for p in originals], [b'original publicado', b'original salvo'])
            self.assertIn('122033314086516', prompt)
            return 'LIMPAR 122033314086516'
        with patch('builtins.input', side_effect=confirm):
            reset.limpar(self.cloud)
        self.assertEqual(self.cloud.posts, [('/universes/v1/10774214423/places/122033314086516/versions?versionType=Published', 'POST', 'application/octet-stream')])
        self.assertEqual(self.cloud.versions[3], (ROOT / 'Baseplate.rbxl').read_bytes())
        self.assertTrue(reset.read(reset.STATE / 'Publicacao_v3.json')['verificada'])
        self.assertFalse((reset.STATE / 'envio-pendente.json').exists())
        reset.limpar(self.cloud)
        self.assertEqual(len(self.cloud.posts), 1)

    def test_cancel_does_not_publish(self):
        with patch('builtins.input', return_value='não'):
            reset.limpar(self.cloud)
        self.assertFalse(self.cloud.posts)

    def test_changed_place_blocks_publication(self):
        def confirm(_):
            self.cloud.versions[3] = b'edicao recente'
            return 'LIMPAR 122033314086516'
        with patch('builtins.input', side_effect=confirm), self.assertRaises(reset.Failure):
            reset.limpar(self.cloud)
        self.assertFalse(self.cloud.posts)

    def test_timeout_can_be_verified_without_sending_again(self):
        normal = self.cloud.request
        def interrupted(*args, **kwargs):
            normal(*args, **kwargs)
            raise reset.Failure('Tempo de resposta excedido.')
        with patch('builtins.input', return_value='LIMPAR 122033314086516'), patch.object(self.cloud, 'request', side_effect=interrupted):
            with self.assertRaises(reset.Failure):
                reset.limpar(self.cloud)
        with self.assertRaises(reset.Failure):
            reset.limpar(self.cloud)
        reset.conferir_publicacao(self.cloud, reset.read(reset.STATE / 'envio-pendente.json'))
        self.assertEqual(len(self.cloud.posts), 1)


if __name__ == '__main__':
    unittest.main()
