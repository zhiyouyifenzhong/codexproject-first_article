% Thermal degradation / heat-saturation validation.
% Compares no-gap and fixed-gap cases over a 30-day continuous operation.

clear; clc;

common.t_end = 30 * 24 * 3600;
common.snapshot_times = [0, 24, 72, 168, 720] * 3600;

fprintf('Running no-gap reference case...\n');
case_no_gap = run_eahe_simulation(struct_merge(common, struct('delta_gap', 0.0)));

fprintf('Running fixed-gap case with reused soil field...\n');
overrides = common;
overrides.delta_gap = 0.002;
overrides.soil_pre = case_no_gap.soil_pre;
case_gap = run_eahe_simulation(overrides);

save('degradation_validation_result.mat', 'case_no_gap', 'case_gap');

figure('Name', 'Thermal degradation - daily mean heat transfer');
plot(case_no_gap.degradation.day, case_no_gap.degradation.Q_day_mean, ...
    'bo-', 'LineWidth', 1.3); hold on;
plot(case_gap.degradation.day, case_gap.degradation.Q_day_mean, ...
    'rs-', 'LineWidth', 1.3);
xlabel('Operation day');
ylabel('Daily mean heat transfer rate / W');
legend('No gap', 'Fixed gap', 'Location', 'best');
grid on;

figure('Name', 'Thermal degradation ratio');
plot(case_no_gap.degradation.day, case_no_gap.degradation.eta_Q_day, ...
    'bo-', 'LineWidth', 1.3); hold on;
plot(case_gap.degradation.day, case_gap.degradation.eta_Q_day, ...
    'rs-', 'LineWidth', 1.3);
xlabel('Operation day');
ylabel('Q day mean / day-1 value');
legend('No gap', 'Fixed gap', 'Location', 'best');
grid on;

figure('Name', 'Near-pipe soil heat accumulation');
plot(case_no_gap.degradation.day, case_no_gap.degradation.near_soil_rise_day_mean, ...
    'bo-', 'LineWidth', 1.3); hold on;
plot(case_gap.degradation.day, case_gap.degradation.near_soil_rise_day_mean, ...
    'rs-', 'LineWidth', 1.3);
xlabel('Operation day');
ylabel('Daily mean near-pipe soil temperature rise / K');
legend('No gap', 'Fixed gap', 'Location', 'best');
grid on;

summary = table( ...
    ["No gap"; "Fixed gap"], ...
    [case_no_gap.degradation.Q_day_mean(1); case_gap.degradation.Q_day_mean(1)], ...
    [case_no_gap.degradation.Q_day_mean(end); case_gap.degradation.Q_day_mean(end)], ...
    [case_no_gap.degradation.eta_Q_day(end); case_gap.degradation.eta_Q_day(end)], ...
    [case_no_gap.degradation.near_soil_rise_day_mean(end); case_gap.degradation.near_soil_rise_day_mean(end)], ...
    'VariableNames', {'Case','Q_day1_W','Q_last_day_W','Eta_Q_last_day','Near_soil_rise_last_day_K'});

disp(summary);
writetable(summary, 'degradation_validation_summary.csv');

function out = struct_merge(a, b)
    out = a;
    names = fieldnames(b);
    for i = 1:numel(names)
        out.(names{i}) = b.(names{i});
    end
end
