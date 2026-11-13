# Holiday Tasquel icons

Holiday versions of the Tasquel logo, made from the app's own icon layers (`AppIcon.icon`) and in-app mark (`TasquelMark.svg`). `overview.png` shows them all: each app icon (rounded as on the home screen) with the in-app mark on a light and a dark header, the current icon first for comparison.

| Holiday | Idea |
|---|---|
| Thanksgiving | A turkey's tail of feathers fanned out behind the ring; amber-to-rust fill |
| Halloween | The ring as a pumpkin: orange ribbed fill, a stem and a curl of vine |
| Christmas | A Santa hat on the ring; red, gold and green fill |
| Hanukkah | The t as a candle with a flame; blue and silver |
| Holiday Season | Neutral: string lights draped across the ring, sparkles; navy to ice blue |
| New Year | Confetti and sparkles; indigo, violet and gold |
| Easter | The ring's egg shape painted with zigzags, dots and stripes |

## In each folder

- `*-app-icon.png` / `.svg`: the 1024 app icon, flat. Icon Composer adds the glass and lighting the real icon has.
- `*-layer-behind.svg`, `*-layer-front.svg`: the decoration, behind or in front of the ring. Drawn in the ring's space with a 170-point margin all round, so each lines up placed at the centre at scale 1, both in Icon Composer (as layers in the logo's group) and in the app (over the template `TasquelMark`, which stays tinted to the theme).
- `*-layer-fill-pattern.svg`: what's painted on the ring's fill (pumpkin ribs, Easter patterns), in the same space.
- `*-fill.txt`: the fill gradient's colors, in the original's direction.
- `*-mark-light.png`, `*-mark-dark.png`: the in-app mark (the Tasquel logo at the top left) with the decoration, on a light and a dark header.
- Some holidays shrink the logo a little in the app icon so the decoration fits (Thanksgiving 1.3, Christmas 1.5, Hanukkah 1.6, New Year 1.55, others the usual 1.7).

## Retro versions

Retro's mark is the t in square brackets, drawn in one color, so every holiday has a pixel version of its own, kept off the t (in one color, anything crossing the t blurs into it):

| Holiday | Retro idea |
|---|---|
| Thanksgiving | Pixel feathers fanned out behind the brackets, banded tips |
| Halloween | Ghosts: a big one by the right bracket looking at the t, a faint small one low on the left (the pumpkin needed its fill) |
| Christmas | A Santa hat on the t between the brackets, flopping right to a pom-pom |
| Hanukkah | A pixel flame on the t's tip, glowing, with twinkles |
| Holiday Season | A string of lights hung under the brackets, twinkles above |
| New Year | The confetti as pixels round the brackets |
| Easter | Three painted eggs (zigzag, stripes, dots) in the grass under the brackets |

Each is `<holiday>/<holiday>-retro-front.svg`: a one-color template the app tints Retro's bright color, shades as opacity, in the mark's space with 170 more on every side. Previews in green and amber: `*-retro-mark-<color>.png`. `retro-overview.png` shows them all in Retro's six colors. Made by `source/retro.py` and `source/retro_overview.py`.

## In the app (2026-11-13)

Holiday Season's lights for the week before Christmas's week and Christmas's week, then New Year's confetti for the week after, in every appearance (Retro's own versions in Retro). See `HolidayMark` in SeasonalTheme.swift.

## Using them

- In the app: the header's mark swaps to the holiday's during its week (the template mark plus the colored layer), like the Retro mark does.
- As the app icon: each would be an alternate icon (like `AppIconRetro.icon`). iOS shows its own alert every time an app changes its icon, so switching it for holidays would need to be the user's choice (a setting), not automatic.
