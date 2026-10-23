#!/bin/bash
# install_afterburner.sh — instala el afterburner UrQMD de la cadena
# (https://bitbucket.org/Chunshen1987/urqmd_afterburner: osc2u.e + urqmd.e,
# UrQMD 3.4 que lee la lista de partículas de iS3D en vez de una colisión),
# fijado al commit usado en producción (09eeac2) y con dos parches
# (README §8.4):
#
#   - urqmd_afterburner_frr_seed.patch: siembra frr0/frrx/frry/frrz con el
#     punto de creación leído de la lista (la superficie de iS3D). Sin él,
#     las partículas que no interactúan dentro del afterburner salen en el
#     f19/f20 con posición de freeze-out (0,0,0,0) (Bug #2).
#   - urqmd_afterburner_burner_keep_f19.patch: quita `f19` de uqmd.burner
#     (listar fNN SUPRIME esa salida; ver skills/hic-chain/references/urqmd.md).
#     Los scripts de producción escriben su propio uqmd.burner, esto solo
#     corrige el de ejemplo.
#   - urqmd_afterburner_rseed_env.patch: semilla fija vía la variable de
#     entorno URQMD_RSEED>0. En modo old-event (afterburner) `rsd` NO
#     funciona: input() retorna antes de leer el burner (input.f:454), el
#     burner se relee por evento en getoldevent, y para entonces uinit ya
#     decidió fixedseed=.false.; cada evento re-siembra con time() en
#     segundos (urqmd.f:66-68), así que procesos que arrancan en el mismo
#     segundo comparten el flujo aleatorio (verificado: salidas idénticas
#     byte a byte). Con URQMD_RSEED, salida reproducible; sin ella, igual
#     que antes.
#
# Al final genera urqmd/tables.dat (tabla de anchos de decaimiento, binaria
# "unformatted" = dependiente del sistema: se genera en la máquina destino,
# no se copia).
#
# Uso:
#   ./install_afterburner.sh [directorio_instalacion]
# Por defecto instala en $HOME/Software/urqmd_afterburner.
# Al final tendrás: <DIR>/osc2u/osc2u.e  <DIR>/urqmd/urqmd.e  <DIR>/urqmd/tables.dat

set -euo pipefail

AB_DIR="${1:-$HOME/Software/urqmd_afterburner}"
AB_REPO="https://bitbucket.org/Chunshen1987/urqmd_afterburner.git"
AB_COMMIT="09eeac2"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================"
echo "  Instalando urqmd_afterburner (${AB_COMMIT})"
echo "  Destino: ${AB_DIR}"
echo "================================================"

missing=()
for c in gfortran make git patch; do command -v $c >/dev/null 2>&1 || missing+=("$c"); done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan dependencias: ${missing[*]}"; exit 1
fi

# ── 1. Clonar en el commit de producción ────────────────────────────────────
if [[ -d "$AB_DIR/.git" ]]; then
    echo "  Ya existe un clone en $AB_DIR"
else
    mkdir -p "$(dirname "$AB_DIR")"
    git clone "$AB_REPO" "$AB_DIR"
fi
git -C "$AB_DIR" checkout -q "$AB_COMMIT"

# ── 2. Parches (idempotentes) ───────────────────────────────────────────────
cd "$AB_DIR"
PATCHED=0
if grep -q "frrx(i)=rx(i)" urqmd/src/output.f; then
    echo "  ✓ frr seed ya aplicado"
else
    patch -p1 < "$PROJECT_DIR/patches/urqmd_afterburner_frr_seed.patch"
    echo "  ✓ frr seed aplicado"; PATCHED=1
fi
if grep -q "URQMD_RSEED" urqmd/src/init.f; then
    echo "  ✓ URQMD_RSEED ya aplicado"
else
    patch -p1 < "$PROJECT_DIR/patches/urqmd_afterburner_rseed_env.patch"
    echo "  ✓ URQMD_RSEED aplicado"; PATCHED=1
fi
if grep -qx "f19" urqmd/uqmd.burner; then
    patch -p1 < "$PROJECT_DIR/patches/urqmd_afterburner_burner_keep_f19.patch"
    echo "  ✓ uqmd.burner: f19 ya no se suprime"
else
    echo "  ✓ uqmd.burner ya corregido"
fi

# ── 3. Compilar ─────────────────────────────────────────────────────────────
# El target de make es el propio urqmd.e: si existe, no recompila aunque
# src/ haya cambiado. Tras parchar hay que borrarlo.
[[ $PATCHED -eq 1 ]] && rm -f urqmd/urqmd.e osc2u/osc2u.e
make -s
[[ -x osc2u/osc2u.e && -x urqmd/urqmd.e ]] || { echo "ERROR: faltan ejecutables"; exit 1; }
echo "  ✓ osc2u/osc2u.e  urqmd/urqmd.e"

# ── 4. tables.dat ───────────────────────────────────────────────────────────
# UrQMD la calcula y la escribe si no la encuentra. Se dispara con una
# corrida con lista de entrada vacía (termina con error después de escribir
# la tabla, eso es esperado).
if [[ -s urqmd/tables.dat ]]; then
    echo "  ✓ tables.dat ya existe"
else
    echo "  Generando urqmd/tables.dat (un par de minutos)..."
    T=$(mktemp -d)
    cp urqmd/urqmd.e urqmd/uqmd.burner "$T/"
    : > "$T/OSCAR.input"
    ( cd "$T" && URQMD_TAB=tables.dat ftn09=uqmd.burner ftn10=OSCAR.input ./urqmd.e > gen.log 2>&1 || true )
    [[ -s "$T/tables.dat" ]] || { echo "ERROR: no se generó tables.dat (ver $T/gen.log)"; exit 1; }
    mv "$T/tables.dat" urqmd/tables.dat; rm -rf "$T"
    echo "  ✓ tables.dat generado"
fi

echo ""
echo "Listo: $AB_DIR"
