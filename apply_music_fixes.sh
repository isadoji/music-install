#!/bin/bash
# apply_music_fixes.sh — aplica parches generales a un MUSIC ya instalado
# con install_music.sh (README §8.1):
#
#   - freeze_pseudo.patch: quita un free(particleList) que cuelga en
#     corridas grandes (Cooper-Frye con muchas partículas muestreadas).
#   - read_in_parameters.patch: acepta EOS_to_use hasta 20 (necesario solo
#     si vas a usar una EOS custom como 2DTExS — esa tabla y el código de
#     la EOS en sí NO están vendorizados en este repo, hay que traerlos de
#     otro checkout que ya los tenga).
#   - hydro_source_strings_norm_clamp.patch: en compute_norm_for_strings(),
#     un string con eta_s_right < eta_s_left (span invertido) hace que
#     E_string_norm salga fuertemente negativo en vez de cercano a cero;
#     el std::max(E_string_norm, small_eps) original es ciego al signo y
#     termina usando small_eps, disparando it->norm a ~1e12-1e14. Se
#     confirmó en IC de producción reales (6/656 strings, campaña Bi+Bi
#     5.8 GeV). Fix: std::max(std::abs(E_string_norm), small_eps).
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
apply_one "hydro_source_strings_norm_clamp.patch" "src/hydro_source_strings.cpp" "$PROJECT_DIR/patches/hydro_source_strings_norm_clamp.patch"

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
