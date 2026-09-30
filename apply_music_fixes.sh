#!/bin/bash
# apply_music_fixes.sh — aplica dos parches generales a un MUSIC ya instalado
# con install_music.sh (README §8.1):
#
#   - freeze_pseudo.patch: quita un free(particleList) que cuelga en
#     corridas grandes (Cooper-Frye con muchas partículas muestreadas).
#   - read_in_parameters.patch: acepta EOS_to_use hasta 20 (necesario solo
#     si vas a usar una EOS custom como 2DTExS — esa tabla y el código de
#     la EOS en sí NO están vendorizados en este repo, hay que traerlos de
#     otro checkout que ya los tenga).
#
# Uso:
#   ./apply_music_fixes.sh [directorio_MUSIC]
#
# Por defecto usa $MUSIC_DIR o $HOME/Software/MUSIC.

set -euo pipefail

MUSIC_DIR="${1:-${MUSIC_DIR:-$HOME/Software/MUSIC}}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -d "$MUSIC_DIR/src" ]]; then
    echo "ERROR: no se encontró $MUSIC_DIR/src"
    echo "Uso: $0 /ruta/a/MUSIC"
    exit 1
fi

echo "================================================"
echo "  Aplicando fixes generales a MUSIC"
echo "  MUSIC dir : $MUSIC_DIR"
echo "================================================"

apply_one() {
    local name="$1" file="$2" patch="$3"
    if patch -p1 -d "$MUSIC_DIR" --dry-run -s < "$patch" >/dev/null 2>&1; then
        patch -p1 -d "$MUSIC_DIR" < "$patch"
        echo "  ✓ $name aplicado"
    else
        echo "  ! $name ya aplicado o conflicto — verificar manualmente ($file)"
    fi
}

apply_one "freeze_pseudo.patch"        "src/freeze_pseudo.cpp"        "$PROJECT_DIR/patches/freeze_pseudo.patch"
apply_one "read_in_parameters.patch"   "src/read_in_parameters.cpp"   "$PROJECT_DIR/patches/read_in_parameters.patch"

echo ""
echo "── Recompilando ──"
BUILD_DIR="$MUSIC_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake .. -DCMAKE_BUILD_TYPE=Release > /dev/null
make -j"$(nproc)" | tail -6

echo ""
echo "================================================"
echo "  Listo."
echo "================================================"
