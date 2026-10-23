# MUSIC (hidro 3+1D) e IC de 3dMCGlauber

Builds: local `~/Software/MUSIC/build/`, cluster `/storage/software/MUSIC/build/`
(NFS, mismo binario en acaxees01 y 02). Instalación: `install_music.sh` +
`apply_music_fixes.sh` + `apply_2dtexs.sh` (este repo).

## 1. Bug de normalización de strings (corregido 2026-10-13)

`HydroSourceStrings::compute_norm_for_strings()`
(`src/hydro_source_strings.cpp`): para strings con
`eta_s_right < eta_s_left`, `E_string_norm` sale negativo y el clamp
`std::max(E_string_norm, small_eps)` es ciego al signo → `it->norm` ~1e12–1e14.
Afecta `get_hydro_energy_source()` (producción). 0.9% de los strings de un IC
real. Fix: `std::max(std::abs(E_string_norm), small_eps)`, en
`patches/hydro_source_strings_norm_clamp.patch`.

Verificar en un build: `grep -n "abs(E_string_norm)" src/hydro_source_strings.cpp`.
Producción de 5.8 GeV anterior a esa fecha es pre-fix (el rerun postfix no
movió R: 8.316±0.220 vs 8.553±0.171 fm).

## 2. EOS

| `EOS_to_use` | EOS                        | nota                                                   |
| ------------ | -------------------------- | ------------------------------------------------------ |
| 9            | hotQCD, μ_B=0              | de fábrica                                             |
| 14           | neos_bqs (μ_B, μ_S, μ_Q)   | brazos `*_neos`                                        |
| 20           | 2DTExS                     | requiere `apply_2dtexs.sh` (código + tabla 41 MB)      |

## 3. `s_factor`

No es transferible entre EOS, energía ni **centralidad**: medir
`decay_factor` con una corrida 2→3→4 completa y calibrar (README §7,
`s_factor_calibrate.py`). Bi+Bi 5.8 GeV: `s_factor 1.0` se calibró contra
la cascada b<1 fm (π⁺ dN/dy = 85.76); la campaña 0–5% (b<3.77) puede
necesitar recalibración contra `cascade_0-5_urqmd/`.

## 4. Formato de strings de 3dMCGlauber

3dMCGlauber escribe 30 columnas, MUSIC acepta máx. 25:
usar `generate_bibi_ic.sh` (recorta a `*_trim25.dat`). Bi-209 requiere
`patches/3dmcglauber_add_bi_nucleus.patch`. Core/corona: archivos
`strings_event_N_core_trim25.dat` (corte n_coll en producción).

## 5. Yields y modo 4

- `yield_corrected.txt` lo produce `check_yield.py` a partir del modo 4.
- **Abierto:** el modo 4 da K⁻ > K⁺ (K⁻/K⁺≈1.15) a μ_B finito: posible signo
  de μ_S. No usar K⁺/K⁻ del modo 4 como física hasta resolverlo; iS3D con el
  fix μ_S/μ_Q da K⁺/K⁻≈2.17.

## 6. Ejecución

- MUSIC busca `./EOS` y `./tables` relativos al directorio de corrida:
  `run_music.sh` crea los symlinks.
- El directorio de `--output` del sbatch tiene que existir antes de enviar.
- `min_pt 0.01`, no 0 (crash GSL).
