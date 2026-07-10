function plot_eahe_summary(result)
%PLOT_EAHE_SUMMARY Plot key EAHE transient and degradation results.

    tHour = result.time / 3600;

    figure('Name', 'EAHE inlet and outlet temperature');
    iPlot = 2:numel(tHour);
    plot(tHour(iPlot), result.Tin(iPlot), 'k--', 'LineWidth', 1.2); hold on;
    plot(tHour(iPlot), result.Tout(iPlot), 'b-', 'LineWidth', 1.5);
    xlabel('Time / h');
    ylabel('Temperature / degC');
    legend('Inlet air', 'Outlet air', 'Location', 'best');
    grid on;

    figure('Name', 'EAHE heat transfer rate');
    plot(tHour(iPlot), result.Q(iPlot), 'r-', 'LineWidth', 1.5);
    xlabel('Time / h');
    ylabel('Heat transfer rate / W');
    grid on;

    figure('Name', 'Near-pipe soil thermal accumulation');
    plot(tHour, result.Tsoil_near_mid_mean - result.Tundist_pipe, 'm-', 'LineWidth', 1.5); hold on;
    plot(tHour, result.Tsoil_near_mid_top - result.Tundist_pipe, 'b--', 'LineWidth', 1.1);
    plot(tHour, result.Tsoil_near_mid_bottom - result.Tundist_pipe, 'r--', 'LineWidth', 1.1);
    xlabel('Time / h');
    ylabel('Near-pipe soil temperature rise / K');
    legend('Mean', 'Top sector', 'Bottom sector', 'Location', 'best');
    grid on;

    if isfield(result, 'degradation') && ~isempty(result.degradation.day)
        figure('Name', 'Daily degradation metrics');
        yyaxis left
        plot(result.degradation.day, result.degradation.eta_Q_day, 'ro-', 'LineWidth', 1.3);
        ylabel('Q day mean / day-1 value');
        yyaxis right
        plot(result.degradation.day, result.degradation.near_soil_rise_day_mean, 'bs-', 'LineWidth', 1.3);
        ylabel('Mean near-pipe soil rise / K');
        xlabel('Operation day');
        grid on;
    end
end
