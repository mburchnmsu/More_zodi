# Pull the images used on given slides of a .pptx (any shape type, via the slide relationships).
#   poster\.venv\Scripts\python.exe poster\deck_media.py deck.pptx OUTDIR 74 75 76 ...
import sys, os
from pptx import Presentation

deck, out = sys.argv[1:3]; slides = [int(s) for s in sys.argv[3:]]
os.makedirs(out, exist_ok=True)
p = Presentation(deck)
for n in slides:
    s = p.slides[n - 1]
    for rid, rel in s.part.rels.items():
        if "image" in rel.reltype:
            blob = rel.target_part.blob; ext = rel.target_part.partname.ext
            fn = os.path.join(out, f"slide{n}_{rid}.{ext}"); open(fn, "wb").write(blob)
            print(fn, len(blob))
