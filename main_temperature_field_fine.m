% High-resolution near-pipe temperature contours for paper-quality figures.
% Uses a finer circumferential-radial RC grid than the default baseline.

clear; clc;

overrides.Ntheta = 16;
overrides.Nr = 10;
overrides.snapshot_times = [0, 12, 24, 72, 168] * 3600;

result = run_eahe_simulation(overrides);
save('temperature_field_fine_result.mat', 'result');

for k = 1:numel(result.snapshots.time)
    plot_temperature_contour(result, k, round(result.param.Nx_pipe / 2));
end
