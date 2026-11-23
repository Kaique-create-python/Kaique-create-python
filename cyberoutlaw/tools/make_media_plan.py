"""Create a manifest for the self-contained source and media bundle."""
from pathlib import Path
import json
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from media_tools.catalog import verify_media, ART, OPTIONAL_SOUNDS, SOUNDS
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

for key in SOUNDS + OPTIONAL_SOUNDS:
    entry = sounds[key]
    p = media / "audio" / (key + ".wav")
    if key.startswith("hello_"):
        note = "Capri Desktop © 2026 Lachy, licença não comercial. https://github.com/lachydotmcg/capri-desktop"
    elif entry["provider"] == "ElevenLabs":
        note = "ElevenLabs Sound Effects."
    elif entry.get("license") == "CC0 1.0":
        note = f"Gravação CC0 de {entry.get('authors', 'OpenGameArt')} ({entry.get('source', 'OpenGameArt')}), recortada por código."
    elif key.startswith("ui_"):
        note = "Som de interface sintetizado por código."
    elif key.startswith("arma_"):
        note = "Som de arma sintetizado por código, sem amostras."
    else:
        note = "Efeito eletrônico original."
    rows.append({**row(key, p, "Audio", "audio/wav", note), "durationSeconds": entry["durationSeconds"]})

for key in ART:
    if key == "title":
        description = "Letreiro original CyberOutlaw."
    elif key == "billboard":
        description = "Arte original dos três painéis de Maré Baixa."
    elif key == "facades":
        description = "Quatro texturas originais para as fachadas da cidade 3D."
    elif key == "icones_interface":
        description = "Ícones 2D das armas e dos botões, desenhados à mão em vetor, sem imagem gerada por IA."
    elif key == "fachada_painel":
        description = "Painéis modulares dos megaprédios de Maré Baixa, desenhados por código, sem imagem gerada por IA."
    elif key.startswith("fachada_"):
        description = "Janelas de Maré Baixa desenhadas por código, sem imagem gerada por IA."
    elif key == "vitrines":
        description = "Interiores das lojas de Maré Baixa vistos pela vitrine, desenhados por código, sem imagem gerada por IA."
    elif key == "anuncios":
        description = "Anúncios de marcas fictícias de Maré Baixa, desenhados por código, sem imagem gerada por IA."
    elif key.startswith("poca_"):
        description = "Poça de rua: asfalto Poly Haven (CC0) com a água recortada por código."
    elif key.startswith("ceu_"):
        description = "Face do céu noturno de Maré Baixa, gradiente desenhado por código, sem imagem gerada por IA."
    elif key.split("_normal")[0] in ("tijolo", "metal_ondulado", "piso_hexagonal", "concreto_rachado"):
        description = "Material da cidade jogável. Digitalização Poly Haven, licença CC0 1.0."
    else:
        description = "Material do terraço. Digitalização Poly Haven, licença CC0 1.0."
    rows.append(row(key, media / "art" / (key + ".png"), "Image", "image/png", description))

manifest = media / "ASSET_PLAN.json"
manifest.write_text(json.dumps({"schemaVersion": 1, "target": upload.TARGET, "assets": rows}, ensure_ascii=False, indent=2) + "\n")
verify_media(ROOT)
print(f"Manifesto verificado: {len(rows)} arquivos, {len(capri['clips'])} animações.")
