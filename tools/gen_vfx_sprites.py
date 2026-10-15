#!/usr/bin/env python3
"""gen_vfx_sprites.py - generate the muted VFX sprite set with Pillow.

Outputs into assets/sprites/vfx/:
  spark.png  64x64  4-point sparkle (move / piece landed)
  burst.png  96x96  expanding ring    (capture)
  poof.png   80x80  soft cloud        (piece sent back to pen)

Palette is deliberately muted (cream / pumpkin orange / dusty violet):
no neon, no cyan - enforced later by tools/audit_palette.py.
All shapes are drawn at 4x and downsampled with LANCZOS for smooth edges.
Deterministic: no randomness.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "vfx"
SS = 4  # supersample factor

CREAM = (243, 233, 200)
ORANGE = (232, 134, 46)
ORANGE_SOFT = (232, 134, 46, 120)
VIOLET = (107, 78, 142)
VIOLET_PALE = (150, 128, 180)


def canvas(px: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (px * SS, px * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def finish(img: Image.Image, px: int, name: str) -> None:
    out = img.resize((px, px), Image.LANCZOS)
    out.save(OUT / name)
    print(f"  {name} ({px}x{px})")


def diamond(d: ImageDraw.ImageDraw, cx: float, cy: float, w: float, h: float, fill) -> None:
    d.polygon([(cx, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2), (cx - w / 2, cy)], fill=fill)


def gen_spark() -> None:
    px = 64
    img, d = canvas(px)
    c = px * SS / 2
    spike_w = px * SS * 0.14
    spike_h = px * SS * 0.46
    # tall N/S and wide E/W spikes, cream core
    d.polygon([(c, c - spike_h), (c + spike_w, c), (c, c + spike_h), (c - spike_w, c)], fill=ORANGE_SOFT)
    d.polygon([(c, c - spike_h), (c + spike_w * 0.45, c), (c, c + spike_h), (c - spike_w * 0.45, c)],
              fill=(232, 134, 46, 200))
    d.polygon([(c - spike_h, c), (c, c + spike_w), (c + spike_h, c), (c, c - spike_w)], fill=ORANGE_SOFT)
    d.polygon([(c - spike_h, c), (c, c + spike_w * 0.45), (c + spike_h, c), (c, c - spike_w * 0.45)],
              fill=(232, 134, 46, 200))
    r = px * SS * 0.10
    d.ellipse([c - r, c - r, c + r, c + r], fill=CREAM)
    d.ellipse([c - r * 0.5, c - r * 0.5, c + r * 0.5, c + r * 0.5], fill=(255, 250, 235))
    finish(img, px, "spark.png")


def gen_burst() -> None:
    px = 96
    img, d = canvas(px)
    c = px * SS / 2
    outer = px * SS * 0.46
    width = px * SS * 0.075
    # soft inner glow
    r = px * SS * 0.26
    d.ellipse([c - r, c - r, c + r, c + r], fill=(232, 134, 46, 60))
    # main ring (two passes for a soft edge)
    d.ellipse([c - outer, c - outer, c + outer, c + outer], outline=ORANGE, width=int(width))
    d.ellipse([c - outer, c - outer, c + outer, c + outer], outline=(232, 134, 46, 150), width=int(width * 0.5))
    # 8 short radial ticks
    tick = px * SS * 0.07
    for k in range(8):
        import math
        a = k * math.pi / 4.0
        r0, r1 = outer * 1.02, outer + tick
        d.line([(c + r0 * math.cos(a), c + r0 * math.sin(a)),
                (c + r1 * math.cos(a), c + r1 * math.sin(a))],
               fill=(232, 134, 46, 190), width=int(width * 0.45))
    img = img.filter(ImageFilter.GaussianBlur(radius=SS * 0.6))
    finish(img, px, "burst.png")


def gen_poof() -> None:
    px = 80
    img, d = canvas(px)
    c = px * SS / 2
    blobs = [
        (-0.22, -0.05, 0.20, VIOLET_PALE),
        (0.22, 0.02, 0.18, VIOLET),
        (0.0, -0.16, 0.19, VIOLET_PALE),
        (-0.10, 0.14, 0.16, VIOLET),
        (0.12, -0.10, 0.15, VIOLET_PALE),
        (-0.02, 0.04, 0.17, (150, 128, 180, 110)),
    ]
    for dx, dy, r, col in blobs:
        x, y, rr = c + dx * px * SS, c + dy * px * SS, r * px * SS
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)
    img = img.filter(ImageFilter.GaussianBlur(radius=SS * 1.2))
    finish(img, px, "poof.png")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    gen_spark()
    gen_burst()
    gen_poof()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
