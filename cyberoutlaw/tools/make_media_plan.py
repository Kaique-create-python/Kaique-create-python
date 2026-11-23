"""Create a manifest for the self-contained source and media bundle."""
from pathlib import Path
import json
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from media_tools.catalog import verify_media, ART, SOUNDS
from media_tools import upload

media = ROOT / "media"
capri = json.loads((media / "capri/capri_clips.json").read_text())
sounds = json.loads((media / "audio/CREDITOS.json").read_text())

def row(key, value, kind, mime, desc):
    return {
        "key": key,
        "path": value.relative_to(media).as_posix(),
        "assetType": kind,
        "contentType": mime,
        "sha256": hashlib.sha256(value.read_bytes()).hexdigest(),
        "displayName": f"CyberOutlaw {key}",
        "description": desc,
    }

rows = []
for key, rel in sorted(capri["images"].items()):
    p = ROOT / rel
    title = "Capri Desktop © 2026 Lachy. Arte e animação: artista anônima. https://github.com/lachydotmcg/capri-desktop — PolyForm Noncommercial 1.0.0."
    rows.append(row(key, p, "Image", "image/png", title))

for key in SOUNDS:
    entry = sounds[key]
    p = media / "audio" / (key + ".wav")
    note = "Capri Desktop © 2026 Lachy, licença não comercial. https://github.com/lachydotmcg/capri-desktop" if key.startswith("hello_") else ("ElevenLabs Sound Effects." if entry["provider"] == "ElevenLabs" else "Efeito eletrônico original.")
    rows.append({**row(key, p, "Audio", "audio/wav", note), "durationSeconds": entry["durationSeconds"]})

for key in ART:
    if key == "title":
        description = "Letreiro original CyberOutlaw."
    elif key == "billboard":
        description = "Arte original dos três painéis de Maré Baixa."
    elif key == "facades":
        description = "Quatro texturas originais para as fachadas da cidade 3D."
    elif key.startswith("fachada_"):
        description = "Janelas de Maré Baixa desenhadas por código, sem imagem gerada por IA."
    else:
        description = "Material do terraço. Digitalização Poly Haven, licença CC0 1.0."
    rows.append(row(key, media / "art" / (key + ".png"), "Image", "image/png", description))

manifest = media / "ASSET_PLAN.json"
manifest.write_text(json.dumps({"schemaVersion": 1, "target": upload.TARGET, "assets": rows}, ensure_ascii=False, indent=2) + "\n")
verify_media(ROOT)
print(f"Manifesto verificado: {len(rows)} arquivos, {len(capri['clips'])} animações.")
