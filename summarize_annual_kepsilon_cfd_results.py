from pathlib import Path

import pandas as pd


ROOT = Path("G:/codexproject")
OUT = ROOT / "COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon"


def main():
    energy = pd.read_csv(OUT / "COMSOL_annual_energy_summary.csv")
    tout = pd.read_csv(OUT / "COMSOL_Tout_delta_sweep.csv")

    tout_rows = []
    for d, col in [
        (0, "Tout_resistance_delta_0mm_C"),
        (1, "Tout_resistance_delta_1mm_C"),
        (5, "Tout_resistance_delta_5mm_C"),
    ]:
        s = tout[col]
        tout_rows.append({
            "delta_mm": d,
            "Tout_mean_C": s.mean(),
            "Tout_min_C": s.min(),
            "Tout_max_C": s.max(),
        })
    tout_stats = pd.DataFrame(tout_rows)
    tout_stats.to_csv(OUT / "COMSOL_annual_Tout_stats.csv", index=False)

    h_rows = []
    h_global_rows = []
    for d in [0, 1, 5]:
        case_file = OUT / f"COMSOL_case_resistance_gap_delta_{d}mm.csv"
        ts = pd.read_csv(case_file)
        hg = pd.to_numeric(ts["h_eq_global_W_m2K"], errors="coerce").dropna()
        h_global_rows.append({
            "delta_mm": d,
            "h_eq_mean_W_m2K": hg.mean(),
            "h_eq_median_W_m2K": hg.median(),
            "h_eq_min_W_m2K": hg.min(),
            "h_eq_max_W_m2K": hg.max(),
        })

        h_file = OUT / f"COMSOL_local_h_resistance_gap_delta_{d}mm.csv"
        h = pd.read_csv(h_file)
        vals = pd.to_numeric(h["h_local_W_m2K"], errors="coerce").dropna()
        vals_f = vals[(vals > 0) & (vals < 200)]
        h_rows.append({
            "delta_mm": d,
            "n": len(vals),
            "n_filtered": len(vals_f),
            "h_mean_W_m2K": vals_f.mean(),
            "h_median_W_m2K": vals_f.median(),
            "h_p05_W_m2K": vals_f.quantile(0.05),
            "h_p95_W_m2K": vals_f.quantile(0.95),
        })
    h_stats = pd.DataFrame(h_rows)
    h_stats.to_csv(OUT / "COMSOL_annual_local_h_stats_recomputed.csv", index=False)
    h_global_stats = pd.DataFrame(h_global_rows)
    h_global_stats.to_csv(OUT / "COMSOL_annual_global_h_eq_stats.csv", index=False)

    mat = pd.read_csv(
        ROOT / "EAHE_airgap_physical_v18_minaei_contact_results"
        / "Table_01_main_performance_summary.csv"
    )
    mat = mat[mat.delta_mm.isin([0, 1, 5])][[
        "delta_mm", "Ecool_kWh", "Eheat_kWh", "Eabs_kWh", "Dgap_percent",
        "Tout_mean_C", "Tout_min_C", "Tout_max_C",
    ]]
    comp = energy.merge(mat, on="delta_mm", suffixes=("_CFD", "_MinaeiG"))
    for q in ["Ecool_kWh", "Eheat_kWh", "Eabs_kWh"]:
        comp[q + "_CFD_minus_MinaeiG_percent"] = (
            comp[q + "_CFD"] / comp[q + "_MinaeiG"] - 1
        ) * 100
    comp["Dgap_CFD_minus_MinaeiG_pctpt"] = (
        comp["Dgap_percent_CFD"] - comp["Dgap_percent_MinaeiG"]
    )
    comp.to_csv(OUT / "COMSOL_annual_kepsilon_vs_MinaeiG_comparison.csv", index=False)

    print("ENERGY")
    print(energy.to_string(index=False))
    print("TOUT")
    print(tout_stats.to_string(index=False, float_format=lambda x: f"{x:.3f}"))
    print("H")
    print(h_stats.to_string(index=False, float_format=lambda x: f"{x:.3f}"))
    print("GLOBAL_H_EQ")
    print(h_global_stats.to_string(index=False, float_format=lambda x: f"{x:.3f}"))
    print("COMP")
    cols = [
        "delta_mm", "Eabs_kWh_CFD", "Eabs_kWh_MinaeiG",
        "Eabs_kWh_CFD_minus_MinaeiG_percent", "Dgap_percent_CFD",
        "Dgap_percent_MinaeiG", "Dgap_CFD_minus_MinaeiG_pctpt",
    ]
    print(comp[cols].to_string(index=False, float_format=lambda x: f"{x:.3f}"))


if __name__ == "__main__":
    main()
