from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


ROOT = Path("G:/codexproject")
OUT = ROOT / "COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon"
FIG = OUT / "annual_figures"


def main():
    FIG.mkdir(exist_ok=True)
    energy = pd.read_csv(OUT / "COMSOL_annual_energy_summary.csv")
    tout = pd.read_csv(OUT / "COMSOL_Tout_delta_sweep.csv")
    comp = pd.read_csv(OUT / "COMSOL_annual_kepsilon_vs_MinaeiG_comparison.csv")
    h = pd.read_csv(OUT / "COMSOL_annual_global_h_eq_stats.csv")

    fig, ax = plt.subplots(figsize=(7.4, 4.2))
    x = energy["delta_mm"].astype(str)
    ax.bar(x, energy["Eabs_kWh"], color="#4477AA")
    ax.set_xlabel("air gap delta / mm")
    ax.set_ylabel("annual heat exchange / kWh")
    ax.set_title("Annual k-epsilon CFD heat exchange")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_energy.png", dpi=240)
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_energy.pdf")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.4, 4.2))
    ax.plot(tout["t_day"], tout["Tin_C"], "k-", lw=1.2, label="Tin")
    for d, col in [
        (0, "Tout_resistance_delta_0mm_C"),
        (1, "Tout_resistance_delta_1mm_C"),
        (5, "Tout_resistance_delta_5mm_C"),
    ]:
        ax.plot(tout["t_day"], tout[col], lw=1.1, label=f"Tout delta={d} mm")
    ax.set_xlabel("time / day")
    ax.set_ylabel("temperature / degC")
    ax.set_title("Annual k-epsilon CFD outlet temperature")
    ax.grid(True, alpha=0.3)
    ax.legend(ncol=2)
    fig.tight_layout()
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_Tout.png", dpi=240)
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_Tout.pdf")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.4, 4.2))
    ax.plot(comp["delta_mm"], comp["Eabs_kWh_CFD_minus_MinaeiG_percent"], "o-", lw=1.4)
    ax.axhline(0, color="k", lw=0.8)
    ax.set_xlabel("air gap delta / mm")
    ax.set_ylabel("CFD minus Minaei-G / %")
    ax.set_title("Annual heat exchange difference")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_vs_MinaeiG_error.png", dpi=240)
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_vs_MinaeiG_error.pdf")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.4, 4.2))
    ax.bar(h["delta_mm"].astype(str), h["h_eq_mean_W_m2K"], color="#66A61E")
    ax.set_xlabel("air gap delta / mm")
    ax.set_ylabel("global h_eq mean / W/(m2 K)")
    ax.set_title("Annual k-epsilon CFD global effective h")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_h_eq.png", dpi=240)
    fig.savefig(FIG / "Fig_annual_kepsilon_CFD_h_eq.pdf")
    plt.close(fig)

    print(f"Wrote figures to {FIG}")


if __name__ == "__main__":
    main()
