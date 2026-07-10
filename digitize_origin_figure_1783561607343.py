import json
import os
import time
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "1783561607343_d.png"
OUT = ROOT / "image_digitization_1783561607343"

# Pixel coordinates are the centers of the detected plot-frame strokes.
PLOT_LEFT = 105.5
PLOT_RIGHT = 580.5
PLOT_TOP = 31.5
PLOT_BOTTOM = 463.5
X_MIN, X_MAX = 0.0, 365.0
Y_MIN, Y_MAX = 4.0, 28.0

# Keep the legend from entering raw-pixel exports. It lies below the data range,
# but masking it makes QA overlays easier to interpret.
LEGEND_BOX = (118, 327, 454, 432)


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


def native_centerline(
    mask,
    xx,
    yy,
    name,
    mode="median",
    min_temp=None,
    max_temp=None,
):
    cols = np.arange(int(np.ceil(PLOT_LEFT + 1)), int(np.floor(PLOT_RIGHT)))
    rows = []
    for col in cols:
        sel = mask & (xx == col)
        if not np.any(sel):
            rows.append({"pixel_x": col, "time_day": px_to_data(col, 0)[0], name: np.nan})
            continue

        yvals = yy[sel].astype(float)
        _, temp_vals = px_to_data(np.full_like(yvals, col), yvals)
        if min_temp is not None:
            keep = temp_vals >= min_temp
            yvals = yvals[keep]
            temp_vals = temp_vals[keep]
        if max_temp is not None:
            keep = temp_vals <= max_temp
            yvals = yvals[keep]
            temp_vals = temp_vals[keep]
        if len(temp_vals) == 0:
            rows.append({"pixel_x": col, "time_day": px_to_data(col, 0)[0], name: np.nan})
            continue

        if mode == "upper_temp":
            temp = float(np.nanpercentile(temp_vals, 85))
        elif mode == "lower_temp":
            temp = float(np.nanpercentile(temp_vals, 15))
        elif mode == "upper_envelope":
            temp = float(np.nanpercentile(temp_vals, 92))
        elif mode == "lower_envelope":
            temp = float(np.nanpercentile(temp_vals, 8))
        else:
            temp = float(np.nanmedian(temp_vals))

        rows.append({"pixel_x": col, "time_day": px_to_data(col, 0)[0], name: temp})

    return pd.DataFrame(rows)


def interpolate_series(df, col, x_new):
    valid = df[["time_day", col]].dropna()
    if valid.empty:
        return np.full_like(x_new, np.nan, dtype=float)
    return np.interp(x_new, valid["time_day"].values, valid[col].values)


def smooth_series(values, window):
    return (
        values.interpolate(limit_direction="both")
        .rolling(window, center=True, min_periods=max(3, window // 4))
        .median()
        .interpolate(limit_direction="both")
    )


def save_origin_project(csv_path, out_dir):
    try:
        import win32com.client  # type: ignore
    except Exception as exc:  # pragma: no cover - depends on local Windows setup.
        return False, f"pywin32 unavailable: {exc}"

    try:
        app = win32com.client.Dispatch("Origin.ApplicationSI")
        app.Execute("doc -mc 1;")
        app.Execute("doc -n;")
        app.Execute("newbook name:=DigitizedFigure option:=lsname;")
        app.Execute(f'impASC fname:="{str(csv_path).replace(chr(92), chr(92) * 2)}";')
        app.Execute("range rr = 1!(1,2:6);")
        app.Execute("plotxy iy:=rr plot:=200;")
        app.Execute('page.longname$ = "Digitized annual temperature curves";')
        app.Execute('label -xb "Time (days)";')
        app.Execute('label -yl "Temperature (degC)";')
        app.Execute("layer.x.from=0; layer.x.to=365; layer.y.from=4; layer.y.to=28;")
        origin_png_dir = out_dir / "origin_exports"
        origin_png_dir.mkdir(exist_ok=True)
        escaped_dir = str(origin_png_dir).replace("\\", "\\\\")
        app.Execute(f'expGraph type:=png path:="{escaped_dir}" filename:="origin_digitized_replot" overwrite:=replace tr1:=600;')
        app.Execute(f'expGraph type:=pdf path:="{escaped_dir}" filename:="origin_digitized_replot" overwrite:=replace;')
        opju = out_dir / "digitized_1783561607343_origin_project.opju"
        app.Execute(f'save "{str(opju).replace(chr(92), chr(92) * 2)}";')
        time.sleep(1)
        app.Exit()
        if opju.exists():
            return True, str(opju)
        candidates = sorted(out_dir.glob("digitized_1783561607343_origin_project*.opj*"))
        if candidates:
            return True, str(candidates[-1])
        return True, str(opju)
    except Exception as exc:  # pragma: no cover - depends on Origin automation.
        try:
            app.Exit()
        except Exception:
            pass
        return False, f"Origin automation failed: {exc}"


def draw_rect_width(draw, box, color, width):
    x0, y0, x1, y1 = box
    for offset in range(width):
        draw.rectangle((x0 - offset, y0 - offset, x1 + offset, y1 + offset), outline=color)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGB")
    arr = np.asarray(img)
    yy, xx = np.indices(arr.shape[:2])

    r = arr[..., 0].astype(int)
    g = arr[..., 1].astype(int)
    b = arr[..., 2].astype(int)

    inside = (
        (xx > PLOT_LEFT + 1)
        & (xx < PLOT_RIGHT - 1)
        & (yy > PLOT_TOP + 1)
        & (yy < PLOT_BOTTOM - 1)
        & ~in_legend(xx, yy)
    )
    _, temp_grid = px_to_data(xx, yy)
    data_band = (temp_grid >= 13.2) & (temp_grid <= 27.2)

    green_mask = inside & data_band & (g > 110) & (g - r > 35) & (g - b > 20)
    red_mask = inside & data_band & (r > 145) & (r - g > 55) & (r - b > 55)
    black_inside = inside & (xx > PLOT_LEFT + 12) & (xx < PLOT_RIGHT - 12)
    black_mask = black_inside & data_band & (r < 95) & (g < 95) & (b < 95) & (np.abs(r - g) < 25) & (np.abs(r - b) < 25)

    raw_rows = []
    for curve_name, mask in [
        ("green_pixels_all", green_mask),
        ("red_pixels_all", red_mask),
        ("black_pixels_all", black_mask),
    ]:
        xs = xx[mask]
        ys = yy[mask]
        xdata, ydata = px_to_data(xs, ys)
        raw_rows.append(
            pd.DataFrame(
                {
                    "curve_pixel_class": curve_name,
                    "pixel_x": xs.astype(int),
                    "pixel_y": ys.astype(int),
                    "time_day": xdata,
                    "temperature_C": ydata,
                    "r": r[mask],
                    "g": g[mask],
                    "b": b[mask],
                }
            )
        )
    raw_pixels = pd.concat(raw_rows, ignore_index=True)
    raw_pixels.to_csv(OUT / "digitized_1783561607343_raw_pixels.csv", index=False, encoding="utf-8-sig")

    green = native_centerline(
        green_mask,
        xx,
        yy,
        name="vaz_experimental_green_raw_C",
        mode="median",
        min_temp=13.2,
        max_temp=27.2,
    )
    black = native_centerline(
        black_mask,
        xx,
        yy,
        name="present_study_black_C",
        mode="median",
        min_temp=14.2,
        max_temp=24.2,
    )
    red_dash = native_centerline(
        red_mask,
        xx,
        yy,
        name="vaz_full_numerical_red_dashed_C",
        mode="upper_envelope",
        min_temp=14.8,
        max_temp=24.5,
    )
    red_solid = native_centerline(
        red_mask,
        xx,
        yy,
        name="brum_simplified_red_solid_C",
        mode="lower_envelope",
        min_temp=14.8,
        max_temp=24.5,
    )

    native = green.merge(black, on=["pixel_x", "time_day"], how="outer")
    native = native.merge(red_dash, on=["pixel_x", "time_day"], how="outer")
    native = native.merge(red_solid, on=["pixel_x", "time_day"], how="outer")
    native = native.sort_values("pixel_x").reset_index(drop=True)

    native["vaz_fitted_experimental_green_smooth_C"] = smooth_series(native["vaz_experimental_green_raw_C"], 31)
    for col in [
        "present_study_black_C",
        "vaz_full_numerical_red_dashed_C",
        "brum_simplified_red_solid_C",
    ]:
        native[col] = smooth_series(native[col], 9)

    curve_cols = [
        "vaz_experimental_green_raw_C",
        "vaz_fitted_experimental_green_smooth_C",
        "present_study_black_C",
        "vaz_full_numerical_red_dashed_C",
        "brum_simplified_red_solid_C",
    ]

    native.to_csv(OUT / "digitized_1783561607343_native_pixel_columns.csv", index=False, encoding="utf-8-sig")

    days = np.arange(0, 366, dtype=float)
    daily = pd.DataFrame({"time_day": days})
    for col in curve_cols:
        daily[col] = interpolate_series(native, col, days)
    daily.to_csv(OUT / "digitized_1783561607343_daily.csv", index=False, encoding="utf-8-sig")

    try:
        with pd.ExcelWriter(OUT / "digitized_1783561607343_data.xlsx", engine="openpyxl") as writer:
            daily.to_excel(writer, sheet_name="daily_0_365", index=False)
            native.to_excel(writer, sheet_name="native_pixel_columns", index=False)
            raw_pixels.to_excel(writer, sheet_name="raw_pixels", index=False)
    except Exception as exc:
        (OUT / "xlsx_export_error.txt").write_text(str(exc), encoding="utf-8")

    calibration = {
        "source_image": str(SRC),
        "image_size_px": {"width": img.width, "height": img.height},
        "plot_frame_px_center": {
            "left": PLOT_LEFT,
            "right": PLOT_RIGHT,
            "top": PLOT_TOP,
            "bottom": PLOT_BOTTOM,
        },
        "axis_data_range": {
            "x": {"min": X_MIN, "max": X_MAX, "unit": "days"},
            "y": {"min": Y_MIN, "max": Y_MAX, "unit": "degC"},
        },
        "resolution": {
            "day_per_pixel_x": (X_MAX - X_MIN) / (PLOT_RIGHT - PLOT_LEFT),
            "degC_per_pixel_y": (Y_MAX - Y_MIN) / (PLOT_BOTTOM - PLOT_TOP),
        },
        "curve_extraction": {
            "green": "color threshold; native median centerline; fitted experimental is 31-pixel rolling median of green centerline",
            "black": "dark neutral pixels; native median centerline; 9-pixel rolling median",
            "red_dashed": "red-pixel upper temperature envelope; 9-pixel rolling median",
            "red_solid": "red-pixel lower temperature envelope; 9-pixel rolling median",
        },
    }
    (OUT / "digitized_1783561607343_calibration.json").write_text(
        json.dumps(calibration, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    overlay = img.copy()
    draw = ImageDraw.Draw(overlay, "RGBA")
    draw_rect_width(draw, (PLOT_LEFT, PLOT_TOP, PLOT_RIGHT, PLOT_BOTTOM), (30, 90, 255, 230), 2)
    draw_rect_width(draw, LEGEND_BOX, (255, 128, 0, 220), 2)
    for col, color in [
        ("vaz_experimental_green_raw_C", (0, 180, 75, 210)),
        ("vaz_fitted_experimental_green_smooth_C", (0, 120, 30, 210)),
        ("present_study_black_C", (0, 0, 0, 220)),
        ("vaz_full_numerical_red_dashed_C", (255, 0, 0, 210)),
        ("brum_simplified_red_solid_C", (190, 0, 0, 210)),
    ]:
        points = []
        for xval, yval in native[["time_day", col]].dropna().values:
            xp, yp = data_to_px(xval, yval)
            points.append((float(xp), float(yp)))
        if len(points) > 1:
            draw.line(points, fill=color, width=2)
    overlay.save(OUT / "digitized_1783561607343_overlay.png")

    fig, ax = plt.subplots(figsize=(7.1, 5.1))
    ax.plot(daily["time_day"], daily["vaz_experimental_green_raw_C"], color="#00c853", lw=0.9, alpha=0.9, label="Experimental data of Vaz et al. [9]")
    ax.plot(daily["time_day"], daily["vaz_fitted_experimental_green_smooth_C"], color="#00c853", lw=1.6, ls="-.", label="Fitted experimental data")
    ax.plot(daily["time_day"], daily["present_study_black_C"], color="black", lw=1.8, label="Present study")
    ax.plot(daily["time_day"], daily["vaz_full_numerical_red_dashed_C"], color="red", lw=1.5, ls=(0, (5, 5)), label="Full numerical model of Vaz et al. [9]")
    ax.plot(daily["time_day"], daily["brum_simplified_red_solid_C"], color="red", lw=1.5, label="Simplified numerical model of Brum et al. [10]")
    ax.set_xlim(0, 365)
    ax.set_ylim(4, 28)
    ax.set_xlabel("Time (days)")
    ax.set_ylabel("Temperature (degC)")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="lower left", fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "digitized_1783561607343_replot.png", dpi=300)
    fig.savefig(OUT / "digitized_1783561607343_replot.pdf")
    plt.close(fig)

    notes = [
        "# Digitization notes",
        "",
        "Source image: 1783561607343_d.png.",
        "",
        "Axis calibration:",
        f"- x = {PLOT_LEFT}-{PLOT_RIGHT} px maps to 0-365 days.",
        f"- y = {PLOT_BOTTOM}-{PLOT_TOP} px maps to 4-28 degC.",
        f"- Native horizontal resolution is {(X_MAX - X_MIN) / (PLOT_RIGHT - PLOT_LEFT):.4f} day/px.",
        f"- Native vertical resolution is {(Y_MAX - Y_MIN) / (PLOT_BOTTOM - PLOT_TOP):.4f} degC/px.",
        "",
        "Precision notes:",
        "- The native-pixel-column CSV is the highest-resolution centerline table extracted from the raster image.",
        "- The daily CSV is interpolated from the native-pixel-column table.",
        "- Green raw experimental and green fitted experimental pixels overlap; the fitted curve is saved as a smooth rolling-median centerline.",
        "- Red dashed and red solid curves are very close; they are separated with the upper/lower red-pixel temperature envelope, so use them as digitized approximations rather than original data.",
        "",
        "Origin:",
        "- The script imports the daily CSV into Origin, plots the five curves, exports PNG/PDF, and saves an OPJU project when Origin COM automation is available.",
    ]
    (OUT / "digitized_1783561607343_notes.md").write_text("\n".join(notes) + "\n", encoding="utf-8")

    ok, message = save_origin_project(OUT / "digitized_1783561607343_daily.csv", OUT)
    (OUT / "origin_automation_status.txt").write_text(
        ("OK: " if ok else "FAILED: ") + message + "\n",
        encoding="utf-8",
    )
    print(f"Wrote digitized outputs to {OUT}")
    print(("Origin project: " if ok else "Origin status: ") + message)


if __name__ == "__main__":
    main()
