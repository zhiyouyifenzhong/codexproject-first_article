%% run_vaz_minaei_params_matlab_digitized_comparison.m
% Annual MATLAB Minaei-G validation with the Vaz/Minaei Fig. 4 parameters.
%
% The script runs a standalone MATLAB implementation using the extracted
% Minaei validation parameters, then compares the outlet temperature against
% the digitized Fig. 4 curves produced from the user-provided image.

function run_vaz_minaei_params_matlab_digitized_comparison()
    close all; clc;

    rootDir = fileparts(mfilename('fullpath'));
    if isempty(rootDir); rootDir = pwd; end

    digitizedFile = fullfile(rootDir, 'image_digitization_1783561607343', ...
        'digitized_1783561607343_daily.csv');
    assert(exist(digitizedFile, 'file') == 2, 'Missing digitized CSV: %s', digitizedFile);

    outDir = fullfile(rootDir, 'MATLAB_Vaz_Minaei_params_digitized_validation');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    p = vazMinaeiParams();
    fprintf('Running Vaz/Minaei annual MATLAB validation...\n');
    fprintf('L = %.2f m, Di = %.3f m, H = %.2f m, velocity = %.2f m/s\n', ...
        p.L, 2*p.rpi, p.H, p.air_velocity);

    sim = simulateAnnualMinaeiG(p);
    D = readtable(digitizedFile);

    tDay = (0:365)';
    ToutModel = interp1(sim.day(:), sim.Tout(:), tDay, 'linear', 'extrap');
    TinModel = inletTemperatureVaz(p, tDay*86400);
    ThModel = soilTemperatureAtDepthVaz(p, p.H, tDay*86400);

    pointTable = table(tDay, TinModel(:), ThModel(:), ToutModel(:), ...
        D.present_study_black_C(:), ...
        D.vaz_full_numerical_red_dashed_C(:), ...
        D.brum_simplified_red_solid_C(:), ...
        D.vaz_fitted_experimental_green_smooth_C(:), ...
        D.vaz_experimental_green_raw_C(:), ...
        ToutModel(:) - D.present_study_black_C(:), ...
        ToutModel(:) - D.vaz_full_numerical_red_dashed_C(:), ...
        ToutModel(:) - D.brum_simplified_red_solid_C(:), ...
        ToutModel(:) - D.vaz_fitted_experimental_green_smooth_C(:), ...
        ToutModel(:) - D.vaz_experimental_green_raw_C(:), ...
        'VariableNames', {'time_day','Tin_MATLAB_C','Tsoil_undisturbed_MATLAB_C', ...
        'Tout_MATLAB_VazParams_C','digitized_present_study_black_C', ...
        'digitized_Vaz_full_numerical_red_dashed_C', ...
        'digitized_Brum_simplified_red_solid_C', ...
        'digitized_fitted_experimental_green_C', ...
        'digitized_raw_experimental_green_C', ...
        'MATLAB_minus_present_study_C', ...
        'MATLAB_minus_Vaz_full_numerical_C', ...
        'MATLAB_minus_Brum_simplified_C', ...
        'MATLAB_minus_fitted_experiment_C', ...
        'MATLAB_minus_raw_experiment_C'});

    comparisons = {
        'Present study black', 'MATLAB_minus_present_study_C';
        'Vaz full numerical red dashed', 'MATLAB_minus_Vaz_full_numerical_C';
        'Brum simplified red solid', 'MATLAB_minus_Brum_simplified_C';
        'Fitted experimental green', 'MATLAB_minus_fitted_experiment_C';
        'Raw experimental green', 'MATLAB_minus_raw_experiment_C';
    };
    metricRows = cell(size(comparisons,1), 9);
    for i = 1:size(comparisons,1)
        err = pointTable.(comparisons{i,2});
        stats = errorStatsLocal(err);
        metricRows(i,:) = {string(comparisons{i,1}), stats.n, stats.rmse, ...
            stats.mae, stats.bias, stats.maxAbs, prctile(abs(err),95), ...
            mean(pointTable.Tout_MATLAB_VazParams_C, 'omitnan'), ...
            mean(pointTable.(targetColumnForComparison(comparisons{i,2})), 'omitnan')};
    end
    metricTable = cell2table(metricRows, 'VariableNames', ...
        {'comparison_target','n_points','RMSE_C','MAE_C','bias_MATLAB_minus_target_C', ...
        'max_abs_error_C','p95_abs_error_C','MATLAB_mean_C','target_mean_C'});

    parameterTable = struct2ParameterTable(p);

    writetable(pointTable, fullfile(outDir, 'Vaz_Minaei_params_MATLAB_vs_digitized_points.csv'));
    writetable(metricTable, fullfile(outDir, 'Vaz_Minaei_params_MATLAB_vs_digitized_metrics.csv'));
    writetable(parameterTable, fullfile(outDir, 'Vaz_Minaei_params_used.csv'));
    save(fullfile(outDir, 'Vaz_Minaei_params_MATLAB_simulation.mat'), 'p', 'sim', ...
        'pointTable', 'metricTable');

    plotComparison(outDir, pointTable);
    plotResiduals(outDir, pointTable);
    writeReport(outDir, p, metricTable, digitizedFile);

    disp(metricTable);
    fprintf('Done. Outputs written to: %s\n', outDir);
end

function p = vazMinaeiParams()
    p.L = 25.77;
    p.Nx = 80;
    p.rpi = 0.110/2;
    p.pipe_thickness = 2.5e-3; % Table 2 is missing; Table 3 reports 2.5 mm.
    p.rpo = p.rpi + p.pipe_thickness;
    p.H = 1.6;

    p.rho_f = 1.225;
    p.cp_f = 1006.0;
    p.k_air = 0.0242;
    p.mu_f = 1.81e-5; % not tabulated in Minaei Table 1; standard air value.
    p.air_velocity = 3.3;
    p.Vdot = p.air_velocity*pi*p.rpi^2;
    p.mdot = p.rho_f*p.Vdot;

    p.kp = 0.40;     % PVC-like pipe assumption; not tabulated for validation case.
    p.rho_p = 1400;  % PVC-like pipe assumption.
    p.cp_p = 900;    % PVC-like pipe assumption.

    p.ks = 2.1;
    p.rho_s = 1800.0;
    p.cp_s = 1780.0;
    p.alpha_s = p.ks/(p.rho_s*p.cp_s);

    p.P = 365*24*3600;
    p.nYears = 2;
    p.tEnd = p.nYears*p.P;
    p.dt = 6*3600;
    p.picardMax = 12;
    p.picardTol = 1e-5;
    p.picardRelax = 0.65;
    p.gQuadN = 900;
    p.gQuadBmax = 160.0;

    p.Tm = 18.55;
    p.Asurf = 6.28;
    p.surface_phase_rad = 26.4;
    p.Tin_mean = 20.34;
    p.Tin_amp = 5.66;
    p.inlet_phase_rad = -5.30;
end

function sim = simulateAnnualMinaeiG(p)
    t = (0:p.dt:p.tEnd)';
    Nt = numel(t);
    Nx = p.Nx;
    dx = p.L/Nx;

    Tin = inletTemperatureVaz(p, t);
    Th = soilTemperatureAtDepthVaz(p, p.H, t);
    [Rp1, Rdelta, rResponse] = radialNetwork(p);
    G = minaeiGKernel(p, rResponse, Nt);
    A = buildAirPipeMatrix(p, Rp1, Rdelta);

    Tf = zeros(Nx,Nt);
    Tp = zeros(Nx,Nt);
    Tg = zeros(Nx,Nt);
    qg = zeros(Nx,Nt);
    Tf(:,1) = Th(1);
    Tp(:,1) = Th(1);
    Tg(:,1) = Th(1);

    Cf = p.rho_f*pi*p.rpi^2*p.cp_f;
    Cp = p.rho_p*pi*(p.rpo^2-p.rpi^2)*p.cp_p;
    Adv = p.mdot*p.cp_f/dx;

    for m = 2:Nt
        qTrial = qg(:,m-1);
        for it = 1:p.picardMax
            TgNow = soilBoundaryFromG(p, qg, qTrial, m, G, Th(m));
            b = zeros(2*Nx,1);
            b(1:Nx) = Cf/p.dt*Tf(:,m-1);
            b(1) = b(1) + Adv*Tin(m);
            b(Nx+1:end) = Cp/p.dt*Tp(:,m-1) + TgNow/Rdelta;
            x = A\b;
            TpNew = x(Nx+1:end);
            qNew = (TpNew - TgNow)/Rdelta;
            rel = norm(qNew-qTrial)/max(norm(qNew),1);
            qTrial = p.picardRelax*qNew + (1-p.picardRelax)*qTrial;
            if rel < p.picardTol
                break;
            end
        end
        Tg(:,m) = soilBoundaryFromG(p, qg, qTrial, m, G, Th(m));
        b = zeros(2*Nx,1);
        b(1:Nx) = Cf/p.dt*Tf(:,m-1);
        b(1) = b(1) + Adv*Tin(m);
        b(Nx+1:end) = Cp/p.dt*Tp(:,m-1) + Tg(:,m)/Rdelta;
        x = A\b;
        Tf(:,m) = x(1:Nx);
        Tp(:,m) = x(Nx+1:end);
        qg(:,m) = (Tp(:,m)-Tg(:,m))/Rdelta;
    end

    startEval = p.tEnd - p.P;
    idx = find(t >= startEval & t <= p.tEnd);
    tEval = t(idx) - startEval;
    sim.t_s = tEval;
    sim.day = tEval/86400;
    sim.Tin = Tin(idx);
    sim.Th = Th(idx);
    sim.Tout = Tf(end,idx)';
    sim.Qair = p.mdot*p.cp_f*(sim.Tin - sim.Tout);
end

function Tin = inletTemperatureVaz(p, t)
    Tin = p.Tin_mean + p.Tin_amp*sin(2*pi*t/p.P + p.inlet_phase_rad);
end

function T = soilTemperatureAtDepthVaz(p, h, t)
    beta = sqrt(pi/(p.P*p.alpha_s));
    T = p.Tm + p.Asurf*exp(-h*beta).*sin(2*pi*t/p.P + p.surface_phase_rad - h*beta);
end

function [Rp1, Rdelta, rResponse] = radialNetwork(p)
    hi = internalH(p);
    re = sqrt((p.rpi^2+p.rpo^2)/2);
    Rconv = 1/(2*pi*p.rpi*hi);
    RcondInner = log(re/p.rpi)/(2*pi*p.kp);
    RcondOuter = log(p.rpo/re)/(2*pi*p.kp);
    Rp1 = Rconv + RcondInner;
    Rdelta = RcondOuter;
    rResponse = p.rpo;
end

function hi = internalH(p)
    d = 2*p.rpi;
    Re = p.rho_f*p.air_velocity*d/p.mu_f;
    Pr = p.cp_f*p.mu_f/p.k_air;
    if Re < 2300
        Nu = 3.66;
    else
        f = (0.79*log(Re)-1.64)^(-2);
        Nu = ((f/8)*(Re-1000)*Pr)/(1+12.7*sqrt(f/8)*(Pr^(2/3)-1));
    end
    hi = Nu*p.k_air/d;
end

function A = buildAirPipeMatrix(p, Rp1, Rdelta)
    Nx = p.Nx;
    dx = p.L/Nx;
    Cf = p.rho_f*pi*p.rpi^2*p.cp_f;
    Cp = p.rho_p*pi*(p.rpo^2-p.rpi^2)*p.cp_p;
    Adv = p.mdot*p.cp_f/dx;
    A = sparse(2*Nx,2*Nx);
    for i = 1:Nx
        A(i,i) = Cf/p.dt + Adv + 1/Rp1;
        A(i,Nx+i) = -1/Rp1;
        if i > 1
            A(i,i-1) = -Adv;
        end
        row = Nx+i;
        A(row,row) = Cp/p.dt + 1/Rp1 + 1/Rdelta;
        A(row,i) = -1/Rp1;
    end
end

function G = minaeiGKernel(p, r, Nt)
    beta = logspace(-6, log10(p.gQuadBmax), p.gQuadN);
    J1 = besselj(1,beta);
    Y1 = bessely(1,beta);
    den = beta.^2.*(J1.^2+Y1.^2);
    shape = -2./(pi*beta);
    G = zeros(Nt,1);
    for k = 1:Nt
        tau = (k-1)*p.dt;
        if tau <= 0
            tau = 0.5*p.dt;
        end
        Fo = p.alpha_s*tau/(r^2);
        integrand = (exp(-(beta.^2)*Fo)-1).*shape./den;
        integrand(~isfinite(integrand)) = 0;
        G(k) = max(trapz(beta, integrand)/(pi^2), 0);
    end
end

function Tg = soilBoundaryFromG(p, qg, qTrial, m, G, ThNow)
    qLocal = qg(:,1:m);
    qLocal(:,m) = qTrial;
    dq = zeros(size(qLocal));
    dq(:,1) = qLocal(:,1);
    if m > 1
        dq(:,2:end) = qLocal(:,2:end) - qLocal(:,1:end-1);
    end
    weights = G(m:-1:1);
    Tg = ThNow + dq*weights/p.ks;
end

function stats = errorStatsLocal(err)
    err = err(:);
    err = err(isfinite(err));
    stats.n = numel(err);
    stats.rmse = sqrt(mean(err.^2));
    stats.mae = mean(abs(err));
    stats.bias = mean(err);
    stats.maxAbs = max(abs(err));
end

function col = targetColumnForComparison(errCol)
    switch errCol
        case 'MATLAB_minus_present_study_C'
            col = 'digitized_present_study_black_C';
        case 'MATLAB_minus_Vaz_full_numerical_C'
            col = 'digitized_Vaz_full_numerical_red_dashed_C';
        case 'MATLAB_minus_Brum_simplified_C'
            col = 'digitized_Brum_simplified_red_solid_C';
        case 'MATLAB_minus_fitted_experiment_C'
            col = 'digitized_fitted_experimental_green_C';
        otherwise
            col = 'digitized_raw_experimental_green_C';
    end
end

function T = struct2ParameterTable(p)
    names = fieldnames(p);
    vals = cell(numel(names),1);
    for i = 1:numel(names)
        v = p.(names{i});
        if isnumeric(v) && isscalar(v)
            vals{i} = v;
        else
            vals{i} = string(mat2str(v));
        end
    end
    T = table(string(names), vals, 'VariableNames', {'parameter','value'});
end

function plotComparison(outDir, T)
    fig = figure('Color','w','Position',[80 80 1180 620]);
    plot(T.time_day, T.digitized_raw_experimental_green_C, '-', 'Color', [0.20 0.70 0.25 0.45], 'LineWidth', 0.8); hold on;
    plot(T.time_day, T.digitized_fitted_experimental_green_C, '-.', 'Color', [0.00 0.55 0.15], 'LineWidth', 1.1);
    plot(T.time_day, T.digitized_present_study_black_C, 'k-', 'LineWidth', 1.5);
    plot(T.time_day, T.digitized_Vaz_full_numerical_red_dashed_C, '--', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.1);
    plot(T.time_day, T.digitized_Brum_simplified_red_solid_C, '-', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.1);
    plot(T.time_day, T.Tout_MATLAB_VazParams_C, '-', 'Color', [0.05 0.25 0.85], 'LineWidth', 1.8);
    grid on; box on;
    xlim([0 365]); ylim([4 28]);
    xlabel('Time (day)');
    ylabel('Temperature (degC)');
    title('Vaz/Minaei parameter MATLAB model vs digitized Fig. 4');
    legend({'Digitized raw experiment','Digitized fitted experiment','Digitized present study', ...
        'Digitized Vaz full numerical','Digitized Brum simplified','MATLAB modified to Vaz/Minaei params'}, ...
        'Location','southwest');
    saveas(fig, fullfile(outDir, 'Fig_MATLAB_VazParams_vs_digitized_curves.png'));
    saveas(fig, fullfile(outDir, 'Fig_MATLAB_VazParams_vs_digitized_curves.pdf'));
    close(fig);
end

function plotResiduals(outDir, T)
    fig = figure('Color','w','Position',[80 80 1180 520]);
    plot(T.time_day, T.MATLAB_minus_present_study_C, 'k-', 'LineWidth', 1.3); hold on;
    plot(T.time_day, T.MATLAB_minus_Vaz_full_numerical_C, '--', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.1);
    plot(T.time_day, T.MATLAB_minus_Brum_simplified_C, '-', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.1);
    plot(T.time_day, T.MATLAB_minus_fitted_experiment_C, '-.', 'Color', [0.00 0.55 0.15], 'LineWidth', 1.1);
    yline(0, ':', 'Color', [0.4 0.4 0.4]);
    grid on; box on;
    xlim([0 365]);
    xlabel('Time (day)');
    ylabel('MATLAB - digitized target (degC)');
    title('Residuals after matching Vaz/Minaei parameters');
    legend({'Present study','Vaz full numerical','Brum simplified','Fitted experiment'}, ...
        'Location','best');
    saveas(fig, fullfile(outDir, 'Fig_MATLAB_VazParams_residuals.png'));
    saveas(fig, fullfile(outDir, 'Fig_MATLAB_VazParams_residuals.pdf'));
    close(fig);
end

function writeReport(outDir, p, M, digitizedFile)
    reportFile = fullfile(outDir, 'Vaz_Minaei_params_digitized_validation_report.md');
    fid = fopen(reportFile, 'w');
    assert(fid > 0, 'Cannot open report: %s', reportFile);
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '# Vaz/Minaei Parameter MATLAB vs Digitized Fig. 4 Validation\n\n');
    fprintf(fid, 'Digitized source: `%s`\n\n', digitizedFile);
    fprintf(fid, 'The MATLAB model was modified to use the extracted Vaz/Minaei validation parameters: L = %.2f m, Di = %.3f m, H = %.2f m, air velocity = %.2f m/s, soil k = %.2f W/(m K), rho_s = %.0f kg/m3, cp_s = %.0f J/(kg K).\n\n', ...
        p.L, 2*p.rpi, p.H, p.air_velocity, p.ks, p.rho_s, p.cp_s);
    fprintf(fid, 'Boundary functions use the extracted annual sinusoidal phases directly: Tin = %.2f + %.2f sin(2*pi*t/P %.2f), surface T = %.2f + %.2f sin(2*pi*t/P + %.2f).\n\n', ...
        p.Tin_mean, p.Tin_amp, p.inlet_phase_rad, p.Tm, p.Asurf, p.surface_phase_rad);
    fprintf(fid, 'Assumptions: pipe thickness is set to 2.5 mm because Minaei validation Table 2 omits it, while Table 3 reports 2.5 mm; pipe material is represented with PVC-like k = %.2f W/(m K), rho = %.0f kg/m3, cp = %.0f J/(kg K).\n\n', ...
        p.kp, p.rho_p, p.cp_p);

    fprintf(fid, '## Error metrics\n\n');
    fprintf(fid, '| Target | n | RMSE (degC) | MAE (degC) | Bias MATLAB-target (degC) | Max abs (degC) | p95 abs (degC) |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(M)
        fprintf(fid, '| %s | %.0f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
            M.comparison_target(i), M.n_points(i), M.RMSE_C(i), M.MAE_C(i), ...
            M.bias_MATLAB_minus_target_C(i), M.max_abs_error_C(i), M.p95_abs_error_C(i));
    end

    fprintf(fid, '\n## Interpretation\n\n');
    fprintf(fid, 'The central reproducibility check is MATLAB vs the digitized black Present Study curve. Comparisons to the red and green curves are included for context because those curves are external numerical or experimental references rather than the modified MATLAB model itself.\n');
end
