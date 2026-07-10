%% run_comsol_sharan_50m_cfd_kepsilon_validated.m
% Sharan 50 m EAHE CFD validation using the GUI-validated k-epsilon
% wall-function route.
%
% This does not overwrite the previous SST runs. The air-side pipe benchmark
% showed that k-epsilon + wall functions can reproduce Gnielinski h within
% 3.2%, so this runner tests the same route in the full pipe-wall-soil model.

function run_comsol_sharan_50m_cfd_kepsilon_validated(runSolver)
    if nargin < 1
        runSolver = true;
    end

    base = sharan_kepsilon_base_cfg(runSolver);

    may = base;
    may.output_dir = 'COMSOL_Sharan_50m_CFD_kepsilon_May_cooling';
    may.validation_case_name = "Sharan_May_cooling_kepsilon";
    may.short_end_s = 7*3600;
    may.exp_time_s = (0:7)'*3600;
    may.exp_Tin_C = [31.3; 33.7; 36.4; 37.8; 40.8; 40.4; 39.8; 39.6];
    may.exp_Tsoil_C = [26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.5];
    may.exp_Tmid_C = [29.1; 29.2; 29.5; 29.5; 29.7; 29.7; 29.8; 30.0];
    may.exp_Tout_C = [26.8; 26.8; 27.2; 27.2; 27.2; 27.2; 27.2; 27.2];
    comsol_eahe_airgap_model(may);

    jan = base;
    jan.output_dir = 'COMSOL_Sharan_50m_CFD_kepsilon_January_heating';
    jan.validation_case_name = "Sharan_January_heating_kepsilon";
    jan.short_end_s = 12*3600;
    jan.exp_time_s = (0:12)'*3600;
    jan.exp_Tin_C = [19.8; 17.6; 13.3; 11.9; 10.4; 9.6; 9.1; 8.7; 8.3; 8.7; 9.1; 9.6; 9.8];
    jan.exp_Tsoil_C = 24.2*ones(13,1);
    jan.exp_Tmid_C = [22.3; 22.2; 22.1; 21.9; 21.8; 21.7; 21.6; 21.5; 21.5; 21.4; 21.3; 21.2; 21.2];
    jan.exp_Tout_C = [23.4; 23.4; 23.3; 23.3; 23.3; 23.3; 23.2; 23.2; 23.0; 23.0; 22.9; 22.9; 22.8];
    comsol_eahe_airgap_model(jan);

    if runSolver
        summarize_sharan_kepsilon_validation();
    end
end

function cfg = sharan_kepsilon_base_cfg(runSolver)
    cfg = struct();
    cfg.model_type = "resistance_gap";
    cfg.physics_model = "cfd_kepsilon";
    cfg.study_mode = "short_test";
    cfg.temperature_profile = "table";
    cfg.delta_mm_list = 0;
    cfg.run_solver = runSolver;
    cfg.save_mph = true;
    cfg.export_field_figures = false;
    cfg.export_local_h_profiles = runSolver;
    cfg.use_mapped_mesh = true;
    cfg.use_mass_weighted_temperature = true;

    cfg.L = 50.0;
    cfg.rpi = 0.050;
    cfg.rpo = 0.053;
    cfg.Rs = 2.00;

    cfg.rho_f = 0.0975/0.0863;
    cfg.cp_f = 1006.0;
    cfg.k_air = 0.026;
    cfg.mu_f = 1.85e-5;

    cfg.rho_p = 7850.0;
    cfg.cp_p = 470.0;
    cfg.k_p = 45.0;

    cfg.rho_s = 1800.0;
    cfg.cp_s = 1200.0;
    cfg.k_s = 1.50;

    cfg.rho_gap = cfg.rho_f;
    cfg.cp_gap = cfg.cp_f;
    cfg.k_gap = cfg.k_air;

    cfg.Vdot = 0.0863;
    cfg.turbulence_intensity = 0.05;
    cfg.turbulent_length_scale_factor = 0.07;
    cfg.turbulent_prandtl = 0.85;

    cfg.day_s = 24*3600;
    cfg.short_dt_s = 300;
    cfg.P_day = 365.0;
    cfg.Tin_mean_C = 20.0;
    cfg.A_in_C = 1.0;
    cfg.t_phase_day = 0.0;
    cfg.Tm_C = 24.0;
    cfg.A_s_C = 0.0;
    cfg.H = 3.0;
    cfg.t0_day = 0.0;

    cfg.validation_z_m = 25.0;
    cfg.local_h_z_points = [1 5 10 15 20 25 30 40 49];
    cfg.local_h_air_r_points = 51;

    % k-epsilon wall-function route: keep y+ in the wall-function range.
    cfg.mesh_axial_max = 50.0/160.0;
    cfg.cfd_air_radial_elems = 16;
    cfg.mesh_air_radial_elems = 12;
    cfg.mesh_pipe_radial_elems = 8;
    cfg.mesh_gap_radial_elems_min = 5;
    cfg.mesh_soil_radial_elems = 50;
    cfg.mesh_gap_max = 1.0e-4;
    cfg.mesh_soil_near_max = 0.006;
    cfg.mesh_soil_far_max = 0.120;
    cfg.cfd_boundary_layer_layers = 0;
    cfg.cfd_first_layer_thickness = 0.0;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');
end

function summarize_sharan_kepsilon_validation()
    cases = {
        'COMSOL_Sharan_50m_CFD_kepsilon_May_cooling', 'Sharan_May_cooling_kepsilon';
        'COMSOL_Sharan_50m_CFD_kepsilon_January_heating', 'Sharan_January_heating_kepsilon'
        };
    allRows = table();
    metricRows = table();
    energyRows = table();
    for i = 1:size(cases, 1)
        outDir = cases{i, 1};
        caseLabel = string(cases{i, 2});
        valFile = fullfile(outDir, 'COMSOL_experimental_validation.csv');
        tsFile = fullfile(outDir, 'COMSOL_case_resistance_gap_delta_0mm.csv');
        if exist(valFile, 'file')
            T = readtable(valFile);
            allRows = [allRows; T]; %#ok<AGROW>
            metricRows = [metricRows; validation_metric_row(T, caseLabel, "Tmid_error_C")]; %#ok<AGROW>
            metricRows = [metricRows; validation_metric_row(T, caseLabel, "Tout_error_C")]; %#ok<AGROW>
        end
        if exist(tsFile, 'file')
            TS = readtable(tsFile);
            energyRows = [energyRows; energy_row(TS, caseLabel)]; %#ok<AGROW>
        end
    end

    if ~isempty(allRows)
        writetable(allRows, 'COMSOL_Sharan_50m_CFD_kepsilon_all_points.csv');
    end
    if ~isempty(metricRows)
        writetable(metricRows, 'COMSOL_Sharan_50m_CFD_kepsilon_metrics.csv');
    end
    if ~isempty(energyRows)
        writetable(energyRows, 'COMSOL_Sharan_50m_CFD_kepsilon_energy.csv');
    end
    if ~isempty(allRows)
        writetable(allRows, 'COMSOL_Sharan_50m_CFD_kepsilon_summary.xlsx', 'Sheet', 'points');
    end
    if ~isempty(metricRows)
        writetable(metricRows, 'COMSOL_Sharan_50m_CFD_kepsilon_summary.xlsx', 'Sheet', 'metrics');
    end
    if ~isempty(energyRows)
        writetable(energyRows, 'COMSOL_Sharan_50m_CFD_kepsilon_summary.xlsx', 'Sheet', 'energy');
    end
end

function row = validation_metric_row(T, caseLabel, errName)
    e = T.(errName);
    e = e(isfinite(e));
    row = table(caseLabel, string(errName), sqrt(mean(e.^2)), mean(abs(e)), ...
        mean(e), max(abs(e)), ...
        'VariableNames', {'case_name','quantity','RMSE_C','MAE_C','bias_C','max_abs_C'});
end

function row = energy_row(TS, caseLabel)
    q = TS.Q_W;
    t = TS.t_day*24*3600;
    Eabs = trapz(t, abs(q))/3.6e6;
    E_signed = trapz(t, q)/3.6e6;
    Qmean = mean(q);
    hMean = mean(TS.h_eq_global_W_m2K(isfinite(TS.h_eq_global_W_m2K)));
    row = table(caseLabel, Eabs, E_signed, Qmean, hMean, ...
        'VariableNames', {'case_name','Eabs_kWh','Esigned_kWh','Qmean_W','h_eq_mean_W_m2K'});
end
