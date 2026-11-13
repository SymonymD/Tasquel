"""An overview sheet: each holiday's app icon (rounded like the home screen) with its in-app
mark on a light and a dark header."""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont

out = pathlib.Path(sys.argv[1])
names = sys.argv[3:]
icon_size, mark_size, pad, label = 300, 140, 36, 60
cols = len(names)
width = pad + cols * (icon_size + pad)
height = label + icon_size + pad + mark_size + pad
sheet = Image.new("RGB", (width, height), (238, 238, 242))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 30)
except Exception:
    font = ImageFont.load_default()
mask = Image.new("L", (icon_size, icon_size), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, icon_size - 1, icon_size - 1), radius=int(icon_size * 0.225), fill=255)
for i, name in enumerate(names):
    x = pad + i * (icon_size + pad)
    title = "Default" if name == "default" else name.replace("-", " ").title()
    draw.text((x, 14), title, fill=(40, 40, 46), font=font)
    icon = Image.open(out / name / f"{name}-app-icon.png").convert("RGB").resize((icon_size, icon_size))
    sheet.paste(icon, (x, label), mask)
    for j, look in enumerate(("light", "dark")):
        mark = Image.open(out / name / f"{name}-mark-{look}.png").convert("RGB").resize((mark_size, mark_size))
        sheet.paste(mark, (x + j * (mark_size + 20), label + icon_size + pad))
sheet.save(sys.argv[2])
print(sheet.size)
