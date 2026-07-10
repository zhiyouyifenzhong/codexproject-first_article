% Compare the layered-soil EAHE RC model with a classical homogeneous-soil
% approximation over a 30-day continuous cooling operation.

clear; clc; close all;

common.t_end = 30 * 24 * 3600;
common.snapshot_times = [0, 24, 72, 168, 720] * 3600;

fprintf('Running layered-soil reference case...\n');
layered_case = run_eahe_simulation(common);

fprintf('Running homogeneous-soil classical approximation...\n');
homogeneous = common;
homogeneous.k_soil = [1.55, 1.55, 1.55];
homogeneous.rho_soil = [1700.0, 1700.0, 1700.0];
homogeneous.cp_soil = [1400.0, 1400.0, 1400.0];
homogeneous_case = run_eahe_simulation(homogeneous);

save('homogeneous_degradation_comparison_result.mat', ...
    'layered_case', 'homogeneous_case');

summary = table( ...
    ["Layered soil"; "Homogeneous soil"], ...
    [layered_case.degradation.Q_day_mean(1); homogeneous_case.degradation.Q_day_mean(1)], ...
    [layered_case.degradation.Q_day_mean(end); homogeneous_case.degradation.Q_day_mean(end)], ...
    [layered_case.degradation.eta_Q_day(end); homogeneous_case.degradation.eta_Q_day(end)], ...
    [layered_case.degradation.near_soil_rise_day_mean(end); homogeneous_case.degradation.near_soil_rise_day_mean(end)], ...
    'VariableNames', {'Case','Q_day1_W','Q_last_day_W','Eta_Q_last_day','Near_soil_rise_last_day_K'});

disp(summary);
writetable(summary, 'homogeneous_degradation_comparison_summary.csv');

figure('Name', 'Layered vs homogeneous soil - degradation ratio');
plot(layered_case.degradation.day, layered_case.degradation.eta_Q_day, ...
    'o-', 'LineWidth', 1.3); hold on;
plot(homogeneous_case.degradation.day, homogeneous_case.degradation.eta_Q_day, ...
    's--', 'LineWidth', 1.3);
xlabel('Operation day');
ylabel('Q day mean / day-1 value');
legend('Layered soil', 'Homogeneous soil', 'Location', 'best');
grid on;

figure('Name', 'Layered vs homogeneous soil - near-pipe heat accumulation');
plot(layered_case.degradation.day, layered_case.degradation.near_soil_rise_day_mean, ...
    'o-', 'LineWidth', 1.3); hold on;
plot(homogeneous_case.degradation.day, homogeneous_case.degradation.near_soil_rise_day_mean, ...
    's--', 'LineWidth', 1.3);
xlabel('Operation day');
ylabel('Daily mean near-pipe soil temperature rise / K');
legend('Layered soil', 'Homogeneous soil', 'Location', 'best');
grid on;

save_all_open_figures(fullfile('figures', 'homogeneous_degradation'), 'homogeneous_degradation');
