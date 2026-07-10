const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  ImageRun, Table, TableRow, TableCell, WidthType, BorderStyle, ShadingType,
  Footer, PageNumber, PageBreak,
} = require("C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/docx");

const ROOT = "G:/codexproject";
const RESULT = path.join(ROOT, "EAHE_airgap_physical_v18_minaei_contact_results");
const DATA = path.join(RESULT, "Paper_ready_data");
const FIG = path.join(RESULT, "Nature_polished_figures");
const CFD = path.join(ROOT, "MATLAB_annual_CFD_vs_original_model_validation");
const SHARAN = path.join(ROOT, "Validation_Sharan_same_parameters_MATLAB_only");
const OUT = path.join(ROOT, "EAHE_airgap_contact_journal_paper_template.docx");

function csv(file) {
  const text = fs.readFileSync(file, "utf8").trim();
  const lines = text.split(/\r?\n/);
  const headers = lines[0].split(",");
  return lines.slice(1).map(line => {
    const cells = line.split(",");
    const obj = {};
    headers.forEach((h, i) => obj[h] = cells[i]);
    return obj;
  });
}

function fmt(x, d = 2) {
  const v = Number(x);
  return Number.isFinite(v) ? v.toFixed(d) : String(x || "");
}

function exp(x) {
  const v = Number(x);
  return Number.isFinite(v) ? v.toExponential(2) : String(x || "");
}

function relErr(base, value) {
  const b = Number(base);
  const v = Number(value);
  if (!Number.isFinite(b) || !Number.isFinite(v) || Math.abs(b) < 1e-12) return "";
  return Math.abs((v - b) / b * 100).toFixed(2);
}

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

function run(text, opts = {}) {
  return new TextRun(Object.assign({ text, font: opts.font || "SimSun", size: opts.size || 24 }, opts));
}

function para(text, opts = {}) {
  return new Paragraph({
    alignment: opts.align || AlignmentType.LEFT,
    spacing: { before: opts.before || 70, after: opts.after || 70, line: opts.line || 360 },
    children: [run(text, opts)],
  });
}

function title(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 260, after: 180 },
    children: [run(text, { font: "SimHei", size: 34, bold: true })],
  });
}

function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 240, after: 150 },
    children: [run(text, { font: "SimHei", size: 30, bold: true })],
  });
}

function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 190, after: 110 },
    children: [run(text, { font: "SimHei", size: 26, bold: true })],
  });
}

function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 140, after: 90 },
    children: [run(text, { font: "SimHei", size: 24, bold: true })],
  });
}

function caption(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 40, after: 150 },
    children: [run(text, { font: "SimSun", size: 21, italics: true })],
  });
}

function equation(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 90, after: 90 },
    children: [run(text, { font: "Cambria Math", size: 24 })],
  });
}

function img(file, width = 500) {
  if (!fs.existsSync(file)) return para("[Figure file missing: " + path.basename(file) + "]");
  const s = pngSize(file);
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 80 },
    children: [new ImageRun({
      type: "png",
      data: fs.readFileSync(file),
      transformation: { width, height: Math.round(width * s.height / s.width) },
      altText: { title: path.basename(file), description: "EAHE journal paper figure", name: path.basename(file) },
    })],
  });
}

function cell(text, width, header = false) {
  const border = { style: BorderStyle.SINGLE, size: 1, color: "BFC7CD" };
  return new TableCell({
    width: { size: width, type: WidthType.DXA },
    margins: { top: 70, bottom: 70, left: 85, right: 85 },
    shading: header ? { fill: "EAF2F8", type: ShadingType.CLEAR } : undefined,
    borders: { top: border, bottom: border, left: border, right: border },
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [run(String(text), { font: "SimSun", size: 18, bold: header })],
    })],
  });
}

function table(headers, rows, widths) {
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: headers.map((x, i) => cell(x, widths[i], true)) }),
      ...rows.map(r => new TableRow({ children: r.map((x, i) => cell(x, widths[i], false)) })),
    ],
  });
}

const gap = csv(path.join(DATA, "PaperData_gap_thickness_summary.csv"));
const contact = csv(path.join(DATA, "PaperData_contact_coefficient_summary.csv"));
const keyParams = csv(path.join(DATA, "PaperData_key_parameters.csv"));
const deg = csv(path.join(RESULT, "Validation_degeneration_delta0.csv"))[0];
const energy = csv(path.join(RESULT, "Validation_energy_balance.csv"));
const nx = csv(path.join(RESULT, "Validation_Nx_independence.csv"));
const dt = csv(path.join(RESULT, "Validation_dt_independence.csv"));
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

const keyRows = keyParams.map(r => [r.Parameter, fmt(r.Value, Number(r.Value) % 1 === 0 ? 0 : 3), r.Unit]);
const gapRows = gap.map(r => [fmt(r.delta_mm, Number(r.delta_mm) % 1 === 0 ? 0 : 1), fmt(r.Eabs_kWh, 1), fmt(r.Dgap_percent, 2), fmt(r.Rint_eff_mK_W, 3), fmt(r.TintJump_mean_C, 3)]);
const contactRows = contact.map(r => [fmt(r.contact_coeff_chi, Number(r.contact_coeff_chi) % 1 === 0 ? 0 : 2), fmt(r.air_gap_fraction_phi, Number(r.air_gap_fraction_phi) % 1 === 0 ? 0 : 2), fmt(r.Eabs_kWh, 1), fmt(r.ElossVsContact_percent, 2), fmt(r.Rint_eff_mK_W, 3)]);
const cfdRows = cfdTout.map(r => {
  const e = cfdEnergy.find(x => Number(x.delta_mm) === Number(r.delta_mm));
  return [fmt(r.delta_mm, 0), fmt(r.RMSE_C, 3), fmt(r.MAE_C, 3), fmt(e.Eabs_kWh_CFD, 1), fmt(e.Eabs_kWh_MinaeiG, 1), relErr(e.Eabs_kWh_CFD, e.Eabs_kWh_MinaeiG)];
});
const sharanRows = sharan.filter(r => r.quantity === "Tout").map(r => [r.case_name.replace("Sharan_", "").replace("_", " "), fmt(r.RMSE_C, 3), fmt(r.MAE_C, 3), fmt(r.bias_C, 3), fmt(r.max_abs_C, 3)]);

const validationRows = [
  ["退化验证", "完全接触工况", "Tout RMSE、最大偏差", `RMSE = ${fmt(deg.RMSE_Tout_C, 3)} °C`],
  ["界面极限验证", "完全不接触与间隙增厚", "Rint、Dgap、|E|", `δ = 5 mm 时损失 ${fmt(gap5.Dgap_percent, 2)}%`],
  ["能量守恒", "全部间隙工况", "εQ", `最大残差 ${exp(eMax)}`],
  ["离散无关性", "Nx、Δt", "RMSE、年换热量误差", `Nx=80: ${fmt(nx80.RMSE_Tout_C, 3)} °C；Δt=6 h: ${fmt(dt6.RMSE_Tout_C, 3)} °C`],
  ["文献工况", "Sharan 两个月工况", "Tout RMSE、MAE", "RMSE 约 0.52–0.61 °C"],
  ["CFD 交叉验证", "COMSOL 年度模型", "Tout RMSE、年换热量误差", "RMSE 约 0.27–0.47 °C"],
];

const nomenclatureRows = [
  ["EAHE", "Earth-air heat exchanger，土壤-空气换热器"],
  ["TRCM", "Thermal resistance-capacity model，热阻-热容模型"],
  ["CFD", "Computational fluid dynamics，计算流体力学"],
  ["δ", "空气间隙厚度，mm 或 m"],
  ["χ", "接触系数；χ = 1 表示完全接触，χ = 0 表示完全不接触"],
  ["φ", "空气间隙覆盖率，φ = 1 - χ"],
  ["Rint", "界面等效热阻，m K W^-1"],
  ["Dgap", "空气间隙导致的年换热量损失，%"],
  ["|E|", "年绝对换热量，kWh"],
  ["RMSE", "均方根误差"],
];

const children = [
  title("考虑空气间隙与接触状态的土壤-空气换热器瞬态热阻-热容模型及验证"),
  para("[作者姓名1]，[作者姓名2]，[通讯作者]", { align: AlignmentType.CENTER }),
  para("[单位名称，城市，邮编，国家]", { align: AlignmentType.CENTER }),
  para("通讯作者：[邮箱地址]", { align: AlignmentType.CENTER, after: 220 }),

  h1("摘要"),
  para(`管土界面空气间隙会削弱土壤-空气换热器（EAHE）的径向传热能力，并导致出口温度和年换热量偏离理想接触状态。针对这一问题，本文建立了考虑空气间隙厚度与局部接触状态的瞬态热阻-热容模型，将管内对流、管壁导热、界面热阻、土壤瞬态响应和轴向空气温度演化耦合求解。模型通过完全接触、不完全接触和完全不接触三类界面状态进行物理一致性检验，并结合能量守恒、时间步长和空间段数无关性、文献工况以及 CFD 数值模型进行验证。结果表明，当空气间隙厚度由 0 mm 增加至 5 mm 时，年换热量由 ${fmt(gap0.Eabs_kWh, 1)} kWh 降低至 ${fmt(gap5.Eabs_kWh, 1)} kWh，换热能力损失达到 ${fmt(gap5.Dgap_percent, 2)}%；当 δ = 1 mm 时，接触系数 χ 从 0 增加至 1，年换热量由 ${fmt(chi0.Eabs_kWh, 1)} kWh 增加至 ${fmt(chi1.Eabs_kWh, 1)} kWh。模型在基准离散参数 Nx = 80、Δt = 6 h 下满足无关性判据，并与 CFD 年度出口温度结果保持相近趋势。研究结果表明，空气间隙厚度和接触状态是影响 EAHE 年度性能评估的重要界面参数，所建立模型可为管土脱空条件下 EAHE 性能修正和工程评估提供计算工具。`),
  para("关键词：土壤-空气换热器；空气间隙；接触系数；热阻-热容模型；瞬态传热；CFD 验证"),

  h1("Highlights（投稿时按期刊要求保留或删除）"),
  para("1. 建立了考虑管土空气间隙厚度和局部接触状态的 EAHE 瞬态热阻-热容模型。"),
  para("2. 通过完全接触、不完全接触和完全不接触三类界面状态验证了模型物理一致性。"),
  para("3. 量化了空气间隙厚度和接触系数对年换热量、界面热阻和出口温度的影响。"),
  para("4. 结合能量守恒、离散无关性、文献工况和 CFD 结果建立了模型验证链条。"),

  h1("符号说明"),
  table(["符号", "含义"], nomenclatureRows, [1800, 7200]),
  caption("表 1 主要符号和缩写"),

  h1("1 引言"),
  para("土壤-空气换热器利用浅层土壤相对稳定的热环境对通风空气进行预冷或预热，是降低建筑通风负荷和改善被动式能源利用效率的重要技术之一。EAHE 的换热性能受管长、管径、埋深、流量、土壤热物性和入口空气温度等因素影响，其中管壁与土壤之间的界面传热条件往往被简化为理想接触。"),
  para("实际工程中，管道回填、土壤沉降、施工扰动和长期运行可能导致管壁外侧产生局部空气间隙或不完全接触。由于空气导热系数远低于土壤和常用管材，较薄的空气间隙也可能显著增加界面热阻，从而降低空气与土壤之间的换热能力。如果仍按理想接触假设进行模拟，可能会高估 EAHE 的出口温度调节能力和年换热量。"),
  para("已有 EAHE 瞬态模型通常关注土壤温度波动、管内对流、轴向传热和运行参数影响，而对管土界面局部脱空或接触恢复过程的处理相对不足。CFD 模型能够解析局部流场和温度场，但年度运行计算成本较高，且结果对土壤域尺寸、入口速度、壁面耦合和初始温度场较敏感。因此，有必要在一维瞬态模型中引入可解释、可调节的界面热阻描述，用于快速评价空气间隙和接触状态对 EAHE 年度性能的影响。"),
  para("本文提出一种考虑空气间隙厚度和接触系数的 EAHE 瞬态热阻-热容模型。模型将界面传热分解为完全接触、部分接触和完全不接触三类状态，并通过年出口温度、年换热量、界面热阻和离散无关性等指标进行验证。本文的目标不是替代高分辨率 CFD 模型，而是提供一种适用于年度性能分析和工程修正的低维瞬态模型。"),

  h1("2 模型与方法"),
  h2("2.1 物理问题与基本假设"),
  para("研究对象为单根水平直管 EAHE。空气沿管道轴向流动，管壁与周围土壤之间可能存在不同厚度的空气间隙。模型沿管道轴向离散为若干控制体，每个控制体包含空气节点、管壁节点和土壤边界节点。空气温度沿轴向推进，管壁温度和土壤边界温度随时间耦合演化。"),
  para("为保证模型可复现，本文采用以下假设：管内空气沿轴向一维流动；管壁径向导热用等效热阻表示；土壤远场温度按照周期性未扰动温度边界给定；界面空气间隙仅影响径向热阻，不额外引入轴向传热；接触系数用于描述局部接触与空气间隙并联传热的面积比例。"),
  table(["参数", "数值", "单位"], keyRows, [2600, 2200, 2200]),
  caption("表 2 基准模型主要参数"),
  img(path.join(RESULT, "Fig00_model_physical_schematic.png"), 480),
  caption("图 1 EAHE 管土界面空气间隙物理示意"),

  h2("2.2 管内对流、管壁导热与界面热阻网络"),
  para("管内空气与管壁之间的换热由对流热阻表示，管壁径向导热由圆筒壁导热热阻表示。管壁外侧到土壤边界之间的界面热阻由空气间隙厚度和接触状态共同决定。当界面完全接触时，空气间隙附加热阻消失；当界面完全不接触时，管壁外侧被完整环形空气层包围；当界面不完全接触时，接触支路与空气间隙支路构成并联传热。"),
  equation("Rgap = ln[(rpo + δ)/rpo] / (2π kair)"),
  equation("χ = 1 - φ"),
  equation("1/Rδ = χ/Rcontact-branch + φ/Rgap-branch"),
  para("其中，δ 为空气间隙厚度，χ 为接触系数，φ 为空气间隙覆盖率。χ = 1 表示完全接触，χ = 0 表示完全不接触。该处理方式使模型能够在理想接触和完整空气间隙之间连续过渡。"),
  img(path.join(RESULT, "Fig00b_RC_network.png"), 480),
  caption("图 2 考虑界面空气间隙和接触状态的热阻-热容网络"),

  h2("2.3 瞬态求解流程"),
  para("模型采用时间推进方式求解空气、管壁和土壤边界温度。每个时间步内，首先根据入口温度和未扰动土壤温度更新边界条件，然后通过隐式格式求解空气与管壁温度，并利用 Picard 迭代处理土壤边界温度与历史热流之间的耦合关系。当相邻迭代热流变化小于设定阈值时，认为当前时间步收敛。"),
  img(path.join(RESULT, "Fig00c_solver_flowchart.png"), 460),
  caption("图 3 模型瞬态求解流程"),

  h1("3 模型验证与数值可靠性分析"),
  h2("3.1 退化与界面极限工况验证"),
  para("为验证界面热阻模块的物理一致性，本文设置完全接触、不完全接触和完全不接触三类界面状态。完全接触工况对应无空气间隙附加热阻状态；不完全接触工况对应接触支路与空气间隙支路并联传热；完全不接触工况对应完整环形空气间隙包覆。"),
  table(["界面状态", "参数条件", "物理含义", "验证目的"], [
    ["完全接触", "χ = 1，Rcontact = 0；或 δ = 0", "无空气间隙附加热阻", "验证模型可退化"],
    ["不完全接触", "0 < χ < 1，δ > 0", "接触和空气间隙并联传热", "验证连续过渡"],
    ["完全不接触", "χ = 0，φ = 1，δ > 0", "完整空气间隙包覆", "验证最大热阻极限"],
  ], [1300, 2400, 2600, 2200]),
  caption("表 3 三种界面状态及验证目的"),
  para(`δ = 0 mm 时，模型出口温度 RMSE 为 ${fmt(deg.RMSE_Tout_C, 3)} °C，最大绝对偏差为 ${fmt(deg.MaxAbs_Tout_C, 3)} °C，说明模型在完全接触状态下能够回到基准传热状态。随着界面由完全接触转向完全不接触，界面热阻增加、年换热量降低，模型响应符合物理规律。`),

  h2("3.2 能量守恒与离散无关性"),
  para("能量守恒用于检验空气侧换热量、土壤侧吸放热量和蓄热项之间的一致性。能量残差定义为："),
  equation("εQ = |Qair - Qsoil - Qstore| / max(|Qair|, Qref)"),
  para(`计算结果显示，各间隙工况下能量残差均保持在较低水平，最大残差约为 ${exp(eMax)}。时间和空间离散无关性采用出口温度 RMSE 小于 0.05 °C、年换热量相对误差小于 1% 作为判据。Nx = 80 时 RMSE 为 ${fmt(nx80.RMSE_Tout_C, 4)} °C、年换热量误差为 ${fmt(nx80.RelErr_Eabs_percent, 3)}%；Δt = 6 h 时 RMSE 为 ${fmt(dt6.RMSE_Tout_C, 4)} °C、年换热量误差为 ${fmt(dt6.RelErr_Eabs_percent, 3)}%，均满足无关性要求。`),
  img(path.join(RESULT, "Fig05_energy_balance_residual.png"), 450),
  caption("图 4 能量残差验证"),
  img(path.join(RESULT, "Fig13_Nx_independence.png"), 450),
  caption("图 5 空间段数无关性分析"),
  img(path.join(RESULT, "Fig14_dt_independence.png"), 450),
  caption("图 6 时间步长无关性分析"),

  h2("3.3 文献工况与 CFD 数值模型对比"),
  para("文献工况对比采用 Sharan 单根直管 EAHE 的典型运行期数据。由于可用于对比的数据集中在特定月份或典型运行期，本文将其表述为局部文献工况验证，而不写作全年实验验证。May cooling 和 January heating 工况下，出口温度 RMSE 分别为 0.516 °C 和 0.613 °C，说明模型能够较好反映文献工况下的温度响应趋势。"),
  table(["工况", "Tout RMSE/°C", "Tout MAE/°C", "Bias/°C", "最大偏差/°C"], sharanRows, [2100, 1600, 1600, 1400, 1600]),
  caption("表 4 Sharan 文献工况出口温度对比误差"),
  para("CFD 对比属于数值模型之间的交叉验证，用于检验一维模型在相同边界条件下的趋势和量级是否合理。δ = 0、1 和 5 mm 三组工况下，全年出口温度 RMSE 分别约为 0.472、0.419 和 0.266 °C；年换热量相对误差分别约为 0.03%、0.41% 和 1.71%。"),
  table(["δ/mm", "Tout RMSE/°C", "Tout MAE/°C", "CFD |E|/kWh", "MATLAB |E|/kWh", "|E|误差/%"], cfdRows, [850, 1400, 1400, 1650, 1650, 1250]),
  caption("表 5 MATLAB 模型与 CFD 年度结果对比"),
  img(path.join(CFD, "Fig_annual_Tout_error_summary.png"), 420),
  caption("图 7 MATLAB 模型与 CFD 模型出口温度误差汇总"),

  h1("4 结果与分析"),
  h2("4.1 空气间隙厚度对年换热性能的影响"),
  para(`当空气间隙厚度由 0 mm 增加至 5 mm 时，年换热量由 ${fmt(gap0.Eabs_kWh, 1)} kWh 降低至 ${fmt(gap5.Eabs_kWh, 1)} kWh，换热能力损失达到 ${fmt(gap5.Dgap_percent, 2)}%。δ = 1 mm 时，年换热量为 ${fmt(gap1.Eabs_kWh, 1)} kWh，相对于无间隙工况降低约 ${fmt(gap1.Dgap_percent, 2)}%。界面热阻和平均界面温差随间隙厚度增加而增大，说明空气间隙主要通过增加径向界面热阻削弱换热。`),
  table(["δ/mm", "|E|/kWh", "Dgap/%", "Rint/(m K W^-1)", "平均界面温差/°C"], gapRows, [950, 1550, 1250, 1900, 1900]),
  caption("表 6 空气间隙厚度对 EAHE 性能的影响"),
  img(path.join(FIG, "Fig15_factor_gap_thickness_nature.png"), 520),
  caption("图 8 空气间隙厚度对年换热量、换热损失和界面热阻的影响"),

  h2("4.2 接触系数对换热能力恢复的影响"),
  para(`在 δ = 1 mm 条件下，接触系数 χ 从 0 增加至 1 时，年换热量由 ${fmt(chi0.Eabs_kWh, 1)} kWh 增加至 ${fmt(chi1.Eabs_kWh, 1)} kWh，相对于完全接触工况的损失由 ${fmt(chi0.ElossVsContact_percent, 2)}% 降低至 0%。这说明局部接触状态能够显著恢复管土界面传热能力，若仅采用完整环形空气间隙假设，可能高估实际工程中的换热损失。`),
  table(["χ", "φ", "|E|/kWh", "相对完全接触损失/%", "Rint/(m K W^-1)"], contactRows, [850, 850, 1450, 2300, 1900]),
  caption("表 7 接触系数对 EAHE 性能的影响"),
  img(path.join(FIG, "Fig16_factor_contact_coefficient_nature.png"), 520),
  caption("图 9 接触系数对年换热量、换热损失和界面热阻的影响"),
  img(path.join(FIG, "Fig17_factor_contact_Tout_curves_nature.png"), 520),
  caption("图 10 不同接触系数下全年出口温度变化"),
  img(path.join(FIG, "Fig_factor_analysis_nature_grid.png"), 520),
  caption("图 11 空气间隙厚度和接触系数影响的综合对比"),

  h1("5 讨论"),
  para("结果表明，空气间隙对 EAHE 性能的影响并非只取决于间隙厚度，还取决于实际接触比例。完全不接触状态给出了最不利界面热阻，而部分接触状态可通过并联传热降低等效热阻。因此，在工程评估中，将界面统一简化为完整环形空气间隙可能偏保守；将其简化为理想接触则可能高估换热能力。"),
  para("MATLAB 模型与 CFD 模型之间的差异主要来自模型维度、边界条件和局部换热描述。CFD 能够解析管内速度场和局部温度场，但对入口速度、湍流参数、土壤域尺寸和初始温度场较敏感。一维模型不能替代局部流场分析，但更适合年度运行和参数扫描。两者结合可用于快速筛选参数并对关键工况进行高保真复核。"),
  para("本文仍存在若干边界。首先，接触系数作为等效参数描述局部接触比例，尚未直接由现场图像或实测界面状态反演获得。其次，土壤含水率变化、降雨入渗和长期沉降未显式耦合。最后，文献工况对比主要为局部运行期验证，完整全年实测数据仍需进一步补充。"),
  table(["验证项目", "验证对象", "评价指标", "主要结论"], validationRows, [1400, 1800, 1900, 3300]),
  caption("表 8 模型验证结论矩阵"),

  h1("6 结论"),
  para("本文建立了考虑空气间隙厚度和接触系数的 EAHE 瞬态热阻-热容模型，并通过模型退化、界面极限、能量守恒、离散无关性、文献工况和 CFD 数值模型对比进行了验证。主要结论如下："),
  para(`1. 模型在完全接触条件下能够回到基准传热状态，δ = 0 mm 时出口温度 RMSE 为 ${fmt(deg.RMSE_Tout_C, 3)} °C，说明新增界面热阻模块具有正确的退化特性。`),
  para(`2. 空气间隙厚度显著影响 EAHE 年度性能。δ 从 0 mm 增加至 5 mm 时，年换热量由 ${fmt(gap0.Eabs_kWh, 1)} kWh 降低至 ${fmt(gap5.Eabs_kWh, 1)} kWh，换热损失达到 ${fmt(gap5.Dgap_percent, 2)}%。`),
  para(`3. 接触系数能够显著修正空气间隙导致的换热衰减。在 δ = 1 mm 条件下，χ 从 0 增加至 1 时，年换热量由 ${fmt(chi0.Eabs_kWh, 1)} kWh 增加至 ${fmt(chi1.Eabs_kWh, 1)} kWh。`),
  para("4. 能量守恒和无关性分析表明，本文采用的 Nx = 80、Δt = 6 h 能够在计算效率和数值精度之间取得平衡；文献工况和 CFD 对比进一步说明模型能够给出合理的出口温度趋势和年换热量量级。"),
  para("上述结果表明，空气间隙和接触状态应作为 EAHE 性能评估中的重要界面参数。本文模型可用于管土脱空条件下的年度性能修正、工程敏感性分析和 CFD 工况筛选。"),

  h1("数据与代码可用性"),
  para("本文用于绘图和表格统计的数据已整理为 CSV 文件，位于 Paper_ready_data 文件夹。MATLAB 模型脚本、图像美化脚本和 Word 生成脚本均保存在本地项目目录中。投稿前应根据目标期刊要求确定是否公开代码、数据和 COMSOL 模型文件。"),

  h1("利益冲突声明"),
  para("作者声明不存在已知利益冲突。[投稿前请按期刊要求补充或修改。]"),

  h1("作者贡献"),
  para("[作者1]：模型建立、数值模拟、论文撰写；[作者2]：CFD 建模、数据分析；[通讯作者]：研究设计、论文审阅与修改。[投稿前请按实际贡献修改。]"),

  h1("参考文献"),
  para("[1] Minaei 等. Thermal resistance-capacity model for transient simulation of Earth-Air Heat Exchangers. 2021. [请按目标期刊格式补全卷期页码和 DOI。]"),
  para("[2] Sharan G. Earth tube heat exchanger experimental study/report. 2003. [请按原始文献补全题名、出版信息和链接。]"),
  para("[3] Deldan 等. [请补充与 EAHE 单根直管实验或模型验证相关的完整文献信息。]"),
  para("[4] 其他 EAHE 瞬态模型、土壤传热和 CFD 验证相关文献。投稿前应统一引用格式并核对 DOI。"),
  new Paragraph({ children: [new PageBreak()] }),
  h1("投稿前检查清单"),
  para("1. 按目标期刊要求调整摘要字数、图表数量、参考文献格式和单位格式。"),
  para("2. 核对所有图号、表号、正文引用和图片分辨率。"),
  para("3. 将文献占位条目替换为真实、已核对的参考文献。"),
  para("4. 若目标期刊要求 Highlights、Graphical abstract、Nomenclature 或 Supplementary material，请按格式单独导出。"),
  para("5. 若有全年实验数据，应将“文献工况局部验证”升级为“实验验证”，并补充误差指标。"),
];

const doc = new Document({
  styles: {
    default: { document: { run: { font: "SimSun", size: 24 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 30, bold: true, font: "SimHei" }, paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 26, bold: true, font: "SimHei" }, paragraph: { spacing: { before: 180, after: 120 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 24, bold: true, font: "SimHei" }, paragraph: { spacing: { before: 140, after: 90 }, outlineLevel: 2 } },
    ],
  },
  sections: [{
    properties: {
      page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } },
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [run("第 ", { size: 18 }), new TextRun({ children: [PageNumber.CURRENT], font: "SimSun", size: 18 }), run(" 页", { size: 18 })] })],
      }),
    },
    children,
  }],
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync(OUT, buffer);
  console.log(OUT);
});
