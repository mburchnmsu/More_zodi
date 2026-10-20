"""Build the URS/AMP poster (36 x 48 in, portrait) in a light and a dark theme → poster/poster_{light,dark}.pptx

    poster\\.venv\\Scripts\\python.exe poster\\build_poster.py

Figures come from poster/make_figures.jl (poster/fig/*_{light,dark}.png); logos from the NMSU template PDF
(poster/extract_logos.py → poster/src/logo1.png = NMSU, logo2.png = SPHEREx) and NSF (src/logo_nsf.png, Wikimedia
Commons "NSF logo.svg"). All text lives in the TEXT block below; [CHECK] items are in the speaker notes.
Text is mostly bullets: H("...") = a small heading line, B([...runs]) = a bullet, a plain list of runs = a paragraph.
"""
import math, os
from lxml import etree
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "fig")
W, H_ = 36.0, 48.0                     # inches
M, GUT = 0.8, 0.8                      # outer margin, column gutter
CW = (W - 2 * M - GUT) / 2             # column width
X1, X2 = M, M + CW + GUT
FONT = "Arial"

THEMES = {
    "light": dict(page="F2F4F7", panel="FFFFFF", border="1E3557", head="1E3557", headtxt="FFFFFF", text="1B1F24",
                  sub="4A5563", accent="8C0B42", accent2="1E5AA8", banner="8C0B42", bannertxt="FFFFFF",
                  tile="EAF1FA", tilenum="1E5AA8", box="EAF1FA", boxborder="1E5AA8", done="2E7D32", now="E08A00",
                  nxt="5A6472", problem="FFF4E0", problemborder="E08A00", hl="B8460B"),
    "dark":  dict(page="0A1524", panel="0F2036", border="2D5A94", head="1E3557", headtxt="FFFFFF", text="EEF3F8",
                  sub="A9B6C6", accent="FF6F91", accent2="5FB0FF", banner="8C0B42", bannertxt="FFFFFF",
                  tile="16304F", tilenum="5FB0FF", box="16304F", boxborder="5FB0FF", done="66BB6A", now="FFB000",
                  nxt="A9B6C6", problem="2A2416", problemborder="FFB000", hl="FFC861"),
}

class H(str):
    """A small heading line inside a text block."""
class B(list):
    """A bullet: list of (text, bold) runs."""

# ----------------------------------------------------------------------------------------------- TEXT
TITLE = "Teaching a Neural Network the Glow of the Solar System"
SUBTITLE = "A geometrically constrained model of zodiacal light for NASA's SPHEREx mission"
AUTHORS = "Mark Burch and Andrew Saydjari"
AFFIL = "Astronomy Department, New Mexico State University, Las Cruces, NM"
TAKEAWAY = ("A geometrically constrained neural network learns the zodiacal light from viewing geometry alone, "
            "reaching ~0.02% median error on months it never saw.")

BG_SPHEREX = [B([("SPHEREx: ", True), ("NASA space telescope (launched March 2025) mapping the ", False),
                 ("entire sky in infrared", True), (" (0.75–5 μm)", False)]),
              B([("Science: ", True), ("how the universe began, how galaxies formed, where water and other "
                 "ingredients for life are found", False)])]
BG_TEXT = [H("Zodiacal light"),
           B([("Sunlight scattered by dust from comets and asteroids, plus the dust's heat glow (Fig. 1)", False)]),
           B([("Far brighter than the faint glow of distant galaxies SPHEREx aims to measure", False)]),
           B([("Changes with pointing and Earth's place in orbit → ", False), ("must be modeled and removed", True)]),
           H("The Kelsall model"),
           B([("Standard dust model from NASA's COBE; ", False), ("ZodiPy", True),
              (" evaluates its prediction of the zodiacal-light contribution to what SPHEREx observes", False)])]
PROBLEM_L = [H("The problem"),
             B([("Zodiacal light must be removed from every SPHEREx image, but Kelsall's model uses a finite number of "
                "analytic components that don't fully describe the spatial and spectral structure in real data", False)])]
PROBLEM_R = [H("Research objective"),
             B([("A ", False), ("geometrically constrained", True), (" neural network that learns zodiacal light from "
                "SPHEREx data and ", False), ("outperforms the Kelsall model", True),
                (". First step: ZodiPy's simulated sky", False)])]
METHOD_GEOM = [H("A geometrically constrained model"),
               B([("No dates or sky coordinates: only ", False), ("9 numbers describing the viewing geometry", True),
                  (" (Fig. 2), dot products of the pointing vector n", False)]),
               B([("It must learn how brightness depends on geometry, as the physics does, not memorize when and where "
                  "SPHEREx looked", False)])]
INPUTS = [("n·S, n·E", "toward or away from the Sun (seen from SPHEREx and from Earth)"),
          ("n·z", "how far above or below the plane of the planets"),
          ("n·vS, n·vE", "ahead of or behind the orbital motion (SPHEREx, Earth)"),
          ("n·x⊕, n·y⊕", "Earth-following frame: x⊕ = Sun → Earth, y⊕ = Earth's motion"),
          ("sin λ⊕, cos λ⊕", "Earth's position in its orbit: the time of year")]
METHOD_TRAIN = [H("Training and testing"),
                B([("423,607 simulated pointings (140 days, 5 μm); five small networks (Flux.jl), averaged", False)]),
                B([("Tested on whole months and sky regions they never saw", False)])]
CAP_SKY = ("Figure 1. The whole sky at 5 μm from SPHEREx (ZodiPy): brightest toward the Sun and along the plane of the "
           "planets. Grey: too close to the Sun to observe.")
CAP_GEOM = ("Figure 2. The geometry the network sees (top view, not to scale): n = SPHEREx's pointing vector; S, E = "
            "SPHEREx, Earth positions; v = orbital motion; λ⊕ = Earth's angle around its orbit. Jupiter and the Moon are "
            "tracked for real data: dust clouds leading and trailing Jupiter, and moonlight.")
CAP_TRAIN = ("Figure 3. Error during training: 5 networks (thin), average (thick). The error on withheld months levels off "
             "and never rises: no overfitting.")
TILES = [("0.018%", "median error on months\nwithheld from training"), ("97.5%", "of pointings within\n0.1% of ZodiPy"),
         ("≤0.03%", "median error for every\nchoice of withheld months")]
CAP_ACC = ("Figure 4. Network vs. ZodiPy on the two 30-day blocks never used in training (days 30–60, 90–120; 180,166 "
           "pointings). Left: error through the mission; right: every pointing falls on the 1:1 line.")
CAP_SHIFT = ("Figure 5. Six versions of the test, sliding the withheld months 10 days at a time: all reach 0.015–0.03% "
             "(red). Predicting past the start/end of the data (orange) is harder: fine for ~10 days, then errors grow.")
RES_SKY = [B([("Largest errors ", True), ("along the plane of the planets, where the dust bands are; ", False),
              ("smallest ", True), ("toward the poles (Fig. 6)", False)]),
           B([("More data: ", True), ("with all 500 days the whole sky is tested and the plane-of-the-planets error drops "
              "(0.083% → 0.063%)", False)])]
SUFFIX = os.environ.get("POSTER_SUFFIX", "")
CAP_SKYERR = ("Figure 6. Error on pointings the network never saw, across the sky (3.5° patches, about SPHEREx's view). "
              "Left: the first 140 days. Right: all 500 days now available (that model also uses Jupiter's direction, n·J). "
              "Grey: not tested.")
STEPS = [("done", "Validate", "Learn ZodiPy's simulated sky from geometry alone"),
         ("now", "Refine", "More data (500 days), longer training, Jupiter's direction"),
         ("next", "Scale up", "Move training to a computing cluster"),
         ("next", "Real data", "Train on real SPHEREx images; compare with Kelsall")]
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
- Fig. 3: Jupiter and the Moon are drawn for context; the poster's model inputs are n.S n.z n.E n.vS n.vE n.x_E n.y_E sin/cos(lambda_E) (no Jupiter, no Moon).
Numbers (poster v6): 5-network ensemble, 64-64-32-16 gelu (4 hidden layers), 750 epochs (round 21, z115_m750_shift*).
- Fig. 2 (poster/data_components.jl): ZodiPy components per pointing as % of the total. Smooth cloud 90.1% (|b|<5) to
  94.8% (>60 deg); behind Earth (n.vE<-0.5, |b|<15) the trailing cloud is 7.0% vs 1.1% ahead.
- Fig. 4 (poster/data_accuracy.jl): trained on days 0-30, 60-90, 120-140; tested on days 30-60, 90-120 (180,166 pointings,
  43%): median 0.018%, p95 0.069%, 97.5% within 0.1%. (100 epochs: 0.026%, 0.10%, 94.8%.)
  Errors are relative to ZodiPy (the Kelsall model), not the real sky.
- Fig. 5 (poster/data_training.jl): epoch-averaged MSE (mean of 10 in-epoch evaluations) on the training data and the
  withheld months; final mean train/test MSE 2.5e-8 / 1.2e-7 (MJy/sr)^2.
- Fig. 6: the 30-day split slid by 0, 10, ..., 50 days, 5 seeds each, 750 epochs. Red = withheld windows with training
  data before and after (interpolation): 0.015-0.030%. Orange = windows at the mission's start/end (extrapolation in
  time): 10 days 0.016-0.023%, 20-30 days 0.07-0.09% median.
- Fig. 7 (poster/data_skyerror.jl): red (interior) windows only, 364,797 pointings (86%), each averaged over the versions
  that withheld it: median 0.016%, p95 0.063%; within 2 deg of the ecliptic 0.083%, above 60 deg 0.0125%. Map: each
  boresight spread over a disc on a 1-deg grid (radius 1.75 deg = 3.5-deg patches, or 3.5 deg = the 7-deg blend);
  boresights lie on scan circles a few degrees apart, so without spreading thin pole-to-pole gaps appear.
- Earth-trailing cloud (mentor's test, 10182026 notebook): stacking residuals along the ahead/behind-Earth angle and the
  angle to the cloud's centre shows no leftover cloud signal; fitted missing fraction 0.06 +/- 0.09% (|b|<15, 750 ep).
- Multi-wavelength (Refine step): round-15 'ep300' ensemble, 30-day blocks, 1.25-5.0 um, ~0.1% median (poster/data_spectra.jl).
"""

# ----------------------------------------------------------------------------------------------- helpers
def rgb(h): return RGBColor.from_string(h)
BODY, CAP = 30, 26                     # body text and caption sizes (pt); were ~25 and 22 before Oct 20 (mentor: larger)
BUL_IN = 0.42                          # bullet hanging indent (in)

def _runs(para):
    return [(para, False)] if isinstance(para, str) else list(para)

def est_height(paras, w, size, spacing=1.1, after=8):
    """Rough height (in) of a text block: Arial ≈ 0.47 em per character."""
    h = 0.0
    for para in paras:
        n = sum(len(t) for t, _ in _runs(para))
        ww = w - 0.1 - (BUL_IN if isinstance(para, B) else 0)
        s = size + (2 if isinstance(para, H) else 0)
        lines = max(1, math.ceil(n * 0.47 * s / 72 / ww))
        h += lines * s * spacing * 1.2 / 72 + after / 72 + (6 / 72 if isinstance(para, H) else 0)
    return h + 0.05

class Poster:
    def __init__(self, theme):
        self.t = THEMES[theme]; self.theme = theme
        self.prs = Presentation(); self.prs.slide_width = Inches(W); self.prs.slide_height = Inches(H_)
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
        """paras: list of paragraphs; each a str, a list of (text, bold) runs, an H heading or a B bullet."""
        tb = self.s.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)); tf = tb.text_frame
        tf.word_wrap = True; tf.vertical_anchor = anchor
        tf.margin_left = tf.margin_right = Inches(0.05); tf.margin_top = tf.margin_bottom = Inches(0.02)
        for i, para in enumerate(paras):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.alignment = align; p.line_spacing = spacing; p.space_after = Pt(after)
            if isinstance(para, H):
                p.space_before = Pt(6 if i else 0)
                runs, sz, col = [(str(para), True)], size + 2, self.t["accent2"]
            else:
                runs, sz, col = (_runs(para) if not isinstance(para, str) else [(para, bold)]), size, color or self.t["text"]
            if isinstance(para, B):
                pPr = p._p.get_or_add_pPr()
                pPr.set("marL", str(Inches(BUL_IN))); pPr.set("indent", str(-Inches(BUL_IN)))
                clr = etree.SubElement(pPr, qn("a:buClr")); etree.SubElement(clr, qn("a:srgbClr")).set("val", self.t["accent"])
                etree.SubElement(pPr, qn("a:buFont")).set("typeface", FONT)
                etree.SubElement(pPr, qn("a:buChar")).set("char", "•")
            for txt, b in runs:
                r = p.add_run(); r.text = txt; f = r.font
                # key phrases (bold runs inside bullets) are highlighted in colour, as in the mentor's example posters
                f.size = Pt(sz); f.bold = b; f.name = font
                f.color.rgb = rgb(self.t["hl"] if (b and isinstance(para, B)) else col)
        return tb

    def block(self, x, y, w, paras, size=BODY, spacing=1.08, after=6):
        """Text block sized by est_height; returns its height."""
        h = est_height(paras, w, size, spacing, after)
        self.text(x, y, w, h, paras, size=size, spacing=spacing, after=after)
        return h

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

    def figpath(self, name): return os.path.join(FIG, f"{name}_{self.theme}.png")
    def aspect(self, name):
        im = Image.open(self.figpath(name)); return im.height / im.width
    def fig(self, name, x, y, w):
        return self.picture(self.figpath(name), x, y, w=w)

    def caption(self, x, y, w, txt):
        paras = [[(txt.split(". ", 1)[0] + ". ", True), (txt.split(". ", 1)[1], False)]]
        h = est_height(paras, w, CAP, 1.05, 0)
        self.text(x, y, w, h, paras, size=CAP, color=self.t["sub"], spacing=1.05, after=0)
        return h

    def flow(self, x, y0, y1, w, items):
        """Stack items vertically between y0 and y1. Items: ("text", paras[, size]) | ("fig", name, max_frac, caption)
        | ("gap", inches) | ("custom", height, draw(x, y)). Figures shrink together to fit; leftover space is spread
        evenly between items."""
        fixed, figs = 0.0, 0.0
        for it in items:
            if it[0] == "text": fixed += est_height(it[1], w, it[2] if len(it) > 2 else BODY, 1.08, 6)
            elif it[0] == "fig":
                fixed += est_height([[(it[3], False)]], w, CAP, 1.05, 0) + 0.1; figs += self.aspect(it[1]) * w * it[2]
            elif it[0] == "gap": fixed += it[1]
            elif it[0] == "custom": fixed += it[1]
        scale = min(1.0, (y1 - y0 - fixed - 0.15 * len(items)) / figs) if figs else 1.0
        used = fixed + figs * scale
        pad = max(0.0, (y1 - y0 - used) / (len(items) + 1))
        y = y0 + min(pad, 0.4)
        pad = (y1 - y0 - used - min(pad, 0.4)) / len(items)
        for it in items:
            if it[0] == "text": y += self.block(x, y, w, it[1], size=it[2] if len(it) > 2 else BODY)
            elif it[0] == "fig":
                fw = w * it[2] * scale; y += self.fig(it[1], x + (w - fw) / 2, y, fw) + 0.1
                y += self.caption(x, y, w, it[3])
            elif it[0] == "gap": y += it[1]
            elif it[0] == "custom": it[2](x, y); y += it[1]
            y += pad
        if scale < 0.999: print(f"  flow at y={y0:.1f}: figures scaled to {scale:.2f}")
        return y

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
    # Background: SPHEREx bullets across, then zodiacal light / Kelsall bullets beside Fig. 1
    y0 = top + 1.15 + 0.35
    y = y0 + est_height(BG_SPHEREX, iw, BODY, 1.08, 6) + 0.1
    tw = iw * 0.50; fx = X1 + pad + tw + 0.3; fw = iw - tw - 0.3
    fh = fw * P.aspect("sky")
    bg_h = max(est_height(BG_TEXT, tw, BODY - 2, 1.08, 6) * 1.06,
               0.3 + fh + 0.1 + est_height([[(CAP_SKY, False)]], fw, CAP, 1.05, 0))
    bg_bot = y + bg_h + 0.3
    P.section(X1, top, CW, bg_bot - top, "Background")
    P.block(X1 + pad, y0, iw, BG_SPHEREX, size=BODY)
    P.block(X1 + pad, y, tw, BG_TEXT, size=BODY - 2)
    P.fig("sky", fx, y + 0.3, fw)
    P.caption(fx, y + 0.3 + fh + 0.1, fw, CAP_SKY)

    # Problem / research objective: two halves of one box
    pr_top = bg_bot + 0.45
    hw = (iw - 0.5) / 2
    ph = max(est_height(PROBLEM_L, hw, BODY - 2, 1.08, 6), est_height(PROBLEM_R, hw, BODY - 2, 1.08, 6)) * 1.06 + 0.5
    pr_bot = pr_top + ph
    P.rect(X1, pr_top, CW, ph, fill=t["problem"], line=t["problemborder"], lw=6)
    P.block(X1 + pad, pr_top + 0.22, hw, PROBLEM_L, size=BODY - 2)
    P.block(X1 + pad + hw + 0.5, pr_top + 0.22, hw, PROBLEM_R, size=BODY - 2)

    # Methods
    me_top = pr_bot + 0.45
    y = P.section(X1, me_top, CW, colbot - me_top, "Methods")
    ROW = 0.56
    def inputs(x, y):
        P.text(x, y, iw, 0.65, [[("The 9 inputs", True)]], size=BODY + 2, color=t["accent2"], after=0); y += 0.68
        for sym, meaning in INPUTS:
            P.text(x + 0.2, y, 4.0, ROW, [[(sym, True)]], size=BODY - 2, color=t["accent2"], after=0)
            P.text(x + 4.2, y, iw - 4.2, ROW, [meaning], size=BODY - 4, after=0)
            y += ROW
    def beside(paras, name, frac, cap):
        """Bullets on the left, a figure (frac of the width) on the right, caption below both → (height, draw)."""
        fw_ = iw * frac; fh_ = fw_ * P.aspect(name); bw_ = iw - fw_ - 0.3
        bh = est_height(paras, bw_, BODY - 2, 1.08, 6)
        def draw(x, y):
            P.text(x, y + max(0.0, (fh_ - bh) / 2), bw_, bh, paras, size=BODY - 2, spacing=1.08, after=6)
            P.fig(name, x + bw_ + 0.3, y, fw_)
            P.caption(x, y + max(fh_, bh) + 0.1, iw, cap)
        return max(fh_, bh) + 0.1 + est_height([[(cap, False)]], iw, CAP, 1.05, 0), draw
    inputs_h = 0.68 + ROW * len(INPUTS)
    avail = (colbot - 0.2) - (y - 0.2) - 0.3 * 4                       # leave ~0.3 in between items
    for s in [1 - 0.02 * k for k in range(30)]:                        # shrink both figures together until it fits
        geom_h, geom = beside(METHOD_GEOM, "geometry", 0.56 * s, CAP_GEOM)
        train_h, train = beside(METHOD_TRAIN, "training", 0.50 * s, CAP_TRAIN)
        if geom_h + inputs_h + train_h <= avail: break
    if s < 0.999: print(f"  methods figures scaled to {s:.2f}")
    P.flow(X1 + pad, y - 0.2, colbot - 0.2, iw,
           [("custom", geom_h, geom), ("custom", inputs_h, inputs), ("custom", train_h, train)])

    # ================= right column
    res_bot = 38.4
    y = P.section(X2, top, CW, res_bot - top, "Results")
    tw_ = (iw - 2 * 0.35) / 3
    for i, (num, lbl) in enumerate(TILES):
        tx = X2 + pad + i * (tw_ + 0.35)
        P.rect(tx, y, tw_, 2.7, fill=t["tile"], shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
        P.text(tx, y + 0.08, tw_, 1.4, [num], size=76, bold=True, color=t["tilenum"], align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        P.text(tx, y + 1.45, tw_, 1.2, lbl.split("\n"), size=BODY - 4, color=t["text"], align=PP_ALIGN.CENTER, after=0, spacing=1.0)
    y += 2.7
    P.flow(X2 + pad, y, res_bot - 0.15, iw,
           [("fig", "accuracy2", 0.9, CAP_ACC), ("fig", "shifts", 0.85, CAP_SHIFT),
            ("text", RES_SKY), ("fig", "skyerror_pair", 1.0, CAP_SKYERR)])

    # Next Steps: compact 2 × 2 roadmap (reading order: left → right, top → bottom; arrows between)
    ns_top = res_bot + 0.45
    y = P.section(X2, ns_top, CW, colbot - ns_top, "Next Steps", hh=1.0)
    gapx = 0.6; bw = (iw - gapx) / 2; bh = (colbot - 0.75 - y - 0.25) / 2
    for i, (state, head, body) in enumerate(STEPS):
        col = t["nxt" if state == "next" else state]
        r, c = divmod(i, 2); bx = X2 + pad + c * (bw + gapx); by = y + r * (bh + 0.25)
        P.rect(bx, by, bw, bh, fill=t["box"], line=col, lw=5, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.12)
        P.text(bx + 0.2, by + 0.08, bw - 0.4, bh - 0.16, [[(f"{STEP_LABEL[state]}: {head}", True)], body], size=BODY - 8,
               color=t["text"], anchor=MSO_ANCHOR.MIDDLE, after=2, spacing=1.0)
        if c == 0:
            P.rect(bx + bw + 0.1, by + bh / 2 - 0.2, gapx - 0.2, 0.4, fill=t["accent"], shape=MSO_SHAPE.RIGHT_ARROW)
    P.text(X2 + pad, colbot - 0.6, iw, 0.45, [NEXT_NOTE], size=BODY - 8, color=t["sub"], align=PP_ALIGN.CENTER, after=0)

    # ================= bottom: Acknowledgements | References
    b_top, b_bot = colbot + 0.4, H_ - 0.5
    y = P.section(X1, b_top, CW, b_bot - b_top, "Acknowledgements", hh=0.85)
    lh = b_bot - y - 0.1
    P.picture(os.path.join(HERE, "src", "logo_nsf.png"), X1 + CW - pad - lh, y - 0.15, h=lh)
    P.text(X1 + pad, y - 0.2, iw - lh - 0.3, lh + 0.2, [ACK], size=BODY - 6, spacing=1.05)
    y = P.section(X2, b_top, CW, b_bot - b_top, "References", hh=0.85)
    cw2 = (iw - 0.4) / 2
    for j, col in enumerate(REFS):
        P.text(X2 + pad + j * (cw2 + 0.4), y - 0.2, cw2, b_bot - y, col, size=BODY - 7, spacing=1.0, after=6)

    P.s.notes_slide.notes_text_frame.text = NOTES
    out = os.path.join(HERE, f"poster_{theme}{SUFFIX}.pptx"); P.prs.save(out); print("wrote", out)

for th in ("light", "dark"):
    build(th)
