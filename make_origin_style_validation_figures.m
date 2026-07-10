%% make_origin_style_validation_figures.m
% Create publication-style figures from the Origin export CSV data.
%
% The local OriginLab folder does not expose a callable Origin executable in
% this environment, so this script applies an Origin-like paper style directly
% to the exported plotting data. The same CSV files remain available for
% further manual editing in Origin.

function make_origin_style_validation_figures()
    close all; clc;

    rootDir = pwd;
    dataDir = fullfile(rootDir, 'Origin_export_validation_data');
    outDir = fullfile(dataDir, 'paper_figures');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    setPaperDefaults();

    may = readtable(fullfile(dataDir, 'Origin_Sharan_May_MATLAB_vs_exp.csv'));
    jan = readtable(fullfile(dataDir, 'Origin_Sharan_January_MATLAB_vs_exp.csv'));
    annual0 = readtable(fullfile(dataDir, 'Origin_Annual_CFD_vs_MATLAB_delta_0mm.csv'));
    annual1 = readtable(fullfile(dataDir, 'Origin_Annual_CFD_vs_MATLAB_delta_1mm.csv'));
    annual5 = readtable(fullfile(dataDir, 'Origin_Annual_CFD_vs_MATLAB_delta_5mm.csv'));
    metrics = readtable(fullfile(dataDir, 'Origin_Sharan_and_annual_metrics.csv'));

    plotSharanFigure(outDir, may, jan);
    plotAnnualToutFigure(outDir, annual0, annual1, annual5);
    plotAnnualResidualFigure(outDir, annual0, annual1, annual5);
    plotMetricFigure(outDir, metrics);

    fprintf('Origin-style paper figures written to: %s\n', outDir);
end

function setPaperDefaults()
    set(groot, 'defaultFigureColor', 'w');
    set(groot, 'defaultAxesFontName', 'Times New Roman');
    set(groot, 'defaultTextFontName', 'Times New Roman');
    set(groot, 'defaultLegendFontName', 'Times New Roman');
    set(groot, 'defaultAxesFontSize', 8.5);
    set(groot, 'defaultTextFontSize', 8.5);
    set(groot, 'defaultLineLineWidth', 1.15);
    set(groot, 'defaultAxesLineWidth', 0.85);
    set(groot, 'defaultAxesTickDir', 'in');
    set(groot, 'defaultAxesTickLength', [0.012 0.012]);
    set(groot, 'defaultAxesXMinorTick', 'on');
    set(groot, 'defaultAxesYMinorTick', 'on');
end

function plotSharanFigure(outDir, may, jan)
    fig = figure('Units','centimeters','Position',[2 2 18.0 13.6]);
    tiledlayout(2, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

    plotPair(nexttile, may.time_h, may.T25_exp_C, may.T25_MATLAB_C, ...
        '(a) May cooling, 25 m', 'Time (h)', 'Temperature (^{\circ}C)');
    plotPair(nexttile, may.time_h, may.Tout_exp_C, may.Tout_MATLAB_C, ...
        '(b) May cooling, outlet', 'Time (h)', 'Temperature (^{\circ}C)');
    plotPair(nexttile, jan.time_h, jan.T25_exp_C, jan.T25_MATLAB_C, ...
        '(c) January heating, 25 m', 'Time (h)', 'Temperature (^{\circ}C)');
    plotPair(nexttile, jan.time_h, jan.Tout_exp_C, jan.Tout_MATLAB_C, ...
        '(d) January heating, outlet', 'Time (h)', 'Temperature (^{\circ}C)');

    exportFigure(fig, outDir, 'Fig01_Sharan_MATLAB_vs_experiment_origin_style');
end

function plotPair(ax, x, yExp, yModel, ttl, xl, yl)
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    ax.GridColor = [0.82 0.82 0.82];
    ax.GridAlpha = 0.35;
    plot(ax, x, yExp, 'o-', 'Color', [0.00 0.00 0.00], ...
        'MarkerFaceColor', 'w', 'MarkerSize', 3.8, 'DisplayName', 'Experiment');
    plot(ax, x, yModel, 's--', 'Color', [0.00 0.32 0.72], ...
        'MarkerFaceColor', 'w', 'MarkerSize', 3.8, 'DisplayName', 'MATLAB Minaei-G');
    title(ax, ttl, 'FontWeight', 'normal');
    xlabel(ax, xl);
    ylabel(ax, yl);
    legend(ax, 'Location', 'best', 'Box', 'off', 'FontSize', 7.5);
end

function plotAnnualToutFigure(outDir, d0, d1, d5)
    fig = figure('Units','centimeters','Position',[2 2 18.0 14.2]);
    tiledlayout(3, 1, 'TileSpacing', 'loose', 'Padding', 'compact');

    plotAnnualPanel(nexttile, d0, '(a) \delta = 0 mm');
    plotAnnualPanel(nexttile, d1, '(b) \delta = 1 mm');
    plotAnnualPanel(nexttile, d5, '(c) \delta = 5 mm');

    exportFigure(fig, outDir, 'Fig02_Annual_CFD_vs_MATLAB_Tout_origin_style');
end

function plotAnnualPanel(ax, T, ttl)
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    ax.GridColor = [0.84 0.84 0.84];
    ax.GridAlpha = 0.32;
    plot(ax, T.t_day, T.Tin_C, '-', 'Color', [0.55 0.55 0.55], ...
        'LineWidth', 0.9, 'DisplayName', 'Inlet');
    plot(ax, T.t_day, T.Tout_CFD_kepsilon_C, '-', 'Color', [0.00 0.32 0.72], ...
        'LineWidth', 1.2, 'DisplayName', 'CFD k-\epsilon');
    plot(ax, T.t_day, T.Tout_MATLAB_MinaeiG_C, '--', 'Color', [0.80 0.18 0.12], ...
        'LineWidth', 1.2, 'DisplayName', 'MATLAB Minaei-G');
    title(ax, ttl, 'FontWeight', 'normal');
    xlabel(ax, 'Time (day)');
    ylabel(ax, 'Temperature (^{\circ}C)');
    xlim(ax, [0 365]);
    ylim(ax, [14 27]);
    legend(ax, 'Location', 'north', 'Box', 'off', 'NumColumns', 3, 'FontSize', 7.2);
end

function plotAnnualResidualFigure(outDir, d0, d1, d5)
    fig = figure('Units','centimeters','Position',[2 2 18.0 12.6]);
    tiledlayout(3, 1, 'TileSpacing', 'loose', 'Padding', 'compact');

    plotResidualPanel(nexttile, d0, '(a) \delta = 0 mm');
    plotResidualPanel(nexttile, d1, '(b) \delta = 1 mm');
    plotResidualPanel(nexttile, d5, '(c) \delta = 5 mm');

    exportFigure(fig, outDir, 'Fig03_Annual_Tout_residual_origin_style');
end

function plotResidualPanel(ax, T, ttl)
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    ax.GridColor = [0.84 0.84 0.84];
    ax.GridAlpha = 0.32;
    plot(ax, T.t_day, T.Tout_MATLAB_minus_CFD_C, '-', 'Color', [0.10 0.10 0.10], 'LineWidth', 1.25);
    yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
    title(ax, ttl, 'FontWeight', 'normal');
    xlabel(ax, 'Time (day)');
    ylabel(ax, 'MATLAB - CFD (^{\circ}C)');
    xlim(ax, [0 365]);
end

function plotMetricFigure(outDir, metrics)
    fig = figure('Units','centimeters','Position',[2 2 18.0 8.2]);
    tiledlayout(1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

    sharan = metrics(strcmp(string(metrics.source), "Sharan_MATLAB_vs_exp"), :);
    sharanTout = sharan(strcmp(string(sharan.quantity), "Tout"), :);
    [~, order] = ismember(["Sharan_May_cooling"; "Sharan_January_heating"], string(sharanTout.case_name));
    order = order(order > 0);
    sharanTout = sharanTout(order, :);
    ax1 = nexttile; hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
    bar(ax1, 1:height(sharanTout), sharanTout.RMSE_C, 0.55, ...
        'FaceColor', [0.00 0.32 0.72], 'EdgeColor', 'k', 'LineWidth', 0.6);
    ax1.XTick = 1:height(sharanTout);
    ax1.XTickLabel = {'May cooling', 'January heating'};
    ax1.XTickLabelRotation = 0;
    ylim(ax1, [0 0.75]);
    ylabel(ax1, 'RMSE (^{\circ}C)');
    title(ax1, '(a) MATLAB vs Sharan outlet temperature', 'FontWeight', 'normal', 'FontSize', 8.2);
    ax1.GridAlpha = 0.25;

    annual = metrics(strcmp(string(metrics.source), "Annual_CFD_vs_MATLAB_Tout"), :);
    ax2 = nexttile; hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
    bar(ax2, annual.delta_mm, annual.RMSE_C, 0.55, ...
        'FaceColor', [0.80 0.18 0.12], 'EdgeColor', 'k', 'LineWidth', 0.6);
    ax2.XTick = [0 1 5];
    xlim(ax2, [-0.6 5.6]);
    ylim(ax2, [0 0.55]);
    xlabel(ax2, '\delta (mm)');
    ylabel(ax2, 'RMSE (^{\circ}C)');
    title(ax2, '(b) CFD vs MATLAB annual outlet temperature', 'FontWeight', 'normal', 'FontSize', 8.2);
    ax2.GridAlpha = 0.25;

    exportFigure(fig, outDir, 'Fig04_Validation_RMSE_summary_origin_style');
end

function exportFigure(fig, outDir, name)
    pngFile = fullfile(outDir, [name '.png']);
    pdfFile = fullfile(outDir, [name '.pdf']);
    tifFile = fullfile(outDir, [name '.tif']);

    try
        exportgraphics(fig, pngFile, 'Resolution', 600);
        exportgraphics(fig, pdfFile, 'ContentType', 'vector');
        exportgraphics(fig, tifFile, 'Resolution', 600);
    catch
        print(fig, pngFile, '-dpng', '-r600');
        print(fig, pdfFile, '-dpdf', '-painters');
        print(fig, tifFile, '-dtiff', '-r600');
    end
    close(fig);
end
