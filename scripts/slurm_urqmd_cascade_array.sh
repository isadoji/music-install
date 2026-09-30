#!/bin/bash
#SBATCH --job-name=urqmd_cascade
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --output=urqmd_cascade_logs/task_%a.log
#SBATCH --error=urqmd_cascade_logs/task_%a.log
#
# Un task del array = una instancia independiente de UrQMD en modo cascada
# (single-core, sin MPI/OpenMP), corriendo un shard contiguo de la
# estadistica total del chequeo. Bi+Bi central (b=0-1fm), sqrt(s_NN)=5.8 GeV,
# modo cascada (eos=0), t_max=200 fm/c -- reproduce el setup de
# Ayala et al. 2401.00619 Tabla 1 (ver README §9).
#
# Version portable: URQMD_BIN se toma de la variable de entorno URQMD_DIR
# (exportada por install_urqmd.sh) en vez de una ruta fija de cluster. El
# --partition/--mem de arriba son solo un default razonable: ajustalo a tu
# cluster antes de lanzar (o pasalo en la linea de sbatch con --partition=...).
#
# Uso:
#   export URQMD_DIR=$HOME/Software/urqmd-3.4
#   mkdir -p urqmd_cascade_logs
#   sbatch --array=0-N scripts/slurm_urqmd_cascade_array.sh <n_total_events> <outdir> <base_seed>
set -e

N_TOTAL="${1:?usage: sbatch --array=0-N slurm_urqmd_cascade_array.sh <n_total_events> <outdir> <base_seed>}"
OUTDIR="${2:?usage: ...}"
BASE_SEED="${3:-90000}"

URQMD_BIN="${URQMD_DIR:?export URQMD_DIR=/ruta/a/urqmd-3.4 antes de lanzar (ver install_urqmd.sh)}/urqmd.x86_64"
[[ -x "$URQMD_BIN" ]] || { echo "ERROR: no ejecutable en $URQMD_BIN"; exit 1; }

TASK_ID=${SLURM_ARRAY_TASK_ID:-0}
N_TASKS=$(( ${SLURM_ARRAY_TASK_MAX:-0} - ${SLURM_ARRAY_TASK_MIN:-0} + 1 ))

mkdir -p "$OUTDIR"
WORKER_DIR=$(mktemp -d "${TMPDIR:-/tmp}/urqmd_worker_${TASK_ID}_XXXX")
trap 'rm -rf "$WORKER_DIR"' EXIT

ln -sf "$URQMD_BIN" "$WORKER_DIR/urqmd.x86_64"
cd "$WORKER_DIR"

BASE=$(( N_TOTAL / N_TASKS ))
REM=$(( N_TOTAL % N_TASKS ))
if [ "$TASK_ID" -lt "$REM" ]; then
  MY_COUNT=$(( BASE + 1 ))
  MY_START=$(( TASK_ID * (BASE + 1) ))
else
  MY_COUNT=$BASE
  MY_START=$(( REM * (BASE + 1) + (TASK_ID - REM) * BASE ))
fi
MY_SEED=$(( BASE_SEED + TASK_ID ))

echo "== Task $TASK_ID/$N_TASKS: $MY_COUNT eventos (idx global $MY_START..$((MY_START+MY_COUNT-1))), seed=$MY_SEED =="

# NOTA (README §8.4): en la tarjeta de entrada de UrQMD, listar una unidad
# de salida (fXX) la SUPRIME; para obtener f19 hay que comentarla (#f19),
# y para suprimir las que no interesan hay que listarlas sin comentar.
cat > inputfile << EOF
pro 209 83
tar 209 83

nev $MY_COUNT
IMP 0.0 1.0

ecm 5.8
eos 0
rsd $MY_SEED
tim 200 200

#f13
f14
f15
f16
#f19
f20

xxx
EOF

export ftn09=inputfile
export ftn13=task.f13
export ftn14=task.f14
export ftn15=task.f15
export ftn16=task.f16
export ftn19=task.f19
export ftn20=task.f20

./urqmd.x86_64 > run.log 2>&1
STATUS=$?

if [ $STATUS -eq 0 ] && [ -s task.f19 ]; then
  cp task.f19 "$OUTDIR/urqmd_task_$(printf %03d "$TASK_ID").f19"
  echo "Task $TASK_ID OK -> $OUTDIR/urqmd_task_$(printf %03d "$TASK_ID").f19"
else
  echo "Task $TASK_ID FAILED (exit $STATUS)"
  cp run.log "$OUTDIR/FAILED_task_$(printf %03d "$TASK_ID").log"
  exit $STATUS
fi
