function EAHE_postprocess_saved_results_review_figures()
%EAHE_POSTPROCESS_SAVED_RESULTS_REVIEW_FIGURES Redraw review-ready figures.
% This postprocessor uses the saved v17 MAT file and does not rerun the
% annual EAHE simulation.

rootDir = 'G:\codexproject\EAHE_airgap_physical_v17_review_ready_results';
matFile = fullfile(rootDir, 'EAHE_airgap_physical_v17_review_ready_results.mat');
outDir = fullfile(rootDir, 'review_redrawn_figures');

if ~exist(matFile, 'file')
    error('Saved result file not found: %s', matFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

S = load(matFile);
p = S.p;
res = S.res;
deltaList_mm = S.deltaList_mm;
phi = S.phiBase;
T_Nx = S.T_Nx;
T_dt = S.T_dt;

plot_physical_schematic_pp(p, outDir);
plot_rc_network_pp(outDir);
plot_solver_flowchart_pp(outDir);
plot_main_results_pp(res, deltaList_mm, outDir);
plot_resistance_and_engineering_pp(res, deltaList_mm, outDir);
plot_summary_figures_pp(res, deltaList_mm, p, phi, outDir);
plot_independence_results_pp(T_Nx, T_dt, outDir);

fprintf('Review-ready redrawn figures exported to: %s\n', outDir);
end

function plot_physical_schematic_pp(p, outDir)
deltaShow = 2e-3;
rg = p.rpo + deltaShow;
fig = figure('Name','Fig00 physical schematic','Color','w', ...
    'Position',[100 100 1150 420]);
hold on; box on;
x0 = 0; x1 = p.L;
rectangle('Position',[x0, 0, x1, 0.18], 'FaceColor',[0.86 0.92 0.82], ...
    'EdgeColor',[0.35 0.45 0.30], 'LineWidth',1.0);
rectangle('Position',[x0, 0, x1, rg], 'FaceColor',[0.98 0.93 0.76], ...
    'EdgeColor',[0.70 0.55 0.20], 'LineWidth',1.0);
rectangle('Position',[x0, 0, x1, p.rpo], 'FaceColor',[0.78 0.80 0.84], ...
    'EdgeColor',[0.25 0.25 0.28], 'LineWidth',1.0);
rectangle('Position',[x0, 0, x1, p.rpi], 'FaceColor',[0.73 0.87 0.98], ...
    'EdgeColor',[0.10 0.30 0.55], 'LineWidth',1.0);
plot([x0 x1],[p.rpi p.rpi],'k-','LineWidth',1.0);
plot([x0 x1],[p.rpo p.rpo],'k-','LineWidth',1.0);
plot([x0 x1],[rg rg],'k--','LineWidth',1.0);
plot([1.0 4.8], [p.rpi*0.45 p.rpi*0.45], '-', 'LineWidth',1.5, ...
    'Color',[0.05 0.25 0.55]);
plot(4.8, p.rpi*0.45, '>', 'MarkerFaceColor',[0.05 0.25 0.55], ...
    'MarkerEdgeColor',[0.05 0.25 0.55], 'MarkerSize',7);
text(5.4, p.rpi*0.48, 'Air flow T_f', 'Color',[0.05 0.25 0.55]);
text(p.L*0.50, p.rpi*0.42, 'air', 'HorizontalAlignment','center');
text(p.L*0.50, (p.rpi+p.rpo)/2, 'pipe', 'HorizontalAlignment','center');
text(p.L*0.50, (p.rpo+rg)/2, 'air gap \delta', 'HorizontalAlignment','center');
text(p.L*0.50, (rg+0.18)/2, 'soil', 'HorizontalAlignment','center');
text(0.8, p.rpi, 'r_{pi}', 'VerticalAlignment','bottom');
text(0.8, p.rpo, 'r_{po}', 'VerticalAlignment','bottom');
text(0.8, rg, 'r_g=r_{po}+\delta', 'VerticalAlignment','bottom');
xlabel('z / m'); ylabel('r / m');
title('EAHE physical model and air-gap interface');
xlim([0 p.L]); ylim([0 0.18]);
apply_style(gca);
export_fig(fig, outDir, 'Fig00_model_physical_schematic_redrawn');
end

function plot_rc_network_pp(outDir)
fig = figure('Name','Fig00b RC network','Color','w', ...
    'Position',[100 100 980 360]);
hold on; axis off;
nodesX = [0 2.2 4.4 6.6];
labels = {'T_f','T_p','T_g','T_h + \DeltaT_s'};
for i = 1:numel(nodesX)
    plot(nodesX(i), 0, 'o', 'MarkerSize',22, ...
        'MarkerFaceColor',[0.90 0.95 1.00], ...
        'MarkerEdgeColor',[0.15 0.25 0.45]);
    text(nodesX(i), 0, labels{i}, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', 'FontWeight','bold');
end
plot([nodesX(1) nodesX(2)],[0 0],'k-','LineWidth',1.4);
plot([nodesX(2) nodesX(3)],[0 0],'k-','LineWidth',1.4);
plot([nodesX(3) nodesX(4)],[0 0],'k--','LineWidth',1.2);
text(mean(nodesX(1:2)), 0.35, 'R_{p1}=R_{conv}+R_{cond,in}', ...
    'HorizontalAlignment','center');
text(mean(nodesX(2:3)), 0.35, 'R_{\delta}=R_{p2}+R_{gap}', ...
    'HorizontalAlignment','center');
text(mean(nodesX(3:4)), 0.35, 'soil response G(t)', ...
    'HorizontalAlignment','center');
text(nodesX(1), -0.42, 'C_f', 'HorizontalAlignment','center');
text(nodesX(2), -0.42, 'C_p', 'HorizontalAlignment','center');
text(mean(nodesX(2:3)), -0.42, 'T_{po}-T_g=q_g R_{gap}', ...
    'HorizontalAlignment','center', 'Color',[0.55 0.10 0.08]);
text(mean(nodesX(1:2)), -0.72, ...
    'C_f dT_f/dt = advection + (T_p-T_f)/R_{p1}', ...
    'HorizontalAlignment','center', 'FontSize',9);
text(mean(nodesX(2:3)), -0.72, ...
    'C_p dT_p/dt = (T_f-T_p)/R_{p1} + (T_g-T_p)/R_{\delta}', ...
    'HorizontalAlignment','center', 'FontSize',9);
title('Thermal resistance-capacitance network');
xlim([-0.45 7.05]); ylim([-0.88 0.75]);
export_fig(fig, outDir, 'Fig00b_RC_network_redrawn');
end

function plot_solver_flowchart_pp(outDir)
fig = figure('Name','Fig00c solver workflow','Color','w', ...
    'Position',[100 100 820 900]);
hold on; axis off;
boxW = 5.8; boxH = 0.58; x = 0.25;
y = [6.0 5.1 4.2 3.3 2.4 1.5 0.6 -0.3];
txt = {'Input geometry, material and operation parameters', ...
       'Compute R_{p1}, R_{gap}, R_{\delta} and soil kernel G(t)', ...
       'Initialize T_f, T_p and T_g from undisturbed soil temperature', ...
       'Advance to time step n -> n+1', ...
       'Picard iteration: update T_g and q_g until convergence', ...
       'Solve T_f and T_p with implicit Euler and upwind advection', ...
       'Store T_{out}, Q_{air}, \DeltaT_{int} and energy residual', ...
       'Export last-year figures, CSV tables and Excel workbook'};
for i = 1:numel(y)
    rectangle('Position',[x y(i) boxW boxH], 'Curvature',0.05, ...
        'FaceColor',[0.96 0.97 0.98], 'EdgeColor',[0.25 0.25 0.25]);
    text(x+boxW/2, y(i)+boxH/2, txt{i}, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', 'FontSize',9);
    if i < numel(y)
        quiver(x+boxW/2, y(i)-0.04, 0, -0.34, 0, 'k', ...
            'LineWidth',1.0, 'MaxHeadSize',0.4);
    end
end
title('Numerical solution workflow');
xlim([0 6.3]); ylim([-0.75 6.85]);
export_fig(fig, outDir, 'Fig00c_solver_flowchart_redrawn');
end

function plot_main_results_pp(res, deltaList_mm, outDir)
labels = delta_labels(deltaList_mm);
colors = lines(numel(res));

fig = figure('Name','Fig01 temperature','Color','w', 'Position',[100 100 1200 620]);
hold on; box on; grid on;
plot(res{1}.day, res{1}.Tin, 'k-', 'LineWidth', 1.6, 'DisplayName', 'T_{in}');
plot(res{1}.day, res{1}.Th, 'k--', 'LineWidth', 1.6, 'DisplayName', 'T_h(H,t)');
for k = 1:numel(res)
    plot(res{k}.day, res{k}.Tout, 'LineWidth', 1.25, ...
        'Color', colors(k,:), 'DisplayName', labels{k});
end
xlabel('t / day'); ylabel('Temperature / ^\circC');
title('Inlet, undisturbed soil and outlet air temperatures');
legend('Location','eastoutside'); apply_style(gca);
export_fig(fig, outDir, 'Fig01_Tin_Th_Tout_redrawn');

fig = figure('Name','Fig02 Tout deviation','Color','w', 'Position',[100 100 1200 620]);
hold on; box on; grid on;
Tout0 = res{1}.Tout;
for k = 2:numel(res)
    plot(res{k}.day, res{k}.Tout - Tout0, 'LineWidth', 1.35, ...
        'Color', colors(k,:), 'DisplayName', labels{k});
end
yline(0,'k:','HandleVisibility','off');
xlabel('t / day'); ylabel('T_{out,\delta}-T_{out,0} / ^\circC');
title('Outlet temperature deviation induced by air gap');
legend('Location','eastoutside'); apply_style(gca);
export_fig(fig, outDir, 'Fig02_Tout_deviation_redrawn');

fig = figure('Name','Fig03 heat rate','Color','w', 'Position',[100 100 1200 620]);
hold on; box on; grid on;
for k = 1:numel(res)
    plot(res{k}.day, res{k}.Qair, 'LineWidth', 1.25, ...
        'Color', colors(k,:), 'DisplayName', labels{k});
end
yline(0,'k:','HandleVisibility','off');
xlabel('t / day'); ylabel('Q_{air} / W');
title('Instantaneous air-side heat transfer rate');
legend('Location','eastoutside'); apply_style(gca);
export_fig(fig, outDir, 'Fig03_heat_rate_redrawn');

fig = figure('Name','Fig04 interface jump','Color','w', 'Position',[100 100 1200 620]);
hold on; box on; grid on;
for k = 2:numel(res)
    jumpMean = mean(abs(res{k}.TintJump),1);
    plot(res{k}.day, jumpMean, 'LineWidth', 1.35, ...
        'Color', colors(k,:), 'DisplayName', labels{k});
end
xlabel('t / day'); ylabel('|\Delta T_{int}| / ^\circC');
title('Air-gap interface temperature jump');
legend('Location','eastoutside'); apply_style(gca);
export_fig(fig, outDir, 'Fig04_interface_temperature_jump_redrawn');

fig = figure('Name','Fig05 energy residual','Color','w', 'Position',[100 100 1200 620]);
hold on; box on; grid on;
for k = 1:numel(res)
    semilogy(res{k}.day, max(res{k}.epsQ, eps), 'LineWidth', 1.1, ...
        'Color', colors(k,:), 'DisplayName', labels{k});
end
xlabel('t / day'); ylabel('\epsilon_Q');
title('Energy balance residual');
legend('Location','eastoutside'); apply_style(gca);
export_fig(fig, outDir, 'Fig05_energy_balance_residual_redrawn');
end

function plot_resistance_and_engineering_pp(res, deltaList_mm, outDir)
n = numel(res);
comp = zeros(n,4);
etaU = zeros(n,1);
Lratio = zeros(n,1);
Rint = zeros(n,1);
for k = 1:n
    R = res{k}.Reng;
    Rtot = R.RtotPhi;
    comp(k,:) = [R.Ra, R.Rp, R.Rs0, max(R.Rint_eff,0)]/Rtot*100;
    etaU(k) = R.etaU;
    Lratio(k) = R.Lratio;
    Rint(k) = R.Rint_eff;
end

fig = figure('Name','Fig06 resistance contribution','Color','w', ...
    'Position',[100 100 1050 620]);
box on; grid on;
xcat = categorical(delta_labels(deltaList_mm));
xcat = reordercats(xcat, delta_labels(deltaList_mm));
bar(xcat, comp, 'stacked');
xlabel('\delta / mm'); ylabel('Contribution / %');
legend('R_a','R_p','R_s','R_{int}','Location','eastoutside');
title('Total thermal resistance components');
apply_style(gca);
export_fig(fig, outDir, 'Fig06_resistance_contribution_redrawn');

fig = figure('Name','Fig07 engineering factors','Color','w', ...
    'Position',[100 100 1320 440]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
nexttile; box on; grid on;
plot(deltaList_mm, Rint, '-o', 'LineWidth', 1.4);
xlabel('\delta / mm'); ylabel('R''_{int} / (m K W^{-1})');
title('Additional interface resistance'); apply_style(gca);
nexttile; box on; grid on;
plot(deltaList_mm, etaU, '-o', 'LineWidth', 1.4); hold on;
yline(0.98,'k:','0.98','LabelHorizontalAlignment','left');
yline(0.95,'k:','0.95','LabelHorizontalAlignment','left');
yline(0.90,'k:','0.90','LabelHorizontalAlignment','left');
xlabel('\delta / mm'); ylabel('\eta_U');
title('Heat-transfer correction factor'); apply_style(gca);
nexttile; box on; grid on;
plot(deltaList_mm, Lratio, '-o', 'LineWidth', 1.4);
xlabel('\delta / mm'); ylabel('L_{\delta}/L_0');
title('Effective length correction'); apply_style(gca);
export_fig(fig, outDir, 'Fig07_engineering_correction_factors_redrawn');
end

function plot_summary_figures_pp(res, deltaList_mm, p, phi, outDir)
n = numel(res);
Ecool = zeros(n,1); Eheat = zeros(n,1); Eabs = zeros(n,1);
Dgap = zeros(n,1); dToutMean = zeros(n,1); dToutMax = zeros(n,1);
jumpMean = zeros(n,1); jumpMax = zeros(n,1);
Tout0 = res{1}.Tout;
E0 = res{1}.E_abs;
for k = 1:n
    Ecool(k) = res{k}.E_cool;
    Eheat(k) = res{k}.E_heat;
    Eabs(k) = res{k}.E_abs;
    Dgap(k) = (1 - res{k}.E_abs/E0)*100;
    dToutMean(k) = mean(abs(res{k}.Tout(:) - Tout0(:)));
    dToutMax(k) = max(abs(res{k}.Tout(:) - Tout0(:)));
    jumpMean(k) = mean(abs(res{k}.TintJump(:)));
    jumpMax(k) = max(abs(res{k}.TintJump(:)));
end

fig = figure('Name','Fig08 annual energy','Color','w');
box on; grid on; hold on;
plot(deltaList_mm, Ecool, '-o', 'LineWidth', 1.4, 'DisplayName','Cooling');
plot(deltaList_mm, Eheat, '-s', 'LineWidth', 1.4, 'DisplayName','Heating');
plot(deltaList_mm, Eabs, '-^', 'LineWidth', 1.4, 'DisplayName','Absolute');
xlabel('\delta / mm'); ylabel('Annual energy / kWh');
title('Annual heat exchange energy versus air-gap thickness');
legend('Location','best'); apply_style(gca);
export_fig(fig, outDir, 'Fig08_annual_energy_vs_delta_redrawn');

fig = figure('Name','Fig09 Dgap','Color','w');
box on; grid on;
plot(deltaList_mm, Dgap, '-o', 'LineWidth', 1.4);
xlabel('\delta / mm'); ylabel('D_{gap} / %');
title('Annual performance degradation caused by air gap');
apply_style(gca);
export_fig(fig, outDir, 'Fig09_Dgap_vs_delta_redrawn');

fig = figure('Name','Fig10 Tout summary','Color','w');
box on; grid on; hold on;
plot(deltaList_mm, dToutMean, '-o', 'LineWidth',1.4, 'DisplayName','Mean absolute deviation');
plot(deltaList_mm, dToutMax, '-s', 'LineWidth',1.4, 'DisplayName','Maximum absolute deviation');
xlabel('\delta / mm'); ylabel('|T_{out,\delta}-T_{out,0}| / ^\circC');
title('Outlet temperature deviation summary');
legend('Location','best'); apply_style(gca);
export_fig(fig, outDir, 'Fig10_Tout_deviation_summary_redrawn');

fig = figure('Name','Fig11 interface summary','Color','w');
box on; grid on; hold on;
plot(deltaList_mm, jumpMean, '-o', 'LineWidth',1.4, 'DisplayName','Mean |\DeltaT_{int}|');
plot(deltaList_mm, jumpMax, '-s', 'LineWidth',1.4, 'DisplayName','Maximum |\DeltaT_{int}|');
xlabel('\delta / mm'); ylabel('|\Delta T_{int}| / ^\circC');
title('Interface temperature jump summary');
legend('Location','best'); apply_style(gca);
export_fig(fig, outDir, 'Fig11_interface_jump_summary_redrawn');

deltaLimit_mm = [0 0.1 0.5 1 2 5 20];
[Rgap, Rdelta, qRelative] = interface_limit_arrays(p, phi, deltaLimit_mm);
mainIdx = deltaLimit_mm <= 5;

fig = figure('Name','Fig12 interface limit','Color','w', ...
    'Position',[100 100 760 720]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile; box on; grid on; hold on;
plot(deltaLimit_mm(mainIdx), Rgap(mainIdx), '-o', 'LineWidth',1.4, 'DisplayName','R_{gap}');
plot(deltaLimit_mm(mainIdx), Rdelta(mainIdx), '-s', 'LineWidth',1.4, 'DisplayName','R_{\delta}');
ylabel('Thermal resistance / (m K W^{-1})');
title('Interface resistance, 0-5 mm');
legend('Location','northwest'); apply_style(gca);
nexttile; box on; grid on;
plot(deltaLimit_mm(mainIdx), qRelative(mainIdx), '-^', 'LineWidth',1.4, ...
    'Color',[0.85 0.33 0.10]);
xlabel('\delta / mm'); ylabel('Relative heat flux');
apply_style(gca);
export_fig(fig, outDir, 'Fig12_interface_resistance_limit_redrawn');

fig = figure('Name','Fig12b wide interface limit','Color','w', ...
    'Position',[100 100 760 720]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile; box on; grid on; hold on;
plot(deltaLimit_mm, Rgap, '-o', 'LineWidth',1.4, 'DisplayName','R_{gap}');
plot(deltaLimit_mm, Rdelta, '-s', 'LineWidth',1.4, 'DisplayName','R_{\delta}');
ylabel('Thermal resistance / (m K W^{-1})');
title('Interface resistance limiting behavior');
legend('Location','northwest'); apply_style(gca);
nexttile; box on; grid on;
plot(deltaLimit_mm, qRelative, '-^', 'LineWidth',1.4, ...
    'Color',[0.85 0.33 0.10]);
xlabel('\delta / mm'); ylabel('Relative heat flux');
apply_style(gca);
export_fig(fig, outDir, 'Fig12b_interface_resistance_wide_range_redrawn');
end

function plot_independence_results_pp(T_Nx, T_dt, outDir)
if ~isempty(T_Nx)
    fig = figure('Name','Fig13 Nx independence','Color','w', ...
        'Position',[100 100 980 420]);
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    nexttile; box on; grid on;
    plot(T_Nx.Nx, T_Nx.RMSE_Tout_C, '-o', 'LineWidth',1.4);
    xlabel('N_x'); ylabel('RMSE of T_{out} / ^\circC');
    title('Outlet-temperature convergence'); apply_style(gca);
    nexttile; box on; grid on;
    plot(T_Nx.Nx, T_Nx.RelErr_Eabs_percent, '-s', 'LineWidth',1.4);
    xlabel('N_x'); ylabel('Relative error of E_{abs} / %');
    title('Annual-energy convergence'); apply_style(gca);
    export_fig(fig, outDir, 'Fig13_Nx_independence_redrawn');
end
if ~isempty(T_dt)
    fig = figure('Name','Fig14 dt independence','Color','w', ...
        'Position',[100 100 980 420]);
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    nexttile; box on; grid on;
    plot(T_dt.dt_h, T_dt.RMSE_Tout_C, '-o', 'LineWidth',1.4);
    set(gca,'XDir','reverse');
    xlabel('\Delta t / h'); ylabel('RMSE of T_{out} / ^\circC');
    title('Outlet-temperature convergence'); apply_style(gca);
    nexttile; box on; grid on;
    plot(T_dt.dt_h, T_dt.RelErr_Eabs_percent, '-s', 'LineWidth',1.4);
    set(gca,'XDir','reverse');
    xlabel('\Delta t / h'); ylabel('Relative error of E_{abs} / %');
    title('Annual-energy convergence'); apply_style(gca);
    export_fig(fig, outDir, 'Fig14_dt_independence_redrawn');
end
end

function [Rgap, Rdelta, qRelative] = interface_limit_arrays(p, phi, deltaList_mm)
Rgap = zeros(size(deltaList_mm));
Rdelta = zeros(size(deltaList_mm));
qRelative = zeros(size(deltaList_mm));
R0 = radial_network_pp(p, 0, phi);
for k = 1:numel(deltaList_mm)
    R = radial_network_pp(p, deltaList_mm(k)*1e-3, phi);
    Rgap(k) = R.Rgap;
    Rdelta(k) = R.Rdelta;
    qRelative(k) = R0.Rdelta/R.Rdelta;
end
end

function R = radial_network_pp(p, delta, phi)
re = sqrt((p.rpi^2 + p.rpo^2)/2);
Rp2 = log(p.rpo/re)/(2*pi*p.kp);
if delta <= 0
    Rgap = 0;
    Rdelta = Rp2;
else
    rg = p.rpo + max(delta,0);
    RgapFull = log(rg/p.rpo)/(2*pi*p.k_air);
    if phi <= 0
        Rgap = 0;
        Rdelta = Rp2;
    elseif phi >= 1
        Rgap = RgapFull;
        Rdelta = Rp2 + RgapFull;
    else
        Rgap = RgapFull;
        Gdelta = (1-phi)/Rp2 + phi/(Rp2 + RgapFull);
        Rdelta = 1/Gdelta;
    end
end
R.Rgap = Rgap;
R.Rdelta = Rdelta;
end

function labels = delta_labels(deltaList_mm)
labels = cell(numel(deltaList_mm),1);
for i = 1:numel(deltaList_mm)
    labels{i} = sprintf('\\delta = %g mm', deltaList_mm(i));
end
end

function apply_style(ax)
set(ax, 'FontName','Arial', 'FontSize',10, 'LineWidth',0.9);
ax.GridAlpha = 0.22;
end

function export_fig(fig, outDir, baseName)
set(fig, 'PaperPositionMode','auto');
axs = findall(fig, 'Type', 'axes');
for i = 1:numel(axs)
    try
        disableDefaultInteractivity(axs(i));
    catch
    end
    try
        axs(i).Toolbar.Visible = 'off';
    catch
    end
end
drawnow;
pngPath = fullfile(outDir, [baseName '.png']);
pdfPath = fullfile(outDir, [baseName '.pdf']);
try
    print(fig, pngPath, '-dpng', '-r450');
    print(fig, pdfPath, '-dpdf', '-vector');
catch
    print(fig, pngPath, '-dpng', '-r600');
    print(fig, pdfPath, '-dpdf', '-painters');
end
close(fig);
end
