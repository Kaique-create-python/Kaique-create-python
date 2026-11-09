#!/usr/bin/env bash
# Gera os arquivos de lugar com Rojo e roda os testes offline com Lune.
# Uso: tools/build.sh [--sem-testes]
# Requer rojo e lune no PATH (ou ROJO/LUNE apontando para os binários).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ROJO="${ROJO:-rojo}"
LUNE="${LUNE:-lune}"
NAME="IdeiasSemLimites_V3"

mkdir -p build dist
"$ROJO" build default.project.json -o "build/$NAME.rbxl"
"$ROJO" build default.project.json -o "build/$NAME.rbxlx"

if [[ "${1:-}" != "--sem-testes" ]]; then
	"$LUNE" run tests/lune/run_tests.luau "build/$NAME.rbxl" all
fi

cp "build/$NAME.rbxl" "build/$NAME.rbxlx" dist/
cp assets/sons/IdeiasSons.ogg dist/
( cd dist && sha256sum "$NAME.rbxl" "$NAME.rbxlx" IdeiasSons.ogg > SHA256SUMS )
echo "Arquivos prontos em dist/:"
ls -la dist/
