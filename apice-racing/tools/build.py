#!/usr/bin/env python3
"""Gera versões de arquivo único do Ápice Racing.

  python3 tools/build.py            -> dist/apice-racing.html (documento completo, abre direto no navegador)
  python3 tools/build.py --fragment SAIDA.html -> fragmento sem <html>/<head>/<body> (para hospedagens que montam o esqueleto)
"""
import base64
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def between(text, start, end):
    a = text.index(start) + len(start)
    b = text.index(end, a)
    return text[a:b].strip("\n")


def main():
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    head = between(html, "<!-- HEAD:START -->", "<!-- HEAD:END -->")
    body = between(html, "<!-- BODY:START -->", "<!-- BODY:END -->")
    css = (ROOT / "css" / "style.css").read_text(encoding="utf-8")
    scripts = re.findall(r'<script src="([^"]+)"></script>', html)
    external = "\n".join(f'<script src="{s}"></script>' for s in scripts if s.startswith("http"))
    js = "\n".join((ROOT / s).read_text(encoding="utf-8") for s in scripts if not s.startswith("http"))
    js = js.replace("</script", "<\\/script")
    inner = f"{head}\n<style>\n{css}\n</style>\n{body}\n{external}\n<script>\n{js}\n</script>\n"

    args = sys.argv[1:]
    if args and args[0] == "--fragment":
        out = pathlib.Path(args[1])
        # a hospedagem do fragmento não serve .glb: o modelo vai em .js (base64)
        frag = inner.replace("<script>\n", "<script>window.APX_MODEL_JS = true;\n", 1) if False else inner
        frag = frag.replace(f"{external}\n<script>\n", f"{external}\n<script>window.APX_MODEL_JS = true;</script>\n<script>\n", 1)
        out.write_text(frag, encoding="utf-8")
        assets = out.parent / "assets"
        shutil.copytree(ROOT / "assets", assets, dirs_exist_ok=True)
        for glb in (ROOT / "assets").rglob("*.glb"):
            rel = glb.relative_to(ROOT).as_posix()
            b64 = base64.b64encode(glb.read_bytes()).decode("ascii")
            (out.parent / (rel + ".js")).write_text(
                f"(window.APX_MODEL_DATA = window.APX_MODEL_DATA || {{}})[{rel!r}] = '{b64}';\n", encoding="utf-8")
    else:
        full_head = head.replace('<meta name="claude:viewport-fit-sides" content="cover">\n', "")
        doc = (
            '<!doctype html>\n<html lang="pt-BR">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            f"{full_head}\n<style>\n{css}\n</style>\n</head>\n<body>\n{body}\n{external}\n<script>\n{js}\n</script>\n</body>\n</html>\n"
        )
        out = ROOT / "dist" / "apice-racing.html"
        out.parent.mkdir(exist_ok=True)
        out.write_text(doc, encoding="utf-8")
        # modelo 3D e sons ficam ao lado do arquivo único
        shutil.copytree(ROOT / "assets", ROOT / "dist" / "assets", dirs_exist_ok=True)
    print(f"{out} ({out.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
