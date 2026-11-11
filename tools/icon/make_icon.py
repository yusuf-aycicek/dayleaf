"""Generates every Dayleaf launcher icon from one parametric design.

    python tools/icon/make_icon.py

Outputs:
  docs/store/icon-512.png                      Play Store icon (512x512, opaque)
  android/app/src/main/res/mipmap-*/ic_launcher.png              legacy icon (API 24-25)
  android/app/src/main/res/mipmap-*/ic_launcher_{background,foreground,monochrome}.png
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml     adaptive icon
  docs/store/icon-adaptive-preview.png         adaptive layers under a circle mask

The design lives in a 512x512 coordinate space. To recolour or move something,
change the constants below and run the script again. Needs only Pillow.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / 'assets/fonts/BricolageGrotesque-Variable.ttf'
RES = ROOT / 'android/app/src/main/res'
STORE = ROOT / 'docs/store'

# --- design (512 x 512 space) -------------------------------------------------
GROUND = '#F2EDE4'
PINK = '#FF5C8A'  # left, top, diameter
PINK_CIRCLE = (70, 96, 270)
BLUE = '#3D7DD8'
BLUE_CIRCLE = (190, 170, 250)
INK = '#1A1A1A'
LETTER = 'd'
WEIGHT = 800
LETTER_HEIGHT = 330  # ink height of the glyph
LETTER_TOP = 52  # ink top
MISREG = '#FF5C8A'  # print-misregistration copy under the letter
MISREG_OFFSET = (7, 7)
GRAIN = 7  # grain strength in 0-255 levels (about one standard deviation)

# --- adaptive icon -------------------------------------------------------------
CANVAS_DP = 108
SAFE_DIAMETER_DP = 66
SAFE_MARGIN = 0.9  # keep the ink slightly inside the safe circle

SS = 4  # supersampling factor
LEGACY_DP = 48
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def font_for(height_px):
    """Font sized so the glyph ink is `height_px` tall."""
    probe = ImageFont.truetype(str(FONT), 1000)
    probe.set_variation_by_axes([96, WEIGHT, 100])
    b = probe.getbbox(LETTER)
    f = ImageFont.truetype(str(FONT), max(1, round(1000 * height_px / (b[3] - b[1]))))
    f.set_variation_by_axes([96, WEIGHT, 100])
    return f


class Frame:
    """Maps design coordinates to a canvas of `size` pixels."""

    def __init__(self, size, k, anchor=(256, 256)):
        self.size, self.k, self.anchor = size, k, anchor

    def pt(self, x, y):
        return ((x - self.anchor[0]) * self.k + self.size / 2,
                (y - self.anchor[1]) * self.k + self.size / 2)


def circle_layer(frame, color, spec):
    left, top, d = spec
    x0, y0 = frame.pt(left, top)
    x1, y1 = frame.pt(left + d, top + d)
    im = Image.new('RGB', (frame.size, frame.size), 'white')
    ImageDraw.Draw(im).ellipse([x0, y0, x1, y1], fill=color)
    return im


def background(frame):
    im = Image.new('RGB', (frame.size, frame.size), GROUND)
    im = ImageChops.multiply(im, circle_layer(frame, PINK, PINK_CIRCLE))
    return ImageChops.multiply(im, circle_layer(frame, BLUE, BLUE_CIRCLE))


def letter_mask(frame, dx=0, dy=0):
    f = font_for(LETTER_HEIGHT * frame.k)
    b = f.getbbox(LETTER)
    w = b[2] - b[0]
    x, y = frame.pt(256 + dx, LETTER_TOP + dy)
    mask = Image.new('L', (frame.size, frame.size), 0)
    ImageDraw.Draw(mask).text((x - w / 2 - b[0], y - b[1]), LETTER, font=f, fill=255)
    return mask


def foreground(frame, misreg=True):
    im = Image.new('RGBA', (frame.size, frame.size), (0, 0, 0, 0))
    if misreg:
        im.paste(MISREG, mask=letter_mask(frame, *MISREG_OFFSET))
    im.paste(INK, mask=letter_mask(frame))
    return im


def grain(im, seed_size):
    """Adds print grain at the final resolution (alpha stays as it is)."""
    noise = Image.effect_noise(im.size, 64).point(
        lambda v: max(0, min(255, round(128 + (v - 128) * GRAIN / 64))))
    rgb = im.convert('RGB')
    rgb = ImageChops.add(rgb, Image.merge('RGB', [noise] * 3), 1, -128)
    if im.mode == 'RGBA':
        rgb.putalpha(im.getchannel('A'))
    return rgb


def render(size, k, anchor, layer):
    big = Frame(size * SS, k * SS, anchor)
    return layer(big).resize((size, size), Image.LANCZOS)


def ink_extent():
    """Ink bounding-box centre and the farthest ink pixel from it (design px)."""
    frame = Frame(512, 1)
    mask = ImageChops.lighter(letter_mask(frame), letter_mask(frame, *MISREG_OFFSET))
    x0, y0, x1, y1 = mask.getbbox()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    px = mask.load()
    far = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y] > 96:
                far = max(far, ((x + .5 - cx) ** 2 + (y + .5 - cy) ** 2) ** .5)
    return (cx, cy), far


def main():
    STORE.mkdir(parents=True, exist_ok=True)

    # Play Store icon: the design as drawn, opaque.
    play = grain(render(512, 1, (256, 256), lambda f: Image.alpha_composite(
        background(f).convert('RGBA'), foreground(f))), 512)
    play.convert('RGB').convert('RGBA').save(STORE / 'icon-512.png')

    # Adaptive icon: centre on the ink and scale everything so the letter and
    # its misregistered copy fit the 66dp safe circle of the 108dp canvas.
    anchor, far = ink_extent()
    dp_per_px = SAFE_DIAMETER_DP / 2 * SAFE_MARGIN / far
    print(f'adaptive scale: {dp_per_px * 512 / CANVAS_DP:.3f} of full bleed')

    for name, d in DENSITIES.items():
        out = RES / f'mipmap-{name}'
        out.mkdir(exist_ok=True)
        size = round(CANVAS_DP * d)
        k = dp_per_px * d
        grain(render(size, k, anchor, background), size).save(out / 'ic_launcher_background.png')
        grain(render(size, k, anchor, foreground), size).save(out / 'ic_launcher_foreground.png')
        mono = render(size, k, anchor, lambda f: foreground(f, misreg=False))
        white = Image.new('RGBA', mono.size, (255, 255, 255, 0))
        white.putalpha(mono.getchannel('A'))
        white.save(out / 'ic_launcher_monochrome.png')

        # Legacy launchers (API 24-25): the full design on a rounded square.
        size = round(LEGACY_DP * d)
        legacy = grain(render(size, size / 512, (256, 256), lambda f: Image.alpha_composite(
            background(f).convert('RGBA'), foreground(f))), size)
        corner = Image.new('L', (size * SS, size * SS), 0)
        ImageDraw.Draw(corner).rounded_rectangle(
            [0, 0, size * SS - 1, size * SS - 1], radius=size * SS * 0.22, fill=255)
        legacy.putalpha(corner.resize((size, size), Image.LANCZOS))
        legacy.save(out / 'ic_launcher.png')

    anydpi = RES / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Generated by tools/icon/make_icon.py -->\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n', encoding='utf-8', newline='\n')

    # Preview: xxxhdpi layers under a circle and a squircle-like mask, plus the
    # safe circle outline and the themed (monochrome) look.
    src = RES / 'mipmap-xxxhdpi'
    bg = Image.open(src / 'ic_launcher_background.png').convert('RGBA')
    fg = Image.open(src / 'ic_launcher_foreground.png')
    full = Image.alpha_composite(bg, fg)
    n = full.size[0]
    sheet = Image.new('RGB', (n * 3 + 80, n + 40), '#FFFFFF')
    guide = full.copy()
    r = SAFE_DIAMETER_DP / CANVAS_DP * n / 2
    ImageDraw.Draw(guide).ellipse([n / 2 - r, n / 2 - r, n / 2 + r, n / 2 + r], outline='#00A000', width=2)
    sheet.paste(guide, (20, 20))
    m = Image.new('L', (n, n), 0)
    inset = (CANVAS_DP - 72) / CANVAS_DP * n / 2  # launchers show the middle 72dp
    ImageDraw.Draw(m).ellipse([inset, inset, n - inset, n - inset], fill=255)
    sheet.paste(full, (n + 40, 20), m)
    themed = Image.new('RGBA', (n, n), '#D7E3FF')
    tint = Image.new('RGBA', (n, n), '#1B3A6B')
    tint.putalpha(Image.open(src / 'ic_launcher_monochrome.png').getchannel('A'))
    sheet.paste(Image.alpha_composite(themed, tint), (2 * n + 60, 20), m)
    sheet.save(STORE / 'icon-adaptive-preview.png')


if __name__ == '__main__':
    main()
