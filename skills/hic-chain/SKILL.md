---
name: hic-chain
description: Uso correcto de la cadena 3dMCGlauber → MUSIC → iS3D → UrQMD (cascada y afterburner) → CRAB3/be del proyecto (Bi+Bi NICA, AuAu, cluster acaxees). Cargar ANTES de escribir o modificar inputs, scripts slurm, parches o análisis de cualquiera de estos códigos, y antes de interpretar sus salidas (yields, C2, radios R, centralidad b).
---

# hic-chain: reglas de la cadena de simulación

Esta Skill junta las trampas que ya mordieron al proyecto al menos una vez.
Cada regla de abajo tiene su historia y su evidencia en `references/`; lee la
referencia del código que vas a tocar **antes** de escribir nada.

| Vas a tocar...                                      | Lee                         |
| ---------------------------------------------------- | --------------------------- |
| input de UrQMD (cascada o afterburner), f19/f20/f14  | `references/urqmd.md`       |
| MUSIC (input, EOS, s_factor, strings, modo 4)        | `references/music.md`       |
| iS3D (parámetros, superficie, eventos muestreados)   | `references/is3d.md`        |
| CRAB3, `be/` (C2/C3), cualquier fit de R/λ           | `references/crab3_be.md`    |
| sbatch, rutas, nodos, python, corridas existentes    | `references/cluster.md`     |

## Reglas que nunca se rompen (resumen)

1. **UrQMD `imp` ≠ `IMP`.** `imp X` (minúscula, X>0) fija b = X en *todos* los
   eventos. Para un rango de centralidad usa `IMP bmin bmax`. Ver urqmd.md §1.
2. **UrQMD `fNN` en el input SUPRIME la salida NN**, no la pide. Para tener
   f19, no listes `f19`.
3. **Posición de freeze-out: solo f19/f20 nativos**, nunca derivada de f14.
4. **CRAB3 columna 1 = Qinv verdadero en MeV/c**, aunque el header diga
   `k=Qinv/2`. Nunca `q = 2*k`. Si lo haces, R sale a la mitad.
5. **`be/kernels.py` es GeV/fm con k = Qinv/2.** Si llamas el kernel directo,
   `maxmom_gev = maxmom_mev/1000`. El fallo es silencioso (C2≈1 plano).
6. **iS3D debe traer los 5 parches** de `install_is3d.sh` (bilineal δf,
   μ_S/μ_Q, lector mode 8, clamp, memset). Una salida sin la línea
   `muSQ patch: ...` con μ_S≠0 es sospechosa.
7. **MUSIC debe traer el clamp `abs(E_string_norm)`** (`apply_music_fixes.sh`).
8. **`s_factor` no es transferible** entre EOS, energía ni centralidad.
   Recalibrar contra la cascada de la misma ventana de b.
9. **Nunca sobrescribir corridas de referencia.** Corrida nueva = directorio
   nuevo. Backup (`cp`) antes de cualquier `--force` sobre una salida viva.
10. **sbatch sin `--time`.** CPUs: ≤26 si el job debe caber en ambos nodos.

## Checks deterministas

Antes de lanzar, corre los checks sobre lo que escribiste (salen ≠0 si hay
un error):

```bash
S=~/.claude/skills/hic-chain/checks
$S/check_urqmd_input.sh  <inputfile o slurm script con heredoc>...
$S/check_crab3_qinv.sh   <script(s) .py o directorio>
$S/check_ref_protected.sh <directorio de salida nuevo>...
$S/check_b_range.sh      <f19|f14> <bmin> <bmax>     # después de correr
$S/run_all.sh            <directorio con scripts>   # urqmd + crab3 juntos
```

`check_ref_protected.sh` lee `checks/protected_refs.txt`: agrega ahí cada
corrida de referencia nueva.

## Cómo reportar resultados de esta cadena

- Di qué build/parche produjo la salida (fecha del fix de iS3D 2026-10-23,
  del clamp de MUSIC 2026-10-13). Salidas anteriores a un fix se marcan como
  tales, no se mezclan sin decirlo.
- Toda R de CRAB3 se contrasta con el estimador independiente (`be/`) en la
  misma muestra cuando existe.
- Si encuentras una trampa nueva: agrégala a la referencia que corresponda,
  a `README.md` §8 de music-install y, si es mecánica, a un check.
