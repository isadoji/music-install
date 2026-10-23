#!/bin/bash
# install_is3d.sh — instala iS3D (https://github.com/derekeverett/iS3D),
# el muestreador de partículas sobre la superficie de freeze-out (Cooper-Frye),
# con TODOS los parches que usa la cadena MUSIC 3+1D de producción ya aplicados
# (mismo árbol que /storage/software/iS3D en acaxees01, verificado 2026-10-23):
#
#   1. iS3D_deltafReader_bilinear_fix.patch   tabla δf transpuesta con include_baryon 1
#                                              (p̄/p ~2.4 en vez de ~1)
#   2. iS3D_deltafReader_table_clamp.patch     celdas con (T, μ_B) fuera de la tabla δf
#                                              abortaban todo el muestreo
#   3. iS3D_mode8_music_3p1d_reader.patch      lector `mode 8`: superficie binaria de MUSIC
#                                              3+1D (34 float32/celda); no existe upstream
#   4. iS3D_smooth_kernels_chunk_memset.patch  buffer por chunk no se re-ceraba (piso
#                                              espurio en espectros suaves, operation 1)
#   5. iS3D_muS_muQ_chemical_potentials.patch  el muestreo ignoraba μ_S y μ_Q de la
#                                              superficie (K⁺/K⁻≈1 en vez de ≈2.2 a 5.8 GeV)
#
# Además copia configs/iS3D_parameters_music3p1d.dat como iS3D_parameters.dat
# (mode 8, dimension 3, df_mode 2, include_baryon 1; el original upstream queda
# en iS3D_parameters.dat.upstream). Ver README §8.3.
#
# Uso:
#   ./install_is3d.sh [directorio_instalacion]
#
# Por defecto instala en $HOME/Software/iS3D.
#
# Al final tendrás: <IS3D_DIR>/iS3D (cmake install lo copia a la raíz del clone)

set -euo pipefail

IS3D_DIR="${1:-$HOME/Software/iS3D}"
IS3D_REPO="https://github.com/derekeverett/iS3D.git"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_DIR="${PROJECT_DIR}/patches"
PARAMS_FILE="${PROJECT_DIR}/configs/iS3D_parameters_music3p1d.dat"
# commit upstream contra el que se generaron los parches 2-5
IS3D_COMMIT="ede5cd4"

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
    echo "  Ya existe un clone en $IS3D_DIR"
else
    mkdir -p "$(dirname "$IS3D_DIR")"
    git clone "$IS3D_REPO" "$IS3D_DIR"
fi
# Commit fijo: los 5 parches se generaron contra él (antes solo se avisaba
# si el clone estaba en otro commit). Con el árbol ya parchado el checkout
# conserva los cambios locales (mismo commit, nada que mover).
git -C "$IS3D_DIR" checkout -q "$IS3D_COMMIT"
echo "  ✓ iS3D en $(git -C "$IS3D_DIR" log --oneline -1)"

# ── 3. Parches ───────────────────────────────────────────────────────────────
echo ""
echo "── Aplicando parches ──"

# 3.1 bilinear (formato antiguo: diff de un solo archivo, se aplica con ruta explícita)
DFR="$IS3D_DIR/src/cpp/deltafReader.cpp"
if grep -q 'f_data\[imuBL\]\[iTL\]' "$DFR" 2>/dev/null; then
    echo "  [1/5] bilinear δf: ya aplicado, se omite."
else
    patch -s "$DFR" "$PATCH_DIR/iS3D_deltafReader_bilinear_fix.patch"
    echo "  [1/5] ✓ bilinear δf (indexa f_data[imuB][iT])"
fi

# 3.2-3.5 diffs git (-p1 desde la raíz del clone), en orden. Idempotente por
# marcador de texto (los parches se solapan en readindata.cpp/deltafReader.cpp,
# así que un "patch -R --dry-run" no sirve para detectar los ya aplicados)
i=2
for SPEC in "iS3D_deltafReader_table_clamp.patch|T_clamped|src/cpp/deltafReader.cpp" \
            "iS3D_mode8_music_3p1d_reader.patch|read_surf_VH_MUSIC_3p1D|src/cpp/readindata.cpp" \
            "iS3D_smooth_kernels_chunk_memset.patch|re-zero the chunk buffer|src/cpp/emissionfunction_smooth_kernels.cpp" \
            "iS3D_muS_muQ_chemical_potentials.patch|muSQ patch|src/cpp/deltafReader.cpp"; do
    IFS='|' read -r P MARK FILE <<< "$SPEC"
    if grep -q "$MARK" "$IS3D_DIR/$FILE" 2>/dev/null; then
        echo "  [$i/5] $P: ya aplicado, se omite."
    elif patch -s -p1 --dry-run -d "$IS3D_DIR" < "$PATCH_DIR/$P" >/dev/null 2>&1; then
        patch -s -p1 -d "$IS3D_DIR" < "$PATCH_DIR/$P"
        echo "  [$i/5] ✓ $P"
    else
        echo "ERROR: $P no aplica limpio sobre $IS3D_DIR (¿commit distinto de $IS3D_COMMIT?)"
        exit 1
    fi
    i=$((i+1))
done

# 3.6 parámetros de producción (MUSIC 3+1D)
if [[ ! -f "$IS3D_DIR/iS3D_parameters.dat.upstream" ]]; then
    cp "$IS3D_DIR/iS3D_parameters.dat" "$IS3D_DIR/iS3D_parameters.dat.upstream"
fi
cp "$PARAMS_FILE" "$IS3D_DIR/iS3D_parameters.dat"
echo "  ✓ iS3D_parameters.dat = configs/iS3D_parameters_music3p1d.dat (mode 8, dimension 3)"

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
if ! make -j"${NJOBS:-$(nproc)}" > "$MAKE_LOG" 2>&1; then
    echo "ERROR: make falló. Últimas 40 líneas:"
    tail -40 "$MAKE_LOG"
    echo "  Log completo: $MAKE_LOG"
    exit 1
fi
make install >> "$MAKE_LOG" 2>&1 || true
rm -f "$MAKE_LOG"

echo ""
echo "================================================"
echo "  ✓ iS3D instalado con los 5 parches (README §8.3)"
echo "  Binario: $IS3D_DIR/iS3D"
echo ""
echo "  Al correr, la salida debe incluir una línea"
echo "    muSQ patch: (T, muB, muS, muQ) = (...) GeV"
echo "  con μ_S ≠ 0 para superficies de MUSIC con μ_B finito."
echo "================================================"
