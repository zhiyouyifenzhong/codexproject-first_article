 %% EAHE_airgap_physical_modules_v17_review_ready.m
% -------------------------------------------------------------------------
% 题目：考虑管土空气隙界面热阻的土壤空气换热器 EAHE 瞬态传热模型
% 版本：v17_review_ready
%
% 写法说明：
% 本脚本不是 CFD/FEM。它把 EAHE 沿轴向离散为若干一维单元，
% 每个单元包含“空气节点 Tf”和“管壁节点 Tp”，土壤边界温度 Tg
% 由年周期未扰动地温 + 土壤热响应叠加得到。
%
% 物理传热模块对应关系：
%   模块 0：参数系统                         -> 几何、材料、运行与数值参数
%   模块 1：入口空气边界                     -> Tin(t)
%   模块 2：未扰动土壤温度                   -> Th(H,t)
%   模块 3：管内对流换热                     -> Rconv, hi
%   模块 4：管壁径向导热                     -> Rp1, Rp2
%   模块 5：管土空气隙界面热阻               -> Rgap, Rdelta, TintJump
%   模块 6：土壤热扩散响应                   -> ILS 响应核 G(t)
%   模块 7：空气-管壁-土壤耦合瞬态求解        -> 隐式欧拉 + 轴向上风
%   模块 8：性能评价                         -> Tout, Q, E, Dgap, eta_U, Lratio
%   模块 9：模型验证                         -> 退化、极限、能量守恒、离散无关性
%   模块10：图表输出                         -> 论文用图、CSV 表格和 Excel 工作簿
%
% 主要变量符号：
%   delta  : 空气隙厚度, m
%   phi    : 空气隙覆盖率；phi=1 为完整环形空气隙，phi<1 为局部空气隙
%   chi    : 接触系数, chi=1-phi；chi=1 为完全接触，chi=0 为完整脱空
%   Rgap   : 单位长度空气隙热阻, m*K/W
%   Rdelta : 管壁节点到土壤边界节点之间的等效单位长度热阻, m*K/W
%   qg     : 单位长度进入土壤的热流, W/m；qg>0 表示管道向土壤放热
%   Qair   : 空气侧总换热量, W；Qair>0 表示空气被冷却
%
% 适用版本：MATLAB R2016b 及以上版本。脚本末尾使用局部函数。
% -------------------------------------------------------------------------

clear; clc; close all;

%% ========================================================================
% 模块 0：参数系统与总控开关
% ========================================================================
p = defaultParams();
opt = defaultOptions();

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir); scriptDir = pwd; end
outDir = fullfile(scriptDir, 'EAHE_airgap_physical_v17_review_ready_results');
if ~exist(outDir, 'dir'); mkdir(outDir); end

if strcmpi(getenv('EAHE_RUN_COMSOL_CALIBRATION'), '1')
    run_comsol_parameter_calibration(p, outDir);
    return;
end
if strcmpi(getenv('EAHE_RUN_COMSOL_CURRENT_COMPARE'), '1')
    run_current_matlab_comsol_comparison(p, outDir);
    return;
end

fprintf('\n============================================================\n');
fprintf('EAHE air-gap interface thermal resistance model v16\n');
fprintf('L = %.2f m, Nx = %d, dt = %.2f h, nYears = %d\n', ...
    p.L, p.Nx, p.dt/3600, p.nYears);
fprintf('Output folder: %s\n', outDir);
fprintf('============================================================\n\n');

%% ========================================================================
% 模块 1-8：主工况计算 —— 空气隙厚度扫描
% ========================================================================
% deltaList_mm 可以根据论文需要修改，例如 [0 0.2 0.5 1 2 3 5]。
deltaList_mm = [0 0.5 1 2 3 5];
phiBase = 1.0;          % phi=1 表示完整环形空气隙，代表最不利接触状态

res = cell(numel(deltaList_mm),1);
for k = 1:numel(deltaList_mm)
    delta = deltaList_mm(k)*1e-3;
    fprintf('Running case %d/%d: delta = %.3f mm, phi = %.2f ...\n', ...
        k, numel(deltaList_mm), deltaList_mm(k), phiBase);
    res{k} = simulateEAHE_case(p, delta, phiBase, 'AIRGAP');
end

%% ========================================================================
% 模块 9：模型验证与数值可靠性分析
% ========================================================================
fprintf('\n==================== Model validation modules ====================\n');

T_degeneration = validation_degeneration(p, outDir);
T_limits       = validation_interface_limits(p, outDir);
T_energy       = validation_energy_balance(res, deltaList_mm, outDir);
T_Nx = table();
T_dt = table();

if opt.runNxIndependence
    T_Nx = validation_Nx_independence(p, 1e-3, phiBase, outDir);
else
    fprintf('Nx independence study skipped. Set opt.runNxIndependence = true to run.\n');
end

if opt.runDtIndependence
    T_dt = validation_dt_independence(p, 1e-3, phiBase, outDir);
else
    fprintf('dt independence study skipped. Set opt.runDtIndependence = true to run.\n');
end

%% ========================================================================
% 模块 8 与 10：性能评价、工程修正指标和图表输出
% ========================================================================
T_summary = build_summary_table(res, deltaList_mm);
writetable(T_summary, fullfile(outDir, 'Table_01_main_performance_summary.csv'));
writetable(T_degeneration, fullfile(outDir, 'Table_02_degeneration_validation.csv'));
writetable(T_limits, fullfile(outDir, 'Table_03_interface_limit_validation.csv'));
writetable(T_energy, fullfile(outDir, 'Table_04_energy_balance_validation.csv'));

if opt.makePlots
    plot_model_method_figures(p, outDir);
    plot_main_results(res, deltaList_mm, outDir);
    plot_resistance_and_engineering(p, deltaList_mm, phiBase, outDir);
    plot_summary_figures(res, deltaList_mm, p, phiBase, outDir);
    plot_independence_results(T_Nx, T_dt, outDir);
end

T_figcheck = review_figure_checklist(outDir);
writetable(T_figcheck, fullfile(outDir, 'Table_06_review_figure_checklist.csv'));
export_origin_ready_data(outDir, res, deltaList_mm, T_Nx, T_dt, p, phiBase);

if opt.exportExcel
    export_review_excel(outDir, p, res, deltaList_mm, T_summary, T_degeneration, ...
        T_limits, T_energy, T_Nx, T_dt, T_figcheck);
end

save(fullfile(outDir, 'EAHE_airgap_physical_v17_review_ready_results.mat'), ...
    'p', 'opt', 'deltaList_mm', 'phiBase', 'res', ...
    'T_summary', 'T_degeneration', 'T_limits', 'T_energy', ...
    'T_Nx', 'T_dt', 'T_figcheck', '-v7.3');

fprintf('\nCalculation finished. Results saved in: %s\n', outDir);
disp(T_summary);

%% ========================================================================
%%                         局部函数区：参数与选项
%% ========================================================================

function p = defaultParams()
    % defaultParams
    % ---------------------------------------------------------------------
    % 模块 0：集中定义几何、材料、运行和数值参数。
    % 后续论文使用时，建议把“基准参数表”与这里保持一致。
    % ---------------------------------------------------------------------

    p = struct();

    % ---------------------------- 几何参数 -------------------------------
    p.L     = 30.0;          % 管长, m
    p.Nx    = 80;            % 轴向离散单元数
    p.rpi   = 0.055;         % 管内半径, m
    p.rpo   = 0.060;         % 管外半径, m
    p.H     = 2.0;           % 管中心埋深, m
    p.rs    = 1.50;          % 工程总热阻计算中的土壤热影响半径, m

    % ---------------------------- 管材参数 -------------------------------
    p.kp    = 0.40;          % 管材导热系数, W/(m*K)
    p.rho_p = 1400;          % 管材密度, kg/m3
    p.cp_p  = 900;           % 管材比热, J/(kg*K)

    % ---------------------------- 空气参数 -------------------------------
    p.k_air = 0.026;         % 空气导热系数, W/(m*K)
    p.rho_f = 1.20;          % 空气密度, kg/m3
    p.cp_f  = 1006;          % 空气定压比热, J/(kg*K)
    p.mu_f  = 1.81e-5;       % 空气动力黏度, Pa*s
    p.Vdot  = 0.050;         % 体积流量, m3/s
    p.mdot  = p.rho_f*p.Vdot;% 质量流量, kg/s

    % 管内对流换热系数设置。
    % 若 p.useHiCorrelation=true，则由 Reynolds 数和 Nusselt 数关联式计算；
    % 若为 false，则直接使用 p.hi_const。
    p.useHiCorrelation = true;
    p.hi_const = 12.0;       % 固定管内换热系数, W/(m2*K)
    p.hi_scale = 1.0;        % COMSOL calibration scale for internal convection

    % ---------------------------- 土壤参数 -------------------------------
    p.ks    = 1.50;          % 土壤导热系数, W/(m*K)
    p.rho_s = 1800;          % 土壤密度, kg/m3
    p.cp_s  = 1200;          % 土壤比热, J/(kg*K)
    p.alpha_s = p.ks/(p.rho_s*p.cp_s); % 土壤热扩散率, m2/s
    p.soil_response_scale = 1.0; % COMSOL calibration scale for soil response
    p.beta_gap = 1.0;        % COMSOL calibration multiplier for full air-gap resistance

    % ---------------------------- 年周期边界 -----------------------------
    p.P      = 365*24*3600;  % 年周期, s
    p.Tm     = 19.2;         % 年平均地表温度, degC
    p.Asurf  = 8.0;          % 地表温度年振幅, degC
    p.t0     = 30*24*3600;   % 地表温度相位, s

    % 入口空气温度：示例采用正弦年周期，可替换为实测逐时/逐日数据。
    p.Tin_mean      = 20.35; % 入口空气平均温度, degC
    p.Tin_amp       = 5.65;  % 入口空气年振幅, degC
    p.Tin_phase_day = 35;    % 入口温度峰值相位, day

    % ---------------------------- 数值参数 -------------------------------
    p.dt      = 6*3600;      % 时间步长, s
    p.nYears  = 1;           % 年度对比默认与 COMSOL 一致：0-365 day 单年瞬态
    p.tEnd    = p.nYears*p.P;% 总模拟时长, s
    p.nPicard = 3;           % 兼容旧版本的默认 Picard 迭代次数
    p.picardMaxIter = 20;    % 土壤边界温度与热流耦合的最大 Picard 迭代次数
    p.picardTol = 1e-4;      % Picard 相对收敛阈值
    p.picardRelax = 0.6;     % Picard 欠松弛系数
    p.Qref    = 1.0;         % 能量残差归一化参考功率, W
    p.soilKernelType = 'FLS'; % 'ILS' or 'FLS'; FLS applies finite-length correction
    p.flsQuadN = 121;        % quadrature points for finite line-source correction

    % ---------------------------- 单位长度热容 ---------------------------
    p.Af = pi*p.rpi^2;                   % 管内空气流通面积, m2
    p.Ap = pi*(p.rpo^2 - p.rpi^2);       % 管壁截面积, m2
    p.Cf = p.rho_f*p.Af*p.cp_f;          % 单位长度空气热容, J/(m*K)
    p.Cp = p.rho_p*p.Ap*p.cp_p;          % 单位长度管壁热容, J/(m*K)
end

function opt = defaultOptions()
    % defaultOptions
    % ---------------------------------------------------------------------
    % 模块 0：控制是否运行耗时较长的无关性分析。
    % 首次运行建议保持 false；论文定稿时再改为 true。
    % ---------------------------------------------------------------------
    opt = struct();
    opt.makePlots = true;
    opt.exportExcel = true;
    opt.runNxIndependence = true;
    opt.runDtIndependence = true;
end

%% ========================================================================
%%                         局部函数区：主求解器
%% ========================================================================

function result = simulateEAHE_case(p, delta, phi, modelType)
    % simulateEAHE_case
    % ---------------------------------------------------------------------
    % 模块 1-8 的总入口。
    % modelType = 'AIRGAP'：本文模型，允许 delta 和 phi 起作用；
    % modelType = 'M0'    ：原始完全接触模型，不加入空气隙界面热阻。
    % ---------------------------------------------------------------------

    dx = p.L/p.Nx;
    t  = 0:p.dt:p.tEnd;
    Nt = numel(t);
    Nx = p.Nx;

    % 模块 3-5：计算管内对流、管壁导热、空气隙界面热阻。
    Rnet = radialThermalNetwork(p, delta, phi, modelType);

    % 模块 1：入口温度边界 Tin(t)。
    Tin = inletTemperature(p, t);

    % 模块 2：埋深 H 处未扰动土壤温度 Th(H,t)。
    Th = undisturbedSoilTemperature(p, p.H, t);

    % 状态量矩阵：每一列代表一个时间步，每一行代表一个轴向单元。
    Tf = zeros(Nx,Nt);   % 管内空气温度, degC
    Tp = zeros(Nx,Nt);   % 管壁等效节点温度, degC
    Tg = zeros(Nx,Nt);   % 土壤边界温度, degC
    qg = zeros(Nx,Nt);   % 进入土壤的单位长度热流, W/m
    picardIterFull = zeros(1,Nt);
    picardResidualFull = NaN(1,Nt);

    % 初始条件：系统初始处于未扰动土壤温度。
    Tf(:,1) = Th(1);
    Tp(:,1) = Th(1);
    Tg(:,1) = Th(1);

    % 模块 6：预计算土壤响应核 G(tau)。
    Glag = buildSoilResponseKernel(p, Rnet.rg, Nx, dx, Nt);

    % 模块 7：时间推进，隐式欧拉 + 轴向上风格式。
    for m = 2:Nt
        qTrial = qg(:,m-1);
        picardResidual = NaN;

        % Picard 迭代：土壤边界温度 Tg 依赖热流历史，热流又依赖 Tg。
        for it = 1:p.picardMaxIter
            TgNow = soilBoundaryTemperature(p, qg, qTrial, m, Glag, Th(m));
            [~, TpNew] = solveAirPipeImplicitStep( ...
                p, Tf(:,m-1), Tp(:,m-1), TgNow, Tin(m), Rnet.Rp1, Rnet.Rdelta);
            qNew = (TpNew - TgNow)/Rnet.Rdelta;

            % 欠松弛用于增强稳定性。
            qOld = qTrial;
            qTrial = p.picardRelax*qNew + (1-p.picardRelax)*qTrial;
            picardResidual = max(abs(qTrial-qOld))/max(max(abs(qTrial)), p.Qref);
            if picardResidual < p.picardTol
                break;
            end
        end
        picardIterFull(m) = it;
        picardResidualFull(m) = picardResidual;

        Tg(:,m) = soilBoundaryTemperature(p, qg, qTrial, m, Glag, Th(m));
        [Tf(:,m), Tp(:,m)] = solveAirPipeImplicitStep( ...
            p, Tf(:,m-1), Tp(:,m-1), Tg(:,m), Tin(m), Rnet.Rp1, Rnet.Rdelta);
        qg(:,m) = (Tp(:,m)-Tg(:,m))/Rnet.Rdelta;
    end

    % 模块 8：空气侧换热量、土壤侧热流、储热项与能量残差。
    ToutFull = Tf(end,:);
    QairFull = p.mdot*p.cp_f*(Tin - ToutFull);  % W；正值表示空气被冷却
    QsoilFull = sum(qg,1)*dx;                   % W；正值表示管道向土壤放热

    QstoreFull = zeros(1,Nt);
    QstoreFull(2:end) = sum( ...
        p.Cf*(Tf(:,2:end)-Tf(:,1:end-1))/p.dt + ...
        p.Cp*(Tp(:,2:end)-Tp(:,1:end-1))/p.dt, 1)*dx;

    epsQFull = abs(QairFull - QsoilFull - QstoreFull)./max(abs(QairFull),p.Qref);

    % 取最后一年作为评价期，避免初始条件对结果的影响。
    startEval = p.tEnd - p.P;
    idxEval = find(t > startEval & t <= p.tEnd);
    tEval = t(idxEval) - t(idxEval(1));

    TinE = Tin(idxEval);
    ThE  = Th(idxEval);
    TfE  = Tf(:,idxEval);
    TpE  = Tp(:,idxEval);
    TgE  = Tg(:,idxEval);
    qgE  = qg(:,idxEval);
    ToutE = ToutFull(idxEval);
    Qair = QairFull(idxEval);
    Qsoil = QsoilFull(idxEval);
    Qstore = QstoreFull(idxEval);
    epsQ = epsQFull(idxEval);
    epsQ(1) = NaN;  % 去除年度切片首点的离散残差伪影。
    picardIter = picardIterFull(idxEval);
    picardResidual = picardResidualFull(idxEval);

    % 模块 5：界面温度跳跃。
    % 对完整环形空气隙：TintJump = qg*Rgap。
    % 对局部空气隙：这里表示空气隙分支的特征温度跳跃。
    TintJump = qgE*Rnet.Rgap;

    % 模块 8：年冷却量、预热量和绝对换热量。
    E_cool = trapz(tEval, max(Qair,0))/3.6e6;    % kWh
    E_heat = trapz(tEval, max(-Qair,0))/3.6e6;   % kWh
    E_abs  = trapz(tEval, abs(Qair))/3.6e6;      % kWh

    Reng = engineeringResistances(p, delta, phi);

    result = struct();
    result.t = tEval;
    result.day = tEval/86400;
    result.Tin = TinE;
    result.Th = ThE;
    result.Tf = TfE;
    result.Tp = TpE;
    result.Tg = TgE;
    result.Tout = ToutE;
    result.qg = qgE;
    result.Qair = Qair;
    result.Qsoil = Qsoil;
    result.Qstore = Qstore;
    result.epsQ = epsQ;
    result.picardIter = picardIter;
    result.picardResidual = picardResidual;
    result.TintJump = TintJump;

    result.t_full = t;
    result.day_full = t/86400;
    result.Tout_full = ToutFull;
    result.Qair_full = QairFull;

    result.delta = delta;
    result.phi = phi;
    result.chi = 1-phi;
    result.modelType = modelType;
    result.Rnet = Rnet;
    result.Reng = Reng;
    result.Rgap = Rnet.Rgap;
    result.Rdelta = Rnet.Rdelta;
    result.E_cool = E_cool;
    result.E_heat = E_heat;
    result.E_abs  = E_abs;
end

function Rnet = radialThermalNetwork(p, delta, phi, modelType)
    % radialThermalNetwork
    % ---------------------------------------------------------------------
    % 模块 3：管内对流热阻
    % 模块 4：管壁径向导热热阻
    % 模块 5：空气隙界面热阻
    %
    % 物理路径：
    %   Tf -- Rconv + Rcond_inner --> Tp -- Rp2 + Rgap --> Tg
    % ---------------------------------------------------------------------

    hi = internalConvectionCoefficient(p);

    re = sqrt((p.rpi^2 + p.rpo^2)/2);      % 管壁等效节点半径
    rg = p.rpo + max(delta,0);             % 空气隙外边界半径

    Rconv = 1/(2*pi*p.rpi*hi);
    Rcond_inner = log(re/p.rpi)/(2*pi*p.kp);
    Rcond_outer = log(p.rpo/re)/(2*pi*p.kp);

    Rp1 = Rconv + Rcond_inner;             % 空气节点到管壁节点热阻
    Rp2 = Rcond_outer;                     % 管壁节点到管外壁热阻

    if strcmpi(modelType,'M0') || delta <= 0
        Rgap = 0;
        Rdelta = Rp2;
        rg = p.rpo;
    else
        Rgap_full = p.beta_gap*log(rg/p.rpo)/(2*pi*p.k_air);

        % 局部空气隙的动态等效：
        % phi 为空气隙覆盖率，接触系数 chi=1-phi。
        % 周向 chi 部分直接接触 Rp2，1-chi 部分通过 Rp2+Rgap_full，近似并联。
        if phi <= 0
            Rgap = 0;
            Rdelta = Rp2;
        elseif phi >= 1
            Rgap = Rgap_full;
            Rdelta = Rp2 + Rgap_full;
        else
            Rgap = Rgap_full;
            Gdelta = (1-phi)/Rp2 + phi/(Rp2 + Rgap_full);
            Rdelta = 1/Gdelta;
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
    Rnet.Rdelta = Rdelta;
    Rnet.phi_gap = phi;
    Rnet.chi_contact = 1-phi;
end

function hi = internalConvectionCoefficient(p)
    % internalConvectionCoefficient
    % ---------------------------------------------------------------------
    % 模块 3：管内强迫对流换热系数。
    % 层流采用 Nu=3.66；湍流采用 Gnielinski 关联式。
    % 若 p.useHiCorrelation=false，则直接使用 p.hi_const。
    % ---------------------------------------------------------------------

    if ~p.useHiCorrelation
        hi = p.hi_const*p.hi_scale;
        return;
    end

    D = 2*p.rpi;
    u = p.Vdot/(pi*p.rpi^2);
    Re = p.rho_f*u*D/p.mu_f;
    Pr = p.mu_f*p.cp_f/p.k_air;

    if Re < 2300
        Nu = 3.66;
    else
        f = (0.79*log(Re) - 1.64)^(-2);
        Nu = ((f/8)*(Re-1000)*Pr) / ...
             (1 + 12.7*sqrt(f/8)*(Pr^(2/3)-1));
    end

    hi = Nu*p.k_air/D;
    hi = hi*p.hi_scale;
end

function T = inletTemperature(p, t)
    % inletTemperature
    % ---------------------------------------------------------------------
    % 模块 1：入口空气温度边界。
    % 当前采用年周期正弦形式；有实测数据时，可在此函数中改为插值。
    % ---------------------------------------------------------------------
    phase = p.Tin_phase_day*86400;
    T = p.Tin_mean + p.Tin_amp*cos(2*pi*(t-phase)/p.P);
end

function T = undisturbedSoilTemperature(p, h, t)
    % undisturbedSoilTemperature
    % ---------------------------------------------------------------------
    % 模块 2：未扰动土壤温度。
    % 地表年周期温度向下传播时，振幅随深度指数衰减，且相位滞后。
    % ---------------------------------------------------------------------
    beta = sqrt(pi/(p.P*p.alpha_s));
    T = p.Tm - p.Asurf*exp(-h*beta).* ...
        cos(2*pi/p.P*(t - p.t0 - h/2*sqrt(p.P/(pi*p.alpha_s))));
end

function G = soilResponseKernel_ILS(p, r, tau)
    % soilResponseKernel_ILS
    % ---------------------------------------------------------------------
    % 模块 6：土壤热扩散响应核。
    % 采用无限线热源 ILS 响应：DeltaT = q'/ks * G。
    % G = 1/(4*pi) * E1(r^2/(4*alpha*tau))。
    % ---------------------------------------------------------------------
    % 离散卷积中 tau=0 对应当前时间步的自响应。直接令 G(0)=0
    % 会把当前步热流变化完全滞后一拍；这里采用中点近似 tau=dt/2。
    if tau <= 0
        tau = p.dt/2;
    end
    x = r^2/(4*p.alpha_s*tau);
    G = (1/(4*pi))*expint(x);
end

function Glag = buildSoilResponseKernel(p, r, Nx, dx, Nt)
    % buildSoilResponseKernel
    % ILS returns a 1-by-Nt kernel. FLS returns an Nx-by-Nt kernel whose rows
    % include finite pipe-length correction factors for each axial cell.

    kernelType = upper(string(p.soilKernelType));
    switch kernelType
        case "ILS"
            Glag = zeros(1,Nt);
            for k = 1:Nt
                tau = (k-1)*p.dt;
                Glag(k) = soilResponseKernel_ILS(p, r, tau);
            end
        case "FLS"
            Glag = zeros(Nx,Nt);
            zEval = ((1:Nx).' - 0.5)*dx;
            zSrc = linspace(0, p.L, p.flsQuadN);
            for k = 1:Nt
                tau = (k-1)*p.dt;
                Gils = soilResponseKernel_ILS(p, r, tau);
                Gfls = soilResponseKernel_FLS_finite_length(p, r, tau, zEval, zSrc);
                if Gils > 0
                    corr = min(max(Gfls/Gils, 0), 1);
                    Glag(:,k) = Gils*corr;
                else
                    Glag(:,k) = Gfls;
                end
            end
        otherwise
            error('Unknown soilKernelType: %s. Use ILS or FLS.', p.soilKernelType);
    end
end

function G = soilResponseKernel_FLS_finite_length(p, r, tau, zEval, zSrc)
    % soilResponseKernel_FLS_finite_length
    % Dimensionless finite line-source step response. It is used here as a
    % finite-length correction to the local ILS Duhamel kernel.
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
    % soilBoundaryTemperature
    % ---------------------------------------------------------------------
    % 模块 6：土壤边界温度。
    % Tg = Th + DeltaTdist。
    % DeltaTdist 由历史热流增量 dq 通过 Duhamel 叠加得到。
    % ---------------------------------------------------------------------

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
    % solveAirPipeImplicitStep
    % ---------------------------------------------------------------------
    % 模块 7：空气-管壁耦合方程。
    %
    % 空气节点：
    % Cf dTf_i/dt = mdot*cp/dx*(Tf_{i-1}-Tf_i) + (Tp_i-Tf_i)/Rp1
    %
    % 管壁节点：
    % Cp dTp_i/dt = (Tf_i-Tp_i)/Rp1 + (Tg_i-Tp_i)/Rdelta
    %
    % 离散方法：时间上隐式欧拉，轴向上风格式。
    % ---------------------------------------------------------------------

    Nx = p.Nx;
    dx = p.L/Nx;
    dt = p.dt;
    M = p.mdot*p.cp_f/dx;

    A = sparse(2*Nx,2*Nx);
    b = zeros(2*Nx,1);

    % ---------------------------- 空气节点方程 ---------------------------
    for i = 1:Nx
        row = i;
        iF = i;
        iP = Nx + i;

        A(row,iF) = p.Cf/dt + M + 1/Rp1;
        A(row,iP) = -1/Rp1;
        b(row) = p.Cf/dt*TfOld(i);

        if i == 1
            b(row) = b(row) + M*Tin;
        else
            A(row,iF-1) = -M;
        end
    end

    % ---------------------------- 管壁节点方程 ---------------------------
    for i = 1:Nx
        row = Nx + i;
        iF = i;
        iP = Nx + i;

        A(row,iP) = p.Cp/dt + 1/Rp1 + 1/Rdelta;
        A(row,iF) = -1/Rp1;
        b(row) = p.Cp/dt*TpOld(i) + Tg(i)/Rdelta;
    end

    x = A\b;
    TfNew = x(1:Nx);
    TpNew = x(Nx+1:end);
end

%% ========================================================================
%%                         局部函数区：工程热阻与评价
%% ========================================================================

function R = engineeringResistances(p, delta, phi)
    % engineeringResistances
    % ---------------------------------------------------------------------
    % 模块 8：工程总热阻与修正指标。
    % 该模块用于解释空气隙对总传热能力的削弱，独立于瞬态求解器。
    %
    % Rtot0   : 完全接触时总热阻
    % RtotGap : 完整环形空气隙时总热阻
    % RtotPhi : 局部空气隙覆盖率 phi 下的并联等效总热阻
    % etaU    : 传热能力修正系数 = Rtot0/RtotPhi
    % Lratio  : 有效管长修正系数 = RtotPhi/Rtot0
    % ---------------------------------------------------------------------

    rg = p.rpo + max(delta,0);
    hi = internalConvectionCoefficient(p);

    Ra  = 1/(2*pi*p.rpi*hi);
    Rp  = log(p.rpo/p.rpi)/(2*pi*p.kp);
    Rs0 = log(p.rs/p.rpo)/(2*pi*p.ks);

    if delta <= 0
        Rgap = 0;
    else
        Rgap = p.beta_gap*log(rg/p.rpo)/(2*pi*p.k_air);
    end

    Rsg = log(p.rs/rg)/(2*pi*p.ks);
    Rtot0 = Ra + Rp + Rs0;
    RtotGap = Ra + Rp + Rgap + Rsg;

    if phi <= 0 || delta <= 0
        RtotPhi = Rtot0;
    elseif phi >= 1
        RtotPhi = RtotGap;
    else
        RtotPhi = 1/((1-phi)/Rtot0 + phi/RtotGap);
    end

    R = struct();
    R.Ra = Ra;
    R.Rp = Rp;
    R.Rs0 = Rs0;
    R.Rgap = Rgap;
    R.Rsg = Rsg;
    R.Rtot0 = Rtot0;
    R.RtotGap = RtotGap;
    R.RtotPhi = RtotPhi;
    R.Rint_eff = RtotPhi - Rtot0;
    R.etaU = Rtot0/RtotPhi;
    R.Lratio = RtotPhi/Rtot0;
    R.phi_gap = phi;
    R.chi_contact = 1-phi;
end

function T = build_summary_table(res, deltaList_mm)
    % build_summary_table
    % ---------------------------------------------------------------------
    % 模块 8：将每个空气隙工况的出口温度、年换热量和工程指标汇总。
    % ---------------------------------------------------------------------

    n = numel(res);
    delta_mm = deltaList_mm(:);
    phi = zeros(n,1);
    chi = zeros(n,1);
    Rgap_mK_W = zeros(n,1);
    Rdelta_mK_W = zeros(n,1);
    Rint_eff_mK_W = zeros(n,1);
    etaU = zeros(n,1);
    Ldelta_over_L0 = zeros(n,1);
    Tout_mean_C = zeros(n,1);
    Tout_min_C = zeros(n,1);
    Tout_max_C = zeros(n,1);
    DeltaToutMean_C = zeros(n,1);
    DeltaToutMax_C = zeros(n,1);
    Ecool_kWh = zeros(n,1);
    Eheat_kWh = zeros(n,1);
    Eabs_kWh = zeros(n,1);
    Dgap_percent = zeros(n,1);
    TintJump_mean_C = zeros(n,1);
    TintJump_max_C = zeros(n,1);
    PicardIter_max = zeros(n,1);
    PicardResidual_max = zeros(n,1);

    Tout0 = res{1}.Tout;
    E0 = res{1}.E_abs;

    for k = 1:n
        r = res{k};
        phi(k) = r.phi;
        chi(k) = r.chi;
        Rgap_mK_W(k) = r.Rgap;
        Rdelta_mK_W(k) = r.Rdelta;
        Rint_eff_mK_W(k) = r.Reng.Rint_eff;
        etaU(k) = r.Reng.etaU;
        Ldelta_over_L0(k) = r.Reng.Lratio;
        Tout_mean_C(k) = mean(r.Tout);
        Tout_min_C(k) = min(r.Tout);
        Tout_max_C(k) = max(r.Tout);
        DeltaToutMean_C(k) = mean(abs(r.Tout - Tout0));
        DeltaToutMax_C(k) = max(abs(r.Tout - Tout0));
        Ecool_kWh(k) = r.E_cool;
        Eheat_kWh(k) = r.E_heat;
        Eabs_kWh(k) = r.E_abs;
        Dgap_percent(k) = (1 - r.E_abs/E0)*100;
        TintJump_mean_C(k) = mean(abs(r.TintJump(:)));
        TintJump_max_C(k) = max(abs(r.TintJump(:)));
        PicardIter_max(k) = max(r.picardIter(:));
        PicardResidual_max(k) = max(r.picardResidual(isfinite(r.picardResidual)));
    end

    T = table(delta_mm, phi, chi, Rgap_mK_W, Rdelta_mK_W, Rint_eff_mK_W, ...
        etaU, Ldelta_over_L0, Tout_mean_C, Tout_min_C, Tout_max_C, ...
        DeltaToutMean_C, DeltaToutMax_C, Ecool_kWh, Eheat_kWh, Eabs_kWh, ...
        Dgap_percent, TintJump_mean_C, TintJump_max_C, ...
        PicardIter_max, PicardResidual_max);
end

%% ========================================================================
%%                         局部函数区：验证模块
%% ========================================================================

function T = validation_degeneration(p, outDir)
    % validation_degeneration
    % ---------------------------------------------------------------------
    % 模块 9-1：退化验证。
    % 当 delta=0 时，本文模型应退化为原始完全接触 RC 模型。
    % ---------------------------------------------------------------------

    pv = p;
    pv.Nx = 40;
    pv.dt = 12*3600;
    pv.nYears = 2;
    pv.tEnd = pv.nYears*pv.P;

    rM0 = simulateEAHE_case(pv, 0, 0, 'M0');
    rA0 = simulateEAHE_case(pv, 0, 1, 'AIRGAP');

    dT = rA0.Tout - rM0.Tout;
    RMSE_Tout_C = sqrt(mean(dT.^2));
    MaxAbs_Tout_C = max(abs(dT));
    RelErr_Eabs_percent = abs(rA0.E_abs-rM0.E_abs)/max(rM0.E_abs,eps)*100;

    Item = {'Tout RMSE'; 'Tout maximum absolute error'; 'Eabs relative error'};
    Value = [RMSE_Tout_C; MaxAbs_Tout_C; RelErr_Eabs_percent];
    Unit = {'degC'; 'degC'; '%'};
    Criterion = {'should approach 0'; 'should approach 0'; 'should approach 0'};
    T = table(Item, Value, Unit, Criterion);

    writetable(T, fullfile(outDir, 'Validation_degeneration_delta0.csv'));
    fprintf('Degeneration validation: Tout RMSE = %.3e degC, MaxAbs = %.3e degC.\n', ...
        RMSE_Tout_C, MaxAbs_Tout_C);
end

function T = validation_interface_limits(p, outDir)
    % validation_interface_limits
    % ---------------------------------------------------------------------
    % 模块 9-2：界面极限验证。
    % delta=0       -> Rgap=0, 温度跳跃为 0；
    % delta 增大    -> Rgap 增大，相同热流下温度跳跃增大；
    % Rgap -> inf   -> qg -> 0，界面接近绝热。
    % ---------------------------------------------------------------------

    delta_mm = [0; 0.1; 0.5; 1; 2; 5; 20];
    qTest_W_m = 10;  % 假定单位长度热流，仅用于计算温度跳跃趋势

    Rgap = zeros(size(delta_mm));
    Rdelta = zeros(size(delta_mm));
    Jump_C = zeros(size(delta_mm));
    qRelative = zeros(size(delta_mm));

    R0 = radialThermalNetwork(p, 0, 1, 'AIRGAP');
    for i = 1:numel(delta_mm)
        R = radialThermalNetwork(p, delta_mm(i)*1e-3, 1, 'AIRGAP');
        Rgap(i) = R.Rgap;
        Rdelta(i) = R.Rdelta;
        Jump_C(i) = qTest_W_m*R.Rgap;
        qRelative(i) = R0.Rdelta/R.Rdelta;
    end

    T = table(delta_mm, Rgap, Rdelta, Jump_C, qRelative, ...
        'VariableNames', {'delta_mm','Rgap_mK_W','Rdelta_mK_W','Jump_at_q10_C','RelativeHeatFlux'});

    writetable(T, fullfile(outDir, 'Validation_interface_limits.csv'));
    fprintf('Interface limit validation finished.\n');
end

function T = validation_energy_balance(res, deltaList_mm, outDir)
    % validation_energy_balance
    % ---------------------------------------------------------------------
    % 模块 9-3：能量守恒检查。
    % epsQ = |Qair - Qsoil - Qstore| / max(|Qair|, Qref)
    % 其中 Qair 为空气侧换热量，Qsoil 为进入土壤热流，Qstore 为节点储热率。
    % ---------------------------------------------------------------------

    n = numel(res);
    delta_mm = deltaList_mm(:);
    epsQ_mean = zeros(n,1);
    epsQ_95percentile = zeros(n,1);
    epsQ_max = zeros(n,1);

    for k = 1:n
        e = res{k}.epsQ(:);
        e = e(isfinite(e));
        epsQ_mean(k) = mean(e);
        epsQ_95percentile(k) = percentile_local(e,95);
        epsQ_max(k) = max(e);
    end

    T = table(delta_mm, epsQ_mean, epsQ_95percentile, epsQ_max);
    writetable(T, fullfile(outDir, 'Validation_energy_balance.csv'));
    fprintf('Energy balance validation finished.\n');
end

function T = validation_Nx_independence(p, delta, phi, outDir)
    % validation_Nx_independence
    % ---------------------------------------------------------------------
    % 模块 9-4：轴向离散无关性。
    % 以最大 Nx 结果为参考，比较出口温度 RMSE 和年换热量误差。
    % ---------------------------------------------------------------------

    NxList = [20 40 80 120 160];
    pv = p;
    pv.dt = 12*3600;
    pv.nYears = 2;
    pv.tEnd = pv.nYears*pv.P;

    results = cell(numel(NxList),1);
    for i = 1:numel(NxList)
        pv.Nx = NxList(i);
        results{i} = simulateEAHE_case(pv, delta, phi, 'AIRGAP');
    end
    ref = results{end};

    Nx = NxList(:);
    RMSE_Tout_C = zeros(numel(Nx),1);
    RelErr_Eabs_percent = zeros(numel(Nx),1);

    for i = 1:numel(Nx)
        dT = results{i}.Tout - ref.Tout;
        RMSE_Tout_C(i) = sqrt(mean(dT.^2));
        RelErr_Eabs_percent(i) = abs(results{i}.E_abs-ref.E_abs)/max(ref.E_abs,eps)*100;
    end

    T = table(Nx, RMSE_Tout_C, RelErr_Eabs_percent);
    writetable(T, fullfile(outDir, 'Validation_Nx_independence.csv'));
end

function T = validation_dt_independence(p, delta, phi, outDir)
    % validation_dt_independence
    % ---------------------------------------------------------------------
    % 模块 9-5：时间步长无关性。
    % 以最小 dt 结果为参考，比较出口温度 RMSE 和年换热量误差。
    % ---------------------------------------------------------------------

    dtList_h = [24 12 6 3];
    pv = p;
    pv.Nx = 60;
    pv.nYears = 2;
    pv.tEnd = pv.nYears*pv.P;

    results = cell(numel(dtList_h),1);
    for i = 1:numel(dtList_h)
        pv.dt = dtList_h(i)*3600;
        results{i} = simulateEAHE_case(pv, delta, phi, 'AIRGAP');
    end

    ref = results{end};
    dt_h = dtList_h(:);
    RMSE_Tout_C = zeros(numel(dt_h),1);
    RelErr_Eabs_percent = zeros(numel(dt_h),1);

    for i = 1:numel(dt_h)
        % 不同 dt 时用插值对齐到参考时间点。
        ToutInterp = interp1(results{i}.t, results{i}.Tout, ref.t, 'linear', 'extrap');
        dT = ToutInterp - ref.Tout;
        RMSE_Tout_C(i) = sqrt(mean(dT.^2));
        RelErr_Eabs_percent(i) = abs(results{i}.E_abs-ref.E_abs)/max(ref.E_abs,eps)*100;
    end

    T = table(dt_h, RMSE_Tout_C, RelErr_Eabs_percent);
    writetable(T, fullfile(outDir, 'Validation_dt_independence.csv'));
end

function y = percentile_local(x,pct)
    % percentile_local
    % ---------------------------------------------------------------------
    % 避免依赖 Statistics Toolbox 的 prctile。
    % ---------------------------------------------------------------------
    x = sort(x(:));
    if isempty(x)
        y = NaN;
        return;
    end
    k = 1 + (numel(x)-1)*pct/100;
    k0 = floor(k);
    k1 = ceil(k);
    if k0 == k1
        y = x(k0);
    else
        y = x(k0) + (x(k1)-x(k0))*(k-k0);
    end
end

%% ========================================================================
%%                         局部函数区：绘图模块
%% ========================================================================

function plot_model_method_figures(p, outDir)
    % plot_model_method_figures
    % ---------------------------------------------------------------------
    % 模块 10-0：论文方法图，包括物理结构、热阻-热容网络和求解流程。
    % 这些图用于补足审稿人通常要求的模型可解释性材料。
    % ---------------------------------------------------------------------
    plot_physical_schematic(p, outDir);
    plot_rc_network(outDir);
    plot_solver_flowchart(outDir);
end

function plot_physical_schematic(p, outDir)
    deltaShow = 2e-3;
    rg = p.rpo + deltaShow;

    figure('Name','Fig00 Physical schematic','Color','w');
    hold on; box on;
    x0 = 0; x1 = p.L;
    rectangle('Position',[x0, 0, x1, p.rs], 'FaceColor',[0.86 0.92 0.82], ...
        'EdgeColor',[0.35 0.45 0.30], 'LineWidth',1.0);
    rectangle('Position',[x0, 0, x1, rg], 'FaceColor',[0.98 0.93 0.76], ...
        'EdgeColor',[0.70 0.55 0.20], 'LineWidth',1.0);
    rectangle('Position',[x0, 0, x1, p.rpo], 'FaceColor',[0.78 0.80 0.84], ...
        'EdgeColor',[0.25 0.25 0.28], 'LineWidth',1.0);
    rectangle('Position',[x0, 0, x1, p.rpi], 'FaceColor',[0.73 0.87 0.98], ...
        'EdgeColor',[0.10 0.30 0.55], 'LineWidth',1.0);
    plot([x0 x1],[p.rpi p.rpi],'k-','LineWidth',1.0);
    plot([x0 x1],[p.rpo p.rpo],'k-','LineWidth',1.0);
    plot([x0 x1],[rg rg],'k--','LineWidth',1.0);
    plot([1.0 4.8], [p.rpi*0.45 p.rpi*0.45], '-', 'LineWidth',1.4, ...
        'Color',[0.05 0.25 0.55]);
    plot(4.8, p.rpi*0.45, '>', 'MarkerFaceColor',[0.05 0.25 0.55], ...
        'MarkerEdgeColor',[0.05 0.25 0.55], 'MarkerSize',7);
    text(5.5, p.rpi*0.48, 'Air flow T_f', 'Color',[0.05 0.25 0.55]);
    text(p.L*0.50, p.rpi*0.45, 'air', 'HorizontalAlignment','center');
    text(p.L*0.50, (p.rpi+p.rpo)/2, 'pipe', 'HorizontalAlignment','center');
    text(p.L*0.50, (p.rpo+rg)/2, 'air gap \delta', 'HorizontalAlignment','center');
    text(p.L*0.50, (rg+p.rs)/2, 'soil', 'HorizontalAlignment','center');
    text(0.8, p.rpi, 'r_{pi}', 'VerticalAlignment','bottom');
    text(0.8, p.rpo, 'r_{po}', 'VerticalAlignment','bottom');
    text(0.8, rg, 'r_g=r_{po}+\delta', 'VerticalAlignment','bottom');
    xlabel('z / m'); ylabel('r / m');
    title('EAHE physical model and air-gap interface');
    xlim([0 p.L]); ylim([0 min(0.18,p.rs)]);
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig00_model_physical_schematic');
end

function plot_rc_network(outDir)
    figure('Name','Fig00b RC network','Color','w', 'Position',[100 100 980 360]);
    hold on; axis off;
    nodesX = [0 2.2 4.4 6.6];
    nodesY = [0 0 0 0];
    labels = {'T_f','T_p','T_g','T_h + \DeltaT_s'};
    for i = 1:numel(nodesX)
        plot(nodesX(i), nodesY(i), 'o', 'MarkerSize',22, ...
            'MarkerFaceColor',[0.90 0.95 1.00], 'MarkerEdgeColor',[0.15 0.25 0.45]);
        text(nodesX(i), nodesY(i), labels{i}, 'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', 'FontWeight','bold');
    end
    plot([nodesX(1) nodesX(2)],[0 0],'k-','LineWidth',1.4);
    plot([nodesX(2) nodesX(3)],[0 0],'k-','LineWidth',1.4);
    plot([nodesX(3) nodesX(4)],[0 0],'k--','LineWidth',1.2);
    text(mean(nodesX(1:2)), 0.35, 'R_{p1}=R_{conv}+R_{cond,in}', ...
        'HorizontalAlignment','center');
    text(mean(nodesX(2:3)), 0.35, 'R_{\delta}=R_{p2}+R_{gap}', ...
        'HorizontalAlignment','center');
    text(mean(nodesX(3:4)), 0.35, 'soil response G(t)', ...
        'HorizontalAlignment','center');
    text(nodesX(1), -0.55, 'C_f', 'HorizontalAlignment','center');
    text(nodesX(2), -0.55, 'C_p', 'HorizontalAlignment','center');
    text(mean(nodesX(2:3)), -0.55, 'T_{po}-T_g=q_g R_{gap}', ...
        'HorizontalAlignment','center', 'Color',[0.55 0.10 0.08]);
    text(mean(nodesX(1:2)), -0.85, 'C_f dT_f/dt = advection + (T_p-T_f)/R_{p1}', ...
        'HorizontalAlignment','center', 'FontSize',9);
    text(mean(nodesX(2:3)), -0.85, 'C_p dT_p/dt = (T_f-T_p)/R_{p1} + (T_g-T_p)/R_{\delta}', ...
        'HorizontalAlignment','center', 'FontSize',9);
    title('Thermal resistance-capacitance network');
    xlim([-0.45 7.05]); ylim([-1.05 0.75]);
    export_publication_figure(gcf, outDir, 'Fig00b_RC_network');
end

function plot_solver_flowchart(outDir)
    figure('Name','Fig00c Solver flowchart','Color','w', 'Position',[100 100 820 920]);
    hold on; axis off;
    boxW = 5.6; boxH = 0.58;
    x = 0.35;
    y = [6.0 5.1 4.2 3.3 2.4 1.5 0.6 -0.3];
    txt = {'输入几何、材料、运行和数值参数', ...
           '计算 R_{p1}、R_{gap}、R_{\delta} 和土壤响应核 G(t)', ...
           '由未扰动土壤温度初始化 T_f、T_p、T_g', ...
           '进入时间步 n \rightarrow n+1', ...
           'Picard 迭代：更新 T_g 与 q_g，直至残差收敛', ...
           '隐式欧拉 + 轴向上风格式求解 T_f、T_p', ...
           '保存 T_{out}、Q_{air}、\DeltaT_{int} 和能量残差', ...
           '截取最后一年，导出图像、CSV 和 Excel'};
    for i = 1:numel(y)
        rectangle('Position',[x y(i) boxW boxH], 'Curvature',0.05, ...
            'FaceColor',[0.96 0.97 0.98], 'EdgeColor',[0.25 0.25 0.25]);
        text(x+boxW/2, y(i)+boxH/2, txt{i}, 'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', 'FontSize',9);
        if i < numel(y)
            quiver(x+boxW/2, y(i)-0.04, 0, -0.34, 0, 'k', ...
                'LineWidth',1.0, 'MaxHeadSize',0.4);
        end
    end
    title('数值求解流程');
    xlim([0 6.3]); ylim([-0.75 6.85]);
    export_publication_figure(gcf, outDir, 'Fig00c_solver_flowchart');
end

function plot_main_results(res, deltaList_mm, outDir)
    % plot_main_results
    % ---------------------------------------------------------------------
    % 模块 10：论文主结果图。
    % ---------------------------------------------------------------------

    labels = delta_case_labels(deltaList_mm);
    colors = lines(numel(res));

    % 图 1：入口温度、未扰动土壤温度和不同空气隙下出口温度。
    figure('Name','Fig01 Temperature boundary and outlet','Color','w');
    hold on; box on; grid on;
    plot(res{1}.day, res{1}.Tin, 'k-', 'LineWidth', 1.6, 'DisplayName', 'T_{in}');
    plot(res{1}.day, res{1}.Th, 'k--', 'LineWidth', 1.6, 'DisplayName', 'T_h(H,t)');
    for k = 1:numel(res)
        plot(res{k}.day, res{k}.Tout, 'LineWidth', 1.3, ...
            'Color', colors(k,:), 'DisplayName', labels{k});
    end
    xlabel('t / day'); ylabel('Temperature / ^\circC');
    title('入口温度、未扰动土壤温度与出口温度');
    legend('Location','eastoutside');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig01_Tin_Th_Tout');

    % 图 2：相对于无空气隙工况的出口温度偏差。
    figure('Name','Fig02 Outlet temperature deviation','Color','w');
    hold on; box on; grid on;
    Tout0 = res{1}.Tout;
    for k = 2:numel(res)
        plot(res{k}.day, res{k}.Tout - Tout0, 'LineWidth', 1.4, ...
            'Color', colors(k,:), 'DisplayName', labels{k});
    end
    xlabel('t / day'); ylabel('T_{out,\delta}-T_{out,0} / ^\circC');
    title('空气隙导致的出口温度偏差');
    yline(0,'k:','HandleVisibility','off');
    legend('Location','eastoutside');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig02_Tout_deviation');

    % 图 3：空气侧换热量。
    figure('Name','Fig03 Heat rate','Color','w');
    hold on; box on; grid on;
    for k = 1:numel(res)
        plot(res{k}.day, res{k}.Qair, 'LineWidth', 1.3, ...
            'Color', colors(k,:), 'DisplayName', labels{k});
    end
    xlabel('t / day'); ylabel('Q_{air} / W');
    title('空气侧瞬时换热量（Q_{air}>0 表示空气被冷却）');
    yline(0,'k:','HandleVisibility','off');
    legend('Location','eastoutside');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig03_heat_rate');

    % 图 4：界面温度跳跃。
    figure('Name','Fig04 Interface temperature jump','Color','w');
    hold on; box on; grid on;
    for k = 2:numel(res)
        jumpMean = mean(abs(res{k}.TintJump),1);
        plot(res{k}.day, jumpMean, 'LineWidth', 1.4, ...
            'Color', colors(k,:), 'DisplayName', labels{k});
    end
    xlabel('t / day'); ylabel('|\Delta T_{int}| / ^\circC');
    title('空气隙界面温度跳跃绝对值');
    legend('Location','eastoutside');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig04_interface_temperature_jump');

    % 图 5：能量守恒残差。
    figure('Name','Fig05 Energy balance residual','Color','w');
    hold on; box on; grid on;
    for k = 1:numel(res)
        semilogy(res{k}.day, max(res{k}.epsQ, eps), 'LineWidth', 1.1, ...
            'Color', colors(k,:), 'DisplayName', labels{k});
    end
    xlabel('t / day'); ylabel('\epsilon_Q');
    title('能量守恒残差');
    legend('Location','eastoutside');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig05_energy_balance_residual');
end

function plot_resistance_and_engineering(p, deltaList_mm, phi, outDir)
    % plot_resistance_and_engineering
    % ---------------------------------------------------------------------
    % 模块 10：工程热阻贡献率、eta_U 和有效管长修正图。
    % ---------------------------------------------------------------------

    n = numel(deltaList_mm);
    comp = zeros(n,4);
    etaU = zeros(n,1);
    Lratio = zeros(n,1);
    Rint = zeros(n,1);
    dmax = zeros(3,1);
    etaMin = [0.98; 0.95; 0.90];

    for k = 1:n
        R = engineeringResistances(p, deltaList_mm(k)*1e-3, phi);
        Rtot = R.RtotPhi;
        comp(k,:) = [R.Ra, R.Rp, R.Rs0, max(R.Rint_eff,0)]/Rtot*100;
        etaU(k) = R.etaU;
        Lratio(k) = R.Lratio;
        Rint(k) = R.Rint_eff;
    end

    for i = 1:numel(etaMin)
        dmax(i) = allowableGapThickness(p, etaMin(i), phi);
    end

    figure('Name','Fig06 Resistance contribution','Color','w'); box on; grid on;
    xcat = categorical(delta_case_labels(deltaList_mm));
    xcat = reordercats(xcat, delta_case_labels(deltaList_mm));
    bar(xcat, comp, 'stacked');
    xlabel('\delta / mm'); ylabel('Contribution / %');
    legend('R_a','R_p','R_s','R_{int}','Location','best');
    title('总热阻组成与界面热阻贡献率');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig06_resistance_contribution');

    figure('Name','Fig07 Engineering correction factors','Color','w');
    subplot(1,3,1); box on; grid on;
    plot(deltaList_mm, Rint, '-o', 'LineWidth', 1.4);
    xlabel('\delta / mm'); ylabel('R''_{int} / (m K W^{-1})');
    title('附加界面热阻');
    apply_publication_style(gca);

    subplot(1,3,2); box on; grid on;
    plot(deltaList_mm, etaU, '-o', 'LineWidth', 1.4);
    hold on;
    for i = 1:numel(etaMin)
        yline(etaMin(i), '--', sprintf('\\eta_U=%.2f, \\delta_{max}=%.3f mm', ...
            etaMin(i), dmax(i)*1000), 'LabelHorizontalAlignment','left');
    end
    xlabel('\delta / mm'); ylabel('\eta_U');
    title('传热能力修正系数');
    apply_publication_style(gca);

    subplot(1,3,3); box on; grid on;
    plot(deltaList_mm, Lratio, '-o', 'LineWidth', 1.4);
    xlabel('\delta / mm'); ylabel('L_\delta/L_0');
    title('有效管长修正系数');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig07_engineering_correction_factors');

    Tallow = table(etaMin, dmax*1000, ...
        'VariableNames', {'etaU_min','delta_max_mm'});
    writetable(Tallow, fullfile(outDir, 'Table_05_allowable_gap_thickness.csv'));
end

function plot_summary_figures(res, deltaList_mm, p, phi, outDir)
    % plot_summary_figures
    % ---------------------------------------------------------------------
    % 审稿增强图：年度能量、衰减因子、温度偏差、界面跳跃和界面热阻极限。
    % ---------------------------------------------------------------------
    n = numel(res);
    Ecool = zeros(n,1);
    Eheat = zeros(n,1);
    Eabs = zeros(n,1);
    Dgap = zeros(n,1);
    dToutMean = zeros(n,1);
    dToutMax = zeros(n,1);
    jumpMean = zeros(n,1);
    jumpMax = zeros(n,1);
    Tout0 = res{1}.Tout;
    E0 = res{1}.E_abs;

    for k = 1:n
        Ecool(k) = res{k}.E_cool;
        Eheat(k) = res{k}.E_heat;
        Eabs(k) = res{k}.E_abs;
        Dgap(k) = (1 - Eabs(k)/E0)*100;
        dToutMean(k) = mean(abs(res{k}.Tout - Tout0));
        dToutMax(k) = max(abs(res{k}.Tout - Tout0));
        jumpMean(k) = mean(abs(res{k}.TintJump(:)));
        jumpMax(k) = max(abs(res{k}.TintJump(:)));
    end

    figure('Name','Fig08 Annual energy','Color','w');
    hold on; box on; grid on;
    plot(deltaList_mm, Ecool, '-o', 'LineWidth',1.4, 'DisplayName','冷却量');
    plot(deltaList_mm, Eheat, '-s', 'LineWidth',1.4, 'DisplayName','预热量');
    plot(deltaList_mm, Eabs, '-^', 'LineWidth',1.4, 'DisplayName','总换热量');
    xlabel('\delta / mm'); ylabel('Annual energy / kWh');
    title('空气隙厚度对年换热量的影响');
    legend('Location','best');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig08_annual_energy_vs_delta');

    figure('Name','Fig09 Performance decay','Color','w');
    plot(deltaList_mm, Dgap, '-o', 'LineWidth',1.5, 'MarkerFaceColor','w');
    box on; grid on;
    text(deltaList_mm(end), Dgap(end), sprintf('  %.2f%%', Dgap(end)), ...
        'VerticalAlignment','bottom');
    xlabel('\delta / mm'); ylabel('D_{gap} / %');
    title('空气隙性能衰减因子');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig09_Dgap_vs_delta');

    figure('Name','Fig10 Outlet deviation summary','Color','w');
    hold on; box on; grid on;
    plot(deltaList_mm, dToutMean, '-o', 'LineWidth',1.4, 'DisplayName','平均绝对偏差');
    plot(deltaList_mm, dToutMax, '-s', 'LineWidth',1.4, 'DisplayName','最大绝对偏差');
    xlabel('\delta / mm'); ylabel('|T_{out,\delta}-T_{out,0}| / ^\circC');
    title('出口温度偏差汇总');
    legend('Location','best');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig10_Tout_deviation_summary');

    figure('Name','Fig11 Interface jump summary','Color','w');
    hold on; box on; grid on;
    plot(deltaList_mm, jumpMean, '-o', 'LineWidth',1.4, 'DisplayName','平均 |\DeltaT_{int}|');
    plot(deltaList_mm, jumpMax, '-s', 'LineWidth',1.4, 'DisplayName','最大 |\DeltaT_{int}|');
    xlabel('\delta / mm'); ylabel('|\Delta T_{int}| / ^\circC');
    title('界面温度跳跃汇总');
    legend('Location','best');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig11_interface_jump_summary');

    deltaLimit_mm = [0 0.1 0.5 1 2 5 20];
    Rgap = zeros(size(deltaLimit_mm));
    Rdelta = zeros(size(deltaLimit_mm));
    qRelative = zeros(size(deltaLimit_mm));
    R0 = radialThermalNetwork(p, 0, phi, 'AIRGAP');
    for k = 1:numel(deltaLimit_mm)
        R = radialThermalNetwork(p, deltaLimit_mm(k)*1e-3, phi, 'AIRGAP');
        Rgap(k) = R.Rgap;
        Rdelta(k) = R.Rdelta;
        qRelative(k) = R0.Rdelta/R.Rdelta;
    end

    mainIdx = deltaLimit_mm <= 5;
    figure('Name','Fig12 Interface resistance limit','Color','w');
    yyaxis left;
    plot(deltaLimit_mm(mainIdx), Rgap(mainIdx), '-o', 'LineWidth',1.4, 'DisplayName','R_{gap}');
    hold on;
    plot(deltaLimit_mm(mainIdx), Rdelta(mainIdx), '-s', 'LineWidth',1.4, 'DisplayName','R_{\delta}');
    ylabel('Thermal resistance / (m K W^{-1})');
    yyaxis right;
    plot(deltaLimit_mm(mainIdx), qRelative(mainIdx), '-^', 'LineWidth',1.4, 'DisplayName','相对传热能力');
    ylabel('Relative heat flux');
    xlabel('\delta / mm');
    title('界面热阻与相对传热能力（0-5 mm）');
    box on; grid on;
    legend('Location','best');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig12_interface_resistance_limit');

    figure('Name','Fig12b Interface resistance wide range','Color','w');
    yyaxis left;
    plot(deltaLimit_mm, Rgap, '-o', 'LineWidth',1.4, 'DisplayName','R_{gap}');
    hold on;
    plot(deltaLimit_mm, Rdelta, '-s', 'LineWidth',1.4, 'DisplayName','R_{\delta}');
    ylabel('Thermal resistance / (m K W^{-1})');
    yyaxis right;
    plot(deltaLimit_mm, qRelative, '-^', 'LineWidth',1.4, 'DisplayName','相对传热能力');
    ylabel('Relative heat flux');
    xlabel('\delta / mm');
    title('界面热阻极限验证（含 20 mm 极限点）');
    box on; grid on;
    legend('Location','best');
    apply_publication_style(gca);
    export_publication_figure(gcf, outDir, 'Fig12b_interface_resistance_wide_range');
end

function plot_independence_results(T_Nx, T_dt, outDir)
    if ~isempty(T_Nx)
        figure('Name','Fig13 Nx independence','Color','w');
        subplot(1,2,1); box on; grid on;
        plot(T_Nx.Nx, T_Nx.RMSE_Tout_C, '-o', 'LineWidth',1.4);
        xlabel('N_x'); ylabel('RMSE of T_{out} / ^\circC');
        title('轴向离散无关性：出口温度');
        apply_publication_style(gca);
        subplot(1,2,2); box on; grid on;
        plot(T_Nx.Nx, T_Nx.RelErr_Eabs_percent, '-s', 'LineWidth',1.4);
        xlabel('N_x'); ylabel('Relative error of E_{abs} / %');
        title('轴向离散无关性：年换热量');
        apply_publication_style(gca);
        export_publication_figure(gcf, outDir, 'Fig13_Nx_independence');
    end

    if ~isempty(T_dt)
        figure('Name','Fig14 dt independence','Color','w');
        subplot(1,2,1); box on; grid on;
        plot(T_dt.dt_h, T_dt.RMSE_Tout_C, '-o', 'LineWidth',1.4);
        set(gca,'XDir','reverse');
        xlabel('\Delta t / h'); ylabel('RMSE of T_{out} / ^\circC');
        title('时间步长无关性：出口温度');
        apply_publication_style(gca);
        subplot(1,2,2); box on; grid on;
        plot(T_dt.dt_h, T_dt.RelErr_Eabs_percent, '-s', 'LineWidth',1.4);
        set(gca,'XDir','reverse');
        xlabel('\Delta t / h'); ylabel('Relative error of E_{abs} / %');
        title('时间步长无关性：年换热量');
        apply_publication_style(gca);
        export_publication_figure(gcf, outDir, 'Fig14_dt_independence');
    end
end

function dmax = allowableGapThickness(p, etaMin, phi)
    % allowableGapThickness
    % ---------------------------------------------------------------------
    % 模块 8：给定 eta_U 下反推允许最大空气隙厚度。
    % ---------------------------------------------------------------------
    fun = @(d) engineeringResistances(p,d,phi).etaU - etaMin;
    try
        dmax = fzero(fun, [0, 0.05]);
    catch
        dmax = NaN;
    end
end

function labels = delta_case_labels(deltaList_mm)
    labels = arrayfun(@(d)sprintf('delta = %g mm', d), ...
        deltaList_mm, 'UniformOutput', false);
end

function apply_publication_style(ax)
    set(ax, 'FontName','Arial', 'FontSize',10, 'LineWidth',0.9, ...
        'TickDir','out', 'Layer','top');
end

function export_publication_figure(fig, outDir, baseName)
    set(fig, 'Color','w');
    pngPath = fullfile(outDir, [baseName '.png']);
    pdfPath = fullfile(outDir, [baseName '.pdf']);
    try
        exportgraphics(fig, pngPath, 'Resolution',600);
        exportgraphics(fig, pdfPath, 'ContentType','vector');
    catch
        saveas(fig, pngPath);
        saveas(fig, pdfPath);
    end
end

function export_origin_ready_data(outDir, res, deltaList_mm, T_Nx, T_dt, p, phi)
    % export_origin_ready_data
    % ---------------------------------------------------------------------
    % 将关键图的数据整理成 Origin 易导入的宽表 CSV，并写出说明文件。
    % Origin COM 在不同机器上稳定性不同，因此主流程不强制依赖 Origin。
    % ---------------------------------------------------------------------
    orgDir = fullfile(outDir, 'Origin_ready_data');
    if ~exist(orgDir, 'dir'); mkdir(orgDir); end

    labels = matlab.lang.makeValidName(delta_case_labels(deltaList_mm));
    day = res{1}.day(:);

    T = table(day, res{1}.Tin(:), res{1}.Th(:), ...
        'VariableNames', {'day','Tin_C','Th_C'});
    for k = 1:numel(res)
        T.(['Tout_' labels{k} '_C']) = res{k}.Tout(:);
    end
    writetable(T, fullfile(orgDir, 'Origin_Fig01_Tin_Th_Tout.csv'));

    Tout0 = res{1}.Tout(:);
    T = table(day, 'VariableNames', {'day'});
    for k = 2:numel(res)
        T.(['DeltaTout_' labels{k} '_C']) = res{k}.Tout(:) - Tout0;
    end
    writetable(T, fullfile(orgDir, 'Origin_Fig02_Tout_deviation.csv'));

    T = table(day, 'VariableNames', {'day'});
    for k = 1:numel(res)
        T.(['Qair_' labels{k} '_W']) = res{k}.Qair(:);
    end
    writetable(T, fullfile(orgDir, 'Origin_Fig03_Qair.csv'));

    T = table(day, 'VariableNames', {'day'});
    for k = 2:numel(res)
        T.(['TintJumpMean_' labels{k} '_C']) = mean(abs(res{k}.TintJump),1).';
    end
    writetable(T, fullfile(orgDir, 'Origin_Fig04_interface_jump.csv'));

    n = numel(res);
    Ecool = zeros(n,1); Eheat = zeros(n,1); Eabs = zeros(n,1);
    Dgap = zeros(n,1); dToutMean = zeros(n,1); dToutMax = zeros(n,1);
    jumpMean = zeros(n,1); jumpMax = zeros(n,1);
    E0 = res{1}.E_abs;
    for k = 1:n
        Ecool(k) = res{k}.E_cool;
        Eheat(k) = res{k}.E_heat;
        Eabs(k) = res{k}.E_abs;
        Dgap(k) = (1 - Eabs(k)/E0)*100;
        dToutMean(k) = mean(abs(res{k}.Tout(:) - res{1}.Tout(:)));
        dToutMax(k) = max(abs(res{k}.Tout(:) - res{1}.Tout(:)));
        jumpMean(k) = mean(abs(res{k}.TintJump(:)));
        jumpMax(k) = max(abs(res{k}.TintJump(:)));
    end
    T = table(deltaList_mm(:), Ecool, Eheat, Eabs, Dgap, dToutMean, ...
        dToutMax, jumpMean, jumpMax, ...
        'VariableNames', {'delta_mm','Ecool_kWh','Eheat_kWh','Eabs_kWh', ...
        'Dgap_percent','DeltaToutMean_C','DeltaToutMax_C', ...
        'TintJumpMean_C','TintJumpMax_C'});
    writetable(T, fullfile(orgDir, 'Origin_Fig08_11_summary_vs_delta.csv'));

    deltaLimit_mm = [0; 0.1; 0.5; 1; 2; 5; 20];
    Rgap = zeros(size(deltaLimit_mm));
    Rdelta = zeros(size(deltaLimit_mm));
    qRelative = zeros(size(deltaLimit_mm));
    R0 = radialThermalNetwork(p, 0, phi, 'AIRGAP');
    for k = 1:numel(deltaLimit_mm)
        R = radialThermalNetwork(p, deltaLimit_mm(k)*1e-3, phi, 'AIRGAP');
        Rgap(k) = R.Rgap;
        Rdelta(k) = R.Rdelta;
        qRelative(k) = R0.Rdelta/R.Rdelta;
    end
    T = table(deltaLimit_mm, Rgap, Rdelta, qRelative);
    writetable(T, fullfile(orgDir, 'Origin_Fig12_interface_limit.csv'));

    if ~isempty(T_Nx)
        writetable(T_Nx, fullfile(orgDir, 'Origin_Fig13_Nx_independence.csv'));
    end
    if ~isempty(T_dt)
        writetable(T_dt, fullfile(orgDir, 'Origin_Fig14_dt_independence.csv'));
    end

    fid = fopen(fullfile(orgDir, 'Origin_import_guide.txt'), 'w');
    if fid > 0
        fprintf(fid, 'Origin-ready data exported from EAHE MATLAB model.\\n');
        fprintf(fid, 'Origin was detected at G:\\\\Origin2021\\\\Origin64.exe, but COM automation was not stable enough to make the MATLAB model depend on it.\\n\\n');
        fprintf(fid, 'Recommended Origin workflow:\\n');
        fprintf(fid, '1. Open Origin 2021.\\n');
        fprintf(fid, '2. Import each Origin_*.csv file as a worksheet.\\n');
        fprintf(fid, '3. Set column 1 as X and subsequent numeric columns as Y.\\n');
        fprintf(fid, '4. Use Line + Symbol for summary plots and Line for time-series plots.\\n');
        fprintf(fid, '5. Export figures as PDF/EPS for manuscript submission.\\n');
        fclose(fid);
    end
end

function export_review_excel(outDir, p, res, deltaList_mm, T_summary, ...
    T_degeneration, T_limits, T_energy, T_Nx, T_dt, T_figcheck)
    % export_review_excel
    % ---------------------------------------------------------------------
    % 将审稿需要的主结果、验证表和曲线数据统一写入 Excel 工作簿。
    % 若本机 MATLAB/Excel 环境不支持 xlsx，则自动补写 CSV 作为兜底。
    % ---------------------------------------------------------------------
    xlsxPath = fullfile(outDir, 'EAHE_airgap_review_ready_tables.xlsx');
    if exist(xlsxPath, 'file')
        delete(xlsxPath);
    end

    export_table_sheet(T_summary, xlsxPath, 'main_summary', outDir);
    export_table_sheet(T_degeneration, xlsxPath, 'degeneration', outDir);
    export_table_sheet(T_limits, xlsxPath, 'interface_limits', outDir);
    export_table_sheet(T_energy, xlsxPath, 'energy_balance', outDir);
    export_table_sheet(build_parameter_table(p), xlsxPath, 'parameters', outDir);
    export_table_sheet(T_figcheck, xlsxPath, 'figure_checklist', outDir);

    if ~isempty(T_Nx)
        export_table_sheet(T_Nx, xlsxPath, 'Nx_independence', outDir);
    end
    if ~isempty(T_dt)
        export_table_sheet(T_dt, xlsxPath, 'dt_independence', outDir);
    end

    for k = 1:numel(res)
        sheetName = sprintf('case_%gmm', deltaList_mm(k));
        sheetName = strrep(sheetName, '.', 'p');
        export_table_sheet(build_timeseries_table(res{k}), xlsxPath, ...
            sheetName, outDir);
    end
end

function export_table_sheet(T, xlsxPath, sheetName, outDir)
    try
        writetable(T, xlsxPath, 'Sheet', sheetName);
    catch ME
        warning('Excel export failed for sheet %s: %s', sheetName, ME.message);
        csvName = ['ExcelFallback_' sheetName '.csv'];
        writetable(T, fullfile(outDir, csvName));
    end
end

function T = build_parameter_table(p)
    Name = {'L'; 'Nx'; 'rpi'; 'rpo'; 'H'; 'rs'; ...
        'kp'; 'rho_p'; 'cp_p'; 'k_air'; 'rho_f'; 'cp_f'; 'mu_f'; ...
        'Vdot'; 'mdot'; 'ks'; 'rho_s'; 'cp_s'; 'alpha_s'; ...
        'dt_h'; 'nYears'; 'picardMaxIter'; 'picardTol'; 'picardRelax'};
    Value = [p.L; p.Nx; p.rpi; p.rpo; p.H; p.rs; ...
        p.kp; p.rho_p; p.cp_p; p.k_air; p.rho_f; p.cp_f; p.mu_f; ...
        p.Vdot; p.mdot; p.ks; p.rho_s; p.cp_s; p.alpha_s; ...
        p.dt/3600; p.nYears; p.picardMaxIter; p.picardTol; p.picardRelax];
    Unit = {'m'; '-'; 'm'; 'm'; 'm'; 'm'; ...
        'W/(m K)'; 'kg/m3'; 'J/(kg K)'; 'W/(m K)'; 'kg/m3'; ...
        'J/(kg K)'; 'Pa s'; 'm3/s'; 'kg/s'; 'W/(m K)'; ...
        'kg/m3'; 'J/(kg K)'; 'm2/s'; 'h'; 'year'; '-'; '-'; '-'};
    T = table(Name, Value, Unit);
end

function T = build_timeseries_table(r)
    day = r.day(:);
    Tin_C = r.Tin(:);
    Th_C = r.Th(:);
    Tout_C = r.Tout(:);
    Qair_W = r.Qair(:);
    Qsoil_W = r.Qsoil(:);
    Qstore_W = r.Qstore(:);
    EnergyResidual = r.epsQ(:);
    PicardIter = r.picardIter(:);
    PicardResidual = r.picardResidual(:);
    qg_mean_W_m = mean(r.qg,1).';
    qg_maxAbs_W_m = max(abs(r.qg),[],1).';
    TintJump_mean_C = mean(r.TintJump,1).';
    TintJump_maxAbs_C = max(abs(r.TintJump),[],1).';
    T = table(day, Tin_C, Th_C, Tout_C, Qair_W, Qsoil_W, Qstore_W, ...
        EnergyResidual, PicardIter, PicardResidual, qg_mean_W_m, ...
        qg_maxAbs_W_m, TintJump_mean_C, TintJump_maxAbs_C);
end

function run_comsol_parameter_calibration(p, outDir)
    % run_comsol_parameter_calibration
    % Calibrate only physically common parameters against the present
    % COMSOL resistance-gap model. The contact coefficient is fixed:
    % phi = 1, chi = 0. This avoids using a local-contact correction to fit
    % a COMSOL model that does not contain local contact.

    rootDir = fileparts(outDir);
    comsolDir = fullfile(rootDir, 'COMSOL_EAHE_outputs_annual_full');
    energyPath = fullfile(comsolDir, 'COMSOL_annual_energy_summary.csv');
    toutPath = fullfile(comsolDir, 'COMSOL_Tout_delta_sweep.csv');
    if exist(energyPath, 'file') ~= 2 || exist(toutPath, 'file') ~= 2
        error('COMSOL calibration input files were not found in %s.', comsolDir);
    end

    kernelTag = char(upper(string(p.soilKernelType)));
    calDir = fullfile(outDir, ...
        ['COMSOL_parameter_calibration_phi1_chi0_' kernelTag]);
    if ~exist(calDir, 'dir'); mkdir(calDir); end

    Tenergy = readtable(energyPath);
    Ttout = readtable(toutPath);

    fprintf('\n=== COMSOL parameter calibration, phi=1 and chi=0 ===\n');
    fprintf('Target: COMSOL resistance_gap annual outputs.\n');
    fprintf('Contact coefficient is not calibrated in this run.\n\n');

    pSearch = p;
    pSearch.Nx = 32;
    pSearch.dt = 12*3600;
    pSearch.nYears = 1;
    pSearch.tEnd = pSearch.P;

    hiGrid = [0.05 0.08 0.10 0.12 0.15 0.18 0.20 0.25 0.30];
    soilGrid = [1.50 2.00 2.50 3.00 3.50 4.00 4.50 5.00];
    betaGrid = [1.00 1.20 1.40 1.60 1.80 2.00 2.30 2.60];
    deltasFinal_mm = [0 0.5 1 2 3 5];

    n1 = numel(hiGrid)*numel(soilGrid);
    hi_col = zeros(n1,1);
    soil_col = zeros(n1,1);
    Eabs_col = zeros(n1,1);
    Erel_col = zeros(n1,1);
    rmse_col = zeros(n1,1);
    bias_col = zeros(n1,1);
    obj_col = zeros(n1,1);

    E0com = comsol_energy_value(Tenergy, 0, 'Eabs_kWh');
    row = 0;
    bestJ = inf;
    bestHi = 1.0;
    bestSoil = 1.0;

    for ih = 1:numel(hiGrid)
        for is = 1:numel(soilGrid)
            row = row + 1;
            pTry = pSearch;
            pTry.hi_scale = hiGrid(ih);
            pTry.soil_response_scale = soilGrid(is);
            pTry.beta_gap = 1.0;

            r0 = simulateEAHE_case(pTry, 0, 1.0, 'AIRGAP');
            [rmseT, biasT] = calibration_tout_metrics(r0, Ttout, 0);
            relE = abs(r0.E_abs - E0com)/max(E0com, eps);
            J = rmseT + 2.0*relE + 0.25*abs(biasT);
            if ~isfinite(J)
                J = realmax;
            end

            hi_col(row) = pTry.hi_scale;
            soil_col(row) = pTry.soil_response_scale;
            Eabs_col(row) = r0.E_abs;
            Erel_col(row) = 100*relE;
            rmse_col(row) = rmseT;
            bias_col(row) = biasT;
            obj_col(row) = J;

            if J < bestJ
                bestJ = J;
                bestHi = pTry.hi_scale;
                bestSoil = pTry.soil_response_scale;
            end
        end
    end

    Tstage1 = table(hi_col, soil_col, Eabs_col, Erel_col, rmse_col, ...
        bias_col, obj_col, 'VariableNames', {'hi_scale', ...
        'soil_response_scale', 'MATLAB_Eabs_delta0_kWh', ...
        'Eabs_relative_error_percent', 'Tout_RMSE_delta0_C', ...
        'Tout_bias_delta0_C', 'objective'});
    writetable(Tstage1, fullfile(calDir, 'Calibration_stage1_base_grid.csv'));

    pBase = pSearch;
    pBase.hi_scale = bestHi;
    pBase.soil_response_scale = bestSoil;
    pBase.beta_gap = 1.0;
    rBase0 = simulateEAHE_case(pBase, 0, 1.0, 'AIRGAP');

    trainDelta = [1 3 5];
    n2 = numel(betaGrid);
    beta_col = zeros(n2,1);
    rmseD_col = zeros(n2,1);
    rmseIncTout_col = zeros(n2,1);
    obj2_col = zeros(n2,1);

    for ib = 1:numel(betaGrid)
        pTry = pBase;
        pTry.beta_gap = betaGrid(ib);
        dErr = zeros(numel(trainDelta),1);
        toutErr = zeros(numel(trainDelta),1);
        for id = 1:numel(trainDelta)
            dmm = trainDelta(id);
            rd = simulateEAHE_case(pTry, dmm*1e-3, 1.0, 'AIRGAP');
            Dmat = 100*(1 - rd.E_abs/max(rBase0.E_abs, eps));
            Dcom = comsol_energy_value(Tenergy, dmm, 'Dgap_percent');
            dErr(id) = Dmat - Dcom;
            toutErr(id) = calibration_incremental_tout_rmse(rd, rBase0, Ttout, dmm);
        end
        beta_col(ib) = betaGrid(ib);
        rmseD_col(ib) = sqrt(mean(dErr.^2));
        rmseIncTout_col(ib) = sqrt(mean(toutErr.^2));
        obj2_col(ib) = rmseD_col(ib)/10 + rmseIncTout_col(ib);
    end

    [~, ibest] = min(obj2_col);
    bestBeta = beta_col(ibest);
    Tstage2 = table(beta_col, rmseD_col, rmseIncTout_col, obj2_col, ...
        'VariableNames', {'beta_gap', 'Dgap_RMSE_percent_point', ...
        'Incremental_Tout_RMSE_C', 'objective'});
    writetable(Tstage2, fullfile(calDir, 'Calibration_stage2_beta_grid.csv'));

    pFinal = p;
    pFinal.nYears = 1;
    pFinal.tEnd = pFinal.P;
    pFinal.hi_scale = bestHi;
    pFinal.soil_response_scale = bestSoil;
    pFinal.beta_gap = bestBeta;

    resFinal = cell(numel(deltasFinal_mm),1);
    for k = 1:numel(deltasFinal_mm)
        fprintf('Final calibrated run: delta = %.3g mm, phi=1, chi=0.\n', ...
            deltasFinal_mm(k));
        resFinal{k} = simulateEAHE_case(pFinal, deltasFinal_mm(k)*1e-3, ...
            1.0, 'AIRGAP');
    end

    Tsummary = build_calibrated_comparison_table(resFinal, deltasFinal_mm, ...
        Tenergy, Ttout);
    writetable(Tsummary, fullfile(calDir, ...
        'Calibrated_MATLAB_vs_COMSOL_summary.csv'));
    export_calibrated_timeseries(resFinal, deltasFinal_mm, Ttout, calDir);

    Tparams = table(bestHi, bestSoil, bestBeta, 1.0, 0.0, ...
        'VariableNames', {'hi_scale', 'soil_response_scale', ...
        'beta_gap', 'phi', 'chi'});
    writetable(Tparams, fullfile(calDir, 'Calibrated_parameter_set.csv'));

    xlsxPath = fullfile(calDir, 'Calibrated_MATLAB_COMSOL_comparison.xlsx');
    export_table_sheet(Tparams, xlsxPath, 'parameters', calDir);
    export_table_sheet(Tstage1, xlsxPath, 'stage1_base_grid', calDir);
    export_table_sheet(Tstage2, xlsxPath, 'stage2_beta_grid', calDir);
    export_table_sheet(Tsummary, xlsxPath, 'final_summary', calDir);

    plot_calibrated_comparison_figures(Tsummary, Tstage1, Tstage2, calDir);
    save(fullfile(calDir, 'Calibrated_MATLAB_vs_COMSOL_results.mat'), ...
        'pFinal', 'resFinal', 'deltasFinal_mm', 'Tsummary', ...
        'Tstage1', 'Tstage2', 'Tparams', '-v7.3');

    fprintf('\nCalibration finished. Output folder: %s\n', calDir);
    fprintf('Selected: hi_scale = %.4f, soil_response_scale = %.4f, beta_gap = %.4f.\n', ...
        bestHi, bestSoil, bestBeta);
    disp(Tsummary);
end

function y = comsol_energy_value(Tenergy, delta_mm, varName)
    model = string(Tenergy.model_type);
    idx = strcmpi(model, 'resistance_gap') & abs(Tenergy.delta_mm - delta_mm) < 1e-9;
    if ~any(idx)
        error('Cannot find COMSOL resistance_gap energy row for delta %.6g mm.', delta_mm);
    end
    v = Tenergy.(varName);
    y = v(find(idx, 1, 'first'));
end

function colName = comsol_tout_column(delta_mm)
    tag = strrep(sprintf('%g', delta_mm), '.', 'p');
    colName = ['Tout_resistance_delta_' tag 'mm_C'];
end

function [rmseT, biasT] = calibration_tout_metrics(r, Ttout, delta_mm)
    colName = comsol_tout_column(delta_mm);
    day = r.day(:);
    matT = r.Tout(:);
    comDay = Ttout.t_day(:);
    comT = Ttout.(colName);
    mask = comDay >= min(day) & comDay <= max(day);
    matInterp = interp1(day, matT, comDay(mask), 'linear');
    err = matInterp - comT(mask);
    rmseT = sqrt(mean(err.^2));
    biasT = mean(err);
end

function rmseT = calibration_incremental_tout_rmse(rd, r0, Ttout, delta_mm)
    colD = comsol_tout_column(delta_mm);
    col0 = comsol_tout_column(0);
    day = rd.day(:);
    matD = rd.Tout(:) - r0.Tout(:);
    comDay = Ttout.t_day(:);
    comD = Ttout.(colD) - Ttout.(col0);
    mask = comDay >= min(day) & comDay <= max(day);
    matInterp = interp1(day, matD, comDay(mask), 'linear');
    err = matInterp - comD(mask);
    rmseT = sqrt(mean(err.^2));
end

function Tsummary = build_calibrated_comparison_table(resFinal, deltaList_mm, ...
        Tenergy, Ttout)
    n = numel(deltaList_mm);
    delta_mm = deltaList_mm(:);
    MATLAB_Eabs_kWh = zeros(n,1);
    COMSOL_Eabs_kWh = zeros(n,1);
    Eabs_error_percent = zeros(n,1);
    MATLAB_Dgap_percent = zeros(n,1);
    COMSOL_Dgap_percent = zeros(n,1);
    Dgap_error_percent_point = zeros(n,1);
    Tout_RMSE_C = zeros(n,1);
    Tout_bias_C = zeros(n,1);
    Incremental_Tout_RMSE_C = zeros(n,1);
    phi = ones(n,1);
    chi = zeros(n,1);

    E0 = resFinal{1}.E_abs;
    for k = 1:n
        dmm = deltaList_mm(k);
        MATLAB_Eabs_kWh(k) = resFinal{k}.E_abs;
        COMSOL_Eabs_kWh(k) = comsol_energy_value(Tenergy, dmm, 'Eabs_kWh');
        Eabs_error_percent(k) = 100*(MATLAB_Eabs_kWh(k) - COMSOL_Eabs_kWh(k)) ...
            /max(COMSOL_Eabs_kWh(k), eps);
        MATLAB_Dgap_percent(k) = 100*(1 - MATLAB_Eabs_kWh(k)/max(E0, eps));
        COMSOL_Dgap_percent(k) = comsol_energy_value(Tenergy, dmm, 'Dgap_percent');
        Dgap_error_percent_point(k) = MATLAB_Dgap_percent(k) - COMSOL_Dgap_percent(k);
        [Tout_RMSE_C(k), Tout_bias_C(k)] = calibration_tout_metrics(resFinal{k}, ...
            Ttout, dmm);
        if k == 1
            Incremental_Tout_RMSE_C(k) = 0;
        else
            Incremental_Tout_RMSE_C(k) = calibration_incremental_tout_rmse( ...
                resFinal{k}, resFinal{1}, Ttout, dmm);
        end
    end

    Tsummary = table(delta_mm, phi, chi, MATLAB_Eabs_kWh, COMSOL_Eabs_kWh, ...
        Eabs_error_percent, MATLAB_Dgap_percent, COMSOL_Dgap_percent, ...
        Dgap_error_percent_point, Tout_RMSE_C, Tout_bias_C, ...
        Incremental_Tout_RMSE_C);
end

function export_calibrated_timeseries(resFinal, deltaList_mm, Ttout, calDir)
    day = Ttout.t_day(:);
    T = table(day, Ttout.Tin_C(:), 'VariableNames', {'day', 'Tin_COMSOL_C'});
    for k = 1:numel(deltaList_mm)
        dmm = deltaList_mm(k);
        tag = strrep(sprintf('%g', dmm), '.', 'p');
        col = comsol_tout_column(dmm);
        T.(['COMSOL_Tout_' tag 'mm_C']) = Ttout.(col);
        T.(['MATLAB_Tout_' tag 'mm_C']) = interp1(resFinal{k}.day(:), ...
            resFinal{k}.Tout(:), day, 'linear', 'extrap');
    end
    writetable(T, fullfile(calDir, 'Calibrated_MATLAB_Tout_timeseries.csv'));
end

function plot_calibrated_comparison_figures(Tsummary, Tstage1, Tstage2, calDir)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 430]);
    subplot(1,2,1);
    plot(Tsummary.delta_mm, Tsummary.COMSOL_Eabs_kWh, 'o-', 'LineWidth', 1.5);
    hold on;
    plot(Tsummary.delta_mm, Tsummary.MATLAB_Eabs_kWh, 's--', 'LineWidth', 1.5);
    xlabel('\delta / mm');
    ylabel('Annual |Q| / kWh');
    legend({'COMSOL resistance gap', 'MATLAB calibrated'}, 'Location', 'southwest');
    grid on;
    subplot(1,2,2);
    plot(Tsummary.delta_mm, Tsummary.COMSOL_Dgap_percent, 'o-', 'LineWidth', 1.5);
    hold on;
    plot(Tsummary.delta_mm, Tsummary.MATLAB_Dgap_percent, 's--', 'LineWidth', 1.5);
    xlabel('\delta / mm');
    ylabel('D_{gap} / %');
    legend({'COMSOL resistance gap', 'MATLAB calibrated'}, 'Location', 'northwest');
    grid on;
    save_calibration_figure(fig, calDir, 'Fig_CALP01_Eabs_Dgap');

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 430]);
    subplot(1,2,1);
    plot(Tsummary.delta_mm, Tsummary.Tout_RMSE_C, 'o-', 'LineWidth', 1.5);
    xlabel('\delta / mm');
    ylabel('Tout RMSE / degC');
    grid on;
    subplot(1,2,2);
    bar(Tsummary.delta_mm, Tsummary.Dgap_error_percent_point);
    xlabel('\delta / mm');
    ylabel('D_{gap} error / percentage point');
    grid on;
    save_calibration_figure(fig, calDir, 'Fig_CALP02_Tout_RMSE_Dgap_error');

    if ~isempty(Tstage1) && ~isempty(Tstage2)
        fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 430]);
        subplot(1,2,1);
        scatter3(Tstage1.hi_scale, Tstage1.soil_response_scale, ...
            Tstage1.objective, 46, Tstage1.objective, 'filled');
        xlabel('h_i scale');
        ylabel('soil response scale');
        zlabel('objective');
        grid on;
        subplot(1,2,2);
        plot(Tstage2.beta_gap, Tstage2.objective, 'o-', 'LineWidth', 1.5);
        xlabel('\beta_{gap}');
        ylabel('objective');
        grid on;
        save_calibration_figure(fig, calDir, 'Fig_CALP03_calibration_objectives');
    end
end

function save_calibration_figure(fig, outDir, baseName)
    pngPath = fullfile(outDir, [baseName '.png']);
    pdfPath = fullfile(outDir, [baseName '.pdf']);
    try
        exportgraphics(fig, pngPath, 'Resolution', 300);
        exportgraphics(fig, pdfPath, 'ContentType', 'vector');
    catch
        print(fig, pngPath, '-dpng', '-r300');
        print(fig, pdfPath, '-dpdf', '-painters');
    end
    close(fig);
end

function run_current_matlab_comsol_comparison(p, outDir)
    % Direct comparison using the current default MATLAB parameter set.
    % This is intentionally not calibrated: hi_scale=1, soil_response_scale=1,
    % beta_gap=1, phi=1 and chi=0.
    rootDir = fileparts(outDir);
    comsolDir = fullfile(rootDir, 'COMSOL_EAHE_outputs_annual_full');
    energyPath = fullfile(comsolDir, 'COMSOL_annual_energy_summary.csv');
    toutPath = fullfile(comsolDir, 'COMSOL_Tout_delta_sweep.csv');
    if exist(energyPath, 'file') ~= 2 || exist(toutPath, 'file') ~= 2
        error('COMSOL comparison input files were not found in %s.', comsolDir);
    end

    kernelTag = char(upper(string(p.soilKernelType)));
    compareDir = fullfile(outDir, ...
        ['COMSOL_current_parameter_comparison_phi1_chi0_' kernelTag]);
    if ~exist(compareDir, 'dir'); mkdir(compareDir); end

    Tenergy = readtable(energyPath);
    Ttout = readtable(toutPath);
    deltaList_mm = [0 0.5 1 2 3 5];

    pCurrent = p;
    pCurrent.nYears = 1;
    pCurrent.tEnd = pCurrent.P;
    pCurrent.hi_scale = 1.0;
    pCurrent.soil_response_scale = 1.0;
    pCurrent.beta_gap = 1.0;

    resCurrent = cell(numel(deltaList_mm),1);
    for k = 1:numel(deltaList_mm)
        fprintf('Current uncalibrated comparison run: delta = %.3g mm.\n', ...
            deltaList_mm(k));
        resCurrent{k} = simulateEAHE_case(pCurrent, deltaList_mm(k)*1e-3, ...
            1.0, 'AIRGAP');
    end

    Tsummary = build_calibrated_comparison_table(resCurrent, deltaList_mm, ...
        Tenergy, Ttout);
    writetable(Tsummary, fullfile(compareDir, ...
        'Current_MATLAB_vs_COMSOL_summary.csv'));
    export_calibrated_timeseries(resCurrent, deltaList_mm, Ttout, compareDir);

    Tparams = table(pCurrent.hi_scale, pCurrent.soil_response_scale, ...
        pCurrent.beta_gap, 1.0, 0.0, pCurrent.nYears, pCurrent.dt/3600, ...
        'VariableNames', {'hi_scale', 'soil_response_scale', 'beta_gap', ...
        'phi', 'chi', 'nYears', 'dt_h'});
    writetable(Tparams, fullfile(compareDir, 'Current_parameter_set.csv'));

    plot_calibrated_comparison_figures(Tsummary, table(), table(), compareDir);
    save(fullfile(compareDir, 'Current_MATLAB_vs_COMSOL_results.mat'), ...
        'pCurrent', 'resCurrent', 'deltaList_mm', 'Tsummary', 'Tparams', '-v7.3');

    fprintf('\nCurrent uncalibrated comparison finished. Output folder: %s\n', ...
        compareDir);
    disp(Tsummary);
end

function T = review_figure_checklist(outDir)
    % review_figure_checklist
    % ---------------------------------------------------------------------
    % 检查论文审稿常用图件是否已经存在。COMSOL 图件来自前序数值验证目录。
    % ---------------------------------------------------------------------
    rootDir = fileparts(outDir);
    Item = { ...
        'Physical schematic'; ...
        'Thermal RC network'; ...
        'Solver flowchart'; ...
        'MATLAB Tin/Th/Tout'; ...
        'MATLAB Tout deviation'; ...
        'MATLAB heat rate'; ...
        'MATLAB interface temperature jump'; ...
        'MATLAB energy residual'; ...
        'MATLAB resistance contribution'; ...
        'MATLAB engineering correction'; ...
        'MATLAB annual energy summary'; ...
        'MATLAB performance decay'; ...
        'MATLAB outlet deviation summary'; ...
        'MATLAB interface jump summary'; ...
        'MATLAB interface resistance limit'; ...
        'MATLAB interface resistance wide range'; ...
        'MATLAB Nx independence'; ...
        'MATLAB dt independence'; ...
        'COMSOL geometry explicit gap'; ...
        'COMSOL initial temperature contour'; ...
        'COMSOL final temperature contour'; ...
        'COMSOL final zoom temperature contour'; ...
        'COMSOL explicit vs resistance Tout'; ...
        'COMSOL annual energy'};
    Role = { ...
        'Model geometry definition'; ...
        'Equation and resistance interpretation'; ...
        'Numerical method reproducibility'; ...
        'Annual thermal response'; ...
        'Air-gap impact on outlet temperature'; ...
        'Heat transfer rate comparison'; ...
        'Interface thermal jump evidence'; ...
        'Energy conservation evidence'; ...
        'Thermal resistance contribution'; ...
        'Engineering design correction'; ...
        'Annual energy degradation evidence'; ...
        'Performance decay evidence'; ...
        'Outlet temperature deviation summary'; ...
        'Interface temperature jump summary'; ...
        'Interface resistance limiting behavior'; ...
        'Supplementary wide-range interface limit'; ...
        'Spatial discretization independence'; ...
        'Time-step independence'; ...
        'COMSOL model evidence'; ...
        'Initial field evidence'; ...
        'Final field evidence'; ...
        'Pipe-near-field evidence'; ...
        'Equivalent boundary validation'; ...
        'Annual performance validation'};
    Path = { ...
        fullfile(outDir,'Fig00_model_physical_schematic.png'); ...
        fullfile(outDir,'Fig00b_RC_network.png'); ...
        fullfile(outDir,'Fig00c_solver_flowchart.png'); ...
        fullfile(outDir,'Fig01_Tin_Th_Tout.png'); ...
        fullfile(outDir,'Fig02_Tout_deviation.png'); ...
        fullfile(outDir,'Fig03_heat_rate.png'); ...
        fullfile(outDir,'Fig04_interface_temperature_jump.png'); ...
        fullfile(outDir,'Fig05_energy_balance_residual.png'); ...
        fullfile(outDir,'Fig06_resistance_contribution.png'); ...
        fullfile(outDir,'Fig07_engineering_correction_factors.png'); ...
        fullfile(outDir,'Fig08_annual_energy_vs_delta.png'); ...
        fullfile(outDir,'Fig09_Dgap_vs_delta.png'); ...
        fullfile(outDir,'Fig10_Tout_deviation_summary.png'); ...
        fullfile(outDir,'Fig11_interface_jump_summary.png'); ...
        fullfile(outDir,'Fig12_interface_resistance_limit.png'); ...
        fullfile(outDir,'Fig12b_interface_resistance_wide_range.png'); ...
        fullfile(outDir,'Fig13_Nx_independence.png'); ...
        fullfile(outDir,'Fig14_dt_independence.png'); ...
        fullfile(rootDir,'COMSOL_EAHE_field_materials','field_figures','Fig_COMSOL_geometry_explicit_gap_delta_0p5mm.png'); ...
        fullfile(rootDir,'COMSOL_EAHE_field_materials','field_figures','Fig_COMSOL_Tfield_initial_explicit_gap_delta_0p5mm.png'); ...
        fullfile(rootDir,'COMSOL_EAHE_field_materials','field_figures','Fig_COMSOL_Tfield_final_explicit_gap_delta_0p5mm.png'); ...
        fullfile(rootDir,'COMSOL_EAHE_field_materials','field_figures','Fig_COMSOL_Tfield_final_zoom_explicit_gap_delta_0p5mm.png'); ...
        fullfile(rootDir,'COMSOL_EAHE_outputs_annual_full','Fig_COMSOL_06_explicit_vs_resistance_Tout.png'); ...
        fullfile(rootDir,'COMSOL_EAHE_outputs_annual_full','Fig_COMSOL_04_annual_energy.png')};
    Exists = false(numel(Path),1);
    for i = 1:numel(Path)
        Exists(i) = exist(Path{i}, 'file') == 2;
    end
    T = table(Item, Role, Path, Exists);
end
