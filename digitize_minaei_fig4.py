from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
IN = ROOT / "Minaei_literature_data_extract" / "rendered_pages" / "Minaei_page6_300dpi.png"
OUT = ROOT / "Minaei_literature_data_extract" / "Fig4_digitized"
OUT.mkdir(parents=True, exist_ok=True)

# Manual calibration from the rendered page.
# Pixel coordinates are for the inner plot frame of Fig. 4.
PLOT_LEFT = 1516
PLOT_RIGHT = 2264
PLOT_TOP = 792
PLOT_BOTTOM = 1540
X_MIN, X_MAX = 0.0, 365.0
Y_MIN, Y_MAX = 4.0, 28.0

# Legend is inside the lower-left of the plot; mask it to avoid digitizing legend strokes.
LEGEND_BOX = (1524, 1258, 1970, 1524)


def px_to_data(x_px, y_px):
    x = X_MIN + (x_px - PLOT_LEFT) / (PLOT_RIGHT - PLOT_LEFT) * (X_MAX - X_MIN)
    y = Y_MAX - (y_px - PLOT_TOP) / (PLOT_BOTTOM - PLOT_TOP) * (Y_MAX - Y_MIN)
    return x, y


def data_to_px(x, y):
    x_px = PLOT_LEFT + (x - X_MIN) / (X_MAX - X_MIN) * (PLOT_RIGHT - PLOT_LEFT)
    y_px = PLOT_TOP + (Y_MAX - y) / (Y_MAX - Y_MIN) * (PLOT_BOTTOM - PLOT_TOP)
    return x_px, y_px


def in_legend(x, y):
    x0, y0, x1, y1 = LEGEND_BOX
    return (x >= x0) & (x <= x1) & (y >= y0) & (y <= y1)


def masked_arrays(image):
    arr = np.asarray(image.convert("RGB"))
    yy, xx = np.indices(arr.shape[:2])
    inside = (
        (xx >= PLOT_LEFT + 12)
        & (xx <= PLOT_RIGHT - 14)
        & (yy >= PLOT_TOP + 12)
        & (yy <= PLOT_BOTTOM - 14)
        & ~in_legend(xx, yy)
    )
    return arr, xx, yy, inside


def bin_curve(mask, xx, yy, bin_days=5.0, mode="median", y_range=None):
    x_data, y_data = px_to_data(xx[mask], yy[mask])
    if y_range is not None:
        lo_y, hi_y = y_range
        keep = (y_data >= lo_y) & (y_data <= hi_y)
        x_data = x_data[keep]
        y_data = y_data[keep]
    bins = np.arange(X_MIN, X_MAX + bin_days, bin_days)
    rows = []
    for lo, hi in zip(bins[:-1], bins[1:]):
        sel = (x_data >= lo) & (x_data < hi)
        if not np.any(sel):
            rows.append(((lo + hi) / 2, np.nan))
            continue
        vals = y_data[sel]
        if mode == "upper":
            y = np.nanpercentile(vals, 80)
        elif mode == "lower":
            y = np.nanpercentile(vals, 20)
        elif mode == "p10":
            y = np.nanpercentile(vals, 10)
        elif mode == "p90":
            y = np.nanpercentile(vals, 90)
        else:
            y = np.nanmedian(vals)
        rows.append(((lo + hi) / 2, y))
    return pd.DataFrame(rows, columns=["time_day", "temperature_C"])


def smooth(series, window=7):
    return series.interpolate(limit_direction="both").rolling(window, center=True, min_periods=1).median()


def main():
    img = Image.open(IN)
    arr, xx, yy, inside = masked_arrays(img)
    r = arr[..., 0]
    g = arr[..., 1]
    b = arr[..., 2]

    # Anti-aliased line masks, tuned for the rendered Elsevier figure.
    green_mask = inside & (g > 120) & (r < 120) & (b < 180)
    red_mask = inside & (r > 150) & (g < 130) & (b < 130)
    black_mask = inside & (r < 95) & (g < 95) & (b < 95)

    green_mid = bin_curve(green_mask, xx, yy, mode="median", y_range=(13.0, 27.8)).rename(
        columns={"temperature_C": "experimental_green_digitized_C"}
    )
    green_p10 = bin_curve(green_mask, xx, yy, mode="p10", y_range=(13.0, 27.8)).rename(
        columns={"temperature_C": "experimental_green_p10_C"}
    )
    green_p90 = bin_curve(green_mask, xx, yy, mode="p90", y_range=(13.0, 27.8)).rename(
        columns={"temperature_C": "experimental_green_p90_C"}
    )
    black = bin_curve(black_mask, xx, yy, mode="upper", y_range=(14.0, 25.5)).rename(
        columns={"temperature_C": "present_study_black_digitized_C"}
    )
    red_upper = bin_curve(red_mask, xx, yy, mode="upper", y_range=(15.0, 25.5)).rename(
        columns={"temperature_C": "full_numerical_red_dashed_approx_C"}
    )
    red_lower = bin_curve(red_mask, xx, yy, mode="lower", y_range=(15.0, 25.5)).rename(
        columns={"temperature_C": "simplified_numerical_red_solid_approx_C"}
    )

    df = green_mid.merge(green_p10, on="time_day").merge(green_p90, on="time_day")
    df = df.merge(black, on="time_day").merge(red_upper, on="time_day").merge(red_lower, on="time_day")

    # Smooth the black/red model curves because they are continuous smooth curves.
    for col in [
        "present_study_black_digitized_C",
        "full_numerical_red_dashed_approx_C",
        "simplified_numerical_red_solid_approx_C",
    ]:
        df[col] = smooth(df[col])

    df.to_csv(OUT / "Minaei_Fig4_digitized_5day.csv", index=False, encoding="utf-8-sig")

    # Save crop and mask-QA image.
    crop = img.crop((PLOT_LEFT - 80, PLOT_TOP - 60, PLOT_RIGHT + 30, PLOT_BOTTOM + 90))
    crop.save(OUT / "Minaei_Fig4_crop.png")

    qa = img.copy()
    draw = ImageDraw.Draw(qa)
    for offset in range(3):
        draw.rectangle(
            (PLOT_LEFT - offset, PLOT_TOP - offset, PLOT_RIGHT + offset, PLOT_BOTTOM + offset),
            outline=(0, 0, 255),
        )
        x0, y0, x1, y1 = LEGEND_BOX
        draw.rectangle((x0 - offset, y0 - offset, x1 + offset, y1 + offset), outline=(255, 128, 0))
    qa.crop((PLOT_LEFT - 100, PLOT_TOP - 100, PLOT_RIGHT + 60, PLOT_BOTTOM + 140)).save(
        OUT / "Minaei_Fig4_digitization_calibration_crop.png"
    )

    fig, ax = plt.subplots(figsize=(7.2, 4.6))
    ax.fill_between(
        df["time_day"],
        df["experimental_green_p10_C"],
        df["experimental_green_p90_C"],
        color="#2ecc71",
        alpha=0.18,
        label="Experimental green band p10-p90",
    )
    ax.plot(df["time_day"], df["experimental_green_digitized_C"], color="#2ecc71", lw=1.4, label="Experimental green median")
    ax.plot(df["time_day"], df["present_study_black_digitized_C"], color="black", lw=1.8, label="Present study")
    ax.plot(
        df["time_day"],
        df["full_numerical_red_dashed_approx_C"],
        color="red",
        ls="--",
        lw=1.5,
        label="Full numerical red dashed approx",
    )
    ax.plot(
        df["time_day"],
        df["simplified_numerical_red_solid_approx_C"],
        color="red",
        lw=1.5,
        label="Simplified numerical red solid approx",
    )
    ax.set_xlim(0, 365)
    ax.set_ylim(4, 28)
    ax.set_xlabel("Time / days")
    ax.set_ylabel("Temperature / degC")
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=8, loc="lower left")
    fig.tight_layout()
    fig.savefig(OUT / "Minaei_Fig4_digitized_curves.png", dpi=300)
    fig.savefig(OUT / "Minaei_Fig4_digitized_curves.pdf")
    plt.close(fig)

    notes = [
        "# Minaei Fig. 4 Digitization Notes",
        "",
        "Source: Minaei et al. 2021 Fig. 4, rendered from the local PDF at scale 4.0.",
        "",
        "Axis calibration:",
        f"- x pixel range {PLOT_LEFT}-{PLOT_RIGHT} maps to 0-365 days.",
        f"- y pixel range {PLOT_BOTTOM}-{PLOT_TOP} maps to 4-28 degC.",
        "",
        "The legend is inside the plot and was masked before color extraction.",
        "The green experimental curve is noisy and overlaps the fitted green curve; the CSV therefore reports a green median and p10-p90 band rather than claiming exact raw/fitted separation.",
        "The red dashed and red solid curves are close together; they are separated approximately using upper/lower red-pixel percentiles.",
        "",
        "Use these data as digitized approximate literature data, not as original experimental measurements.",
    ]
    (OUT / "Minaei_Fig4_digitization_notes.md").write_text("\n".join(notes), encoding="utf-8")

    print(f"Wrote Fig. 4 digitized outputs to {OUT}")


if __name__ == "__main__":
    main()
