# EAHE Results Image Review

## Overall Judgment

The generated figures are physically reasonable overall. The current result set already supports the main research logic:

1. Baseline EAHE cooling and temperature-wave attenuation.
2. Near-pipe soil heat accumulation and performance degradation.
3. Pipe-soil gap resistance reducing heat transfer.
4. Higher gap effective conductivity improving heat transfer.
5. Higher mass flow rate increasing total heat transfer but reducing air temperature drop.
6. Longer pipe length lowering outlet temperature with diminishing per-length benefit.
7. Higher layer-2 soil conductivity improving heat diffusion and reducing heat saturation.
8. Fine-grid temperature contours showing near-pipe heat accumulation and vertical asymmetry.
9. Temperature-dependent gap resistance causing additional performance degradation.

## Figure Checks

### Baseline

The baseline trends are correct:

- Inlet air has daily sinusoidal variation.
- Outlet air temperature is significantly attenuated and lower than inlet air.
- Outlet temperature gradually rises with operation time, indicating near-pipe soil heat accumulation.
- Heat transfer rate decreases gradually, consistent with thermal saturation.

Issue:

- `figures/baseline/baseline_01_EAHE_inlet_and_outlet_temperature.png` still appears to be an old export with an initial-point plotting artifact on the left edge.

Fix:

```matlab
regenerate_baseline_figures
```

### Degradation

The degradation figures are reasonable:

- Daily mean heat transfer decreases with operation day.
- Degradation ratio drops below 1, showing performance decay.
- Near-pipe soil temperature rise increases, explaining the decay mechanism.

The no-gap case has larger heat transfer than the fixed-gap case, as expected.

### Gap Thickness Sensitivity

The trend is correct:

- Larger `delta_gap` increases outlet temperature.
- Larger `delta_gap` decreases heat transfer.
- Ignoring the gap overestimates EAHE performance.

### Gap Conductivity Sensitivity

The trend is correct:

- Larger `k_gap_eff` lowers outlet temperature.
- Larger `k_gap_eff` increases heat transfer.
- The curves approach the no-gap behavior as `k_gap_eff` increases.

### Operation Sensitivity

The trends are correct:

- Larger mass flow rate increases total heat transfer.
- Larger mass flow rate decreases `Tin - Tout`.
- Longer pipe length lowers outlet temperature.
- Longer pipe length shows diminishing per-length heat transfer benefit.

### Soil Layer-2 Conductivity

The trend is correct:

- Higher `k_soil2` lowers outlet temperature.
- Higher `k_soil2` increases heat transfer.
- Higher `k_soil2` reduces near-pipe soil temperature rise and weakens heat saturation.

### Fine Temperature Contours

The fine-grid contour is acceptable for paper figures:

- The pipe is correctly located at 2 m depth in layer 2.
- Temperature near the pipe is higher after continuous summer cooling operation, showing heat accumulation.
- Upward and downward asymmetry is visible due to vertical soil stratification and surface boundary influence.
- The fine-grid contour is smoother than the original `Ntheta=8, Nr=6` contour.

Minor note:

- The contour still has a polygonal outer boundary because the RC grid is circumferential-radial. This is acceptable for a model visualization, but if a smoother visual is desired, use more sectors or interpolate only inside a circular mask with a smoother boundary.

### Variable Gap Resistance

The numerical summary is reasonable:

| `a_gap_T` / 1/K | Final `Tout` / degC | Last-day `Q` / W | Final `Rgap` factor |
|---:|---:|---:|---:|
| 0.00 | 21.04 | 958.90 | 1.000 |
| 0.01 | 21.09 | 956.15 | 1.044 |
| 0.02 | 21.14 | 953.43 | 1.089 |
| 0.04 | 21.23 | 948.09 | 1.176 |
| 0.08 | 21.41 | 937.78 | 1.350 |

Interpretation:

- Increasing `a_gap_T` increases the effective gap resistance as near-pipe soil warms.
- Outlet temperature increases.
- Heat transfer decreases.
- Thermal degradation becomes slightly stronger.

Missing figure export:

- The CSV and MAT exist, but `figures/variable_gap_sensitivity` was not present during inspection.

Fix:

```matlab
regenerate_variable_gap_sensitivity_figures
```

## Recommended Next Commands

Run these after the current MATLAB job finishes:

```matlab
regenerate_baseline_figures
regenerate_variable_gap_sensitivity_figures
check_generated_results
collect_summary_tables
extract_key_findings
```

For the final complete result set:

```matlab
main_all_results
check_generated_results
collect_summary_tables
extract_key_findings
```

## Paper-Ready Result Claims

The current results can support the following statements:

- Pipe-soil gap resistance weakens EAHE heat transfer and raises outlet air temperature.
- Continuous operation causes near-pipe soil heat accumulation, reducing the daily mean heat transfer rate.
- Higher soil thermal conductivity in the pipe layer enhances heat diffusion and reduces heat saturation.
- Increasing pipe length improves outlet cooling but with diminishing per-length returns.
- Increasing air flow rate increases total heat transfer but reduces outlet temperature drop.
- A temperature-dependent gap resistance can further amplify long-term performance degradation.
