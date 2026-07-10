# Sharan 50 m EAHE 修正 CFD 湍流模型步骤与错误诊断

## 1. 再次诊断当前 CFD 的主要错误

当前 `COMSOL_Sharan_50m_CFD_*` 结果存在一个核心矛盾：

- Sharan 工况的管内流动明确是湍流。
- 由参数计算得到 `Re ≈ 6.7e4`。
- Gnielinski 关联式给出 `h_i ≈ 34.5 W/(m2 K)`。
- 但当前 CFD 后处理得到的全局等效换热系数只有 `h_eq ≈ 2 W/(m2 K)`。

这会导致 CFD 总换热量严重偏低：

| Case | Experiment abs energy | Minaei-G RC abs energy | Current CFD abs energy |
|---|---:|---:|---:|
| May cooling | 7.31 kWh | 7.10 kWh | 2.14 kWh |
| January heating | 14.40 kWh | 14.02 kWh | 4.16 kWh |

因此，当前大差异不是 Sharan 参数本身造成的，而是 CFD 的有效热耦合或后处理没有闭合。

## 2. 当前 CFD 中最可能的问题

### 2.1 出口温度平均方式不严格

当前脚本里：

```matlab
var.set('Tout_C_eval', 'ave_out(T)-273.15[K]');
```

这是出口面积平均温度。对于湍流管流，应优先使用质量流量加权温度：

```text
Tout_bulk = integral(rho*cp*u_z*T dA) / integral(rho*cp*u_z dA)
```

否则在速度剖面和温度边界层不均匀时，会偏离真实空气焓流温度。

### 2.2 Nonisothermal Flow 耦合可能没有正确生效

当前脚本用 `try/catch` 创建：

```matlab
comp.multiphysics.create('nitf1', 'NonIsothermalFlow', 'geom1')
```

如果 COMSOL API 属性名不匹配，脚本只 warning，不会强制失败。这样可能出现：

- 流场求解了；
- 热传递也求解了；
- 但湍流热扩散、热壁函数或流热耦合没有按预期作用。

新的 CFD 模型中，这一步必须作为硬性验证项：耦合创建失败时直接停止，不继续导出结果。

### 2.3 全局热流、壁面热通量积分和空气焓差没有闭合

必须同时导出三种热量：

```text
Q_air = mdot*cp*(Tin_bulk - Tout_bulk)
Q_wall = integral(inner wall heat flux dA)
Q_store = d/dt integral(rho*cp*T dV) over air+pipe+soil
```

短时瞬态下，至少应满足：

```text
Q_air ≈ Q_wall + dU_air/dt
```

若 `Q_air` 与内壁热流积分差一个数量级，则 CFD 或后处理错误。

### 2.4 局部 h 的提取方式不可靠

当前局部 `h_local` 是用管壁内外两个点差分估计壁面热流：

```matlab
qWall = k_p*(Twall - Touter)/(rpi*log(rpo/rpi))
```

这对采样点位置非常敏感。更稳妥的方式是直接用 COMSOL 热通量变量或内壁法向热通量积分，而不是用两个点温差反推。

## 3. Sharan 参数

新 CFD 湍流模型固定使用以下参数。

### 几何

| Parameter | Value |
|---|---:|
| Pipe length `L` | 50 m |
| Inner radius `rpi` | 0.050 m |
| Outer radius `rpo` | 0.053 m |
| Pipe wall thickness | 0.003 m |
| Soil outer radius `Rs` | 建议先用 2.0 m，并做 2/3/5 m 敏感性 |

### 空气

| Parameter | Value |
|---|---:|
| Volume flow rate `Vdot` | 0.0863 m3/s |
| Mass flow rate `mdot` | 0.0975 kg/s |
| Density `rho_f` | 1.1298 kg/m3 |
| Specific heat `cp_f` | 1006 J/(kg K) |
| Conductivity `k_air` | 0.026 W/(m K) |
| Dynamic viscosity `mu_f` | 1.85e-5 Pa s |
| Mean velocity | 10.99 m/s |
| Reynolds number | 6.7e4 |

### Pipe and soil

| Domain | rho | cp | k |
|---|---:|---:|---:|
| Mild steel pipe | 7850 kg/m3 | 470 J/(kg K) | 45 W/(m K) |
| Soil | 1800 kg/m3 | 1200 J/(kg K) | 1.5 W/(m K) |

### Experimental temperature profiles

May cooling:

```text
t = 0:7 h
Tin  = [31.3, 33.7, 36.4, 37.8, 40.8, 40.4, 39.8, 39.6] C
Tsoil = [26.6, 26.6, 26.6, 26.6, 26.6, 26.6, 26.6, 26.5] C
T25_exp = [29.1, 29.2, 29.5, 29.5, 29.7, 29.7, 29.8, 30.0] C
Tout_exp = [26.8, 26.8, 27.2, 27.2, 27.2, 27.2, 27.2, 27.2] C
```

January heating:

```text
t = 0:12 h
Tin = [19.8, 17.6, 13.3, 11.9, 10.4, 9.6, 9.1, 8.7, 8.3, 8.7, 9.1, 9.6, 9.8] C
Tsoil = 24.2 C
T25_exp = [22.3, 22.2, 22.1, 21.9, 21.8, 21.7, 21.6, 21.5, 21.5, 21.4, 21.3, 21.2, 21.2] C
Tout_exp = [23.4, 23.4, 23.3, 23.3, 23.3, 23.3, 23.2, 23.2, 23.0, 23.0, 22.9, 22.9, 22.8] C
```

## 4. 新 CFD 湍流模型建模步骤

### Step 0：先做管内空气侧基准验证

在进入土壤耦合前，必须先做一个单独圆管湍流换热验证：

1. 只建空气管道，长度 50 m，半径 0.05 m。
2. 入口给定 Sharan 流量和温度。
3. 管壁给定恒温，例如 May 用 `Tw = 26.6 C`，January 用 `Tw = 24.2 C`。
4. 使用 SST 湍流模型。
5. 导出：
   - 质量流量加权 `Tout_bulk`
   - 内壁热通量积分 `Q_wall`
   - `Q_air = mdot cp (Tin-Tout_bulk)`
   - `Nu = Q_wall/(A*(Tbulk_mean-Twall))*D/k_air`
6. 要求：
   - `h_CFD` 应与 Gnielinski 的 `34.5 W/(m2 K)` 同量级。
   - `Q_air` 与 `Q_wall` 相对误差应小于 5-10%。

如果这一步不通过，不应继续做土壤耦合 CFD。

### Step 1：建立 2D 轴对称共轭传热几何

几何域：

1. 空气域：`0 <= r <= rpi`, `0 <= z <= L`
2. 管壁域：`rpi <= r <= rpo`, `0 <= z <= L`
3. 土壤域：`rpo <= r <= Rs`, `0 <= z <= L`

Sharan 无空气隙，因此不建立 gap 域。

### Step 2：物理场

使用：

```text
Turbulent Flow, SST
Heat Transfer in Solids and Fluids
Nonisothermal Flow multiphysics coupling
```

流体域只选空气域；固体域为管壁和土壤。

### Step 3：流动边界

入口：

```text
Velocity inlet
u_mean = Vdot/(pi*rpi^2) = 10.99 m/s
Turbulence intensity = 5%
Turbulent length scale = 0.07*D
```

出口：

```text
p = 0 Pa
```

壁面：

```text
No slip
SST wall treatment / automatic wall function
```

### Step 4：热边界

入口：

```text
T = Tin(t)
```

出口：

```text
Convective outflow
```

土壤外边界：

```text
T = Tsoil(t)
```

土壤轴向两端：

```text
Thermal insulation
```

空气-管壁、管壁-土壤界面：

```text
Temperature continuity
Heat flux continuity
```

### Step 5：初始条件

直接短时验证：

```text
T_air = Tsoil(0)
T_pipe = Tsoil(0)
T_soil = Tsoil(0)
```

更推荐的实验对比：

1. 先做预运行或给定校准径向土壤初始剖面。
2. 再运行实验测量窗口。

因为 Sharan 实验可能不是从完全未扰动土壤开始。

### Step 6：网格

空气域：

- 径向至少 40 个单元。
- 近壁边界层 12-20 层。
- 第一层厚度需要根据 SST 壁处理控制 `y+`。

建议做两套：

```text
low-Re resolved wall: y+ ≈ 1
wall-function mode: 30 < y+ < 100
```

不能处在尴尬的过渡区而又不检查 wall treatment。

管壁：

- 径向 6-10 层。

土壤：

- 管外近壁 `0.005-0.01 m` 加密。
- 远场逐渐放粗。
- `Rs = 2, 3, 5 m` 做边界敏感性。

轴向：

- 最大单元 0.25-0.5 m。
- 入口前 5 m 加密，因为温度梯度最大。

### Step 7：求解

推荐分两步：

1. Stationary flow only：只求稳态 SST 流场。
2. Transient heat transfer + frozen or coupled flow：
   - 若流体物性常数，可固定稳态流场，只做非稳态传热。
   - 时间步建议 `60-300 s`，不要一开始用 `600 s`。

### Step 8：必须导出的验证量

每个时间步导出：

```text
Tin_bulk
Tout_bulk_mass_weighted
T25_bulk_mass_weighted
Q_air = mdot*cp*(Tin_bulk-Tout_bulk)
Q_wall = integral(q_wall_inner dA)
Q_soil_outer
air/pipe/soil storage terms
h_global_from_Q_wall
Nu_global
yplus_wall
```

其中出口温度和 25 m 截面温度必须使用质量流量加权：

```text
Tbulk(z) = integral_A rho*cp*u_z*T dA / integral_A rho*cp*u_z dA
```

## 5. 合格判据

### 空气侧基准算例

- `h_CFD / h_Gnielinski` 应在 `0.7-1.3` 内。
- `Q_air` 与 `Q_wall` 相对差小于 `5-10%`。

### Sharan 共轭传热算例

May cooling：

- 实验总换热量约 `7.31 kWh`。
- 若 CFD 仍只有 `2.14 kWh`，说明 CFD 仍未修正。

January heating：

- 实验总换热量约 `14.40 kWh`。
- 若 CFD 仍只有 `4.16 kWh`，说明 CFD 仍未修正。

### 与实验对比

只有满足能量闭合后，才计算：

```text
RMSE(T25)
RMSE(Tout)
MAE
Bias
```

否则 RMSE 不具备解释意义。

## 6. 论文中应如何表述

建议不要写“降阶模型与 CFD 差异很大，因此降阶模型不可靠”。更准确的表述是：

```text
The initial SST CFD implementation underpredicted the measured heat exchange by about 70%.
The discrepancy was traced to an unrealistically low global heat-transfer coefficient
and lack of energy closure between the air enthalpy change and wall heat-flux integral.
Therefore, the CFD model must first be verified using a constant-wall-temperature turbulent pipe benchmark
before being used as a high-fidelity reference for the reduced Minaei-G model.
```

中文：

```text
初始 SST CFD 模型显著低估实验换热量，偏差主要来自空气侧有效换热系数和能量闭合问题。
因此，在将 CFD 作为高保真基准前，必须先通过恒壁温湍流圆管算例验证空气侧换热，
并用质量流量加权温度和壁面热流积分完成能量闭合。
```
