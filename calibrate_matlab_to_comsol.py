import csv
import math
import os


ROOT = r"G:\codexproject"
MAT_DIR = os.path.join(ROOT, "EAHE_airgap_physical_v17_review_ready_results")
ORG_DIR = os.path.join(MAT_DIR, "Origin_ready_data")
COM_DIR = os.path.join(ROOT, "COMSOL_EAHE_outputs_annual_full")
OUT_DIR = os.path.join(MAT_DIR, "MATLAB_COMSOL_calibrated")

SUMMARY_MAT = os.path.join(MAT_DIR, "Table_01_main_performance_summary.csv")
TOUT_MAT = os.path.join(ORG_DIR, "Origin_Fig01_Tin_Th_Tout.csv")
Q_MAT = os.path.join(ORG_DIR, "Origin_Fig03_Qair.csv")
SUMMARY_COM = os.path.join(COM_DIR, "COMSOL_annual_energy_summary.csv")
TOUT_COM = os.path.join(COM_DIR, "COMSOL_Tout_delta_sweep.csv")

DELTAS = [0, 0.5, 1, 2, 3, 5]
MDOT_CP = 1.20 * 0.050 * 1006.0


def read_csv(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows, fields):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fields)
        writer.writeheader()
        writer.writerows(rows)


def tag(d):
    return ("%g" % d).replace(".", "p")


def mat_tag(d):
    return "d" + tag(d) + "mm"


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


def metrics(a, b):
    diffs = [x - y for x, y in zip(a, b)]
    return {
        "RMSE_Tout_C": math.sqrt(sum(x * x for x in diffs) / len(diffs)),
        "MAE_Tout_C": sum(abs(x) for x in diffs) / len(diffs),
        "MaxAbs_Tout_C": max(abs(x) for x in diffs),
        "Bias_Calibrated_minus_COMSOL_C": sum(diffs) / len(diffs),
    }


def annual_energy(day, q):
    # day step can be nonuniform; convert day to seconds for trapezoidal integration.
    ecool = 0.0
    eheat = 0.0
    eabs = 0.0
    for i in range(1, len(day)):
        dt = (day[i] - day[i - 1]) * 86400.0
        q0, q1 = q[i - 1], q[i]
        pos0, pos1 = max(q0, 0.0), max(q1, 0.0)
        neg0, neg1 = max(-q0, 0.0), max(-q1, 0.0)
        ecool += 0.5 * (pos0 + pos1) * dt
        eheat += 0.5 * (neg0 + neg1) * dt
        eabs += 0.5 * (abs(q0) + abs(q1)) * dt
    return ecool / 3.6e6, eheat / 3.6e6, eabs / 3.6e6


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    mat_summary = {float(r["delta_mm"]): r for r in read_csv(SUMMARY_MAT)}
    com_summary = {
        float(r["delta_mm"]): r
        for r in read_csv(SUMMARY_COM)
        if r["model_type"] == "resistance_gap"
    }

    mat_e0 = float(mat_summary[0]["Eabs_kWh"])
    com_e0 = float(com_summary[0]["Eabs_kWh"])
    strength_factor = com_e0 / mat_e0

    dmat = [float(mat_summary[d]["Dgap_percent"]) for d in DELTAS if d > 0]
    dcom = [float(com_summary[d]["Dgap_percent"]) for d in DELTAS if d > 0]
    gap_sensitivity_factor = sum(a * b for a, b in zip(dmat, dcom)) / sum(a * a for a in dmat)

    calib_rows = []
    scale_by_delta = {}
    for d in DELTAS:
        raw_e = float(mat_summary[d]["Eabs_kWh"])
        raw_dgap = float(mat_summary[d]["Dgap_percent"])
        target_dgap = gap_sensitivity_factor * raw_dgap
        target_e = com_e0 * (1.0 - target_dgap / 100.0)
        scale = target_e / raw_e
        scale_by_delta[d] = scale
        calib_rows.append(
            {
                "delta_mm": d,
                "MATLAB_raw_Eabs_kWh": raw_e,
                "COMSOL_target_Eabs_kWh": float(com_summary[d]["Eabs_kWh"]),
                "MATLAB_calibrated_Eabs_kWh": target_e,
                "MATLAB_raw_Dgap_percent": raw_dgap,
                "COMSOL_target_Dgap_percent": float(com_summary[d]["Dgap_percent"]),
                "MATLAB_calibrated_Dgap_percent": target_dgap,
                "heat_strength_factor": strength_factor,
                "gap_sensitivity_factor": gap_sensitivity_factor,
                "Q_scale_for_this_delta": scale,
            }
        )

    write_csv(
        os.path.join(OUT_DIR, "calibration_summary.csv"),
        calib_rows,
        list(calib_rows[0].keys()),
    )

    tout_rows = read_csv(TOUT_MAT)
    q_rows = read_csv(Q_MAT)
    day = [float(r["day"]) for r in tout_rows]
    time_fields = ["day", "Tin_C"]
    cal_time_rows = [{"day": r["day"], "Tin_C": r["Tin_C"]} for r in tout_rows]

    for d in DELTAS:
        mt = mat_tag(d)
        q_col = "Qair_" + mt + "_W"
        tout_col = "Tout_calibrated_" + mt + "_C"
        time_fields.append(tout_col)
        scale = scale_by_delta[d]
        for i, row in enumerate(cal_time_rows):
            tin = float(tout_rows[i]["Tin_C"])
            q_cal = scale * float(q_rows[i][q_col])
            row[tout_col] = tin - q_cal / MDOT_CP

    write_csv(
        os.path.join(OUT_DIR, "calibrated_Tout_timeseries.csv"),
        cal_time_rows,
        time_fields,
    )

    # Compute time-series metrics against COMSOL resistance-gap output.
    com_tout_rows = read_csv(TOUT_COM)
    com_day = [float(r["t_day"]) for r in com_tout_rows]
    metric_rows = []
    base_cal = [float(r["Tout_calibrated_d0mm_C"]) for r in cal_time_rows]
    base_com = [float(r["Tout_resistance_delta_0mm_C"]) for r in com_tout_rows]
    base_cal_on_com = [interp_linear(day, base_cal, x) for x in com_day]
    for d in DELTAS:
        mt = mat_tag(d)
        ct = tag(d) + "mm"
        cal = [float(r["Tout_calibrated_" + mt + "_C"]) for r in cal_time_rows]
        com = [float(r["Tout_resistance_delta_" + ct + "_C"]) for r in com_tout_rows]
        cal_on_com = [interp_linear(day, cal, x) for x in com_day]
        m = metrics(cal_on_com, com)
        cal_effect = [v - b for v, b in zip(cal_on_com, base_cal_on_com)]
        com_effect = [v - b for v, b in zip(com, base_com)]
        em = metrics(cal_effect, com_effect)
        metric_rows.append(
            {
                "delta_mm": d,
                **m,
                "RMSE_airgap_effect_C": em["RMSE_Tout_C"],
                "MAE_airgap_effect_C": em["MAE_Tout_C"],
                "MaxAbs_airgap_effect_C": em["MaxAbs_Tout_C"],
                "Bias_airgap_effect_C": em["Bias_Calibrated_minus_COMSOL_C"],
            }
        )

    write_csv(
        os.path.join(OUT_DIR, "calibrated_Tout_metrics_vs_COMSOL.csv"),
        metric_rows,
        list(metric_rows[0].keys()),
    )

    print("Calibration output:", OUT_DIR)
    print("heat_strength_factor = {:.6f}".format(strength_factor))
    print("gap_sensitivity_factor = {:.6f}".format(gap_sensitivity_factor))
    for r in calib_rows:
        print(
            "d={:>3g} mm | Eabs cal {:.2f}, COMSOL {:.2f} kWh | "
            "Dgap cal {:.2f}%, COMSOL {:.2f}% | Q scale {:.4f}".format(
                r["delta_mm"],
                r["MATLAB_calibrated_Eabs_kWh"],
                r["COMSOL_target_Eabs_kWh"],
                r["MATLAB_calibrated_Dgap_percent"],
                r["COMSOL_target_Dgap_percent"],
                r["Q_scale_for_this_delta"],
            )
        )
    print("Time-series metrics:")
    for r in metric_rows:
        print(
            "d={:>3g} mm | Tout RMSE {:.3f} C | effect RMSE {:.3f} C".format(
                r["delta_mm"], r["RMSE_Tout_C"], r["RMSE_airgap_effect_C"]
            )
        )


if __name__ == "__main__":
    main()
