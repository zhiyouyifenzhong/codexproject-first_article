import csv
import os
import shutil
import time
from pathlib import Path

import win32com.client


ROOT = Path(r"G:\codexproject")
SRC = ROOT / "EAHE_airgap_physical_v18_minaei_contact_results" / "Origin_ready_data_all_figures"
OUT = SRC / "paper_ready_origin_figures"
DATA = OUT / "data"
PNG = OUT / "png"
PDF = OUT / "pdf"
TIFF = OUT / "tiff"
INTEGRATED = OUT / "integrated_previous_validation"


def lt_path(path):
    return str(path).replace("\\", "\\\\")


def ensure_dirs():
    for folder in [OUT, DATA, PNG, PDF, TIFF, INTEGRATED]:
        folder.mkdir(parents=True, exist_ok=True)


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    return rows, list(rows[0].keys()) if rows else []


def pretty_label(name):
    labels = {
        "day": "Day",
        "time_day": "Day",
        "delta_mm": "Gap",
        "contact_coeff_chi": "Contact",
        "dt_h": "dt",
        "Nx": "Nx",
        "Tin_C": "Inlet",
        "Th_C": "Soil",
        "Tout_literature_C": "Literature",
        "Qair_literature_W": "Literature",
        "Tout_MATLAB_VazParams_C": "MATLAB",
        "digitized_present_study_black_C": "Present study",
        "digitized_Vaz_full_numerical_red_dashed_C": "Vaz full",
        "digitized_Brum_simplified_red_solid_C": "Brum simplified",
        "MATLAB_minus_present_study_C": "vs Present",
        "MATLAB_minus_Vaz_full_numerical_C": "vs Vaz full",
        "MATLAB_minus_Brum_simplified_C": "vs Brum",
        "RMSE_Tout_C": "RMSE",
        "RelErr_Eabs_percent": "Eabs error",
        "Dgap_percent": "Dgap",
        "etaU": "eta_U",
        "Ldelta_over_L0": "Ldelta/L0",
        "Rint_eff_mK_W": "Rint",
        "Ra_percent": "Air",
        "Rp_percent": "Pipe",
        "Rs0_percent": "Soil",
        "Rint_percent": "Interface",
    }
    if name in labels:
        return labels[name]
    out = name
    replacements = [
        ("Tout_improved_delta_", "Improved "),
        ("Tout_delta_", "Tout "),
        ("Qair_improved_delta_", "Improved "),
        ("Qair_delta_", "Qair "),
        ("DeltaTout_delta_", "Gap "),
        ("TintJumpMeanAbs_delta_", "Mean "),
        ("EnergyResidual_delta_", "Gap "),
        ("Tout_chi_", "chi "),
        ("_0p5", "0.5"),
        ("_0p25", "0.25"),
        ("_0p75", "0.75"),
        ("_0p1", "0.1"),
        ("_0p9", "0.9"),
        ("_mm", " mm"),
        ("_C", ""),
        ("_W", ""),
        ("_percent", ""),
        ("_", " "),
    ]
    for old, new in replacements:
        out = out.replace(old, new)
    return out.strip()


def write_selected_csv(src, dest_name, columns, rename=None):
    rows, headers = read_csv(src)
    rename = rename or {c: pretty_label(c) for c in columns}
    out_headers = [rename.get(c, c) for c in columns]
    dest = DATA / dest_name
    with dest.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=out_headers)
        writer.writeheader()
        for row in rows:
            writer.writerow({rename.get(c, c): row.get(c, "") for c in columns})
    return dest


def copy_integrated_files():
    sources = [
        ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Vaz_Minaei_params_MATLAB_vs_digitized_points.csv",
        ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Vaz_Minaei_params_MATLAB_vs_digitized_metrics.csv",
        ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Vaz_Minaei_params_used.csv",
        ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Vaz_Minaei_params_digitized_validation_report.md",
        ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Fig_MATLAB_VazParams_vs_digitized_curves.png",
        ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Fig_MATLAB_VazParams_residuals.png",
        ROOT / "image_digitization_1783561607343" / "digitized_1783561607343_daily.csv",
        ROOT / "image_digitization_1783561607343" / "digitized_1783561607343_overlay.png",
        ROOT / "image_digitization_1783561607343" / "digitized_1783561607343_replot.png",
        ROOT / "image_digitization_1783561607343" / "digitized_1783561607343_data.xlsx",
    ]
    for src in sources:
        if src.exists():
            shutil.copy2(src, INTEGRATED / src.name)


def prepare_data():
    configs = []

    def add(name, source, columns, xlabel, ylabel, title, xlim=None, ylim=None, rename=None):
        clean_name = name + ".csv"
        csv_path = write_selected_csv(SRC / source, clean_name, columns, rename)
        configs.append(
            {
                "name": name,
                "csv": csv_path,
                "xlabel": xlabel,
                "ylabel": ylabel,
                "title": title,
                "xlim": xlim,
                "ylim": ylim,
            }
        )

    add(
        "Fig00d_Tout_literature_comparison",
        "Origin_Fig00d_improved_vs_literature_Tout.csv",
        [
            "day",
            "Tout_literature_C",
            "Tout_improved_delta_0_mm_C",
            "Tout_improved_delta_1_mm_C",
            "Tout_improved_delta_3_mm_C",
            "Tout_improved_delta_5_mm_C",
        ],
        "Time (day)",
        "Outlet temperature (degC)",
        "Improved model vs literature model",
        (0, 365),
    )
    add(
        "Fig00e_Qair_literature_comparison",
        "Origin_Fig00e_improved_vs_literature_Qair.csv",
        [
            "day",
            "Qair_literature_W",
            "Qair_improved_delta_0_mm_W",
            "Qair_improved_delta_1_mm_W",
            "Qair_improved_delta_3_mm_W",
            "Qair_improved_delta_5_mm_W",
        ],
        "Time (day)",
        "Heat-transfer rate (W)",
        "Annual heat-transfer rate comparison",
        (0, 365),
    )
    add(
        "Fig00f_literature_error_energy",
        "Origin_Fig00f_improved_vs_literature_energy.csv",
        [
            "delta_mm",
            "Tout_RMSE_vs_literature_C",
            "Tout_max_abs_vs_literature_C",
            "Eabs_relative_change_percent",
        ],
        "Air-gap thickness (mm)",
        "Error or relative change",
        "Improved model deviation from literature model",
    )
    add(
        "Fig01_Tin_Th_Tout",
        "Origin_Fig01_Tin_Th_Tout.csv",
        ["day", "Tin_C", "Th_C", "Tout_delta_0_mm_C", "Tout_delta_1_mm_C", "Tout_delta_3_mm_C", "Tout_delta_5_mm_C"],
        "Time (day)",
        "Temperature (degC)",
        "Annual inlet, soil and outlet temperatures",
        (0, 365),
    )
    add(
        "Fig02_Tout_deviation",
        "Origin_Fig02_Tout_deviation.csv",
        ["day", "DeltaTout_delta_0p5_mm_C", "DeltaTout_delta_1_mm_C", "DeltaTout_delta_2_mm_C", "DeltaTout_delta_3_mm_C", "DeltaTout_delta_5_mm_C"],
        "Time (day)",
        "Outlet-temperature deviation (degC)",
        "Outlet-temperature deviation caused by air gap",
        (0, 365),
    )
    add(
        "Fig03_heat_rate",
        "Origin_Fig03_heat_rate.csv",
        ["day", "Qair_delta_0_mm_W", "Qair_delta_1_mm_W", "Qair_delta_3_mm_W", "Qair_delta_5_mm_W"],
        "Time (day)",
        "Heat-transfer rate (W)",
        "Annual heat-transfer rate",
        (0, 365),
    )
    add(
        "Fig04_interface_temperature_jump",
        "Origin_Fig04_interface_temperature_jump.csv",
        ["day", "TintJumpMeanAbs_delta_0p5_mm_C", "TintJumpMeanAbs_delta_1_mm_C", "TintJumpMeanAbs_delta_2_mm_C", "TintJumpMeanAbs_delta_3_mm_C", "TintJumpMeanAbs_delta_5_mm_C"],
        "Time (day)",
        "Mean absolute temperature jump (degC)",
        "Interface temperature jump",
        (0, 365),
    )
    add(
        "Fig05_energy_balance_residual",
        "Origin_Fig05_energy_balance_residual.csv",
        ["day", "EnergyResidual_delta_0_mm", "EnergyResidual_delta_1_mm", "EnergyResidual_delta_3_mm", "EnergyResidual_delta_5_mm"],
        "Time (day)",
        "Energy-balance residual",
        "Energy-balance residual",
        (0, 365),
    )
    add(
        "Fig06_resistance_contribution",
        "Origin_Fig06_resistance_contribution.csv",
        ["delta_mm", "Ra_percent", "Rp_percent", "Rs0_percent", "Rint_percent"],
        "Air-gap thickness (mm)",
        "Resistance contribution (%)",
        "Thermal-resistance contribution",
    )
    add(
        "Fig07_engineering_correction",
        "Origin_Fig07_engineering_correction_factors.csv",
        ["delta_mm", "etaU", "Ldelta_over_L0", "Rint_eff_mK_W"],
        "Air-gap thickness (mm)",
        "Correction factor or resistance",
        "Engineering correction factors",
    )
    add(
        "Fig08_annual_energy_vs_delta",
        "Origin_Fig08_annual_energy_vs_delta.csv",
        ["delta_mm", "Ecool_kWh", "Eheat_kWh", "Eabs_kWh"],
        "Air-gap thickness (mm)",
        "Annual energy (kWh)",
        "Annual heat-exchange energy",
    )
    add(
        "Fig09_Dgap_vs_delta",
        "Origin_Fig09_Dgap_vs_delta.csv",
        ["delta_mm", "Dgap_percent"],
        "Air-gap thickness (mm)",
        "Annual degradation (%)",
        "Annual performance degradation",
    )
    add(
        "Fig10_Tout_deviation_summary",
        "Origin_Fig10_Tout_deviation_summary.csv",
        ["delta_mm", "DeltaToutMean_C", "DeltaToutMax_C"],
        "Air-gap thickness (mm)",
        "Outlet-temperature deviation (degC)",
        "Summary of outlet-temperature deviation",
    )
    add(
        "Fig11_interface_jump_summary",
        "Origin_Fig11_interface_jump_summary.csv",
        ["delta_mm", "TintJump_mean_C", "TintJump_max_C"],
        "Air-gap thickness (mm)",
        "Interface temperature jump (degC)",
        "Summary of interface temperature jump",
    )
    add(
        "Fig12_interface_resistance_limit",
        "Origin_Fig12_interface_resistance_limit.csv",
        ["delta_mm", "Rgap_mK_W", "Rdelta_mK_W", "Jump_at_q10_C"],
        "Air-gap thickness (mm)",
        "Resistance or jump",
        "Interface resistance limit",
    )
    add(
        "Fig13_Nx_independence",
        "Origin_Fig13_Nx_independence.csv",
        ["Nx", "RMSE_Tout_C", "RelErr_Eabs_percent"],
        "Axial grid number",
        "Numerical error",
        "Axial-grid independence",
    )
    add(
        "Fig14_dt_independence",
        "Origin_Fig14_dt_independence.csv",
        ["dt_h", "RMSE_Tout_C", "RelErr_Eabs_percent"],
        "Time step (h)",
        "Numerical error",
        "Time-step independence",
    )
    add(
        "Fig15_factor_gap_thickness",
        "Origin_Fig15_factor_gap_thickness.csv",
        ["delta_mm", "etaU", "Ldelta_over_L0", "Dgap_percent", "TintJump_mean_C"],
        "Air-gap thickness (mm)",
        "Factor value",
        "Gap-thickness factor analysis",
    )
    add(
        "Fig16_factor_contact_coefficient",
        "Origin_Fig16_factor_contact_coefficient.csv",
        ["contact_coeff_chi", "etaU", "Dgap_percent", "ElossVsContact_percent", "TintJump_mean_C"],
        "Contact coefficient",
        "Factor value",
        "Contact-coefficient factor analysis",
    )
    add(
        "Fig17_factor_contact_Tout_curves",
        "Origin_Fig17_factor_contact_Tout_curves.csv",
        ["day", "Tout_chi_0_C", "Tout_chi_0p25_C", "Tout_chi_0p5_C", "Tout_chi_0p75_C", "Tout_chi_1_C"],
        "Time (day)",
        "Outlet temperature (degC)",
        "Outlet temperature under different contact coefficients",
        (0, 365),
    )

    val_src = ROOT / "MATLAB_Vaz_Minaei_params_digitized_validation" / "Vaz_Minaei_params_MATLAB_vs_digitized_points.csv"
    add(
        "Fig18_Vaz_Minaei_validation_curves_no_green",
        str(val_src.relative_to(SRC)) if False else val_src,
        ["time_day", "Tout_MATLAB_VazParams_C", "digitized_present_study_black_C", "digitized_Vaz_full_numerical_red_dashed_C", "digitized_Brum_simplified_red_solid_C"],
        "Time (day)",
        "Outlet temperature (degC)",
        "Vaz/Minaei parameter validation",
        (0, 365),
        (14, 25),
    )
    add(
        "Fig19_Vaz_Minaei_validation_residuals_no_green",
        val_src,
        ["time_day", "MATLAB_minus_present_study_C", "MATLAB_minus_Vaz_full_numerical_C", "MATLAB_minus_Brum_simplified_C"],
        "Time (day)",
        "MATLAB - digitized target (degC)",
        "Vaz/Minaei validation residuals",
        (0, 365),
        (-1.8, 0.6),
    )

    return configs


def import_and_plot(app, cfg):
    csv_path = cfg["csv"]
    graph_name = cfg["name"]
    app.Execute(f"newbook name:={graph_name[:24]} option:=lsname;")
    app.Execute(f'impASC fname:="{lt_path(csv_path)}";')

    rows, headers = read_csv(csv_path)
    ncols = len(headers)
    if ncols <= 1:
        return
    if ncols == 2:
        app.Execute("range rr = 1!(1,2);")
    else:
        app.Execute(f"range rr = 1!(1,2:{ncols});")

    # plot 200 is a line plot. The cleaned CSVs keep the first column as X.
    app.Execute("plotxy iy:=rr plot:=200;")
    app.Execute(f'page.longname$ = "{cfg["title"]}";')
    app.Execute(f'label -xb "{cfg["xlabel"]}";')
    app.Execute(f'label -yl "{cfg["ylabel"]}";')
    if cfg.get("xlim"):
        x0, x1 = cfg["xlim"]
        app.Execute(f"layer.x.from={x0}; layer.x.to={x1};")
    if cfg.get("ylim"):
        y0, y1 = cfg["ylim"]
        app.Execute(f"layer.y.from={y0}; layer.y.to={y1};")
    app.Execute("legend -r;")
    app.Execute("layer -g;")

    for typ, folder in [("png", PNG), ("pdf", PDF), ("tif", TIFF)]:
        if typ == "pdf":
            app.Execute(f'expGraph type:=pdf path:="{lt_path(folder)}" filename:="{graph_name}" overwrite:=replace;')
        else:
            app.Execute(f'expGraph type:={typ} path:="{lt_path(folder)}" filename:="{graph_name}" overwrite:=replace tr1:=600;')


def save_index(configs):
    index = OUT / "PAPER_READY_ORIGIN_FIGURE_INDEX.md"
    lines = [
        "# Paper-ready Origin figure package",
        "",
        "This folder was generated from the original Origin-ready CSV files and integrated with the Vaz/Minaei digitized validation outputs.",
        "",
        "Subfolders:",
        "- `data/`: cleaned plotting CSV files used by Origin.",
        "- `png/`, `pdf/`, `tiff/`: exported figure images.",
        "- `integrated_previous_validation/`: copied digitization and MATLAB validation files from the previous workflow.",
        "",
        "Figures:",
    ]
    for cfg in configs:
        lines.append(f"- {cfg['name']}: {cfg['title']}")
    lines.extend(
        [
            "",
            "Notes:",
            "- Fig18 and Fig19 intentionally omit the green experimental curve from the main validation figure; green-curve data remain in the integrated CSV files for supplementary discussion.",
            "- The Origin project file contains all generated worksheets and graph pages.",
        ]
    )
    index.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    ensure_dirs()
    copy_integrated_files()
    configs = prepare_data()

    app = win32com.client.Dispatch("Origin.ApplicationSI")
    app.Execute("doc -mc 1;")
    app.Execute("doc -n;")
    for cfg in configs:
        print("Plotting", cfg["name"])
        import_and_plot(app, cfg)

    project = OUT / "EAHE_airgap_paper_ready_all_figures.opju"
    app.Execute(f'save -DIJ "{lt_path(project)}";')
    time.sleep(1)
    app.Exit()
    save_index(configs)
    print(f"Wrote paper-ready Origin package to {OUT}")


if __name__ == "__main__":
    main()
