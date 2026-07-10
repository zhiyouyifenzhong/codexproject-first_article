% Validation against Ozgener et al. (2011), Int. Commun. Heat Mass Transfer.
% The experiment is represented as a reduced homogeneous-soil, no-gap,
% steady-inlet case to match the assumptions used in the reference paper.

clear; clc; close all;

exp.L_pipe = 47.0;
exp.D_i = 0.56;
exp.D_o = 0.565;          % nominal galvanized wall, used only as a small thermal mass
exp.z_pipe = 3.0;
exp.k_soil = 2.85;
exp.m_dot = 1.64;
exp.Tin_mean = 33.27;
exp.Tout_mean = 31.01;
exp.Tf_mean = 32.14;
exp.Tw_mean = 28.21;
exp.Rtot_avg = 0.021;
exp.q_l_reported = 0.34e3;

overrides.L_pipe = exp.L_pipe;
overrides.Nx_pipe = 47;
overrides.D_i = exp.D_i;
overrides.D_o = exp.D_o;
overrides.z_pipe = exp.z_pipe;
overrides.r_soil_max = 2.8;
overrides.delta_gap = 0.0;
overrides.k_pipe = 50.0;      % galvanized steel, pipe wall resistance is small
overrides.k_soil = [exp.k_soil, exp.k_soil, exp.k_soil];
overrides.rho_soil = [1700.0, 1700.0, 1700.0];
overrides.cp_soil = [1400.0, 1400.0, 1400.0];
overrides.m_dot = exp.m_dot;
overrides.Tin_mode = 'constant';
overrides.Tin_const = exp.Tin_mean;
overrides.T_air_mean = exp.Tw_mean;
overrides.T_air_amp_year = 0.0;
overrides.T_air_amp_day = 0.0;
overrides.T_deep = exp.Tw_mean;
overrides.operation_start_day = 285;
overrides.t_end = 10 * 24 * 3600;
overrides.dt = 600;
overrides.snapshot_times = [0, 24, 120, 240] * 3600;

fprintf('Running Ozgener 2011 reduced validation case...\n');
result = run_eahe_simulation(overrides);

idx = result.time >= (result.time(end) - 24 * 3600);
Tf = 0.5 * (result.Tin + result.Tout);
q_l = result.Q / exp.L_pipe;
R_fluid_wall = (Tf - result.Tpipe_mid) ./ q_l;
R_fluid_far = (Tf - result.Tundist_pipe) ./ q_l;

summary = table( ...
    exp.Rtot_avg, ...
    mean(R_fluid_wall(idx), 'omitnan'), ...
    mean(R_fluid_far(idx), 'omitnan'), ...
    mean(result.Tout(idx), 'omitnan'), ...
    exp.Tout_mean, ...
    mean(result.Q(idx), 'omitnan') / 1000, ...
    'VariableNames', {'Rtot_exp_avg_K_m_W','R_fluid_wall_model_K_m_W', ...
    'R_fluid_far_model_K_m_W','Tout_model_degC','Tout_exp_mean_degC', ...
    'Q_model_kW'});

disp(summary);
writetable(summary, 'ozgener2011_validation_summary.csv');

time_h = result.time / 3600;
model_series = table(time_h, result.Tin, result.Tout, result.Tpipe_mid, ...
    result.Tundist_pipe, result.Q, q_l, R_fluid_wall, R_fluid_far, ...
    'VariableNames', {'time_h','Tin_degC','Tout_degC','Tpipe_mid_degC', ...
    'Tundist_pipe_degC','Q_W','q_l_W_m','R_fluid_wall_K_m_W', ...
    'R_fluid_far_K_m_W'});
writetable(model_series, 'ozgener2011_model_rtot.csv');
save('ozgener2011_validation_result.mat', 'result', 'exp', 'summary', 'model_series');

figure('Name', 'Ozgener 2011 validation - equivalent resistance');
plot(time_h, R_fluid_wall, 'b-', 'LineWidth', 1.2); hold on;
yline(exp.Rtot_avg, 'r--', 'Reported average R_{Tot}');
xlabel('Time / h');
ylabel('Equivalent resistance / K m W^{-1}');
legend('Model: (T_f - T_w) / q_l', 'Reference average', 'Location', 'best');
grid on;

figure('Name', 'Ozgener 2011 validation - outlet temperature');
plot(time_h, result.Tout, 'b-', 'LineWidth', 1.2); hold on;
yline(exp.Tout_mean, 'r--', 'Reported mean outlet temperature');
xlabel('Time / h');
ylabel('Outlet air temperature / degC');
legend('Model', 'Experiment mean', 'Location', 'best');
grid on;

save_all_open_figures(fullfile('figures', 'ozgener2011_validation'), 'ozgener2011_validation');
