"""Post-process Ozgener et al. (2011) validation data.

The digitized data are extracted from Figs. 3-7 of:
Ozgener, O., Ozgener, L., Goswami, D. Y. (2011). Experimental
prediction of total thermal resistance of a closed loop EAHE for
greenhouse cooling system. International Communications in Heat and Mass
Transfer, 38, 711-716. DOI: 10.1016/j.icheatmasstransfer.2011.03.009.

If `ozgener2011_model_rtot.csv` exists, model-to-experiment metrics are
added automatically. Otherwise only the literature digitization statistics
are exported.
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parent
DATA = ROOT / "literature_extraction" / "ozgener2011_digitized_rtot.csv"
PARAMS = ROOT / "literature_extraction" / "ozgener2011_extracted_parameters.csv"
OUT_FIG = ROOT / "paper_figures"
OUT_TAB = ROOT / "paper_tables"
REPORTED_RTOT = 0.021


def setup_style():
    plt.rcParams.update(
        {
            "font.family": "Arial",
            "font.size": 8.5,
            "axes.labelsize": 9,
            "legend.fontsize": 8,
            "xtick.labelsize": 8,
            "ytick.labelsize": 8,
            "savefig.dpi": 600,
        }
    )


def figure_digitized_curves(df):
    labels = {
        "Fig3": ("Test length / h", "Time effect"),
        "Fig4": ("Wall temperature / degC", "Wall-temperature effect"),
        "Fig5": ("Inlet air temperature / degC", "Inlet-temperature effect"),
        "Fig6": ("Outlet air temperature / degC", "Outlet-temperature effect"),
        "Fig7": ("Fluid-wall temperature difference / K", "Driving-temperature effect"),
    }
    colors = {
        "Fig3": "#1f77b4",
        "Fig4": "#2ca02c",
        "Fig5": "#d62728",
        "Fig6": "#9467bd",
        "Fig7": "#8c564b",
    }
    fig, axes = plt.subplots(3, 2, figsize=(7.0, 7.4))
    axes = axes.ravel()
    for ax, fig_id in zip(axes, ["Fig3", "Fig4", "Fig5", "Fig6", "Fig7"]):
        sub = df[df["Figure"] == fig_id].copy()
        ax.plot(sub["x"], sub["Rtot_K_m_W"], "o-", color=colors[fig_id], ms=3.5, label="digitized data")
        ax.axhline(REPORTED_RTOT, color="0.25", ls="--", lw=0.9, label="reported mean")
        ax.set_xlabel(labels[fig_id][0])
        ax.set_ylabel("Rtot / K m W-1")
        ax.set_title(labels[fig_id][1])
        ax.grid(True, alpha=0.25)
        ax.legend(frameon=False)
    axes[-1].axis("off")
    OUT_FIG.mkdir(exist_ok=True)
    plt.tight_layout()
    plt.savefig(OUT_FIG / "Fig08_ozgener2011_digitized_resistance.png")
    plt.savefig(OUT_FIG / "Fig08_ozgener2011_digitized_resistance.pdf")
    plt.close()


def table_digitized_stats(df):
    rows = []
    for fig_id, sub in df.groupby("Figure", sort=True):
        err = sub["Rtot_K_m_W"].values - REPORTED_RTOT
        rows.append(
            {
                "Figure": fig_id,
                "N": len(sub),
                "Rtot_min_K_m_W": sub["Rtot_K_m_W"].min(),
                "Rtot_mean_K_m_W": sub["Rtot_K_m_W"].mean(),
                "Rtot_max_K_m_W": sub["Rtot_K_m_W"].max(),
                "RMSE_vs_reported_mean_K_m_W": float(np.sqrt(np.mean(err**2))),
                "MBE_vs_reported_mean_K_m_W": float(np.mean(err)),
            }
        )
    out = pd.DataFrame(rows)
    OUT_TAB.mkdir(exist_ok=True)
    out.to_csv(OUT_TAB / "ozgener2011_digitized_rtot_statistics.csv", index=False)
    return out


def model_metrics_if_available():
    model_file = ROOT / "ozgener2011_model_rtot.csv"
    if not model_file.exists():
        return pd.DataFrame(
            [
                {
                    "Status": "model file not found",
                    "Note": "Run main_ozgener2011_validation in MATLAB to generate ozgener2011_model_rtot.csv.",
                }
            ]
        )
    m = pd.read_csv(model_file)
    last_day = m[m["time_h"] >= m["time_h"].max() - 24]
    r_model = last_day["R_fluid_wall_K_m_W"].mean()
    tout_model = last_day["Tout_degC"].mean()

    params = pd.read_csv(PARAMS)
    exp_tout = float(params.loc[params["Parameter"] == "Mean outlet air temperature", "Value"].iloc[0])
    err_r = r_model - REPORTED_RTOT
    return pd.DataFrame(
        [
            {
                "Status": "model compared",
                "R_model_last_day_K_m_W": r_model,
                "R_reported_K_m_W": REPORTED_RTOT,
                "R_error_K_m_W": err_r,
                "Tout_model_last_day_degC": tout_model,
                "Tout_exp_mean_degC": exp_tout,
                "Tout_error_K": tout_model - exp_tout,
            }
        ]
    )


def main():
    setup_style()
    df = pd.read_csv(DATA)
    figure_digitized_curves(df)
    stats = table_digitized_stats(df)
    metrics = model_metrics_if_available()
    metrics.to_csv(OUT_TAB / "ozgener2011_model_validation_metrics.csv", index=False)
    print(stats.to_string(index=False))
    print(metrics.to_string(index=False))


if __name__ == "__main__":
    main()
