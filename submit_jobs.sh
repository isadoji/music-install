#!/bin/bash
# submit_jobs.sh — envía N eventos a SLURM
#
# Uso:
#   ./submit_jobs.sh <N_eventos> <config> <IC_file> [prefijo]
#
# Ejemplo (10 eventos con la misma condición inicial):
#   ./submit_jobs.sh 10 configs/200GeV_hotQCD.inp \
#       ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat 200GeV
#
# Nota: para estadística real se necesitan ICs diferentes por evento
# (distintos archivos IP-Glasma con diferentes semillas aleatorias).

N="${1:-1}"
CONFIG="$2"
IC_FILE="$3"
PREFIX="${4:-run}"

if [[ -z "$CONFIG" || -z "$IC_FILE" ]]; then
    echo "Uso: $0 <N> <config> <IC_file> [prefijo]"
    exit 1
fi

echo "Enviando ${N} jobs a SLURM..."
for i in $(seq -w 1 $N); do
    JOB_NAME="${PREFIX}_ev${i}"
    # el directorio de --output debe existir antes de enviar el job
    mkdir -p "runs/${JOB_NAME}"
    JOB_ID=$(sbatch --job-name="$JOB_NAME" slurm_music.sh "$CONFIG" "$IC_FILE" | awk '{print $4}')
    echo "  Submitted: ${JOB_NAME}  (SLURM job ${JOB_ID})"
done

echo ""
echo "Monitor: squeue -u $USER"
echo "Logs   : runs/<nombre>/music.log"
