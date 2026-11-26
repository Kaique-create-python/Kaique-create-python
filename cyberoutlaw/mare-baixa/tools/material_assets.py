"""Prepare and optionally send the city's PNGs using the existing CyberOutlaw asset uploader."""
import argparse
import getpass
from hashlib import sha256
import json
from pathlib import Path
import sys
import warnings


ROOT = Path(__file__).resolve().parents[1]
MATERIALS = ROOT / "materials"
MATERIAL_INDEX = MATERIALS / "manifest.json"
PLAN = MATERIALS / "ASSET_PLAN.json"
RECEIPTS = Path.home() / ".cyberoutlaw-menu" / "recibos-midia"


def load_uploader():
    for candidate in (ROOT, ROOT.parent):
        if (candidate / "media_tools/upload.py").is_file():
            sys.path.insert(0, str(candidate))
            from media_tools import upload
            return upload
    raise ValueError("Use o pacote completo ou extraia a pasta materials no projeto CyberOutlaw.")


def make_plan(upload):
    registry = json.loads(MATERIAL_INDEX.read_text(encoding="utf-8"))
    assets = []
    for key, definition in sorted(registry.items()):
        for channel, filename in sorted(definition["maps"].items()):
            path = (MATERIALS / filename).resolve()
            if not path.is_relative_to(MATERIALS):
                raise ValueError(f"Caminho fora da pasta de texturas em {key}.{channel}")
            assets.append({
                "key": f"{key}.{channel}",
                "path": path.relative_to(MATERIALS).as_posix(),
                "assetType": "Image",
                "contentType": "image/png",
                "sha256": sha256(path.read_bytes()).hexdigest(),
                "displayName": f"Mare Baixa {key} {channel}",
                "description": "Material de cenário original do projeto CyberOutlaw.",
            })
    upload._atomic_json(PLAN, {"schemaVersion": 1, "target": upload.TARGET, "assets": assets})
    return upload.validate_manifest(PLAN)


def write_ids(upload, plan, catalog):
    approved = {row["key"]: row for row in catalog.get("assets", [])}
    materials = {}
    pending = []
    for asset in plan["assets"]:
        key = asset["key"]
        row = approved.get(key, {})
        if row.get("status") != "ready" or row.get("sha256") != asset["sha256"]:
            pending.append(key)
            continue
        material, channel = key.split(".")
        asset_id = int(row["assetId"])
        if not 0 < asset_id < 2**53:
            raise ValueError(f"ID de imagem inválido para {key}")
        materials.setdefault(material, {})[channel] = asset_id
    if pending:
        raise ValueError(f"Ainda faltam {len(pending)} aprovações. Consulte novamente com o comando enviar.")
    output = ROOT / "material_ids.json"
    upload._atomic_json(output, materials)
    print(f"IDs vinculados em {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("acao", choices=("verificar", "enviar", "ids"))
    args = parser.parse_args()
    upload = load_uploader()
    plan = make_plan(upload)
    if args.acao == "verificar":
        print(f"{len(plan['assets'])} PNGs íntegros · universo {plan['target']['universeId']}.")
        return
    if args.acao == "enviar":
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            key = getpass.getpass("Chave Roblox Open Cloud (oculta) ")
        try:
            catalog = upload.upload_manifest(PLAN, key.strip(), state_dir=RECEIPTS, max_polls=5,
                                             max_wait_seconds=18, progress=lambda line: print(line, flush=True))
        finally:
            del key
    else:
        catalog = upload.read_saved_catalog(plan, RECEIPTS) or {}
    write_ids(upload, plan, catalog)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, getpass.GetPassWarning) as error:
        raise SystemExit(str(error)) from None
