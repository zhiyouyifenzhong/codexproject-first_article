% Baseline run for the first-version EAHE RC model.
% Outputs:
% - baseline_result.mat
% - outlet temperature, heat transfer rate, degradation metrics

clear; clc;

result = run_eahe_simulation();

save('baseline_result.mat', 'result');

plot_eahe_summary(result);

fprintf('\nBaseline complete.\n');
fprintf('Final outlet temperature: %.2f degC\n', result.Tout(end));
fprintf('Final heat transfer rate: %.1f W\n', result.Q(end));
if ~isempty(result.degradation.day)
    fprintf('Day-1 mean Q: %.1f W\n', result.degradation.Q_day_mean(1));
    fprintf('Last-day mean Q: %.1f W\n', result.degradation.Q_day_mean(end));
    fprintf('Last-day Q degradation ratio: %.3f\n', result.degradation.eta_Q_day(end));
end
