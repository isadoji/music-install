#!/bin/bash
# check_b_range.sh -- verifica el parametro de impacto de una salida de UrQMD:
#   f19/f20 OSCAR1997A: lineas de evento de 4 campos (evento npart b phi)
#   f14: lineas `impact_parameter_real/min/max(fm): b bmin bmax ...`
# Falla si algun b cae fuera de [bmin, bmax] o si todos los b son iguales
# (sintoma del bug `imp` en minuscula, references/urqmd.md §1).
# Uso: check_b_range.sh <archivo> <bmin> <bmax>
set -u
[ $# -eq 3 ] || { echo "uso: $0 <f19|f14> <bmin> <bmax>"; exit 2; }
awk -v lo="$2" -v hi="$3" '
  /^[[:space:]]*impact_parameter/ { b=$2; seen=1 }
  !/impact_parameter/ && NF==4 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ { b=$3; seen=1 }
  seen { n++; s+=b; if (n==1||b<mn) mn=b; if (n==1||b>mx) mx=b; if (b<lo-1e-6||b>hi+1e-6) bad++; seen=0 }
  END {
    if (n==0) { print "ERROR: no se encontraron eventos con b"; exit 1 }
    printf "eventos %d  b min %.3f  max %.3f  media %.3f  (rango pedido [%s, %s])\n", n, mn, mx, s/n, lo, hi
    if (bad>0) { printf "ERROR: %d eventos fuera de rango\n", bad; exit 1 }
    if (n>1 && mx-mn<1e-6) { print "ERROR: todos los eventos tienen el mismo b (imp en minuscula?)"; exit 1 }
    print "ok"
  }' "$1"
