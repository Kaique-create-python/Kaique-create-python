"""Catch sprite truncation and foreign-source acceptance during stage 3 updates."""
from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import sys
import unittest
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from instalador.codec import Failure
from instalador.midia import CABECALHO, fonte_audio, validar_dados
from instalador.patcher import patch_place


def audio_data():
    return {
        "versao": 3,
        "sprites": {
            "voz_pt": {"arquivo": "audio/voz_pt.ogg", "segundos": 10},
            "efeitos": {"arquivo": "audio/efeitos.ogg", "segundos": 5},
            "voices_atlas": {"arquivo": "audio/voices_atlas.ogg", "segundos": 8},
        },
        "vozes": {"pt": {"pavel_cafe": [0.05, 3.79], "pavel_novo": [1, 2, "voices_atlas"]}},
        "sfx": {"toques_longe": [0.05, 4.5]},
        "loops": {"ambiente": [3, 2, "voices_atlas"]},
        "duracoes": {"pavel_cafe": 3.79, "pavel_novo": 2},
    }


def place(source):
    return ('<roblox version="4"><Item class="ReplicatedStorage"><Properties>'
            '<string name="Name">ReplicatedStorage</string></Properties>'
            '<Item class="ModuleScript"><Properties><string name="Name">BastiaoCompartilhado</string>'
            '<ProtectedString name="Source">return {}</ProtectedString></Properties>'
            '<Item class="ModuleScript"><Properties><string name="Name">Audio</string>'
            '<ProtectedString name="Source">' + escape(source) + '</ProtectedString>'
            '</Properties></Item></Item></Item></roblox>').encode()


class DynamicAudioTests(unittest.TestCase):
    def test_generated_audio_keeps_old_clip_and_new_sprite(self):
        try:
            source = fonte_audio(audio_data(), {"voz_pt": 123, "efeitos": 124, "voices_atlas": 125})
        except Failure as exc:
            self.fail("Dynamic atlas sprites must generate playable source: " + str(exc))
        self.assertIn('pavel_cafe = { 0.05, 3.79 }', source)
        self.assertIn('pavel_novo = { 1, 2, "voices_atlas" }', source)
        self.assertIn('voices_atlas = 125', source)

    def test_segment_cannot_refer_to_missing_sprite_or_cross_its_end(self):
        for segment in ([0, 1, "unknown"], [7, 2, "voices_atlas"]):
            data = audio_data()
            data["vozes"]["pt"]["pavel_novo"] = segment
            with self.assertRaises(Failure):
                validar_dados(data)

    def test_dynamic_sprite_cannot_escape_payload_directory(self):
        data = audio_data()
        data["sprites"]["voices_atlas"]["arquivo"] = "../secret.ogg"
        with self.assertRaises(Failure):
            validar_dados(data)


class StrictGeneratedSourceTests(unittest.TestCase):
    def rows(self):
        data = audio_data()
        return [
            {"path": ["ReplicatedStorage", "BastiaoCompartilhado"], "cls": "ModuleScript", "source": "return {}"},
            {"path": ["ReplicatedStorage", "BastiaoCompartilhado", "Audio"], "cls": "ModuleScript",
             "source": fonte_audio(data, {"voz_pt": 700, "efeitos": 701, "voices_atlas": 702}),
             "generatedAudio": [data], "gerado": CABECALHO},
        ]

    def test_known_generated_audio_can_change_ids_and_update_idempotently(self):
        source = fonte_audio(audio_data(), {"voz_pt": 123, "efeitos": 124, "voices_atlas": 125})
        result, changed = patch_place(place(source), self.rows())
        self.assertTrue(changed)
        self.assertEqual(patch_place(result, self.rows()), (result, False))

    def test_header_does_not_authorize_foreign_code(self):
        rows = self.rows()
        source = fonte_audio(audio_data(), {"voz_pt": 123, "efeitos": 124, "voices_atlas": 125})
        with self.assertRaises(Failure):
            patch_place(place(source + "error('foreign code')\n"), rows)

    def test_known_hashes_still_allow_previous_stage_source(self):
        rows = self.rows()
        rows[-1]["known"] = [hashlib.sha256(b"return {previous=true}").hexdigest()]
        self.assertTrue(patch_place(place("return {previous=true}"), rows)[1])


if __name__ == "__main__":
    unittest.main()
