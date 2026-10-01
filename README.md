# MUSIC install & run

Guía y scripts mínimos para instalar [MUSIC](https://github.com/MUSIC-fluid/MUSIC)
(EOS estándar, `EOS_to_use 9` — hotQCD lattice, la que trae MUSIC de
fábrica), correrlo localmente, correrlo en paralelo en un cluster SLURM, y
revisar los yields de partículas resultantes. También incluye un pipeline aparte para colisiones Bi+Bi a energías de

NICA (√s_NN=9 GeV, EOS a μ_B finito) usando 3dMCGlauber como generador de
condiciones iniciales — ver §4.

No modifica la ecuación de estado ni el código de MUSIC — es solo el flujo
de instalación + ejecución + análisis básico.

---

## 1. Prerrequisitos

| Paquete    | Para qué                           | Instalación (Ubuntu/Debian)                                  |
| ---------- | ----------------------------------- | ------------------------------------------------------------- |
| g++        | compilar MUSIC                      | incluido en`build-essential`                                |
| cmake      | generar el build                    | `sudo apt install cmake`                                    |
| git        | clonar los repos                    | `sudo apt install git`                                      |
| libgsl-dev | interpolación (MUSIC lo requiere)  | `sudo apt install libgsl-dev`                               |
| Python 3   | análisis de yields (`ptdist.py`) | `sudo apt install python3 python3-numpy python3-matplotlib` |

**Ojo con `libgsl-dev` específicamente:** algunos sistemas ya traen
`libgsl28` (la librería en tiempo de ejecución) pero no los headers de
desarrollo. Si falta `libgsl-dev`, `cmake` compila MUSIC igual pero **sin
GSL y sin avisar con un error fuerte** — el binario queda incompleto y
falla de formas confusas más adelante. `install_music.sh` (abajo) verifica
esto explícitamente antes de compilar.

---

## 2. Instalación

```bash
git clone https://github.com/isadoji/music-install.git
cd music-install
./install_music.sh                       # instala en $HOME/Software/MUSIC
# o, para elegir dónde:
./install_music.sh /ruta/que/quieras/MUSIC
```

El script:

- Revisa dependencias antes de compilar (falla con un mensaje claro si
  falta algo, en vez de dejarte un binario roto).
- Clona `MUSIC-fluid/MUSIC` (o hace `git pull` si ya existe).
- Compila con `cmake` + `make`, mostrando el error completo si algo falla
  (no hay `| tail` escondiendo la salida real).
- Verifica al final que `build/src/MUSIChydro` exista y sea ejecutable.

Al terminar, dile a los scripts de este repo dónde quedó instalado:

```bash
export MUSIC_DIR=$HOME/Software/MUSIC     # o la ruta que hayas elegido
```

(Agrégalo a tu `.bashrc` si vas a usarlo seguido. Si no lo exportas,
`run_music.sh` y `slurm_music.sh` asumen `$HOME/Software/MUSIC` por
defecto.)

---

## 3. Correr localmente (un evento)

Este repo trae de ejemplo una condición inicial IP-Glasma real
(`ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat`, Au+Au 200 GeV) y su config
(`configs/200GeV_hotQCD.inp`), listos para usar:

```bash
./run_pipeline.sh mi_corrida configs/200GeV_hotQCD.inp \
    ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat
```

Esto corre modo 2 (evolución hidro) → modo 3 (espectros térmicos) → modo 4
(espectros + decaimientos), uno tras otro, esperando a que cada paso
termine. Tarda en total ~45-60 min en una máquina normal (el modo 2 domina
el tiempo).

Salida en `runs/mi_corrida/`:

- `run_mode2.log`, `run_mode3.log`, `run_mode4.log` — progreso de cada paso
- `particleInformation.dat` / `yptphiSpectra.dat` — espectros térmicos (modo 3)
- `FparticleInformation.dat` / `FyptphiSpectra.dat` — espectros con
  decaimientos de resonancias (modo 4) — estos son los que se comparan con
  datos experimentales

Si solo quieres un paso específico (por ejemplo, solo la evolución hidro):

```bash
./run_music.sh mi_corrida configs/200GeV_hotQCD.inp \
    ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat 2   # 2=evolución, 3=espectros, 4=decaimientos
```

---

## 4. Bi+Bi a 9 GeV (NICA) — condición inicial 3D MC-Glauber

Para energías bajas (régimen de NICA) la condición inicial IP-Glasma de la
sección 3 no aplica: hace falta una condición inicial 3D con número
bariónico neto y evolución no boost-invariant. Este repo agrega el
pipeline para eso, usando
[3dMCGlauber](https://github.com/chunshen1987/3dMCGlauber) (mismo autor que
MUSIC) para generar las condiciones iniciales que lee
`Initial_profile 13`.

```bash
./install_3dmcglauber.sh                       # instala en $HOME/Software/3dMCGlauber
export GLAUBER_DIR=$HOME/Software/3dMCGlauber   # o la ruta que hayas elegido

./generate_bibi_ic.sh initial/BiBi_9GeV_event0.dat
./run_music.sh mi_corrida_bibi configs/BiBi_9GeV.inp initial/BiBi_9GeV_event0.dat
```

Qué hace cada pieza:

- **`install_3dmcglauber.sh`** — clona y compila 3dMCGlauber, y aplica
  `patches/3dmcglauber_add_bi_nucleus.patch`: el núcleo de Bi-209 (R=6.96 fm,
  a=0.537 fm, convención [arXiv:2401.00619](https://arxiv.org/abs/2401.00619))
  no viene de fábrica en 3dMCGlauber.
- **`generate_bibi_ic.sh`** — corre `3dMCGlb.e` con
  `glauber_configs/BiBi_9GeV.input` (√s_NN=9 GeV, `b_max 2` fm → solo
  colisiones centrales) y **recorta el archivo de salida a 25 columnas**.
  Esto es necesario porque la versión instalada de 3dMCGlauber escribe 30
  columnas (incluye campos nuevos de transporte de carga eléctrica que
  MUSIC `public_stable` todavía no lee) — sin el recorte, MUSIC aborta con
  `the format of file...is wrong`.
- **`configs/BiBi_9GeV.inp`** — usa `Initial_profile 13`,
  `EOS_to_use 14` (`neos_bqs`, EOS de red a μ_B finito — viene de fábrica
  con MUSIC, no requiere parches), `Include_Rhob_Yes_1_No_0 1` y
  `boost_invariant 0`. La resolución de grilla y el tiempo de evolución
  están reducidos a propósito (smoke test, minutos en una laptop); para
  producción real, sube esos valores a los de
  `example_inputfiles/3D_dynamical/music_input_mode_2` de MUSIC y corre en
  cluster (§5).

**Validado:** este pipeline se corrió end-to-end (evento Npart=393,
b=0.32 fm → evolución hidro modo 2) y produjo una superficie de
freeze-out no vacía, con número bariónico neto y temperatura evolucionando
de forma físicamente consistente. **No validado todavía:** los modos 3/4
(espectros térmicos y decaimientos) con `EOS_to_use 14` — probablemente
funcionen igual que con hotQCD, pero no se ha corrido esa parte.

### ¿Cuándo poner μ_B ≠ 0? (`Include_Rhob_Yes_1_No_0`)

Si en el futuro se corren otras especies y/o energías, el criterio para
decidir `Include_Rhob_Yes_1_No_0` no es "por defecto" sino que depende de
la energía de colisión:

- **Energías altas (200 GeV y más, ej. Au+Au/Pb+Pb top RHIC/LHC):**
  dejar `Include_Rhob_Yes_1_No_0 0`. La transparencia bariónica es casi
  total (los núcleos se atraviesan), el μ_B a midrapidity es pequeño
  (~20-25 MeV según extracciones de razones p/p̄ de STAR/PHENIX), y la
  condición inicial estándar ahí (IP-Glasma boost-invariante, §3) **no
  trae corriente bariónica neta** — solo densidad de energía. Prender la
  bandera sin una IC que aporte bariones no serviría de nada (μ_B
  seguiría siendo 0 en la práctica); para tener μ_B real a estas energías
  haría falta además una IC 3D con "dynamical initialization"/stopping
  (ej. 3dMCGlauber), no solo el flag.
- **Energías bajas (régimen NICA/BES, ej. Bi+Bi 9 GeV, Au+Au ≲20 GeV):**
  usar `Include_Rhob_Yes_1_No_0 1` — **obligatorio**. El frenado
  bariónico es enorme y el sistema queda bariónicamente denso (μ_B
  finito, del orden de cientos de MeV), que es justo lo que estas
  energías están pensadas para explorar. Esto solo tiene sentido físico
  si además:
  - la IC es 3D con bariones netos (3dMCGlauber, `Initial_profile 13`,
    como en esta sección), y
  - la EOS depende de μ_B (`EOS_to_use 14`, `neos_bqs`, o equivalente —
    **no** usar una EOS a μ_B=0 como `EOS_to_use 2`/hotQCD con el flag
    prendido, sería inconsistente).

  `turn_on_baryon_diffusion 0` (como está en `BiBi_9GeV.inp`) es válido
  como primera aproximación (evolución bariónica ideal, sin difusión). Si
  más adelante se quiere afinar la forma de la distribución de bariones
  netos en rapidez (ej. comparar contra el pico de protones netos de STAR
  BES), ese es el siguiente parámetro a activar, con un
  `kappa_coefficient` no nulo.

---

## 5. Correr en paralelo (cluster SLURM)

```bash
./submit_jobs.sh 10 configs/200GeV_hotQCD.inp \
    ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat mi_prefijo
```

Envía 10 jobs independientes a SLURM (`mi_prefijo_ev01` … `mi_prefijo_ev10`),
cada uno corriendo el pipeline completo (2→3→4) vía `slurm_music.sh`.
Corren en paralelo automáticamente si el cluster tiene cupo — no hace falta
orquestar nada más.

**Nota sobre "eventos":** todos usan la misma condición inicial IP-Glasma
(la evolución hidro de MUSIC es determinista, no hay muestreo Monte Carlo
en los modos 2/3/4). Para estadística real por evento se necesitan
condiciones iniciales IP-Glasma distintas, o un pipeline de muestreo
Monte Carlo aparte (p. ej. iS3D) sobre la superficie de freeze-out.

**Antes de tu primer envío, revisa la partición de tu cluster:**

```bash
sinfo -o "%P %l"        # lista particiones y su límite de tiempo
```

`slurm_music.sh` no fija una partición a propósito (los nombres varían
entre clusters). Si tu sitio no tiene una partición por defecto, pásala en
la llamada a `sbatch` (edita `submit_jobs.sh` o llama a `slurm_music.sh`
directo):

```bash
sbatch --partition=<nombre> --job-name=ev01 slurm_music.sh \
    configs/200GeV_hotQCD.inp ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat
```

Monitorea con:

```bash
squeue -u $USER
tail -f runs/mi_prefijo_ev01/music.log
```

**Para comparar configs distintos en paralelo** (por ejemplo, dos valores
de `s_factor`, o dos EOS si tienes una versión modificada de MUSIC),
lánzalos como jobs separados con nombres distintos — es el mismo
mecanismo, solo con `configs/` diferentes:

```bash
mkdir -p runs/corridaA runs/corridaB
sbatch --job-name=corridaA slurm_music.sh configs/configA.inp ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat
sbatch --job-name=corridaB slurm_music.sh configs/configB.inp ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat
```

(El `mkdir -p runs/<nombre>` antes de cada `sbatch` es necesario: SLURM
abre el archivo de log en cuanto el job arranca, antes de que el propio
script cree su directorio de salida.)

---

## 6. Revisar yields

Una vez que una corrida terminó (existen `FparticleInformation.dat` y
`FyptphiSpectra.dat` en su `runs/<nombre>/`):

```bash
python3 ptdist.py runs/mi_corrida
```

Imprime una tabla de `dN/dy` térmico vs. con decaimientos para π±, K±, p,
p̄, el `dN_ch/dη` total comparado contra PHENIX 0-5% (680), el
`decay_factor` medido de esa corrida (post-decaimiento / térmico, no un
valor asumido), y el `s_factor` real usado (leído automáticamente de
`runs/mi_corrida/music_input`, no hay que pasarlo a mano). Guarda además
una gráfica en `runs/mi_corrida/ptdist_thermal_vs_decay.png`.

Al final imprime el punto de calibración ya formateado para
`s_factor_calibrate.py` (§7), listo para copiar/pegar:

```
Punto de calibración para s_factor_calibrate.py:
  --decay-factor 2.175 --points 0.045:454.0
```

**Sin `music_input` en el run_dir** (por ejemplo, si copiaste solo los
`.dat` sin el resto de la corrida): `ptdist.py` avisa con una advertencia
y omite el `s_factor` y el punto de calibración, pero el resto de la
tabla se calcula igual.

**Sin display (cluster por SSH sin X forwarding):** `ptdist.py` detecta
automáticamente si no hay `$DISPLAY` y usa un backend no interactivo
(guarda el PNG sin intentar abrir una ventana).

---

## 7. Calibrar `s_factor`

### Por qué hay que ajustarlo (físicamente)

`s_factor` reescala la densidad de energía inicial de IP-Glasma
(`ε_actual = s_factor × ε_IPGlasma`) antes de que arranque la evolución
hidrodinámica. Hace falta ajustarlo porque esa ε no viene con una
normalización fijada de primeros principios:

- IP-Glasma calcula ε a partir de la evolución clásica de campos de
  gluones (CGC) hasta un tiempo muy temprano (τ₀~0.4 fm/c) — el sistema
  todavía no está termalizado, son campos clásicos, no un fluido en
  equilibrio local.
- La normalización absoluta de ese cálculo depende de parámetros no
  fijados por primeros principios (acoplamiento, regularización IR,
  ajuste a datos de DIS extrapolado a cinemática de iones pesados), y de
  qué tan eficiente es la termalización temprana — algo que el cálculo de
  IP-Glasma no predice por sí solo.
- La fracción de esa energía "pre-equilibrio" que termina como energía
  térmica del fluido depende además de la EOS con la que evoluciones
  (`EOS_to_use`) — por eso `hotQCD` y `2DTExS` necesitan un `s_factor`
  distinto aunque arranquen del mismo perfil crudo de IP-Glasma.

Por esto la normalización global de la multiplicidad final (`dN_ch/dη`) se
deja como parámetro libre y se fija comparando contra un dato de
referencia (multiplicidad experimental medida, o una predicción de otro
modelo como UrQMD si no hay datos, p. ej. en NICA). Lo que el modelo sí
predice y **no** se toca con `s_factor` son las formas: v_n, fluctuaciones
evento a evento, dependencia con centralidad.

### Cómo se hace el ajuste: `s_factor_calibrate.py`

0. **`decay_factor` se mide, no se asume.** Hace falta al menos una
   corrida completa (modo 2→3→4) de la energía/EOS que te interesa para
   medirlo — no se puede sacar de una corrida modo 2→3-only, porque
   necesita los archivos `F*` post-decaimiento. Si ya tienes una corrida
   completa, `python3 ptdist.py runs/mi_corrida` (§6) te da el
   `decay_factor` y el primer punto de calibración ya listos. Si vas a
   probar un sistema/energía nuevo (p. ej. Bi+Bi a 9 GeV, sin datos
   experimentales de referencia), corre el pipeline completo una vez con
   cualquier `s_factor` razonable de partida solo para medir su
   `decay_factor` propio — no lo reutilices del run de otra energía/EOS
   sin pensarlo (a μ_B finito la química de freeze-out es distinta, así
   que el `decay_factor` de 200 GeV no aplica directo a NICA).

1. Corre **solo modo 2→3** (sin modo 4, para no gastar tiempo en
   decaimientos) con un `s_factor` de prueba:

   ```bash
   ./run_music.sh mi_corrida configs/mi_config.inp \
       ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat 2
   ./run_music.sh mi_corrida configs/mi_config.inp \
       ipglasma/200GeV/epsilon-u-Hydro-t0.4-0.dat 3
   ```

   y mide el `dN_ch/dη` térmico total (suma de especies cargadas de
   `particleInformation.dat`/`yptphiSpectra.dat`, mismo método que usa
   `ptdist.py`).

2. Con uno o más puntos `(s_factor, dN_ch/dη_térmico)` medidos así, pide
   el siguiente `s_factor` sugerido:

   ```bash
   python3 s_factor_calibrate.py --target-exp 680 --decay-factor 1.993 \
       --points 0.045:171.5 0.176:298.4
   ```

   - `--target-exp`: multiplicidad experimental (o de referencia) para
     esa energía/sistema/centralidad.
   - `--decay-factor`: razón `dN_ch/dη` post-decaimiento / térmico
     (medida en una corrida completa previa con modo 4; ~2.0 típico con
     el freeze-out de este repo).
   - `--points`: pares `s_factor:dN_ch/dη_térmico` medidos.

   Con **un solo punto** el script asume el exponente ideal `n=3/4`
   (`dN_ch/dη ∝ s_factor^(3/4)`, exacto solo para una EOS conforme sin
   viscosidad). Con **dos o más puntos** ajusta el exponente real `n` por
   regresión log-log en vez de asumirlo — necesario para EOS viscosas y
   no conformes como `hotQCD`/`2DTExS`, donde `n` se desvía de 3/4.

3. Itera: corre modo 2→3 con el `s_factor` sugerido, mide de nuevo, y
   repite hasta que el resultado térmico esté dentro de tu tolerancia del
   target. Solo hasta el final, con el `s_factor` ya calibrado, corre el
   modo 4 completo para comparar contra datos experimentales.

---

## 8. Problemas conocidos

Esta sección junta **todos los bugs de instalación/ejecución encontrados hasta
ahora en la cadena completa** (MUSIC + IP-Glasma + 3dMCGlauber + iS3D + UrQMD +
CRAB3/`be`), recolectados a lo largo de las campañas Bi+Bi/AuAu en
[[music]], [[music/c3]] y el repo [[urqmd]]. La idea es que una instalación
nueva (laptop o cluster) pueda aplicar todos estos fixes de una vez en vez de
redescubrirlos uno por uno. Los fixes de MUSIC, 3dMCGlauber, iS3D y UrQMD ya
están vendorizados en este repo (`patches/`, `install_*.sh`,
`apply_music_fixes.sh`) — clonar y correr los `install_*.sh` los aplica
automáticamente. `be/` (Python C2/C3) sigue viviendo en el repo `music` y sus
fixes se listan aquí solo para referencia; hay que aplicarlos a mano en ese
checkout. Ver también §9 para el flujo completo de instalación desde cero y
el chequeo de sanidad end-to-end.

### 8.1 MUSIC (core)

| Síntoma                                                                                | Causa                                                                         | Fix                                                                                         |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `Could NOT find GSL` en cmake, o comportamiento raro más adelante                    | falta`libgsl-dev` (headers), aunque `libgsl28` sí esté instalado        | `sudo apt install libgsl-dev`, luego borra `build/` y recompila desde cero              |
| `sbatch: error` o el job falla instantáneo con `mkdir: Permission denied`          | el directorio de`--output` no existía antes de enviar el job               | `mkdir -p runs/<nombre>` antes de `sbatch` (ver §5)                                    |
| Job SLURM falla de inmediato sin log útil                                              | partición inexistente en tu cluster                                          | revisa`sinfo -o "%P"` y usa `--partition=<la_tuya>`                                     |
| Crash GSL`x values must be strictly increasing` en `interp.c`                       | `min_pt` en 0 exacto                                                        | usar`min_pt 0.01` (ya está así en `configs/200GeV_hotQCD.inp`)                        |
| MUSIC no encuentra`./outputs` en modo 3                                               | falta crear el directorio antes                                               | manejado automáticamente por`run_music.sh`/`slurm_music.sh`                            |
| `the format of file...is wrong` leyendo `strings_event_N.dat` (pipeline Bi+Bi, §4) | 3dMCGlauber escribe 30 columnas, MUSIC`public_stable` espera máx. 25       | usar`generate_bibi_ic.sh` (ya hace el recorte) en vez de la salida cruda de `3dMCGlb.e` |
| `Can not open EOS files: ./EOS/...` corriendo Bi+Bi (§4)                             | MUSIC busca`./EOS` relativo al directorio de la corrida, no a `MUSIC_DIR` | manejado automáticamente por`run_music.sh` (symlinks `EOS/` y `tables/`)             |
| `free(particleList)` cuelga en corridas grandes de `freeze_pseudo.cpp`            | bug conocido de MUSIC upstream en la limpieza de memoria al final del freeze-out | `./apply_music_fixes.sh $MUSIC_DIR` (este repo, `patches/freeze_pseudo.patch`) — elimina el `free()` problemático |
| `EOS_to_use 20` (2DTExS) no reconocido / rechazado al leer el input               | `read_in_parameters.cpp` de MUSIC stock solo acepta EOS ≤ 14 de fábrica        | incluido en `./apply_2dtexs.sh $MUSIC_DIR` (ver fila siguiente) |
| 2DTExS calibrado pero MUSIC no encuentra `EOS/2DTExS/EoS2DTExS.dat`, o `eos.cpp`/`CMakeLists.txt` de MUSIC stock no registran la EOS 20 | antes la EOS 2DTExS (código + tabla de 41 MB) vivía solo en el repo `music` (`music_patches/`), que a su vez la copiaba desde `epos/src/MSt/EoS2DTExS.dat` — un checkout sin `epos/` al lado dejaba `EOS_to_use 20` roto en silencio | **ya vendorizado en este repo** (`patches/2dtexs/`: `eos_2dtexs.{h,cpp}`, `eos.cpp`, `CMakeLists.txt` y la tabla `EoS2DTExS.dat`, 41 MB, checksum verificado contra el original de `epos/`): `./apply_2dtexs.sh $MUSIC_DIR` instala todo (archivos nuevos + reemplazo de `eos.cpp`/`CMakeLists.txt` + los dos parches anteriores + la tabla) y recompila en un solo paso — ya no depende de un checkout de `epos/` aparte |
| `s_factor` calibrado a un EOS/energía se reutiliza sin re-medir en otro EOS/energía y el resultado queda muy lejos del target | `s_factor`/`decay_factor` NO son transferibles entre EOS o energías (química de freeze-out distinta, sobre todo a μ_B finito) | siempre medir `decay_factor` con una corrida completa (modo 2→3→4) del EOS/energía nuevo antes de calibrar (§7, paso 0) |

### 8.2 Condiciones iniciales — IP-Glasma / 3dMCGlauber

| Síntoma                                                                                   | Causa                                                                                                    | Fix                                                                                                         |
| ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| IP-Glasma parece colgarse / "se le acaba la memoria" a 24-64-195 GB sin terminar          | no es OOM real: es un **loop infinito** porque falta `nucleusConfigurations/Au197.bin.in` (o el núcleo que corresponda) | descargar el archivo `.bin.in` del núcleo desde el repo `glaubernucleusconfigs` (bitbucket) antes de correr; con el archivo presente el uso real es ~1.2 GB y tarda ~8 min |
| Superficie de freeze-out con τ equivocado / nombre de archivo distinto al esperado por los scripts downstream | `maxtime` en el input de IP-Glasma debe ser **0.4**, no 0.6 (0.6 genera un archivo con τ=0.6 en vez de τ=0.4); además builds nuevos de IP-Glasma renombraron la salida a `epsilon-u-Hydro-TauHydro-0.dat` (antes `epsilon-u-Hydro-t0.4-0.dat`) | fijar `maxtime 0.4` explícitamente; si el build es reciente, actualizar cualquier script que busque el nombre viejo del archivo |
| `the format of file...is wrong` leyendo `strings_event_N.dat` | 3dMCGlauber (build instalado) escribe 30 columnas (incluye campos de transporte de carga eléctrica), MUSIC `public_stable` espera máx. 25 | usar `generate_bibi_ic.sh` (recorta a 25 columnas) — ver §4 |
| Reproducción de una IC 200 GeV con Qs table reciclada a otra energía no da Npart idéntico | tablas Qs de IP-Glasma están tabuladas por energía; reusar la de 200 GeV a falta de una propia para la energía nueva introduce un sesgo pequeño (~2%) en Npart | documentar explícitamente cuándo se está reciclando una tabla Qs de otra energía; no asumir reproducibilidad exacta |
| Núcleo Bi-209 no disponible en 3dMCGlauber de fábrica | 3dMCGlauber stock no trae la parametrización de Bi-209 (R=6.96 fm, a=0.537 fm, convención arXiv:2401.00619) | aplicar `patches/3dmcglauber_add_bi_nucleus.patch` de este repo vía `install_3dmcglauber.sh` |

### 8.3 iS3D (muestreo de partículas sobre la superficie de freeze-out)

| Síntoma                                                                                              | Causa                                                                                                                                                                                                             | Fix                                                                                                                                                        |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **p̄/p, n̄/n, Λ̄/Λ muy asimétricos incluso a μ_B≈0** (p̄/p ~2.4 en vez de ~1), K/π inflado, bariones sistemáticamente bajos | **Bug crítico en `deltafReader.cpp`**: `Deltaf_Data::calculate_bilinear` indexa la tabla δf como `f_data[iT][imuB]`, pero el loader la guarda como `f_data[iB][iT]` (ejes transpuestos) — con `include_baryon 1`, **todo** coeficiente δf (F, G, betabulk, betaV, betapi) se lee de la celda equivocada de la tabla (p. ej. G=1.65 en vez de 0 a μ_B=0); puede además leer fuera de rango si `iT>80`. El camino `include_baryon 0` (spline cúbico) NO está afectado — pura mesones (π) prácticamente no cambian | `./install_is3d.sh` (este repo) aplica `patches/iS3D_deltafReader_bilinear_fix.patch` automáticamente al clonar — **verificar que cualquier instalación nueva de iS3D lo traiga antes de usarla para física con bariones** |
| Workaround rápido si no se puede recompilar de inmediato | mismo bug de arriba | poner `include_baryon 0` en `iS3D_parameters.dat` (fuerza el camino spline, no afectado) — solo válido para superficies con μ_B≈0 |
| Superficie boost-invariant (2D) da resultados raros con el reader por defecto | iS3D necesita `mode=8` explícitamente para leer correctamente superficies 2D/boost-invariant en vez de 3+1D | fijar `mode 8` en la config de iS3D cuando la superficie viene de una corrida boost-invariant (confirmar con T_avg/μ_B,avg físicamente razonables tras correr) |

### 8.4 UrQMD (afterburner / cascada)

| Síntoma                                                                                     | Causa                                                                                                                                                    | Fix                                                                                                                                    |
| --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Falla de compilación con gfortran ≥ 10 (`Type mismatch`, `Rank mismatch`, etc.)             | UrQMD 3.4 es Fortran legacy; gfortran ≥10 endureció el chequeo de tipos/argumentos por defecto                                                             | `./install_urqmd.sh` (este repo) descarga el tar de `urqmd.org` y aplica `patches/urqmd_Linux.mk.patch` automáticamente — agrega `-std=legacy -fallow-argument-mismatch -ffixed-line-length-none` antes de compilar |
| `tar: This does not look like a tar archive` al correr `install_urqmd.sh` (descarga "exitosa") | **`urqmd.org` ya no sirve `urqmd-3.4.tar` directo**: el dominio entero redirige (301→301→200) a la página personal del mantenedor en `itp.uni-frankfurt.de`, que hoy solo publica **UrQMD 4.0** (`.tar.gz`); `curl -f` no detecta el problema porque la página de aterrizaje responde HTTP 200, no 404 — descarga HTML en vez del tar | `install_urqmd.sh` ahora valida el archivo descargado con `tar tf` y falla con mensaje claro en vez de dejar que `tar xf` falle críptico (fix aplicado 2026-10-01). El tar 3.4 ya no es descargable automáticamente: conseguirlo a mano (pedirlo a `urqmd@urqmd.org`) o copiarlo desde un checkout que ya lo tenga — hay una copia verificada en `doramilaje:~/github/urqmd/urqmd-3.4.tar` (213MB, no vendorizable en este repo por la licencia de urqmd.org, igual que la tabla 2DTExS antes de ser vendorizada) — y colocarlo en `<URQMD_DIR>/../urqmd-3.4.tar` antes de correr el script (lo detecta y se salta la descarga) |
| `f19` sale vacío (0 eventos) aunque el input lo pide explícitamente                        | **la bandera está invertida**: listar una unidad de salida (`fXX`) en el input de UrQMD la **suprime** (`bfXX=.true.` → no escribe), no la habilita       | para quedarte solo con `f19`, listar las que **no** quieres en el input: `f13 f14 f15 f16 f18 f20` (deja f19/f20 según convenga) — NO listar `f19` directamente |
| Pérdida de eventos por chunk (3–43% según config) en el afterburner, atribuida por error a OOM | UrQMD 3.4 aborta con `stop 137` desde `anndec.f:285` (`anndex(dec)`, ityp 139, m=2.112 GeV, sin canal de decaimiento — todas las probabilidades de rama en cero); es un exit code propio de UrQMD, NO memoria (algún comentario en scripts SLURM que dice "OOM" está equivocado) | reconocer `stop 137` como crash interno de UrQMD, no OOM; mitigar corriendo en chunks pequeños con reintento/skip del evento que crashea en vez de perder el resto del chunk (no implementado aún como fix automático) |
| Radios/λ de HBT con un dip artificial cerca de q≈30 MeV/c | conversión `f14`→f19-nativo introducía un artefacto (Bug #1) | usar la salida `f19` nativa de UrQMD directamente, no convertir desde `f14` |
| Posiciones de freeze-out (`frr*`) en cero/no inicializadas en el provenance del afterburner | el wrapper del afterburner nunca sembraba `frr*` (Bug #2) — parche aplicado, pero **no** retro-aplicado a corridas viejas (p. ej. AuAu200) | confirmar que cualquier wrapper nuevo de afterburner siembra `frr*`; no reutilizar output viejo generado antes del fix para física de posiciones (cτ, core/halo) |
| `f20`/`f19` freeze-out positions parecen distintas a las de un `.f14` convertido | `f20`'s `osc99_event` (dump final) escribe `frrx/frry/frrz/frr0` (coordenadas reales de freeze-out); `.f14`'s `file14out` escribe `r0/rx/ry/rz` (posiciones free-streamed) — **no son la misma cantidad**, confirmado leyendo `output.f` | usar siempre `f19`/`f20` nativos para cualquier análisis que dependa de la posición real de freeze-out, nunca derivarla de `.f14` |

### 8.5 CRAB3 / `be` (correlaciones C2/C3)

| Síntoma                                                                                                | Causa                                                                                                                                                                 | Fix                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CRAB3 aborta: `Increase NPHASEMAX in crab.cpp`                                                          | `crab.cpp`'s `#define NPHASEMAX 20000000` es un arreglo **estático de punteros** (`NBMAX=1`) que guarda TODOS los π+ de TODOS los eventos pooled del run; campañas grandes (~1M eventos) lo superan | `./install_crab3.sh` (este repo) aplica `patches/crab3_increase_nphasemax.patch` (sube la constante a `200000000`) automáticamente — al ser un arreglo de punteros, el costo real de memoria (BSS) crece solo con las entradas usadas, no con el tamaño declarado |
| `crab.e` segfault al arrancar en un directorio nuevo                                                    | escribe resultados vía `fopen()` sin checar que exista `results/`                                                                                                    | `mkdir -p results/` antes de correr `crab.e` (o parchar para crear el directorio si falta)                                                             |
| Stack overflow / crash silencioso con `NMAX_FOR_MIXING` grande | `crab_main.cpp` declara los arreglos de `MIXED_PAIRS_FOR_DENOM` en la pila | `./install_crab3.sh` (este repo) aplica `patches/crab3_nmax_mixing_heap_fix.patch` — los mueve al heap |
| `--mem` estático del job SLURM de CRAB3 se queda corto (OOM) o sobra por mucho                          | el multiplicity real (π+/evento) solo se conoce corriendo el afterburner; `#SBATCH --mem=` se fija estáticamente al hacer `sbatch`, no se puede calcular dentro del mismo script | insertar un job SLURM intermedio "autosize" (muestrea un shard real, proyecta el total, aplica margen) entre el afterburner y el job real de CRAB3/`be`; ver `slurm_*_crab3_autosize.sh` en `music/BiBi_cascade_*GeV/*/` |
| `scontrol update JobId=<id> MinMemoryNode=<valor>` falla con `Invalid MinMemoryNode value`            | el campo espera un entero plano en MB, no un sufijo `G`                                                                                                              | usar MB (`MinMemoryNode=32768`), no `32G`                                                                                                               |
| Comparar contra un `crab3_qinv*.dat` da un factor ~2 de diferencia en R                                | algunos headers de referencia CRAB3 dicen `k=(p2-p1)/2:` (reducido) y otros `k=(p2-p1):` (Qinv completo) — **no es una convención fija por proyecto**, cambia por build/config | siempre leer el header del `.dat` de referencia antes de comparar, nunca asumir la convención |
| `be/kernels.py` (o cualquier driver que lo llame directo) da `C2≈1.000` plano, sin error, con eje 0–50 GeV en vez de 0–50 MeV | `be/kernels.py` trabaja en GeV/fm con momento reducido `k=Qinv/2`; los wrappers `compute_c2_crab`/`compute_c2_batched` convierten `maxmom_mev/1000` internamente — un driver que llama el kernel numba directo **no** hace esa conversión, y el fallo es silencioso (el job termina con exit 0 y arrays con la forma correcta, solo el contenido está mal) | convertir siempre `maxmom_gev = maxmom_mev / 1000.0` antes de binear si se llama `kernels.py` directo; validar contra el estimador pool-random como cross-check ([[reference_be_kernels_units_gotcha]]) |
| `plotting.py`'s `plot_c2()` crashea con `yerr` negativo | errorbarrea la curva de referencia sin filtrar el sentinel `-1` que algunos `.dat` usan para "sin datos" en un bin | enmascarar `ref_err >= 0` antes de graficar (ya corregido en `be/plotting.py`) |
| C3 con symmetrización BE incorrecta (usar `weight = w12*w13*w23`) | producto de pesos pairwise NO es la simetrización genuina de bosones idénticos para N=3; hay que sumar sobre las 3!=6 permutaciones de S_3 | usar `kernels.triplet_be_weight()` (suma las 6 fases de permutación directo de los cuadrivectores) |
| Job de `c3.py`/`c2.py` con `n_triplets`/`n_pairs` grande hace OOM/thrashea la máquina | la implementación original retenía CADA par/triplet muestreado en memoria (RSS escala linealmente: 100M triplets→24GB, 400M→88GB; `n_pairs=2e8`→~30GB) | usar el refactor de reservoir acotado (`reservoir_size`, ya presente en `be/c2.py`/`c3.py`) — RSS queda acotado independiente de `n_pairs`/`n_triplets`; además correr bajo `ulimit -v` como cinturón de seguridad en jobs grandes |
| `compute_c3_diagonal_crab` da una meseta sospechosamente baja (~0.5-0.6) a k grande | el reservoir del denominador mixto se llenaba SOLO con triplets ya aceptados por el corte diagonal — sesga la referencia mixta | llenar el reservoir sin condición desde todo intento crudo; aplicar el corte diagonal únicamente al binear numerador/denominador |
| Script SLURM falla con `No such file or directory` buscando otro script "al lado" (`estimate_piplus.py`, etc.) | usar `$(dirname "$0")`/`BASH_SOURCE` para ubicar el propio directorio no funciona bajo SLURM: el script se copia primero a un directorio spool antes de ejecutarse | hardcodear `SCRIPT_DIR` como ruta absoluta en vez de derivarla en runtime (recurrió 2 veces, en las campañas 5.8 y 7.7 GeV) |
| Un `glob`/expansión de muchos archivos de shards falla con `Argument list too long` | expansión de shell excede `ARG_MAX` con miles de archivos de shards | usar `find ... -exec` o iterar leyendo una lista desde archivo, no un glob directo en la línea de comandos |

---

## 9. Cadena completa (MUSIC → 3dMCGlauber → UrQMD → iS3D → CRAB3) y chequeo de yield

Con solo clonar este repo se puede instalar la cadena completa y correr un
chequeo de sanidad end-to-end, sin tener que traer nada de los repos
`music`/`urqmd`:

```bash
git clone https://github.com/isadoji/music-install.git
cd music-install

./install_music.sh                 && export MUSIC_DIR=$HOME/Software/MUSIC
./apply_music_fixes.sh $MUSIC_DIR  # freeze_pseudo + read_in_parameters (§8.1)

./install_3dmcglauber.sh           && export GLAUBER_DIR=$HOME/Software/3dMCGlauber
./install_urqmd.sh                 && export URQMD_DIR=$HOME/Software/urqmd-3.4
./install_is3d.sh                  && export IS3D_DIR=$HOME/Software/iS3D
./install_crab3.sh                 && export CRAB3_DIR=$HOME/Software/crab3
```

Cada `install_*.sh` descarga/clona la fuente correspondiente, aplica los
parches necesarios de `patches/` (ver §8 para el detalle de cada bug) y
verifica que el binario final quede compilado y ejecutable.

**Antes de invertir tiempo de cómputo en la cadena hidro completa**, se
recomienda validar la instalación de UrQMD reproduciendo un yield de
referencia con una cascada **standalone** (sin MUSIC/iS3D — UrQMD puro),
que es independiente de cualquier suposición hidrodinámica:

```bash
# opción sin SLURM (una sola máquina, usa todos los cores):
./scripts/run_urqmd_cascade.sh 100000 runs/urqmd_check

# opción con SLURM:
mkdir -p urqmd_cascade_logs
sbatch --array=0-59 scripts/slurm_urqmd_cascade_array.sh \
    100000 runs/urqmd_check 90000

# en ambos casos, al terminar:
python3 scripts/check_yield_urqmd.py runs/urqmd_check --target 85.75
```

`check_yield_urqmd.py` calcula `dN(π+)/dy` en `|y|<0.5` sobre los `.f19`
(OSCAR1997A nativo) producidos y lo compara contra el valor de referencia
**85.75** (Bi+Bi central, √s_NN=5.8 GeV, medido con 66,670 eventos —
Ayala et al. [arXiv:2401.00619](https://arxiv.org/abs/2401.00619) Tabla 1).
Una discrepancia grande indica que algún parche de UrQMD (semántica de
banderas `fXX`, o el parche de compilación de gfortran) no se aplicó
correctamente, antes de gastar cómputo en la cadena hidro completa.

La guía paso a paso completa, con cada bug de instalación ya resuelto
integrado en el orden de ejecución (incluyendo los de `iS3D`/UrQMD/CRAB3/`be`
de §8 que no tienen su propio `install_*.sh` en este repo), está en
[`install_xook_fullchain.tex`](install_xook_fullchain.tex) /
[`install_xook_fullchain.pdf`](install_xook_fullchain.pdf) — escrita
originalmente para un checkout nuevo en `xook`, pero aplica a cualquier
máquina nueva.
