import contextlib
import io
import json
import sys
import tempfile
import unittest
import importlib.util
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from installer14.runtime import Runtime, TARGET, read
from installer14.codec import Failure
from test_installer14 import FakeCloud, patch_place


class DiagnosticTests(unittest.TestCase):
    def test_failed_report_explains_reason_and_saves_without_publish_or_secret(self):
        with tempfile.TemporaryDirectory() as name:
            rt = Runtime(Path(name), 14, 'digest', patch_place, lambda *args: ['verify'])
            cloud = FakeCloud()
            cloud.key = 'SECRET-FIXTURE-ONLY'
            report = {'package': rt.package, 'passed': False,
                      'erros': ['Nao conseguiu ler Source: SECRET-FIXTURE-ONLY'],
                      'avisos': ['textura indisponivel'], 'info': {'fonts': 0}}
            output = io.StringIO()
            with patch.object(cloud, 'task', return_value=report), contextlib.redirect_stdout(output), self.assertRaises(Failure) as caught:
                rt.test(cloud)
            message = output.getvalue() + str(caught.exception)
            self.assertIn('Nao conseguiu ler Source', message)
            self.assertNotIn(cloud.key, message)
            saved = read(rt.state / 'ultimo-teste.json')
            self.assertEqual(saved['version'], 11)
            self.assertFalse(saved['report']['passed'])
            self.assertNotIn(cloud.key, json.dumps(saved))
            self.assertEqual(cloud.writes, ['Saved'])
            self.assertFalse((rt.state / 'test.json').exists())

    def helper(self):
        path = Path(__file__).resolve().parents[1] / 'dist/BIZARRE_DIAGNOSTICO14.py'
        spec = importlib.util.spec_from_file_location('diag14', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_existing_task_is_get_only_and_secret_redacted(self):
        helper = self.helper()
        from test_installer14_boundaries import Opener, Response
        report = {'package': 'BIZARRE-AJUSTE-14', 'passed': False, 'erros': ['causa SECRET-TEST-ONLY']}
        for value in (report, json.dumps(report)):
            with self.subTest(value=type(value)):
                opener = Opener(Response(json.dumps({'state': 'COMPLETE', 'output': {'results': [value]}}).encode()))
                output = helper.consultar('SECRET-TEST-ONLY', opener)
                self.assertIn('causa [OCULTA]', output)
                self.assertNotIn('SECRET-TEST-ONLY', output)
                self.assertEqual(len(opener.requests), 1)
                request = opener.requests[0]
                self.assertEqual(request.get_method(), 'GET')
                self.assertEqual(request.full_url, helper.URL)
                self.assertIsNone(request.data)

    def test_helper_rejects_redirect_instead_of_forwarding_key(self):
        helper = self.helper()
        self.assertIsNone(helper.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://example.org'))

    def test_helper_refuses_key_echo_terminal(self):
        helper = self.helper()
        import getpass, warnings
        def echo(*args):
            warnings.warn('cannot hide', getpass.GetPassWarning)
            return 'DO-NOT-READ'
        with patch.object(helper.getpass, 'getpass', side_effect=echo), patch.object(helper, 'consultar') as consult:
            with self.assertRaises(SystemExit):
                helper.main()
            consult.assert_not_called()


if __name__ == '__main__':
    unittest.main()
