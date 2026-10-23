# CRAB3 y `be/` (C2/C3)

## 1. CRAB3: la columna 1 es Qinv verdadero

`crab3_qinv*.dat` (copia de `results/qinv.dat`): la columna 1 **ya es
Q_inv en MeV/c**, aunque el header diga `k=Qinv/2`. Cargar con
`q = d[:, 0] / 1000.0`. **Nunca** `q = 2*d[:, 0]/1000`: duplica el eje y el
fit de Lévy (depende de qR) devuelve R a la mitad.

Evidencia (2026-10-12/13): CRAB3 crudo en k=X coincide con el estimador
`be/` validado en qinv=X (<1%). Encontrado y corregido en 4 scripts:
`fit_plot_corecorona.py` (5.8), `fit_figA3_crab3.py`, `make_report_77.py`,
`make_report_fix_correlations_77.py` (7.7). Core 5.8: R 4.276 → 8.553 fm.

**Pendiente, no confirmado:** en el cluster,
`c3/code/be/validate_against_crab3.py`, `validate_against_crab3_auau200.py`
y `AuAu_200GeV/c3/compare_auau1M_vs_crab3.py` leen `ref[:, 0]` como k sin
dividir; `validate_against_crab3_f19.py` sí divide entre 2. La usuaria dijo
dejarlo pendiente.

Diferencias entre dos brazos con el mismo error son de modo común (las σ no
cambian); valores absolutos de R no.

Check: `checks/check_crab3_qinv.sh <script.py|dir>`.

## 2. Configuración de producción

- Coulomb-OFF, mixed-event, `qinv_factor 1.0`.
- Entrada: un solo f19 OSCAR1997A (header + shards concatenados);
  `phasedescription.dat`: `1` y luego `particle_list.f19 0.0 0.0 0.0 <N_eventos> 1 1.0`.
- Número de pares por stdin: `echo $CRAB_NMAX | ./crab.e`.
- Un build por especie: π⁺ IDENT 211, π⁻ IDENT −211
  (`eos2x2_0-5/scripts/build_crab3_pipm.sh`). Validado: build π⁻ sobre π⁻ =
  build π⁺ sobre π⁻ reetiquetado, byte a byte.
- `mkdir -p results/` antes de correr (si no, segfault).
- `NPHASEMAX`: los builds viejos tienen arreglo estático de 2e7 →
  `Increase NPHASEMAX`. `install_crab3.sh` lo sube a 2e8 y mueve los arreglos
  de mixing al heap. Builds nuevos del proyecto son dinámicos.
- `--mem` de CRAB3 se dimensiona con un autosize (π/evento × eventos × 100 B
  × 1.3, mín. 16 G), ver `slurm_eos2x2_arm_driver.sh`.

## 3. `be/` (repo `music`, `c3/code/be/`)

- `kernels.py` trabaja en **GeV y fm**, eje de binning **k = Qinv/2**.
- `compute_c2_crab`/`compute_c2_batched` reciben `maxmom_mev` y convierten
  solos. Un driver que llama los njit directo debe hacer
  `maxmom_gev = maxmom_mev/1000.0`. Si no: todos los pares en el bin 0,
  C2≈1.000 plano, exit 0 (Bug #7, 2026-09-10).
- Al comparar con un `.dat` de referencia, leer el header de **ese** archivo
  y verificar el eje contra un estimador independiente.
- C3: usar `kernels.triplet_be_weight()` (suma de las 6 permutaciones), no
  `w12*w13*w23`.
- Memoria: usar el reservoir acotado (`reservoir_size`) y correr bajo
  `ulimit -v` (`systemd-run MemoryMax` no limita en esta máquina).
- `compute_c3_diagonal_crab`: el reservoir del denominador mixto se llena con
  todos los intentos, el corte diagonal solo al binear.
- `plot_c2()`: enmascarar `ref_err >= 0` (sentinel −1).

## 4. Validación mínima de un C2 nuevo

Comparar bin a bin contra el estimador pool-random/provenance-mixed en el
subset `all` antes de citar un R. Si difieren ~2×, sospechar primero del eje.
