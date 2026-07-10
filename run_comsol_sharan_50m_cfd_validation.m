%% run_comsol_sharan_50m_cfd_validation.m
% CFD validation cases based on Sharan & Jadhav single-pass 50 m EAHE data.

function run_comsol_sharan_50m_cfd_validation(runSolver)
    if nargin < 1
        runSolver = true;
    end

    base = sharan_base_cfg(runSolver);

    may = base;
    may.output_dir = 'COMSOL_Sharan_50m_CFD_May_cooling';
    may.validation_case_name = "Sharan_May_cooling";
    may.short_end_s = 7*3600;
    may.exp_time_s = (0:7)'*3600;
    may.exp_Tin_C = [31.3; 33.7; 36.4; 37.8; 40.8; 40.4; 39.8; 39.6];
    may.exp_Tsoil_C = [26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.5];
    may.exp_Tmid_C = [29.1; 29.2; 29.5; 29.5; 29.7; 29.7; 29.8; 30.0];
    may.exp_Tout_C = [26.8; 26.8; 27.2; 27.2; 27.2; 27.2; 27.2; 27.2];
    comsol_eahe_airgap_model(may);

    jan = base;
    jan.output_dir = 'COMSOL_Sharan_50m_CFD_January_heating';
    jan.validation_case_name = "Sharan_January_heating";
    jan.short_end_s = 12*3600;
    jan.exp_time_s = (0:12)'*3600;
    jan.exp_Tin_C = [19.8; 17.6; 13.3; 11.9; 10.4; 9.6; 9.1; 8.7; 8.3; 8.7; 9.1; 9.6; 9.8];
    jan.exp_Tsoil_C = 24.2*ones(13,1);
    jan.exp_Tmid_C = [22.3; 22.2; 22.1; 21.9; 21.8; 21.7; 21.6; 21.5; 21.5; 21.4; 21.3; 21.2; 21.2];
    jan.exp_Tout_C = [23.4; 23.4; 23.3; 23.3; 23.3; 23.3; 23.2; 23.2; 23.0; 23.0; 22.9; 22.9; 22.8];
    comsol_eahe_airgap_model(jan);

    if runSolver
        summarize_sharan_validation();
    end
end

function cfg = sharan_base_cfg(runSolver)
    cfg = struct();
    cfg.model_type = "resistance_gap";
    cfg.physics_model = "cfd_sst";
    cfg.study_mode = "short_test";
    cfg.temperature_profile = "table";
    cfg.delta_mm_list = 0;
    cfg.run_solver = runSolver;
    cfg.save_mph = true;
    cfg.export_field_figures = runSolver;
    cfg.export_local_h_profiles = runSolver;
    cfg.use_mapped_mesh = true;

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
    cfg.short_dt_s = 600;
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
    cfg.local_h_air_r_points = 31;

    cfg.mesh_axial_max = 1.0;
    cfg.cfd_air_radial_elems = 30;
    cfg.mesh_air_radial_elems = 10;
    cfg.mesh_pipe_radial_elems = 5;
    cfg.mesh_gap_radial_elems_min = 5;
    cfg.mesh_soil_radial_elems = 40;
    cfg.mesh_gap_max = 1.0e-4;
    cfg.mesh_soil_near_max = 0.010;
    cfg.mesh_soil_far_max = 0.150;
    cfg.cfd_boundary_layer_layers = 10;
    cfg.cfd_first_layer_thickness = 2.0e-4;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');
end

function summarize_sharan_validation()
    cases = {
        'COMSOL_Sharan_50m_CFD_May_cooling', 'May_cooling';
        'COMSOL_Sharan_50m_CFD_January_heating', 'January_heating'
        };
    allRows = table();
    metricRows = table();
    for i = 1:size(cases, 1)
        outDir = cases{i, 1};
        caseLabel = string(cases{i, 2});
        valFile = fullfile(outDir, 'COMSOL_experimental_validation.csv');
        if ~exist(valFile, 'file')
            continue
        end
        T = readtable(valFile);
        allRows = [allRows; T]; %#ok<AGROW>
        metricRows = [metricRows; validation_metric_row(T, caseLabel, "Tmid_error_C")]; %#ok<AGROW>
        metricRows = [metricRows; validation_metric_row(T, caseLabel, "Tout_error_C")]; %#ok<AGROW>
    end
    if ~isempty(allRows)
        writetable(allRows, 'COMSOL_Sharan_50m_CFD_validation_all_points.csv');
        writetable(metricRows, 'COMSOL_Sharan_50m_CFD_validation_metrics.csv');
        writetable(allRows, 'COMSOL_Sharan_50m_CFD_validation_summary.xlsx', 'Sheet', 'points');
        writetable(metricRows, 'COMSOL_Sharan_50m_CFD_validation_summary.xlsx', 'Sheet', 'metrics');
    end
end

function row = validation_metric_row(T, caseLabel, errName)
    e = T.(errName);
    e = e(isfinite(e));
    rmse = sqrt(mean(e.^2));
    mae = mean(abs(e));
    bias = mean(e);
    maxAbs = max(abs(e));
    row = table(caseLabel, string(errName), rmse, mae, bias, maxAbs, ...
        'VariableNames', {'case_name','quantity','RMSE_C','MAE_C','bias_C','max_abs_C'});
end
