import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.gridspec as gridspec
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


plt.rcParams["font.family"] = "sans-serif"
plt.rcParams["font.sans-serif"] = ["Arial", "DejaVu Sans", "Liberation Sans"]
plt.rcParams["svg.fonttype"] = "none"
plt.rcParams["pdf.fonttype"] = 42
plt.rcParams.update({
    "font.size": 7,
    "axes.spines.right": False,
    "axes.spines.top": False,
    "axes.linewidth": 0.75,
    "xtick.major.width": 0.75,
    "ytick.major.width": 0.75,
    "xtick.major.size": 2.3,
    "ytick.major.size": 2.3,
    "legend.frameon": False,
})


ROOT = r"G:\codexproject"
POINTS_FILE = os.path.join(
    ROOT,
    "Validation_annual_CFD_vs_MATLAB_Tout_only",
    "Annual_CFD_vs_MATLAB_Tout_only_points.csv",
)
METRICS_FILE = os.path.join(
    ROOT,
    "Validation_annual_CFD_vs_MATLAB_Tout_only",
    "Annual_CFD_vs_MATLAB_Tout_only_metrics.csv",
)
ENERGY_FILE = os.path.join(
    ROOT,
    "COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon",
    "COMSOL_annual_kepsilon_vs_MinaeiG_comparison.csv",
)

OUT_DIR = os.path.join(ROOT, "Minaei_parameter_gap_CFD_MinaeiG_validation")
FIG_DIR = os.path.join(OUT_DIR, "nature_python_figures")
ORIGIN_DIR = os.path.join(OUT_DIR, "origin_data")

COL = {
    "black": "#272727",
    "grey": "#767676",
    "light": "#D8D8D8",
    "blue": "#0F4D92",
    "blue_soft": "#DCE8F6",
    "red": "#B64342",
    "red_soft": "#F6CFCB",
    "teal": "#42949E",
}


def ensure(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def as_float_array(values):
    return np.asarray(values, dtype=float)


def rmse(values):
    v = as_float_array(values)
    v = v[np.isfinite(v)]
    return float(np.sqrt(np.mean(v ** 2)))


def mae(values):
    v = as_float_array(values)
    v = v[np.isfinite(v)]
    return float(np.mean(np.abs(v)))


def style_ax(ax):
    ax.tick_params(direction="out", width=0.75, length=2.3, pad=2)
    ax.grid(False)
    return ax


def add_panel(ax, letter):
    ax.text(-0.12, 1.05, letter, transform=ax.transAxes, ha="left",
            va="bottom", fontsize=8.0, fontweight="bold", color=COL["black"])


def save_pub(fig, stem):
    ensure(FIG_DIR)
    base = os.path.join(FIG_DIR, stem)
    fig.savefig(base + ".svg", bbox_inches="tight")
    fig.savefig(base + ".pdf", bbox_inches="tight")
    fig.savefig(base + ".png", dpi=600, bbox_inches="tight")
    fig.savefig(base + ".tiff", dpi=600, bbox_inches="tight")
    plt.close(fig)


def load_data():
    pts = pd.read_csv(POINTS_FILE)
    met = pd.read_csv(METRICS_FILE)
    eng = pd.read_csv(ENERGY_FILE)
    deltas = sorted([int(x) for x in pts["delta_mm"].unique()])
    return pts, met, eng, deltas


def export_origin_data(pts, met, eng, deltas):
    ensure(ORIGIN_DIR)
    for delta in deltas:
        d = pts[pts["delta_mm"] == delta].copy()
        d = d[[
            "t_day",
            "Tin_C",
            "Tout_CFD_kepsilon_C",
            "Tout_MATLAB_MinaeiG_C",
            "Tout_MATLAB_minus_CFD_C",
        ]]
        d.columns = [
            "Time_day",
            "Tin_C",
            "Tout_CFD_kepsilon_C",
            "Tout_MinaeiG_model_C",
            "Tout_MinaeiG_minus_CFD_C",
        ]
        d.to_csv(
            os.path.join(
                ORIGIN_DIR,
                "Origin_Minaei_params_Tout_CFD_vs_MinaeiG_delta_%dmm.csv" % delta,
            ),
            index=False,
        )

    met_out = met.copy()
    met_out.to_csv(
        os.path.join(ORIGIN_DIR, "Origin_Minaei_params_Tout_error_metrics.csv"),
        index=False,
    )

    keep = [
        "delta_mm",
        "Ecool_kWh_CFD",
        "Eheat_kWh_CFD",
        "Eabs_kWh_CFD",
        "Dgap_percent_CFD",
        "Ecool_kWh_MinaeiG",
        "Eheat_kWh_MinaeiG",
        "Eabs_kWh_MinaeiG",
        "Dgap_percent_MinaeiG",
        "Ecool_kWh_CFD_minus_MinaeiG_percent",
        "Eheat_kWh_CFD_minus_MinaeiG_percent",
        "Eabs_kWh_CFD_minus_MinaeiG_percent",
        "Dgap_CFD_minus_MinaeiG_pctpt",
    ]
    eng_out = eng[[c for c in keep if c in eng.columns]].copy()
    eng_out.to_csv(
        os.path.join(ORIGIN_DIR, "Origin_Minaei_params_annual_energy_gap_summary.csv"),
        index=False,
    )

    with open(os.path.join(ORIGIN_DIR, "README_Origin_data.txt"), "w") as f:
        f.write("Minaei-parameter CFD vs Minaei-G model validation data\n")
        f.write("Validated k-epsilon CFD gap cases available here: 0, 1, and 5 mm.\n")
        f.write("No interpolated CFD is generated for unrun gaps.\n")
        f.write("Use the per-gap Tout CSVs for annual outlet-temperature curves.\n")
        f.write("Use the energy summary CSV for annual heat-exchange and Dgap plots.\n")


def plot_case(ax, axr, pts, met, delta, letter1, letter2):
    d = pts[pts["delta_mm"] == delta].sort_values("t_day")
    m = met[met["delta_mm"] == delta].iloc[0]
    t = as_float_array(d["t_day"])
    tin = as_float_array(d["Tin_C"])
    cfd = as_float_array(d["Tout_CFD_kepsilon_C"])
    model = as_float_array(d["Tout_MATLAB_MinaeiG_C"])
    err = as_float_array(d["Tout_MATLAB_minus_CFD_C"])

    ax.plot(t, tin, color=COL["light"], lw=0.85, zorder=1)
    ax.plot(t, cfd, color=COL["red"], lw=1.25, zorder=3)
    ax.plot(t, model, color=COL["blue"], lw=1.25, ls="--", zorder=4)
    ax.set_xlim(0, 365)
    ax.set_ylim(14.0, 27.0)
    ax.set_ylabel("Temperature (deg C)")
    ax.set_title("gap = %d mm" % delta, loc="left", fontsize=7.3, pad=2)
    ax.text(0.03, 0.08, "RMSE = %.2f deg C" % float(m["RMSE_C"]),
            transform=ax.transAxes, fontsize=6.2, color=COL["grey"])
    if delta == 0:
        ax.text(0.70, 0.86, "Inlet", transform=ax.transAxes,
                fontsize=6.1, color=COL["light"])
        ax.text(0.70, 0.78, "CFD k-epsilon", transform=ax.transAxes,
                fontsize=6.1, color=COL["red"])
        ax.text(0.70, 0.70, "Minaei-G model", transform=ax.transAxes,
                fontsize=6.1, color=COL["blue"])
    add_panel(ax, letter1)

    axr.axhline(0, color=COL["light"], lw=0.9, zorder=1)
    axr.fill_between(t, 0, err, where=err >= 0, color=COL["blue_soft"], lw=0)
    axr.fill_between(t, 0, err, where=err < 0, color=COL["red_soft"], lw=0)
    axr.plot(t, err, color=COL["black"], lw=1.0, zorder=3)
    axr.set_xlim(0, 365)
    ylim = 2.0 if delta == 5 else 0.9
    axr.set_ylim(-0.75, ylim)
    axr.set_ylabel("Model - CFD\n(deg C)")
    axr.set_title("residual, gap = %d mm" % delta, loc="left", fontsize=7.3, pad=2)
    axr.text(0.03, 0.08, "bias = %.2f deg C" % float(m["bias_MATLAB_minus_CFD_C"]),
             transform=axr.transAxes, fontsize=6.2, color=COL["grey"])
    add_panel(axr, letter2)


def make_tout_figure(pts, met, deltas):
    fig = plt.figure(figsize=(7.2, 7.1))
    gs = gridspec.GridSpec(len(deltas), 2, figure=fig, wspace=0.32, hspace=0.46,
                           width_ratios=[1.15, 1.0])
    letters = list("abcdef")
    for i, delta in enumerate(deltas):
        ax = fig.add_subplot(gs[i, 0])
        axr = fig.add_subplot(gs[i, 1])
        style_ax(ax)
        style_ax(axr)
        plot_case(ax, axr, pts, met, delta, letters[2 * i], letters[2 * i + 1])
        if i == len(deltas) - 1:
            ax.set_xlabel("Time (day)")
            axr.set_xlabel("Time (day)")
        else:
            ax.set_xticklabels([])
            axr.set_xticklabels([])
    save_pub(fig, "Nature_Fig01_Minaei_params_gap_Tout_CFD_vs_MinaeiG")


def make_energy_figure(eng):
    e = eng.sort_values("delta_mm").reset_index(drop=True)
    x = as_float_array(e["delta_mm"])
    labels = ["%g" % v for v in x]
    xpos = np.arange(len(x))
    width = 0.34

    fig = plt.figure(figsize=(7.2, 4.6))
    gs = gridspec.GridSpec(2, 2, figure=fig, wspace=0.34, hspace=0.42)
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    ax3 = fig.add_subplot(gs[1, 0])
    ax4 = fig.add_subplot(gs[1, 1])
    for ax in [ax1, ax2, ax3, ax4]:
        style_ax(ax)

    b1 = ax1.bar(xpos - width / 2, e["Eabs_kWh_CFD"], width=width,
                 color=COL["red"], edgecolor=COL["black"], linewidth=0.45,
                 label="CFD")
    b2 = ax1.bar(xpos + width / 2, e["Eabs_kWh_MinaeiG"], width=width,
                 color=COL["blue"], edgecolor=COL["black"], linewidth=0.45,
                 label="Minaei-G")
    ax1.set_xticks(xpos)
    ax1.set_xticklabels(labels)
    ax1.set_xlabel("Air-gap thickness (mm)")
    ax1.set_ylabel("Annual |Q| (kWh)")
    ax1.set_title("Annual heat exchange", loc="left", fontsize=7.3, pad=2)
    ax1.legend(loc="upper right", fontsize=6.1)
    add_panel(ax1, "a")

    ax2.axhline(0, color=COL["light"], lw=0.9)
    err = as_float_array(e["Eabs_kWh_CFD_minus_MinaeiG_percent"])
    ax2.bar(xpos, err, width=0.5, color=COL["teal"],
            edgecolor=COL["black"], linewidth=0.45)
    ax2.set_ylim(min(-2.1, float(np.nanmin(err)) - 0.25), 0.18)
    ax2.set_xticks(xpos)
    ax2.set_xticklabels(labels)
    ax2.set_xlabel("Air-gap thickness (mm)")
    ax2.set_ylabel("CFD - model (%)")
    ax2.set_title("|Q| difference", loc="left", fontsize=7.3, pad=2)
    for xx, yy in zip(xpos, err):
        if yy >= 0:
            ax2.text(xx, yy + 0.08, "%.2f" % yy, ha="center",
                     va="bottom", fontsize=6.0)
        else:
            ax2.text(xx, yy + 0.10, "%.2f" % yy, ha="center",
                     va="bottom", fontsize=6.0)
    add_panel(ax2, "b")

    ax3.bar(xpos - width / 2, e["Dgap_percent_CFD"], width=width,
            color=COL["red"], edgecolor=COL["black"], linewidth=0.45)
    ax3.bar(xpos + width / 2, e["Dgap_percent_MinaeiG"], width=width,
            color=COL["blue"], edgecolor=COL["black"], linewidth=0.45)
    ax3.set_xticks(xpos)
    ax3.set_xticklabels(labels)
    ax3.set_xlabel("Air-gap thickness (mm)")
    ax3.set_ylabel("Heat-exchange reduction (%)")
    ax3.set_title("Gap-induced degradation", loc="left", fontsize=7.3, pad=2)
    add_panel(ax3, "c")

    dg = as_float_array(e["Dgap_CFD_minus_MinaeiG_pctpt"])
    ax4.axhline(0, color=COL["light"], lw=0.9)
    ax4.plot(xpos, dg, color=COL["black"], lw=1.2, marker="o", ms=3.2,
             mfc="white", mec=COL["black"])
    ax4.set_xticks(xpos)
    ax4.set_xticklabels(labels)
    ax4.set_xlabel("Air-gap thickness (mm)")
    ax4.set_ylabel("CFD - model (percentage points)")
    ax4.set_title("Dgap difference", loc="left", fontsize=7.3, pad=2)
    for xx, yy in zip(xpos, dg):
        ax4.text(xx, yy + 0.09, "%.2f" % yy, ha="center", va="bottom", fontsize=6.0)
    add_panel(ax4, "d")

    for bars in (b1, b2):
        for bar in bars:
            yy = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2.0, yy + 25,
                     "%.0f" % yy, ha="center", va="bottom", fontsize=5.8)

    save_pub(fig, "Nature_Fig02_Minaei_params_gap_energy_Dgap_CFD_vs_MinaeiG")


def make_metric_figure(met, eng):
    m = met.sort_values("delta_mm").reset_index(drop=True)
    e = eng.sort_values("delta_mm").reset_index(drop=True)
    x = np.arange(len(m))
    labels = ["%g" % v for v in m["delta_mm"]]
    width = 0.23

    fig = plt.figure(figsize=(7.2, 2.8))
    gs = gridspec.GridSpec(1, 2, figure=fig, wspace=0.34)
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    style_ax(ax1)
    style_ax(ax2)

    series = [
        ("RMSE", m["RMSE_C"], COL["blue"]),
        ("MAE", m["MAE_C"], COL["teal"]),
        ("Max abs", m["max_abs_error_C"], COL["red"]),
    ]
    for j, (name, vals, color) in enumerate(series):
        ax1.bar(x + (j - 1) * width, vals, width=width, color=color,
                edgecolor=COL["black"], linewidth=0.45, label=name)
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels)
    ax1.set_xlabel("Air-gap thickness (mm)")
    ax1.set_ylabel("Outlet-temperature error (deg C)")
    ax1.set_title("Annual Tout error", loc="left", fontsize=7.3, pad=2)
    ax1.legend(loc="upper left", fontsize=6.1, ncol=1)
    add_panel(ax1, "a")

    ax2.axhline(0, color=COL["light"], lw=0.9)
    abs_err = as_float_array(e["Eabs_kWh_CFD_minus_MinaeiG_percent"])
    heat_err = as_float_array(e["Eheat_kWh_CFD_minus_MinaeiG_percent"])
    cool_err = as_float_array(e["Ecool_kWh_CFD_minus_MinaeiG_percent"])
    ax2.plot(x, cool_err, color=COL["red"], lw=1.1, marker="o", ms=3.0,
             mfc="white", label="cooling")
    ax2.plot(x, heat_err, color=COL["blue"], lw=1.1, marker="s", ms=3.0,
             mfc="white", label="heating")
    ax2.plot(x, abs_err, color=COL["black"], lw=1.2, marker="^", ms=3.2,
             mfc="white", label="absolute")
    ax2.set_xticks(x)
    ax2.set_xticklabels(labels)
    ax2.set_xlabel("Air-gap thickness (mm)")
    ax2.set_ylabel("CFD - model (%)")
    ax2.set_title("Energy-balance difference", loc="left", fontsize=7.3, pad=2)
    ax2.legend(loc="lower left", fontsize=6.1)
    add_panel(ax2, "b")

    save_pub(fig, "Nature_Fig03_Minaei_params_gap_error_summary")


def write_notes(deltas):
    ensure(OUT_DIR)
    text = """# Minaei-parameter gap validation package

Scope:
- The comparison uses the available validated k-epsilon CFD annual gap cases: %s mm.
- The reduced model is the MATLAB Minaei-G annual model aligned to the CFD time grid.
- The comparison is limited to CFD vs Minaei-G; no ILS or FLS response kernels are evaluated here.
- Older non-turbulence/full-gap COMSOL outputs are not mixed into this package.

Figure contract:
- Core conclusion: under the Minaei-parameter annual validation setting, the corrected k-epsilon CFD and the Minaei-G reduced model give closely matched annual outlet-temperature and annual heat-exchange trends for the available gap cases.
- Archetype: quantitative grid.
- Source data: CSV files in origin_data.
- Export: editable SVG/PDF plus PNG/TIFF previews.
""" % (", ".join(["%g" % d for d in deltas]))
    with open(os.path.join(OUT_DIR, "Minaei_parameter_gap_validation_notes.md"), "w") as f:
        f.write(text)


def main():
    ensure(OUT_DIR)
    ensure(FIG_DIR)
    ensure(ORIGIN_DIR)
    pts, met, eng, deltas = load_data()
    export_origin_data(pts, met, eng, deltas)
    make_tout_figure(pts, met, deltas)
    make_energy_figure(eng)
    make_metric_figure(met, eng)
    write_notes(deltas)
    print("Minaei-parameter CFD vs Minaei-G validation package written to: %s" % OUT_DIR)


if __name__ == "__main__":
    main()
