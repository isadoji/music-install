#!/bin/bash
# generate_bibi_ic.sh — generate a Bi+Bi sqrt(s_NN)=9 GeV initial condition
# with 3dMCGlauber and convert it to the column format MUSIC's
# Initial_profile 13 reader expects.
#
# Usage:
#   ./generate_bibi_ic.sh <output_file> [n_events] [seed] [event_index]
#
# Example:
#   ./generate_bibi_ic.sh initial/BiBi_9GeV_event0.dat 3 12345
#
# Qué hace:
#   1. Corre 3dMCGlb.e con glauber_configs/BiBi_9GeV.input (b_max=2 fm,
#      colisiones centrales) para generar <n_events> eventos.
#   2. Selecciona el evento <event_index> (por defecto 0).
#   3. Lo recorta a 25 columnas -- MUSIC public_stable
#      (hydro_source_strings.cpp) espera máximo 25 columnas por string;
#      el 3dMCGlauber actual escribe 30 (incluye campos nuevos de
#      transporte de carga eléctrica Qe_l/Qe_r/eta_s_Qe_l/eta_s_Qe_r que
#      la versión pública de MUSIC todavía no lee). Sin este recorte,
#      MUSIC aborta con "the format of file...is wrong".
#
# El archivo resultante se usa directo como <initial_condition_file> en
# run_music.sh, junto con configs/BiBi_9GeV.inp.
#
# Nota: 3dMCGlb.e escribe su salida en el directorio desde el que corre
# (busca ./tables/ ahí mismo), así que este script corre dentro de
# GLAUBER_DIR y limpia los archivos temporales al terminar.

set -euo pipefail

GLAUBER_DIR="${GLAUBER_DIR:-$HOME/Software/3dMCGlauber}"
GLAUBER_BIN="${GLAUBER_DIR}/3dMCGlb.e"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLAUBER_CONFIG="${PROJECT_DIR}/glauber_configs/BiBi_9GeV.input"

OUT_FILE="$1"
N_EVENTS="${2:-3}"
SEED="${3:-$RANDOM}"
EVENT_INDEX="${4:-0}"

if [[ -z "$OUT_FILE" ]]; then
    echo "Usage: $0 <output_file> [n_events] [seed] [event_index]"
    exit 1
fi

if [[ ! -x "$GLAUBER_BIN" ]]; then
    echo "ERROR: 3dMCGlb.e no encontrado en $GLAUBER_BIN"
    echo "  Instálalo con: ./install_3dmcglauber.sh"
    exit 1
fi

# resolver OUT_FILE a ruta absoluta ANTES de cambiar de directorio
mkdir -p "$(dirname "$OUT_FILE")"
OUT_FILE_ABS="$(realpath "$OUT_FILE" 2>/dev/null || echo "$(cd "$(dirname "$OUT_FILE")" && pwd)/$(basename "$OUT_FILE")")"

RUN_INPUT="input_BiBi_9GeV_run_$$"
cp "$GLAUBER_CONFIG" "${GLAUBER_DIR}/${RUN_INPUT}"

cleanup() {
    cd "$GLAUBER_DIR"
    rm -f "${RUN_INPUT}" \
          strings_event_*.dat participants_event_*.dat \
          spectators_event_*.dat binaryCollisions_event_*.dat \
          events_summary.dat
}
trap cleanup EXIT

cd "$GLAUBER_DIR"

echo "================================================"
echo "  Generando IC Bi+Bi 9 GeV con 3dMCGlauber"
echo "  Eventos: ${N_EVENTS}  Seed: ${SEED}"
echo "================================================"
./3dMCGlb.e "$N_EVENTS" "$RUN_INPUT" "$SEED"

EVENT_FILE="strings_event_${EVENT_INDEX}.dat"
if [[ ! -f "$EVENT_FILE" ]]; then
    echo "ERROR: 3dMCGlauber no generó $EVENT_FILE"
    ls strings_event_*.dat 2>/dev/null || echo "  (no se generó ningún evento)"
    exit 1
fi

# recorta a 25 columnas (las 2 líneas de encabezado se copian tal cual).
# NF>=25: descarta lineas de string truncadas/malformadas que a veces
# escribe 3dMCGlb.e (menos de 25 columnas) -- rellenarlas en vez de
# descartarlas produce un archivo que MUSIC rechaza ("format ... wrong").
head -2 "$EVENT_FILE" > "$OUT_FILE_ABS"
tail -n +3 "$EVENT_FILE" | \
    awk 'NF>=25{for(i=1;i<=25;i++) printf "%s%s", $i, (i<25?" ":"\n")}
        NF<25{print "WARN: linea malformada NF="NF" descartada" > "/dev/stderr"}' >> "$OUT_FILE_ABS"

echo ""
echo "  ✓ Condición inicial lista: ${OUT_FILE_ABS}"
echo "    Úsala con:"
echo "      ./run_music.sh <run_name> configs/BiBi_9GeV.inp ${OUT_FILE_ABS}"
