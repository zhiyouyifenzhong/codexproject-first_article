# 空气隙接触系数校准实施办法

## 1. 修正目标

当前 MATLAB 模型中已经有局部接触参数：

- `phi`：空气隙覆盖率，`phi=1` 表示完整环形空气隙。
- `chi`：接触系数，`chi=1-phi`，`chi=1` 表示完全接触，`chi=0` 表示完全脱空。

但是当前主计算使用：

```matlab
phiBase = 1.0;
```

因此主结果等价于 `chi=0` 的最不利完整脱空工况，没有真正启用局部接触修正。

修正目标是：用 COMSOL 结果反推合理的 `phi_cal` 或 `chi_cal`，然后把它作为论文模型中的物理接触参数，而不是继续使用后处理换热量缩放因子。

## 2. 推荐校准逻辑

采用两阶段校准：

### 阶段 A：基准传热校准

只使用 `delta = 0 mm` 工况，不涉及空气隙参数。

建议优先校准：

```text
h_i_scale
```

或：

```text
G_soil_scale
```

用于消除 MATLAB 一维 RC 模型与 COMSOL 二维轴对称模型之间的基准换热强度差异。

目标函数：

```text
J0 = w1 * RMSE(Tout_MATLAB, Tout_COMSOL)
   + w2 * abs(Eabs_MATLAB - Eabs_COMSOL) / Eabs_COMSOL
```

输出：

```text
h_i_scale_cal 或 G_soil_scale_cal
```

### 阶段 B：接触系数校准

固定阶段 A 的基准传热校准参数，仅校准空气隙接触参数。

建议校准：

```text
phi_cal
chi_cal = 1 - phi_cal
```

目标函数使用空气隙增量效应，而不是绝对出口温度：

```text
DeltaTout = Tout_delta - Tout_0
Dgap = 1 - Eabs_delta / Eabs_0
```

目标函数：

```text
Jgap(phi) = a * RMSE(DeltaTout_MATLAB(phi), DeltaTout_COMSOL)
          + b * RMSE(Dgap_MATLAB(phi), Dgap_COMSOL)
```

## 3. 训练集与验证集

不要用所有空气隙工况同时拟合后再声称验证成功。

推荐：

```text
训练集：delta = 1 mm, 3 mm
验证集：delta = 0.5 mm, 2 mm, 5 mm
```

如果训练集和验证集都能保持较小误差，论文可信度更高。

## 4. 当前已有数据给出的初始估计

前面后处理校准得到：

```text
gap_sensitivity_factor = 0.660900
```

如果把这个因子解释为空气隙有效覆盖率的初始估计，则：

```text
phi_initial ≈ 0.660900
chi_initial ≈ 0.339100
```

这不是最终物理校准结果，只能作为 `phi` 搜索的初值。

建议搜索范围：

```text
0.40 <= phi <= 1.00
0.00 <= chi <= 0.60
```

## 5. 代码实施位置

### 5.1 主计算中替换固定完整空气隙

原代码：

```matlab
phiBase = 1.0;
```

建议改为：

```matlab
opt.useContactCalibration = true;
opt.phiInitial = 0.6609003459;

if opt.useContactCalibration
    phiBase = opt.phiInitial;
else
    phiBase = 1.0;
end
```

正式版应进一步由 `calibrate_contact_phi(...)` 自动计算 `phiBase`。

### 5.2 保留原有并联热阻模型

现有代码已经合理，不需要重写：

```matlab
Gdelta = (1-phi)/Rp2 + phi/(Rp2 + Rgap_full);
Rdelta = 1/Gdelta;
```

该式对应：

```text
1/R_delta = chi/R_contact + phi/(R_contact + R_gap)
chi = 1 - phi
```

这是论文中应重点解释的接触系数模型。

### 5.3 新增接触系数校准函数

建议在 MATLAB 主脚本末尾新增：

```matlab
function Tcal = calibrate_contact_phi(p, deltaTrain_mm, deltaValid_mm, comsolDir, outDir)
    phiGrid = 0.40:0.02:1.00;
    target = read_comsol_dgap_targets(comsolDir);
    J = zeros(numel(phiGrid),1);

    for i = 1:numel(phiGrid)
        phi = phiGrid(i);
        res0 = simulateEAHE_case(p, 0, phi, 'AIRGAP');
        E0 = res0.E_abs;
        err = 0;

        for k = 1:numel(deltaTrain_mm)
            dmm = deltaTrain_mm(k);
            r = simulateEAHE_case(p, dmm*1e-3, phi, 'AIRGAP');
            DgapMat = 100*(1 - r.E_abs/E0);
            DgapCom = target.Dgap_percent(target.delta_mm == dmm);
            err = err + (DgapMat - DgapCom)^2;
        end

        J(i) = sqrt(err/numel(deltaTrain_mm));
    end

    [~, idx] = min(J);
    phiCal = phiGrid(idx);
    chiCal = 1 - phiCal;

    Tcal = validate_contact_phi(p, phiCal, deltaTrain_mm, deltaValid_mm, target);
    Tcal.phi_cal(:) = phiCal;
    Tcal.chi_cal(:) = chiCal;
    writetable(Tcal, fullfile(outDir, 'Contact_coefficient_calibration.csv'));
end
```

实际实现时还应加入 `DeltaTout` RMSE 项，不只用 `Dgap`。

## 6. 输出结果要求

校准后必须输出：

1. `Contact_coefficient_calibration.csv`
   - `phi_cal`
   - `chi_cal`
   - 训练集误差
   - 验证集误差

2. `Fig_contact_phi_objective.png`
   - 横坐标：`phi`
   - 纵坐标：目标函数 `Jgap`
   - 标出最优 `phi_cal`

3. `Fig_contact_calibrated_Dgap.png`
   - MATLAB 接触系数校准模型 vs COMSOL

4. `Fig_contact_calibrated_DeltaTout.png`
   - `Tout_delta - Tout_0` 的对比

## 7. 论文推荐表述

建议写成：

```text
为考虑实际施工中管土界面并非完全环形脱空，本文引入接触系数 chi 和空气隙覆盖率 phi，采用接触路径与空气隙路径并联的方式构建等效界面热阻。无空气隙工况用于校准基准传热强度，空气隙工况仅用于识别 phi/chi。校准后，未参与拟合的空气隙厚度工况仍与 COMSOL 结果保持良好一致，说明所提出的局部接触界面热阻模型具有合理的预测能力。
```

## 8. 注意事项

- 不建议继续把 `gap_sensitivity_factor` 作为正式论文模型参数。
- `gap_sensitivity_factor` 可以作为 `phi` 初值，但不能替代接触系数校准。
- `phi_cal` 必须限定在 `0` 到 `1` 之间。
- 如果 `phi_cal` 非常接近 1，说明完整空气隙假设足够。
- 如果 `phi_cal` 明显小于 1，说明局部接触对传热有重要贡献。
