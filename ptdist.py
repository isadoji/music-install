#!/usr/bin/env python3
"""Transverse momentum distributions — MUSIC Au+Au 200 GeV"""

import os
import sys
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from pathlib import Path

if len(sys.argv) < 2:
    sys.exit(f"Uso: {sys.argv[0]} <run_dir>\n"
             f"  ej: {sys.argv[0]} runs/200GeV_hotQCD_default")
RUN_DIR = Path(sys.argv[1])
if not RUN_DIR.is_dir():
    sys.exit(f"ERROR: no existe el directorio de corrida: {RUN_DIR}")

# backend no interactivo si no hay display (típico en un cluster por SSH)
if not os.environ.get('DISPLAY'):
    matplotlib.use('Agg')

PARTICLE_INFO   = RUN_DIR / 'particleInformation.dat'
SPECTRA_FILE    = RUN_DIR / 'yptphiSpectra.dat'
F_PARTICLE_INFO = RUN_DIR / 'FparticleInformation.dat'
F_SPECTRA_FILE  = RUN_DIR / 'FyptphiSpectra.dat'

PHENIX_DNCH_DETA = 680.0

SPECIES = [
    ( 211, r'$\pi^+$',   'tab:blue',   '-'),
    (-211, r'$\pi^-$',   'tab:cyan',   '--'),
    ( 321, r'$K^+$',     'tab:orange', '-'),
    (-321, r'$K^-$',     'tab:red',    '--'),
    (2212, r'$p$',       'tab:green',  '-'),
    (-2212,r'$\bar{p}$', 'tab:purple', '--'),
]
CHARGED_PDG = [p[0] for p in SPECIES]


def read_particle_info(fname):
    particles = []
    with open(fname) as f:
        for line in f:
            vals = line.split()
            if len(vals) < 7:
                continue
            pdg    = int(vals[0])
            eta_max= float(vals[1])
            N_eta  = int(vals[2])
            pT_min = float(vals[3])
            pT_max = float(vals[4])
            N_pT   = int(vals[5])
            N_phi  = int(vals[6])
            pseudo_steps = N_eta - 1
            delta_eta = 2 * eta_max / pseudo_steps if pseudo_steps > 0 else 0.0
            eta = np.array([i * delta_eta - eta_max for i in range(N_eta)])
            ipt = np.arange(N_pT, dtype=float)
            pT  = pT_min + (pT_max - pT_min) * ipt**2 / (N_pT - 1)**2
            phi = np.linspace(0, 2 * np.pi, N_phi, endpoint=False)
            particles.append(dict(
                pdg=pdg, eta_max=eta_max, N_eta=N_eta, N_pT=N_pT, N_phi=N_phi,
                delta_eta=delta_eta, eta=eta, pT=pT, phi=phi
            ))
    return particles


def read_s_factor(run_dir):
    """Lee s_factor del music_input real usado en la corrida (lo escribe
    run_music.sh/slurm_music.sh en cada modo). None si no se encuentra."""
    music_input = run_dir / 'music_input'
    if not music_input.exists():
        return None
    with open(music_input) as f:
        for line in f:
            if line.strip().startswith('s_factor'):
                return float(line.split()[1])
    return None


def read_spectra(fname, particles):
    data = np.fromfile(fname, sep=' ')
    spectra, offset = [], 0
    for p in particles:
        size  = p['N_eta'] * p['N_pT'] * p['N_phi']
        block = np.maximum(data[offset:offset + size], 0.0)
        spectra.append(block.reshape(p['N_eta'], p['N_pT'], p['N_phi']))
        offset += size
    return spectra


def compute_dNdpT(spectrum, p, y_cut=0.5):
    eta  = p['eta']
    pT   = p['pT']
    dphi = 2 * np.pi / p['N_phi']
    mask = np.abs(eta) <= y_cut
    dN_deta_dpT = spectrum.sum(axis=2) * dphi
    dN_dpT = np.trapezoid(dN_deta_dpT[mask, :], eta[mask], axis=0)
    return pT, dN_dpT


S_FACTOR = read_s_factor(RUN_DIR)

# ── load thermal (mode 3) ────────────────────────────────────────────────────
particles  = read_particle_info(PARTICLE_INFO)
spectra    = read_spectra(SPECTRA_FILE, particles)
pdg_index  = {p['pdg']: i for i, p in enumerate(particles)}

# ── load post-decay (mode 4) ─────────────────────────────────────────────────
particles_F = read_particle_info(F_PARTICLE_INFO)
spectra_F   = read_spectra(F_SPECTRA_FILE, particles_F)
pdg_index_F = {p['pdg']: i for i, p in enumerate(particles_F)}

# ── dN/dy table ──────────────────────────────────────────────────────────────
print(f"Run: {RUN_DIR.name}")
print()
print(f"{'Especie':8s}  {'dN/dy térmico':>15s}  {'dN/dy +decaim.':>16s}  {'ratio':>7s}  {'<pT> [GeV]':>12s}")
print('-' * 65)

music_dnch_th = 0.0
music_dnch_fd = 0.0

for pdg, label, *_ in SPECIES:
    dN_th = dN_fd = mean_pT = 0.0

    if pdg in pdg_index:
        idx = pdg_index[pdg]
        pT, dNdpT = compute_dNdpT(spectra[idx], particles[idx])
        dN_th    = np.trapezoid(dNdpT, pT)
        mean_pT  = np.trapezoid(pT * dNdpT, pT) / dN_th if dN_th > 0 else 0

    if pdg in pdg_index_F:
        idx_F = pdg_index_F[pdg]
        pT_F, dNdpT_F = compute_dNdpT(spectra_F[idx_F], particles_F[idx_F])
        dN_fd = np.trapezoid(dNdpT_F, pT_F)

    ratio = dN_fd / dN_th if dN_th > 0 else 0
    print(f"{label:8s}  {dN_th:>15.1f}  {dN_fd:>16.1f}  {ratio:>7.3f}  {mean_pT:>12.4f}")

    if pdg in CHARGED_PDG:
        music_dnch_th += dN_th
        music_dnch_fd += dN_fd

print('-' * 65)
print(f"{'Total ch.':8s}  {music_dnch_th:>15.1f}  {music_dnch_fd:>16.1f}")
print()

decay_factor = music_dnch_fd / music_dnch_th if music_dnch_th > 0 else float('nan')
print(f"decay_factor medido (post-decaim. / térmico):    {decay_factor:.3f}")
print()

if S_FACTOR is not None:
    print(f"s_factor de esta corrida (leído de music_input): {S_FACTOR:.4f}")
else:
    print("ADVERTENCIA: no se encontró music_input en el run_dir — no se puede "
          "reportar s_factor automáticamente ni el punto de calibración.")

target_th = PHENIX_DNCH_DETA / decay_factor if decay_factor > 0 else float('nan')
print(f"PHENIX 0-5%  dN_ch/dη (medido):                  {PHENIX_DNCH_DETA:.0f}")
print(f"Objetivo térmico (÷ decay_factor medido):        {target_th:.1f}")
print()
print(f"MUSIC térmico / objetivo   = {music_dnch_th / target_th:.3f}")
print(f"MUSIC +decaim. / PHENIX    = {music_dnch_fd / PHENIX_DNCH_DETA:.3f}")
print()

if S_FACTOR is not None:
    print("Punto de calibración para s_factor_calibrate.py:")
    print(f"  --decay-factor {decay_factor:.3f} --points {S_FACTOR}:{music_dnch_th:.1f}")

# ── plot: thermal vs post-decay ───────────────────────────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(18, 6))
panels = [
    ([ 211,-211], r'$\pi^\pm$',   axes[0]),
    ([ 321,-321], r'$K^\pm$',     axes[1]),
    ([2212,-2212],r'$p,\bar{p}$', axes[2]),
]
colors = {211:'tab:blue',-211:'tab:blue',321:'tab:orange',-321:'tab:orange',2212:'tab:green',-2212:'tab:green'}
ls_map = {211:'-',-211:'--',321:'-',-321:'--',2212:'-',-2212:'--'}

for pdg_list, title, ax in panels:
    for pdg in pdg_list:
        c, ls = colors[pdg], ls_map[pdg]
        name = {211:r'$\pi^+$',-211:r'$\pi^-$',321:r'$K^+$',-321:r'$K^-$',2212:r'$p$',-2212:r'$\bar{p}$'}[pdg]
        if pdg in pdg_index:
            idx = pdg_index[pdg]
            pT, dNdpT = compute_dNdpT(spectra[idx], particles[idx])
            ax.plot(pT, dNdpT / (2*np.pi*pT), color=c, ls=ls, lw=2, alpha=0.4, label=f'{name} térmico')
        if pdg in pdg_index_F:
            idx_F = pdg_index_F[pdg]
            pT_F, dNdpT_F = compute_dNdpT(spectra_F[idx_F], particles_F[idx_F])
            ax.plot(pT_F, dNdpT_F / (2*np.pi*pT_F), color=c, ls=ls, lw=2, label=f'{name} +decaim.')
    ax.set_yscale('log')
    ax.set_xlabel(r'$p_T$ [GeV/c]', fontsize=12)
    ax.set_ylabel(r'$\frac{1}{2\pi p_T}\frac{dN}{dp_T dy}$  [GeV$^{-2}$]', fontsize=11)
    s_factor_label = f'{S_FACTOR:.4f}' if S_FACTOR is not None else '?'
    ax.set_title(f'{title} — {RUN_DIR.name}  (s_factor={s_factor_label})', fontsize=11)
    ax.set_xlim(0, 3)
    ax.legend(fontsize=9)
    ax.grid(True, which='both', alpha=0.3)

plt.suptitle(f'MUSIC hotQCD EOS — {RUN_DIR.name}', fontsize=12, y=1.02)
plt.tight_layout()
out = RUN_DIR / 'ptdist_thermal_vs_decay.png'
plt.savefig(out, dpi=150, bbox_inches='tight')
print(f"\nGráfica guardada → {out}")
plt.show()
