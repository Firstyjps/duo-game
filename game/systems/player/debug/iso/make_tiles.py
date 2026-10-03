#!/usr/bin/env python3
"""ประกอบ tile isometric ลานวัด (PixelLab, ต้นฉบับใน kintsugi/assets/tiles_iso/) → iso_tiles.png
แถวเดียว ช่อง 64x64: 0 หินพื้น · 1 หินพื้น+รอยทองคินสึงิ · 2 หินมีมอส · 3 บล็อกกำแพง
ตำแหน่งในภาพ (ใช้ตั้ง texture_origin ใน iso_courtyard.gd): พื้นบาง = หน้าบนกลางที่ y≈38 · บล็อก = ฐานกลางที่ y=48
รัน: python3 game/systems/player/debug/iso/make_tiles.py"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
SRC = ROOT / "kintsugi/assets/tiles_iso"
OUT = Path(__file__).with_name("iso_tiles.png")
ORDER = ["floor_plain", "floor_kintsugi", "floor_moss", "wall_block"]


def main() -> None:
    img = Image.new("RGBA", (64 * len(ORDER), 64), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        img.alpha_composite(Image.open(SRC / f"{name}.png").convert("RGBA"), (64 * i, 0))
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
