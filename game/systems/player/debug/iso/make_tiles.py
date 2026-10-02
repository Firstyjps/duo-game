#!/usr/bin/env python3
"""สร้าง tile isometric ชั่วคราวสำหรับลานวัดทดสอบ (64x32 diamond) — ไม่ใช่ art จริง
รัน: python3 game/systems/player/debug/iso/make_tiles.py → iso_tiles.png (แถวเดียว ช่อง 64x64)
ช่อง: 0 หินพื้น · 1 หินพื้น+รอยทองคินสึงิ · 2 หินมีมอส · 3 บล็อกกำแพง (สูง 32)"""
import random
from pathlib import Path
from PIL import Image, ImageDraw

W, H, CELL = 64, 32, 64
OUT = Path(__file__).with_name("iso_tiles.png")
STONE = [(74, 72, 86), (82, 80, 95), (68, 66, 80)]
EDGE = (46, 44, 58)
GOLD = (232, 182, 72)
MOSS = (70, 96, 70)


def in_diamond(x: int, y: int, top: int) -> bool:
    cx, cy = W / 2 - 0.5, top + H / 2 - 0.5
    return abs(x - cx) / (W / 2) + abs(y - cy) / (H / 2) <= 1.0


def floor(img: Image.Image, ox: int, top: int, rng: random.Random, kind: int) -> None:
    px = img.load()
    for y in range(top, top + H):
        for x in range(W):
            if not in_diamond(x, y, top):
                continue
            edge = not (in_diamond(x - 1, y, top) and in_diamond(x + 1, y, top)
                        and in_diamond(x, y - 1, top) and in_diamond(x, y + 1, top))
            c = EDGE if edge else rng.choice(STONE)
            if kind == 2 and not edge and rng.random() < 0.35:
                c = MOSS
            px[ox + x, y] = c + (255,)
    if kind == 1:  # รอยร้าวทอง: เดินสุ่มจากซ้ายไปขวาในรูปเพชร
        x, y = 14, top + 16
        while x < 50:
            if in_diamond(x, y, top):
                px[ox + x, y] = GOLD + (255,)
            x += 1
            y += rng.choice((-1, 0, 0, 1))
            y = max(top + 8, min(top + 24, y))


def block(img: Image.Image, ox: int, rng: random.Random) -> None:
    d = ImageDraw.Draw(img)
    # ด้านซ้าย/ขวา (สูง 32) ใต้หน้าบน
    d.polygon([(ox, 16), (ox + 32, 32), (ox + 32, 63), (ox, 47)], fill=(52, 50, 64))
    d.polygon([(ox + 32, 32), (ox + 63, 16), (ox + 63, 47), (ox + 32, 63)], fill=(40, 38, 50))
    floor(img, ox, 0, rng, 0)


def main() -> None:
    rng = random.Random(7)
    img = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
    for i in range(3):  # พื้น: วางหน้าเพชรที่ครึ่งล่างของช่อง (origin = กลางเพชร)
        floor(img, CELL * i, 32, rng, i)
    block(img, CELL * 3, rng)
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
