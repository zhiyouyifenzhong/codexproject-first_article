# COMSOL GUI-Validated k-epsilon Route and 50 m Sharan Results

## 1. Pipe Benchmark Result

The COMSOL GUI-built turbulent pipe template was saved as:

```text
G:\codexproject\COMSOL_GUI_templates\Sharan_pipe_GUI_template.mph
```

It was then loaded and solved using:

```text
run_comsol_gui_template_sharan_pipe_benchmark.m
```

The GUI template passes the constant-wall-temperature pipe benchmark:

```text
Re = 6.7103e4
Pr = 0.7158
h_COMSOL = 33.413 W/(m2 K)
h_Gnielinski = 34.500 W/(m2 K)
h_COMSOL / h_Gnielinski = 0.969
Nu_COMSOL = 128.51
Nu_Gnielinski = 132.69
Tout_bulk = 26.662 degC
Qair_COMSOL = 1269.06 W
Qair_Gnielinski = 1270.02 W
```

This confirms that the Sharan velocity and air properties are reasonable. The
previous low h was caused by the script-generated SST/nonisothermal setup, not
by the input flow parameters.

## 2. COMSOL API Correction

The GUI template was inspected with:

```text
inspect_comsol_gui_template_api.m
```

The actual COMSOL 6.3 k-epsilon physics type is:

```text
TurbulentFlowkeps
```

This API key was added to:

```text
comsol_eahe_airgap_model.m
```

The full 50 m validation was then run with:

```text
run_comsol_sharan_50m_cfd_kepsilon_validated.m
```

## 3. 50 m Sharan CFD Results

### May Cooling

```text
Eabs = 7.001 kWh
Qmean = 997.65 W
h_eq_mean = 19.45 W/(m2 K)
T25 RMSE = 1.305 C
Tout RMSE = 0.604 C
Tout bias = +0.442 C
```

### January Heating

```text
Eabs = 14.063 kWh
Qmean = -1169.45 W
h_eq_mean = 20.79 W/(m2 K)
T25 RMSE = 2.180 C
Tout RMSE = 0.582 C
Tout bias = -0.258 C
```

The outlet temperature is now close to Sharan's measured outlet values. The
remaining larger error at 25 m is likely linked to soil/initial-condition
history and the simplified outer soil boundary, not to air-side turbulent heat
transfer.

## 4. Improvement Relative to Previous SST CFD

The previous corrected SST run gave:

```text
May h_eq_mean = 2.37 W/(m2 K)
January h_eq_mean = 2.36 W/(m2 K)
May Tout RMSE = 7.57 C
January Tout RMSE = 8.59 C
```

The GUI-validated k-epsilon run gives:

```text
May h_eq_mean = 19.45 W/(m2 K)
January h_eq_mean = 20.79 W/(m2 K)
May Tout RMSE = 0.60 C
January Tout RMSE = 0.58 C
```

Therefore the main discrepancy has been fixed. The CFD model now exchanges heat
at the correct order of magnitude.

## 5. Generated Result Files

Summary tables:

```text
COMSOL_Sharan_50m_CFD_kepsilon_all_points.csv
COMSOL_Sharan_50m_CFD_kepsilon_metrics.csv
COMSOL_Sharan_50m_CFD_kepsilon_energy.csv
COMSOL_Sharan_50m_CFD_kepsilon_summary.xlsx
```

Solved COMSOL files:

```text
COMSOL_Sharan_50m_CFD_kepsilon_May_cooling\
  COMSOL_case_resistance_gap_delta_0mm_20260706_213713.mph

COMSOL_Sharan_50m_CFD_kepsilon_January_heating\
  COMSOL_case_resistance_gap_delta_0mm_20260706_214008.mph
```

Figures:

```text
COMSOL_Sharan_50m_CFD_kepsilon_comparison_figures\
  Fig_kepsilon_CFD_vs_exp_MinaeiG_May_cooling.png
  Fig_kepsilon_CFD_vs_exp_MinaeiG_January_heating.png
  Fig_kepsilon_CFD_RMSE_summary.png
  Fig_kepsilon_CFD_energy.png
  Fig_oldSST_vs_kepsilon_RMSE.png
  Fig_oldSST_vs_kepsilon_energy.png
  Fig_oldSST_vs_kepsilon_h_eq.png
```

## 6. Recommended Next Step

Use the k-epsilon wall-function route as the corrected CFD reference for the
50 m Sharan comparison. For the paper/report, present:

1. Constant-wall-temperature pipe benchmark proving air-side turbulent heat
   transfer is correct.
2. Old SST failure diagnosis showing h was about 2.3 W/(m2 K).
3. Corrected k-epsilon 50 m results showing h is about 19-21 W/(m2 K) in the
   conjugate soil model and outlet RMSE is below 1 C.

The remaining 25 m temperature mismatch should be discussed as a soil thermal
history/boundary-condition uncertainty rather than an air-side turbulence error.
