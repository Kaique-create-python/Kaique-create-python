"""Build the offline Termux lighting update from reviewed sources."""
import argparse
import base64
import hashlib
from pathlib import Path
import zlib

from build_correction10 import read_rows

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT.parent / "dist"
BASE = DIST / "CORRIGIR_ETAPA3_10_CODEX.py"
FILES = (
    "src/client/BastiaoIluminacao.client.luau",
    "src/teste_nuvem.luau",
    "tooling/release_builder.py",
)

ENTRYPOINT = '''
def run_graphics_update():
    import fcntl

    if any(arg in ("--verificar", "--verify", "-h", "--help") for arg in sys.argv[1:]):
        return main(ARQUIVOS)
    cache = Path.home() / ".bastiao_etapa3"
    lock_path = cache / "execucao.lock"
    if not cache.is_dir():
        return main(ARQUIVOS)
    _safe(lock_path)
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise PatchError("Outro instalador do Bastiao esta aberto. Feche-o primeiro.") from None
        result = main(ARQUIVOS)
    if result == 0:
        print("Iluminacao pronta para testar. Rode o testar-nuvem do BASTIAO_ETAPA3.py.")
    else:
        print("Esta entrega usa a base da Correcao 10 do Codex. Preserve arquivos diferentes e revise o erro acima.")
    return result

if __name__ == "__main__":
    try:
        raise SystemExit(run_graphics_update())
    except (OSError, PatchError, KeyboardInterrupt) as exc:
        raise SystemExit("BLOQUEADO: " + str(exc)) from None
'''


def build(output: Path) -> str:
    original = read_rows(BASE)
    rows = {}
    for name in FILES:
        raw = (ROOT / name).read_bytes()
        before = original.get(name)
        rows[name] = {
            "modo": "trocar" if before else "criar",
            "antes": [before["novo"]] if before else [],
            "novo": hashlib.sha256(raw).hexdigest(),
            "dados": base64.b85encode(zlib.compress(raw, 9)).decode("ascii"),
        }
    engine = (ROOT / "tooling/patch_install.py").read_text(encoding="utf-8")
    engine = engine.replace("_METADATA = '.correcao10'", "_METADATA = '.graficos_bastiao'")
    engine = engine.replace("correction: int", "update: str").replace("'correction': 10", "'update': 'graficos-bastiao'")
    engine = engine.replace("Correcao 10 local/offline com backup e rollback.", "Iluminacao do Bastiao com backup local.")
    content = "#!/usr/bin/env python3\n\"\"\"Atualizacao local de iluminacao do Projeto Bastiao.\"\"\"\nimport sys\n"
    content += engine + "\nARQUIVOS = " + repr(rows) + "\n" + ENTRYPOINT
    compile(content, str(output), "exec")
    output.write_text(content, encoding="utf-8")
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DIST / "BASTIAO_GRAFICOS.py")
    args = parser.parse_args()
    print(build(args.output))
