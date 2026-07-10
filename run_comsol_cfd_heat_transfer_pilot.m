%% run_comsol_cfd_heat_transfer_pilot.m
% Build and run high-fidelity CFD conjugate heat-transfer pilot cases.
%
% Recommended first use:
%   run_comsol_cfd_heat_transfer_pilot(false)  % build only, checks API keys
%   run_comsol_cfd_heat_transfer_pilot(true)   % solve short-test pilot cases

function run_comsol_cfd_heat_transfer_pilot(runSolver)
    if nargin < 1
        runSolver = true;
    end

    cfg = struct();
    cfg.output_dir = 'COMSOL_EAHE_outputs_CFD_pilot';
    cfg.model_type = "resistance_gap";
    cfg.physics_model = "cfd_sst";
    cfg.study_mode = "short_test";
    cfg.delta_mm_list = [0, 1, 5];
    cfg.run_solver = runSolver;
    cfg.save_mph = true;
    cfg.export_field_figures = runSolver;
    cfg.use_mapped_mesh = true;

    % Keep the first CFD run modest. Increase after the pilot converges.
    cfg.short_dt_s = 6*3600;
    cfg.short_end_s = 7*24*3600;
    cfg.mesh_axial_max = 0.75;
    cfg.cfd_air_radial_elems = 24;
    cfg.cfd_boundary_layer_layers = 10;
    cfg.cfd_first_layer_thickness = 5.0e-4;

    % LiveLink settings. If MATLAB is already connected to COMSOL, set
    % auto_mphstart=false or leave these fields unused.
    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');

    comsol_eahe_airgap_model(cfg);
end
