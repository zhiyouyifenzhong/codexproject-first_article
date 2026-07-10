function result = run_eahe_simulation(overrides)
%RUN_EAHE_SIMULATION Reusable EAHE transient RC simulation.
%   result = run_eahe_simulation()
%   result = run_eahe_simulation(struct('delta_gap',0.001,'t_end',30*86400))
%
%   Model scope:
%   - horizontal EAHE pipe at z_pipe = 2 m by default
%   - vertical three-layer soil, no soil-layer interface resistance
%   - circumferential-radial near-soil RC grid
%   - fixed pipe-soil gap resistance
%   - optional weak heat-moisture coupling for layered unsaturated soil
%   - implicit Euler time integration

    if nargin < 1
        overrides = struct();
    end

    param = init_param();
    soil_pre_override = [];
    if isfield(overrides, 'soil_pre')
        soil_pre_override = overrides.soil_pre;
        overrides = rmfield(overrides, 'soil_pre');
    end
    param = apply_overrides(param, overrides);
    param = finalize_param(param);
    validate_param(param);

    if isempty(soil_pre_override)
        fprintf('Precomputing undisturbed layered soil temperature...\n');
        soil_pre = precompute_undisturbed_soil(param);
    else
        validate_soil_pre_compatibility(soil_pre_override, param);
        fprintf('Using supplied undisturbed soil temperature field...\n');
        soil_pre = soil_pre_override;
    end

    fprintf('Building EAHE RC network...\n');
    geom = build_geometry(param);
    flow0 = operating_conditions(0, param);
    [C, A, bc] = build_eahe_matrices(param, geom, soil_pre, [], flow0);

    X = build_initial_state(param, geom, soil_pre);

    useVariableGap = strcmpi(param.R_gap_mode, 'variable');
    useDynamicMatrix = useVariableGap || param.use_moisture_state ...
        || ~strcmpi(param.operation_mode, 'continuous');
    if ~useDynamicMatrix
        M = C / param.dt - A;
        dM = decomposition(M, 'lu');
    end

    result = initialize_result(param);
    result = save_time_step(result, 1, X, param, geom, soil_pre);

    snapshot_id = 1;
    result.snapshots.time = zeros(0, 1);
    result.snapshots.X = zeros(param.nState, 0);
    [result, snapshot_id] = maybe_save_snapshot(result, snapshot_id, X, param, 1);

    fprintf('Running EAHE transient simulation...\n');
    for n = 2:param.Nt
        tNew = param.time(n);
        Tin = inlet_temperature(tNew, param);
        Tprof = get_undisturbed_profile(tNew, soil_pre, param);
        flow = operating_conditions(tNew, param);

        if useDynamicMatrix
            X_old = X;
            X_iter = X_old;
            maxIter = max(param.maxIter_gap, param.maxIter_moisture);
            for iter = 1:maxIter
                [C_iter, A_iter, bc_iter] = build_eahe_matrices(param, geom, soil_pre, X_iter, flow);
                b = build_boundary_vector(param, bc_iter, Tin, Tprof);
                M = C_iter / param.dt - A_iter;
                rhs = C_iter * X_old / param.dt + b;
                X_new = M \ rhs;

                err = norm(X_new - X_iter) / max(norm(X_new), 1);
                X_iter = X_new;
                if err < min(param.tol_gap, param.tol_moisture)
                    break
                end
                if ~useVariableGap && ~param.use_moisture_state
                    break
                end
            end
            X = X_iter;
        else
            b = build_boundary_vector(param, bc, Tin, Tprof);
            rhs = C * X / param.dt + b;
            X = dM \ rhs;
        end
        X = clamp_moisture_state(X, param);

        result = save_time_step(result, n, X, param, geom, soil_pre);
        [result, snapshot_id] = maybe_save_snapshot(result, snapshot_id, X, param, n);
    end

    result.X_final = X;
    result.param = param;
    result.soil_pre = soil_pre;
    result.geom = geom;
    result.C = C;
    result.A = A;
    result.bc = bc;
    result.degradation = calc_degradation_metrics(result, param);
end

function param = init_param()
    param.model_revision = 'soil_phase_offset_v2';
    param.day = 24 * 3600;
    param.year = 365 * param.day;

    param.L_pipe = 40.0;
    param.D_i = 0.20;
    param.D_o = 0.22;
    param.r_i = param.D_i / 2;
    param.r_o = param.D_o / 2;
    param.z_pipe = 2.0;
    param.Nx_pipe = 40;

    param.Ntheta = 8;
    param.Nr = 6;
    param.r_soil_max = 1.80;

    param.rho_air = 1.20;
    param.cp_air = 1006.0;
    param.k_air = 0.026;
    param.mu_air = 1.85e-5;
    param.m_dot = 0.08;

    param.k_pipe = 0.40;
    param.rho_pipe = 950.0;
    param.cp_pipe = 1900.0;

    param.delta_gap = 0.002;
    param.k_gap_eff = 0.050;
    param.R_gap_mode = 'constant'; % 'constant' or 'variable'
    param.a_gap_T = 0.02;          % 1/K, positive means warmer near-soil increases gap resistance.
    param.T_gap_ref = 15.0;        % degC
    param.R_gap_min_factor = 0.50;
    param.R_gap_max_factor = 3.00;
    param.tol_gap = 1e-6;
    param.maxIter_gap = 20;

    param.n_layer = 3;
    param.z_layer_top = [0.0, 1.0, 3.0];
    param.z_layer_bot = [1.0, 3.0, 8.0];
    param.k_soil = [1.10, 1.55, 1.80];
    param.rho_soil = [1500.0, 1700.0, 1850.0];
    param.cp_soil = [1300.0, 1400.0, 1450.0];
    param.moisture_model = 'off'; % 'off', 'property_only', or 'diffusion'
    param.theta_soil = [0.18, 0.20, 0.22];
    param.theta_ref = param.theta_soil;
    param.theta_min = 0.05;
    param.theta_max = 0.45;
    param.rho_water = 1000.0;
    param.cp_water = 4180.0;
    param.k_theta_slope = [3.0, 3.0, 3.0]; % W/(m K) per m3/m3
    param.D_theta = [2.0e-7, 2.0e-7, 2.0e-7]; % m2/s
    param.D_T = [1.0e-9, 1.0e-9, 1.0e-9]; % m2/(s K)
    param.L_v = 2.45e6; % J/kg, latent heat of vaporization near ambient temperature
    param.D_theta_v = [1.0e-10, 1.0e-10, 1.0e-10]; % vapor-related moisture diffusivity, m2/s
    param.D_T_v = [1.0e-12, 1.0e-12, 1.0e-12]; % vapor thermal-diffusion coefficient, m2/(s K)
    param.tol_moisture = 1e-6;
    param.maxIter_moisture = 10;
    param.include_latent_heat = false;

    param.operation_mode = 'continuous'; % 'continuous', 'on_off', 'liu_60_30', or 'liu_60_60'
    param.operation_on_time = 60 * 60;
    param.operation_off_time = 0;
    param.h_in_off = 2.0;

    param.z_max = 8.0;
    param.Nz_soil = 161;
    param.dt_pre = 3600.0;
    param.n_year_pre = 4;
    param.h_surface = 12.0;
    param.T_deep = 15.0;

    param.T_air_mean = 15.0;
    param.T_air_amp_year = 12.0;
    param.T_air_amp_day = 4.0;
    param.phase_year = 115 * param.day;
    param.phase_day = 14 * 3600;
    % EAHE simulation time starts at this day of the undisturbed soil annual
    % cycle. For summer cooling, use a summer day so the precomputed soil
    % temperature field is consistent with the hot inlet-air condition.
    param.operation_start_day = 210;
    param.soil_time_offset = param.operation_start_day * param.day;

    param.Tin_mode = 'sine';
    param.Tin_const = 35.0;
    param.Tin_mean = 32.0;
    param.Tin_amp = 5.0;
    param.Tin_phase = 15 * 3600;

    param.dt = 300.0;
    param.t_end = 7 * param.day;

    param.snapshot_times = [0, 12, 24, 72, 168] * 3600;
end

function param = apply_overrides(param, overrides)
    names = fieldnames(overrides);
    for i = 1:numel(names)
        param.(names{i}) = overrides.(names{i});
    end
end

function param = finalize_param(param)
    param.r_i = param.D_i / 2;
    param.r_o = param.D_o / 2;
    param.dx_pipe = param.L_pipe / param.Nx_pipe;
    param.dtheta = 2 * pi / param.Ntheta;
    param.soil_time_offset = param.operation_start_day * param.day;
    param.time = (0:param.dt:param.t_end).';
    param.Nt = numel(param.time);
    param.nNode_seg = 2 + param.Ntheta * param.Nr;
    param.nThermalState = param.Nx_pipe * param.nNode_seg;
    param.nMoistNode = param.Nx_pipe * param.Ntheta * param.Nr;
    param.use_moisture_state = strcmpi(param.moisture_model, 'diffusion');
    if param.use_moisture_state
        param.nState = param.nThermalState + param.nMoistNode;
    else
        param.nState = param.nThermalState;
    end
    param.h_in = calc_internal_h_for_mdot(param, param.m_dot);
    [param.operation_on_time, param.operation_off_time] = operation_times(param);
    param.snapshot_times = param.snapshot_times(param.snapshot_times <= param.t_end);
end

function validate_param(param)
    if param.D_i <= 0 || param.D_o <= param.D_i
        error('Invalid pipe diameters: require D_o > D_i > 0.');
    end
    if param.L_pipe <= 0 || param.Nx_pipe < 1
        error('Invalid axial discretization: require L_pipe > 0 and Nx_pipe >= 1.');
    end
    if param.Ntheta < 4 || param.Nr < 2
        error('Invalid soil grid: require Ntheta >= 4 and Nr >= 2.');
    end
    if param.delta_gap < 0 || param.k_gap_eff <= 0
        error('Invalid gap properties: require delta_gap >= 0 and k_gap_eff > 0.');
    end
    if param.r_o + param.delta_gap >= param.r_soil_max
        error('Invalid near-soil domain: r_soil_max must exceed r_o + delta_gap.');
    end
    if param.z_pipe - param.r_soil_max < 0
        error(['The upper near-soil boundary crosses the ground surface. ', ...
            'For the current RC boundary treatment require r_soil_max <= z_pipe.']);
    end
    if param.z_pipe + param.r_soil_max > param.z_max
        error('The lower near-soil boundary exceeds z_max. Increase z_max or reduce r_soil_max.');
    end
    if param.z_layer_top(1) ~= 0 || param.z_layer_bot(end) < param.z_max
        error('Soil layer bounds must start at 0 and cover z_max.');
    end
    if numel(param.k_soil) ~= param.n_layer ...
            || numel(param.rho_soil) ~= param.n_layer ...
            || numel(param.cp_soil) ~= param.n_layer
        error('Soil property arrays must have n_layer entries.');
    end
    if any(strcmpi(param.moisture_model, {'property_only', 'diffusion'}))
        if numel(param.theta_soil) ~= param.n_layer ...
                || numel(param.theta_ref) ~= param.n_layer ...
                || numel(param.k_theta_slope) ~= param.n_layer ...
                || numel(param.D_theta) ~= param.n_layer ...
                || numel(param.D_T) ~= param.n_layer ...
                || numel(param.D_theta_v) ~= param.n_layer ...
                || numel(param.D_T_v) ~= param.n_layer
            error('Moisture property arrays must have n_layer entries.');
        end
        if any(param.theta_soil < param.theta_min) || any(param.theta_soil > param.theta_max)
            error('Initial soil water contents must be inside [theta_min, theta_max].');
        end
        if param.include_latent_heat && ~strcmpi(param.moisture_model, 'diffusion')
            error('include_latent_heat requires moisture_model = ''diffusion''.');
        end
    elseif ~strcmpi(param.moisture_model, 'off')
        error('Unknown moisture_model: %s', param.moisture_model);
    end
    if any(param.D_theta < 0) || any(param.D_T < 0) ...
            || any(param.D_theta_v < 0) || any(param.D_T_v < 0)
        error('Moisture transport coefficients must be non-negative.');
    end
    if param.L_v < 0
        error('L_v must be non-negative.');
    end
    if param.theta_min < 0 || param.theta_max <= param.theta_min
        error('Invalid moisture bounds.');
    end
    validModes = {'continuous', 'on_off', 'liu_60_30', 'liu_60_60'};
    if ~any(strcmpi(param.operation_mode, validModes))
        error('Unknown operation_mode: %s', param.operation_mode);
    end
    if param.operation_on_time <= 0 || param.operation_off_time < 0
        error('Operation timing requires operation_on_time > 0 and operation_off_time >= 0.');
    end
    if param.z_pipe < param.z_layer_top(2) || param.z_pipe > param.z_layer_bot(2)
        warning('Pipe depth is not inside layer 2. Check whether this is intended.');
    end
    if param.operation_start_day < 0 || param.operation_start_day >= 365
        error('operation_start_day must be in [0, 365).');
    end
    if param.dt <= 0 || param.t_end <= 0
        error('Time settings must satisfy dt > 0 and t_end > 0.');
    end
end

function validate_soil_pre_compatibility(soil_pre, param)
    if ~isfield(soil_pre, 'signature')
        error(['Supplied soil_pre has no compatibility signature. ', ...
            'It was likely generated by an old model revision; recompute it.']);
    end
    current = soil_signature(param);
    if ~isequaln(soil_pre.signature, current)
        error(['Supplied soil_pre is incompatible with current soil/boundary settings. ', ...
            'Recompute the undisturbed soil field instead of reusing it.']);
    end
end

function signature = soil_signature(param)
    signature.model_revision = param.model_revision;
    signature.z_max = param.z_max;
    signature.Nz_soil = param.Nz_soil;
    signature.dt_pre = param.dt_pre;
    signature.n_year_pre = param.n_year_pre;
    signature.h_surface = param.h_surface;
    signature.T_deep = param.T_deep;
    signature.T_air_mean = param.T_air_mean;
    signature.T_air_amp_year = param.T_air_amp_year;
    signature.T_air_amp_day = param.T_air_amp_day;
    signature.phase_year = param.phase_year;
    signature.phase_day = param.phase_day;
    signature.n_layer = param.n_layer;
    signature.z_layer_top = param.z_layer_top;
    signature.z_layer_bot = param.z_layer_bot;
    signature.k_soil = param.k_soil;
    signature.rho_soil = param.rho_soil;
    signature.cp_soil = param.cp_soil;
    signature.moisture_model = param.moisture_model;
    signature.theta_soil = param.theta_soil;
    signature.theta_ref = param.theta_ref;
    signature.k_theta_slope = param.k_theta_slope;
    signature.rho_water = param.rho_water;
    signature.cp_water = param.cp_water;
end

function h = calc_internal_h(param)
    h = calc_internal_h_for_mdot(param, param.m_dot);
end

function h = calc_internal_h_for_mdot(param, mDot)
    if mDot <= 0
        h = param.h_in_off;
        return
    end
    A = pi * param.D_i^2 / 4;
    v = mDot / (param.rho_air * A);
    Re = param.rho_air * v * param.D_i / param.mu_air;
    Pr = param.cp_air * param.mu_air / param.k_air;
    if Re < 2300
        Nu = 3.66;
    else
        Nu = 0.023 * Re^0.8 * Pr^0.4;
    end
    h = Nu * param.k_air / param.D_i;
end

function result = initialize_result(param)
    result.time = param.time(:);
    result.Tin = zeros(param.Nt, 1);
    result.Tout = zeros(param.Nt, 1);
    result.Q = zeros(param.Nt, 1);
    result.Tpipe_mid = zeros(param.Nt, 1);
    result.Tsoil_near_mid_mean = zeros(param.Nt, 1);
    result.Tsoil_near_mid_top = zeros(param.Nt, 1);
    result.Tsoil_near_mid_bottom = zeros(param.Nt, 1);
    result.Tundist_pipe = zeros(param.Nt, 1);
    result.Rgap_factor_mid_mean = zeros(param.Nt, 1);
    result.is_operating = false(param.Nt, 1);
    result.m_dot_eff = zeros(param.Nt, 1);
    result.theta_near_mid_mean = nan(param.Nt, 1);
    result.theta_near_mid_top = nan(param.Nt, 1);
    result.theta_near_mid_bottom = nan(param.Nt, 1);
end

function result = save_time_step(result, n, X, param, geom, soil_pre)
    t = param.time(n);
    Tin = inlet_temperature(t, param);
    flow = operating_conditions(t, param);
    Tprof = get_undisturbed_profile(t, soil_pre, param);
    mid = round(param.Nx_pipe / 2);
    result.Tin(n) = Tin;
    result.Tout(n) = X(idx_Ta(param.Nx_pipe, param));
    result.Q(n) = flow.m_dot * param.cp_air * (Tin - result.Tout(n));
    result.Tpipe_mid(n) = X(idx_Tp(mid, param));
    result.Tundist_pipe(n) = interp1(soil_pre.z, Tprof, param.z_pipe, 'linear', 'extrap');
    result.is_operating(n) = flow.is_on;
    result.m_dot_eff(n) = flow.m_dot;

    near = zeros(param.Ntheta, 1);
    thetaNear = nan(param.Ntheta, 1);
    for m = 1:param.Ntheta
        near(m) = X(idx_Ts(mid, m, 1, param));
        thetaNear(m) = soil_theta_node(mid, m, 1, param, geom, X);
    end
    result.Tsoil_near_mid_mean(n) = mean(near);
    [~, top_m] = min(abs(wrap_to_pi(geom.theta - 3*pi/2)));
    [~, bottom_m] = min(abs(wrap_to_pi(geom.theta - pi/2)));
    result.Tsoil_near_mid_top(n) = near(top_m);
    result.Tsoil_near_mid_bottom(n) = near(bottom_m);
    result.theta_near_mid_mean(n) = mean(thetaNear);
    result.theta_near_mid_top(n) = thetaNear(top_m);
    result.theta_near_mid_bottom(n) = thetaNear(bottom_m);
    if strcmpi(param.R_gap_mode, 'variable')
        result.Rgap_factor_mid_mean(n) = mean(gap_factor_from_temperature(near, param));
    else
        result.Rgap_factor_mid_mean(n) = 1.0;
    end
end

function [result, snapshot_id] = maybe_save_snapshot(result, snapshot_id, X, param, n)
    if snapshot_id > numel(param.snapshot_times)
        return
    end
    if abs(param.time(n) - param.snapshot_times(snapshot_id)) <= param.dt / 2
        result.snapshots.time(end+1, 1) = param.time(n);
        result.snapshots.X(:, end+1) = X;
        snapshot_id = snapshot_id + 1;
    end
end

function metrics = calc_degradation_metrics(result, param)
    nPerDay = round(param.day / param.dt);
    nDay = floor(numel(result.time) / nPerDay);
    metrics.day = (1:nDay).';
    metrics.Q_day_mean = zeros(nDay, 1);
    metrics.dT_day_mean = zeros(nDay, 1);
    metrics.near_soil_rise_day_mean = zeros(nDay, 1);
    for d = 1:nDay
        id = (d-1)*nPerDay + (1:nPerDay);
        metrics.Q_day_mean(d) = mean(result.Q(id));
        metrics.dT_day_mean(d) = mean(result.Tin(id) - result.Tout(id));
        metrics.near_soil_rise_day_mean(d) = mean(result.Tsoil_near_mid_mean(id) - result.Tundist_pipe(id));
    end
    if nDay > 0 && abs(metrics.Q_day_mean(1)) > eps
        metrics.eta_Q_day = metrics.Q_day_mean / metrics.Q_day_mean(1);
    else
        metrics.eta_Q_day = nan(nDay, 1);
    end
    if nDay > 0 && abs(metrics.dT_day_mean(1)) > eps
        metrics.eta_dT_day = metrics.dT_day_mean / metrics.dT_day_mean(1);
    else
        metrics.eta_dT_day = nan(nDay, 1);
    end
end

function soil_pre = precompute_undisturbed_soil(param)
    dz = param.z_max / param.Nz_soil;
    z = ((1:param.Nz_soil).' - 0.5) * dz;
    [kz, rhocz] = layer_properties(z, param);

    C = spdiags(rhocz * dz, 0, param.Nz_soil, param.Nz_soil);
    A = sparse(param.Nz_soil, param.Nz_soil);
    bcTopG = 1 / (1 / param.h_surface + (dz / 2) / kz(1));
    bcBotG = 1 / ((dz / 2) / kz(end));

    for j = 1:param.Nz_soil-1
        R = (dz / 2) / kz(j) + (dz / 2) / kz(j+1);
        G = 1 / R;
        A = add_link(A, j, j+1, G);
    end
    A(1, 1) = A(1, 1) - bcTopG;
    A(end, end) = A(end, end) - bcBotG;

    M = C / param.dt_pre - A;
    dM = decomposition(M, 'lu');

    T = param.T_deep * ones(param.Nz_soil, 1);
    Nt_pre = round(param.n_year_pre * param.year / param.dt_pre);
    start_last = (param.n_year_pre - 1) * param.year;
    nSave = round(param.year / param.dt_pre) + 1;
    Tsave = zeros(param.Nz_soil, nSave);
    tsave = zeros(1, nSave);
    saveId = 0;

    for n = 0:Nt_pre
        t = n * param.dt_pre;
        if t >= start_last - 0.5 * param.dt_pre
            saveId = saveId + 1;
            if saveId <= nSave
                Tsave(:, saveId) = T;
                tsave(saveId) = t - start_last;
            end
        end
        if n == Nt_pre
            break
        end

        tNew = (n + 1) * param.dt_pre;
        Tair = outdoor_air_temperature(tNew, param);
        b = zeros(param.Nz_soil, 1);
        b(1) = b(1) + bcTopG * Tair;
        b(end) = b(end) + bcBotG * param.T_deep;
        rhs = C * T / param.dt_pre + b;
        T = dM \ rhs;
    end

    soil_pre.z = z;
    soil_pre.time = tsave(1:saveId);
    soil_pre.T = Tsave(:, 1:saveId);
    soil_pre.signature = soil_signature(param);
end

function geom = build_geometry(param)
    r_inner_soil = param.r_o + param.delta_gap;
    geom.r_edges = logspace(log10(r_inner_soil), log10(param.r_soil_max), param.Nr + 1).';
    geom.r_centers = sqrt(geom.r_edges(1:end-1) .* geom.r_edges(2:end));
    geom.theta = ((1:param.Ntheta).' - 0.5) * param.dtheta;
end

function [C, A, bc] = build_eahe_matrices(param, geom, soil_pre, X_gap, flow)
    if nargin < 5 || isempty(flow)
        flow = operating_conditions(0, param);
    end
    C = sparse(param.nState, param.nState);
    A = sparse(param.nState, param.nState);

    bc.inletRow = idx_Ta(1, param);
    bc.inletG = flow.m_dot * param.cp_air;
    bc.farRows = [];
    bc.farG = [];
    bc.farZ = [];
    bc.soilZ = soil_pre.z;

    Vair = pi * param.D_i^2 / 4 * param.dx_pipe;
    Ca = param.rho_air * param.cp_air * Vair;
    Cp = param.rho_pipe * param.cp_pipe ...
        * pi * (param.r_o^2 - param.r_i^2) * param.dx_pipe;
    Rconv = 1 / (flow.h_in * pi * param.D_i * param.dx_pipe);
    Gconv = 1 / Rconv;

    rInnerSoil = param.r_o + param.delta_gap;

    for i = 1:param.Nx_pipe
        ia = idx_Ta(i, param);
        ip = idx_Tp(i, param);

        C(ia, ia) = Ca;
        C(ip, ip) = Cp;
        A = add_link(A, ia, ip, Gconv);

        A(ia, ia) = A(ia, ia) - flow.m_dot * param.cp_air;
        if i > 1
            A(ia, idx_Ta(i-1, param)) = A(ia, idx_Ta(i-1, param)) ...
                + flow.m_dot * param.cp_air;
        end

        for m = 1:param.Ntheta
            theta = geom.theta(m);
            is1 = idx_Ts(i, m, 1, param);
            z1 = node_depth(param.z_pipe, geom.r_centers(1), theta);
            k1 = soil_k_node(i, m, 1, param, geom, X_gap);

            Rpipe = log(param.r_o / param.r_i) ...
                / (param.k_pipe * param.dtheta * param.dx_pipe);
            RgapBase = log(rInnerSoil / param.r_o) ...
                / (param.k_gap_eff * param.dtheta * param.dx_pipe);
            if strcmpi(param.R_gap_mode, 'variable') && ~isempty(X_gap)
                TsNear = X_gap(is1);
                RgapFactor = gap_factor_from_temperature(TsNear, param);
            else
                RgapFactor = 1.0;
            end
            Rgap = RgapBase * RgapFactor;
            RsoilHalf = log(geom.r_centers(1) / rInnerSoil) ...
                / (k1 * param.dtheta * param.dx_pipe);
            Gps = 1 / (Rpipe + Rgap + RsoilHalf);
            A = add_link(A, ip, is1, Gps);
        end

        for m = 1:param.Ntheta
            theta = geom.theta(m);
            for r = 1:param.Nr
                is = idx_Ts(i, m, r, param);
                rin = geom.r_edges(r);
                rout = geom.r_edges(r+1);
                rc = geom.r_centers(r);
                zc = node_depth(param.z_pipe, rc, theta);
                rhoc = soil_rhoc_node(i, m, r, param, geom, X_gap);
                V = 0.5 * (rout^2 - rin^2) * param.dtheta * param.dx_pipe;
                C(is, is) = rhoc * V;
            end

            for r = 1:param.Nr-1
                isA = idx_Ts(i, m, r, param);
                isB = idx_Ts(i, m, r+1, param);
                rFace = geom.r_edges(r+1);
                rA = geom.r_centers(r);
                rB = geom.r_centers(r+1);
                zA = node_depth(param.z_pipe, rA, theta);
                zB = node_depth(param.z_pipe, rB, theta);
                kA = soil_k_node(i, m, r, param, geom, X_gap);
                kB = soil_k_node(i, m, r+1, param, geom, X_gap);
                R = log(rFace / rA) / (kA * param.dtheta * param.dx_pipe) ...
                    + log(rB / rFace) / (kB * param.dtheta * param.dx_pipe);
                A = add_link(A, isA, isB, 1 / R);
            end

            isFar = idx_Ts(i, m, param.Nr, param);
            rFar = geom.r_edges(end);
            rC = geom.r_centers(end);
            zC = node_depth(param.z_pipe, rC, theta);
            zFar = node_depth(param.z_pipe, rFar, theta);
            kC = soil_k_node(i, m, param.Nr, param, geom, X_gap);
            Rfar = log(rFar / rC) / (kC * param.dtheta * param.dx_pipe);
            Gfar = 1 / Rfar;
            A(isFar, isFar) = A(isFar, isFar) - Gfar;
            bc.farRows(end+1, 1) = isFar;
            bc.farG(end+1, 1) = Gfar;
            bc.farZ(end+1, 1) = zFar;
        end

        for r = 1:param.Nr
            rin = geom.r_edges(r);
            rout = geom.r_edges(r+1);
            rc = geom.r_centers(r);
            dr = rout - rin;
            for m = 1:param.Ntheta
                mNext = m + 1;
                if mNext > param.Ntheta
                    mNext = 1;
                end
                isA = idx_Ts(i, m, r, param);
                isB = idx_Ts(i, mNext, r, param);
                zA = node_depth(param.z_pipe, rc, geom.theta(m));
                zB = node_depth(param.z_pipe, rc, geom.theta(mNext));
                kA = soil_k_node(i, m, r, param, geom, X_gap);
                kB = soil_k_node(i, mNext, r, param, geom, X_gap);
                kEff = harmonic_mean(kA, kB);
                Rtheta = rc * param.dtheta / (kEff * dr * param.dx_pipe);
                A = add_link(A, isA, isB, 1 / Rtheta);
            end
        end
    end

    if param.use_moisture_state
        [C, A] = add_moisture_diffusion_network(C, A, param, geom);
    end
end

function X = build_initial_state(param, geom, soil_pre)
    Tprof0 = get_undisturbed_profile(0, soil_pre, param);
    X = zeros(param.nState, 1);
    Tin0 = inlet_temperature(0, param);
    Tpipe0 = interp1(soil_pre.z, Tprof0, param.z_pipe, 'linear', 'extrap');

    for i = 1:param.Nx_pipe
        X(idx_Ta(i, param)) = Tin0;
        X(idx_Tp(i, param)) = Tpipe0;
        for m = 1:param.Ntheta
            theta = geom.theta(m);
            for r = 1:param.Nr
                zc = node_depth(param.z_pipe, geom.r_centers(r), theta);
                X(idx_Ts(i, m, r, param)) = interp1(soil_pre.z, Tprof0, zc, 'linear', 'extrap');
                if param.use_moisture_state
                    X(idx_theta(i, m, r, param)) = soil_theta_at_depth(zc, param);
                end
            end
        end
    end
end

function X = clamp_moisture_state(X, param)
    if ~param.use_moisture_state
        return
    end
    ids = (param.nThermalState + 1):param.nState;
    X(ids) = min(max(X(ids), param.theta_min), param.theta_max);
end

function b = build_boundary_vector(param, bc, Tin, Tprof)
    b = zeros(param.nState, 1);
    b(bc.inletRow) = b(bc.inletRow) + bc.inletG * Tin;
    Tfar = interp1(bc.soilZ, Tprof, bc.farZ, 'linear', 'extrap');
    for j = 1:numel(bc.farRows)
        b(bc.farRows(j)) = b(bc.farRows(j)) + bc.farG(j) * Tfar(j);
    end
end

function flow = operating_conditions(t, param)
    [onTime, offTime] = operation_times(param);
    if offTime <= 0
        isOn = true;
    else
        cycle = onTime + offTime;
        isOn = mod(t, cycle) < onTime;
    end
    if isOn
        mDot = param.m_dot;
    else
        mDot = 0.0;
    end
    flow.is_on = isOn;
    flow.m_dot = mDot;
    flow.h_in = calc_internal_h_for_mdot(param, mDot);
end

function [onTime, offTime] = operation_times(param)
    switch lower(param.operation_mode)
        case 'continuous'
            onTime = param.operation_on_time;
            offTime = 0.0;
        case 'on_off'
            onTime = param.operation_on_time;
            offTime = param.operation_off_time;
        case 'liu_60_30'
            onTime = 60 * 60;
            offTime = 30 * 60;
        case 'liu_60_60'
            onTime = 60 * 60;
            offTime = 60 * 60;
        otherwise
            error('Unknown operation_mode: %s', param.operation_mode);
    end
end

function T = outdoor_air_temperature(t, param)
    T = param.T_air_mean ...
        + param.T_air_amp_year * sin(2*pi*(t - param.phase_year) / param.year) ...
        + param.T_air_amp_day * sin(2*pi*(t - param.phase_day) / param.day);
end

function Tin = inlet_temperature(t, param)
    switch lower(param.Tin_mode)
        case 'constant'
            Tin = param.Tin_const;
        case 'sine'
            Tin = param.Tin_mean ...
                + param.Tin_amp * sin(2*pi*(t - param.Tin_phase) / param.day);
        otherwise
            error('Unknown Tin_mode: %s', param.Tin_mode);
    end
end

function Tprof = get_undisturbed_profile(t, soil_pre, param)
    if isfield(param, 'soil_time_offset')
        tq = mod(t + param.soil_time_offset, param.year);
    else
        tq = mod(t, param.year);
    end
    tt = soil_pre.time(:);
    TT = soil_pre.T;
    if tt(end) < param.year
        tt = [tt; param.year];
        TT = [TT, TT(:, 1)];
    end
    Tprof = interp1(tt, TT.', tq, 'linear', 'extrap').';
end

function [k, rhoc] = layer_properties(z, param)
    k = zeros(size(z));
    rhoc = zeros(size(z));
    for n = 1:numel(z)
        layer = find_layer(z(n), param);
        theta = soil_theta_at_depth(z(n), param);
        [k(n), rhoc(n)] = soil_properties_from_theta(layer, theta, param);
    end
end

function k = soil_k_at_depth(z, param)
    layer = find_layer(z, param);
    theta = soil_theta_at_depth(z, param);
    [k, ~] = soil_properties_from_theta(layer, theta, param);
end

function theta = soil_theta_at_depth(z, param)
    layer = find_layer(z, param);
    if any(strcmpi(param.moisture_model, {'property_only', 'diffusion'}))
        theta = param.theta_soil(layer);
    else
        theta = param.theta_ref(layer);
    end
    theta = clamp_theta(theta, param);
end

function theta = soil_theta_node(i, m, r, param, geom, X)
    if param.use_moisture_state && ~isempty(X)
        theta = X(idx_theta(i, m, r, param));
    else
        z = node_depth(param.z_pipe, geom.r_centers(r), geom.theta(m));
        theta = soil_theta_at_depth(z, param);
    end
    theta = clamp_theta(theta, param);
end

function k = soil_k_node(i, m, r, param, geom, X)
    z = node_depth(param.z_pipe, geom.r_centers(r), geom.theta(m));
    layer = find_layer(z, param);
    theta = soil_theta_node(i, m, r, param, geom, X);
    [k, ~] = soil_properties_from_theta(layer, theta, param);
end

function rhoc = soil_rhoc_node(i, m, r, param, geom, X)
    z = node_depth(param.z_pipe, geom.r_centers(r), geom.theta(m));
    layer = find_layer(z, param);
    theta = soil_theta_node(i, m, r, param, geom, X);
    [~, rhoc] = soil_properties_from_theta(layer, theta, param);
end

function [k, rhoc] = soil_properties_from_theta(layer, theta, param)
    theta = clamp_theta(theta, param);
    if strcmpi(param.moisture_model, 'off')
        k = param.k_soil(layer);
        rhoc = param.rho_soil(layer) * param.cp_soil(layer);
        return
    end
    dtheta = theta - param.theta_ref(layer);
    k = param.k_soil(layer) + param.k_theta_slope(layer) * dtheta;
    k = max(k, 0.05);
    rhoc = param.rho_soil(layer) * param.cp_soil(layer) ...
        + param.rho_water * param.cp_water * dtheta;
    rhoc = max(rhoc, 5.0e5);
end

function theta = clamp_theta(theta, param)
    theta = min(max(theta, param.theta_min), param.theta_max);
end

function layer = find_layer(z, param)
    zc = min(max(z, 0), param.z_max);
    layer = find(zc >= param.z_layer_top & zc < param.z_layer_bot, 1, 'first');
    if isempty(layer)
        layer = param.n_layer;
    end
end

function z = node_depth(zPipe, r, theta)
    z = zPipe + r * sin(theta);
end

function [C, A] = add_moisture_diffusion_network(C, A, param, geom)
    for i = 1:param.Nx_pipe
        for m = 1:param.Ntheta
            thetaAng = geom.theta(m);
            for r = 1:param.Nr
                ith = idx_theta(i, m, r, param);
                rin = geom.r_edges(r);
                rout = geom.r_edges(r+1);
                V = 0.5 * (rout^2 - rin^2) * param.dtheta * param.dx_pipe;
                C(ith, ith) = V;
            end

            for r = 1:param.Nr-1
                ithA = idx_theta(i, m, r, param);
                ithB = idx_theta(i, m, r+1, param);
                itA = idx_Ts(i, m, r, param);
                itB = idx_Ts(i, m, r+1, param);
                rFace = geom.r_edges(r+1);
                area = rFace * param.dtheta * param.dx_pipe;
                dist = geom.r_centers(r+1) - geom.r_centers(r);
                zA = node_depth(param.z_pipe, geom.r_centers(r), thetaAng);
                zB = node_depth(param.z_pipe, geom.r_centers(r+1), thetaAng);
                [Dtheta, DT] = moisture_transport_coefficients(zA, zB, param);
                Gtheta = Dtheta * area / dist;
                GT = DT * area / dist;
                A = add_link(A, ithA, ithB, Gtheta);
                A = add_gradient_coupling(A, ithA, ithB, itA, itB, GT);
                if param.include_latent_heat
                    [DthetaV, DTV] = vapor_transport_coefficients(zA, zB, param);
                    GthetaV = DthetaV * area / dist;
                    GTV = DTV * area / dist;
                    A = add_latent_heat_coupling(A, itA, itB, ithA, ithB, GthetaV, GTV, param);
                end
            end
        end

        for r = 1:param.Nr
            rin = geom.r_edges(r);
            rout = geom.r_edges(r+1);
            rc = geom.r_centers(r);
            dr = rout - rin;
            for m = 1:param.Ntheta
                mNext = m + 1;
                if mNext > param.Ntheta
                    mNext = 1;
                end
                ithA = idx_theta(i, m, r, param);
                ithB = idx_theta(i, mNext, r, param);
                itA = idx_Ts(i, m, r, param);
                itB = idx_Ts(i, mNext, r, param);
                area = dr * param.dx_pipe;
                dist = rc * param.dtheta;
                zA = node_depth(param.z_pipe, rc, geom.theta(m));
                zB = node_depth(param.z_pipe, rc, geom.theta(mNext));
                [Dtheta, DT] = moisture_transport_coefficients(zA, zB, param);
                Gtheta = Dtheta * area / dist;
                GT = DT * area / dist;
                A = add_link(A, ithA, ithB, Gtheta);
                A = add_gradient_coupling(A, ithA, ithB, itA, itB, GT);
                if param.include_latent_heat
                    [DthetaV, DTV] = vapor_transport_coefficients(zA, zB, param);
                    GthetaV = DthetaV * area / dist;
                    GTV = DTV * area / dist;
                    A = add_latent_heat_coupling(A, itA, itB, ithA, ithB, GthetaV, GTV, param);
                end
            end
        end
    end
end

function [Dtheta, DT] = moisture_transport_coefficients(zA, zB, param)
    layerA = find_layer(zA, param);
    layerB = find_layer(zB, param);
    Dtheta = harmonic_mean(param.D_theta(layerA), param.D_theta(layerB));
    DT = 0.5 * (param.D_T(layerA) + param.D_T(layerB));
end

function [DthetaV, DTV] = vapor_transport_coefficients(zA, zB, param)
    layerA = find_layer(zA, param);
    layerB = find_layer(zB, param);
    DthetaV = harmonic_mean(param.D_theta_v(layerA), param.D_theta_v(layerB));
    DTV = 0.5 * (param.D_T_v(layerA) + param.D_T_v(layerB));
end

function A = add_latent_heat_coupling(A, itA, itB, ithA, ithB, GthetaV, GTV, param)
    latentScale = param.L_v * param.rho_water;
    Gtheta = latentScale * GthetaV;
    GT = latentScale * GTV;
    if Gtheta ~= 0
        A(itA, ithB) = A(itA, ithB) + Gtheta;
        A(itA, ithA) = A(itA, ithA) - Gtheta;
        A(itB, ithA) = A(itB, ithA) + Gtheta;
        A(itB, ithB) = A(itB, ithB) - Gtheta;
    end
    if GT ~= 0
        A(itA, itB) = A(itA, itB) + GT;
        A(itA, itA) = A(itA, itA) - GT;
        A(itB, itA) = A(itB, itA) + GT;
        A(itB, itB) = A(itB, itB) - GT;
    end
end

function A = add_gradient_coupling(A, ithA, ithB, itA, itB, G)
    if G == 0
        return
    end
    A(ithA, itB) = A(ithA, itB) + G;
    A(ithA, itA) = A(ithA, itA) - G;
    A(ithB, itA) = A(ithB, itA) + G;
    A(ithB, itB) = A(ithB, itB) - G;
end

function A = add_link(A, i, j, G)
    A(i, i) = A(i, i) - G;
    A(i, j) = A(i, j) + G;
    A(j, j) = A(j, j) - G;
    A(j, i) = A(j, i) + G;
end

function h = harmonic_mean(a, b)
    if a + b <= 0
        h = 0;
    else
        h = 2 * a * b / (a + b);
    end
end

function factor = gap_factor_from_temperature(TsNear, param)
    factor = 1 + param.a_gap_T * (TsNear - param.T_gap_ref);
    factor = min(max(factor, param.R_gap_min_factor), param.R_gap_max_factor);
end

function y = wrap_to_pi(x)
    y = mod(x + pi, 2*pi) - pi;
end

function ia = idx_Ta(i, param)
    ia = (i - 1) * param.nNode_seg + 1;
end

function ip = idx_Tp(i, param)
    ip = (i - 1) * param.nNode_seg + 2;
end

function is = idx_Ts(i, m, r, param)
    is = (i - 1) * param.nNode_seg + 2 + (m - 1) * param.Nr + r;
end

function ith = idx_theta(i, m, r, param)
    local = (i - 1) * param.Ntheta * param.Nr + (m - 1) * param.Nr + r;
    ith = param.nThermalState + local;
end
