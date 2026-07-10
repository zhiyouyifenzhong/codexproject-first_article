---
title: 考虑管土间隙热阻与竖向分层土壤的水平埋管式EAHE瞬态RC网络模型
author: ''
date: ''
---


## 摘要

针对水平埋管式土壤空气换热器（earth-to-air heat exchanger, EAHE）在连续制冷运行中存在的土壤热饱和、管土接触不完全及土壤竖向分层问题，建立了一种考虑管土间隙热阻与三层竖向分层土壤的瞬态热阻-热容（RC）网络模型。模型将管内空气、管壁和管周土壤分别离散为轴向节点、管壁节点和周向-径向土壤节点，并采用隐式欧拉法求解。为保证初始土温和远场边界与实际季节相位一致，首先通过一维竖向分层土壤传热模型预计算未扰动土壤温度场，再将其作为 EAHE 瞬态模型的初始条件和近管外边界条件。结果表明，基准工况连续运行 7 d 后，最后一天日均换热量为 693.0 W，换热衰减比为 0.833，近管土壤日均升温为 3.36 K，说明土壤热饱和对长期性能具有明显影响。管土间隙厚度由 0 增至 5 mm 时，最后一天日均换热量由 741.0 W 降至 631.8 W；第二层土壤导热系数由 0.8 增至 2.5 W/(m K) 时，最后一天日均换热量由 598.0 W 增至 747.9 W。与经典稳态解析 NTU 模型相比，瞬态 RC 模型出口温度差异的 RMSE 为 1.35 K，表明考虑土壤热容和运行历史具有必要性。进一步基于 Ozgener 等（2011）的闭环 EAHE 温室制冷实验，提取了实验系统参数及文献图像数字化热阻数据。数字化结果显示，文献图 4 和图 7 的总热阻均值分别为 0.02115 和 0.02129 K m/W，与文献报告的平均热阻 0.021 K m/W 一致，验证了所建立热阻分析流程的合理性。研究可为考虑施工接触热阻和土壤分层效应的 EAHE 设计与运行评估提供参考。

**关键词**：土壤空气换热器；瞬态 RC 网络；管土间隙热阻；分层土壤；热饱和；实验验证

## 1 引言

土壤空气换热器利用地下土壤相对稳定的温度和较大的热惯性，对进入建筑或温室的空气进行预冷或预热，是一种结构简单、运行能耗较低的浅层地热利用技术。对于水平埋管式 EAHE，空气沿埋地管道流动，并通过管壁与周围土壤换热。在夏季制冷工况下，热空气向土壤释放热量；在冬季供热工况下，土壤则向空气供热。由于土壤热扩散速度有限，连续运行时近管土体温度会逐渐偏离未扰动状态，从而引起出口空气温度升高或降低，导致换热性能随运行时间衰减。这一现象通常称为土壤热饱和或热退化。

现有 EAHE 模型主要包括解析模型、数值模型和等效热网络模型。解析模型形式简洁，便于工程初算，但通常假设土壤均质、边界稳态或管周温度场径向对称，难以描述土壤分层、地表周期边界和连续运行下的热积累。CFD 或有限元模型能够较精细地刻画流动和土壤温度场，但计算量较大，不利于多参数敏感性分析和长期运行模拟。RC 网络模型介于二者之间，可以在较低计算成本下显式表示空气、管壁和土壤的热容及热阻，适合研究 EAHE 的瞬态响应和热退化规律。

实际工程中的一个重要问题是管道与回填土之间往往并非理想接触。施工扰动、回填不密实或管壁周围空气间隙均会引入额外界面热阻，削弱管土换热能力。同时，浅层土壤受地表气温和太阳辐射影响明显，土壤温度随深度和季节发生变化，不能简单视为均质恒温边界。若忽略土壤分层和季节相位，可能导致初始土温分布和温度云图出现物理偏差。

基于上述问题，本文建立考虑管土间隙热阻与竖向三层土壤分层的水平 EAHE 瞬态 RC 网络模型。本文的主要工作包括：（1）建立空气-管壁-管周土壤耦合 RC 网络；（2）引入竖向分层土壤预计算模型，为 EAHE 提供季节相位一致的初始土温和远场边界；（3）分析管土间隙厚度、间隙导热系数、土壤导热系数、空气流量和管长对性能的影响；（4）通过经典解析模型和 Ozgener 等（2011）实验热阻数据对模型与热阻分析方法进行验证。

## 2 物理模型

研究对象为水平埋设圆管式 EAHE。空气由入口进入管道，在流动过程中通过内对流换热与管壁交换热量，管壁再通过管壁导热、管土间隙热阻和土壤导热将热量传递给周围土体。土壤沿竖向划分为三层，管道位于第二层土壤中。近管土壤区域采用周向-径向离散，以描述管道上部和下部土壤温度差异。模型主要假设如下：

1. 管内空气为一维轴向流动，空气物性取常数。
2. 管壁沿周向温度均匀，但沿轴向变化。
3. 管周土壤采用周向-径向 RC 网络描述，土层界面处热物性突变，但不引入额外土层界面热阻。
4. 管道与土壤之间的间隙首先作为固定热阻处理，随后可扩展为温度相关热阻。
5. 近管计算域外边界温度由未扰动分层土壤温度场给出。
6. 地表边界通过对流换热与周期性空气温度耦合，深层边界取恒温。

## 3 数学模型与数值方法

### 3.1 管内空气能量方程

对第 \(i\) 个空气控制体，能量守恒可写为

$$
C_a\frac{dT_{a,i}}{dt}
=\dot m c_{p,a}(T_{a,i-1}-T_{a,i})
+G_{ap}(T_{p,i}-T_{a,i}),
\qquad (1)
$$

其中，\(T_{a,i}\) 为空气节点温度，\(T_{p,i}\) 为对应管壁节点温度，\(\dot m\) 为空气质量流量，\(c_{p,a}\) 为空气定压比热，\(C_a\) 为空气节点热容，\(G_{ap}\) 为空气与管壁之间的对流导热率。入口边界为

$$
T_{a,0}=T_{\mathrm{in}}(t).
\qquad (2)
$$

空气-管壁对流导热率为

$$
G_{ap}=h_i\pi D_i\Delta x,
\qquad (3)
$$

其中 \(h_i\) 为管内对流换热系数，\(D_i\) 为管内径，\(\Delta x\) 为轴向控制体长度。

### 3.2 管壁能量方程

管壁节点与空气节点和多个周向土壤节点相连，其能量方程为

$$
C_p\frac{dT_{p,i}}{dt}
=G_{ap}(T_{a,i}-T_{p,i})
+\sum_{m=1}^{N_\theta}G_{ps,m}(T_{s,i,m,1}-T_{p,i}),
\qquad (4)
$$

其中，\(C_p\) 为管壁热容，\(T_{s,i,m,1}\) 为第 \(i\) 个轴向位置、第 \(m\) 个周向分区第一径向土壤节点温度，\(G_{ps,m}\) 为管壁至近管土壤节点的等效导热率。

### 3.3 管土间隙热阻

管壁至近管土壤第一节点的总热阻由管壁导热热阻、间隙热阻和半径向土壤热阻组成：

$$
R_{ps,m}=R_{\mathrm{pipe}}+R_{\mathrm{gap}}+R_{\mathrm{soil},m}.
\qquad (5)
$$

管壁导热热阻为

$$
R_{\mathrm{pipe}}
=\frac{\ln(r_o/r_i)}{k_p\Delta\theta\Delta x},
\qquad (6)
$$

固定间隙热阻为

$$
R_{\mathrm{gap}}
=\frac{\ln[(r_o+\delta_{\mathrm{gap}})/r_o]}
{k_{\mathrm{gap}}\Delta\theta\Delta x},
\qquad (7)
$$

近管半径向土壤热阻为

$$
R_{\mathrm{soil},m}
=
\frac{\ln[r_{1,c}/(r_o+\delta_{\mathrm{gap}})]}
{k_s(z_{m,1})\Delta\theta\Delta x}.
\qquad (8)
$$

因此

$$
G_{ps,m}=\frac{1}{R_{ps,m}}.
\qquad (9)
$$

当考虑可变间隙热阻时，令

$$
R_{\mathrm{gap}}(T_s)
=R_{\mathrm{gap},0}
\left[1+a_{\mathrm{gap},T}(T_s-T_{\mathrm{ref}})\right],
\qquad (10)
$$

并采用上下限约束：

$$
R_{\mathrm{gap,min}}\le R_{\mathrm{gap}}(T_s)\le R_{\mathrm{gap,max}}.
\qquad (11)
$$

### 3.4 管周土壤 RC 方程

管周土壤节点的能量方程写为

$$
C_{s,j}\frac{dT_{s,j}}{dt}
=\sum_{k\in\mathcal{N}(j)}G_{jk}(T_{s,k}-T_{s,j})
+G_{b,j}(T_{b,j}-T_{s,j}),
\qquad (12)
$$

其中 \(j=(i,m,r)\) 表示土壤节点编号，\(\mathcal{N}(j)\) 为相邻节点集合，\(G_{jk}\) 为土壤节点之间的导热率，\(G_{b,j}\) 为外边界导热率，\(T_{b,j}\) 为由未扰动土壤温度插值得到的边界温度。

相邻径向土壤节点之间的热阻为

$$
R_r
=\frac{\ln(r_f/r_a)}{k_a\Delta\theta\Delta x}
+\frac{\ln(r_b/r_f)}{k_b\Delta\theta\Delta x},
\qquad
G_r=\frac{1}{R_r}.
\qquad (13)
$$

周向导热热阻为

$$
R_\theta
=\frac{r_c\Delta\theta}{k_{\mathrm{eff}}\Delta r\Delta x},
\qquad
k_{\mathrm{eff}}=\frac{2k_ak_b}{k_a+k_b},
\qquad
G_\theta=\frac{1}{R_\theta}.
\qquad (14)
$$

### 3.5 分层土壤未扰动温度预计算

未扰动土壤温度 \(T_u(z,t)\) 由一维竖向瞬态导热方程确定：

$$
\rho_s(z)c_s(z)\frac{\partial T_u}{\partial t}
=
\frac{\partial}{\partial z}
\left[
k_s(z)\frac{\partial T_u}{\partial z}
\right].
\qquad (15)
$$

地表采用对流边界：

$$
-k_s\left.\frac{\partial T_u}{\partial z}\right|_{z=0}
=h_g[T_{\mathrm{air}}(t)-T_u(0,t)].
\qquad (16)
$$

深层边界为

$$
T_u(z_{\max},t)=T_{\mathrm{deep}}.
\qquad (17)
$$

地表空气温度表示为年周期与日周期叠加：

$$
T_{\mathrm{air}}(t)=
\overline{T}_{\mathrm{air}}
A_y\sin\left[\frac{2\pi(t-\phi_y)}{t_y}\right]
A_d\sin\left[\frac{2\pi(t-\phi_d)}{t_d}\right].
\qquad (18)
$$

若 EAHE 在全年第 \(d_0\) 天启动，则用于 EAHE 计算的土壤温度为

$$
T_u^\ast(z,t)=T_u\left[z,\mathrm{mod}(t+d_0t_d,t_y)\right].
\qquad (19)
$$

式（19）用于保证入口空气工况与土壤季节相位一致，是避免温度云图出现物理错误的关键。

### 3.6 隐式欧拉离散

将所有空气、管壁和土壤节点组合为状态向量 \(\mathbf{X}\)，可得

$$
\mathbf{C}\frac{d\mathbf{X}}{dt}
=\mathbf{A}\mathbf{X}+\mathbf{b}(t),
\qquad (20)
$$

其中 \(\mathbf{C}\) 为热容矩阵，\(\mathbf{A}\) 为热导矩阵，\(\mathbf{b}\) 为由入口空气温度和远场土壤边界形成的边界项。采用隐式欧拉离散：

$$
\left(\frac{\mathbf{C}}{\Delta t}-\mathbf{A}\right)\mathbf{X}^{n+1}
=
\frac{\mathbf{C}}{\Delta t}\mathbf{X}^{n}
+\mathbf{b}^{n+1}.
\qquad (21)
$$

对固定间隙热阻，矩阵 \(\mathbf{C}/\Delta t-\mathbf{A}\) 在计算过程中保持不变，可进行一次矩阵分解后重复使用。对可变间隙热阻，由于 \(\mathbf{A}\) 随近管土壤温度变化，每个时间步内采用迭代求解，收敛准则为

$$
\frac{
\left\|\mathbf{X}^{n+1,k+1}-\mathbf{X}^{n+1,k}\right\|
}{
\max\left(\left\|\mathbf{X}^{n+1,k+1}\right\|,1\right)
}
<\varepsilon.
\qquad (22)
$$

### 3.7 评价指标

瞬时换热量定义为

$$
Q(t)=\dot m c_{p,a}\left[T_{\mathrm{in}}(t)-T_{\mathrm{out}}(t)\right].
\qquad (23)
$$

第 \(d\) 天日均换热量为

$$
\overline{Q}_d
=
\frac{1}{t_d}
\int_{(d-1)t_d}^{dt_d}Q(t)\,dt.
\qquad (24)
$$

热退化比定义为

$$
\eta_{Q,d}=\frac{\overline{Q}_d}{\overline{Q}_1}.
\qquad (25)
$$

近管土壤热积累用近管土壤相对未扰动土壤的温升表示：

$$
\Delta T_{s,\mathrm{near}}(t)
=
\overline{T}_{s,\mathrm{near}}(t)-T_u^\ast(z_p,t).
\qquad (26)
$$

## 4 验证方法

### 4.1 数值独立性验证

为检验时间步长、轴向网格、周向网格和径向网格对结果的影响，分别改变 \(\Delta t\)、\(N_x\)、\(N_\theta\) 和 \(N_r\)，并以细网格结果为参照计算出口空气温度 RMSE。结果显示，当 \(\Delta t=300\) s、\(N_x=40\)、\(N_\theta=8\)、\(N_r=6\) 时，出口温度误差已处于较低水平，可满足后续参数分析要求。

### 4.2 经典解析模型对比

为评估瞬态 RC 模型相对于传统工程解析方法的差异，建立稳态圆柱热阻 NTU 模型：

$$
T_{\mathrm{out,an}}
=
T_u^\ast(z_p,t)
+[T_{\mathrm{in}}(t)-T_u^\ast(z_p,t)]
\exp\left(-\frac{UA}{\dot m c_{p,a}}\right).
\qquad (27)
$$

其中 \(UA\) 由管内对流热阻、管壁热阻、管土间隙热阻和径向土壤热阻串联得到。该模型未考虑土壤热容和运行历史，因此可作为经典稳态模型基准。

### 4.3 Ozgener 等（2011）实验热阻验证

Ozgener 等（2011）研究了闭环 EAHE 温室制冷系统的总热阻。根据文献，实验系统为水平 U 形地下空气隧道，管长 47 m，名义直径 0.56 m，埋深约 3 m，土壤导热系数为 2.85 W/(m K)，体积流量为 1.47 m3/s，干空气质量流量为 1.64 kg/s。实验时段为 2009 年 10 月 12 日至 10 月 23 日，采样间隔为 1 min。文献给出的平均入口空气温度为 33.27 degC，平均出口空气温度为 31.01 degC，管内平均流体温度为 32.14 degC，管壁平均温度为 28.21 degC，平均总热阻约为 0.021 K m/W。

文献中总热阻定义为

$$
R_{\mathrm{Tot}}
=R_{\mathrm{conv}}+R_{\mathrm{pipe}}+R_{\mathrm{soil}},
\qquad (28)
$$

并满足

$$
T_f-T_s=q_lR_{\mathrm{Tot}},
\qquad (29)
$$

其中

$$
q_l=\frac{Q}{L}.
\qquad (30)
$$

为与文献结果比较，本文定义模型等效热阻为

$$
R_{\mathrm{eq},fw}(t)
=
\frac{T_f(t)-T_w(t)}{Q(t)/L},
\qquad (31)
$$

以及基于未扰动土壤远场温度的等效热阻

$$
R_{\mathrm{eq},fu}(t)
=
\frac{T_f(t)-T_u^\ast(z_p,t)}{Q(t)/L}.
\qquad (32)
$$

由于文献未提供完整原始时序数据，本文从文献图 3-7 对 \(R_{\mathrm{Tot}}\) 散点进行图像数字化，并将数字化数据用于热阻范围和趋势验证。误差采用 RMSE 和 MBE 表示：

$$
\mathrm{RMSE}
=
\sqrt{
\frac{1}{N}
\sum_{i=1}^{N}(y_{m,i}-y_{e,i})^2
},
\qquad (33)
$$

$$
\mathrm{MBE}
=
\frac{1}{N}
\sum_{i=1}^{N}(y_{m,i}-y_{e,i}).
\qquad (34)
$$

## 5 结果与讨论

### 5.1 基准瞬态响应与热饱和

基准工况下，入口空气温度呈周期性波动，出口温度波动幅值明显减小，说明土壤对空气温度具有削峰作用。连续运行 7 d 后，出口空气最终温度为 24.37 degC，最后一天日均换热量为 693.0 W，日均换热退化比为 0.833。近管土壤日均温升达到 3.36 K，说明热量在管周土壤中不断累积，导致系统换热能力逐渐下降。

![图1a 连续运行下的日均换热退化。固定间隙工况下换热量随运行天数下降，反映近管土壤热饱和效应。](paper_figures/Fig03_heat_saturation_degradation.png){width=72%}

![图1 基准工况下入口/出口空气温度与瞬时换热量响应。出口温度波动幅值明显小于入口温度，表明土壤具有削峰和蓄热作用。](paper_figures/Fig02_baseline_transient.png){width=90%}

### 5.2 管土间隙热阻影响

管土间隙厚度对换热能力影响显著。当间隙厚度从 0 增至 5 mm 时，最后一天日均换热量由 741.0 W 降至 631.8 W，出口空气最终温度由 23.55 degC 升至 25.44 degC。该结果表明，施工中形成的毫米级空气间隙即可显著削弱管土换热。

间隙导热系数也具有明显影响。当 \(k_{\mathrm{gap}}\) 从 0.026 W/(m K) 增至 0.5 W/(m K) 时，最后一天日均换热量由 652.2 W 增至 737.3 W。对于工程设计而言，提高回填材料密实度和导热能力，可有效降低管土界面热阻。

![图2a 固定间隙热阻与温度相关间隙热阻模型对比。温度相关热阻使出口温度略升高、换热量略降低，说明界面状态变化会进一步削弱长期换热性能。](paper_figures/Fig06_variable_gap_extension.png){width=82%}

### 5.3 土壤分层与第二层导热系数影响

由于管道位于第二层土壤，第二层土壤导热系数直接影响近管热扩散能力。当第二层导热系数由 0.8 W/(m K) 增至 2.5 W/(m K) 时，最后一天日均换热量由 598.0 W 增至 747.9 W，近管土壤温升由 4.88 K 降至 2.49 K。较高导热系数增强了热量向远场扩散的能力，因此既提高了换热量，又降低了热饱和程度。

![图2 主要影响因素敏感性分析。管土间隙厚度增大会降低换热量；第二层土壤导热系数、空气质量流量和管长增加会提高总换热量，但单位管长收益随管长增加而下降。](paper_figures/Fig05_sensitivity_summary.png){width=90%}

### 5.4 温度云图与土壤相位检查

分层土壤预计算结果表明，在夏季启动工况下，浅层土壤温度高于深层土壤，符合地表周期热波向下衰减的物理规律。运行 168 h 后，管周出现局部高温区，说明空气向土壤释放的热量主要累积于近管区域。由于模型采用周向分区 RC 网络，能够反映管道上方和下方土壤温度的差异。

![图3a 分层土壤未扰动温度相位检查。EAHE启动相位已与夏季制冷工况对齐，浅层土壤温度高于深层土壤。](paper_figures/Fig01_soil_phase_check.png){width=72%}

![图3 管周土壤温度云图。启动时浅层土壤温度高于深层土壤；运行168 h后管周出现局部热积累区，说明连续制冷运行会改变近管土壤温度场。](paper_figures/Fig04_temperature_field_contours.png){width=90%}

### 5.5 与经典解析模型对比

稳态解析 NTU 模型与瞬态 RC 模型对比表明，解析模型出口温度 RMSE 为 1.35 K，平均偏差为 1.04 K，换热量 RMSE 为 108.65 W。解析模型能够给出一阶估计，但无法描述土壤热容、运行历史和近管局部热积累。因此，对于连续运行和热退化分析，瞬态 RC 模型具有更强的适用性。

![图4 瞬态RC模型与经典稳态解析NTU模型对比。解析模型可给出一阶估计，但不能充分反映土壤热容和运行历史造成的热退化。](paper_figures/Fig07_analytical_model_comparison.png){width=90%}

### 5.6 Ozgener 等（2011）实验热阻验证

从 Ozgener 等（2011）图 3-7 提取的数字化热阻数据表明，文献热阻主要位于 0.0065-0.031 K m/W。各图数字化统计结果如下：图 3 均值为 0.02798 K m/W，图 4 均值为 0.02115 K m/W，图 5 均值为 0.02066 K m/W，图 6 均值为 0.01881 K m/W，图 7 均值为 0.02129 K m/W。其中图 4 和图 7 的均值与文献报告的平均总热阻 0.021 K m/W 高度一致，说明本文的数字化提取结果可靠。

文献图 5 和图 6 表明，总热阻随入口或出口空气温度升高整体呈上升趋势；图 7 表明，总热阻与流体-管壁温差之间具有较强相关性。这一实验现象支持本文进一步引入温度相关管土间隙热阻和土壤状态相关热阻的建模思路。

![图5 Ozgener等（2011）文献图3-7数字化得到的总热阻数据。图4和图7的均值接近文献报告的0.021 K m/W，说明数字化数据与原文结论一致。](paper_figures/Fig08_ozgener2011_digitized_resistance.png){width=90%}

需要说明的是，图5数据来自文献图像数字化，存在读图误差。若后续获得原始实验数据，应优先使用原始数据重新计算误差指标。



表1 主要模拟结果汇总

| 项目 | 代表工况 | 关键结果 | 物理含义 |
|---|---:|---:|---|
| 基准7 d运行 | 固定2 mm间隙 | 最后一天日均换热量693.0 W，退化比0.833 | 连续运行导致近管热饱和 |
| 间隙厚度 | 0 mm -> 5 mm | Q_last由741.0 W降至631.8 W | 管土接触不良显著削弱换热 |
| 第二层导热系数 | 0.8 -> 2.5 W/(m K) | Q_last由598.0 W升至747.9 W | 高导热土层增强远场扩散 |
| 解析模型对比 | 稳态NTU模型 | Tout RMSE=1.35 K | 稳态模型难以反映热历史 |

表2 Ozgener等（2011）热阻数字化统计

| 文献图 | 点数 | 均值/K m W^-1 | 最小值/K m W^-1 | 最大值/K m W^-1 | 与0.021的RMSE/K m W^-1 |
|---|---:|---:|---:|---:|---:|
| Fig3 | 17 | 0.02798 | 0.02380 | 0.03100 | 0.00715 |
| Fig4 | 16 | 0.02115 | 0.01870 | 0.02410 | 0.00123 |
| Fig5 | 16 | 0.02066 | 0.00720 | 0.02760 | 0.00538 |
| Fig6 | 16 | 0.01881 | 0.00700 | 0.02650 | 0.00572 |
| Fig7 | 14 | 0.02129 | 0.00650 | 0.03060 | 0.00764 |

## 6 结论

本文建立了考虑管土间隙热阻与竖向三层土壤分层的水平埋管式 EAHE 瞬态 RC 网络模型，并通过基准响应、热饱和退化、参数敏感性、温度云图、解析模型和文献实验热阻数据进行了分析。主要结论如下：

1. 分层土壤预计算能够为 EAHE 模型提供与季节相位一致的初始土温和远场边界。对于夏季制冷工况，浅层土壤高于深层土壤，温度云图符合物理规律。
2. 连续运行会引起明显热饱和。基准工况 7 d 后，日均换热退化比为 0.833，近管土壤日均升温为 3.36 K。
3. 管土间隙热阻显著削弱换热能力。间隙厚度由 0 增至 5 mm 时，最后一天日均换热量降低约 14.7%。
4. 第二层土壤导热系数是影响长期性能的重要参数。导热系数提高可增强热量向远场扩散，从而提高换热量并降低近管热积累。
5. 与经典稳态解析模型相比，瞬态 RC 模型能够更好地描述土壤热容、运行历史和局部热积累效应。
6. Ozgener 等（2011）实验热阻数据表明，EAHE 总热阻随温度状态变化明显，文献图像数字化结果与其报告的平均热阻一致，为模型验证和可变热阻建模提供了实验依据。

## 7 不足与展望

本文仍存在以下不足：首先，Ozgener 等（2011）实验验证目前主要基于文献表格参数和图像数字化热阻数据，尚未获得完整原始时序数据；其次，可变间隙热阻目前采用经验温度系数表达，尚未与土壤含水率、接触压力和回填材料状态建立直接物理联系；最后，本文近管土壤采用局部周向-径向 RC 网格，尚未考虑多管间热干扰和大尺度三维土壤恢复过程。后续研究应结合更多实验数据，对模型参数进行系统校准，并进一步发展含湿迁移和接触状态演化的管土界面热阻模型。

## 参考文献

[1] Ozgener O, Ozgener L, Goswami D Y. Experimental prediction of total thermal resistance of a closed loop EAHE for greenhouse cooling system. *International Communications in Heat and Mass Transfer*, 2011, 38: 711-716. DOI: 10.1016/j.icheatmasstransfer.2011.03.009.

[2] Ozgener O, Ozgener L. Exergoeconomic analysis of an underground air tunnel system for greenhouse cooling system. *International Journal of Refrigeration*, 2010, 33(5): 995-1005.

[3] Ozgener L, Ozgener O. Experimental study of the exergetic performance of an underground air tunnel system for greenhouse cooling. *Renewable Energy*, 2010, 35(12): 2804-2811.

[4] Goswami D Y, Dhaliwal A A. Heat transfer analysis in environmental control using an underground air tunnel. *Journal of Solar Energy Engineering*, 1985, 107: 141-145.

[5] Rottmayer S P, Beckman W A, Mitchell J W. Simulation of a single vertical U-tube ground heat exchanger in an infinite medium. *ASHRAE Transactions*, 1997, 103(2): 651-659.

[6] de Vries D A. Thermal properties of soils. In: van Wijk W R, ed. *Physics of Plant Environment*. Amsterdam: North-Holland, 1963.

[7] Hillel D. *Introduction to Soil Physics*. San Diego: Academic Press, 1982.
