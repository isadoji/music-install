# iS3D (muestreo Cooper-Frye)

Instalación de producción: `/storage/software/iS3D` (cluster). Instalar
siempre con `install_is3d.sh` de este repo, que aplica 5 parches de forma
idempotente (marcadores `grep`) y copia
`configs/iS3D_parameters_music3p1d.dat` como `iS3D_parameters.dat`
(mode 8, dimension 3, df_mode 2, include_baryon 1, set_FO_temperature 0).

## Parches obligatorios

| parche                                       | sin él                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------ |
| `iS3D_deltafReader_bilinear_fix.patch`       | con `include_baryon 1` lee la tabla δf transpuesta: p̄/p ≈ 2.4 a μ_B≈0, bariones bajos (encontrado 2026-09-25) |
| `iS3D_muS_muQ_chemical_potentials.patch`     | mode 8 descarta μ_S, μ_Q: K⁺/K⁻ 1.006 en vez de 2.17, Λ/Λ̄ 99 en vez de 41, π⁺ primarios +4.4% (encontrado 2026-10-23) |
| `iS3D_mode8_music_3p1d_reader.patch`         | no existe el lector de la superficie binaria de MUSIC 3+1D (no es upstream) |
| `iS3D_deltafReader_table_clamp.patch`        | aborta con `(T,muB) outside df coefficient table` por una sola celda     |
| `iS3D_smooth_kernels_chunk_memset.patch`     | piso espurio en espectros suaves (`operation 1`)                         |

Señal en tiempo de ejecución: la salida debe imprimir
`muSQ patch: (T, muB, muS, muQ) = ...` con μ_S≠0. Si no aparece, el binario
es pre-fix.

**Toda producción con mode 8 anterior al 2026-10-23 es pre-fix μ_S/μ_Q**
(Bi+Bi 5.8/7.7, AuAu130 probablemente). Las campañas de 1M de 5.8 GeV lo
son; el efecto sobre C2 no está medido.

## Superficie de entrada

`surface.dat` binario de MUSIC (`FindFreezeOutSurface_Cornelius`), 34 float32
por celda. `average_thermodynamic_quantities.dat`: las líneas 6-7 son μ_S, μ_Q.

## Formato de eventos de salida

Un archivo por evento `event_N.dat`: línea `# N` y luego filas
`pdg t x y z E px py pz`. Conversión a OSCAR1997A para el afterburner:
`BiBi_cascade_5.8GeV/scripts/is3d_to_oscar1997a.py` → `osc2u.e` → UrQMD.

## Workaround solo de emergencia

`include_baryon 0` evita el bug bilineal (camino spline) pero solo vale con
μ_B≈0. No usar a energías NICA.
