#!/usr/bin/env python3
"""Portable Termux preparation and reviewed Saved/publish workflow for ETAPA 3."""
from __future__ import annotations

import argparse
import getpass
import json
import os
from pathlib import Path
import sys
import warnings

from instalador.codec import Failure
from instalador.runtime import read
from tooling import assets_upload, prepare_audio, release_builder as builder

ROOT = Path(__file__).resolve().parent


def hidden_key(label):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            value = getpass.getpass(label + " (oculta; nunca salva): ").strip()
    except (getpass.GetPassWarning, EOFError, KeyboardInterrupt):
        raise Failure("Não foi possível ocultar a chave. Abra um terminal Termux; nada foi enviado.") from None
    if not value:raise Failure("Chave vazia.")
    return value


def _state_root():
    return Path.home() / ".bastiao_instalador"


def _pending_guard():
    pending = read(_state_root() / "active-write.json")
    if pending:
        raise Failure("Existe envio pendente. Preserve active-write.json e execute resume; não repita o envio.")


def main(argv=None, *, root=ROOT):
    parser = argparse.ArgumentParser(description="Projeto Bastião — atualização móvel ETAPA 3 com teste Saved antes de publicar.")
    parser.add_argument("command", choices=("verificar", "preparar-audio", "assets", "testar-nuvem", "publicar", "resume", "status"))
    args = parser.parse_args(argv)
    root = Path(root)
    if args.command == "verificar":
        print(json.dumps(builder.verify(root), ensure_ascii=False, indent=2));return
    if args.command == "status":
        active = read(_state_root() / "active-write.json", {})
        proof = read(_state_root() / "state-etapa3/test.json", {})
        print(json.dumps({"stage": 3, "tested": bool(proof),
                          "pending": {k: active.get(k) for k in ("package", "mode", "base", "version", "status")} if active else None}, ensure_ascii=False, indent=2));return
    if args.command != "resume":_pending_guard()
    os.umask(0o077)
    if args.command == "preparar-audio":
        plan = root / "audio/AUDIO_PLAN.json"
        prepare_audio.load_plan(plan)
        key = hidden_key("Chave ElevenLabs")
        try:
            manifest = prepare_audio.prepare(plan, key)
        finally:key = ""
        print("Áudio produzido e verificado:", len(manifest["segments"]), "segmentos. Agora execute assets.")
        return
    if args.command == "assets":
        paths = builder.upload_manifests(root)
        builder.seed_legacy_receipts(paths[0], _state_root())
        key = hidden_key("Chave Roblox Open Cloud")
        try:
            results = [assets_upload.upload_manifest(path, key) for path in paths]
        finally:key = ""
        rows = [row for result in results for row in result["assets"]]
        print(json.dumps({"ready": all(row["status"] == "ready" for row in rows),
                          "assets": [{k: row.get(k) for k in ("key", "assetId", "status", "moderationState", "permissionStatus")} for row in rows]}, ensure_ascii=False, indent=2))
        if any(row["status"] != "ready" for row in rows):
            raise Failure("Assets pendentes de moderação/permissão ou envio incerto. Recibos preservados; publicação bloqueada. Consulte docs/INSTALAR_TERMUX.md.")
        return
    if args.command == "resume":
        files = builder.load_payload(root)
    else:
        files, _ = builder.build_files(root)
        if args.command == "testar-nuvem":builder.persist_payload(root, files)
    from instalador.cli import main as reviewed_main
    reviewed_main(files, [args.command])


if __name__ == "__main__":
    try:
        main()
    except (Failure, builder.BuildError, prepare_audio.AudioProductionError, OSError, ValueError) as exc:
        print("ERRO:", str(exc), file=sys.stderr)
        raise SystemExit(1)
