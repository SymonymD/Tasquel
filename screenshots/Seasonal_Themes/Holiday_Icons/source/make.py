"""Writes each holiday's icon, its layers and in-app mark previews to <out>/<holiday>/."""
import pathlib, subprocess, sys
from base import *
from holidays import HOLIDAYS

out = pathlib.Path(sys.argv[1])
render = sys.argv[2]
only = sys.argv[3:] or list(HOLIDAYS)

for name in only:
    spec = HOLIDAYS[name]()
    folder = out / name
    folder.mkdir(parents=True, exist_ok=True)
    behind, front, pattern = spec.get("behind", ""), spec.get("front", ""), spec.get("pattern", "")
    # The app icon, flat (Icon Composer adds the glass).
    icon = app_icon(layers(spec["fill"], fill_pattern=pattern, behind=behind, front=front),
                    scale=spec.get("scale", 1.7), dy=spec.get("dy", 0))
    (folder / f"{name}-app-icon.svg").write_text(icon)
    subprocess.run([render, str(folder / f"{name}-app-icon.svg"), str(folder / f"{name}-app-icon.png"), "1024"], check=True)
    # Layers for Icon Composer and the app, in the ring's space (centred on it).
    if behind:
        (folder / f"{name}-layer-behind.svg").write_text(layer_svg(behind))
    if front:
        (folder / f"{name}-layer-front.svg").write_text(layer_svg(front))
    if pattern:
        (folder / f"{name}-layer-fill-pattern.svg").write_text(
            layer_svg(f'<g transform="{EGG_FRAME}"><g clip-path="url(#egg)">{pattern}</g></g>', defs=f'<clipPath id="egg">{EGG}</clipPath>'))
    (folder / f"{name}-fill.txt").write_text("Fill gradient (the ring's inside, same direction as AppIcon.icon): " + " → ".join(spec["fill"]) + "\n")
    # The in-app mark: ring and t in the header's text color, with the holiday's layers.
    fill_layer = ""
    if spec.get("mark_fill"):
        fill_layer = (f'<defs>{fill_gradient("fill", spec["fill"])}</defs><g transform="{EGG_FRAME}"><g fill="url(#fill)">{EGG}</g>'
                      f'<g clip-path="url(#egg)">{pattern}</g></g>')
    for look, color, bg in (("light", "#1C1C24", "#F2F2F7"), ("dark", "#FFFFFF", "#1C1C1E")):
        svg = mark_preview(behind, front, color, bg, fill_layer)
        (folder / f"{name}-mark-{look}.svg").write_text(svg)
        subprocess.run([render, str(folder / f"{name}-mark-{look}.svg"), str(folder / f"{name}-mark-{look}.png"), "360"], check=True)
        (folder / f"{name}-mark-{look}.svg").unlink()
    print("made", name)
