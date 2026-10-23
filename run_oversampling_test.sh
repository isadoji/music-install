#!/bin/bash
# run_oversampling_test.sh — prueba de flujo completo con oversampling:
# genera N_SURFACES eventos Bi+Bi 9GeV independientes con MUSIC (modo 2,
# resolucion smoke-test de configs/BiBi_9GeV.inp), y para cada surface.dat
# corre iS3D x N_OVERSAMPLE -> osc2u -> UrQMD -> CRAB3 (afterburner
# pipeline ya existente en music/crab_analysis/scripts, reusado tal cual).
#
# Corre MUSIC de forma SINCRONA (a diferencia de run_music.sh, que lanza en
# background con nohup) para poder medir el tiempo real de cada etapa.
#
# Uso: ./run_oversampling_test.sh [n_surfaces] [n_oversample] [n_workers] [chunk]

set -euo pipefail

N_SURFACES="${1:-10}"
N_OVERSAMPLE="${2:-1000}"
N_WORKERS="${3:-10}"
CHUNK="${4:-25}"
SEED_BASE=30000

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MUSIC_DIR="${MUSIC_DIR:-$HOME/Software/MUSIC}"
MUSIC_BIN="${MUSIC_DIR}/build/src/MUSIChydro"
CONFIG="${PROJECT_DIR}/configs/BiBi_9GeV.inp"
PIPELINE_SCRIPTS="/home/isadoji/github/music/crab_analysis/scripts"

TEST_DIR="${PROJECT_DIR}/runs/oversampling_test"
mkdir -p "${TEST_DIR}/ic"
SUMMARY="${TEST_DIR}/summary.log"

echo "n_surfaces=${N_SURFACES} n_oversample=${N_OVERSAMPLE} n_workers=${N_WORKERS} chunk=${CHUNK} start=$(date '+%Y-%m-%d %H:%M:%S')" > "$SUMMARY"

TOTAL_T0=$(date +%s)

for ((s=0; s<N_SURFACES; s++)); do
    SEED=$((SEED_BASE + s))
    IC_FILE="${TEST_DIR}/ic/event_${s}.dat"
    RUN_NAME="ovs_ev${s}"
    RUN_DIR="${PROJECT_DIR}/runs/${RUN_NAME}"

    echo "== surface ${s}/${N_SURFACES}: generando IC (seed=${SEED}) ==" | tee -a "$SUMMARY"
    IC_T0=$(date +%s)
    "${PROJECT_DIR}/generate_bibi_ic.sh" "$IC_FILE" 1 "$SEED" 0 > "${TEST_DIR}/ic_gen_${s}.log" 2>&1
    IC_T1=$(date +%s)
    echo "  ic_wall_s=$((IC_T1-IC_T0))" | tee -a "$SUMMARY"

    echo "== surface ${s}: MUSIC modo 2 (smoke-test resolution) ==" | tee -a "$SUMMARY"
    mkdir -p "$RUN_DIR"
    ln -sf "${MUSIC_DIR}/EOS"    "${RUN_DIR}/EOS"
    ln -sf "${MUSIC_DIR}/tables" "${RUN_DIR}/tables"
    ln -sf "$MUSIC_BIN"          "${RUN_DIR}/MUSIChydro"
    sed "s|INITIAL_FILE|${IC_FILE}|g; s|^mode .*|mode 2|" "$CONFIG" > "${RUN_DIR}/music_input"

    MUSIC_T0=$(date +%s)
    if ( cd "$RUN_DIR" && OMP_NUM_THREADS=12 ./MUSIChydro music_input > "${RUN_DIR}/run_mode2.log" 2>&1 ); then
        MUSIC_STATUS=0
    else
        MUSIC_STATUS=$?
    fi
    MUSIC_T1=$(date +%s)
    echo "  music2_status=${MUSIC_STATUS} music2_wall_s=$((MUSIC_T1-MUSIC_T0))" | tee -a "$SUMMARY"

    SURFACE_FILE="${RUN_DIR}/surface.dat"
    if [[ ! -s "$SURFACE_FILE" ]]; then
        echo "  ERROR: surface.dat no generado para ${RUN_NAME}, se omite oversampling" | tee -a "$SUMMARY"
        continue
    fi

    echo "== surface ${s}: iS3D x${N_OVERSAMPLE} -> osc2u -> UrQMD -> CRAB3 (${N_WORKERS} workers) ==" | tee -a "$SUMMARY"
    PIPE_T0=$(date +%s)
    "${PIPELINE_SCRIPTS}/run_pipeline_parallel.sh" "$SURFACE_FILE" "$N_OVERSAMPLE" \
        "${TEST_DIR}/afterburner_${s}" "$N_WORKERS" "$CHUNK" > "${TEST_DIR}/afterburner_${s}.log" 2>&1
    PIPE_T1=$(date +%s)
    N_COMPLETED_S=$(cat "${TEST_DIR}/afterburner_${s}/n_events_completed.txt" 2>/dev/null || echo "?")
    echo "  afterburner_wall_s=$((PIPE_T1-PIPE_T0)) n_completed=${N_COMPLETED_S}/${N_OVERSAMPLE}" | tee -a "$SUMMARY"
done

TOTAL_T1=$(date +%s)
echo "TOTAL_wall_s=$((TOTAL_T1-TOTAL_T0))" | tee -a "$SUMMARY"
echo "end=$(date '+%Y-%m-%d %H:%M:%S')" >> "$SUMMARY"
echo "== run_oversampling_test.sh done. Ver ${SUMMARY} =="
