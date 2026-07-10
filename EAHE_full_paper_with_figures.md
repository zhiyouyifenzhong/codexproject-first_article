# 考虑管土空气隙热阻的 Earth-Air Heat Exchanger 瞬态 Minaei-G 热阻-热容模型及 CFD 验证

## 摘要

水平埋管式 earth-air heat exchanger（EAHE）在长期运行过程中会受到土壤热积累、管土接触不良和空气隙热阻的共同影响，导致出口空气温度和年换热量偏离理想接触条件。为描述这一过程，本文建立了一种考虑管土空气隙热阻的瞬态热阻-热容（thermal resistance-capacity, TRC）模型。模型将管内空气和管壁沿轴向离散为一维节点，并通过管内对流热阻、管壁导热热阻、空气隙热阻和土壤瞬态响应核进行耦合。与传统 ILS/FLS 响应核不同，本文土壤响应统一采用 Minaei 等文献中的圆柱瞬态导热 G 函数，从而使降阶模型与文献理论形式保持一致。针对 0-5 mm 空气隙厚度，模型给出了出口温度、年换热量、空气隙引起的性能衰减和界面温度跃迁。结果表明，当空气隙厚度从 0 增至 5 mm 时，年绝对换热量由 1778.93 kWh 降至 1146.93 kWh，性能衰减率达到 35.53%。采用 Sharan 单根直管实验进行短时出口温度验证时，MATLAB Minaei-G 模型在制冷和供热工况下的出口温度 RMSE 分别为 0.516 和 0.613 deg C；在 Minaei 参数体系下与 k-epsilon CFD 进行全年同工况对比时，0、1 和 5 mm 空气隙对应的出口温度 RMSE 分别为 0.472、0.419 和 0.266 deg C，年绝对换热量差异低于 1.7%。时间步长和空间段数无关性分析表明，dt = 6 h 和 Nx = 80 可满足全年计算精度要求。研究结果说明，基于 Minaei-G 响应核的 TRC 模型能够以较低计算成本预测管土空气隙对 EAHE 长期热性能的影响。

**关键词：** earth-air heat exchanger；空气隙热阻；Minaei G 函数；热阻-热容模型；k-epsilon CFD；数值验证

## 1 引言

Earth-air heat exchanger（EAHE）利用地下土壤温度相对稳定和热容量较大的特点，对进入建筑或温室的空气进行预冷或预热，是浅层地热利用和低能耗通风系统中的重要技术。对于水平埋管式 EAHE，空气沿管道轴向流动，并通过管壁与周围土壤交换热量。夏季制冷工况下，热空气向土壤释放热量；冬季供热工况下，土壤向空气供热。由于土壤热扩散速度有限，连续运行会使近管土体温度逐渐偏离未扰动状态，从而引起出口空气温度和换热量的时间衰减。

现有 EAHE 模型主要包括解析模型、CFD 或有限元模型以及等效热阻-热容模型。解析模型形式简洁，适合初步设计，但通常需要假设土壤均质、边界稳态或温度场径向对称，难以同时处理地表周期边界、土壤热滞后和管土接触不良。CFD 或有限元模型能够较完整地描述湍流流动和温度场，但计算成本较高，不利于多年运行和多参数敏感性分析。等效热阻-热容模型介于二者之间，能够保留空气、管壁和土壤热容量的瞬态特征，同时具有较高计算效率。

实际工程中的一个关键问题是管道与回填土之间并非总是理想接触。施工扰动、回填不密实、管壁周围微小空腔或脱空均会引入额外界面热阻，削弱管土换热能力。该问题在传统 EAHE 模型中常被忽略，或仅通过经验修正系数处理，难以定量分析空气隙厚度对全年出口温度和换热量的影响。另一方面，土壤响应核的选择会影响降阶模型对长期热积累的预测。若使用 ILS/FLS 响应核，模型几何假设与圆管实际换热边界并不完全一致。Minaei 等提出的热阻-热容瞬态模型中采用了圆柱坐标下的 G 函数响应，为单根圆管 EAHE 的土壤瞬态导热提供了更一致的理论基础。

基于上述问题，本文建立考虑管土空气隙热阻的 Minaei-G 瞬态 TRC 模型。本文的主要工作包括：（1）建立空气-管壁-空气隙-土壤的等效热阻网络；（2）将土壤响应核改为 Minaei 文献中的 G 函数，且不再引入 ILS/FLS 响应核；（3）分析空气隙厚度对出口温度、年换热量和性能衰减率的影响；（4）通过 Sharan 单根直管实验、k-epsilon CFD 同工况结果和数值无关性分析对模型进行验证。

## 2 物理模型与基本假设

研究对象为单根水平埋设圆管式 EAHE。空气由入口进入管道，沿轴向流动并与管壁发生对流换热；管壁再通过自身导热、管土空气隙热阻和土壤瞬态导热将热量传递至周围土体。空气隙厚度记为 \(\delta\)，当 \(\delta=0\) 时表示理想接触或无空气隙状态；当 \(\delta>0\) 时，管外半径至土壤响应边界之间引入空气层导热热阻。

![图1 物理模型示意图](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig00_model_physical_schematic.png)

**图1 物理模型示意图。** 模型包括管内空气、管壁、管土空气隙和周围土壤区域。空气隙厚度通过额外径向热阻影响管土换热。

模型采用如下假设：

1. 管内空气按一维轴向流动处理，空气热物性为常数。
2. 管壁沿周向温度均匀，但沿轴向随空气温度变化。
3. 管土界面空气隙为均匀环形空气层，空气隙导热系数取空气导热系数。
4. 土壤响应采用圆柱径向瞬态导热 G 函数描述，土壤热物性在本文验证工况中取常数。
5. 入口温度采用年周期边界，未扰动土壤温度作为土壤远场基准。
6. 本文仅讨论单根直管，不考虑多管间热干扰、含湿迁移和冷凝潜热。

## 3 数学模型与数值方法

### 3.1 热阻-热容网络

图2给出了本文采用的等效热阻-热容网络。每一个轴向单元包含空气节点 \(T_f\) 和管壁节点 \(T_p\)。空气节点和管壁节点之间通过管内对流热阻 \(R_{p1}\) 相连；管壁节点与土壤响应边界节点之间通过外侧管壁导热热阻和空气隙热阻构成的 \(R_\delta\) 相连；土壤边界温度则由未扰动土壤温度和历史热流卷积得到。

![图2 热阻-热容网络](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig00b_RC_network.png)

**图2 热阻-热容网络。** 模型将空气、管壁和土壤响应写成一组沿轴向离散的瞬态能量方程。

对第 \(i\) 个轴向空气单元，能量方程写为

\[
C_f \frac{dT_{f,i}}{dt}
= \dot m c_{p,f}(T_{f,i-1}-T_{f,i})
+ \frac{T_{p,i}-T_{f,i}}{R_{p1}},
\]

其中 \(C_f\) 为空气节点热容，\(\dot m\) 为空气质量流量，\(c_{p,f}\) 为空气定压比热。管壁节点方程写为

\[
C_p \frac{dT_{p,i}}{dt}
= \frac{T_{f,i}-T_{p,i}}{R_{p1}}
+ \frac{T_{g,i}-T_{p,i}}{R_\delta},
\]

其中 \(C_p\) 为管壁节点热容，\(T_{g,i}\) 为土壤响应边界温度。管内对流热阻和管壁导热热阻分别由管内对流换热系数、管径和管壁导热系数确定。空气隙热阻写为

\[
R_{\mathrm{gap}}
= \frac{\ln[(r_{po}+\delta)/r_{po}]}{2\pi k_{\mathrm{air}}},
\]

其中 \(r_{po}\) 为管外半径，\(k_{\mathrm{air}}\) 为空气导热系数。管壁外侧至土壤响应边界的总热阻为

\[
R_\delta = R_{p2}+R_{\mathrm{gap}}.
\]

当 \(\delta=0\) 时，\(R_{\mathrm{gap}}=0\)，模型退化为 Minaei 原文献形式中的无空气隙结构。

### 3.2 Minaei-G 土壤响应核

土壤边界温度由未扰动土壤温度和历史进入土壤的单位长度热流叠加得到：

\[
T_g(t)=T_h(t)+\frac{1}{k_s}\sum_j \Delta q_j G(t-t_j),
\]

其中 \(T_h(t)\) 为未扰动土壤温度，\(k_s\) 为土壤导热系数，\(q_j\) 为进入土壤的单位长度热流。本文的 \(G(t)\) 采用 Minaei 等给出的圆柱瞬态导热 G 函数。该选择使土壤响应核与圆管边界相匹配，并避免在计算中混入 ILS 或 FLS 响应核。

### 3.3 数值求解流程

时间推进采用隐式欧拉格式，轴向对流项采用上风离散。由于土壤边界温度依赖当前时刻热流，而热流又依赖管壁和土壤边界温度，因此每一时间步内采用 Picard 迭代更新 \(q_g\) 和 \(T_g\)。图3给出了模型求解流程。

![图3 求解流程](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig00c_solver_flowchart.png)

**图3 求解流程。** 每个时间步内先根据历史热流计算土壤响应，再通过空气-管壁方程和 Picard 迭代更新热流与温度场。

性能指标包括出口温度 \(T_{\mathrm{out}}\)、空气侧换热功率

\[
Q_{\mathrm{air}}=\dot m c_{p,f}(T_{\mathrm{in}}-T_{\mathrm{out}}),
\]

以及全年制冷量、供热量和绝对换热量。空气隙造成的性能衰减定义为

\[
D_{\mathrm{gap}} = \left(1-\frac{E_{\mathrm{abs}}(\delta)}{E_{\mathrm{abs}}(0)}\right)\times 100\%.
\]

## 4 结果与分析

### 4.1 不同空气隙厚度下的出口温度响应

图4给出了不同空气隙厚度下的入口温度、未扰动土壤温度和出口温度。随着空气隙厚度增大，管土之间的热阻增加，空气与土壤之间的热交换减弱。因此，在制冷季节，较大空气隙对应的出口温度更接近入口温度；在供热季节，空气从土壤获得的热量也减少。

![图4 不同空气隙厚度下的出口温度](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig01_Tin_Th_Tout.png)

**图4 不同空气隙厚度下的全年出口温度。** 空气隙增大后，出口温度调节幅度降低，表明管土换热能力下降。

相对于无空气隙工况，空气隙会造成出口温度偏差。图5进一步显示了各空气隙工况相对 \(\delta=0\) 的出口温度偏差。空气隙厚度为 0.5、1、2、3 和 5 mm 时，平均出口温度偏差分别为 0.178、0.339、0.615、0.844 和 1.199 deg C；最大偏差分别达到 0.349、0.666、1.209、1.645 和 2.290 deg C。该结果说明，即使毫米级空气隙也会对出口温度产生可观影响。

![图5 出口温度偏差](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig02_Tout_deviation.png)

**图5 出口温度偏差。** 偏差定义为有空气隙工况相对无空气隙工况的出口温度差。

### 4.2 换热功率与界面温度跃迁

图6显示了不同空气隙厚度下的空气侧换热功率。空气隙增大后，换热功率幅值降低，表明管土界面热阻控制了空气与土壤之间的热量交换。该趋势在全年制冷和供热阶段均存在。

![图6 空气侧换热功率](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig03_heat_rate.png)

**图6 空气侧换热功率。** 空气隙热阻削弱了全年制冷和供热阶段的换热能力。

空气隙热阻还会造成管壁外表面与土壤响应边界之间的温度跃迁。图7显示，界面温度跃迁随空气隙厚度增大而增加。对于 5 mm 空气隙，界面温度跃迁的平均值约为 2.19 deg C，说明空气隙已经成为管土传热链中的主要热阻之一。

![图7 界面温度跃迁](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig04_interface_temperature_jump.png)

**图7 管土界面温度跃迁。** 空气隙越大，管壁与土壤响应边界之间的温度跃迁越明显。

### 4.3 年换热量与空气隙衰减

图8和表1给出了不同空气隙厚度下的全年换热量。无空气隙时，年制冷量为 1044.94 kWh，年供热量为 733.99 kWh，年绝对换热量为 1778.93 kWh。当空气隙厚度增至 5 mm 时，年制冷量降至 678.02 kWh，年供热量降至 468.91 kWh，年绝对换热量降至 1146.93 kWh。

![图8 年换热量随空气隙厚度变化](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig08_annual_energy_vs_delta.png)

**图8 年换热量随空气隙厚度变化。** 空气隙增大后，制冷量、供热量和绝对换热量均显著下降。

**表1 不同空气隙厚度下的年换热量和性能衰减。**

| 空气隙厚度 (mm) | 年制冷量 (kWh) | 年供热量 (kWh) | 年绝对换热量 (kWh) | 性能衰减 Dgap (%) |
|---:|---:|---:|---:|---:|
| 0 | 1044.94 | 733.99 | 1778.93 | 0.00 |
| 0.5 | 990.57 | 694.35 | 1684.92 | 5.28 |
| 1 | 941.60 | 658.75 | 1600.35 | 10.04 |
| 2 | 857.15 | 597.58 | 1454.72 | 18.22 |
| 3 | 787.10 | 547.08 | 1334.18 | 25.00 |
| 5 | 678.02 | 468.91 | 1146.93 | 35.53 |

图9给出了空气隙引起的性能衰减率。结果表明，Dgap 随空气隙厚度单调增加。当空气隙厚度为 1 mm 时，Dgap 为 10.04%；当空气隙厚度为 5 mm 时，Dgap 增至 35.53%。这说明管土接触质量是影响 EAHE 长期性能的重要工程因素。

![图9 空气隙造成的性能衰减](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig09_Dgap_vs_delta.png)

**图9 空气隙造成的性能衰减。** Dgap 表示相对无空气隙工况的年绝对换热量下降比例。

### 4.4 热阻贡献与工程修正系数

图10给出了不同空气隙厚度下各热阻项的贡献。无空气隙时，主要热阻来自管内对流和管壁导热；当空气隙增大后，空气隙热阻迅速成为主导项。对于 5 mm 空气隙，空气隙热阻为 0.490 m K W-1，总 \(R_\delta\) 为 0.507 m K W-1，明显高于无空气隙时的 0.0166 m K W-1。

![图10 热阻贡献](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig06_resistance_contribution.png)

**图10 热阻贡献。** 空气隙热阻随厚度增加迅速增大，并主导管土传热链。

图11给出了等效传热修正系数 \(\eta_U\) 和等效长度修正系数。空气隙厚度为 0.5、1、2、3 和 5 mm 时，\(\eta_U\) 分别为 0.912、0.840、0.725、0.639 和 0.519。这意味着在 5 mm 空气隙下，等效管土传热能力约下降至理想接触状态的 52%。若要达到无空气隙工况相同的热阻水平，需要显著增加等效管长。

![图11 工程修正系数](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig07_engineering_correction_factors.png)

**图11 工程修正系数。** \(\eta_U\) 表征空气隙对等效传热能力的削弱程度。

## 5 模型验证与数值无关性

### 5.1 Sharan 单根直管短时实验验证

为检验模型对真实 EAHE 出口温度的预测能力，采用 Sharan 单根直管实验中的短时制冷和供热工况进行验证。由于 25 m 中间测点对局部换热、边界条件和测点定义更敏感，本文将出口温度作为主要验证指标。

![图12 Sharan 短时实验出口温度验证](G:/codexproject/Validation_outlet_CFD_MATLAB_literature/nature_python_figures/Nature_Fig01_Outlet_literature_MATLAB_CFD_validation.png)

**图12 Sharan 短时实验出口温度验证。** 黑色曲线为文献实验出口温度，蓝色虚线为 MATLAB Minaei-G 模型，红色曲线为 k-epsilon CFD 结果。

在 5 月制冷工况中，MATLAB Minaei-G 模型相对文献出口温度的 RMSE 为 0.516 deg C，CFD 相对文献出口温度的 RMSE 为 0.604 deg C。在 1 月供热工况中，MATLAB 模型相对文献的 RMSE 为 0.613 deg C，CFD 相对文献的 RMSE 为 0.582 deg C。MATLAB 与 CFD 之间的出口温度 RMSE 在制冷和供热工况下分别为 0.104 deg C 和 0.040 deg C，说明两种模型在相同参数下对出口温度的预测较为一致。

### 5.2 Minaei 参数下的全年 CFD-MATLAB 对比

由于现有文献未提供与本文 Minaei 参数体系完全一致的单根直管全年出口温度实测序列，全年验证采用 k-epsilon CFD 与 MATLAB Minaei-G 模型之间的同工况对比。图13给出了 0、1 和 5 mm 空气隙下的全年出口温度曲线和残差。

![图13 Minaei 参数下全年 CFD-MATLAB 出口温度对比](G:/codexproject/Minaei_parameter_gap_CFD_MinaeiG_validation_MATLAB_curves/curve_figures/MATLAB_curve_Minaei_params_gap_Tout_CFD_vs_MinaeiG.png)

**图13 Minaei 参数下全年 CFD-MATLAB 出口温度对比。** 左列为入口温度、CFD 出口温度和 MATLAB 出口温度；右列为 MATLAB 与 CFD 的残差。

0、1 和 5 mm 空气隙下，MATLAB 模型相对 CFD 的全年出口温度 RMSE 分别为 0.472、0.419 和 0.266 deg C。年绝对换热量方面，0、1 和 5 mm 空气隙下 CFD 与 MATLAB 的差异分别为 -0.026%、-0.403% 和 -1.679%。该结果表明，Minaei-G 降阶模型能够较好复现 CFD 的全年出口温度响应和年换热量趋势。

### 5.3 能量守恒验证

模型内部通过空气侧换热量、进入土壤热流和节点储热率之间的平衡关系进行能量守恒检查。不同空气隙厚度下，能量残差均保持在 \(10^{-12}\) 量级。以平均残差为例，0、1 和 5 mm 空气隙下分别为 \(1.03\times10^{-13}\)、\(1.16\times10^{-13}\) 和 \(8.21\times10^{-14}\)。这说明离散方程和热流后处理在数值上保持一致。

![图14 能量守恒残差](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig05_energy_balance_residual.png)

**图14 能量守恒残差。** 残差定义为空气侧换热、土壤热流和节点储热项之间的不平衡量。

### 5.4 时间步长无关性

图15给出了时间步长无关性分析。当前主输出采用 24、18、12、9、6、4、3 和 2 h 共 8 个时间步长点，并以 2 h 结果作为参考；代码中已进一步扩展为包含 1 h 参考解的 9 点序列。早期仅包含三个时间步点的调试文件不用于论文验证。

![图15 时间步长无关性](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig14_dt_independence.png)

**图15 时间步长无关性。** 左图为出口温度 RMSE，右图为年换热量相对误差。

当采用 6 h 时间步长时，出口温度相对参考解的 RMSE 为 0.00250 deg C，年绝对换热量相对误差为 0.0487%。即使采用更严格的 1 h 参考数据，6 h 时间步长的出口温度 RMSE 也仅为 0.00310 deg C，年换热量误差为 0.0609%。因此，本文采用 dt = 6 h 进行全年计算。

### 5.5 空间段数无关性

图16给出了轴向空间段数无关性分析。本文采用 20、30、40、50、60、70、80、100、120、140、160、200 和 240 共 13 个轴向段数，并以 Nx = 240 作为参考解。

![图16 空间段数无关性](G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Fig13_Nx_independence.png)

**图16 空间段数无关性。** 左图为出口温度 RMSE，右图为年换热量相对误差。

当 Nx = 80 时，出口温度 RMSE 为 0.00706 deg C，年绝对换热量相对误差为 0.209%。该误差远小于模型与实验或 CFD 之间的差异量级，说明 Nx = 80 可作为精度和计算成本之间的折中。早期仅包含 20、40 和 80 三个空间点的调试文件不用于论文验证。

## 6 讨论

本文结果表明，管土空气隙热阻会显著削弱 EAHE 的长期换热能力。该影响不仅体现在瞬时出口温度偏差上，也体现在全年绝对换热量和性能衰减率上。对于 1 mm 空气隙，年绝对换热量已下降约 10%；对于 5 mm 空气隙，下降幅度超过 35%。这说明在 EAHE 设计与施工中，回填密实度和管土接触状态不应仅作为施工质量问题处理，而应作为影响长期热性能的重要热阻参数纳入模型。

与 CFD 相比，Minaei-G TRC 模型的优势在于计算成本低、参数扫描方便，并能直接输出空气隙热阻、界面温度跃迁和工程修正系数。CFD 能更详细地描述湍流流动和局部壁面换热，但全年多工况计算成本较高。本文中 MATLAB 模型与 k-epsilon CFD 的全年出口温度 RMSE 低于 0.5 deg C，年换热量差异低于 1.7%，说明在单根直管和给定参数范围内，降阶模型可以替代 CFD 用于空气隙敏感性和工程估算。

模型仍存在边界。首先，本文假设空气隙为均匀环形层，而实际施工中空气隙可能呈局部脱空或非均匀接触。其次，土壤热物性取常数，尚未考虑含水率迁移、冻结融化或冷凝潜热。第三，验证中全年部分为 CFD-MATLAB 同工况对比，并非全年现场实测验证；Sharan 文献提供的是短时出口温度数据。因此，本文结论适用于单根直管、等效空气隙热阻和给定年周期边界条件下的模型验证。对于多管阵列、非均匀回填和显著湿热耦合工况，仍需进一步扩展模型并进行独立实验验证。

## 7 结论

本文建立了考虑管土空气隙热阻的 EAHE 瞬态 Minaei-G 热阻-热容模型，并通过实验数据、k-epsilon CFD 和数值无关性分析进行了验证。主要结论如下：

1. 将土壤响应核统一改为 Minaei 文献中的圆柱瞬态导热 G 函数后，模型能够在不引入 ILS/FLS 响应核的情况下描述圆管 EAHE 的长期土壤热响应。
2. 空气隙热阻对 EAHE 年换热量影响显著。当空气隙厚度由 0 增至 5 mm 时，年绝对换热量由 1778.93 kWh 降至 1146.93 kWh，性能衰减率达到 35.53%。
3. Sharan 短时实验验证表明，MATLAB Minaei-G 模型在制冷和供热工况下的出口温度 RMSE 分别为 0.516 和 0.613 deg C，与 k-epsilon CFD 预测水平相近。
4. Minaei 参数下的全年 CFD-MATLAB 对比表明，0、1 和 5 mm 空气隙下出口温度 RMSE 分别为 0.472、0.419 和 0.266 deg C，年绝对换热量差异低于 1.7%。
5. 数值无关性分析表明，dt = 6 h 和 Nx = 80 可满足全年模拟精度要求，时间和空间离散误差显著小于模型验证误差。

综上，所建立的 Minaei-G TRC 模型可用于分析管土空气隙热阻对单根直管 EAHE 长期热性能的影响，并可为回填施工质量控制和工程修正设计提供定量依据。

## 数据和代码可用性

本文使用的 MATLAB 模型、CFD 后处理数据、Origin 可编辑数据和论文图像均保存在本地工程目录中。主要数据包括：

- MATLAB 主模型：`G:/codexproject/EAHE_airgap_physical_modules_v18_minaei_contact.m`
- CFD-MATLAB 曲线验证数据：`G:/codexproject/Minaei_parameter_gap_CFD_MinaeiG_validation_MATLAB_curves/origin_data`
- 出口温度实验验证数据：`G:/codexproject/Validation_outlet_CFD_MATLAB_literature/origin_data`
- 时间和空间无关性数据：`G:/codexproject/EAHE_airgap_physical_v18_minaei_contact_results/Validation_dt_independence.csv` 和 `Validation_Nx_independence.csv`

## 参考文献

[1] Minaei et al. Thermal resistance capacity model for transient simulation of Earth-Air Heat Exchangers, 2021.

[2] Sharan et al. Experimental and/or numerical study of single-pipe earth-air heat exchanger performance, 2003.

[3] Ozgener et al. Experimental investigation and thermal-resistance analysis of an earth-air heat exchanger system, 2011.

> 注：参考文献条目需在投稿前按目标期刊格式补全 DOI、期刊名、卷期和页码。
