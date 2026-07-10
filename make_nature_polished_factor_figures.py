import os
import re

import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt


ROOT = r"G:\codexproject\EAHE_airgap_physical_v18_minaei_contact_results"
DATA_DIR = os.path.join(ROOT, "Paper_ready_data")
OUT_DIR = os.path.join(ROOT, "Nature_polished_figures")


mpl.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans", "sans-serif"],
    "svg.fonttype": "none",
    "pdf.fonttype": 42,
    "font.size": 7.0,
    "axes.linewidth": 0.75,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "xtick.direction": "out",
    "ytick.direction": "out",
    "xtick.major.size": 3.0,
    "ytick.major.size": 3.0,
    "legend.frameon": False,
})


PALETTE = {
    "black": "#222222",
    "gray": "#6F7478",
    "lightgray": "#D8DEE2",
    "blue": "#4C78A8",
    "cyan": "#72B7B2",
    "orange": "#F28E2B",
    "red": "#E15759",
    "green": "#59A14F",
    "purple": "#8E6C8A",
}


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def read_data():
    gap = pd.read_csv(os.path.join(DATA_DIR, "PaperData_gap_thickness_summary.csv"))
    contact = pd.read_csv(os.path.join(DATA_DIR, "PaperData_contact_coefficient_summary.csv"))
    contact_ts = pd.read_csv(os.path.join(DATA_DIR, "PaperData_contact_coefficient_timeseries.csv"))
    return gap, contact, contact_ts


def style_axis(ax):
    ax.grid(True, axis="y", color=PALETTE["lightgray"], lw=0.55, alpha=0.75)
    ax.tick_params(width=0.75)
    for spine in ("left", "bottom"):
        ax.spines[spine].set_color(PALETTE["black"])
        ax.spines[spine].set_linewidth(0.75)


def add_panel_label(ax, label):
    ax.text(-0.18, 1.08, label, transform=ax.transAxes, ha="left", va="top",
            fontsize=8.5, fontweight="bold", color=PALETTE["black"])


def line_with_points(ax, x, y, color, marker="o", label=None):
    ax.plot(x, y, color=color, lw=1.45, marker=marker, ms=4.0,
            mec="white", mew=0.55, label=label)


def save_figure(fig, basename):
    ensure_dir(OUT_DIR)
    base = os.path.join(OUT_DIR, basename)
    fig.savefig(base + ".svg", bbox_inches="tight")
    fig.savefig(base + ".pdf", bbox_inches="tight")
    fig.savefig(base + ".png", dpi=600, bbox_inches="tight")
    try:
        fig.savefig(base + ".tiff", dpi=600, bbox_inches="tight")
    except Exception as exc:
        print("TIFF export skipped for {}: {}".format(basename, exc))


def draw_combined(gap, contact, contact_ts):
    fig, axes = plt.subplots(2, 3, figsize=(7.2, 4.8))
    axes = axes.ravel()

    x_gap = gap["delta_mm"].values
    x_chi = contact["contact_coeff_chi"].values

    add_panel_label(axes[0], "a")
    line_with_points(axes[0], x_gap, gap["Eabs_kWh"], PALETTE["blue"])
    axes[0].set_xlabel(r"Air-gap thickness, $\delta$ (mm)")
    axes[0].set_ylabel("Annual heat exchange (kWh)")
    axes[0].set_title("Gap thickness reduces capacity", pad=5)
    axes[0].set_xlim(-0.15, max(x_gap) + 0.35)
    style_axis(axes[0])

    add_panel_label(axes[1], "b")
    line_with_points(axes[1], x_gap, gap["Dgap_percent"], PALETTE["red"], marker="s")
    axes[1].set_xlabel(r"Air-gap thickness, $\delta$ (mm)")
    axes[1].set_ylabel("Capacity loss (%)")
    axes[1].set_title("Loss increases monotonically", pad=5)
    axes[1].set_xlim(-0.15, max(x_gap) + 0.35)
    style_axis(axes[1])

    add_panel_label(axes[2], "c")
    line_with_points(axes[2], x_gap, gap["Rint_eff_mK_W"], PALETTE["purple"], marker="^")
    axes[2].set_xlabel(r"Air-gap thickness, $\delta$ (mm)")
    axes[2].set_ylabel("Interface resistance (m K W$^{-1}$)")
    axes[2].set_title("Interface resistance dominates", pad=5)
    axes[2].set_xlim(-0.15, max(x_gap) + 0.35)
    style_axis(axes[2])

    add_panel_label(axes[3], "d")
    line_with_points(axes[3], x_chi, contact["Eabs_kWh"], PALETTE["green"])
    axes[3].set_xlabel(r"Contact coefficient, $\chi$")
    axes[3].set_ylabel("Annual heat exchange (kWh)")
    axes[3].set_title("Contact restores heat transfer", pad=5)
    axes[3].set_xlim(-0.03, 1.03)
    style_axis(axes[3])

    add_panel_label(axes[4], "e")
    line_with_points(axes[4], x_chi, contact["ElossVsContact_percent"], PALETTE["orange"], marker="s")
    axes[4].set_xlabel(r"Contact coefficient, $\chi$")
    axes[4].set_ylabel("Loss vs full contact (%)")
    axes[4].set_title("Loss collapses as contact improves", pad=5)
    axes[4].set_xlim(-0.03, 1.03)
    style_axis(axes[4])

    add_panel_label(axes[5], "f")
    chi_cols = [c for c in contact_ts.columns if c.startswith("Tout_chi_") and c.endswith("_C")]
    selected = []
    for target in ("0", "0p25", "0p5", "0p75", "1"):
        for col in chi_cols:
            if re.search(r"Tout_chi_{}_C$".format(target), col):
                selected.append(col)
                break
    if not selected:
        selected = chi_cols
    colors = [PALETTE["red"], PALETTE["orange"], PALETTE["gray"], PALETTE["cyan"], PALETTE["green"]]
    for i, col in enumerate(selected):
        chi_label = col.replace("Tout_chi_", "").replace("_C", "").replace("p", ".")
        axes[5].plot(contact_ts["day"], contact_ts[col], lw=1.05,
                     color=colors[i % len(colors)], label=r"$\chi$ = {}".format(chi_label))
    axes[5].set_xlabel("Time (day)")
    axes[5].set_ylabel(r"Outlet temperature ($^\circ$C)")
    axes[5].set_title("Annual outlet-temperature response", pad=5)
    axes[5].legend(loc="upper right", fontsize=6.2, handlelength=1.4)
    style_axis(axes[5])

    fig.suptitle("Air-gap and contact effects on EAHE annual thermal performance",
                 x=0.02, y=1.02, ha="left", fontsize=8.5, fontweight="bold")
    fig.tight_layout(w_pad=1.3, h_pad=1.4)
    save_figure(fig, "Fig_factor_analysis_nature_grid")
    plt.close(fig)


def draw_gap_single(gap):
    fig, axes = plt.subplots(1, 3, figsize=(7.2, 2.15))
    x = gap["delta_mm"].values
    panels = [
        ("a", "Eabs_kWh", "Annual heat exchange (kWh)", PALETTE["blue"], "o"),
        ("b", "Dgap_percent", "Capacity loss (%)", PALETTE["red"], "s"),
        ("c", "Rint_eff_mK_W", "Interface resistance (m K W$^{-1}$)", PALETTE["purple"], "^"),
    ]
    for ax, (label, col, ylabel, color, marker) in zip(axes, panels):
        add_panel_label(ax, label)
        line_with_points(ax, x, gap[col], color, marker=marker)
        ax.set_xlabel(r"Air-gap thickness, $\delta$ (mm)")
        ax.set_ylabel(ylabel)
        ax.set_xlim(-0.15, max(x) + 0.35)
        style_axis(ax)
    fig.tight_layout(w_pad=1.3)
    save_figure(fig, "Fig15_factor_gap_thickness_nature")
    plt.close(fig)


def draw_contact_single(contact):
    fig, axes = plt.subplots(1, 3, figsize=(7.2, 2.15))
    x = contact["contact_coeff_chi"].values
    panels = [
        ("a", "Eabs_kWh", "Annual heat exchange (kWh)", PALETTE["green"], "o"),
        ("b", "ElossVsContact_percent", "Loss vs full contact (%)", PALETTE["orange"], "s"),
        ("c", "Rint_eff_mK_W", "Interface resistance (m K W$^{-1}$)", PALETTE["purple"], "^"),
    ]
    for ax, (label, col, ylabel, color, marker) in zip(axes, panels):
        add_panel_label(ax, label)
        line_with_points(ax, x, contact[col], color, marker=marker)
        ax.set_xlabel(r"Contact coefficient, $\chi$")
        ax.set_ylabel(ylabel)
        ax.set_xlim(-0.03, 1.03)
        style_axis(ax)
    fig.tight_layout(w_pad=1.3)
    save_figure(fig, "Fig16_factor_contact_coefficient_nature")
    plt.close(fig)


def draw_tout_single(contact_ts):
    fig, ax = plt.subplots(1, 1, figsize=(7.2, 2.55))
    chi_cols = [c for c in contact_ts.columns if c.startswith("Tout_chi_") and c.endswith("_C")]
    cmap = [PALETTE["red"], PALETTE["orange"], PALETTE["gray"], PALETTE["cyan"], PALETTE["blue"], PALETTE["green"]]
    for i, col in enumerate(chi_cols):
        chi_label = col.replace("Tout_chi_", "").replace("_C", "").replace("p", ".")
        lw = 1.35 if chi_label in ("0", "1") else 0.95
        ax.plot(contact_ts["day"], contact_ts[col], lw=lw,
                color=cmap[i % len(cmap)], label=r"$\chi$ = {}".format(chi_label))
    ax.set_xlabel("Time (day)")
    ax.set_ylabel(r"Outlet temperature ($^\circ$C)")
    ax.legend(ncol=4, loc="upper center", bbox_to_anchor=(0.5, 1.18),
              fontsize=6.4, handlelength=1.5, columnspacing=0.9)
    style_axis(ax)
    fig.tight_layout()
    save_figure(fig, "Fig17_factor_contact_Tout_curves_nature")
    plt.close(fig)


def write_figure_note(gap, contact):
    note = os.path.join(OUT_DIR, "Figure_contract_and_key_results.txt")
    gap_1mm = gap.loc[np.isclose(gap["delta_mm"], 1.0)].iloc[0]
    gap_5mm = gap.loc[np.isclose(gap["delta_mm"], 5.0)].iloc[0]
    chi0 = contact.loc[np.isclose(contact["contact_coeff_chi"], 0.0)].iloc[0]
    chi1 = contact.loc[np.isclose(contact["contact_coeff_chi"], 1.0)].iloc[0]
    with open(note, "w") as f:
        f.write("Core conclusion: air-gap thickness monotonically weakens annual EAHE heat exchange, while contact recovery suppresses the interface penalty.\n")
        f.write("Archetype: quantitative grid.\n")
        f.write("Export contract: editable SVG/PDF, 600 dpi PNG/TIFF, source data in Paper_ready_data.\n\n")
        f.write("At delta = 1 mm, annual heat exchange = {:.3f} kWh and gap loss = {:.3f}%.\n".format(
            gap_1mm["Eabs_kWh"], gap_1mm["Dgap_percent"]))
        f.write("At delta = 5 mm, annual heat exchange = {:.3f} kWh and gap loss = {:.3f}%.\n".format(
            gap_5mm["Eabs_kWh"], gap_5mm["Dgap_percent"]))
        f.write("At delta = 1 mm, chi = 0 gives {:.3f} kWh; chi = 1 gives {:.3f} kWh.\n".format(
            chi0["Eabs_kWh"], chi1["Eabs_kWh"]))


def main():
    ensure_dir(OUT_DIR)
    gap, contact, contact_ts = read_data()
    draw_combined(gap, contact, contact_ts)
    draw_gap_single(gap)
    draw_contact_single(contact)
    draw_tout_single(contact_ts)
    write_figure_note(gap, contact)
    print("Nature-polished figures written to {}".format(OUT_DIR))


if __name__ == "__main__":
    main()
