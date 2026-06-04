#!/usr/bin/env python3
"""Generate the Markdown QuickLook .dmg installer background art.

The output is deterministic: running this script reproduces the committed
``dmg-background.png`` (660x400) and ``dmg-background@2x.png`` (1320x800)
that ``scripts/make-dmg.sh`` converts into a HiDPI TIFF.

The composition is defined in 660x400 logical points and rendered (with
supersampling for crisp edges) at both 1x and 2x:

  - white background
  - bold app title + a lighter instruction line at the top
  - two dashed rounded-rectangle "drop zones" centered on the icon
    positions used by create-dmg (app at x=165, Applications at x=495,
    both at y=235), so the Finder icons land neatly inside them
  - a single arrow centered vertically in the gap between the boxes

The script never draws the icons themselves -- create-dmg/Finder overlay the
real app icon and the Applications-folder alias on top of this background.

Usage:
  python3 scripts/dmg-assets/generate-background.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

# --- Canvas (logical points, matching create-dmg --window-size 660 400) ------
W, H = 660, 400

# Icon centers used by scripts/make-dmg.sh (create-dmg --icon / --app-drop-link).
APP_CX, APP_CY = 165, 235
APPS_CX, APPS_CY = 495, 235

# --- Colors (Apple-ish neutrals) ---------------------------------------------
BG = (255, 255, 255)
TITLE_COLOR = (29, 29, 31)       # near-black (#1d1d1f)
SUBTITLE_COLOR = (134, 134, 139)  # system gray (#86868b)
BOX_COLOR = (193, 193, 198)       # light separator gray (#c1c1c6)
ARROW_COLOR = (142, 142, 147)     # system gray (#8e8e93)

# --- Text --------------------------------------------------------------------
TITLE = "Markdown QuickLook"
SUBTITLE = "Drag the app to Applications to install"

TITLE_SIZE = 30
SUBTITLE_SIZE = 15
TITLE_Y = 44      # baseline-ish top anchor (center of text)
SUBTITLE_Y = 82

# --- Drop-zone boxes ---------------------------------------------------------
BOX_W, BOX_H = 172, 192
BOX_RADIUS = 18
BOX_DASH = 5.0
BOX_GAP = 4.0
BOX_LINE = 1.4

# --- Arrow -------------------------------------------------------------------
ARROW_Y = 235
ARROW_X0 = 292        # shaft start
ARROW_TIP = 368       # arrowhead tip
ARROW_HEAD_LEN = 15
ARROW_HEAD_HALF = 8
ARROW_SHAFT = 2.6

SUPERSAMPLE = 3

# Font candidates, preferring clean Helvetica-like faces. The first that loads
# wins; the committed PNGs were rendered with Liberation Sans on Linux, which is
# metric-compatible with Helvetica/Arial.
BOLD_FONTS = [
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]
REGULAR_FONTS = [
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def load_font(candidates, size):
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def rounded_rect_perimeter(x0, y0, x1, y1, r, step):
    """Return a closed polyline tracing a rounded rectangle's outline."""
    pts = []

    def arc(cx, cy, a0, a1):
        length = abs(a1 - a0) * r
        n = max(2, int(length / step))
        for i in range(n + 1):
            a = math.radians(a0 + (a1 - a0) * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))

    # top edge -> TR arc -> right edge -> BR arc -> bottom -> BL arc -> left -> TL arc
    pts.append((x0 + r, y0))
    pts.append((x1 - r, y0))
    arc(x1 - r, y0 + r, -90, 0)
    pts.append((x1, y1 - r))
    arc(x1 - r, y1 - r, 0, 90)
    pts.append((x0 + r, y1))
    arc(x0 + r, y1 - r, 90, 180)
    pts.append((x0, y0 + r))
    arc(x0 + r, y0 + r, 180, 270)
    pts.append((x0 + r, y0))
    return pts


def draw_dashed_path(draw, pts, dash, gap, width, fill):
    """Walk a polyline drawing dash/gap segments with rounded caps."""
    period = dash + gap
    cap = width / 2.0
    carry = 0.0  # distance traveled within the current period
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        if seg == 0:
            continue
        ux, uy = (x1 - x0) / seg, (y1 - y0) / seg
        d = 0.0
        while d < seg:
            phase = carry % period
            if phase < dash:
                on_len = min(dash - phase, seg - d)
                sx, sy = x0 + ux * d, y0 + uy * d
                ex, ey = x0 + ux * (d + on_len), y0 + uy * (d + on_len)
                draw.line([(sx, sy), (ex, ey)], fill=fill, width=int(round(width)))
                for px, py in ((sx, sy), (ex, ey)):
                    draw.ellipse([px - cap, py - cap, px + cap, py + cap], fill=fill)
                step = on_len
            else:
                step = min(period - phase, seg - d)
            d += step
            carry += step


def render(scale):
    s = scale * SUPERSAMPLE

    def S(v):
        return v * s

    img = Image.new("RGB", (int(W * s), int(H * s)), BG)
    draw = ImageDraw.Draw(img)

    title_font = load_font(BOLD_FONTS, int(round(TITLE_SIZE * s)))
    subtitle_font = load_font(REGULAR_FONTS, int(round(SUBTITLE_SIZE * s)))

    draw.text((S(W / 2), S(TITLE_Y)), TITLE, font=title_font,
              fill=TITLE_COLOR, anchor="mm")
    draw.text((S(W / 2), S(SUBTITLE_Y)), SUBTITLE, font=subtitle_font,
              fill=SUBTITLE_COLOR, anchor="mm")

    for cx, cy in ((APP_CX, APP_CY), (APPS_CX, APPS_CY)):
        x0, y0 = cx - BOX_W / 2, cy - BOX_H / 2
        x1, y1 = cx + BOX_W / 2, cy + BOX_H / 2
        pts = rounded_rect_perimeter(
            S(x0), S(y0), S(x1), S(y1), S(BOX_RADIUS), step=max(1.0, S(1.0)))
        draw_dashed_path(draw, pts, S(BOX_DASH), S(BOX_GAP), S(BOX_LINE), BOX_COLOR)

    # Arrow: shaft + filled triangular head, centered between the boxes.
    shaft_end = ARROW_TIP - ARROW_HEAD_LEN
    draw.line([(S(ARROW_X0), S(ARROW_Y)), (S(shaft_end), S(ARROW_Y))],
              fill=ARROW_COLOR, width=int(round(S(ARROW_SHAFT))))
    draw.polygon([
        (S(ARROW_TIP), S(ARROW_Y)),
        (S(shaft_end), S(ARROW_Y - ARROW_HEAD_HALF)),
        (S(shaft_end), S(ARROW_Y + ARROW_HEAD_HALF)),
    ], fill=ARROW_COLOR)

    return img.resize((int(W * scale), int(H * scale)), Image.LANCZOS)


def main():
    out_1x = os.path.join(HERE, "dmg-background.png")
    out_2x = os.path.join(HERE, "dmg-background@2x.png")
    render(1).save(out_1x)
    render(2).save(out_2x)
    print(f"wrote {out_1x} (660x400)")
    print(f"wrote {out_2x} (1320x800)")


if __name__ == "__main__":
    main()
