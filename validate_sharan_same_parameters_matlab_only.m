%% validate_sharan_same_parameters_matlab_only.m
% MATLAB Minaei-G model validation using the same operating parameters as
% the Sharan 50 m single straight pipe experiment.
%
% This script compares only:
%   MATLAB Minaei-G model vs Sharan experimental data
%
% It does not compare CFD data and does not evaluate ILS/FLS kernels.

function validate_sharan_same_parameters_matlab_only()
    close all; clc;

    outDir = fullfile(pwd, 'Validation_Sharan_same_parameters_MATLAB_only');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    p = sharanParameters();
    cases = sharanCases();

    pointRows = table();
    metricRows = table();

    for i = 1:numel(cases)
        c = cases(i);
        fprintf('Running Sharan MATLAB-only validation: %s\n', c.name);

        sim = solveMinaeiG(p, c.t_s, c.Tin_C, c.Tsoil_C);
        T25_model = interp1(sim.t_s, sim.T25_C, c.t_s, 'linear');
        Tout_model = interp1(sim.t_s, sim.Tout_C, c.t_s, 'linear');

        pointRows = [pointRows; table( ...
            repmat(string(c.name), numel(c.t_s), 1), c.t_s/3600, c.Tin_C, c.Tsoil_C, ...
            c.T25_exp_C, T25_model, T25_model-c.T25_exp_C, ...
            c.Tout_exp_C, Tout_model, Tout_model-c.Tout_exp_C, ...
            'VariableNames', {'case_name','time_h','Tin_exp_C','Tsoil_C', ...
            'T25_exp_C','T25_MATLAB_C','T25_MATLAB_minus_exp_C', ...
            'Tout_exp_C','Tout_MATLAB_C','Tout_MATLAB_minus_exp_C'})]; %#ok<AGROW>

        metricRows = [metricRows; makeMetric(c.name, 'T25', T25_model-c.T25_exp_C)]; %#ok<AGROW>
        metricRows = [metricRows; makeMetric(c.name, 'Tout', Tout_model-c.Tout_exp_C)]; %#ok<AGROW>

        plotSharanOnly(outDir, c, T25_model, Tout_model);
    end

    writetable(pointRows, fullfile(outDir, 'Sharan_same_parameters_MATLAB_only_points.csv'));
    writetable(metricRows, fullfile(outDir, 'Sharan_same_parameters_MATLAB_only_metrics.csv'));
    writeReport(outDir, metricRows);

    fprintf('Done. Output folder: %s\n', outDir);
end

function p = sharanParameters()
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

function cases = sharanCases()
    cases(1).name = "Sharan_May_cooling";
    cases(1).t_s = (0:7)'*3600;
    cases(1).Tin_C = [31.3; 33.7; 36.4; 37.8; 40.8; 40.4; 39.8; 39.6];
    cases(1).Tsoil_C = [26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.6; 26.5];
    cases(1).T25_exp_C = [29.1; 29.2; 29.5; 29.5; 29.7; 29.7; 29.8; 30.0];
    cases(1).Tout_exp_C = [26.8; 26.8; 27.2; 27.2; 27.2; 27.2; 27.2; 27.2];

    cases(2).name = "Sharan_January_heating";
    cases(2).t_s = (0:12)'*3600;
    cases(2).Tin_C = [19.8; 17.6; 13.3; 11.9; 10.4; 9.6; 9.1; 8.7; 8.3; 8.7; 9.1; 9.6; 9.8];
    cases(2).Tsoil_C = 24.2*ones(13,1);
    cases(2).T25_exp_C = [22.3; 22.2; 22.1; 21.9; 21.8; 21.7; 21.6; 21.5; 21.5; 21.4; 21.3; 21.2; 21.2];
    cases(2).Tout_exp_C = [23.4; 23.4; 23.3; 23.3; 23.3; 23.3; 23.2; 23.2; 23.0; 23.0; 22.9; 22.9; 22.8];
end

function sim = solveMinaeiG(p, tExp, TinExp, TsoilExp)
    t = (0:p.dt:tExp(end))';
    Tin = interp1(tExp, TinExp, t, 'linear');
    Th = interp1(tExp, TsoilExp, t, 'linear');
    Nt = numel(t);
    Nx = p.Nx;
    dx = p.L/Nx;

    [Rp1, Rdelta, rResponse] = radialNetwork(p);
    G = minaeiGKernel(p, rResponse, Nt);
    A = buildMatrix(p, Rp1, Rdelta);

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
            TgNow = soilTemperatureFromG(p, qg, qTrial, m, G, Th(m));
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

        Tg(:,m) = soilTemperatureFromG(p, qg, qTrial, m, G, Th(m));
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
    sim.T25_C = T25;
    sim.Tout_C = Tf(end,:)';
end

function [Rp1, Rdelta, rResponse] = radialNetwork(p)
    hi = internalH(p);
    re = sqrt((p.rpi^2+p.rpo^2)/2);
    Rp1 = 1/(2*pi*p.rpi*hi) + log(re/p.rpi)/(2*pi*p.kp);
    Rdelta = log(p.rpo/re)/(2*pi*p.kp);
    rResponse = p.rpo;
end

function hi = internalH(p)
    d = 2*p.rpi;
    v = p.Vdot/(pi*p.rpi^2);
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

function A = buildMatrix(p, Rp1, Rdelta)
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

function Tg = soilTemperatureFromG(p, qg, qTrial, m, G, ThNow)
    qLocal = qg(:,1:m);
    qLocal(:,m) = qTrial;
    dq = zeros(size(qLocal));
    dq(:,1) = qLocal(:,1);
    if m > 1
        dq(:,2:end) = qLocal(:,2:end) - qLocal(:,1:end-1);
    end
    Tg = ThNow + dq*G(m:-1:1)/p.ks;
end

function row = makeMetric(caseName, quantity, err)
    err = err(isfinite(err));
    row = table(string(caseName), string(quantity), sqrt(mean(err.^2)), ...
        mean(abs(err)), mean(err), max(abs(err)), ...
        'VariableNames', {'case_name','quantity','RMSE_C','MAE_C','bias_C','max_abs_C'});
end

function plotSharanOnly(outDir, c, T25Model, ToutModel)
    time_h = c.t_s/3600;
    fig = figure('Color','w','Position',[80 80 1050 420]);

    subplot(1,2,1); hold on; box on; grid on;
    plot(time_h, c.T25_exp_C, 'ko-', 'LineWidth',1.2, 'DisplayName','Sharan experiment');
    plot(time_h, T25Model, 'bs--', 'LineWidth',1.2, 'DisplayName','MATLAB Minaei-G');
    xlabel('time / h'); ylabel('T_{25m} / ^\circC');
    title(sprintf('%s T25', char(c.name)), 'Interpreter', 'none');
    legend('Location','best');

    subplot(1,2,2); hold on; box on; grid on;
    plot(time_h, c.Tout_exp_C, 'ko-', 'LineWidth',1.2, 'DisplayName','Sharan experiment');
    plot(time_h, ToutModel, 'bs--', 'LineWidth',1.2, 'DisplayName','MATLAB Minaei-G');
    xlabel('time / h'); ylabel('T_{out} / ^\circC');
    title(sprintf('%s Tout', char(c.name)), 'Interpreter', 'none');
    legend('Location','best');

    safeName = char(strrep(c.name, "Sharan_", ""));
    saveas(fig, fullfile(outDir, ['Fig_' safeName '_MATLAB_vs_Sharan.png']));
    saveas(fig, fullfile(outDir, ['Fig_' safeName '_MATLAB_vs_Sharan.pdf']));
    close(fig);
end

function writeReport(outDir, M)
    fid = fopen(fullfile(outDir, 'Sharan_same_parameters_MATLAB_only_report.md'), 'w');
    fprintf(fid, '# MATLAB vs Sharan Validation with Identical Parameters\n\n');
    fprintf(fid, 'Only the MATLAB Minaei-G model is compared with the Sharan experimental data. CFD results, ILS, and FLS kernels are not included.\n\n');
    fprintf(fid, '| Case | Quantity | RMSE (degC) | MAE (degC) | Bias (degC) | Max abs (degC) |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|\n');
    for i = 1:height(M)
        fprintf(fid, '| %s | %s | %.4f | %.4f | %.4f | %.4f |\n', ...
            M.case_name(i), M.quantity(i), M.RMSE_C(i), M.MAE_C(i), M.bias_C(i), M.max_abs_C(i));
    end
    fclose(fid);
end
