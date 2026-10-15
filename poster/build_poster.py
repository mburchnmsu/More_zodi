"""Build the URS/AMP poster (36 x 48 in, portrait) in a light and a dark theme → poster/poster_{light,dark}.pptx

    poster\\.venv\\Scripts\\python.exe poster\\build_poster.py

Figures come from poster/make_figures.jl (poster/fig/*_{light,dark}.png); logos from the NMSU template PDF
(poster/extract_logos.py → poster/src/logo1.png = NMSU, logo2.png = SPHEREx). All text lives in TEXT below.
Items marked [CHECK] in the speaker notes are wording the mentor should confirm.
"""
import os
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "fig")
W, H = 36.0, 48.0                      # inches
M, GUT = 0.8, 0.8                      # outer margin, column gutter
CW = (W - 2 * M - GUT) / 2             # column width
X1, X2 = M, M + CW + GUT
FONT = "Arial"

THEMES = {
    "light": dict(page="F2F4F7", panel="FFFFFF", border="1E3557", head="1E3557", headtxt="FFFFFF", text="1B1F24",
                  sub="4A5563", accent="8C0B42", accent2="1E5AA8", banner="8C0B42", bannertxt="FFFFFF",
                  tile="EAF1FA", tilenum="1E5AA8", box="EAF1FA", boxborder="1E5AA8", done="2E7D32", now="E08A00",
                  nxt="5A6472", problem="FFF4E0", problemborder="E08A00"),
    "dark":  dict(page="0A1524", panel="0F2036", border="2D5A94", head="1E3557", headtxt="FFFFFF", text="EEF3F8",
                  sub="A9B6C6", accent="FF6F91", accent2="5FB0FF", banner="8C0B42", bannertxt="FFFFFF",
                  tile="16304F", tilenum="5FB0FF", box="16304F", boxborder="5FB0FF", done="66BB6A", now="FFB000",
                  nxt="A9B6C6", problem="2A2416", problemborder="FFB000"),
}

# ----------------------------------------------------------------------------------------------- text
TITLE = "Teaching a Neural Network the Glow of the Solar System"
SUBTITLE = "A fast zodiacal-light emulator for NASA's SPHEREx mission"
AUTHORS = "Mark A. Burch and Dr. Andrew Saydjari"
AFFIL = "Astronomy Department, New Mexico State University, Las Cruces, NM"
TAKEAWAY = ("A small neural network reproduces a physics model of the Solar System's dust glow to within 0.015%, "
            "up to ~2,000× faster per pointing, and can be extended to every wavelength SPHEREx observes.")

BG_SPHEREX = [[("SPHEREx", True), (" is a NASA space telescope, launched in March 2025, that maps the ", False),
               ("entire sky in 102 infrared colors", True), (" (0.75–5 μm) every six months. Its maps will help explain "
               "how the universe began, how galaxies formed, and where water and other ingredients for life are found.", False)]]
BG_ZODI = [[("Zodiacal light. ", True), ("The Solar System is filled with a thin cloud of dust from comets and asteroids. "
            "Sunlight scattered by this dust, plus the dust's own heat glow, is the ", False),
            ("brightest thing in almost every SPHEREx image", True), (" (Fig. 1). It changes with where the telescope looks "
            "and where Earth is in its orbit, so it must be modeled and removed before faint, distant galaxies can be studied.", False)]]
BG_KELSALL = [[("The Kelsall model. ", True), ("Kelsall et al. (1998) built the standard model of this dust from NASA's "
               "COBE satellite: a smooth cloud, three dust bands, a ring of dust around the Sun, and a clump that trails "
               "Earth. The software ", False), ("ZodiPy", True), (" adds up the glow along each line of sight to predict "
               "what a telescope sees (Fig. 2).", False)]]
PROBLEM = [[("The problem: ", True), ("computing the model means adding up dust glow along every line of sight, for "
            "millions of SPHEREx pointings, at many wavelengths, again and again as the model is compared with real data.", False)],
           [("Research objective: ", True), ("to build and test a neural-network ", False), ("“emulator”", True),
            (" that reproduces ZodiPy's zodiacal light accurately (well under 1% error) while running much faster, "
             "ready for real SPHEREx data.", False)]]
METHOD_STEPS = [("Simulate", "ZodiPy computes the zodiacal light for 423,607 SPHEREx pointings (140 days, 5 μm)"),
                ("Describe", "9 numbers per pointing: where the telescope looks relative to the Sun and Earth, plus the time of year"),
                ("Train", "A neural network (Flux.jl in Julia) learns brightness from geometry; 5 networks are averaged"),
                ("Test", "Compare with ZodiPy on pointings the network never saw: random, unseen months, unseen sky")]
METHOD_NOTES = [[("Give the network the right physics. ", True), ("Telling it where Earth is in its orbit (the “season”) "
                 "cut errors about 40–65×.", False)],
                [("Test honestly. ", True), ("Data were split by time, by sky region and at random, and many network sizes "
                 "and training schedules were compared.", False)]]
TILES = [("0.015%", "median error on\nunseen pointings"), ("~2,000×", "faster per pointing\nthan ZodiPy"),
         ("64", "wavelengths in\none network")]
CAP_ACC = ("Figure 3. The neural network vs. ZodiPy on 42,361 pointings it never saw in training. Left: every point "
           "lies on the 1:1 line. Right: half of the errors are smaller than 0.015%, and 98% are under 0.1%.")
CAP_SPEED = ("Figure 4. Time per pointing on a laptop (one CPU core, the same 20,000 pointings). One at a time, the "
             "network is ~2,000× faster; in large batches, where ZodiPy is efficient, it is ~4× faster.")
FWD_TEXT = [[("Looking forward: every SPHEREx wavelength. ", True), ("Real SPHEREx images cover many wavelengths, so "
             "wavelength becomes one more input. A first version covering 1.25–5 μm already reaches ~0.1% median error.", False)]]
CAP_SPEC = ("Figure 5. Brightness vs. wavelength for three pointings: ZodiPy (solid) and the network (dashed). Below "
            "3 μm we see scattered sunlight; above, the dust's heat. Bottom: the differences stay under 1%.")
CAP_SCHEM = "Figure 1. SPHEREx looks out through the Sun's dust cloud (top view, not to scale)."
CAP_SKY = ("Figure 2. The whole sky at 5 μm as seen from SPHEREx (ZodiPy). The glow is brightest toward the Sun "
           "and along the plane of the planets. Grey: too close to the Sun to observe.")
STEPS = [("done", "Validate", "Accuracy, speed, unseen months and sky regions, all on simulated data"),
         ("now", "Refine", "Longer training; all SPHEREx wavelengths (0.75–5 μm)"),
         ("next", "Scale up", "Move training to a computing cluster"),
         ("next", "Real data", "Apply the emulator to real SPHEREx images")]
STEP_LABEL = {"done": "✓ DONE", "now": "IN PROGRESS", "next": "NEXT"}
NEXT_NOTE = "All results so far are preliminary and use simulated data. Next, the model is fully validated and then applied to real SPHEREx data."
ACK = ("This research is supported by a URS grant at New Mexico State University. Thank you to Dr. Andrew Saydjari "
       "for mentorship, and to the developers of ZodiPy and Flux.jl.")
REFS = ["Kelsall, T., et al. 1998, ApJ, 508, 44 (COBE/DIRBE zodiacal-light model)",
        "San, M., et al. 2022, JOSS, 7, 4602 (ZodiPy)",
        "Doré, O., et al. 2014, arXiv:1412.4872 (SPHEREx)",
        "Innes, M. 2018, JOSS, 3, 602 (Flux.jl)"]
NOTES = """[CHECK with mentor]
- The problem statement: is 'compared with real data / fitting' the right reason the emulator is needed?
- Acknowledgment: exact name of the URS grant/program.
- Author line: middle initial / 'Dr.' style for the mentor.
- Speed: measured on this laptop (poster/bench_zodipy.py, poster/bench_emulator.jl): ZodiPy 21.6 ms vs network 11 us per single pointing; 32 vs 7.7 us per pointing in batches of 20,000.
- Accuracy: emulator v2 (9 inputs, 64-64-32-16, 5-network ensemble) on the random 10% held-out pointings (poster/data_accuracy.jl).
- Multi-wavelength: round-15 'ep300' ensemble, 30-day blocks, 1.25-5.0 um (poster/data_spectra.jl).
"""

# ----------------------------------------------------------------------------------------------- helpers
def rgb(h): return RGBColor.from_string(h)

class Poster:
    def __init__(self, theme):
        self.t = THEMES[theme]; self.theme = theme
        self.prs = Presentation(); self.prs.slide_width = Inches(W); self.prs.slide_height = Inches(H)
        self.s = self.prs.slides.add_slide(self.prs.slide_layouts[6])
        bg = self.s.background.fill; bg.solid(); bg.fore_color.rgb = rgb(self.t["page"])

    def rect(self, x, y, w, h, fill=None, line=None, lw=0, shape=MSO_SHAPE.RECTANGLE, radius=None):
        sh = self.s.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
        if fill: sh.fill.solid(); sh.fill.fore_color.rgb = rgb(fill)
        else: sh.fill.background()
        if line: sh.line.color.rgb = rgb(line); sh.line.width = Pt(lw)
        else: sh.line.fill.background()
        if radius is not None and shape == MSO_SHAPE.ROUNDED_RECTANGLE: sh.adjustments[0] = radius
        sh.shadow.inherit = False
        return sh

    def text(self, x, y, w, h, paras, size=28, color=None, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, bold=False,
             spacing=1.12, after=10, font=FONT):
        """paras: list of paragraphs; each a str or a list of (text, bold) runs."""
        tb = self.s.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)); tf = tb.text_frame
        tf.word_wrap = True; tf.vertical_anchor = anchor
        tf.margin_left = tf.margin_right = Inches(0.05); tf.margin_top = tf.margin_bottom = Inches(0.02)
        for i, para in enumerate(paras):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.alignment = align; p.line_spacing = spacing; p.space_after = Pt(after)
            runs = [(para, bold)] if isinstance(para, str) else para
            for txt, b in runs:
                r = p.add_run(); r.text = txt; f = r.font
                f.size = Pt(size); f.bold = b; f.name = font; f.color.rgb = rgb(color or self.t["text"])
        return tb

    def section(self, x, y, w, h, title, hh=1.15):
        self.rect(x, y, w, h, fill=self.t["panel"], line=self.t["border"], lw=3)
        self.rect(x, y, w, hh, fill=self.t["head"])
        self.text(x, y, w, hh, [title], size=50 if hh > 1 else 40, bold=True, color=self.t["headtxt"], align=PP_ALIGN.CENTER,
                  anchor=MSO_ANCHOR.MIDDLE, after=0)
        return y + hh + 0.35          # first content y

    def picture(self, path, x, y, w=None, h=None):
        im = Image.open(path); ar = im.height / im.width
        if w is None: w = h / ar
        if h is None: h = w * ar
        self.s.shapes.add_picture(path, Inches(x), Inches(y), Inches(w), Inches(h))
        return h

    def fig(self, name, x, y, w):
        return self.picture(os.path.join(FIG, f"{name}_{self.theme}.png"), x, y, w=w)

    def caption(self, x, y, w, txt, h=1.0):
        self.text(x, y, w, h, [[(txt.split(". ", 1)[0] + ". ", True), (txt.split(". ", 1)[1], False)]], size=22,
                  color=self.t["sub"], spacing=1.05)

# ----------------------------------------------------------------------------------------------- layout
def build(theme):
    P = Poster(theme); t = P.t; pad = 0.45

    # header
    P.rect(0, 0, W, 5.6, fill=t["head"])
    P.picture(os.path.join(HERE, "src", "logo1.png"), 0.9, 0.55, h=4.5)
    P.picture(os.path.join(HERE, "src", "logo2.png"), W - 0.9 - 4.6, 0.5, h=4.6)
    P.text(6.0, 0.2, W - 12.0, 2.6, [TITLE], size=80, bold=True, color="FFFFFF", align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, spacing=0.92, after=0)
    P.text(6.0, 2.8, W - 12.0, 0.8, [SUBTITLE], size=44, color="FFD27A", align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, after=0)
    P.text(6.0, 3.65, W - 12.0, 1.75, [AUTHORS, AFFIL], size=34, color="FFFFFF", align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, after=2)

    # take-away banner
    P.rect(M, 6.0, W - 2 * M, 1.75, fill=t["banner"], shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.25)
    P.text(M + 0.6, 6.0, W - 2 * M - 1.2, 1.75, [TAKEAWAY], size=40, bold=True, color=t["bannertxt"], align=PP_ALIGN.CENTER,
           anchor=MSO_ANCHOR.MIDDLE, spacing=1.0)

    top, colbot = 8.2, 39.1
    iw = CW - 2 * pad                                            # inner width

    # ---------------- left column: Background
    bg_bot = 26.6
    y = P.section(X1, top, CW, bg_bot - top, "Background")
    P.text(X1 + pad, y, iw, 2.6, BG_SPHEREX); y += 2.5
    # two rows: text left, figure right
    tw = iw * 0.45; fx = X1 + pad + tw + 0.35; fw = iw - tw - 0.35
    P.text(X1 + pad, y, tw, 6.6, BG_ZODI, size=27)
    fh = P.fig("schematic", fx, y, fw)
    P.caption(fx, y + fh + 0.05, fw, CAP_SCHEM, h=0.9)
    y += fh + 1.05
    P.text(X1 + pad, y, tw, 5.4, BG_KELSALL, size=27)
    fh = P.fig("sky", fx, y + 0.1, fw)
    P.caption(fx, y + 0.1 + fh + 0.05, fw, CAP_SKY, h=1.4)

    # ---------------- left column: The Problem
    pr_top, pr_bot = bg_bot + 0.45, 31.2
    P.rect(X1, pr_top, CW, pr_bot - pr_top, fill=t["problem"], line=t["problemborder"], lw=6)
    P.text(X1 + pad, pr_top + 0.3, iw, pr_bot - pr_top - 0.5, PROBLEM, size=29, after=14)

    # ---------------- left column: Methods
    me_top = pr_bot + 0.45
    y = P.section(X1, me_top, CW, colbot - me_top, "Methods")
    n = len(METHOD_STEPS); aw = 0.55; bw = (iw - (n - 1) * aw) / n; bh = 3.55
    for i, (head, body) in enumerate(METHOD_STEPS):
        bx = X1 + pad + i * (bw + aw)
        P.rect(bx, y, bw, bh, fill=t["box"], line=t["boxborder"], lw=3, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.08)
        P.text(bx + 0.1, y + 0.12, bw - 0.2, 0.6, [f"{i + 1}. {head}"], size=30, bold=True, color=t["accent2"], align=PP_ALIGN.CENTER)
        P.text(bx + 0.15, y + 0.8, bw - 0.3, bh - 0.9, [body], size=21, align=PP_ALIGN.CENTER, spacing=1.02)
        if i < n - 1:
            P.rect(bx + bw + 0.08, y + bh / 2 - 0.3, aw - 0.16, 0.6, fill=t["accent"], shape=MSO_SHAPE.RIGHT_ARROW)
    y += bh + 0.35
    P.text(X1 + pad, y, iw, colbot - y - 0.2, METHOD_NOTES, size=26, after=8)

    # ---------------- right column: Results
    y = P.section(X2, top, CW, colbot - top, "Results")
    tw_ = (iw - 2 * 0.35) / 3
    for i, (num, lbl) in enumerate(TILES):
        tx = X2 + pad + i * (tw_ + 0.35)
        P.rect(tx, y, tw_, 2.9, fill=t["tile"], shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
        P.text(tx, y + 0.1, tw_, 1.45, [num], size=80, bold=True, color=t["tilenum"], align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        P.text(tx, y + 1.55, tw_, 1.25, lbl.split("\n"), size=24, color=t["text"], align=PP_ALIGN.CENTER, after=0, spacing=1.0)
    y += 2.9 + 0.35
    fh = P.fig("accuracy", X2 + pad, y, iw); y += fh
    P.caption(X2 + pad, y, iw, CAP_ACC); y += 1.05
    fw = iw * 0.72; fh = P.fig("speed", X2 + pad + (iw - fw) / 2, y, fw); y += fh
    P.caption(X2 + pad, y, iw, CAP_SPEED); y += 1.1
    P.rect(X2 + pad, y, iw, 0.06, fill=t["border"]); y += 0.25
    P.text(X2 + pad, y, iw, 1.8, FWD_TEXT); y += 1.65
    fw = colbot - 1.15 - y; fw = min(iw * 0.9, fw * 1.5)              # spectra figure is 3:2; fill the space left
    fh = P.fig("spectra", X2 + pad + (iw - fw) / 2, y, fw); y += fh
    P.caption(X2 + pad, y, iw, CAP_SPEC)

    # ---------------- full width: Next Steps
    ns_top, ns_bot = colbot + 0.45, 44.3
    y = P.section(M, ns_top, W - 2 * M, ns_bot - ns_top, "Next Steps")
    n = len(STEPS); aw = 0.7; sw = (W - 2 * M - 2 * pad - (n - 1) * aw) / n; sh_ = 2.2
    for i, (state, head, body) in enumerate(STEPS):
        sx = M + pad + i * (sw + aw); col = t["nxt" if state == "next" else state]
        P.rect(sx, y, sw, sh_, fill=t["box"], line=col, lw=5, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
        P.text(sx + 0.2, y + 0.12, sw - 0.4, 0.6, [[(STEP_LABEL[state] + "   ", True), (head, True)]], size=28, color=col)
        P.text(sx + 0.2, y + 0.8, sw - 0.4, sh_ - 0.9, [body], size=24, spacing=1.02)
        if i < n - 1:
            P.rect(sx + sw + 0.1, y + sh_ / 2 - 0.35, aw - 0.2, 0.7, fill=t["accent"], shape=MSO_SHAPE.RIGHT_ARROW)
    P.text(M + pad, y + sh_ + 0.15, W - 2 * M - 2 * pad, 0.6, [NEXT_NOTE], size=23, color=t["sub"], align=PP_ALIGN.CENTER)

    # ---------------- bottom: Acknowledgements | References
    b_top, b_bot = ns_bot + 0.4, H - 0.5
    y = P.section(X1, b_top, CW, b_bot - b_top, "Acknowledgements", hh=0.85)
    P.text(X1 + pad, y - 0.2, iw, b_bot - y, [ACK], size=22, spacing=1.05)
    y = P.section(X2, b_top, CW, b_bot - b_top, "References", hh=0.85)
    P.text(X2 + pad, y - 0.25, iw, b_bot - y + 0.2, REFS, size=19, spacing=1.0, after=0)

    P.s.notes_slide.notes_text_frame.text = NOTES
    out = os.path.join(HERE, f"poster_{theme}.pptx"); P.prs.save(out); print("wrote", out)

for th in ("light", "dark"):
    build(th)
