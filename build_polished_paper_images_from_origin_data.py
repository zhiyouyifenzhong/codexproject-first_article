from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from build_paper_ready_origin_figures import DATA, OUT, prepare_data


PNG = OUT / "paper_polished_png"
PDF = OUT / "paper_polished_pdf"
TIFF = OUT / "paper_polished_tiff"


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


def ensure_dirs():
    for folder in [PNG, PDF, TIFF]:
        folder.mkdir(parents=True, exist_ok=True)


def plot_cfg(cfg):
    df = pd.read_csv(cfg["csv"])
    x = df.iloc[:, 0]
    ycols = list(df.columns[1:])

    fig, ax = plt.subplots(figsize=(6.8, 4.7))
    for i, col in enumerate(ycols):
        ax.plot(
            x,
            df[col],
            label=col,
            color=COLORS[i % len(COLORS)],
            linestyle=LINESTYLES[i % len(LINESTYLES)],
            linewidth=1.45,
        )

    if cfg.get("xlim"):
        ax.set_xlim(*cfg["xlim"])
    if cfg.get("ylim"):
        ax.set_ylim(*cfg["ylim"])

    ax.set_xlabel(cfg["xlabel"], fontsize=10)
    ax.set_ylabel(cfg["ylabel"], fontsize=10)
    ax.tick_params(axis="both", labelsize=9, direction="out", length=4, width=0.8)
    for spine in ax.spines.values():
        spine.set_linewidth(0.8)
    ax.grid(False)

    if len(ycols) <= 5:
        ax.legend(frameon=False, fontsize=8, loc="best")
    else:
        ax.legend(frameon=False, fontsize=7.5, ncol=2, loc="upper center", bbox_to_anchor=(0.5, 1.18))

    fig.tight_layout()
    stem = cfg["name"]
    fig.savefig(PNG / f"{stem}.png", dpi=600, bbox_inches="tight")
    fig.savefig(PDF / f"{stem}.pdf", bbox_inches="tight")
    fig.savefig(TIFF / f"{stem}.tiff", dpi=600, bbox_inches="tight")
    plt.close(fig)


def main():
    ensure_dirs()
    configs = prepare_data()
    for cfg in configs:
        print("Rendering polished", cfg["name"])
        plot_cfg(cfg)
    print(f"Wrote polished paper images to {OUT}")


if __name__ == "__main__":
    main()
