% Check whether saved MAT results were generated with the current model
% revision. This is important after changing the undisturbed-soil annual
% phase alignment.

clear; clc;

currentRevision = 'soil_phase_offset_v2';

files = {
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

for i = 1:numel(files)
    file = files{i};
    if ~exist(file, 'file')
        fprintf('[MISS] %s\n', file);
        continue
    end

    rev = read_revision(file);
    if strcmp(rev, currentRevision)
        fprintf('[OK]   %-45s %s\n', file, rev);
    else
        fprintf('[OLD]  %-45s %s\n', file, rev);
    end
end

function rev = read_revision(file)
    rev = '<unknown>';
    vars = whos('-file', file);
    names = {vars.name};

    try
        if any(strcmp(names, 'result'))
            S = load(file, 'result');
            rev = get_result_revision(S.result);
        elseif any(strcmp(names, 'results'))
            S = load(file, 'results');
            if iscell(S.results) && ~isempty(S.results)
                rev = get_result_revision(S.results{1});
            end
        elseif any(strcmp(names, 'case_gap'))
            S = load(file, 'case_gap');
            rev = get_result_revision(S.case_gap);
        elseif any(strcmp(names, 'fixed_case'))
            S = load(file, 'fixed_case');
            rev = get_result_revision(S.fixed_case);
        elseif any(strcmp(names, 'm_results'))
            S = load(file, 'm_results');
            rev = get_cell_result_revision(S.m_results);
        elseif any(strcmp(names, 'L_results'))
            S = load(file, 'L_results');
            rev = get_cell_result_revision(S.L_results);
        elseif any(strcmp(names, 'dt_results'))
            S = load(file, 'dt_results');
            rev = get_cell_result_revision(S.dt_results);
        elseif any(strcmp(names, 'Nx_results'))
            S = load(file, 'Nx_results');
            rev = get_cell_result_revision(S.Nx_results);
        elseif any(strcmp(names, 'Ntheta_results'))
            S = load(file, 'Ntheta_results');
            rev = get_cell_result_revision(S.Ntheta_results);
        elseif any(strcmp(names, 'Nr_results'))
            S = load(file, 'Nr_results');
            rev = get_cell_result_revision(S.Nr_results);
        end
    catch
        rev = '<unreadable>';
    end
end

function rev = get_cell_result_revision(results)
    rev = '<unknown>';
    if iscell(results) && ~isempty(results)
        rev = get_result_revision(results{1});
    end
end

function rev = get_result_revision(result)
    rev = '<unknown>';
    if isfield(result, 'param') && isfield(result.param, 'model_revision')
        rev = result.param.model_revision;
    end
end
