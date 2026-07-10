import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd

# nature-figure Python backend: keep text editable in SVG.
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
})

ROOT = r"G:\codexproject"
SHARAN_POINTS = os.path.join(ROOT, "MATLAB_Sharan_50m_MinaeiG_validation",
                             "Sharan_MATLAB_MinaeiG_points.csv")
SHARAN_METRICS = os.path.join(ROOT, "MATLAB_Sharan_50m_MinaeiG_validation",
                              "Sharan_MATLAB_MinaeiG_metrics.csv")
ANNUAL_POINTS = os.path.join(ROOT, "Validation_annual_CFD_vs_MATLAB_Tout_only",
                             "Annual_CFD_vs_MATLAB_Tout_only_points.csv")
ANNUAL_METRICS = os.path.join(ROOT, "Validation_annual_CFD_vs_MATLAB_Tout_only",
                              "Annual_CFD_vs_MATLAB_Tout_only_metrics.csv")

OUT_DIR = os.path.join(ROOT, "Validation_outlet_CFD_MATLAB_literature")
ORIGIN_DIR = os.path.join(OUT_DIR, "origin_data")
FIG_DIR = os.path.join(OUT_DIR, "nature_python_figures")

COL = {
    "black": "#272727",
    "grey": "#767676",
    "light_grey": "#D8D8D8",
    "blue": "#0F4D92",
    "red": "#B64342",
    "red_light": "#F6CFCB",
    "blue_light": "#D6E2F0",
    "teal": "#42949E",
}


def ensure(path):
    if not os.path.exists(path):
        os.makedirs(path)


def rmse(y):
    y = np.asarray(y, dtype=float)
    return np.sqrt(np.nanmean(y * y))


def save_pub(fig, name, dpi=600):
    ensure(FIG_DIR)
    base = os.path.join(FIG_DIR, name)
    fig.savefig(base + ".svg", bbox_inches="tight")
    fig.savefig(base + ".pdf", bbox_inches="tight")
    fig.savefig(base + ".png", dpi=dpi, bbox_inches="tight")
    fig.savefig(base + ".tiff", dpi=dpi, bbox_inches="tight")
    plt.close(fig)


def add_panel(ax, letter):
    ax.text(-0.12, 1.06, letter, transform=ax.transAxes, ha="left", va="bottom",
            fontsize=8.0, fontweight="bold", color=COL["black"])


def style_ax(ax):
    ax.tick_params(direction="out", pad=2)
    ax.grid(False)
    ax.spines["left"].set_color(COL["black"])
    ax.spines["bottom"].set_color(COL["black"])


def export_origin_data():
    ensure(ORIGIN_DIR)
    sharan = pd.read_csv(SHARAN_POINTS)
    annual = pd.read_csv(ANNUAL_POINTS)
    sm = pd.read_csv(SHARAN_METRICS)
    am = pd.read_csv(ANNUAL_METRICS)

    exported = []
    for case_name, label in [
        ("Sharan_May_cooling", "May_cooling"),
        ("Sharan_January_heating", "January_heating"),
    ]:
        d = sharan[sharan["case_name"] == case_name].copy()
        out = pd.DataFrame({
            "Time_h": d["time_h"],
            "Tin_C": d["Tin_exp_C"],
            "Tsoil_C": d["Tsoil_C"],
            "Literature_Sharan_Tout_C": d["Tout_exp_C"],
            "MATLAB_Minaei_G_Tout_C": d["Tout_MATLAB_MinaeiG_C"],
            "CFD_k_epsilon_Tout_C": d["Tout_CFD_kepsilon_C"],
            "MATLAB_minus_literature_C": d["Tout_MATLAB_minus_exp_C"],
            "CFD_minus_literature_C": d["Tout_CFD_minus_exp_C"],
            "MATLAB_minus_CFD_C": d["Tout_MATLAB_MinaeiG_C"] - d["Tout_CFD_kepsilon_C"],
        })
        path = os.path.join(ORIGIN_DIR, "Origin_outlet_%s_literature_MATLAB_CFD.csv" % label)
        out.to_csv(path, index=False)
        exported.append(path)

    for delta in [0, 1, 5]:
        d = annual[annual["delta_mm"] == delta].copy()
        out = pd.DataFrame({
            "Time_day": d["t_day"],
            "Tin_C": d["Tin_C"],
            "CFD_k_epsilon_Tout_C": d["Tout_CFD_kepsilon_C"],
            "MATLAB_Minaei_G_Tout_C": d["Tout_MATLAB_MinaeiG_C"],
            "MATLAB_minus_CFD_C": d["Tout_MATLAB_minus_CFD_C"],
        })
        path = os.path.join(ORIGIN_DIR, "Origin_annual_outlet_delta_%dmm_CFD_MATLAB.csv" % delta)
        out.to_csv(path, index=False)
        exported.append(path)

    outlet_metrics = sm[(sm["quantity"] == "Tout")].copy()
    outlet_metrics.to_csv(os.path.join(ORIGIN_DIR, "Origin_outlet_validation_metrics.csv"), index=False)
    am.to_csv(os.path.join(ORIGIN_DIR, "Origin_annual_outlet_metrics.csv"), index=False)

    readme = """Origin data package for outlet-temperature validation.

Files:
- Origin_outlet_May_cooling_literature_MATLAB_CFD.csv:
  X = Time_h; Y = Literature_Sharan_Tout_C, MATLAB_Minaei_G_Tout_C, CFD_k_epsilon_Tout_C.
- Origin_outlet_January_heating_literature_MATLAB_CFD.csv:
  X = Time_h; Y = Literature_Sharan_Tout_C, MATLAB_Minaei_G_Tout_C, CFD_k_epsilon_Tout_C.
- Origin_annual_outlet_delta_0mm_CFD_MATLAB.csv, delta_1mm, delta_5mm:
  X = Time_day; Y = Tin_C, CFD_k_epsilon_Tout_C, MATLAB_Minaei_G_Tout_C.
- *_metrics.csv:
  RMSE, MAE, bias and maximum error summaries.

Recommended Origin plots:
1. Outlet validation: line + symbol plot with Time_h as X.
2. Outlet residuals: line plot of MATLAB_minus_literature_C and CFD_minus_literature_C.
3. Annual outlet comparison: line plot with Time_day as X.
4. Annual residuals: line or area plot of MATLAB_minus_CFD_C.
"""
    with open(os.path.join(ORIGIN_DIR, "README_Origin_data.txt"), "w", encoding="utf-8") as f:
        f.write(readme)
    return exported


def make_outlet_validation_figure():
    may = pd.read_csv(os.path.join(ORIGIN_DIR, "Origin_outlet_May_cooling_literature_MATLAB_CFD.csv"))
    jan = pd.read_csv(os.path.join(ORIGIN_DIR, "Origin_outlet_January_heating_literature_MATLAB_CFD.csv"))

    fig = plt.figure(figsize=(7.2, 4.6))
    gs = gridspec.GridSpec(2, 2, figure=fig, hspace=0.48, wspace=0.34,
                           height_ratios=[1.05, 0.75])
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    ax3 = fig.add_subplot(gs[1, 0])
    ax4 = fig.add_subplot(gs[1, 1])

    plot_outlet_panel(ax1, may, "May cooling", (26.45, 28.35), "a")
    plot_outlet_panel(ax2, jan, "January heating", (21.85, 24.35), "b")
    plot_outlet_residual(ax3, may, "May cooling residual", (-0.35, 1.15), "c")
    plot_outlet_residual(ax4, jan, "January heating residual", (-0.95, 0.45), "d")
    save_pub(fig, "Nature_Fig01_Outlet_literature_MATLAB_CFD_validation")


def plot_outlet_panel(ax, d, title, ylim, letter):
    style_ax(ax)
    x = d["Time_h"]
    ax.plot(x, d["Literature_Sharan_Tout_C"], color=COL["black"], lw=1.2,
            marker="o", ms=3.2, mfc="white", mec=COL["black"], mew=0.7,
            label="Sharan literature")
    ax.plot(x, d["MATLAB_Minaei_G_Tout_C"], color=COL["blue"], lw=1.2, ls="--",
            marker="s", ms=3.0, mfc="white", mec=COL["blue"], mew=0.7,
            label="MATLAB Minaei-G")
    ax.plot(x, d["CFD_k_epsilon_Tout_C"], color=COL["red"], lw=1.1,
            marker="^", ms=3.0, mfc="white", mec=COL["red"], mew=0.7,
            label="CFD k-epsilon")
    ax.set_ylim(ylim)
    ax.set_xlabel("Time (h)")
    ax.set_ylabel("Outlet temperature (deg C)")
    ax.set_title(title, loc="left", fontsize=7.3, pad=2)
    ax.text(0.03, 0.08,
            "RMSE: MATLAB %.2f, CFD %.2f deg C" %
            (rmse(d["MATLAB_minus_literature_C"]), rmse(d["CFD_minus_literature_C"])),
            transform=ax.transAxes, fontsize=6.2, color=COL["grey"])
    if letter == "a":
        ax.text(0.55, 0.34, "Sharan literature", transform=ax.transAxes,
                color=COL["black"], fontsize=6.3)
        ax.text(0.55, 0.25, "MATLAB Minaei-G", transform=ax.transAxes,
                color=COL["blue"], fontsize=6.3)
        ax.text(0.55, 0.16, "CFD k-epsilon", transform=ax.transAxes,
                color=COL["red"], fontsize=6.3)
    add_panel(ax, letter)


def plot_outlet_residual(ax, d, title, ylim, letter):
    style_ax(ax)
    x = d["Time_h"]
    ax.axhline(0, color=COL["light_grey"], lw=0.8, zorder=0)
    ax.plot(x, d["MATLAB_minus_literature_C"], color=COL["blue"], lw=1.1,
            marker="s", ms=2.8, mfc="white", mec=COL["blue"], mew=0.65)
    ax.plot(x, d["CFD_minus_literature_C"], color=COL["red"], lw=1.1,
            marker="^", ms=2.8, mfc="white", mec=COL["red"], mew=0.65)
    ax.set_ylim(ylim)
    ax.set_xlabel("Time (h)")
    ax.set_ylabel("Model - literature\n(deg C)")
    ax.set_title(title, loc="left", fontsize=7.3, pad=2)
    add_panel(ax, letter)


def make_annual_figure():
    fig = plt.figure(figsize=(7.2, 5.2))
    gs = gridspec.GridSpec(3, 2, figure=fig, hspace=0.46, wspace=0.30,
                           width_ratios=[1.15, 1.0])
    letters = ["a", "b", "c", "d", "e", "f"]
    for i, delta in enumerate([0, 1, 5]):
        d = pd.read_csv(os.path.join(ORIGIN_DIR, "Origin_annual_outlet_delta_%dmm_CFD_MATLAB.csv" % delta))
        ax_t = fig.add_subplot(gs[i, 0])
        ax_r = fig.add_subplot(gs[i, 1])
        plot_annual_panel(ax_t, d, delta, letters[2*i])
        plot_annual_residual(ax_r, d, delta, letters[2*i + 1])
        if i < 2:
            ax_t.set_xticklabels([])
            ax_t.set_xlabel("")
            ax_r.set_xticklabels([])
            ax_r.set_xlabel("")
    save_pub(fig, "Nature_Fig02_Annual_outlet_CFD_MATLAB_comparison")


def plot_annual_panel(ax, d, delta, letter):
    style_ax(ax)
    x = d["Time_day"]
    ax.plot(x, d["Tin_C"], color=COL["light_grey"], lw=0.9)
    ax.plot(x, d["CFD_k_epsilon_Tout_C"], color=COL["red"], lw=1.15)
    ax.plot(x, d["MATLAB_Minaei_G_Tout_C"], color=COL["blue"], lw=1.15, ls="--")
    ax.set_xlim(0, 365)
    ax.set_ylim(14, 27)
    ax.set_xlabel("Time (day)")
    ax.set_ylabel("Temperature (deg C)")
    ax.set_title("delta = %d mm" % delta, loc="left", fontsize=7.3, pad=2)
    ax.text(0.03, 0.08, "RMSE = %.2f deg C" % rmse(d["MATLAB_minus_CFD_C"]),
            transform=ax.transAxes, fontsize=6.3, color=COL["grey"])
    if delta == 0:
        ax.text(0.70, 0.88, "Inlet", transform=ax.transAxes,
                fontsize=6.2, color=COL["light_grey"])
        ax.text(0.70, 0.80, "CFD k-epsilon", transform=ax.transAxes,
                fontsize=6.2, color=COL["red"])
        ax.text(0.70, 0.72, "MATLAB Minaei-G", transform=ax.transAxes,
                fontsize=6.2, color=COL["blue"])
    add_panel(ax, letter)


def plot_annual_residual(ax, d, delta, letter):
    style_ax(ax)
    x = d["Time_day"].values
    err = d["MATLAB_minus_CFD_C"].values
    ax.axhline(0, color=COL["light_grey"], lw=0.8, zorder=0)
    ax.fill_between(x, 0, err, where=err >= 0, color=COL["blue_light"], alpha=0.9, linewidth=0)
    ax.fill_between(x, 0, err, where=err < 0, color=COL["red_light"], alpha=0.7, linewidth=0)
    ax.plot(x, err, color=COL["black"], lw=0.9)
    ax.set_xlim(0, 365)
    if delta == 5:
        ax.set_ylim(-0.5, 2.0)
    else:
        ax.set_ylim(-0.65, 0.85)
    ax.set_xlabel("Time (day)")
    ax.set_ylabel("MATLAB - CFD\n(deg C)")
    ax.set_title("residual, delta = %d mm" % delta, loc="left", fontsize=7.3, pad=2)
    ax.text(0.03, 0.08, "bias = %.2f deg C" % np.nanmean(err),
            transform=ax.transAxes, fontsize=6.3, color=COL["grey"])
    add_panel(ax, letter)


def make_metric_figure():
    sm = pd.read_csv(os.path.join(ORIGIN_DIR, "Origin_outlet_validation_metrics.csv"))
    am = pd.read_csv(os.path.join(ORIGIN_DIR, "Origin_annual_outlet_metrics.csv"))

    fig = plt.figure(figsize=(7.2, 2.55))
    gs = gridspec.GridSpec(1, 2, figure=fig, wspace=0.34)
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    style_ax(ax1)
    style_ax(ax2)

    rows = []
    for case_name, case_label in [("Sharan_May_cooling", "May"), ("Sharan_January_heating", "January")]:
        for comp, comp_label in [("MATLAB_MinaeiG_vs_exp", "MATLAB"), ("CFD_kepsilon_vs_exp", "CFD")]:
            r = sm[(sm["case_name"] == case_name) & (sm["comparison"] == comp)].iloc[0]
            rows.append((case_label, comp_label, r["RMSE_C"]))
    x = np.array([0, 1])
    width = 0.34
    y_mat = [v for c, m, v in rows if m == "MATLAB"]
    y_cfd = [v for c, m, v in rows if m == "CFD"]
    b_mat = ax1.bar(x - width/2, y_mat, width=width, color=COL["blue"],
                    edgecolor=COL["black"], linewidth=0.45, label="MATLAB Minaei-G")
    b_cfd = ax1.bar(x + width/2, y_cfd, width=width, color=COL["red"],
                    edgecolor=COL["black"], linewidth=0.45, label="CFD k-epsilon")
    ax1.set_xticks(x)
    ax1.set_xticklabels(["May\ncooling", "January\nheating"])
    ax1.set_ylim(0, 0.75)
    ax1.set_ylabel("Outlet RMSE vs literature (deg C)")
    ax1.set_title("Short-term outlet validation", loc="left", fontsize=7.3, pad=2)
    ax1.legend(loc="upper left", fontsize=6.1, handlelength=1.0, borderaxespad=0.2)
    for bars in (b_mat, b_cfd):
        for bar in bars:
            yy = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2.0, yy + 0.018, "%.2f" % yy,
                     ha="center", va="bottom", fontsize=6.0)
    add_panel(ax1, "a")

    ax2.bar(am["delta_mm"], am["RMSE_C"], width=0.55, color=COL["red"],
            edgecolor=COL["black"], linewidth=0.45)
    ax2.set_xlim(-0.7, 5.7)
    ax2.set_ylim(0, 0.55)
    ax2.set_xticks([0, 1, 5])
    ax2.set_xlabel("Air-gap thickness (mm)")
    ax2.set_ylabel("Annual RMSE (deg C)")
    ax2.set_title("Annual CFD vs MATLAB", loc="left", fontsize=7.3, pad=2)
    for xx, yy in zip(am["delta_mm"], am["RMSE_C"]):
        ax2.text(xx, yy + 0.018, "%.2f" % yy, ha="center", va="bottom", fontsize=6.3)
    add_panel(ax2, "b")
    save_pub(fig, "Nature_Fig03_Outlet_validation_RMSE_summary")


def write_notes():
    ensure(OUT_DIR)
    text = """# Outlet-temperature validation package

Scope:
- The 25 m intermediate-temperature comparison is excluded because its deviation is large.
- This package focuses on outlet temperature only.

Short-term validation:
- Literature benchmark: Sharan outlet-temperature data.
- Compared series: Sharan literature, MATLAB Minaei-G, COMSOL CFD k-epsilon.

Annual comparison:
- Compared series: annual CFD outlet temperature and MATLAB Minaei-G outlet temperature.
- This is a model-to-model consistency check, not an annual experimental validation.

Outputs:
- nature_python_figures: Nature-style SVG/PDF/PNG/TIFF figures.
- origin_data: CSV files with clean column names for Origin modification.
"""
    with open(os.path.join(OUT_DIR, "Outlet_validation_notes.md"), "w", encoding="utf-8") as f:
        f.write(text)


def main():
    ensure(OUT_DIR)
    ensure(ORIGIN_DIR)
    ensure(FIG_DIR)
    export_origin_data()
    make_outlet_validation_figure()
    make_annual_figure()
    make_metric_figure()
    write_notes()
    print("Outlet validation package written to: %s" % OUT_DIR)


if __name__ == "__main__":
    main()
