"""Lays out Tasquel's raw simulator screenshots as App Store images:
a headline and subhead above the screenshot, in a device bezel, on the icon's navy."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC = Path(sys.argv[1])
OUT = Path(sys.argv[2])
FONT_DIR = "/usr/share/fonts/opentype/inter/"
BOLD = FONT_DIR + "InterDisplay-Bold.otf"
MEDIUM = FONT_DIR + "InterDisplay-Medium.otf"

# From AppIcon.icon: navy gradient (P3 0.336,0.339,0.5 -> 0.216,0.216,0.321), silver border.
TOP = (86, 87, 128)
BOTTOM = (30, 30, 46)
HEADLINE = (255, 255, 255)
SUBHEAD = (196, 198, 214)
BEZEL = (14, 14, 20)
BEZEL_EDGE = (150, 152, 172)

# "\n" marks the iPhone line breaks; iPad, being wider, joins them into one line.
SHOTS = [
    ("01-week", "Plan one week\nat a time", "Sort tasks into cards. Each new\nweek builds itself from the last."),
    ("02-card-open", "Lists, sub-tasks\nand goals", "Tick off items, steps and progress,\nall in one card."),
    ("03-type-and-mode", "Unfinished?\nIt carries over.", "Choose what happens to each\ntask when the week ends."),
    ("04-calendar-events", "Your calendar,\nalongside", "See the week's events right\nnext to your tasks."),
    ("05-retro", "Go retro", "A terminal theme in six phosphor\ncolors, with a matching icon."),
    ("06-dark", "Easy on the eyes", "Light, Dark, or\nfollow your device."),
]

DEVICES = {
    # canvas size, headline px, subhead px, top margin, bottom margin, bezel px, screen corner radius (fraction of shot width)
    "iphone": dict(size=(1320, 2868), h=104, s=50, top=150, bottom=110, bezel=26, radius=0.125, lines=(2, 2)),
    "ipad": dict(size=(2064, 2752), h=124, s=60, top=150, bottom=110, bezel=30, radius=0.035, lines=(1, 1)),
}


def gradient(size):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def wrap(draw, text, font, max_width):
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) <= max_width:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def compose(device, name, headline, subhead):
    spec = DEVICES[device]
    W, H = spec["size"]
    canvas = gradient((W, H))
    draw = ImageDraw.Draw(canvas)
    hfont = ImageFont.truetype(BOLD, spec["h"])
    sfont = ImageFont.truetype(MEDIUM, spec["s"])
    max_text = W * 0.84

    def lines_of(text, font):
        if spec["lines"] == (1, 1):
            text = text.replace("\n", " ")
        return [l for part in text.split("\n") for l in wrap(draw, part, font, max_text)]

    head_lines = lines_of(headline, hfont)
    sub_lines = lines_of(subhead, sfont)
    head_lh, sub_lh, gap = spec["h"] * 1.12, spec["s"] * 1.3, spec["s"] * 0.45
    # The device sits at the same height on every image: room is kept for the most
    # lines any image uses, and each image's text is centred in that room.
    room = spec["lines"][0] * head_lh + gap + spec["lines"][1] * sub_lh
    used = len(head_lines) * head_lh + gap + len(sub_lines) * sub_lh
    y = spec["top"] + (room - used) / 2
    for line in head_lines:
        draw.text((W / 2, y), line, font=hfont, fill=HEADLINE, anchor="mt")
        y += head_lh
    y += gap
    for line in sub_lines:
        draw.text((W / 2, y), line, font=sfont, fill=SUBHEAD, anchor="mt")
        y += sub_lh
    text_bottom = spec["top"] + room + spec["s"] * 0.9

    shot = Image.open(SRC / device / f"{name}.png").convert("RGB")
    bezel = spec["bezel"]
    avail_h = H - text_bottom - spec["bottom"] - 2 * bezel
    scale = avail_h / shot.height
    sw, sh = round(shot.width * scale), round(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = round(sw * spec["radius"])

    dw, dh = sw + 2 * bezel, sh + 2 * bezel
    dx, dy = round((W - dw) / 2), round(text_bottom)

    # Soft shadow under the device.
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((dx, dy + 30, dx + dw, dy + dh + 30), radius=radius + bezel, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(60))
    canvas.paste((8, 8, 14), (0, 0), shadow)

    # Bezel with a thin silver edge, then the screen.
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((dx, dy, dx + dw, dy + dh), radius=radius + bezel, fill=BEZEL_EDGE)
    draw.rounded_rectangle((dx + 3, dy + 3, dx + dw - 3, dy + dh - 3), radius=radius + bezel - 3, fill=BEZEL)
    canvas.paste(shot, (dx + bezel, dy + bezel), rounded_mask((sw, sh), radius))

    out = OUT / device
    out.mkdir(parents=True, exist_ok=True)
    canvas.save(out / f"{name}.png", optimize=True)  # RGB, no alpha (App Store requirement)
    return out / f"{name}.png"


if __name__ == "__main__":
    for device in DEVICES:
        for name, headline, subhead in SHOTS:
            print(compose(device, name, headline, subhead))
