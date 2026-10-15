# Dump text + low-res renders of PDFs (poster template / outline) for review.
#   poster\.venv\Scripts\python.exe poster\pdf_peek.py OUTDIR file1.pdf [file2.pdf ...]
import pymupdf, sys, os

out = sys.argv[1]
for f in sys.argv[2:]:
    d = pymupdf.open(f)
    stem = os.path.splitext(os.path.basename(f))[0]
    for i, p in enumerate(d):
        print("=====", stem, "page", i, p.rect)
        print(p.get_text())
        p.get_pixmap(dpi=40).save(os.path.join(out, f"{stem}_{i}.png"))
