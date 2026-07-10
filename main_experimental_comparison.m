% Compare EAHE predictions with digitized experimental outlet-temperature
% time series. Populate experimental_comparison_timeseries.csv first.

clear; clc; close all;

dataFile = 'experimental_comparison_timeseries.csv';
if ~exist(dataFile, 'file')
    error('Missing %s. Fill the template before running this comparison.', dataFile);
end

T = readtable(dataFile, 'TextType', 'string');
required = ["StudyID", "CaseID", "time_h", "Tin_degC", "Tout_exp_degC"];
for k = 1:numel(required)
    if ~ismember(required(k), string(T.Properties.VariableNames))
        error('Missing required column: %s', required(k));
    end
end

if ~ismember("Tout_model_degC", string(T.Properties.VariableNames))
    T.Tout_model_degC = nan(height(T), 1);
end

caseKeys = unique(T.StudyID + "|" + T.CaseID, 'stable');
summary = table(strings(numel(caseKeys),1), strings(numel(caseKeys),1), ...
    zeros(numel(caseKeys),1), zeros(numel(caseKeys),1), zeros(numel(caseKeys),1), ...
    'VariableNames', {'StudyID','CaseID','N','Tout_RMSE_K','Tout_MBE_K'});

figure('Name', 'Experimental comparison - outlet temperature');
tiledlayout('flow');

for c = 1:numel(caseKeys)
    parts = split(caseKeys(c), "|");
    studyID = parts(1);
    caseID = parts(2);
    id = T.StudyID == studyID & T.CaseID == caseID;
    Tc = T(id, :);

    if all(isnan(Tc.Tout_model_degC))
        warning('Skipping %s / %s because Tout_model_degC is empty.', studyID, caseID);
        continue
    end

    err = Tc.Tout_model_degC - Tc.Tout_exp_degC;
    summary.StudyID(c) = studyID;
    summary.CaseID(c) = caseID;
    summary.N(c) = numel(err);
    summary.Tout_RMSE_K(c) = sqrt(mean(err.^2, 'omitnan'));
    summary.Tout_MBE_K(c) = mean(err, 'omitnan');

    nexttile;
    plot(Tc.time_h, Tc.Tout_exp_degC, 'ko', 'MarkerSize', 4); hold on;
    plot(Tc.time_h, Tc.Tout_model_degC, 'r-', 'LineWidth', 1.2);
    xlabel('Time / h');
    ylabel('Outlet temperature / degC');
    title(studyID + " / " + caseID, 'Interpreter', 'none');
    legend('Experiment', 'Model', 'Location', 'best');
    grid on;
end

summary = summary(summary.N > 0, :);
disp(summary);
writetable(summary, 'experimental_comparison_summary.csv');
save_all_open_figures(fullfile('figures', 'experimental_comparison'), 'experimental_comparison');
