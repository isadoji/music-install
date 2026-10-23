#!/bin/bash
# check_urqmd_input.sh -- revisa inputs de UrQMD 3.4 (archivo suelto o
# heredoc dentro de un script slurm) buscando las trampas conocidas:
#   ERROR  `imp X` con X>0      -> b fijo en todos los eventos (usar IMP bmin bmax)
#   WARN   `imp -X`             -> b aleatorio en [0,X]; valido, pero preferir IMP
#   WARN   `f19` listado        -> f19 queda SUPRIMIDO (listar fNN apaga la salida)
#   info   resumen de las salidas fNN suprimidas
#   WARN   sin imp/IMP          -> b por defecto de UrQMD
# Solo mira lineas que parecen keywords de UrQMD (keyword + espacios + valor
# al inicio de linea). Ver references/urqmd.md.
#
# Uso: check_urqmd_input.sh <archivo>...      Sale 1 si hay algun ERROR.
set -u
[ $# -ge 1 ] || { echo "uso: $0 <inputfile|script>..."; exit 2; }
rc=0
for f in "$@"; do
    [ -f "$f" ] || { echo "$f: no existe"; rc=1; continue; }
    # solo archivos que parecen inputs de UrQMD
    if ! grep -qE '^(pro|tar|PRO|TAR|nev|ecm|elb|tim)[[:space:]]' "$f"; then
        echo "$f: no parece un input de UrQMD, se salta"; continue
    fi
    while IFS=: read -r n line; do
        v=$(awk '{print $2}' <<<"$line")
        if awk -v v="$v" 'BEGIN{exit !(v+0>0)}'; then
            echo "$f:$n: ERROR \`$line\` fija b=$v fm en TODOS los eventos; usa \`IMP 0.0 $v\`"; rc=1
        else
            echo "$f:$n: WARN \`$line\` da b aleatorio en [0,${v#-}]; preferir \`IMP 0.0 ${v#-}\`"
        fi
    done < <(grep -nE '^imp[[:space:]]+' "$f")
    grep -nE '^IMP[[:space:]]+' "$f" | while IFS=: read -r n line; do
        echo "$f:$n: ok   \`$line\`"
    done
    grep -qE '^(imp|IMP)[[:space:]]+' "$f" || echo "$f: WARN no hay imp/IMP: b por defecto de UrQMD"
    grep -nE '^f19([[:space:]]|$)' "$f" | while IFS=: read -r n line; do
        echo "$f:$n: WARN \`f19\` listado SUPRIME el f19 (listar fNN la apaga, no la pide)"
    done
    off=$(grep -oE '^f[0-9]{2}([[:space:]]|$)' "$f" | tr -d '[:space:]' | sed 's/f/ f/g')
    echo "$f: info salidas suprimidas:${off:- ninguna}"
done
exit $rc
