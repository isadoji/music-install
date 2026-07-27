#!/bin/bash
# Corre los 3 pasos de MUSIC secuencialmente para un run dado.
# Uso: ./run_pipeline.sh <run_name> <config> <ic_file>
set -e

RUN_NAME="$1"; CONFIG="$2"; IC_FILE="$3"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

run_and_wait() {
    local mode="$1"
    local label="${mode:-2}"
    echo ""
    echo "=== PASO modo ${label} ==="
    "$PROJECT_DIR/run_music.sh" "$RUN_NAME" "$CONFIG" "$IC_FILE" ${mode}
    local log="$PROJECT_DIR/runs/${RUN_NAME}/run_mode${label}.log"
    echo "Esperando señal en $log ..."
    until grep -q "MUSIC FINISHED OK\|MUSIC FAILED" "$log" 2>/dev/null; do sleep 5; done
    if grep -q "MUSIC FAILED" "$log"; then
        echo "ERROR: modo ${label} falló. Revisa $log"; exit 1
    fi
    echo "Modo ${label} completado OK."
}

run_and_wait ""   # modo 2 (default)
run_and_wait 3
run_and_wait 4

echo ""
echo "=== Pipeline completo: $RUN_NAME ==="
