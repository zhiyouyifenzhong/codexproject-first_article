% Check whether expected result files, CSV summaries, and figure folders exist.
% Run this after main_core_results or main_all_results completes.

clear; clc;

expectedMat = {
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

expectedCsv = {
    'degradation_validation_summary.csv'
    'gap_sensitivity_summary.csv'
    'gap_conductivity_sensitivity_summary.csv'
    'operation_mdot_summary.csv'
    'operation_length_summary.csv'
    'soil_layer2_sensitivity_summary.csv'
    'variable_gap_extension_summary.csv'
    'variable_gap_sensitivity_summary.csv'
    'validation_dt_summary.csv'
    'validation_Nx_summary.csv'
    'validation_Ntheta_summary.csv'
    'validation_Nr_summary.csv'
    };

expectedFolders = {
    fullfile('figures','baseline')
    fullfile('figures','soil_phase_check')
    fullfile('figures','temperature_field_fine')
    fullfile('figures','degradation')
    fullfile('figures','gap_thickness')
    fullfile('figures','gap_conductivity')
    fullfile('figures','operation')
    fullfile('figures','soil_layer2')
    fullfile('figures','variable_gap')
    fullfile('figures','variable_gap_sensitivity')
    fullfile('figures','numerical_validation')
    };

fprintf('\nMAT files:\n');
print_file_status(expectedMat);

fprintf('\nCSV summaries:\n');
print_file_status(expectedCsv);

fprintf('\nFigure folders:\n');
for i = 1:numel(expectedFolders)
    folder = expectedFolders{i};
    if exist(folder, 'dir')
        pngCount = numel(dir(fullfile(folder, '*.png')));
        figCount = numel(dir(fullfile(folder, '*.fig')));
        fprintf('  [OK] %-40s  PNG: %2d  FIG: %2d\n', folder, pngCount, figCount);
    else
        fprintf('  [MISS] %s\n', folder);
    end
end

function print_file_status(files)
    for i = 1:numel(files)
        file = files{i};
        if exist(file, 'file')
            d = dir(file);
            fprintf('  [OK] %-45s  %.2f MB\n', file, d.bytes / 1024^2);
        else
            fprintf('  [MISS] %s\n', file);
        end
    end
end
