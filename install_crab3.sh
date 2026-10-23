#!/bin/bash
# install_crab3.sh — instala CRAB3 (https://github.com/chunshen1987/crab3,
# fork del CRAB "Correlation After Burner" de Scott Pratt), con dos parches
# ya aplicados (README §8.5):
#
#   - NPHASEMAX -> 200e6 (arreglo estático de punteros que guarda TODOS
#     los pi+ pooled del run; campañas grandes lo superan y crab.e aborta
#     pidiendo aumentarlo). Se hace con sed, no con
#     crab3_increase_nphasemax.patch: el upstream trae 5000 (no 20e6 como
#     asumía el parche) y el patch fallaba en una instalación limpia
#     (itzalan, 2026-10-23).
#   - MIXED_PAIRS_FOR_DENOM activado y NMAX_FOR_MIXING 10000 -> 200000,
#     igual que /storage/software/crab3 en acaxees (upstream lo trae
#     comentado).
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
CRAB3_COMMIT="7e885f5"   # el de acaxees y doramilaje
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
    echo "  Ya existe un clone en $CRAB3_DIR"
else
    mkdir -p "$(dirname "$CRAB3_DIR")"
    git clone "$CRAB3_REPO" "$CRAB3_DIR"
fi
git -C "$CRAB3_DIR" checkout -q "$CRAB3_COMMIT"

# ── 3. Parches ───────────────────────────────────────────────────────────────
echo ""
echo "── Aplicando parches ──"

C="$CRAB3_DIR/crab.cpp"
grep -qE '^#define NPHASEMAX [0-9]+' "$C" || { echo "ERROR: no encuentro '#define NPHASEMAX' en $C"; exit 1; }
sed -i -E 's|^#define NPHASEMAX [0-9]+|#define NPHASEMAX 200000000|' "$C"
sed -i -E 's|^/\* *#define MIXED_PAIRS_FOR_DENOM *\*/|#define MIXED_PAIRS_FOR_DENOM|' "$C"
sed -i -E 's|^#define NMAX_FOR_MIXING [0-9]+|#define NMAX_FOR_MIXING 200000|' "$C"
for d in "NPHASEMAX 200000000" "MIXED_PAIRS_FOR_DENOM" "NMAX_FOR_MIXING 200000"; do
    grep -qx "#define $d" "$C" || { echo "ERROR: no quedó '#define $d' en $C"; exit 1; }
done
echo "  ✓ NPHASEMAX=200000000, MIXED_PAIRS_FOR_DENOM, NMAX_FOR_MIXING=200000"

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
