function comsol_eahe_airgap_model(userCfg)
%COMSOL_EAHE_AIRGAP_MODEL Build and run COMSOL EAHE air-gap validation cases.
%
% This script uses COMSOL LiveLink for MATLAB to build a 2D axisymmetric
% transient conjugate heat-transfer model of a straight EAHE pipe. It runs two
% model families:
%   1) explicit_gap: an actual annular air-gap domain is included.
%   2) resistance_gap: the gap is represented by an equivalent thermal
%      resistance/thin-layer boundary.
%
% The script exports CSV files only from solved COMSOL data. Failed cases are
% recorded in COMSOL_failed_cases.csv and are filled with NaN in combined
% sweep tables.
%
% Usage examples:
%   comsol_eahe_airgap_model
%   comsol_eahe_airgap_model(struct('comsol_mli_path', ...
%       'G:\COMSOL\COMSOL63\Multiphysics\mli', 'mphserver_port', 2036))
%   comsol_eahe_airgap_model(struct('study_mode',"annual"))
%   comsol_eahe_airgap_model(struct('model_type',"explicit_gap", ...
%       'delta_mm_list',[0 1 3], 'study_mode',"short_test"))

    if nargin < 1
        userCfg = struct();
    end

    cfg = eahe_default_config();
    cfg = apply_user_config(cfg, userCfg);
    if isempty(cfg.run_id)
        cfg.run_id = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    end
    ensure_output_dir(cfg.output_dir);
    setup_livelink_if_requested(cfg);

    import com.comsol.model.*
    import com.comsol.model.util.*

    try
        ModelUtil.showProgress(true);
    catch
        % showProgress is available in most LiveLink versions, but not all.
    end

    modelTypes = requested_model_types(cfg.model_type);
    tSec = make_time_vector(cfg);
    tDay = tSec(:) / cfg.day_s;
    TinC = tin_celsius(tSec(:), cfg);

    toutTable = table(tDay, TinC, 'VariableNames', {'t_day','Tin_C'});
    qTable = table(tDay, 'VariableNames', {'t_day'});
    interfaceTable = table();
    validationTable = table();
    annualRows = table();
    failedRows = table();

    fprintf('COMSOL EAHE numerical validation started.\n');
    fprintf('Study mode: %s, number of time points: %d\n', cfg.study_mode, numel(tSec));

    maxCases = numel(modelTypes) * numel(cfg.delta_mm_list);
    caseResults = repmat(struct('name', "", 'model_type', "", 'delta_mm', NaN, 'raw', []), maxCases, 1);
    caseCount = 0;

    for iType = 1:numel(modelTypes)
        modelType = modelTypes{iType};
        for iDelta = 1:numel(cfg.delta_mm_list)
            deltaMm = cfg.delta_mm_list(iDelta);
            caseName = sprintf('%s_delta_%s', modelType, delta_token(deltaMm));
            fprintf('\nRunning %s (delta = %.4g mm)\n', modelType, deltaMm);

            try
                model = build_eahe_case_model(cfg, modelType, deltaMm);
                if ~cfg.run_solver
                    if cfg.save_mph
                        try
                            mphsave(model, fullfile(cfg.output_dir, ...
                                sprintf('COMSOL_case_%s_built_only_%s.mph', caseName, cfg.run_id)));
                        catch saveME
                            warning('Built-only model was created, but mphsave failed for %s: %s', ...
                                caseName, saveME.message);
                        end
                    end
                    fprintf('Built model only; solver skipped for %s.\n', caseName);
                    try
                        ModelUtil.remove(model.tag);
                    catch
                    end
                    continue
                end
                model.study('std1').run;
                raw = extract_case_outputs(model, cfg, modelType, deltaMm, tSec);
                if cfg.export_field_figures
                    export_case_field_figures(model, cfg, modelType, deltaMm, tSec);
                end

                caseCount = caseCount + 1;
                caseResults(caseCount).name = string(caseName);
                caseResults(caseCount).model_type = string(modelType);
                caseResults(caseCount).delta_mm = deltaMm;
                caseResults(caseCount).raw = raw;

                toutCol = sprintf('Tout_%s_delta_%s_C', model_prefix(modelType), delta_token(deltaMm));
                qCol = sprintf('Q_%s_delta_%s_W', model_prefix(modelType), delta_token(deltaMm));
                toutTable.(toutCol) = raw.Tout_C(:);
                qTable.(qCol) = raw.Q_W(:);
                interfaceTable = [interfaceTable; raw.interface]; %#ok<AGROW>
                if isfield(raw, 'validation') && ~isempty(raw.validation)
                    validationTable = [validationTable; raw.validation]; %#ok<AGROW>
                end

                annualRows = [annualRows; annual_energy_row(raw, cfg, modelType, deltaMm)]; %#ok<AGROW>

                writetable(raw.time_series, fullfile(cfg.output_dir, ...
                    sprintf('COMSOL_case_%s.csv', caseName)));
                if isfield(raw, 'local_h') && ~isempty(raw.local_h)
                    localHFile = fullfile(cfg.output_dir, ...
                        sprintf('COMSOL_local_h_%s.csv', caseName));
                    writetable(raw.local_h, localHFile);
                    export_local_h_profile_figure(raw.local_h, cfg, modelType, deltaMm);
                end

                if cfg.save_mph
                    try
                        mphsave(model, fullfile(cfg.output_dir, ...
                            sprintf('COMSOL_case_%s_%s.mph', caseName, cfg.run_id)));
                    catch saveME
                        warning('Solved case was exported, but mphsave failed for %s: %s', ...
                            caseName, saveME.message);
                    end
                end

                try
                    ModelUtil.remove(model.tag);
                catch
                    % The tag removal method is version-sensitive. Not fatal.
                end
            catch ME
                warning('COMSOL case failed: %s, delta %.4g mm. %s', ...
                    modelType, deltaMm, ME.message);

                toutCol = sprintf('Tout_%s_delta_%s_C', model_prefix(modelType), delta_token(deltaMm));
                qCol = sprintf('Q_%s_delta_%s_W', model_prefix(modelType), delta_token(deltaMm));
                toutTable.(toutCol) = nan(size(tDay));
                qTable.(qCol) = nan(size(tDay));

                failedRows = [failedRows; table( ...
                    string(modelType), deltaMm, string(ME.identifier), string(ME.message), ...
                    'VariableNames', {'model_type','delta_mm','identifier','message'})]; %#ok<AGROW>
            end
        end
    end

    caseResults = caseResults(1:caseCount);
    annualRows = add_dgap_to_annual_rows(annualRows);
    compareRows = build_explicit_resistance_comparison(caseResults, cfg);

    if ~cfg.run_solver
        fprintf('\nBuilt-only run complete. Result CSV files were not overwritten.\n');
        return
    end

    writetable(toutTable, fullfile(cfg.output_dir, 'COMSOL_Tout_delta_sweep.csv'));
    writetable(qTable, fullfile(cfg.output_dir, 'COMSOL_Q_delta_sweep.csv'));
    if ~isempty(interfaceTable)
        writetable(interfaceTable, fullfile(cfg.output_dir, 'COMSOL_interface_jump.csv'));
    else
        write_empty_interface_table(cfg.output_dir);
    end
    if ~isempty(validationTable)
        writetable(validationTable, fullfile(cfg.output_dir, 'COMSOL_experimental_validation.csv'));
    end
    if ~isempty(annualRows)
        writetable(annualRows, fullfile(cfg.output_dir, 'COMSOL_annual_energy_summary.csv'));
    else
        write_empty_annual_table(cfg.output_dir);
    end
    if ~isempty(compareRows)
        writetable(compareRows, fullfile(cfg.output_dir, 'COMSOL_explicit_vs_resistance_gap.csv'));
    else
        write_empty_comparison_table(cfg.output_dir);
    end
    if ~isempty(failedRows)
        writetable(failedRows, fullfile(cfg.output_dir, 'COMSOL_failed_cases.csv'));
    else
        failedFile = fullfile(cfg.output_dir, 'COMSOL_failed_cases.csv');
        if exist(failedFile, 'file')
            delete(failedFile);
        end
    end

    fprintf('\nCOMSOL EAHE export complete. Output directory: %s\n', cfg.output_dir);
end

function cfg = eahe_default_config()
    cfg.output_dir = 'COMSOL_EAHE_outputs';
    cfg.run_id = '';                      % auto-filled and used in MPH filenames
    cfg.comsol_mli_path = '';             % Example: G:\COMSOL\COMSOL63\Multiphysics\mli
    cfg.auto_mphstart = false;            % true to call mphstart before ModelUtil imports
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = '';
    cfg.mphserver_password = '';
    cfg.run_solver = true;                % false builds geometry/physics/mesh/study only
    cfg.export_field_figures = false;     % true exports geometry and temperature contour PNGs
    cfg.export_local_h_profiles = true;   % true exports CFD local wall heat-transfer profiles
    cfg.use_mass_weighted_temperature = false; % true: sample rho*cp*u_z*T weighted air bulk temperature
    cfg.field_figure_dir = '';            % empty => <output_dir>/field_figures
    cfg.field_r_points = 140;
    cfg.field_z_points = 260;
    cfg.local_h_z_points = [1 5 10 15 20 25 29];
    cfg.local_h_air_r_points = 25;
    cfg.validation_z_m = [];
    cfg.temperature_profile = "annual_sinusoid"; % "annual_sinusoid" or "table"
    cfg.exp_time_s = [];
    cfg.exp_Tin_C = [];
    cfg.exp_Tsoil_C = [];
    cfg.exp_Tmid_C = [];
    cfg.exp_Tout_C = [];
    cfg.validation_case_name = "";
    cfg.model_type = "both";              % "both", "explicit_gap", "resistance_gap"
    cfg.study_mode = "short_test";        % "short_test" or "annual"
    cfg.physics_model = "prescribed_velocity"; % "prescribed_velocity", "cfd_sst", "cfd_kepsilon", or "cfd_laminar"
    cfg.delta_mm_list = [0, 0.5, 1, 2, 3, 5];
    cfg.save_mph = false;
    cfg.use_mapped_mesh = true;           % structured quad mesh for thin annular layers

    % Geometry, SI units.
    cfg.L = 30.0;                         % m
    cfg.rpi = 0.055;                      % m
    cfg.rpo = 0.060;                      % m
    cfg.Rs = 1.50;                        % m

    % Fluid and material properties.
    cfg.rho_f = 1.20;                     % kg/m^3
    cfg.cp_f = 1006.0;                    % J/(kg K)
    cfg.k_air = 0.026;                    % W/(m K)
    cfg.mu_f = 1.81e-5;                   % Pa*s

    cfg.rho_p = 1400.0;                   % kg/m^3
    cfg.cp_p = 900.0;                     % J/(kg K)
    cfg.k_p = 0.40;                       % W/(m K)

    cfg.rho_s = 1800.0;                   % kg/m^3
    cfg.cp_s = 1200.0;                    % J/(kg K)
    cfg.k_s = 1.50;                       % W/(m K)

    cfg.rho_gap = 1.20;                   % kg/m^3
    cfg.cp_gap = 1006.0;                  % J/(kg K)
    cfg.k_gap = 0.026;                    % W/(m K)

    % Flow.
    cfg.Vdot = 0.050;                     % m^3/s
    cfg.mdot = cfg.rho_f * cfg.Vdot;      % kg/s
    cfg.turbulence_intensity = 0.05;      % inlet turbulence intensity
    cfg.turbulent_length_scale_factor = 0.07; % Lt = factor*D
    cfg.turbulent_prandtl = 0.85;         % common turbulent Prandtl number

    % Boundary temperatures.
    cfg.Tin_mean_C = 20.35;               % degC
    cfg.A_in_C = 5.65;                    % K
    cfg.t_phase_day = 35.0;               % day
    cfg.P_day = 365.0;                    % day

    cfg.Tm_C = 19.2;                      % degC
    cfg.A_s_C = 8.0;                      % K
    cfg.H = 2.0;                          % m
    cfg.t0_day = 30.0;                    % day

    % Time modes.
    cfg.day_s = 24 * 3600;
    cfg.short_dt_s = 3600;
    cfg.short_end_s = 30 * cfg.day_s;
    cfg.annual_dt_s = 6 * 3600;
    cfg.annual_end_s = 365 * cfg.day_s;

    % Mesh controls.
    cfg.mesh_air_max = 0.020;             % m
    cfg.mesh_pipe_max = 0.0010;           % m
    cfg.mesh_gap_max = 0.00010;           % m, important for delta = 0.5 mm
    cfg.mesh_soil_near_max = 0.010;       % m
    cfg.mesh_soil_far_max = 0.120;        % m
    cfg.mesh_axial_max = 0.50;            % m, mapped mesh axial element length
    cfg.mesh_air_radial_elems = 6;
    cfg.mesh_pipe_radial_elems = 5;
    cfg.mesh_gap_radial_elems_min = 5;
    cfg.mesh_soil_radial_elems = 36;
    cfg.cfd_air_radial_elems = 24;
    cfg.cfd_boundary_layer_layers = 10;
    cfg.cfd_boundary_layer_stretch = 1.20;
    cfg.cfd_first_layer_thickness = 5.0e-4;

    % Numerical extraction offsets, used to evaluate temperatures on each
    % side of an interface without relying on version-specific boundary
    % variables.
    cfg.eval_eps = 1.0e-6;                % m
end

function setup_livelink_if_requested(cfg)
    if ~isempty(cfg.comsol_mli_path)
        addpath(cfg.comsol_mli_path);
    end

    if ~cfg.auto_mphstart
        return
    end

    if isempty(which('mphstart'))
        error(['mphstart was not found. Set cfg.comsol_mli_path to the COMSOL mli folder, ' ...
            'for example G:\COMSOL\COMSOL63\Multiphysics\mli.']);
    end

    try
        if ~isempty(cfg.mphserver_user)
            mphstart(cfg.mphserver_host, cfg.mphserver_port, ...
                cfg.mphserver_user, cfg.mphserver_password);
        else
            mphstart(cfg.mphserver_host, cfg.mphserver_port);
        end
    catch ME
        if contains(ME.message, 'Already connected', 'IgnoreCase', true)
            fprintf('MATLAB is already connected to a COMSOL server; reusing the existing connection.\n');
        else
            rethrow(ME);
        end
    end
end

function cfg = apply_user_config(cfg, userCfg)
    if isempty(userCfg)
        return
    end
    names = fieldnames(userCfg);
    for i = 1:numel(names)
        cfg.(names{i}) = userCfg.(names{i});
    end
    cfg.mdot = cfg.rho_f * cfg.Vdot;
end

function modelTypes = requested_model_types(modelType)
    modelType = string(modelType);
    if strcmpi(modelType, "both")
        modelTypes = {'explicit_gap','resistance_gap'};
    elseif any(strcmpi(modelType, ["explicit_gap","resistance_gap"]))
        modelTypes = {char(modelType)};
    else
        error('Unknown model_type: %s', modelType);
    end
end

function ensure_output_dir(outputDir)
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
end

function tSec = make_time_vector(cfg)
    switch lower(string(cfg.study_mode))
        case "short_test"
            tSec = 0:cfg.short_dt_s:cfg.short_end_s;
        case "annual"
            tSec = 0:cfg.annual_dt_s:cfg.annual_end_s;
        otherwise
            error('Unknown study_mode: %s', cfg.study_mode);
    end
end

function model = build_eahe_case_model(cfg, modelType, deltaMm)
    import com.comsol.model.*
    import com.comsol.model.util.*

    delta = deltaMm * 1.0e-3;
    hasExplicitGap = strcmpi(modelType, 'explicit_gap') && delta > 0;
    rg = cfg.rpo + delta;

    tag = matlab.lang.makeValidName(sprintf('EAHE_%s_%s', modelType, delta_token(deltaMm)));
    model = ModelUtil.create(tag);
    model.modelPath(pwd);
    model.label(sprintf('EAHE %s delta %.4g mm', modelType, deltaMm));

    comp = model.component.create('comp1', true);
    geom = comp.geom.create('geom1', 2);
    geom.axisymmetric(true);
    geom.lengthUnit('m');

    set_case_parameters(model, cfg, deltaMm, delta, rg);

    % COMSOL axisymmetric 2D coordinates are x = r and y = z.
    create_rectangle(geom, 'air_dom',  0.0,     0.0, cfg.rpi,           cfg.L);
    create_rectangle(geom, 'pipe_dom', cfg.rpi, 0.0, cfg.rpo - cfg.rpi, cfg.L);
    if hasExplicitGap
        create_rectangle(geom, 'gap_dom',  cfg.rpo, 0.0, delta,       cfg.L);
        create_rectangle(geom, 'soil_dom', rg,      0.0, cfg.Rs - rg, cfg.L);
    else
        create_rectangle(geom, 'soil_dom', cfg.rpo, 0.0, cfg.Rs - cfg.rpo, cfg.L);
    end
    geom.run;

    sel = make_selections(model, cfg, hasExplicitGap, rg);
    add_materials(model, sel, hasExplicitGap);
    add_heat_transfer_physics(model, cfg, sel, modelType, delta);
    add_mesh(model, cfg, sel, hasExplicitGap, delta);
    add_average_and_variables(model, sel);
    add_transient_study(model, cfg);
end

function set_case_parameters(model, cfg, deltaMm, delta, rg)
    p = model.param;
    p.set('L', sprintf('%.16g[m]', cfg.L));
    p.set('rpi', sprintf('%.16g[m]', cfg.rpi));
    p.set('rpo', sprintf('%.16g[m]', cfg.rpo));
    p.set('delta', sprintf('%.16g[m]', delta));
    p.set('delta_mm', sprintf('%.16g', deltaMm));
    p.set('rg', sprintf('%.16g[m]', rg));
    p.set('Rs', sprintf('%.16g[m]', cfg.Rs));

    p.set('rho_f', sprintf('%.16g[kg/m^3]', cfg.rho_f));
    p.set('cp_f', sprintf('%.16g[J/(kg*K)]', cfg.cp_f));
    p.set('k_air', sprintf('%.16g[W/(m*K)]', cfg.k_air));
    p.set('mu_f', sprintf('%.16g[Pa*s]', cfg.mu_f));
    p.set('rho_p', sprintf('%.16g[kg/m^3]', cfg.rho_p));
    p.set('cp_p', sprintf('%.16g[J/(kg*K)]', cfg.cp_p));
    p.set('k_p', sprintf('%.16g[W/(m*K)]', cfg.k_p));
    p.set('rho_s', sprintf('%.16g[kg/m^3]', cfg.rho_s));
    p.set('cp_s', sprintf('%.16g[J/(kg*K)]', cfg.cp_s));
    p.set('k_s', sprintf('%.16g[W/(m*K)]', cfg.k_s));
    p.set('rho_gap', sprintf('%.16g[kg/m^3]', cfg.rho_gap));
    p.set('cp_gap', sprintf('%.16g[J/(kg*K)]', cfg.cp_gap));
    p.set('k_gap', sprintf('%.16g[W/(m*K)]', cfg.k_gap));

    p.set('Vdot', sprintf('%.16g[m^3/s]', cfg.Vdot));
    p.set('mdot', 'rho_f*Vdot');
    p.set('u_z', 'Vdot/(pi*rpi^2)');
    p.set('Dhyd', '2*rpi');
    p.set('I_turb', sprintf('%.16g', cfg.turbulence_intensity));
    p.set('Lt_turb', sprintf('%.16g*Dhyd', cfg.turbulent_length_scale_factor));
    p.set('Pr_turb', sprintf('%.16g', cfg.turbulent_prandtl));
    p.set('A_inner', '2*pi*rpi*L');

    p.set('day', '86400[s]');
    p.set('P', sprintf('%.16g*day', cfg.P_day));
    p.set('Tin_mean_C', sprintf('%.16g', cfg.Tin_mean_C));
    p.set('A_in_C', sprintf('%.16g', cfg.A_in_C));
    p.set('t_phase', sprintf('%.16g*day', cfg.t_phase_day));
    if strcmpi(cfg.temperature_profile, "table")
        p.set('Tin_K', linear_temperature_expression(cfg.exp_time_s, cfg.exp_Tin_C));
        p.set('Tin_init_K', sprintf('%.16g[degC]', cfg.exp_Tin_C(1)));
    else
        p.set('Tin_K', 'Tin_mean_C[degC]+A_in_C[K]*cos(2*pi*(t-t_phase)/P)');
        p.set('Tin_init_K', 'Tin_mean_C[degC]+A_in_C[K]*cos(2*pi*(-t_phase)/P)');
    end

    p.set('Tm_C', sprintf('%.16g', cfg.Tm_C));
    p.set('A_s_C', sprintf('%.16g', cfg.A_s_C));
    p.set('H', sprintf('%.16g[m]', cfg.H));
    p.set('t0', sprintf('%.16g*day', cfg.t0_day));
    p.set('alpha_s', 'k_s/(rho_s*cp_s)');
    if strcmpi(cfg.temperature_profile, "table")
        p.set('Th_K', linear_temperature_expression(cfg.exp_time_s, cfg.exp_Tsoil_C));
        p.set('Th_init_K', sprintf('%.16g[degC]', cfg.exp_Tsoil_C(1)));
    elseif strcmpi(cfg.study_mode, 'short_test')
        p.set('Th_K', 'Tm_C[degC]');
        p.set('Th_init_K', 'Tm_C[degC]');
    else
        p.set('Th_K', ['Tm_C[degC]-A_s_C[K]*exp(-H*sqrt(pi/(P*alpha_s)))' ...
            '*cos(2*pi/P*(t-t0-H/2*sqrt(P/(pi*alpha_s))))']);
        p.set('Th_init_K', ['Tm_C[degC]-A_s_C[K]*exp(-H*sqrt(pi/(P*alpha_s)))' ...
            '*cos(2*pi/P*(-t0-H/2*sqrt(P/(pi*alpha_s))))']);
    end

    p.set('Rgap_line', 'log((rpo+delta)/rpo)/(2*pi*k_air)');
    p.set('Rgap_area', 'rpo*log((rpo+delta)/rpo)/k_air');
    p.set('h_gap', 'if(delta>0[m],1/Rgap_area,1e12[W/(m^2*K)])');

    p.set('mesh_air_max', sprintf('%.16g[m]', cfg.mesh_air_max));
    p.set('mesh_pipe_max', sprintf('%.16g[m]', cfg.mesh_pipe_max));
    if delta > 0
        p.set('mesh_gap_max', sprintf('%.16g[m]', min(cfg.mesh_gap_max, max(delta / 5, delta / 10))));
    else
        p.set('mesh_gap_max', sprintf('%.16g[m]', cfg.mesh_gap_max));
    end
    p.set('mesh_soil_near_max', sprintf('%.16g[m]', cfg.mesh_soil_near_max));
    p.set('mesh_soil_far_max', sprintf('%.16g[m]', cfg.mesh_soil_far_max));
end

function expr = linear_temperature_expression(tSec, tempC)
    tSec = tSec(:);
    tempC = tempC(:);
    if numel(tSec) ~= numel(tempC) || numel(tSec) < 1
        error('Experimental temperature profile requires matching exp_time_s and temperature arrays.');
    end
    if numel(tSec) == 1
        expr = sprintf('%.16g[degC]', tempC(1));
        return
    end

    tail = sprintf('%.16g[degC]', tempC(end));
    for i = (numel(tSec)-1):-1:1
        dt = tSec(i+1) - tSec(i);
        dT = tempC(i+1) - tempC(i);
        segment = sprintf('(%.16g[degC]+%.16g[K]*(t-%.16g[s])/(%.16g[s]))', ...
            tempC(i), dT, tSec(i), dt);
        tail = sprintf('if(t<%.16g[s],%s,%s)', tSec(i+1), segment, tail);
    end
    expr = tail;
end

function create_rectangle(geom, tag, x, y, w, h)
    r = geom.feature.create(tag, 'Rectangle');
    r.set('pos', {num2str(x, '%.16g'), num2str(y, '%.16g')});
    r.set('size', {num2str(w, '%.16g'), num2str(h, '%.16g')});
end

function sel = make_selections(model, cfg, hasExplicitGap, rg)
    % mphselectbox is a LiveLink helper. In some older COMSOL versions its
    % argument order differs; if this fails, create equivalent named
    % selections manually in the COMSOL GUI and update the selection tags here.
    comp = model.component('comp1');
    geomTag = 'geom1';
    epsBox = 1.0e-8;

    sel.air = create_domain_selection(comp, 'sel_air', ...
        select_box(model, geomTag, [0, cfg.rpi], [0, cfg.L], 'domain'));
    sel.pipe = create_domain_selection(comp, 'sel_pipe', ...
        select_box(model, geomTag, [cfg.rpi, cfg.rpo], [0, cfg.L], 'domain'));
    if hasExplicitGap
        sel.gap = create_domain_selection(comp, 'sel_gap', ...
            select_box(model, geomTag, [cfg.rpo, rg], [0, cfg.L], 'domain'));
        soilInner = rg;
    else
        sel.gap = [];
        soilInner = cfg.rpo;
    end
    sel.soil = create_domain_selection(comp, 'sel_soil', ...
        select_box(model, geomTag, [soilInner, cfg.Rs], [0, cfg.L], 'domain'));

    sel.inlet = create_boundary_selection(comp, 'sel_inlet', ...
        select_box(model, geomTag, [0, cfg.rpi], [-epsBox, epsBox], 'boundary'));
    sel.outlet = create_boundary_selection(comp, 'sel_outlet', ...
        select_box(model, geomTag, [0, cfg.rpi], [cfg.L-epsBox, cfg.L+epsBox], 'boundary'));
    sel.outer_soil = create_boundary_selection(comp, 'sel_outer_soil', ...
        select_box(model, geomTag, [cfg.Rs-epsBox, cfg.Rs+epsBox], [0, cfg.L], 'boundary'));
    sel.pipe_outer = create_boundary_selection(comp, 'sel_pipe_outer', ...
        select_box(model, geomTag, [cfg.rpo-epsBox, cfg.rpo+epsBox], [0, cfg.L], 'boundary'));
    sel.air_pipe = create_boundary_selection(comp, 'sel_air_pipe', ...
        select_box(model, geomTag, [cfg.rpi-epsBox, cfg.rpi+epsBox], [0, cfg.L], 'boundary'));
    if hasExplicitGap
        sel.gap_soil = create_boundary_selection(comp, 'sel_gap_soil', ...
            select_box(model, geomTag, [rg-epsBox, rg+epsBox], [0, cfg.L], 'boundary'));
    else
        sel.gap_soil = [];
    end
end

function ids = select_box(model, geomTag, xRange, yRange, entity)
    ids = mphselectbox(model, geomTag, ...
        [xRange(1), xRange(2); yRange(1), yRange(2)], entity);
end

function tag = create_domain_selection(comp, tag, ids)
    s = comp.selection.create(tag, 'Explicit');
    s.geom('geom1', 2);
    s.set(ids);
end

function tag = create_boundary_selection(comp, tag, ids)
    s = comp.selection.create(tag, 'Explicit');
    s.geom('geom1', 1);
    s.set(ids);
end

function add_materials(model, sel, hasExplicitGap)
    comp = model.component('comp1');

    matAir = comp.material.create('mat_air', 'Common');
    matAir.label('Pipe internal air');
    matAir.selection.named(sel.air);
    set_material_scalar(matAir, 'k_air', 'rho_f', 'cp_f');
    set_material_viscosity(matAir, 'mu_f');

    matPipe = comp.material.create('mat_pipe', 'Common');
    matPipe.label('Pipe wall');
    matPipe.selection.named(sel.pipe);
    set_material_scalar(matPipe, 'k_p', 'rho_p', 'cp_p');

    if hasExplicitGap
        matGap = comp.material.create('mat_gap', 'Common');
        matGap.label('Conductive air gap');
        matGap.selection.named(sel.gap);
        set_material_scalar(matGap, 'k_gap', 'rho_gap', 'cp_gap');
    end

    matSoil = comp.material.create('mat_soil', 'Common');
    matSoil.label('Soil');
    matSoil.selection.named(sel.soil);
    set_material_scalar(matSoil, 'k_s', 'rho_s', 'cp_s');
end

function set_material_scalar(mat, kExpr, rhoExpr, cpExpr)
    def = mat.propertyGroup('def');
    def.set('thermalconductivity', {kExpr, '0', '0', '0', kExpr, '0', '0', '0', kExpr});
    def.set('density', rhoExpr);
    def.set('heatcapacity', cpExpr);
end

function set_material_viscosity(mat, muExpr)
    def = mat.propertyGroup('def');
    try
        def.set('dynamicviscosity', muExpr);
    catch
        try
            def.set('mu', muExpr);
        catch
            warning('Dynamic viscosity property was not assigned automatically.');
        end
    end
end

function add_heat_transfer_physics(model, cfg, sel, modelType, delta)
    comp = model.component('comp1');

    if startsWith(lower(string(cfg.physics_model)), "cfd")
        add_cfd_conjugate_heat_transfer_physics(model, cfg, sel, modelType, delta);
        return
    end

    % Interface name is stable in recent COMSOL Heat Transfer Module versions.
    % If your version uses another physics interface key, replace
    % HeatTransferInSolidsAndFluids below with the GUI-generated key.
    ht = comp.physics.create('ht', 'HeatTransferInSolidsAndFluids', 'geom1');
    ht.selection.all;
    ht.feature('init1').set('Tinit', 'Th_init_K');

    % Pipe internal air: prescribe mean axial advection velocity.
    % Property names for velocity components are version-sensitive. The try
    % blocks cover common LiveLink variants for 2D axisymmetric heat transfer.
    try
        ht.feature('fluid1').selection.named(sel.air);
    catch
        try
            ht.feature.create('fluid_air', 'Fluid', 2);
            ht.feature('fluid_air').selection.named(sel.air);
        catch
            warning(['Could not assign a Fluid domain feature automatically. ' ...
                'Check the Heat Transfer interface fluid-domain settings in COMSOL.']);
        end
    end
    try_set_velocity(ht);

    % Solids. Heat continuity on conformal internal boundaries is the default.
    try
        ht.feature.create('solid_pipe', 'Solid', 2);
        ht.feature('solid_pipe').selection.named(sel.pipe);
    catch
    end
    if ~isempty(sel.gap)
        try
            ht.feature.create('solid_gap', 'Solid', 2);
            ht.feature('solid_gap').selection.named(sel.gap);
        catch
        end
    end
    try
        ht.feature.create('solid_soil', 'Solid', 2);
        ht.feature('solid_soil').selection.named(sel.soil);
    catch
    end

    tin = ht.feature.create('Tin', 'TemperatureBoundary', 1);
    tin.selection.named(sel.inlet);
    tin.set('T0', 'Tin_K');

    % At the outlet, convective outflow is preferred. COMSOL 6.3 uses the
    % feature ID ConvectiveOutflow for Heat Transfer in Solids and Fluids.
    try
        out = ht.feature.create('out1', 'ConvectiveOutflow', 1);
        out.selection.named(sel.outlet);
    catch
        try
            out = ht.feature.create('open_out', 'OpenBoundary', 1);
            out.selection.named(sel.outlet);
        catch
            warning('Outflow feature was not created. Natural boundary condition will be used at the outlet.');
        end
    end

    soilT = ht.feature.create('Tsoil', 'TemperatureBoundary', 1);
    soilT.selection.named(sel.outer_soil);
    soilT.set('T0', 'Th_K');

    if strcmpi(modelType, 'resistance_gap') && delta > 0
        add_gap_resistance_feature(ht, sel.pipe_outer);
    end

    % Soil axial end faces outside the pipe are left at the natural insulation
    % condition. This avoids forcing pipe-end soil temperatures.
end

function add_cfd_conjugate_heat_transfer_physics(model, cfg, sel, modelType, delta)
    comp = model.component('comp1');

    flowTag = create_flow_physics(comp, cfg, sel);
    ht = comp.physics.create('ht', 'HeatTransferInSolidsAndFluids', 'geom1');
    ht.selection.all;
    ht.feature('init1').set('Tinit', 'Th_init_K');

    try
        ht.feature('fluid1').selection.named(sel.air);
    catch
        try
            ht.feature.create('fluid_air', 'Fluid', 2);
            ht.feature('fluid_air').selection.named(sel.air);
        catch
            warning('Could not assign air as Heat Transfer fluid domain automatically.');
        end
    end
    try_set_heat_velocity_from_flow(ht, flowTag);

    try
        ht.feature.create('solid_pipe', 'Solid', 2);
        ht.feature('solid_pipe').selection.named(sel.pipe);
    catch
    end
    if ~isempty(sel.gap)
        try
            ht.feature.create('solid_gap', 'Solid', 2);
            ht.feature('solid_gap').selection.named(sel.gap);
        catch
        end
    end
    try
        ht.feature.create('solid_soil', 'Solid', 2);
        ht.feature('solid_soil').selection.named(sel.soil);
    catch
    end

    tin = ht.feature.create('Tin', 'TemperatureBoundary', 1);
    tin.selection.named(sel.inlet);
    tin.set('T0', 'Tin_K');

    try
        out = ht.feature.create('out1', 'ConvectiveOutflow', 1);
        out.selection.named(sel.outlet);
    catch
        try
            out = ht.feature.create('open_out', 'OpenBoundary', 1);
            out.selection.named(sel.outlet);
        catch
            warning('CFD heat outlet feature was not created; natural outlet is used.');
        end
    end

    soilT = ht.feature.create('Tsoil', 'TemperatureBoundary', 1);
    soilT.selection.named(sel.outer_soil);
    soilT.set('T0', 'Th_K');

    if strcmpi(modelType, 'resistance_gap') && delta > 0
        add_gap_resistance_feature(ht, sel.pipe_outer);
    end

    add_nonisothermal_coupling(comp, flowTag);
end

function flowTag = create_flow_physics(comp, cfg, sel)
    modelName = lower(string(cfg.physics_model));
    if modelName == "cfd_laminar"
        candidates = {'LaminarFlow'};
    elseif modelName == "cfd_kepsilon"
        candidates = {'TurbulentFlowkeps','TurbulentFlowKEpsilon','TurbulentFlowkEpsilon','TurbulentFlowKepsilon'};
    else
        candidates = {'TurbulentFlowSST','TurbulentFlowkOmegaSST','TurbulentFlowKOmegaSST'};
    end

    flowTag = 'spf';
    created = false;
    lastMsg = '';
    for i = 1:numel(candidates)
        try
            comp.physics.create(flowTag, candidates{i}, 'geom1');
            created = true;
            break
        catch ME
            lastMsg = ME.message;
        end
    end
    if ~created
        error(['Could not create requested CFD flow interface (%s). Last COMSOL error: %s. ' ...
            'Create the corresponding Turbulent Flow interface once in the GUI and use the generated API key here.'], ...
            cfg.physics_model, lastMsg);
    end

    spf = comp.physics(flowTag);
    spf.selection.named(sel.air);
    set_flow_initial_values(spf);

    inlet = spf.feature.create('inl1', 'Inlet', 1);
    inlet.selection.named(sel.inlet);
    try_set_any(inlet, {'BoundaryCondition'}, 'Velocity');
    try_set_many(inlet, {'U0in','U0','Uav','Umean','V0'}, 'u_z');
    try_set_many(inlet, {'IT','I0','I'}, 'I_turb');
    try_set_many(inlet, {'LT','Lt','L'}, 'Lt_turb');

    outlet = spf.feature.create('out1', 'Outlet', 1);
    outlet.selection.named(sel.outlet);
    try_set_any(outlet, {'p0','p0gh','p'}, '0[Pa]');

    try
        wall = spf.feature.create('wall_pipe', 'Wall', 1);
        wall.selection.named(sel.air_pipe);
        try_set_any(wall, {'BoundaryCondition','WallCondition'}, 'NoSlip');
    catch
        % The default wall condition in flow interfaces is no-slip.
    end
end

function set_flow_initial_values(spf)
    try
        init = spf.feature('init1');
    catch
        return
    end
    try_set_any(init, {'u_init'}, {'0', 'u_z'});
    try_set_any(init, {'p_init'}, '0[Pa]');
    try_set_any(init, {'k_init'}, '1.5*(u_z*I_turb)^2');
    try_set_any(init, {'om_init'}, 'sqrt(1.5*(u_z*I_turb)^2)/(Lt_turb)');
    try_set_any(init, {'ep_init'}, '(1.5*(u_z*I_turb)^2)^(3/2)/(Lt_turb)');
end

function try_set_heat_velocity_from_flow(ht, flowTag)
    tags = {'fluid1','fluid_air'};
    for i = 1:numel(tags)
        tag = tags{i};
        try
            ht.feature(tag).set('u_src', 'userdef');
            ht.feature(tag).set('u', {'u', '0', 'w'});
            return
        catch
        end
        try
            ht.feature(tag).set('u_src', 'userdef');
            ht.feature(tag).set('u', {'u', 'w'});
            return
        catch
        end
        try
            ht.feature(tag).set('u_src', 'userdef');
            ht.feature(tag).set('u', {'u', '0', 'v'});
            return
        catch
        end
        try
            ht.feature(tag).set('u_src', 'userdef');
            ht.feature(tag).set('u', {'u', 'v'});
            return
        catch
        end
        try
            ht.feature(tag).set('u_src', 'userdef');
            ht.feature(tag).set('u', {sprintf('%s.u', flowTag), '0', sprintf('%s.w', flowTag)});
            return
        catch
        end
        try
            ht.feature(tag).set('u', {sprintf('%s.u', flowTag), sprintf('%s.w', flowTag)});
            return
        catch
        end
        try
            ht.feature(tag).set('VelocityField', {sprintf('%s.u', flowTag), sprintf('%s.w', flowTag)});
            return
        catch
        end
        try
            ht.feature(tag).set('u', {sprintf('%s.u', flowTag), sprintf('%s.v', flowTag)});
            return
        catch
        end
        try
            ht.feature(tag).set('VelocityField', {sprintf('%s.u', flowTag), sprintf('%s.v', flowTag)});
            return
        catch
        end
    end
    warning('Heat Transfer velocity could not be linked to the CFD flow field automatically.');
end

function add_nonisothermal_coupling(comp, flowTag)
    try
        nitf = comp.multiphysics.create('nitf1', 'NonIsothermalFlow', 'geom1');
        nitf.set('Fluid_physics', flowTag);
        nitf.set('Heat_physics', 'ht');
        try_set_any(nitf, {'ThermalTurbType'}, 'KaysCrawford');
        try_set_any(nitf, {'ThermalWallFunction'}, 'Standard');
        try_set_any(nitf, {'Prt'}, 'Pr_turb');
    catch
        warning(['Nonisothermal Flow multiphysics coupling was not created automatically. ' ...
            'If this COMSOL version requires it, add the ht-spf coupling in the GUI.']);
    end
end

function ok = try_set_any(feature, propertyNames, value)
    ok = false;
    for i = 1:numel(propertyNames)
        try
            feature.set(propertyNames{i}, value);
            ok = true;
            return
        catch
        end
    end
end

function ok = try_set_many(feature, propertyNames, value)
    ok = false;
    for i = 1:numel(propertyNames)
        try
            feature.set(propertyNames{i}, value);
            ok = true;
        catch
        end
    end
end

function try_set_velocity(ht)
    velocitySet = false;
    velocityFeatureTags = {'fluid1','fluid_air'};
    for i = 1:numel(velocityFeatureTags)
        tag = velocityFeatureTags{i};
        try
            ht.feature(tag).set('u_src', 'userdef');
            % In 2D axisymmetric heat transfer COMSOL stores the velocity as
            % [u_r, u_phi, u_z]. Axial pipe flow is therefore the third entry.
            ht.feature(tag).set('u', {'0', '0', 'u_z'});
            velocitySet = true;
            break
        catch
        end
        try
            ht.feature(tag).set('u', {'0', 'u_z'});
            velocitySet = true;
            break
        catch
        end
        try
            ht.feature(tag).set('u', '0');
            ht.feature(tag).set('w', 'u_z');
            velocitySet = true;
            break
        catch
        end
        try
            ht.feature(tag).set('VelocityField', {'0', 'u_z'});
            velocitySet = true;
            break
        catch
        end
    end
    if ~velocitySet
        warning(['Velocity was not set through a known property name. ' ...
            'Open the model and set radial velocity u=0 and axial velocity w=u_z in the air domain.']);
    end
end

function add_gap_resistance_feature(ht, pipeOuterSelection)
    % Preferred representation for this script: a resistive Thin Layer with
    % area resistance Rgap_area [m^2 K/W]. This avoids version-sensitive
    % ThermalContact property names and directly matches the required
    % equivalent boundary resistance.
    try
        tl = ht.feature.create('gap_thin_layer', 'ThinLayer', 1);
        tl.selection.named(pipeOuterSelection);
        tl.set('LayerType', 'Resistive');
        tl.set('ThermalResistanceType', 'ThermalResistance');
        tl.set('R_s', 'Rgap_area');
        tl.set('ks_mat', 'userdef');
        tl.set('ks', 'k_air');
        tl.set('rhos_mat', 'userdef');
        tl.set('rhos', 'rho_gap');
        tl.set('Cp_s_mat', 'userdef');
        tl.set('Cp_s', 'cp_gap');
        return
    catch
    end

    % Fallback for versions where the explicit resistance mode is named
    % differently. A layer of thickness delta and conductivity k_air gives the
    % same area resistance in the small-gap limit.
    try
        tl = ht.feature.create('gap_thin_layer_fallback', 'ThinLayer', 1);
        tl.selection.named(pipeOuterSelection);
        try
            tl.set('ds', 'delta');
            tl.set('ks', 'k_air');
        catch
            tl.set('d', 'delta');
            tl.set('k', 'k_air');
        end
        return
    catch
    end

    warning(['Could not create a ThinLayer resistance boundary automatically. ' ...
        'For resistance_gap and delta>0, add an equivalent boundary resistance Rgap_area manually.']);
end

function add_mesh(model, cfg, sel, hasExplicitGap, delta)
    comp = model.component('comp1');
    mesh = comp.mesh.create('mesh1');

    if cfg.use_mapped_mesh
        add_mapped_mesh(model, mesh, cfg, hasExplicitGap, delta);
        return
    end

    mesh.feature.create('ftri1', 'FreeTri');

    sAir = mesh.feature.create('size_air', 'Size');
    sAir.selection.geom('geom1', 2);
    sAir.selection.named(sel.air);
    sAir.set('custom', 'on');
    sAir.set('hmax', 'mesh_air_max');

    sPipe = mesh.feature.create('size_pipe', 'Size');
    sPipe.selection.geom('geom1', 2);
    sPipe.selection.named(sel.pipe);
    sPipe.set('custom', 'on');
    sPipe.set('hmax', 'mesh_pipe_max');

    if hasExplicitGap
        sGap = mesh.feature.create('size_gap', 'Size');
        sGap.selection.geom('geom1', 2);
        sGap.selection.named(sel.gap);
        sGap.set('custom', 'on');
        sGap.set('hmax', 'mesh_gap_max');
        if delta > 0 && cfg.mesh_gap_max > delta / 3
            warning('mesh_gap_max is larger than delta/3. Consider reducing it to keep at least 3 gap elements.');
        end
    end

    sSoil = mesh.feature.create('size_soil', 'Size');
    sSoil.selection.geom('geom1', 2);
    sSoil.selection.named(sel.soil);
    sSoil.set('custom', 'on');
    sSoil.set('hmax', 'mesh_soil_far_max');
    sSoil.set('hgrad', 1.25);

    % Boundary refinement near pipe/gap/soil interface.
    try
        sWall = mesh.feature.create('size_wall', 'Size');
        sWall.selection.geom('geom1', 1);
        sWall.selection.named(sel.pipe_outer);
        sWall.set('custom', 'on');
        sWall.set('hmax', 'mesh_soil_near_max');
    catch
    end

    mesh.run;
end

function add_mapped_mesh(model, mesh, cfg, hasExplicitGap, delta)
    % Mapped quadrilateral mesh for rectangular r-z domains. This is much more
    % efficient for a thin, long explicit air gap than an isotropic FreeTri
    % mesh: radial layers are controlled independently from axial divisions.
    map = mesh.feature.create('map1', 'Map');
    map.selection.geom('geom1', 2);
    map.selection.all;

    nAxial = max(2, ceil(cfg.L / cfg.mesh_axial_max));
    add_mesh_distribution(map, 'dist_axial', ...
        axial_boundary_ids(model, cfg, hasExplicitGap, delta), nAxial);

    if startsWith(lower(string(cfg.physics_model)), "cfd")
        nAirRadial = cfg.cfd_air_radial_elems;
    else
        nAirRadial = cfg.mesh_air_radial_elems;
    end
    add_mesh_distribution(map, 'dist_air_radial', ...
        horizontal_segment_ids(model, cfg, 0.0, cfg.rpi), nAirRadial);
    add_mesh_distribution(map, 'dist_pipe_radial', ...
        horizontal_segment_ids(model, cfg, cfg.rpi, cfg.rpo), cfg.mesh_pipe_radial_elems);

    if hasExplicitGap
        nGap = max(cfg.mesh_gap_radial_elems_min, ceil(delta / cfg.mesh_gap_max));
        add_mesh_distribution(map, 'dist_gap_radial', ...
            horizontal_segment_ids(model, cfg, cfg.rpo, cfg.rpo + delta), nGap);
        soilInner = cfg.rpo + delta;
    else
        soilInner = cfg.rpo;
    end

    add_mesh_distribution(map, 'dist_soil_radial', ...
        horizontal_segment_ids(model, cfg, soilInner, cfg.Rs), cfg.mesh_soil_radial_elems);

    mesh.run;
end

function add_mesh_distribution(map, tag, boundaryIds, nElem)
    if isempty(boundaryIds)
        warning('Mapped mesh distribution %s has no selected boundaries.', tag);
        return
    end
    dist = map.create(tag, 'Distribution');
    dist.selection.geom('geom1', 1);
    dist.selection.set(boundaryIds);
    dist.set('type', 'number');
    dist.set('numelem', num2str(nElem));
end

function ids = axial_boundary_ids(model, cfg, hasExplicitGap, delta)
    epsBox = 1.0e-8;
    radii = [0.0, cfg.rpi, cfg.rpo, cfg.Rs];
    if hasExplicitGap
        radii = [radii, cfg.rpo + delta];
    end
    ids = [];
    for i = 1:numel(radii)
        r = radii(i);
        ids = [ids, select_box(model, 'geom1', ...
            [r-epsBox, r+epsBox], [0, cfg.L], 'boundary')]; %#ok<AGROW>
    end
    ids = unique(ids);
end

function ids = horizontal_segment_ids(model, cfg, r1, r2)
    epsBox = 1.0e-8;
    ids0 = select_box(model, 'geom1', [r1, r2], [-epsBox, epsBox], 'boundary');
    idsL = select_box(model, 'geom1', [r1, r2], [cfg.L-epsBox, cfg.L+epsBox], 'boundary');
    ids = unique([ids0(:).', idsL(:).']);
end

function add_average_and_variables(model, sel)
    comp = model.component('comp1');

    aveOut = comp.cpl.create('ave_out', 'Average');
    aveOut.selection.named(sel.outlet);
    aveWall = comp.cpl.create('ave_wall_inner', 'Average');
    aveWall.selection.named(sel.air_pipe);

    var = comp.variable.create('var_post');
    var.set('Tin_C_eval', 'Tin_K-273.15[K]');
    var.set('Tout_C_eval', 'ave_out(T)-273.15[K]');
    var.set('Q_eval', 'mdot*cp_f*(Tin_K-ave_out(T))');
    var.set('Twall_inner_C_eval', 'ave_wall_inner(T)-273.15[K]');
    var.set('h_eq_global_eval', 'abs(Q_eval)/(A_inner*abs((Tin_K+ave_out(T))/2-ave_wall_inner(T)))');

    % qg_mid is evaluated in MATLAB from -k*d(T,x) at a point near the wall.
    % In 2D axisymmetry x is radial r, so q'' ~= -k*dT/dr.
    var.set('q_pipe_radial', '-k_p*d(T,x)');
    var.set('q_soil_radial', '-k_s*d(T,x)');
end

function add_transient_study(model, cfg)
    std = model.study.create('std1');
    if startsWith(lower(string(cfg.physics_model)), "cfd")
        stat = std.create('stat_flow', 'Stationary');
        try
            stat.set('activate', {'spf','on','ht','off'});
        catch
        end
    end
    time = std.create('time', 'Transient');
    switch lower(string(cfg.study_mode))
        case "short_test"
            time.set('tlist', sprintf('range(0,%g,%g)', cfg.short_dt_s, cfg.short_end_s));
        case "annual"
            time.set('tlist', sprintf('range(0,%g,%g)', cfg.annual_dt_s, cfg.annual_end_s));
    end
    if startsWith(lower(string(cfg.physics_model)), "cfd")
        try
            time.set('activate', {'spf','on','ht','on'});
        catch
        end
        try
            time.set('usesol', 'on');
        catch
        end
    end
    time.set('rtol', '1e-3');
end

function raw = extract_case_outputs(model, cfg, modelType, deltaMm, tSec)
    delta = deltaMm * 1.0e-3;
    rg = cfg.rpo + delta;
    zMid = cfg.L / 2;

    TinC = tin_celsius(tSec(:), cfg);
    if isfield(cfg, 'use_mass_weighted_temperature') && cfg.use_mass_weighted_temperature && ...
            startsWith(lower(string(cfg.physics_model)), "cfd")
        ToutC = evaluate_air_bulk_temperature_mass(model, cfg, cfg.L - max(cfg.eval_eps, 1.0e-6), tSec);
        ToutAreaC = eval_global_time_safe(model, 'Tout_C_eval', tSec);
    else
        ToutC = eval_global_time(model, 'Tout_C_eval', tSec);
        ToutAreaC = ToutC;
    end
    QW = cfg.mdot * cfg.cp_f .* (TinC(:) - ToutC(:));
    TwallInnerC = eval_global_time_safe(model, 'Twall_inner_C_eval', tSec);
    hEqGlobal = abs(QW(:))./(2*pi*cfg.rpi*cfg.L* ...
        max(abs((TinC(:)+ToutC(:))/2 - TwallInnerC(:)), 1.0e-6));

    if strcmpi(modelType, 'explicit_gap') && delta > 0
        rPipeEval = cfg.rpo - cfg.eval_eps;
        rGapSoilEval = rg + cfg.eval_eps;
    elseif strcmpi(modelType, 'resistance_gap') && delta > 0
        rPipeEval = cfg.rpo - cfg.eval_eps;
        rGapSoilEval = cfg.rpo + cfg.eval_eps;
    else
        rPipeEval = cfg.rpo - cfg.eval_eps;
        rGapSoilEval = cfg.rpo + cfg.eval_eps;
    end

    TpoC = eval_point_time(model, 'T-273.15[K]', rPipeEval, zMid, tSec);
    TgC = eval_point_time(model, 'T-273.15[K]', rGapSoilEval, zMid, tSec);
    if delta > 0
        RgapLine = log((cfg.rpo + delta) / cfg.rpo) / (2*pi*cfg.k_air);
        qgLine = (TpoC(:) - TgC(:)) ./ RgapLine;
    else
        % For direct pipe-soil contact there is no gap temperature jump.
        % Estimate the local interface heat flux from the two evaluation
        % points straddling the continuous pipe-soil interface. The sampling
        % resistance is eps/k_p + eps/k_s, and q' = q''*2*pi*rpo.
        sampleResistance = cfg.eval_eps / cfg.k_p + cfg.eval_eps / cfg.k_s;
        qFlux = (TpoC(:) - TgC(:)) ./ sampleResistance;
        qgLine = qFlux(:) .* (2*pi*cfg.rpo);
    end

    raw.time_series = table(tSec(:)/cfg.day_s, TinC(:), ToutC(:), ToutAreaC(:), QW(:), ...
        TwallInnerC(:), hEqGlobal(:), ...
        'VariableNames', {'t_day','Tin_C','Tout_C','Tout_area_mean_C','Q_W', ...
        'Twall_inner_C','h_eq_global_W_m2K'});

    modelTypeCol = repmat(string(modelType), numel(tSec), 1);
    deltaCol = repmat(deltaMm, numel(tSec), 1);
    raw.interface = table(tSec(:)/cfg.day_s, modelTypeCol, deltaCol, ...
        TpoC(:), TgC(:), TpoC(:)-TgC(:), qgLine(:), ...
        'VariableNames', {'t_day','model_type','delta_mm','Tpo_mid_C','Tg_mid_C', ...
        'DeltaTint_mid_C','qg_mid_W_per_m'});

    raw.t_day = tSec(:)/cfg.day_s;
    raw.Tin_C = TinC(:);
    raw.Tout_C = ToutC(:);
    raw.Q_W = QW(:);
    raw.Tpo_mid_C = TpoC(:);
    raw.Tg_mid_C = TgC(:);
    raw.DeltaTint_mid_C = TpoC(:) - TgC(:);
    raw.qg_mid_W_per_m = qgLine(:);
    raw.local_h = table();
    if cfg.export_local_h_profiles && startsWith(lower(string(cfg.physics_model)), "cfd")
        raw.local_h = compute_local_h_profile(model, cfg, modelType, deltaMm, tSec);
    end
    raw.validation = table();
    if ~isempty(cfg.validation_z_m)
        raw.validation = compute_validation_outputs(model, cfg, modelType, deltaMm, tSec, TinC, ToutC);
    end
end

function validation = compute_validation_outputs(model, cfg, modelType, deltaMm, tSec, TinC, ToutC)
    zList = cfg.validation_z_m(:);
    zList = zList(zList > 0 & zList < cfg.L);
    if isempty(zList)
        validation = table();
        return
    end

    tVal = tSec(:);
    if strcmpi(cfg.temperature_profile, "table") && ~isempty(cfg.exp_time_s)
        tVal = cfg.exp_time_s(:);
    end

    nT = numel(tVal);
    nZ = numel(zList);
    nRows = nT * nZ;
    caseName = repmat(string(cfg.validation_case_name), nRows, 1);
    modelTypeCol = repmat(string(modelType), nRows, 1);
    deltaCol = repmat(deltaMm, nRows, 1);
    timeCol = zeros(nRows, 1);
    zCol = zeros(nRows, 1);
    TinExpCol = nan(nRows, 1);
    TmidExpCol = nan(nRows, 1);
    ToutExpCol = nan(nRows, 1);
    TmidSimCol = nan(nRows, 1);
    ToutSimCol = nan(nRows, 1);

    row0 = 0;
    for iz = 1:nZ
        z = zList(iz);
        if isfield(cfg, 'use_mass_weighted_temperature') && cfg.use_mass_weighted_temperature && ...
                startsWith(lower(string(cfg.physics_model)), "cfd")
            TmidSim = evaluate_air_bulk_temperature_mass(model, cfg, z, tVal);
        else
            TmidSim = evaluate_air_bulk_temperature(model, cfg, z, tVal);
        end
        idx = row0 + (1:nT);
        timeCol(idx) = tVal(:) / cfg.day_s;
        zCol(idx) = z;
        TinExpCol(idx) = profile_interp(tVal, tSec, TinC);
        ToutSimCol(idx) = profile_interp(tVal, tSec, ToutC);
        TmidSimCol(idx) = TmidSim(:);
        if ~isempty(cfg.exp_Tmid_C)
            TmidExpCol(idx) = profile_interp(tVal, cfg.exp_time_s(:), cfg.exp_Tmid_C(:));
        end
        if ~isempty(cfg.exp_Tout_C)
            ToutExpCol(idx) = profile_interp(tVal, cfg.exp_time_s(:), cfg.exp_Tout_C(:));
        end
        row0 = row0 + nT;
    end

    validation = table(caseName, modelTypeCol, deltaCol, timeCol, zCol, ...
        TinExpCol, TmidExpCol, TmidSimCol, TmidSimCol - TmidExpCol, ...
        ToutExpCol, ToutSimCol, ToutSimCol - ToutExpCol, ...
        'VariableNames', {'case_name','model_type','delta_mm','t_day','z_m', ...
        'Tin_exp_C','Tmid_exp_C','Tmid_sim_C','Tmid_error_C', ...
        'Tout_exp_C','Tout_sim_C','Tout_error_C'});
end

function Tbulk = evaluate_air_bulk_temperature(model, cfg, z, tSec)
    epsWall = max(cfg.eval_eps, 1.0e-6);
    rAir = linspace(0, max(cfg.rpi - epsWall, epsWall), cfg.local_h_air_r_points).';
    wAir = rAir;
    if sum(wAir) <= 0
        wAir(:) = 1;
    end
    wAir = wAir ./ sum(wAir);
    coordAir = [rAir.'; repmat(z, 1, numel(rAir))];
    Tair = eval_interp_time_safe(model, 'T-273.15[K]', coordAir, tSec);
    Tair = orient_interp_matrix(Tair, numel(rAir), numel(tSec));
    if size(Tair, 1) == 1
        Tbulk = Tair(:);
    else
        Tbulk = (wAir.' * Tair).';
    end
end

function Tbulk = evaluate_air_bulk_temperature_mass(model, cfg, z, tSec)
    % Mass-flow weighted bulk temperature for CFD validation:
    % Tbulk = int rho cp u_z T dA / int rho cp u_z dA.
    % The integration is done by radial sampling to avoid COMSOL-version
    % differences in coupling operator syntax and velocity variable names.
    epsWall = max(cfg.eval_eps, 1.0e-6);
    zEval = min(max(z, epsWall), cfg.L - epsWall);
    rAir = linspace(0, max(cfg.rpi - epsWall, epsWall), cfg.local_h_air_r_points).';
    areaWeight = rAir;
    if sum(areaWeight) <= 0
        areaWeight(:) = 1;
    end
    coordAir = [rAir.'; repmat(zEval, 1, numel(rAir))];

    Tair = eval_interp_time_safe(model, 'T-273.15[K]', coordAir, tSec);
    Tair = orient_interp_matrix(Tair, numel(rAir), numel(tSec));
    uz = eval_axial_velocity_matrix(model, coordAir, tSec, numel(rAir), numel(tSec));

    if isempty(uz) || all(~isfinite(uz(:))) || max(abs(uz(:))) <= 1.0e-12
        warning('Mass-weighted temperature fell back to area-weighted value because axial velocity was unavailable.');
        w = areaWeight ./ sum(areaWeight);
        Tbulk = (w.' * Tair).';
        return
    end

    uz = abs(uz);
    Tbulk = nan(numel(tSec), 1);
    for j = 1:numel(tSec)
        w = areaWeight .* uz(:,j);
        if sum(w(isfinite(w))) <= 0
            w = areaWeight;
        end
        good = isfinite(w) & isfinite(Tair(:,j));
        if any(good)
            Tbulk(j) = sum(w(good).*Tair(good,j))/sum(w(good));
        end
    end
end

function uz = eval_axial_velocity_matrix(model, coordAir, tSec, nPoint, nTime)
    candidates = {'v', 'spf.v', 'w', 'spf.w', 'u_z'};
    uz = [];
    for i = 1:numel(candidates)
        try
            uTry = eval_interp_time_safe(model, candidates{i}, coordAir, tSec);
            uTry = orient_interp_matrix(uTry, nPoint, nTime);
            if any(isfinite(uTry(:))) && max(abs(uTry(:))) > 1.0e-12
                uz = uTry;
                return
            end
        catch
        end
    end
    uz = nan(nPoint, nTime);
end

function yq = profile_interp(tq, t, y)
    tq = tq(:);
    t = t(:);
    y = y(:);
    if numel(t) == 1
        yq = repmat(y(1), size(tq));
    else
        yq = interp1(t, y, tq, 'linear', 'extrap');
    end
end

function localH = compute_local_h_profile(model, cfg, modelType, deltaMm, tSec)
    zList = cfg.local_h_z_points(:);
    zList = zList(zList > 0 & zList < cfg.L);
    if isempty(zList)
        localH = table();
        return
    end

    epsWall = max(cfg.eval_eps, 1.0e-6);
    rWallFluid = max(cfg.rpi - epsWall, 0);
    rPipeOuter = cfg.rpo - epsWall;
    rAir = linspace(0, max(cfg.rpi - epsWall, epsWall), cfg.local_h_air_r_points).';
    wAir = rAir;
    if sum(wAir) <= 0
        wAir(:) = 1;
    end
    wAir = wAir ./ sum(wAir);

    nT = numel(tSec);
    nZ = numel(zList);
    nRows = nT * nZ;
    tCol = zeros(nRows, 1);
    zCol = zeros(nRows, 1);
    deltaCol = repmat(deltaMm, nRows, 1);
    modelCol = repmat(string(modelType), nRows, 1);
    TbulkCol = nan(nRows, 1);
    TwallCol = nan(nRows, 1);
    qWallCol = nan(nRows, 1);
    hLocalCol = nan(nRows, 1);
    hGnCol = repmat(gnielinski_h_inner(cfg), nRows, 1);

    row0 = 0;
    for iz = 1:nZ
        z = zList(iz);
        if isfield(cfg, 'use_mass_weighted_temperature') && cfg.use_mass_weighted_temperature
            Tbulk = evaluate_air_bulk_temperature_mass(model, cfg, z, tSec);
        else
            coordAir = [rAir.'; repmat(z, 1, numel(rAir))];
            Tair = eval_interp_time_safe(model, 'T-273.15[K]', coordAir, tSec);
            Tair = orient_interp_matrix(Tair, numel(rAir), nT);
            if size(Tair, 1) == 1
                Tbulk = Tair(:);
            else
                Tbulk = (wAir.' * Tair).';
            end
        end

        Twall = eval_point_time_safe(model, 'T-273.15[K]', rWallFluid, z, tSec);
        Touter = eval_point_time_safe(model, 'T-273.15[K]', rPipeOuter, z, tSec);
        qWall = cfg.k_p .* (Twall(:) - Touter(:)) ./ ...
            (cfg.rpi * log(cfg.rpo / cfg.rpi));
        hLocal = abs(qWall(:)) ./ max(abs(Tbulk(:) - Twall(:)), 1.0e-6);

        idx = row0 + (1:nT);
        tCol(idx) = tSec(:) / cfg.day_s;
        zCol(idx) = z;
        TbulkCol(idx) = Tbulk(:);
        TwallCol(idx) = Twall(:);
        qWallCol(idx) = qWall(:);
        hLocalCol(idx) = hLocal(:);
        row0 = row0 + nT;
    end

    localH = table(tCol, modelCol, deltaCol, zCol, TbulkCol, TwallCol, ...
        qWallCol, hLocalCol, hGnCol, ...
        'VariableNames', {'t_day','model_type','delta_mm','z_m', ...
        'Tbulk_C','Twall_inner_C','q_wall_W_m2','h_local_W_m2K', ...
        'h_gnielinski_W_m2K'});
end

function y = orient_interp_matrix(y, nPoint, nTime)
    if isempty(y)
        y = nan(nPoint, nTime);
        return
    end
    if isvector(y)
        y = y(:);
        if numel(y) == nTime && nPoint == 1
            y = y.';
        elseif numel(y) == nPoint && nTime == 1
            y = y(:);
        elseif numel(y) == nTime
            y = repmat(y(:).', nPoint, 1);
        elseif numel(y) == nPoint
            y = y(:);
        end
        return
    end
    if size(y, 1) == nPoint && size(y, 2) == nTime
        return
    end
    if size(y, 1) == nTime && size(y, 2) == nPoint
        y = y.';
        return
    end
    if size(y, 1) == nPoint
        return
    end
    if size(y, 2) == nPoint
        y = y.';
    end
end

function h = gnielinski_h_inner(cfg)
    D = 2 * cfg.rpi;
    A = pi * cfg.rpi^2;
    u = cfg.Vdot / A;
    Re = cfg.rho_f * u * D / cfg.mu_f;
    Pr = cfg.cp_f * cfg.mu_f / cfg.k_air;
    if Re < 2300
        Nu = 3.66;
    else
        f = (0.79 * log(Re) - 1.64)^(-2);
        Nu = (f/8) * (Re - 1000) * Pr / ...
            (1 + 12.7 * sqrt(f/8) * (Pr^(2/3) - 1));
    end
    h = Nu * cfg.k_air / D;
end

function export_local_h_profile_figure(localH, cfg, modelType, deltaMm)
    if isempty(localH) || height(localH) == 0
        return
    end
    figDir = fullfile(cfg.output_dir, 'local_h_figures');
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end

    tUnique = unique(localH.t_day);
    if numel(tUnique) >= 3
        tPick = [tUnique(2); tUnique(round(numel(tUnique)/2)); tUnique(end)];
    else
        tPick = tUnique;
    end

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 520]);
    ax = axes(fig);
    hold(ax, 'on');
    for i = 1:numel(tPick)
        [~, iNear] = min(abs(localH.t_day - tPick(i)));
        tUse = localH.t_day(iNear);
        rows = localH(abs(localH.t_day - tUse) < 1e-9, :);
        rows = sortrows(rows, 'z_m');
        plot(ax, rows.z_m, rows.h_local_W_m2K, '-o', ...
            'LineWidth', 1.4, 'DisplayName', sprintf('t = %.2f day', tUse));
    end
    yline(ax, localH.h_gnielinski_W_m2K(1), '--k', ...
        'DisplayName', 'Gnielinski reference');
    xlabel(ax, 'z / m');
    ylabel(ax, 'h_{local} / (W m^{-2} K^{-1})');
    title(ax, sprintf('CFD local inner-wall heat-transfer coefficient, %s, \\delta = %.4g mm', ...
        strrep(char(modelType), '_', '\_'), deltaMm));
    grid(ax, 'on');
    legend(ax, 'Location', 'best');
    outFile = fullfile(figDir, sprintf('Fig_COMSOL_local_h_%s_delta_%s.png', ...
        modelType, delta_token(deltaMm)));
    exportgraphics(fig, outFile, 'Resolution', 300);
    close(fig);
end

function export_case_field_figures(model, cfg, modelType, deltaMm, tSec)
    figDir = cfg.field_figure_dir;
    if isempty(figDir)
        figDir = fullfile(cfg.output_dir, 'field_figures');
    end
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end

    delta = deltaMm * 1.0e-3;
    rg = cfg.rpo + delta;
    tag = sprintf('%s_delta_%s', modelType, delta_token(deltaMm));

    export_geometry_figure(cfg, modelType, deltaMm, figDir);
    export_temperature_cloud(model, cfg, modelType, deltaMm, tSec(1), ...
        fullfile(figDir, sprintf('Fig_COMSOL_Tfield_initial_%s.png', tag)), ...
        'Initial temperature field');
    export_temperature_cloud(model, cfg, modelType, deltaMm, tSec(end), ...
        fullfile(figDir, sprintf('Fig_COMSOL_Tfield_final_%s.png', tag)), ...
        'Final temperature field');

    if strcmpi(modelType, 'explicit_gap') && delta > 0
        export_temperature_cloud_zoom(model, cfg, modelType, deltaMm, tSec(end), ...
            [max(0, cfg.rpi - 0.01), min(cfg.Rs, rg + 0.03)], ...
            fullfile(figDir, sprintf('Fig_COMSOL_Tfield_final_zoom_%s.png', tag)), ...
            'Final near-wall temperature field');
    else
        export_temperature_cloud_zoom(model, cfg, modelType, deltaMm, tSec(end), ...
            [max(0, cfg.rpi - 0.01), min(cfg.Rs, cfg.rpo + max(delta, 0.005) + 0.03)], ...
            fullfile(figDir, sprintf('Fig_COMSOL_Tfield_final_zoom_%s.png', tag)), ...
            'Final near-wall temperature field');
    end
end

function export_temperature_cloud(model, cfg, modelType, deltaMm, tValue, fileName, titleText)
    r = linspace(0, cfg.Rs, cfg.field_r_points);
    z = linspace(0, cfg.L, cfg.field_z_points);
    [Z, R] = meshgrid(z, r);
    coord = [R(:).'; Z(:).'];
    T = mphinterp(model, 'T-273.15[K]', 'coord', coord, 't', tValue);
    T = reshape(T, size(R));

    fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 420]);
    contourf(Z, R, T, 40, 'LineColor', 'none');
    hold on;
    overlay_radial_boundaries(cfg, deltaMm);
    xlabel('z / m');
    ylabel('r / m');
    title(sprintf('%s: %s, delta = %.3g mm, t = %.3g day', ...
        titleText, modelType, deltaMm, tValue/cfg.day_s), 'FontSize', 11);
    cb = colorbar;
    cb.Label.String = 'Temperature / degC';
    axis tight;
    grid on;
    set(gca, 'FontSize', 9);
    save_png(fig, fileName);
end

function export_temperature_cloud_zoom(model, cfg, modelType, deltaMm, tValue, rRange, fileName, titleText)
    r = linspace(rRange(1), rRange(2), max(80, round(cfg.field_r_points/2)));
    z = linspace(0, cfg.L, cfg.field_z_points);
    [Z, R] = meshgrid(z, r);
    coord = [R(:).'; Z(:).'];
    T = mphinterp(model, 'T-273.15[K]', 'coord', coord, 't', tValue);
    T = reshape(T, size(R));

    fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 420]);
    contourf(Z, R, T, 40, 'LineColor', 'none');
    hold on;
    overlay_radial_boundaries(cfg, deltaMm);
    ylim(rRange);
    xlabel('z / m');
    ylabel('r / m');
    title(sprintf('%s: %s, delta = %.3g mm, t = %.3g day', ...
        titleText, modelType, deltaMm, tValue/cfg.day_s), 'FontSize', 11);
    cb = colorbar;
    cb.Label.String = 'Temperature / degC';
    grid on;
    set(gca, 'FontSize', 9);
    save_png(fig, fileName);
end

function export_geometry_figure(cfg, modelType, deltaMm, figDir)
    delta = deltaMm * 1.0e-3;
    rg = cfg.rpo + delta;
    tag = sprintf('%s_delta_%s', modelType, delta_token(deltaMm));
    fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 480]);
    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    draw_geometry_panel(cfg, modelType, deltaMm, [0, cfg.Rs], true);
    title(sprintf('Full 2D axisymmetric geometry: %s, delta = %.3g mm', modelType, deltaMm), ...
        'FontSize', 11);

    nexttile;
    rMax = min(cfg.Rs, max(rg + 0.04, cfg.rpo + 0.05));
    draw_geometry_panel(cfg, modelType, deltaMm, [0, rMax], false);
    title('Near-pipe radial structure', 'FontSize', 11);

    save_png(fig, fullfile(figDir, sprintf('Fig_COMSOL_geometry_%s.png', tag)));
end

function draw_geometry_panel(cfg, modelType, deltaMm, rLim, showLegend)
    delta = deltaMm * 1.0e-3;
    rg = cfg.rpo + delta;
    hold on;
    draw_rect(0, cfg.rpi, cfg.L, [0.70 0.86 1.00], 'air');
    draw_rect(cfg.rpi, cfg.rpo, cfg.L, [0.82 0.82 0.82], 'pipe');
    if strcmpi(modelType, 'explicit_gap') && delta > 0
        draw_rect(cfg.rpo, rg, cfg.L, [1.00 0.92 0.58], 'gap');
        soilStart = rg;
    else
        soilStart = cfg.rpo;
    end
    draw_rect(soilStart, cfg.Rs, cfg.L, [0.74 0.88 0.70], 'soil');
    overlay_radial_boundaries(cfg, deltaMm);
    xlim([0, cfg.L]);
    ylim(rLim);
    xlabel('z / m');
    ylabel('r / m');
    grid on;
    set(gca, 'FontSize', 9);
    if showLegend
        legend('Location', 'southoutside', 'Orientation', 'horizontal');
    end
end

function draw_rect(r1, r2, L, color, labelText)
    patch([0 L L 0], [r1 r1 r2 r2], color, ...
        'EdgeColor', 'none', 'DisplayName', labelText, 'FaceAlpha', 0.85);
end

function overlay_radial_boundaries(cfg, deltaMm)
    delta = deltaMm * 1.0e-3;
    rg = cfg.rpo + delta;
    yline(cfg.rpi, 'k-', 'HandleVisibility', 'off');
    yline(cfg.rpo, 'k--', 'HandleVisibility', 'off');
    if delta > 0
        yline(rg, 'k:', 'HandleVisibility', 'off');
    end
    yline(cfg.Rs, 'k-', 'HandleVisibility', 'off');
end

function save_png(fig, fileName)
    try
        exportgraphics(fig, fileName, 'Resolution', 300);
    catch
        saveas(fig, fileName);
    end
    close(fig);
end

function y = eval_global_time(model, expr, tSec)
    try
        y = mphglobal(model, expr, 't', tSec);
    catch
        % Some versions prefer solnum. This keeps the failure message close to
        % the version-sensitive API rather than hiding it.
        y = mphglobal(model, expr);
    end
    y = y(:);
    if numel(y) ~= numel(tSec)
        y = interp_to_requested_time(model, expr, tSec);
    end
end

function y = interp_to_requested_time(model, expr, tSec)
    y = mphglobal(model, expr, 't', tSec);
    y = y(:);
end

function y = eval_global_time_safe(model, expr, tSec)
    try
        y = eval_global_time(model, expr, tSec);
    catch ME
        warning('Failed to evaluate %s: %s', expr, ME.message);
        y = nan(numel(tSec),1);
    end
end

function y = eval_point_time(model, expr, r, z, tSec)
    coord = [r; z];
    try
        y = mphinterp(model, expr, 'coord', coord, 't', tSec);
    catch
        y = mphinterp(model, expr, 'coord', coord);
    end
    y = y(:);
end

function y = eval_point_time_safe(model, expr, r, z, tSec)
    try
        y = eval_point_time(model, expr, r, z, tSec);
    catch ME
        warning('Failed to evaluate %s at r = %.6g, z = %.6g: %s', ...
            expr, r, z, ME.message);
        y = nan(numel(tSec), 1);
    end
end

function y = eval_interp_time_safe(model, expr, coord, tSec)
    try
        y = mphinterp(model, expr, 'coord', coord, 't', tSec);
    catch ME
        warning('Failed to interpolate %s: %s', expr, ME.message);
        y = nan(size(coord, 2), numel(tSec));
    end
    if isvector(y)
        y = y(:);
    end
end

function TinC = tin_celsius(tSec, cfg)
    if strcmpi(cfg.temperature_profile, "table") && ~isempty(cfg.exp_time_s)
        TinC = profile_interp(tSec(:), cfg.exp_time_s(:), cfg.exp_Tin_C(:));
        return
    end
    P = cfg.P_day * cfg.day_s;
    TinC = cfg.Tin_mean_C + cfg.A_in_C .* cos(2*pi*(tSec - cfg.t_phase_day*cfg.day_s) ./ P);
end

function row = annual_energy_row(raw, cfg, modelType, deltaMm)
    tSec = raw.t_day(:) * cfg.day_s;
    Q = raw.Q_W(:);
    Ecool = trapz(tSec, max(Q, 0)) / 3.6e6;
    Eheat = trapz(tSec, max(-Q, 0)) / 3.6e6;
    Eabs = trapz(tSec, abs(Q)) / 3.6e6;
    row = table(string(modelType), deltaMm, Ecool, Eheat, Eabs, NaN, ...
        'VariableNames', {'model_type','delta_mm','Ecool_kWh','Eheat_kWh','Eabs_kWh','Dgap_percent'});
end

function annualRows = add_dgap_to_annual_rows(annualRows)
    if isempty(annualRows)
        return
    end
    for i = 1:height(annualRows)
        thisType = annualRows.model_type(i);
        base = annualRows(strcmp(annualRows.model_type, thisType) & annualRows.delta_mm == 0, :);
        if ~isempty(base) && isfinite(base.Eabs_kWh(1)) && base.Eabs_kWh(1) ~= 0
            annualRows.Dgap_percent(i) = 100 * (1 - annualRows.Eabs_kWh(i) / base.Eabs_kWh(1));
        end
    end
end

function compareRows = build_explicit_resistance_comparison(caseResults, ~)
    compareRows = table();
    if isempty(caseResults)
        return
    end
    deltas = unique([caseResults.delta_mm]);
    for i = 1:numel(deltas)
        d = deltas(i);
        modelTypeList = string({caseResults.model_type});
        idxE = find(modelTypeList == "explicit_gap" & [caseResults.delta_mm] == d, 1);
        idxR = find(modelTypeList == "resistance_gap" & [caseResults.delta_mm] == d, 1);
        if isempty(idxE) || isempty(idxR)
            continue
        end
        e = caseResults(idxE).raw;
        r = caseResults(idxR).raw;
        n = min(numel(e.t_day), numel(r.t_day));
        deltaCol = repmat(d, n, 1);
        rows = table(e.t_day(1:n), deltaCol, ...
            e.Tout_C(1:n), r.Tout_C(1:n), e.Tout_C(1:n)-r.Tout_C(1:n), ...
            e.Tpo_mid_C(1:n), r.Tpo_mid_C(1:n), ...
            e.Tg_mid_C(1:n), r.Tg_mid_C(1:n), ...
            e.DeltaTint_mid_C(1:n), r.DeltaTint_mid_C(1:n), ...
            'VariableNames', {'t_day','delta_mm','Tout_explicit_C','Tout_resistance_C', ...
            'DeltaTout_C','Tpo_explicit_C','Tpo_resistance_C','Tg_explicit_C', ...
            'Tg_resistance_C','DeltaTint_explicit_C','DeltaTint_resistance_C'});
        compareRows = [compareRows; rows]; %#ok<AGROW>
    end
end

function prefix = model_prefix(modelType)
    if strcmpi(modelType, 'explicit_gap')
        prefix = 'explicit';
    else
        prefix = 'resistance';
    end
end

function tok = delta_token(deltaMm)
    if abs(deltaMm - round(deltaMm)) < 1e-12
        tok = sprintf('%gmm', deltaMm);
    else
        tok = strrep(sprintf('%gmm', deltaMm), '.', 'p');
    end
end

function write_empty_interface_table(outputDir)
    T = table([], strings(0,1), [], [], [], [], [], ...
        'VariableNames', {'t_day','model_type','delta_mm','Tpo_mid_C','Tg_mid_C', ...
        'DeltaTint_mid_C','qg_mid_W_per_m'});
    writetable(T, fullfile(outputDir, 'COMSOL_interface_jump.csv'));
end

function write_empty_annual_table(outputDir)
    T = table(strings(0,1), [], [], [], [], [], ...
        'VariableNames', {'model_type','delta_mm','Ecool_kWh','Eheat_kWh','Eabs_kWh','Dgap_percent'});
    writetable(T, fullfile(outputDir, 'COMSOL_annual_energy_summary.csv'));
end

function write_empty_comparison_table(outputDir)
    T = table([], [], [], [], [], [], [], [], [], [], [], ...
        'VariableNames', {'t_day','delta_mm','Tout_explicit_C','Tout_resistance_C', ...
        'DeltaTout_C','Tpo_explicit_C','Tpo_resistance_C','Tg_explicit_C', ...
        'Tg_resistance_C','DeltaTint_explicit_C','DeltaTint_resistance_C'});
    writetable(T, fullfile(outputDir, 'COMSOL_explicit_vs_resistance_gap.csv'));
end
