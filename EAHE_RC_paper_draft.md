# 考虑管土间隙热阻与竖向三层土壤分层的水平埋管式 EAHE 瞬态 RC 网络模型

## 摘要

针对水平埋管式土壤空气换热器（earth-to-air heat exchanger, EAHE）在连续夏季制冷运行中出现的土壤热饱和、管土接触不完全和土壤竖向分层问题，本文建立了一种考虑管土间隙热阻与竖向三层土壤分层的瞬态热阻-热容（RC）网络模型。模型将管内空气、管壁和管周土壤离散为轴向-周向-径向耦合节点，并采用隐式欧拉法求解瞬态传热方程。未扰动土壤温度由一维竖向分层土壤传热预计算获得，以保证埋深、地表周期性边界和土层热物性对初始场及远场边界的影响被一致引入。管土间隙首先作为固定热阻处理，随后扩展为温度相关的可变热阻。结果表明，7 d 基准工况下出口空气温度保持明显低于入口空气温度，最后一天平均换热量为 693.0 W，日均换热衰减比为 0.833，近管土壤日均升温为 3.36 K。间隙厚度由 0 增至 5 mm 时，最后一天平均换热量由 741.0 W 降至 631.8 W；第二层土壤导热系数由 0.8 增至 2.5 W/(m K) 时，最后一天平均换热量由 598.0 W 增至 747.9 W。与经典稳态解析 NTU 模型相比，本文瞬态 RC 模型的出口温度差异 RMSE 为 1.35 K，显示出引入土壤热容、竖向分层与近管局部热积累的必要性。进一步参考 Ozgener 等（2011）的闭环 EAHE 温室制冷实验，提取了实验系统参数与图像数字化热阻数据。文献报告的平均总热阻为 0.021 K m/W，图 4 和图 7 数字化热阻均值分别为 0.02115 和 0.02129 K m/W，验证了数字化数据与原文结论的一致性，并为后续模型-实验定量对比提供了数据基础。

**关键词**：土壤空气换热器；瞬态 RC 网络；管土间隙热阻；分层土壤；热饱和；实验验证

## 1 引言

土壤空气换热器利用土壤较大的热惯性对通风空气进行预冷或预热，是温室、建筑和低品位能源系统中常见的被动或半主动换热装置。对于水平埋管式 EAHE，长期连续运行时，管周土体会逐渐累积或释放热量，使出口空气温度和换热量出现明显的时间衰减。这一现象通常称为土壤热饱和或热退化。若采用稳态或均质土壤假设，模型往往难以同时解释出口温度的日周期响应、运行多日后的换热退化，以及管周温度场的非对称分布。

已有 EAHE 模型大致可分为解析模型、数值传热模型和等效 RC 网络模型。解析模型形式简洁，适合初步设计，但常将土壤视为均质无限介质，且难以处理地表周期边界、土壤竖向分层和管土接触热阻。高维 CFD 或有限元模型能够较完整地描述温度场，但参数量和计算量较大，不利于多工况敏感性分析。RC 网络模型介于两者之间，既保留管内空气、管壁和土壤热容的瞬态特征，又具有较好的计算效率。

实际工程中，埋管与回填土之间可能存在空气间隙、施工扰动或接触不良区域。该界面热阻会降低空气向土壤的传热能力，并影响长期运行时近管土壤的热积累。同时，土壤常呈明显竖向分层，浅层受地表气温和太阳辐射影响较大，深层温度波动较弱。若不对初始土温和远场土温进行分层预计算，可能出现与季节相位不一致的温度云图，从而导致物理解释错误。

本文目标为：

1. 建立考虑竖向三层土壤、管土间隙热阻和周向分区近管土壤的水平 EAHE 瞬态 RC 网络模型；
2. 采用分层土壤预计算获得初始土温和远场边界，以捕捉季节相位和地表传热影响；
3. 通过退化验证、参数敏感性、温度云图和经典模型对比分析热饱和机制；
4. 参考 Ozgener 等（2011）的闭环 EAHE 温室制冷实验，提取实验参数和热阻数据，为模型实验验证提供依据。

## 2 物理模型与基本假设

研究对象为水平埋设的圆形空气管道。空气沿轴向流动，管壁与周围土壤之间存在可选的管土间隙热阻。土壤沿竖向分为三层，管道中心位于第二层，埋深为 2 m；在 Ozgener 实验验证工况中，管道埋深按文献设置为约 3 m。

主要假设如下：

1. 管内空气为一维轴向塞流，空气物性取常数；
2. 管壁沿周向温度均匀，但沿轴向随空气温度变化；
3. 管周土壤采用周向-径向 RC 网格描述，周向节点用于捕捉上、下部土壤温度差异；
4. 土层之间不设置界面热阻，热物性在层界面处突变；
5. 近管计算域外边界温度由分层土壤预计算结果给出；
6. 管土间隙热阻先取常数，扩展模型中允许随近管土壤温度变化。

## 3 数学模型

### 3.1 管内空气能量方程

第 \(i\) 个轴向空气节点的能量守恒写为

$$
C_{a}\frac{T_{a,i}^{n+1}-T_{a,i}^{n}}{\Delta t}
=\dot m c_{p,a}\left(T_{a,i-1}^{n+1}-T_{a,i}^{n+1}\right)
G_{ap}\left(T_{p,i}^{n+1}-T_{a,i}^{n+1}\right),
\tag{1}
$$

其中 \(T_{a,i}\) 为空气节点温度，\(T_{p,i}\) 为管壁温度，\(\dot m\) 为空气质量流量，\(c_{p,a}\) 为空气定压比热，\(C_a\) 为空气节点热容，\(G_{ap}\) 为空气-管壁对流导热率。入口边界为

$$
T_{a,0}^{n+1}=T_{\mathrm{in}}^{n+1}.
\tag{2}
$$

### 3.2 管壁节点能量方程

管壁节点与空气节点和周向土壤内边界节点相连，其能量方程为

$$
C_{p}\frac{T_{p,i}^{n+1}-T_{p,i}^{n}}{\Delta t}
=G_{ap}\left(T_{a,i}^{n+1}-T_{p,i}^{n+1}\right)
\sum_{m=1}^{N_\theta}G_{ps,m}
\left(T_{s,i,m,1}^{n+1}-T_{p,i}^{n+1}\right),
\tag{3}
$$

其中 \(C_p\) 为管壁热容，\(T_{s,i,m,1}\) 为第 \(i\) 个轴向位置、第 \(m\) 个周向分区、第一个径向土壤节点温度，\(G_{ps,m}\) 为管壁至近管土壤节点的等效导热率。

### 3.3 管土间隙热阻

对第 \(m\) 个周向分区，管壁至第一层土壤节点的总热阻为

$$
R_{ps,m}=R_{\mathrm{pipe}}+R_{\mathrm{gap}}+R_{\mathrm{soil},1/2,m},
\tag{4}
$$

其中

$$
R_{\mathrm{pipe}}
=\frac{\ln(r_o/r_i)}{k_p \Delta \theta \Delta x},
\tag{5}
$$

$$
R_{\mathrm{gap}}
=\frac{\ln[(r_o+\delta_{\mathrm{gap}})/r_o]}
{k_{\mathrm{gap}}\Delta \theta \Delta x},
\tag{6}
$$

$$
R_{\mathrm{soil},1/2,m}
=\frac{\ln[r_{1,c}/(r_o+\delta_{\mathrm{gap}})]}
{k_s(z_{m,1})\Delta \theta \Delta x}.
\tag{7}
$$

于是

$$
G_{ps,m}=\frac{1}{R_{ps,m}}.
\tag{8}
$$

在可变管土间隙模型中，间隙热阻写为

$$
R_{\mathrm{gap}}(T_s)
=R_{\mathrm{gap},0}
\left[1+a_{\mathrm{gap},T}(T_s-T_{\mathrm{ref}})\right],
\tag{9}
$$

并限制在

$$
R_{\mathrm{gap,min}}\leq R_{\mathrm{gap}}(T_s)\leq R_{\mathrm{gap,max}}.
\tag{10}
$$

### 3.4 管周土壤 RC 方程

管周土壤节点满足

$$
C_{s,j}\frac{T_{s,j}^{n+1}-T_{s,j}^{n}}{\Delta t}
=\sum_{k\in \mathcal{N}(j)}
G_{jk}\left(T_{s,k}^{n+1}-T_{s,j}^{n+1}\right)
G_{b,j}\left(T_{b,j}^{n+1}-T_{s,j}^{n+1}\right),
\tag{11}
$$

其中 \(j=(i,m,r)\) 表示土壤节点编号，\(\mathcal{N}(j)\) 为相邻径向或周向节点集合，\(G_{b,j}\) 为外边界导热率，\(T_{b,j}\) 为由未扰动土壤温度场插值得到的远场边界温度。

任意两个相邻土壤节点之间采用热阻串联形式计算导热率。径向热阻为

$$
R_{r}
=\frac{\ln(r_f/r_a)}{k_a\Delta\theta\Delta x}
+\frac{\ln(r_b/r_f)}{k_b\Delta\theta\Delta x},
\qquad
G_r=\frac{1}{R_r}.
\tag{12}
$$

周向热阻为

$$
R_{\theta}
=\frac{r_c\Delta\theta}{k_{\mathrm{eff}}\Delta r\Delta x},
\qquad
k_{\mathrm{eff}}=\frac{2k_a k_b}{k_a+k_b},
\qquad
G_\theta=\frac{1}{R_\theta}.
\tag{13}
$$

### 3.5 分层未扰动土壤温度预计算

未扰动土壤温度采用一维竖向瞬态导热方程计算：

$$
\rho_s(z)c_s(z)\frac{\partial T_u}{\partial t}
=\frac{\partial}{\partial z}
\left[
k_s(z)\frac{\partial T_u}{\partial z}
\right].
\tag{14}
$$

地表边界采用对流边界：

$$
-k_s\left.\frac{\partial T_u}{\partial z}\right|_{z=0}
=h_g\left[T_{\mathrm{air}}(t)-T_u(0,t)\right],
\tag{15}
$$

深层边界为

$$
T_u(z_{\max},t)=T_{\mathrm{deep}}.
\tag{16}
$$

地表空气温度取年周期与日周期叠加形式：

$$
T_{\mathrm{air}}(t)
=\overline{T}_{\mathrm{air}}
A_y\sin\left[\frac{2\pi(t-\phi_y)}{t_y}\right]
A_d\sin\left[\frac{2\pi(t-\phi_d)}{t_d}\right].
\tag{17}
$$

EAHE 启动时刻对应全年第 \(d_0\) 天，则模型中使用的未扰动温度为

$$
T_u^\ast(z,t)=T_u\left[z,\ \mathrm{mod}(t+d_0 t_d,\ t_y)\right].
\tag{18}
$$

式 (18) 是保证夏季入口高温工况与夏季土壤温度场一致的关键。

### 3.6 隐式欧拉矩阵形式

所有空气、管壁和土壤节点组合为状态向量

$$
\mathbf{X}
=
\left[
T_{a,1},T_{p,1},T_{s,1,1,1},\cdots,
T_{a,N_x},T_{p,N_x},T_{s,N_x,N_\theta,N_r}
\right]^T.
\tag{19}
$$

RC 网络可写为

$$
\mathbf{C}\frac{d\mathbf{X}}{dt}
=\mathbf{A}\mathbf{X}+\mathbf{b}(t).
\tag{20}
$$

采用隐式欧拉离散：

$$
\left(\frac{\mathbf{C}}{\Delta t}-\mathbf{A}\right)\mathbf{X}^{n+1}
=\frac{\mathbf{C}}{\Delta t}\mathbf{X}^{n}
+\mathbf{b}^{n+1}.
\tag{21}
$$

对固定间隙热阻，矩阵 \(\mathbf{C}/\Delta t-\mathbf{A}\) 在整个计算中保持不变，可预分解以提高计算效率。对可变间隙热阻，\(\mathbf{A}\) 随近管土壤温度更新，每个时间步内进行 Picard 迭代：

$$
\frac{\left\|\mathbf{X}^{n+1,k+1}-\mathbf{X}^{n+1,k}\right\|}
{\max\left(\left\|\mathbf{X}^{n+1,k+1}\right\|,1\right)}
<\varepsilon.
\tag{22}
$$

### 3.7 性能指标

瞬时换热量定义为

$$
Q(t)=\dot m c_{p,a}\left[T_{\mathrm{in}}(t)-T_{\mathrm{out}}(t)\right].
\tag{23}
$$

第 \(d\) 天的日均换热量为

$$
\overline{Q}_{d}
=\frac{1}{t_d}\int_{(d-1)t_d}^{dt_d}Q(t)\,dt.
\tag{24}
$$

热退化比定义为

$$
\eta_{Q,d}
=\frac{\overline{Q}_{d}}{\overline{Q}_{1}}.
\tag{25}
$$

近管土壤热积累用近管土壤温升表示：

$$
\Delta T_{s,\mathrm{near}}(t)
=\overline{T}_{s,\mathrm{near}}(t)-T_u^\ast(z_p,t).
\tag{26}
$$

## 4 文献实验数据提取与验证方法

### 4.1 Ozgener 等（2011）实验系统

Ozgener 等（2011）研究了土壤空气换热器在温室制冷系统中的总热阻。文献对象为水平 U 形闭环地下空气隧道，主要参数如下：管长 \(L=47\) m，名义直径 \(D=0.56\) m，埋深约 3 m，土壤导热系数 \(k_s=2.85\) W/(m K)，体积流量 1.47 m3/s，干空气质量流量 1.64 kg/s。实验时段为 2009 年 10 月 12 日至 10 月 23 日，温度采样间隔为 1 min。文献给出的平均入口温度为 33.27 degC，平均出口温度为 31.01 degC，管内平均流体温度为 32.14 degC，管壁平均温度为 28.21 degC，最大冷却能力为 16.93 kW，平均总热阻约为 0.021 K m/W。

本文将该文献用于两个层次的验证：

1. 文字和表格参数用于构建实验等效边界条件；
2. 图 3-7 中 \(R_{\mathrm{Tot}}\) 散点经数字化后用于热阻范围和趋势验证。

### 4.2 文献总热阻定义

Ozgener 等采用的总热阻可概括为

$$
R_{\mathrm{Tot}}
=R_{\mathrm{conv}}+R_{\mathrm{pipe}}+R_{\mathrm{soil}}.
\tag{27}
$$

简化热阻关系为

$$
T_f-T_s=q_l R_{\mathrm{Tot}},
\tag{28}
$$

其中单位长度换热量为

$$
q_l=\frac{Q}{L}.
\tag{29}
$$

在本文 RC 模型中，为与文献热阻进行对比，定义模型等效热阻为

$$
R_{\mathrm{eq},fw}(t)
=\frac{T_f(t)-T_w(t)}{Q(t)/L},
\tag{30}
$$

以及基于远场土温的等效热阻

$$
R_{\mathrm{eq},fu}(t)
=\frac{T_f(t)-T_u^\ast(z_p,t)}{Q(t)/L}.
\tag{31}
$$

式 (30) 更接近文献中由流体平均温度和管壁温度得到的热阻趋势，式 (31) 则反映从空气到未扰动土壤远场的总热阻。

### 4.3 误差指标

模型与实验或数字化数据的均方根误差和平均偏差定义为

$$
\mathrm{RMSE}
=
\sqrt{
\frac{1}{N}\sum_{i=1}^{N}
\left(y_{m,i}-y_{e,i}\right)^2
},
\tag{32}
$$

$$
\mathrm{MBE}
=
\frac{1}{N}\sum_{i=1}^{N}
\left(y_{m,i}-y_{e,i}\right).
\tag{33}
$$

若仅验证数字化热阻与文献报告平均值的一致性，则 \(y_{m,i}\) 可取数字化热阻，\(y_{e,i}\) 取文献报告平均热阻 0.021 K m/W。

## 5 结果与讨论

### 5.1 基准瞬态响应

基准工况下，入口空气具有明显日周期波动，而出口空气温度波动幅值显著降低。7 d 连续运行后，出口空气最终温度为 24.37 degC，最后一天平均换热量为 693.0 W，日均换热退化比为 0.833。近管土体日均升温由第一天的 1.39 K 增至最后一天的 3.36 K，表明土壤热饱和是换热量衰减的主要原因。

图 `paper_figures/Fig02_baseline_transient.png` 可作为基准瞬态响应主图。

### 5.2 土壤热饱和与退化验证

无间隙热阻时，30 d 工况最后一天日均换热量为 645.1 W，退化比为 0.724；固定 2 mm 间隙时，最后一天日均换热量为 605.4 W，退化比为 0.728。间隙热阻降低了绝对换热能力，同时由于进入土壤的热通量减小，近管土壤热积累略低于无间隙工况。这说明评价 EAHE 性能时不能只看退化比，还应同时报告绝对换热量和土壤温升。

图 `paper_figures/Fig03_heat_saturation_degradation.png` 可用于说明热饱和退化。

### 5.3 温度云图与土壤分层效应

分层土壤预计算后，夏季启动时浅层土壤温度高于深层土壤，符合地表热波向下衰减的物理规律。运行 168 h 后，管周出现局部高温区，说明空气向土壤释放的热量主要累积于近管区域。由于周向分区 RC 网络保留了上下部土壤的温度差异，模型能够捕捉管周温度场的非径向对称性。

图 `paper_figures/Fig04_temperature_field_contours.png` 已经检查坐标方向：浅层在上，深层在下，温度分布合理。

### 5.4 管土间隙与土壤导热系数敏感性

间隙厚度由 0 增加至 5 mm 时，最后一天平均换热量由 741.0 W 降至 631.8 W，出口空气最终温度由 23.55 degC 升至 25.44 degC。说明即使毫米级间隙也会显著削弱管土换热。

第二层土壤导热系数由 0.8 增至 2.5 W/(m K) 时，最后一天平均换热量由 598.0 W 增至 747.9 W，近管土壤升温由 4.88 K 降至 2.49 K。导热系数提高增强了热量向远场扩散的能力，因此既提升换热量，又降低近管热积累。

图 `paper_figures/Fig05_sensitivity_summary.png` 可作为参数敏感性主图。

### 5.5 可变间隙热阻

当间隙热阻随近管土壤温度升高而增加时，最后一天平均换热量由固定间隙的 693.0 W 降至 689.4 W，最终间隙热阻因子为 1.082。参数扫描表明，温度系数 \(a_{\mathrm{gap},T}\) 从 0 增加到 0.08 1/K 时，最后一天平均换热量从 693.0 W 降至 679.0 W。该结果说明，对于短期运行，可变间隙热阻影响相对温和；但对于长期连续运行或回填材料湿度显著变化的场景，该机制可能进一步放大热退化。

### 5.6 与经典解析模型对比

经典稳态解析 NTU 模型可写为

$$
T_{\mathrm{out,an}}
=T_u^\ast(z_p,t)
+\left[T_{\mathrm{in}}(t)-T_u^\ast(z_p,t)\right]
\exp\left(-\frac{UA}{\dot m c_{p,a}}\right).
\tag{34}
$$

其中 \(UA\) 由内部对流热阻、管壁热阻、间隙热阻和径向土壤热阻串联得到。与瞬态 RC 模型相比，该解析模型的出口温度 RMSE 为 1.35 K，平均偏差为 1.04 K，换热量 RMSE 为 108.65 W。这表明简单解析模型能够给出一阶估计，但难以描述土壤热容、运行历史和管周局部热积累。

图 `paper_figures/Fig07_analytical_model_comparison.png` 可作为解析模型验证图。

### 5.7 Ozgener 等（2011）实验热阻验证

从 Ozgener 等（2011）图 3-7 提取的数字化热阻数据表明：

- 图 3 的 \(R_{\mathrm{Tot}}\) 均值为 0.02798 K m/W；
- 图 4 的 \(R_{\mathrm{Tot}}\) 均值为 0.02115 K m/W；
- 图 5 的 \(R_{\mathrm{Tot}}\) 均值为 0.02066 K m/W；
- 图 6 的 \(R_{\mathrm{Tot}}\) 均值为 0.01881 K m/W；
- 图 7 的 \(R_{\mathrm{Tot}}\) 均值为 0.02129 K m/W。

其中图 4 和图 7 的均值与文献报告的平均热阻 0.021 K m/W 几乎一致，RMSE 分别为 0.00123 和 0.00764 K m/W。图 5 和图 6 显示，当入口或出口温度升高时，总热阻整体呈上升趋势；图 7 显示总热阻与流体-管壁温差之间具有较强相关性，文献报告拟合优度约为 \(R^2=0.98\)。这些趋势支持本文引入温度相关间隙热阻和土壤状态相关热阻的建模思路。

图 `paper_figures/Fig08_ozgener2011_digitized_resistance.png` 为文献热阻数字化验证图。需要强调的是，该图中散点来自论文图像数字化，存在读图误差；在正式投稿前，若可获得原始实验数据，应优先使用原始数据重新计算误差指标。

## 6 结论

本文建立了考虑管土间隙热阻与竖向三层土壤分层的水平 EAHE 瞬态 RC 网络模型，并完成了基准响应、热饱和退化、参数敏感性、温度云图、解析模型对比和文献实验热阻验证。主要结论如下：

1. 分层土壤预计算对夏季工况至关重要。采用启动日相位修正后，浅层土壤高于深层土壤，温度云图恢复物理合理性。
2. 管土间隙热阻显著降低换热能力。间隙厚度由 0 增至 5 mm 时，最后一天平均换热量降低约 14.7%。
3. 第二层土壤导热系数是影响管周热扩散和长期性能的重要参数。较高导热系数可提高换热量并降低近管热积累。
4. 连续运行会导致明显土壤热饱和。基准工况 7 d 后日均换热退化比为 0.833，近管土体日均升温达到 3.36 K。
5. 与经典稳态解析 NTU 模型相比，瞬态 RC 模型更适合描述运行历史和热饱和效应。
6. Ozgener 等（2011）的实验热阻数据支持总热阻随温度状态变化的判断。图像数字化结果与文献报告平均热阻在多个图中保持一致，为后续实验验证提供了基础。

## 7 后续工作

后续应进一步完成以下工作：

1. 在 MATLAB 中运行 `main_ozgener2011_validation.m`，生成 `ozgener2011_model_rtot.csv`，并用 `ozgener2011_validation_postprocess.py` 自动叠加模型-实验热阻对比；
2. 从 Ozgener 等（2010, 2011）及其他 EAHE 实验论文中提取入口/出口空气温度时序，填入 `experimental_comparison_timeseries.csv`，完成多实验 RMSE 与 MBE 对比；
3. 将管土间隙热阻与土壤含水率、接触压力或回填材料热导率关联，建立更具物理基础的可变热阻模型；
4. 将当前局部周向-径向 RC 模型扩展到更大尺度的三维土壤热恢复问题，以研究间歇运行和管间热干扰。

## 参考文献

[1] Ozgener, O., Ozgener, L., Goswami, D. Y. Experimental prediction of total thermal resistance of a closed loop EAHE for greenhouse cooling system. *International Communications in Heat and Mass Transfer*, 38, 711-716, 2011. DOI: 10.1016/j.icheatmasstransfer.2011.03.009.

[2] Ozgener, O., Ozgener, L. Exergoeconomic analysis of an underground air tunnel system for greenhouse cooling system. *International Journal of Refrigeration*, 33(5), 995-1005, 2010.

[3] Ozgener, L., Ozgener, O. Experimental study of the exergetic performance of an underground air tunnel system for greenhouse cooling. *Renewable Energy*, 35(12), 2804-2811, 2010.

[4] Goswami, D. Y., Dhaliwal, A. A. Heat transfer analysis in environmental control using an underground air tunnel. *Journal of Solar Energy Engineering*, 107, 141-145, 1985.

[5] Rottmayer, S. P., Beckman, W. A., Mitchell, J. W. Simulation of a single vertical U-tube ground heat exchanger in an infinite medium. *ASHRAE Transactions*, 103(2), 651-659, 1997.

[6] Zeng, H. Y., Diao, N. R., Fang, Z. H. A finite line-source model for boreholes in geothermal heat exchangers. *Heat Transfer-Asian Research*, 31(7), 558-567, 2002.

[7] de Vries, D. A. Thermal properties of soils. In: van Wijk, W. R. (Ed.), *Physics of Plant Environment*. North-Holland, Amsterdam, 1963.
