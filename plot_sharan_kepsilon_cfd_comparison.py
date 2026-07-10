from __future__ import print_function

import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


ROOT = r"G:\codexproject"
OUT = os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_kepsilon_comparison_figures")


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def clean_label(s):
    return s.replace("Sharan_", "").replace("_kepsilon", "").replace("_corrected", "")


def main():
    ensure_dir(OUT)
    cfd = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_kepsilon_all_points.csv"))
    red = pd.read_csv(os.path.join(
        ROOT, "MinaeiG_validation_and_50m_CFD_results",
        "MinaeiG_50m_CFD_comparison_points.csv"))
    energy = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_kepsilon_energy.csv"))
    metrics = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_kepsilon_metrics.csv"))

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
            ax.plot(c.t_day * 24, c[cfd_col], "o-", lw=1.5, label="k-epsilon CFD")
            ax.plot(c.t_day * 24, c[exp_col], "k^-", lw=1.2, label="Sharan experiment")
            ax.plot(r.t_day * 24, r[red_col], "s--", lw=1.2, label="Minaei-G RC")
            ax.set_xlabel("time / h")
            ax.set_ylabel(q + " / degC")
            ax.grid(True, alpha=0.3)
            ax.legend()
        fig.suptitle(clean_label(case).replace("_", " "))
        fig.tight_layout()
        tag = clean_label(case)
        fig.savefig(os.path.join(OUT, "Fig_kepsilon_CFD_vs_exp_MinaeiG_%s.png" % tag), dpi=240)
        fig.savefig(os.path.join(OUT, "Fig_kepsilon_CFD_vs_exp_MinaeiG_%s.pdf" % tag))
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.5, 4.2))
    x = range(len(metrics))
    ax.bar(x, metrics.RMSE_C, color="#4477AA")
    ax.set_xticks(list(x))
    ax.set_xticklabels(metrics.case_name.map(clean_label) + "\n" + metrics.quantity, fontsize=8)
    ax.set_ylabel("RMSE / degC")
    ax.set_title("k-epsilon CFD validation error")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "Fig_kepsilon_CFD_RMSE_summary.png"), dpi=240)
    fig.savefig(os.path.join(OUT, "Fig_kepsilon_CFD_RMSE_summary.pdf"))
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.4, 4.0))
    ax.bar(energy.case_name.map(clean_label), energy.Eabs_kWh, color="#66A61E")
    ax.set_ylabel("abs energy / kWh")
    ax.set_title("k-epsilon CFD total heat exchange")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "Fig_kepsilon_CFD_energy.png"), dpi=240)
    fig.savefig(os.path.join(OUT, "Fig_kepsilon_CFD_energy.pdf"))
    plt.close(fig)

    old_metrics_path = os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_corrected_metrics.csv")
    old_energy_path = os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_corrected_energy.csv")
    if os.path.exists(old_metrics_path):
        old = pd.read_csv(old_metrics_path)
        old["route"] = "old SST"
        metrics2 = metrics.copy()
        metrics2["route"] = "GUI-validated k-epsilon"
        old["case_short"] = old.case_name.map(clean_label)
        metrics2["case_short"] = metrics2.case_name.map(clean_label)
        both = pd.concat([
            old[["case_short", "quantity", "RMSE_C", "route"]],
            metrics2[["case_short", "quantity", "RMSE_C", "route"]],
        ], ignore_index=True)
        both["xlab"] = both.case_short + "\n" + both.quantity
        pivot = both.pivot_table(index="xlab", columns="route", values="RMSE_C")
        fig, ax = plt.subplots(figsize=(9.2, 4.3))
        pivot.plot(kind="bar", ax=ax)
        ax.set_ylabel("RMSE / degC")
        ax.set_title("CFD route comparison: old SST vs validated k-epsilon")
        ax.grid(True, axis="y", alpha=0.3)
        fig.tight_layout()
        fig.savefig(os.path.join(OUT, "Fig_oldSST_vs_kepsilon_RMSE.png"), dpi=240)
        fig.savefig(os.path.join(OUT, "Fig_oldSST_vs_kepsilon_RMSE.pdf"))
        plt.close(fig)

    if os.path.exists(old_energy_path):
        olde = pd.read_csv(old_energy_path)
        olde["route"] = "old SST"
        energy2 = energy.copy()
        energy2["route"] = "GUI-validated k-epsilon"
        olde["case_short"] = olde.case_name.map(clean_label)
        energy2["case_short"] = energy2.case_name.map(clean_label)
        both_e = pd.concat([
            olde[["case_short", "Eabs_kWh", "h_eq_mean_W_m2K", "route"]],
            energy2[["case_short", "Eabs_kWh", "h_eq_mean_W_m2K", "route"]],
        ], ignore_index=True)
        for col, title, fname, ylabel in [
            ("Eabs_kWh", "Total heat exchange comparison", "Fig_oldSST_vs_kepsilon_energy", "abs energy / kWh"),
            ("h_eq_mean_W_m2K", "Effective h comparison", "Fig_oldSST_vs_kepsilon_h_eq", "h_eq / W/(m2 K)"),
        ]:
            pivot = both_e.pivot_table(index="case_short", columns="route", values=col)
            fig, ax = plt.subplots(figsize=(7.6, 4.0))
            pivot.plot(kind="bar", ax=ax)
            ax.set_ylabel(ylabel)
            ax.set_title(title)
            ax.grid(True, axis="y", alpha=0.3)
            fig.tight_layout()
            fig.savefig(os.path.join(OUT, fname + ".png"), dpi=240)
            fig.savefig(os.path.join(OUT, fname + ".pdf"))
            plt.close(fig)

    print("Wrote k-epsilon comparison figures to %s" % OUT)


if __name__ == "__main__":
    main()
