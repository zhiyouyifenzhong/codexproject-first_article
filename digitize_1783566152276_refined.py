import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image, ImageDraw
from scipy import ndimage


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "1783566152276_d.png"
OUT = ROOT / "image_digitization_1783566152276_refined"

PLOT_LEFT = 117.5
PLOT_RIGHT = 592.5
PLOT_TOP = 29.5
PLOT_BOTTOM = 461.5
X_MIN, X_MAX = 0.0, 365.0
Y_MIN, Y_MAX = 4.0, 28.0

LEGEND_BOX = (128, 325, 475, 432)


def px_to_data(x_px, y_px):
    x = X_MIN + (np.asarray(x_px) - PLOT_LEFT) / (PLOT_RIGHT - PLOT_LEFT) * (X_MAX - X_MIN)
    y = Y_MAX - (np.asarray(y_px) - PLOT_TOP) / (PLOT_BOTTOM - PLOT_TOP) * (Y_MAX - Y_MIN)
    return x, y


def data_to_px(x, y):
    x_px = PLOT_LEFT + (np.asarray(x) - X_MIN) / (X_MAX - X_MIN) * (PLOT_RIGHT - PLOT_LEFT)
    y_px = PLOT_TOP + (Y_MAX - np.asarray(y)) / (Y_MAX - Y_MIN) * (PLOT_BOTTOM - PLOT_TOP)
    return x_px, y_px


def in_legend(xx, yy):
    x0, y0, x1, y1 = LEGEND_BOX
    return (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)


def component_info(mask):
    labels, nlab = ndimage.label(mask, structure=np.ones((3, 3), dtype=int))
    objects = ndimage.find_objects(labels)
    info = {}
    for label_id, sli in enumerate(objects, start=1):
        if sli is None:
            continue
        count = int((labels[sli] == label_id).sum())
        y0, y1 = sli[0].start, sli[0].stop - 1
        x0, x1 = sli[1].start, sli[1].stop - 1
        info[label_id] = {
            "count": count,
            "x0": x0,
            "x1": x1,
            "y0": y0,
            "y1": y1,
            "width": x1 - x0 + 1,
            "height": y1 - y0 + 1,
            "score": count * max(y1 - y0 + 1, 1),
        }
    return labels, info


def green_experimental_mask(green_mask):
    labels, info = component_info(green_mask)
    keep_ids = []
    for label_id, d in info.items():
        # The fitted green curve is dash-dot and forms short, low-height
        # components. The raw experimental curve forms taller jagged segments.
        if d["count"] >= 80 or (d["count"] >= 14 and d["height"] >= 6):
            keep_ids.append(label_id)
    keep = np.isin(labels, keep_ids)
    return keep, labels, info


def centerline_from_mask(mask, xx, yy, name, mode="median", labels=None, info=None):
    cols = np.arange(int(np.ceil(PLOT_LEFT + 2)), int(np.floor(PLOT_RIGHT - 2)) + 1)
    rows = []
    for col in cols:
        sel = mask & (xx == col)
        if not np.any(sel):
            rows.append({"pixel_x": col, "time_day": float(px_to_data(col, 0)[0]), name: np.nan})
            continue
        yvals = yy[sel].astype(float)
        if labels is not None and info is not None:
            ids = labels[sel]
            ids = ids[ids > 0]
            if len(ids) > 0:
                unique_ids = np.unique(ids)
                best_id = max(unique_ids, key=lambda k: info.get(int(k), {}).get("score", 0))
                yvals = yy[(labels == best_id) & (xx == col)].astype(float)
        _, temps = px_to_data(np.full_like(yvals, col), yvals)
        if len(temps) == 0:
            value = np.nan
        elif mode == "upper":
            value = float(np.nanpercentile(temps, 90))
        elif mode == "lower":
            value = float(np.nanpercentile(temps, 10))
        elif mode == "upper_mid":
            value = float(np.nanpercentile(temps, 78))
        elif mode == "lower_mid":
            value = float(np.nanpercentile(temps, 22))
        else:
            value = float(np.nanmedian(temps))
        rows.append({"pixel_x": col, "time_day": float(px_to_data(col, 0)[0]), name: value})
    return pd.DataFrame(rows)


def split_red_masks(red_mask):
    labels, info = component_info(red_mask)
    if not info:
        return red_mask & False, red_mask & False, labels, info, None
    largest = max(info.keys(), key=lambda k: info[k]["count"])
    solid = labels == largest
    dashed = red_mask & (labels > 0) & (labels != largest)
    return solid, dashed, labels, info, largest


def interpolate_to_days(native, column):
    days = np.arange(0, 366, dtype=float)
    valid = native[["time_day", column]].dropna()
    if valid.empty:
        return days, np.full_like(days, np.nan)
    return days, np.interp(days, valid["time_day"].values, valid[column].values)


def sample_to_days_gapped(native, column, half_width_days=0.55):
    days = np.arange(0, 366, dtype=float)
    out = np.full_like(days, np.nan)
    valid = native[["time_day", column]].dropna()
    if valid.empty:
        return days, out
    t = valid["time_day"].values
    y = valid[column].values
    for i, day in enumerate(days):
        sel = np.abs(t - day) <= half_width_days
        if np.any(sel):
            out[i] = float(np.nanmedian(y[sel]))
    return days, out


def smooth_light(values, window):
    return values.interpolate(limit_direction="both").rolling(window, center=True, min_periods=2).median().interpolate(limit_direction="both")


def nearest_pixel_error(mask, times, temps):
    py, px = np.where(mask)
    if len(px) == 0:
        return {"mean_px": np.nan, "p95_px": np.nan, "max_px": np.nan}
    points = np.column_stack([px.astype(float), py.astype(float)])
    distances = []
    for x, y in zip(times, temps):
        if not np.isfinite(y):
            continue
        xp, yp = data_to_px(x, y)
        d2 = (points[:, 0] - xp) ** 2 + (points[:, 1] - yp) ** 2
        distances.append(float(np.sqrt(d2.min())))
    if not distances:
        return {"mean_px": np.nan, "p95_px": np.nan, "max_px": np.nan}
    arr = np.asarray(distances)
    return {"mean_px": float(arr.mean()), "p95_px": float(np.percentile(arr, 95)), "max_px": float(arr.max())}


def draw_segments(draw, native, column, color, width=2, max_gap_days=1.7):
    segment = []
    last_x = None
    for xval, yval in native[["time_day", column]].values:
        if not np.isfinite(yval):
            if len(segment) > 1:
                draw.line(segment, fill=color, width=width)
            segment = []
            last_x = None
            continue
        if last_x is not None and (xval - last_x) > max_gap_days:
            if len(segment) > 1:
                draw.line(segment, fill=color, width=width)
            segment = []
        xp, yp = data_to_px(xval, yval)
        segment.append((float(xp), float(yp)))
        last_x = xval
    if len(segment) > 1:
        draw.line(segment, fill=color, width=width)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGB")
    arr = np.asarray(img)
    h, w = arr.shape[:2]
    yy, xx = np.indices((h, w))

    r = arr[..., 0].astype(int)
    g = arr[..., 1].astype(int)
    b = arr[..., 2].astype(int)

    _, temp_grid = px_to_data(xx, yy)
    inside = (
        (xx > PLOT_LEFT + 1)
        & (xx < PLOT_RIGHT - 1)
        & (yy > PLOT_TOP + 1)
        & (yy < PLOT_BOTTOM - 1)
        & ~in_legend(xx, yy)
        & (temp_grid >= 13.5)
        & (temp_grid <= 27.3)
    )

    green_all = inside & (g > 120) & (r < 150) & (b < 200) & ((g - r) > 25) & ((g - b) > 10)
    green_raw, green_labels, green_info = green_experimental_mask(green_all)

    red_mask = inside & (r > 140) & (g < 130) & (b < 130) & ((r - g) > 40) & ((r - b) > 40)
    red_solid_mask, red_dashed_mask, red_labels, red_info, red_solid_label = split_red_masks(red_mask)
    black_mask = (
        inside
        & (xx > PLOT_LEFT + 18)
        & (xx < PLOT_RIGHT - 8)
        & (r < 115)
        & (g < 115)
        & (b < 115)
        & (np.abs(r - g) < 35)
        & (np.abs(r - b) < 35)
        & (temp_grid >= 14.0)
        & (temp_grid <= 24.4)
    )

    green = centerline_from_mask(
        green_raw,
        xx,
        yy,
        "experimental_vaz_green_C",
        labels=green_labels,
        info=green_info,
    )
    black = centerline_from_mask(black_mask, xx, yy, "present_study_black_C")
    red_dash = centerline_from_mask(red_dashed_mask, xx, yy, "full_numerical_vaz_red_dashed_C")
    red_solid = centerline_from_mask(red_solid_mask, xx, yy, "simplified_brum_red_solid_C")

    native = green.merge(black, on=["pixel_x", "time_day"], how="outer")
    native = native.merge(red_dash, on=["pixel_x", "time_day"], how="outer")
    native = native.merge(red_solid, on=["pixel_x", "time_day"], how="outer")
    native = native.sort_values("pixel_x").reset_index(drop=True)

    for col in ["present_study_black_C", "simplified_brum_red_solid_C"]:
        native[col] = smooth_light(native[col], 5)

    # The experimental green curve is intentionally not smoothed heavily: it is
    # the raw jagged curve rather than the fitted experimental curve.
    native["experimental_vaz_green_C"] = native["experimental_vaz_green_C"].interpolate(limit_direction="both")

    daily = pd.DataFrame({"time_day": np.arange(0, 366, dtype=float)})
    for col in [
        "experimental_vaz_green_C",
        "present_study_black_C",
        "full_numerical_vaz_red_dashed_C",
        "simplified_brum_red_solid_C",
    ]:
        if col == "full_numerical_vaz_red_dashed_C":
            _, vals = sample_to_days_gapped(native, col)
        else:
            _, vals = interpolate_to_days(native, col)
        daily[col] = vals

    # Save with five decimals because the user requested 1e-5 formatting.
    native.round(5).to_csv(OUT / "digitized_1783566152276_native_pixel_columns_refined.csv", index=False, encoding="utf-8-sig")
    daily.round(5).to_csv(OUT / "digitized_1783566152276_daily_refined.csv", index=False, encoding="utf-8-sig")
    try:
        with pd.ExcelWriter(OUT / "digitized_1783566152276_refined_data.xlsx", engine="openpyxl") as writer:
            daily.round(5).to_excel(writer, sheet_name="daily_0_365", index=False)
            native.round(5).to_excel(writer, sheet_name="native_pixel_columns", index=False)
    except Exception as exc:
        (OUT / "xlsx_export_error.txt").write_text(str(exc), encoding="utf-8")

    raw_rows = []
    for curve, mask in [
        ("experimental_green_raw_pixels", green_raw),
        ("present_study_black_pixels", black_mask),
        ("red_model_pixels", red_mask),
    ]:
        xs = xx[mask]
        ys = yy[mask]
        xd, yd = px_to_data(xs, ys)
        raw_rows.append(
            pd.DataFrame(
                {
                    "curve_pixel_class": curve,
                    "pixel_x": xs.astype(int),
                    "pixel_y": ys.astype(int),
                    "time_day": xd,
                    "temperature_C": yd,
                    "r": r[mask],
                    "g": g[mask],
                    "b": b[mask],
                }
            )
        )
    pd.concat(raw_rows, ignore_index=True).round(5).to_csv(
        OUT / "digitized_1783566152276_raw_pixels_refined.csv", index=False, encoding="utf-8-sig"
    )

    overlay = img.copy()
    draw = ImageDraw.Draw(overlay, "RGBA")
    draw.rectangle((PLOT_LEFT, PLOT_TOP, PLOT_RIGHT, PLOT_BOTTOM), outline=(30, 90, 255, 230))
    draw.rectangle(LEGEND_BOX, outline=(255, 128, 0, 220))
    draw_cfg = [
        ("experimental_vaz_green_C", (0, 190, 70, 230)),
        ("present_study_black_C", (0, 0, 0, 230)),
        ("full_numerical_vaz_red_dashed_C", (255, 0, 0, 230)),
        ("simplified_brum_red_solid_C", (180, 0, 0, 230)),
    ]
    for col, color in draw_cfg:
        draw_segments(draw, native, col, color, width=2)
    overlay.save(OUT / "digitized_1783566152276_overlay_refined.png")

    fig, ax = plt.subplots(figsize=(7.0, 4.8))
    ax.plot(daily["time_day"], daily["experimental_vaz_green_C"], color="#00b050", lw=0.9, label="Experimental data of Vaz et al.")
    ax.plot(daily["time_day"], daily["present_study_black_C"], color="black", lw=1.6, label="Present study")
    ax.plot(native["time_day"], native["full_numerical_vaz_red_dashed_C"], color="red", lw=1.3, ls="-", label="Full numerical model of Vaz et al. (digitized dashed segments)")
    ax.plot(daily["time_day"], daily["simplified_brum_red_solid_C"], color="red", lw=1.3, label="Simplified numerical model of Brum et al.")
    ax.set_xlim(0, 365)
    ax.set_ylim(4, 28)
    ax.set_xlabel("Time (days)")
    ax.set_ylabel("Temperature (degC)")
    ax.legend(frameon=False, fontsize=8, loc="lower left")
    fig.tight_layout()
    fig.savefig(OUT / "digitized_1783566152276_replot_refined.png", dpi=300)
    fig.savefig(OUT / "digitized_1783566152276_replot_refined.pdf")
    plt.close(fig)

    diagnostics = {
        "source_image": str(SRC),
        "plot_frame_px_center": {
            "left": PLOT_LEFT,
            "right": PLOT_RIGHT,
            "top": PLOT_TOP,
            "bottom": PLOT_BOTTOM,
        },
        "axis_data_range": {
            "x_days": [X_MIN, X_MAX],
            "y_degC": [Y_MIN, Y_MAX],
        },
        "pixel_resolution": {
            "day_per_pixel": (X_MAX - X_MIN) / (PLOT_RIGHT - PLOT_LEFT),
            "degC_per_pixel": (Y_MAX - Y_MIN) / (PLOT_BOTTOM - PLOT_TOP),
        },
        "true_precision_note": "Values are saved to 0.00001 degC, but the raster image supports only about 0.05556 degC per vertical pixel before subpixel assumptions.",
        "excluded_curve": "Fitted experimental Data green dash-dot curve is not exported.",
        "pixel_fit_distance": {
            "experimental_green": nearest_pixel_error(green_raw, native["time_day"].values, native["experimental_vaz_green_C"].values),
            "present_study_black": nearest_pixel_error(black_mask, native["time_day"].values, native["present_study_black_C"].values),
            "red_solid": nearest_pixel_error(red_solid_mask, native["time_day"].values, native["simplified_brum_red_solid_C"].values),
            "red_dashed": nearest_pixel_error(red_dashed_mask, native["time_day"].values, native["full_numerical_vaz_red_dashed_C"].values),
        },
        "red_component_split": {
            "solid_component_label": int(red_solid_label) if red_solid_label is not None else None,
            "solid_component_pixel_count": int(red_info[red_solid_label]["count"]) if red_solid_label is not None else None,
            "dashed_component_count": int(sum(1 for k in red_info if k != red_solid_label)),
            "rule": "Largest red connected component is treated as the continuous red solid curve; all smaller red components are exported as separated dashed segments with NaN gaps.",
        },
        "green_component_rule": "Kept tall/large green connected components to retain jagged experimental data and reject short dash-dot fitted segments.",
    }
    (OUT / "digitized_1783566152276_refined_diagnostics.json").write_text(
        json.dumps(diagnostics, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    notes = [
        "# Refined digitization notes",
        "",
        "The exported curves exclude the fitted experimental green dash-dot curve.",
        "Saved numeric precision is 5 decimal places.",
        "The actual physical precision is limited by the raster image resolution: approximately 0.05556 degC per pixel vertically.",
        "Therefore, 0.00001 degC should be interpreted as file formatting precision, not measurement accuracy.",
        "",
        "Files:",
        "- digitized_1783566152276_daily_refined.csv",
        "- digitized_1783566152276_native_pixel_columns_refined.csv",
        "- digitized_1783566152276_overlay_refined.png",
        "- digitized_1783566152276_refined_diagnostics.json",
    ]
    (OUT / "digitized_1783566152276_refined_notes.md").write_text("\n".join(notes) + "\n", encoding="utf-8")
    print("Wrote refined digitization outputs to", OUT)


if __name__ == "__main__":
    main()
