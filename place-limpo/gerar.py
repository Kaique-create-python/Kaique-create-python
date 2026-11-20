"""Monta o arquivo único de Termux com funções de transporte já usadas no projeto."""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent / "bastiao/revisao_codex_correcao9/instalador"


def extract(filename, names):
    source = (OLD / filename).read_text(encoding="utf-8")
    nodes = {node.name: node for node in ast.parse(source).body
             if isinstance(node, (ast.ClassDef, ast.FunctionDef))}
    return "\n\n".join(ast.get_source_segment(source, nodes[name]) for name in names)


cloud = extract("cloud.py", ("number", "NoRedirect", "Cloud")).split("\n def task(")[0]
cloud = cloud.replace("Destino fixo BASTIAO invalido.", "Destino fixo inválido.").replace("BASTIAO-ETAPA/1.0", "Place-Limpo/1.0")
parts = [
    '#!/usr/bin/env python3\n"""Atualizador de Baseplate para o Place 122033314086516."""',
    "import datetime, fcntl, getpass, hashlib, io, json, os, re, sys, time, uuid, warnings, argparse",
    "from pathlib import Path\nfrom urllib.error import HTTPError, URLError\nfrom urllib.parse import urlencode, urlsplit",
    "from urllib.request import Request, build_opener, HTTPRedirectHandler\nimport xml.etree.ElementTree as ET",
    "API = 'https://apis.roblox.com'\nMAX_FILE = 64 * 1024 * 1024\nSTATE = None",
    "TARGET = {'universe': 10774214423, 'place': 122033314086516}",
    f"PLACE_LIMPO = {(ROOT / 'Baseplate.rbxl').read_bytes()!r}",
    extract("codec.py", ("Failure",)),
    extract("paths.py", ("guard", "private_dir", "sync_dir", "sync_file", "write_once")),
    extract("runtime.py", ("sha", "stamp", "read", "save")),
    cloud,
    (ROOT / "reset_main.py").read_text(encoding="utf-8"),
]
text = "\n\n".join(parts)
compile(text, "LIMPAR_PLACE_ROBLOX.py", "exec")
(ROOT / "LIMPAR_PLACE_ROBLOX.py").write_text(text, encoding="utf-8")
