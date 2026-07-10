"""Paper-oriented post-processing for the EAHE RC study.

This script does not rerun the MATLAB model. It reads the existing current
result files, creates a concise set of publication-style figures, writes a
figure-selection table, and adds a simple analytical-model comparison.
"""

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import scipy.io as sio
from scipy.interpolate import griddata


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "paper_figures"
TABLES = ROOT / "paper_tables"
REVISION = "soil_phase_offset_v2"


def loadmat(name: str) -> dict:
    return sio.loadmat(ROOT / name, squeeze_me=True, struct_as_record=False)


def arr(x):
    return np.asarray(x).squeeze()


def cases(obj):
    if isinstance(obj, np.ndarray):
        return [obj.flat[i] for i in range(obj.size)]
    return [obj]


def revision(result) -> str:
    try:
        return str(result.param.model_revision)
    except Exception:
        return "<unknown>"


def require_current(result, name: str):
    rev = revision(result)
    if rev != REVISION:
        raise RuntimeError(f"{name} revision is {rev}; expected {REVISION}")


def setup_style():
    plt.rcParams.update(
        {
            "font.family": "Arial",
            "font.size": 8.5,
            "axes.labelsize": 9,
            "axes.titlesize": 9.5,
            "legend.fontsize": 8,
            "xtick.labelsize": 8,
            "ytick.labelsize": 8,
            "axes.linewidth": 0.8,
            "lines.linewidth": 1.35,
            "figure.dpi": 130,
            "savefig.dpi": 600,
            "savefig.bbox": "tight",
        }
    )


def save(name: str):
    OUT.mkdir(exist_ok=True)
    plt.savefig(OUT / f"{name}.png")
    plt.savefig(OUT / f"{name}.pdf")
    plt.close()


def profile_at(t, soil_pre, param):
    tq = (t + float(param.soil_time_offset)) % float(param.year)
    tt = arr(soil_pre.time)
    TT = np.asarray(soil_pre.T)
    if tt[-1] < float(param.year):
        tt = np.r_[tt, float(param.year)]
        TT = np.c_[TT, TT[:, 0]]
    return np.array([np.interp(tq, tt, TT[i, :]) for i in range(TT.shape[0])])


def idx_ts(i, m, r, param) -> int:
    return int((i - 1) * param.nNode_seg + 2 + (m - 1) * param.Nr + r - 1)


def analytical_tout(result):
    """Steady cylindrical-resistance analytical reference.

    The far-field soil temperature is the undisturbed temperature at pipe
    depth. This is a deliberately simple classical baseline, not a replacement
    for the transient RC network.
    """
    p = result.param
    t = arr(result.time)
    tin = arr(result.Tin)
    t_soil = arr(result.Tundist_pipe)

    r_i = float(p.r_i)
    r_o = float(p.r_o)
    d_i = float(p.D_i)
    length = float(p.L_pipe)
    mcp = float(p.m_dot) * float(p.cp_air)
    h_in = float(p.h_in)
    k_pipe = float(p.k_pipe)
    k_gap = float(p.k_gap_eff)
    delta_gap = float(p.delta_gap)
    r_gap = r_o + delta_gap
    k_soil = float(arr(p.k_soil)[1])
    r_far = min(float(p.r_soil_max), float(p.z_pipe))

    r_conv = 1.0 / (h_in * math.pi * d_i)
    r_pipe = math.log(r_o / r_i) / (2 * math.pi * k_pipe)
    r_gap_line = 0.0 if delta_gap <= 0 else math.log(r_gap / r_o) / (2 * math.pi * k_gap)
    r_soil = math.log(r_far / r_gap) / (2 * math.pi * k_soil)
    ual = 1.0 / (r_conv + r_pipe + r_gap_line + r_soil)
    ntu = ual * length / mcp
    tout = t_soil + (tin - t_soil) * np.exp(-ntu)
    q = mcp * (tin - tout)
    return tout, q, ntu


def figure_soil_phase(result):
    p = result.param
    z = arr(result.soil_pre.z)
    times_h = [0, 24, 72, 168]
    colors = ["#2b6cb0", "#2f855a", "#c05621", "#6b46c1"]

    fig, ax = plt.subplots(figsize=(3.4, 4.2))
    for th, c in zip(times_h, colors):
        ax.plot(profile_at(th * 3600, result.soil_pre, p), z, color=c, label=f"{th:g} h")
    ax.axhline(float(p.z_pipe), color="black", lw=0.9, label="pipe")
    for zb in arr(p.z_layer_bot)[:2]:
        ax.axhline(float(zb), color="0.45", ls="--", lw=0.8)
    ax.invert_yaxis()
    ax.set_xlabel("Undisturbed soil temperature / degC")
    ax.set_ylabel("Depth / m")
    ax.set_title("Layered-soil initial phase")
    ax.grid(True, alpha=0.25)
    ax.legend(frameon=False)
    save("Fig01_soil_phase_check")


def figure_baseline(result):
    t = arr(result.time) / 3600
    idx = np.arange(1, len(t))
    fig, axes = plt.subplots(2, 1, figsize=(5.6, 4.4), sharex=True)
    axes[0].plot(t[idx], arr(result.Tin)[idx], color="0.15", ls="--", label="Inlet")
    axes[0].plot(t[idx], arr(result.Tout)[idx], color="#1f77b4", label="Outlet")
    axes[0].set_ylabel("Air temperature / degC")
    axes[0].legend(frameon=False, ncol=2)
    axes[1].plot(t[idx], arr(result.Q)[idx], color="#d62728")
    axes[1].set_ylabel("Heat transfer / W")
    axes[1].set_xlabel("Time / h")
    for ax in axes:
        ax.grid(True, alpha=0.25)
    save("Fig02_baseline_transient")


def figure_degradation():
    data = loadmat("degradation_validation_result.mat")
    no_gap = data["case_no_gap"]
    gap = data["case_gap"]
    require_current(gap, "degradation_validation_result.mat")
    fig, ax = plt.subplots(figsize=(4.5, 3.3))
    ax.plot(arr(no_gap.degradation.day), arr(no_gap.degradation.eta_Q_day), "o-", color="#1f77b4", label="No gap")
    ax.plot(arr(gap.degradation.day), arr(gap.degradation.eta_Q_day), "s-", color="#d62728", label="Fixed gap")
    ax.set_xlabel("Operation day")
    ax.set_ylabel("Daily heat-transfer ratio")
    ax.set_ylim(0.65, 1.03)
    ax.grid(True, alpha=0.25)
    ax.legend(frameon=False)
    save("Fig03_heat_saturation_degradation")


def contour_panel(ax, result, snap_index: int):
    p = result.param
    g = result.geom
    Xmat = np.asarray(result.snapshots.X)
    if Xmat.ndim == 1:
        Xmat = Xmat[:, None]
    X = Xmat[:, snap_index]
    nx = int(p.Nx_pipe)
    mid = round(nx / 2)
    xs, zs, ts = [], [], []
    for m in range(1, int(p.Ntheta) + 1):
        theta = arr(g.theta)[m - 1]
        for r in range(1, int(p.Nr) + 1):
            rr = arr(g.r_centers)[r - 1]
            xs.append(rr * math.cos(theta))
            zs.append(float(p.z_pipe) + rr * math.sin(theta))
            ts.append(X[idx_ts(mid, m, r, p)])
    xs, zs, ts = map(np.asarray, (xs, zs, ts))
    rmax = float(p.r_soil_max)
    ro = float(p.r_o)
    zpipe = float(p.z_pipe)
    xq = np.linspace(-rmax, rmax, 220)
    zq = np.linspace(zpipe - rmax, zpipe + rmax, 220)
    Xq, Zq = np.meshgrid(xq, zq)
    Tq = griddata((xs, zs), ts, (Xq, Zq), method="cubic")
    if np.isnan(Tq).any():
        Tlin = griddata((xs, zs), ts, (Xq, Zq), method="linear")
        Tq = np.where(np.isnan(Tq), Tlin, Tq)
    Rq = np.sqrt(Xq**2 + (Zq - zpipe) ** 2)
    Tq[(Rq < ro) | (Rq > rmax) | (Zq < 0)] = np.nan
    cf = ax.contourf(Xq, Zq, Tq, 24, cmap="viridis")
    th = np.linspace(0, 2 * np.pi, 240)
    ax.plot(ro * np.cos(th), zpipe + ro * np.sin(th), color="black", lw=1.4)
    for zb in arr(p.z_layer_bot)[:2]:
        ax.axhline(float(zb), color="0.2", ls="--", lw=0.7)
    ax.set_aspect("equal")
    ax.set_xlabel("x / m")
    ax.set_title(f"t = {arr(result.snapshots.time)[snap_index] / 3600:.0f} h")
    return cf


def figure_contours():
    result = loadmat("temperature_field_fine_result.mat")["result"]
    require_current(result, "temperature_field_fine_result.mat")
    fig, axes = plt.subplots(1, 2, figsize=(6.4, 3.8), sharey=True)
    cf0 = contour_panel(axes[0], result, 0)
    cf1 = contour_panel(axes[1], result, -1)
    axes[0].invert_yaxis()
    axes[0].set_ylabel("Depth / m")
    cbar = fig.colorbar(cf1, ax=axes, shrink=0.82, pad=0.02)
    cbar.set_label("Soil temperature / degC")
    save("Fig04_temperature_field_contours")


def figure_sensitivity_summary():
    gap = pd.read_csv(ROOT / "gap_sensitivity_summary.csv")
    soil = pd.read_csv(ROOT / "soil_layer2_sensitivity_summary.csv")
    op_m = pd.read_csv(ROOT / "operation_mdot_summary.csv")
    op_l = pd.read_csv(ROOT / "operation_length_summary.csv")
    fig, axes = plt.subplots(2, 2, figsize=(6.6, 5.0))
    axes[0, 0].plot(gap["Gap_mm"], gap["Q_last_day_W"], "o-", color="#d62728")
    axes[0, 0].set_xlabel("Gap thickness / mm")
    axes[0, 0].set_ylabel("Last-day heat / W")
    axes[0, 1].plot(soil["k_soil2_W_mK"], soil["Q_last_day_W"], "o-", color="#2ca02c")
    axes[0, 1].set_xlabel("Layer-2 k / W m-1 K-1")
    axes[0, 1].set_ylabel("Last-day heat / W")
    axes[1, 0].plot(op_m["m_dot_kg_s"], op_m["Q_last_day_W"], "o-", color="#1f77b4")
    axes[1, 0].set_xlabel("Mass flow / kg s-1")
    axes[1, 0].set_ylabel("Last-day heat / W")
    axes[1, 1].plot(op_l["L_pipe_m"], op_l["Q_per_length_last_day_W_m"], "o-", color="#9467bd")
    axes[1, 1].set_xlabel("Pipe length / m")
    axes[1, 1].set_ylabel("Specific heat / W m-1")
    for ax in axes.ravel():
        ax.grid(True, alpha=0.25)
    save("Fig05_sensitivity_summary")


def figure_variable_gap():
    data = loadmat("variable_gap_extension_result.mat")
    fixed = data["fixed_case"]
    variable = data["variable_case"]
    require_current(fixed, "variable_gap_extension_result.mat")
    t = arr(fixed.time) / 3600
    idx = np.arange(1, len(t))
    fig, axes = plt.subplots(1, 2, figsize=(6.6, 2.8))
    axes[0].plot(t[idx], arr(fixed.Tout)[idx], color="#1f77b4", label="Fixed")
    axes[0].plot(t[idx], arr(variable.Tout)[idx], color="#d62728", ls="--", label="Variable")
    axes[0].set_xlabel("Time / h")
    axes[0].set_ylabel("Outlet temperature / degC")
    axes[0].legend(frameon=False)
    axes[1].plot(arr(variable.time) / 3600, arr(variable.Rgap_factor_mid_mean), color="#9467bd")
    axes[1].set_xlabel("Time / h")
    axes[1].set_ylabel("Rgap factor")
    for ax in axes:
        ax.grid(True, alpha=0.25)
    save("Fig06_variable_gap_extension")


def figure_analytical_comparison(result):
    tout_a, q_a, ntu = analytical_tout(result)
    t = arr(result.time) / 3600
    idx = np.arange(1, len(t))
    tout_rc = arr(result.Tout)
    q_rc = arr(result.Q)
    err = tout_a - tout_rc
    metrics = {
        "Analytical_NTU": ntu,
        "Tout_RMSE_K": float(np.sqrt(np.mean(err[idx] ** 2))),
        "Tout_MBE_K": float(np.mean(err[idx])),
        "Q_RMSE_W": float(np.sqrt(np.mean((q_a[idx] - q_rc[idx]) ** 2))),
    }
    pd.DataFrame([metrics]).to_csv(TABLES / "analytical_comparison_metrics.csv", index=False)

    fig, axes = plt.subplots(2, 1, figsize=(5.8, 4.4), sharex=True)
    axes[0].plot(t[idx], tout_rc[idx], color="#1f77b4", label="Transient RC")
    axes[0].plot(t[idx], tout_a[idx], color="#d62728", ls="--", label="Analytical")
    axes[0].set_ylabel("Outlet temperature / degC")
    axes[0].legend(frameon=False, ncol=2)
    axes[1].plot(t[idx], err[idx], color="0.25")
    axes[1].axhline(0, color="0.5", lw=0.8)
    axes[1].set_ylabel("Analytical - RC / K")
    axes[1].set_xlabel("Time / h")
    for ax in axes:
        ax.grid(True, alpha=0.25)
    save("Fig07_analytical_model_comparison")


def write_figure_selection():
    rows = [
        ("Fig01", "Soil phase check", "Main or SI", "Shows summer-phase layered initial soil temperature; use in method validation or SI."),
        ("Fig02", "Baseline transient", "Main", "Shows inlet, outlet and heat-transfer response."),
        ("Fig03", "Heat-saturation degradation", "Main", "Directly supports transient degradation and gap resistance discussion."),
        ("Fig04", "Temperature contours", "Main", "Use two-panel 0 h / 168 h figure after contour audit."),
        ("Fig05", "Sensitivity summary", "Main", "Compresses gap, soil, flow and length effects into one figure."),
        ("Fig06", "Variable gap extension", "SI or final section", "Use if variable gap resistance remains part of the final model scope."),
        ("Fig07", "Analytical comparison", "Main validation", "Shows improvement over simple steady analytical model."),
        ("Full time-series sweeps", "Existing figures/*", "SI", "Keep full case curves in supplementary material."),
    ]
    df = pd.DataFrame(rows, columns=["Figure", "Content", "RecommendedUse", "Reason"])
    df.to_csv(TABLES / "paper_figure_selection.csv", index=False)


def main():
    setup_style()
    OUT.mkdir(exist_ok=True)
    TABLES.mkdir(exist_ok=True)
    for old in OUT.glob("*.*"):
        if old.suffix.lower() in {".png", ".pdf"}:
            old.unlink()

    baseline = loadmat("baseline_result.mat")["result"]
    require_current(baseline, "baseline_result.mat")

    figure_soil_phase(baseline)
    figure_baseline(baseline)
    figure_degradation()
    figure_contours()
    figure_sensitivity_summary()
    figure_variable_gap()
    figure_analytical_comparison(baseline)
    write_figure_selection()

    print(f"Paper figures written to {OUT}")
    print(f"Paper tables written to {TABLES}")


if __name__ == "__main__":
    main()
