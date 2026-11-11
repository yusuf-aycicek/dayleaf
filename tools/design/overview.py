"""Builds docs/design/catalog/overview.png: one recipe per family.

Run after `flutter test --tags golden --update-goldens`:
    python tools/design/overview.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / 'docs/design/catalog'
FONTS = ROOT / 'assets/fonts'
PICKS = [
    ('dictionary', 'dictionary_ivory'),
    ('terminal', 'terminal_amber'),
    ('calendar', 'calendar_classic'),
    ('wall_calendar', 'wall_calendar_walnut'),
    ('riso', 'riso_pink_blue'),
    ('topo', 'topo_forest'),
    ('halftone', 'halftone_yellow'),
    ('bauhaus', 'bauhaus_classic'),
    ('waves', 'waves_sunset'),
    ('notebook', 'notebook_lined'),
]

book = json.loads((ROOT / 'assets/styles/recipes.json').read_text('utf-8'))
names = {f['id']: f['name']['tr'] for f in book['families']}
TW, TH, GAP, PAD, LAB, COLS = 270, 600, 28, 48, 74, 5
W = PAD * 2 + COLS * TW + (COLS - 1) * GAP
H = PAD + 110 + 2 * (TH + LAB) + GAP + PAD
img = Image.new('RGB', (W, H), '#F4F1EA')
draw = ImageDraw.Draw(img)
title = ImageFont.truetype(str(FONTS / 'InstrumentSerif-Regular.ttf'), 58)
sub = ImageFont.truetype(str(FONTS / 'IBMPlexMono-Regular.ttf'), 20)
fam = ImageFont.truetype(str(FONTS / 'SpaceGrotesk-Variable.ttf'), 26)
fam.set_variation_by_axes([700])
rec = ImageFont.truetype(str(FONTS / 'IBMPlexMono-Regular.ttf'), 18)
draw.text((PAD, PAD - 6), 'Dayleaf · stil kataloğu', font=title, fill='#1B1B1B')
draw.text(
    (PAD, PAD + 66),
    f'Her aileden bir tarif · {len(names)} aile, {len(book["recipes"])} tarif'
    ' · 10 Kasım 2026',
    font=sub,
    fill='#5A564E',
)
for i, (family, recipe) in enumerate(PICKS):
    row, col = divmod(i, COLS)
    x = PAD + col * (TW + GAP)
    y = PAD + 110 + row * (TH + LAB + GAP)
    tile = Image.open(CATALOG / f'{recipe}.png').convert('RGB')
    img.paste(Image.new('RGB', (TW, TH), '#D9D4C8'), (x + 4, y + 5))
    img.paste(tile.resize((TW, TH), Image.LANCZOS), (x, y))
    draw.rectangle([x, y, x + TW - 1, y + TH - 1], outline='#CFC9BC')
    draw.text((x, y + TH + 12), names[family], font=fam, fill='#1B1B1B')
    draw.text((x, y + TH + 46), recipe, font=rec, fill='#5A564E')
img.save(CATALOG / 'overview.png', optimize=True)
