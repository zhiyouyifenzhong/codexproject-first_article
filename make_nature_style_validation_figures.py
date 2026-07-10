import os
import math

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd

# Mandatory editable-text settings from the nature-figure Python backend.
plt.rcParams["font.family"] = "sans-serif"
plt.rcParams["font.sans-serif"] = ["Arial", "DejaVu Sans", "Liberation Sans"]
plt.rcParams["svg.fonttype"] = "none"

plt.rcParams.update({
    "pdf.fonttype": 42,
    "font.size": 7.0,
    "axes.spines.right": False,
    "axes.spines.top": False,
    "axes.linewidth": 0.75,
    "xtick.major.width": 0.7,
    "ytick.major.width": 0.7,
    "xtick.major.size": 2.4,
    "ytick.major.size": 2.4,
    "legend.frameon": False,
    "legend.fontsize": 6.4,
})

ROOT = r"G:\codexproject"
DATA_DIR = os.path.join(ROOT, "Origin_export_validation_data")
OUT_DIR = os.path.join(DATA_DIR, "nature_python_figures")

COL = {
    "black": "#272727",
    "grey": "#767676",
    "light_grey": "#D8D8D8",
    "blue": "#0F4D92",
    "blue_soft": "#3775BA",
    "red": "#B64342",
    "red_soft": "#E9A6A1",
    "teal": "#42949E",
}


def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)


def save_pub(fig, base, dpi=600):
    ensure_dir(os.path.dirname(base))
    fig.savefig(base + ".svg", bbox_inches="tight")
    fig.savefig(base + ".pdf", bbox_inches="tight")
    fig.savefig(base + ".png", dpi=dpi, bbox_inches="tight")
    fig.savefig(base + ".tiff", dpi=dpi, bbox_inches="tight")
    plt.close(fig)


def read_csv(name):
    return pd.read_csv(os.path.join(DATA_DIR, name))


def rmse(y):
    y = np.asarray(y, dtype=float)
    return math.sqrt(np.nanmean(y * y))


def add_panel_label(ax, label):
    ax.text(-0.12, 1.06, label, transform=ax.transAxes, ha="left", va="bottom",
            fontweight="bold", fontsize=8.0, color=COL["black"])


def soften_axes(ax):
    ax.tick_params(direction="out", pad=2)
    ax.grid(False)
    for side in ["left", "bottom"]:
        ax.spines[side].set_color(COL["black"])
    ax.set_facecolor("white")


def plot_sharan_panel(ax, df, x, exp_col, model_col, label, title, ylim):
    soften_axes(ax)
    ax.plot(df[x], df[exp_col], color=COL["black"], lw=1.15, marker="o",
            ms=3.2, mfc="white", mec=COL["black"], mew=0.75, label="Experiment")
    ax.plot(df[x], df[model_col], color=COL["blue"], lw=1.15, marker="s",
            ms=3.0, mfc="white", mec=COL["blue"], mew=0.75, label="MATLAB Minaei-G")
    ax.set_title(title, loc="left", fontsize=7.3, pad=2)
    ax.set_ylim(ylim)
    ax.set_xlabel("Time (h)")
    ax.set_ylabel("Temperature (deg C)")
    e = rmse(df[model_col].values - df[exp_col].values)
    ax.text(0.03, 0.06, "RMSE = %.2f deg C" % e, transform=ax.transAxes,
            fontsize=6.4, color=COL["grey"])
    if label == "a":
        ax.text(0.57, 0.18, "Experiment", transform=ax.transAxes,
                fontsize=6.5, color=COL["black"])
        ax.text(0.57, 0.10, "MATLAB Minaei-G", transform=ax.transAxes,
                fontsize=6.5, color=COL["blue"])
    add_panel_label(ax, label)


def make_figure_sharan():
    may = read_csv("Origin_Sharan_May_MATLAB_vs_exp.csv")
    jan = read_csv("Origin_Sharan_January_MATLAB_vs_exp.csv")

    fig = plt.figure(figsize=(7.2, 4.9))
    gs = gridspec.GridSpec(2, 2, figure=fig, hspace=0.48, wspace=0.34)

    ax_a = fig.add_subplot(gs[0, 0])
    ax_b = fig.add_subplot(gs[0, 1])
    ax_c = fig.add_subplot(gs[1, 0])
    ax_d = fig.add_subplot(gs[1, 1])

    plot_sharan_panel(ax_a, may, "time_h", "T25_exp_C", "T25_MATLAB_C",
                      "a", "May cooling, 25 m", (26.0, 31.8))
    plot_sharan_panel(ax_b, may, "time_h", "Tout_exp_C", "Tout_MATLAB_C",
                      "b", "May cooling, outlet", (26.5, 28.2))
    plot_sharan_panel(ax_c, jan, "time_h", "T25_exp_C", "T25_MATLAB_C",
                      "c", "January heating, 25 m", (18.0, 24.6))
    plot_sharan_panel(ax_d, jan, "time_h", "Tout_exp_C", "Tout_MATLAB_C",
                      "d", "January heating, outlet", (22.0, 24.3))

    fig.subplots_adjust(top=0.94)
    save_pub(fig, os.path.join(OUT_DIR, "Nature_Fig01_Sharan_MATLAB_validation"))


def read_annual(delta):
    return read_csv("Origin_Annual_CFD_vs_MATLAB_delta_%dmm.csv" % delta)


def plot_annual_temp(ax, df, delta, label):
    soften_axes(ax)
    ax.plot(df["t_day"], df["Tin_C"], color=COL["light_grey"], lw=0.9, label="Inlet")
    ax.plot(df["t_day"], df["Tout_CFD_kepsilon_C"], color=COL["red"], lw=1.15,
            label="CFD k-epsilon")
    ax.plot(df["t_day"], df["Tout_MATLAB_MinaeiG_C"], color=COL["blue"], lw=1.15,
            ls="--", label="MATLAB Minaei-G")
    ax.set_xlim(0, 365)
    ax.set_ylim(14, 27)
    ax.set_ylabel("Temperature (deg C)")
    ax.set_title("delta = %d mm" % delta, loc="left", fontsize=7.3, pad=2)
    ax.text(0.03, 0.08,
            "RMSE = %.2f deg C" % rmse(df["Tout_MATLAB_minus_CFD_C"].values),
            transform=ax.transAxes, fontsize=6.3, color=COL["grey"])
    if delta == 0:
        ax.text(0.70, 0.88, "Inlet", transform=ax.transAxes,
                fontsize=6.3, color=COL["light_grey"])
        ax.text(0.70, 0.80, "CFD k-epsilon", transform=ax.transAxes,
                fontsize=6.3, color=COL["red"])
        ax.text(0.70, 0.72, "MATLAB Minaei-G", transform=ax.transAxes,
                fontsize=6.3, color=COL["blue"])
    add_panel_label(ax, label)


def plot_residual(ax, df, delta, label):
    soften_axes(ax)
    ax.axhline(0, color=COL["light_grey"], lw=0.8, zorder=0)
    err = df["Tout_MATLAB_minus_CFD_C"].values
    x = df["t_day"].values
    ax.fill_between(x, 0, err, where=err >= 0, color=COL["blue"], alpha=0.16, linewidth=0)
    ax.fill_between(x, 0, err, where=err < 0, color=COL["red"], alpha=0.16, linewidth=0)
    ax.plot(x, err, color=COL["black"], lw=0.9)
    ax.set_xlim(0, 365)
    if delta == 5:
        ax.set_ylim(-0.5, 2.0)
    else:
        ax.set_ylim(-0.65, 0.85)
    ax.set_ylabel("MATLAB - CFD\n(deg C)")
    ax.set_title("residual, delta = %d mm" % delta, loc="left", fontsize=7.3, pad=2)
    ax.text(0.03, 0.08, "bias = %.2f deg C" % np.nanmean(err),
            transform=ax.transAxes, fontsize=6.3, color=COL["grey"])
    add_panel_label(ax, label)


def make_figure_annual():
    data = {0: read_annual(0), 1: read_annual(1), 5: read_annual(5)}

    fig = plt.figure(figsize=(7.2, 5.8))
    gs = gridspec.GridSpec(3, 2, figure=fig, hspace=0.48, wspace=0.30,
                           width_ratios=[1.15, 1.0])
    letters = ["a", "b", "c", "d", "e", "f"]
    k = 0
    for row, delta in enumerate([0, 1, 5]):
        ax_t = fig.add_subplot(gs[row, 0])
        plot_annual_temp(ax_t, data[delta], delta, letters[k])
        k += 1
        if row < 2:
            ax_t.set_xticklabels([])
            ax_t.set_xlabel("")
        else:
            ax_t.set_xlabel("Time (day)")

        ax_r = fig.add_subplot(gs[row, 1])
        plot_residual(ax_r, data[delta], delta, letters[k])
        k += 1
        if row < 2:
            ax_r.set_xticklabels([])
            ax_r.set_xlabel("")
        else:
            ax_r.set_xlabel("Time (day)")

    fig.subplots_adjust(top=0.94)
    save_pub(fig, os.path.join(OUT_DIR, "Nature_Fig02_Annual_CFD_MATLAB_Tout"))


def make_figure_rmse():
    sharan_metrics = pd.read_csv(os.path.join(
        ROOT, "Validation_Sharan_same_parameters_MATLAB_only",
        "Sharan_same_parameters_MATLAB_only_metrics.csv"))
    annual_metrics = pd.read_csv(os.path.join(
        ROOT, "Validation_annual_CFD_vs_MATLAB_Tout_only",
        "Annual_CFD_vs_MATLAB_Tout_only_metrics.csv"))

    sharan_tout = sharan_metrics[sharan_metrics["quantity"] == "Tout"].copy()
    order = ["Sharan_May_cooling", "Sharan_January_heating"]
    sharan_tout["ord"] = sharan_tout["case_name"].apply(lambda x: order.index(x))
    sharan_tout = sharan_tout.sort_values("ord")

    fig = plt.figure(figsize=(7.2, 2.3))
    gs = gridspec.GridSpec(1, 2, figure=fig, wspace=0.36)
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    soften_axes(ax1)
    soften_axes(ax2)

    x1 = np.arange(len(sharan_tout))
    ax1.bar(x1, sharan_tout["RMSE_C"].values, width=0.55, color=COL["blue"],
            edgecolor=COL["black"], linewidth=0.5)
    ax1.set_xticks(x1)
    ax1.set_xticklabels(["May\ncooling", "January\nheating"])
    ax1.set_ylim(0, 0.75)
    ax1.set_ylabel("Outlet RMSE (deg C)")
    ax1.set_title("MATLAB vs Sharan", loc="left", fontsize=7.3, pad=2)
    for i, v in enumerate(sharan_tout["RMSE_C"].values):
        ax1.text(i, v + 0.025, "%.2f" % v, ha="center", va="bottom", fontsize=6.4)
    add_panel_label(ax1, "a")

    x2 = annual_metrics["delta_mm"].values
    y2 = annual_metrics["RMSE_C"].values
    ax2.bar(x2, y2, width=0.55, color=COL["red"], edgecolor=COL["black"], linewidth=0.5)
    ax2.set_xticks([0, 1, 5])
    ax2.set_xlim(-0.7, 5.7)
    ax2.set_ylim(0, 0.55)
    ax2.set_xlabel("Air-gap thickness (mm)")
    ax2.set_ylabel("Annual RMSE (deg C)")
    ax2.set_title("CFD vs MATLAB", loc="left", fontsize=7.3, pad=2)
    for x, v in zip(x2, y2):
        ax2.text(x, v + 0.018, "%.2f" % v, ha="center", va="bottom", fontsize=6.4)
    add_panel_label(ax2, "b")

    save_pub(fig, os.path.join(OUT_DIR, "Nature_Fig03_RMSE_summary"))


def write_qa_notes():
    ensure_dir(OUT_DIR)
    txt = """# Nature-style figure QA notes

Core conclusion: The MATLAB Minaei-G reduced model reproduces Sharan outlet-temperature measurements under identical short-term operating parameters and remains consistent with the annual CFD outlet-temperature trend.

Figure archetype: quantitative grid.
Backend: Python only, matplotlib.
Target/export: manuscript-ready SVG primary, PDF vector, 600 dpi TIFF/PNG preview.

Panel map:
- Fig. 1: Sharan May and January measurements versus MATLAB model at 25 m and outlet.
- Fig. 2: Annual CFD/MATLAB outlet-temperature agreement and residuals for delta = 0, 1, and 5 mm.
- Fig. 3: RMSE summary for the two validation levels.

Reviewer risks:
- Sharan data are short-term experimental validation, not annual experimental validation.
- Annual CFD/MATLAB plots are model-to-model consistency checks.
- delta = 5 mm contains an initial transient outlier; the residual panel makes this visible.

Source data:
- CSV files in Origin_export_validation_data and validation metric folders.

Export QA:
- SVG text is editable via svg.fonttype = none.
- PDF text uses TrueType font embedding via pdf.fonttype = 42.
- No rainbow maps; colors are method-consistent across panels.
"""
    with open(os.path.join(OUT_DIR, "Nature_figure_QA_notes.md"), "w", encoding="utf-8") as f:
        f.write(txt)


def main():
    ensure_dir(OUT_DIR)
    make_figure_sharan()
    make_figure_annual()
    make_figure_rmse()
    write_qa_notes()
    print("Nature-style Python figures written to: %s" % OUT_DIR)


if __name__ == "__main__":
    main()
