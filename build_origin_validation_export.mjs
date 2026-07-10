import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const root = "G:/codexproject";
const outDir = path.join(root, "Origin_export_validation_data");

const sharanPoints = path.join(root, "Validation_Sharan_same_parameters_MATLAB_only", "Sharan_same_parameters_MATLAB_only_points.csv");
const sharanMetrics = path.join(root, "Validation_Sharan_same_parameters_MATLAB_only", "Sharan_same_parameters_MATLAB_only_metrics.csv");
const annualPoints = path.join(root, "Validation_annual_CFD_vs_MATLAB_Tout_only", "Annual_CFD_vs_MATLAB_Tout_only_points.csv");
const annualMetrics = path.join(root, "Validation_annual_CFD_vs_MATLAB_Tout_only", "Annual_CFD_vs_MATLAB_Tout_only_metrics.csv");

function parseCsv(text) {
  const lines = text.trim().split(/\r?\n/);
  const headers = lines.shift().split(",");
  return lines.filter(Boolean).map((line) => {
    const values = line.split(",");
    const row = {};
    headers.forEach((h, i) => {
      const v = values[i] ?? "";
      const n = Number(v);
      row[h] = v !== "" && Number.isFinite(n) ? n : v;
    });
    return row;
  });
}

function toCsv(rows, headers) {
  const body = rows.map((row) => headers.map((h) => row[h] ?? "").join(","));
  return [headers.join(","), ...body].join("\n") + "\n";
}

function matrixFromRows(rows, headers) {
  return [headers, ...rows.map((row) => headers.map((h) => row[h] ?? null))];
}

function shortAnnualRows(rows, delta) {
  return rows
    .filter((r) => r.delta_mm === delta)
    .map((r) => ({
      t_day: r.t_day,
      Tin_C: r.Tin_C,
      Tout_CFD_kepsilon_C: r.Tout_CFD_kepsilon_C,
      Tout_MATLAB_MinaeiG_C: r.Tout_MATLAB_MinaeiG_C,
      Tout_MATLAB_minus_CFD_C: r.Tout_MATLAB_minus_CFD_C,
    }));
}

function shortSharanRows(rows, caseName) {
  return rows
    .filter((r) => r.case_name === caseName)
    .map((r) => ({
      time_h: r.time_h,
      Tin_exp_C: r.Tin_exp_C,
      Tsoil_C: r.Tsoil_C,
      T25_exp_C: r.T25_exp_C,
      T25_MATLAB_C: r.T25_MATLAB_C,
      Tout_exp_C: r.Tout_exp_C,
      Tout_MATLAB_C: r.Tout_MATLAB_C,
      T25_MATLAB_minus_exp_C: r.T25_MATLAB_minus_exp_C,
      Tout_MATLAB_minus_exp_C: r.Tout_MATLAB_minus_exp_C,
    }));
}

async function writeCsv(name, rows, headers) {
  await fs.writeFile(path.join(outDir, name), toCsv(rows, headers), "utf8");
}

function addSheet(workbook, name, rows, headers) {
  const ws = workbook.worksheets.add(name);
  const matrix = matrixFromRows(rows, headers);
  const range = ws.getRangeByIndexes(0, 0, matrix.length, headers.length);
  range.values = matrix;
  ws.freezePanes.freezeRows(1);
  ws.getRangeByIndexes(0, 0, 1, headers.length).format = {
    fill: "#1F4E79",
    font: { bold: true, color: "#FFFFFF" },
  };
  ws.getRangeByIndexes(0, 0, matrix.length, headers.length).format.borders = {
    preset: "all",
    style: "thin",
    color: "#D9D9D9",
  };
  ws.getRangeByIndexes(1, 0, Math.max(matrix.length - 1, 1), headers.length).format.numberFormat = "0.0000";
  range.format.autofitColumns();
}

await fs.mkdir(outDir, { recursive: true });

const sharanRows = parseCsv(await fs.readFile(sharanPoints, "utf8"));
const sharanMetricRows = parseCsv(await fs.readFile(sharanMetrics, "utf8"));
const annualRows = parseCsv(await fs.readFile(annualPoints, "utf8"));
const annualMetricRows = parseCsv(await fs.readFile(annualMetrics, "utf8"));

const sharanMay = shortSharanRows(sharanRows, "Sharan_May_cooling");
const sharanJan = shortSharanRows(sharanRows, "Sharan_January_heating");
const annual0 = shortAnnualRows(annualRows, 0);
const annual1 = shortAnnualRows(annualRows, 1);
const annual5 = shortAnnualRows(annualRows, 5);

const sharanHeaders = [
  "time_h",
  "Tin_exp_C",
  "Tsoil_C",
  "T25_exp_C",
  "T25_MATLAB_C",
  "Tout_exp_C",
  "Tout_MATLAB_C",
  "T25_MATLAB_minus_exp_C",
  "Tout_MATLAB_minus_exp_C",
];
const annualHeaders = [
  "t_day",
  "Tin_C",
  "Tout_CFD_kepsilon_C",
  "Tout_MATLAB_MinaeiG_C",
  "Tout_MATLAB_minus_CFD_C",
];

await writeCsv("Origin_Sharan_May_MATLAB_vs_exp.csv", sharanMay, sharanHeaders);
await writeCsv("Origin_Sharan_January_MATLAB_vs_exp.csv", sharanJan, sharanHeaders);
await writeCsv("Origin_Annual_CFD_vs_MATLAB_delta_0mm.csv", annual0, annualHeaders);
await writeCsv("Origin_Annual_CFD_vs_MATLAB_delta_1mm.csv", annual1, annualHeaders);
await writeCsv("Origin_Annual_CFD_vs_MATLAB_delta_5mm.csv", annual5, annualHeaders);
await writeCsv("Origin_Sharan_and_annual_metrics.csv", [
  ...sharanMetricRows.map((r) => ({ source: "Sharan_MATLAB_vs_exp", ...r })),
  ...annualMetricRows.map((r) => ({ source: "Annual_CFD_vs_MATLAB_Tout", ...r })),
], Array.from(new Set([
  "source",
  ...Object.keys(sharanMetricRows[0] ?? {}),
  ...Object.keys(annualMetricRows[0] ?? {}),
])));

const workbook = Workbook.create();
addSheet(workbook, "Sharan_May", sharanMay, sharanHeaders);
addSheet(workbook, "Sharan_January", sharanJan, sharanHeaders);
addSheet(workbook, "Annual_delta_0mm", annual0, annualHeaders);
addSheet(workbook, "Annual_delta_1mm", annual1, annualHeaders);
addSheet(workbook, "Annual_delta_5mm", annual5, annualHeaders);
addSheet(workbook, "Sharan_metrics", sharanMetricRows, Object.keys(sharanMetricRows[0] ?? {}));
addSheet(workbook, "Annual_metrics", annualMetricRows, Object.keys(annualMetricRows[0] ?? {}));

const overview = workbook.worksheets.add("README");
overview.getRange("A1:B8").values = [
  ["Purpose", "Origin plotting data for validation figures"],
  ["Part 1", "MATLAB Minaei-G with Sharan parameters vs Sharan experiment"],
  ["Part 2", "Annual COMSOL k-epsilon CFD outlet temperature vs MATLAB Minaei-G outlet temperature"],
  ["X column for Sharan sheets", "time_h"],
  ["Y columns for Sharan sheets", "T25_exp_C, T25_MATLAB_C, Tout_exp_C, Tout_MATLAB_C"],
  ["X column for annual sheets", "t_day"],
  ["Y columns for annual sheets", "Tin_C, Tout_CFD_kepsilon_C, Tout_MATLAB_MinaeiG_C"],
  ["Error columns", "Use *_minus_* columns for residual plots"],
];
overview.getRange("A1:B8").format.borders = { preset: "all", style: "thin", color: "#D9D9D9" };
overview.getRange("A1:A8").format = { fill: "#1F4E79", font: { bold: true, color: "#FFFFFF" } };
overview.getRange("A1:B8").format.autofitColumns();

const inspect = await workbook.inspect({
  kind: "sheet",
  include: "name",
  maxChars: 3000,
});
console.log(inspect.ndjson);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(path.join(outDir, "Origin_validation_data_for_plotting.xlsx"));

console.log(`Wrote Origin export data to ${outDir}`);
