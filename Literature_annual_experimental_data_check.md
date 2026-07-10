# Minaei 文献年度实验数据与出口温度数据核查

## 结论

Minaei et al. (2021) 文献中有年度尺度的出口温度验证曲线和年度 RMSD 指标，但没有给出可直接导入模型的全年逐时/逐日出口温度表格数据。

因此，论文验证部分可以使用 Minaei 文献给出的年度验证结论作为精度基准：

- 与拟合实验测量值相比，Minaei 模型年度 RMSD 为 1.98 degC。
- 与 Vaz et al. 的 full 3D numerical model 相比，Minaei 模型年度 RMSD 为 0.48 degC。
- Minaei Fig. 4 展示了第二年全年结果，与 experimental measurements、full numerical simulation 和 Brum 简化模型对比。

但如果需要“全年实验出口温度序列”来逐点计算 RMSE、MAE 或年换热量误差，需要：

1. 从 Minaei Fig. 4 或 Vaz et al. (2011) 对应图像数字化提取曲线；
2. 或获取 Vaz et al. 实验原始数据；
3. 或在论文中明确说明：当前年度实验基准来自文献图形曲线和文献 RMSD，而短时 CFD/MATLAB 验证使用 Sharan 的可量化实验点。

## Minaei 文献中能直接使用的信息

Minaei 第 3.1 节 Validation 说明，其 hybrid model 使用 Vaz et al. 的实验测量进行验证。仿真计算了连续两年，并报告第二年结果，以便与文献数据保持一致。

文献还给出用于验证的周期边界条件：

- 地表温度函数 Eq. (24)：年周期正弦边界，平均值约 18.55 degC，振幅约 6.28 degC。
- 入口空气温度函数 Eq. (25)：年周期正弦入口，平均值约 20.34 degC，振幅约 5.66 degC。

这些函数可用于复现实验工况的年度模型输入，但不是出口温度实验数据表。

## 可作为论文验证依据的参考文献

- Minaei et al. (2021), Thermal resistance capacity model for transient simulation of Earth-Air Heat Exchangers. Renewable Energy 167, 558-567. DOI: https://doi.org/10.1016/j.renene.2020.11.114
- Vaz et al. (2011), Experimental and numerical analysis of an earth-air heat exchanger. Energy and Buildings 43, 2476-2482. DOI: https://doi.org/10.1016/j.enbuild.2011.06.003
- Hermes et al. (2020), Further realistic annual simulations of earth-air heat exchangers installations in a coastal city. Sustainable Energy Technologies and Assessments 37, 100603. DOI: https://doi.org/10.1016/j.seta.2019.100603

## 对当前论文验证章节的建议写法

年度验证不要声称已经获得 Minaei 或 Vaz 的全年原始实验表格数据。更严谨的表述是：

> Minaei et al. validated their annual TRCM prediction against the fitted experimental measurements of Vaz et al. and reported an annual RMSD of 1.98 degC. Since the original paper provides the annual validation mainly as plotted curves rather than tabulated time-series data, the present work uses the published RMSD and annual curve as literature-level evidence, while quantitative point-by-point validation is performed with the available Sharan experimental data and the validated k-epsilon CFD model.

这样不会把图像曲线误写成原始实验数据，同时仍然保留了文献验证价值。
