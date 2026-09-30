#!/bin/bash
# run_urqmd_cascade.sh — version sin SLURM del chequeo de yield UrQMD
# (README §9), para correr en una sola maquina (xook, laptop, etc.) usando
# todos los cores disponibles en paralelo con xargs.
#
# Reproduce exactamente la misma tarjeta de entrada que
# scripts/slurm_urqmd_cascade_array.sh (Bi+Bi central, sqrt(s_NN)=5.8 GeV,
# cascada eos=0, t_max=200 fm/c), repartiendo N_TOTAL eventos entre
# N_TASKS shards que corren en paralelo.
#
# Uso:
#   export URQMD_DIR=$HOME/Software/urqmd-3.4
#   ./scripts/run_urqmd_cascade.sh <n_total_events> <outdir> [n_tasks] [base_seed]
#
# Por defecto n_tasks = nproc.

set -euo pipefail

N_TOTAL="${1:?uso: run_urqmd_cascade.sh <n_total_events> <outdir> [n_tasks] [base_seed]}"
OUTDIR="${2:?uso: ...}"
N_TASKS="${3:-$(nproc)}"
BASE_SEED="${4:-90000}"

URQMD_BIN="${URQMD_DIR:?export URQMD_DIR=/ruta/a/urqmd-3.4 antes de correr (ver install_urqmd.sh)}/urqmd.x86_64"
[[ -x "$URQMD_BIN" ]] || { echo "ERROR: no ejecutable en $URQMD_BIN"; exit 1; }

mkdir -p "$OUTDIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

run_one_task() {
    local TASK_ID=$1
    SLURM_ARRAY_TASK_ID=$TASK_ID \
    SLURM_ARRAY_TASK_MIN=0 \
    SLURM_ARRAY_TASK_MAX=$((N_TASKS - 1)) \
    URQMD_DIR="$URQMD_DIR" \
    bash "$SCRIPT_DIR/slurm_urqmd_cascade_array.sh" "$N_TOTAL" "$OUTDIR" "$BASE_SEED"
}
export -f run_one_task
export N_TOTAL OUTDIR BASE_SEED N_TASKS URQMD_DIR SCRIPT_DIR

echo "Lanzando $N_TASKS tasks en paralelo (nproc=$(nproc)), $N_TOTAL eventos totales..."
seq 0 $((N_TASKS - 1)) | xargs -P "$N_TASKS" -I{} bash -c 'run_one_task "$@"' _ {}

N_OK=$(find "$OUTDIR" -maxdepth 1 -name "urqmd_task_*.f19" | wc -l)
N_FAIL=$(find "$OUTDIR" -maxdepth 1 -name "FAILED_task_*.log" | wc -l)
echo ""
echo "Listo: $N_OK/$N_TASKS tasks OK, $N_FAIL fallidos."
[[ "$N_FAIL" -eq 0 ]] || { echo "Revisa $OUTDIR/FAILED_task_*.log"; exit 1; }

echo ""
echo "Siguiente paso:"
echo "  python3 $SCRIPT_DIR/check_yield_urqmd.py $OUTDIR --target 85.75"
