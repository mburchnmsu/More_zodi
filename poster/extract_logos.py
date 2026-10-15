# Extract the template's logos WITH transparency (the PDF stores alpha as a separate soft mask).
#   poster\.venv\Scripts\python.exe poster\extract_logos.py template.pdf poster\src
import sys, os, pymupdf

pdf, out = sys.argv[1:3]
d = pymupdf.open(pdf)
for j, img in enumerate(d[0].get_images(full=True)):
    xref, smask = img[0], img[1]
    pix = pymupdf.Pixmap(d, xref)
    if smask:
        pix = pymupdf.Pixmap(pix, pymupdf.Pixmap(d, smask))   # attach alpha
    if pix.n - pix.alpha > 3:
        pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
    fn = os.path.join(out, f"logo{j}.png"); pix.save(fn)
    print(fn, pix.width, pix.height, "alpha" if pix.alpha else "no alpha", "smask", smask)
