% Heat-moisture coupled EAHE cases based on Liu Qinggong operation modes.
% Outputs:
% - heat_moisture_coupling_result.mat
% - heat_moisture_operation_summary.csv
% - heat_moisture_theta_summary.csv
% - figures\heat_moisture\*.png and *.fig

clear; clc; close all;

common.t_end = 7 * 24 * 3600;
common.snapshot_times = [0, 24, 72, 168] * 3600;
common.Tin_mode = 'constant';
common.Tin_const = 38.0;
common.m_dot = 154 / 3600 * 1.20; % 154 m3/h, converted with rho_air = 1.20 kg/m3.
common.T_air_mean = 17.0;
common.T_deep = 17.0;
common.T_air_amp_year = 0.0;
common.T_air_amp_day = 0.0;
common.operation_start_day = 210;

%% 1. Equivalent moisture-property cases under continuous operation.
theta_list = [0.10, 0.20, 0.30];
theta_results = cell(numel(theta_list), 1);
theta_labels = strings(numel(theta_list), 1);

for c = 1:numel(theta_list)
    overrides = common;
    overrides.moisture_model = 'property_only';
    overrides.theta_soil = theta_list(c) * ones(1, 3);
    overrides.theta_ref = 0.20 * ones(1, 3);
    overrides.operation_mode = 'continuous';
    fprintf('Running property-only moisture case: theta = %.2f\n', theta_list(c));
    theta_results{c} = run_eahe_simulation(overrides);
    theta_labels(c) = sprintf('\\theta=%.2f', theta_list(c));
end

%% 2. Operation-mode cases with moisture diffusion enabled.
mode_list = {'continuous', 'liu_60_30', 'liu_60_60'};
mode_labels = {'Continuous', '60 min on / 30 min off', '60 min on / 60 min off'};
mode_results = cell(numel(mode_list), 1);

for c = 1:numel(mode_list)
    overrides = common;
    overrides.moisture_model = 'diffusion';
    overrides.include_latent_heat = true;
    overrides.theta_soil = 0.20 * ones(1, 3);
    overrides.theta_ref = 0.20 * ones(1, 3);
    overrides.operation_mode = mode_list{c};
    fprintf('Running heat-moisture operation case: %s\n', mode_labels{c});
    mode_results{c} = run_eahe_simulation(overrides);
end

%% 3. Latent-heat switch check for model auditing.
latent_flags = [false, true];
latent_results = cell(numel(latent_flags), 1);
latent_labels = strings(numel(latent_flags), 1);
for c = 1:numel(latent_flags)
    overrides = common;
    overrides.moisture_model = 'diffusion';
    overrides.include_latent_heat = latent_flags(c);
    overrides.theta_soil = 0.20 * ones(1, 3);
    overrides.theta_ref = 0.20 * ones(1, 3);
    overrides.operation_mode = 'continuous';
    fprintf('Running latent-heat switch check: include_latent_heat = %d\n', latent_flags(c));
    latent_results{c} = run_eahe_simulation(overrides);
    if latent_flags(c)
        latent_labels(c) = 'Latent heat on';
    else
        latent_labels(c) = 'Latent heat off';
    end
end

save('heat_moisture_coupling_result.mat', ...
    'theta_results', 'theta_list', 'theta_labels', ...
    'mode_results', 'mode_list', 'mode_labels', ...
    'latent_results', 'latent_flags', 'latent_labels');

%% 4. Summary tables.
theta_summary = table(theta_list(:), zeros(numel(theta_list),1), ...
    zeros(numel(theta_list),1), zeros(numel(theta_list),1), zeros(numel(theta_list),1), ...
    'VariableNames', {'theta','Tout_last_day_mean_degC','Q_last_day_mean_W', ...
    'near_soil_rise_last_day_K','theta_near_final'});
for c = 1:numel(theta_list)
    r = theta_results{c};
    last = last_day_indices(r);
    theta_summary.Tout_last_day_mean_degC(c) = mean(r.Tout(last));
    theta_summary.Q_last_day_mean_W(c) = mean(r.Q(last));
    theta_summary.near_soil_rise_last_day_K(c) = mean(r.Tsoil_near_mid_mean(last) - r.Tundist_pipe(last));
    theta_summary.theta_near_final(c) = r.theta_near_mid_mean(end);
end

operation_summary = table(string(mode_labels(:)), zeros(numel(mode_list),1), ...
    zeros(numel(mode_list),1), zeros(numel(mode_list),1), zeros(numel(mode_list),1), ...
    zeros(numel(mode_list),1), true(numel(mode_list),1), ...
    'VariableNames', {'operation_mode','operating_fraction','Tout_on_mean_degC', ...
    'Q_on_mean_W','near_soil_rise_last_day_K','theta_near_final','include_latent_heat'});
for c = 1:numel(mode_list)
    r = mode_results{c};
    on = r.is_operating;
    last = last_day_indices(r);
    operation_summary.operating_fraction(c) = mean(on);
    operation_summary.Tout_on_mean_degC(c) = mean(r.Tout(on));
    operation_summary.Q_on_mean_W(c) = mean(r.Q(on));
    operation_summary.near_soil_rise_last_day_K(c) = mean(r.Tsoil_near_mid_mean(last) - r.Tundist_pipe(last));
    operation_summary.theta_near_final(c) = r.theta_near_mid_mean(end);
end

latent_summary = table(latent_flags(:), zeros(numel(latent_flags),1), ...
    zeros(numel(latent_flags),1), zeros(numel(latent_flags),1), zeros(numel(latent_flags),1), ...
    'VariableNames', {'include_latent_heat','Tout_last_day_mean_degC','Q_last_day_mean_W', ...
    'near_soil_rise_last_day_K','theta_near_final'});
for c = 1:numel(latent_flags)
    r = latent_results{c};
    last = last_day_indices(r);
    latent_summary.Tout_last_day_mean_degC(c) = mean(r.Tout(last));
    latent_summary.Q_last_day_mean_W(c) = mean(r.Q(last));
    latent_summary.near_soil_rise_last_day_K(c) = mean(r.Tsoil_near_mid_mean(last) - r.Tundist_pipe(last));
    latent_summary.theta_near_final(c) = r.theta_near_mid_mean(end);
end

writetable(theta_summary, 'heat_moisture_theta_summary.csv');
writetable(operation_summary, 'heat_moisture_operation_summary.csv');
writetable(latent_summary, 'heat_moisture_latent_summary.csv');
disp(theta_summary);
disp(operation_summary);
disp(latent_summary);

%% 5. Figures.
figure('Name', 'Moisture property effect - outlet temperature');
hold on;
for c = 1:numel(theta_list)
    r = theta_results{c};
    plot(r.time/3600, r.Tout, 'LineWidth', 1.3);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(theta_labels, 'Location', 'best');
grid on;

figure('Name', 'Moisture property effect - heat transfer');
hold on;
for c = 1:numel(theta_list)
    r = theta_results{c};
    plot(r.time/3600, r.Q, 'LineWidth', 1.3);
end
xlabel('Time / h');
ylabel('Heat transfer rate / W');
legend(theta_labels, 'Location', 'best');
grid on;

figure('Name', 'Operation mode effect - outlet temperature');
hold on;
for c = 1:numel(mode_list)
    r = mode_results{c};
    plot(r.time/3600, r.Tout, 'LineWidth', 1.3);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(mode_labels, 'Location', 'best');
grid on;

figure('Name', 'Operation mode effect - near-pipe soil recovery');
hold on;
for c = 1:numel(mode_list)
    r = mode_results{c};
    plot(r.time/3600, r.Tsoil_near_mid_mean - r.Tundist_pipe, 'LineWidth', 1.3);
end
xlabel('Time / h');
ylabel('Near-pipe soil temperature rise / K');
legend(mode_labels, 'Location', 'best');
grid on;

figure('Name', 'Moisture diffusion case - near-pipe water content');
hold on;
for c = 1:numel(mode_list)
    r = mode_results{c};
    plot(r.time/3600, r.theta_near_mid_mean, 'LineWidth', 1.3);
end
xlabel('Time / h');
ylabel('Near-pipe volumetric water content');
legend(mode_labels, 'Location', 'best');
grid on;

figure('Name', 'Latent heat switch check - outlet temperature');
hold on;
for c = 1:numel(latent_flags)
    r = latent_results{c};
    plot(r.time/3600, r.Tout, 'LineWidth', 1.3);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(latent_labels, 'Location', 'best');
grid on;

save_all_open_figures(fullfile('figures', 'heat_moisture'), 'heat_moisture');
close all;

fprintf('\nHeat-moisture coupled cases complete.\n');

function id = last_day_indices(result)
    nPerDay = round(result.param.day / result.param.dt);
    id = max(1, numel(result.time) - nPerDay + 1):numel(result.time);
end
