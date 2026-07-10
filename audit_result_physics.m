% Basic physical and bookkeeping audit for generated EAHE result files.
% This script is intentionally conservative: it flags suspicious outcomes
% that should be inspected before using figures in the paper.

clear; clc;

currentRevision = 'soil_phase_offset_v2';
issues = strings(0, 1);

resultFiles = {
    'baseline_result.mat'
    'degradation_validation_result.mat'
    'gap_sensitivity_result.mat'
    'gap_conductivity_sensitivity_result.mat'
    'operation_sensitivity_result.mat'
    'soil_layer2_sensitivity_result.mat'
    'temperature_field_fine_result.mat'
    'variable_gap_extension_result.mat'
    'variable_gap_sensitivity_result.mat'
    'numerical_validation_result.mat'
    };

fprintf('\nEAHE physical audit\n');
fprintf('===================\n');

for i = 1:numel(resultFiles)
    file = resultFiles{i};
    if ~exist(file, 'file')
        issues(end+1) = "Missing result file: " + file;
        continue
    end
    if ~is_current_mat(file, currentRevision)
        issues(end+1) = "Old or unreadable result revision: " + file;
    end
end

if exist('baseline_result.mat', 'file')
    S = load('baseline_result.mat', 'result');
    result = S.result;
    issues = [issues; audit_single_case(result, 'baseline_result.mat')]; %#ok<AGROW>
end

if exist('temperature_field_fine_result.mat', 'file')
    S = load('temperature_field_fine_result.mat', 'result');
    result = S.result;
    issues = [issues; audit_temperature_field(result, 'temperature_field_fine_result.mat')]; %#ok<AGROW>
end

if isempty(issues)
    fprintf('[OK] No obvious revision or physical-consistency problems found.\n');
else
    fprintf('[WARN] Issues needing review:\n');
    for i = 1:numel(issues)
        fprintf('  - %s\n', issues(i));
    end
end

function issues = audit_single_case(result, label)
    label = string(label);
    issues = strings(0, 1);
    if ~is_current_result(result, 'soil_phase_offset_v2')
        issues(end+1) = label + ": result revision is not current.";
        return
    end

    param = result.param;
    soil_pre = result.soil_pre;

    if ~isfield(soil_pre, 'signature')
        issues(end+1) = label + ": soil_pre has no signature.";
    elseif ~strcmp(soil_pre.signature.model_revision, param.model_revision)
        issues(end+1) = label + ": soil_pre signature revision does not match result revision.";
    end

    if abs(param.soil_time_offset - param.operation_start_day * param.day) > 1e-9
        issues(end+1) = label + ": soil_time_offset is inconsistent with operation_start_day.";
    end

    zUpper = max(0, param.z_pipe - 0.75 * param.r_soil_max);
    zLower = min(param.z_max, param.z_pipe + 0.75 * param.r_soil_max);
    Tprof0 = local_get_undisturbed_profile(0, soil_pre, param);
    Tupper0 = interp1(soil_pre.z, Tprof0, zUpper, 'linear', 'extrap');
    Tlower0 = interp1(soil_pre.z, Tprof0, zLower, 'linear', 'extrap');
    if Tupper0 + 0.5 < Tlower0
        issues(end+1) = label + sprintf( ...
            ": summer-phase undisturbed upper soil is colder than lower soil (%.2f vs %.2f degC).", ...
            Tupper0, Tlower0);
    end

    active = 2:numel(result.time);
    if mean(result.Tin(active) - result.Tout(active), 'omitnan') <= 0
        issues(end+1) = label + ": mean Tin - Tout is not positive for the cooling case.";
    end
    if mean(result.Q(active), 'omitnan') <= 0
        issues(end+1) = label + ": mean heat-transfer rate is not positive for the cooling case.";
    end

    if isfield(result, 'degradation') && numel(result.degradation.Q_day_mean) >= 2
        qDay = result.degradation.Q_day_mean;
        if qDay(end) > 1.05 * qDay(1)
            issues(end+1) = label + ": daily mean heat transfer increases strongly instead of degrading.";
        end
        riseDay = result.degradation.near_soil_rise_day_mean;
        if mean(riseDay, 'omitnan') < -0.1
            issues(end+1) = label + ": near-pipe soil temperature rise is negative on average.";
        end
    end
end

function issues = audit_temperature_field(result, label)
    label = string(label);
    issues = strings(0, 1);
    if ~is_current_result(result, 'soil_phase_offset_v2')
        issues(end+1) = label + ": result revision is not current.";
        return
    end

    param = result.param;
    geom = result.geom;
    if isempty(result.snapshots.time)
        issues(end+1) = label + ": no temperature snapshots were saved.";
        return
    end

    mid = round(param.Nx_pipe / 2);
    firstX = result.snapshots.X(:, 1);
    [aboveMean, belowMean] = split_upper_lower_mean(firstX, mid, param, geom);
    if aboveMean + 0.5 < belowMean
        issues(end+1) = label + sprintf( ...
            ": initial contour data has upper soil colder than lower soil (%.2f vs %.2f degC).", ...
            aboveMean, belowMean);
    end

    lastX = result.snapshots.X(:, end);
    if any(~isfinite(lastX))
        issues(end+1) = label + ": final snapshot contains NaN or Inf.";
    end
end

function [aboveMean, belowMean] = split_upper_lower_mean(X, i, param, geom)
    above = [];
    below = [];
    for m = 1:param.Ntheta
        for r = 1:param.Nr
            z = param.z_pipe + geom.r_centers(r) * sin(geom.theta(m));
            value = X(idx_Ts(i, m, r, param));
            if z < param.z_pipe
                above(end+1, 1) = value; %#ok<AGROW>
            elseif z > param.z_pipe
                below(end+1, 1) = value; %#ok<AGROW>
            end
        end
    end
    aboveMean = mean(above, 'omitnan');
    belowMean = mean(below, 'omitnan');
end

function tf = is_current_mat(file, currentRevision)
    tf = false;
    try
        vars = whos('-file', file);
        names = {vars.name};
        if any(strcmp(names, 'result'))
            S = load(file, 'result');
            tf = is_current_result(S.result, currentRevision);
        elseif any(strcmp(names, 'results'))
            S = load(file, 'results');
            tf = is_current_result_cell(S.results, currentRevision);
        elseif any(strcmp(names, 'case_gap'))
            S = load(file, 'case_gap');
            tf = is_current_result(S.case_gap, currentRevision);
        elseif any(strcmp(names, 'fixed_case'))
            S = load(file, 'fixed_case');
            tf = is_current_result(S.fixed_case, currentRevision);
        elseif any(strcmp(names, 'm_results'))
            S = load(file, 'm_results');
            tf = is_current_result_cell(S.m_results, currentRevision);
        elseif any(strcmp(names, 'L_results'))
            S = load(file, 'L_results');
            tf = is_current_result_cell(S.L_results, currentRevision);
        elseif any(strcmp(names, 'dt_results'))
            S = load(file, 'dt_results');
            tf = is_current_result_cell(S.dt_results, currentRevision);
        elseif any(strcmp(names, 'Nx_results'))
            S = load(file, 'Nx_results');
            tf = is_current_result_cell(S.Nx_results, currentRevision);
        elseif any(strcmp(names, 'Ntheta_results'))
            S = load(file, 'Ntheta_results');
            tf = is_current_result_cell(S.Ntheta_results, currentRevision);
        elseif any(strcmp(names, 'Nr_results'))
            S = load(file, 'Nr_results');
            tf = is_current_result_cell(S.Nr_results, currentRevision);
        end
    catch
        tf = false;
    end
end

function tf = is_current_result_cell(results, currentRevision)
    tf = iscell(results) && ~isempty(results) ...
        && is_current_result(results{1}, currentRevision);
end

function tf = is_current_result(result, currentRevision)
    tf = isfield(result, 'param') ...
        && isfield(result.param, 'model_revision') ...
        && strcmp(result.param.model_revision, currentRevision);
end

function Tprof = local_get_undisturbed_profile(t, soil_pre, param)
    tq = mod(t + param.soil_time_offset, param.year);
    tt = soil_pre.time(:);
    TT = soil_pre.T;
    if tt(end) < param.year
        tt = [tt; param.year];
        TT = [TT, TT(:, 1)];
    end
    Tprof = interp1(tt, TT.', tq, 'linear', 'extrap').';
end

function is = idx_Ts(i, m, r, param)
    is = (i - 1) * param.nNode_seg + 2 + (m - 1) * param.Nr + r;
end
