import csv
import math
import os


ROOT = r"G:\codexproject"
MAT_ORIGIN = os.path.join(
    ROOT,
    "EAHE_airgap_physical_v17_review_ready_results",
    "Origin_ready_data",
    "Origin_Fig01_Tin_Th_Tout.csv",
)
COM_TOUT = os.path.join(
    ROOT,
    "COMSOL_EAHE_outputs_annual_full",
    "COMSOL_Tout_delta_sweep.csv",
)
OUT_PATH = os.path.join(
    ROOT,
    "EAHE_airgap_physical_v17_review_ready_results",
    "MATLAB_COMSOL_Tout_timeseries_metrics.csv",
)


DELTAS = [0, 0.5, 1, 2, 3, 5]


def read_csv(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def interp_linear(xs, ys, x):
    if x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    lo, hi = 0, len(xs) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if xs[mid] <= x:
            lo = mid
        else:
            hi = mid
    x0, x1 = xs[lo], xs[hi]
    y0, y1 = ys[lo], ys[hi]
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


def delta_tag(d):
    text = ("%g" % d).replace(".", "p")
    return f"d{text}mm"


def comsol_delta_tag(d):
    return ("%g" % d).replace(".", "p") + "mm"


def metrics(a, b):
    diffs = [x - y for x, y in zip(a, b)]
    mae = sum(abs(x) for x in diffs) / len(diffs)
    rmse = math.sqrt(sum(x * x for x in diffs) / len(diffs))
    max_abs = max(abs(x) for x in diffs)
    bias = sum(diffs) / len(diffs)
    return rmse, mae, max_abs, bias


def main():
    mat_rows = read_csv(MAT_ORIGIN)
    com_rows = read_csv(COM_TOUT)
    mat_day = [float(r["day"]) for r in mat_rows]
    com_day = [float(r["t_day"]) for r in com_rows]

    rows = []
    mat_base = [float(r["Tout_d0mm_C"]) for r in mat_rows]
    com_base = [float(r["Tout_resistance_delta_0mm_C"]) for r in com_rows]
    mat_base_on_com = [interp_linear(mat_day, mat_base, day) for day in com_day]
    for d in DELTAS:
        tag = delta_tag(d)
        mat_col = f"Tout_{tag}_C"
        com_col = f"Tout_resistance_delta_{comsol_delta_tag(d)}_C"
        mat_tout = [float(r[mat_col]) for r in mat_rows]
        com_tout = [float(r[com_col]) for r in com_rows]
        mat_on_com = [interp_linear(mat_day, mat_tout, day) for day in com_day]
        rmse, mae, max_abs, bias = metrics(mat_on_com, com_tout)
        mat_effect = [v - b for v, b in zip(mat_on_com, mat_base_on_com)]
        com_effect = [v - b for v, b in zip(com_tout, com_base)]
        ermse, emae, emax_abs, ebias = metrics(mat_effect, com_effect)
        rows.append(
            {
                "delta_mm": d,
                "RMSE_Tout_C": rmse,
                "MAE_Tout_C": mae,
                "MaxAbs_Tout_C": max_abs,
                "Bias_MATLAB_minus_COMSOL_C": bias,
                "RMSE_airgap_effect_C": ermse,
                "MAE_airgap_effect_C": emae,
                "MaxAbs_airgap_effect_C": emax_abs,
                "Bias_airgap_effect_C": ebias,
            }
        )

    fields = list(rows[0].keys())
    with open(OUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fields)
        writer.writeheader()
        writer.writerows(rows)

    print(OUT_PATH)
    for r in rows:
        print(
            "d={:>3g} mm | RMSE {:.3f} C | MAE {:.3f} C | Max {:.3f} C | Bias {:+.3f} C".format(
                r["delta_mm"],
                r["RMSE_Tout_C"],
                r["MAE_Tout_C"],
                r["MaxAbs_Tout_C"],
                r["Bias_MATLAB_minus_COMSOL_C"],
            )
        )
    print("Air-gap incremental effect, using Tout_delta - Tout_0:")
    for r in rows:
        print(
            "d={:>3g} mm | RMSE {:.3f} C | MAE {:.3f} C | Max {:.3f} C | Bias {:+.3f} C".format(
                r["delta_mm"],
                r["RMSE_airgap_effect_C"],
                r["MAE_airgap_effect_C"],
                r["MaxAbs_airgap_effect_C"],
                r["Bias_airgap_effect_C"],
            )
        )


if __name__ == "__main__":
    main()
