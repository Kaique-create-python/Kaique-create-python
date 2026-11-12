"""A entrada documentada deve encaminhar AJ14 ao patch, sem reconstruir Morioh."""
import importlib.util
from pathlib import Path
import sys
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / 'tools/gerar_instalador.py'
spec = importlib.util.spec_from_file_location('legacy_builder_entry', path)
legacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legacy)


class EntryTests(TestCase):
    def test_adjust14_uses_source_patch_builder(self):
        called = []
        target = SimpleNamespace(main=lambda argv: called.append(argv))
        with patch.dict(sys.modules, {'gerar_ajuste14': target}), patch.object(sys, 'argv', [str(path), 'AJUSTE-14']), patch.object(legacy.subprocess, 'run', side_effect=AssertionError('gerador antigo reconstruiu o mapa')):
            legacy.main()
        self.assertEqual(called, [[]])
