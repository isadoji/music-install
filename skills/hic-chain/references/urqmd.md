# UrQMD 3.4 (cascada y afterburner)

Binarios en el cluster:
- cascada: `/storage/software/urqmd/urqmd-3.4/urqmd.x86_64`
- afterburner (osc2u + urqmd.e + tables.dat): `/storage/software/urqmd/urqmd_afterburner`
- fuente local de referencia: `~/Software/UrQMD/urqmd-3.4/` (`input.f`, `output.f`, `anndec.f`)

## 1. Parámetro de impacto: `imp` vs `IMP`

`input.f:686-708`:

| línea del input  | qué hace                                                                       |
| ---------------- | ------------------------------------------------------------------------------ |
| `imp 3.77`       | **b fijo = 3.77 fm en todos los eventos** (`bmin=0`, `CTOption(5)` no se toca) |
| `imp -3.77`      | b aleatorio en [0, 3.77] (pone `CTOption(5)=1`)                                |
| `IMP 0.0 3.77`   | b aleatorio en [bmin, bmax] = [0, 3.77] (`CTOption(5)=1`). **Usar esta.**      |

Mordió al proyecto de centralidad (2026-10-22): las 3 campañas de
centralidad fija salieron con un solo b. Todos los inputs de `music` usan
`IMP` (cascadas de referencia `IMP 0.0 1.0`, corona p+p `IMP 0.0 1.2`,
cascada 0–5% `IMP 0.0 3.77`): no afectados.

Validar después de correr: `checks/check_b_range.sh <f19> 0 3.77` (debe dar
b distribuidos en todo el rango, no un valor único). Bi+Bi 5.8 GeV: 0–5% es
b < 3.77 fm.

## 2. Banderas de salida invertidas

`input.f:755-780`: la línea `f19` en el input pone `bf19=.true.`, y
`output.f` hace `if (bf19) return`. O sea **listar `fNN` suprime esa
salida**. Para quedarte con f19 lista las que *no* quieres
(`f13 f14 f15 f16 f18` ...). La salida se redirige con variables de entorno
`ftnNN=archivo` (p. ej. `ftn19=particle_list.f19`), que no la habilitan ni
deshabilitan.

## 3. Freeze-out: f19/f20 nativos, nunca f14

- f20 (`osc99_event`) escribe `frr0/frrx/frry/frrz`: coordenadas reales de
  freeze-out (último punto de interacción).
- f14 (`file14out`) escribe `r0/rx/ry/rz`: posiciones propagadas
  libremente. **No es la misma cantidad** (confirmado leyendo `output.f`).
- Bug #1: convertir f14 → f19 metía un dip artificial en C2 cerca de
  q≈30 MeV/c. Bug #2: el wrapper del afterburner no sembraba `frr*`
  (corregido, no retroaplicado a AuAu200 viejo).

Formato OSCAR1997A del f19: línea de evento con 4 campos
(`evento npart b phi`), luego 11 campos por partícula
(`i pdg px py pz E m x y z t`). Los scripts filtran con `awk 'NF==4'`/`NF==11`.

## 4. `stop 137` no es OOM

`anndec.f:289` (`anndex`, ityp 139, m=2.112 GeV, sin canal de decaimiento)
aborta con `stop 137`. Es un exit propio de UrQMD. En chunks, el chunk se
corta ahí: ~90% de eventos completados por chunk es **normal**. Contar
eventos completados (`n_done_task_*.txt`), no los pedidos. Comentarios de
scripts viejos que dicen "OOM" están mal.

## 5. Compilación e instalación

`install_urqmd.sh` aplica `patches/urqmd_Linux.mk.patch`
(`-std=legacy -fallow-argument-mismatch -ffixed-line-length-none`).
`urqmd.org` ya no sirve el tar 3.4 (redirige a una página que solo tiene 4.0
y devuelve HTML con HTTP 200). Copia verificada:
`doramilaje:~/github/urqmd/urqmd-3.4.tar`. La usuaria decidió quedarse en 3.4.

## 6. Conversión a OSCAR por especie

`music/BiBi_cascade_5.8GeV_corecorona/eos2x2_0-5/scripts/f19_native_to_oscar1997a_pid.awk -v PID=<pdg>`;
para PID=211 es byte-idéntico al convertidor original.
