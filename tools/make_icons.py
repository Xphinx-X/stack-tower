#!/usr/bin/env python3
"""Generate the launcher icon set for Stack Tower (no external dependencies).

Produces:
  icon.png                 512x512 rounded-square app icon
  icon_foreground.png      512x512 adaptive foreground (transparent, safe-zone)
  icon_background.png      512x512 adaptive background (gradient only)
"""

import math
import os
import struct
import zlib

SIZE = 512
OUT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PALETTE = [
    (0.98, 0.36, 0.42),  # coral
    (0.99, 0.70, 0.30),  # amber
    (0.32, 0.90, 0.66),  # mint
    (0.32, 0.72, 1.00),  # sky
    (0.72, 0.55, 1.00),  # violet
]


class Canvas:
    def __init__(self, size):
        self.size = size
        self.buf = bytearray(size * size * 4)

    def blend(self, x, y, rgb, alpha):
        if alpha <= 0.0:
            return
        a = min(1.0, alpha)
        i = (y * self.size + x) * 4
        b = self.buf
        b[i] = int(b[i] * (1.0 - a) + rgb[0] * 255.0 * a)
        b[i + 1] = int(b[i + 1] * (1.0 - a) + rgb[1] * 255.0 * a)
        b[i + 2] = int(b[i + 2] * (1.0 - a) + rgb[2] * 255.0 * a)
        b[i + 3] = int(b[i + 3] * (1.0 - a) + 255.0 * a)

    def fill_gradient(self, top, bottom, glow=None, glow_pos=(0.5, 0.42)):
        for y in range(self.size):
            t = y / (self.size - 1)
            for x in range(self.size):
                c = [top[k] + (bottom[k] - top[k]) * t for k in range(3)]
                if glow:
                    dx = (x / (self.size - 1)) - glow_pos[0]
                    dy = (y / (self.size - 1)) - glow_pos[1]
                    d = math.sqrt(dx * dx + dy * dy)
                    f = max(0.0, 1.0 - d / 0.72) ** 2
                    for k in range(3):
                        c[k] += glow[k] * f
                self.blend(x, y, c, 1.0)

    def rounded_rect(self, cx, cy, hw, hh, radius, rgb, alpha=1.0, shadow=None):
        if shadow:
            self.rounded_rect(cx, cy + shadow[0], hw, hh, radius, shadow[1], shadow[2])
        x0, x1 = int(cx - hw) - 2, int(cx + hw) + 3
        y0, y1 = int(cy - hh) - 2, int(cy + hh) + 3
        for y in range(max(0, y0), min(self.size, y1)):
            for x in range(max(0, x0), min(self.size, x1)):
                px, py = x + 0.5, y + 0.5
                qx = abs(px - cx) - hw + radius
                qy = abs(py - cy) - hh + radius
                sd = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - radius
                cov = min(1.0, max(0.0, 0.5 - sd))
                self.blend(x, y, rgb, cov * alpha)

    def save(self, path):
        raw = bytearray()
        stride = self.size * 4
        for y in range(self.size):
            raw.append(0)
            raw += self.buf[y * stride:(y + 1) * stride]

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.size, self.size, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)
        print("wrote", path, len(png), "bytes")


def draw_tower(canvas, scale=1.0, center_y=0.5, gap=8.0, radius=16.0):
    widths = [300.0, 256.0, 212.0, 168.0, 124.0]
    height = 62.0
    total = len(widths) * height + (len(widths) - 1) * gap
    base_y = center_y * canvas.size + total * 0.5
    cx = canvas.size * 0.5
    for i, w in enumerate(widths):
        cy = base_y - i * (height + gap) - height * 0.5
        w *= scale
        h = height * scale
        col = PALETTE[i % len(PALETTE)]
        canvas.rounded_rect(cx, cy, w * 0.5, h * 0.5, radius * scale, col,
                            shadow=(6.0 * scale, (0.0, 0.0, 0.0), 0.28))
        # glossy top edge
        inset = 7.0 * scale
        canvas.rounded_rect(cx, cy - h * 0.5 + inset + (h * 0.22) * 0.5,
                            w * 0.5 - inset, (h * 0.22) * 0.5, max(2.0, radius * scale * 0.65),
                            [min(1.0, c + 0.35) for c in col], alpha=0.55)


def main():
    # Main icon: rounded square background + tower
    icon = Canvas(SIZE)
    icon.rounded_rect(SIZE / 2, SIZE / 2, SIZE / 2 - 8, SIZE / 2 - 8, 108,
                      (0.09, 0.07, 0.21), alpha=1.0)
    inner = Canvas(SIZE)
    inner.rounded_rect(SIZE / 2, SIZE / 2, SIZE / 2 - 8, SIZE / 2 - 8, 108,
                       (0.0, 0.0, 0.0), alpha=0.0)
    # gradient clipped to the rounded square: draw gradient where icon is opaque
    grad = Canvas(SIZE)
    grad.fill_gradient((0.16, 0.11, 0.36), (0.03, 0.03, 0.09), glow=(0.24, 0.13, 0.42))
    mask = Canvas(SIZE)
    mask.rounded_rect(SIZE / 2, SIZE / 2, SIZE / 2 - 8, SIZE / 2 - 8, 108, (1, 1, 1))
    for i in range(3, len(grad.buf), 4):
        icon.buf[i] = grad.buf[i]
    for i in range(0, len(grad.buf), 4):
        a = mask.buf[i + 3] / 255.0
        for k in range(3):
            icon.buf[i + k] = int(grad.buf[i + k] * a + 0x17 * (1 - a))
        icon.buf[i + 3] = 255
    draw_tower(icon, scale=1.0, center_y=0.56)
    icon.save(os.path.join(OUT_DIR, "icon.png"))

    # Adaptive foreground: tower only, inside the safe zone, transparent bg
    fg = Canvas(SIZE)
    draw_tower(fg, scale=0.74, center_y=0.5, radius=18.0)
    fg.save(os.path.join(OUT_DIR, "icon_foreground.png"))

    # Adaptive background: plain gradient
    bg = Canvas(SIZE)
    bg.fill_gradient((0.16, 0.11, 0.36), (0.03, 0.03, 0.09), glow=(0.24, 0.13, 0.42))
    bg.save(os.path.join(OUT_DIR, "icon_background.png"))


if __name__ == "__main__":
    main()
