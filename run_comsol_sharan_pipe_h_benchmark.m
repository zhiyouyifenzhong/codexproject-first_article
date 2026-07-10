%% run_comsol_sharan_pipe_h_benchmark.m
% Air-side turbulent pipe heat-transfer benchmark for the Sharan 50 m EAHE.
%
% Purpose:
%   Verify that the COMSOL LiveLink turbulence + heat-transfer configuration
%   can reproduce a standard constant-wall-temperature turbulent pipe result
%   before using it in the conjugate soil model.
%
% Acceptance target:
%   h_COMSOL / h_Gnielinski should be roughly 0.7--1.3.

function run_comsol_sharan_pipe_h_benchmark(runSolver, thermalModel)
    if nargin < 1
        runSolver = true;
    end
    if nargin < 2
        thermalModel = "native_coupling";
    end

    cfg = benchmark_config(runSolver, thermalModel);
    if ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end

    setup_livelink(cfg);

    import com.comsol.model.*
    import com.comsol.model.util.*

    try
        ModelUtil.showProgress(true);
    catch
    end

    ref = reference_pipe_values(cfg);
    model = build_pipe_benchmark_model(cfg);

    if cfg.save_mph
        mphsave(model, fullfile(cfg.output_dir, ...
            sprintf('Sharan_pipe_h_benchmark_built_only_%s.mph', cfg.run_id)));
    end

    if ~runSolver
        write_reference_only(cfg, ref);
        fprintf('Built-only benchmark model saved in %s\n', cfg.output_dir);
        return
    end

    model.study('std1').run;

    result = extract_benchmark_outputs(model, cfg, ref);
    writetable(result.summary, fullfile(cfg.output_dir, 'Sharan_pipe_h_benchmark_summary.csv'));
    writetable(result.profile, fullfile(cfg.output_dir, 'Sharan_pipe_h_benchmark_axial_profile.csv'));
    writetable(result.mesh, fullfile(cfg.output_dir, 'Sharan_pipe_h_benchmark_mesh_yplus.csv'));

    if cfg.save_mph
        mphsave(model, fullfile(cfg.output_dir, ...
            sprintf('Sharan_pipe_h_benchmark_solved_%s.mph', cfg.run_id)));
    end

    fprintf('\nSharan pipe benchmark complete.\n');
    fprintf('h_COMSOL = %.3f W/(m2 K), h_Gnielinski = %.3f W/(m2 K), ratio = %.3f\n', ...
        result.summary.h_COMSOL_W_m2K(1), result.summary.h_Gnielinski_W_m2K(1), ...
        result.summary.h_ratio_to_Gnielinski(1));
    fprintf('Tout_bulk = %.3f degC, Nu_COMSOL = %.2f, Nu_Gnielinski = %.2f\n', ...
        result.summary.Tout_bulk_C(1), result.summary.Nu_COMSOL(1), result.summary.Nu_Gnielinski(1));
end

function cfg = benchmark_config(runSolver, thermalModel)
    cfg = struct();
    cfg.thermal_model = string(thermalModel);
    if strcmpi(cfg.thermal_model, "explicit_komega_diffusivity")
        cfg.output_dir = 'COMSOL_Sharan_pipe_h_benchmark_explicit_keff';
    else
        cfg.output_dir = 'COMSOL_Sharan_pipe_h_benchmark';
    end
    cfg.run_id = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    cfg.run_solver = runSolver;
    cfg.save_mph = true;

    cfg.comsol_mli_path = 'G:\COMSOL\COMSOL63\Multiphysics\mli';
    cfg.auto_mphstart = true;
    cfg.mphserver_host = 'localhost';
    cfg.mphserver_port = 2036;
    cfg.mphserver_user = getenv('COMSOL_MPH_USER');
    cfg.mphserver_password = getenv('COMSOL_MPH_PASSWORD');

    % Sharan 50 m EAHE air-side parameters.
    cfg.L = 50.0;
    cfg.rpi = 0.050;
    cfg.D = 2 * cfg.rpi;
    cfg.Vdot = 0.0863;
    cfg.rho_f = 0.0975 / 0.0863;
    cfg.cp_f = 1006.0;
    cfg.k_air = 0.026;
    cfg.mu_f = 1.85e-5;
    cfg.turbulence_intensity = 0.05;
    cfg.turbulent_length_scale_factor = 0.07;
    cfg.turbulent_prandtl = 0.85;

    % May cooling benchmark: hot air cooled by the Sharan soil temperature.
    cfg.Tin_C = 39.6;
    cfg.Twall_C = 26.6;

    % Mesh: wall-function scale, first cell center y+ should be O(30--100).
    % This is intentionally a clean benchmark separate from the soil model.
    cfg.mesh_axial_elems = 160;
    cfg.mesh_radial_elems = 60;
    cfg.eval_radial_points = 161;
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

function ref = reference_pipe_values(cfg)
    ref = struct();
    ref.A = pi * cfg.rpi^2;
    ref.P = 2 * pi * cfg.rpi;
    ref.u_mean = cfg.Vdot / ref.A;
    ref.mdot = cfg.rho_f * cfg.Vdot;
    ref.Pr = cfg.cp_f * cfg.mu_f / cfg.k_air;
    ref.Re = cfg.rho_f * ref.u_mean * cfg.D / cfg.mu_f;

    f = (0.79 * log(ref.Re) - 1.64)^(-2);
    ref.f_Darcy = f;
    ref.Nu_Gnielinski = ((f / 8) * (ref.Re - 1000) * ref.Pr) / ...
        (1 + 12.7 * sqrt(f / 8) * (ref.Pr^(2/3) - 1));
    ref.h_Gnielinski = ref.Nu_Gnielinski * cfg.k_air / cfg.D;

    ref.u_tau = ref.u_mean * sqrt(f / 8);
    ref.nu = cfg.mu_f / cfg.rho_f;
    ref.yplus_first_center_est = (cfg.rpi / cfg.mesh_radial_elems / 2) * ref.u_tau / ref.nu;
    ref.Tout_Gnielinski_C = cfg.Twall_C + (cfg.Tin_C - cfg.Twall_C) * ...
        exp(-ref.h_Gnielinski * ref.P * cfg.L / (ref.mdot * cfg.cp_f));
end

function model = build_pipe_benchmark_model(cfg)
    import com.comsol.model.*
    import com.comsol.model.util.*

    model = ModelUtil.create('SharanPipeHBenchmark');
    model.modelPath(pwd);
    model.label('Sharan 50 m turbulent pipe heat-transfer benchmark');

    comp = model.component.create('comp1', true);
    geom = comp.geom.create('geom1', 2);
    geom.axisymmetric(true);
    geom.lengthUnit('m');

    rect = geom.feature.create('air_dom', 'Rectangle');
    rect.set('pos', {'0', '0'});
    rect.set('size', {sprintf('%.16g', cfg.rpi), sprintf('%.16g', cfg.L)});
    geom.run;

    sel = create_pipe_selections(model, cfg);
    set_pipe_parameters(model, cfg);
    add_pipe_material(model, cfg);
    flowTag = add_pipe_flow_physics(comp, sel);
    add_pipe_heat_physics(comp, sel, flowTag);
    add_pipe_mesh(comp, model, cfg);
    add_pipe_study(model);
end

function sel = create_pipe_selections(model, cfg)
    comp = model.component('comp1');
    epsBox = 1.0e-8;
    sel = struct();
    sel.air = create_domain_selection(comp, 'sel_air', ...
        mphselectbox(model, 'geom1', [0 cfg.rpi; 0 cfg.L], 'domain'));
    sel.axis = create_boundary_selection(comp, 'sel_axis', ...
        mphselectbox(model, 'geom1', [-epsBox epsBox; 0 cfg.L], 'boundary'));
    sel.inlet = create_boundary_selection(comp, 'sel_inlet', ...
        mphselectbox(model, 'geom1', [0 cfg.rpi; -epsBox epsBox], 'boundary'));
    sel.outlet = create_boundary_selection(comp, 'sel_outlet', ...
        mphselectbox(model, 'geom1', [0 cfg.rpi; cfg.L-epsBox cfg.L+epsBox], 'boundary'));
    sel.wall = create_boundary_selection(comp, 'sel_wall', ...
        mphselectbox(model, 'geom1', [cfg.rpi-epsBox cfg.rpi+epsBox; 0 cfg.L], 'boundary'));
end

function tag = create_domain_selection(comp, tag, ids)
    sel = comp.selection.create(tag, 'Explicit');
    sel.geom('geom1', 2);
    sel.set(ids);
end

function tag = create_boundary_selection(comp, tag, ids)
    sel = comp.selection.create(tag, 'Explicit');
    sel.geom('geom1', 1);
    sel.set(ids);
end

function set_pipe_parameters(model, cfg)
    p = model.param;
    p.set('L', sprintf('%.16g[m]', cfg.L));
    p.set('rpi', sprintf('%.16g[m]', cfg.rpi));
    p.set('Dhyd', '2*rpi');
    p.set('rho_f', sprintf('%.16g[kg/m^3]', cfg.rho_f));
    p.set('cp_f', sprintf('%.16g[J/(kg*K)]', cfg.cp_f));
    p.set('k_air', sprintf('%.16g[W/(m*K)]', cfg.k_air));
    p.set('mu_f', sprintf('%.16g[Pa*s]', cfg.mu_f));
    p.set('Vdot', sprintf('%.16g[m^3/s]', cfg.Vdot));
    p.set('mdot', 'rho_f*Vdot');
    p.set('u_z', 'Vdot/(pi*rpi^2)');
    p.set('Tin_K', sprintf('%.16g[degC]', cfg.Tin_C));
    p.set('Twall_K', sprintf('%.16g[degC]', cfg.Twall_C));
    p.set('I_turb', sprintf('%.16g', cfg.turbulence_intensity));
    p.set('Lt_turb', sprintf('%.16g*Dhyd', cfg.turbulent_length_scale_factor));
    p.set('Pr_turb', sprintf('%.16g', cfg.turbulent_prandtl));
end

function add_pipe_material(model, cfg)
    comp = model.component('comp1');
    mat = comp.material.create('mat_air', 'Common');
    mat.label('Air Sharan benchmark');
    if strcmpi(cfg.thermal_model, "explicit_komega_diffusivity")
        kExpr = 'k_air+rho_f*k/max(om,1[1/s])*cp_f/Pr_turb';
        mat.label('Air Sharan benchmark with explicit k-omega thermal diffusivity');
    else
        kExpr = 'k_air';
    end
    mat.propertyGroup('def').set('thermalconductivity', {kExpr '0' '0' '0' kExpr '0' '0' '0' kExpr});
    mat.propertyGroup('def').set('density', 'rho_f');
    mat.propertyGroup('def').set('heatcapacity', 'cp_f');
    mat.propertyGroup('def').set('dynamicviscosity', 'mu_f');
end

function flowTag = add_pipe_flow_physics(comp, sel)
    candidates = {'TurbulentFlowSST','TurbulentFlowkOmegaSST','TurbulentFlowKOmegaSST'};
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
        error('Could not create SST turbulent flow interface. Last COMSOL error: %s', lastMsg);
    end

    spf = comp.physics(flowTag);
    spf.selection.named(sel.air);

    init = spf.feature('init1');
    set_any_required_values(init, {'u_init'}, {{'0', '0', 'u_z'}, {'0', 'u_z'}}, ...
        'flow initial velocity');
    set_any_optional(init, {'p_init'}, '0[Pa]');
    set_any_optional(init, {'k_init'}, '1.5*(u_z*I_turb)^2');
    set_any_optional(init, {'om_init'}, 'sqrt(1.5*(u_z*I_turb)^2)/(Lt_turb)');

    inlet = spf.feature.create('inl1', 'Inlet', 1);
    inlet.selection.named(sel.inlet);
    set_any_optional(inlet, {'BoundaryCondition'}, 'Velocity');
    set_any_required(inlet, {'U0in','U0','Uav','Umean','V0'}, 'u_z', 'flow inlet velocity');
    set_any_required(inlet, {'IT','I0','I'}, 'I_turb', 'inlet turbulence intensity');
    set_any_required(inlet, {'LT','Lt','L'}, 'Lt_turb', 'inlet turbulence length scale');

    outlet = spf.feature.create('out1', 'Outlet', 1);
    outlet.selection.named(sel.outlet);
    set_any_optional(outlet, {'p0','p0gh','p'}, '0[Pa]');

    wall = spf.feature.create('wall_pipe', 'Wall', 1);
    wall.selection.named(sel.wall);
    set_any_optional(wall, {'BoundaryCondition','WallCondition'}, 'NoSlip');
end

function add_pipe_heat_physics(comp, sel, flowTag)
    ht = comp.physics.create('ht', 'HeatTransferInFluids', 'geom1');
    ht.selection.named(sel.air);
    ht.feature('init1').set('Tinit', 'Tin_K');

    if ~link_heat_velocity(ht, flowTag)
        error('Heat-transfer velocity could not be linked to the turbulent flow field.');
    end

    tin = ht.feature.create('Tin', 'TemperatureBoundary', 1);
    tin.selection.named(sel.inlet);
    tin.set('T0', 'Tin_K');

    twall = ht.feature.create('Twall', 'TemperatureBoundary', 1);
    twall.selection.named(sel.wall);
    twall.set('T0', 'Twall_K');

    try
        out = ht.feature.create('out1', 'ConvectiveOutflow', 1);
        out.selection.named(sel.outlet);
    catch
        out = ht.feature.create('open_out', 'OpenBoundary', 1);
        out.selection.named(sel.outlet);
    end

    nitf = comp.multiphysics.create('nitf1', 'NonIsothermalFlow', 'geom1');
    set_required(nitf, 'Fluid_physics', flowTag, 'nonisothermal flow physics link');
    set_required(nitf, 'Heat_physics', 'ht', 'nonisothermal heat physics link');

    % These property names are COMSOL-version dependent. The benchmark records
    % failure by stopping instead of silently continuing with molecular-only
    % heat transport.
    set_any_required(nitf, {'ThermalTurbType','TurbulenceModelForHeatTransfer'}, ...
        'KaysCrawford', 'thermal turbulence model');
    set_any_required(nitf, {'ThermalWallFunction','WallTreatmentForHeatTransfer'}, ...
        'Standard', 'thermal wall function');
    set_any_required(nitf, {'Prt','PrT','TurbulentPrandtlNumber'}, ...
        'Pr_turb', 'turbulent Prandtl number');
end

function ok = link_heat_velocity(ht, flowTag)
    ok = false;
    tags = {'fluid1'};
    values = {
        {'u', '0', 'w'};
        {'u', 'w'};
        {sprintf('%s.u', flowTag), '0', sprintf('%s.w', flowTag)};
        {sprintf('%s.u', flowTag), sprintf('%s.w', flowTag)};
        {'u', '0', 'v'};
        {'u', 'v'};
        {sprintf('%s.u', flowTag), '0', sprintf('%s.v', flowTag)};
        {sprintf('%s.u', flowTag), sprintf('%s.v', flowTag)}
        };
    for i = 1:numel(tags)
        for j = 1:numel(values)
            try
                ht.feature(tags{i}).set('u_src', 'userdef');
                ht.feature(tags{i}).set('u', values{j});
                ok = true;
                return
            catch
            end
        end
    end
end

function add_pipe_mesh(comp, model, cfg)
    mesh = comp.mesh.create('mesh1');
    map = mesh.feature.create('map1', 'Map');
    map.selection.geom('geom1', 2);
    map.selection.all;

    epsBox = 1.0e-8;
    axialIds = unique([ ...
        mphselectbox(model, 'geom1', [-epsBox epsBox; 0 cfg.L], 'boundary'), ...
        mphselectbox(model, 'geom1', [cfg.rpi-epsBox cfg.rpi+epsBox; 0 cfg.L], 'boundary')]);
    radialIds = unique([ ...
        mphselectbox(model, 'geom1', [0 cfg.rpi; -epsBox epsBox], 'boundary'), ...
        mphselectbox(model, 'geom1', [0 cfg.rpi; cfg.L-epsBox cfg.L+epsBox], 'boundary')]);

    distA = map.create('dist_axial', 'Distribution');
    distA.selection.geom('geom1', 1);
    distA.selection.set(axialIds);
    distA.set('type', 'number');
    distA.set('numelem', num2str(cfg.mesh_axial_elems));

    distR = map.create('dist_radial', 'Distribution');
    distR.selection.geom('geom1', 1);
    distR.selection.set(radialIds);
    distR.set('type', 'number');
    distR.set('numelem', num2str(cfg.mesh_radial_elems));

    mesh.run;
end

function add_pipe_study(model)
    std = model.study.create('std1');
    stat = std.create('stat', 'Stationary');
    try
        stat.set('activate', {'spf','on','ht','on'});
    catch
    end
end

function result = extract_benchmark_outputs(model, cfg, ref)
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
    Qgn = ref.mdot * cfg.cp_f * (cfg.Tin_C - ref.Tout_Gnielinski_C);

    summary = table( ...
        string('Sharan_pipe_h_benchmark'), string(cfg.thermal_model), ...
        ref.Re, ref.Pr, ref.u_mean, ref.mdot, ...
        cfg.Tin_C, cfg.Twall_C, Tout, ref.Tout_Gnielinski_C, ...
        hCfd, ref.h_Gnielinski, hCfd/ref.h_Gnielinski, ...
        NuCfd, ref.Nu_Gnielinski, Qair, Qgn, ...
        'VariableNames', {'case_name','thermal_model','Re','Pr','u_mean_m_s','mdot_kg_s', ...
        'Tin_C','Twall_C','Tout_bulk_C','Tout_Gnielinski_C', ...
        'h_COMSOL_W_m2K','h_Gnielinski_W_m2K','h_ratio_to_Gnielinski', ...
        'Nu_COMSOL','Nu_Gnielinski','Qair_COMSOL_W','Qair_Gnielinski_W'});

    profile = table(z, Tbulk, 'VariableNames', {'z_m','Tbulk_C'});
    yFirstCenter = cfg.rpi / cfg.mesh_radial_elems / 2;
    mesh = table(cfg.mesh_axial_elems, cfg.mesh_radial_elems, yFirstCenter, ...
        ref.yplus_first_center_est, ...
        'VariableNames', {'axial_elements','radial_elements','first_cell_center_m', ...
        'estimated_first_cell_yplus'});

    result = struct('summary', summary, 'profile', profile, 'mesh', mesh);
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
    w = areaWeight .* max(uz(:), 0);
    if sum(w) <= 0 || any(~isfinite(w))
        w = areaWeight;
    end
    Tbulk = sum(w .* T) / sum(w);
end

function uz = axial_velocity(model, coord)
    candidates = {'w', 'spf.w', 'v', 'spf.v', 'u_z'};
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
end

function write_reference_only(cfg, ref)
    T = table(string('Sharan_pipe_h_benchmark'), ref.Re, ref.Pr, ref.u_mean, ...
        ref.mdot, ref.h_Gnielinski, ref.Nu_Gnielinski, ref.Tout_Gnielinski_C, ...
        ref.yplus_first_center_est, ...
        'VariableNames', {'case_name','Re','Pr','u_mean_m_s','mdot_kg_s', ...
        'h_Gnielinski_W_m2K','Nu_Gnielinski','Tout_Gnielinski_C', ...
        'estimated_first_cell_yplus'});
    writetable(T, fullfile(cfg.output_dir, 'Sharan_pipe_h_benchmark_reference_only.csv'));
end

function set_required(feature, propertyName, value, label)
    try
        feature.set(propertyName, value);
    catch ME
        error('Failed to set %s (%s): %s', label, propertyName, ME.message);
    end
end

function set_any_required(feature, propertyNames, value, label)
    lastMsg = '';
    for i = 1:numel(propertyNames)
        try
            feature.set(propertyNames{i}, value);
            return
        catch ME
            lastMsg = ME.message;
        end
    end
    error('Failed to set %s. Tried: %s. Last COMSOL error: %s', ...
        label, strjoin(propertyNames, ', '), lastMsg);
end

function set_any_required_values(feature, propertyNames, values, label)
    lastMsg = '';
    tried = {};
    for i = 1:numel(propertyNames)
        for j = 1:numel(values)
            tried{end+1} = propertyNames{i}; %#ok<AGROW>
            try
                feature.set(propertyNames{i}, values{j});
                return
            catch ME
                lastMsg = ME.message;
            end
        end
    end
    error('Failed to set %s. Tried properties: %s. Last COMSOL error: %s', ...
        label, strjoin(unique(tried), ', '), lastMsg);
end

function ok = set_any_optional(feature, propertyNames, value)
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
