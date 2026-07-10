%% run_comsol_cfd_annual_delta_sweep.m
% Run annual CFD conjugate heat-transfer cases for the main air-gap levels.
%
% This is intentionally separated from the reduced annual resistance model
% because the CFD solve is much more expensive. Start with [0 1 5] mm and a
% daily output step, then refine if the annual trend needs tighter resolution.

function run_comsol_cfd_annual_delta_sweep(runSolver)
    if nargin < 1
        runSolver = true;
    end

    cfg = struct();
    cfg.output_dir = 'COMSOL_EAHE_outputs_CFD_annual_delta_sweep';
    cfg.model_type = "resistance_gap";
    cfg.physics_model = "cfd_sst";
    cfg.study_mode = "annual";
    cfg.delta_mm_list = [0, 1, 5];
    cfg.run_solver = runSolver;
    cfg.save_mph = true;
    cfg.export_field_figures = runSolver;
    cfg.export_local_h_profiles = runSolver;
    cfg.use_mapped_mesh = true;

    % Annual CFD is expensive; daily output is the first review-ready pass.
    cfg.annual_dt_s = 24*3600;
    cfg.annual_end_s = 365*24*3600;
    cfg.mesh_axial_max = 0.75;
    cfg.cfd_air_radial_elems = 24;
    cfg.cfd_boundary_layer_layers = 10;
    cfg.cfd_first_layer_thickness = 5.0e-4;
    cfg.local_h_z_points = [1 5 10 15 20 25 29];
    cfg.local_h_air_r_points = 25;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');

    comsol_eahe_airgap_model(cfg);
end
