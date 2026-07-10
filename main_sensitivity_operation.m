% Operation and design parameter sensitivity analysis.
% Includes air mass flow rate and pipe length.

clear; clc;

common.t_end = 7 * 24 * 3600;
common.snapshot_times = [0, 24, 72, 168] * 3600;

fprintf('Preparing reusable soil field with baseline case...\n');
base = run_eahe_simulation(common);
soil_pre = base.soil_pre;

%% Mass flow rate sensitivity
m_dot_list = [0.04, 0.08, 0.12, 0.16];
m_results = cell(numel(m_dot_list), 1);
m_labels = strings(numel(m_dot_list), 1);

for c = 1:numel(m_dot_list)
    overrides = common;
    overrides.m_dot = m_dot_list(c);
    overrides.soil_pre = soil_pre;
    fprintf('Running mass-flow sensitivity: m_dot = %.3f kg/s\n', m_dot_list(c));
    m_results{c} = run_eahe_simulation(overrides);
    m_labels(c) = sprintf('\\dot{m}=%.2f kg/s', m_dot_list(c));
end

%% Pipe length sensitivity
L_list = [20, 40, 60, 80];
L_results = cell(numel(L_list), 1);
L_labels = strings(numel(L_list), 1);

for c = 1:numel(L_list)
    overrides = common;
    overrides.L_pipe = L_list(c);
    overrides.Nx_pipe = max(20, round(L_list(c))); % about 1 m axial cell length
    overrides.soil_pre = soil_pre;
    fprintf('Running pipe-length sensitivity: L = %.1f m\n', L_list(c));
    L_results{c} = run_eahe_simulation(overrides);
    L_labels(c) = sprintf('L=%.0f m', L_list(c));
end

save('operation_sensitivity_result.mat', ...
    'm_results', 'm_dot_list', 'm_labels', ...
    'L_results', 'L_list', 'L_labels');

figure('Name', 'Mass flow sensitivity - outlet temperature');
hold on;
for c = 1:numel(m_dot_list)
    idx = 2:numel(m_results{c}.time);
    plot(m_results{c}.time(idx)/3600, m_results{c}.Tout(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(m_labels, 'Location', 'best');
grid on;

figure('Name', 'Mass flow sensitivity - daily heat and cooling drop');
tiledlayout(1,2);
nexttile; hold on;
for c = 1:numel(m_dot_list)
    plot(m_results{c}.degradation.day, m_results{c}.degradation.Q_day_mean, ...
        'o-', 'LineWidth', 1.2);
end
xlabel('Operation day'); ylabel('Daily mean heat transfer / W'); grid on;
legend(m_labels, 'Location', 'best');
nexttile; hold on;
for c = 1:numel(m_dot_list)
    plot(m_results{c}.degradation.day, m_results{c}.degradation.dT_day_mean, ...
        'o-', 'LineWidth', 1.2);
end
xlabel('Operation day'); ylabel('Daily mean Tin - Tout / K'); grid on;

figure('Name', 'Pipe length sensitivity - outlet temperature');
hold on;
for c = 1:numel(L_list)
    idx = 2:numel(L_results{c}.time);
    plot(L_results{c}.time(idx)/3600, L_results{c}.Tout(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(L_labels, 'Location', 'best');
grid on;

summary_m = table(m_dot_list(:), zeros(numel(m_dot_list),1), zeros(numel(m_dot_list),1), zeros(numel(m_dot_list),1), ...
    'VariableNames', {'m_dot_kg_s','Tout_final_degC','Q_last_day_W','dT_last_day_K'});
for c = 1:numel(m_dot_list)
    summary_m.Tout_final_degC(c) = m_results{c}.Tout(end);
    summary_m.Q_last_day_W(c) = m_results{c}.degradation.Q_day_mean(end);
    summary_m.dT_last_day_K(c) = m_results{c}.degradation.dT_day_mean(end);
end

summary_L = table(L_list(:), zeros(numel(L_list),1), zeros(numel(L_list),1), zeros(numel(L_list),1), ...
    'VariableNames', {'L_pipe_m','Tout_final_degC','Q_last_day_W','Q_per_length_last_day_W_m'});
for c = 1:numel(L_list)
    summary_L.Tout_final_degC(c) = L_results{c}.Tout(end);
    summary_L.Q_last_day_W(c) = L_results{c}.degradation.Q_day_mean(end);
    summary_L.Q_per_length_last_day_W_m(c) = summary_L.Q_last_day_W(c) / L_list(c);
end

disp(summary_m);
disp(summary_L);
writetable(summary_m, 'operation_mdot_summary.csv');
writetable(summary_L, 'operation_length_summary.csv');
