# Annual k-epsilon CFD Results

## Run Description

The annual CFD sweep was re-run with the GUI-validated turbulence route:

```text
Turbulent flow model: k-epsilon
Wall treatment: wall functions
Output step: 1 day
Annual duration: 365 days
Gap cases: 0, 1, 5 mm
Output directory: COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon
```

This run is separate from the older annual SST CFD run.

## Annual CFD Heat Exchange

```text
delta = 0 mm:
  Ecool = 1070.244 kWh
  Eheat = 708.213 kWh
  Eabs  = 1778.457 kWh
  Dgap  = 0.000 %

delta = 1 mm:
  Ecool = 961.186 kWh
  Eheat = 632.707 kWh
  Eabs  = 1593.892 kWh
  Dgap  = 10.378 %

delta = 5 mm:
  Ecool = 678.534 kWh
  Eheat = 449.142 kWh
  Eabs  = 1127.676 kWh
  Dgap  = 36.592 %
```

## Annual Outlet Temperature

```text
delta = 0 mm:
  Tout_mean = 19.666 C
  Tout_min  = 18.000 C
  Tout_max  = 21.391 C

delta = 1 mm:
  Tout_mean = 19.731 C
  Tout_min  = 17.881 C
  Tout_max  = 21.601 C

delta = 5 mm:
  Tout_mean = 19.920 C
  Tout_min  = 17.223 C
  Tout_max  = 22.565 C
```

## Global Effective Heat-Transfer Coefficient

The stable postprocessed quantity is the global effective coefficient from the
time-series file, not the local h profile. The local h profile can become
singular when the local bulk-wall temperature difference is very small.

```text
delta = 0 mm:
  h_eq_mean   = 20.463 W/(m2 K)
  h_eq_median = 20.233 W/(m2 K)

delta = 1 mm:
  h_eq_mean   = 21.395 W/(m2 K)
  h_eq_median = 21.247 W/(m2 K)

delta = 5 mm:
  h_eq_mean   = 23.492 W/(m2 K)
  h_eq_median = 23.421 W/(m2 K)
```

## Comparison with Minaei-G Annual Model

```text
delta = 0 mm:
  CFD Eabs = 1778.457 kWh
  Minaei-G Eabs = 1778.928 kWh
  difference = -0.026 %

delta = 1 mm:
  CFD Eabs = 1593.892 kWh
  Minaei-G Eabs = 1600.347 kWh
  difference = -0.403 %

delta = 5 mm:
  CFD Eabs = 1127.676 kWh
  Minaei-G Eabs = 1146.928 kWh
  difference = -1.679 %
```

The annual energy agreement is very good. The corrected annual CFD supports the
Minaei-G reduced model trend and magnitude.

## Key Files

```text
COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon/
  COMSOL_annual_energy_summary.csv
  COMSOL_annual_Tout_stats.csv
  COMSOL_annual_global_h_eq_stats.csv
  COMSOL_annual_kepsilon_vs_MinaeiG_comparison.csv
  COMSOL_Tout_delta_sweep.csv
  COMSOL_Q_delta_sweep.csv
  COMSOL_case_resistance_gap_delta_0mm_20260706_215541.mph
  COMSOL_case_resistance_gap_delta_1mm_20260706_215541.mph
  COMSOL_case_resistance_gap_delta_5mm_20260706_215541.mph
```

Figures:

```text
COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon/annual_figures/
  Fig_annual_kepsilon_CFD_energy.png
  Fig_annual_kepsilon_CFD_Tout.png
  Fig_annual_kepsilon_CFD_vs_MinaeiG_error.png
  Fig_annual_kepsilon_CFD_h_eq.png
```
