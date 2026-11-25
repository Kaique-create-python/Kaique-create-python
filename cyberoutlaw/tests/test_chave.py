import unittest

from install.chave import clean_key, fingerprint

KEY = "Ab3+/=" * 160  # 960 caracteres no alfabeto das chaves


class CleanKeyTests(unittest.TestCase):
    def test_plain_key_is_untouched(self):
        self.assertEqual(clean_key(KEY), (KEY, []))

    def test_bracketed_paste_markers_are_removed(self):
        for raw in ("\x1b[200~" + KEY + "\x1b[201~", "[200~" + KEY + "[201~"):
            key, notes = clean_key(raw)
            self.assertEqual(key, KEY)
            self.assertTrue(notes)

    def test_spaces_newlines_quotes_and_label(self):
        key, _ = clean_key(' x-api-key: "' + KEY[:300] + "\n" + KEY[300:] + '" \r\n')
        self.assertEqual(key, KEY)

    def test_odd_characters_are_reported(self):
        _, notes = clean_key(KEY + "§")
        self.assertEqual(notes, [])  # não ASCII sai sem aviso
        _, notes = clean_key(KEY + "#")
        self.assertIn("#", notes[-1])

    def test_fingerprint_never_shows_the_whole_key(self):
        text = fingerprint(KEY)
        self.assertIn("960 caracteres", text)
        self.assertNotIn(KEY[4:-4], text)


if __name__ == "__main__":
    unittest.main()
