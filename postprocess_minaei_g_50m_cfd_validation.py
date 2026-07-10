from __future__ import print_function

import math
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import special
from scipy.sparse import lil_matrix
from scipy.sparse.linalg import factorized


ROOT = r"G:\codexproject"
OUT_DIR = os.path.join(ROOT, "MinaeiG_validation_and_50m_CFD_results")


def ensure_dir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def sharan_params():
    p = {}
    p["L"] = 50.0
    p["Nx"] = 80
    p["rpi"] = 0.050
    p["rpo"] = 0.053
    p["kp"] = 45.0
    p["rho_p"] = 7850.0
    p["cp_p"] = 470.0
    p["rho_f"] = 0.0975 / 0.0863
    p["cp_f"] = 1006.0
    p["k_air"] = 0.026
    p["mu_f"] = 1.85e-5
    p["Vdot"] = 0.0863
    p["mdot"] = 0.0975
    p["ks"] = 1.50
    p["rho_s"] = 1800.0
    p["cp_s"] = 1200.0
    p["alpha_s"] = p["ks"] / (p["rho_s"] * p["cp_s"])
    p["dt"] = 600.0
    p["picard_max"] = 12
    p["picard_tol"] = 1e-5
    p["picard_relax"] = 0.65
    p["g_quad_n"] = 900
    p["g_quad_bmax"] = 160.0
    p["soil_response_scale"] = 1.0
    return p


def internal_h(p):
    d = 2.0 * p["rpi"]
    area = math.pi * p["rpi"] ** 2
    velocity = p["Vdot"] / area
    re = p["rho_f"] * velocity * d / p["mu_f"]
    pr = p["cp_f"] * p["mu_f"] / p["k_air"]
    if re < 2300.0:
        nu = 3.66
    else:
        f = (0.79 * math.log(re) - 1.64) ** (-2.0)
        nu = ((f / 8.0) * (re - 1000.0) * pr) / (
            1.0 + 12.7 * math.sqrt(f / 8.0) * (pr ** (2.0 / 3.0) - 1.0)
        )
    return nu * p["k_air"] / d


def radial_network(p, delta_m, literature=False):
    hi = internal_h(p)
    re = math.sqrt((p["rpi"] ** 2 + p["rpo"] ** 2) / 2.0)
    r_response = p["rpo"] + max(delta_m, 0.0)
    rconv = 1.0 / (2.0 * math.pi * p["rpi"] * hi)
    rcond_inner = math.log(re / p["rpi"]) / (2.0 * math.pi * p["kp"])
    rp1 = rconv + rcond_inner
    rp2 = math.log(p["rpo"] / re) / (2.0 * math.pi * p["kp"])
    if literature or delta_m <= 0.0:
        rdelta = rp2
        rgap = 0.0
        r_response = p["rpo"]
    else:
        rgap = math.log(r_response / p["rpo"]) / (2.0 * math.pi * p["k_air"])
        rdelta = rp2 + rgap
    return rp1, rdelta, r_response, rgap


def minaei_g_kernel(p, r, nt):
    beta = np.logspace(-6.0, math.log10(p["g_quad_bmax"]), int(p["g_quad_n"]))
    j1 = special.j1(beta)
    y1 = special.y1(beta)
    den = beta ** 2 * (j1 ** 2 + y1 ** 2)
    shape = -2.0 / (math.pi * beta)
    g = np.zeros(nt)
    for k in range(nt):
        tau = k * p["dt"]
        if tau <= 0.0:
            tau = 0.5 * p["dt"]
        fo = p["alpha_s"] * tau / (r ** 2)
        integrand = (np.exp(-(beta ** 2) * fo) - 1.0) * shape / den
        integrand[~np.isfinite(integrand)] = 0.0
        g[k] = max(np.trapz(integrand, beta) / (math.pi ** 2), 0.0)
    return g


def factor_air_pipe_matrix(p, rp1, rdelta):
    nx = int(p["Nx"])
    dx = p["L"] / nx
    dt = p["dt"]
    cf = p["rho_f"] * math.pi * p["rpi"] ** 2 * p["cp_f"]
    cp = p["rho_p"] * math.pi * (p["rpo"] ** 2 - p["rpi"] ** 2) * p["cp_p"]
    adv = p["mdot"] * p["cp_f"] / dx
    a = lil_matrix((2 * nx, 2 * nx))
    for i in range(nx):
        row = i
        a[row, i] = cf / dt + adv + 1.0 / rp1
        a[row, nx + i] = -1.0 / rp1
        if i > 0:
            a[row, i - 1] = -adv
        row = nx + i
        a[row, nx + i] = cp / dt + 1.0 / rp1 + 1.0 / rdelta
        a[row, i] = -1.0 / rp1
    return factorized(a.tocsc())


def soil_boundary_temperature(p, q_hist, q_trial, m, g_lag, th_now):
    q_local = q_hist[:, : m + 1].copy()
    q_local[:, m] = q_trial
    dq = np.zeros_like(q_local)
    dq[:, 0] = q_local[:, 0]
    dq[:, 1:] = q_local[:, 1:] - q_local[:, :-1]
    weights = g_lag[m::-1]
    tdist = p["soil_response_scale"] * dq.dot(weights) / p["ks"]
    return th_now + tdist


def simulate_case(p, time_s, tin_c, soil_c, delta_m=0.0, literature=False):
    t_end = float(time_s[-1])
    nt = int(round(t_end / p["dt"])) + 1
    t = np.arange(nt) * p["dt"]
    tin = np.interp(t, time_s, tin_c)
    th = np.interp(t, time_s, soil_c)

    nx = int(p["Nx"])
    dx = p["L"] / nx
    rp1, rdelta, r_response, _ = radial_network(p, delta_m, literature)
    solve = factor_air_pipe_matrix(p, rp1, rdelta)
    g_lag = minaei_g_kernel(p, r_response, nt)

    tf = np.zeros((nx, nt))
    tp = np.zeros((nx, nt))
    tg = np.zeros((nx, nt))
    qg = np.zeros((nx, nt))
    tf[:, 0] = th[0]
    tp[:, 0] = th[0]
    tg[:, 0] = th[0]

    cf = p["rho_f"] * math.pi * p["rpi"] ** 2 * p["cp_f"]
    cp = p["rho_p"] * math.pi * (p["rpo"] ** 2 - p["rpi"] ** 2) * p["cp_p"]
    adv = p["mdot"] * p["cp_f"] / dx
    for m in range(1, nt):
        q_trial = qg[:, m - 1].copy()
        for _ in range(p["picard_max"]):
            tg_now = soil_boundary_temperature(p, qg, q_trial, m, g_lag, th[m])
            b = np.zeros(2 * nx)
            b[:nx] = cf / p["dt"] * tf[:, m - 1]
            b[0] += adv * tin[m]
            b[nx:] = cp / p["dt"] * tp[:, m - 1] + tg_now / rdelta
            x = solve(b)
            tp_new = x[nx:]
            q_new = (tp_new - tg_now) / rdelta
            rel = np.linalg.norm(q_new - q_trial) / max(np.linalg.norm(q_new), 1.0)
            q_trial = p["picard_relax"] * q_new + (1.0 - p["picard_relax"]) * q_trial
            if rel < p["picard_tol"]:
                break
        tg[:, m] = soil_boundary_temperature(p, qg, q_trial, m, g_lag, th[m])
        b = np.zeros(2 * nx)
        b[:nx] = cf / p["dt"] * tf[:, m - 1]
        b[0] += adv * tin[m]
        b[nx:] = cp / p["dt"] * tp[:, m - 1] + tg[:, m] / rdelta
        x = solve(b)
        tf[:, m] = x[:nx]
        tp[:, m] = x[nx:]
        qg[:, m] = (tp[:, m] - tg[:, m]) / rdelta

    z = (np.arange(nx) + 0.5) * dx
    t25 = np.array([np.interp(25.0, z, tf[:, j]) for j in range(nt)])
    tout = tf[-1, :]
    qair = p["mdot"] * p["cp_f"] * (tin - tout)
    return {"t": t, "Tin": tin, "Tsoil": th, "T25": t25, "Tout": tout, "Qair": qair}


def metrics(err):
    err = np.asarray(err)
    err = err[np.isfinite(err)]
    return {
        "RMSE_C": math.sqrt(float(np.mean(err ** 2))),
        "MAE_C": float(np.mean(np.abs(err))),
        "Bias_C": float(np.mean(err)),
        "MaxAbs_C": float(np.max(np.abs(err))),
    }


def plot_case(case_df, model_df, case_name, out_dir):
    safe = case_name.replace("Sharan_", "")
    xh = case_df["t_day"].values * 24.0
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))
    for ax, quantity, cfd_col, model_col, exp_col in [
        (axes[0], "T25", "Tmid_sim_C", "MinaeiG_T25_C", "Tmid_exp_C"),
        (axes[1], "Tout", "Tout_sim_C", "MinaeiG_Tout_C", "Tout_exp_C"),
    ]:
        ax.plot(xh, case_df[cfd_col], "o-", label="SST CFD")
        ax.plot(xh, model_df[model_col], "s--", label="Minaei-G RC")
        if exp_col in case_df:
            ax.plot(xh, case_df[exp_col], "k:", label="experiment")
        ax.set_xlabel("time / h")
        ax.set_ylabel(quantity + " / degC")
        ax.set_title(case_name.replace("_", " ") + " " + quantity)
        ax.grid(True, alpha=0.3)
        ax.legend()
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, "Fig_50m_CFD_compare_%s.png" % safe), dpi=240)
    fig.savefig(os.path.join(out_dir, "Fig_50m_CFD_compare_%s.pdf" % safe))
    plt.close(fig)


def run_50m_cfd_comparison(out_dir):
    points_path = os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_validation_all_points.csv")
    points = pd.read_csv(points_path)
    p0 = sharan_params()
    rows = []
    metric_rows = []
    energy_rows = []

    for case_name, grp in points.groupby("case_name"):
        grp = grp.sort_values("t_day").reset_index(drop=True)
        time_s = grp["t_day"].values * 86400.0
        tin = grp["Tin_exp_C"].values
        if "May" in case_name:
            soil = np.linspace(26.6, 26.5, len(time_s))
        else:
            soil = np.ones(len(time_s)) * 24.2
        sim = simulate_case(p0, time_s, tin, soil, delta_m=0.0, literature=True)
        t25_model = np.interp(time_s, sim["t"], sim["T25"])
        tout_model = np.interp(time_s, sim["t"], sim["Tout"])

        model_df = pd.DataFrame({
            "case_name": case_name,
            "t_day": grp["t_day"].values,
            "MinaeiG_T25_C": t25_model,
            "MinaeiG_Tout_C": tout_model,
            "CFD_T25_C": grp["Tmid_sim_C"].values,
            "CFD_Tout_C": grp["Tout_sim_C"].values,
            "Exp_T25_C": grp["Tmid_exp_C"].values,
            "Exp_Tout_C": grp["Tout_exp_C"].values,
            "MinaeiG_minus_CFD_T25_C": t25_model - grp["Tmid_sim_C"].values,
            "MinaeiG_minus_CFD_Tout_C": tout_model - grp["Tout_sim_C"].values,
        })
        rows.append(model_df)
        for quantity, err in [
            ("T25", model_df["MinaeiG_minus_CFD_T25_C"].values),
            ("Tout", model_df["MinaeiG_minus_CFD_Tout_C"].values),
        ]:
            m = metrics(err)
            m["case_name"] = case_name
            m["quantity"] = quantity
            metric_rows.append(m)

        q_cfd = p0["mdot"] * p0["cp_f"] * (tin - grp["Tout_sim_C"].values)
        q_model = p0["mdot"] * p0["cp_f"] * (tin - tout_model)
        e_cfd = np.trapz(np.abs(q_cfd), time_s) / 3.6e6
        e_model = np.trapz(np.abs(q_model), time_s) / 3.6e6
        energy_rows.append({
            "case_name": case_name,
            "CFD_abs_energy_kWh": e_cfd,
            "MinaeiG_abs_energy_kWh": e_model,
            "MinaeiG_minus_CFD_kWh": e_model - e_cfd,
            "relative_error_percent": 100.0 * (e_model - e_cfd) / max(e_cfd, 1e-12),
        })
        plot_case(grp, model_df, case_name, out_dir)

    all_points = pd.concat(rows, ignore_index=True)
    metric_df = pd.DataFrame(metric_rows)
    metric_df = metric_df[["case_name", "quantity", "RMSE_C", "MAE_C", "Bias_C", "MaxAbs_C"]]
    energy_df = pd.DataFrame(energy_rows)
    all_points.to_csv(os.path.join(out_dir, "MinaeiG_50m_CFD_comparison_points.csv"), index=False)
    metric_df.to_csv(os.path.join(out_dir, "MinaeiG_50m_CFD_comparison_metrics.csv"), index=False)
    energy_df.to_csv(os.path.join(out_dir, "MinaeiG_50m_CFD_energy_comparison.csv"), index=False)

    fig, ax = plt.subplots(figsize=(8.2, 4.4))
    x = np.arange(len(metric_df))
    ax.bar(x, metric_df["RMSE_C"].values)
    ax.set_xticks(x)
    ax.set_xticklabels(metric_df["case_name"].str.replace("Sharan_", "") + "\n" + metric_df["quantity"], rotation=0)
    ax.set_ylabel("RMSE / degC")
    ax.set_title("Minaei-G RC vs 50 m SST CFD")
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, "Fig_50m_CFD_RMSE_summary.png"), dpi=240)
    fig.savefig(os.path.join(out_dir, "Fig_50m_CFD_RMSE_summary.pdf"))
    plt.close(fig)
    return all_points, metric_df, energy_df


def run_independence_studies(out_dir):
    points = pd.read_csv(os.path.join(ROOT, "COMSOL_Sharan_50m_CFD_validation_all_points.csv"))
    grp = points[points["case_name"] == "Sharan_May_cooling"].sort_values("t_day").reset_index(drop=True)
    time_s = grp["t_day"].values * 86400.0
    tin = grp["Tin_exp_C"].values
    soil = np.linspace(26.6, 26.5, len(time_s))

    nx_values = [25, 50, 80, 120]
    nx_ref = None
    nx_rows = []
    sims = {}
    for nx in nx_values:
        p = sharan_params()
        p["Nx"] = nx
        p["dt"] = 600.0
        sim = simulate_case(p, time_s, tin, soil, literature=True)
        sims[nx] = sim
        if nx == 120:
            nx_ref = sim
    ref_tout = np.interp(time_s, nx_ref["t"], nx_ref["Tout"])
    for nx in nx_values:
        tout = np.interp(time_s, sims[nx]["t"], sims[nx]["Tout"])
        err = tout - ref_tout
        nx_rows.append({"Nx": nx, "Tout_RMSE_vs_Nx120_C": metrics(err)["RMSE_C"]})
    nx_df = pd.DataFrame(nx_rows)
    nx_df.to_csv(os.path.join(out_dir, "MinaeiG_validation_Nx_independence.csv"), index=False)

    dt_values = [1800.0, 1200.0, 600.0, 300.0]
    dt_ref = None
    dt_sims = {}
    for dt in dt_values:
        p = sharan_params()
        p["Nx"] = 80
        p["dt"] = dt
        sim = simulate_case(p, time_s, tin, soil, literature=True)
        dt_sims[dt] = sim
        if dt == 300.0:
            dt_ref = sim
    ref_tout = np.interp(time_s, dt_ref["t"], dt_ref["Tout"])
    dt_rows = []
    for dt in dt_values:
        tout = np.interp(time_s, dt_sims[dt]["t"], dt_sims[dt]["Tout"])
        err = tout - ref_tout
        dt_rows.append({"dt_s": dt, "dt_h": dt / 3600.0, "Tout_RMSE_vs_dt300_C": metrics(err)["RMSE_C"]})
    dt_df = pd.DataFrame(dt_rows)
    dt_df.to_csv(os.path.join(out_dir, "MinaeiG_validation_dt_independence.csv"), index=False)

    fig, axes = plt.subplots(1, 2, figsize=(10, 4.0))
    axes[0].plot(nx_df["Nx"], nx_df["Tout_RMSE_vs_Nx120_C"], "o-", lw=1.5)
    axes[0].set_xlabel("axial segments Nx")
    axes[0].set_ylabel("Tout RMSE vs Nx=120 / degC")
    axes[0].set_title("Spatial-segment independence")
    axes[0].grid(True, alpha=0.3)
    axes[1].plot(dt_df["dt_h"], dt_df["Tout_RMSE_vs_dt300_C"], "s-", lw=1.5)
    axes[1].invert_xaxis()
    axes[1].set_xlabel("time step / h")
    axes[1].set_ylabel("Tout RMSE vs dt=300 s / degC")
    axes[1].set_title("Time-step independence")
    axes[1].grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, "Fig_MinaeiG_Nx_dt_independence.png"), dpi=240)
    fig.savefig(os.path.join(out_dir, "Fig_MinaeiG_Nx_dt_independence.pdf"))
    plt.close(fig)
    return nx_df, dt_df


def write_summary(out_dir, metrics_df, energy_df, nx_df, dt_df):
    def markdown_table(df):
        cols = list(df.columns)
        lines = []
        lines.append("| " + " | ".join(cols) + " |")
        lines.append("| " + " | ".join(["---"] * len(cols)) + " |")
        for _, row in df.iterrows():
            vals = []
            for c in cols:
                v = row[c]
                if isinstance(v, float):
                    vals.append("%.6g" % v)
                else:
                    vals.append(str(v))
            lines.append("| " + " | ".join(vals) + " |")
        return "\n".join(lines)

    md_path = os.path.join(out_dir, "MinaeiG_validation_summary.md")
    with open(md_path, "w") as f:
        f.write("# Minaei-G improved model validation summary\n\n")
        f.write("The post-processing uses only the Minaei et al. Eq. (9) G-function response kernel. ")
        f.write("No ILS or FLS response kernels are evaluated in this validation script.\n\n")
        f.write("## 50 m SST CFD comparison\n\n")
        f.write(markdown_table(metrics_df))
        f.write("\n\n## Energy comparison\n\n")
        f.write(markdown_table(energy_df))
        f.write("\n\n## Independence checks\n\n")
        f.write("Spatial segment check:\n\n")
        f.write(markdown_table(nx_df))
        f.write("\n\nTime-step check:\n\n")
        f.write(markdown_table(dt_df))
        f.write("\n")


def main():
    ensure_dir(OUT_DIR)
    _, metric_df, energy_df = run_50m_cfd_comparison(OUT_DIR)
    nx_df, dt_df = run_independence_studies(OUT_DIR)
    write_summary(OUT_DIR, metric_df, energy_df, nx_df, dt_df)
    print("Wrote Minaei-G validation outputs to %s" % OUT_DIR)


if __name__ == "__main__":
    main()
