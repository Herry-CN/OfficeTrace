from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "public" / "feeds"
W, H = 640, 400


def make_dog_frames(count: int = 24) -> list[Image.Image]:
    frames: list[Image.Image] = []
    random.seed(7)
    for i in range(count):
        img = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(img)
        bob = int(math.sin(i / 3) * 8)
        for y in range(H):
            t = y / H
            d.line(
                [(0, y), (W, y)],
                fill=(int(18 + t * 40), int(28 + t * 55), int(38 + t * 30)),
            )
        base = 210 + bob
        d.polygon([(0, H), (0, base + 40), (W, base + 10), (W, H)], fill=(42, 48, 28))
        d.polygon(
            [(W * 0.35, H), (W * 0.45, base + 20), (W * 0.55, base + 20), (W * 0.7, H)],
            fill=(70, 62, 40),
        )
        offset = (i * 14) % 80
        for x in range(-40 + offset, W + 40, 80):
            d.rectangle([x, base - 50 + bob, x + 8, base + 30 + bob], fill=(90, 95, 70))
            d.line(
                [(x, base - 30 + bob), (x + 70, base - 25 + bob)],
                fill=(120, 125, 90),
                width=2,
            )
        for sx, sh in [(80, 70), (200, 90), (420, 60), (540, 100)]:
            d.rectangle([sx, base - sh + bob, sx + 50, base + bob], fill=(30, 40, 48))
            d.rectangle(
                [sx + 10, base - sh + 15 + bob, sx + 22, base - sh + 30 + bob],
                fill=(180, 200, 90),
            )
        px = int(W * 0.62 + math.sin(i / 5) * 20)
        py = base - 35 + bob
        d.ellipse([px - 10, py - 28, px + 10, py], fill=(20, 20, 20))
        d.rectangle([px - 8, py, px + 8, py + 30], fill=(15, 15, 15))
        for _ in range(120):
            x = random.randint(0, W - 1)
            y = random.randint(0, H - 1)
            r, g, b = img.getpixel((x, y))
            c = random.randint(0, 40)
            img.putpixel((x, y), (min(255, r + c // 2), min(255, g + c // 2), min(255, b + c // 3)))
        for y in range(0, H, 3):
            d.line([(0, (y + i) % H), (W, (y + i) % H)], fill=(0, 0, 0))
        frames.append(img.resize((480, 300), Image.Resampling.BILINEAR))
    return frames


def make_drone_frames(count: int = 24) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for i in range(count):
        img = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(img)
        for y in range(H):
            t = y / H
            d.line([(0, y), (W, y)], fill=(int(20 + t * 30), int(50 + t * 40), int(35 + t * 25)))
        off = i * 10
        for yy in range(-40, H + 40, 60):
            y = yy + (off % 60)
            d.rectangle([0, y, W, y + 28], fill=(34, 70, 40))
        rx = int(W * 0.4 + math.sin(i / 8) * 30)
        d.polygon([(rx, 0), (rx + 70, 0), (rx + 140, H), (rx - 20, H)], fill=(55, 55, 50))
        for cx, cy, cw, ch in [(100, 80, 90, 50), (300, 120, 110, 40), (480, 60, 80, 70)]:
            d.rectangle([cx, cy + (i % 3), cx + cw, cy + ch], outline=(200, 180, 80), width=2)
            d.rectangle([cx + 2, cy + 2, cx + cw - 2, cy + ch - 2], fill=(40, 55, 45))
        d.ellipse([330 + i % 5, 170, 350 + i % 5, 200], outline=(255, 60, 60), width=2)
        for y in range(0, H, 3):
            d.line([(0, (y + i * 2) % H), (W, (y + i * 2) % H)], fill=(0, 0, 0))
        frames.append(img.resize((480, 300), Image.Resampling.BILINEAR))
    return frames


def to_thermal(frames: list[Image.Image]) -> list[Image.Image]:
    out: list[Image.Image] = []
    for fr in frames:
        gray = fr.convert("L")
        therm = Image.new("RGB", gray.size)
        px = gray.load()
        tp = therm.load()
        w, h = gray.size
        for y in range(h):
            for x in range(w):
                v = px[x, y]
                if v > 160:
                    tp[x, y] = (255, min(255, 80 + (v - 160) * 3), 20)
                elif v > 100:
                    tp[x, y] = (255, 140 + (v - 100), 40)
                elif v > 60:
                    tp[x, y] = (180, 40, 120)
                else:
                    tp[x, y] = (20, 10, 40)
        out.append(therm)
    return out


def save_gif(path: Path, frames: list[Image.Image], duration: int) -> None:
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        optimize=False,
    )
    print(path.name, path.stat().st_size)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    dog = make_dog_frames()
    drone = make_drone_frames()
    save_gif(OUT / "robot-dog-live.gif", dog, 70)
    save_gif(OUT / "robot-dog-thermal.gif", to_thermal(dog), 70)
    save_gif(OUT / "drone-live.gif", drone, 80)
    save_gif(OUT / "drone-thermal.gif", to_thermal(drone), 80)


if __name__ == "__main__":
    main()
