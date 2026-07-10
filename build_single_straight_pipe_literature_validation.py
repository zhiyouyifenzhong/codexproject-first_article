from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "single_straight_pipe_literature_validation"
OUT.mkdir(exist_ok=True)


def write_sharan_extracted():
    may = pd.DataFrame(
        [
            ("10:00", 0, 31.3, 26.6, 29.1, 26.8, 1.73),
            ("11:00", 1, 33.7, 26.6, 29.2, 26.8, 2.6),
            ("12:00", 2, 36.4, 26.6, 29.5, 27.2, 3.2),
            ("13:00", 3, 37.8, 26.6, 29.5, 27.2, 3.9),
            ("14:00", 4, 40.8, 26.6, 29.7, 27.2, 4.4),
            ("15:00", 5, 40.4, 26.6, 29.7, 27.2, 4.2),
            ("16:00", 6, 39.8, 26.6, 29.8, 27.2, 4.1),
            ("17:00", 7, 39.6, 26.5, 30.0, 27.2, 4.0),
        ],
        columns=["time_clock", "t_h", "Tin_C", "Tsoil_3m_C", "T25m_C", "Tout_C", "COP"],
    )
    jan = pd.DataFrame(
        [
            ("18:00", 0, 19.8, 24.2, 22.3, 23.4, 1.5),
            ("19:00", 1, 17.6, 24.2, 22.2, 23.4, 2.6),
            ("20:00", 2, 13.3, 24.2, 22.1, 23.3, 3.5),
            ("21:00", 3, 11.9, 24.2, 21.9, 23.3, 3.4),
            ("22:00", 4, 10.4, 24.2, 21.8, 23.3, 4.3),
            ("23:00", 5, 9.6, 24.2, 21.7, 23.3, 4.5),
            ("00:00", 6, 9.1, 24.2, 21.6, 23.2, 4.6),
            ("01:00", 7, 8.7, 24.2, 21.5, 23.2, 4.7),
            ("02:00", 8, 8.3, 24.2, 21.5, 23.0, 5.0),
            ("03:00", 9, 8.7, 24.2, 21.4, 23.0, 4.5),
            ("04:00", 10, 9.1, 24.2, 21.3, 22.9, 4.4),
            ("05:00", 11, 9.6, 24.2, 21.2, 22.9, 4.3),
            ("06:00", 12, 9.8, 24.2, 21.2, 22.8, 4.2),
        ],
        columns=["time_clock", "t_h", "Tin_C", "Tsoil_3m_C", "T25m_C", "Tout_C", "COP"],
    )
    monthly = pd.DataFrame(
        [
            ("February", 37.9, 25.2, 26.4),
            ("March", 39.4, 25.8, 26.4),
            ("April", 41.4, 26.6, 28.0),
            ("May", 40.8, 26.6, 27.2),
            ("June", 37.5, 29.8, 31.9),
            ("September", 39.1, 28.9, 30.0),
            ("October", 34.8, 25.6, 26.2),
            ("November", 30.6, 24.2, 24.2),
            ("December", 30.7, 24.4, 24.4),
        ],
        columns=["month", "Tin_14h_C", "Tsoil_3m_C", "Tout_14h_C"],
    )
    may.to_csv(OUT / "Sharan2003_Table1_May_hourly.csv", index=False)
    jan.to_csv(OUT / "Sharan2003_Table2_January_hourly.csv", index=False)
    monthly.to_csv(OUT / "Sharan2003_Table3_cooling_monthly_summary.csv", index=False)
    return may, jan, monthly


def write_deldan_extracted():
    open_mean = pd.DataFrame(
        [
            (24.0, 1.26, 1.80, 65984.1, 2.29, 5.59, 0.41, "open"),
            (18.0, 0.95, 1.61, 44181.3, 1.53, 4.71, 0.33, "open"),
            (14.0, 0.74, 3.75, 80222.0, 2.79, 3.56, 0.78, "open"),
            (11.0, 0.58, 3.55, 59652.4, 2.07, 3.48, 0.60, "open"),
            (4.0, 0.21, 4.19, 25598.5, 0.89, 3.12, 0.28, "open"),
            (2.3, 0.12, 7.70, 27009.9, 0.94, 2.95, 0.32, "open"),
        ],
        columns=[
            "velocity_m_s",
            "mdot_kg_s",
            "mean_deltaT_C",
            "mean_Qh_kJ",
            "mean_Qe_kW",
            "blower_Qb_kW",
            "mean_COP",
            "system_mode",
        ],
    )
    closed_mean = pd.DataFrame(
        [
            (24.0, 1.26, 0.76, 0.97, 5.59, 0.17, "closed"),
            (18.0, 0.95, 0.70, 0.67, 4.71, 0.14, "closed"),
            (14.0, 0.74, 1.78, 1.32, 3.56, 0.37, "closed"),
            (11.0, 0.58, 1.62, 0.94, 3.48, 0.27, "closed"),
            (5.0, 0.26, 1.49, 0.40, 3.21, 0.12, "closed"),
            (4.0, 0.21, 1.88, 0.40, 3.12, 0.13, "closed"),
            (3.0, 0.16, 4.30, 0.68, 3.08, 0.22, "closed"),
            (2.3, 0.12, 6.50, 0.79, 2.95, 0.27, "closed"),
        ],
        columns=[
            "velocity_m_s",
            "mdot_kg_s",
            "mean_deltaT_C",
            "mean_Qe_kW",
            "blower_Qb_kW",
            "mean_COP",
            "system_mode",
        ],
    )
    open_mean.to_csv(OUT / "Deldan2017_open_system_velocity_mean.csv", index=False)
    closed_mean.to_csv(OUT / "Deldan2017_closed_system_velocity_mean.csv", index=False)
    return open_mean, closed_mean


def write_geothermics_extracted():
    cooling = pd.DataFrame(
        [
            ("August 2017", 2.8, 15.978, 4.438, 185),
            ("September 2017", 2.7, 7.751, 2.153, 93),
            ("October 2017", 2.6, 6.771, 1.881, 82),
            ("November 2017", 2.3, 5.294, 1.470, 73),
            ("December 2017", 2.7, 8.662, 2.406, 102),
            ("January 2018", 2.7, 2.018, 0.561, 24),
        ],
        columns=["month", "mean_deltaT_C", "QC_MJ", "QC_kWh", "working_time_h"],
    )
    heating = pd.DataFrame(
        [
            ("November 2017", 3.6, 1.366, 0.38, 12.2),
            ("December 2017", 3.3, 6.946, 1.93, 68.8),
            ("January 2018", 3.2, 14.405, 4.00, 143.5),
        ],
        columns=["month", "mean_deltaT_C", "QC_MJ", "QC_kWh", "working_time_h"],
    )
    cooling.to_csv(OUT / "DiazHernandez2020_Table2_cooling_summary_excluded_geometry.csv", index=False)
    heating.to_csv(OUT / "DiazHernandez2020_Table3_heating_summary_excluded_geometry.csv", index=False)
    return cooling, heating


def build_screening_table():
    screening = pd.DataFrame(
        [
            (
                "Sharan and Jadhav 2003",
                "single 50 m mild-steel pipe, nominal 0.10 m diameter, 3 mm wall, buried 3 m",
                "near-straight single pass; small risers/elbow and external spiral fins are reported",
                "hourly Tin, T25m, Tout for May and January; monthly 14:00 summary",
                "accepted for strict comparison with the current 50 m single-pipe validation case",
            ),
            (
                "Diaz-Hernandez et al. 2020",
                "three pipe sections: 6 m horizontal plus 3 m inlet and 3 m insulated outlet, 101.6 mm PVC",
                "not a pure single straight buried pipe",
                "six-month cooling/heating summaries and plotted 10 min temperatures",
                "excluded from strict single-straight-pipe validation; data extracted only as reference",
            ),
            (
                "Deldan et al. 2017",
                "single 42 m PVC pipe, 0.25 m diameter, buried 3.5 m",
                "single pipe, but geometry/material/diameter/operation differ strongly from Sharan case",
                "velocity-sweep aggregate DT, heating potential, COP, tube efficiency",
                "usable only as a separate independent 42 m heating-mode validation after building matching model cases",
            ),
        ],
        columns=["paper", "geometry", "single_straight_pipe_screen", "extractable_data", "decision"],
    )
    screening.to_csv(OUT / "literature_single_straight_pipe_screening.csv", index=False)
    return screening


def build_sharan_comparison():
    cfd_points_path = ROOT / "COMSOL_Sharan_50m_CFD_kepsilon_all_points.csv"
    cfd_metrics_path = ROOT / "COMSOL_Sharan_50m_CFD_kepsilon_metrics.csv"
    energy_path = ROOT / "Sharan_literature_vs_kepsilon_CFD_vs_MinaeiG_energy_recheck.csv"
    outputs = {}
    if cfd_points_path.exists():
        pts = pd.read_csv(cfd_points_path)
        pts.to_csv(OUT / "Sharan2003_experiment_vs_kepsilon_CFD_points.csv", index=False)
        outputs["points"] = pts
    if cfd_metrics_path.exists():
        metrics = pd.read_csv(cfd_metrics_path)
        metrics.to_csv(OUT / "Sharan2003_experiment_vs_kepsilon_CFD_metrics.csv", index=False)
        outputs["metrics"] = metrics
    if energy_path.exists():
        energy = pd.read_csv(energy_path)
        energy.to_csv(OUT / "Sharan2003_experiment_vs_CFD_MinaeiG_energy.csv", index=False)
        outputs["energy"] = energy
    return outputs


def plot_outputs(deldan_open, deldan_closed, sharan_outputs):
    if "points" in sharan_outputs:
        pts = sharan_outputs["points"].copy()
        fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), sharey=False)
        for ax, case_key, title in [
            (axes[0], "May", "Sharan May cooling"),
            (axes[1], "January", "Sharan January heating"),
        ]:
            sub = pts[pts["case_name"].str.contains(case_key)].copy()
            ax.plot(sub["t_day"] * 24, sub["Tmid_exp_C"], "o-", label="T25 exp")
            ax.plot(sub["t_day"] * 24, sub["Tmid_sim_C"], "o--", label="T25 CFD")
            ax.plot(sub["t_day"] * 24, sub["Tout_exp_C"], "s-", label="Tout exp")
            ax.plot(sub["t_day"] * 24, sub["Tout_sim_C"], "s--", label="Tout CFD")
            ax.set_xlabel("Time after start / h")
            ax.set_ylabel("Temperature / degC")
            ax.set_title(title)
            ax.grid(True, alpha=0.3)
        axes[0].legend(ncol=2, fontsize=8)
        fig.tight_layout()
        fig.savefig(OUT / "Fig_Sharan2003_exp_vs_kepsilon_CFD_temperatures.png", dpi=300)
        fig.savefig(OUT / "Fig_Sharan2003_exp_vs_kepsilon_CFD_temperatures.pdf")
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    ax.plot(deldan_open["velocity_m_s"], deldan_open["mean_deltaT_C"], "o-", label="Open system")
    ax.plot(deldan_closed["velocity_m_s"], deldan_closed["mean_deltaT_C"], "s-", label="Closed system")
    ax.invert_xaxis()
    ax.set_xlabel("Air velocity / m s-1")
    ax.set_ylabel("Mean temperature rise / degC")
    ax.set_title("Deldan 2017 heating-mode velocity scan")
    ax.grid(True, alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT / "Fig_Deldan2017_velocity_scan_extracted.png", dpi=300)
    fig.savefig(OUT / "Fig_Deldan2017_velocity_scan_extracted.pdf")
    plt.close(fig)


def write_report(screening, sharan_outputs):
    lines = []
    lines.append("# Single Straight Pipe Literature Validation Check\n")
    lines.append("## Screening Result\n")
    lines.append(
        "Only Sharan and Jadhav (2003) is accepted for the current strict comparison because it is the same basic "
        "single-pass 50 m buried pipe geometry used in the COMSOL/MATLAB validation case. The paper does report "
        "external spiral fins, so the comparison should be described as a Sharan single-pipe benchmark rather than "
        "a perfectly smooth bare-pipe benchmark.\n"
    )
    lines.append(
        "Diaz-Hernandez et al. (2020) is excluded from the strict set because the exchanger consists of a 6 m "
        "horizontal pipe plus vertical inlet/outlet sections, with outlet insulation. Deldan et al. (2017) is a "
        "single pipe, but it is a 42 m, 0.25 m PVC heating-mode velocity-sweep system; it should be simulated as a "
        "separate case before being used as a quantitative validation benchmark.\n"
    )
    lines.append("## Extracted Data Files\n")
    lines.append("- Sharan2003_Table1_May_hourly.csv")
    lines.append("- Sharan2003_Table2_January_hourly.csv")
    lines.append("- Sharan2003_Table3_cooling_monthly_summary.csv")
    lines.append("- Deldan2017_open_system_velocity_mean.csv")
    lines.append("- Deldan2017_closed_system_velocity_mean.csv")
    lines.append("- DiazHernandez2020_Table2_cooling_summary_excluded_geometry.csv")
    lines.append("- DiazHernandez2020_Table3_heating_summary_excluded_geometry.csv\n")
    lines.append("Figures:")
    lines.append("- Fig_Sharan2003_exp_vs_kepsilon_CFD_temperatures.png")
    lines.append("- Fig_Deldan2017_velocity_scan_extracted.png\n")

    if "metrics" in sharan_outputs:
        lines.append("## Sharan 2003 Pointwise CFD Validation\n")
        metrics = sharan_outputs["metrics"]
        for _, row in metrics.iterrows():
            lines.append(
                f"- {row.case_name}, {row.quantity}: RMSE = {row.RMSE_C:.3f} degC, "
                f"MAE = {row.MAE_C:.3f} degC, bias = {row.bias_C:.3f} degC, "
                f"max abs = {row.max_abs_C:.3f} degC."
            )
        lines.append("")
    if "energy" in sharan_outputs:
        lines.append("## Sharan 2003 Short-Time Energy Validation\n")
        energy = sharan_outputs["energy"]
        for _, row in energy.iterrows():
            lines.append(
                f"- {row.case}: experiment = {row.E_literature_exp_kWh:.3f} kWh, "
                f"k-epsilon CFD = {row.E_kepsilon_CFD_kWh:.3f} kWh "
                f"({row.CFD_minus_exp_percent:.2f}%), MATLAB Minaei-G = {row.E_MinaeiG_kWh:.3f} kWh "
                f"({row.MinaeiG_minus_exp_percent:.2f}%)."
            )
        lines.append("")

    lines.append("## Recommended Use In The Paper\n")
    lines.append(
        "Use Sharan and Jadhav (2003) for strict single-pipe short-time validation. Use Deldan et al. (2017) only "
        "after adding a separate 42 m PVC heating-mode model with the same velocity, diameter, depth, and open/closed "
        "boundary condition. Do not include Diaz-Hernandez et al. (2020) in the strict single-straight-pipe validation."
    )
    (OUT / "single_straight_pipe_literature_validation_report.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    write_sharan_extracted()
    deldan_open, deldan_closed = write_deldan_extracted()
    write_geothermics_extracted()
    screening = build_screening_table()
    sharan_outputs = build_sharan_comparison()
    plot_outputs(deldan_open, deldan_closed, sharan_outputs)
    write_report(screening, sharan_outputs)
    print(f"Wrote literature validation outputs to {OUT}")


if __name__ == "__main__":
    main()
