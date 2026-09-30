#!/bin/bash
# install_is3d.sh — instala iS3D (https://github.com/derekeverett/iS3D),
# el muestreador de partículas sobre la superficie de freeze-out (Cooper-Frye),
# con el parche crítico de `deltafReader.cpp` ya aplicado
# (patches/iS3D_deltafReader_bilinear_fix.patch).
#
# Sin ese parche, cualquier corrida con `include_baryon 1` lee la tabla
# delta-f transpuesta (f_data[iT][imuB] en vez de f_data[imuB][iT]) y
# produce p̄/p, n̄/n, Λ̄/Λ sistemáticamente mal (p̄/p ~2.4 en vez de ~1) —
# ver README §8.3.
#
# Uso:
#   ./install_is3d.sh [directorio_instalacion]
#
# Por defecto instala en $HOME/Software/iS3D.
#
# Al final tendrás: <IS3D_DIR>/build/iS3D (o similar, según cmake)

set -euo pipefail

IS3D_DIR="${1:-$HOME/Software/iS3D}"
IS3D_REPO="https://github.com/derekeverett/iS3D.git"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="${PROJECT_DIR}/patches/iS3D_deltafReader_bilinear_fix.patch"

echo "================================================"
echo "  Instalando iS3D"
echo "  Destino: ${IS3D_DIR}"
echo "================================================"

# ── 1. Dependencias ──────────────────────────────────────────────────────────
echo ""
echo "── Verificando dependencias ──"

missing=()
command -v g++    >/dev/null 2>&1 || missing+=("g++")
command -v cmake  >/dev/null 2>&1 || missing+=("cmake")
command -v git    >/dev/null 2>&1 || missing+=("git")
command -v patch  >/dev/null 2>&1 || missing+=("patch")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan dependencias: ${missing[*]}"
    echo "  Instálalas con:"
    echo "    sudo apt update && sudo apt install -y ${missing[*]}"
    exit 1
fi
echo "  ✓ g++, cmake, git, patch presentes"

# ── 2. Clonar ────────────────────────────────────────────────────────────────
echo ""
echo "── Obteniendo código fuente ──"
if [[ -d "$IS3D_DIR/.git" ]]; then
    echo "  Ya existe un clone en $IS3D_DIR, actualizando..."
    git -C "$IS3D_DIR" pull --ff-only
else
    mkdir -p "$(dirname "$IS3D_DIR")"
    git clone "$IS3D_REPO" "$IS3D_DIR"
fi

# ── 3. Parche crítico deltafReader.cpp ───────────────────────────────────────
echo ""
echo "── Aplicando parche (deltafReader.cpp, bug de indexación δf) ──"
DFR="$IS3D_DIR/src/cpp/deltafReader.cpp"
if grep -q 'f_data\[imuBL\]\[iTL\]' "$DFR" 2>/dev/null; then
    echo "  Ya aplicado, se omite."
else
    patch "$DFR" "$PATCH_FILE"
    echo "  ✓ Parche aplicado (indexa f_data[imuB][iT] correctamente)"
fi

# ── 4. Compilar ────────────────────────────────────────────────────────────────
echo ""
echo "── Compilando ──"
BUILD_DIR="$IS3D_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CMAKE_LOG=$(mktemp)
if ! cmake .. > "$CMAKE_LOG" 2>&1; then
    echo "ERROR: cmake falló. Salida completa:"
    cat "$CMAKE_LOG"
    exit 1
fi
rm -f "$CMAKE_LOG"

MAKE_LOG=$(mktemp)
if ! make -j"$(nproc)" > "$MAKE_LOG" 2>&1; then
    echo "ERROR: make falló. Últimas 40 líneas:"
    tail -40 "$MAKE_LOG"
    echo "  Log completo: $MAKE_LOG"
    exit 1
fi
make install >> "$MAKE_LOG" 2>&1 || true
rm -f "$MAKE_LOG"

echo ""
echo "================================================"
echo "  ✓ iS3D instalado (parche δf aplicado)"
echo "  Directorio de build: $BUILD_DIR"
echo ""
echo "  Recordatorio (README §8.3):"
echo "    - include_baryon 1 requiere el parche (ya aplicado aquí)"
echo "    - superficies boost-invariant (2D): fijar mode 8 en la config"
echo "================================================"
