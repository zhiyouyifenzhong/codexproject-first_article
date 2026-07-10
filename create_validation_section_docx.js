const fs = require("fs");
const path = require("path");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  HeadingLevel,
  AlignmentType,
  ImageRun,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  ShadingType,
  PageNumber,
  Footer,
} = require("C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/docx");

const ROOT = "G:/codexproject";
const RESULT_DIR = path.join(ROOT, "EAHE_airgap_physical_v18_minaei_contact_results");
const FIG_DIR = path.join(RESULT_DIR, "Nature_polished_figures");
const DATA_DIR = path.join(RESULT_DIR, "Paper_ready_data");
const OUT = path.join(ROOT, "EAHE_model_validation_section_expanded.docx");

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

function imageParagraph(file, widthPx) {
  const size = pngSize(file);
  const heightPx = Math.round(widthPx * size.height / size.width);
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 80 },
    children: [
      new ImageRun({
        type: "png",
        data: fs.readFileSync(file),
        transformation: { width: widthPx, height: heightPx },
        altText: {
          title: path.basename(file),
          description: "EAHE model validation figure",
          name: path.basename(file),
        },
      }),
    ],
  });
}

function p(text) {
  return new Paragraph({
    spacing: { before: 80, after: 80, line: 360 },
    children: [new TextRun({ text, font: "SimSun", size: 24 })],
  });
}

function caption(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 40, after: 160 },
    children: [new TextRun({ text, font: "SimSun", size: 21, italics: true })],
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
    spacing: { before: 180, after: 120 },
    children: [new TextRun({ text, font: "SimHei", size: 28, bold: true })],
  });
}

function equation(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 100, after: 100 },
    children: [new TextRun({ text, font: "Cambria Math", size: 24 })],
  });
}

function parseCsv(file) {
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

function num(x, d) {
  const v = Number(x);
  return Number.isFinite(v) ? v.toFixed(d) : String(x);
}

function tableCell(text, shaded, width) {
  const border = { style: BorderStyle.SINGLE, size: 1, color: "BFC7CD" };
  return new TableCell({
    width: { size: width, type: WidthType.DXA },
    margins: { top: 80, bottom: 80, left: 100, right: 100 },
    shading: shaded ? { fill: "EAF2F8", type: ShadingType.CLEAR } : undefined,
    borders: { top: border, bottom: border, left: border, right: border },
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: String(text), font: "SimSun", size: 20, bold: shaded })],
      }),
    ],
  });
}

function simpleTable(headers, rows, widths) {
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: headers.map((h, i) => tableCell(h, true, widths[i])) }),
      ...rows.map(r => new TableRow({ children: r.map((c, i) => tableCell(c, false, widths[i])) })),
    ],
  });
}

const gap = parseCsv(path.join(DATA_DIR, "PaperData_gap_thickness_summary.csv"));
const contact = parseCsv(path.join(DATA_DIR, "PaperData_contact_coefficient_summary.csv"));
const gap1 = gap.find(r => Number(r.delta_mm) === 1);
const gap5 = gap.find(r => Number(r.delta_mm) === 5);
const chi0 = contact.find(r => Number(r.contact_coeff_chi) === 0);
const chi1 = contact.find(r => Number(r.contact_coeff_chi) === 1);

const gapRows = gap.map(r => [
  num(r.delta_mm, Number(r.delta_mm) % 1 === 0 ? 0 : 1),
  num(r.Eabs_kWh, 1),
  num(r.Dgap_percent, 2),
  num(r.Rint_eff_mK_W, 3),
  num(r.TintJump_mean_C, 3),
]);

const contactRows = contact.map(r => [
  num(r.contact_coeff_chi, Number(r.contact_coeff_chi) % 1 === 0 ? 0 : 2),
  num(r.air_gap_fraction_phi, Number(r.air_gap_fraction_phi) % 1 === 0 ? 0 : 2),
  num(r.Eabs_kWh, 1),
  num(r.ElossVsContact_percent, 2),
  num(r.Rint_eff_mK_W, 3),
]);

const children = [
  h1("3 模型验证与参数影响分析"),
  p("为验证考虑管土空气间隙和局部接触效应的 EAHE 瞬态模型的可靠性，本文从模型退化、界面热阻极限、能量守恒、数值离散无关性、文献工况对比以及 CFD 数值模型对比等方面进行验证。在此基础上，进一步分析空气间隙厚度和接触系数对出口温度及年换热量的影响。该验证体系既用于检查模型在基本物理极限下的正确性，也用于评价其在工程参数变化下的响应合理性。"),
  p("需要说明的是，CFD 对比属于数值模型之间的交叉验证，不能等同于实验验证。文献工况验证只有在边界条件、几何参数和运行参数与文献实验一致时，才可作为实验数据验证；若文献仅提供局部时段或典型日数据，则应表述为文献工况对比验证。"),

  h2("3.1 模型退化验证"),
  p("当空气间隙厚度取 δ = 0，或管壁与土壤处于完全接触状态时，界面附加热阻消失，传热网络应退化为不含空气间隙热阻的基准模型。此时，改进模型与基准模型的出口温度、空气侧换热量和年换热量应保持一致。因此，退化验证是判断新增界面热阻模块是否正确嵌入原有瞬态求解框架的第一步。"),
  p("本文以 δ = 0 mm 作为退化验证工况，将改进模型计算结果与基准模型结果进行比较。结果表明，两者全年出口温度曲线重合，出口温度均方根误差接近零，最大绝对偏差也接近零。这说明当空气间隙不存在时，新增界面模块不会引入额外数值偏差，模型能够回到正确的基准传热状态。"),

  h2("3.2 界面热阻极限验证"),
  p("空气间隙会显著增加管壁外侧到土壤边界之间的径向热阻。按照径向导热理论，随着空气间隙厚度增大，界面等效热阻应单调增大，空气与土壤之间的换热能力应单调降低。因此，界面热阻极限验证主要考察模型是否能够给出符合物理规律的单调响应。"),
  p(`本文设置 δ = 0、0.5、1、2、3 和 5 mm 六组工况进行计算。结果显示，当间隙厚度从 0 mm 增加至 5 mm 时，年换热量由 ${num(gap[0].Eabs_kWh, 1)} kWh 降低至 ${num(gap5.Eabs_kWh, 1)} kWh，换热能力损失达到 ${num(gap5.Dgap_percent, 2)}%。当 δ = 1 mm 时，年换热量为 ${num(gap1.Eabs_kWh, 1)} kWh，相对于无间隙工况降低约 ${num(gap1.Dgap_percent, 2)}%。与此同时，界面等效热阻随间隙厚度增加而近似单调增大，表明模型对空气间隙热阻的响应符合传热学预期。`),
  simpleTable(
    ["δ/mm", "|E|/kWh", "Dgap/%", "Rint/(m K W^-1)", "平均界面温差/°C"],
    gapRows,
    [1050, 1550, 1350, 1900, 1900]
  ),
  caption("表 1 空气间隙厚度对 EAHE 年换热性能和界面热阻的影响"),
  imageParagraph(path.join(FIG_DIR, "Fig15_factor_gap_thickness_nature.png"), 520),
  caption("图 1 空气间隙厚度对年换热量、换热损失和界面热阻的影响"),

  h2("3.3 能量守恒验证"),
  p("瞬态传热模型不仅需要给出合理的出口温度，还应满足空气侧换热量、土壤侧吸放热量以及系统蓄热项之间的能量一致性。本文通过能量残差检验每个时间步内空气侧、管壁和土壤边界之间的能量平衡关系。能量残差越小，说明土壤响应叠加、管壁热容和空气侧换热之间的耦合越稳定。"),
  equation("εQ = |Qair - Qsoil - Qstore| / max(|Qair|, Qref)"),
  p("式中，Qair 为空气侧总换热量，Qsoil 为进入土壤的热量，Qstore 为管壁及近壁区域的蓄热项，Qref 为避免小热流工况下残差被放大的参考功率。计算结果表明，各间隙工况下能量残差保持在较低水平，Picard 迭代残差满足设定收敛阈值，说明模型在全年瞬态计算过程中具有较好的数值稳定性。"),

  h2("3.4 时间步长和空间段数无关性分析"),
  p("为排除时间步长和轴向空间离散对计算结果的影响，本文分别开展时间步长无关性和空间段数无关性分析。空间段数分析中，通过改变管道轴向分段数 Nx，比较不同离散尺度下的出口温度均方根误差和年换热量相对误差；时间步长分析中，通过改变 Δt，比较出口温度曲线和年换热量的收敛情况。"),
  p("随着 Nx 增大，出口温度曲线和年换热量逐渐趋于稳定；当 Nx 增加到基准取值附近后，继续加密空间网格对计算结果的影响已经较小。类似地，随着时间步长减小，出口温度和年换热量逐渐收敛。综合计算精度和计算效率，本文采用 Nx = 80、Δt = 6 h 作为基准离散参数。若后续用于论文定稿，建议保留较密集的 Nx 和 Δt 取值点，避免仅凭少量离散点判断无关性。"),

  h2("3.5 文献工况对比验证"),
  p("为进一步检验模型在实际 EAHE 工况下的适用性，可选取 Sharan 等文献报道的单根直管实验参数进行对比。对比时应尽量保持管长、管径、埋深、空气流量、入口温度、土壤初始温度和土壤热物性参数一致，并提取相同时段的出口温度进行比较。"),
  p("若文献仅提供两个月、典型日或部分运行期数据，则该部分应表述为局部运行期文献工况验证，而不应表述为全年实验验证。模型若能较好再现实测出口温度的变化趋势和幅值范围，可说明其具备一定外部适用性；若存在局部偏差，则应结合入口温度边界、土壤含水率、实际埋设环境和现场运行状态进行讨论。"),

  h2("3.6 CFD 数值模型对比验证"),
  p("为进一步检验一维瞬态模型在相同边界条件下的合理性，本文建立与 MATLAB 模型几何和运行参数一致的 CFD 湍流传热模型，并比较出口温度和年换热量。CFD 模型应采用相同的管长、管径、入口速度、入口温度、土壤初始温度和外边界条件，以保证差异主要来自模型维度和传热描述方式，而不是参数设置不一致。"),
  p("对比结果可从两个层面解释。首先，若 MATLAB 模型与 CFD 模型在出口温度季节变化趋势上保持一致，则说明一维模型能够捕捉 EAHE 的主要热响应规律。其次，若两者在绝对温度或年换热量上存在差异，应重点检查 CFD 中的入口速度、湍流强度、壁面热耦合、土壤域尺寸、初始温度场以及外边界条件。特别是当 CFD 得到的有效换热系数偏低时，不应立即归因于湍流模型错误，而应优先检查速度入口、壁面边界和土壤热容量是否设置合理。"),
  p("因此，CFD 对比在本文中应定位为数值交叉验证。其作用是判断改进模型的趋势和量级是否合理，并辅助识别参数设置或边界条件导致的偏差，而不是替代实验数据验证。"),

  h2("3.7 空气间隙厚度和接触系数影响分析"),
  p("在完成基本验证后，本文进一步分析空气间隙厚度和接触系数对 EAHE 换热性能的影响。空气间隙厚度代表管壁与土壤之间的脱空程度，接触系数 χ 则表示局部接触恢复程度。χ = 0 表示完整空气间隙状态，χ = 1 表示完全接触状态。"),
  p(`在 δ = 1 mm 条件下，接触系数 χ 从 0 增加至 1 时，年换热量由 ${num(chi0.Eabs_kWh, 1)} kWh 增加至 ${num(chi1.Eabs_kWh, 1)} kWh，相对于完全接触工况的损失由 ${num(chi0.ElossVsContact_percent, 2)}% 降低至 0%。这表明局部接触状态对空气间隙模型结果具有重要影响。如果仅按完整环形空气间隙处理，可能会高估实际工程中的换热损失。`),
  simpleTable(
    ["χ", "φ", "|E|/kWh", "相对完全接触损失/%", "Rint/(m K W^-1)"],
    contactRows,
    [900, 900, 1600, 2300, 2000]
  ),
  caption("表 2 接触系数对 EAHE 年换热性能和界面热阻的影响"),
  imageParagraph(path.join(FIG_DIR, "Fig16_factor_contact_coefficient_nature.png"), 520),
  caption("图 2 接触系数对年换热量、换热损失和界面热阻的影响"),
  imageParagraph(path.join(FIG_DIR, "Fig17_factor_contact_Tout_curves_nature.png"), 520),
  caption("图 3 不同接触系数下全年出口温度变化"),
  imageParagraph(path.join(FIG_DIR, "Fig_factor_analysis_nature_grid.png"), 520),
  caption("图 4 空气间隙厚度和接触系数对 EAHE 热性能影响的综合对比"),

  h2("3.8 本节小结"),
  p("综上，本文从退化工况、界面热阻极限、能量守恒、离散无关性、文献工况和 CFD 数值模型对比等方面建立了较完整的验证链条。结果表明，模型在无间隙条件下能够回到基准状态；在空气间隙增大时，界面热阻增大、年换热量降低，变化趋势符合物理规律；在接触系数增大时，界面热阻降低，换热能力得到恢复。"),
  p("从论文写作角度，建议将退化验证、能量守恒和离散无关性作为模型可靠性验证，将文献工况和 CFD 对比作为外部/数值对比验证，将空气间隙厚度和接触系数作为参数影响分析。这样的结构能够避免把参数敏感性分析误写为实验验证，也能更清楚地解释模型与 CFD 或文献数据之间的差异来源。"),
];

const doc = new Document({
  styles: {
    default: {
      document: { run: { font: "SimSun", size: 24 } },
    },
    paragraphStyles: [
      {
        id: "Heading1",
        name: "Heading 1",
        basedOn: "Normal",
        next: "Normal",
        quickFormat: true,
        run: { size: 32, bold: true, font: "SimHei" },
        paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 },
      },
      {
        id: "Heading2",
        name: "Heading 2",
        basedOn: "Normal",
        next: "Normal",
        quickFormat: true,
        run: { size: 28, bold: true, font: "SimHei" },
        paragraph: { spacing: { before: 180, after: 120 }, outlineLevel: 1 },
      },
    ],
  },
  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 },
        margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
      },
    },
    footers: {
      default: new Footer({
        children: [
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: "第 ", font: "SimSun", size: 18 }), new TextRun({ children: [PageNumber.CURRENT], font: "SimSun", size: 18 }), new TextRun({ text: " 页", font: "SimSun", size: 18 })],
          }),
        ],
      }),
    },
    children,
  }],
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync(OUT, buffer);
  console.log(OUT);
});
