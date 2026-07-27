#!/bin/bash
#SBATCH --job-name=MUSIC
#SBATCH --output=runs/%x/slurm.log
#SBATCH --error=runs/%x/slurm.log
#SBATCH --cpus-per-task=6          # 6 threads por job → caben 2 simultáneos en 12 CPUs
#SBATCH --mem=8G
#SBATCH --time=08:00:00

# ──────────────────────────────────────────────────────────────────────────────
# Uso:
#   mkdir -p runs/200GeV_ev001   # el directorio de --output debe existir ANTES
#                                 # de enviar el job (SLURM abre el log al
#                                 # arrancar, antes de que este script corra
#                                 # su propio mkdir)
#   sbatch --job-name=200GeV_ev001 slurm_music.sh \
#          configs/200GeV_hotQCD.inp \
#          ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat
#
# El run_name se toma de --job-name. Usa submit_jobs.sh para no tener que
# hacer esto a mano por cada evento.
#
# Partición: no se fija aquí a propósito (cada cluster tiene nombres
# distintos: debug, fcfm, general...). Si tu sitio no tiene partición por
# defecto, agrega --partition=<nombre> al comando sbatch, ej.:
#   sbatch --partition=fcfm --job-name=200GeV_ev001 slurm_music.sh ...
#
# Para múltiples eventos:
#   ./submit_jobs.sh 10 configs/200GeV_hotQCD.inp \
#       ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat 200GeV
# ──────────────────────────────────────────────────────────────────────────────

set -e

CONFIG="$1"
IC_FILE="$2"
RUN_NAME="${SLURM_JOB_NAME}"
MUSIC_DIR="${MUSIC_DIR:-$HOME/Software/MUSIC}"
MUSIC_BIN="${MUSIC_DIR}/build/src/MUSIChydro"
# $(dirname "$0") NO sirve aquí: sbatch copia este script a un directorio de
# spool antes de ejecutarlo, así que "$0" ya no apunta al repo. SLURM sí
# garantiza SLURM_SUBMIT_DIR = directorio desde donde llamaste a sbatch.
PROJECT_DIR="${SLURM_SUBMIT_DIR}"
RUN_DIR="${PROJECT_DIR}/runs/${RUN_NAME}"

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

if [[ -z "$CONFIG" || -z "$IC_FILE" ]]; then
    echo "Uso: sbatch --job-name=<nombre> slurm_music.sh <config> <IC_file>"
    exit 1
fi

IC_FILE_ABS="$(realpath "$IC_FILE")"
mkdir -p "${RUN_DIR}/outputs"

ln -sf "${MUSIC_DIR}/EOS"    "${RUN_DIR}/EOS"
ln -sf "${MUSIC_DIR}/tables" "${RUN_DIR}/tables"
ln -sf "$MUSIC_BIN"          "${RUN_DIR}/MUSIChydro"

echo "================================================"
echo "  Job         : ${SLURM_JOB_ID} — ${RUN_NAME}"
echo "  Run dir     : ${RUN_DIR}"
echo "  Config      : ${CONFIG}"
echo "  IC file     : ${IC_FILE_ABS}"
echo "  OMP threads : ${OMP_NUM_THREADS}"
echo "  Start       : $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"

run_mode() {
    local MODE=$1
    sed "s|INITIAL_FILE|${IC_FILE_ABS}|g; s|^mode .*|mode ${MODE}|" \
        "$CONFIG" > "${RUN_DIR}/music_input"

    echo ""
    echo "── Modo ${MODE} — $(date '+%H:%M:%S') ──────────────────────"
    cd "${RUN_DIR}"
    ./MUSIChydro music_input >> "${RUN_DIR}/music.log" 2>&1
    local STATUS=$?
    if [ $STATUS -eq 0 ]; then
        echo "=== Modo ${MODE} FINISHED OK  $(date '+%Y-%m-%d %H:%M:%S') ===" | tee -a "${RUN_DIR}/music.log"
    else
        echo "=== Modo ${MODE} FAILED (exit $STATUS)  $(date '+%Y-%m-%d %H:%M:%S') ===" | tee -a "${RUN_DIR}/music.log"
        exit $STATUS
    fi
    cd "$PROJECT_DIR"
}

# Pipeline completo: evolución → espectros térmicos → decaimientos
run_mode 2
run_mode 3
run_mode 4

echo ""
echo "================================================"
echo "=== PIPELINE COMPLETO OK  $(date '+%Y-%m-%d %H:%M:%S')  ==="
echo "================================================"
