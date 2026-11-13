"""Holiday variants of the Tasquel icon and in-app mark. Each holiday gives the fill's colors,
anything drawn on the fill (clipped to it), and decorations behind and in front of the ring,
all in the ring's 408x443 space."""
import math, random
from base import EGG_TRANSFORM, ORIGINAL_FILL

CX, CY = 204, 240  # about the ring's middle


def star(x, y, r, color, opacity=1.0):
    """A four-point sparkle."""
    k = r * 0.28
    return (f'<path d="M{x},{y - r} Q{x + k},{y - k} {x + r},{y} Q{x + k},{y + k} {x},{y + r} '
            f'Q{x - k},{y + k} {x - r},{y} Q{x - k},{y - k} {x},{y - r}Z" fill="{color}" opacity="{opacity}"/>')


def thanksgiving():
    # A turkey's tail: feathers fanned out behind the ring, tips lighter.
    colors = ["#8C4A22", "#C0562B", "#D9822B", "#E8A93A", "#D9822B", "#C0562B", "#8C4A22"]
    behind = ""
    for i, angle in enumerate([-78, -52, -26, 0, 26, 52, 78]):
        c = colors[i]
        behind += (f'<g transform="translate({CX} {CY}) rotate({angle})">'
                   f'<ellipse cx="0" cy="-235" rx="58" ry="130" fill="{c}"/>'
                   f'<ellipse cx="0" cy="-300" rx="40" ry="62" fill="#F4CF7A" opacity="0.55"/>'
                   f'<path d="M0,-120 L0,-350" stroke="#5E3016" stroke-width="5" opacity="0.5"/></g>')
    return dict(fill=["#E8A93A", "#D9822B", "#B8452A"], behind=behind, scale=1.3, dy=40)


def halloween():
    # A pumpkin: ribs on an orange fill, and a stem with a curl of vine on top.
    pattern = f'<g transform="{EGG_TRANSFORM}" fill="none" stroke="#B4480C" stroke-width="7" opacity="0.6">'
    for ry in (55, 115, 170):
        pattern += f'<ellipse cx="187.36" cy="204.29" rx="210.3" ry="{ry}"/>'
    pattern += '</g>'
    front = ('<path d="M212,14 C210,-12 220,-38 236,-58 L262,-48 C248,-30 242,-8 246,16 Z" fill="#5E7A2A"/>'
             '<path d="M246,-40 C276,-62 306,-48 300,-24 C296,-8 278,-10 280,-24" fill="none" stroke="#6E8F2F" stroke-width="7" stroke-linecap="round"/>'
             '<path d="M232,-14 C200,-40 168,-32 160,-12 C182,-6 206,-6 230,-10 Z" fill="#7FA03A"/>')
    return dict(fill=["#FFB347", "#F2761E", "#C4500E"], pattern=pattern, front=front, mark_fill=True)


def christmas():
    # A Santa hat on the ring, its tip falling to the right.
    front = ('<path d="M128,22 C150,-70 240,-128 330,-112 C372,-104 400,-70 404,-30 C384,-58 352,-70 330,-62 '
             'C312,-40 306,-6 316,24 Z" fill="#D7263D"/>'
             '<path d="M150,-10 C178,-70 238,-104 300,-102" fill="none" stroke="#B01D31" stroke-width="10" opacity="0.6"/>'
             '<rect x="112" y="-6" width="226" height="50" rx="25" fill="#F7F4EF" transform="rotate(2 225 19)"/>'
             '<circle cx="406" cy="-24" r="30" fill="#F7F4EF"/>')
    return dict(fill=["#E23B4E", "#F4C95D", "#2BA36B"], front=front, scale=1.5, dy=50)


def hanukkah():
    # The t as a candle: a flame on top, and silver sparkles.
    front = ('<defs><radialGradient id="flame" cx="0.5" cy="0.7" r="0.6"><stop offset="0" stop-color="#FFFBEA"/>'
             '<stop offset="0.45" stop-color="#FFD54F"/><stop offset="1" stop-color="#FF8F00"/></radialGradient></defs>'
             '<path d="M290,-74 C320,-32 338,6 327,38 C316,66 270,68 259,42 C246,12 266,-20 290,-74 Z" fill="url(#flame)"/>'
             + star(110, 40, 22, "#E3ECF7") + star(380, 90, 16, "#E3ECF7") + star(60, 330, 14, "#E3ECF7")
             + star(400, 330, 20, "#E3ECF7"))
    return dict(fill=["#1E4FA0", "#3E86D6", "#BFE0FF"], front=front, scale=1.6, dy=30)


def holiday_season():
    # String lights draped across the ring, and a few snow sparkles.
    wire = "M20,150 C80,250 330,250 398,128"
    front = f'<path d="{wire}" fill="none" stroke="#2A2E3A" stroke-width="6"/>'
    colors = ["#FFE8A3", "#F4C24C", "#9FD6FF", "#FFE8A3", "#F4C24C", "#9FD6FF", "#FFE8A3"]
    # Points along the wire (a cubic): bulbs hang from them.
    p0, p1, p2, p3 = (20, 150), (80, 250), (330, 250), (398, 128)
    for i in range(7):
        t = (i + 0.5) / 7
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1]
        tilt = (i - 3) * 6
        front += (f'<g transform="translate({x:.1f} {y:.1f}) rotate({tilt})">'
                  f'<circle cx="0" cy="30" r="32" fill="{colors[i]}" opacity="0.35"/>'
                  f'<rect x="-10" y="0" width="20" height="14" rx="3" fill="#3A3F4D"/>'
                  f'<ellipse cx="0" cy="31" rx="17" ry="23" fill="{colors[i]}"/></g>')
    front += star(60, 40, 16, "#FFFFFF", 0.8) + star(370, 20, 12, "#FFFFFF", 0.8) + star(395, 380, 14, "#FFFFFF", 0.7)
    return dict(fill=["#22346B", "#4C79C6", "#A9D4FF"], front=front)


def new_year():
    # Confetti and sparkles all round.
    rnd = random.Random(3)
    colors = ["#F4C24C", "#E3ECF7", "#FF7BA0", "#4FD1E8", "#B7A4FF"]
    around = ""
    for i in range(34):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(235, 330)
        x, y = CX + r * math.cos(a), CY - 15 + r * math.sin(a) * 1.05
        c = colors[i % len(colors)]
        if i % 3 == 0:
            around += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rnd.uniform(6, 10):.1f}" fill="{c}"/>'
        else:
            w, h = rnd.uniform(10, 16), rnd.uniform(22, 32)
            around += f'<rect x="{x - w / 2:.1f}" y="{y - h / 2:.1f}" width="{w:.1f}" height="{h:.1f}" rx="3" fill="{c}" transform="rotate({rnd.uniform(-70, 70):.0f} {x:.1f} {y:.1f})"/>'
    front = star(70, 40, 30, "#F4C24C") + star(372, 30, 22, "#E3ECF7") + star(30, 400, 18, "#F4C24C")
    return dict(fill=["#2B2D6E", "#7A4FC2", "#E0B64A"], behind=around, front=front, scale=1.55)


def easter():
    # A painted egg: bands of zigzags, dots and stripes across it.
    g = f'<g transform="{EGG_TRANSFORM}">'
    cx, cy = 187.36, 204.29
    for dx, color in ((-120, "#FFD54F"), (120, "#FFD54F")):
        g += f'<rect x="{cx + dx - 14}" y="{cy - 200}" width="28" height="400" fill="{color}"/>'
    for dx in (-60, 60):
        zig = f"M{cx + dx - 16},{cy - 200}"
        for k in range(21):
            y = cy - 200 + k * 20
            zig += f" L{cx + dx + (16 if k % 2 == 0 else -16)},{y + 10}"
        g += f'<path d="{zig}" fill="none" stroke="#4DB6AC" stroke-width="12" stroke-linejoin="round"/>'
    for k in range(-4, 5):
        g += f'<circle cx="{cx}" cy="{cy + k * 44}" r="13" fill="#FFFFFF" opacity="0.9"/>'
    for dx in (-175, 175):
        g += f'<rect x="{cx + dx - 10}" y="{cy - 200}" width="20" height="400" fill="#9575CD"/>'
    g += '</g>'
    front = star(380, 40, 18, "#FFFFFF", 0.9) + star(40, 60, 12, "#FFFFFF", 0.8)
    return dict(fill=["#F48FB1", "#F06292", "#BA68C8"], pattern=g, front=front, mark_fill=True)


HOLIDAYS = {
    "default": lambda: dict(fill=ORIGINAL_FILL),
    "thanksgiving": thanksgiving,
    "halloween": halloween,
    "christmas": christmas,
    "hanukkah": hanukkah,
    "holiday-season": holiday_season,
    "new-year": new_year,
    "easter": easter,
}
