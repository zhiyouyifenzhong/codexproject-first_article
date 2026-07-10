%% run_matlab_sharan_50m_minaeig_validation.m
% Sharan and Jadhav 50 m single-pass EAHE validation using a standalone
% MATLAB implementation of the Minaei G-function RC model.
%
% Outputs:
%   MATLAB_Sharan_50m_MinaeiG_validation/
%     Sharan_MATLAB_MinaeiG_points.csv
%     Sharan_MATLAB_MinaeiG_metrics.csv
%     Sharan_MATLAB_MinaeiG_energy.csv
%     Sharan_MATLAB_MinaeiG_validation_report.md
%
% The script uses only the Minaei G-function response kernel. ILS/FLS kernels
% are not evaluated.

function run_matlab_sharan_50m_minaeig_validation()
    close all; clc;
    outDir = fullfile(pwd, 'MATLAB_Sharan_50m_MinaeiG_validation');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    p = sharanParams();
    cfd = readCFDPointsIfAvailable();

    cases = buildSharanCases();
    allPoints = table();
    metricRows = table();
    energyRows = table();

    for i = 1:numel(cases)
        c = cases(i);
        fprintf('Running MATLAB Minaei-G case: %s\n', c.name);
        sim = simulateMinaeiGCase(p, c.t_s, c.Tin_C, c.Tsoil_C);

        T25_model = interp1(sim.t_s, sim.T25_C, c.t_s, 'linear');
        Tout_model = interp1(sim.t_s, sim.Tout_C, c.t_s, 'linear');
        Q_model_W = p.mdot*p.cp_f*(c.Tin_C - Tout_model);
        Q_exp_W = p.mdot*p.cp_f*(c.Tin_C - c.Tout_exp_C);

        cfdCase = table();
        if ~isempty(cfd)
            cfdCase = cfd(strcmp(string(cfd.case_name), c.cfd_name), :);
        end
        if ~isempty(cfdCase)
            cfd_T25 = cfdCase.Tmid_sim_C;
            cfd_Tout = cfdCase.Tout_sim_C;
            Q_cfd_W = p.mdot*p.cp_f*(c.Tin_C - cfd_Tout);
        else
            cfd_T25 = NaN(size(c.t_s));
            cfd_Tout = NaN(size(c.t_s));
            Q_cfd_W = NaN(size(c.t_s));
        end

        thisPoints = table( ...
            repmat(string(c.name), numel(c.t_s), 1), c.t_s/3600, c.Tin_C, c.Tsoil_C, ...
            c.T25_exp_C, c.Tout_exp_C, T25_model, Tout_model, cfd_T25, cfd_Tout, ...
            T25_model-c.T25_exp_C, Tout_model-c.Tout_exp_C, cfd_T25-c.T25_exp_C, cfd_Tout-c.Tout_exp_C, ...
            'VariableNames', {'case_name','time_h','Tin_exp_C','Tsoil_C','T25_exp_C','Tout_exp_C', ...
            'T25_MATLAB_MinaeiG_C','Tout_MATLAB_MinaeiG_C','T25_CFD_kepsilon_C','Tout_CFD_kepsilon_C', ...
            'T25_MATLAB_minus_exp_C','Tout_MATLAB_minus_exp_C','T25_CFD_minus_exp_C','Tout_CFD_minus_exp_C'});
        allPoints = [allPoints; thisPoints]; %#ok<AGROW>

        metricRows = [metricRows; metricRow(c.name, "MATLAB_MinaeiG_vs_exp", "T25", T25_model-c.T25_exp_C)]; %#ok<AGROW>
        metricRows = [metricRows; metricRow(c.name, "MATLAB_MinaeiG_vs_exp", "Tout", Tout_model-c.Tout_exp_C)]; %#ok<AGROW>
        if ~isempty(cfdCase)
            metricRows = [metricRows; metricRow(c.name, "CFD_kepsilon_vs_exp", "T25", cfd_T25-c.T25_exp_C)]; %#ok<AGROW>
            metricRows = [metricRows; metricRow(c.name, "CFD_kepsilon_vs_exp", "Tout", cfd_Tout-c.Tout_exp_C)]; %#ok<AGROW>
            metricRows = [metricRows; metricRow(c.name, "MATLAB_MinaeiG_vs_CFD_kepsilon", "T25", T25_model-cfd_T25)]; %#ok<AGROW>
            metricRows = [metricRows; metricRow(c.name, "MATLAB_MinaeiG_vs_CFD_kepsilon", "Tout", Tout_model-cfd_Tout)]; %#ok<AGROW>
        end

        E_exp = trapz(c.t_s, abs(Q_exp_W))/3.6e6;
        E_model = trapz(c.t_s, abs(Q_model_W))/3.6e6;
        E_cfd = trapz(c.t_s, abs(Q_cfd_W))/3.6e6;
        energyRows = [energyRows; table(string(c.name), E_exp, E_model, E_cfd, ...
            100*(E_model-E_exp)/max(E_exp, eps), 100*(E_cfd-E_exp)/max(E_exp, eps), ...
            'VariableNames', {'case_name','E_exp_kWh','E_MATLAB_MinaeiG_kWh','E_CFD_kepsilon_kWh', ...
            'MATLAB_minus_exp_percent','CFD_minus_exp_percent'})]; %#ok<AGROW>

        plotSharanCase(outDir, c, T25_model, Tout_model, cfd_T25, cfd_Tout);
    end

    writetable(allPoints, fullfile(outDir, 'Sharan_MATLAB_MinaeiG_points.csv'));
    writetable(metricRows, fullfile(outDir, 'Sharan_MATLAB_MinaeiG_metrics.csv'));
    writetable(energyRows, fullfile(outDir, 'Sharan_MATLAB_MinaeiG_energy.csv'));
    writeSharanReport(outDir, metricRows, energyRows);
    fprintf('Wrote outputs to %s\n', outDir);
end

function p = sharanParams()
    p.L = 50.0;
    p.Nx = 80;
    p.rpi = 0.050;
    p.rpo = 0.053;
    p.kp = 45.0;
    p.rho_p = 7850.0;
    p.cp_p = 470.0;
    p.rho_f = 0.0975/0.0863;
    p.cp_f = 1006.0;
    p.k_air = 0.026;
    p.mu_f = 1.85e-5;
    p.Vdot = 0.0863;
    p.mdot = 0.0975;
    p.ks = 1.50;
    p.rho_s = 1800.0;
    p.cp_s = 1200.0;
    p.alpha_s = p.ks/(p.rho_s*p.cp_s);
    p.dt = 600.0;
    p.picardMax = 12;
    p.picardTol = 1e-5;
    p.picardRelax = 0.65;
    p.gQuadN = 900;
    p.gQuadBmax = 160.0;
end

function cases = buildSharanCases()
    cases(1).name = "Sharan_May_cooling";
    cases(1).cfd_name = "Sharan_May_cooling_kepsilon";
    cases(1).t_s = (0:7)'*3600;
    cases(1).Tin_C = [31.3; 33.7; 36.4; 37.8; 40.8; 40.4; 39.8; 39.6];
    cases(1).Tsoil_C = [26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.5];
    cases(1).T25_exp_C = [29.1; 29.2; 29.5; 29.5; 29.7; 29.7; 29.8; 30.0];
    cases(1).Tout_exp_C = [26.8; 26.8; 27.2; 27.2; 27.2; 27.2; 27.2; 27.2];

    cases(2).name = "Sharan_January_heating";
    cases(2).cfd_name = "Sharan_January_heating_kepsilon";
    cases(2).t_s = (0:12)'*3600;
    cases(2).Tin_C = [19.8; 17.6; 13.3; 11.9; 10.4; 9.6; 9.1; 8.7; 8.3; 8.7; 9.1; 9.6; 9.8];
    cases(2).Tsoil_C = 24.2*ones(13,1);
    cases(2).T25_exp_C = [22.3; 22.2; 22.1; 21.9; 21.8; 21.7; 21.6; 21.5; 21.5; 21.4; 21.3; 21.2; 21.2];
    cases(2).Tout_exp_C = [23.4; 23.4; 23.3; 23.3; 23.3; 23.3; 23.2; 23.2; 23.0; 23.0; 22.9; 22.9; 22.8];
end

function cfd = readCFDPointsIfAvailable()
    f = fullfile(pwd, 'COMSOL_Sharan_50m_CFD_kepsilon_all_points.csv');
    if exist(f, 'file')
        cfd = readtable(f);
    else
        cfd = table();
    end
end

function sim = simulateMinaeiGCase(p, tExp, TinExp, TsoilExp)
    tEnd = tExp(end);
    t = (0:p.dt:tEnd)';
    Tin = interp1(tExp, TinExp, t, 'linear');
    Th = interp1(tExp, TsoilExp, t, 'linear');
    Nt = numel(t);
    Nx = p.Nx;
    dx = p.L/Nx;

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

    z = ((1:Nx)'-0.5)*dx;
    T25 = zeros(Nt,1);
    for m = 1:Nt
        T25(m) = interp1(z, Tf(:,m), 25.0, 'linear');
    end
    sim.t_s = t;
    sim.Tin_C = Tin;
    sim.T25_C = T25;
    sim.Tout_C = Tf(end,:)';
end

function [Rp1, Rdelta, rResponse] = radialNetwork(p)
    hi = internalH(p);
    re = sqrt((p.rpi^2+p.rpo^2)/2);
    Rconv = 1/(2*pi*p.rpi*hi);
    RcondInner = log(re/p.rpi)/(2*pi*p.kp);
    Rp1 = Rconv + RcondInner;
    Rdelta = log(p.rpo/re)/(2*pi*p.kp);
    rResponse = p.rpo;
end

function hi = internalH(p)
    d = 2*p.rpi;
    area = pi*p.rpi^2;
    v = p.Vdot/area;
    Re = p.rho_f*v*d/p.mu_f;
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

function row = metricRow(caseName, comparison, quantity, err)
    err = err(isfinite(err));
    row = table(string(caseName), string(comparison), string(quantity), ...
        sqrt(mean(err.^2)), mean(abs(err)), mean(err), max(abs(err)), ...
        'VariableNames', {'case_name','comparison','quantity','RMSE_C','MAE_C','bias_C','max_abs_C'});
end

function plotSharanCase(outDir, c, T25_model, Tout_model, cfd_T25, cfd_Tout)
    time_h = c.t_s/3600;
    fig = figure('Color','w','Position',[80 80 1050 420]);
    subplot(1,2,1); hold on; box on; grid on;
    plot(time_h, c.T25_exp_C, 'ko-', 'LineWidth',1.2, 'DisplayName','Experiment');
    plot(time_h, T25_model, 'bs--', 'LineWidth',1.2, 'DisplayName','MATLAB Minaei-G');
    if any(isfinite(cfd_T25)); plot(time_h, cfd_T25, 'r^-', 'LineWidth',1.2, 'DisplayName','CFD k-\epsilon'); end
    xlabel('time / h'); ylabel('T_{25m} / ^\circC');
    title(sprintf('%s T25', char(c.name)), 'Interpreter', 'none');
    legend('Location','best');

    subplot(1,2,2); hold on; box on; grid on;
    plot(time_h, c.Tout_exp_C, 'ko-', 'LineWidth',1.2, 'DisplayName','Experiment');
    plot(time_h, Tout_model, 'bs--', 'LineWidth',1.2, 'DisplayName','MATLAB Minaei-G');
    if any(isfinite(cfd_Tout)); plot(time_h, cfd_Tout, 'r^-', 'LineWidth',1.2, 'DisplayName','CFD k-\epsilon'); end
    xlabel('time / h'); ylabel('T_{out} / ^\circC');
    title(sprintf('%s Tout', char(c.name)), 'Interpreter', 'none');
    legend('Location','best');
    safeName = char(strrep(c.name, "Sharan_", ""));
    saveas(fig, fullfile(outDir, ['Fig_' safeName '_MATLAB_CFD_exp.png']));
    saveas(fig, fullfile(outDir, ['Fig_' safeName '_MATLAB_CFD_exp.pdf']));
    close(fig);
end

function writeSharanReport(outDir, M, E)
    fid = fopen(fullfile(outDir, 'Sharan_MATLAB_MinaeiG_validation_report.md'), 'w');
    fprintf(fid, '# Sharan 50 m MATLAB Minaei-G Validation\n\n');
    fprintf(fid, 'The MATLAB script uses the same Sharan geometry and operating data as the CFD validation: L = 50 m, r_i = 0.05 m, r_o = 0.053 m, Vdot = 0.0863 m3/s, mdot = 0.0975 kg/s. Only the Minaei G-function response kernel is used.\n\n');
    fprintf(fid, '## Metrics\n\n');
    for i = 1:height(M)
        fprintf(fid, '- %s, %s, %s: RMSE = %.3f degC, MAE = %.3f degC, bias = %.3f degC, max abs = %.3f degC.\n', ...
            M.case_name(i), M.comparison(i), M.quantity(i), M.RMSE_C(i), M.MAE_C(i), M.bias_C(i), M.max_abs_C(i));
    end
    fprintf(fid, '\n## Energy\n\n');
    for i = 1:height(E)
        fprintf(fid, '- %s: E_exp = %.3f kWh, E_MATLAB = %.3f kWh (%.2f%%), E_CFD = %.3f kWh (%.2f%%).\n', ...
            E.case_name(i), E.E_exp_kWh(i), E.E_MATLAB_MinaeiG_kWh(i), E.MATLAB_minus_exp_percent(i), E.E_CFD_kepsilon_kWh(i), E.CFD_minus_exp_percent(i));
    end
    fprintf(fid, '\n## Interpretation\n\n');
    fprintf(fid, 'This is a short-time validation against measured Sharan data. It checks the air-side turbulent heat exchange and transient pipe-soil response under two representative months. It is not an annual experimental validation because Sharan does not provide annual hourly outlet-temperature data.\n');
    fclose(fid);
end
