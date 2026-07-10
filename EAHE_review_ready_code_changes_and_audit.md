# EAHE MATLAB Code Review-Ready Update and Audit

## Updated file

- `G:\codexproject\EAHE_airgap_physical_modules_v17_review_ready.m`

The original file in `C:\Users\dell\Downloads\EAHE_airgap_physical_modules_v16.m` was not overwritten.

## Code improvements

1. Added contact-coefficient output:
   - `phi` remains air-gap coverage ratio.
   - `chi = 1 - phi` is now exported as the contact coefficient.
   - `Rnet.chi_contact` and `Reng.chi_contact` are included for traceability.

2. Improved soil response discretization:
   - The infinite-line-source kernel now treats the current-step self response with a midpoint approximation, `tau = dt/2`, instead of forcing `G(0)=0`.
   - This avoids fully lagging the current heat-flow increment by one time step.

3. Added Picard convergence control:
   - Added `p.picardMaxIter`, `p.picardTol`, and `p.picardRelax`.
   - Each time step records `picardIter` and `picardResidual`.
   - Summary table now includes maximum Picard iteration count and residual.

4. Added review-oriented figures:
   - `Fig00_model_physical_schematic.png`
   - `Fig00b_RC_network.png`
   - `Fig00c_solver_flowchart.png`
   - Existing result figures `Fig01` to `Fig07` are retained.

5. Added Excel export:
   - `EAHE_airgap_review_ready_tables.xlsx`
   - Includes summary, validation, parameter, figure checklist, and per-case time-series sheets.
   - If `.xlsx` export fails on a machine, fallback CSV files are written.

6. Added figure checklist:
   - `Table_06_review_figure_checklist.csv`
   - Checks MATLAB-generated method/result figures and existing COMSOL validation figures.

## Static code check

MATLAB `checkcode` was run on the improved script.

Result:

- Syntax-breaking issues: none.
- Remaining messages: 5 sparse-matrix indexing performance warnings in the implicit solver.

These warnings do not affect physical correctness. They only indicate that sparse matrix assembly could be optimized further if runtime becomes a problem.

## Existing COMSOL figure and data audit

The following required COMSOL materials already exist in the workspace:

- Geometry figure:
  - `G:\codexproject\COMSOL_EAHE_field_materials\field_figures\Fig_COMSOL_geometry_explicit_gap_delta_0p5mm.png`
- Initial temperature field:
  - `G:\codexproject\COMSOL_EAHE_field_materials\field_figures\Fig_COMSOL_Tfield_initial_explicit_gap_delta_0p5mm.png`
- Final temperature field:
  - `G:\codexproject\COMSOL_EAHE_field_materials\field_figures\Fig_COMSOL_Tfield_final_explicit_gap_delta_0p5mm.png`
- Final near-pipe zoom:
  - `G:\codexproject\COMSOL_EAHE_field_materials\field_figures\Fig_COMSOL_Tfield_final_zoom_explicit_gap_delta_0p5mm.png`
- Explicit-vs-resistance outlet temperature comparison:
  - `G:\codexproject\COMSOL_EAHE_outputs_annual_full\Fig_COMSOL_06_explicit_vs_resistance_Tout.png`
- Annual energy comparison:
  - `G:\codexproject\COMSOL_EAHE_outputs_annual_full\Fig_COMSOL_04_annual_energy.png`
- Validation metrics:
  - `G:\codexproject\COMSOL_EAHE_outputs_annual_full\COMSOL_validation_metrics.csv`
- Mesh independence summary:
  - `G:\codexproject\COMSOL_EAHE_mesh_independence\COMSOL_mesh_independence_summary.csv`

## Reviewer-readiness judgment

The updated MATLAB script plus existing COMSOL outputs now cover the core reviewer requirements:

- Physical model diagram: added.
- Thermal resistance-capacitance network: added.
- Numerical solution workflow: added.
- COMSOL geometry figure: exists.
- Initial and final temperature contours: exist.
- Explicit air-gap vs equivalent resistance validation: exists.
- Annual performance curves and tables: exist.
- Mesh independence data: exists.
- Excel-ready data export: added.

Remaining recommendation:

- Before final submission, run the improved MATLAB script once to generate the new `v17_review_ready_results` folder and confirm all MATLAB figures and Excel sheets are produced on the target machine.
