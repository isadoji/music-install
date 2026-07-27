#!/bin/bash
# run_music.sh — set up and execute a MUSIC run from this project directory
#
# Usage:
#   ./run_music.sh <run_name> <config_file> <initial_condition_file> [mode]
#
# Examples:
#   ./run_music.sh 200GeV_hotQCD_run1 configs/200GeV_hotQCD.inp \
#       ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat
#
#   ./run_music.sh 200GeV_hotQCD_run1 configs/200GeV_hotQCD.inp \
#       ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat 3

set -e

MUSIC_DIR="${MUSIC_DIR:-$HOME/Software/MUSIC}"
MUSIC_BIN="${MUSIC_DIR}/build/src/MUSIChydro"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

RUN_NAME="$1"
CONFIG="$2"
IC_FILE="$3"
MODE="${4:-2}"   # default: evolution only

if [[ -z "$RUN_NAME" || -z "$CONFIG" || -z "$IC_FILE" ]]; then
    echo "Usage: $0 <run_name> <config_file> <initial_condition_file> [mode]"
    exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config file not found: $CONFIG"
    exit 1
fi

IC_FILE_ABS="$(realpath "$IC_FILE")"
if [[ ! -f "$IC_FILE_ABS" ]]; then
    echo "ERROR: initial condition file not found: $IC_FILE_ABS"
    exit 1
fi

if [[ ! -f "$MUSIC_BIN" ]]; then
    echo "ERROR: MUSIC executable not found at $MUSIC_BIN"
    echo "  cd ${MUSIC_DIR}/build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j\$(nproc)"
    exit 1
fi

RUN_DIR="${PROJECT_DIR}/runs/${RUN_NAME}"

mkdir -p "$RUN_DIR"

# symlinks so MUSIC finds its EOS tables and tables/
ln -sf "${MUSIC_DIR}/EOS"    "${RUN_DIR}/EOS"
ln -sf "${MUSIC_DIR}/tables" "${RUN_DIR}/tables"
ln -sf "$MUSIC_BIN"          "${RUN_DIR}/MUSIChydro"

# build music_input from config: replace placeholder and set mode
sed "s|INITIAL_FILE|${IC_FILE_ABS}|g; s|^mode .*|mode ${MODE}|" \
    "$CONFIG" > "${RUN_DIR}/music_input"

echo "================================================"
echo "  Run directory : ${RUN_DIR}"
echo "  Config        : ${CONFIG}"
echo "  Initial cond. : ${IC_FILE_ABS}"
echo "  Mode          : ${MODE}"
echo "================================================"
mkdir -p "${RUN_DIR}/outputs"

echo "Launching MUSIC..."

LOG="${RUN_DIR}/run_mode${MODE}.log"

cd "$RUN_DIR"
nohup bash -c "
    ./MUSIChydro music_input
    STATUS=\$?
    if [ \$STATUS -eq 0 ]; then
        echo '================================================'
        echo '=== MUSIC FINISHED OK  '\"$(date '+%Y-%m-%d %H:%M:%S')\"'  ==='
        echo '================================================'
    else
        echo '================================================'
        echo '=== MUSIC FAILED (exit \$STATUS)  '\"$(date '+%Y-%m-%d %H:%M:%S')\"'  ==='
        echo '================================================'
    fi
" >> "$LOG" 2>&1 &
PID=$!
echo "PID: ${PID}  — log: ${LOG}"
echo "Monitor with: tail -f ${LOG}"
