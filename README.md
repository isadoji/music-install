# MUSIC install & run

Guía y scripts mínimos para instalar [MUSIC](https://github.com/MUSIC-fluid/MUSIC)
(EOS estándar, `EOS_to_use 9` — hotQCD lattice, la que trae MUSIC de
fábrica), correrlo localmente, correrlo en paralelo en un cluster SLURM, y
revisar los yields de partículas resultantes. Pensada para que cualquier
persona pueda seguirla sin depender de rutas o de un usuario en particular.

No modifica la ecuación de estado ni el código de MUSIC — es solo el flujo
de instalación + ejecución + análisis básico.

---

## 1. Prerrequisitos

| Paquete    | Para qué                          | Instalación (Ubuntu/Debian)     |
| ---------- | ---------------------------------- | -------------------------------- |
| g++        | compilar MUSIC                     | incluido en `build-essential`   |
| cmake      | generar el build                   | `sudo apt install cmake`        |
| git        | clonar los repos                   | `sudo apt install git`          |
| libgsl-dev | interpolación (MUSIC lo requiere)  | `sudo apt install libgsl-dev`   |
| Python 3   | análisis de yields (`ptdist.py`)   | `sudo apt install python3 python3-numpy python3-matplotlib` |

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

## 4. Correr en paralelo (cluster SLURM)

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

## 5. Revisar yields

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

## Problemas conocidos

| Síntoma | Causa | Fix |
| --- | --- | --- |
| `Could NOT find GSL` en cmake, o comportamiento raro más adelante | falta `libgsl-dev` (headers), aunque `libgsl28` sí esté instalado | `sudo apt install libgsl-dev`, luego borra `build/` y recompila desde cero |
| `sbatch: error` o el job falla instantáneo con `mkdir: Permission denied` | el directorio de `--output` no existía antes de enviar el job | `mkdir -p runs/<nombre>` antes de `sbatch` (ver §4) |
| Job SLURM falla de inmediato sin log útil | partición inexistente en tu cluster | revisa `sinfo -o "%P"` y usa `--partition=<la_tuya>` |
| Crash GSL `x values must be strictly increasing` en `interp.c` | `min_pt` en 0 exacto | usar `min_pt 0.01` (ya está así en `configs/200GeV_hotQCD.inp`) |
| MUSIC no encuentra `./outputs` en modo 3 | falta crear el directorio antes | manejado automáticamente por `run_music.sh`/`slurm_music.sh` |
