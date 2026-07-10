import csv
import os


ROOT = r"G:\codexproject"
MAT_PATH = os.path.join(
    ROOT,
    "EAHE_airgap_physical_v17_review_ready_results",
    "Table_01_main_performance_summary.csv",
)
COM_PATH = os.path.join(
    ROOT,
    "COMSOL_EAHE_outputs_annual_full",
    "COMSOL_annual_energy_summary.csv",
)
OUT_PATH = os.path.join(
    ROOT,
    "EAHE_airgap_physical_v17_review_ready_results",
    "MATLAB_COMSOL_comparison_summary.csv",
)


def read_rows(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def main():
    mat = {float(row["delta_mm"]): row for row in read_rows(MAT_PATH)}
    com = {"explicit_gap": {}, "resistance_gap": {}}
    for row in read_rows(COM_PATH):
        com[row["model_type"]][float(row["delta_mm"])] = row

    fields = [
        "delta_mm",
        "MATLAB_Eabs_kWh",
        "COMSOL_resistance_Eabs_kWh",
        "COMSOL_explicit_Eabs_kWh",
        "MATLAB_vs_COMSOL_resistance_rel_percent",
        "COMSOL_explicit_vs_resistance_rel_percent",
        "MATLAB_Dgap_percent",
        "COMSOL_resistance_Dgap_percent",
        "COMSOL_explicit_Dgap_percent",
        "Dgap_MATLAB_minus_COMSOL_resistance_point",
        "Dgap_explicit_minus_resistance_point",
    ]
    rows = []
    for d in sorted(mat):
        m = mat[d]
        cr = com["resistance_gap"][d]
        ce = com["explicit_gap"][d]
        m_e = float(m["Eabs_kWh"])
        cr_e = float(cr["Eabs_kWh"])
        ce_e = float(ce["Eabs_kWh"])
        m_d = float(m["Dgap_percent"])
        cr_d = float(cr["Dgap_percent"])
        ce_d = float(ce["Dgap_percent"])
        rows.append(
            {
                "delta_mm": d,
                "MATLAB_Eabs_kWh": m_e,
                "COMSOL_resistance_Eabs_kWh": cr_e,
                "COMSOL_explicit_Eabs_kWh": ce_e,
                "MATLAB_vs_COMSOL_resistance_rel_percent": (m_e - cr_e) / cr_e * 100,
                "COMSOL_explicit_vs_resistance_rel_percent": (ce_e - cr_e) / cr_e * 100,
                "MATLAB_Dgap_percent": m_d,
                "COMSOL_resistance_Dgap_percent": cr_d,
                "COMSOL_explicit_Dgap_percent": ce_d,
                "Dgap_MATLAB_minus_COMSOL_resistance_point": m_d - cr_d,
                "Dgap_explicit_minus_resistance_point": ce_d - cr_d,
            }
        )

    with open(OUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fields)
        writer.writeheader()
        writer.writerows(rows)

    print(OUT_PATH)
    for r in rows:
        print(
            "d={:>3g} mm | Eabs: MATLAB {:.2f}, COMSOL-R {:.2f}, "
            "COMSOL-exp {:.2f} kWh | MATLAB-COMSOL-R {:+.1f}% | "
            "Dgap M {:.2f}%, CR {:.2f}%, CE {:.2f}%".format(
                r["delta_mm"],
                r["MATLAB_Eabs_kWh"],
                r["COMSOL_resistance_Eabs_kWh"],
                r["COMSOL_explicit_Eabs_kWh"],
                r["MATLAB_vs_COMSOL_resistance_rel_percent"],
                r["MATLAB_Dgap_percent"],
                r["COMSOL_resistance_Dgap_percent"],
                r["COMSOL_explicit_Dgap_percent"],
            )
        )


if __name__ == "__main__":
    main()
