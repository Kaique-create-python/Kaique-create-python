import io
import contextlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from installer14.runtime import Runtime, read, save
from installer14.codec import Failure
from test_installer14 import FakeCloud, patch_place


class SameVersionCloud(FakeCloud):
    mark_published = True
    unknown_reply = False

    def request(self, path, **kwargs):
        if path.endswith('versionType=Published'):
            assert kwargs['method'] == 'POST'
            version = max(self.blobs)
            assert self.blobs[version] == kwargs['raw']
            self.writes.append('Published')
            if self.mark_published:
                next(r for r in self.rows if r['version'] == version)['isPublished'] = True
            return {} if self.unknown_reply else {'versionNumber': version}
        return super().request(path, **kwargs)


class SameVersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.rt = Runtime(Path(self.temp.name), 14, 'digest', patch_place, lambda *args: ['verify'])
        self.cloud = SameVersionCloud()
        with contextlib.redirect_stdout(io.StringIO()):
            self.proof = self.rt.test(self.cloud)

    def tearDown(self):
        self.temp.cleanup()

    def uncertain(self):
        self.cloud.unknown_reply = True
        with patch('builtins.input', return_value='PUBLICAR AJUSTE14'), self.assertRaises(Failure):
            self.rt.publish(self.cloud)
        return read(self.rt.active)

    def test_same_version_ack_requires_flag_and_hash_then_verifies(self):
        with patch('builtins.input', return_value='PUBLICAR AJUSTE14'):
            receipt = self.rt.publish(self.cloud)
        self.assertEqual(receipt['version'], self.proof['base'])
        self.assertEqual(receipt['status'], 'VERIFIED')
        self.assertEqual(self.cloud.writes, ['Saved', 'Published'])
        self.assertFalse(self.rt.active.exists())

    def test_uncertain_post_recovers_same_version_get_only(self):
        self.uncertain()
        writes = list(self.cloud.writes)
        receipt = self.rt.resume(self.cloud)
        self.assertEqual(receipt['status'], 'VERIFIED')
        self.assertEqual(self.cloud.writes, writes)

    def test_saved_flag_cannot_be_declared_published_even_with_exact_bytes(self):
        self.cloud.mark_published = False
        before = self.uncertain()
        with self.assertRaises(Failure) as caught:
            self.rt.resume(self.cloud)
        self.assertIn('ultima_publicada', str(caught.exception))
        self.assertEqual(read(self.rt.active), before)

    def test_published_flag_cannot_override_wrong_bytes(self):
        before = self.uncertain()
        self.cloud.blobs[self.proof['base']] += b'different'
        with self.assertRaises(Failure):
            self.rt.resume(self.cloud)
        self.assertEqual(read(self.rt.active), before)

    def test_later_save_prevents_confirming_older_base(self):
        before = self.uncertain()
        version = self.proof['base'] + 1
        self.cloud.blobs[version] = self.cloud.blobs[self.proof['base']]
        self.cloud.rows.append({'version': version, 'isPublished': False})
        with self.assertRaises(Failure):
            self.rt.resume(self.cloud)
        self.assertEqual(read(self.rt.active), before)

    def test_saved_mode_still_rejects_same_version_receipt(self):
        entry = self.uncertain()
        entry.update(mode='Saved', version=entry['base'])
        save(self.rt.active, entry)
        with self.assertRaisesRegex(Failure, 'Recibo incompleto'):
            self.rt.resume(self.cloud)


if __name__ == '__main__':
    unittest.main()
