%% run_comsol_gui_template_sharan_pipe_benchmark.m
% Load a COMSOL GUI-built Sharan turbulent pipe template and verify h/Nu.
%
% This runner intentionally does not create the turbulent physics from
% LiveLink. The physics must come from a COMSOL GUI-built model using the
% predefined Nonisothermal Flow turbulent interface.

function run_comsol_gui_template_sharan_pipe_benchmark(templatePath, runSolver)
    if nargin < 1 || isempty(templatePath)
        templatePath = fullfile(pwd, 'COMSOL_GUI_templates', 'Sharan_pipe_GUI_template.mph');
    end
    if nargin < 2
        runSolver = true;
    end

    cfg = sharan_gui_template_cfg(templatePath, runSolver);
    if ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end

    if ~exist(cfg.template_path, 'file')
        write_missing_template_note(cfg);
        error(['GUI template was not found: %s\n' ...
            'Build it in COMSOL GUI using COMSOL_GUI_Sharan_pipe_template_steps.md, ' ...
            'then rerun this script.'], cfg.template_path);
    end

    setup_livelink(cfg);

    import com.comsol.model.*
    import com.comsol.model.util.*

    model = mphload(cfg.template_path);
    set_sharan_template_parameters(model, cfg);

    if ~runSolver
        mphsave(model, fullfile(cfg.output_dir, ...
            sprintf('Sharan_pipe_GUI_template_loaded_only_%s.mph', cfg.run_id)));
        write_reference_only(cfg);
        fprintf('Template loaded and parameters updated. Solver skipped.\n');
        return
    end

    model.study(cfg.study_tag).run;

    result = extract_gui_template_benchmark(model, cfg);
    writetable(result.summary, fullfile(cfg.output_dir, 'Sharan_pipe_GUI_template_benchmark_summary.csv'));
    writetable(result.profile, fullfile(cfg.output_dir, 'Sharan_pipe_GUI_template_benchmark_axial_profile.csv'));
    writetable(result.variableProbe, fullfile(cfg.output_dir, 'Sharan_pipe_GUI_template_variable_probe.csv'));

    mphsave(model, fullfile(cfg.output_dir, ...
        sprintf('Sharan_pipe_GUI_template_solved_%s.mph', cfg.run_id)));

    fprintf('\nGUI template Sharan pipe benchmark complete.\n');
    fprintf('h_COMSOL = %.3f W/(m2 K), h_Gnielinski = %.3f W/(m2 K), ratio = %.3f\n', ...
        result.summary.h_COMSOL_W_m2K(1), result.summary.h_Gnielinski_W_m2K(1), ...
        result.summary.h_ratio_to_Gnielinski(1));
    fprintf('Tout_bulk = %.3f degC, Nu_COMSOL = %.2f, Nu_Gnielinski = %.2f\n', ...
        result.summary.Tout_bulk_C(1), result.summary.Nu_COMSOL(1), ...
        result.summary.Nu_Gnielinski(1));

    if result.summary.h_ratio_to_Gnielinski(1) < 0.7 || ...
            result.summary.h_ratio_to_Gnielinski(1) > 1.3
        warning(['GUI template benchmark failed the acceptance range. ' ...
            'Check y+, thermal wall function, turbulent Prandtl number, ' ...
            'and mass-flow weighted outlet temperature.']);
    end
end

function cfg = sharan_gui_template_cfg(templatePath, runSolver)
    cfg = struct();
    cfg.template_path = templatePath;
    cfg.output_dir = fullfile(pwd, 'COMSOL_GUI_template_Sharan_pipe_results');
    cfg.run_id = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    cfg.run_solver = runSolver;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');
    cfg.study_tag = 'std1';

    cfg.L = 50.0;
    cfg.rpi = 0.050;
    cfg.D = 2 * cfg.rpi;
    cfg.Vdot = 0.0863;
    cfg.rho_f = 0.0975 / 0.0863;
    cfg.cp_f = 1006.0;
    cfg.k_air = 0.026;
    cfg.mu_f = 1.85e-5;
    cfg.Tin_C = 39.6;
    cfg.Twall_C = 26.6;
    cfg.turbulence_intensity = 0.05;
    cfg.turbulent_length_scale_factor = 0.07;
    cfg.turbulent_prandtl = 0.85;

    cfg.eval_radial_points = 201;
    cfg.eval_z_points = [1 5 10 15 20 25 30 40 50];
end

function setup_livelink(cfg)
    if ~isempty(cfg.comsol_mli_path)
        addpath(cfg.comsol_mli_path);
    end
    if ~cfg.auto_mphstart
        return
    end
    if isempty(which('mphstart'))
        error('mphstart was not found. Check cfg.comsol_mli_path.');
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
            fprintf('MATLAB is already connected to a COMSOL server; reusing it.\n');
        else
            rethrow(ME);
        end
    end
end

function set_sharan_template_parameters(model, cfg)
    p = model.param;
    set_param_if_exists(p, 'L', sprintf('%.16g[m]', cfg.L));
    set_param_if_exists(p, 'rpi', sprintf('%.16g[m]', cfg.rpi));
    set_param_if_exists(p, 'Dhyd', '2*rpi');
    set_param_if_exists(p, 'Vdot', sprintf('%.16g[m^3/s]', cfg.Vdot));
    set_param_if_exists(p, 'rho_f', sprintf('%.16g[kg/m^3]', cfg.rho_f));
    set_param_if_exists(p, 'cp_f', sprintf('%.16g[J/(kg*K)]', cfg.cp_f));
    set_param_if_exists(p, 'k_air', sprintf('%.16g[W/(m*K)]', cfg.k_air));
    set_param_if_exists(p, 'mu_f', sprintf('%.16g[Pa*s]', cfg.mu_f));
    set_param_if_exists(p, 'mdot', 'rho_f*Vdot');
    set_param_if_exists(p, 'u_z', 'Vdot/(pi*rpi^2)');
    set_param_if_exists(p, 'Tin_K', sprintf('%.16g[degC]', cfg.Tin_C));
    set_param_if_exists(p, 'Twall_K', sprintf('%.16g[degC]', cfg.Twall_C));
    set_param_if_exists(p, 'I_turb', sprintf('%.16g', cfg.turbulence_intensity));
    set_param_if_exists(p, 'Lt_turb', sprintf('%.16g*Dhyd', cfg.turbulent_length_scale_factor));
    set_param_if_exists(p, 'Pr_turb', sprintf('%.16g', cfg.turbulent_prandtl));
end

function set_param_if_exists(param, name, value)
    try
        param.set(name, value);
    catch ME
        error(['The GUI template must define parameter "%s". ' ...
            'Add it in COMSOL GUI exactly as listed in COMSOL_GUI_Sharan_pipe_template_steps.md. ' ...
            'COMSOL message: %s'], name, ME.message);
    end
end

function result = extract_gui_template_benchmark(model, cfg)
    ref = reference_values(cfg);
    z = cfg.eval_z_points(:);
    Tbulk = nan(size(z));
    for i = 1:numel(z)
        Tbulk(i) = mass_weighted_temperature(model, cfg, z(i));
    end
    Tout = Tbulk(end);

    theta = (Tout - cfg.Twall_C) / (cfg.Tin_C - cfg.Twall_C);
    if theta <= 0 || theta >= 1 || ~isfinite(theta)
        hCfd = NaN;
    else
        hCfd = -ref.mdot * cfg.cp_f * log(theta) / (ref.P * cfg.L);
    end
    NuCfd = hCfd * cfg.D / cfg.k_air;
    Qair = ref.mdot * cfg.cp_f * (cfg.Tin_C - Tout);

    summary = table( ...
        string('Sharan_pipe_GUI_template'), ref.Re, ref.Pr, ref.u_mean, ref.mdot, ...
        cfg.Tin_C, cfg.Twall_C, Tout, ref.Tout_Gnielinski_C, ...
        hCfd, ref.h_Gnielinski, hCfd/ref.h_Gnielinski, ...
        NuCfd, ref.Nu_Gnielinski, Qair, ref.Qair_Gnielinski, ...
        'VariableNames', {'case_name','Re','Pr','u_mean_m_s','mdot_kg_s', ...
        'Tin_C','Twall_C','Tout_bulk_C','Tout_Gnielinski_C', ...
        'h_COMSOL_W_m2K','h_Gnielinski_W_m2K','h_ratio_to_Gnielinski', ...
        'Nu_COMSOL','Nu_Gnielinski','Qair_COMSOL_W','Qair_Gnielinski_W'});

    profile = table(z, Tbulk, 'VariableNames', {'z_m','Tbulk_C'});
    variableProbe = probe_variables(model, cfg);
    result = struct('summary', summary, 'profile', profile, 'variableProbe', variableProbe);
end

function ref = reference_values(cfg)
    ref = struct();
    ref.A = pi * cfg.rpi^2;
    ref.P = 2 * pi * cfg.rpi;
    ref.u_mean = cfg.Vdot / ref.A;
    ref.mdot = cfg.rho_f * cfg.Vdot;
    ref.Pr = cfg.cp_f * cfg.mu_f / cfg.k_air;
    ref.Re = cfg.rho_f * ref.u_mean * cfg.D / cfg.mu_f;
    f = (0.79 * log(ref.Re) - 1.64)^(-2);
    ref.Nu_Gnielinski = ((f / 8) * (ref.Re - 1000) * ref.Pr) / ...
        (1 + 12.7 * sqrt(f / 8) * (ref.Pr^(2/3) - 1));
    ref.h_Gnielinski = ref.Nu_Gnielinski * cfg.k_air / cfg.D;
    ref.Tout_Gnielinski_C = cfg.Twall_C + (cfg.Tin_C - cfg.Twall_C) * ...
        exp(-ref.h_Gnielinski * ref.P * cfg.L / (ref.mdot * cfg.cp_f));
    ref.Qair_Gnielinski = ref.mdot * cfg.cp_f * (cfg.Tin_C - ref.Tout_Gnielinski_C);
end

function Tbulk = mass_weighted_temperature(model, cfg, z)
    epsWall = 1.0e-6;
    zEval = min(max(z, epsWall), cfg.L - epsWall);
    r = linspace(0, cfg.rpi - epsWall, cfg.eval_radial_points).';
    coord = [r.'; zEval * ones(1, numel(r))];

    T = mphinterp(model, 'T-273.15[K]', 'coord', coord);
    T = T(:);
    uz = axial_velocity(model, coord);
    areaWeight = r;
    wgt = areaWeight .* max(uz(:), 0);
    if sum(wgt) <= 0 || any(~isfinite(wgt))
        wgt = areaWeight;
    end
    Tbulk = sum(wgt .* T) / sum(wgt);
end

function uz = axial_velocity(model, coord)
    candidates = {'w', 'spf.w', 'nitf.w', 'v', 'spf.v', 'u_z'};
    uz = nan(1, size(coord, 2));
    for i = 1:numel(candidates)
        try
            val = mphinterp(model, candidates{i}, 'coord', coord);
            val = val(:).';
            if all(isfinite(val))
                uz = val;
                return
            end
        catch
        end
    end
    error('Could not evaluate axial velocity. Check whether the template uses w or another axial velocity variable.');
end

function T = probe_variables(model, cfg)
    coord = [0.95 * cfg.rpi; 0.5 * cfg.L];
    names = {'u'; 'v'; 'w'; 'spf.u'; 'spf.v'; 'spf.w'; ...
        'k'; 'om'; 'omega'; 'ep'; 'spf.muT'; 'spf.nuT'; ...
        'ht.k_eff'; 'ht.keff'; 'ht.kteff'; 'ht.tfluxMag'; ...
        'T'; 'T-273.15[K]'};
    expr = strings(numel(names), 1);
    ok = false(numel(names), 1);
    value = nan(numel(names), 1);
    message = strings(numel(names), 1);
    for i = 1:numel(names)
        expr(i) = string(names{i});
        try
            val = mphinterp(model, names{i}, 'coord', coord);
            value(i) = val(1);
            ok(i) = isfinite(value(i));
        catch ME
            message(i) = string(ME.message);
        end
    end
    T = table(expr, ok, value, message, ...
        'VariableNames', {'expression','ok','value_at_0p95r_midpipe','message'});
end

function write_reference_only(cfg)
    ref = reference_values(cfg);
    T = table(string('Sharan_pipe_GUI_template'), ref.Re, ref.Pr, ref.u_mean, ...
        ref.mdot, ref.h_Gnielinski, ref.Nu_Gnielinski, ref.Tout_Gnielinski_C, ...
        'VariableNames', {'case_name','Re','Pr','u_mean_m_s','mdot_kg_s', ...
        'h_Gnielinski_W_m2K','Nu_Gnielinski','Tout_Gnielinski_C'});
    writetable(T, fullfile(cfg.output_dir, 'Sharan_pipe_GUI_template_reference_only.csv'));
end

function write_missing_template_note(cfg)
    if ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end
    lines = {
        'GUI template missing.'
        ''
        ['Expected path: ' cfg.template_path]
        ''
        'Build and save the model using:'
        'G:\codexproject\COMSOL_GUI_Sharan_pipe_template_steps.md'
        ''
        'Then rerun:'
        'matlab -batch "cd(''G:\codexproject''); run_comsol_gui_template_sharan_pipe_benchmark"'
        };
    fid = fopen(fullfile(cfg.output_dir, 'README_missing_GUI_template.txt'), 'w');
    cleanup = onCleanup(@() fclose(fid));
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end
