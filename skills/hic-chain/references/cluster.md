# Cluster acaxees y reglas de ejecución

## Acceso y nodos

- `acaxees01` (40 CPUs) y `acaxees02` (26 CPUs). acaxees02 solo se alcanza
  desde acaxees01. `/storage` es NFS compartido (mismos binarios en ambos).
- Partición `fcfm`. `RealMemory` bajado a 150000 MB en ambos (2026-10-21,
  canal D de memoria de acaxees02 inestable).
- Python en el cluster: `/storage/software/miniconda3/envs/root_env/bin/python`.
  Local (doramilaje): `~/Software/miniconda3/bin/python`.
- `squeue` corta nombres: `squeue -u isadoji -o "%.10i %.30j %.8T %.10M %R"`.

## Reglas de sbatch

- **Nunca `--time`** (ni `#SBATCH --time`). Un pilot con `--time=04:00:00`
  se mató a medias.
- `--cpus-per-task` al máximo: ≤26 para que el job quepa en cualquier nodo
  (40 solo si se fija acaxees01). En doramilaje, máximo 10 cores.
- `mkdir -p` del directorio de `--output` antes de `sbatch`.
- En scripts SLURM, `SCRIPT_DIR` absoluto: `$(dirname "$0")` apunta al spool.
- Muchos shards: `find ... -exec` o lista en archivo, no glob (ARG_MAX).
- `scontrol update ... MinMemoryNode=` en MB enteros, sin sufijo `G`.
- Jobs de la usuaria (`urqmd_bi*`, `mpd_urqmd_bi11`): no tocarlos; usar
  `--dependency=afterany:<ids>` si hay que esperarlos.

## Corridas de referencia

- Nunca editar ni sobrescribir una corrida de referencia ni sus reportes.
  Comparación nueva = directorio nuevo (`*_postfix`, `*_normfix`, ...).
- `cp` de respaldo antes de cualquier `--force`/`--forzar` sobre salida viva.
- Los launchers del proyecto abortan si el directorio del brazo ya existe
  (`[ -e "$A" ] && exit 1`); mantener ese patrón.
- Lista de referencias protegidas: `checks/protected_refs.txt`, verificada
  por `checks/check_ref_protected.sh`.

## Datos

- Campañas: `/storage/isadoji/music/<campaña>/`. Manifiestos de limpieza:
  `/storage/isadoji/music/CLEANUP_*.txt` (lo borrado y lo conservado).
- Faltantes o eventos inutilizables se excluyen y se documentan; no se
  interpolan ni se inventan.
