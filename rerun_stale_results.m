% Rerun only missing or old-revision result groups, then refresh summaries.
% Use this when check_result_revision reports a small number of stale files.

clear; clc; close all;

fprintf('\n=== Checking result revisions ===\n');
check_result_revision;

if ~is_current_mat('operation_sensitivity_result.mat')
    fprintf('\n=== Rerunning operation sensitivity ===\n');
    main_sensitivity_operation;
    save_all_open_figures(fullfile('figures', 'operation'), 'operation');
    close all;
else
    fprintf('\nOperation sensitivity is current. Skipping rerun.\n');
end

if ~is_current_mat('numerical_validation_result.mat')
    fprintf('\n=== Rerunning numerical validation ===\n');
    main_numerical_validation;
    save_all_open_figures(fullfile('figures', 'numerical_validation'), 'numerical_validation');
    close all;
else
    fprintf('\nNumerical validation is current. Skipping rerun.\n');
end

if ~is_current_mat('variable_gap_extension_result.mat')
    fprintf('\n=== Rerunning variable-gap comparison ===\n');
    main_variable_gap_extension;
    save_all_open_figures(fullfile('figures', 'variable_gap'), 'variable_gap');
    close all;
else
    fprintf('\nVariable-gap comparison is current. Skipping rerun.\n');
end

fprintf('\n=== Refreshing summaries ===\n');
check_result_revision;
check_generated_results;
collect_summary_tables;
extract_key_findings;
audit_result_physics;

fprintf('\nSelective rerun complete.\n');

function tf = is_current_mat(file)
    tf = false;
    if ~exist(file, 'file')
        return
    end

    try
        vars = whos('-file', file);
        names = {vars.name};
        if any(strcmp(names, 'result'))
            S = load(file, 'result');
            tf = is_current_result(S.result);
        elseif any(strcmp(names, 'results'))
            S = load(file, 'results');
            tf = is_current_result_cell(S.results);
        elseif any(strcmp(names, 'case_gap'))
            S = load(file, 'case_gap');
            tf = is_current_result(S.case_gap);
        elseif any(strcmp(names, 'fixed_case'))
            S = load(file, 'fixed_case');
            tf = is_current_result(S.fixed_case);
        elseif any(strcmp(names, 'm_results'))
            S = load(file, 'm_results');
            tf = is_current_result_cell(S.m_results);
        elseif any(strcmp(names, 'L_results'))
            S = load(file, 'L_results');
            tf = is_current_result_cell(S.L_results);
        elseif any(strcmp(names, 'dt_results'))
            S = load(file, 'dt_results');
            tf = is_current_result_cell(S.dt_results);
        elseif any(strcmp(names, 'Nx_results'))
            S = load(file, 'Nx_results');
            tf = is_current_result_cell(S.Nx_results);
        elseif any(strcmp(names, 'Ntheta_results'))
            S = load(file, 'Ntheta_results');
            tf = is_current_result_cell(S.Ntheta_results);
        elseif any(strcmp(names, 'Nr_results'))
            S = load(file, 'Nr_results');
            tf = is_current_result_cell(S.Nr_results);
        end
    catch
        tf = false;
    end
end

function tf = is_current_result_cell(results)
    tf = iscell(results) && ~isempty(results) && is_current_result(results{1});
end

function tf = is_current_result(result)
    tf = isfield(result, 'param') ...
        && isfield(result.param, 'model_revision') ...
        && strcmp(result.param.model_revision, 'soil_phase_offset_v2');
end
