import csv
import os
import shutil
import time
import win32com.client

ROOT = r"G:\codexproject"
DATA_DIR = os.path.join(ROOT, "Origin_export_validation_data")
OUT_DIR = os.path.join(DATA_DIR, "origin_real_figures")
CSV_DIR = os.path.join(OUT_DIR, "origin_clean_csv")


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_csv(path, headers, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        for row in rows:
            writer.writerow({h: row.get(h, "") for h in headers})


def clean_number(row, key):
    return row[key]


def make_sharan_clean(src_name, out_name, quantity):
    rows = read_csv(os.path.join(DATA_DIR, src_name))
    if quantity == "T25":
        headers = ["Time (h)", "Experiment", "MATLAB Minaei-G"]
        out_rows = [
            {
                "Time (h)": clean_number(r, "time_h"),
                "Experiment": clean_number(r, "T25_exp_C"),
                "MATLAB Minaei-G": clean_number(r, "T25_MATLAB_C"),
            }
            for r in rows
        ]
    else:
        headers = ["Time (h)", "Experiment", "MATLAB Minaei-G"]
        out_rows = [
            {
                "Time (h)": clean_number(r, "time_h"),
                "Experiment": clean_number(r, "Tout_exp_C"),
                "MATLAB Minaei-G": clean_number(r, "Tout_MATLAB_C"),
            }
            for r in rows
        ]
    path = os.path.join(CSV_DIR, out_name)
    write_csv(path, headers, out_rows)
    return path


def make_annual_clean(src_name, out_name, residual=False):
    rows = read_csv(os.path.join(DATA_DIR, src_name))
    if residual:
        headers = ["Time (day)", "MATLAB - CFD"]
        out_rows = [
            {
                "Time (day)": clean_number(r, "t_day"),
                "MATLAB - CFD": clean_number(r, "Tout_MATLAB_minus_CFD_C"),
            }
            for r in rows
        ]
    else:
        headers = ["Time (day)", "Inlet", "CFD k-epsilon", "MATLAB Minaei-G"]
        out_rows = [
            {
                "Time (day)": clean_number(r, "t_day"),
                "Inlet": clean_number(r, "Tin_C"),
                "CFD k-epsilon": clean_number(r, "Tout_CFD_kepsilon_C"),
                "MATLAB Minaei-G": clean_number(r, "Tout_MATLAB_MinaeiG_C"),
            }
            for r in rows
        ]
    path = os.path.join(CSV_DIR, out_name)
    write_csv(path, headers, out_rows)
    return path


def lt_path(path):
    return path.replace("\\", "\\\\")


def run_origin_plot(app, csv_path, graph_name, ycols, xlabel, ylabel, title, xlim=None, ylim=None):
    stem = os.path.splitext(os.path.basename(csv_path))[0]
    app.Execute("newbook name:=%s option:=lsname;" % stem)
    app.Execute('impASC fname:="%s";' % lt_path(csv_path))
    if ycols == 2:
        app.Execute("range rr = 1!(1,2);")
    elif ycols == 3:
        app.Execute("range rr = 1!(1,2:3);")
    else:
        app.Execute("range rr = 1!(1,2:4);")
    app.Execute("plotxy iy:=rr plot:=200;")
    app.Execute('page.longname$ = "%s";' % title)
    app.Execute('label -xb "%s";' % xlabel)
    app.Execute('label -yl "%s";' % ylabel)
    if xlim:
        app.Execute("layer.x.from=%g; layer.x.to=%g;" % xlim)
    if ylim:
        app.Execute("layer.y.from=%g; layer.y.to=%g;" % ylim)
    png_dir = os.path.join(OUT_DIR, "png")
    pdf_dir = os.path.join(OUT_DIR, "pdf")
    tif_dir = os.path.join(OUT_DIR, "tif")
    for d in [png_dir, pdf_dir, tif_dir]:
        os.makedirs(d, exist_ok=True)
    app.Execute('expGraph type:=png path:="%s" filename:="%s" overwrite:=replace tr1:=600;' % (lt_path(png_dir), graph_name))
    app.Execute('expGraph type:=pdf path:="%s" filename:="%s" overwrite:=replace;' % (lt_path(pdf_dir), graph_name))
    app.Execute('expGraph type:=tif path:="%s" filename:="%s" overwrite:=replace tr1:=600;' % (lt_path(tif_dir), graph_name))


def main():
    if os.path.exists(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(CSV_DIR, exist_ok=True)

    files = []
    files.append(("Origin_Fig01a_Sharan_May_T25", make_sharan_clean("Origin_Sharan_May_MATLAB_vs_exp.csv", "sharan_may_t25.csv", "T25"), 3, "Time (h)", "Temperature (degC)", "Sharan May cooling, 25 m", (0, 8), (26, 32)))
    files.append(("Origin_Fig01b_Sharan_May_Tout", make_sharan_clean("Origin_Sharan_May_MATLAB_vs_exp.csv", "sharan_may_tout.csv", "Tout"), 3, "Time (h)", "Temperature (degC)", "Sharan May cooling, outlet", (0, 8), (26.4, 28.3)))
    files.append(("Origin_Fig01c_Sharan_January_T25", make_sharan_clean("Origin_Sharan_January_MATLAB_vs_exp.csv", "sharan_january_t25.csv", "T25"), 3, "Time (h)", "Temperature (degC)", "Sharan January heating, 25 m", (0, 12), (18, 25)))
    files.append(("Origin_Fig01d_Sharan_January_Tout", make_sharan_clean("Origin_Sharan_January_MATLAB_vs_exp.csv", "sharan_january_tout.csv", "Tout"), 3, "Time (h)", "Temperature (degC)", "Sharan January heating, outlet", (0, 12), (22, 24.5)))

    for delta in [0, 1, 5]:
        src = "Origin_Annual_CFD_vs_MATLAB_delta_%dmm.csv" % delta
        files.append(("Origin_Fig02_delta_%dmm_Annual_Tout" % delta, make_annual_clean(src, "annual_delta_%dmm_tout.csv" % delta), 4, "Time (day)", "Temperature (degC)", "Annual outlet temperature, delta = %d mm" % delta, (0, 365), (14, 27)))
        files.append(("Origin_Fig03_delta_%dmm_Annual_residual" % delta, make_annual_clean(src, "annual_delta_%dmm_residual.csv" % delta, True), 2, "Time (day)", "MATLAB - CFD (degC)", "Annual outlet-temperature residual, delta = %d mm" % delta, (0, 365), None))

    app = win32com.client.Dispatch("Origin.ApplicationSI")
    app.Execute("doc -mc 1;")
    app.Execute("doc -n;")
    for graph_name, csv_path, ycols, xlabel, ylabel, title, xlim, ylim in files:
        run_origin_plot(app, csv_path, graph_name, ycols, xlabel, ylabel, title, xlim, ylim)
    app.Execute('save -DIJ "%s";' % lt_path(os.path.join(OUT_DIR, "Origin_validation_figures_project.opju")))
    time.sleep(1)
    app.Exit()


if __name__ == "__main__":
    main()
