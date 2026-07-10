% Full final generation script.
% This script clears old figure images, reruns all simulations/analyses,
% regenerates every figure in the existing figures/* folders, and exports
% summary data tables and key findings.

clear; clc; close all;

fprintf('\n=== Cleaning old figure exports ===\n');
clean_figure_outputs('figures');

fprintf('\n=== Generating all simulation results and figures ===\n');
main_all_results;

fprintf('\n=== Finalizing and exporting data products ===\n');
finalize_results_after_run;

fprintf('\n=== Final output generation complete ===\n');
fprintf('Figures: %s\n', fullfile(pwd, 'figures'));
fprintf('Summary workbook: %s\n', fullfile(pwd, 'EAHE_summary_tables.xlsx'));
fprintf('Key findings: %s\n', fullfile(pwd, 'EAHE_key_findings.txt'));
