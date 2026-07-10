# MATLAB code and independence-check audit

## Scope

Checked files:

- `EAHE_airgap_physical_modules_v18_minaei_contact.m`
- attached pasted copy of `EAHE_airgap_physical_modules_v18_minaei_contact.m`
- current independence output CSV files under `EAHE_airgap_physical_v18_minaei_contact_results`
- older root-level `validation_dt_summary.csv` and `validation_Nx_summary.csv`

## Soil-response kernel check

The v18 model is correctly restricted to the Minaei G-function kernel:

- `p.soilKernelType = 'MINAEI_G'`
- `buildSoilResponseKernel()` rejects any kernel type other than `MINAEI_G`.
- The code path therefore does not evaluate ILS or FLS kernels.

This is consistent with the current validation requirement.

## Space-independence check

The current v18 MATLAB code uses a dense axial-segment sequence:

```matlab
NxList = [20 30 40 50 60 70 80 100 120 140 160 200 240];
```

This is 13 points, with `Nx = 240` as the reference solution. This is not too few
for a paper-level spatial independence check.

Current output:

- file: `EAHE_airgap_physical_v18_minaei_contact_results/Validation_Nx_independence.csv`
- number of points: 13
- range: `Nx = 20` to `Nx = 240`
- at the working value `Nx = 80`, the reported error is:
  - `RMSE_Tout_C = 0.0070648388 deg C`
  - `RelErr_Eabs_percent = 0.209159%`

Conclusion: `Nx = 80` is acceptable for the annual MATLAB reduced model.

## Time-step independence check

The attached/current MATLAB code originally used 8 points:

```matlab
dtList_h = [24 18 12 9 6 4 3 2];
```

This is already much better than the obsolete three-point check, but the code has
now been updated to include a 1 h reference solution:

```matlab
dtList_h = [24 18 12 9 6 4 3 2 1];
```

This makes the intended paper-level check 9 points, with `dt = 1 h` as the
reference. However, a direct rerun of the 1 h reference case exceeded the
10-minute command timeout, so the main CSV has not yet been refreshed by this
turn.

Current available outputs:

- `Validation_dt_independence.csv`: 8 points, `dt = 24` to `2 h`.
- `Origin_ready_data/Origin_Fig14_dt_independence.csv`: 9 points, `dt = 24` to `1 h`.
- old root `validation_dt_summary.csv`: only 3 points, obsolete and should not be
  used in the paper.

At the working value `dt = 6 h`, the 8-point main CSV gives:

- `RMSE_Tout_C = 0.0024968148 deg C`
- `RelErr_Eabs_percent = 0.0486703%`

The 9-point Origin-ready CSV gives, relative to a stricter 1 h reference:

- `RMSE_Tout_C = 0.0031031310 deg C`
- `RelErr_Eabs_percent = 0.06091498%`

Both values are very small. Therefore `dt = 6 h` is acceptable.

## Main problem found

The statement that "time and space independence uses too few points" is true only
for the old root-level files:

- `validation_dt_summary.csv`: 3 points
- `validation_Nx_summary.csv`: 3 points

Those files are old/debug summaries and should not be cited.

The v18 validation outputs are denser:

- spatial: 13 points
- time-step: 8 points currently in the main CSV, 9 points in the Origin-ready CSV,
  and the code has been updated to use 9 points in future reruns.

## Recommendation for the paper

Use these files for the validation section:

- `EAHE_airgap_physical_v18_minaei_contact_results/Validation_Nx_independence.csv`
- `EAHE_airgap_physical_v18_minaei_contact_results/Validation_dt_independence.csv`
- if using the stricter 1 h time reference, use
  `EAHE_airgap_physical_v18_minaei_contact_results/Origin_ready_data/Origin_Fig14_dt_independence.csv`

Do not use:

- `validation_dt_summary.csv`
- `validation_Nx_summary.csv`

If the final manuscript must be perfectly internally consistent, rerun only the
time-step independence study with the updated 9-point `dtList_h` during a longer
MATLAB session, then regenerate the Origin-ready exports.
