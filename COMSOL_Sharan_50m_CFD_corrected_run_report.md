# Corrected Sharan 50 m SST CFD Run Report

## Generated model and data

Corrected runner:

```text
G:\codexproject\run_comsol_sharan_50m_cfd_corrected.m
```

The run uses Sharan 50 m parameters, SST turbulence, no air gap, and mass-flow weighted validation temperatures. Solved COMSOL models were preserved:

```text
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_May_cooling\COMSOL_case_resistance_gap_delta_0mm_20260706_161526.mph
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_January_heating\COMSOL_case_resistance_gap_delta_0mm_20260706_161910.mph
```

Built-only model files were also saved in the same folders.

Primary data files:

```text
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_all_points.csv
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_metrics.csv
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_energy.csv
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_vs_MinaeiG_metrics.csv
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_summary.xlsx
```

Figures:

```text
G:\codexproject\COMSOL_Sharan_50m_CFD_corrected_comparison_figures
```

## Model settings

Sharan parameters:

| Parameter | Value |
|---|---:|
| Pipe length | 50 m |
| Inner radius | 0.050 m |
| Outer radius | 0.053 m |
| Soil radius | 2.0 m |
| Volume flow rate | 0.0863 m3/s |
| Mass flow rate | 0.0975 kg/s |
| Air density | 1.1298 kg/m3 |
| Mean velocity | 10.99 m/s |
| Reynolds number | about 6.7e4 |
| Turbulence model | SST |
| Turbulence intensity | 5% |
| Turbulent length scale | 0.07D |
| Pipe material | mild steel, k = 45 W/(m K) |
| Soil conductivity | 1.5 W/(m K) |

Corrections relative to the previous run:

- `Tout` and `T25` are computed by mass-flow weighted radial sampling.
- Area-mean `Tout_area_mean_C` is retained only as a diagnostic column.
- Time step changed from 600 s to 300 s.
- Air radial mesh and boundary layer resolution were increased.
- Solved `.mph` files are saved for COMSOL inspection.

## Corrected CFD validation against experiment

| Case | Quantity | RMSE (C) | Bias (C) |
|---|---|---:|---:|
| May cooling | T25 | 6.336 | 5.360 |
| May cooling | Tout | 7.571 | 6.915 |
| January heating | T25 | 8.327 | -7.679 |
| January heating | Tout | 8.592 | -8.033 |

Compared with the earlier run, the outlet RMSE improved slightly:

- May Tout RMSE: 7.821 -> 7.571 C.
- January Tout RMSE: 8.937 -> 8.592 C.

However, the T25 RMSE worsened, and the total heat-transfer problem remains.

## Energy result

| Case | Corrected CFD Eabs | Mean Q | Mean h_eq |
|---|---:|---:|---:|
| May cooling | 2.158 kWh | 309 W | 2.37 W/(m2 K) |
| January heating | 4.400 kWh | -367 W | 2.36 W/(m2 K) |

For comparison, the experimental heat exchange estimated from Sharan inlet/outlet data is approximately:

| Case | Experimental Eabs | Minaei-G RC Eabs | Corrected CFD Eabs |
|---|---:|---:|---:|
| May cooling | 7.31 kWh | 7.10 kWh | 2.16 kWh |
| January heating | 14.40 kWh | 14.02 kWh | 4.40 kWh |

Therefore the corrected CFD still predicts only about 30% of the experimental heat exchange.

## Interpretation

The corrected run confirms the previous diagnosis. Changing to mass-flow weighted temperature and a finer transient/mesh setup did not restore turbulent heat transfer. The global effective heat-transfer coefficient remains about:

```text
h_eq = 2.3-2.4 W/(m2 K)
```

This is still far below the expected Gnielinski value:

```text
h_Gnielinski ≈ 34.5 W/(m2 K)
```

Thus the dominant problem is not the Sharan parameter set, nor the outlet temperature averaging alone. The corrected COMSOL SST model still has an air-side thermal coupling or wall-treatment problem.

## What should be checked next in COMSOL

1. Open the solved `.mph` files listed above.
2. Check the SST velocity field and confirm the axial velocity magnitude is about 11 m/s.
3. Inspect the Nonisothermal Flow multiphysics node and verify that turbulent heat transfer and thermal wall functions are active.
4. Add a simple constant-wall-temperature pipe benchmark in COMSOL:
   - same `D`, `Vdot`, `rho`, `mu`, `cp`, `k`;
   - wall fixed at 26.6 C or 24.2 C;
   - no soil and no pipe wall.
5. Compute:
   - mass-flow weighted outlet temperature;
   - wall heat-flux integral;
   - `h_CFD`;
   - `Nu_CFD`.
6. The benchmark must produce `h_CFD` close to 34.5 W/(m2 K). If it still gives about 2 W/(m2 K), the SST thermal wall treatment or heat-transfer coupling is not configured correctly.

## Bottom line

The requested corrected Sharan 50 m COMSOL turbulent models were generated, solved, and saved. The new comparison still shows large disagreement with experiment and Minaei-G. The reason is now clearer: the corrected CFD model still underpredicts air-side heat transfer by about one order of magnitude. Before using CFD as the high-fidelity reference, the air-side turbulent pipe heat-transfer benchmark must be fixed.
