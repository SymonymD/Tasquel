"""The Tasquel icon's layers (from AppIcon.icon and TasquelMark.svg), for holiday variants."""

RING = ("M179.5,443.31c-28.45,0-56.1-6.65-81.35-19.91-46.79-24.55-79.61-68.74-92.41-124.43-12.69-55.18-4.17-115.12,"
        "23.99-168.78C57.89,76.53,102.37,35.46,154.99,14.55c53.1-21.1,108.11-19.2,154.9,5.35,46.79,24.55,79.61,68.74,"
        "92.41,124.43,12.69,55.18,4.17,115.12-23.99,168.78l-8.02-4.21,8.02,4.21c-28.16,53.66-72.65,94.73-125.26,115.64"
        "-24.44,9.71-49.29,14.55-73.55,14.55ZM228.65,18.22c-70.48,0-143.26,44.87-182.88,120.38-53.74,102.4-26.46,222.97,"
        "60.8,268.76,42.04,22.06,91.68,23.68,139.8,4.56,48.6-19.31,89.76-57.39,115.91-107.22,53.74-102.4,26.46-222.97"
        "-60.8-268.76-22.91-12.02-47.73-17.72-72.82-17.72Z")
T = ("M148.58,313.7c47.9-20.19,88.82-53.2,123.12-125.16.13-.27-.05-.58-.34-.63,0,0-12.5-2.43-12.5-2.43-1.57-.3-3.17.27"
     "-4.18,1.51-22.71,27.86-53.84,65.8-92.7,65.8-25.79,0-35.37-14-35.37-29.48,0-11.79,3.68-20.64,8.84-32.43l29.64-66.34"
     "c.8-1.78,2.57-2.93,4.52-2.93,0,0,35.91,0,35.91,0,1.31,0,2.5-.76,3.06-1.94l9.33-19.76c1.06-2.24-.58-4.83-3.06-4.83"
     "h-32.47c-2.33,0-3.9-2.39-2.97-4.53,0,0,39.03-89.9,39.03-89.9.13-.3-.09-.64-.42-.64,0,0-35.35,0-35.35,0-1.87,0"
     "-3.58.99-4.56,2.59-29.55,48.41-95.43,84.91-149.63,93.44,0,0-9.5,20.78-9.5,20.78-1.02,2.24.61,4.79,3.08,4.79,0,0,"
     "24,0,24,0,3.57,0,5.97,3.67,4.54,6.94L12.39,215.93C4.66,233.73-.86,253.31.11,272.91s12.73,38.27,35.63,47.03"
     "c45.09,17.26,89.08,3.77,112.84-6.24Z")
# The fill inside the ring, in its own layer's space; EGG_FRAME places that layer in the ring's.
EGG_TRANSFORM = "translate(-80.59 275.27) rotate(-62.31)"
EGG = f'<ellipse cx="187.36" cy="204.29" rx="210.3" ry="180.5" transform="{EGG_TRANSFORM}"/>'
EGG_FRAME = "translate(16.66 17.37)"
T_FRAME = "translate(85.14 57.54)"
ORIGINAL_FILL = ["#c246ff", "#00ffff", "#00ff40"]
RING_W, RING_H = 408.04, 443.31
# Decorations may reach this far past the ring's box.
MARGIN = 170


def fill_gradient(gid, stops):
    n = len(stops)
    s = "".join(f'<stop offset="{i / (n - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(stops))
    return (f'<linearGradient id="{gid}" x1="12.19" y1="305.43" x2="362.54" y2="103.15" '
            f'gradientTransform="translate(281.19 -56.55) rotate(62.31)" gradientUnits="userSpaceOnUse">{s}</linearGradient>')


def layers(fill_stops, fill_pattern="", ring_color="#bfbfbf", t_color="#ffffff", behind="", front="", defs=""):
    """The icon in the ring's space: decorations behind, the fill (and anything drawn on it,
    clipped to it), the ring, the t, decorations in front."""
    return (f'<defs>{fill_gradient("fill", fill_stops)}<clipPath id="egg">{EGG}</clipPath>{defs}</defs>'
            f'{behind}'
            f'<g transform="{EGG_FRAME}"><g fill="url(#fill)">{EGG}</g>'
            f'<g clip-path="url(#egg)">{fill_pattern}</g></g>'
            f'<path d="{RING}" fill="{ring_color}"/>'
            f'<g transform="{T_FRAME}"><path d="{T}" fill="{t_color}"/></g>'
            f'{front}')


def app_icon(content, extra="", scale=1.7, dy=0):
    """A 1024 app icon: the icon's navy background and the group at its scale (1.7, centred; a
    holiday with a big decoration shrinks it to fit, dy moving it down)."""
    tx, ty = 512 - RING_W / 2 * scale, 512 - RING_H / 2 * scale + dy
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
            '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#373752"/>'
            '<stop offset="0.7" stop-color="#000000"/></linearGradient></defs>'
            '<rect width="1024" height="1024" fill="url(#bg)"/>'
            f'<g transform="translate({tx:.2f} {ty:.2f}) scale({scale})">{content}{extra}</g></svg>')


def layer_svg(content, defs=""):
    """A layer for Icon Composer or the app, in the ring's space with MARGIN all round (so its
    centre is the ring's: it lines up placed at the centre, scale 1)."""
    m = MARGIN
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-m} {-m} {RING_W + 2 * m:.2f} {RING_H + 2 * m:.2f}">'
            f'<defs>{defs}</defs>{content}</svg>')


def mark_preview(content_behind, content_front, mark_color, background, fill_layer=""):
    """The in-app mark (ring and t in the header's color) with a holiday layer, on a header color."""
    m = MARGIN
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-m} {-m} {RING_W + 2 * m:.2f} {RING_H + 2 * m:.2f}">'
            f'<rect x="{-m}" y="{-m}" width="{RING_W + 2 * m}" height="{RING_H + 2 * m}" fill="{background}"/>'
            f'<defs><clipPath id="egg">{EGG}</clipPath></defs>'
            f'{content_behind}{fill_layer}'
            f'<path d="{RING}" fill="{mark_color}"/>'
            f'<g transform="{T_FRAME}"><path d="{T}" fill="{mark_color}"/></g>'
            f'{content_front}</svg>')


def grid():
    g = ""
    for x in range(-100, 520, 50):
        g += (f'<line x1="{x}" y1="-120" x2="{x}" y2="560" stroke="red" stroke-width="0.8"/>'
              f'<text x="{x + 2}" y="-105" font-size="12" fill="red">{x}</text>')
    for y in range(-100, 560, 50):
        g += (f'<line x1="-120" y1="{y}" x2="520" y2="{y}" stroke="red" stroke-width="0.8"/>'
              f'<text x="-118" y="{y - 2}" font-size="12" fill="red">{y}</text>')
    return g
