from pathlib import Path

import pypdfium2 as pdfium


ROOT = Path(__file__).resolve().parent
PDF = ROOT / "Minaei_literature_data_extract" / "Minaei_2021_TRCM.pdf"
OUT = ROOT / "Minaei_literature_data_extract" / "rendered_pages"
OUT.mkdir(parents=True, exist_ok=True)


def main():
    pdf = pdfium.PdfDocument(str(PDF))
    for page_no in [5, 6]:
        page = pdf[page_no - 1]
        bitmap = page.render(scale=4.0)
        image = bitmap.to_pil()
        image.save(OUT / f"Minaei_page{page_no}_300dpi.png")
        print(OUT / f"Minaei_page{page_no}_300dpi.png", image.size)


if __name__ == "__main__":
    main()
