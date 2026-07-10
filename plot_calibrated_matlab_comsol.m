function plot_calibrated_matlab_comsol()
%PLOT_CALIBRATED_MATLAB_COMSOL Plot calibrated MATLAB-COMSOL comparison.

rootDir = 'G:\codexproject';
matDir = fullfile(rootDir, 'EAHE_airgap_physical_v17_review_ready_results');
calDir = fullfile(matDir, 'MATLAB_COMSOL_calibrated');
outDir = fullfile(calDir, 'figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

Tcal = readtable(fullfile(calDir, 'calibration_summary.csv'));
Tmetric = readtable(fullfile(calDir, 'calibrated_Tout_metrics_vs_COMSOL.csv'));

fig = figure('Name','Calibrated annual comparison','Color','w', ...
    'Position',[100 100 1120 450]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
plot(Tcal.delta_mm, Tcal.MATLAB_calibrated_Eabs_kWh, '-o', 'LineWidth',1.4, ...
    'DisplayName','Calibrated MATLAB');
plot(Tcal.delta_mm, Tcal.COMSOL_target_Eabs_kWh, '-s', 'LineWidth',1.4, ...
    'DisplayName','COMSOL resistance gap');
xlabel('\delta / mm'); ylabel('E_{abs} / kWh');
title('Annual heat exchange after calibration');
legend('Location','southwest'); apply_style(gca);

nexttile; hold on; box on; grid on;
plot(Tcal.delta_mm, Tcal.MATLAB_calibrated_Dgap_percent, '-o', 'LineWidth',1.4, ...
    'DisplayName','Calibrated MATLAB');
plot(Tcal.delta_mm, Tcal.COMSOL_target_Dgap_percent, '-s', 'LineWidth',1.4, ...
    'DisplayName','COMSOL resistance gap');
xlabel('\delta / mm'); ylabel('D_{gap} / %');
title('Air-gap performance degradation');
legend('Location','northwest'); apply_style(gca);
export_fig(fig, outDir, 'Fig_CAL01_energy_Dgap');

fig = figure('Name','Calibrated Tout metrics','Color','w', ...
    'Position',[100 100 1120 450]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
plot(Tmetric.delta_mm, Tmetric.RMSE_Tout_C, '-o', 'LineWidth',1.4);
xlabel('\delta / mm'); ylabel('RMSE of T_{out} / ^\circC');
title('Outlet-temperature difference');
apply_style(gca);

nexttile; hold on; box on; grid on;
plot(Tmetric.delta_mm, Tmetric.RMSE_airgap_effect_C, '-s', 'LineWidth',1.4);
xlabel('\delta / mm'); ylabel('RMSE of air-gap effect / ^\circC');
title('Incremental effect: T_{out,\delta}-T_{out,0}');
apply_style(gca);
export_fig(fig, outDir, 'Fig_CAL02_Tout_metrics');

fprintf('Calibrated comparison figures exported to: %s\n', outDir);
end

function apply_style(ax)
set(ax, 'FontName','Arial', 'FontSize',10, 'LineWidth',0.9);
ax.GridAlpha = 0.22;
try
    disableDefaultInteractivity(ax);
    ax.Toolbar.Visible = 'off';
catch
end
end

function export_fig(fig, outDir, baseName)
pngPath = fullfile(outDir, [baseName '.png']);
pdfPath = fullfile(outDir, [baseName '.pdf']);
set(fig, 'PaperPositionMode','auto');
print(fig, pngPath, '-dpng', '-r450');
print(fig, pdfPath, '-dpdf', '-vector');
close(fig);
end
