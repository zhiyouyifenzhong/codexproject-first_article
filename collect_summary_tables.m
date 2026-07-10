% Collect CSV summary tables into one Excel workbook.
% Run after the relevant sensitivity scripts have completed.

clear; clc;

outFile = 'EAHE_summary_tables.xlsx';

items = {
    'degradation_validation_summary.csv',      'Degradation',            'degradation_validation_result.mat'
    'gap_sensitivity_summary.csv',             'GapThickness',           'gap_sensitivity_result.mat'
    'gap_conductivity_sensitivity_summary.csv','GapConductivity',        'gap_conductivity_sensitivity_result.mat'
    'operation_mdot_summary.csv',              'MassFlow',               'operation_sensitivity_result.mat'
    'operation_length_summary.csv',            'PipeLength',             'operation_sensitivity_result.mat'
    'soil_layer2_sensitivity_summary.csv',     'SoilLayer2',             'soil_layer2_sensitivity_result.mat'
    'variable_gap_extension_summary.csv',      'VariableGapCompare',     'variable_gap_extension_result.mat'
    'variable_gap_sensitivity_summary.csv',    'VariableGapSensitivity', 'variable_gap_sensitivity_result.mat'
    'heat_moisture_theta_summary.csv',         'HeatMoistureTheta',      'heat_moisture_coupling_result.mat'
    'heat_moisture_operation_summary.csv',     'HeatMoistureOperation',  'heat_moisture_coupling_result.mat'
    'heat_moisture_latent_summary.csv',        'HeatMoistureLatent',     'heat_moisture_coupling_result.mat'
    'validation_dt_summary.csv',               'Validation_dt',          'numerical_validation_result.mat'
    'validation_Nx_summary.csv',               'Validation_Nx',          'numerical_validation_result.mat'
    'validation_Ntheta_summary.csv',           'Validation_Ntheta',      'numerical_validation_result.mat'
    'validation_Nr_summary.csv',               'Validation_Nr',          'numerical_validation_result.mat'
    };

if exist(outFile, 'file')
    delete(outFile);
end

for i = 1:size(items, 1)
    csvFile = items{i, 1};
    sheetName = items{i, 2};
    matFile = items{i, 3};
    if exist(csvFile, 'file')
        if is_current_mat(matFile)
            T = readtable(csvFile);
            writetable(T, outFile, 'Sheet', sheetName);
            fprintf('[OK] %s -> %s\n', csvFile, sheetName);
        else
            fprintf('[SKIP] %s has no current matching MAT result\n', csvFile);
        end
    else
        fprintf('[SKIP] %s not found\n', csvFile);
    end
end

fprintf('Summary workbook written to %s\n', outFile);

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
            tf = iscell(S.results) && ~isempty(S.results) && is_current_result(S.results{1});
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
        elseif any(strcmp(names, 'theta_results'))
            S = load(file, 'theta_results');
            tf = is_current_result_cell(S.theta_results);
        elseif any(strcmp(names, 'mode_results'))
            S = load(file, 'mode_results');
            tf = is_current_result_cell(S.mode_results);
        elseif any(strcmp(names, 'latent_results'))
            S = load(file, 'latent_results');
            tf = is_current_result_cell(S.latent_results);
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
