#!/usr/bin/env python3
"""ดึงตัวละคร PixelLab (zip จาก /mcp/characters/<id>/download) → <raw_dir>/<ท่า>/<ทิศ>/frame_NNN.png
+ <raw_dir>/rotations/<ทิศ>.png · เก็บ raw ไว้นอก game/ (Godot ไม่ import) เช่น kintsugi/assets/sprites/hero_iso/
ใช้คู่กับ build_dir_atlas.py · zip คืน 423 ถ้ายังมีท่าที่กำลังสร้าง → รอแล้วรันใหม่"""
import io
import sys
import urllib.request
import zipfile
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: fetch_pixellab_character.py <character_id> <raw_dir>")
    cid, out = sys.argv[1], Path(sys.argv[2])
    url = f"https://api.pixellab.ai/mcp/characters/{cid}/download"
    data = urllib.request.urlopen(url).read()
    n = 0
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            parts = Path(name).parts
            if not name.endswith(".png"):
                continue
            if "animations" in parts:
                rel = Path(*parts[parts.index("animations") + 1:])
            elif "rotations" in parts:
                rel = Path("rotations", parts[-1])
            else:
                continue
            dst = out / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(z.read(name))
            n += 1
    print(f"extracted {n} png → {out}")


if __name__ == "__main__":
    main()
