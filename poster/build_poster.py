"""Build the URS/AMP poster (36 x 48 in, portrait) in a light and a dark theme → poster/poster_{light,dark}.pptx

    poster\\.venv\\Scripts\\python.exe poster\\build_poster.py

Figures come from poster/make_figures.jl (poster/fig/*_{light,dark}.png); logos from the NMSU template PDF
(poster/extract_logos.py → poster/src/logo1.png = NMSU, logo2.png = SPHEREx) and NSF (src/logo_nsf.png, Wikimedia
Commons "NSF logo.svg"). All text lives in the TEXT block below; [CHECK] items are in the speaker notes.
"""
import os
from pptx import Presentation
from pptx.util import Inches, Pt
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

# ----------------------------------------------------------------------------------------------- TEXT
TITLE = "Teaching a Neural Network the Glow of the Solar System"
SUBTITLE = "A geometrically constrained model of zodiacal light for NASA's SPHEREx mission"
AUTHORS = "Mark A. Burch and Dr. Andrew Saydjari"
AFFIL = "Astronomy Department, New Mexico State University, Las Cruces, NM"
TAKEAWAY = ("A geometrically constrained neural network learns the zodiacal light from viewing geometry alone, "
            "reaching ~0.03% median error on months it never saw.")

BG_SPHEREX = [[("SPHEREx", True), (" is a NASA space telescope, launched in March 2025, that maps the ", False),
               ("entire sky across a range of infrared wavelengths", True), (" (0.75–5 μm). Its maps will help explain how "
               "the universe began, how galaxies formed, and where water and other ingredients for life are found.", False)]]
BG_TEXT = [[("Zodiacal light. ", True), ("The Solar System is filled with a thin cloud of dust from comets and asteroids. "
            "Sunlight scattered by this dust, plus the dust's own heat glow, adds a smooth glow across every SPHEREx image "
            "(Fig. 1). It is bright enough to be confused with the faint background light from distant galaxies, and it "
            "changes with where the telescope looks and where Earth is in its orbit, so it must be carefully modeled and removed.", False)],
           [("The Kelsall model. ", True), ("Kelsall et al. (1998) built the standard model of this dust from NASA's COBE "
            "satellite: a smooth cloud, three dust bands, a ring around the Sun and a clump trailing Earth. The software ", False),
            ("ZodiPy", True), (" computes what a telescope would see from it; we use it to simulate SPHEREx data.", False)]]
PROBLEM = [[("The problem: ", True), ("zodiacal light must be removed from every SPHEREx image, but physics models such as "
            "Kelsall's were fit to older data and leave errors behind.", False)],
           [("Research objective: ", True), ("build a ", False), ("geometrically constrained", True), (" neural network that "
            "learns the zodiacal light directly from SPHEREx data and ", False), ("outperforms the Kelsall model", True),
            (". First step (this poster): show that it can learn ZodiPy's simulated sky from geometry alone.", False)]]
METHOD_GEOM = [[("A geometrically constrained model. ", True), ("The network never sees a date or a position on a sky map. "
                "Its only inputs are 9 numbers describing the viewing geometry (Fig. 2): dot products of SPHEREx's look "
                "direction n with the directions that shape the zodiacal light, plus Earth's place in its orbit. It must learn "
                "how the brightness depends on geometry, just as the physics does, instead of memorizing when and where "
                "SPHEREx looked.", False)]]
INPUTS = [("n·S, n·E", "toward or away from the Sun (seen from SPHEREx and from Earth)"),
          ("n·z", "how far above or below the plane of the planets"),
          ("n·vS, n·vE", "ahead of or behind the orbital motion (SPHEREx, Earth)"),
          ("n·x⊕, n·y⊕", "look direction in a frame that turns with Earth (x⊕ = Sun → Earth)"),
          ("sin λ⊕, cos λ⊕", "Earth's position in its orbit: the time of year")]
METHOD_TRAIN = [[("Training and testing. ", True), ("ZodiPy simulates 423,607 SPHEREx pointings (140 days, 5 μm). Five small "
                 "networks (4 hidden layers, 64 → 16 neurons; Flux.jl in Julia) learn brightness from the 9 inputs and are "
                 "averaged, then tested on whole months and sky regions they never saw.", False)],
                [("Lesson: ", True), ("adding the time of year (sin λ⊕, cos λ⊕) cut the errors about 40–65×.", False)]]
TILES = [("0.026%", "median error on months\nwithheld from training"), ("95%", "of pointings within\n0.1% of ZodiPy"),
         ("≤0.04%", "median error for every\nchoice of withheld months")]
CAP_SKY = ("Figure 1. The whole sky at 5 μm as seen from SPHEREx (ZodiPy). The glow is brightest toward the Sun and along "
           "the plane of the planets. Grey: too close to the Sun to observe.")
CAP_GEOM = ("Figure 2. The geometry the network sees (top view, not to scale). n is where SPHEREx looks; S and E point from "
            "the Sun to SPHEREx and Earth; v is the orbital motion; λ⊕ is Earth's angle around its orbit. Jupiter and the Moon "
            "are shown for context: the final model uses only the Sun–Earth–SPHEREx geometry and the time of year.")
CAP_ACC = ("Figure 3. Neural network vs. ZodiPy. The network was trained on mission days 0–30, 60–90 and 120–140, then "
           "tested on the two 30-day blocks it never saw (days 30–60 and 90–120; 180,166 pointings). Half of the errors "
           "are below 0.026% and 95% are below 0.1%. (With a random 10% of pointings withheld instead, the median is 0.015%.)")
SKYERR_TEXT = [[("Where on the sky are the errors? ", True), ("We repeated the test six times, sliding which months were "
                "withheld, so almost every pointing was tested by networks that never saw it. Every version reached "
                "0.023–0.037% median error. The errors are largest along the plane of the planets, where the dust bands "
                "are (0.09%), and smallest toward the poles (0.016%).", False)]]
CAP_SKYERR = ("Figure 4. The network's error on pointings it never saw, across the whole sky (plane of the planets across "
              "the middle). Each pointing is drawn as a 3.5°-wide patch, about the width of SPHEREx's view. Grey: not observed "
              "in the 140 days, or only at the very start or end of the mission.")
STEPS = [("done", "Validate", "Learn ZodiPy's simulated sky from geometry alone; test on unseen months and sky regions"),
         ("now", "Refine", "Longer training; all SPHEREx wavelengths (a first 1.25–5 μm version: ~0.1% error)"),
         ("next", "Scale up", "Move training to a computing cluster"),
         ("next", "Real data", "Train on real SPHEREx images and compare with the Kelsall model")]
STEP_LABEL = {"done": "✓ DONE", "now": "IN PROGRESS", "next": "NEXT"}
NEXT_NOTE = "All results so far are preliminary and use simulated data."
ACK = ("This research is supported by a URS grant at New Mexico State University, funded by the National Science "
       "Foundation (NSF). Thank you to Dr. Andrew Saydjari for mentorship, and to the developers of ZodiPy and Flux.jl.")
REFS = [["Kelsall, T., et al. 1998, ApJ, 508, 44 (COBE/DIRBE zodiacal-light model)",
         "San, M., et al. 2022, JOSS, 7, 4602 (ZodiPy)"],
        ["Doré, O., et al. 2014, arXiv:1412.4872 (SPHEREx)",
         "Innes, M. 2018, JOSS, 3, 602 (Flux.jl)"]]
NOTES = """[CHECK with mentor]
- Problem statement: 'physics models such as Kelsall's were fit to older data and leave errors behind' -- right framing?
- Acknowledgment: exact name of the URS grant/program and the NSF award number (if one should be listed).
- Author line: middle initial / 'Dr.' style for the mentor.
- Fig. 2: Jupiter and the Moon are drawn for context; the poster's model inputs are n.S n.z n.E n.vS n.vE n.x_E n.y_E sin/cos(lambda_E) (no Jupiter, no Moon).
Numbers (poster/data_accuracy.jl, data_blocks.jl): 5-network ensemble, 64-64-32-16 gelu.
  Trained on days 0-30, 60-90, 120-140; tested on days 30-60, 90-120 (180,166 pointings, 43%): median 0.026%, p95 0.10%, 94.8% within 0.1%, RMS 0.058%.
  Random 10% withheld: median 0.015%. Last 20% of the mission (days 111-140, older season inputs): median 0.10%, p95 0.67%.
  Errors are relative to ZodiPy (the Kelsall model), not the real sky.
- Multi-wavelength (Refine step): round-15 'ep300' ensemble, 30-day blocks, 1.25-5.0 um, ~0.1% median (poster/data_spectra.jl).
- Fig. 4 / sky text (poster/data_skyerror.jl, round 16, 10152026 notebook): 30-day split slid by 0,10,...,50 days, 5 seeds each;
  interior withheld windows only (training data before and after; 364,797 pointings = 86%), each pointing averaged over the
  versions that withheld it. Per-version interior medians 0.023-0.037%. Within 2 deg of the ecliptic 0.094%, above 60 deg 0.016%.
  Map: each boresight spread over a 1.75-deg-radius disc on a 1-deg grid (the boresights lie on scan circles a few degrees
  apart; without spreading, thin pole-to-pole gaps appear). Windows at the mission's start/end (extrapolation) are excluded.
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
    P = Poster(theme); t = P.t; pad = 0.45; iw = CW - 2 * pad

    # header
    P.rect(0, 0, W, 5.6, fill=t["head"])
    P.picture(os.path.join(HERE, "src", "logo1.png"), 0.9, 0.55, h=4.5)
    P.picture(os.path.join(HERE, "src", "logo2.png"), W - 0.9 - 4.6, 0.5, h=4.6)
    P.text(6.0, 0.2, W - 12.0, 2.6, [TITLE], size=80, bold=True, color="FFFFFF", align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, spacing=0.92, after=0)
    P.text(6.0, 2.8, W - 12.0, 0.8, [SUBTITLE], size=40, color="FFD27A", align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, after=0)
    P.text(6.0, 3.65, W - 12.0, 1.75, [AUTHORS, AFFIL], size=34, color="FFFFFF", align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, after=2)

    # take-away banner
    P.rect(M, 6.0, W - 2 * M, 1.5, fill=t["banner"], shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.25)
    P.text(M + 0.6, 6.0, W - 2 * M - 1.2, 1.5, [TAKEAWAY], size=40, bold=True, color=t["bannertxt"], align=PP_ALIGN.CENTER,
           anchor=MSO_ANCHOR.MIDDLE, spacing=1.0, after=0)

    top, colbot = 7.9, 44.0

    # ================= left column
    # Background
    bg_bot = 19.45
    y = P.section(X1, top, CW, bg_bot - top, "Background")
    P.text(X1 + pad, y, iw, 2.2, BG_SPHEREX); y += 2.25
    tw = iw * 0.47; fx = X1 + pad + tw + 0.35; fw = iw - tw - 0.35
    P.text(X1 + pad, y, tw, bg_bot - y - 0.2, BG_TEXT, size=25, after=8, spacing=1.08)
    fh = P.fig("sky", fx, y + 0.2, fw)
    P.caption(fx, y + 0.2 + fh + 0.1, fw, CAP_SKY, h=1.6)

    # Problem / research objective
    pr_top, pr_bot = bg_bot + 0.45, 23.25
    P.rect(X1, pr_top, CW, pr_bot - pr_top, fill=t["problem"], line=t["problemborder"], lw=6)
    P.text(X1 + pad, pr_top + 0.25, iw, pr_bot - pr_top - 0.4, PROBLEM, size=28, after=12)

    # Methods
    me_top = pr_bot + 0.45
    y = P.section(X1, me_top, CW, colbot - me_top, "Methods")
    P.text(X1 + pad, y, iw, 2.6, METHOD_GEOM, size=27); y += 2.65
    fw = iw * 0.80; fh = P.fig("geometry", X1 + pad + (iw - fw) / 2, y, fw); y += fh
    P.caption(X1 + pad, y + 0.05, iw, CAP_GEOM, h=1.3); y += 1.45
    P.text(X1 + pad, y, iw, 0.6, [[("The 9 inputs", True)]], size=28, color=t["accent2"], after=0); y += 0.6
    for sym, meaning in INPUTS:
        P.text(X1 + pad + 0.2, y, 3.6, 0.5, [[(sym, True)]], size=24, color=t["accent2"], after=0)
        P.text(X1 + pad + 3.8, y, iw - 3.8, 0.5, [meaning], size=24, after=0)
        y += 0.47
    y += 0.25
    P.text(X1 + pad, y, iw, colbot - y - 0.15, METHOD_TRAIN, size=25, after=8, spacing=1.08)

    # ================= right column
    res_bot = 34.7
    y = P.section(X2, top, CW, res_bot - top, "Results")
    tw_ = (iw - 2 * 0.35) / 3
    for i, (num, lbl) in enumerate(TILES):
        tx = X2 + pad + i * (tw_ + 0.35)
        P.rect(tx, y, tw_, 2.9, fill=t["tile"], shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
        P.text(tx, y + 0.1, tw_, 1.45, [num], size=80, bold=True, color=t["tilenum"], align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        P.text(tx, y + 1.55, tw_, 1.25, lbl.split("\n"), size=24, color=t["text"], align=PP_ALIGN.CENTER, after=0, spacing=1.0)
    y += 2.9 + 0.35
    fh = P.fig("accuracy", X2 + pad, y, iw); y += fh
    P.caption(X2 + pad, y, iw, CAP_ACC, h=1.5); y += 1.55
    P.rect(X2 + pad, y, iw, 0.06, fill=t["border"]); y += 0.25
    P.text(X2 + pad, y, iw, 2.4, SKYERR_TEXT, size=27); y += 2.4
    im = Image.open(os.path.join(FIG, f"skyerror_{theme}.png")); ar = im.height / im.width
    fw = min(iw, (res_bot - 1.45 - y) / ar)                     # fill the space left above the caption
    fh = P.fig("skyerror", X2 + pad + (iw - fw) / 2, y, fw); y += fh
    P.caption(X2 + pad, y, iw, CAP_SKYERR, h=1.3)

    # Next Steps (vertical roadmap)
    ns_top = res_bot + 0.45
    y = P.section(X2, ns_top, CW, colbot - ns_top, "Next Steps")
    sh_, gap = 1.35, 0.32
    for i, (state, head, body) in enumerate(STEPS):
        col = t["nxt" if state == "next" else state]
        P.rect(X2 + pad, y, iw, sh_, fill=t["box"], line=col, lw=5, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.15)
        P.text(X2 + pad + 0.25, y, 4.3, sh_, [STEP_LABEL[state], head], size=24, bold=True, color=col, anchor=MSO_ANCHOR.MIDDLE,
               after=0, spacing=1.0)
        P.text(X2 + pad + 4.6, y, iw - 4.85, sh_, [body], size=25, anchor=MSO_ANCHOR.MIDDLE, after=0, spacing=1.02)
        y += sh_
        if i < len(STEPS) - 1:
            P.rect(X2 + pad + iw / 2 - 0.3, y + 0.03, 0.6, gap - 0.06, fill=t["accent"], shape=MSO_SHAPE.DOWN_ARROW)
            y += gap
    P.text(X2 + pad, y + 0.15, iw, 0.6, [NEXT_NOTE], size=23, color=t["sub"], align=PP_ALIGN.CENTER)

    # ================= bottom: Acknowledgements | References
    b_top, b_bot = colbot + 0.4, H - 0.5
    y = P.section(X1, b_top, CW, b_bot - b_top, "Acknowledgements", hh=0.85)
    lh = b_bot - y - 0.1
    P.picture(os.path.join(HERE, "src", "logo_nsf.png"), X1 + CW - pad - lh, y - 0.15, h=lh)
    P.text(X1 + pad, y - 0.2, iw - lh - 0.3, lh + 0.2, [ACK], size=22, spacing=1.05)
    y = P.section(X2, b_top, CW, b_bot - b_top, "References", hh=0.85)
    cw2 = (iw - 0.4) / 2
    for j, col in enumerate(REFS):
        P.text(X2 + pad + j * (cw2 + 0.4), y - 0.2, cw2, b_bot - y, col, size=21, spacing=1.0, after=6)

    P.s.notes_slide.notes_text_frame.text = NOTES
    out = os.path.join(HERE, f"poster_{theme}.pptx"); P.prs.save(out); print("wrote", out)

for th in ("light", "dark"):
    build(th)
