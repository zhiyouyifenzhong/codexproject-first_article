# Sharan 50 m CFD Validation Run

This folder group contains two COMSOL CFD validation runs based on the Sharan
and Jadhav single-pass earth-tube heat exchanger data.

## Implemented Cases

- `COMSOL_Sharan_50m_CFD_May_cooling`
- `COMSOL_Sharan_50m_CFD_January_heating`

Both cases use:

- 2D axisymmetric geometry.
- L = 50 m.
- rpi = 0.050 m.
- rpo = 0.053 m.
- Mild steel pipe: k = 45 W/(m K), rho = 7850 kg/m3, cp = 470 J/(kg K).
- Air velocity from Vdot = 0.0863 m3/s, corresponding to approximately 11 m/s.
- SST turbulent flow.
- Nonisothermal flow coupling.
- Soil outer radius Rs = 2.0 m.
- No air gap, because the reference experiment does not report pipe-soil separation.

## Exported Validation Files

- `COMSOL_Sharan_50m_CFD_validation_all_points.csv`
- `COMSOL_Sharan_50m_CFD_validation_metrics.csv`
- `COMSOL_Sharan_50m_CFD_validation_summary.xlsx`

Each case folder also contains:

- `COMSOL_experimental_validation.csv`
- `COMSOL_Tout_delta_sweep.csv`
- `COMSOL_Q_delta_sweep.csv`
- `COMSOL_local_h_resistance_gap_delta_0mm.csv`
- geometry and temperature field figures
- solved `.mph` model file

## Direct CFD Validation Metrics

| Case | Quantity | RMSE (degC) | MAE (degC) | Bias (degC) | Max abs. error (degC) |
|---|---|---:|---:|---:|---:|
| May cooling | T25m | 4.874 | 4.622 | 4.001 | 6.283 |
| May cooling | Tout | 7.821 | 7.198 | 7.149 | 9.697 |
| January heating | T25m | 6.629 | 6.330 | -6.063 | 8.011 |
| January heating | Tout | 8.937 | 8.482 | -8.360 | 10.585 |

## Interpretation

The direct short-duration CFD run does not yet reproduce the experimental
outlet temperature. It underestimates the heat exchange with the surrounding
ground. This does not prove the CFD formulation is invalid; it means the
experimental initial and boundary state is not fully represented by simply
setting the far-field soil boundary to the measured soil temperature.

Likely causes:

- The experiment was performed after repeated operation, so the near-pipe soil
  temperature field was not equal to a uniform far-field temperature.
- The measured soil temperature was reported at a point/depth, not necessarily
  as a Dirichlet boundary at a finite radius around the pipe.
- The current soil domain starts from an initially uniform field and only runs
  for 7 h or 12 h, which is too short to establish the experimental thermal
  history.
- The actual installation may include backfill, moisture, contact resistance,
  or ground surface effects not represented in the first CFD implementation.

## Recommended Next Step

For publication-quality validation, do not present the current direct CFD
result as final agreement with the experiment. The next validation pass should:

1. Add a preconditioning stage with repeated daily operation or a calibrated
   initial radial soil temperature profile.
2. Treat the reported soil temperature as the undisturbed soil condition, not
   necessarily as a near-field boundary.
3. Compare May and January only after the preconditioned soil field is used.
4. Report both the direct-run mismatch and the corrected validation result if
   needed, so the modeling assumptions remain transparent.

