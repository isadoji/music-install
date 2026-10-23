#!/bin/bash
# check_afterburner_seed.sh -- semilla del afterburner UrQMD (references/urqmd.md §7).
# En modo afterburner (old-event) `rsd` se IGNORA y cada evento se re-siembra
# con time() en segundos: tareas concurrentes comparten el flujo aleatorio.
# El unico mecanismo que funciona es la variable URQMD_RSEED>0 del binario
# parchado (music-install patches/urqmd_afterburner_rseed_env.patch).
#
#   ERROR  script que corre ./urqmd.e sin URQMD_RSEED
#   WARN   script que corre ./urqmd.e sin verificar "fixed random number" en el log
#   ERROR  binario urqmd.e sin el parche (con --bin <dir_afterburner>)
#
# Uso: check_afterburner_seed.sh [--bin <dir_afterburner>]... <script|dir>...
# Sale 1 si hay algun ERROR.
set -u
rc=0; args=()
while [ $# -gt 0 ]; do
    if [ "$1" = --bin ]; then
        b="$2/urqmd/urqmd.e"; shift 2
        if [ ! -x "$b" ]; then echo "$b: ERROR no existe"; rc=1
        elif grep -aq URQMD_RSEED "$b"; then echo "$b: ok   binario con URQMD_RSEED"
        else echo "$b: ERROR binario SIN el parche URQMD_RSEED (correr install_afterburner.sh sobre ese dir)"; rc=1; fi
    else args+=("$1"); shift; fi
done
[ ${#args[@]} -gt 0 ] || exit $rc
mapfile -t S < <(find "${args[@]}" -type f -name '*.sh' 2>/dev/null | xargs -r grep -lE '\./urqmd\.e([[:space:]]|$)' 2>/dev/null)
for f in "${S[@]}"; do
    case "$f" in *.bak*|*~) continue;; esac
    if ! grep -q URQMD_RSEED "$f"; then
        echo "$f: ERROR corre ./urqmd.e sin URQMD_RSEED: tareas concurrentes comparten el flujo aleatorio"; rc=1
    elif ! grep -q 'fixed random number' "$f"; then
        echo "$f: WARN pasa URQMD_RSEED pero no verifica \"fixed random number\" en el log (binario sin parche la ignora en silencio)"
    else
        echo "$f: ok"
    fi
done
exit $rc
