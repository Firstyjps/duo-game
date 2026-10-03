#!/usr/bin/env python3
"""ประกอบเฟรม PixelLab 8 ทิศ → atlas PNG + SpriteFrames (.tres) สำหรับ DirSprite

ขั้นตอน (ทำซ้ำได้ทุกครั้งที่สร้างท่าใหม่):
  1. ดึงเฟรมดิบ: python3 game/systems/player/tools/fetch_pixellab_character.py <character_id> <raw_dir>
     → <raw_dir>/<ท่า PixelLab>/<ทิศ>/<เลขเฟรม>.png
  2. ประกอบ:   python3 game/systems/player/tools/build_dir_atlas.py --raw <raw_dir> \
                 --out game/systems/player/art/kintsugi_hero --name kintsugi_hero \
                 --anim idle=idle:6:loop --anim walk=walk:10:loop ... [--fix-north-hair]
     --anim <ชื่อในเกม>=<โฟลเดอร์ใน raw>:<fps>:<loop|once>
  3. godot --headless --path game --import

layout atlas: แถว = ท่า × 8 ทิศ (ลำดับ Dir8: south, south-east, east, north-east, north, north-west, west, south-west)
คอลัมน์ = เฟรม · ช่อง 96×96 (--cell; เฟรมเล็กกว่าวางกลางช่อง) · แอนิเมชันใน SpriteFrames ชื่อ "<ท่า>_<ทิศ>"
"""
import argparse
import colorsys
import json
from pathlib import Path

from PIL import Image

DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
# ผมทิศ north ของตัวละคร A ออกมาเป็นเบจแบน → แทนด้วยลาเวนเดอร์ที่ทิศอื่นใช้
HAIR_LIGHT = (225, 223, 253)
HAIR_MID = (189, 187, 252)


def fix_north_hair(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if h * 360 <= 45 and s < 0.25 and v > 0.6:
                c = HAIR_LIGHT if v > 0.78 else HAIR_MID
                px[x, y] = c + (a,)
    return img


def frame_files(folder: Path) -> list[Path]:
    return sorted(folder.glob("*.png"), key=lambda p: int("".join(ch for ch in p.stem if ch.isdigit()) or 0))


def parse_anim(spec: str) -> dict:
    name, rest = spec.split("=", 1)
    src, fps, mode = rest.split(":")
    return {"name": name, "src": src, "fps": float(fps), "loop": mode == "loop"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--name", required=True)
    ap.add_argument("--anim", action="append", required=True, type=parse_anim)
    ap.add_argument("--cell", type=int, default=96)
    ap.add_argument("--fix-north-hair", action="store_true")
    args = ap.parse_args()

    cell = args.cell
    frames: dict[tuple[str, str], list[Image.Image]] = {}
    for anim in args.anim:
        for d in DIRS:
            files = frame_files(args.raw / anim["src"] / d)
            if not files:
                raise SystemExit(f"ไม่มีเฟรม: {args.raw / anim['src'] / d}")
            imgs = []
            for f in files:
                im = Image.open(f).convert("RGBA")
                if im.width > cell or im.height > cell:
                    raise SystemExit(f"{f} ขนาด {im.size} ใหญ่กว่าช่อง {cell} — เพิ่ม --cell")
                if im.size != (cell, cell):  # PixelLab ขยาย canvas รอบตัวเท่ากันทุกด้าน → วางกลางช่อง เท้าตรงกันทุกท่า
                    pad = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
                    pad.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
                    im = pad
                if args.fix_north_hair and d == "north":
                    im = fix_north_hair(im)
                imgs.append(im)
            frames[(anim["name"], d)] = imgs

    cols = max(len(v) for v in frames.values())
    rows = len(args.anim) * len(DIRS)
    atlas = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    meta = {"cell": cell, "dirs": DIRS, "anims": []}
    for ai, anim in enumerate(args.anim):
        meta["anims"].append({**anim, "row": ai * len(DIRS), "frames": len(frames[(anim["name"], DIRS[0])])})
        for di, d in enumerate(DIRS):
            for fi, im in enumerate(frames[(anim["name"], d)]):
                atlas.alpha_composite(im, (fi * cell, (ai * len(DIRS) + di) * cell))

    args.out.mkdir(parents=True, exist_ok=True)
    png = args.out / f"{args.name}.png"
    atlas.save(png)
    (args.out / f"{args.name}.json").write_text(json.dumps(meta, indent=1, ensure_ascii=False))
    write_tres(args.out / f"{args.name}_frames.tres", png, args.anim, frames, cell)
    print(f"wrote {png} ({cols}x{rows} cells) + {args.name}_frames.tres")


def res_path(p: Path) -> str:
    parts = p.resolve().parts
    return "res://" + "/".join(parts[parts.index("game") + 1:])


def write_tres(path: Path, png: Path, anims: list[dict], frames: dict, cell: int) -> None:
    subs: list[str] = []
    anim_blocks: list[str] = []
    for ai, anim in enumerate(anims):
        for di, d in enumerate(DIRS):
            refs = []
            for fi in range(len(frames[(anim["name"], d)])):
                sid = f"a{ai}_{di}_{fi}"
                subs.append(
                    f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                    f"region = Rect2({fi * cell}, {(ai * len(DIRS) + di) * cell}, {cell}, {cell})\n")
                refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
            anim_blocks.append(
                '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": %s\n}'
                % (", ".join(refs), "true" if anim["loop"] else "false", anim["name"], d, anim["fps"]))
    text = (f'[gd_resource type="SpriteFrames" load_steps={len(subs) + 2} format=3]\n\n'
            f'[ext_resource type="Texture2D" path="{res_path(png)}" id="1"]\n\n'
            + "\n".join(subs)
            + "\n[resource]\nanimations = [" + ", ".join(anim_blocks) + "]\n")
    path.write_text(text)


if __name__ == "__main__":
    main()
