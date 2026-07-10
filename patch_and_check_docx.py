from pathlib import Path
import re
import shutil
import zipfile


doc = Path(r"G:\codexproject\EAHE_CFD_heat_moisture_Tang_paper.docx")
backup = Path(r"G:\codexproject\EAHE_CFD_heat_moisture_Tang_paper_before_page_patch.docx")
tmp = Path(r"G:\codexproject\tmp_docx_patch_py")

if tmp.exists():
    shutil.rmtree(tmp)
tmp.mkdir()
shutil.copy2(doc, backup)

with zipfile.ZipFile(doc, "r") as z:
    z.extractall(tmp)

xml_path = tmp / "word" / "document.xml"
xml = xml_path.read_text(encoding="utf-8")
if "<w:pgSz" not in xml:
    xml = re.sub(
        r"<w:sectPr([^>]*)>",
        r'<w:sectPr\1><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>',
        xml,
        count=1,
    )
xml_path.write_text(xml, encoding="utf-8")

doc.unlink()
with zipfile.ZipFile(doc, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for path in tmp.rglob("*"):
        if path.is_file():
            z.write(path, path.relative_to(tmp).as_posix())

shutil.rmtree(tmp)

with zipfile.ZipFile(doc, "r") as z:
    names = z.namelist()
    media = len([n for n in names if n.startswith("word/media/")])
    content = z.read("word/document.xml").decode("utf-8", errors="ignore")
    pics = len(re.findall(r"<wp:inline|<wp:anchor", content))
    math = len(re.findall(r"<m:oMath", content))

print(f"Size={doc.stat().st_size}")
print(f"MediaFiles={media}")
print(f"InlinePictures={pics}")
print(f"MathObjects={math}")
print(f"HasPassiveVapor={'被动水汽分压' in content}")
print(f"HasCondensation={'饱和约束与冷凝源项验证' in content}")
print(f"HasPgSz={'<w:pgSz' in content}")
has_raw_latex = ("T_{" in content) or ("\\frac" in content)
print(f"HasRawLatex={has_raw_latex}")
