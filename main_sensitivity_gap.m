% Pipe-soil gap thickness sensitivity analysis.
% The undisturbed soil field is reused across cases because soil preheating
% is independent of the pipe-soil gap resistance.

clear; clc;

gap_list = [0.0, 0.5, 1.0, 2.0, 5.0] * 1e-3; % m
nCase = numel(gap_list);

results = cell(nCase, 1);
labels = strings(nCase, 1);

fprintf('Running reference case for reusable soil field...\n');
base = run_eahe_simulation(struct('delta_gap', gap_list(1)));
results{1} = base;
labels(1) = sprintf('\\delta_{gap}=%.1f mm', gap_list(1)*1e3);

for c = 2:nCase
    fprintf('Running gap sensitivity case %d/%d...\n', c, nCase);
    overrides.delta_gap = gap_list(c);
    overrides.soil_pre = base.soil_pre;
    results{c} = run_eahe_simulation(overrides);
    labels(c) = sprintf('\\delta_{gap}=%.1f mm', gap_list(c)*1e3);
end

save('gap_sensitivity_result.mat', 'results', 'gap_list', 'labels');

figure('Name', 'Gap sensitivity - outlet temperature');
hold on;
for c = 1:nCase
    idx = 2:numel(results{c}.time);
    plot(results{c}.time(idx)/3600, results{c}.Tout(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(labels, 'Location', 'best');
grid on;

figure('Name', 'Gap sensitivity - heat transfer rate');
hold on;
for c = 1:nCase
    idx = 2:numel(results{c}.time);
    plot(results{c}.time(idx)/3600, results{c}.Q(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Heat transfer rate / W');
legend(labels, 'Location', 'best');
grid on;

figure('Name', 'Gap sensitivity - daily mean heat transfer');
hold on;
for c = 1:nCase
    plot(results{c}.degradation.day, results{c}.degradation.Q_day_mean, ...
        'o-', 'LineWidth', 1.2);
end
xlabel('Operation day');
ylabel('Daily mean heat transfer rate / W');
legend(labels, 'Location', 'best');
grid on;

summary = table(gap_list(:)*1e3, zeros(nCase,1), zeros(nCase,1), zeros(nCase,1), ...
    'VariableNames', {'Gap_mm','Tout_final_degC','Q_last_day_W','Eta_Q_last_day'});
for c = 1:nCase
    summary.Tout_final_degC(c) = results{c}.Tout(end);
    summary.Q_last_day_W(c) = results{c}.degradation.Q_day_mean(end);
    summary.Eta_Q_last_day(c) = results{c}.degradation.eta_Q_day(end);
end

disp(summary);
writetable(summary, 'gap_sensitivity_summary.csv');
