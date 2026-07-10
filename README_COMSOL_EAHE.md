# COMSOL EAHE 空气隙热阻数值验证脚本

本目录提供一套用于“管土空气隙界面热阻”验证的 COMSOL 数值实验脚本。请注意，这部分结果应称为 **COMSOL 数值验证** 或 **COMSOL 数值实验**，不要称为真实实验验证。

建议论文表述：

> 为进一步验证空气隙等效热阻模型的合理性，本文建立了 COMSOL 共轭传热数值模型，并分别采用显式空气隙区域和等效热阻边界两种方式描述管土空气隙。通过比较两种模型的出口温度、界面温度跳跃和管土界面热流，验证空气隙等效热阻处理的可行性。

## 文件

- `comsol_eahe_airgap_model.m`  
  使用 COMSOL LiveLink for MATLAB 建立 2D 轴对称瞬态共轭传热模型，循环计算显式空气隙模型和等效热阻边界模型，并导出 CSV。

- `postprocess_comsol_eahe.m`  
  读取 COMSOL CSV，计算出口温度误差、瞬时换热量、年换热量、空气隙性能衰减因子、界面温度跳跃和界面热流衰减率，并输出图像。

- `README_COMSOL_EAHE.md`  
  本说明文件。

- `run_comsol_mesh_independence.m`  
  mapped 网格无关性验证脚本。默认对 `delta = 0.5 mm`、两类模型、30 天 `short_test` 做 coarse/default/fine 三组网格比较。

## 需要的软件和模块

- MATLAB。
- COMSOL Multiphysics。
- COMSOL LiveLink for MATLAB。
- Heat Transfer Module，或至少包含 `Heat Transfer in Solids and Fluids` 物理接口的许可。

推荐从 COMSOL 的 MATLAB 入口启动：

```matlab
mphstart
```

或在系统命令行中使用 COMSOL with MATLAB 启动方式，然后在 MATLAB 中运行脚本。

本机已检测到 COMSOL 6.3 路径可用：

```text
G:\COMSOL\COMSOL63\Multiphysics
```

LiveLink 的 MATLAB 路径为：

```matlab
addpath('G:\COMSOL\COMSOL63\Multiphysics\mli')
```

如果 `mphstart` 提示 `No User information found`，需要先在一个交互式 PowerShell 或 CMD 中初始化 COMSOL Multiphysics Server 用户信息：

```powershell
& 'G:\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolmphserver.exe' -port 2036 -login force -user your_user_name
```

按提示输入用户名/密码并保持 server 运行。之后在 MATLAB 中连接：

```matlab
addpath('G:\COMSOL\COMSOL63\Multiphysics\mli')
mphstart('localhost',2036,'your_user_name','your_password')
```

也可以让脚本自动添加 LiveLink 路径并连接已有 server：

```matlab
comsol_eahe_airgap_model(struct( ...
    'comsol_mli_path','G:\COMSOL\COMSOL63\Multiphysics\mli', ...
    'auto_mphstart',true, ...
    'mphserver_host','localhost', ...
    'mphserver_port',2036, ...
    'mphserver_user','your_user_name', ...
    'mphserver_password','your_password'))
```

## 运行方法

快速测试：

```matlab
comsol_eahe_airgap_model
postprocess_comsol_eahe
```

全年计算：

```matlab
comsol_eahe_airgap_model(struct('study_mode',"annual"))
postprocess_comsol_eahe
```

只运行一类模型或部分空气隙厚度：

```matlab
comsol_eahe_airgap_model(struct( ...
    'model_type',"explicit_gap", ...
    'study_mode',"short_test", ...
    'delta_mm_list',[0 1 3]))
```

指定输出目录并后处理该目录：

```matlab
comsol_eahe_airgap_model(struct( ...
    'output_dir','COMSOL_EAHE_outputs_short_test_full', ...
    'model_type',"both", ...
    'delta_mm_list',[0 0.5 1 2 3 5], ...
    'study_mode',"short_test"))

postprocess_comsol_eahe(struct( ...
    'output_dir','COMSOL_EAHE_outputs_short_test_full'))
```

可选 `model_type`：

- `"both"`
- `"explicit_gap"`
- `"resistance_gap"`

可选 `study_mode`：

- `"short_test"`：`0:1 h:30 day`
- `"annual"`：`0:6 h:365 day`

如果全年计算太慢，可先把 `annual_end_s` 改为 `90*day_s` 做 90 天测试。

## 模型说明

脚本建立 2D 轴对称模型。COMSOL 几何中使用：

- `x = r`，径向坐标；
- `y = z`，管道轴向坐标。

几何区域：

- 管内空气区：`0 <= r <= rpi`
- 管壁区：`rpi < r <= rpo`
- 显式空气隙区：`rpo < r <= rpo + delta`
- 土壤区：外边界到 `Rs`

当 `delta = 0` 时，显式空气隙模型不会创建零厚度空气隙，而是退化为管壁与土壤直接接触。

等效热阻边界模型不创建空气隙实体。其面积热阻为：

```text
Rgap'' = rpo * ln((rpo + delta)/rpo) / k_air
```

对应单位长度热阻为：

```text
Rgap' = ln((rpo + delta)/rpo) / (2*pi*k_air)
```

当 `delta = 0` 时，`Rgap'' = 0`，模型应退化为热连续边界。

## 单位约定

脚本内部采用 SI 单位：

- 长度：m
- 时间：s
- 温度：K
- 导出温度：degC
- 热流率：W
- 年换热量：kWh
- 单位长度界面热流：W/m

入口温度：

```text
Tin(t) = Tin_mean + A_in*cos(2*pi*(t - t_phase)/P)
```

土壤外边界温度：

```text
Th(t) = Tm - A_s*exp(-H*sqrt(pi/(P*alpha_s)))
        *cos(2*pi/P*(t - t0 - H/2*sqrt(P/(pi*alpha_s))))
```

`short_test` 模式中，脚本默认使用恒定土壤外边界温度 `19.2 degC`，以便快速验证。

## 网格参数

在 `comsol_eahe_airgap_model.m` 开头的 `eahe_default_config()` 中设置：

- `use_mapped_mesh`：默认 `true`。使用结构化四边形 mapped 网格，径向和轴向单元数分别控制，适合 30 m 长管和 0.5 mm 空气隙这类细长区域。
- `mesh_air_max`：管内空气区最大单元尺寸。
- `mesh_pipe_max`：管壁区最大单元尺寸。
- `mesh_gap_max`：空气隙区最大单元尺寸。对 `delta = 0.5 mm`，建议不大于 `0.1 mm`。
- `mesh_soil_near_max`：管外壁、空气隙和近壁土壤附近的最大单元尺寸。
- `mesh_soil_far_max`：远场土壤最大单元尺寸。
- `mesh_axial_max`：mapped 网格轴向单元长度上限，默认 `0.50 m`。
- `mesh_air_radial_elems`、`mesh_pipe_radial_elems`、`mesh_gap_radial_elems_min`、`mesh_soil_radial_elems`：mapped 网格中各径向区域的单元层数。

显式空气隙模型中，小空气隙至少应保持 3 到 5 层单元。

说明：早期版本使用自由三角网格时，`delta = 0.5 mm` 且 `L = 30 m` 会产生极大的各向同性网格。当前脚本默认使用 mapped 网格，将空气隙径向加密和管道轴向离散分开控制，可显著降低单元数。

## 输出目录

所有 CSV 和 PNG 默认输出到：

```text
COMSOL_EAHE_outputs/
```

若目录不存在，脚本会自动创建。

## COMSOL 脚本导出的 CSV

- `COMSOL_Tout_delta_sweep.csv`  
  出口截面平均温度，包含 `Tin_C` 和所有模型/空气隙厚度的 `Tout`。

- `COMSOL_Q_delta_sweep.csv`  
  瞬时换热量：

  ```text
  Q(t) = mdot * cp_f * (Tin - Tout)
  ```

- `COMSOL_interface_jump.csv`  
  管道中部 `z = L/2` 处的 `Tpo_mid_C`、`Tg_mid_C`、`DeltaTint_mid_C` 和 `qg_mid_W_per_m`。

- `COMSOL_annual_energy_summary.csv`  
  `Ecool_kWh`、`Eheat_kWh`、`Eabs_kWh`、`Dgap_percent`。

- `COMSOL_explicit_vs_resistance_gap.csv`  
  显式空气隙模型与等效热阻边界模型的逐时对比。

- `COMSOL_failed_cases.csv`  
  若某个 `model_type` 和 `delta` 求解失败，会记录错误信息。

每个单独工况还会导出：

```text
COMSOL_case_<model_type>_delta_<delta>.csv
```

## 后处理输出

`postprocess_comsol_eahe.m` 会生成：

- `COMSOL_validation_metrics.csv`
- `COMSOL_performance_summary.csv`
- `COMSOL_mechanism_chain_summary.csv`

默认读取 `COMSOL_EAHE_outputs/`。若需要处理其他目录，可使用：

```matlab
postprocess_comsol_eahe(struct('output_dir','COMSOL_EAHE_outputs_short_test_full'))
```

并保存以下图像：

- `Fig_COMSOL_01_Tout_delta_sweep.png`
- `Fig_COMSOL_02_Tout_deviation.png`
- `Fig_COMSOL_03_Q_delta_sweep.png`
- `Fig_COMSOL_04_annual_energy.png`
- `Fig_COMSOL_05_Dgap.png`
- `Fig_COMSOL_06_explicit_vs_resistance_Tout.png`
- `Fig_COMSOL_07_interface_jump.png`
- `Fig_COMSOL_08_qg_decay.png`

脚本不会把二维温度云图作为主要结果图；重点是出口温度、界面温度跳跃、热流衰减和换热量。

## 已生成的主要结果目录

- `COMSOL_EAHE_outputs_short_test_full/`  
  30 天 `short_test` 全参数扫描结果，包含 12 个工况的 CSV、汇总表和 8 张图。

- `COMSOL_EAHE_outputs_annual_full/`  
  365 天 `annual` 全参数扫描结果，包含 12 个工况的 CSV、年度换热量汇总、验证指标和 8 张图。

- `COMSOL_EAHE_mesh_independence/`  
  mapped 网格无关性验证结果。汇总表为 `COMSOL_mesh_independence_summary.csv`。

- `COMSOL_EAHE_field_materials/`  
  后续论文或汇报材料用的代表性模型图和温度云图。图片位于 `field_figures/`，包含 `delta = 0.5 mm` 和 `delta = 5 mm` 下显式空气隙模型、等效热阻模型的几何结构图、初始温度云图、30 天结束温度云图和近壁放大温度云图。

## 模型图和温度云图

代表性云图可通过以下命令生成：

```matlab
comsol_eahe_airgap_model(struct( ...
    'output_dir','COMSOL_EAHE_field_materials', ...
    'model_type',"both", ...
    'delta_mm_list',[0.5 5], ...
    'study_mode',"short_test", ...
    'export_field_figures',true))
```

输出示例：

- `Fig_COMSOL_geometry_explicit_gap_delta_0p5mm.png`
- `Fig_COMSOL_Tfield_initial_explicit_gap_delta_0p5mm.png`
- `Fig_COMSOL_Tfield_final_explicit_gap_delta_0p5mm.png`
- `Fig_COMSOL_Tfield_final_zoom_explicit_gap_delta_0p5mm.png`

说明：温度云图用于辅助展示模型结构和温度场演化，不建议替代出口温度、界面温度跳跃、年度换热量等主要验证指标。

## 网格无关性验证

运行：

```matlab
run_comsol_mesh_independence
```

该脚本对 `delta = 0.5 mm`、`short_test`、两类模型分别运行三组 mapped 网格：

- coarse：`mesh_axial_max = 1.00 m`
- default：`mesh_axial_max = 0.50 m`
- fine：`mesh_axial_max = 0.25 m`

当前实算结果显示，相对于 fine 网格，default 网格的出口温度 RMSE 约为 `0.018-0.020 degC`，`Eabs` 相对误差约为 `1.4%`；coarse 网格误差约为 `6.9%`，不建议作为最终结果网格。若论文需要更严格的网格独立性，可使用 fine 配置重新运行年度扫描。

## 与 MATLAB RC 模型对比

后处理脚本预留了函数：

```matlab
compare_comsol_with_rc(comsolFile, rcFile)
```

若下列文件存在于输出目录：

- `EAHE_RC_Tout_delta_sweep.csv`
- `EAHE_RC_Q_delta_sweep.csv`
- `EAHE_RC_interface_jump.csv`
- `EAHE_RC_annual_energy_summary.csv`

脚本会尝试计算：

- `RMSE_Tout`
- `MAE_Tout`
- `MaxAbs_Tout`
- `RelError_Eabs_percent`

若 RC 文件不存在，只给出 warning，不中断后处理。

## 可能需要根据 COMSOL 版本调整的 API

COMSOL LiveLink 的以下 API 或特征名称可能随版本变化：

- `HeatTransferInSolidsAndFluids` 物理接口名称。
- 流体传热域的速度字段属性，如 `u`、`w` 或 `VelocityField`。
- 出口边界特征，如 `Outflow` 或 `ConvectiveFlux`。
- 等效热阻边界特征，如 `ThermalContact`、`ThinLayer`，以及热阻属性名 `Rc`、`Rth`。
- `mphselectbox` 的参数格式。
- 时间求解结果提取中的 `mphevalglobal(...,'t',tSec)` 和 `mphinterp(...,'t',tSec)` 写法。

脚本已经在这些位置加入 `try-catch` 和注释。如果版本不匹配，建议先在 COMSOL GUI 中手动建立一个最小模型，然后使用 “Save as MATLAB File” 导出，对照修改对应特征名。

## 常见问题

1. `Undefined function ModelUtil`  
   没有通过 LiveLink 启动 MATLAB，或没有执行 `mphstart`。

2. `Unknown physics interface HeatTransferInSolidsAndFluids`  
   COMSOL 版本或模块许可不同。请在 GUI 中确认 Heat Transfer in Solids and Fluids 的接口 key。

3. `mphselectbox` 没选中域或边界  
   检查几何坐标。脚本使用 `x = r`、`y = z`。若版本选择行为不同，可在 COMSOL GUI 中创建等价 selections 后替换脚本中的 selection tag。

4. 等效热阻模型没有形成温度跳跃  
   检查 `ThermalContact` 或 `ThinLayer` 是否确实作用在管外壁和土壤之间的内部边界上。不同 COMSOL 版本对热接触和薄层边界的温度连续性处理不同。

5. 全年计算耗时很长  
   先运行 `short_test`，确认显式空气隙与等效热阻边界的一致性，再运行 `annual`。也可临时缩短 `annual_end_s`。

6. `delta = 0.5 mm` 网格失败或过粗  
   降低 `mesh_gap_max`，并确认空气隙域至少有 3 到 5 层单元。

## 重要说明

这些脚本只生成建模、求解和后处理流程，不编造任何数值结果。只有在 COMSOL 成功求解并导出 CSV 后，后处理脚本才会计算指标和绘图。
