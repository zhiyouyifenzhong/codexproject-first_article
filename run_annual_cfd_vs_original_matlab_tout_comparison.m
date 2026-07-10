%% run_annual_cfd_vs_original_matlab_tout_comparison.m
% Compare annual outlet temperature from the original MATLAB Minaei-G model
% with the annual COMSOL k-epsilon CFD export.
%
% Outputs:
%   MATLAB_annual_CFD_vs_original_model_validation/
%     Annual_CFD_vs_original_MATLAB_Tout_points.csv
%     Annual_CFD_vs_original_MATLAB_Tout_metrics.csv
%     Annual_CFD_vs_original_MATLAB_energy_metrics.csv
%     Annual_CFD_vs_original_MATLAB_validation_report.md
%
% The script reads existing annual model results. It does not evaluate ILS or
% FLS kernels.

function run_annual_cfd_vs_original_matlab_tout_comparison()
    close all; clc;

    rootDir = pwd;
    matDir = fullfile(rootDir, 'EAHE_airgap_physical_v18_minaei_contact_results');
    cfdDir = fullfile(rootDir, 'COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon');
    outDir = fullfile(rootDir, 'MATLAB_annual_CFD_vs_original_model_validation');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    matFile = fullfile(matDir, 'EAHE_airgap_physical_v18_minaei_contact_results.mat');
    cfdToutFile = fullfile(cfdDir, 'COMSOL_Tout_delta_sweep.csv');
    cfdEnergyFile = fullfile(cfdDir, 'COMSOL_annual_kepsilon_vs_MinaeiG_comparison.csv');

    assert(exist(matFile, 'file') == 2, 'Missing MATLAB result file: %s', matFile);
    assert(exist(cfdToutFile, 'file') == 2, 'Missing CFD Tout file: %s', cfdToutFile);

    S = load(matFile);
    cfdTout = readtable(cfdToutFile);
    deltas = [0 1 5];

    pointRows = {};
    metricRows = {};

    for i = 1:numel(deltas)
        delta = deltas(i);
        R = resultForDelta(S, delta);
        tCfd_day = cfdTout.t_day(:);
        cfdCol = sprintf('Tout_resistance_delta_%dmm_C', delta);
        assert(any(strcmp(cfdTout.Properties.VariableNames, cfdCol)), ...
            'Missing CFD column: %s', cfdCol);

        Tout_cfd = cfdTout.(cfdCol)(:);
        Tin_cfd = cfdTout.Tin_C(:);
        Tout_matlab = interp1(R.day(:), R.Tout(:), tCfd_day, 'linear', 'extrap');
        Tin_matlab = interp1(R.day(:), R.Tin(:), tCfd_day, 'linear', 'extrap');
        dTout = Tout_matlab - Tout_cfd;

        for k = 1:numel(tCfd_day)
            pointRows(end+1, :) = {delta, tCfd_day(k), Tin_cfd(k), Tin_matlab(k), ...
                Tout_cfd(k), Tout_matlab(k), dTout(k)}; %#ok<AGROW>
        end

        stats = errorStats(dTout);
        postInitialStats = errorStats(dTout(tCfd_day > 0));
        metricRows(end+1, :) = {delta, stats.n, stats.rmse, stats.mae, stats.bias, ...
            stats.maxAbs, postInitialStats.rmse, postInitialStats.mae, postInitialStats.maxAbs, ...
            mean(Tout_cfd, 'omitnan'), mean(Tout_matlab, 'omitnan'), ...
            min(Tout_cfd), max(Tout_cfd), min(Tout_matlab), max(Tout_matlab)}; %#ok<AGROW>

        plotAnnualTout(outDir, delta, tCfd_day, Tin_cfd, Tout_cfd, Tout_matlab, dTout);
    end

    pointTable = cell2table(pointRows, 'VariableNames', ...
        {'delta_mm','t_day','Tin_CFD_C','Tin_MATLAB_C','Tout_CFD_kepsilon_C', ...
        'Tout_original_MATLAB_MinaeiG_C','Tout_MATLAB_minus_CFD_C'});
    metricTable = cell2table(metricRows, 'VariableNames', ...
        {'delta_mm','n_points','RMSE_C','MAE_C','bias_MATLAB_minus_CFD_C', ...
        'max_abs_error_C','RMSE_excluding_day0_C','MAE_excluding_day0_C', ...
        'max_abs_error_excluding_day0_C','Tout_CFD_mean_C','Tout_MATLAB_mean_C', ...
        'Tout_CFD_min_C','Tout_CFD_max_C','Tout_MATLAB_min_C','Tout_MATLAB_max_C'});

    writetable(pointTable, fullfile(outDir, 'Annual_CFD_vs_original_MATLAB_Tout_points.csv'));
    writetable(metricTable, fullfile(outDir, 'Annual_CFD_vs_original_MATLAB_Tout_metrics.csv'));

    energyTable = table();
    if exist(cfdEnergyFile, 'file') == 2
        energyTable = readtable(cfdEnergyFile);
        writetable(energyTable, fullfile(outDir, 'Annual_CFD_vs_original_MATLAB_energy_metrics.csv'));
    end

    plotMetricSummary(outDir, metricTable);
    if ~isempty(energyTable)
        plotEnergySummary(outDir, energyTable);
    end
    writeAnnualReport(outDir, metricTable, energyTable, matFile, cfdToutFile, cfdEnergyFile);

    fprintf('Annual CFD vs MATLAB comparison complete. Output: %s\n', outDir);
end

function R = resultForDelta(S, delta)
    assert(isfield(S, 'deltaList_mm'), 'MATLAB result file lacks deltaList_mm.');
    assert(isfield(S, 'res'), 'MATLAB result file lacks res.');

    deltaList = S.deltaList_mm(:);
    idx = find(abs(deltaList - delta) < 1e-9, 1);
    assert(~isempty(idx), 'delta = %.6g mm was not found in deltaList_mm.', delta);

    if iscell(S.res)
        R = S.res{idx};
    else
        R = S.res(idx);
    end

    needed = {'day','Tin','Tout'};
    for j = 1:numel(needed)
        assert(isfield(R, needed{j}), 'Result for delta %.6g mm lacks field %s.', delta, needed{j});
    end
end

function stats = errorStats(err)
    err = err(:);
    ok = isfinite(err);
    err = err(ok);
    stats.n = numel(err);
    stats.rmse = sqrt(mean(err.^2));
    stats.mae = mean(abs(err));
    stats.bias = mean(err);
    stats.maxAbs = max(abs(err));
end

function plotAnnualTout(outDir, delta, tDay, Tin, ToutCfd, ToutMatlab, dTout)
    fig = figure('Color', 'w', 'Position', [80 80 1180 680]);
    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(tDay, Tin, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.9); hold on;
    plot(tDay, ToutCfd, '-', 'Color', [0.05 0.39 0.75], 'LineWidth', 1.2);
    plot(tDay, ToutMatlab, '--', 'Color', [0.78 0.22 0.12], 'LineWidth', 1.2);
    grid on; box on;
    xlabel('Time (day)');
    ylabel('Temperature (degC)');
    title(sprintf('Annual outlet temperature, delta = %d mm', delta));
    legend({'Tin', 'COMSOL k-\epsilon CFD', 'Original MATLAB Minaei-G'}, 'Location', 'best');

    nexttile;
    plot(tDay, dTout, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0);
    yline(0, ':', 'Color', [0.4 0.4 0.4]);
    grid on; box on;
    xlabel('Time (day)');
    ylabel('MATLAB - CFD (degC)');

    base = fullfile(outDir, sprintf('Fig_annual_Tout_CFD_vs_MATLAB_delta_%dmm', delta));
    saveas(fig, [base '.png']);
    saveas(fig, [base '.pdf']);
    close(fig);
end

function plotMetricSummary(outDir, metricTable)
    fig = figure('Color', 'w', 'Position', [120 120 820 460]);
    bar(metricTable.delta_mm, [metricTable.RMSE_C metricTable.MAE_C metricTable.max_abs_error_C], 'grouped');
    grid on; box on;
    xlabel('Air-gap thickness, delta (mm)');
    ylabel('Temperature error (degC)');
    title('Annual outlet temperature error: original MATLAB minus CFD');
    legend({'RMSE', 'MAE', 'Max abs'}, 'Location', 'northwest');
    base = fullfile(outDir, 'Fig_annual_Tout_error_summary');
    saveas(fig, [base '.png']);
    saveas(fig, [base '.pdf']);
    close(fig);
end

function plotEnergySummary(outDir, energyTable)
    names = energyTable.Properties.VariableNames;
    if ~any(strcmp(names, 'Eabs_diff_percent'))
        return;
    end

    fig = figure('Color', 'w', 'Position', [120 120 760 440]);
    bar(energyTable.delta_mm, energyTable.Eabs_diff_percent, 0.55, 'FaceColor', [0.22 0.48 0.70]);
    grid on; box on;
    xlabel('Air-gap thickness, delta (mm)');
    ylabel('Annual |Q| difference (%)');
    title('Annual heat-exchange difference: CFD minus MATLAB');
    yline(0, ':', 'Color', [0.3 0.3 0.3]);
    base = fullfile(outDir, 'Fig_annual_energy_error_summary');
    saveas(fig, [base '.png']);
    saveas(fig, [base '.pdf']);
    close(fig);
end

function writeAnnualReport(outDir, metricTable, energyTable, matFile, cfdToutFile, cfdEnergyFile)
    reportFile = fullfile(outDir, 'Annual_CFD_vs_original_MATLAB_validation_report.md');
    fid = fopen(reportFile, 'w');
    assert(fid > 0, 'Could not open report file: %s', reportFile);
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '# Annual CFD vs Original MATLAB Minaei-G Comparison\n\n');
    fprintf(fid, 'Input MATLAB result file: `%s`\n\n', matFile);
    fprintf(fid, 'Input CFD outlet-temperature file: `%s`\n\n', cfdToutFile);
    if exist(cfdEnergyFile, 'file') == 2
        fprintf(fid, 'Input annual energy comparison file: `%s`\n\n', cfdEnergyFile);
    end

    fprintf(fid, '## Outlet-temperature metrics\n\n');
    fprintf(fid, '| delta (mm) | n | RMSE (degC) | MAE (degC) | bias (degC) | max abs (degC) | RMSE after day 0 (degC) | max abs after day 0 (degC) |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(metricTable)
        fprintf(fid, '| %.0f | %.0f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
            metricTable.delta_mm(i), metricTable.n_points(i), metricTable.RMSE_C(i), ...
            metricTable.MAE_C(i), metricTable.bias_MATLAB_minus_CFD_C(i), ...
            metricTable.max_abs_error_C(i), metricTable.RMSE_excluding_day0_C(i), ...
            metricTable.max_abs_error_excluding_day0_C(i));
    end

    if ~isempty(energyTable)
        fprintf(fid, '\n## Annual energy metrics\n\n');
        names = energyTable.Properties.VariableNames;
        hasAll = all(ismember({'delta_mm','Eabs_kWh_CFD','Eabs_kWh_MinaeiG','Eabs_diff_percent'}, names));
        if hasAll
            fprintf(fid, '| delta (mm) | CFD annual abs heat (kWh) | MATLAB annual abs heat (kWh) | CFD minus MATLAB (%) |\n');
            fprintf(fid, '|---:|---:|---:|---:|\n');
            for i = 1:height(energyTable)
                fprintf(fid, '| %.0f | %.3f | %.3f | %.4f |\n', ...
                    energyTable.delta_mm(i), energyTable.Eabs_kWh_CFD(i), ...
                    energyTable.Eabs_kWh_MinaeiG(i), energyTable.Eabs_diff_percent(i));
            end
        end
    end

    fprintf(fid, '\n## Interpretation for validation\n\n');
    fprintf(fid, ['This annual comparison is a CFD-to-reduced-model consistency check. ', ...
        'It is useful for confirming that the COMSOL k-epsilon setup and the MATLAB ', ...
        'Minaei-G implementation produce nearly the same annual outlet-temperature trend ', ...
        'under the same boundary conditions. It is not, by itself, an independent ', ...
        'annual experimental validation because the CFD data are model predictions rather ', ...
        'than measured annual outlet temperatures.\n']);
end
