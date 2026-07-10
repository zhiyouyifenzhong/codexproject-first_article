import re
from pathlib import Path

import pandas as pd


root = Path(__file__).resolve().parent
src = root / "EAHE_RC_short_paper.md"
out = root / "EAHE_RC_short_paper_word.md"

text = src.read_text(encoding="utf-8")

replacements = {
    "**图 1** 建议采用 `paper_figures/Fig02_baseline_transient.png`，用于展示入口/出口温度和瞬时换热量。":
        "![图1 基准工况下入口/出口空气温度与瞬时换热量响应。出口温度波动幅值明显小于入口温度，表明土壤具有削峰和蓄热作用。](paper_figures/Fig02_baseline_transient.png){width=90%}",
    "**图 2** 建议采用 `paper_figures/Fig05_sensitivity_summary.png`，用于综合展示间隙厚度、土壤导热系数、流量和管长的影响。":
        "![图2 主要影响因素敏感性分析。管土间隙厚度增大会降低换热量；第二层土壤导热系数、空气质量流量和管长增加会提高总换热量，但单位管长收益随管长增加而下降。](paper_figures/Fig05_sensitivity_summary.png){width=90%}",
    "**图 3** 建议采用 `paper_figures/Fig04_temperature_field_contours.png`。该图已经检查坐标方向，浅层位于图上方、深层位于图下方，温度场物理含义正确。":
        "![图3 管周土壤温度云图。启动时浅层土壤温度高于深层土壤；运行168 h后管周出现局部热积累区，说明连续制冷运行会改变近管土壤温度场。](paper_figures/Fig04_temperature_field_contours.png){width=90%}",
    "**图 4** 建议采用 `paper_figures/Fig07_analytical_model_comparison.png`。":
        "![图4 瞬态RC模型与经典稳态解析NTU模型对比。解析模型可给出一阶估计，但不能充分反映土壤热容和运行历史造成的热退化。](paper_figures/Fig07_analytical_model_comparison.png){width=90%}",
    "**图 5** 建议采用 `paper_figures/Fig08_ozgener2011_digitized_resistance.png`。需要说明的是，该图数据来自文献图像数字化，存在读图误差。若后续获得原始实验数据，应优先使用原始数据重新计算误差指标。":
        "![图5 Ozgener等（2011）文献图3-7数字化得到的总热阻数据。图4和图7的均值接近文献报告的0.021 K m/W，说明数字化数据与原文结论一致。](paper_figures/Fig08_ozgener2011_digitized_resistance.png){width=90%}\n\n需要说明的是，图5数据来自文献图像数字化，存在读图误差。若后续获得原始实验数据，应优先使用原始数据重新计算误差指标。",
}

for old, new in replacements.items():
    text = text.replace(old, new)

phase_marker = "分层土壤预计算结果表明，在夏季启动工况下，浅层土壤温度高于深层土壤，符合地表周期热波向下衰减的物理规律。运行 168 h 后，管周出现局部高温区，说明空气向土壤释放的热量主要累积于近管区域。由于模型采用周向分区 RC 网络，能够反映管道上方和下方土壤温度的差异。"
phase_insert = (
    phase_marker
    + "\n\n![图3a 分层土壤未扰动温度相位检查。EAHE启动相位已与夏季制冷工况对齐，浅层土壤温度高于深层土壤。](paper_figures/Fig01_soil_phase_check.png){width=72%}"
)
text = text.replace(phase_marker, phase_insert)

sat_marker = "基准工况下，入口空气温度呈周期性波动，出口温度波动幅值明显减小，说明土壤对空气温度具有削峰作用。连续运行 7 d 后，出口空气最终温度为 24.37 degC，最后一天日均换热量为 693.0 W，日均换热退化比为 0.833。近管土壤日均温升达到 3.36 K，说明热量在管周土壤中不断累积，导致系统换热能力逐渐下降。"
sat_insert = (
    sat_marker
    + "\n\n![图1a 连续运行下的日均换热退化。固定间隙工况下换热量随运行天数下降，反映近管土壤热饱和效应。](paper_figures/Fig03_heat_saturation_degradation.png){width=72%}"
)
text = text.replace(sat_marker, sat_insert)

var_marker = "间隙导热系数也具有明显影响。当 \\(k_{\\mathrm{gap}}\\) 从 0.026 W/(m K) 增至 0.5 W/(m K) 时，最后一天日均换热量由 652.2 W 增至 737.3 W。对于工程设计而言，提高回填材料密实度和导热能力，可有效降低管土界面热阻。"
var_insert = (
    var_marker
    + "\n\n![图2a 固定间隙热阻与温度相关间隙热阻模型对比。温度相关热阻使出口温度略升高、换热量略降低，说明界面状态变化会进一步削弱长期换热性能。](paper_figures/Fig06_variable_gap_extension.png){width=82%}"
)
text = text.replace(var_marker, var_insert)

ozg = pd.read_csv(root / "paper_tables" / "ozgener2011_digitized_rtot_statistics.csv")
table_text = """

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
"""

for _, row in ozg.iterrows():
    table_text += (
        f"| {row['Figure']} | {int(row['N'])} | {row['Rtot_mean_K_m_W']:.5f} | "
        f"{row['Rtot_min_K_m_W']:.5f} | {row['Rtot_max_K_m_W']:.5f} | "
        f"{row['RMSE_vs_reported_mean_K_m_W']:.5f} |\n"
    )

text = text.replace("## 6 结论", table_text + "\n## 6 结论")

# Older Pandoc versions used in this environment do not support LaTeX \\tag{}
# in docx math conversion. Keep the equation number inside the math object.
text = re.sub(r"\\tag\{(\d+)\}", r"\\qquad (\1)", text)

metadata = """---
title: 考虑管土间隙热阻与竖向分层土壤的水平埋管式EAHE瞬态RC网络模型
author: ''
date: ''
---

"""

lines = text.splitlines()
if lines and lines[0].startswith("# "):
    lines = lines[1:]

out.write_text(metadata + "\n".join(lines), encoding="utf-8")
print(str(out))
