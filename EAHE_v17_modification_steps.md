# EAHE v17 review-ready 修改与运行步骤

## 1. 修改后的脚本

使用：

`G:\codexproject\EAHE_airgap_physical_modules_v17_review_ready.m`

原始下载目录中的 v16 文件没有被覆盖。

## 2. 本次代码修改内容

1. 默认开启审稿所需验证：
   - `opt.runNxIndependence = true`
   - `opt.runDtIndependence = true`

2. 修正主要图件：
   - 所有 `delta` 曲线使用明确图例，例如 `delta = 0.5 mm`。
   - 能量残差图改为 `semilogy`。
   - 换热量图加入零线，并注明 `Qair > 0` 表示空气被冷却。
   - 热阻贡献率图改为分类横坐标，避免 4 mm 空档。
   - 工程修正图加入 `etaU = 0.98, 0.95, 0.90` 阈值线和允许空气隙厚度。

3. 修正方法图：
   - 物理模型图中的空气流动箭头改为水平短箭头，避免斜穿图面。
   - 方法图统一使用高清导出。

4. 新增审稿增强图：
   - `Fig08_annual_energy_vs_delta`
   - `Fig09_Dgap_vs_delta`
   - `Fig10_Tout_deviation_summary`
   - `Fig11_interface_jump_summary`
   - `Fig12_interface_resistance_limit`
   - `Fig13_Nx_independence`
   - `Fig14_dt_independence`

5. 图片导出方式：
   - 每张图同时导出 `.png` 和 `.pdf`。
   - PNG 分辨率为 600 dpi。

6. Excel 输出：
   - `EAHE_airgap_review_ready_tables.xlsx`
   - 包含主汇总、退化验证、界面极限、能量守恒、无关性验证、参数表、图像清单和各工况时间序列。

## 3. 运行步骤

1. 打开 MATLAB。
2. 切换到工作目录：

   ```matlab
   cd('G:\codexproject')
   ```

3. 运行脚本：

   ```matlab
   run('EAHE_airgap_physical_modules_v17_review_ready.m')
   ```

4. 输出目录：

   `G:\codexproject\EAHE_airgap_physical_v17_review_ready_results`

## 4. 运行后需要检查的文件

必须存在：

- `EAHE_airgap_review_ready_tables.xlsx`
- `Table_01_main_performance_summary.csv`
- `Validation_Nx_independence.csv`
- `Validation_dt_independence.csv`
- `Fig01_Tin_Th_Tout.png`
- `Fig08_annual_energy_vs_delta.png`
- `Fig09_Dgap_vs_delta.png`
- `Fig13_Nx_independence.png`
- `Fig14_dt_independence.png`

## 5. 静态检查结果

已运行 MATLAB `checkcode`。

结果：

- 无语法错误。
- 仅剩 5 条稀疏矩阵逐项赋值的性能提示，不影响结果正确性。

## 6. 论文中建议使用的图

正文优先使用：

1. 物理模型图
2. 热阻-热容网络图
3. 求解流程图
4. 出口温度曲线
5. 出口温度偏差曲线
6. 年换热量随空气隙厚度变化图
7. 性能衰减因子图
8. 界面温度跳跃汇总图
9. 工程修正系数图
10. Nx 和 dt 无关性图

补充材料使用：

- 能量守恒残差图
- 界面热阻极限验证图
- 全部时间序列 Excel 数据
