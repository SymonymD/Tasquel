"""An overview sheet of Retro's marks: the plain t in brackets and each holiday's (rows), in each of Retro's six colors (columns), on Retro's black. The colors are Retro's
bright (decorations) and dim (the mark) from Theme.swift.

Usage: python3 retro_overview.py <Holiday_Icons dir> <render binary> <out.png>
Run retro.py first: it writes the layers this reads.
"""
import pathlib
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import retro  # noqa: E402

# Theme.retroPalette: (bright, dim), each r, g, b in 0...1.
COLORS = {
    "Green": ((0.2, 1.0, 0.2), (0.15, 0.7, 0.15)),
    "Amber": ((1.0, 0.75, 0.0), (0.72, 0.54, 0.0)),
    "Blue": ((0.3, 0.7, 1.0), (0.25, 0.59, 0.84)),
    "White": ((0.95, 0.95, 0.95), (0.65, 0.65, 0.65)),
    "Red": ((1.0, 0.43, 0.43), (0.89, 0.38, 0.38)),
    "Purple": ((0.78, 0.48, 1.0), (0.69, 0.43, 0.89)),
}


def hex_color(rgb):
    return "#" + "".join(f"{round(c * 255):02X}" for c in rgb)


def main():
    icons, render, out = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3])
    mark = (icons.parent.parent.parent / "Tasquel" / "Assets.xcassets" / "TasquelMarkRetro.imageset" / "TasquelMarkRetro.svg").read_text()
    empty = retro.svg("")
    rows = [("Retro", empty, None)]
    for folder in ("thanksgiving", "halloween", "christmas", "hanukkah", "holiday-season", "new-year", "easter"):
        cut = icons / folder / f"{folder}-retro-knockout.svg"
        rows.append((folder.replace("-", " ").title(), (icons / folder / f"{folder}-retro-front.svg").read_text(),
                     cut.read_text() if cut.exists() else None))

    tile, gap, pad, row_label, col_label = 200, 16, 36, 250, 60
    width = pad + row_label + len(COLORS) * (tile + gap) - gap + pad
    height = pad + col_label + len(rows) * (tile + gap) - gap + pad
    sheet = Image.new("RGB", (width, height), (238, 238, 242))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 30)
    except Exception:
        font = ImageFont.load_default()

    with tempfile.TemporaryDirectory() as tmp:
        for c, (color, (bright, dim)) in enumerate(COLORS.items()):
            x = pad + row_label + c * (tile + gap)
            draw.text((x, pad), color, fill=(40, 40, 46), font=font)
            for r, (name, front, knockout) in enumerate(rows):
                y = pad + col_label + r * (tile + gap)
                if c == 0:
                    draw.text((pad, y + tile // 2 - 18), name, fill=(40, 40, 46), font=font)
                png = pathlib.Path(tmp) / f"{r}-{c}.png"
                retro.preview(front, knockout, mark, hex_color(bright), hex_color(dim), png, render)
                sheet.paste(Image.open(png).convert("RGB").resize((tile, tile), Image.LANCZOS), (x, y))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
