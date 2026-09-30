#!/bin/bash
# install_urqmd.sh — instala UrQMD 3.4 (http://urqmd.org) en modo cascada,
# con el parche de compilación para gfortran >= 10 ya aplicado
# (patches/urqmd_Linux.mk.patch).
#
# El tar fuente de UrQMD NO se puede clonar por git ni redistribuir desde
# este repo (licencia de urqmd.org) — hay que descargarlo a mano una vez
# aceptando los términos del sitio, o dejar que este script lo intente por
# curl si el sitio lo permite sin login.
#
# Uso:
#   ./install_urqmd.sh [directorio_instalacion]
#
# Por defecto instala en $HOME/Software/urqmd-3.4.
#
# Al final tendrás: <URQMD_DIR>/urqmd.x86_64

set -euo pipefail

URQMD_DIR="${1:-$HOME/Software/urqmd-3.4}"
URQMD_URL="http://urqmd.org/download/urqmd-3.4.tar"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="${PROJECT_DIR}/patches/urqmd_Linux.mk.patch"

echo "================================================"
echo "  Instalando UrQMD 3.4 (modo cascada)"
echo "  Destino: ${URQMD_DIR}"
echo "================================================"

# ── 1. Dependencias ──────────────────────────────────────────────────────────
echo ""
echo "── Verificando dependencias ──"

missing=()
command -v gfortran >/dev/null 2>&1 || missing+=("gfortran")
command -v make      >/dev/null 2>&1 || missing+=("make")
command -v patch     >/dev/null 2>&1 || missing+=("patch")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan dependencias: ${missing[*]}"
    echo "  Instálalas con:"
    echo "    sudo apt update && sudo apt install -y ${missing[*]}"
    exit 1
fi
echo "  ✓ gfortran, make, patch presentes"

GFC_MAJOR=$(gfortran -dumpversion | cut -d. -f1)
echo "  gfortran detectado: versión ${GFC_MAJOR}.x"

# ── 2. Descargar y extraer ───────────────────────────────────────────────────
echo ""
echo "── Obteniendo código fuente ──"
mkdir -p "$(dirname "$URQMD_DIR")"

if [[ -d "$URQMD_DIR" && -f "$URQMD_DIR/urqmd.f" ]]; then
    echo "  Ya existe una fuente en $URQMD_DIR, se omite la descarga."
else
    TAR_FILE="$(dirname "$URQMD_DIR")/urqmd-3.4.tar"
    if [[ ! -f "$TAR_FILE" ]]; then
        echo "  Descargando de $URQMD_URL ..."
        if ! curl -fsSL -o "$TAR_FILE" "$URQMD_URL"; then
            echo "ERROR: no se pudo descargar automáticamente."
            echo "  Descárgalo a mano desde $URQMD_URL y colócalo en:"
            echo "    $TAR_FILE"
            echo "  luego vuelve a correr este script."
            exit 1
        fi
    fi
    mkdir -p "$URQMD_DIR"
    tar xf "$TAR_FILE" -C "$(dirname "$URQMD_DIR")"
fi

# ── 3. Parche de compilación (gfortran >= 10) ────────────────────────────────
echo ""
echo "── Aplicando parche de compilación (gfortran >= 10) ──"
if grep -q -- "-std=legacy" "$URQMD_DIR/mk/Linux.mk" 2>/dev/null; then
    echo "  Ya aplicado, se omite."
else
    patch "$URQMD_DIR/mk/Linux.mk" "$PATCH_FILE"
    echo "  ✓ Parche aplicado (-std=legacy -fallow-argument-mismatch -ffixed-line-length-none)"
fi

# ── 4. Compilar ───────────────────────────────────────────────────────────────
echo ""
echo "── Compilando ──"
cd "$URQMD_DIR"

MAKE_LOG=$(mktemp)
if ! make > "$MAKE_LOG" 2>&1; then
    echo "ERROR: make falló. Últimas 40 líneas:"
    tail -40 "$MAKE_LOG"
    echo "  Log completo: $MAKE_LOG"
    exit 1
fi
rm -f "$MAKE_LOG"

# ── 5. Verificar binario ──────────────────────────────────────────────────────
URQMD_BIN="$URQMD_DIR/urqmd.x86_64"
if [[ ! -x "$URQMD_BIN" ]]; then
    echo "ERROR: compiló sin errores pero no se encuentra $URQMD_BIN"
    exit 1
fi

echo ""
echo "================================================"
echo "  ✓ UrQMD 3.4 instalado y compilado correctamente"
echo "  Binario: $URQMD_BIN"
echo ""
echo "  Siguiente paso: exporta URQMD_DIR y usa"
echo "  scripts/run_urqmd_cascade.sh / scripts/slurm_urqmd_cascade_array.sh"
echo "  de este repo para correr el chequeo de yield (§9 del README):"
echo "    export URQMD_DIR=$URQMD_DIR"
echo "================================================"
