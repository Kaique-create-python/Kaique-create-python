"""Limpeza da chave Open Cloud colada no Termux (usada pelo instalador e pelo envio de mídia).

Ao colar, alguns terminais embrulham o texto com os marcadores de "bracketed paste" (ESC[200~ ... ESC[201~).
Tirar só os caracteres invisíveis deixava "[200~" e "[201~" grudados na chave, e o Roblox respondia 401.
Aqui saem os marcadores inteiros, espaços, quebras de linha, aspas em volta e um rótulo "x-api-key:" colado
junto. A chave em si nunca é mudada nem mostrada: só o tamanho e as 4 primeiras e 4 últimas letras.
"""
import re

_PASTE = re.compile(r"\x1b?\[20[01]~")
_LABEL = re.compile(r"^(x-api-key|api[ _-]?key|chave)\s*[:=]\s*", re.IGNORECASE)
_ALLOWED = re.compile(r"[A-Za-z0-9+/=._-]")


def clean_key(raw):
    """Devolve (chave, avisos). Os avisos descrevem o que foi tirado ou o que parece errado."""
    notes = []
    text = raw or ""
    if _PASTE.search(text):
        text = _PASTE.sub("", text)
        notes.append("tirei os marcadores de colagem do terminal ([200~ e [201~)")
    text = "".join(c for c in text if c.isascii() and c.isprintable() and not c.isspace())
    label = _LABEL.match(text)
    if label:
        text = text[label.end():]
        notes.append("tirei o rótulo colado antes da chave")
    while len(text) >= 2 and text[0] == text[-1] and text[0] in "'\"`":
        text = text[1:-1]
        notes.append("tirei as aspas em volta da chave")
    odd = sorted({c for c in text if not _ALLOWED.fullmatch(c)})
    if odd:
        notes.append("a chave tem caracteres que chaves do Roblox normalmente não têm: " + " ".join(odd)
                     + " (confira se não colou texto a mais)")
    return text, notes


def fingerprint(key):
    """Resumo seguro para conferir com o site: tamanho e as pontas (nunca a chave inteira)."""
    if len(key) < 16:
        return f"{len(key)} caracteres"
    return f"{len(key)} caracteres, começa com {key[:4]}… e termina com …{key[-4:]}"
