#!/usr/bin/env bash
# Baixa o Horizon Android 0.7.8 no commit exato da tag v0.7.8 e aplica o patch do Horizon Turbo.
# Uso: bash horizon-turbo/scripts/fetch-source.sh [pasta-destino]
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:-horizon-src}"
repo="https://github.com/Vasysik/horizon-android.git"
tag="v0.7.8"
# Uma tag pode ser movida: o commit é conferido antes de qualquer build.
commit="68a2c4dd1b9a9e511ad3758a79ab772b6f9e5b29"

rm -rf "$dest"
git -c advice.detachedHead=false -c core.autocrlf=false \
  clone --quiet --depth 1 --branch "$tag" "$repo" "$dest"
actual="$(git -C "$dest" rev-parse HEAD)"
if [ "$actual" != "$commit" ]; then
  echo "::error::$tag aponta para $actual; esperado $commit" >&2
  exit 1
fi
for patch in "$here"/patches/*.patch; do
  git -C "$dest" apply --whitespace=nowarn "$patch"
  echo "Aplicado: $(basename "$patch")"
done
echo "Horizon Android $tag ($commit) + Horizon Turbo em $dest"
