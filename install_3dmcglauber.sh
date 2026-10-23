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
# Commit fijo GLAUBER_COMMIT (b6059e2, el de acaxees/doramilaje). Solo se
# compila el target 3dMCGlb.e: upstream define también Metropolis.e y
# Metropolis_for_dipole.e, que necesitan LHAPDF (get_LHAPDF.sh) y la cadena
# no usa; un `make` completo fallaba sin LHAPDF y `make install` no corría
# (la instalación vieja de itzalan quedó así, con el binario solo en
# build/src/, visto 2026-10-23). Con useQuarks 1 + cache_tables 1 (default
# y lo que usa la cadena) Metropolis.e solo se llama si faltan las tablas
# tables/*valence_quark_samples*.dat, que vienen en el repo.
# WITH_LHAPDF=1 reproduce la instalación de acaxees/doramilaje: corre el
# get_LHAPDF.sh de upstream (LHAPDF 6.2.1 desde utilities/ + pdfset CT10nnlo
# bajado de lhapdfsets.web.cern.ch) y compila e instala todos los targets.
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
GLAUBER_COMMIT="b6059e2"
WITH_LHAPDF="${WITH_LHAPDF:-0}"
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
    echo "  Ya existe un clone en $GLAUBER_DIR"
else
    mkdir -p "$(dirname "$GLAUBER_DIR")"
    git clone "$GLAUBER_REPO" "$GLAUBER_DIR"
fi
git -C "$GLAUBER_DIR" checkout -q "$GLAUBER_COMMIT"
echo "  ✓ 3dMCGlauber en $(git -C "$GLAUBER_DIR" log --oneline -1)"

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
if [[ "$WITH_LHAPDF" == 1 && ! -e "$GLAUBER_DIR/LHAPDF_Lib/lib/libLHAPDF.so" ]]; then
    echo "  Compilando LHAPDF (get_LHAPDF.sh de upstream)..."
    ( cd "$GLAUBER_DIR" && bash ./get_LHAPDF.sh "$(nproc)" > lhapdf_build.log 2>&1 ) \
        || { echo "ERROR: get_LHAPDF.sh falló (ver $GLAUBER_DIR/lhapdf_build.log)"; exit 1; }
    [[ -d "$GLAUBER_DIR/LHAPDF_Lib/share/LHAPDF/CT10nnlo" ]] || { echo "ERROR: falta el pdfset CT10nnlo"; exit 1; }
    echo "  ✓ LHAPDF + CT10nnlo en $GLAUBER_DIR/LHAPDF_Lib"
fi
BUILD_DIR="$GLAUBER_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CMAKE_LOG=$(mktemp)
if ! cmake .. -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON > "$CMAKE_LOG" 2>&1; then
    echo "ERROR: cmake falló. Salida completa:"
    cat "$CMAKE_LOG"
    exit 1
fi
rm -f "$CMAKE_LOG"

MAKE_LOG=$(mktemp)
TARGET=3dMCGlb.e; [[ "$WITH_LHAPDF" == 1 ]] && TARGET=all
if ! make -j"$(nproc)" $TARGET > "$MAKE_LOG" 2>&1; then
    echo "ERROR: make falló. Últimas 40 líneas:"
    tail -40 "$MAKE_LOG"
    echo "  Log completo: $MAKE_LOG"
    exit 1
fi
# `make install` instalaría también los Metropolis*.e (no compilados): se
# copia a mano lo mismo que instalaría para 3dMCGlb.e (prefijo = raíz del
# repo, RPATH = <prefijo>/lib).
if [[ "$WITH_LHAPDF" == 1 ]]; then
    make install >> "$MAKE_LOG" 2>&1 || { echo "ERROR: make install falló"; tail -40 "$MAKE_LOG"; exit 1; }
else
    install -D -m 755 src/3dMCGlb.e "$GLAUBER_DIR/3dMCGlb.e"
    install -D -m 755 src/lib3dMCGlb.so "$GLAUBER_DIR/lib/lib3dMCGlb.so"
fi
if ldd "$GLAUBER_DIR/3dMCGlb.e" | grep -q "not found"; then
    echo "ERROR: 3dMCGlb.e con bibliotecas sin resolver:"; ldd "$GLAUBER_DIR/3dMCGlb.e"; exit 1
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
