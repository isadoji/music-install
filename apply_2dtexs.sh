#!/bin/bash
# apply_2dtexs.sh — instala la EOS custom 2DTExS (EOS_to_use 20) en un MUSIC
# ya instalado con install_music.sh (README §8.1).
#
# A diferencia de apply_music_fixes.sh (que solo parchea freeze_pseudo.cpp y
# read_in_parameters.cpp), este script instala la EOS 2DTExS completa:
#
#   1. Archivos nuevos: eos_2dtexs.h, eos_2dtexs.cpp
#   2. Archivos modificados completos: eos.cpp, CMakeLists.txt (los stock de
#      MUSIC no registran la EOS 20, hay que reemplazarlos enteros)
#   3. Parches a archivos grandes: freeze_pseudo.patch, read_in_parameters.patch
#      (idempotente: si ya se corrió apply_music_fixes.sh antes, los detecta
#      ya aplicados y no falla)
#   4. Copia la tabla EoS2DTExS.dat (41MB, vendorizada en este repo bajo
#      patches/2dtexs/ — ya NO depende de un checkout separado de epos/)
#   5. Recompila
#
# Uso:
#   ./apply_2dtexs.sh [directorio_MUSIC]
#
# Por defecto usa $MUSIC_DIR o $HOME/Software/MUSIC.

set -euo pipefail

MUSIC_DIR="${1:-${MUSIC_DIR:-$HOME/Software/MUSIC}}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJECT_DIR/patches/2dtexs"

if [[ ! -d "$MUSIC_DIR/src" ]]; then
    echo "ERROR: no se encontró $MUSIC_DIR/src"
    echo "Uso: $0 /ruta/a/MUSIC"
    exit 1
fi

echo "================================================"
echo "  Instalando EOS 2DTExS (EOS_to_use 20) en MUSIC"
echo "  MUSIC dir : $MUSIC_DIR"
echo "================================================"

echo ""
echo "── Copiando archivos nuevos ──"
cp "$SRC_DIR/eos_2dtexs.h"   "$MUSIC_DIR/src/"  && echo "  ✓ eos_2dtexs.h"
cp "$SRC_DIR/eos_2dtexs.cpp" "$MUSIC_DIR/src/"  && echo "  ✓ eos_2dtexs.cpp"

echo ""
echo "── Reemplazando archivos modificados completos ──"
cp "$SRC_DIR/eos.cpp"        "$MUSIC_DIR/src/"  && echo "  ✓ eos.cpp"
cp "$SRC_DIR/CMakeLists.txt" "$MUSIC_DIR/src/"  && echo "  ✓ CMakeLists.txt"

echo ""
echo "── Aplicando parches generales (freeze_pseudo / read_in_parameters) ──"
apply_one() {
    local name="$1" patch="$2"
    if patch -p1 -d "$MUSIC_DIR" --dry-run -s < "$patch" >/dev/null 2>&1; then
        patch -p1 -d "$MUSIC_DIR" < "$patch"
        echo "  ✓ $name aplicado"
    else
        echo "  ! $name ya aplicado o conflicto — verificar manualmente"
    fi
}
apply_one "freeze_pseudo.patch"      "$PROJECT_DIR/patches/freeze_pseudo.patch"
apply_one "read_in_parameters.patch" "$PROJECT_DIR/patches/read_in_parameters.patch"

echo ""
echo "── Copiando tabla EoS2DTExS.dat (vendorizada, 41MB) ──"
TABLE_DST="$MUSIC_DIR/EOS/2DTExS"
mkdir -p "$TABLE_DST"
cp "$SRC_DIR/EoS2DTExS.dat" "$TABLE_DST/"
echo "  ✓ EoS2DTExS.dat → $TABLE_DST/"

echo ""
echo "── Recompilando ──"
BUILD_DIR="$MUSIC_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake .. -DCMAKE_BUILD_TYPE=Release > /dev/null
make -j"$(nproc)" | tail -6

echo ""
echo "================================================"
echo "  Listo. Usar EOS_to_use 20 en el config."
echo "  Tabla: $TABLE_DST/EoS2DTExS.dat"
echo "================================================"
