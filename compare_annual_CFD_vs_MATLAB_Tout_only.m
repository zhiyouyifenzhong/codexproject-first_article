%% compare_annual_CFD_vs_MATLAB_Tout_only.m
% Annual outlet-temperature comparison:
%   COMSOL k-epsilon CFD Tout vs original MATLAB Minaei-G Tout
%
% This script compares only annual outlet temperature. It does not compare
% annual heat quantity, Sharan data, ILS, or FLS kernels.

function compare_annual_CFD_vs_MATLAB_Tout_only()
    close all; clc;

    rootDir = pwd;
    matlabMatFile = fullfile(rootDir, 'EAHE_airgap_physical_v18_minaei_contact_results', ...
        'EAHE_airgap_physical_v18_minaei_contact_results.mat');
    cfdToutFile = fullfile(rootDir, 'COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon', ...
        'COMSOL_Tout_delta_sweep.csv');
    outDir = fullfile(rootDir, 'Validation_annual_CFD_vs_MATLAB_Tout_only');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    assert(exist(matlabMatFile, 'file') == 2, 'Missing MATLAB result file: %s', matlabMatFile);
    assert(exist(cfdToutFile, 'file') == 2, 'Missing CFD Tout CSV: %s', cfdToutFile);

    S = load(matlabMatFile);
    cfd = readtable(cfdToutFile);
    deltas_mm = [0 1 5];

    allPoints = table();
    metrics = table();

    for i = 1:numel(deltas_mm)
        delta = deltas_mm(i);
        R = getResultForDelta(S, delta);

        cfdCol = sprintf('Tout_resistance_delta_%dmm_C', delta);
        assert(any(strcmp(cfd.Properties.VariableNames, cfdCol)), 'Missing CFD column %s', cfdCol);

        t_day = cfd.t_day(:);
        Tout_cfd = cfd.(cfdCol)(:);
        Tout_matlab = interp1(R.day(:), R.Tout(:), t_day, 'linear', 'extrap');
        err = Tout_matlab - Tout_cfd;

        allPoints = [allPoints; table( ...
            repmat(delta, numel(t_day), 1), t_day, cfd.Tin_C(:), Tout_cfd, Tout_matlab, err, ...
            'VariableNames', {'delta_mm','t_day','Tin_C','Tout_CFD_kepsilon_C', ...
            'Tout_MATLAB_MinaeiG_C','Tout_MATLAB_minus_CFD_C'})]; %#ok<AGROW>

        sAll = stats(err);
        sAfter0 = stats(err(t_day > 0));
        metrics = [metrics; table(delta, numel(err), sAll.rmse, sAll.mae, sAll.bias, sAll.maxAbs, ...
            sAfter0.rmse, sAfter0.mae, sAfter0.maxAbs, ...
            mean(Tout_cfd, 'omitnan'), mean(Tout_matlab, 'omitnan'), ...
            'VariableNames', {'delta_mm','n_points','RMSE_C','MAE_C','bias_MATLAB_minus_CFD_C', ...
            'max_abs_error_C','RMSE_excluding_day0_C','MAE_excluding_day0_C', ...
            'max_abs_error_excluding_day0_C','Tout_CFD_mean_C','Tout_MATLAB_mean_C'})]; %#ok<AGROW>

        plotAnnualCase(outDir, delta, t_day, cfd.Tin_C(:), Tout_cfd, Tout_matlab, err);
    end

    writetable(allPoints, fullfile(outDir, 'Annual_CFD_vs_MATLAB_Tout_only_points.csv'));
    writetable(metrics, fullfile(outDir, 'Annual_CFD_vs_MATLAB_Tout_only_metrics.csv'));
    writeReport(outDir, metrics, matlabMatFile, cfdToutFile);

    fprintf('Done. Output folder: %s\n', outDir);
end

function R = getResultForDelta(S, delta)
    idx = find(abs(S.deltaList_mm(:)-delta) < 1e-9, 1);
    assert(~isempty(idx), 'delta = %.6g mm is not present in MATLAB results.', delta);
    if iscell(S.res)
        R = S.res{idx};
    else
        R = S.res(idx);
    end
end

function s = stats(err)
    err = err(isfinite(err));
    s.rmse = sqrt(mean(err.^2));
    s.mae = mean(abs(err));
    s.bias = mean(err);
    s.maxAbs = max(abs(err));
end

function plotAnnualCase(outDir, delta, t_day, Tin, Tout_cfd, Tout_matlab, err)
    fig = figure('Color','w','Position',[80 80 1120 650]);
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(t_day, Tin, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.9, 'DisplayName','Tin');
    plot(t_day, Tout_cfd, '-', 'Color', [0.05 0.39 0.75], 'LineWidth', 1.25, 'DisplayName','CFD k-\epsilon');
    plot(t_day, Tout_matlab, '--', 'Color', [0.78 0.22 0.12], 'LineWidth', 1.25, 'DisplayName','MATLAB Minaei-G');
    xlabel('time / day');
    ylabel('temperature / ^\circC');
    title(sprintf('Annual outlet temperature comparison, delta = %d mm', delta));
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(t_day, err, 'k-', 'LineWidth', 1.0);
    yline(0, ':', 'Color', [0.35 0.35 0.35]);
    xlabel('time / day');
    ylabel('MATLAB - CFD / ^\circC');

    base = fullfile(outDir, sprintf('Fig_annual_CFD_vs_MATLAB_Tout_delta_%dmm', delta));
    saveas(fig, [base '.png']);
    saveas(fig, [base '.pdf']);
    close(fig);
end

function writeReport(outDir, M, matlabMatFile, cfdToutFile)
    fid = fopen(fullfile(outDir, 'Annual_CFD_vs_MATLAB_Tout_only_report.md'), 'w');
    fprintf(fid, '# Annual CFD vs MATLAB Outlet Temperature Comparison\n\n');
    fprintf(fid, 'MATLAB file: `%s`\n\n', matlabMatFile);
    fprintf(fid, 'CFD file: `%s`\n\n', cfdToutFile);
    fprintf(fid, 'Only annual outlet temperature is compared.\n\n');
    fprintf(fid, '| delta (mm) | n | RMSE (degC) | MAE (degC) | Bias (degC) | Max abs (degC) | RMSE after day 0 (degC) | Max abs after day 0 (degC) |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(M)
        fprintf(fid, '| %.0f | %.0f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
            M.delta_mm(i), M.n_points(i), M.RMSE_C(i), M.MAE_C(i), ...
            M.bias_MATLAB_minus_CFD_C(i), M.max_abs_error_C(i), ...
            M.RMSE_excluding_day0_C(i), M.max_abs_error_excluding_day0_C(i));
    end
    fclose(fid);
end
