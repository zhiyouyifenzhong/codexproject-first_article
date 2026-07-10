function export_origin_from_saved_results()
%EXPORT_ORIGIN_FROM_SAVED_RESULTS Export Origin-ready CSV files from saved v17 results.

rootDir = 'G:\codexproject\EAHE_airgap_physical_v17_review_ready_results';
matFile = fullfile(rootDir, 'EAHE_airgap_physical_v17_review_ready_results.mat');
outDir = fullfile(rootDir, 'Origin_ready_data');

if ~exist(matFile, 'file')
    error('Result MAT file not found: %s', matFile);
end

S = load(matFile, 'res', 'deltaList_mm', 'T_summary', 'T_Nx', 'T_dt');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

res = S.res;
deltaList_mm = S.deltaList_mm;

idx0 = find(abs(deltaList_mm - 0) < 1e-12, 1, 'first');
if isempty(idx0)
    idx0 = 1;
end
baseTout = res{idx0}.Tout;

T1 = table(res{idx0}.day(:), res{idx0}.Tin(:), res{idx0}.Th(:), ...
    'VariableNames', {'day','Tin_C','Undisturbed_soil_C'});
for i = 1:numel(res)
    tag = delta_tag(deltaList_mm(i));
    T1.(sprintf('Tout_%s_C', tag)) = res{i}.Tout(:);
end
writetable(T1, fullfile(outDir, 'Origin_Fig01_Tin_Th_Tout.csv'));

T2 = table(res{idx0}.day(:), 'VariableNames', {'day'});
for i = 1:numel(res)
    tag = delta_tag(deltaList_mm(i));
    T2.(sprintf('Delta_Tout_%s_C', tag)) = res{i}.Tout(:) - baseTout(:);
end
writetable(T2, fullfile(outDir, 'Origin_Fig02_Tout_deviation.csv'));

T3 = table(res{idx0}.day(:), 'VariableNames', {'day'});
for i = 1:numel(res)
    tag = delta_tag(deltaList_mm(i));
    T3.(sprintf('Qair_%s_W', tag)) = res{i}.Qair(:);
end
writetable(T3, fullfile(outDir, 'Origin_Fig03_Qair.csv'));

T4 = table(res{idx0}.day(:), 'VariableNames', {'day'});
for i = 1:numel(res)
    tag = delta_tag(deltaList_mm(i));
    T4.(sprintf('Tint_jump_mean_%s_C', tag)) = mean(abs(res{i}.TintJump), 1).';
end
writetable(T4, fullfile(outDir, 'Origin_Fig04_interface_jump.csv'));

writetable(S.T_summary, fullfile(outDir, 'Origin_Fig08_11_summary_vs_delta.csv'));

if exist(fullfile(rootDir, 'Table_03_interface_limit_validation.csv'), 'file')
    Tlimit = readtable(fullfile(rootDir, 'Table_03_interface_limit_validation.csv'));
    writetable(Tlimit, fullfile(outDir, 'Origin_Fig12_interface_limit.csv'));
end

if ~isempty(S.T_Nx)
    writetable(S.T_Nx, fullfile(outDir, 'Origin_Fig13_Nx_independence.csv'));
end
if ~isempty(S.T_dt)
    writetable(S.T_dt, fullfile(outDir, 'Origin_Fig14_dt_independence.csv'));
end

guideFile = fullfile(outDir, 'Origin_import_guide.txt');
fid = fopen(guideFile, 'w');
fprintf(fid, 'Origin import guide for EAHE air-gap model\n');
fprintf(fid, '1. Import each CSV as a worksheet with the first row as long names.\n');
fprintf(fid, '2. Use day or delta_mm as X; plot remaining numeric columns as Y.\n');
fprintf(fid, '3. Recommended main figures: Fig01, Fig02, Fig03, Fig04, Fig08-Fig14.\n');
fprintf(fid, '4. Export final Origin figures as PDF vector plus 600 dpi PNG/TIFF.\n');
fprintf(fid, '5. Keep Fig05 energy residual and Fig13-Fig14 as validation or supplementary figures.\n');
fclose(fid);

fprintf('Origin-ready files written to: %s\n', outDir);
end

function tag = delta_tag(delta_mm)
tag = sprintf('d%gmm', delta_mm);
tag = regexprep(tag, '\.', 'p');
tag = regexprep(tag, '[^A-Za-z0-9_]', '_');
end
