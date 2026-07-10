%% EAHE_Fig4_Validation_Cylinder.m
% 复现 Minaei et al. (2021) Fig.4 验证案例
% 关键改进：新增 CYLINDER 土壤核（文献 Eq.9 Bessel 精确积分）
% 作者：基于原始代码修改

clear; clc; close all;

%% ==================== 用户配置区 ====================
config = struct();
config.soilKernel         = 'CYLINDER';   % 可选: 'ILS' / 'FLS' / 'CYLINDER' / 'CYLINDER_FLS'
config.wallThickness_mm   = 2.5;          % 壁厚 [mm]：Table 2 未给出，默认 2.5（Table 3），可改 2,3,4
config.runWallSensitivity = false;        % true: 运行 2/3/4 mm 壁厚对比；false: 仅运行单次
config.quickTest          = false;        % true: 1 年快速测试；false: 2 年（文献标准）
% ===================================================

%% 参数初始化
p = defaultParamsMinaei('validation', config);
opt = defaultOptions();

%% 输出目录
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir); scriptDir = pwd; end
outDir = fullfile(scriptDir, 'EAHE_Fig4_Cylinder_Results');
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('\n=====================================================\n');
fprintf('  Minaei et al. (2021) Fig.4 Validation (Cylinder Kernel)\n');
fprintf('=====================================================\n');
fprintf('Soil Kernel : %s\n', config.soilKernel);
fprintf('Wall Thickness: %.1f mm (rpo = %.4f m)\n', config.wallThickness_mm, p.rpo);
fprintf('L = %.2f m, H = %.2f m, u = %.2f m/s\n', p.L, p.H, p.u_air);
fprintf('Soil: rho_s=%.0f, cp_s=%.0f, ks=%.2f\n', p.rho_s, p.cp_s, p.ks);

%% 参数相位自检（验证 Eq.25 & Eq.26）
verifyBoundaryConditions(p);

%% 主运行或壁厚灵敏度
if config.runWallSensitivity
    wallList = [2, 3, 4];  % mm
    colors = lines(numel(wallList));
    fig = figure('Color','w','Position',[200 200 800 500]); hold on;
    
    for iw = 1:numel(wallList)
        pc = p;
        pc.rpo = pc.rpi + wallList(iw)*1e-3;
        pc.Ap = pi*(pc.rpo^2 - pc.rpi^2);
        pc.Cp = pc.rho_p*pc.Ap*pc.cp_p;
        
        fprintf('\n--- Wall Sensitivity %d/%d: %.1f mm ---\n', iw, numel(wallList), wallList(iw));
        res = simulateEAHE_case(pc, 0, 1.0, 'M0');
        [t_day, Tout] = extractSecondYear(pc, res);
        
        plot(t_day, Tout, '-', 'Color', colors(iw,:), 'LineWidth', 1.8, ...
            'DisplayName', sprintf('wall = %.1f mm', wallList(iw)));
    end
    
    xlabel('Time (days)'); ylabel('T_{out} (^{\circ}C)');
    title('Fig.4 Sensitivity: Pipe Wall Thickness');
    legend('Location','best'); grid on; box on;
    xlim([0 365]); ylim([10 28]);
    saveFigure(fig, outDir, 'Fig4_WallSensitivity');
    fprintf('\nWall sensitivity plot saved.\n');
    
else
    %% 单次运行
    fprintf('\n--- Running single case (kernel = %s) ---\n', config.soilKernel);
    res = simulateEAHE_case(p, 0, 1.0, 'M0');
    
    %% 提取第 2 年数据
    [t_day, Tout, Tin, Th] = extractSecondYear(p, res);
    
    %% 绘图：Fig.4 风格
    fig = figure('Color','w','Position',[200 200 800 600]);
    
    % 主图：出口温度
    subplot(2,1,1);
    plot(t_day, Tout, 'k-', 'LineWidth', 2.2); hold on;
    plot(t_day, Tin, 'k--', 'LineWidth', 1.5);
    plot(t_day, Th, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2);
    
    % 文献参考区间（Fig.4 目测：出口在 16~24°C 之间波动）
    fill([0 365 365 0], [16 16 24 24], [0.9 0.95 1], 'FaceAlpha', 0.3, 'EdgeColor','none');
    
    xlabel('Time (days)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Temperature (^{\circ}C)', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('Fig.4 Validation: %s Kernel (2nd Year)', config.soilKernel), 'FontSize', 12);
    legend({'Present T_{out}', 'Inlet T_a (Eq.26)', 'Soil T_h (Eq.3)', 'Literature T_{out} range'}, ...
        'Location', 'best', 'FontSize', 9);
    grid on; box on;
    xlim([0 365]); ylim([10 28]);
    
    % 子图：Picard 迭代残差（检查收敛性）
    subplot(2,1,2);
    semilogy(t_day, max(1e-10, res.picardResidual(idx_year2(p, res))), 'b-', 'LineWidth', 1.2);
    xlabel('Time (days)'); ylabel('Picard Residual');
    title('Nonlinear Solver Convergence'); grid on; box on;
    xlim([0 365]);
    
    saveFigure(fig, outDir, sprintf('Fig4_Validation_%s', config.soilKernel));
    
    %% 统计输出
    fprintf('\n--- 2nd Year Statistics ---\n');
    fprintf('Tout: mean=%.2f, min=%.2f (day=%.0f), max=%.2f (day=%.0f)\n', ...
        mean(Tout), min(Tout), t_day(Tout==min(Tout)), max(Tout), t_day(Tout==max(Tout)));
    fprintf('Tin:  mean=%.2f, min=%.2f, max=%.2f\n', mean(Tin), min(Tin), max(Tin));
    fprintf('Th:   mean=%.2f, min=%.2f, max=%.2f\n', mean(Th), min(Th), max(Th));
    fprintf('Annual cooling energy: %.2f kWh\n', res.E_cool);
    fprintf('Annual heating energy: %.2f kWh\n', res.E_heat);
    fprintf('Results saved to: %s\n', outDir);
end

%% ==================== 局部函数 ====================

function p = defaultParamsMinaei(caseName, config)
    if nargin < 2, config = struct(); end
    if ~isfield(config, 'wallThickness_mm'), config.wallThickness_mm = 2.5; end
    if ~isfield(config, 'soilKernel'), config.soilKernel = 'CYLINDER'; end
    if ~isfield(config, 'quickTest'), config.quickTest = false; end
    
    p = struct();
    
    % 几何（Table 1: Di = 110 mm）
    p.rpi = 0.055;
    p.rpo = p.rpi + config.wallThickness_mm*1e-3;  % 壁厚可配置
    
    % PVC (Table 1)
    p.kp = 0.19; p.rho_p = 1380; p.cp_p = 900;
    
    % Air (Table 1)
    p.k_air = 0.0242; p.rho_f = 1.225; p.cp_f = 1006; p.mu_f = 1.81e-5;
    
    % Convection (Eq.14)
    p.useHiCorrelation = true;
    p.hi_const = 12.0; p.hi_scale = 1.0; p.allowHiScale = false;
    
    % Numerics
    p.Nx = 80;
    p.dt = 6*3600;
    p.picardMaxIter = 20; p.picardTol = 1e-4; p.picardRelax = 0.6;
    p.soilKernelType = config.soilKernel;
    p.flsQuadN = 121;
    
    % Air-gap/contact (not used for Fig.4, but kept for compatibility)
    p.soil_response_scale = 1.0; p.beta_gap = 1.0; p.Rcontact = 0.0;
    
    % Validation case (Section 3.1, Table 2)
    p.L = 25.77; p.H = 1.6; p.rs = 2.50; p.u_air = 3.3;
    p.ks = 2.10; p.rho_s = 1800; p.cp_s = 1780;
    
    p.P = 365*24*3600;
    p.Tm = 18.55; p.Asurf = 6.28; p.t0 = 200.1*24*3600;  % Eq.25 matched
    
    p.Tin_mean = 20.34; p.Tin_amp = 5.66; p.Tin_phase_rad = -5.30;  % Eq.26
    p.TinProfile = 'minaei_sine';
    
    if config.quickTest
        p.nYears = 1; p.tEnd = p.P;
        fprintf('>>> QUICK TEST MODE: 1 year only <<<\n');
    else
        p.nYears = 2; p.tEnd = p.nYears * p.P;  % Literature standard
    end
    
    % Derived
    p.alpha_s = p.ks/(p.rho_s*p.cp_s);
    p.Vdot = p.u_air*pi*p.rpi^2;
    p.mdot = p.rho_f*p.Vdot;
    p.Af = pi*p.rpi^2;
    p.Ap = pi*(p.rpo^2 - p.rpi^2);
    p.Cf = p.rho_f*p.Af*p.cp_f;   % FIXED: original had typo p.pf_f
    p.Cp = p.rho_p*p.Ap*p.cp_p;
end

function opt = defaultOptions()
    opt = struct();
    opt.runMainFigures = true;
    opt.runSensitivity = false;
end

function verifyBoundaryConditions(p)
    fprintf('\n--- Boundary Condition Verification ---\n');
    t_test = linspace(0, p.P, 1000);
    
    % Eq.25: T_s = 18.55 + 6.28*sin(2*pi*t/P + 26.4)
    % Our form: T(0,t) = Tm - Asurf*cos(2*pi/P*(t-t0))
    T_surf = p.Tm - p.Asurf*cos(2*pi/p.P*(t_test - p.t0));
    T_surf_ref = 18.55 + 6.28*sin(2*pi*t_test/p.P + 26.4);
    fprintf('Surface T: max err vs Eq.25 = %.4f degC\n', max(abs(T_surf - T_surf_ref)));
    
    % Eq.26: T_a = 20.34 + 5.66*sin(2*pi*t/P - 5.30)
    T_in = p.Tin_mean + p.Tin_amp*sin(2*pi*t_test/p.P + p.Tin_phase_rad);
    T_in_ref = 20.34 + 5.66*sin(2*pi*t_test/p.P - 5.30);
    fprintf('Inlet T:   max err vs Eq.26 = %.4f degC\n', max(abs(T_in - T_in_ref)));
    
    % Check extrema timing
    [~, imin] = min(T_surf); [~, imax] = max(T_surf);
    fprintf('Surface min at day %.1f, max at day %.1f (expected ~200, ~20)\n', ...
        t_test(imin)/86400, t_test(imax)/86400);
    [~, imin] = min(T_in); [~, imax] = max(T_in);
    fprintf('Inlet   min at day %.1f, max at day %.1f\n', ...
        t_test(imin)/86400, t_test(imax)/86400);
end

function [t_day, Tout, Tin, Th] = extractSecondYear(p, res)
    P = p.P;
    idx = (res.t > P) & (res.t <= 2*P);
    t_day = (res.t(idx) - P)/86400;
    Tout = res.Tout(idx);
    Tin = res.Tin(idx);
    Th = res.Th(idx);
end

function idx = idx_year2(p, res)
    P = p.P;
    idx = (res.t > P) & (res.t <= 2*P);
end

%% ==================== Core Solver (Unchanged Logic) ====================

function result = simulateEAHE_case(p, delta, phi, modelType)
    dx = p.L/p.Nx;
    t = 0:p.dt:p.tEnd;
    Nt = numel(t);
    Nx = p.Nx;

    Rnet = radialThermalNetwork(p, delta, phi, modelType);
    Tin = inletTemperature(p, t);
    Th = undisturbedSoilTemperature(p, p.H, t);
    Glag = buildSoilResponseKernel(p, Rnet.rg, Nx, dx, Nt);

    Tf = zeros(Nx, Nt); Tp = zeros(Nx, Nt); Tg = zeros(Nx, Nt); qg = zeros(Nx, Nt);
    picardIter = zeros(1, Nt); picardResidual = nan(1, Nt);

    Tf(:,1) = Th(1); Tp(:,1) = Th(1); Tg(:,1) = Th(1);

    for m = 2:Nt
        qTrial = qg(:,m-1); resNorm = inf;
        for it = 1:p.picardMaxIter
            TgNow = soilBoundaryTemperature(p, qg, qTrial, m, Glag, Th(m));
            [~, TpNew] = solveAirPipeImplicitStep(p, Tf(:,m-1), Tp(:,m-1), ...
                TgNow, Tin(m), Rnet.Rp1, Rnet.Rdelta);
            qNew = (TpNew - TgNow)/Rnet.Rdelta;
            denom = max(1, max(abs(qNew)));
            resNorm = max(abs(qNew - qTrial))/denom;
            qTrial = p.picardRelax*qNew + (1-p.picardRelax)*qTrial;
            if resNorm < p.picardTol, break; end
        end
        picardIter(m) = it; picardResidual(m) = resNorm;
        Tg(:,m) = soilBoundaryTemperature(p, qg, qTrial, m, Glag, Th(m));
        [Tf(:,m), Tp(:,m)] = solveAirPipeImplicitStep(p, Tf(:,m-1), Tp(:,m-1), ...
            Tg(:,m), Tin(m), Rnet.Rp1, Rnet.Rdelta);
        qg(:,m) = (Tp(:,m) - Tg(:,m))/Rnet.Rdelta;
    end

    Tout = Tf(end,:);
    Qair = p.mdot*p.cp_f*(Tin - Tout);
    E_cool = trapz(t, max(Qair,0))/3.6e6;
    E_heat = trapz(t, max(-Qair,0))/3.6e6;

    result = struct('t',t, 'day',t/86400, 'Tin',Tin, 'Th',Th, 'Tf',Tf, 'Tp',Tp, ...
        'Tg',Tg, 'qg',qg, 'Tout',Tout, 'Qair',Qair, 'E_cool',E_cool, 'E_heat',E_heat, ...
        'picardIter',picardIter, 'picardResidual',picardResidual, 'Rnet',Rnet);
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
        Rgap = 0; Rdelta = Rp2; rg = p.rpo;
    else
        if delta <= 0
            Rgap = 0; rg = p.rpo;
        else
            Rgap = p.beta_gap*log(rg/p.rpo)/(2*pi*p.k_air);
        end
        phi = min(max(phi,0),1); chi = 1 - phi;
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

    Rnet = struct('hi',hi, 're',re, 'rg',rg, 'Rconv',Rconv, 'Rcond_inner',Rcond_inner, ...
        'Rcond_outer',Rcond_outer, 'Rp1',Rp1, 'Rp2',Rp2, 'Rgap',Rgap, ...
        'Rcontact',Rcontact, 'Rdelta',Rdelta, 'Rint_eff',Rdelta-Rp2, 'phi_gap',phi, 'chi_contact',1-phi);
end

function hi = internalConvectionCoefficient(p)
    if ~p.useHiCorrelation
        hi = p.hi_const;
    else
        D = 2*p.rpi; u = p.Vdot/(pi*p.rpi^2);
        Re = p.rho_f*u*D/p.mu_f; Pr = p.mu_f*p.cp_f/p.k_air;
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

%% ==================== SOIL KERNELS (Modified) ====================

function Glag = buildSoilResponseKernel(p, r, Nx, dx, Nt)
    kernelType = upper(string(p.soilKernelType));
    switch kernelType
        case {"ILS", "CYLINDER"}
            % 纯径向响应（轴向均匀）
            Glag = zeros(1,Nt);
            for k = 1:Nt
                tau = (k-1)*p.dt;
                if kernelType == "ILS"
                    Glag(k) = soilResponseKernel_ILS(p, r, tau);
                else
                    Glag(k) = soilResponseKernel_Cylinder(p, r, tau);
                end
            end
        case {"FLS", "CYLINDER_FLS"}
            % 有限线源轴向修正
            Glag = zeros(Nx,Nt);
            zEval = ((1:Nx).' - 0.5)*dx;
            zSrc = linspace(0, p.L, p.flsQuadN);
            for k = 1:Nt
                tau = (k-1)*p.dt;
                if kernelType == "FLS"
                    Gbase = soilResponseKernel_ILS(p, r, tau);
                else
                    Gbase = soilResponseKernel_Cylinder(p, r, tau);
                end
                Gfls = soilResponseKernel_FLS(p, r, tau, zEval, zSrc);
                if Gbase > 0
                    corr = min(max(Gfls/Gbase, 0), 1);
                    Glag(:,k) = Gbase*corr;
                else
                    Glag(:,k) = Gfls;
                end
            end
        otherwise
            error('Unknown soilKernelType: %s', p.soilKernelType);
    end
end

% --- 经典线源核（原始代码保留）---
function G = soilResponseKernel_ILS(p, r, tau)
    if tau <= 0, tau = p.dt/2; end
    x = r^2/(4*p.alpha_s*tau);
    G = (1/(4*pi))*expint(x);
end

% --- 有限线源核（原始代码保留）---
function G = soilResponseKernel_FLS(p, r, tau, zEval, zSrc)
    if tau <= 0, tau = p.dt/2; end
    G = zeros(numel(zEval),1);
    for i = 1:numel(zEval)
        s = zSrc - zEval(i);
        dist = sqrt(r^2 + s.^2);
        arg = dist./sqrt(4*p.alpha_s*tau);
        integrand = erfc(arg)./dist;
        G(i) = trapz(zSrc, integrand)/(4*pi);
    end
end

% --- 新增：文献 Eq.(9) 圆柱精确解 ---
function G = soilResponseKernel_Cylinder(p, r, tau)
    % T(r,t) = T_Ground + q_po/k_s * G(r,t)
    % 基于 Carslaw & Jaeger 圆柱源精确解（Minaei Eq.9）
    if tau <= 0
        G = 0;
        return
    end
    
    rpo = p.rpo;            % 管道外半径 [m]
    alpha = p.alpha_s;      % 土壤热扩散系数
    Fo = alpha * tau / rpo^2;   % Fourier 数（无量纲时间）
    rho = r / rpo;          % 无量纲径向距离
    
    % 极早期（Fo < 1e-4）：线源近似足够准确，避免 Bessel 积分困难
    if Fo < 1e-4
        G = (1/(4*pi)) * expint(r^2/(4*alpha*tau));
        return
    end
    
    % 数值积分：文献 Eq.(9)
    % 被积函数在 phi->0 时趋于 0，在 phi->inf 时指数衰减
    % 积分上限根据 Fourier 数确定
    phiMax = max(300, sqrt(25/Fo));
    
    % 使用 MATLAB integral 进行自适应积分
    % 注意：被积函数在 phi~0 处行为良好（极限为0），但为避开数值奇点从极小值开始
    G = integral(@(phi) cylinderIntegrand(phi, rho, Fo), 1e-10, phiMax, ...
        'RelTol', 1e-5, 'AbsTol', 1e-8, 'Waypoints', logspace(-2, 1, 20));
    
    % 确保物理非负（数值误差可能导致极小负值）
    G = max(G, 0);
end

function val = cylinderIntegrand(phi, rho, Fo)
    % 文献 Eq.(9) 被积函数
    % G = (1/pi^2) * integral[ (exp(-phi^2*Fo) - 1) / (J1^2 + Y1^2) * 
    %       (J0(rho*phi)*Y1(phi) - J1(phi)*Y0(rho*phi)) / phi^2 ] dphi
    
    J1 = besselj(1, phi);
    Y1 = bessely(1, phi);
    denom = J1.^2 + Y1.^2;
    
    J0r = besselj(0, phi*rho);
    Y0r = bessely(0, phi*rho);
    
    % Bessel 组合：注意符号
    besselCombo = J0r .* Y1 - J1 .* Y0r;
    
    % (exp(-phi^2*Fo) - 1) 为负，besselCombo 在 phi->0 时为负，负负得正
    numer = (exp(-phi.^2 .* Fo) - 1) .* besselCombo;
    val = (1/pi^2) * numer ./ (denom .* phi.^2);
    
    % 清理数值异常
    val(isnan(val) | isinf(val)) = 0;
end

%% ==================== Solver & Post-processing ====================

function TgNow = soilBoundaryTemperature(p, qgHist, qTrial, m, Glag, ThNow)
    Nx = p.Nx;
    if m <= 1
        TgNow = ThNow*ones(Nx,1);
        return
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
    Nx = p.Nx; dx = p.L/Nx; dt = p.dt;
    M = p.mdot*p.cp_f/dx;
    A = sparse(2*Nx, 2*Nx);
    b = zeros(2*Nx, 1);
    for i = 1:Nx
        row = i; iF = i; iP = Nx+i;
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
        row = Nx+i; iF = i; iP = Nx+i;
        A(row,iP) = p.Cp/dt + 1/Rp1 + 1/Rdelta;
        A(row,iF) = -1/Rp1;
        b(row) = p.Cp/dt*TpOld(i) + Tg(i)/Rdelta;
    end
    x = A\b;
    TfNew = x(1:Nx);
    TpNew = x(Nx+1:end);
end

function saveFigure(fig, outDir, baseName)
    pngPath = fullfile(outDir, [baseName '.png']);
    try
        exportgraphics(fig, pngPath, 'Resolution', 300);
    catch
        print(fig, pngPath, '-dpng', '-r300');
    end
    close(fig);
end