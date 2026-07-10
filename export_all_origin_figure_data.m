%% export_all_origin_figure_data.m
% Export numeric source data for MATLAB figures to Origin-ready CSV files.
% Schematic figures are recorded in a coverage table because they have no
% underlying numeric plot data.

clear; clc;

rootDir = 'G:\codexproject\EAHE_airgap_physical_v18_minaei_contact_results';
matPath = fullfile(rootDir, 'EAHE_airgap_physical_v18_minaei_contact_results.mat');
outDir = fullfile(rootDir, 'Origin_ready_data_all_figures');
if ~exist(outDir, 'dir'); mkdir(outDir); end

S = load(matPath);
res = S.res;
factor = S.factor;
deltaList_mm = S.deltaList_mm(:);
rLiterature = S.rLiterature;
T_summary = S.T_summary;
T_literature = S.T_literature;
T_limits = S.T_limits;
T_energy = S.T_energy;

T_Nx = readtable_if_exists(fullfile(rootDir, 'Validation_Nx_independence.csv'));
T_dt = readtable_if_exists(fullfile(rootDir, 'Validation_dt_independence.csv'));
T_allow = readtable_if_exists(fullfile(rootDir, 'Table_05_allowable_gap_thickness.csv'));

labels = cell(numel(deltaList_mm),1);
for k = 1:numel(deltaList_mm)
    labels{k} = number_tag(deltaList_mm(k));
end

coverage = {};

% Fig00 schematic/diagram figures.
coverage = add_coverage(coverage, 'Fig00_model_physical_schematic', 'schematic', '', 'No numeric Origin data required.');
coverage = add_coverage(coverage, 'Fig00b_RC_network', 'schematic', '', 'No numeric Origin data required.');
coverage = add_coverage(coverage, 'Fig00c_solver_flowchart', 'flowchart', '', 'No numeric Origin data required.');

% Literature comparison figures.
T = table(rLiterature.day(:), rLiterature.Tin(:), rLiterature.Th(:), ...
    rLiterature.Tout(:), 'VariableNames', {'day','Tin_C','Th_C','Tout_literature_C'});
for k = 1:numel(res)
    T.(['Tout_improved_delta_' labels{k} '_mm_C']) = res{k}.Tout(:);
end
write_fig_table(T, outDir, 'Origin_Fig00d_improved_vs_literature_Tout.csv');
coverage = add_coverage(coverage, 'Fig00d_improved_vs_literature_Tout', 'timeseries', ...
    'Origin_Fig00d_improved_vs_literature_Tout.csv', 'Literature and improved-model outlet temperatures.');

T = table(rLiterature.day(:), rLiterature.Qair(:), ...
    'VariableNames', {'day','Qair_literature_W'});
for k = 1:numel(res)
    T.(['Qair_improved_delta_' labels{k} '_mm_W']) = res{k}.Qair(:);
end
write_fig_table(T, outDir, 'Origin_Fig00e_improved_vs_literature_Qair.csv');
coverage = add_coverage(coverage, 'Fig00e_improved_vs_literature_Qair', 'timeseries', ...
    'Origin_Fig00e_improved_vs_literature_Qair.csv', 'Literature and improved-model heat-transfer rates.');

write_fig_table(T_literature, outDir, 'Origin_Fig00f_improved_vs_literature_energy.csv');
coverage = add_coverage(coverage, 'Fig00f_improved_vs_literature_energy', 'summary', ...
    'Origin_Fig00f_improved_vs_literature_energy.csv', 'Energy comparison between improved and literature models.');

% Main annual response figures.
T = table(res{1}.day(:), res{1}.Tin(:), res{1}.Th(:), ...
    'VariableNames', {'day','Tin_C','Th_C'});
for k = 1:numel(res)
    T.(['Tout_delta_' labels{k} '_mm_C']) = res{k}.Tout(:);
end
write_fig_table(T, outDir, 'Origin_Fig01_Tin_Th_Tout.csv');
coverage = add_coverage(coverage, 'Fig01_Tin_Th_Tout', 'timeseries', ...
    'Origin_Fig01_Tin_Th_Tout.csv', 'Inlet, undisturbed soil and outlet temperatures.');

Tout0 = res{1}.Tout(:);
T = table(res{1}.day(:), 'VariableNames', {'day'});
for k = 2:numel(res)
    T.(['DeltaTout_delta_' labels{k} '_mm_C']) = res{k}.Tout(:) - Tout0;
end
write_fig_table(T, outDir, 'Origin_Fig02_Tout_deviation.csv');
coverage = add_coverage(coverage, 'Fig02_Tout_deviation', 'timeseries', ...
    'Origin_Fig02_Tout_deviation.csv', 'Outlet-temperature deviation relative to delta = 0.');

T = table(res{1}.day(:), 'VariableNames', {'day'});
for k = 1:numel(res)
    T.(['Qair_delta_' labels{k} '_mm_W']) = res{k}.Qair(:);
end
write_fig_table(T, outDir, 'Origin_Fig03_heat_rate.csv');
coverage = add_coverage(coverage, 'Fig03_heat_rate', 'timeseries', ...
    'Origin_Fig03_heat_rate.csv', 'Air-side heat-transfer rates.');

T = table(res{1}.day(:), 'VariableNames', {'day'});
for k = 1:numel(res)
    T.(['TintJumpMeanAbs_delta_' labels{k} '_mm_C']) = mean(abs(res{k}.TintJump),1).';
    T.(['TintJumpMaxAbs_delta_' labels{k} '_mm_C']) = max(abs(res{k}.TintJump),[],1).';
end
write_fig_table(T, outDir, 'Origin_Fig04_interface_temperature_jump.csv');
coverage = add_coverage(coverage, 'Fig04_interface_temperature_jump', 'timeseries', ...
    'Origin_Fig04_interface_temperature_jump.csv', 'Mean and maximum absolute interface temperature jumps.');

T = table(res{1}.day(:), 'VariableNames', {'day'});
for k = 1:numel(res)
    T.(['EnergyResidual_delta_' labels{k} '_mm']) = res{k}.epsQ(:);
end
write_fig_table(T, outDir, 'Origin_Fig05_energy_balance_residual.csv');
coverage = add_coverage(coverage, 'Fig05_energy_balance_residual', 'timeseries', ...
    'Origin_Fig05_energy_balance_residual.csv', 'Energy residual time series.');

% Engineering and summary figures.
n = numel(res);
delta_mm = deltaList_mm;
Ra_percent = zeros(n,1); Rp_percent = zeros(n,1); Rs0_percent = zeros(n,1);
Rint_percent = zeros(n,1); etaU = zeros(n,1); Ldelta_over_L0 = zeros(n,1);
Rint_eff_mK_W = zeros(n,1);
for k = 1:n
    R = res{k}.Reng;
    Rtot = R.RtotPhi;
    Ra_percent(k) = R.Ra/Rtot*100;
    Rp_percent(k) = R.Rp/Rtot*100;
    Rs0_percent(k) = R.Rs0/Rtot*100;
    Rint_percent(k) = max(R.Rint_eff,0)/Rtot*100;
    etaU(k) = R.etaU;
    Ldelta_over_L0(k) = R.Lratio;
    Rint_eff_mK_W(k) = R.Rint_eff;
end
T = table(delta_mm, Ra_percent, Rp_percent, Rs0_percent, Rint_percent);
write_fig_table(T, outDir, 'Origin_Fig06_resistance_contribution.csv');
coverage = add_coverage(coverage, 'Fig06_resistance_contribution', 'summary', ...
    'Origin_Fig06_resistance_contribution.csv', 'Thermal-resistance contribution percentages.');

T = table(delta_mm, etaU, Ldelta_over_L0, Rint_eff_mK_W);
write_fig_table(T, outDir, 'Origin_Fig07_engineering_correction_factors.csv');
coverage = add_coverage(coverage, 'Fig07_engineering_correction_factors', 'summary', ...
    'Origin_Fig07_engineering_correction_factors.csv', 'Engineering correction factors versus gap thickness.');
if ~isempty(T_allow)
    write_fig_table(T_allow, outDir, 'Origin_Fig07_allowable_gap_thickness.csv');
end

T = T_summary(:, {'delta_mm','Ecool_kWh','Eheat_kWh','Eabs_kWh'});
write_fig_table(T, outDir, 'Origin_Fig08_annual_energy_vs_delta.csv');
coverage = add_coverage(coverage, 'Fig08_annual_energy_vs_delta', 'summary', ...
    'Origin_Fig08_annual_energy_vs_delta.csv', 'Annual cooling, heating and absolute heat exchange.');

T = T_summary(:, {'delta_mm','Dgap_percent'});
write_fig_table(T, outDir, 'Origin_Fig09_Dgap_vs_delta.csv');
coverage = add_coverage(coverage, 'Fig09_Dgap_vs_delta', 'summary', ...
    'Origin_Fig09_Dgap_vs_delta.csv', 'Capacity loss versus gap thickness.');

T = T_summary(:, {'delta_mm','DeltaToutMean_C','DeltaToutMax_C'});
write_fig_table(T, outDir, 'Origin_Fig10_Tout_deviation_summary.csv');
coverage = add_coverage(coverage, 'Fig10_Tout_deviation_summary', 'summary', ...
    'Origin_Fig10_Tout_deviation_summary.csv', 'Outlet-temperature deviation summary.');

T = T_summary(:, {'delta_mm','TintJump_mean_C','TintJump_max_C'});
write_fig_table(T, outDir, 'Origin_Fig11_interface_jump_summary.csv');
coverage = add_coverage(coverage, 'Fig11_interface_jump_summary', 'summary', ...
    'Origin_Fig11_interface_jump_summary.csv', 'Interface temperature-jump summary.');

write_fig_table(T_limits, outDir, 'Origin_Fig12_interface_resistance_limit.csv');
coverage = add_coverage(coverage, 'Fig12_interface_resistance_limit', 'summary', ...
    'Origin_Fig12_interface_resistance_limit.csv', 'Interface resistance limit data.');
coverage = add_coverage(coverage, 'Fig12b_interface_resistance_wide_range', 'summary', ...
    'Origin_Fig12_interface_resistance_limit.csv', 'Same wide-range interface limit data including 20 mm.');

if ~isempty(T_Nx)
    write_fig_table(T_Nx, outDir, 'Origin_Fig13_Nx_independence.csv');
end
coverage = add_coverage(coverage, 'Fig13_Nx_independence', 'summary', ...
    'Origin_Fig13_Nx_independence.csv', 'Spatial discretization independence data.');

if ~isempty(T_dt)
    write_fig_table(T_dt, outDir, 'Origin_Fig14_dt_independence.csv');
end
coverage = add_coverage(coverage, 'Fig14_dt_independence', 'summary', ...
    'Origin_Fig14_dt_independence.csv', 'Time-step independence data.');

write_fig_table(factor.gapSummary, outDir, 'Origin_Fig15_factor_gap_thickness.csv');
coverage = add_coverage(coverage, 'Fig15_factor_gap_thickness', 'summary', ...
    'Origin_Fig15_factor_gap_thickness.csv', 'Gap-thickness factor analysis.');

write_fig_table(factor.contactSummary, outDir, 'Origin_Fig16_factor_contact_coefficient.csv');
coverage = add_coverage(coverage, 'Fig16_factor_contact_coefficient', 'summary', ...
    'Origin_Fig16_factor_contact_coefficient.csv', 'Contact-coefficient factor analysis.');

T = table(factor.contactRes{1}.day(:), factor.contactRes{1}.Tin(:), factor.contactRes{1}.Th(:), ...
    'VariableNames', {'day','Tin_C','Th_C'});
for k = 1:numel(factor.contactRes)
    ctag = number_tag(factor.contactChiList(k));
    T.(['Tout_chi_' ctag '_C']) = factor.contactRes{k}.Tout(:);
end
write_fig_table(T, outDir, 'Origin_Fig17_factor_contact_Tout_curves.csv');
coverage = add_coverage(coverage, 'Fig17_factor_contact_Tout_curves', 'timeseries', ...
    'Origin_Fig17_factor_contact_Tout_curves.csv', 'Outlet-temperature curves for contact-coefficient sweep.');

Tcoverage = cell2table(coverage, 'VariableNames', ...
    {'Figure','DataType','CsvFile','Note'});
write_fig_table(Tcoverage, outDir, 'Origin_figure_data_coverage.csv');

fid = fopen(fullfile(outDir, 'Origin_IMPORT_README.txt'), 'w');
if fid > 0
    fprintf(fid, 'Origin-ready data package for EAHE MATLAB figures.\n');
    fprintf(fid, 'Use Origin_figure_data_coverage.csv as the index.\n');
    fprintf(fid, 'Schematic and flowchart figures have no numeric source data.\n');
    fprintf(fid, 'All numeric MATLAB figures Fig00d-Fig17 are mapped to CSV files.\n');
    fprintf(fid, 'Current dt independence data use dt_h = [24 12 8 6 4 3 2], with 2 h as the routine reference.\n');
    fclose(fid);
end

fprintf('Origin figure data exported to: %s\n', outDir);

function T = readtable_if_exists(pathName)
    if exist(pathName, 'file') == 2
        T = readtable(pathName);
    else
        T = table();
    end
end

function tag = number_tag(x)
    tag = sprintf('%.6g', x);
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '.', 'p');
end

function write_fig_table(T, outDir, fileName)
    writetable(T, fullfile(outDir, fileName));
end

function C = add_coverage(C, figName, dataType, csvFile, note)
    C(end+1,:) = {figName, dataType, csvFile, note};
end
