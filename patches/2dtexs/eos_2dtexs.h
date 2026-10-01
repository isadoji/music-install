// EOS_2DTExS — 2DTExS equation of state for MUSIC
// Original implementation for EPOS4 by Santiago Bernal Langarica and Tomás Polednicek
// Ported to MUSIC by isadoji
// Reference: arXiv:2406.11610
//
// Table: EOS/2DTExS/EoS2DTExS.dat (500×500 grid in tilde coordinates)
// EOS_to_use = 20

#ifndef SRC_EOS_2DTEXS_H_
#define SRC_EOS_2DTEXS_H_

#include "eos_base.h"

class EOS_2DTExS : public EOS_base {
 private:
    // hbar*c [GeV*fm]
    static constexpr double HBARC  = 0.1973269804;
    static constexpr double HBARC3 = HBARC * HBARC * HBARC;
    static constexpr double HBARC4 = HBARC3 * HBARC;

    // T̃ = C_T × e^(1/4) [GeV^4], from arXiv:2406.11610
    static constexpr double C_TILDET = 0.5029582947864298;

    int NtGrid, NmbGrid;
    double tildeTMin, tildeTMax;
    double tildeMuBMin, tildeMuBMax;
    double tildeTStep, tildeMuBStep;

    // table arrays — stored in EPOS units: T[GeV], P[GeV/fm³], muB[GeV], cs²
    double **Ttab;
    double **ptab;
    double **mubtab;
    double **cs2tab;

    // convert MUSIC inputs (1/fm^4, 1/fm^3) to tilde coordinates
    void to_tilde(double e_fm4, double nB_fm3,
                  double &tildeT, double &tildeMuB) const;

    // bilinear interpolation in the (T̃, μ̃_B) grid
    // outputs in GeV-based units: T[GeV], P[GeV/fm³], muB[GeV], cs²
    void interp(double tildeT, double tildeMuB,
                double &T_GeV, double &P_GeV_fm3,
                double &muB_GeV, double &cs2) const;

 public:
    EOS_2DTExS();
    ~EOS_2DTExS();

    void   initialize_eos();

    // MUSIC EOS interface — all in internal units (1/fm^n)
    double get_temperature(double e, double rhob) const;  // returns 1/fm
    double get_pressure   (double e, double rhob) const;  // returns 1/fm^4
    double get_muB        (double e, double rhob) const;  // returns 1/fm
    double get_cs2        (double e, double rhob) const;  // dimensionless
    double p_e_func       (double e, double rhob) const;  // ∂P/∂e ≈ cs2
    double p_rho_func     (double e, double rhob) const { return 0.0; }
    double get_s2e        (double s, double rhob) const;  // bisection
    double get_T2e        (double T_in_GeV, double rhob) const;  // bisection

    void check_eos() const { check_eos_no_muB(); }
};

#endif  // SRC_EOS_2DTEXS_H_
