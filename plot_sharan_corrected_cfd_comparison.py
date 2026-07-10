from __future__ import print_function

import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


ROOT = r"G:\codexproject"
OUT = os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_corrected_comparison_figures")


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def main():
    ensure_dir(OUT)
    cfd = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_corrected_all_points.csv"))
    red = pd.read_csv(os.path.join(
        ROOT, "MinaeiG_validation_and_50m_CFD_results",
        "MinaeiG_50m_CFD_comparison_points.csv"))
    energy = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_corrected_energy.csv"))
    metrics = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_corrected_metrics.csv"))

    for case in sorted(cfd.case_name.unique()):
        c = cfd[cfd.case_name == case].copy()
        if "May" in case:
            rcase = "Sharan_May_cooling"
        else:
            rcase = "Sharan_January_heating"
        r = red[red.case_name == rcase].copy()

        fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))
        for ax, q, cfd_col, exp_col, red_col in [
            (axes[0], "T25", "Tmid_sim_C", "Tmid_exp_C", "MinaeiG_T25_C"),
            (axes[1], "Tout", "Tout_sim_C", "Tout_exp_C", "MinaeiG_Tout_C"),
        ]:
            ax.plot(c.t_day * 24, c[cfd_col], "o-", lw=1.4, label="corrected SST CFD")
            ax.plot(c.t_day * 24, c[exp_col], "k^-", lw=1.2, label="Sharan experiment")
            ax.plot(r.t_day * 24, r[red_col], "s--", lw=1.2, label="Minaei-G RC")
            ax.set_xlabel("time / h")
            ax.set_ylabel(q + " / degC")
            ax.grid(True, alpha=0.3)
            ax.legend()
        fig.suptitle(case.replace("_", " "))
        fig.tight_layout()
        tag = case.replace("Sharan_", "").replace("_corrected", "")
        fig.savefig(os.path.join(OUT, "Fig_corrected_CFD_vs_exp_MinaeiG_%s.png" % tag), dpi=240)
        fig.savefig(os.path.join(OUT, "Fig_corrected_CFD_vs_exp_MinaeiG_%s.pdf" % tag))
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.5, 4.2))
    x = range(len(metrics))
    ax.bar(x, metrics.RMSE_C)
    ax.set_xticks(list(x))
    ax.set_xticklabels(metrics.case_name.str.replace("Sharan_", "") + "\n" + metrics.quantity, fontsize=8)
    ax.set_ylabel("RMSE / degC")
    ax.set_title("Corrected SST CFD validation error")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "Fig_corrected_CFD_RMSE_summary.png"), dpi=240)
    fig.savefig(os.path.join(OUT, "Fig_corrected_CFD_RMSE_summary.pdf"))
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.4, 4.0))
    ax.bar(energy.case_name.str.replace("Sharan_", ""), energy.Eabs_kWh)
    ax.set_ylabel("abs energy / kWh")
    ax.set_title("Corrected SST CFD total heat exchange")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "Fig_corrected_CFD_energy.png"), dpi=240)
    fig.savefig(os.path.join(OUT, "Fig_corrected_CFD_energy.pdf"))
    plt.close(fig)

    print("Wrote corrected comparison figures to %s" % OUT)


if __name__ == "__main__":
    main()
