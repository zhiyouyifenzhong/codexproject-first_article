function plot_temperature_contour(result, snapshotIndex, pipeSegment)
%PLOT_TEMPERATURE_CONTOUR Plot near-pipe soil temperature contour.
%   plot_temperature_contour(result, snapshotIndex)
%   plot_temperature_contour(result, snapshotIndex, pipeSegment)
%
%   snapshotIndex selects result.snapshots.X(:, snapshotIndex).
%   pipeSegment defaults to the middle pipe segment.

    param = result.param;
    geom = result.geom;

    if nargin < 2 || isempty(snapshotIndex)
        snapshotIndex = numel(result.snapshots.time);
    end
    if nargin < 3 || isempty(pipeSegment)
        pipeSegment = round(param.Nx_pipe / 2);
    end

    if ~isfield(result, 'snapshots') || isempty(result.snapshots.X)
        error('No snapshots are available. Set param.snapshot_times before simulation.');
    end

    X = result.snapshots.X(:, snapshotIndex);
    tHour = result.snapshots.time(snapshotIndex) / 3600;

    Ts = zeros(param.Ntheta, param.Nr);

    for m = 1:param.Ntheta
        for r = 1:param.Nr
            Ts(m, r) = X(idx_Ts(pipeSegment, m, r, param));
        end
    end

    thetaExt = [geom.theta - 2*pi; geom.theta; geom.theta + 2*pi];
    TsExt = [Ts; Ts; Ts];
    rExt = [param.r_o; geom.r_centers; param.r_soil_max];
    TsR = [TsExt(:, 1), TsExt, TsExt(:, end)];

    thetaFine = linspace(0, 2*pi, 241);
    rFine = linspace(param.r_o, param.r_soil_max, 160);
    [ThetaQ, RQ] = meshgrid(thetaFine, rFine);
    try
        Tq = interp2(thetaExt, rExt, TsR.', ThetaQ, RQ, 'makima');
    catch
        Tq = interp2(thetaExt, rExt, TsR.', ThetaQ, RQ, 'linear');
    end

    Xq = RQ .* cos(ThetaQ);
    Zq = param.z_pipe + RQ .* sin(ThetaQ);
    Tq(Zq < 0) = nan;

    figure('Name', sprintf('Temperature contour %.1f h', tHour));
    contourf(Xq, Zq, Tq, 30, 'LineColor', 'none');
    colorbar;
    hold on;

    th = linspace(0, 2*pi, 200);
    plot(param.r_o * cos(th), param.z_pipe + param.r_o * sin(th), ...
        'k-', 'LineWidth', 2);

    yline(param.z_layer_bot(1), 'k--', 'Layer 1/2', 'LabelHorizontalAlignment', 'left');
    yline(param.z_layer_bot(2), 'k--', 'Layer 2/3', 'LabelHorizontalAlignment', 'left');

    set(gca, 'YDir', 'reverse');
    axis equal tight;
    xlabel('Horizontal distance from pipe center / m');
    ylabel('Depth / m');
    title(sprintf('Near-pipe soil temperature, t = %.1f h, segment = %d', ...
        tHour, pipeSegment));
end

function is = idx_Ts(i, m, r, param)
    is = (i - 1) * param.nNode_seg + 2 + (m - 1) * param.Nr + r;
end
