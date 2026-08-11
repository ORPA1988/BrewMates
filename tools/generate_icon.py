#!/usr/bin/env python3
"""Generates the BrewMates app icons.

Outputs (relative to the repo root):
  app/assets/icon/icon.png             1024x1024, dark background + beer mug
  app/assets/icon/icon_foreground.png  1024x1024, mug only on transparency,
                                       centred at ~60 % (Android adaptive-icon
                                       safe zone)

Requires Pillow:  pip install pillow
Run:              python3 tools/generate_icon.py
"""

import math
import os

from PIL import Image, ImageDraw

# ----------------------------------------------------------------------------
# Palette
# ----------------------------------------------------------------------------
BG = (0x1C, 0x14, 0x0F)            # dark background #1C140F
AMBER_TOP = (0xE8, 0xA3, 0x3D)     # mug gradient top #E8A33D
AMBER_BOTTOM = (0xB4, 0x63, 0x2C)  # mug gradient bottom #B4632C
FOAM = (0xFA, 0xF3, 0xE7)          # cream foam #FAF3E7
FOAM_SHADE = (0xED, 0xE0, 0xC8)    # slightly darker foam for depth
GLOW = (0xE8, 0xA3, 0x3D)          # amber glow colour

FINAL = 1024      # output size
SS = 4            # supersampling factor (anti-aliasing)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def vertical_gradient(width, height, top, bottom):
    """RGBA image with a vertical linear gradient."""
    grad = Image.new("RGBA", (width, height))
    px = grad.load()
    for y in range(height):
        c = lerp(top, bottom, y / max(1, height - 1))
        for x in range(width):
            px[x, y] = (*c, 255)
    return grad


def draw_mug(size):
    """Draw the stylised beer mug into a transparent square of `size` px.

    The mug (incl. handle and foam) fills the square almost completely,
    so the caller controls the final scale by resizing/pasting.
    """
    L = size
    img = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def P(v):  # unit coordinate -> pixels
        return v * L

    # -- Handle: thick ring on the right; the body is painted afterwards so
    #    only the right part of the ring remains visible. --------------------
    hcx, hcy = P(0.660), P(0.575)
    r_out, r_in = P(0.190), P(0.112)
    ring = Image.new("L", (L, L), 0)
    rdraw = ImageDraw.Draw(ring)
    rdraw.ellipse([hcx - r_out, hcy - r_out, hcx + r_out, hcy + r_out], fill=255)
    rdraw.ellipse([hcx - r_in, hcy - r_in, hcx + r_in, hcy + r_in], fill=0)
    handle_grad = vertical_gradient(L, L, AMBER_TOP, AMBER_BOTTOM)
    img.paste(handle_grad, (0, 0), ring)

    # -- Mug body: rounded rectangle with amber gradient ---------------------
    bx0, by0, bx1, by1 = P(0.175), P(0.300), P(0.660), P(0.885)
    radius = P(0.070)
    body_mask = Image.new("L", (L, L), 0)
    bdraw = ImageDraw.Draw(body_mask)
    bdraw.rounded_rectangle([bx0, by0, bx1, by1], radius=radius, fill=255)
    body_grad = vertical_gradient(L, L, AMBER_TOP, AMBER_BOTTOM)
    img.paste(body_grad, (0, 0), body_mask)

    # -- Glass highlight: soft light stripe on the left ----------------------
    highlight = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle(
        [P(0.225), P(0.400), P(0.285), P(0.820)],
        radius=P(0.030),
        fill=(0xF6, 0xC9, 0x7A, 110),
    )
    img.alpha_composite(highlight)

    # -- Rising bubbles inside the mug ---------------------------------------
    bubbles = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    bubdraw = ImageDraw.Draw(bubbles)
    for cx, cy, r, alpha in [
        (0.335, 0.760, 0.020, 175),
        (0.425, 0.635, 0.027, 190),
        (0.370, 0.510, 0.017, 160),
    ]:
        bubdraw.ellipse(
            [P(cx - r), P(cy - r), P(cx + r), P(cy + r)],
            fill=(*FOAM, alpha),
        )
    img.alpha_composite(bubbles)

    # -- Foam: overlapping cream circles spilling over the rim ---------------
    foam = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(foam)
    # subtle darker layer underneath for depth
    rr = 0.105
    for cx, cy in [
        (0.245, 0.310), (0.360, 0.290), (0.480, 0.300), (0.585, 0.315),
    ]:
        fdraw.ellipse([P(cx - rr), P(cy - rr), P(cx + rr), P(cy + rr)],
                      fill=(*FOAM_SHADE, 255))
    # main foam blobs (4 overlapping circles over the rim)
    for cx, cy, r in [
        (0.240, 0.285, 0.098),
        (0.355, 0.250, 0.118),
        (0.475, 0.265, 0.103),
        (0.580, 0.290, 0.086),
    ]:
        fdraw.ellipse([P(cx - r), P(cy - r), P(cx + r), P(cy + r)],
                      fill=(*FOAM, 255))
    # a drip spilling over the left edge of the mug
    fdraw.ellipse([P(0.155), P(0.300), P(0.245), P(0.420)], fill=(*FOAM, 255))
    img.alpha_composite(foam)

    return img


def radial_glow(size, center, max_radius, color, peak_alpha):
    """Soft radial glow as an RGBA overlay (computed at low resolution)."""
    small = 256
    overlay = Image.new("RGBA", (small, small), (0, 0, 0, 0))
    px = overlay.load()
    cx, cy = center[0] * small, center[1] * small
    mr = max_radius * small
    for y in range(small):
        for x in range(small):
            d = math.hypot(x - cx, y - cy) / mr
            if d < 1.0:
                a = int(peak_alpha * (1.0 - d) ** 2)
                if a > 0:
                    px[x, y] = (*color, a)
    return overlay.resize((size, size), Image.BICUBIC)


def build_icon():
    """1024x1024 launcher icon: dark bg + glow + mug."""
    S = FINAL * SS
    img = Image.new("RGBA", (S, S), (*BG, 255))
    img.alpha_composite(radial_glow(S, (0.5, 0.42), 0.75, GLOW, 92))

    mug_size = int(S * 0.80)  # mug occupies ~80 % of the canvas
    mug = draw_mug(mug_size)
    ox = (S - mug_size) // 2
    oy = (S - mug_size) // 2 + int(S * 0.015)
    img.alpha_composite(mug, (ox, oy))

    return img.resize((FINAL, FINAL), Image.LANCZOS).convert("RGB")


def build_foreground():
    """1024x1024 adaptive-icon foreground: mug only, ~60 % of the canvas."""
    S = FINAL * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mug_size = int(S * 0.60)  # safe zone for Android adaptive icons
    mug = draw_mug(mug_size)
    ox = (S - mug_size) // 2
    oy = (S - mug_size) // 2
    img.alpha_composite(mug, (ox, oy))
    return img.resize((FINAL, FINAL), Image.LANCZOS)


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(repo_root, "app", "assets", "icon")
    os.makedirs(out_dir, exist_ok=True)

    icon = build_icon()
    icon.save(os.path.join(out_dir, "icon.png"))
    print("wrote", os.path.join(out_dir, "icon.png"))

    fg = build_foreground()
    fg.save(os.path.join(out_dir, "icon_foreground.png"))
    print("wrote", os.path.join(out_dir, "icon_foreground.png"))


if __name__ == "__main__":
    main()
