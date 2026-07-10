%% run_comsol_cfd_annual_delta_sweep_kepsilon_validated.m
% Annual CFD delta sweep using the GUI-validated k-epsilon wall-function route.
%
% This keeps the old annual SST run intact and writes a separate output folder.

function run_comsol_cfd_annual_delta_sweep_kepsilon_validated(runSolver)
    if nargin < 1
        runSolver = true;
    end

    cfg = struct();
    cfg.output_dir = 'COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon';
    cfg.model_type = "resistance_gap";
    cfg.physics_model = "cfd_kepsilon";
    cfg.study_mode = "annual";
    cfg.delta_mm_list = [0, 1, 5];
    cfg.run_solver = runSolver;
    cfg.save_mph = true;
    cfg.export_field_figures = false;
    cfg.export_local_h_profiles = runSolver;
    cfg.use_mapped_mesh = true;
    cfg.use_mass_weighted_temperature = true;

    % Annual CFD review pass: daily output over one year.
    cfg.annual_dt_s = 24*3600;
    cfg.annual_end_s = 365*24*3600;

    % Keep the air-side wall-function mesh in the same range as the validated
    % Sharan pipe benchmark.
    cfg.mesh_axial_max = 0.50;
    cfg.cfd_air_radial_elems = 16;
    cfg.mesh_pipe_radial_elems = 8;
    cfg.mesh_soil_radial_elems = 50;
    cfg.mesh_gap_radial_elems_min = 5;
    cfg.mesh_gap_max = 1.0e-4;
    cfg.mesh_soil_near_max = 0.006;
    cfg.mesh_soil_far_max = 0.120;
    cfg.cfd_boundary_layer_layers = 0;
    cfg.cfd_first_layer_thickness = 0.0;
    cfg.local_h_z_points = [1 5 10 15 20 25 29];
    cfg.local_h_air_r_points = 51;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');

    comsol_eahe_airgap_model(cfg);
end
