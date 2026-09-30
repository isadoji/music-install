#!/usr/bin/env python3
"""Chequeo de yield dN/dy(pi+-, |y|<0.5) contra un valor de referencia
(README §9: cascada UrQMD standalone, Bi+Bi central sqrt(s_NN)=5.8 GeV,
target = 85.75 de Ayala et al. 2401.00619 Tabla 1, medido tambien en la
propia corrida de referencia job 12333, 66670 eventos).

Lee los archivos nativos de UrQMD f19 (OSCAR1997A) producidos por
scripts/slurm_urqmd_cascade_array.sh / scripts/run_urqmd_cascade.sh
(naming: urqmd_task_NNN.f19). Evento = linea de encabezado de 4 campos
'iev npart b phi' seguida de npart lineas de particula de 11 campos
(idx pdg px py pz p0 m x y z t).

Uso:
    check_yield_urqmd.py <outdir> [--ymax 0.5] [--target 85.75] [--tol 0.05]

--tol es la tolerancia relativa (5% por defecto) para el veredicto OK/FALLO
frente a --target; si no se pasa --target, solo se imprime el resultado.
"""
import argparse
import glob
import math
import os
import sys

import numpy as np


def count_yields(outdir, ymax):
    cp, cm = [], []
    files = sorted(glob.glob(os.path.join(outdir, "urqmd_task_*.f19")))
    if not files:
        sys.exit(f"ERROR: no se encontraron urqmd_task_*.f19 en {outdir}")
    for fn in files:
        with open(fn) as f:
            for _ in range(3):
                f.readline()
            n_p = n_m = 0
            have = False
            for line in f:
                t = line.split()
                if len(t) == 4:
                    if have:
                        cp.append(n_p)
                        cm.append(n_m)
                    n_p = n_m = 0
                    have = True
                elif len(t) >= 11:
                    pdg = int(t[1])
                    if pdg in (211, -211):
                        pz, e = float(t[4]), float(t[5])
                        if e > abs(pz) and abs(0.5 * math.log((e + pz) / (e - pz))) < ymax:
                            if pdg == 211:
                                n_p += 1
                            else:
                                n_m += 1
            if have:
                cp.append(n_p)
                cm.append(n_m)
    return np.array(cp, float), np.array(cm, float)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("outdir")
    ap.add_argument("--ymax", type=float, default=0.5)
    ap.add_argument("--target", type=float, default=None, help="valor de referencia dN/dy(pi+)")
    ap.add_argument("--tol", type=float, default=0.05, help="tolerancia relativa frente a --target")
    args = ap.parse_args()

    cp, cm = count_yields(args.outdir, args.ymax)
    n = len(cp)
    w = 2 * args.ymax

    print(f"eventos contados: {n}")
    results = {}
    for name, c in (("pi+", cp), ("pi-", cm)):
        mean = c.mean() / w
        err = c.std(ddof=1) / math.sqrt(n) / w
        results[name] = mean
        print(f"dN/dy({name}, |y|<{args.ymax}) = {mean:.3f} +- {err:.3f}   (total {int(c.sum()):,d})")

    if args.target is not None:
        obs = results["pi+"]
        rel = abs(obs - args.target) / args.target
        verdict = "OK" if rel <= args.tol else "FALLO"
        print(f"\nComparacion vs target={args.target}: diff relativa = {rel*100:.1f}%  -> {verdict} (tol={args.tol*100:.0f}%)")
        if verdict == "FALLO":
            sys.exit(1)


if __name__ == "__main__":
    main()
