%% run_comsol_30m_matlab_baseline.m
% Run the COMSOL model using the same 30 m baseline parameters as the MATLAB
% reduced-order model.

function run_comsol_30m_matlab_baseline(runSolver)
    if nargin < 1
        runSolver = true;
    end

    cfg = struct();
    cfg.output_dir = 'COMSOL_EAHE_30m_MATLAB_baseline';
    cfg.model_type = "resistance_gap";
    cfg.physics_model = "prescribed_velocity";
    cfg.study_mode = "annual";
    cfg.delta_mm_list = [0, 0.5, 1, 2, 3, 5];
    cfg.run_solver = runSolver;
    cfg.save_mph = true;
    cfg.export_field_figures = runSolver;
    cfg.export_local_h_profiles = false;
    cfg.use_mapped_mesh = true;

    % Same annual time grid as the MATLAB model.
    cfg.annual_dt_s = 6*3600;
    cfg.annual_end_s = 365*24*3600;

    % Same 30 m baseline parameters.
    cfg.L = 30.0;
    cfg.rpi = 0.055;
    cfg.rpo = 0.060;
    cfg.Rs = 1.50;

    cfg.rho_f = 1.20;
    cfg.cp_f = 1006.0;
    cfg.k_air = 0.026;
    cfg.mu_f = 1.81e-5;

    cfg.rho_p = 1400.0;
    cfg.cp_p = 900.0;
    cfg.k_p = 0.40;

    cfg.rho_s = 1800.0;
    cfg.cp_s = 1200.0;
    cfg.k_s = 1.50;

    cfg.rho_gap = 1.20;
    cfg.cp_gap = 1006.0;
    cfg.k_gap = 0.026;

    cfg.Vdot = 0.050;

    cfg.Tin_mean_C = 20.35;
    cfg.A_in_C = 5.65;
    cfg.t_phase_day = 35.0;
    cfg.P_day = 365.0;

    cfg.Tm_C = 19.2;
    cfg.A_s_C = 8.0;
    cfg.H = 2.0;
    cfg.t0_day = 30.0;

    % Mesh settings used for the annual equivalent COMSOL comparison.
    cfg.mesh_axial_max = 0.50;
    cfg.mesh_air_radial_elems = 6;
    cfg.mesh_pipe_radial_elems = 5;
    cfg.mesh_gap_radial_elems_min = 5;
    cfg.mesh_soil_radial_elems = 36;
    cfg.mesh_gap_max = 1.0e-4;
    cfg.mesh_soil_near_max = 0.010;
    cfg.mesh_soil_far_max = 0.120;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');

    comsol_eahe_airgap_model(cfg);
end
