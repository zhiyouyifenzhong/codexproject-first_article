from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from build_paper_ready_origin_figures import OUT, prepare_data


PNG = OUT / "journal_standard_png"
PDF = OUT / "journal_standard_pdf"
TIFF = OUT / "journal_standard_tiff"

AXIS_LABEL_SIZE = 10.5
TICK_LABEL_SIZE = 9.5
LEGEND_SIZE = 9.0
LINE_WIDTH = 1.7

COLORS = [
    "#4D4D4D",
    "#D62728",
    "#1F77B4",
    "#2CA25F",
    "#9467BD",
    "#D99A00",
    "#17BECF",
    "#8C564B",
]
LINESTYLES = ["-", "-", "-", "-", "-", "-", "--", ":"]


plt.rcParams.update(
    {
        "font.family": "Times New Roman",
        "mathtext.fontset": "stix",
        "axes.unicode_minus": False,
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "savefig.facecolor": "white",
        "axes.linewidth": 0.9,
    }
)


Y_LABELS = {
    "Fig00d_Tout_literature_comparison": "Outlet temperature (degC)",
    "Fig00e_Qair_literature_comparison": "Heat-transfer rate (W)",
    "Fig01_Tin_Th_Tout": "Temperature (degC)",
    "Fig02_Tout_deviation": "Outlet-temperature deviation (degC)",
    "Fig03_heat_rate": "Heat-transfer rate (W)",
    "Fig04_interface_temperature_jump": "Interface temperature jump (degC)",
    "Fig05_energy_balance_residual": "Energy-balance residual (-)",
    "Fig06_resistance_contribution": "Resistance contribution (%)",
    "Fig08_annual_energy_vs_delta": "Annual heat-exchange energy (kWh)",
    "Fig09_Dgap_vs_delta": "Annual degradation (%)",
    "Fig10_Tout_deviation_summary": "Outlet-temperature deviation (degC)",
    "Fig11_interface_jump_summary": "Interface temperature jump (degC)",
    "Fig17_factor_contact_Tout_curves": "Outlet temperature (degC)",
    "Fig18_Vaz_Minaei_validation_curves_no_green": "Outlet temperature (degC)",
    "Fig19_Vaz_Minaei_validation_residuals_no_green": "Temperature residual (degC)",
}


def ensure_dirs():
    for folder in [PNG, PDF, TIFF]:
        folder.mkdir(parents=True, exist_ok=True)


def style_axis(ax, xlabel=None, ylabel=None):
    if xlabel:
        ax.set_xlabel(xlabel, fontsize=AXIS_LABEL_SIZE)
    if ylabel:
        ax.set_ylabel(ylabel, fontsize=AXIS_LABEL_SIZE)
    ax.tick_params(axis="both", labelsize=TICK_LABEL_SIZE, direction="out", length=4, width=0.9)
    ax.grid(False)
    for spine in ax.spines.values():
        spine.set_linewidth(0.9)


def plot_lines(ax, x, df, columns, start_color=0):
    handles = []
    labels = []
    for i, col in enumerate(columns):
        line = ax.plot(
            x,
            df[col],
            label=col,
            color=COLORS[(i + start_color) % len(COLORS)],
            linestyle=LINESTYLES[(i + start_color) % len(LINESTYLES)],
            linewidth=LINE_WIDTH,
        )[0]
        handles.append(line)
        labels.append(col)
    return handles, labels


def save_fig(fig, name):
    fig.savefig(PNG / f"{name}.png", dpi=600, bbox_inches="tight")
    fig.savefig(PDF / f"{name}.pdf", bbox_inches="tight")
    fig.savefig(TIFF / f"{name}.tiff", dpi=600, bbox_inches="tight")
    plt.close(fig)


def add_legend(fig, handles, labels, ncol=None):
    ncol = ncol or min(4, max(1, len(labels)))
    fig.legend(
        handles,
        labels,
        loc="upper center",
        bbox_to_anchor=(0.5, 1.02),
        ncol=ncol,
        frameon=False,
        fontsize=LEGEND_SIZE,
        handlelength=2.4,
        columnspacing=1.4,
    )


def apply_limits(ax, cfg):
    if cfg.get("xlim"):
        ax.set_xlim(*cfg["xlim"])
    if cfg.get("ylim"):
        ax.set_ylim(*cfg["ylim"])


def plot_standard(cfg, df):
    fig, ax = plt.subplots(figsize=(6.6, 4.4))
    x = df.iloc[:, 0]
    ycols = list(df.columns[1:])
    handles, labels = plot_lines(ax, x, df, ycols)
    apply_limits(ax, cfg)
    style_axis(ax, cfg["xlabel"], Y_LABELS.get(cfg["name"], cfg["ylabel"]))
    add_legend(fig, handles, labels)
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    save_fig(fig, cfg["name"])


def plot_dual_axis(cfg, df, left_cols, right_cols, left_label, right_label):
    fig, ax1 = plt.subplots(figsize=(6.6, 4.4))
    ax2 = ax1.twinx()
    x = df.iloc[:, 0]
    h1, l1 = plot_lines(ax1, x, df, left_cols)
    h2, l2 = plot_lines(ax2, x, df, right_cols, start_color=len(left_cols))
    apply_limits(ax1, cfg)
    style_axis(ax1, cfg["xlabel"], left_label)
    style_axis(ax2, None, right_label)
    add_legend(fig, h1 + h2, l1 + l2)
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    save_fig(fig, cfg["name"])


def plot_two_panel_gap_factor(cfg, df):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(6.6, 5.5), sharex=True)
    x = df.iloc[:, 0]
    h1, l1 = plot_lines(ax1, x, df, ["eta_U", "Ldelta/L0"])
    ax2b = ax2.twinx()
    h2, l2 = plot_lines(ax2, x, df, ["Dgap"], start_color=2)
    h3, l3 = plot_lines(ax2b, x, df, ["TintJump mean"], start_color=3)
    style_axis(ax1, None, "Correction factor (-)")
    style_axis(ax2, cfg["xlabel"], "Annual degradation (%)")
    style_axis(ax2b, None, "Temperature jump (degC)")
    add_legend(fig, h1 + h2 + h3, l1 + l2 + l3, ncol=4)
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    save_fig(fig, cfg["name"])


def plot_two_panel_contact_factor(cfg, df):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(6.6, 5.5), sharex=True)
    x = df.iloc[:, 0]
    h1, l1 = plot_lines(ax1, x, df, ["eta_U"])
    ax2b = ax2.twinx()
    h2, l2 = plot_lines(ax2, x, df, ["Dgap", "ElossVsContact"], start_color=2)
    h3, l3 = plot_lines(ax2b, x, df, ["TintJump mean"], start_color=4)
    style_axis(ax1, None, "Correction factor (-)")
    style_axis(ax2, cfg["xlabel"], "Performance change (%)")
    style_axis(ax2b, None, "Temperature jump (degC)")
    add_legend(fig, h1 + h2 + h3, l1 + l2 + l3, ncol=4)
    fig.tight_layout(rect=(0, 0, 1, 0.90))
    save_fig(fig, cfg["name"])


def plot_config(cfg):
    df = pd.read_csv(cfg["csv"])
    name = cfg["name"]

    if name == "Fig00f_literature_error_energy":
        plot_dual_axis(
            cfg,
            df,
            ["Tout RMSE vs literature", "Tout max abs vs literature"],
            ["Eabs relative change"],
            "Outlet-temperature error (degC)",
            "Annual energy change (%)",
        )
    elif name == "Fig07_engineering_correction":
        plot_dual_axis(
            cfg,
            df,
            ["eta_U", "Ldelta/L0"],
            ["Rint"],
            "Correction factor (-)",
            "Interface resistance (m K/W)",
        )
    elif name == "Fig12_interface_resistance_limit":
        plot_dual_axis(
            cfg,
            df,
            ["Rgap mK", "Rdelta mK"],
            ["Jump at q10"],
            "Thermal resistance (m K/W)",
            "Temperature jump (degC)",
        )
    elif name in ["Fig13_Nx_independence", "Fig14_dt_independence"]:
        plot_dual_axis(
            cfg,
            df,
            ["RMSE"],
            ["Eabs error"],
            "Outlet-temperature RMSE (degC)",
            "Annual energy error (%)",
        )
    elif name == "Fig15_factor_gap_thickness":
        plot_two_panel_gap_factor(cfg, df)
    elif name == "Fig16_factor_contact_coefficient":
        plot_two_panel_contact_factor(cfg, df)
    else:
        plot_standard(cfg, df)


def main():
    ensure_dirs()
    configs = prepare_data()
    for cfg in configs:
        print("Rendering journal standard", cfg["name"])
        plot_config(cfg)
    print(f"Wrote journal-standard images to {OUT}")


if __name__ == "__main__":
    main()
