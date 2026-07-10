%% EAHE_airgap_physical_modules_v19_minaei_sensitivity.m
% Clean Minaei-type TRCM model with air-gap/contact resistance and reviewer
% sensitivity studies. The script uses the parameter set reported by Minaei
% et al. for the 50 m EAHE parametric case, with an air-gap/contact extension.

clear; clc; close all;

p = defaultParamsMinaei();
opt = defaultOptions();

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir); scriptDir = pwd; end
outDir = fullfile(scriptDir, 'EAHE_airgap_physical_v19_minaei_sensitivity_results');
if ~exist(outDir, 'dir'); mkdir(outDir); end

if strcmpi(getenv('EAHE_SMOKE_TEST'), '1')
    p.Nx = 8;
    p.dt = 30*24*3600;
    p.tEnd = 90*24*3600;
    p.flsQuadN = 31;
    opt.runMainFigures = false;
    opt.runSensitivity = false;
    deltaList_mm = [0 2];
else
    deltaList_mm = [0 0.5 1 2 3 5];
end

fprintf('\nMinaei-type EAHE TRCM with air-gap/contact sensitivity v19\n');
fprintf('L=%.2f m, D_i=%.3f m, wall=%.4f m, H=%.2f m\n', ...
    p.L, 2*p.rpi, p.rpo-p.rpi, p.H);
fprintf('u=%.2f m/s, Vdot=%.5f m3/s, mdot=%.5f kg/s\n', ...
    p.u_air, p.Vdot, p.mdot);
fprintf('Output folder: %s\n\n', outDir);

phiBase = 1.0;
res = cell(numel(deltaList_mm), 1);
for k = 1:numel(deltaList_mm)
    fprintf('Main delta sweep %d/%d: delta=%.3f mm\n', k, numel(deltaList_mm), deltaList_mm(k));
    res{k} = simulateEAHE_case(p, deltaList_mm(k)*1e-3, phiBase, 'AIRGAP');
end

T_main = buildSummaryTable(res, deltaList_mm);
writetable(T_main, fullfile(outDir, 'Table_01_main_delta_sweep.csv'));
writeTableSheet(T_main, fullfile(outDir, 'EAHE_v19_minaei_results.xlsx'), 'main_delta_sweep');

if opt.runMainFigures
    plotMainDeltaSweep(T_main, outDir);
end

S = struct();
if opt.runSensitivity
    S = runReviewerSensitivityStudies(p, outDir, opt);
end

save(fullfile(outDir, 'EAHE_v19_minaei_sensitivity_results.mat'), ...
    'p', 'opt', 'deltaList_mm', 'phiBase', 'res', 'T_main', 'S', '-v7.3');

fprintf('\nFinished. Results saved in: %s\n', outDir);
disp(T_main);

%% Parameter system
function p = defaultParamsMinaei()
    p = struct();

    % Geometry from Minaei parametric case: Di=110 mm, wall=2.5 mm, L=50 m.
    p.L = 50.0;
    p.Nx = 80;
    p.rpi = 0.055;
    p.rpo = 0.0575;
    p.H = 2.0;
    p.rs = 2.50;

    % PVC pipe and air/soil material properties.
    p.kp = 0.19;
    p.rho_p = 1380;
    p.cp_p = 900;

    p.k_air = 0.0242;
    p.rho_f = 1.225;
    p.cp_f = 1006;
    p.mu_f = 1.81e-5;
    p.u_air = 3.3;
    p.Vdot = p.u_air*pi*p.rpi^2;
    p.mdot = p.rho_f*p.Vdot;

    p.useHiCorrelation = true;
    p.hi_const = 12.0;
    p.hi_scale = 1.0;
    p.allowHiScale = false;

    p.ks = 2.10;
    p.rho_s = 1285;
    p.cp_s = 1285;
    p.alpha_s = p.ks/(p.rho_s*p.cp_s);

    % Air-gap/contact extension.
    p.soil_response_scale = 1.0;
    p.beta_gap = 1.0;
    p.Rcontact = 0.0;

    % Annual ground and inlet temperature profiles.
    p.P = 365*24*3600;
    p.Tm = 18.0;
    p.Asurf = 14.0;
    p.t0 = 18*24*3600;
    p.Tin_mean = 20.34;
    p.Tin_amp = 5.66;
    p.Tin_phase_rad = -5.30;
    p.TinProfile = 'minaei_sine';

    % Numerics.
    p.dt = 6*3600;
    p.nYears = 1;
    p.tEnd = p.nYears*p.P;
    p.picardMaxIter = 20;
    p.picardTol = 1e-4;
    p.picardRelax = 0.6;
    p.soilKernelType = 'FLS';
    p.flsQuadN = 121;

    p.Af = pi*p.rpi^2;
    p.Ap = pi*(p.rpo^2 - p.rpi^2);
    p.Cf = p.rho_f*p.Af*p.cp_f;
    p.Cp = p.rho_p*p.Ap*p.cp_p;
end

function opt = defaultOptions()
    opt = struct();
    opt.runMainFigures = true;
    opt.runSensitivity = true;
    opt.sensitivityNx = 60;
    opt.sensitivityDt_h = 12;
    opt.deltaBase_m = 2e-3;
    opt.phiBase = 1.0;
end

%% Core solver
function result = simulateEAHE_case(p, delta, phi, modelType)
    dx = p.L/p.Nx;
    t = 0:p.dt:p.tEnd;
    Nt = numel(t);
    Nx = p.Nx;

    Rnet = radialThermalNetwork(p, delta, phi, modelType);
    Tin = inletTemperature(p, t);
    Th = undisturbedSoilTemperature(p, p.H, t);
    Glag = buildSoilResponseKernel(p, Rnet.rg, Nx, dx, Nt);

    Tf = zeros(Nx, Nt);
    Tp = zeros(Nx, Nt);
    Tg = zeros(Nx, Nt);
    qg = zeros(Nx, Nt);
    picardIter = zeros(1, Nt);
    picardResidual = nan(1, Nt);

    Tf(:,1) = Th(1);
    Tp(:,1) = Th(1);
    Tg(:,1) = Th(1);

    for m = 2:Nt
        qTrial = qg(:,m-1);
        resNorm = inf;
        for it = 1:p.picardMaxIter
            TgNow = soilBoundaryTemperature(p, qg, qTrial, m, Glag, Th(m));
            [~, TpNew] = solveAirPipeImplicitStep(p, Tf(:,m-1), Tp(:,m-1), ...
                TgNow, Tin(m), Rnet.Rp1, Rnet.Rdelta);
            qNew = (TpNew - TgNow)/Rnet.Rdelta;
            denom = max(1, max(abs(qNew)));
            resNorm = max(abs(qNew - qTrial))/denom;
            qTrial = p.picardRelax*qNew + (1-p.picardRelax)*qTrial;
            if resNorm < p.picardTol
                break;
            end
        end
        picardIter(m) = it;
        picardResidual(m) = resNorm;
        Tg(:,m) = soilBoundaryTemperature(p, qg, qTrial, m, Glag, Th(m));
        [Tf(:,m), Tp(:,m)] = solveAirPipeImplicitStep(p, Tf(:,m-1), Tp(:,m-1), ...
            Tg(:,m), Tin(m), Rnet.Rp1, Rnet.Rdelta);
        qg(:,m) = (Tp(:,m) - Tg(:,m))/Rnet.Rdelta;
    end

    Tout = Tf(end,:);
    Qair = p.mdot*p.cp_f*(Tin - Tout);
    TintJump = qg*(Rnet.Rint_eff);

    E_cool = trapz(t, max(Qair,0))/3.6e6;
    E_heat = trapz(t, max(-Qair,0))/3.6e6;
    E_abs = trapz(t, abs(Qair))/3.6e6;

    result = struct();
    result.t = t;
    result.day = t/86400;
    result.Tin = Tin;
    result.Th = Th;
    result.Tf = Tf;
    result.Tp = Tp;
    result.Tg = Tg;
    result.qg = qg;
    result.Tout = Tout;
    result.Qair = Qair;
    result.TintJump = TintJump;
    result.delta = delta;
    result.phi = phi;
    result.chi = 1 - phi;
    result.Rnet = Rnet;
    result.Rgap = Rnet.Rgap;
    result.Rcontact = Rnet.Rcontact;
    result.Rint_eff = Rnet.Rint_eff;
    result.Rdelta = Rnet.Rdelta;
    result.E_cool = E_cool;
    result.E_heat = E_heat;
    result.E_abs = E_abs;
    result.picardIter = picardIter;
    result.picardResidual = picardResidual;
end

function Rnet = radialThermalNetwork(p, delta, phi, modelType)
    hi = internalConvectionCoefficient(p);
    re = sqrt((p.rpi^2 + p.rpo^2)/2);
    rg = p.rpo + max(delta,0);

    Rconv = 1/(2*pi*p.rpi*hi);
    Rcond_inner = log(re/p.rpi)/(2*pi*p.kp);
    Rcond_outer = log(p.rpo/re)/(2*pi*p.kp);
    Rp1 = Rconv + Rcond_inner;
    Rp2 = Rcond_outer;

    Rcontact = max(p.Rcontact, 0);
    if strcmpi(modelType, 'M0')
        Rgap = 0;
        Rdelta = Rp2;
        rg = p.rpo;
    else
        if delta <= 0
            Rgap = 0;
            rg = p.rpo;
        else
            Rgap = p.beta_gap*log(rg/p.rpo)/(2*pi*p.k_air);
        end
        phi = min(max(phi,0),1);
        chi = 1 - phi;
        Rbranch_contact = Rp2 + Rcontact;
        Rbranch_gap = Rp2 + Rgap;
        if phi <= 0 || delta <= 0
            Rdelta = Rbranch_contact;
        elseif chi <= 0
            Rdelta = Rbranch_gap;
        else
            Rdelta = 1/(chi/Rbranch_contact + phi/Rbranch_gap);
        end
    end

    Rnet = struct();
    Rnet.hi = hi;
    Rnet.re = re;
    Rnet.rg = rg;
    Rnet.Rconv = Rconv;
    Rnet.Rcond_inner = Rcond_inner;
    Rnet.Rcond_outer = Rcond_outer;
    Rnet.Rp1 = Rp1;
    Rnet.Rp2 = Rp2;
    Rnet.Rgap = Rgap;
    Rnet.Rcontact = Rcontact;
    Rnet.Rdelta = Rdelta;
    Rnet.Rint_eff = Rdelta - Rp2;
    Rnet.phi_gap = phi;
    Rnet.chi_contact = 1 - phi;
end

function hi = internalConvectionCoefficient(p)
    if ~p.useHiCorrelation
        hi = p.hi_const;
    else
        D = 2*p.rpi;
        u = p.Vdot/(pi*p.rpi^2);
        Re = p.rho_f*u*D/p.mu_f;
        Pr = p.mu_f*p.cp_f/p.k_air;
        if Re < 2300
            Nu = 3.66;
        else
            f = (0.79*log(Re) - 1.64)^(-2);
            Nu = ((f/8)*(Re-1000)*Pr) / (1 + 12.7*sqrt(f/8)*(Pr^(2/3)-1));
        end
        hi = Nu*p.k_air/D;
    end
    if isfield(p, 'allowHiScale') && p.allowHiScale
        hi = hi*p.hi_scale;
    end
end

function T = inletTemperature(p, t)
    if strcmpi(p.TinProfile, 'minaei_sine')
        T = p.Tin_mean + p.Tin_amp*sin(2*pi*t/p.P + p.Tin_phase_rad);
    else
        T = p.Tin_mean + p.Tin_amp*cos(2*pi*t/p.P);
    end
end

function T = undisturbedSoilTemperature(p, h, t)
    beta = sqrt(pi/(p.P*p.alpha_s));
    T = p.Tm - p.Asurf*exp(-h*beta).* ...
        cos(2*pi/p.P*(t - p.t0 - h/2*sqrt(p.P/(pi*p.alpha_s))));
end

function Glag = buildSoilResponseKernel(p, r, Nx, dx, Nt)
    kernelType = upper(string(p.soilKernelType));
    switch kernelType
        case "ILS"
            Glag = zeros(1,Nt);
            for k = 1:Nt
                Glag(k) = soilResponseKernel_ILS(p, r, (k-1)*p.dt);
            end
        case "FLS"
            Glag = zeros(Nx,Nt);
            zEval = ((1:Nx).' - 0.5)*dx;
            zSrc = linspace(0, p.L, p.flsQuadN);
            for k = 1:Nt
                tau = (k-1)*p.dt;
                Gils = soilResponseKernel_ILS(p, r, tau);
                Gfls = soilResponseKernel_FLS(p, r, tau, zEval, zSrc);
                if Gils > 0
                    corr = min(max(Gfls/Gils, 0), 1);
                    Glag(:,k) = Gils*corr;
                else
                    Glag(:,k) = Gfls;
                end
            end
        otherwise
            error('Unknown soilKernelType: %s', p.soilKernelType);
    end
end

function G = soilResponseKernel_ILS(p, r, tau)
    if tau <= 0
        tau = p.dt/2;
    end
    x = r^2/(4*p.alpha_s*tau);
    G = (1/(4*pi))*expint(x);
end

function G = soilResponseKernel_FLS(p, r, tau, zEval, zSrc)
    if tau <= 0
        tau = p.dt/2;
    end
    G = zeros(numel(zEval),1);
    for i = 1:numel(zEval)
        s = zSrc - zEval(i);
        dist = sqrt(r^2 + s.^2);
        arg = dist./sqrt(4*p.alpha_s*tau);
        integrand = erfc(arg)./dist;
        G(i) = trapz(zSrc, integrand)/(4*pi);
    end
end

function TgNow = soilBoundaryTemperature(p, qgHist, qTrial, m, Glag, ThNow)
    Nx = p.Nx;
    if m <= 1
        TgNow = ThNow*ones(Nx,1);
        return;
    end
    qLocal = qgHist(:,1:m);
    qLocal(:,m) = qTrial;
    dq = zeros(Nx,m);
    dq(:,1) = qLocal(:,1);
    dq(:,2:m) = qLocal(:,2:m) - qLocal(:,1:m-1);
    if isvector(Glag)
        Gvec = Glag(m:-1:1).';
        Tdist = p.soil_response_scale*dq*Gvec/p.ks;
    else
        Gmat = Glag(:,m:-1:1);
        Tdist = p.soil_response_scale*sum(dq.*Gmat, 2)/p.ks;
    end
    TgNow = ThNow + Tdist;
end

function [TfNew, TpNew] = solveAirPipeImplicitStep(p, TfOld, TpOld, Tg, Tin, Rp1, Rdelta)
    Nx = p.Nx;
    dx = p.L/Nx;
    dt = p.dt;
    M = p.mdot*p.cp_f/dx;
    A = sparse(2*Nx, 2*Nx);
    b = zeros(2*Nx, 1);
    for i = 1:Nx
        row = i;
        iF = i;
        iP = Nx+i;
        A(row,iF) = p.Cf/dt + M + 1/Rp1;
        A(row,iP) = -1/Rp1;
        b(row) = p.Cf/dt*TfOld(i);
        if i == 1
            b(row) = b(row) + M*Tin;
        else
            A(row,iF-1) = -M;
        end
    end
    for i = 1:Nx
        row = Nx+i;
        iF = i;
        iP = Nx+i;
        A(row,iP) = p.Cp/dt + 1/Rp1 + 1/Rdelta;
        A(row,iF) = -1/Rp1;
        b(row) = p.Cp/dt*TpOld(i) + Tg(i)/Rdelta;
    end
    x = A\b;
    TfNew = x(1:Nx);
    TpNew = x(Nx+1:end);
end

%% Tables and figures
function T = buildSummaryTable(res, deltaList_mm)
    n = numel(res);
    delta_mm = deltaList_mm(:);
    phi = zeros(n,1);
    chi = zeros(n,1);
    hi_W_m2K = zeros(n,1);
    Rgap_mK_W = zeros(n,1);
    Rcontact_mK_W = zeros(n,1);
    Rint_eff_mK_W = zeros(n,1);
    Rdelta_mK_W = zeros(n,1);
    Tout_mean_C = zeros(n,1);
    Tout_min_C = zeros(n,1);
    Tout_max_C = zeros(n,1);
    Ecool_kWh = zeros(n,1);
    Eheat_kWh = zeros(n,1);
    Eabs_kWh = zeros(n,1);
    Dgap_percent = zeros(n,1);
    PicardIter_max = zeros(n,1);

    E0 = res{1}.E_abs;
    for k = 1:n
        r = res{k};
        phi(k) = r.phi;
        chi(k) = r.chi;
        hi_W_m2K(k) = r.Rnet.hi;
        Rgap_mK_W(k) = r.Rgap;
        Rcontact_mK_W(k) = r.Rcontact;
        Rint_eff_mK_W(k) = r.Rint_eff;
        Rdelta_mK_W(k) = r.Rdelta;
        Tout_mean_C(k) = mean(r.Tout);
        Tout_min_C(k) = min(r.Tout);
        Tout_max_C(k) = max(r.Tout);
        Ecool_kWh(k) = r.E_cool;
        Eheat_kWh(k) = r.E_heat;
        Eabs_kWh(k) = r.E_abs;
        Dgap_percent(k) = 100*(1 - r.E_abs/max(E0, eps));
        PicardIter_max(k) = max(r.picardIter(:));
    end
    T = table(delta_mm, phi, chi, hi_W_m2K, Rgap_mK_W, Rcontact_mK_W, ...
        Rint_eff_mK_W, Rdelta_mK_W, Tout_mean_C, Tout_min_C, Tout_max_C, ...
        Ecool_kWh, Eheat_kWh, Eabs_kWh, Dgap_percent, PicardIter_max);
end

function T = sensitivityResultRow(r, p, delta, phi)
    Tout = r.Tout(:);
    Tin = r.Tin(:);
    dT = Tin - Tout;
    T = table();
    T.delta_mm = delta*1e3;
    T.phi = phi;
    T.chi = 1 - phi;
    T.ks_W_mK = p.ks;
    T.velocity_m_s = p.Vdot/(pi*p.rpi^2);
    T.Vdot_m3_s = p.Vdot;
    T.mdot_kg_s = p.mdot;
    T.Nx = p.Nx;
    T.dt_h = p.dt/3600;
    T.hi_W_m2K = r.Rnet.hi;
    T.Rgap_mK_W = r.Rnet.Rgap;
    T.Rcontact_mK_W = r.Rnet.Rcontact;
    T.Rint_eff_mK_W = r.Rnet.Rint_eff;
    T.Rdelta_mK_W = r.Rnet.Rdelta;
    T.Tout_mean_C = mean(Tout);
    T.Tout_min_C = min(Tout);
    T.Tout_max_C = max(Tout);
    T.DeltaT_mean_C = mean(dT);
    T.DeltaT_abs_mean_C = mean(abs(dT));
    T.Ecool_kWh = r.E_cool;
    T.Eheat_kWh = r.E_heat;
    T.Eabs_kWh = r.E_abs;
    T.Qair_abs_mean_W = mean(abs(r.Qair(:)));
    T.PicardIter_max = max(r.picardIter(:));
    finiteRes = r.picardResidual(isfinite(r.picardResidual));
    if isempty(finiteRes)
        T.PicardResidual_max = NaN;
    else
        T.PicardResidual_max = max(finiteRes);
    end
end

function plotMainDeltaSweep(T, outDir)
    fig = figure('Visible','off','Color','w','Position',[100 100 980 420]);
    subplot(1,2,1);
    plot(T.delta_mm, T.Eabs_kWh, 'o-', 'LineWidth', 1.5);
    xlabel('delta / mm'); ylabel('Annual abs heat / kWh'); grid on;
    subplot(1,2,2);
    plot(T.delta_mm, T.Dgap_percent, 's-', 'LineWidth', 1.5);
    xlabel('delta / mm'); ylabel('Dgap / percent'); grid on;
    saveFigure(fig, outDir, 'Fig_01_main_delta_sweep');
end

%% Reviewer sensitivity studies
function S = runReviewerSensitivityStudies(p, outDir, opt)
    sensDir = fullfile(outDir, 'review_sensitivity_studies');
    if ~exist(sensDir, 'dir'); mkdir(sensDir); end
    ps = p;
    ps.Nx = opt.sensitivityNx;
    ps.dt = opt.sensitivityDt_h*3600;
    ps.tEnd = ps.P;
    ps.allowHiScale = false;
    deltaBase = opt.deltaBase_m;
    phiBase = opt.phiBase;

    ksList = linspace(0.8, 3.2, 17);
    T_ks = runSoilKSweep(ps, sensDir, ksList, deltaBase, phiBase);

    deltaList_mm = [0 0.1 0.2 0.3 0.5 0.75 1.0 1.5 2.0 2.5 3.0 4.0 5.0 6.0 7.0 8.0 10.0];
    T_delta = runDeltaSweep(ps, sensDir, deltaList_mm, phiBase);

    chiList = linspace(0, 1, 21);
    T_chi_2 = runContactSweep(ps, sensDir, chiList, 2e-3, '2mm');
    T_chi_5 = runContactSweep(ps, sensDir, chiList, 5e-3, '5mm');
    T_chi = [T_chi_2; T_chi_5];
    writetable(T_chi, fullfile(sensDir, 'Sensitivity_contact_coefficient_all.csv'));

    velocityList = linspace(1.0, 7.0, 17);
    T_velocity = runVelocitySweep(ps, sensDir, velocityList, deltaBase, phiBase);

    nxList = [20 30 40 60 80 100 120 160];
    T_nx = runNxIndependenceDense(p, sensDir, nxList, deltaBase, phiBase);

    dtList_h = [24 18 12 8 6 4 3 2 1];
    T_dt = runDtIndependenceDense(p, sensDir, dtList_h, deltaBase, phiBase);

    xlsxPath = fullfile(sensDir, 'Reviewer_sensitivity_and_independence.xlsx');
    writeTableSheet(T_ks, xlsxPath, 'soil_k');
    writeTableSheet(T_delta, xlsxPath, 'air_gap_delta');
    writeTableSheet(T_chi, xlsxPath, 'contact_chi');
    writeTableSheet(T_velocity, xlsxPath, 'velocity');
    writeTableSheet(T_nx, xlsxPath, 'Nx_independence');
    writeTableSheet(T_dt, xlsxPath, 'dt_independence');

    plotSensitivityOverview(T_ks, T_delta, T_chi, T_velocity, T_nx, T_dt, sensDir);

    S = struct('soil_k',T_ks, 'delta',T_delta, 'contact_chi',T_chi, ...
        'velocity',T_velocity, 'Nx',T_nx, 'dt',T_dt, 'outputDir',sensDir);
    save(fullfile(sensDir, 'Reviewer_sensitivity_and_independence.mat'), 'S', '-v7.3');
end

function T = runSoilKSweep(p, outDir, ksList, delta, phi)
    rows = cell(numel(ksList),1);
    for i = 1:numel(ksList)
        pp = p;
        pp.ks = ksList(i);
        pp.alpha_s = pp.ks/(pp.rho_s*pp.cp_s);
        fprintf('Soil k sensitivity %d/%d: %.3f W/(m K)\n', i, numel(ksList), ksList(i));
        r = simulateEAHE_case(pp, delta, phi, 'AIRGAP');
        rows{i} = sensitivityResultRow(r, pp, delta, phi);
    end
    T = vertcat(rows{:});
    T.parameter_value = ksList(:);
    T = movevars(T, 'parameter_value', 'Before', 1);
    writetable(T, fullfile(outDir, 'Sensitivity_soil_conductivity.csv'));
end

function T = runDeltaSweep(p, outDir, deltaList_mm, phi)
    rows = cell(numel(deltaList_mm),1);
    E0 = NaN;
    for i = 1:numel(deltaList_mm)
        delta = deltaList_mm(i)*1e-3;
        fprintf('Air-gap sensitivity %d/%d: %.3f mm\n', i, numel(deltaList_mm), deltaList_mm(i));
        r = simulateEAHE_case(p, delta, phi, 'AIRGAP');
        if i == 1; E0 = r.E_abs; end
        rows{i} = sensitivityResultRow(r, p, delta, phi);
        rows{i}.Dgap_from_delta0_percent = 100*(1 - r.E_abs/max(E0, eps));
    end
    T = vertcat(rows{:});
    T.delta_sweep_mm = deltaList_mm(:);
    T = movevars(T, 'delta_sweep_mm', 'Before', 1);
    writetable(T, fullfile(outDir, 'Sensitivity_air_gap_thickness.csv'));
end

function T = runContactSweep(p, outDir, chiList, delta, tag)
    rows = cell(numel(chiList),1);
    for i = 1:numel(chiList)
        chi = chiList(i);
        phi = 1 - chi;
        fprintf('Contact sensitivity %s %d/%d: chi=%.3f\n', tag, i, numel(chiList), chi);
        r = simulateEAHE_case(p, delta, phi, 'AIRGAP');
        rows{i} = sensitivityResultRow(r, p, delta, phi);
    end
    T = vertcat(rows{:});
    T.delta_case_mm = delta*1e3*ones(numel(chiList),1);
    T.chi_contact = chiList(:);
    T.phi_gap = 1 - chiList(:);
    T = movevars(T, {'delta_case_mm','chi_contact','phi_gap'}, 'Before', 1);
    writetable(T, fullfile(outDir, ['Sensitivity_contact_coefficient_' tag '.csv']));
end

function T = runVelocitySweep(p, outDir, velocityList, delta, phi)
    rows = cell(numel(velocityList),1);
    for i = 1:numel(velocityList)
        pp = setAirVelocity(p, velocityList(i));
        fprintf('Velocity sensitivity %d/%d: %.3f m/s\n', i, numel(velocityList), velocityList(i));
        r = simulateEAHE_case(pp, delta, phi, 'AIRGAP');
        rows{i} = sensitivityResultRow(r, pp, delta, phi);
    end
    T = vertcat(rows{:});
    T.velocity_sweep_m_s = velocityList(:);
    T = movevars(T, 'velocity_sweep_m_s', 'Before', 1);
    writetable(T, fullfile(outDir, 'Sensitivity_air_velocity.csv'));
end

function T = runNxIndependenceDense(p, outDir, nxList, delta, phi)
    rows = cell(numel(nxList),1);
    for i = 1:numel(nxList)
        pp = p;
        pp.Nx = nxList(i);
        pp.tEnd = pp.P;
        pp.allowHiScale = false;
        fprintf('Nx independence %d/%d: Nx=%d\n', i, numel(nxList), nxList(i));
        r = simulateEAHE_case(pp, delta, phi, 'AIRGAP');
        rows{i} = sensitivityResultRow(r, pp, delta, phi);
    end
    T = vertcat(rows{:});
    T.Nx_sweep = nxList(:);
    T.Eabs_relative_to_finest_percent = 100*(T.Eabs_kWh/T.Eabs_kWh(end) - 1);
    T.ToutMean_relative_to_finest_C = T.Tout_mean_C - T.Tout_mean_C(end);
    T = movevars(T, 'Nx_sweep', 'Before', 1);
    writetable(T, fullfile(outDir, 'Independence_Nx_dense.csv'));
end

function T = runDtIndependenceDense(p, outDir, dtList_h, delta, phi)
    rows = cell(numel(dtList_h),1);
    for i = 1:numel(dtList_h)
        pp = p;
        pp.dt = dtList_h(i)*3600;
        pp.tEnd = pp.P;
        pp.allowHiScale = false;
        fprintf('dt independence %d/%d: dt=%.3f h\n', i, numel(dtList_h), dtList_h(i));
        r = simulateEAHE_case(pp, delta, phi, 'AIRGAP');
        rows{i} = sensitivityResultRow(r, pp, delta, phi);
    end
    T = vertcat(rows{:});
    T.dt_sweep_h = dtList_h(:);
    T.Eabs_relative_to_finest_percent = 100*(T.Eabs_kWh/T.Eabs_kWh(end) - 1);
    T.ToutMean_relative_to_finest_C = T.Tout_mean_C - T.Tout_mean_C(end);
    T = movevars(T, 'dt_sweep_h', 'Before', 1);
    writetable(T, fullfile(outDir, 'Independence_dt_dense.csv'));
end

function pp = setAirVelocity(p, u)
    pp = p;
    pp.u_air = u;
    pp.Vdot = u*pi*pp.rpi^2;
    pp.mdot = pp.rho_f*pp.Vdot;
end

function plotSensitivityOverview(T_ks, T_delta, T_chi, T_velocity, T_nx, T_dt, outDir)
    fig = figure('Visible','off','Color','w','Position',[100 100 1300 780]);
    subplot(2,3,1);
    plot(T_ks.parameter_value, T_ks.Eabs_kWh, 'o-', 'LineWidth', 1.4);
    xlabel('ks / W m-1 K-1'); ylabel('Annual abs heat / kWh'); grid on;
    title('Soil conductivity');

    subplot(2,3,2);
    plot(T_delta.delta_sweep_mm, T_delta.Eabs_kWh, 'o-', 'LineWidth', 1.4);
    xlabel('delta / mm'); ylabel('Annual abs heat / kWh'); grid on;
    title('Air-gap thickness');

    subplot(2,3,3); hold on;
    cases = unique(T_chi.delta_case_mm);
    for i = 1:numel(cases)
        idx = abs(T_chi.delta_case_mm - cases(i)) < 1e-9;
        plot(T_chi.chi_contact(idx), T_chi.Eabs_kWh(idx), 'o-', 'LineWidth', 1.4);
    end
    xlabel('chi'); ylabel('Annual abs heat / kWh'); grid on;
    legend(compose('delta=%.0f mm', cases), 'Location','best');
    title('Contact coefficient');

    subplot(2,3,4);
    plot(T_velocity.velocity_sweep_m_s, T_velocity.Eabs_kWh, 'o-', 'LineWidth', 1.4);
    xlabel('u / m s-1'); ylabel('Annual abs heat / kWh'); grid on;
    title('Air velocity');

    subplot(2,3,5);
    plot(T_nx.Nx_sweep, abs(T_nx.Eabs_relative_to_finest_percent), 'o-', 'LineWidth', 1.4);
    xlabel('Nx'); ylabel('abs E error / percent'); grid on;
    title('Grid independence');

    subplot(2,3,6);
    plot(T_dt.dt_sweep_h, abs(T_dt.Eabs_relative_to_finest_percent), 'o-', 'LineWidth', 1.4);
    set(gca, 'XDir', 'reverse');
    xlabel('dt / h'); ylabel('abs E error / percent'); grid on;
    title('Time-step independence');

    saveFigure(fig, outDir, 'Fig_review_sensitivity_overview');
end

function writeTableSheet(T, xlsxPath, sheetName)
    try
        writetable(T, xlsxPath, 'Sheet', sheetName);
    catch
        [folder, base, ~] = fileparts(xlsxPath);
        writetable(T, fullfile(folder, [base '_' sheetName '.csv']));
    end
end

function saveFigure(fig, outDir, baseName)
    pngPath = fullfile(outDir, [baseName '.png']);
    pdfPath = fullfile(outDir, [baseName '.pdf']);
    try
        exportgraphics(fig, pngPath, 'Resolution', 300);
        exportgraphics(fig, pdfPath, 'ContentType', 'vector');
    catch
        print(fig, pngPath, '-dpng', '-r300');
        print(fig, pdfPath, '-dpdf', '-vector');
    end
    close(fig);
end
