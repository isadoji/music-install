#!/bin/bash
# install_crab3.sh — instala CRAB3 (https://github.com/chunshen1987/crab3,
# fork del CRAB "Correlation After Burner" de Scott Pratt), con dos parches
# ya aplicados (README §8.5):
#
#   - crab3_increase_nphasemax.patch: NPHASEMAX 20e6 -> 200e6 (arreglo
#     estático de punteros que guarda TODOS los pi+ pooled del run;
#     campañas grandes lo superan y crab.e aborta pidiendo aumentarlo).
#   - crab3_nmax_mixing_heap_fix.patch: mueve los arreglos de
#     MIXED_PAIRS_FOR_DENOM de la pila al heap (evitan overflow de stack
#     con NMAX_FOR_MIXING grande).
#
# CRAB3 no usa cmake: se compila como una sola unidad de traducción
# (crab.cpp incluye los demás .cpp vía #include).
#
# Uso:
#   ./install_crab3.sh [directorio_instalacion]
#
# Por defecto instala en $HOME/Software/crab3.
#
# Al final tendrás: <CRAB3_DIR>/crab.e

set -euo pipefail

CRAB3_DIR="${1:-$HOME/Software/crab3}"
CRAB3_REPO="https://github.com/chunshen1987/crab3.git"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================"
echo "  Instalando CRAB3"
echo "  Destino: ${CRAB3_DIR}"
echo "================================================"

# ── 1. Dependencias ──────────────────────────────────────────────────────────
echo ""
echo "── Verificando dependencias ──"

missing=()
command -v g++   >/dev/null 2>&1 || missing+=("g++")
command -v git   >/dev/null 2>&1 || missing+=("git")
command -v patch >/dev/null 2>&1 || missing+=("patch")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan dependencias: ${missing[*]}"
    echo "  Instálalas con:"
    echo "    sudo apt update && sudo apt install -y ${missing[*]}"
    exit 1
fi
echo "  ✓ g++, git, patch presentes"

# ── 2. Clonar ────────────────────────────────────────────────────────────────
echo ""
echo "── Obteniendo código fuente ──"
if [[ -d "$CRAB3_DIR/.git" ]]; then
    echo "  Ya existe un clone en $CRAB3_DIR, actualizando..."
    git -C "$CRAB3_DIR" pull --ff-only
else
    mkdir -p "$(dirname "$CRAB3_DIR")"
    git clone "$CRAB3_REPO" "$CRAB3_DIR"
fi

# ── 3. Parches ───────────────────────────────────────────────────────────────
echo ""
echo "── Aplicando parches ──"

if grep -q "define NPHASEMAX 200000000" "$CRAB3_DIR/crab.cpp" 2>/dev/null; then
    echo "  NPHASEMAX ya aumentado, se omite."
else
    patch "$CRAB3_DIR/crab.cpp" "$PROJECT_DIR/patches/crab3_increase_nphasemax.patch"
    echo "  ✓ NPHASEMAX aumentado a 200000000"
fi

if grep -q "new double\[NMAX_FOR_MIXING\]" "$CRAB3_DIR/source_files/crab_main.cpp" 2>/dev/null; then
    echo "  Arreglos de mixing ya en heap, se omite."
else
    patch "$CRAB3_DIR/source_files/crab_main.cpp" "$PROJECT_DIR/patches/crab3_nmax_mixing_heap_fix.patch"
    echo "  ✓ Arreglos de MIXED_PAIRS_FOR_DENOM movidos al heap"
fi

# ── 4. Compilar ───────────────────────────────────────────────────────────────
echo ""
echo "── Compilando ──"
cd "$CRAB3_DIR"

BUILD_LOG=$(mktemp)
if ! g++ -O2 -o crab.e crab.cpp > "$BUILD_LOG" 2>&1; then
    echo "ERROR: compilación falló. Salida completa:"
    cat "$BUILD_LOG"
    exit 1
fi
rm -f "$BUILD_LOG"

if [[ ! -x "$CRAB3_DIR/crab.e" ]]; then
    echo "ERROR: compiló sin errores pero no se encuentra $CRAB3_DIR/crab.e"
    exit 1
fi

echo ""
echo "================================================"
echo "  ✓ CRAB3 instalado y compilado correctamente"
echo "  Binario: $CRAB3_DIR/crab.e"
echo ""
echo "  Recordatorio (README §8.5):"
echo "    - crear results/ antes de correr crab.e (o crab.e segfaultea)"
echo "    - el --mem del job SLURM no se puede fijar estático: usa un"
echo "      paso 'autosize' intermedio que mida la multiplicidad real"
echo "      antes de lanzar el job real"
echo "================================================"
