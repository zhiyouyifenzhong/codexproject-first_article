function make_minaei_gap_cfd_model_curve_validation()
%% make_minaei_gap_cfd_model_curve_validation.m
% 改进目的：
%   1) 按 Minaei 验证参数体系，对已验证的 k-epsilon CFD 与 Minaei-G 模型进行同工况比较；
%   2) 只保留曲线图像：年度出口温度曲线与残差曲线；
%   3) 导出 Origin 可编辑数据，包括逐日曲线、误差指标和年度换热量对比；
%   4) 不计算、不绘制 ILS/FLS 响应核。

    close all; clc;

    %% [01] 设置输入文件与输出目录
    rootDir = fileparts(mfilename('fullpath'));
    if isempty(rootDir)
        rootDir = pwd;
    end

    pointFile = fullfile(rootDir, ...
        'Validation_annual_CFD_vs_MATLAB_Tout_only', ...
        'Annual_CFD_vs_MATLAB_Tout_only_points.csv');

    energyFile = fullfile(rootDir, ...
        'COMSOL_EAHE_outputs_CFD_annual_delta_sweep_kepsilon', ...
        'COMSOL_annual_kepsilon_vs_MinaeiG_comparison.csv');

    outDir = fullfile(rootDir, ...
        'Minaei_parameter_gap_CFD_MinaeiG_validation_MATLAB_curves');
    figDir = fullfile(outDir, 'curve_figures');
    dataDir = fullfile(outDir, 'origin_data');

    makeDirIfNeeded(outDir);
    makeDirIfNeeded(figDir);
    makeDirIfNeeded(dataDir);

    %% [02] 读取 CFD 与 Minaei-G 模型的年度出口温度数据
    assert(exist(pointFile, 'file') == 2, 'Missing point file: %s', pointFile);
    assert(exist(energyFile, 'file') == 2, 'Missing energy file: %s', energyFile);

    P = readtable(pointFile);
    E = readtable(energyFile);

    requiredPointVars = {'delta_mm','t_day','Tin_C','Tout_CFD_kepsilon_C', ...
        'Tout_MATLAB_MinaeiG_C','Tout_MATLAB_minus_CFD_C'};
    assert(all(ismember(requiredPointVars, P.Properties.VariableNames)), ...
        'Point file does not contain the required columns.');

    deltas_mm = unique(P.delta_mm(:))';
    deltas_mm = sort(deltas_mm);

    %% [03] 导出逐日曲线数据，供 Origin 或论文附表继续修改
    allCurveRows = table();
    metricRows = table();

    for i = 1:numel(deltas_mm)
        delta = deltas_mm(i);
        idx = P.delta_mm == delta;
        T = sortrows(P(idx, :), 't_day');

        ToutCFD = T.Tout_CFD_kepsilon_C(:);
        ToutModel = T.Tout_MATLAB_MinaeiG_C(:);
        err = T.Tout_MATLAB_minus_CFD_C(:);

        exportT = table(T.t_day(:), T.Tin_C(:), ToutCFD, ToutModel, err, ...
            'VariableNames', {'Time_day','Tin_C','Tout_CFD_kepsilon_C', ...
            'Tout_MinaeiG_model_C','Tout_MinaeiG_minus_CFD_C'});
        writetable(exportT, fullfile(dataDir, ...
            sprintf('Origin_Minaei_params_Tout_curve_delta_%gmm.csv', delta)));

        exportT.delta_mm = repmat(delta, height(exportT), 1);
        allCurveRows = [allCurveRows; exportT]; %#ok<AGROW>

        metricRow = table(delta, height(T), rmseLocal(err), mean(abs(err), 'omitnan'), ...
            mean(err, 'omitnan'), max(abs(err)), mean(ToutCFD, 'omitnan'), ...
            mean(ToutModel, 'omitnan'), min(ToutCFD), max(ToutCFD), ...
            min(ToutModel), max(ToutModel), ...
            'VariableNames', {'delta_mm','n_points','RMSE_C','MAE_C', ...
            'bias_model_minus_CFD_C','max_abs_error_C','Tout_CFD_mean_C', ...
            'Tout_model_mean_C','Tout_CFD_min_C','Tout_CFD_max_C', ...
            'Tout_model_min_C','Tout_model_max_C'});
        metricRows = [metricRows; metricRow]; %#ok<AGROW>
    end

    writetable(allCurveRows, fullfile(dataDir, ...
        'Origin_Minaei_params_Tout_curves_all_gaps_long.csv'));
    writetable(metricRows, fullfile(dataDir, ...
        'Origin_Minaei_params_Tout_curve_error_metrics.csv'));

    %% [04] 导出年度换热量对比数据，但不再生成柱状图
    energyVars = {'delta_mm','Ecool_kWh_CFD','Eheat_kWh_CFD','Eabs_kWh_CFD', ...
        'Dgap_percent_CFD','Ecool_kWh_MinaeiG','Eheat_kWh_MinaeiG', ...
        'Eabs_kWh_MinaeiG','Dgap_percent_MinaeiG', ...
        'Ecool_kWh_CFD_minus_MinaeiG_percent', ...
        'Eheat_kWh_CFD_minus_MinaeiG_percent', ...
        'Eabs_kWh_CFD_minus_MinaeiG_percent', ...
        'Dgap_CFD_minus_MinaeiG_pctpt'};
    energyVars = energyVars(ismember(energyVars, E.Properties.VariableNames));
    writetable(E(:, energyVars), fullfile(dataDir, ...
        'Origin_Minaei_params_annual_energy_export_only.csv'));

    %% [05] 生成唯一保留的验证图：出口温度曲线 + 模型残差曲线
    fig = figure('Color', 'w', 'Units', 'centimeters', ...
        'Position', [2 2 18.3 18.0]);

    for i = 1:numel(deltas_mm)
        delta = deltas_mm(i);
        idx = P.delta_mm == delta;
        T = sortrows(P(idx, :), 't_day');
        M = metricRows(metricRows.delta_mm == delta, :);

        ax1 = subplot(numel(deltas_mm), 2, 2*i - 1);
        plotOutletPanel(ax1, T, M, delta, i == 1);
        addPanelLabel(ax1, char('a' + 2*i - 2));

        ax2 = subplot(numel(deltas_mm), 2, 2*i);
        plotResidualPanel(ax2, T, M, delta);
        addPanelLabel(ax2, char('a' + 2*i - 1));

        if i < numel(deltas_mm)
            set(ax1, 'XTickLabel', []);
            set(ax2, 'XTickLabel', []);
        else
            xlabel(ax1, 'Time (day)');
            xlabel(ax2, 'Time (day)');
        end
    end

    set(findall(fig, '-property', 'FontName'), 'FontName', 'Arial');
    set(findall(fig, '-property', 'FontSize'), 'FontSize', 7);

    baseName = fullfile(figDir, ...
        'MATLAB_curve_Minaei_params_gap_Tout_CFD_vs_MinaeiG');
    saveFigureAll(fig, baseName);
    close(fig);

    %% [06] 写出说明文件，记录只保留曲线图像的版本
    noteFile = fullfile(outDir, 'README_MATLAB_curve_validation.md');
    fid = fopen(noteFile, 'w');
    assert(fid > 0, 'Cannot open note file: %s', noteFile);
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '# Minaei-parameter CFD vs Minaei-G curve validation\n\n');
    fprintf(fid, 'This MATLAB post-processing script keeps only curve figures.\n\n');
    fprintf(fid, '- Compared gap cases: %s mm\n', strjoin(compose('%g', deltas_mm), ', '));
    fprintf(fid, '- Figure output: `curve_figures/`\n');
    fprintf(fid, '- Origin data output: `origin_data/`\n');
    fprintf(fid, '- ILS/FLS kernels are not evaluated or plotted.\n');
    fprintf(fid, '- Annual energy data are exported as CSV only; no bar or summary figures are generated.\n\n');

    fprintf('Done. MATLAB curve-only validation package: %s\n', outDir);
end

function plotOutletPanel(ax, T, M, delta, addLabels)
    axes(ax); %#ok<LAXES>
    hold(ax, 'on'); box(ax, 'off');
    plot(ax, T.t_day, T.Tin_C, '-', 'Color', [0.82 0.82 0.82], 'LineWidth', 0.8);
    plot(ax, T.t_day, T.Tout_CFD_kepsilon_C, '-', 'Color', [0.714 0.263 0.259], 'LineWidth', 1.25);
    plot(ax, T.t_day, T.Tout_MATLAB_MinaeiG_C, '--', 'Color', [0.059 0.302 0.573], 'LineWidth', 1.25);
    xlim(ax, [0 365]);
    ylim(ax, [14 27]);
    ylabel(ax, 'Temperature (deg C)');
    title(ax, sprintf('gap = %g mm', delta), 'FontWeight', 'normal');
    text(ax, 12, 15.1, sprintf('RMSE = %.2f deg C', M.RMSE_C), ...
        'Color', [0.45 0.45 0.45], 'FontSize', 7);
    if addLabels
        text(ax, 255, 25.2, 'Inlet', 'Color', [0.82 0.82 0.82], 'FontSize', 7);
        text(ax, 255, 24.2, 'CFD k-epsilon', 'Color', [0.714 0.263 0.259], 'FontSize', 7);
        text(ax, 255, 23.2, 'Minaei-G model', 'Color', [0.059 0.302 0.573], 'FontSize', 7);
    end
    styleAxes(ax);
end

function plotResidualPanel(ax, T, M, delta)
    axes(ax); %#ok<LAXES>
    hold(ax, 'on'); box(ax, 'off');
    plot(ax, [0 365], [0 0], '-', 'Color', [0.84 0.84 0.84], 'LineWidth', 0.9);
    plot(ax, T.t_day, T.Tout_MATLAB_minus_CFD_C, '-', ...
        'Color', [0.15 0.15 0.15], 'LineWidth', 1.1);
    xlim(ax, [0 365]);
    if delta == 5
        ylim(ax, [-0.75 2.0]);
    else
        ylim(ax, [-0.75 0.9]);
    end
    ylabel(ax, 'Model - CFD (deg C)');
    title(ax, sprintf('residual, gap = %g mm', delta), 'FontWeight', 'normal');
    yl = ylim(ax);
    text(ax, 12, yl(1) + 0.11*diff(yl), ...
        sprintf('bias = %.2f deg C', M.bias_model_minus_CFD_C), ...
        'Color', [0.45 0.45 0.45], 'FontSize', 7);
    styleAxes(ax);
end

function styleAxes(ax)
    set(ax, 'LineWidth', 0.75, 'TickDir', 'out', 'Box', 'off', ...
        'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
end

function addPanelLabel(ax, labelText)
    text(ax, -0.12, 1.06, labelText, 'Units', 'normalized', ...
        'FontWeight', 'bold', 'FontSize', 8, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
end

function value = rmseLocal(err)
    err = err(isfinite(err));
    value = sqrt(mean(err.^2));
end

function makeDirIfNeeded(pathName)
    if ~exist(pathName, 'dir')
        mkdir(pathName);
    end
end

function saveFigureAll(fig, baseName)
    try
        exportgraphics(fig, [baseName '.png'], 'Resolution', 600);
        exportgraphics(fig, [baseName '.tiff'], 'Resolution', 600);
        exportgraphics(fig, [baseName '.pdf'], 'ContentType', 'vector');
        exportgraphics(fig, [baseName '.svg'], 'ContentType', 'vector');
    catch
        saveas(fig, [baseName '.png']);
        saveas(fig, [baseName '.pdf']);
        saveas(fig, [baseName '.svg']);
        print(fig, [baseName '.tiff'], '-dtiff', '-r600');
    end
end
