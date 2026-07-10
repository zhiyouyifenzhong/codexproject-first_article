%% diagnose_sharan_pipe_benchmark_variables.m
% Probe likely COMSOL variable names in the solved Sharan pipe benchmark.

function diagnose_sharan_pipe_benchmark_variables()
    outDir = 'COMSOL_Sharan_pipe_h_benchmark';
    files = dir(fullfile(outDir, 'Sharan_pipe_h_benchmark_solved_*.mph'));
    if isempty(files)
        error('No solved benchmark .mph file found in %s.', outDir);
    end
    [~, idx] = max([files.datenum]);
    mphFile = fullfile(outDir, files(idx).name);

    addpath('G:\COMSOL\COMSOL63\Multiphysics\mli');
    try
        mphstart('localhost', 2036);
    catch ME
        if ~contains(ME.message, 'Already connected', 'IgnoreCase', true)
            rethrow(ME);
        end
    end

    model = mphload(mphFile);
    coord = [0.049; 25.0];
    names = {
        'u'; 'v'; 'w'; 'spf.u'; 'spf.v'; 'spf.w'; ...
        'k'; 'om'; 'omega'; 'ep'; 'spf.k'; 'spf.om'; 'spf.omega'; ...
        'spf.muT'; 'spf.mut'; 'spf.nuT'; 'spf.nut'; ...
        'ht.k'; 'ht.kxx'; 'ht.k_eff'; 'ht.keff'; 'ht.kteff'; ...
        'ht.ntflux'; 'ht.tfluxMag'; 'ht.qr'; 'ht.qx'; 'ht.qy'; ...
        'T'; 'T-273.15[K]'
        };

    expr = strings(numel(names), 1);
    value = nan(numel(names), 1);
    ok = false(numel(names), 1);
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
        'VariableNames', {'expression','ok','value_at_r_0p049_z_25','message'});
    writetable(T, fullfile(outDir, 'Sharan_pipe_h_benchmark_variable_probe.csv'));
    disp(T(:, 1:3));

    r = linspace(0, 0.0499, 21).';
    coordLine = [r.'; 25.0 * ones(1, numel(r))];
    vals = struct();
    vals.r_m = r;
    vals.T_C = safe_interp(model, 'T-273.15[K]', coordLine);
    vals.u_r_m_s = safe_interp(model, 'u', coordLine);
    vals.w_z_m_s = safe_interp(model, 'w', coordLine);
    vals.k_m2_s2 = safe_interp(model, 'k', coordLine);
    vals.om_1_s = safe_interp(model, 'om', coordLine);
    vals.muT_Pa_s = safe_interp(model, 'spf.muT', coordLine);
    vals.nuT_m2_s = safe_interp(model, 'spf.nuT', coordLine);
    R = struct2table(vals);
    writetable(R, fullfile(outDir, 'Sharan_pipe_h_benchmark_radial_variable_profile.csv'));
    disp(R);
end

function y = safe_interp(model, expr, coord)
    try
        y = mphinterp(model, expr, 'coord', coord);
        y = y(:);
    catch
        y = nan(size(coord, 2), 1);
    end
end
