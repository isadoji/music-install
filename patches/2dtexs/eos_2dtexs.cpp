// EOS_2DTExS — 2DTExS equation of state for MUSIC
// Original implementation for EPOS4 by Santiago Bernal Langarica and Tomás Polednicek
// Ported to MUSIC by isadoji
// Reference: arXiv:2406.11610

#include "eos_2dtexs.h"

#include <fstream>
#include <sstream>
#include <cmath>
#include <limits>
#include <iostream>

using std::string;
using std::stringstream;

EOS_2DTExS::EOS_2DTExS() {
    set_EOS_id(20);
    set_number_of_tables(0);
    set_eps_max(1e5);
    set_flag_muB(true);
    set_flag_muS(false);
    set_flag_muC(false);
    NtGrid = NmbGrid = 0;
    tildeTMin = tildeTMax = tildeMuBMin = tildeMuBMax = 0.0;
    tildeTStep = tildeMuBStep = 0.0;
    Ttab = ptab = mubtab = cs2tab = nullptr;
}

EOS_2DTExS::~EOS_2DTExS() {
    if (Ttab) {
        for (int i = 0; i < NtGrid; i++) {
            delete[] Ttab[i];
            delete[] ptab[i];
            delete[] mubtab[i];
            delete[] cs2tab[i];
        }
        delete[] Ttab;
        delete[] ptab;
        delete[] mubtab;
        delete[] cs2tab;
    }
}

void EOS_2DTExS::initialize_eos() {
    music_message.info("reading EOS 2DTExS ...");

    auto envPath = get_hydro_env_path();
    stringstream ss;
    ss << envPath << "/EOS/2DTExS/EoS2DTExS.dat";
    string fname = ss.str();

    music_message << "from path " << fname;
    music_message.flush("info");

    std::ifstream fin(fname.c_str());
    if (!fin.is_open()) {
        music_message.error("Cannot open EoS file: " + fname);
        exit(1);
    }

    // skip comment lines
    string line;
    while (fin.peek() == '#') getline(fin, line);

    // default grid: 500 × 500
    NtGrid = NmbGrid = 500;

    // allocate tables
    Ttab   = new double*[NtGrid];
    ptab   = new double*[NtGrid];
    mubtab = new double*[NtGrid];
    cs2tab = new double*[NtGrid];
    for (int i = 0; i < NtGrid; i++) {
        Ttab[i]   = new double[NmbGrid];
        ptab[i]   = new double[NmbGrid];
        mubtab[i] = new double[NmbGrid];
        cs2tab[i] = new double[NmbGrid];
    }

    tildeTMin  =  1e30; tildeTMax  = -1e30;
    tildeMuBMin = 1e30; tildeMuBMax = -1e30;

    // Columns: Ttilde  muBtilde  e[GeV^4]  nB[GeV^3]  T[GeV]  muB[GeV]
    //          P[GeV^4]  s[GeV^3]  cs2  chi2  chi
    const double GEV4_TO_GEV_FM3 = 1.0 / HBARC3;

    for (int iT = 0; iT < NtGrid; iT++) {
        for (int iMu = 0; iMu < NmbGrid; iMu++) {
            while (fin.peek() == '#' || fin.peek() == '\n' || fin.peek() == '\r')
                getline(fin, line);

            double tildeT, tildeMuB, e_GeV4, nB_GeV3;
            double T_GeV, muB_GeV, P_GeV4, s_GeV3, cs2, chi2, chi;

            if (!(fin >> tildeT >> tildeMuB >> e_GeV4 >> nB_GeV3
                      >> T_GeV >> muB_GeV >> P_GeV4 >> s_GeV3
                      >> cs2 >> chi2 >> chi)) {
                music_message.error("Format error in EoS2DTExS.dat");
                exit(1);
            }

            // store T, muB in GeV (no conversion needed)
            Ttab[iT][iMu]   = T_GeV;
            mubtab[iT][iMu] = muB_GeV;
            // convert P: GeV^4 → GeV/fm³
            ptab[iT][iMu]   = P_GeV4 * GEV4_TO_GEV_FM3;
            cs2tab[iT][iMu] = cs2;

            if (tildeT  < tildeTMin)   tildeTMin   = tildeT;
            if (tildeT  > tildeTMax)   tildeTMax   = tildeT;
            if (tildeMuB < tildeMuBMin) tildeMuBMin = tildeMuB;
            if (tildeMuB > tildeMuBMax) tildeMuBMax = tildeMuB;
        }
    }
    fin.close();

    tildeTStep   = (tildeTMax   - tildeTMin)   / (NtGrid  - 1);
    tildeMuBStep = (tildeMuBMax - tildeMuBMin) / (NmbGrid - 1);

    // set eps_max: maximum e in 1/fm^4 from table range
    // T̃_max = C × e_max^(1/4) → e_max [GeV^4] = (T̃_max/C)^4
    double e_max_GeV4 = pow(tildeTMax / C_TILDET, 4.0);
    double e_max_GeV_fm3 = e_max_GeV4 * GEV4_TO_GEV_FM3;
    set_eps_max(e_max_GeV_fm3 / HBARC);  // convert to 1/fm^4

    music_message << "EOS 2DTExS loaded: "
                  << NtGrid << "×" << NmbGrid << " grid"
                  << "  T̃ = [" << tildeTMin << ", " << tildeTMax << "] GeV"
                  << "  μ̃_B = [" << tildeMuBMin << ", " << tildeMuBMax << "] GeV";
    music_message.flush("info");
    music_message.info("Done reading EOS 2DTExS.");
}

void EOS_2DTExS::to_tilde(double e_fm4, double nB_fm3,
                           double &tildeT, double &tildeMuB) const {
    // convert MUSIC units (1/fm^4, 1/fm^3) to natural units (GeV^4, GeV^3)
    // e [GeV^4] = e [1/fm^4] × hbarc^4 [GeV^4·fm^4]
    const double e_GeV4  = e_fm4  * HBARC4;
    const double nB_GeV3 = nB_fm3 * HBARC3;

    if (e_GeV4 <= 0.0 || !std::isfinite(e_GeV4)) {
        tildeT = tildeTMin;
        tildeMuB = tildeMuBMin;
        return;
    }

    tildeT   = std::pow(e_GeV4, 0.25) * C_TILDET;
    tildeMuB = (tildeT > 0.0) ? 5.0 * nB_GeV3 / (tildeT * tildeT) : 0.0;

    // clamp to table range
    if (tildeT   < tildeTMin)   tildeT   = tildeTMin;
    if (tildeT   > tildeTMax)   tildeT   = tildeTMax;
    if (tildeMuB < tildeMuBMin) tildeMuB = tildeMuBMin;
    if (tildeMuB > tildeMuBMax) tildeMuB = tildeMuBMax;
}

void EOS_2DTExS::interp(double tildeT, double tildeMuB,
                         double &T_GeV, double &P_GeV_fm3,
                         double &muB_GeV, double &cs2) const {
    int iT  = static_cast<int>((tildeT   - tildeTMin)   / tildeTStep);
    int iMu = static_cast<int>((tildeMuB - tildeMuBMin) / tildeMuBStep);

    if (iT  < 0) iT  = 0;
    if (iMu < 0) iMu = 0;
    if (iT  > NtGrid  - 2) iT  = NtGrid  - 2;
    if (iMu > NmbGrid - 2) iMu = NmbGrid - 2;

    const double wT1  = (tildeT   - tildeTMin   - iT  * tildeTStep)   / tildeTStep;
    const double wMu1 = (tildeMuB - tildeMuBMin - iMu * tildeMuBStep) / tildeMuBStep;
    const double wT0  = 1.0 - wT1;
    const double wMu0 = 1.0 - wMu1;

    T_GeV     = wT0*wMu0*Ttab[iT][iMu]   + wT1*wMu0*Ttab[iT+1][iMu]
              + wT0*wMu1*Ttab[iT][iMu+1] + wT1*wMu1*Ttab[iT+1][iMu+1];

    P_GeV_fm3 = wT0*wMu0*ptab[iT][iMu]   + wT1*wMu0*ptab[iT+1][iMu]
              + wT0*wMu1*ptab[iT][iMu+1] + wT1*wMu1*ptab[iT+1][iMu+1];

    muB_GeV   = wT0*wMu0*mubtab[iT][iMu]   + wT1*wMu0*mubtab[iT+1][iMu]
              + wT0*wMu1*mubtab[iT][iMu+1] + wT1*wMu1*mubtab[iT+1][iMu+1];

    cs2       = wT0*wMu0*cs2tab[iT][iMu]   + wT1*wMu0*cs2tab[iT+1][iMu]
              + wT0*wMu1*cs2tab[iT][iMu+1] + wT1*wMu1*cs2tab[iT+1][iMu+1];

    if (P_GeV_fm3 < 0.0) P_GeV_fm3 = 0.0;
    if (cs2 < 0.0) cs2 = 0.0;
    if (cs2 > 1.0) cs2 = 1.0/3.0;
}

double EOS_2DTExS::get_temperature(double e, double rhob) const {
    if (e <= 0.0 || !std::isfinite(e)) return 0.0;
    double tildeT, tildeMuB;
    to_tilde(e, rhob, tildeT, tildeMuB);
    double T_GeV, P, muB, cs2;
    interp(tildeT, tildeMuB, T_GeV, P, muB, cs2);
    return T_GeV / HBARC;  // GeV → 1/fm
}

double EOS_2DTExS::get_pressure(double e, double rhob) const {
    if (e <= 0.0 || !std::isfinite(e)) return 0.0;
    double tildeT, tildeMuB;
    to_tilde(e, rhob, tildeT, tildeMuB);
    double T_GeV, P_GeV_fm3, muB, cs2;
    interp(tildeT, tildeMuB, T_GeV, P_GeV_fm3, muB, cs2);
    return P_GeV_fm3 / HBARC;  // GeV/fm³ → 1/fm^4
}

double EOS_2DTExS::get_muB(double e, double rhob) const {
    if (e <= 0.0 || !std::isfinite(e)) return 0.0;
    double tildeT, tildeMuB;
    to_tilde(e, rhob, tildeT, tildeMuB);
    double T_GeV, P, muB_GeV, cs2;
    interp(tildeT, tildeMuB, T_GeV, P, muB_GeV, cs2);
    return muB_GeV / HBARC;  // GeV → 1/fm
}

double EOS_2DTExS::get_cs2(double e, double rhob) const {
    if (e <= 0.0 || !std::isfinite(e)) return 1.0/3.0;
    double tildeT, tildeMuB;
    to_tilde(e, rhob, tildeT, tildeMuB);
    double T_GeV, P, muB, cs2;
    interp(tildeT, tildeMuB, T_GeV, P, muB, cs2);
    return cs2;
}

double EOS_2DTExS::p_e_func(double e, double rhob) const {
    // ∂P/∂e ≈ cs² (exact at ρ_B=0, approximation at finite ρ_B)
    return get_cs2(e, rhob);
}

double EOS_2DTExS::get_s2e(double s, double rhob) const {
    // bisection: find e such that (e+P-muB*rhob)/T = s
    // s in 1/fm^3, returns e in 1/fm^4
    if (s <= 0.0) return 0.0;
    double e_lo = 0.0, e_hi = get_eps_max();
    for (int iter = 0; iter < 100; iter++) {
        double e_mid = 0.5 * (e_lo + e_hi);
        double T = get_temperature(e_mid, rhob);
        if (T < 1e-15) { e_lo = e_mid; continue; }
        double P   = get_pressure(e_mid, rhob);
        double muB = get_muB(e_mid, rhob);
        double s_mid = (e_mid + P - muB * rhob) / T;
        if (s_mid < s) e_lo = e_mid;
        else           e_hi = e_mid;
        if ((e_hi - e_lo) / (e_hi + e_lo + 1e-30) < 1e-6) break;
    }
    return 0.5 * (e_lo + e_hi);
}

double EOS_2DTExS::get_T2e(double T_in_GeV, double rhob) const {
    // bisection: find e such that get_temperature(e, rhob) = T_in_GeV/hbarc
    if (T_in_GeV <= 0.0) return 0.0;
    const double T_target = T_in_GeV / HBARC;  // 1/fm
    double e_lo = 0.0, e_hi = get_eps_max();
    for (int iter = 0; iter < 100; iter++) {
        double e_mid = 0.5 * (e_lo + e_hi);
        double T_mid = get_temperature(e_mid, rhob);
        if (T_mid < T_target) e_lo = e_mid;
        else                  e_hi = e_mid;
        if ((e_hi - e_lo) / (e_hi + e_lo + 1e-30) < 1e-6) break;
    }
    return 0.5 * (e_lo + e_hi);
}
