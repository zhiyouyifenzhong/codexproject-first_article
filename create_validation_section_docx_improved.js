const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  ImageRun, Table, TableRow, TableCell, WidthType, BorderStyle, ShadingType,
  Footer, PageNumber,
} = require("C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/docx");

const ROOT = "G:/codexproject";
const RESULT = path.join(ROOT, "EAHE_airgap_physical_v18_minaei_contact_results");
const FIG = path.join(RESULT, "Nature_polished_figures");
const DATA = path.join(RESULT, "Paper_ready_data");
const CFD = path.join(ROOT, "MATLAB_annual_CFD_vs_original_model_validation");
const SHARAN = path.join(ROOT, "Validation_Sharan_same_parameters_MATLAB_only");
const OUT = path.join(ROOT, "EAHE_model_validation_section_improved.docx");

function csv(file) {
  const text = fs.readFileSync(file, "utf8").trim();
  const lines = text.split(/\r?\n/);
  const headers = lines[0].split(",");
  return lines.slice(1).map(line => {
    const cells = line.split(",");
    const o = {};
    headers.forEach((h, i) => o[h] = cells[i]);
    return o;
  });
}

function n(x, d = 2) {
  const v = Number(x);
  return Number.isFinite(v) ? v.toFixed(d) : String(x || "");
}

function relErr(a, b) {
  const av = Number(a), bv = Number(b);
  if (!Number.isFinite(av) || !Number.isFinite(bv) || Math.abs(av) < 1e-12) return "";
  return Math.abs((bv - av) / av * 100).toFixed(2);
}

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

function p(text) {
  return new Paragraph({
    spacing: { before: 70, after: 70, line: 360 },
    children: [new TextRun({ text, font: "SimSun", size: 24 })],
  });
}

function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 240, after: 160 },
    children: [new TextRun({ text, font: "SimHei", size: 32, bold: true })],
  });
}

function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 180, after: 110 },
    children: [new TextRun({ text, font: "SimHei", size: 28, bold: true })],
  });
}

function eq(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 90, after: 90 },
    children: [new TextRun({ text, font: "Cambria Math", size: 24 })],
  });
}

function caption(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 40, after: 150 },
    children: [new TextRun({ text, font: "SimSun", size: 21, italics: true })],
  });
}

function img(file, widthPx = 520) {
  if (!fs.existsSync(file)) return p("图像文件未找到：" + path.basename(file));
  const size = pngSize(file);
  const heightPx = Math.round(widthPx * size.height / size.width);
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 80 },
    children: [new ImageRun({
      type: "png",
      data: fs.readFileSync(file),
      transformation: { width: widthPx, height: heightPx },
      altText: { title: path.basename(file), description: "EAHE validation figure", name: path.basename(file) },
    })],
  });
}

function cell(text, width, header = false) {
  const border = { style: BorderStyle.SINGLE, size: 1, color: "BFC7CD" };
  return new TableCell({
    width: { size: width, type: WidthType.DXA },
    margins: { top: 80, bottom: 80, left: 90, right: 90 },
    shading: header ? { fill: "EAF2F8", type: ShadingType.CLEAR } : undefined,
    borders: { top: border, bottom: border, left: border, right: border },
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: String(text), font: "SimSun", size: 19, bold: header })],
    })],
  });
}

function tbl(headers, rows, widths) {
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: headers.map((h, i) => cell(h, widths[i], true)) }),
      ...rows.map(r => new TableRow({ children: r.map((c, i) => cell(c, widths[i], false)) })),
    ],
  });
}

const gap = csv(path.join(DATA, "PaperData_gap_thickness_summary.csv"));
const contact = csv(path.join(DATA, "PaperData_contact_coefficient_summary.csv"));
const energy = csv(path.join(RESULT, "Validation_energy_balance.csv"));
const nx = csv(path.join(RESULT, "Validation_Nx_independence.csv"));
const dt = csv(path.join(RESULT, "Validation_dt_independence.csv"));
const deg = csv(path.join(RESULT, "Validation_degeneration_delta0.csv"))[0];
const cfdTout = csv(path.join(CFD, "Annual_CFD_vs_original_MATLAB_Tout_metrics.csv"));
const cfdEnergy = csv(path.join(CFD, "Annual_CFD_vs_original_MATLAB_energy_metrics.csv"));
const sharan = csv(path.join(SHARAN, "Sharan_same_parameters_MATLAB_only_metrics.csv"));

const gap0 = gap.find(r => Number(r.delta_mm) === 0);
const gap1 = gap.find(r => Number(r.delta_mm) === 1);
const gap5 = gap.find(r => Number(r.delta_mm) === 5);
const chi0 = contact.find(r => Number(r.contact_coeff_chi) === 0);
const chi1 = contact.find(r => Number(r.contact_coeff_chi) === 1);
const nx80 = nx.find(r => Number(r.Nx) === 80);
const dt6 = dt.find(r => Number(r.dt_h) === 6);
const eMax = Math.max(...energy.map(r => Number(r.epsQ_max)));

const interfaceRows = [
  ["完全接触", "χ = 1，Rcontact = 0；或 δ = 0", "无空气间隙附加热阻", "验证模型退化能力"],
  ["不完全接触", "0 < χ < 1，δ > 0", "接触支路与空气间隙支路并联传热", "验证界面状态连续过渡"],
  ["完全不接触", "χ = 0，φ = 1，δ > 0", "完整环形空气间隙包覆", "验证最大界面热阻极限"],
];

const gapRows = gap.map(r => [n(r.delta_mm, Number(r.delta_mm) % 1 === 0 ? 0 : 1), n(r.Eabs_kWh, 1), n(r.Dgap_percent, 2), n(r.Rint_eff_mK_W, 3), n(r.TintJump_mean_C, 3)]);
const contactRows = contact.map(r => [n(r.contact_coeff_chi, Number(r.contact_coeff_chi) % 1 === 0 ? 0 : 2), n(r.air_gap_fraction_phi, Number(r.air_gap_fraction_phi) % 1 === 0 ? 0 : 2), n(r.Eabs_kWh, 1), n(r.ElossVsContact_percent, 2), n(r.Rint_eff_mK_W, 3)]);
const cfdRows = cfdTout.map(r => {
  const e = cfdEnergy.find(x => Number(x.delta_mm) === Number(r.delta_mm));
  return [n(r.delta_mm, 0), n(r.RMSE_C, 3), n(r.MAE_C, 3), n(r.max_abs_error_C, 3), n(e.Eabs_kWh_CFD, 1), n(e.Eabs_kWh_MinaeiG, 1), relErr(e.Eabs_kWh_CFD, e.Eabs_kWh_MinaeiG)];
});
const sharanRows = sharan.filter(r => r.quantity === "Tout").map(r => [r.case_name.replace("Sharan_", "").replace("_", " "), n(r.RMSE_C, 3), n(r.MAE_C, 3), n(r.bias_C, 3), n(r.max_abs_C, 3)]);

const validationRows = [
  ["退化验证", "完全接触工况", "Tout RMSE、最大偏差", `RMSE = ${n(deg.RMSE_Tout_C, 3)} °C，模型可退化`],
  ["界面极限验证", "完全不接触及间隙增厚", "Rint、Dgap、|E|", `δ = 5 mm 时损失 ${n(gap5.Dgap_percent, 2)}%`],
  ["能量守恒", "全部间隙工况", "εQ", `最大残差约 ${eMax.toExponential(2)}`],
  ["离散无关性", "Nx、Δt", "RMSE、年换热量误差", `Nx=80: ${n(nx80.RMSE_Tout_C, 3)} °C；Δt=6 h: ${n(dt6.RMSE_Tout_C, 3)} °C`],
  ["文献工况", "Sharan 两个月工况", "Tout RMSE、MAE", "RMSE 约 0.52–0.61 °C"],
  ["CFD 交叉验证", "COMSOL 年度模型", "Tout RMSE、年换热量误差", "RMSE 约 0.27–0.47 °C"],
  ["参数影响", "δ 与 χ", "Dgap、Rint、|E|", "间隙削弱换热，接触恢复换热"],
];

const children = [
  h1("3 模型验证与数值可靠性分析"),
  p("为验证考虑管土空气间隙和局部接触效应的 EAHE 瞬态模型的可靠性，本文从退化与界面极限工况、能量守恒、时间步长和空间段数无关性、文献工况对比以及 CFD 数值模型交叉验证等方面建立验证链条。在完成可靠性验证后，进一步分析空气间隙厚度和接触系数对出口温度及年换热量的影响。"),
  p("本文将“验证”和“参数影响分析”分开讨论。前者用于证明模型结构、数值求解和外部对比的合理性；后者用于解释空气间隙和接触状态变化对 EAHE 热性能的影响。这样的组织方式可以避免将参数敏感性分析误写为实验验证，也便于解释模型与 CFD 或文献数据之间的差异来源。"),

  h2("3.1 退化与界面极限工况验证"),
  p("界面状态是本文模型的重要物理边界。为验证界面热阻模块的物理一致性，本文设置完全接触、不完全接触和完全不接触三类典型界面状态。完全接触工况用于验证模型是否可退化为无空气间隙附加热阻的基准传热状态；不完全接触工况用于验证接触支路与空气间隙支路之间的连续过渡；完全不接触工况用于验证完整空气间隙下的最大热阻极限。"),
  tbl(["界面状态", "参数条件", "物理含义", "验证目的"], interfaceRows, [1300, 2300, 2700, 2200]),
  caption("表 1 三种界面状态及其验证目的"),
  p(`在完全接触工况下，界面附加热阻消失，改进模型应与基准模型保持一致。计算结果表明，δ = 0 mm 时出口温度 RMSE 为 ${n(deg.RMSE_Tout_C, 3)} °C，最大绝对偏差为 ${n(deg.MaxAbs_Tout_C, 3)} °C，说明新增界面模块不会在无间隙状态下引入额外偏差。在完全不接触工况下，空气间隙热阻达到最大；在不完全接触工况下，随着接触系数增大，等效界面热阻降低，换热能力逐渐恢复，说明模型能够描述从理想接触到完全脱空之间的连续变化。`),

  h2("3.2 界面热阻极限与空气间隙厚度验证"),
  p("空气间隙会增加管壁外侧到土壤边界之间的径向热阻。按照传热学规律，随着空气间隙厚度增大，界面等效热阻应单调增加，年换热量应单调降低。因此，空气间隙厚度扫描可作为界面热阻极限验证的重要部分。"),
  p(`本文设置 δ = 0、0.5、1、2、3 和 5 mm 六组工况。结果显示，当间隙厚度从 0 mm 增加至 5 mm 时，年换热量由 ${n(gap0.Eabs_kWh, 1)} kWh 降低至 ${n(gap5.Eabs_kWh, 1)} kWh，换热能力损失达到 ${n(gap5.Dgap_percent, 2)}%。当 δ = 1 mm 时，年换热量为 ${n(gap1.Eabs_kWh, 1)} kWh，相对于无间隙工况降低约 ${n(gap1.Dgap_percent, 2)}%。上述单调变化说明模型对空气间隙热阻的响应符合物理预期。`),
  tbl(["δ/mm", "|E|/kWh", "Dgap/%", "Rint/(m K W^-1)", "平均界面温差/°C"], gapRows, [950, 1550, 1250, 1900, 1900]),
  caption("表 2 空气间隙厚度对年换热量和界面热阻的影响"),
  img(path.join(FIG, "Fig15_factor_gap_thickness_nature.png"), 520),
  caption("图 1 空气间隙厚度对年换热量、换热损失和界面热阻的影响"),

  h2("3.3 能量守恒验证"),
  p("为检验瞬态求解过程的数值可靠性，本文检查空气侧换热量、土壤侧吸放热量以及系统蓄热项之间的能量平衡。能量残差定义为"),
  eq("εQ = |Qair - Qsoil - Qstore| / max(|Qair|, Qref)"),
  p(`其中，Qair 为空气侧总换热量，Qsoil 为进入土壤的热量，Qstore 为蓄热项，Qref 为参考功率。计算结果表明，各间隙工况下能量残差均保持在很低水平，全部工况最大残差约为 ${eMax.toExponential(2)}，说明空气、管壁和土壤边界之间的瞬态耦合满足能量一致性。`),
  img(path.join(RESULT, "Fig05_energy_balance_residual.png"), 520),
  caption("图 2 不同空气间隙工况下的能量残差"),

  h2("3.4 时间步长和空间段数无关性分析"),
  p("为排除时间和空间离散对计算结果的影响，本文分别进行轴向空间段数 Nx 和时间步长 Δt 的无关性分析。评价指标包括出口温度均方根误差 RMSE_Tout 和年换热量相对误差。本文采用的判断标准为：进一步加密离散后，出口温度 RMSE 小于 0.05 °C，且年换热量相对误差小于 1%，则认为计算结果对该离散参数不敏感。"),
  p(`空间段数分析显示，当 Nx = 80 时，出口温度 RMSE 为 ${n(nx80.RMSE_Tout_C, 4)} °C，年换热量相对误差为 ${n(nx80.RelErr_Eabs_percent, 3)}%，均低于设定阈值。时间步长分析显示，当 Δt = 6 h 时，出口温度 RMSE 为 ${n(dt6.RMSE_Tout_C, 4)} °C，年换热量相对误差为 ${n(dt6.RelErr_Eabs_percent, 3)}%，同样满足无关性要求。因此，本文选取 Nx = 80、Δt = 6 h 作为基准离散参数。`),
  img(path.join(RESULT, "Fig13_Nx_independence.png"), 500),
  caption("图 3 空间段数无关性分析"),
  img(path.join(RESULT, "Fig14_dt_independence.png"), 500),
  caption("图 4 时间步长无关性分析"),

  h2("3.5 文献工况局部验证"),
  p("为进一步检验模型在公开文献工况下的适用性，本文选取 Sharan 单根直管 EAHE 的典型运行期数据进行对比。由于该文献可用于对比的数据集中在特定月份或典型运行期，因此本文将其表述为文献工况局部验证，而不是全年实验验证。"),
  p("在保持管长、管径、埋深、流量、入口温度和土壤参数尽量一致的条件下，分别比较 May cooling 和 January heating 工况下的出口温度。结果表明，模型能够较好反映出口温度变化趋势，其中 May cooling 工况 Tout 的 RMSE 为 0.516 °C，January heating 工况 Tout 的 RMSE 为 0.613 °C。局部偏差主要可能来自现场土壤含水率、入口温度边界、实际埋设环境及运行状态与模型理想化条件之间的差异。"),
  tbl(["工况", "Tout RMSE/°C", "Tout MAE/°C", "Bias/°C", "最大偏差/°C"], sharanRows, [2100, 1600, 1600, 1400, 1600]),
  caption("表 3 Sharan 文献工况下出口温度对比误差"),
  img(path.join(SHARAN, "Fig_May_cooling_MATLAB_vs_Sharan.png"), 470),
  caption("图 5 May cooling 工况下 MATLAB 模型与 Sharan 数据对比"),
  img(path.join(SHARAN, "Fig_January_heating_MATLAB_vs_Sharan.png"), 470),
  caption("图 6 January heating 工况下 MATLAB 模型与 Sharan 数据对比"),

  h2("3.6 CFD 数值模型交叉验证"),
  p("为检验一维瞬态模型在相同边界条件下的计算合理性，本文进一步将 MATLAB 模型与 COMSOL CFD 湍流传热模型进行年度出口温度和年换热量对比。CFD 对比属于数值模型之间的交叉验证，其目的不是替代实验验证，而是判断一维模型在相同几何和边界条件下是否能够给出合理的趋势和量级。"),
  p("对比结果显示，δ = 0、1 和 5 mm 三组工况下，全年出口温度 RMSE 分别为约 0.472、0.419 和 0.266 °C；年换热量相对误差分别约为 0.03%、0.41% 和 1.71%。两种模型在季节变化趋势和年换热量量级上具有较好一致性。对于局部温度偏差，应重点检查 CFD 中的入口速度、湍流入口条件、壁面热耦合、土壤域尺寸、初始温度场和外边界条件，而不应简单归因于湍流模型本身错误。"),
  tbl(["δ/mm", "Tout RMSE/°C", "Tout MAE/°C", "最大温差/°C", "CFD |E|/kWh", "MATLAB |E|/kWh", "|E|误差/%"], cfdRows, [750, 1350, 1350, 1350, 1450, 1600, 1200]),
  caption("表 4 CFD 与 MATLAB 模型的年度出口温度和年换热量对比"),
  img(path.join(CFD, "Fig_annual_Tout_error_summary.png"), 470),
  caption("图 7 MATLAB 模型与 CFD 模型年度出口温度误差汇总"),

  h2("3.7 空气间隙厚度和接触系数影响分析"),
  p("在完成模型可靠性验证后，本文进一步分析空气间隙厚度和接触系数对 EAHE 换热性能的影响。空气间隙厚度代表管壁与土壤之间的脱空程度，接触系数 χ 则表征局部接触恢复程度。χ = 0 表示完整空气间隙状态，χ = 1 表示完全接触状态。"),
  p(`在 δ = 1 mm 条件下，接触系数 χ 从 0 增加至 1 时，年换热量由 ${n(chi0.Eabs_kWh, 1)} kWh 增加至 ${n(chi1.Eabs_kWh, 1)} kWh，相对于完全接触工况的损失由 ${n(chi0.ElossVsContact_percent, 2)}% 降低至 0%。这说明局部接触状态对空气间隙模型结果具有重要影响，仅考虑完整环形空气间隙可能会高估实际工程中的换热损失。`),
  tbl(["χ", "φ", "|E|/kWh", "相对完全接触损失/%", "Rint/(m K W^-1)"], contactRows, [850, 850, 1450, 2300, 1900]),
  caption("表 5 接触系数对年换热量和界面热阻的影响"),
  img(path.join(FIG, "Fig16_factor_contact_coefficient_nature.png"), 520),
  caption("图 8 接触系数对年换热量、换热损失和界面热阻的影响"),
  img(path.join(FIG, "Fig17_factor_contact_Tout_curves_nature.png"), 520),
  caption("图 9 不同接触系数下全年出口温度变化"),
  img(path.join(FIG, "Fig_factor_analysis_nature_grid.png"), 520),
  caption("图 10 空气间隙厚度和接触系数影响的综合对比"),

  h2("3.8 验证结论矩阵"),
  p("为便于总结模型验证结果，表 6 给出了本文验证工作的对象、评价指标和主要结论。可以看出，本文验证链条覆盖模型结构正确性、数值求解可靠性、文献工况适用性、CFD 数值交叉验证以及参数响应合理性。"),
  tbl(["验证项目", "验证对象", "评价指标", "主要结论"], validationRows, [1400, 1800, 1900, 3300]),
  caption("表 6 模型验证结论矩阵"),
  p("综上，模型在完全接触工况下能够正确退化，在完全不接触工况下能够反映空气间隙最大热阻效应，在不完全接触工况下能够描述接触恢复导致的换热增强；能量守恒和离散无关性结果表明数值求解具有稳定性；文献工况和 CFD 对比进一步说明模型能够给出合理的出口温度变化趋势和年换热量量级。"),
];

const doc = new Document({
  styles: {
    default: { document: { run: { font: "SimSun", size: 24 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 32, bold: true, font: "SimHei" }, paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 28, bold: true, font: "SimHei" }, paragraph: { spacing: { before: 180, after: 120 }, outlineLevel: 1 } },
    ],
  },
  sections: [{
    properties: {
      page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } },
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "第 ", font: "SimSun", size: 18 }), new TextRun({ children: [PageNumber.CURRENT], font: "SimSun", size: 18 }), new TextRun({ text: " 页", font: "SimSun", size: 18 })] })],
      }),
    },
    children,
  }],
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync(OUT, buffer);
  console.log(OUT);
});
