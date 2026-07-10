% Numerical independence checks for the EAHE RC model.
% Uses a shorter 3-day simulation to keep validation runs manageable.

clear; clc;

common.t_end = 3 * 24 * 3600;
common.snapshot_times = [0, 24, 72] * 3600;

fprintf('Preparing reusable soil field...\n');
base = run_eahe_simulation(common);
soil_pre = base.soil_pre;

%% Time-step independence
dt_list = [60, 300, 600];
dt_results = cell(numel(dt_list), 1);
for k = 1:numel(dt_list)
    overrides = common;
    overrides.dt = dt_list(k);
    overrides.soil_pre = soil_pre;
    fprintf('Running dt validation: dt = %.0f s\n', dt_list(k));
    dt_results{k} = run_eahe_simulation(overrides);
end

ref = dt_results{1};
dt_rmse = zeros(numel(dt_list), 1);
for k = 1:numel(dt_list)
    Tout_ref = interp1(ref.time, ref.Tout, dt_results{k}.time, 'linear');
    dt_rmse(k) = sqrt(mean((dt_results{k}.Tout - Tout_ref).^2));
end
dt_summary = table(dt_list(:), dt_rmse, ...
    'VariableNames', {'dt_s','Tout_RMSE_vs_60s_K'});

%% Axial grid independence
Nx_list = [20, 40, 80];
Nx_results = cell(numel(Nx_list), 1);
for k = 1:numel(Nx_list)
    overrides = common;
    overrides.Nx_pipe = Nx_list(k);
    overrides.soil_pre = soil_pre;
    fprintf('Running axial grid validation: Nx = %d\n', Nx_list(k));
    Nx_results{k} = run_eahe_simulation(overrides);
end
ref = Nx_results{end};
Nx_rmse = zeros(numel(Nx_list), 1);
for k = 1:numel(Nx_list)
    Nx_rmse(k) = sqrt(mean((Nx_results{k}.Tout - ref.Tout).^2));
end
Nx_summary = table(Nx_list(:), Nx_rmse, ...
    'VariableNames', {'Nx_pipe','Tout_RMSE_vs_Nx80_K'});

%% Circumferential sector independence
Ntheta_list = [4, 8, 16];
Ntheta_results = cell(numel(Ntheta_list), 1);
for k = 1:numel(Ntheta_list)
    overrides = common;
    overrides.Ntheta = Ntheta_list(k);
    overrides.soil_pre = soil_pre;
    fprintf('Running circumferential validation: Ntheta = %d\n', Ntheta_list(k));
    Ntheta_results{k} = run_eahe_simulation(overrides);
end
ref = Ntheta_results{end};
Ntheta_rmse = zeros(numel(Ntheta_list), 1);
for k = 1:numel(Ntheta_list)
    Ntheta_rmse(k) = sqrt(mean((Ntheta_results{k}.Tout - ref.Tout).^2));
end
Ntheta_summary = table(Ntheta_list(:), Ntheta_rmse, ...
    'VariableNames', {'Ntheta','Tout_RMSE_vs_Ntheta16_K'});

%% Radial grid independence
Nr_list = [4, 6, 10];
Nr_results = cell(numel(Nr_list), 1);
for k = 1:numel(Nr_list)
    overrides = common;
    overrides.Nr = Nr_list(k);
    overrides.soil_pre = soil_pre;
    fprintf('Running radial validation: Nr = %d\n', Nr_list(k));
    Nr_results{k} = run_eahe_simulation(overrides);
end
ref = Nr_results{end};
Nr_rmse = zeros(numel(Nr_list), 1);
for k = 1:numel(Nr_list)
    Nr_rmse(k) = sqrt(mean((Nr_results{k}.Tout - ref.Tout).^2));
end
Nr_summary = table(Nr_list(:), Nr_rmse, ...
    'VariableNames', {'Nr','Tout_RMSE_vs_Nr10_K'});

save('numerical_validation_result.mat', ...
    'dt_results', 'Nx_results', 'Ntheta_results', 'Nr_results', ...
    'dt_summary', 'Nx_summary', 'Ntheta_summary', 'Nr_summary');

disp(dt_summary);
disp(Nx_summary);
disp(Ntheta_summary);
disp(Nr_summary);

writetable(dt_summary, 'validation_dt_summary.csv');
writetable(Nx_summary, 'validation_Nx_summary.csv');
writetable(Ntheta_summary, 'validation_Ntheta_summary.csv');
writetable(Nr_summary, 'validation_Nr_summary.csv');

figure('Name', 'Time-step independence');
hold on;
for k = 1:numel(dt_list)
    idx = 2:numel(dt_results{k}.time);
    plot(dt_results{k}.time(idx)/3600, dt_results{k}.Tout(idx), 'LineWidth', 1.1);
end
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend(compose('dt = %g s', dt_list), 'Location', 'best');
grid on;

figure('Name', 'Grid independence summary');
tiledlayout(2,2);
nexttile; plot(dt_summary.dt_s, dt_summary.Tout_RMSE_vs_60s_K, 'o-'); grid on; xlabel('dt / s'); ylabel('RMSE / K');
nexttile; plot(Nx_summary.Nx_pipe, Nx_summary.Tout_RMSE_vs_Nx80_K, 'o-'); grid on; xlabel('Nx'); ylabel('RMSE / K');
nexttile; plot(Ntheta_summary.Ntheta, Ntheta_summary.Tout_RMSE_vs_Ntheta16_K, 'o-'); grid on; xlabel('Ntheta'); ylabel('RMSE / K');
nexttile; plot(Nr_summary.Nr, Nr_summary.Tout_RMSE_vs_Nr10_K, 'o-'); grid on; xlabel('Nr'); ylabel('RMSE / K');
