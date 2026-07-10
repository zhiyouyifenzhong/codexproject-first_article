% Check the undisturbed layered-soil temperature phase used by the EAHE run.
% This verifies that the operation start time is consistent with the intended
% summer cooling condition.

clear; clc;

result = run_eahe_simulation(struct('t_end', 24 * 3600, ...
    'snapshot_times', [0, 12, 24] * 3600));

param = result.param;
soil_pre = result.soil_pre;

checkTimes = [0, 12, 24, 72, 168] * 3600;

figure('Name', 'Undisturbed soil temperature profiles during EAHE operation');
hold on;
for i = 1:numel(checkTimes)
    t = checkTimes(i);
    Tprof = local_get_undisturbed_profile(t, soil_pre, param);
    plot(Tprof, soil_pre.z, 'LineWidth', 1.3, ...
        'DisplayName', sprintf('t = %.0f h', t/3600));
end

yline(param.z_pipe, 'k-', 'Pipe center', 'LabelHorizontalAlignment', 'left');
yline(param.z_layer_bot(1), 'k--', 'Layer 1/2', 'LabelHorizontalAlignment', 'left');
yline(param.z_layer_bot(2), 'k--', 'Layer 2/3', 'LabelHorizontalAlignment', 'left');

set(gca, 'YDir', 'reverse');
xlabel('Undisturbed soil temperature / degC');
ylabel('Depth / m');
title(sprintf('Soil annual phase: operation starts at day %.1f', ...
    param.operation_start_day));
legend('Location', 'best');
grid on;

function Tprof = local_get_undisturbed_profile(t, soil_pre, param)
    tq = mod(t + param.soil_time_offset, param.year);
    tt = soil_pre.time(:);
    TT = soil_pre.T;
    if tt(end) < param.year
        tt = [tt; param.year];
        TT = [TT, TT(:, 1)];
    end
    Tprof = interp1(tt, TT.', tq, 'linear', 'extrap').';
end
