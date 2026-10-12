# Project Istiqamah design system

The interface is calm by default and becomes visibly active when the user is
taking action. Green is reserved for primary actions, progress, and completion;
neutral surfaces carry the rest of the hierarchy.

## Semantic palette

| Role | Light | Dark |
| --- | --- | --- |
| Primary | `#356B5B` | `#8FD3B8` |
| Primary pressed | `#285548` | `#A8E4CA` |
| Background | `#F7F8F6` | `#0D1110` |
| Surface | `#FFFFFF` | `#151B19` |
| Elevated surface | `#F0F3F0` | `#1C2421` |
| Primary text | `#17201D` | `#F2F5F3` |
| Secondary text | `#68736F` | `#9DAAA5` |
| Tertiary text | `#929B97` | `#6F7B76` |
| Border | `#DDE3DF` | `#29332F` |
| Divider | `#E8ECE9` | `#202925` |
| Completed | `#3E8E70` | `#72C7A4` |
| Success | `#31805F` | `#6DCA9F` |
| Warning | `#B9853B` | `#E2B96D` |
| Error | `#B95353` | `#F07F7F` |
| Info | `#547D91` | `#82B8D0` |

All application colors are exposed as semantic values in `Sources/App/Theme.swift`.
Views should use a role such as `secondaryText` or `warning`, not embed a new
hex value. Light and dark variants resolve automatically from the system appearance.

## Usage rules

- Use `background` for screen canvases, `surface` for primary cards, and
  `elevatedSurface` for controls or nested emphasis.
- Use `primary` for the main action and active progress. Use `completed` for
  finished work so action and completion remain visually distinct.
- Use status colors only when they communicate state. Upcoming content uses
  `info`; missed or unfinished content uses `warning`; destructive failures use
  `error`.
- Prefer primary, secondary, and tertiary text roles over opacity changes.
- Cards use continuous 22-point corners, a one-point semantic border, and a
  restrained adaptive shadow.

## App icon and widget mark

The original identity is a sculpted green lowercase `i` with a flowing mint
sweep and gentle highlights. The enhanced version keeps the logo silhouette
intact on a reflective silver background that fills the square. A feathered green-chroma mask applies
10% more saturation and 6% more contrast to the green artwork, followed by a
restrained sharpening pass. A green-chroma mask isolates the sculpture from the
original inset tile. Broad reflected light replaces the inset tile background. A faint specular
reflection, luminous lip, and diffused shadow give the green sculpture glass
depth. There is no inset tile rim or tiny outer gap. This is rendered PNG
artwork; it does not add a system-responsive Liquid Glass material or claim an
official iOS 27 treatment.

`assets/images/icon.png` remains a square, opaque 1024 × 1024 RGB PNG. There is no
baked-in outer rim or rounded tile; iOS applies its own outer icon mask.
`Sources/Widgets/IstiqamahMark.swift` preserves the original native SwiftUI
silhouette with configurable `primary` and `secondary` colors.

Regenerate the enhanced PNG from the repository root:

```bash
python3 -m venv /tmp/istiqamah-artwork
/tmp/istiqamah-artwork/bin/pip install Pillow==11.3.0
/tmp/istiqamah-artwork/bin/python scripts/generate-app-icon.py
```

The script always starts from `scripts/artwork/icon-original.png`, so repeated
runs never compound the adjustments. It does not generate the SwiftUI mark.
Pillow is an artwork development dependency only. Inspect the installed icon
and the widget mark on an iPhone before distributing a build.

## Block colors

Focus widgets and Live Activities use seven subtle palettes: sage, blue,
lavender, rose, peach, sand, and teal. `BlockWidgetPalette.swift` maps a block's
UUID to a palette; refreshes never choose a new random color. This is identity
color, not completion status. The main app retains its semantic green palette.
Home Screen colors adapt to light/dark appearance; iOS may render accessory or
tinted widgets in monochrome. Block name, intention, timer, and status remain
textual so color is not the only signal.
