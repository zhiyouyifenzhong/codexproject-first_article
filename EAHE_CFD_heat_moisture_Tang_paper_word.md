# 考虑水汽分压-相对湿度耦合与 Tang 型界面热接触的土壤-空气换热器热湿迁移模型

## 摘要

针对水平埋管式土壤-空气换热器在长期运行过程中存在的土壤热湿耦合迁移、管土接触不完全以及热饱和退化问题，本文拟建立一种空气侧湍流流动、管壁导热、非饱和土壤热湿迁移与管土界面热接触阻力相耦合的数值模型。空气侧采用 Reynolds 平均 Navier-Stokes 方程和标准 \(k-\varepsilon\) 湍流模型，土壤侧采用以温度 \(T_s\)、体积含水率 \(\theta\)、水汽分压 \(p_v\) 和相对湿度 \(\varphi\) 为状态变量的非饱和多孔介质热湿耦合模型。水分迁移同时考虑液态水通量与水汽通量，水汽迁移通过水汽分压和相对湿度关系描述，土壤水力特性采用 Van Genuchten-Mualem 模型。管土界面引入 Tang 等提出的一般热接触模型，将管土间隙热阻、接触热阻和界面热流收缩效应统一表示为单位面积热阻 \(R_{int}^{\prime\prime}\) 与分配接触系数 \(\eta_{int}\)。模型可退化为完美接触、温度跳跃接触和分配接触三类界面条件。研究将基于 COMSOL Multiphysics 建立耦合求解流程，并结合 MATLAB/Python 进行参数反演、实验验证与论文图表生成。

**关键词**：土壤-空气换热器；热湿耦合；水汽分压；相对湿度；\(k-\varepsilon\) 湍流模型；界面热阻；Tang 热接触模型

## 1 引言

土壤-空气换热器利用浅层土壤温度相对稳定和热容量较大的特点，对进入建筑或温室的空气进行预冷或预热。传统模型多将土壤视为均质导热介质，或将管土换热简化为固定总热阻。然而，实际工程中管道周围土体常呈非饱和状态，温度梯度会诱导液态水和水汽迁移，而含水率变化又会改变土壤导热系数、体积热容和潜热输运能力。同时，管壁与回填土之间可能存在空气间隙、局部脱空或不完全接触，使界面出现温度跳跃和热流收缩。

刘庆功关于土壤-空气换热器热湿迁移的研究表明，管周土壤温度场和湿度场相互影响，且湿度场在径向与轴向上的分布明显不同。因此，若要描述长期运行中的土壤热饱和与恢复过程，模型应保留管长方向上的土壤水分迁移。Tang 等关于多层饱和土界面热接触的研究进一步说明，界面粗糙度、孔隙和孔隙水会造成热流线收缩并引起温度跳跃，可用一般热接触模型统一表示。

基于上述认识，本文拟从原有 RC 网络模型扩展为 CFD-多孔介质热湿耦合模型。原 RC 模型保留为低阶退化模型，用于快速参数分析和退化验证；新模型则用于揭示水汽分压、相对湿度、轴向湿分迁移和管土界面热阻对 EAHE 热湿性能的影响。

## 2 物理模型

计算域由四个部分组成：

\[
\Omega=\Omega_a+\Omega_p+\Omega_g+\Omega_s ,
\qquad (1)
\]

其中 \(\Omega_a\) 为管内空气区域，\(\Omega_p\) 为管壁区域，\(\Omega_g\) 为管土间隙或界面区域，\(\Omega_s\) 为三层非饱和土壤区域。土壤沿竖向分层：

\[
0<z<z_1,\quad z_1<z<z_2,\quad z_2<z<z_{max}.
\qquad (2)
\]

各土层具有不同的热物性和水力参数：

\[
\lambda_s,\ \rho_s,\ c_s,\ \varepsilon,\ \theta_s,\ \theta_r,\ K_s,\ \alpha,\ n .
\qquad (3)
\]

管道为水平埋设，轴向为 \(x\)，竖向为 \(z\)，横向为 \(y\)。若采用二维简化，可建立轴对称或 \(x-r\) 准三维模型；若需同时保留竖向三层土壤和地表边界，推荐采用三维模型。

## 3 空气侧湍流与水汽输运模型

管内空气采用不可压缩或弱可压缩 RANS 模型。连续方程为

\[
\nabla\cdot(\rho_a\mathbf{u})=0 .
\qquad (4)
\]

动量方程为

\[
\nabla\cdot(\rho_a\mathbf{u}\mathbf{u})
=-\nabla p+
\nabla\cdot
\left[
(\mu+\mu_t)
(\nabla\mathbf{u}+\nabla\mathbf{u}^{T})
\right].
\qquad (5)
\]

标准 \(k-\varepsilon\) 模型中，湍流黏度为

\[
\mu_t=\rho_a C_\mu \frac{k^2}{\varepsilon}.
\qquad (6)
\]

湍动能方程为

\[
\nabla\cdot(\rho_a\mathbf{u}k)
=
\nabla\cdot
\left[
\left(\mu+\frac{\mu_t}{\sigma_k}\right)\nabla k
\right]
+G_k-\rho_a\varepsilon .
\qquad (7)
\]

耗散率方程为

\[
\nabla\cdot(\rho_a\mathbf{u}\varepsilon)
=
\nabla\cdot
\left[
\left(\mu+\frac{\mu_t}{\sigma_\varepsilon}\right)\nabla\varepsilon
\right]
+C_{1\varepsilon}\frac{\varepsilon}{k}G_k
-C_{2\varepsilon}\rho_a\frac{\varepsilon^2}{k}.
\qquad (8)
\]

空气能量方程为

\[
\nabla\cdot(\rho_a c_{pa}\mathbf{u}T_a)
=
\nabla\cdot
\left[
\left(\lambda_a+\frac{\mu_t c_{pa}}{Pr_t}\right)\nabla T_a
\right]+S_T .
\qquad (9)
\]

空气中水汽质量分数 \(Y_v\) 满足

\[
\nabla\cdot(\rho_a\mathbf{u}Y_v)
=
\nabla\cdot
\left[
\left(\rho_a D_v+\frac{\mu_t}{Sc_t}\right)\nabla Y_v
\right]+S_v .
\qquad (10)
\]

空气相对湿度由

\[
\varphi_a=\frac{p_{v,a}}{p_{vs}(T_a)}
\qquad (11)
\]

计算，其中 \(p_{v,a}\) 可由 \(Y_v\) 与混合气体状态方程换算得到。

## 4 非饱和土壤水汽分压-相对湿度模型

土壤侧基本未知量为

\[
T_s,\quad \theta,\quad p_v,\quad \varphi .
\qquad (12)
\]

水汽分压与相对湿度满足

\[
p_v=\varphi p_{vs}(T_s).
\qquad (13)
\]

水汽密度为

\[
\rho_v=\frac{p_v}{R_vT_s}.
\qquad (14)
\]

有效饱和度定义为

\[
S_e=\frac{\theta-\theta_r}{\theta_s-\theta_r}.
\qquad (15)
\]

Van Genuchten 模型给出基质势水头：

\[
h_m=
-\frac{1}{\alpha}
\left[
S_e^{-1/m}-1
\right]^{1/n},
\qquad
m=1-\frac{1}{n}.
\qquad (16)
\]

Mualem 导水率为

\[
K(\theta)
=K_sS_e^{1/2}
\left[
1-\left(1-S_e^{1/m}\right)^m
\right]^2 .
\qquad (17)
\]

液态水质量通量为

\[
\mathbf{j}_l
=
-\rho_wK(\theta)(\nabla h_m+\mathbf{e}_z).
\qquad (18)
\]

水汽质量通量采用水汽分压形式：

\[
\mathbf{j}_v
=
-\frac{D_{veff}}{R_vT_s}\nabla p_v
+\frac{D_{veff}p_v}{R_vT_s^2}\nabla T_s .
\qquad (19)
\]

土壤气相孔隙率为

\[
\varepsilon_a=\varepsilon-\theta .
\qquad (20)
\]

总湿分守恒方程为

\[
\frac{\partial}{\partial t}
(\rho_w\theta+\varepsilon_a\rho_v)
+\nabla\cdot(\mathbf{j}_l+\mathbf{j}_v)=0 .
\qquad (21)
\]

该式保留了轴向、径向和竖向水分迁移。当采用三维模型时：

\[
\theta=\theta(x,y,z,t),\quad
p_v=p_v(x,y,z,t),\quad
\varphi=\varphi(x,y,z,t).
\qquad (22)
\]

## 5 土壤能量方程

土壤等效体积热容为

\[
(\rho c)_{eff}
=
(1-\varepsilon)\rho_sc_s
+\theta\rho_wc_w
+\varepsilon_a\rho_vc_v .
\qquad (23)
\]

土壤能量方程写为

\[
(\rho c)_{eff}
\frac{\partial T_s}{\partial t}
=
\nabla\cdot(\lambda_{eff}\nabla T_s)
-\nabla\cdot(c_w\mathbf{j}_lT_s)
-\nabla\cdot(c_v\mathbf{j}_vT_s)
-L_v\nabla\cdot\mathbf{j}_v .
\qquad (24)
\]

其中右端四项依次表示导热、液态水显热迁移、水汽显热迁移和水汽潜热迁移。土壤等效导热系数可先采用经验函数：

\[
\lambda_{eff}=\lambda_{dry}+a_\theta\theta ,
\qquad (25)
\]

后续再根据土壤类型改用更精确的含水率函数。

## 6 Tang 型管土界面热接触模型

Tang 等提出的一般热接触模型可迁移到管土界面。定义管壁外表面温度为 \(T_{p,o}\)，土壤界面温度为 \(T_{s,int}\)，参考温度为 \(T_0\)，界面热流密度为 \(q_{int}\)，则

\[
R_{int}^{\prime\prime}q_{int}
=
(T_{p,o}-T_0)
-\eta_{int}(T_{s,int}-T_0).
\qquad (26)
\]

因此

\[
q_{int}
=
\frac{(T_{p,o}-T_0)-\eta_{int}(T_{s,int}-T_0)}
{R_{int}^{\prime\prime}} .
\qquad (27)
\]

当 \(\eta_{int}=1\) 时，式 (27) 退化为温度跳跃热阻模型：

\[
q_{int}
=
\frac{T_{p,o}-T_{s,int}}{R_{int}^{\prime\prime}} .
\qquad (28)
\]

当 \(R_{int}^{\prime\prime}=0,\eta_{int}=1\) 时，退化为完美热接触：

\[
T_{p,o}=T_{s,int}.
\qquad (29)
\]

单位面积总界面热阻定义为

\[
R_{int}^{\prime\prime}
=R_{gap}^{\prime\prime}+R_c^{\prime\prime}.
\qquad (30)
\]

间隙热阻为

\[
R_{gap}^{\prime\prime}
=
\frac{r_o\ln[(r_o+\delta_{gap})/r_o]}
{\lambda_{gap,eff}} .
\qquad (31)
\]

接触热阻为

\[
R_c^{\prime\prime}=\frac{1}{h_c}.
\qquad (32)
\]

考虑含水率、相对湿度和压实状态时，可取

\[
R_{int}^{\prime\prime}
=
R_{int,0}^{\prime\prime}
\exp[-a_\theta(\theta-\theta_0)]
\exp[-a_\varphi(\varphi-\varphi_0)]
\exp[-a_\sigma\sigma_n'] .
\qquad (33)
\]

式 (33) 表示含水率越高、相对湿度越高、法向有效应力越大，管土界面接触越充分，热阻越小。若只考虑含水率效应，可先简化为

\[
R_{int}^{\prime\prime}
=
R_{int,0}^{\prime\prime}
\exp[-a_\theta(\theta-\theta_0)] .
\qquad (34)
\]

管壁对土壤不透水：

\[
(\mathbf{j}_l+\mathbf{j}_v)\cdot\mathbf{n}=0 .
\qquad (35)
\]

## 7 初始条件与边界条件

管内入口给定速度、温度和相对湿度：

\[
\mathbf{u}=\mathbf{u}_{in},\quad
T_a=T_{in}(t),\quad
\varphi_a=\varphi_{in}(t).
\qquad (36)
\]

管内出口采用压力出口和充分发展边界：

\[
p=p_{out},\quad
\frac{\partial T_a}{\partial x}=0,\quad
\frac{\partial Y_v}{\partial x}=0.
\qquad (37)
\]

地表热边界为

\[
-\lambda_s\nabla T_s\cdot\mathbf{n}
=
h_s(T_{air}-T_s)
+q_{solar}
-q_{rad}
-q_{evap}.
\qquad (38)
\]

地表湿边界为

\[
(\mathbf{j}_l+\mathbf{j}_v)\cdot\mathbf{n}=E_s .
\qquad (39)
\]

底部边界为

\[
T_s=T_{deep},
\qquad (40)
\]

\[
(\mathbf{j}_l+\mathbf{j}_v)\cdot\mathbf{n}=0 .
\qquad (41)
\]

远场边界可由未扰动土壤预计算结果给出：

\[
T_s=T_{undist}(z,t),
\qquad (42)
\]

\[
\theta=\theta_{undist}(z,t).
\qquad (43)
\]

## 8 数值实施方案

### 8.1 COMSOL 模型

COMSOL 模型建议采用以下物理场：

1. 管内空气：Turbulent Flow, \(k-\varepsilon\)；
2. 空气温度：Heat Transfer in Fluids；
3. 管壁与土壤温度：Heat Transfer in Solids 或 General Form PDE；
4. 土壤含水率：General Form PDE；
5. 土壤水汽分压：General Form PDE；
6. 空气水汽输运：Transport of Diluted Species 或 General Form PDE；
7. 管土界面：Thin Layer / Thermal Contact / Weak Contribution 实现 Tang 型热接触条件。

若许可证限制导致特定模块不可用，可优先使用 COMSOL 基础 PDE 接口实现土壤热湿方程。

### 8.2 已完成的 COMSOL 链路验证

已在本机调用 COMSOL 6.3 批处理程序：

```text
G:\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe
```

并对已有模板 `Untitled12.mph` 进行了修复和试算。修复内容包括删除错误周期边界、删除错误无限元设置、删除不一致的非等温流耦合、补充空气流动物性和传热物性。修复后的模型保存为：

```text
G:\codexproject\comsol_outputs\Untitled12_repaired_solved.mph
```

该结果只证明 COMSOL 批处理、Java API 和传热/湍流求解链路可用，尚不能作为 EAHE 正式结果。

在此基础上，本文进一步建立了一个干土固定界面热阻二维基准模型。该模型采用 \(x-z\) 横截面，土壤区域宽度为 8 m、深度为 8 m，管道中心埋深为 2 m，位于第二层土壤中。土壤导热系数按深度分段给定，地表给定等效高温边界，底部给定深层恒温边界，管周采用固定单位面积界面热阻与等效管壁温度构造热通量边界。该模型的目的不是替代最终三维 \(k-\varepsilon\) 热湿耦合模型，而是用于检查竖向坐标、土层分配、固定界面热阻和温度云图方向是否正确。

干热二维基准模型已完成 7 d 瞬态求解。最终时刻地表平均温度约为 \(27.4\,^\circ\mathrm{C}\)，深部平均温度约为 \(16.0\,^\circ\mathrm{C}\)，管周 0.35 m 范围内平均温度约为 \(24.5\,^\circ\mathrm{C}\)。温度云图显示地表高温带位于上部、深层保持低温，管周出现局部高温核，说明深度变量采用 \(depth=-y\) 的处理是正确的，未出现浅层温度被反向赋值的问题。

![COMSOL 干热二维基准温度云图](G:/codexproject/paper_figures/Fig09_comsol_dry_thermal_2D_temperature.png)

进一步改变固定界面热阻 \(R_{int}^{\prime\prime}\) 进行敏感性检查。当 \(R_{int}^{\prime\prime}\) 从 \(0.020\) 增至 \(0.080\,\mathrm{m^2K/W}\) 时，管周 0.35 m 范围内最终平均温度由 \(25.80\,^\circ\mathrm{C}\) 降至 \(22.72\,^\circ\mathrm{C}\)。这说明在给定等效管壁温度的干热基准模型中，界面热阻越大，管道向土壤释放的热扰动越弱，趋势符合传热机理。图中最大温度主要受地表等效高温边界控制，因此评价界面热阻影响时应优先采用管周平均温度或管壁积分热流，而不应仅比较全域最高温度。

![COMSOL 干热基准界面热阻敏感性](G:/codexproject/paper_figures/Fig10_comsol_dry_interface_sensitivity.png)

### 8.3 计算工况

建议设置以下四类界面热接触工况：

\[
R_{int}^{\prime\prime}=0,\quad \eta_{int}=1
\qquad (44)
\]

\[
R_{int}^{\prime\prime}>0,\quad \eta_{int}=1
\qquad (45)
\]

\[
R_{int}^{\prime\prime}=0,\quad \eta_{int}\neq1
\qquad (46)
\]

\[
R_{int}^{\prime\prime}>0,\quad \eta_{int}\neq1 .
\qquad (47)
\]

分别对应完美接触、温度跳跃接触、分配接触和一般热接触模型。

### 8.4 输出指标

主要输出指标包括：

\[
T_{out}(t),\quad \varphi_{out}(t),\quad Q_s(t),\quad Q_l(t),
\qquad (48)
\]

\[
T_s(x,y,z,t),\quad \theta(x,y,z,t),\quad p_v(x,y,z,t),\quad \varphi(x,y,z,t),
\qquad (49)
\]

\[
R_{int}^{\prime\prime},\quad q_{int},\quad \Delta T_{int}.
\qquad (50)
\]

其中显热换热量为

\[
Q_s=\dot m c_{pa}(T_{in}-T_{out}),
\qquad (51)
\]

潜热换热量为

\[
Q_l=\dot m(h_{v,in}-h_{v,out}).
\qquad (52)
\]

## 9 退化验证与先导计算结果

为避免直接进入高维 CFD-热湿耦合模型后难以判断误差来源，本文将已建立的三层土壤瞬态 RC 模型作为低阶退化模型。该模型保留水平埋管、竖向三层土壤、管周周向分区和管土间隙热阻，可用于检查土壤热饱和趋势、界面热阻敏感性和数值离散稳定性。

在基准工况下，7 d 连续运行后的出口温度为 \(24.37\,^\circ\mathrm{C}\)，末日平均换热量为 \(693.0\,\mathrm{W}\)，末日换热退化系数为 0.833，管周土壤平均温升约为 \(3.36\,\mathrm{K}\)。该结果表明，随着运行时间增加，管周土壤逐渐升温，出口空气冷却能力下降，模型能够捕捉 EAHE 的热饱和效应。

![基准工况出口温度与换热量](G:/codexproject/paper_figures/Fig02_baseline_transient.png)

管土间隙厚度对换热性能具有单调影响。当间隙厚度由 0 增至 5 mm 时，末时刻出口温度由 \(23.55\,^\circ\mathrm{C}\) 升高至 \(25.44\,^\circ\mathrm{C}\)，末日平均换热量由 \(741.0\,\mathrm{W}\) 降低至 \(631.8\,\mathrm{W}\)。这说明管土界面热阻不能简单忽略，尤其在施工回填不密实或管壁周围存在空气夹层时，界面热阻会显著削弱管内空气与土壤之间的热交换。

![界面热阻与运行参数敏感性](G:/codexproject/paper_figures/Fig05_sensitivity_summary.png)

三层土壤参数敏感性计算进一步表明，管道所在第二层土壤导热系数由 \(0.80\) 增至 \(2.50\,\mathrm{W/(m\cdot K)}\) 时，末时刻出口温度由 \(25.72\,^\circ\mathrm{C}\) 降至 \(23.60\,^\circ\mathrm{C}\)，末日平均换热量由 \(598.0\,\mathrm{W}\) 增至 \(747.9\,\mathrm{W}\)。因此，高保真模型中必须保留竖向分层土壤，而不能将土壤简单均质化。

![土壤热饱和退化](G:/codexproject/paper_figures/Fig03_heat_saturation_degradation.png)

温度云图用于检查土壤初始温度预计算和管周热扰动方向。对于夏季冷却工况，管道附近土壤应表现为局部升温，且上部浅层土壤受地表边界影响更强。若云图出现“浅层温度系统性偏低、深层反而偏高且与预计算相反”的现象，应优先检查竖向坐标方向、深度变量符号、土层编号和 \(T_{undist}(z,t)\) 插值方式。

![管周土壤温度云图](G:/codexproject/paper_figures/Fig04_temperature_field_contours.png)

## 10 CFD-热湿耦合模型验证路线

高保真模型的验证应分三层进行。第一层为数值验证，包括时间步长、轴向网格、径向网格、周向网格和三维网格无关性。RC 模型已有结果显示，当时间步长从 60 s 增至 600 s 时，出口温度均方根误差约为 \(0.014\,\mathrm{K}\)；当管长方向网格由 20 增至 80 时，误差由 \(0.117\,\mathrm{K}\) 降至基准值。该结果说明低阶隐式离散具有良好稳定性，但 CFD 模型仍需重新进行网格无关性检查。

第二层为理论退化验证。令土壤含水率固定、湿分通量为零、潜热项关闭，并令 \(R_{int}^{\prime\prime}=0,\eta_{int}=1\)，则高保真模型应退化为经典均质土壤导热-管内对流换热模型。此时出口温度可与指数型解析模型比较：

\[
T_{out}=T_s+(T_{in}-T_s)
\exp\left[
-\frac{U P L}{\dot m c_{pa}}
\right],
\qquad (53)
\]

其中 \(U\) 为基于管内对流、管壁导热和土壤导热热阻得到的总传热系数，\(P\) 为管道内周长。若 CFD 结果与式 (53) 的偏差随网格加密收敛，则说明空气侧换热和土壤导热耦合设置基本正确。

第三层为实验验证。优先采用刘庆功热湿迁移实验中的进出口空气温湿度、土壤温湿度测点和连续/间歇运行数据，检验模型对显热、潜热和土壤湿分迁移的预测能力。Ozgener 等闭式 EAHE 温室冷却实验可作为总热阻层面的辅助验证，但其系统形式、管路布置和总热阻定义与本文水平单管模型不完全一致，因此只能用于趋势对比和热阻量级检查，不能直接作为唯一标定依据。

## 11 参数反演与界面热阻识别

利用实验数据反演界面热阻参数：

\[
\min
\left[
\sum_i
\left(T_{out,cal}(t_i)-T_{out,exp}(t_i)\right)^2
+w_1
\sum_i
\left(\varphi_{out,cal}(t_i)-\varphi_{out,exp}(t_i)\right)^2
+w_2
\sum_i
\left(T_{s,cal}(t_i)-T_{s,exp}(t_i)\right)^2
\right].
\qquad (54)
\]

待识别参数为

\[
R_{int,0}^{\prime\prime},\quad \eta_{int},\quad a_\theta,\quad a_\varphi,\quad a_\sigma .
\qquad (55)
\]

为提高参数识别的可辨识性，建议采用分步反演策略。首先在干热或弱湿迁移工况下识别 \(R_{int,0}^{\prime\prime}\) 与 \(\eta_{int}\)，随后在不同初始含水率或不同运行模式下识别 \(a_\theta\) 和 \(a_\varphi\)，最后在具有压实度或覆土压力信息的试验中识别 \(a_\sigma\)。若缺少法向有效应力数据，则暂令 \(a_\sigma=0\)，将模型简化为含水率-相对湿度控制的可变界面热阻模型。

反演目标函数可进一步加入热流和土壤湿度测点：

\[
J=
w_TJ_T+w_\varphi J_\varphi+w_sJ_s+w_qJ_q ,
\qquad (56)
\]

其中 \(J_T\) 表示出口温度误差，\(J_\varphi\) 表示出口相对湿度误差，\(J_s\) 表示土壤测点温湿度误差，\(J_q\) 表示管壁热流误差。多目标函数能够避免只拟合出口温度而导致界面热阻、土壤导热系数和空气侧换热系数之间出现参数补偿。

### 11.1 空气侧等效对流校正

为进一步避免将管壁温度人为固定，本文在干热二维模型中加入管内空气等效对流热阻。以管外表面积为基准，总热阻写为

\[
R_{tot,o}^{\prime\prime}
=
\frac{r_o}{r_i h_i}
+
\frac{r_o\ln(r_o/r_i)}{\lambda_p}
+
R_{int}^{\prime\prime}.
\qquad (57)
\]

其中 \(h_i\) 由 Dittus-Boelter 关联式计算：

\[
Nu=0.023Re^{0.8}Pr^{0.4},\qquad
h_i=\frac{Nu\lambda_a}{D_i}.
\qquad (58)
\]

相应管周热通量边界为

\[
q_{pipe}
=
\frac{T_{a,eq}-T_s}{R_{tot,o}^{\prime\prime}} .
\qquad (59)
\]

当 \(\dot m=0.08\,\mathrm{kg/s}\)、\(r_i=0.055\,\mathrm{m}\) 时，计算得到 \(Re\approx5.0\times10^4\)，\(h_i\approx27.3\,\mathrm{W/(m^2K)}\)，总面积热阻约为 \(0.093\,\mathrm{m^2K/W}\)。与固定管壁温度模型相比，管周 0.35 m 范围内最终平均温度由约 \(24.5\,^\circ\mathrm{C}\) 降至 \(22.3\,^\circ\mathrm{C}\)，说明空气侧对流热阻和管壁热阻会进一步削弱管道对土壤的热扰动。该结果仍保持地表高温、深部低温、管周局部升温的合理温度场结构。

![COMSOL 干热二维等效空气对流模型温度云图](G:/codexproject/paper_figures/Fig11_comsol_dry_air_convection_temperature.png)

### 11.2 准三维轴向空气能量校正

二维截面干热模型能够检查竖向分层土壤、地表边界和管土界面热阻的方向是否正确，但仍将空气温度视为等效给定值，不能直接给出 \(T_{out}(t)\)。因此，本文进一步建立分段准三维轴向空气能量模型，将管长方向离散为 \(N_x\) 个控制体，每段空气与近管土壤通过总热阻耦合。基于管外表面积的总热阻转换为单位长度热阻：

\[
R_{tot}^{\prime}
=
\frac{R_{tot,o}^{\prime\prime}}{2\pi r_o}.
\qquad (60)
\]

第 \(j\) 段空气温度满足一维轴向能量方程：

\[
\frac{\mathrm{d}T_a}{\mathrm{d}x}
=
-
\frac{T_a-T_{s,j}}
{\dot m c_{pa}R_{tot}^{\prime}},
\qquad (61)
\]

在单个长度步长 \(\Delta x\) 内若认为 \(T_{s,j}\) 近似不变，则出口温度可写成精确指数格式：

\[
T_{a,j+1}
=
T_{s,j}
+
\left(T_{a,j}-T_{s,j}\right)
\exp
\left[
-
\frac{\Delta x}{\dot m c_{pa}R_{tot}^{\prime}}
\right].
\qquad (62)
\]

相应地，该段空气向土壤释放的热量为

\[
q_j
=
\dot m c_{pa}
\left(T_{a,j}-T_{a,j+1}\right).
\qquad (63)
\]

近管土壤采用分段集中热容描述，并通过远场热阻 \(R_{far,j}\) 与未扰动土壤温度 \(T_{far}\) 相连：

\[
C_{s,j}
\frac{\mathrm{d}T_{s,j}}{\mathrm{d}t}
=
q_j
-
\frac{T_{s,j}-T_{far}}{R_{far,j}} .
\qquad (64)
\]

式 (64) 使用隐式欧拉格式推进，以保持连续运行长时间计算的稳定性。该准三维模型不是最终 CFD-热湿耦合模型的替代品，而是连接二维温度场检查与三维出口温度预测的中间退化模型。它能够同时保留轴向空气温降、沿程土壤热积累和运行日退化趋势。

基准工况取 \(L=40\,\mathrm{m}\)、\(N_x=80\)、\(\Delta t=300\,\mathrm{s}\)、\(\dot m=0.08\,\mathrm{kg/s}\)。由 Dittus-Boelter 关联式得到 \(Re\approx5.01\times 10^4\)、\(h_i\approx27.34\,\mathrm{W/(m^2K)}\)，并有 \(R_{tot,o}^{\prime\prime}\approx0.09296\,\mathrm{m^2K/W}\)、\(R_{tot}^{\prime}\approx0.2466\,\mathrm{Km/W}\)。连续运行 7 d 后，出口空气末时刻温度约为 \(19.91\,^\circ\mathrm{C}\)，第一天平均换热量为 \(1083.1\,\mathrm{W}\)，第七天平均换热量降至 \(971.0\,\mathrm{W}\)，退化系数为 0.897，分段近管土壤平均温度升至 \(18.58\,^\circ\mathrm{C}\)。该结果表明，加入轴向空气能量方程后，模型能够捕捉出口空气温度、管长方向土壤热累积和日均换热退化三类关键现象。

![准三维轴向空气能量模型瞬态响应](G:/codexproject/paper_figures/Fig12_quasi3d_air_energy_transient.png)

沿程土壤温度分布显示，运行时间越长，入口段附近土壤升温越明显；随着轴向距离增加，空气与土壤之间的温差逐渐减小，远端土壤升温幅度随之降低。这一趋势符合水平 EAHE 在夏季冷却工况下“入口段负荷较大、出口段负荷较小”的传热特征。

![准三维模型沿程土壤温度分布](G:/codexproject/paper_figures/Fig13_quasi3d_soil_axial_profiles.png)

日均换热量随运行天数下降，说明近管土壤热饱和会持续削弱 EAHE 的冷却能力。该退化曲线与前述 RC 模型的热饱和结论一致，但准三维模型进一步给出了空气沿程降温机制，因此可作为后续三维 CFD-热湿耦合模型的出口温度退化验证基准。

![准三维模型日均换热退化](G:/codexproject/paper_figures/Fig14_quasi3d_degradation.png)

### 11.3 三维干热模型先导验证

在完成二维干热模型与准三维空气能量模型后，进一步建立三维干热先导模型，用于检查三维几何、管道轴向、竖向三层土壤和 COMSOL 瞬态求解链路是否可用。该模型建立 \(40\,\mathrm{m}\times8\,\mathrm{m}\times8\,\mathrm{m}\) 土壤域，并从土壤域中扣除水平圆柱管道孔。管道中心深度为 \(2\,\mathrm{m}\)，位于第二层土壤中。空气侧仍采用等效对流热阻处理，但将等效空气温度沿管长方向写为指数衰减形式：

\[
T_{a,eq}(x)
=
T_{deep}
+
\left(T_{in,eq}-T_{deep}\right)
\exp
\left[
-
\frac{x}{\dot m c_{pa} R_{tot}^{\prime}}
\right].
\qquad (65)
\]

管土界面热流仍采用式 (59) 的面积热阻形式，只是将 \(T_{a,eq}\) 替换为式 (65) 的 \(T_{a,eq}(x)\)。这种处理能够在三维土壤中形成入口段强、出口段弱的轴向热扰动，但它尚未实现空气能量方程与土壤温度场的完全双向耦合。

![COMSOL 三维干热先导模型温度场](G:/codexproject/paper_figures/Fig15_comsol_dry_thermal_3D_temperature.png)

三维先导算例在粗网格下完成 7 d 瞬态计算。结果显示，浅层土壤最终平均温度约为 \(25.45\,^\circ\mathrm{C}\)，深层土壤最终平均温度保持在 \(16.00\,^\circ\mathrm{C}\)，近管 \(0.35\,\mathrm{m}\) 范围内最终平均温度约为 \(18.92\,^\circ\mathrm{C}\)。入口侧近管平均温度约为 \(19.31\,^\circ\mathrm{C}\)，出口侧近管平均温度约为 \(16.58\,^\circ\mathrm{C}\)，说明三维模型能够反映沿程热扰动递减趋势。

![三维干热先导模型中剖面与近管沿程温度](G:/codexproject/paper_figures/Fig16_comsol_dry_thermal_3D_midplane_and_axial.png)

需要强调的是，该三维算例目前只是 pilot 验证。由于网格较粗，中剖面温度图只能作为逻辑检查图，不能作为最终论文的高精度温度云图。此外，式 (65) 中 \(T_{a,eq}(x)\) 为预设分布，当局部土壤温度高于该预设空气温度时，界面热流可能出现局部反向。这说明下一步应在三维模型中引入与土壤温度场耦合的一维空气能量方程，然后再开启水汽分压、相对湿度和潜热项。

在此基础上进一步进行了管周网格加密。加密后三维模型最终时刻导出节点数由 760 增至 47,652，入口侧近管平均温度由粗网格的 \(19.31\,^\circ\mathrm{C}\) 提高到 \(21.17\,^\circ\mathrm{C}\)，说明粗网格会低估入口段局部热扰动。加密模型仍保持浅层温度高、深层温度低和沿程热扰动衰减的总体规律，适合作为空气能量闭合检查的基础。

![三维干热加密模型中剖面与近管沿程温度](G:/codexproject/paper_figures/Fig18_comsol_dry_thermal_3D_refined_midplane_and_axial.png)

为量化预设 \(T_{a,eq}(x)\) 带来的闭合误差，提取加密模型管壁附近节点的平均界面热流，并按一维空气能量方程沿程积分：

\[
T_{a,j+1}
=
T_{a,j}
-
\frac{\bar q_{int,j}\,2\pi r_o\,\Delta x}
{\dot m c_{pa}} .
\qquad (66)
\]

闭合检查表明，基于三维壁面热流积分得到的出口空气温度约为 \(25.78\,^\circ\mathrm{C}\)，而预设指数分布末端温度约为 \(18.18\,^\circ\mathrm{C}\)，两者相差约 \(7.59\,\mathrm{K}\)。因此，式 (65) 只适合作为先导模型的边界近似，不能作为正式三维模型的空气侧闭合条件。正式模型应将式 (66) 与三维土壤传热边界迭代或弱耦合求解。

![三维加密模型空气能量闭合检查](G:/codexproject/paper_figures/Fig19_refined_3D_air_energy_closure.png)

为进一步降低空气侧闭合误差，本文采用 Picard-割线迭代修正等效空气温度衰减尺度。记第 \(n\) 次计算的空气侧闭合误差为

\[
e_n
=
T_{out,closure}^{(n)}
-
T_{out,imposed}^{(n)} .
\qquad (67)
\]

若直接 Picard 更新导致振荡，则用两次计算结果构造割线修正：

\[
R_{a}^{\prime(n+1)}
=
R_{a}^{\prime(n-1)}
-
e_{n-1}
\frac{
R_a^{\prime(n)}-R_a^{\prime(n-1)}
}{
e_n-e_{n-1}
}.
\qquad (68)
\]

计算结果显示，原始预设边界的闭合误差为 \(+7.59\,\mathrm{K}\)，Picard1 过度修正为 \(-5.57\,\mathrm{K}\)，Picard2 降至 \(-2.36\,\mathrm{K}\)，Picard3 进一步降至 \(-0.82\,\mathrm{K}\)。Picard3 的预设出口温度约为 \(22.88\,^\circ\mathrm{C}\)，由三维壁面热流积分得到的闭合出口温度约为 \(22.06\,^\circ\mathrm{C}\)。因此，Picard3 可作为当前干热三维模型进入热湿耦合前的空气能量校正基准。

![Picard 空气能量闭合检查](G:/codexproject/paper_figures/Fig25_picard3_3D_air_energy_closure.png)

![空气能量 Picard 迭代收敛过程](G:/codexproject/paper_figures/Fig26_picard_air_energy_convergence.png)

### 11.4 被动水汽分压-相对湿度模型

在 Picard3 干热三维模型基础上，进一步加入被动水汽分压扩散方程。该步骤暂不启用潜热项，也不令含水率或相对湿度反过来修正土壤导热系数和界面热阻，目的仅是验证 \(p_v\)、\(p_{vs}(T)\) 和 \(\varphi\) 的变量定义、边界条件及数值稳定性。水汽分压控制方程写为

\[
\frac{\partial p_v}{\partial t}
=
\nabla\cdot
\left(
D_{v,eff}\nabla p_v
\right),
\qquad (69)
\]

其中 \(D_{v,eff}\) 为土壤等效水汽分压扩散系数。相对湿度由

\[
\varphi_{raw}
=
\frac{p_v}{p_{vs}(T_s)}
\qquad (70)
\]

计算。饱和水汽压采用温度函数表示：

\[
p_{vs}(T)
=
610.78
\exp
\left[
\frac{17.2694(T-273.15)}
{T-35.86}
\right] .
\qquad (71)
\]

被动湿分算例取初始土壤相对湿度 \(\varphi_0=0.75\)，地表相对湿度 \(\varphi_{surf}=0.60\)，管壁等效空气相对湿度 \(\varphi_{pipe}=0.60\)，并令 \(D_{v,eff}=1.5\times10^{-6}\,\mathrm{m^2/s}\)。计算结果显示，最终水汽分压范围约为 \(1367\sim2853\,\mathrm{Pa}\)，原始相对湿度平均值为 0.857，近管区域平均值为 0.828，地表浅层平均值为 0.671。约 6.73% 的节点出现 \(\varphi_{raw}>1\) 的超饱和状态，深层平均 \(\varphi_{raw}\) 达到 1.141。

![被动水汽分压模型相对湿度诊断](G:/codexproject/paper_figures/Fig29_passive_vapor_RH_diagnostics.png)

上述结果说明，被动扩散模型能够稳定求解水汽分压场，并能给出沿管长方向的相对湿度梯度；但由于未考虑凝结、液态水回补和潜热释放，当较高水汽分压扩散到低温深层或低温管周区域时，会出现非物理超饱和。因此，下一步不能直接将 \(\varphi\) 简单截断后进入可变界面热阻，而应加入饱和约束或凝结源项，使 \(p_v\le p_{vs}(T_s)\) 与潜热释放保持一致。

### 11.5 饱和约束与冷凝源项验证

为抑制被动水汽模型中的非物理超饱和，本文进一步引入平滑冷凝源项。该步骤仍不把冷凝潜热反馈到土壤能量方程，其目的在于先验证水汽分压场、相对湿度场和饱和约束之间的数值逻辑。管壁等效水汽分压边界采用温度相关上限：

\[
p_{v,pipe}
=
\min
\left[
\varphi_{pipe}p_{vs}(T_a),
p_{vs}(T_s)
\right] .
\qquad (72)
\]

对局部超饱和量采用平滑正部函数表示：

\[
\left\langle p_v-p_{vs}\right\rangle_+
=
\frac{1}{2}
\left[
p_v-p_{vs}
+
\sqrt{(p_v-p_{vs})^2+p_s^2}
\right],
\qquad (73)
\]

其中 \(p_s\) 为平滑压力尺度。冷凝汇项写为

\[
S_c
=
k_c
\left\langle p_v-p_{vs}\right\rangle_+ ,
\qquad (74)
\]

并将水汽分压控制方程改写为

\[
\frac{\partial p_v}{\partial t}
=
\nabla\cdot
\left(
D_{v,eff}\nabla p_v
\right)
-S_c .
\qquad (75)
\]

计算中取 \(k_c=2.0\times10^{-4}\,\mathrm{s^{-1}}\)，\(p_s=5\,\mathrm{Pa}\)。与被动水汽模型相比，冷凝约束后最终超饱和节点比例由 6.73% 降至 1.35%，\(\varphi_{raw}>1.01\) 的节点比例降至 1.03%；深层平均原始相对湿度由 1.141 降至 0.963，最大原始相对湿度由约 1.569 降至 1.247。冷凝汇项平均值为 \(7.43\times10^{-4}\,\mathrm{Pa/s}\)，最大值为 \(8.99\times10^{-2}\,\mathrm{Pa/s}\)。

![冷凝约束模型相对湿度诊断](G:/codexproject/paper_figures/Fig32_condensation_RH_diagnostics.png)

图中可见，近管区域相对湿度整体低于饱和线，沿管长方向从入口端较高湿度逐渐下降，并在出口附近受边界和轴向扩散影响略有回升。该结果说明，饱和约束已经显著减少深层和近管低温区的非物理超饱和；但仍存在少量 \(\varphi_{raw}>1\) 的节点，表明在启用潜热反馈之前，还应进一步检查冷凝速率 \(k_c\)、平滑尺度 \(p_s\)、出口端边界处理和液态水回补项。下一步完整热湿耦合模型应将潜热项 \(-L_v S_c\) 写入土壤能量方程，并令含水率变化反馈到 \(\lambda_s(\theta)\)、\(C_s(\theta)\) 和界面热阻 \(R_{int}^{\prime\prime}(\theta,\eta_c)\)。

为判断残余超饱和是否主要由冷凝松弛速率不足造成，进一步将 \(k_c\) 由 \(2.0\times10^{-4}\,\mathrm{s^{-1}}\) 提高到 \(1.0\times10^{-3}\,\mathrm{s^{-1}}\)，其余条件保持不变。结果显示，超饱和节点比例由 1.35% 继续降至 1.01%，深层平均 \(\varphi_{raw}\) 由 0.963 降至 0.950，区域平均 \(\varphi_{raw}\) 由 0.843 降至 0.840。与此同时，最大冷凝汇项由 \(8.99\times10^{-2}\,\mathrm{Pa/s}\) 增至 \(4.50\times10^{-1}\,\mathrm{Pa/s}\)。这表明提高 \(k_c\) 能进一步抑制超饱和，但改善幅度已明显小于从被动水汽模型切换到冷凝约束模型的改善幅度。因此，后续不宜单纯继续增大 \(k_c\)，而应同时检查平滑正部函数、边界湿度设定、液态水回补与潜热反馈的能量一致性。

![冷凝速率敏感性](G:/codexproject/paper_figures/Fig33_condensation_rate_sensitivity.png)

## 12 COMSOL 实施细化

正式模型不建议继续修改旧模板，而应新建干净的 EAHE 三维模型。实施顺序如下：

1. 建立几何：管内空气域、管壁、可选管土间隙薄层、三层土壤域；
2. 指定坐标：管轴向为 \(x\)，竖向深度为 \(z\)，土壤层界面采用固定 \(z\) 坐标划分；
3. 添加空气侧 \(k-\varepsilon\) 湍流流动，先求稳态流场；
4. 添加空气温度和水汽输运，入口给定 \(T_{in}(t)\) 与 \(\varphi_{in}(t)\)；
5. 添加管壁导热；
6. 用 General Form PDE 添加土壤 \(\theta\) 和 \(p_v\) 方程；
7. 用热传导或 General Form PDE 添加土壤能量方程，并启用液态水显热、水汽显热和潜热项；
8. 在管壁外表面与土壤内边界之间添加 Tang 型弱约束或薄层热阻；
9. 施加地表热湿边界、底部恒温/绝湿边界和远场未扰动土温边界；
10. 采用“稳态流场 + 瞬态热湿耦合”的分步求解流程。

本机已完成 COMSOL 批处理和 Java API 求解链路验证。模板 `Untitled12.mph` 经修复后可完成瞬态湍流与传热求解，并保存为 `G:\codexproject\comsol_outputs\Untitled12_repaired_solved.mph`。该结果仅证明计算链路可用；论文正式结果仍应来自上述新建的 EAHE 热湿耦合模型。

## 13 论文结果组织

建议论文结果分为六部分：

1. COMSOL 模型与网格独立性；
2. 完美接触与 Tang 型界面热接触模型对比；
3. 不同 \(R_{int}^{\prime\prime}\) 和 \(\eta_{int}\) 对出口温湿度的影响；
4. 轴向土壤水分迁移与径向湿度峰值；
5. 连续运行与间歇运行下的土壤热湿恢复；
6. 实验验证与界面热阻参数反演。

图表筛选建议如下：基准瞬态响应、土壤热饱和退化、温度/湿度云图、界面热阻敏感性、运行参数敏感性、理论退化对比、实验验证对比和界面热阻反演结果。RC 阶段已有图可作为先导结果保留，但最终论文应以 CFD-热湿耦合模型的温度场、含水率场、水汽分压场和相对湿度场为主体。

## 14 关键参数与 COMSOL 实施矩阵

为保证模型可重复实现，正式计算前应建立统一参数表。建议将参数分为空气侧、管壁、管土界面、土壤热物性、土壤水力特性和边界气象条件六类。

| 类别 | 参数 | 含义 | 主要用途 |
|---|---|---|---|
| 空气侧 | \(\dot m,u_{in},T_{in},\varphi_{in}\) | 质量流量、入口速度、入口温度和入口相对湿度 | 入口边界、显热与潜热计算 |
| 湍流模型 | \(k,\varepsilon,C_\mu,\sigma_k,\sigma_\varepsilon\) | 湍动能、耗散率和模型常数 | 管内湍流换热 |
| 管壁 | \(r_i,r_o,\lambda_p,\rho_p,c_p\) | 内外半径与管材热物性 | 管壁导热热阻 |
| 界面 | \(\delta_{gap},\lambda_{gap,eff},R_{int}^{\prime\prime},\eta_{int}\) | 间隙厚度、等效导热系数、单位面积热阻和分配接触系数 | Tang 型热接触边界 |
| 土壤热物性 | \(\lambda_{dry},a_\theta,\rho_s,c_s,\varepsilon\) | 干土导热系数、含水率修正系数、骨架热容和孔隙率 | 土壤能量方程 |
| 土壤水力特性 | \(\theta_s,\theta_r,K_s,\alpha,n\) | 饱和含水率、残余含水率、饱和导水率和 Van Genuchten 参数 | 液态水迁移 |
| 边界条件 | \(T_{air},q_{solar},q_{rad},E_s,T_{deep}\) | 地表空气温度、太阳辐射、长波辐射、蒸发通量和深层温度 | 地表和底部边界 |

在 COMSOL 中，各方程与物理场接口的对应关系建议如下。

| 模型部分 | 推荐接口 | 主要因变量 | 备注 |
|---|---|---|---|
| 管内流动 | Turbulent Flow, \(k-\varepsilon\) | \(\mathbf{u},p,k,\varepsilon\) | 先求稳态流场，再耦合瞬态热湿输运 |
| 空气温度 | Heat Transfer in Fluids | \(T_a\) | 湍流热扩散由湍流普朗特数修正 |
| 空气水汽 | Transport of Diluted Species 或 General Form PDE | \(Y_v\) 或 \(p_{v,a}\) | 推荐输出转换为 \(\varphi_a\) |
| 管壁导热 | Heat Transfer in Solids | \(T_p\) | 与空气侧采用内壁对流或共轭传热 |
| 土壤温度 | Heat Transfer in Solids 或 General Form PDE | \(T_s\) | 若启用潜热项，General Form PDE 更灵活 |
| 土壤含水率 | General Form PDE | \(\theta\) | 需要限制 \(\theta_r\le \theta\le\theta_s\) |
| 土壤水汽分压 | General Form PDE | \(p_v\) | 与 \(\varphi=p_v/p_{vs}(T_s)\) 联立 |
| 管土界面 | Thin Layer、Thermal Contact 或 Weak Contribution | \(q_{int}\) | 用式 (26) 实现 Tang 型一般热接触 |

求解时建议采用分步递进策略：首先运行干土、固定热阻、无湿分迁移算例；随后开启含水率影响的导热系数；再开启水汽分压方程和潜热项；最后开启可变界面热阻。每增加一个耦合项，都应与上一步结果比较，确认出口温度、出口相对湿度、土壤温度场和含水率场没有出现非物理突跳。

## 15 符号说明

| 符号 | 含义 | 单位 |
|---|---|---|
| \(T_a,T_p,T_s\) | 空气、管壁和土壤温度 | K 或 \(^\circ\mathrm{C}\) |
| \(\varphi_a,\varphi\) | 空气侧和土壤孔隙气相相对湿度 | - |
| \(p_v,p_{vs}\) | 水汽分压和饱和水汽压 | Pa |
| \(Y_v\) | 空气中水汽质量分数 | kg/kg |
| \(\theta,\theta_s,\theta_r\) | 体积含水率、饱和含水率和残余含水率 | \(\mathrm{m^3/m^3}\) |
| \(S_e\) | 有效饱和度 | - |
| \(K(\theta)\) | 非饱和导水率 | m/s |
| \(\mathbf{j}_l,\mathbf{j}_v\) | 液态水和水汽质量通量 | \(\mathrm{kg/(m^2 s)}\) |
| \(\lambda_{eff}\) | 土壤等效导热系数 | \(\mathrm{W/(m K)}\) |
| \(R_{int}^{\prime\prime}\) | 单位面积管土界面热阻 | \(\mathrm{m^2 K/W}\) |
| \(\eta_{int}\) | Tang 型界面分配接触系数 | - |
| \(q_{int}\) | 管土界面热流密度 | \(\mathrm{W/m^2}\) |
| \(Q_s,Q_l\) | 显热和潜热换热量 | W |

## 16 参考文献

[1] 刘庆功. 土壤-空气换热器热湿迁移特性的研究. 学位论文, 太原理工大学.

[2] 刘庆功, 杜震宇. 不同运行模式下土壤空气换热器热性能研究. 工程热物理学报.

[3] Ozgener, O., Ozgener, L., Goswami, D. Y. Experimental prediction of total thermal resistance of a closed loop EAHE for greenhouse cooling system. *International Communications in Heat and Mass Transfer*, 2011, 38: 711-716. DOI: 10.1016/j.icheatmasstransfer.2011.03.009.

[4] Tang, K. J., Wen, M. J., Tu, Y., Wu, W. B., Xie, J. H., Liu, K. F., Wu, D. Z. Interfacial thermal contact model for consolidation of multilayered saturated soils subjected to time-dependent temperature and loading. *Journal of Central South University*, 2025, 32(6): 2239-2255. DOI: 10.1007/s11771-025-5976-5.

[5] Renewable Energy 文献. 用于未扰动土壤初始温度计算的解析或半解析模型. DOI: 10.1016/j.renene.2020.11.114.

## 17 现阶段结论

当前工作已完成从 RC 网络模型向 CFD-热湿耦合模型的理论升级方案，并验证了 COMSOL 批处理调用能力。下一步应建立干净的 EAHE 三维几何和物理场，而不是继续修改旧模板。新模型的关键创新点在于：以水汽分压-相对湿度关系描述非饱和土壤湿迁移，以 \(k-\varepsilon\) 模型描述管内空气湍流，以 Tang 型一般热接触模型描述管土界面热阻，并通过实验数据反演界面热阻参数。

