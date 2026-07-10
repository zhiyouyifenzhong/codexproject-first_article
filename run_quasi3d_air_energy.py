import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(r"G:\codexproject")
FIG_DIR = ROOT / "paper_figures"
TABLE_DIR = ROOT / "paper_tables"


def read_parameter_table():
    params = {}
    with (TABLE_DIR / "eahe_cfd_heat_moisture_parameters.csv").open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                params[row["Symbol"]] = float(row["DefaultValue"])
            except ValueError:
                params[row["Symbol"]] = row["DefaultValue"]
    return params


def run_model():
    p = read_parameter_table()

    L_pipe = p["L_pipe"]
    r_i = p["r_i"]
    r_o = p["r_o"]
    m_dot = p["m_dot"]
    cp_a = p["cp_a"]
    rho_a = p["rho_a"]
    mu_a = p["mu_a"]
    k_a = p["k_a"]
    k_pipe = p["k_pipe"]
    R_int = 0.040  # m2 K/W, same fixed interface resistance as dry 2D baseline.
    k_soil = p["k_sat_2"]
    rho_cp_soil = p["rho_s_2"] * p["cp_s_2"] + p["theta0_2"] * p["rho_w"] * p["cp_w"]

    Tin_mean = p["Tin_mean"]
    Tin_amp = p["Tin_amp"]
    T_far = p["T_deep"]

    nx = 80
    dt = 300.0
    t_end = 7 * 24 * 3600.0
    nt = int(t_end / dt) + 1
    dx = L_pipe / nx
    x = np.linspace(dx / 2, L_pipe - dx / 2, nx)
    time = np.arange(nt) * dt

    area_air = np.pi * r_i ** 2
    u_air = m_dot / (rho_a * area_air)
    re_air = rho_a * u_air * (2 * r_i) / mu_a
    pr_air = cp_a * mu_a / k_a
    nu_air = 0.023 * re_air ** 0.8 * pr_air ** 0.4
    h_i = nu_air * k_a / (2 * r_i)

    r_buffer = 0.50
    r_far = 1.50
    r_conv_i_area_o = r_o / (r_i * h_i)
    r_wall_area_o = r_o * np.log(r_o / r_i) / k_pipe
    r_total_area_o = r_conv_i_area_o + r_wall_area_o + R_int
    r_air_per_length = r_total_area_o / (2 * np.pi * r_o)
    r_air_seg = r_air_per_length / dx

    r_far_per_length = np.log(r_far / r_buffer) / (2 * np.pi * k_soil)
    r_far_seg = r_far_per_length / dx
    c_soil_seg = rho_cp_soil * np.pi * (r_buffer ** 2 - r_o ** 2) * dx

    T_soil = np.full(nx, T_far, dtype=float)
    Tout = np.zeros(nt)
    Tin = np.zeros(nt)
    Q_total = np.zeros(nt)
    near_soil_mean = np.zeros(nt)
    eta_day = np.full(7, np.nan)

    profile_times_h = [0, 24, 72, 168]
    profiles = {}

    for n, t in enumerate(time):
        Tin_t = Tin_mean + Tin_amp * np.sin(2 * np.pi * t / (24 * 3600.0))
        Tin[n] = Tin_t

        T_air = Tin_t
        q_seg = np.zeros(nx)
        for j in range(nx):
            # Exact outlet solution for a segment with locally uniform soil temperature.
            eps = np.exp(-dx / (m_dot * cp_a * r_air_per_length))
            T_next = T_soil[j] + (T_air - T_soil[j]) * eps
            q_seg[j] = m_dot * cp_a * (T_air - T_next)
            T_air = T_next

        # Implicit soil storage and far-field recovery using the heat rate just computed.
        T_soil = (c_soil_seg / dt * T_soil + q_seg + T_far / r_far_seg) / (
            c_soil_seg / dt + 1.0 / r_far_seg
        )

        Tout[n] = T_air
        Q_total[n] = np.sum(q_seg)
        near_soil_mean[n] = np.mean(T_soil)

        h = round(t / 3600.0)
        if h in profile_times_h and h not in profiles:
            profiles[h] = T_soil.copy()

    for day in range(7):
        start = int(day * 24 * 3600 / dt)
        stop = int((day + 1) * 24 * 3600 / dt)
        if day == 0:
            q_day1 = np.mean(Q_total[start:stop])
        eta_day[day] = np.mean(Q_total[start:stop]) / q_day1

    return {
        "x": x,
        "time": time,
        "Tin": Tin,
        "Tout": Tout,
        "Q_total": Q_total,
        "T_soil": T_soil,
        "near_soil_mean": near_soil_mean,
        "eta_day": eta_day,
        "profiles": profiles,
        "params": {
            "Re_air": re_air,
            "Pr_air": pr_air,
            "Nu_air": nu_air,
            "h_i": h_i,
            "R_total_area_o": r_total_area_o,
            "R_air_per_length": r_air_per_length,
            "R_far_seg": r_far_seg,
            "C_soil_seg": c_soil_seg,
            "rho_cp_soil": rho_cp_soil,
            "nx": nx,
            "dt": dt,
        },
    }


def export_results(result):
    FIG_DIR.mkdir(exist_ok=True)
    TABLE_DIR.mkdir(exist_ok=True)

    time_h = result["time"] / 3600.0
    days = np.arange(1, 8)

    fig, axs = plt.subplots(2, 1, figsize=(8.0, 6.2), dpi=220, sharex=True)
    axs[0].plot(time_h, result["Tin"], "k--", lw=1.3, label="Inlet air")
    axs[0].plot(time_h, result["Tout"], color="#1f77b4", lw=1.8, label="Outlet air")
    axs[0].set_ylabel("Temperature / degC")
    axs[0].grid(True, alpha=0.25)
    axs[0].legend(frameon=False, ncol=2)

    axs[1].plot(time_h, result["Q_total"], color="#d62728", lw=1.5)
    axs[1].set_xlabel("Time / h")
    axs[1].set_ylabel("Heat transfer rate / W")
    axs[1].grid(True, alpha=0.25)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "Fig12_quasi3d_air_energy_transient.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.0, 4.5), dpi=220)
    for h, profile in sorted(result["profiles"].items()):
        ax.plot(result["x"], profile, lw=1.8, label=f"{h} h")
    ax.set_xlabel("Pipe axial coordinate / m")
    ax.set_ylabel("Segment soil temperature / degC")
    ax.grid(True, alpha=0.25)
    ax.legend(frameon=False, ncol=2)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "Fig13_quasi3d_soil_axial_profiles.png")
    plt.close(fig)

    fig, ax1 = plt.subplots(figsize=(6.8, 4.4), dpi=220)
    ax1.plot(days, result["eta_day"], "o-", color="#1f77b4", lw=1.8)
    ax1.set_xlabel("Operation day")
    ax1.set_ylabel("Daily mean Q / day-1 value")
    ax1.set_ylim(0.75, 1.03)
    ax1.grid(True, alpha=0.25)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "Fig14_quasi3d_degradation.png")
    plt.close(fig)

    with (TABLE_DIR / "quasi3d_air_energy_timeseries.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["time_h", "Tin_degC", "Tout_degC", "Q_W", "near_soil_mean_degC"])
        stride = max(1, int(3600 / result["params"]["dt"]))
        for i in range(0, len(result["time"]), stride):
            writer.writerow([
                result["time"][i] / 3600.0,
                result["Tin"][i],
                result["Tout"][i],
                result["Q_total"][i],
                result["near_soil_mean"][i],
            ])

    with (TABLE_DIR / "quasi3d_air_energy_summary.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Metric", "Value", "Unit", "Note"])
        for key, value in result["params"].items():
            writer.writerow([key, value, "", "Model parameter"])
        writer.writerow(["Tout_final", result["Tout"][-1], "degC", "Final outlet air temperature"])
        writer.writerow(["Q_day1_mean", np.mean(result["Q_total"][: int(24 * 3600 / result["params"]["dt"])]), "W", "First-day mean heat transfer"])
        writer.writerow(["Q_day7_mean", np.mean(result["Q_total"][-int(24 * 3600 / result["params"]["dt"]):]), "W", "Last-day mean heat transfer"])
        writer.writerow(["eta_day7", result["eta_day"][-1], "1", "Last-day heat-transfer degradation ratio"])
        writer.writerow(["soil_mean_final", result["near_soil_mean"][-1], "degC", "Final mean segment soil temperature"])


if __name__ == "__main__":
    result = run_model()
    export_results(result)
    print("Wrote quasi-3D air-energy results.")
