# Paper Figure and Validation Workflow

## 1. Main Figure Selection

Recommended main-text figures:

1. `Fig01_soil_phase_check`: layered-soil initial phase and pipe depth.
2. `Fig02_baseline_transient`: inlet/outlet air temperature and heat-transfer rate.
3. `Fig03_heat_saturation_degradation`: thermal saturation/degradation with and without gap resistance.
4. `Fig04_temperature_field_contours`: near-pipe temperature field at start and after operation.
5. `Fig05_sensitivity_summary`: gap thickness, layer-2 conductivity, mass flow rate, and pipe length.
6. `Fig07_analytical_model_comparison`: transient RC model versus simple analytical NTU model.

Recommended supplementary figures:

- Full gap-thickness time series.
- Full gap-conductivity time series.
- Full operation and pipe-length sensitivity curves.
- Variable gap resistance comparison and coefficient sensitivity.
- Numerical independence checks.

## 2. Temperature Contour Checks

Before using contour figures, run or inspect:

```matlab
audit_result_physics
```

For the summer cooling case, the shallow soil around the pipe should generally
be warmer than the deeper soil at the operation start. After operation, a local
warm region should appear near the pipe wall because heat is released from air
to soil.

## 3. Homogeneous Soil Degradation Comparison

Run:

```matlab
main_compare_homogeneous_degradation
```

Purpose:

- Shows what is gained by using vertical layered soil instead of the classical
  homogeneous-soil approximation.
- Compare daily heat-transfer degradation ratio and near-pipe heat accumulation.

Output:

- `homogeneous_degradation_comparison_result.mat`
- `homogeneous_degradation_comparison_summary.csv`
- `figures/homogeneous_degradation/`

## 4. Experimental Comparison

The user-specified DOI is:

```text
10.1016/j.icheatmasstransfer.2011.03.009
```

The attached PDF confirms this DOI and title:

```text
Experimental prediction of total thermal resistance of a closed loop EAHE for greenhouse cooling system
```

Extracted parameters are stored in:

```text
literature_extraction/ozgener2011_extracted_parameters.csv
```

Digitized thermal-resistance points from Figs. 3-7 are stored in:

```text
literature_extraction/ozgener2011_digitized_rtot.csv
```

Run the reduced homogeneous no-gap validation case:

```matlab
main_ozgener2011_validation
```

Then refresh the validation figure and statistics:

```powershell
python .\ozgener2011_validation_postprocess.py
```

Use `literature_experiment_manifest.csv` to record selected experimental
studies. Use `experimental_comparison_timeseries.csv` for digitized time-series
points. Required columns:

- `StudyID`
- `CaseID`
- `time_h`
- `Tin_degC`
- `Tout_exp_degC`
- `Tout_model_degC`

After filling the file, run:

```matlab
main_experimental_comparison
```

Output:

- `experimental_comparison_summary.csv`
- `figures/experimental_comparison/`

Recommended experiment-screening criteria:

- measured inlet and outlet air temperature time series;
- pipe length, diameter, burial depth, airflow, and soil type reported;
- operating date or undisturbed soil temperature reported;
- enough data points for RMSE/MBE, not only one average value.

## 5. Analytical Model Comparison

`paper_postprocess.py` implements a simple steady cylindrical-resistance NTU
model:

```text
Tout = Tsoil + (Tin - Tsoil) exp[-UA/(m cp)]
```

This model uses the undisturbed soil temperature at pipe depth as far-field
temperature and includes internal convection, pipe wall, gap, and radial soil
resistance. It is intentionally simple and should be presented as a classical
reference, not as an equally detailed transient model.

Run:

```powershell
python .\paper_postprocess.py
```

Output:

- `paper_figures/Fig07_analytical_model_comparison.png`
- `paper_tables/analytical_comparison_metrics.csv`
