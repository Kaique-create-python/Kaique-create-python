import unittest
from xml.etree import ElementTree

from install.codec import Binary, Failure, pack32, pstring
from install.patcher import CLIENT_HEADER, SERVER_HEADER, patch_place
from test_cyber_installer import SOURCE, _chunk, make_binary, make_binary_with_lighting


CITY_NAME = "CyberOutlawCity"
CITY = {CITY_NAME: f"{SERVER_HEADER}{CITY_NAME}\nreturn\n"}
DISABLED = b'<bool name="StreamingEnabled">false</bool>'
XML_SETTINGS = {
    "StreamingEnabled": ("bool", "true"),
    "StreamingMinRadius": ("int", "180"),
    "StreamingTargetRadius": ("int", "640"),
}
BINARY_SETTINGS = {
    "StreamingEnabled": (0x02, b"\x01"),
    "StreamingMinRadius": (0x03, b"\x00\x00\x01\x68"),
    "StreamingTargetRadius": (0x03, b"\x00\x00\x05\x00"),
}


def _place_xml(workspace):
    return b'<roblox version="4">' + workspace + b'</roblox>'


def _with_scripts(raw):
    # Install the scripts and avatar settings separately to isolate the native streaming edit.
    with_r6, _ = patch_place(raw, SOURCE, force_r6=True)
    ready, _ = patch_place(with_r6, SOURCE, server=CITY)
    return ready


def _workspace_props(raw):
    workspace = ElementTree.fromstring(raw).find("./Item[@class='Workspace']")
    return {prop.attrib["name"]: (prop.tag, prop.text) for prop in workspace.find("Properties")}


def _with_binary_props(*props):
    raw = make_binary()
    parenting = Binary(raw).parent_chunk.packet
    additions = b"".join(
        _chunk(b"PROP", pack32(0) + pstring(name.encode()) + bytes([kind]) + payload)
        for name, kind, payload in props
    )
    return raw.replace(parenting, additions + parenting, 1)


class MareStreamingTests(unittest.TestCase):
    def test_xml_updates_only_workspace_streaming_properties(self):
        target = b'<int name="StreamingTargetRadius">1024</int>'
        raw = _place_xml(
            b'<Item class="Workspace" referent="World"><Properties><string name="Name">World</string>'
            + DISABLED + target + b'<token name="StreamingIntegrityMode">0</token></Properties>'
            b'<!-- Preserve the original map & spacing -->\r\n  <Item class="Part" referent="Original"/>'
            b'</Item>'
        )
        for encoding in ("utf-8", "utf-16"):
            with self.subTest(encoding=encoding):
                before = _with_scripts(raw.decode().encode(encoding))
                after, changed = patch_place(before, SOURCE, force_r6=True, server=CITY)
                self.assertTrue(changed)
                workspace_props = _workspace_props(after)
                self.assertEqual({name: workspace_props[name] for name in XML_SETTINGS}, XML_SETTINGS)
                expected = before.decode(encoding).replace(DISABLED.decode(), '<bool name="StreamingEnabled">true</bool>')
                expected = expected.replace(target.decode(), '<int name="StreamingTargetRadius">640</int>')
                expected = expected.replace(
                    '<token name="StreamingIntegrityMode">0</token>',
                    '<token name="StreamingIntegrityMode">0</token><int name="StreamingMinRadius">180</int>',
                )
                self.assertEqual(after, expected.encode(encoding))
                self.assertEqual(patch_place(after, SOURCE, force_r6=True, server=CITY), (after, False))

    def test_xml_inserts_missing_properties_before_existing_map_children(self):
        raw = _place_xml(b'<Item class="Workspace"><Item class="Part" referent="Original"/></Item>')
        after, _ = patch_place(raw, SOURCE, force_r6=True, server=CITY)
        workspace = ElementTree.fromstring(after).find("./Item[@class='Workspace']")
        self.assertEqual([child.tag for child in workspace], ["Properties", "Item"])
        self.assertEqual(_workspace_props(after), XML_SETTINGS)

    def test_binary_writes_zigzag_int32_and_preserves_other_packets(self):
        before = _with_scripts(_with_binary_props(
            ("StreamingEnabled", 0x02, b"\x00"),
            ("StreamingMinRadius", 0x03, b"\x00\x00\x00\x80"),
        ))
        after, changed = patch_place(before, SOURCE, force_r6=True, server=CITY)
        self.assertTrue(changed)
        old, new = Binary(before), Binary(after)
        workspace_gid = new.objects[new.locate(("Workspace",))]["group"]
        for name, (expected_kind, expected_payload) in BINARY_SETTINGS.items():
            chunk, kind, start = new.props[workspace_gid, name]
            self.assertEqual((kind, chunk.data[start:]), (expected_kind, expected_payload), name)

        def unchanged_packets(doc):
            edited = {
                chunk for (gid, name), (chunk, _, _) in doc.props.items()
                if gid == workspace_gid and name in BINARY_SETTINGS
            }
            return [chunk.packet for chunk in doc.chunks if chunk not in edited]

        self.assertEqual(new.header, old.header)
        self.assertEqual(unchanged_packets(new), unchanged_packets(old))
        self.assertEqual(patch_place(after, SOURCE, force_r6=True, server=CITY), (after, False))

    def test_streaming_requires_r6_and_managed_city_server_script(self):
        raw = _place_xml(b'<Item class="Workspace"><Properties>' + DISABLED + b'</Properties></Item>')
        client = {CITY_NAME: f"{CLIENT_HEADER}{CITY_NAME}\nreturn\n"}
        for force_r6, server in ((False, CITY), (True, {}), (True, client)):
            with self.subTest(force_r6=force_r6, server=server):
                after, _ = patch_place(raw, SOURCE, force_r6=force_r6, server=server)
                self.assertEqual(_workspace_props(after), {"StreamingEnabled": ("bool", "false")})

    def test_omitted_workspace_is_left_to_the_engine(self):
        for raw in (_place_xml(b""), make_binary_with_lighting()):
            with self.subTest(binary=raw.startswith(b"<roblox!")):
                before = _with_scripts(raw)
                self.assertEqual(patch_place(before, SOURCE, force_r6=True, server=CITY), (before, False))

    def test_invalid_workspace_settings_are_rejected(self):
        duplicate_workspace = _place_xml(b'<Item class="Workspace"/><Item class="Workspace"/>')
        wrong_type = _with_binary_props(("StreamingMinRadius", 0x12, b"\x00\x00\x00\x40"))
        for raw, message in ((duplicate_workspace, "Workspace"), (wrong_type, "StreamingMinRadius")):
            with self.subTest(message=message):
                with self.assertRaisesRegex(Failure, message):
                    patch_place(raw, SOURCE, force_r6=True, server=CITY)


if __name__ == "__main__":
    unittest.main()
