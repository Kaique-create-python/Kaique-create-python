"""Small, temporary release inputs. No uploaded IDs or machine-specific paths."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


TARGET = {"userId": "10735737143", "universeId": "10776462844", "placeId": "89520940302906"}


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


def asset(root, name, data, key, kind="Audio", content="audio/ogg"):
    path = Path(root) / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return {"key": key, "path": name, "assetType": kind, "contentType": content,
            "sha256": hashlib.sha256(data).hexdigest(), "displayName": "Fixture " + key}


def ready(rows, first=1000):
    return {"schemaVersion": 1, "target": dict(TARGET), "assets": [
        {"key": row["key"], "sha256": row["sha256"], "assetType": row["assetType"],
         "contentType": row["contentType"], "sourcePath": row["path"], "assetId": str(first + i),
         "status": "ready", "moderationState": "Approved", "permissionStatus": "granted"}
        for i, row in enumerate(rows)]}


def make_release(root):
    root = Path(root)
    real = Path(__file__).resolve().parents[1]
    baseline = json.loads((real / "BASE_CLAUDE_ETAPA2.json").read_text())
    write_json(root / "BASE_CLAUDE_ETAPA2.json", baseline)
    for area, names in {
        "server": ["BastiaoServidor", "Interacoes", "Sequencias", "CriaturaCore", "Criatura", "Pavel"],
        "client": ["BastiaoCliente", "Interface", "Som", "Foley", "Efeitos", "MonstroSom"],
    }.items():
        for name in names:
            path = root / "src" / area / (name + ".luau")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("-- replacement fixture " + name + "\nreturn {}\n")
    (root / "src/teste_nuvem.luau").write_text("return {package=cfg.package,passed=false}\n")
    (root / "src/client/BastiaoIluminacao.client.luau").write_text(
        (real / "src/client/BastiaoIluminacao.client.luau").read_text(encoding="utf-8"), encoding="utf-8"
    )
    legacy = json.loads((real / "legado/audio.json").read_text())
    write_json(root / "legado/audio.json", legacy)
    legacy_rows = []
    for key, value in legacy["sprites"].items():
        legacy_rows.append(asset(root / "legado", value["arquivo"], (key + " bytes").encode(), key))
    write_json(root / "legado/UPLOADED_ASSETS.json", ready(legacy_rows, 500))

    new_asset = asset(root / "audio", "publish/new_atlas.ogg", b"new atlas bytes", "new_atlas")
    new_asset["durationSeconds"] = 8
    segments = {
        "pavel_afasta": {"fileKey": "new_atlas", "start": 0.1, "finish": 2.1, "duration": 2,
                         "category": "Voice", "volume": 0.8, "spatial": False, "radio": False, "loop": False},
        "radio_chiado": {"fileKey": "new_atlas", "start": 2.3, "finish": 4.3, "duration": 2,
                         "category": "Foley", "volume": 0.4, "spatial": False, "radio": False, "loop": False},
        "bunker_air": {"fileKey": "new_atlas", "start": 4.5, "finish": 7.5, "duration": 3,
                       "category": "Ambience", "volume": 0.2, "spatial": False, "radio": False, "loop": True},
    }
    manifest = {"schemaVersion": 1, "target": dict(TARGET), "assets": [new_asset], "segments": segments,
                "production": {"complete": True}}
    write_json(root / "audio/AUDIO_MANIFEST.json", manifest)
    write_json(root / "audio/AUDIO_PLAN.json", {"schemaVersion": 1, "target": dict(TARGET),
               "clips": [{"key": name, "enabled": True} for name in segments]})
    write_json(root / "audio/UPLOADED_ASSETS.json", ready([new_asset], 600))

    model = asset(root / "modelo", "monster.glb", b"fixture model", "monster_model", "Model", "model/gltf-binary")
    model = {"file": model.pop("path"), **model, "canonical_mesh_name": "Monster_Animated_18k", "canonical_root_bone": "pelvis"}
    textures, animations = [], []
    for i in range(35):
        name = f"{i+1:02}_CLIP"
        clip = asset(root / "modelo", "animations/" + name + ".rbxm", (name + " data").encode(), name, "Animation", "model/x-rbxm")
        animations.append({"file": clip.pop("path"), **clip, "name": name, "duration_seconds": 2,
                           "loop": False, "markers": [{"name": "Step", "time": 1, "value": "L"}]})
    plan = {"model": model, "textures": textures, "animations": animations,
            "scale": {"monster_rest_height_studs": 9.09, "visual_facing_yaw_degrees": 180}}
    write_json(root / "modelo/MONSTER_ASSET_PLAN.json", plan)
    (root / "modelo/MonsterImportContract.luau").write_text("return {heightStuds=9.09}\n")
    model_rows = []
    for item in [model, *textures, *animations]:
        model_rows.append({"key": item.get("name", "monster_model"), "path": item["file"],
                           "assetType": item["assetType"], "contentType": item["contentType"],
                           "sha256": item["sha256"], "displayName": "Fixture"})
    write_json(root / "modelo/UPLOADED_ASSETS.json", ready(model_rows, 10000))
    return baseline
