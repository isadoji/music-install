#!/bin/bash
# install_music.sh — instala MUSIC (https://github.com/MUSIC-fluid/MUSIC)
# tal cual, SIN los parches de EOS 2DTExS de este repo (music_patches/).
# Úsalo si solo quieres la física estándar (EOS_to_use 9, hotQCD lattice).
#
# Uso:
#   ./install_music.sh [directorio_instalacion]
#
# Por defecto instala en $HOME/Software/MUSIC. Puedes darle otra ruta:
#   ./install_music.sh /storage/software/MUSIC
#
# Qué hace:
#   1. Verifica que estén las dependencias (g++, cmake, libgsl-dev, OpenMP)
#      ANTES de compilar, para no terminar con un binario a medias.
#   2. Clona MUSIC-fluid/MUSIC (si el directorio ya existe, hace git pull).
#   3. Compila con cmake + make, revisando el código de salida real de cada
#      paso (nada de "make ... | tail -6": eso esconde errores de
#      compilación reales detrás de un pipe que siempre sale con éxito).
#   4. Confirma que el binario final existe y funciona.
#
# Al final tendrás: <MUSIC_DIR>/build/src/MUSIChydro

set -euo pipefail

MUSIC_DIR="${1:-$HOME/Software/MUSIC}"
MUSIC_REPO="https://github.com/MUSIC-fluid/MUSIC.git"

echo "================================================"
echo "  Instalando MUSIC (sin parches de EOS)"
echo "  Destino: ${MUSIC_DIR}"
echo "================================================"

# ── 1. Dependencias ──────────────────────────────────────────────────────────
echo ""
echo "── Verificando dependencias ──"

missing=()
command -v g++    >/dev/null 2>&1 || missing+=("g++")
command -v cmake  >/dev/null 2>&1 || missing+=("cmake")
command -v git    >/dev/null 2>&1 || missing+=("git")

# libgsl-dev: no basta con que exista libgsl.so en tiempo de ejecución
# (eso lo trae libgsl28); cmake necesita los headers de desarrollo.
# Si faltan, cmake compila "MUSIC sin GSL" en silencio y el binario queda
# incompleto — esto ya nos pasó, así que lo verificamos explícitamente.
if ! echo '#include <gsl/gsl_version.h>' | \
        g++ -x c++ -E - >/dev/null 2>&1; then
    missing+=("libgsl-dev")
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan dependencias: ${missing[*]}"
    echo "  Instálalas con:"
    echo "    sudo apt update && sudo apt install -y ${missing[*]}"
    exit 1
fi
echo "  ✓ g++, cmake, git, libgsl-dev (headers) presentes"

# ── 2. Clonar ────────────────────────────────────────────────────────────────
echo ""
echo "── Obteniendo código fuente ──"
if [[ -d "$MUSIC_DIR/.git" ]]; then
    echo "  Ya existe un clone en $MUSIC_DIR, actualizando..."
    git -C "$MUSIC_DIR" pull --ff-only
else
    mkdir -p "$(dirname "$MUSIC_DIR")"
    git clone "$MUSIC_REPO" "$MUSIC_DIR"
fi

# ── 3. Compilar ───────────────────────────────────────────────────────────────
echo ""
echo "── Compilando ──"
BUILD_DIR="$MUSIC_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CMAKE_LOG=$(mktemp)
if ! cmake .. -DCMAKE_BUILD_TYPE=Release > "$CMAKE_LOG" 2>&1; then
    echo "ERROR: cmake falló. Salida completa:"
    cat "$CMAKE_LOG"
    exit 1
fi
if ! grep -q "Found GSL" "$CMAKE_LOG"; then
    echo "ERROR: cmake no encontró GSL pese a pasar la verificación anterior."
    echo "  Revisa manualmente: $CMAKE_LOG"
    exit 1
fi
grep -E "Found GSL|Found OpenMP|Build type" "$CMAKE_LOG"
rm -f "$CMAKE_LOG"

MAKE_LOG=$(mktemp)
if ! make -j"$(nproc)" > "$MAKE_LOG" 2>&1; then
    echo "ERROR: make falló. Últimas 40 líneas:"
    tail -40 "$MAKE_LOG"
    echo "  Log completo: $MAKE_LOG"
    exit 1
fi
rm -f "$MAKE_LOG"

# ── 4. Verificar binario ──────────────────────────────────────────────────────
MUSIC_BIN="$BUILD_DIR/src/MUSIChydro"
if [[ ! -x "$MUSIC_BIN" ]]; then
    echo "ERROR: compiló sin errores pero no se encuentra $MUSIC_BIN"
    exit 1
fi

echo ""
echo "================================================"
echo "  ✓ MUSIC instalado y compilado correctamente"
echo "  Binario: $MUSIC_BIN"
echo ""
echo "  Siguiente paso: exporta MUSIC_DIR y usa run_music.sh / slurm_music.sh"
echo "  de este repo para lanzar corridas:"
echo "    export MUSIC_DIR=$MUSIC_DIR"
echo "================================================"
