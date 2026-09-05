# 2D-RPG Art Bible

## Palette
- Primary: #2B2B2B (dark gray)
- Secondary: #4A4A4A (medium gray)
- Accent: #6A6A6A (light gray)
- Highlight: #FFFFFF (white)
- Shadow: #000000 (black)

## Silhouette Rules
- All characters and enemies must have clear, readable silhouettes
- No floating parts without visible connection
- Minimum 2px outline for all sprites
- Distinct shape language per enemy type

## Base Sprite Sizes
- Hero: 64x64 logical pixels (minimum)
- Enemy: 32x32 to 64x64 logical pixels
- Tile: 32x32 logical pixels
- UI icons: 16x16 to 32x32 logical pixels

## Color Variation Rules
- All colors must come from the defined palette
- No more than 3 colors per sprite (plus outline)
- Procedural generation must respect palette constraints
- Darken/lighten by palette steps only

## Font
- English: Default Godot font
- Persian: Vazirmatn (open-license, RTL supported)
- All text must be externalized to locale files