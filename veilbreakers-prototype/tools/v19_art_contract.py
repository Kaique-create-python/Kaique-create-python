"""Shared v1.9 world/UI asset contract, independent of Android rendering."""
GAME_ART_MANIFEST = "project_archive/GAME_ART_MANIFEST_V190.json"
GAME_ART_MANIFESTS = {"1.9.0": GAME_ART_MANIFEST, "1.10.0": "project_archive/GAME_ART_MANIFEST_V200.json"}


def game_art_files(version="1.9.0"):
    files = [f"art_v19/scenes/zone_{index}.png" for index in range(6)]
    files += [f"art_v19/npc/{name}_{index}.png" for name in ("mara", "ivo") for index in range(3)]
    for folder, names in (
        ("portraits", ("kael", "mara", "ivo")),
        ("ui", ("status_panel", "dialogue_frame", "item_slot", "button")),
        ("items", ("sword_varyn", "bandage", "mana_draught", "ivo_note")),
        ("props", ("chest_closed", "chest_open", "sword_ground", "trace", "altar")),
    ):
        files += [f"art_v19/{folder}/{name}.png" for name in names]
    assert len(files) == 28
    if version == "1.10.0":
        files += [f"art_v20/scenes/zone_{index}.png" for index in range(6, 9)]
        files += [f"art_v20/runes/{name}.png" for name in ("arcana", "ember", "frost", "mark")]
        assert len(files) == 35
    return tuple(files)
