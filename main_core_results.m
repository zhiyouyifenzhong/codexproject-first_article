% Core result generation script for the EAHE RC study.
% This script runs the result cases most useful for the paper's Results
% section. Numerical validation remains separate because it is more
% time-consuming.

clear; clc; close all;

fprintf('\n=== 1. Baseline case ===\n');
main_baseline;
save_all_open_figures(fullfile('figures', 'baseline'), 'baseline');
close all;

fprintf('\n=== 2. Undisturbed soil phase check ===\n');
main_check_undisturbed_soil_phase;
save_all_open_figures(fullfile('figures', 'soil_phase_check'), 'soil_phase_check');
close all;

fprintf('\n=== 3. Temperature field contours ===\n');
main_temperature_field_fine;
save_all_open_figures(fullfile('figures', 'temperature_field_fine'), 'contour_fine');
close all;

fprintf('\n=== 4. Thermal degradation validation ===\n');
main_degradation_validation;
save_all_open_figures(fullfile('figures', 'degradation'), 'degradation');
close all;

fprintf('\n=== 5. Pipe-soil gap thickness sensitivity ===\n');
main_sensitivity_gap;
save_all_open_figures(fullfile('figures', 'gap_thickness'), 'gap_thickness');
close all;

fprintf('\n=== 6. Gap effective conductivity sensitivity ===\n');
main_sensitivity_gap_conductivity;
save_all_open_figures(fullfile('figures', 'gap_conductivity'), 'gap_conductivity');
close all;

fprintf('\n=== 7. Operation and length sensitivity ===\n');
main_sensitivity_operation;
save_all_open_figures(fullfile('figures', 'operation'), 'operation');
close all;

fprintf('\n=== 8. Second-layer soil conductivity sensitivity ===\n');
main_sensitivity_soil_layer2;
save_all_open_figures(fullfile('figures', 'soil_layer2'), 'soil_layer2');
close all;

fprintf('\n=== 9. Variable gap resistance extension ===\n');
main_variable_gap_extension;
save_all_open_figures(fullfile('figures', 'variable_gap'), 'variable_gap');
close all;

fprintf('\n=== 10. Variable gap temperature-sensitivity analysis ===\n');
main_sensitivity_variable_gap;
save_all_open_figures(fullfile('figures', 'variable_gap_sensitivity'), 'variable_gap_sensitivity');
close all;

fprintf('\nCore result generation complete.\n');
