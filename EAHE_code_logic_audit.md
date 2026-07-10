# EAHE Code Logic Audit

## Purpose

This audit focuses on model-consistency errors similar to the previously found soil-temperature phase mismatch.

## Issues Found And Fixed

### 1. Undisturbed Soil Annual Phase Mismatch

Problem:

- EAHE inlet air was configured as a summer cooling condition.
- The undisturbed soil field was sampled from the beginning of the annual cycle.
- This could make the upper soil appear abnormally cold in summer temperature contours.

Fix:

- Added `param.operation_start_day = 210`.
- Added `param.soil_time_offset = param.operation_start_day * param.day`.
- Updated `get_undisturbed_profile()` to sample:

```matlab
tq = mod(t + param.soil_time_offset, param.year);
```

### 2. Operation Start Day Could Become Inconsistent With Soil Time Offset

Problem:

- If only `operation_start_day` was overridden, `soil_time_offset` could remain stale.

Fix:

- `finalize_param()` now always recomputes:

```matlab
param.soil_time_offset = param.operation_start_day * param.day;
```

### 3. Reusing Incompatible `soil_pre`

Problem:

- Some sensitivity scripts reuse `soil_pre`, which is valid only when soil, weather, and precomputation settings are unchanged.
- Without a compatibility check, an old or incompatible soil field could silently contaminate results.

Fix:

- `precompute_undisturbed_soil()` now attaches `soil_pre.signature`.
- `run_eahe_simulation()` validates supplied `soil_pre` against current soil and weather settings.
- Incompatible or old `soil_pre` now triggers an error.

### 4. Near-Soil Domain Could Cross Ground Surface Or Leave Precomputed Soil Domain

Problem:

- If `r_soil_max` is too large, the upper near-soil boundary can cross the ground surface.
- If the lower boundary exceeds `z_max`, the far-field boundary is extrapolated beyond the precomputed domain.

Fix:

- Added parameter validation:

```matlab
param.z_pipe - param.r_soil_max >= 0
param.z_pipe + param.r_soil_max <= param.z_max
```

### 5. Old First-Version Script Could Still Be Run

Problem:

- `main_EAHE_RC_first_version.m` still contained the obsolete model without the soil phase correction.

Fix:

- Replaced it with a compatibility wrapper that warns and runs `main_baseline`.

### 6. Old MAT Results Could Be Reused Accidentally

Problem:

- Existing `.mat` files generated before the soil phase correction could still be plotted.

Fix:

- Added `param.model_revision = 'soil_phase_offset_v2'`.
- Added `check_result_revision.m`.
- Updated `finalize_results_after_run.m` to skip old results and instruct rerun.
- Updated the Python fallback exporter to skip old-revision results.

## Remaining Modeling Assumptions

These are not coding errors, but should be stated in the paper:

- The near-pipe soil domain does not explicitly include the ground surface boundary; therefore `r_soil_max <= z_pipe` is enforced.
- Axial soil conduction along the pipe is neglected.
- Soil moisture migration and groundwater advection are not modeled.
- Soil-layer interface resistance is neglected; only thermal-property discontinuity is considered.
- Variable gap resistance is an exploratory temperature-dependent extension and should be calibrated against experiment or high-fidelity simulation before being treated as predictive.

## Recommended Verification After Rerun

Run:

```matlab
generate_all_outputs
check_result_revision
check_generated_results
```

Then inspect:

- `figures/soil_phase_check`
- `figures/temperature_field_fine`
- `EAHE_key_findings.txt`
- `EAHE_summary_tables.xlsx`
