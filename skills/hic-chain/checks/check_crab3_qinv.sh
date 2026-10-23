#!/bin/bash
# check_crab3_qinv.sh -- busca en scripts Python que LEEN un .dat de CRAB3
# (crab3_qinv*.dat / qinv.dat) el patron que duplica su columna 1, que ya es
# Qinv real en MeV/c (references/crab3_be.md):
#   ERROR  2*<arreglo>[:, 0]        duplicacion directa de la columna
#   WARN   2*k, 2.0*k_mev, ...      duplicacion de una variable k: correcto solo
#                                   si k viene de be/ (k=Qinv/2), no de CRAB3
#   WARN   <arreglo>[:, 0]/2        convencion a verificar contra ese .dat
# Scripts que no leen CRAB3 (p. ej. drivers de be/, donde k=Qinv/2 es
# correcto) se saltan.
# Uso: check_crab3_qinv.sh <archivo.py|directorio>...   Sale 1 si hay ERROR.
set -u
[ $# -ge 1 ] || { echo "uso: $0 <archivo.py|dir>..."; exit 2; }
rc=0; nf=0
COL0='[A-Za-z_][A-Za-z0-9_]*\[[[:space:]]*:[[:space:]]*,[[:space:]]*0[[:space:]]*\]'
mapfile -t FILES < <(find "$@" -type f -name '*.py' 2>/dev/null | sort)
for f in "${FILES[@]}"; do
    grep -qE 'crab3_qinv|qinv\.dat|crab3[A-Za-z0-9_]*\.dat' "$f" || continue
    nf=$((nf+1))
    while IFS= read -r hit; do
        echo "$f:$hit"; echo "    ERROR: la columna 1 de CRAB3 ya es Qinv; no duplicar (R sale a la mitad)"; rc=1
    done < <(grep -nE "2(\.0?)?[[:space:]]*\*[[:space:]]*$COL0" "$f")
    while IFS= read -r hit; do
        echo "$f:$hit"; echo "    WARN: duplica una variable k; verificar que no venga de la columna 1 de CRAB3"
    done < <(grep -nE '2(\.0?)?[[:space:]]*\*[[:space:]]*k(_[A-Za-z0-9]+)?\b' "$f" | grep -vE '^[0-9]+:[[:space:]]*#')
    while IFS= read -r hit; do
        echo "$f:$hit"; echo "    WARN: divide la columna 0 entre 2; correcto solo si ESE .dat usa k=Qinv/2"
    done < <(grep -nE "$COL0[[:space:]]*/[[:space:]]*2" "$f")
done
[ $rc -eq 0 ] && echo "check_crab3_qinv: sin duplicaciones directas en $nf script(s) que leen CRAB3"
exit $rc
