#!/bin/bash
# run_all.sh -- corre los checks estaticos sobre un arbol de scripts:
# check_urqmd_input.sh en todo *.sh / inputfile* / *.inp, y check_crab3_qinv.sh
# en todo *.py. Uso: run_all.sh <directorio>...   Sale 1 si algun check falla.
set -u
C="$(dirname "$(readlink -f "$0")")"
[ $# -ge 1 ] || set -- .
rc=0
mapfile -t IN < <(find "$@" -type f \( -name '*.sh' -o -name 'inputfile*' -o -name '*.inp' \) 2>/dev/null \
                  | xargs -r grep -lE '^(pro|PRO)[[:space:]]' 2>/dev/null)
if [ ${#IN[@]} -gt 0 ]; then
    "$C/check_urqmd_input.sh" "${IN[@]}" | grep -v ': ok ' || true
    "$C/check_urqmd_input.sh" "${IN[@]}" > /dev/null || rc=1
fi
"$C/check_crab3_qinv.sh" "$@" || rc=1
echo "run_all: $([ $rc -eq 0 ] && echo OK || echo FALLO)"
exit $rc
