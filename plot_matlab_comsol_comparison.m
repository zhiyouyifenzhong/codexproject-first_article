function plot_matlab_comsol_comparison()
%PLOT_MATLAB_COMSOL_COMPARISON Plot normalized MATLAB-COMSOL comparison.

rootDir = 'G:\codexproject';
matDir = fullfile(rootDir, 'EAHE_airgap_physical_v17_review_ready_results');
outDir = fullfile(matDir, 'MATLAB_COMSOL_comparison_figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

Tmat = readtable(fullfile(matDir, 'Table_01_main_performance_summary.csv'));
Tcom = readtable(fullfile(rootDir, 'COMSOL_EAHE_outputs_annual_full', ...
    'COMSOL_annual_energy_summary.csv'));
Tcmp = readtable(fullfile(matDir, 'MATLAB_COMSOL_Tout_timeseries_metrics.csv'));

Texp = Tcom(strcmp(Tcom.model_type, 'explicit_gap'), :);
Tres = Tcom(strcmp(Tcom.model_type, 'resistance_gap'), :);

fig = figure('Name','MATLAB COMSOL normalized comparison','Color','w', ...
    'Position',[100 100 1120 450]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
plot(Tmat.delta_mm, Tmat.Eabs_kWh/Tmat.Eabs_kWh(1), '-o', 'LineWidth',1.4, ...
    'DisplayName','MATLAB RC model');
plot(Tres.delta_mm, Tres.Eabs_kWh/Tres.Eabs_kWh(1), '-s', 'LineWidth',1.4, ...
    'DisplayName','COMSOL resistance gap');
plot(Texp.delta_mm, Texp.Eabs_kWh/Texp.Eabs_kWh(1), '-^', 'LineWidth',1.4, ...
    'DisplayName','COMSOL explicit gap');
xlabel('\delta / mm'); ylabel('E_{abs}/E_{abs,0}');
title('Normalized annual heat exchange');
legend('Location','southwest');
apply_style(gca);

nexttile; hold on; box on; grid on;
plot(Tmat.delta_mm, Tmat.Dgap_percent, '-o', 'LineWidth',1.4, ...
    'DisplayName','MATLAB RC model');
plot(Tres.delta_mm, Tres.Dgap_percent, '-s', 'LineWidth',1.4, ...
    'DisplayName','COMSOL resistance gap');
plot(Texp.delta_mm, Texp.Dgap_percent, '-^', 'LineWidth',1.4, ...
    'DisplayName','COMSOL explicit gap');
xlabel('\delta / mm'); ylabel('D_{gap} / %');
title('Performance degradation');
legend('Location','northwest');
apply_style(gca);
export_fig(fig, outDir, 'Fig_MC01_normalized_energy_Dgap');

fig = figure('Name','MATLAB COMSOL Tout metrics','Color','w', ...
    'Position',[100 100 1120 450]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on; box on; grid on;
plot(Tcmp.delta_mm, Tcmp.RMSE_Tout_C, '-o', 'LineWidth',1.4);
xlabel('\delta / mm'); ylabel('RMSE of T_{out} / ^\circC');
title('Absolute outlet-temperature difference');
apply_style(gca);

nexttile; hold on; box on; grid on;
plot(Tcmp.delta_mm, Tcmp.RMSE_airgap_effect_C, '-s', 'LineWidth',1.4);
xlabel('\delta / mm'); ylabel('RMSE of air-gap effect / ^\circC');
title('Incremental effect: T_{out,\delta}-T_{out,0}');
apply_style(gca);
export_fig(fig, outDir, 'Fig_MC02_Tout_difference_metrics');

fprintf('MATLAB-COMSOL comparison figures exported to: %s\n', outDir);
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
