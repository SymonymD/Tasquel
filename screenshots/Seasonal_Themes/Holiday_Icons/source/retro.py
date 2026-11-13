"""Retro's holiday marks: pixel versions of every holiday's (the app uses Holiday Season and New Year),
drawn around Retro's mark (the t in brackets, 500 x 443.31) in one color, like everything in
Retro. The app tints `front` in Retro's bright color; shades come from opacity. Nothing
crosses the t (in one color it blurs into it); a `knockout`, tinted the background color
under the front, is written only for a design that does. Layers are in the mark's space
with 170 more on every side, like the others.

Usage: python3 retro.py <Holiday_Icons dir> <render binary>
Writes <holiday>/<holiday>-retro-front.svg, -retro-knockout.svg (only where something crosses
the mark) and -retro-mark-<color>.png.
"""
import re
import subprocess
import sys
from pathlib import Path

MARK_W, MARK_H, MARGIN = 500.0, 443.31, 170.0
VIEWBOX = f"{-MARGIN} {-MARGIN} {MARK_W + 2 * MARGIN} {MARK_H + 2 * MARGIN}"
P = 14.0          # one pixel
GAP = 0.3 * P     # the knockout's margin round each bulb pixel
RING_TO_RETRO = (MARK_W - 408.04) / 2  # the ring mark's drawings, centered on Retro's


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}">{body}</svg>'


def on_mark(c, r):
    """Whether a cell touches the mark (the brackets and t, with a pixel's room)."""
    return -P < c * P < MARK_W and 30 - 2 * P < r * P < 413 + P


class Pixels:
    """Cells on the P grid, each with an opacity; the knockout covers the ones that cut."""

    def __init__(self):
        self.cells = {}      # (col, row) -> opacity
        self.cuts = set()    # cells the knockout goes round

    def put(self, col, row, opacity=1.0, cuts=True):
        key = (col, row)
        if opacity > self.cells.get(key, 0):
            self.cells[key] = opacity
        if cuts:
            self.cuts.add(key)

    def front(self):
        rects = []
        for (c, r), o in sorted(self.cells.items()):
            rects.append(f'<rect x="{c * P:.1f}" y="{r * P:.1f}" width="{P}" height="{P}" opacity="{o:.2f}"/>')
        return svg("".join(rects))

    def knockout(self):
        if not self.cuts:
            return None
        rects = []
        for c, r in sorted(self.cuts):
            rects.append(f'<rect x="{c * P - GAP:.1f}" y="{r * P - GAP:.1f}" width="{P + 2 * GAP}" height="{P + 2 * GAP}"/>')
        return svg("".join(rects))


def cell(x, y):
    return int(x // P), int(y // P)


def sparkle(px, x, y, arm=1, opacity=0.75):
    """A pixel twinkle: a plus with arms `arm` cells long."""
    c, r = cell(x, y)
    px.put(c, r, opacity, cuts=False)
    for d in range(1, arm + 1):
        for dc, dr in ((d, 0), (-d, 0), (0, d), (0, -d)):
            px.put(c + dc, r + dr, opacity * (0.75 if d > 1 else 1), cuts=False)


def holiday_season():
    """A string of lights hung from the brackets' bottom corners, under the [t]: in one color,
    lights across the t (as on the ring) blur into it."""
    px = Pixels()
    a, ctrl, b = (20.0, 420.0), (250.0, 560.0), (480.0, 420.0)
    wire = {}
    steps = 600
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * ctrl[0] + t * t * b[0]
        y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * ctrl[1] + t * t * b[1]
        c, r = cell(x, y)
        wire.setdefault(c, r)
        px.put(c, r, 0.6, cuts=False)
    # Bulbs: socket, a 3-wide body two rows tall, a 1-wide tip. Lit ones glow.
    shades = [1.0, 0.55, 1.0, 0.55, 1.0, 0.55]
    cols = sorted(wire)
    picks = [cols[int(len(cols) * f)] for f in (0.1, 0.25, 0.4, 0.56, 0.72, 0.87)]
    for col, shade in zip(picks, shades):
        top = wire[col] + 1
        px.put(col, top, 0.6, cuts=False)          # socket
        body = [(col - 1, top + 1), (col, top + 1), (col + 1, top + 1),
                (col - 1, top + 2), (col, top + 2), (col + 1, top + 2), (col, top + 3)]
        for c, r in body:
            px.put(c, r, shade, cuts=False)
        if shade == 1.0:
            for c, r in body:
                for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (c + dc, r + dr) not in body and (c + dc, r + dr) != (col, top):
                        px.put(c + dc, r + dr, 0.25, cuts=False)
    sparkle(px, -55, -30)
    sparkle(px, 560, -10)
    sparkle(px, 250, -70, opacity=0.6)
    return px


def new_year(icons):
    """The ring's confetti as pixels: dots one cell, strips two, shades by their colors."""
    px = Pixels()
    shade = {"#F4C24C": 1.0, "#E3ECF7": 0.85, "#B7A4FF": 0.7, "#FF7BA0": 0.6, "#4FD1E8": 0.45}
    behind = (icons / "new-year" / "new-year-layer-behind.svg").read_text()
    for cx, cy, fill in re.findall(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="[\d.]+" fill="(#\w+)"', behind):
        c, r = cell(float(cx) + RING_TO_RETRO, float(cy))
        if not on_mark(c, r):
            px.put(c, r, shade.get(fill, 0.7), cuts=False)
    for x, y, w, h, fill, angle in re.findall(
            r'<rect x="([-\d.]+)" y="([-\d.]+)" width="([\d.]+)" height="([\d.]+)" rx="[\d.]+" fill="(#\w+)" transform="rotate\(([-\d.]+)', behind):
        mx = float(x) + float(w) / 2 + RING_TO_RETRO
        my = float(y) + float(h) / 2
        c, r = cell(mx, my)
        o = shade.get(fill, 0.7)
        other = (c, r + 1) if abs(float(angle)) < 45 else (c + 1, r)  # standing or lying strip
        if not on_mark(c, r) and not on_mark(*other):
            px.put(c, r, o, cuts=False)
            px.put(*other, o, cuts=False)
    # The ring's three stars become twinkles, moved off the brackets' corners.
    sparkle(px, 70 + RING_TO_RETRO, -40, arm=2, opacity=1.0)
    sparkle(px, 372 + RING_TO_RETRO + 60, -30, arm=1, opacity=0.9)
    sparkle(px, -45, 430, arm=1, opacity=0.9)
    return px



# --- The other holidays: drawn clear of the mark (a half-pixel gap round the brackets and
# the t's box), so where they'd pass behind it they stop short, as a "behind" reads in one color.

MARK_RECTS = [
    (12, 30, 48, 413), (12, 30, 96, 66), (12, 377, 96, 413),        # [
    (452, 30, 488, 413), (404, 30, 488, 66), (404, 377, 488, 413),  # ]
    (121, 57, 393, 386),                                            # the t's box
]


MARK_BOX = [(12, 30, 488, 413)]  # for what goes behind: nothing shows between the brackets


def hits_mark(c, r, rects=MARK_RECTS, gap=0.5 * P):
    x0, y0 = c * P, r * P
    return any(x0 < x1 + gap and x0 + P > xa - gap and y0 < y1 + gap and y0 + P > ya - gap
               for xa, ya, x1, y1 in rects)


def put_clear(px, c, r, opacity, rects=MARK_RECTS):
    if not hits_mark(c, r, rects):
        px.put(c, r, opacity, cuts=False)


def cells_in(test, x0, y0, x1, y1):
    """The cells whose centers pass `test(x, y)`, in a box."""
    for r in range(int(y0 // P) - 1, int(y1 // P) + 2):
        for c in range(int(x0 // P) - 1, int(x1 // P) + 2):
            if test(c * P + P / 2, r * P + P / 2):
                yield c, r


def curve(px, points, opacity, steps=400, rects=MARK_RECTS):
    """A pixel line through a quadratic Bezier (a, control, b)."""
    a, ctrl, b = points
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * ctrl[0] + t * t * b[0]
        y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * ctrl[1] + t * t * b[1]
        put_clear(px, *cell(x, y), opacity, rects)


def thanksgiving():
    """A turkey's tail: pixel feathers fanned out behind the [t], banded tips, a quill down each."""
    import math
    px = Pixels()
    cx, cy, reach, half_len, half_w = 250.0, 250.0, 300.0, 95.0, 36.0
    for k, deg in enumerate((168, 143, 118, 90, 62, 37, 12)):
        th = math.radians(deg)
        ux, uy = math.cos(th), -math.sin(th)          # along the feather, outward
        fx, fy = cx + reach * ux, cy + reach * uy
        def inside(x, y):
            along = (x - fx) * ux + (y - fy) * uy
            across = -(x - fx) * uy + (y - fy) * ux
            return (along / half_len) ** 2 + (across / half_w) ** 2 <= 1
        for c, r in cells_in(inside, fx - half_len, fy - half_len, fx + half_len, fy + half_len):
            x, y = c * P + P / 2, r * P + P / 2
            along = (x - fx) * ux + (y - fy) * uy
            across = -(x - fx) * uy + (y - fy) * ux
            if along > half_len * 0.35:
                o = 1.0 if k % 2 == 0 else 0.8           # the banded tip
            elif abs(across) < P * 0.55:
                o = 0.25                                  # the quill
            else:
                o = 0.6 if k % 2 == 0 else 0.45
            put_clear(px, c, r, o, MARK_BOX)
    return px


BIG_GHOST = [
    "...####...",
    ".########.",
    "##########",
    "#..##..###",   # eye holes, looking toward the t
    "#..##..###",
    "##########",
    "###..#####",   # an "oo" mouth
    "###..#####",
    "##########",
    "##########",
    "##.###.###",   # the sheet's ragged hem
    "#...#...#.",
]

SMALL_GHOST = [
    "..###..",
    ".#####.",
    "#######",
    "#.###.#",
    "#######",
    "#######",
    "#######",
    "#.#.#.#",
]


def sprite(px, rows, x0, y0, opacity, fade_rows=0):
    """A pixel sprite: '#' cells lit, the last `fade_rows` rows fainter (a ghost's hem)."""
    c0, r0 = cell(x0, y0)
    for r, line in enumerate(rows):
        o = opacity * (0.6 if r >= len(rows) - fade_rows else 1)
        for c, ch in enumerate(line):
            if ch == "#":
                put_clear(px, c0 + c, r0 + r, o, MARK_BOX)


def halloween():
    """Ghosts: a big one floating by the right bracket, looking at the t, and a faint small
    one low on the left. (The ring's pumpkin needs its fill; in one color it didn't read.)"""
    px = Pixels()
    sprite(px, BIG_GHOST, 504, -56, 0.9, fade_rows=2)
    sprite(px, SMALL_GHOST, -140, 280, 0.5, fade_rows=1)
    return px


def christmas():
    """A pixel Santa hat on the t, between the brackets' tops: a fur brim, the hat flopping
    right to a pom-pom over the right bracket."""
    px = Pixels()
    for c in range(int(112 // P), int(392 // P) + 1):
        for r in (1, 2):
            put_clear(px, c, r, 1.0 if (c + r) % 3 else 0.8)   # the fur, a little uneven
    # A cone leaning right whose tip flops down over the right bracket.
    hat = [(130, 14), (190, -75), (280, -150), (385, -150), (462, -105), (500, -35),
           (466, -52), (428, -95), (372, -100), (372, 14)]
    def inside(x, y):
        n, hit = len(hat), False
        for i in range(n):
            (x1, y1), (x2, y2) = hat[i], hat[(i + 1) % n]
            if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
                hit = not hit
        return hit
    for c, r in cells_in(inside, 120, -165, 520, 14):
        if r < 1:
            put_clear(px, c, r, 0.55)
    for c, r in cells_in(lambda x, y: (x - 500) ** 2 + (y + 22) ** 2 <= 32 ** 2, 460, -60, 540, 15):
        put_clear(px, c, r, 1.0)
    return px


def hanukkah():
    """The t as a candle: a pixel flame on the t's tip (x 303 to 339 at y 58), glowing, with
    twinkles round it."""
    px = Pixels()
    tip_x, base_y = 322.0, 40.0
    def flame(x, y, scale=1.0):
        # A teardrop: a round bottom, tapering to a point leaning a little right.
        top = base_y - 175 * scale
        if y > base_y or y < top:
            return False
        t = (base_y - y) / (base_y - top)                     # 0 at the bottom, 1 at the tip
        width = 40 * scale * (math.sin(math.pi * min(1, t * 1.6)) if t < 0.31 else (1 - t) * 1.45)
        return abs(x - (tip_x + 18 * t * t)) <= width
    import math
    lit = list(cells_in(flame, tip_x - 70, base_y - 190, tip_x + 70, base_y))
    core = set(cells_in(lambda x, y: flame(x, y + 14, 0.5), tip_x - 50, base_y - 110, tip_x + 50, base_y))
    for c, r in lit:
        put_clear(px, c, r, 0.45 if (c, r) in core else 1.0)
    for c, r in lit:
        for dc, dr in ((1, 0), (-1, 0), (0, -1)):
            if (c + dc, r + dr) not in px.cells:
                put_clear(px, c + dc, r + dr, 0.2)
    sparkle(px, -50, 40)
    sparkle(px, 560, 120, opacity=0.6)
    sparkle(px, -30, 440, opacity=0.6)
    sparkle(px, 540, 470)
    return px


def easter():
    """An egg hunt: three painted pixel eggs (zigzag, stripes, dots) in the grass under the [t]."""
    import random
    px = Pixels()
    def egg(cx, cy, rx, ry):
        def inside(x, y):
            dy = (y - cy) / ry
            width = rx * (1 - 0.2 * max(0.0, -dy))           # narrower at the top
            return dy * dy + ((x - cx) / width) ** 2 <= 1
        return list(cells_in(inside, cx - rx, cy - ry, cx + rx, cy + ry))
    eggs = [(-55, 470, "zigzag"), (250, 495, "stripes"), (555, 470, "dots")]
    for ex, ey, paint in eggs:
        cells = egg(ex, ey, 60, 76)
        rows = sorted({r for _, r in cells})
        mid = rows[len(rows) // 2]
        for c, r in cells:
            o = 0.4
            if paint == "zigzag" and r == mid + (1 if c % 2 else -1) or paint == "zigzag" and r == mid:
                o = 1.0
            elif paint == "stripes" and (r - rows[0]) % 3 == 1:
                o = 1.0
            elif paint == "dots" and c % 2 == 0 and (r - rows[0]) % 3 == 1:
                o = 1.0
            put_clear(px, c, r, o)
    rng = random.Random(7)
    ground = int(574 // P)
    for c in range(int(-130 // P), int(630 // P)):
        for h in range(rng.choice((1, 1, 2, 2, 3))):
            if (c, ground - h) not in px.cells:
                put_clear(px, c, ground - h, 0.5 if h == 0 else 0.35)
    return px


def preview(front, knockout, mark, color, dim, out_png, render):
    """Retro's mark in its dim color on black, the knockout, then the decoration."""
    def inner(s):
        return re.sub(r"^<svg[^>]*>|</svg>$", "", s.strip())
    mark_body = inner(re.sub(r"<\?xml[^>]*\?>", "", mark))
    cut = f'<g fill="#000">{inner(knockout)}</g>' if knockout else ""
    body = (f'<rect x="{-MARGIN}" y="{-MARGIN}" width="{MARK_W + 2 * MARGIN}" height="{MARK_H + 2 * MARGIN}" fill="#000"/>'
            f'<g fill="{dim}">{mark_body}</g>{cut}<g fill="{color}">{inner(front)}</g>')
    tmp = out_png.with_suffix(".svg")
    tmp.write_text(svg(body))
    subprocess.run([render, str(tmp), str(out_png), "360", "000000"], check=True)
    tmp.unlink()


def main():
    icons, render = Path(sys.argv[1]), sys.argv[2]
    mark = (icons.parent.parent.parent / "Tasquel" / "Assets.xcassets" / "TasquelMarkRetro.imageset" / "TasquelMarkRetro.svg").read_text()
    looks = {"green": ("#33FF33", "#26B326"), "amber": ("#FFBF00", "#B88A00")}
    designs = (("thanksgiving", thanksgiving()), ("halloween", halloween()), ("christmas", christmas()),
               ("hanukkah", hanukkah()), ("holiday-season", holiday_season()), ("new-year", new_year(icons)),
               ("easter", easter()))
    for name, px in designs:
        folder = icons / name
        front, knockout = px.front(), px.knockout()
        (folder / f"{name}-retro-front.svg").write_text(front)
        if knockout:
            (folder / f"{name}-retro-knockout.svg").write_text(knockout)
        else:
            (folder / f"{name}-retro-knockout.svg").unlink(missing_ok=True)
        for look, (bright, dim) in looks.items():
            preview(front, knockout, mark, bright, dim, folder / f"{name}-retro-mark-{look}.png", render)


if __name__ == "__main__":
    main()
