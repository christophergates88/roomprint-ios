#!/usr/bin/env python3
"""Turns raw 6.9-inch simulator screenshots into App Store marketing screenshots.

Usage: python3 tools/frame_shots.py <raw-dir> <out-dir>

Raw files come from CI (ci-results branch, shots/*.png, 1320 x 2868). Output is 1320 x 2868 PNG, the
size App Store Connect takes for the 6.9-inch display: navy background, a bold caption, the screen below.
Needs Pillow and the Inter Display font (any bold sans works; set RP_FONT to a .ttf/.otf path).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
NAVY = (22, 38, 58)
NAVY_2 = (30, 50, 73)
VELLUM = (243, 238, 226)
MIST = (201, 210, 221)
RECORD = (229, 83, 61)

# (raw file, output name, headline, subline) in App Store order: the first three matter most.
SHOTS = [
    ("review.png", "01-film-a-room.png", "Film a room.\nGet the list.", "Every item named and valued. You approve it."),
    ("home.png", "02-whole-home.png", "Know what your\nhome holds.", "Every room, every item, one total."),
    ("pdf.png", "03-claim-ready.png", "A claim-ready\nrecord.", "One tap to the PDF your insurer asks for."),
    ("room.png", "04-proof.png", "Proof for\nevery item.", "Photos, brands, serial numbers, receipts."),
    ("scan.png", "05-walkthrough.png", "One slow\nwalkthrough.", "30 seconds to 3 minutes a room."),
    ("homes.png", "06-private.png", "Private\nby design.", "Your records stay on your iPhone."),
]


def font(size, weight="ExtraBold"):
    path = os.environ.get("RP_FONT")
    candidates = [path] if path else []
    candidates += [
        f"/usr/share/fonts/opentype/inter/InterDisplay-{weight}.otf",
        f"/usr/share/fonts/opentype/inter/Inter-{weight}.otf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] + radius], radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def frame(raw_path, out_path, headline, subline):
    shot = Image.open(raw_path).convert("RGB")
    canvas = Image.new("RGB", (W, H), NAVY)
    draw = ImageDraw.Draw(canvas)
    # Soft lighter band behind the screen.
    for y in range(H):
        t = max(0.0, (y - 500) / (H - 500))
        c = tuple(int(NAVY[i] + (NAVY_2[i] - NAVY[i]) * t) for i in range(3))
        draw.line([(0, y), (W, y)], fill=c)

    # Caption.
    x0, y = 96, 128
    draw.ellipse([x0, y + 10, x0 + 30, y + 40], fill=RECORD)
    draw.text((x0 + 48, y + 2), "ROOMPRINT", font=font(38, "Bold"), fill=MIST)
    y += 92
    head = font(118)
    for line in headline.split("\n"):
        draw.text((x0, y), line, font=head, fill=VELLUM)
        y += 132
    y += 14
    draw.text((x0, y), subline, font=font(48, "Medium"), fill=MIST)
    top = y + 108

    # The screen: scaled to fit below the caption, bleeding off the bottom edge.
    width = 1090
    scale = width / shot.size[0]
    height = int(shot.size[1] * scale)
    screen = shot.resize((width, height), Image.LANCZOS)
    left = (W - width) // 2
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([left - 6, top + 18, left + width + 6, top + height + 60], 84, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.paste(Image.new("RGB", (W, H), (8, 14, 22)), (0, 0), shadow)
    bezel = Image.new("RGB", (width + 28, height + 28), (12, 20, 31))
    canvas.paste(rounded(bezel, 92), (left - 14, top - 14), rounded(bezel, 92))
    canvas.paste(rounded(screen, 80), (left, top), rounded(screen, 80))
    canvas.save(out_path, "PNG", optimize=True)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    raw, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    made = 0
    for src, name, headline, subline in SHOTS:
        path = os.path.join(raw, src)
        if not os.path.exists(path):
            print("missing", src)
            continue
        frame(path, os.path.join(out, name), headline, subline)
        made += 1
        print("made", name)
    print(f"{made} screenshots in {out}")


if __name__ == "__main__":
    main()
