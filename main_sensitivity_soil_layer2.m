% Second-layer soil thermal conductivity sensitivity analysis.
% The pipe is located in layer 2, so k_soil(2) is a key parameter.

clear; clc;

k2_list = [0.8, 1.2, 1.55, 2.0, 2.5]; % W/(m K)
nCase = numel(k2_list);

results = cell(nCase, 1);
labels = strings(nCase, 1);

for c = 1:nCase
    overrides.k_soil = [1.10, k2_list(c), 1.80];
    fprintf('Running layer-2 soil conductivity case %d/%d: k2 = %.2f W/(m K)\n', ...
        c, nCase, k2_list(c));
    results{c} = run_eahe_simulation(overrides);
    labels(c) = sprintf('k_2=%.2f W/(m K)', k2_list(c));
end

save('soil_layer2_sensitivity_result.mat', 'results', 'k2_list', 'labels');

figure('Name', 'Layer-2 soil conductivity sensitivity - outlet temperature');
hold on;
for c = 1:nCase
    idx = 2:numel(results{c}.time);
    plot(results{c}.time(idx)/3600, results{c}.Tout(idx), 'LineWidth', 1.2);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(labels, 'Location', 'best');
grid on;

figure('Name', 'Layer-2 soil conductivity sensitivity - daily heat transfer');
hold on;
for c = 1:nCase
    plot(results{c}.degradation.day, results{c}.degradation.Q_day_mean, ...
        'o-', 'LineWidth', 1.2);
end
xlabel('Operation day');
ylabel('Daily mean heat transfer rate / W');
legend(labels, 'Location', 'best');
grid on;

summary = table(k2_list(:), zeros(nCase,1), zeros(nCase,1), zeros(nCase,1), zeros(nCase,1), ...
    'VariableNames', {'k_soil2_W_mK','Tout_final_degC','Q_last_day_W','Eta_Q_last_day','Near_soil_rise_last_day_K'});
for c = 1:nCase
    summary.Tout_final_degC(c) = results{c}.Tout(end);
    summary.Q_last_day_W(c) = results{c}.degradation.Q_day_mean(end);
    summary.Eta_Q_last_day(c) = results{c}.degradation.eta_Q_day(end);
    summary.Near_soil_rise_last_day_K(c) = results{c}.degradation.near_soil_rise_day_mean(end);
end

disp(summary);
writetable(summary, 'soil_layer2_sensitivity_summary.csv');
