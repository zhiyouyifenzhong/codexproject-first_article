import os
import time
import win32com.client

root = r"G:\codexproject"
data = os.path.join(root, "Origin_export_validation_data", "Origin_Sharan_May_MATLAB_vs_exp.csv")
out = os.path.join(root, "Origin_export_validation_data", "origin_smoke_test")
os.makedirs(out, exist_ok=True)

app = win32com.client.Dispatch("Origin.ApplicationSI")
app.Execute("doc -mc 1;")
app.Execute("newbook name:=SmokeTest option:=lsname;")
app.Execute('impASC fname:="%s";' % data.replace("\\", "\\\\"))
app.Execute("range rr = 1!(1,6:7);")
app.Execute("plotxy iy:=rr plot:=200;")
app.Execute("page.longname$ = Origin smoke test;")
app.Execute('label -xb "Time (h)";')
app.Execute('label -yl "Temperature (degC)";')
app.Execute('expGraph type:=png path:="%s" filename:="origin_smoke_test" overwrite:=replace tr1:=600;' % out.replace("\\", "\\\\"))
app.Execute('save "%s";' % os.path.join(out, "origin_smoke_test.opju").replace("\\", "\\\\"))
time.sleep(1)
app.Exit()
