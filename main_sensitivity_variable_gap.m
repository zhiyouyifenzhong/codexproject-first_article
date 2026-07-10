% Sensitivity analysis for the temperature-dependent pipe-soil gap resistance.
% Sweeps a_gap_T in:
%
%   Rgap = Rgap0 * [1 + a_gap_T * (Ts_near - T_gap_ref)]

clear; clc;

a_list = [0.00, 0.01, 0.02, 0.04, 0.08]; % 1/K
nCase = numel(a_list);

common.t_end = 7 * 24 * 3600;
common.snapshot_times = [0, 24, 72, 168] * 3600;

fprintf('Running reusable fixed-gap reference soil field...\n');
base = run_eahe_simulation(common);

results = cell(nCase, 1);
labels = strings(nCase, 1);

for c = 1:nCase
    overrides = common;
    overrides.soil_pre = base.soil_pre;
    overrides.R_gap_mode = 'variable';
    overrides.a_gap_T = a_list(c);
    overrides.T_gap_ref = base.Tundist_pipe(1);
    overrides.R_gap_min_factor = 0.50;
    overrides.R_gap_max_factor = 3.00;

    fprintf('Running variable-gap sensitivity case %d/%d: a_gap_T = %.3f 1/K\n', ...
        c, nCase, a_list(c));
    results{c} = run_eahe_simulation(overrides);
    labels(c) = sprintf('a_{gap,T}=%.3f 1/K', a_list(c));
end

save('variable_gap_sensitivity_result.mat', 'results', 'a_list', 'labels', 'base');

figure('Name', 'Variable gap sensitivity - outlet temperature');
hold on;
for c = 1:nCase
    idx = 2:numel(results{c}.time);
    plot(results{c}.time(idx)/3600, results{c}.Tout(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(labels, 'Location', 'best');
grid on;

figure('Name', 'Variable gap sensitivity - daily mean heat transfer');
hold on;
for c = 1:nCase
    plot(results{c}.degradation.day, results{c}.degradation.Q_day_mean, ...
        'o-', 'LineWidth', 1.2);
end
xlabel('Operation day');
ylabel('Daily mean heat transfer rate / W');
legend(labels, 'Location', 'best');
grid on;

figure('Name', 'Variable gap sensitivity - gap resistance factor');
hold on;
for c = 1:nCase
    plot(results{c}.time/3600, results{c}.Rgap_factor_mid_mean, 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Mean R_{gap} factor at middle segment');
legend(labels, 'Location', 'best');
grid on;

summary = table(a_list(:), zeros(nCase,1), zeros(nCase,1), zeros(nCase,1), zeros(nCase,1), ...
    'VariableNames', {'a_gap_T_1_K','Tout_final_degC','Q_last_day_W','Eta_Q_last_day','Rgap_factor_final'});
for c = 1:nCase
    summary.Tout_final_degC(c) = results{c}.Tout(end);
    summary.Q_last_day_W(c) = results{c}.degradation.Q_day_mean(end);
    summary.Eta_Q_last_day(c) = results{c}.degradation.eta_Q_day(end);
    summary.Rgap_factor_final(c) = results{c}.Rgap_factor_mid_mean(end);
end

disp(summary);
writetable(summary, 'variable_gap_sensitivity_summary.csv');
