% Variable pipe-soil gap resistance extension.
% Compares the baseline fixed-gap model with a temperature-dependent gap
% resistance model:
%
%   Rgap = Rgap0 * [1 + a_gap_T * (Ts_near - T_gap_ref)]
%
% bounded by R_gap_min_factor and R_gap_max_factor.

clear; clc;

common.t_end = 7 * 24 * 3600;
common.snapshot_times = [0, 24, 72, 168] * 3600;

fprintf('Running fixed-gap baseline...\n');
fixed_case = run_eahe_simulation(common);

fprintf('Running variable-gap extension with reused undisturbed soil field...\n');
variable_overrides = common;
variable_overrides.soil_pre = fixed_case.soil_pre;
variable_overrides.R_gap_mode = 'variable';
variable_overrides.a_gap_T = 0.02;
variable_overrides.T_gap_ref = fixed_case.Tundist_pipe(1);
variable_overrides.R_gap_min_factor = 0.50;
variable_overrides.R_gap_max_factor = 3.00;
variable_case = run_eahe_simulation(variable_overrides);

save('variable_gap_extension_result.mat', 'fixed_case', 'variable_case');

idxFixed = 2:numel(fixed_case.time);
idxVar = 2:numel(variable_case.time);

figure('Name', 'Variable gap extension - outlet temperature');
plot(fixed_case.time(idxFixed)/3600, fixed_case.Tout(idxFixed), 'b-', 'LineWidth', 1.4); hold on;
plot(variable_case.time(idxVar)/3600, variable_case.Tout(idxVar), 'r--', 'LineWidth', 1.4);
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend('Fixed R_{gap}', 'Variable R_{gap}', 'Location', 'best');
grid on;

figure('Name', 'Variable gap extension - heat transfer rate');
plot(fixed_case.time(idxFixed)/3600, fixed_case.Q(idxFixed), 'b-', 'LineWidth', 1.4); hold on;
plot(variable_case.time(idxVar)/3600, variable_case.Q(idxVar), 'r--', 'LineWidth', 1.4);
xlabel('Time / h');
ylabel('Heat transfer rate / W');
legend('Fixed R_{gap}', 'Variable R_{gap}', 'Location', 'best');
grid on;

figure('Name', 'Variable gap extension - gap resistance factor');
plot(variable_case.time/3600, variable_case.Rgap_factor_mid_mean, 'm-', 'LineWidth', 1.4);
xlabel('Time / h');
ylabel('Mean R_{gap} factor at middle segment');
grid on;

figure('Name', 'Variable gap extension - daily degradation');
plot(fixed_case.degradation.day, fixed_case.degradation.Q_day_mean, ...
    'bo-', 'LineWidth', 1.3); hold on;
plot(variable_case.degradation.day, variable_case.degradation.Q_day_mean, ...
    'rs-', 'LineWidth', 1.3);
xlabel('Operation day');
ylabel('Daily mean heat transfer rate / W');
legend('Fixed R_{gap}', 'Variable R_{gap}', 'Location', 'best');
grid on;

summary = table( ...
    ["Fixed gap"; "Variable gap"], ...
    [fixed_case.Tout(end); variable_case.Tout(end)], ...
    [fixed_case.degradation.Q_day_mean(end); variable_case.degradation.Q_day_mean(end)], ...
    [fixed_case.degradation.eta_Q_day(end); variable_case.degradation.eta_Q_day(end)], ...
    [fixed_case.Rgap_factor_mid_mean(end); variable_case.Rgap_factor_mid_mean(end)], ...
    'VariableNames', {'Case','Tout_final_degC','Q_last_day_W','Eta_Q_last_day','Rgap_factor_final'});

disp(summary);
writetable(summary, 'variable_gap_extension_summary.csv');
