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
p̄, el `dN_ch/dη` total comparado contra PHENIX 0-5% (680), y un
`s_factor` sugerido si el rendimiento no coincide. Guarda además una
gráfica en `runs/mi_corrida/ptdist_thermal_vs_decay.png`.

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

## Problemas conocidos

| Síntoma                                                                                | Causa                                                                         | Fix                                                                                         |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `Could NOT find GSL` en cmake, o comportamiento raro más adelante                    | falta`libgsl-dev` (headers), aunque `libgsl28` sí esté instalado        | `sudo apt install libgsl-dev`, luego borra `build/` y recompila desde cero              |
| `sbatch: error` o el job falla instantáneo con `mkdir: Permission denied`          | el directorio de`--output` no existía antes de enviar el job               | `mkdir -p runs/<nombre>` antes de `sbatch` (ver §5)                                    |
| Job SLURM falla de inmediato sin log útil                                              | partición inexistente en tu cluster                                          | revisa`sinfo -o "%P"` y usa `--partition=<la_tuya>`                                     |
| Crash GSL`x values must be strictly increasing` en `interp.c`                       | `min_pt` en 0 exacto                                                        | usar`min_pt 0.01` (ya está así en `configs/200GeV_hotQCD.inp`)                        |
| MUSIC no encuentra`./outputs` en modo 3                                               | falta crear el directorio antes                                               | manejado automáticamente por`run_music.sh`/`slurm_music.sh`                            |
| `the format of file...is wrong` leyendo `strings_event_N.dat` (pipeline Bi+Bi, §4) | 3dMCGlauber escribe 30 columnas, MUSIC`public_stable` espera máx. 25       | usar`generate_bibi_ic.sh` (ya hace el recorte) en vez de la salida cruda de `3dMCGlb.e` |
| `Can not open EOS files: ./EOS/...` corriendo Bi+Bi (§4)                             | MUSIC busca`./EOS` relativo al directorio de la corrida, no a `MUSIC_DIR` | manejado automáticamente por`run_music.sh` (symlinks `EOS/` y `tables/`)             |
