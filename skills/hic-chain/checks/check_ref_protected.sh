#!/bin/bash
# check_ref_protected.sh -- se niega (exit 1) si algun destino de escritura
#   * esta dentro de una corrida de referencia listada en protected_refs.txt, o
#   * ya existe y no esta vacio (corrida nueva = directorio nuevo).
# Usar antes de mkdir/sbatch en launchers:  check_ref_protected.sh "$A" || exit 1
# Ver references/cluster.md. Para proteger una corrida nueva, agregar su ruta
# absoluta (una por linea, # = comentario) a protected_refs.txt.
set -u
[ $# -ge 1 ] || { echo "uso: $0 <destino>..."; exit 2; }
LIST="$(dirname "$(readlink -f "$0")")/protected_refs.txt"
rc=0
for t in "$@"; do
    abs=$(readlink -m "$t")
    if [ -f "$LIST" ]; then
        while read -r ref; do
            ref="${ref%%#*}"; ref="${ref%"${ref##*[![:space:]]}"}"
            [ -z "$ref" ] && continue
            ref=$(readlink -m "$ref")
            case "$abs/" in "$ref"/*)
                echo "PROHIBIDO: $abs esta dentro de la referencia protegida $ref"; rc=1 ;;
            esac
        done < "$LIST"
    fi
    if [ -e "$abs" ] && [ -n "$(ls -A "$abs" 2>/dev/null)" ]; then
        echo "PROHIBIDO: $abs ya existe y no esta vacio (usa un directorio nuevo o haz backup primero)"; rc=1
    fi
done
[ $rc -eq 0 ] && echo "check_ref_protected: ok ($# destino(s))"
exit $rc
