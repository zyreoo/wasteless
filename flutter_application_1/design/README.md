# Wasteless · Figma implementation

Source: https://www.figma.com/design/9ZzwNrvQszUi871wPSble4/wasteless?node-id=0-1

The Flutter UI covers all 18 artboards. Seventeen are generated from the saved
Figma design context. The confirmation artboard (10:4007) is implemented from
its metadata and a visual inspection in Figma Desktop: the MCP Starter quota
blocked its detailed export. Its exact icon, typography and effects still need
comparison against a fresh export. Do not treat it as pixel-verified.

## Run and review

```sh
flutter pub get
flutter run -d chrome
# Open a catalogue with direct links to every screen:
flutter run -d chrome --dart-define=INITIAL_ROUTE=/screens
flutter test
# Produce 390 × 844 Flutter renders in design/previews:
DESIGN_PREVIEWS=1 flutter test
```

`previews/` contains the actual Flutter renders used for visual review. The
reference width is 390 logical pixels. Other phone widths scale proportionally;
large windows show a centered mobile canvas. Content panels scroll under fixed
navigation and checkout controls. Some original frames crop content (notably
registration and confirmation); scrolling exposes the remaining controls.

## Screen map

| Route | Figma node |
| --- | --- |
| `/` | 5:6 |
| `/onboarding/food` | 5:42 |
| `/onboarding/nearby` | 10:4166 |
| `/onboarding/impact` | 10:4212 |
| `/login` | 5:91 |
| `/register` | 5:181 |
| `/home` | 5:304 |
| `/search` | 5:564 |
| `/notifications` | 5:829 |
| `/profile` | 5:961 |
| `/settings` | 5:1181 |
| `/location` | 5:1353 |
| `/history` | 10:3515 |
| `/store` | 10:3617 |
| `/product` | 10:3721 |
| `/cart` | 10:3827 |
| `/checkout` | 10:3928 |
| `/order-confirm` | 10:4007 |

`/saved` adds an interactive saved-products view using the search card design.
Existing `/inventory`, `/community`, and `/order` links remain supported.

## Editing

- `lib/widgets/figma_layout.dart`: shared native Flutter layout, text, local SVG
  and image widgets. No webview and no screenshots used as entire screens.
- `lib/pages/design_page.dart`: route catalogue, interaction bindings, local
  preview state and design-node overrides for forms, filtering and quantities.
- `assets/figma/screens.json`: compiled layout data with original Figma node IDs.
- `design/figma/*.txt`: reference JSX supplied by Figma, retained for traceability.
- `tool/import_figma.py`: converts reference geometry/styles to Flutter data.
  Run `python3 tool/import_figma.py` to rebuild the layout bundle. Use
  `--download` to refresh images and fonts while the source URLs remain valid
  (requires Python fontTools). The application itself uses only bundled files.

All 131 original exported SVG/PNG assets and the Plus Jakarta Sans weights
400–800 are local. The font's OFL license is included. Native emoji follow the
platform's emoji font, so Android and Apple may draw them differently. The
screenshot tests use the installed Apple emoji font on macOS without distributing
that proprietary font. The map panel intentionally retains the source's `harta`
placeholder; the supplied Figma artboard contains no real map artwork.

## Behavior and limits

This is a UI preview with seeded design data, not a completed commerce backend.
Navigation, editable form fields, search/category/price filtering, favorites,
quantity steppers, checkout totals, payment selection and notification toggles
work locally. Authentication, actual payments, external maps, promo validation
and account changes are not connected. Settings are session-local; no operating
system notification settings are changed. Checkout navigation sends no charge.

All 24 widget checks cover screen rendering/assets, onboarding navigation,
search results, cart/checkout totals, settings toggles and 320/430 px widths.
The legacy unused Dart files have pre-existing analyzer lints; the new UI is
analyzed separately as well as through a full project analysis.
