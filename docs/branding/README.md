# Branding assets

Logos for **Markdown QuickLook**. Both marks were generated with the
[`image-gen` skill](https://github.com/jzone3/profile-skills/tree/master/skills/image-gen)
(OpenAI `gpt-image-2`), then post-processed with Pillow. The exact prompts are
below so the assets are reproducible.

## Assets

| File | Size | Purpose |
| --- | --- | --- |
| `app-icon-1024.png` | 1024×1024, RGBA | Main macOS app icon. Squircle with transparent corners (macOS does **not** auto-mask app icons). Source of the `AppIcon.appiconset` sizes. |
| `menubar-icon-1024.png` | 1024×1024, RGBA | Menu-bar **template** master: pure black (`#000000`) glyph on transparent. |
| `menubar-icon-36.png` / `menubar-icon-18.png` | 36 / 18 px, RGBA | Menu-bar template exports (`@2x` / `@1x`) for an `NSStatusItem`. |

### App icon

A modern macOS "squircle": deep indigo→blue gradient tile, a white document
peeking out behind a rounded **M + down-arrow** Markdown badge (the canonical
Markdown mark), suggesting a rendered Quick Look preview. No wordmark. Reads
cleanly on light and dark backgrounds and stays legible down to ~32 px.

### Menu-bar icon

The canonical Markdown mark (rounded-rectangle frame containing a bold **M** and
a downward arrow) as a single flat black silhouette. It is a macOS **template
image** (`template-rendering-intent`), so macOS tints it automatically — black in
the light menu bar, white in the dark menu bar.

## Where they're wired

- `App/Resources/Assets.xcassets/AppIcon.appiconset/` — full mac icon set
  (16–512 pt, `@1x`/`@2x`) generated from `app-icon-1024.png`. Referenced by the
  app target via `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`.
- `App/Resources/Assets.xcassets/MenuBarIcon.imageset/` — template image for a
  future menu-bar / `NSStatusItem` build. Load with
  `NSImage(named: "MenuBarIcon")` (it is already marked as a template, so no need
  to call `setTemplate(true)`).

## Regenerating

Provider keys are read from the environment (`OPENAI_API_KEY`, `GEMINI_API_KEY`,
`XAI_API_KEY`). `GEN=<path>/profile-skills/skills/image-gen/scripts/generate_image.py`.

### App icon

```bash
# 1) candidates across providers
python "$GEN" --prompt-file app-icon.prompt.txt -o gpt.png    -n 4 --provider openai --size 1024x1024 --quality high
python "$GEN" --prompt-file app-icon.prompt.txt -o gemini.png -n 4 --provider gemini --model gemini-3-pro-image-preview
python "$GEN" --prompt-file app-icon.prompt.txt -o xai.png    -n 4 --provider xai --aspect-ratio 1:1 --resolution 2k

# 2) refine the winner (edit pass)
python "$GEN" "Refine this macOS app icon. Keep the same composition, deep indigo-to-blue gradient squircle, the white document peeking out behind, and the rounded 'M + down-arrow' markdown badge. Make the white M and downward arrow crisper, bolder and slightly larger so the glyph stays legible at small sizes; clean flat vector edges; subtle soft drop shadow; pure-white background around the squircle. No text/wordmark except the single M." \
  -s gpt_3.png -o refine.png -n 3 --provider openai --size 1024x1024 --quality high

# 3) mask the white background -> transparent squircle corners (Pillow):
#    detect the colored squircle bbox, draw a rounded-rectangle alpha mask
#    (radius ~= 0.225 * side), inset a few px to trim AA fringe, recenter on a
#    1024 transparent canvas at ~0.90 fill.
```

App-icon prompt (`app-icon.prompt.txt`):

```
A polished modern macOS application icon, 1024x1024, centered, in the contemporary macOS style: a rounded-rectangle "squircle" app tile with a smooth surface, subtle top-to-bottom gradient, soft realistic drop shadow, and gentle inner highlight for depth. Subject (single central glyph): the canonical Markdown mark — a bold rounded-rectangle badge containing a capital "M" next to a downward-pointing arrow. Integrate a subtle Quick Look / preview motif: the markdown mark sits on a small white document card peeking out behind it, showing a few faint lines of rendered text. Color & style: tasteful developer-tool aesthetic in the quality tier of Linear, Vercel, Raycast. Squircle background a refined deep indigo-to-blue gradient; the glyph crisp clean white, high contrast. Flat, geometric, minimal, no text/wordmark, no letters other than the single "M". Crisp vector-like edges, legible at large and small sizes. Plain neutral background around the squircle.
```

### Menu-bar template icon

```bash
# gpt-image-2 has no transparent-background mode, so generate black-on-white...
python "$GEN" --prompt-file menubar.prompt.txt -o mark.png -n 4 --provider openai --size 1024x1024 --quality high
# ...then threshold to pure black on transparent (Pillow):
#   L = grayscale;  alpha = clip((175 - L) / (175 - 90), 0, 1) * 255;  RGB = (0,0,0)
#   trim to the glyph bbox, center on a square canvas at ~0.80 fill.
```

Menu-bar prompt (`menubar.prompt.txt`):

```
A minimal monochrome macOS menu-bar (status bar) template icon. Solid pure black silhouette on a fully transparent background. Single flat weight, NO gradients, NO shadows, NO color. The glyph is the canonical Markdown mark: a rounded-rectangle outline frame containing a bold capital "M" and, to its right, a downward-pointing arrow. Thick confident strokes, geometric, high contrast. Crisp and legible at very small size (18x18 points). Centered with generous even padding. No text. Pure black (#000000) only.
```

Winning candidates: **OpenAI `gpt-image-2`** for both marks (the app icon is an
OpenAI edit/refine pass on an OpenAI candidate). xAI and Gemini candidates were
generated for comparison but the OpenAI outputs had the cleanest glyphs.
