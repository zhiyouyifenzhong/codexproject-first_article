% Pipe-soil gap effective thermal conductivity sensitivity analysis.
% This complements main_sensitivity_gap.m by changing k_gap_eff at fixed
% equivalent gap thickness.

clear; clc;

k_gap_list = [0.026, 0.05, 0.10, 0.20, 0.50]; % W/(m K)
nCase = numel(k_gap_list);

results = cell(nCase, 1);
labels = strings(nCase, 1);

fprintf('Running reference case for reusable soil field...\n');
base = run_eahe_simulation(struct('k_gap_eff', k_gap_list(1)));
results{1} = base;
labels(1) = sprintf('k_{gap}=%.3f W/(m K)', k_gap_list(1));

for c = 2:nCase
    fprintf('Running gap-conductivity sensitivity case %d/%d...\n', c, nCase);
    overrides.k_gap_eff = k_gap_list(c);
    overrides.soil_pre = base.soil_pre;
    results{c} = run_eahe_simulation(overrides);
    labels(c) = sprintf('k_{gap}=%.3f W/(m K)', k_gap_list(c));
end

save('gap_conductivity_sensitivity_result.mat', 'results', 'k_gap_list', 'labels');

figure('Name', 'Gap conductivity sensitivity - outlet temperature');
hold on;
for c = 1:nCase
    idx = 2:numel(results{c}.time);
    plot(results{c}.time(idx)/3600, results{c}.Tout(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(labels, 'Location', 'best');
grid on;

figure('Name', 'Gap conductivity sensitivity - daily mean heat transfer');
hold on;
for c = 1:nCase
    plot(results{c}.degradation.day, results{c}.degradation.Q_day_mean, ...
        'o-', 'LineWidth', 1.2);
end
xlabel('Operation day');
ylabel('Daily mean heat transfer rate / W');
legend(labels, 'Location', 'best');
grid on;

summary = table(k_gap_list(:), zeros(nCase,1), zeros(nCase,1), zeros(nCase,1), ...
    'VariableNames', {'k_gap_eff_W_mK','Tout_final_degC','Q_last_day_W','Eta_Q_last_day'});
for c = 1:nCase
    summary.Tout_final_degC(c) = results{c}.Tout(end);
    summary.Q_last_day_W(c) = results{c}.degradation.Q_day_mean(end);
    summary.Eta_Q_last_day(c) = results{c}.degradation.eta_Q_day(end);
end

disp(summary);
writetable(summary, 'gap_conductivity_sensitivity_summary.csv');
