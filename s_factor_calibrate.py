#!/usr/bin/env python3
"""
Calibración de s_factor a partir de corridas modo 2->3 (sin modo 4).

Ajusta el exponente local n en  dN_ch/dη_térmico ∝ s_factor^n  usando 1+ puntos
medidos, y sugiere el siguiente s_factor a probar para alcanzar el target
experimental (o de referencia, ej. UrQMD para NICA donde no hay datos aún).

n=3/4 es solo exacto para una EOS ideal/conforme sin viscosidad; con un solo
punto se asume ese valor. Con 2+ puntos se ajusta empíricamente (regresión
log-log), que es lo recomendado para hotQCD/2DTExS viscosas.

Uso:
    python3 s_factor_calibrate.py --target-exp 680 --decay-factor 1.993 \
        --points 0.045:171.5 0.176:298.4

    # un solo punto (usa n=3/4 por defecto):
    python3 s_factor_calibrate.py --target-exp 341.7 --decay-factor 1 \
        --points 0.176:298.4
"""
import argparse
import numpy as np


def suggest_next_s_factor(target_th, points):
    """
    points: lista de tuplas (s_factor, dNdeta_termico), 1 o más.
    target_th: target térmico (ya dividido por el decay factor).

    Devuelve (s_factor_sugerido, n_usado, nota).
    """
    s_vals = np.array([p[0] for p in points], dtype=float)
    a_vals = np.array([p[1] for p in points], dtype=float)

    if len(points) == 1:
        n = 0.75
        s0, a0 = points[0]
        s_next = s0 * (target_th / a0) ** (1 / n)
        return s_next, n, "n asumido = 3/4 (EOS ideal/conforme; un solo punto disponible)"

    ln_s = np.log(s_vals)
    ln_a = np.log(a_vals)
    n, _ = np.polyfit(ln_s, ln_a, 1)  # ln(a) = n*ln(s) + ln(c)

    # extrapola desde el punto medido más cercano al target (más confiable localmente)
    idx = np.argmin(np.abs(a_vals - target_th))
    s0, a0 = s_vals[idx], a_vals[idx]
    s_next = s0 * (target_th / a0) ** (1 / n)
    return s_next, n, f"n ajustado empíricamente de {len(points)} puntos (regresión log-log)"


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--target-exp', type=float, required=True,
                     help='dN_ch/dη experimental o de referencia (ej. PHENIX, STAR, o tu propio UrQMD) '
                          'para esa energía/sistema/centralidad')
    ap.add_argument('--decay-factor', type=float, default=2.0,
                     help='dN_ch/dη post-decaimiento / térmico. Default 2.0 (medido para '
                          'hotQCD/2DTExS con eps_freeze=0.18). Usa 1.0 si --target-exp ya es térmico.')
    ap.add_argument('--points', nargs='+', required=True,
                     help='pares s_factor:dNdeta_termico medidos (modo 2->3), ej: 0.045:171.5 0.176:298.4')
    args = ap.parse_args()

    points = []
    for p in args.points:
        s_str, a_str = p.split(':')
        points.append((float(s_str), float(a_str)))

    target_th = args.target_exp / args.decay_factor
    s_next, n, note = suggest_next_s_factor(target_th, points)

    print(f"Target experimental/referencia dN_ch/dη:  {args.target_exp:.2f}")
    print(f"Decay factor usado:                        {args.decay_factor:.3f}")
    print(f"Target térmico (modo 2->3):                {target_th:.2f}")
    print()
    for s, a in points:
        print(f"  s_factor={s:<8.4f} -> dN_ch/dη térmico={a:.2f}")
    print()
    print(f"Exponente n ajustado:                       {n:.4f}   ({note})")
    print(f"s_factor sugerido para siguiente prueba:    {s_next:.4f}")


if __name__ == '__main__':
    main()
