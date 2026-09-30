#!/bin/bash
# install_3dmcglauber.sh — instala 3dMCGlauber (https://github.com/chunshen1987/3dMCGlauber)
# el generador de condiciones iniciales 3D Monte-Carlo Glauber que usa
# MUSIC en Initial_profile 13 (evolución no boost-invariant, p.ej. Bi+Bi
# a energías de NICA).
#
# Aplica además un parche local (patches/3dmcglauber_add_bi_nucleus.patch)
# que agrega el núcleo de Bi-209 (A=209, Z=83, R=6.96 fm, a=0.537 fm,
# convención arXiv:2401.00619) — 3dMCGlauber no lo trae de fábrica.
#
# Uso:
#   ./install_3dmcglauber.sh [directorio_instalacion]
#
# Por defecto instala en $HOME/Software/3dMCGlauber.
#
# Al final tendrás: <GLAUBER_DIR>/3dMCGlb.e

set -euo pipefail

GLAUBER_DIR="${1:-$HOME/Software/3dMCGlauber}"
GLAUBER_REPO="https://github.com/chunshen1987/3dMCGlauber.git"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="${PROJECT_DIR}/patches/3dmcglauber_add_bi_nucleus.patch"

echo "================================================"
echo "  Instalando 3dMCGlauber"
echo "  Destino: ${GLAUBER_DIR}"
echo "================================================"

# ── 1. Dependencias ──────────────────────────────────────────────────────────
echo ""
echo "── Verificando dependencias ──"

missing=()
command -v g++    >/dev/null 2>&1 || missing+=("g++")
command -v cmake  >/dev/null 2>&1 || missing+=("cmake")
command -v git    >/dev/null 2>&1 || missing+=("git")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan dependencias: ${missing[*]}"
    echo "  Instálalas con:"
    echo "    sudo apt update && sudo apt install -y ${missing[*]}"
    exit 1
fi
echo "  ✓ g++, cmake, git presentes"

# ── 2. Clonar ────────────────────────────────────────────────────────────────
echo ""
echo "── Obteniendo código fuente ──"
if [[ -d "$GLAUBER_DIR/.git" ]]; then
    echo "  Ya existe un clone en $GLAUBER_DIR, actualizando..."
    git -C "$GLAUBER_DIR" pull --ff-only
else
    mkdir -p "$(dirname "$GLAUBER_DIR")"
    git clone "$GLAUBER_REPO" "$GLAUBER_DIR"
fi

# ── 3. Parche del núcleo de Bi ────────────────────────────────────────────────
echo ""
echo "── Aplicando parche (núcleo Bi) ──"
if grep -q '"Bi"' "$GLAUBER_DIR/src/Nucleus.cpp"; then
    echo "  Ya aplicado, se omite."
else
    git -C "$GLAUBER_DIR" apply "$PATCH_FILE"
    echo "  ✓ Parche aplicado"
fi

# ── 4. Compilar ────────────────────────────────────────────────────────────────
echo ""
echo "── Compilando ──"
BUILD_DIR="$GLAUBER_DIR/build"
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
if ! make install >> "$MAKE_LOG" 2>&1; then
    echo "ERROR: make install falló. Últimas 40 líneas:"
    tail -40 "$MAKE_LOG"
    exit 1
fi
rm -f "$MAKE_LOG"

# ── 5. Verificar binario ──────────────────────────────────────────────────────
GLAUBER_BIN="$GLAUBER_DIR/3dMCGlb.e"
if [[ ! -x "$GLAUBER_BIN" ]]; then
    echo "ERROR: compiló sin errores pero no se encuentra $GLAUBER_BIN"
    exit 1
fi

echo ""
echo "================================================"
echo "  ✓ 3dMCGlauber instalado y compilado correctamente"
echo "  Binario: $GLAUBER_BIN"
echo ""
echo "  Siguiente paso: exporta GLAUBER_DIR y usa generate_bibi_ic.sh"
echo "  de este repo para generar condiciones iniciales:"
echo "    export GLAUBER_DIR=$GLAUBER_DIR"
echo "================================================"
