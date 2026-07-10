# Minaei G 函数土壤响应核对比分析

## 依据

Minaei 等（2021）在 Eq. (8)-(10) 中把管外土壤视为半无限径向导热域。恒定单位长度热流下：

```text
T(r,t) = TGround + qpo / ks * G(r,t)
```

其中 G(r,t) 由 Eq. (9) 的 Bessel 函数积分给出。实际 EAHE 中 qpo 随时间变化，因此 Eq. (10) 使用 Duhamel 叠加：

```text
Tpo(tm) = TGround + 1/ks * sum_k [qpo(tk)-qpo(tk-1)] * G(rpo, tm-tk-1)
          + seasonal ground-temperature term
```

这与本 MATLAB 模型已有的 `dq` 历史热流增量叠加结构一致，核心需要替换的是响应核 G(tau) 本身。

## 代码实现

修改文件：

```text
G:\codexproject\EAHE_airgap_physical_modules_v18_minaei_contact.m
```

主要改动：

- 默认 `p.soilKernelType` 从 `FLS` 改为 `MINAEI_G`。
- 新增 `soilResponseKernel_MinaeiG`，按 Minaei Eq. (9) 计算 Bessel 积分。
- `buildSoilResponseKernel` 支持 `MINAEI_G`、`ILS`、`FLS` 三种核。
- 新增 `build_soil_kernel_comparison_table`，输出 Minaei G、ILS、FLS mid-length 之间的量化对比。
- 主流程新增 `Table_05_minaei_g_kernel_comparison.csv`。
- 方法图新增 `Fig00d_Minaei_G_kernel_comparison`。
- Excel 工作簿新增 `minaei_g_kernel` sheet。
- Origin 数据包新增 `Origin_Fig00d_Minaei_G_kernel_comparison.csv`。

## 与文献的一致性

一致点：

- 保留文献的半无限土壤径向导热假设。
- 保留文献的单位长度热流响应形式 `DeltaT = q'/ks * G`。
- 保留文献 Eq. (10) 的热流增量 Duhamel 叠加。
- 保留地表年周期温度向埋深传播的未扰动土壤温度项。

模型扩展点：

- 文献中 G 函数用于管外壁 `rpo`；本空气隙模型中，热流进入土壤的位置是空气隙外边界 `rg = rpo + delta`，因此 `MINAEI_G` 在主求解中以 `rg` 作为土壤响应半径。无空气隙时 `rg = rpo`，退化为文献形式。
- 文献忽略土壤轴向导热；`MINAEI_G` 也按这个假设实现。旧 `FLS` 核保留为对照，用于观察有限长度端部修正的影响。

## 代表性数值对比

在当前默认参数 `ks = 1.5 W/(m K)`、`rpo = 0.06 m`、`alpha_s = 6.94e-7 m2/s` 下，Minaei G 与 ILS 的代表性对比如下：

| tau | Minaei G | ILS G | Minaei/ILS | DeltaT for 1 W/m |
|---:|---:|---:|---:|---:|
| 0.5 h | 0.08425 | 0.02864 | 2.941 | 0.05616 C |
| 6 h | 0.20479 | 0.18265 | 1.121 | 0.13653 C |
| 24 h | 0.29805 | 0.28946 | 1.030 | 0.19870 C |
| 168 h | 0.44470 | 0.44329 | 1.003 | 0.29647 C |
| 8760 h | 0.75722 | 0.75777 | 0.999 | 0.50481 C |

结论：Minaei G 核对短时间热流变化的自响应更强，尤其在小于一个时间步量级时明显高于 ILS；随着时间增大，二者快速接近。换言之，替换为文献 G 函数主要改变瞬态初期和高频热流扰动响应，对年尺度长记忆项影响较小。

## 对结果解释的影响

- 出口温度：短时热流更快反馈到土壤边界温度，可能使 `Tg` 更快接近管壁侧扰动温度。
- 空气隙影响：空气隙热阻仍通过 `Rdelta` 控制 `qg`，Minaei G 控制的是进入土壤后的扩散记忆，因此两者物理职责分离。
- 与旧 FLS 对比：FLS 包含有限管长端部修正，而 Minaei 文献假设管长远大于直径、忽略轴向土壤导热；如果年尺度 FLS 与 Minaei 差异较大，应在论文中解释为端部效应假设差异，而不是热阻网络错误。
