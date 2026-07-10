% Generate all core results plus numerical validation.
% This is the most complete and most time-consuming run script.

clear; clc; close all;

main_core_results;

fprintf('\n=== 10. Numerical validation ===\n');
main_numerical_validation;
save_all_open_figures(fullfile('figures', 'numerical_validation'), 'numerical_validation');
close all;

fprintf('\nAll result generation complete.\n');
