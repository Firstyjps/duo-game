#!/usr/bin/env python3
"""
Generate isometric tileset placeholder for dungeon system.
Resolution: 512x128 (8 cols x 4 rows of 64x32 cells).
- Row 0: Floor tiles (64x32)
- Row 1-2: Wall & Door tiles (64x64, size_in_atlas 1x2)
- Row 3: Special / Accent tiles (64x32)
Theme: Japanese mountain temple at night, dark navy/plum slate, gold kintsugi cracks, warm lantern fire.
"""

from PIL import Image, ImageDraw
import math
import os

W, H = 512, 128
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Palette
C_TRANS = (0, 0, 0, 0)
C_INK = (15, 18, 27, 255)
C_NAVY_DARK = (21, 16, 55, 255)
C_NAVY = (28, 21, 77, 255)
C_STONE_DARK = (33, 26, 75, 255)
C_STONE_MID = (46, 38, 102, 255)
C_STONE_LIGHT = (64, 53, 133, 255)
C_STONE_HI = (88, 76, 168, 255)
C_LILAC = (158, 160, 250, 255)

# Kintsugi gold palette
C_GOLD_DARK = (138, 72, 0, 255)
C_GOLD_AMBER = (224, 94, 43, 255)
C_GOLD = (255, 163, 3, 255)
C_GOLD_HI = (255, 220, 100, 255)
C_GOLD_CORE = (255, 255, 204, 255)

# Accent palette
C_RED_DARK = (100, 20, 20, 255)
C_RED = (180, 30, 30, 255)
C_RED_HI = (240, 70, 70, 255)
C_LANTERN_GLOW = (255, 200, 80, 255)
C_LANTERN_HOT = (255, 245, 180, 255)
C_WOOD_DARK = (45, 28, 20, 255)
C_WOOD = (75, 45, 30, 255)


def in_diamond_32(x: int, y: int) -> bool:
    """Return True if (x, y) within a 64x32 diamond."""
    if y < 0 or y >= 32 or x < 0 or x >= 64:
        return False
    if y <= 15:
        return (30 - 2 * y) <= x <= (33 + 2 * y)
    else:
        return (2 * y - 32) <= x <= (95 - 2 * y)


def get_diamond_mask(w=64, h=32):
    mask = []
    for y in range(h):
        row = []
        for x in range(w):
            row.append(in_diamond_32(x, y))
        mask.append(row)
    return mask


DIAMOND_MASK = get_diamond_mask()


def draw_floor_base(ox: int, oy: int, base_col=C_STONE_MID, edge_hi=C_STONE_HI, edge_sh=C_STONE_DARK):
    """Draw a base 64x32 flagstone diamond with bevel edges."""
    for y in range(32):
        for x in range(64):
            if not DIAMOND_MASK[y][x]:
                continue
            # Noise / texture
            noise = ((x * 13 + y * 29) % 17 - 8)
            r = min(255, max(0, base_col[0] + noise))
            g = min(255, max(0, base_col[1] + noise))
            b = min(255, max(0, base_col[2] + noise))
            img.putpixel((ox + x, oy + y), (r, g, b, 255))

    # Bevel top edges (highlight from top-left)
    for y in range(16):
        # Top-left edge
        x_left = 30 - 2 * y
        for dx in range(2):
            if in_diamond_32(x_left + dx, y):
                img.putpixel((ox + x_left + dx, oy + y), edge_hi)
        # Top-right edge
        x_right = 33 + 2 * y
        for dx in range(2):
            if in_diamond_32(x_right - dx, y):
                img.putpixel((ox + x_right - dx, oy + y), edge_sh)

    # Bevel bottom edges (shadow)
    for y in range(16, 32):
        x_left = 2 * y - 32
        for dx in range(2):
            if in_diamond_32(x_left + dx, y):
                img.putpixel((ox + x_left + dx, oy + y), edge_sh)
        x_right = 95 - 2 * y
        for dx in range(2):
            if in_diamond_32(x_right - dx, y):
                img.putpixel((ox + x_right - dx, oy + y), (max(0, edge_sh[0] - 10), max(0, edge_sh[1] - 10), max(0, edge_sh[2] - 10), 255))


def draw_gold_fissure(ox: int, oy: int, points: list):
    """Draw a golden kintsugi crack along point sequence."""
    for i in range(len(points) - 1):
        x0, y0 = points[i]
        x1, y1 = points[i + 1]
        dist = int(math.hypot(x1 - x0, y1 - y0)) + 1
        for step in range(dist + 1):
            t = step / max(1, dist)
            px = int(x0 + (x1 - x0) * t)
            py = int(y0 + (y1 - y0) * t)
            # Outer dark gold glow
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                if in_diamond_32(px + dx, py + dy):
                    img.putpixel((ox + px + dx, oy + py + dy), C_GOLD_DARK)
            # Amber gold
            if in_diamond_32(px, py):
                img.putpixel((ox + px, oy + py), C_GOLD)
            # Highlights along line
            if step % 2 == 0 and in_diamond_32(px, py):
                img.putpixel((ox + px, oy + py), C_GOLD_CORE)


# -------------------------------------------------------------
# 1. FLOOR TILES (Row 0, y=0..31)
# -------------------------------------------------------------

# Col 0: Plain temple stone flagstone
draw_floor_base(0 * 64, 0)

# Col 1: Weathered stone with pavers & subtle fissures
draw_floor_base(1 * 64, 0, base_col=C_NAVY)
# Paver seam
for y in range(8, 24):
    x = int(32 + (y - 16) * 0.8)
    if in_diamond_32(x, y):
        img.putpixel((1 * 64 + x, y), C_STONE_DARK)
        img.putpixel((1 * 64 + x + 1, y), C_STONE_LIGHT)

# Col 2: Kintsugi stone variant 1 (branching fissure)
draw_floor_base(2 * 64, 0)
draw_gold_fissure(2 * 64, 0, [
    (12, 10), (22, 13), (32, 16), (42, 18), (52, 22)
])
draw_gold_fissure(2 * 64, 0, [
    (32, 16), (28, 22), (25, 27)
])

# Col 3: Kintsugi stone variant 2 (jagged lightning crack)
draw_floor_base(3 * 64, 0, base_col=C_NAVY_DARK)
draw_gold_fissure(3 * 64, 0, [
    (30, 2), (26, 8), (34, 12), (30, 18), (38, 23), (32, 29)
])
draw_gold_fissure(3 * 64, 0, [
    (34, 12), (44, 14), (50, 12)
])

# Col 4: Ornate temple diamond seal
draw_floor_base(4 * 64, 0, base_col=C_STONE_MID)
for r in [6, 12]:
    for y in range(32):
        for x in range(64):
            d = abs(x - 31.5) / 2.0 + abs(y - 15.5)
            if abs(d - r) < 0.6 and in_diamond_32(x, y):
                img.putpixel((4 * 64 + x, y), C_GOLD)
# Center gold stud
img.putpixel((4 * 64 + 31, 15), C_GOLD_CORE)
img.putpixel((4 * 64 + 32, 15), C_GOLD_CORE)
img.putpixel((4 * 64 + 31, 16), C_GOLD_CORE)
img.putpixel((4 * 64 + 32, 16), C_GOLD_CORE)

# Col 5: Cobblestone / courtyard pavers
draw_floor_base(5 * 64, 0, base_col=C_NAVY)
for cy in [8, 16, 24]:
    for cx in [16, 32, 48]:
        for dy in range(-2, 3):
            for dx in range(-4, 5):
                x = cx + dx
                y = cy + dy
                if in_diamond_32(x, y) and (abs(dx) == 4 or abs(dy) == 2):
                    img.putpixel((5 * 64 + x, y), C_STONE_DARK)

# Col 6: Doorway threshold tile (indicates passage)
draw_floor_base(6 * 64, 0, base_col=C_STONE_DARK)
for y in range(32):
    for x in range(64):
        if in_diamond_32(x, y) and (y in (10, 11, 20, 21)):
            img.putpixel((6 * 64 + x, y), C_GOLD_AMBER)

# Col 7: Spawn seal / ritual rune
draw_floor_base(7 * 64, 0, base_col=C_INK)
for y in range(32):
    for x in range(64):
        if not in_diamond_32(x, y):
            continue
        rad = math.hypot((x - 31.5) / 2.0, y - 15.5)
        if 8.5 < rad < 10.5:
            img.putpixel((7 * 64 + x, y), (140, 40, 70, 255))
        elif 4.0 < rad < 5.5:
            img.putpixel((7 * 64 + x, y), C_GOLD)


# -------------------------------------------------------------
# 2. WALL & DOOR BLOCKS (Rows 1-2, size 64x64, y=32..95)
# -------------------------------------------------------------
# Top diamond: y = 0..31 inside the 64x64 block (ox + x, oy + y)
# Wall height: 32px downward
# Base diamond: y = 32..63 inside the 64x64 block

def draw_wall_prism(col: int, top_col=C_STONE_LIGHT, left_col=C_NAVY_DARK, right_col=C_STONE_DARK):
    """Draw a 64x64 isometric stone block (32px high)."""
    ox = col * 64
    oy = 32  # Row 1 start

    # 1. Front-left face: bounded by x in [0, 31], y from top diamond bottom to base diamond bottom
    for x in range(32):
        top_y = 16 + int(x * 0.5)
        base_y = top_y + 32
        for y in range(top_y, base_y + 1):
            # Vertical brick seams
            shade = left_col
            if x == 0:
                shade = C_STONE_HI  # corner highlight
            elif y in (top_y + 10, top_y + 22):
                shade = C_INK  # horizontal mortar line
            elif (y < top_y + 10 and x == 15) or (top_y + 10 < y < top_y + 22 and x == 8):
                shade = C_INK  # vertical mortar line
            img.putpixel((ox + x, oy + y), shade)

    # 2. Front-right face: bounded by x in [32, 63], y from top diamond bottom to base diamond bottom
    for x in range(32, 64):
        top_y = 31 - int((x - 32) * 0.5)
        base_y = top_y + 32
        for y in range(top_y, base_y + 1):
            shade = right_col
            if x == 32:
                shade = C_STONE_LIGHT  # front center ridge highlight
            elif x == 63:
                shade = C_INK  # far right edge shadow
            elif y in (top_y + 10, top_y + 22):
                shade = C_INK
            elif (y < top_y + 10 and x == 48) or (top_y + 10 < y < top_y + 22 and x == 40):
                shade = C_INK
            img.putpixel((ox + x, oy + y), shade)

    # 3. Top diamond cap (y in 0..31)
    for y in range(32):
        for x in range(64):
            if not in_diamond_32(x, y):
                continue
            noise = ((x * 7 + y * 19) % 11 - 5)
            r = min(255, max(0, top_col[0] + noise))
            g = min(255, max(0, top_col[1] + noise))
            b = min(255, max(0, top_col[2] + noise))
            img.putpixel((ox + x, oy + y), (r, g, b, 255))

    # Top diamond edge bevels
    for y in range(16):
        x_left = 30 - 2 * y
        img.putpixel((ox + x_left, oy + y), C_LILAC)
        img.putpixel((ox + x_left + 1, oy + y), C_STONE_HI)
    for y in range(16, 32):
        x_left = 2 * y - 32
        img.putpixel((ox + x_left, oy + y), C_STONE_DARK)


# Col 0: Plain Stone Wall Block
draw_wall_prism(0)

# Col 1: Kintsugi Gold Wall Block
draw_wall_prism(1)
# Add gold fissure across top and cascading down front face
oy1 = 32
crack_pts = [
    # Top diamond
    (14, 12), (24, 18), (32, 28), (32, 31),
    # Down front center ridge
    (31, 36), (33, 42), (30, 48), (32, 54), (31, 62)
]
for i in range(len(crack_pts) - 1):
    x0, y0 = crack_pts[i]
    x1, y1 = crack_pts[i + 1]
    steps = int(math.hypot(x1 - x0, y1 - y0)) + 1
    for s in range(steps + 1):
        t = s / max(1, steps)
        px = int(x0 + (x1 - x0) * t)
        py = int(y0 + (y1 - y0) * t)
        img.putpixel((1 * 64 + px, oy1 + py), C_GOLD_CORE)
        for d in [-1, 1]:
            img.putpixel((1 * 64 + px + d, oy1 + py), C_GOLD)
            img.putpixel((1 * 64 + px, oy1 + py + d), C_GOLD_AMBER)

# Branch onto right face
for t in range(12):
    px = 33 + t
    py = 42 + int(t * 0.4)
    img.putpixel((1 * 64 + px, oy1 + py), C_GOLD)

# Col 2: Ornate Wall with Carved Relief
draw_wall_prism(2, top_col=C_STONE_HI)
# Carved sacred diamond on left face
oy2 = 32
for y in range(40, 52):
    for x in range(10, 22):
        if abs(x - 15.5) + abs(y - 45.5) < 5:
            img.putpixel((2 * 64 + x, oy2 + y), C_GOLD)
# Carved sacred diamond on right face
for y in range(40, 52):
    for x in range(42, 54):
        if abs(x - 47.5) + abs(y - 45.5) < 5:
            img.putpixel((2 * 64 + x, oy2 + y), C_GOLD_AMBER)

# Col 3: Weathered Temple Wall Block
draw_wall_prism(3, top_col=C_STONE_DARK, left_col=C_INK, right_col=C_NAVY_DARK)
# Moss / crack marks
oy3 = 32
for y in range(30):
    for x in range(64):
        if in_diamond_32(x, y) and (x + y * 3) % 9 == 0:
            img.putpixel((3 * 64 + x, oy3 + y), (30, 45, 40, 255))

# Col 4: Door Closed (Locked Gate with Golden Lattice Seal)
draw_wall_prism(4, top_col=C_RED_DARK, left_col=C_WOOD_DARK, right_col=C_WOOD)
oy4 = 32
# Draw closed iron/wood barrier grill & glowing gold talisman
for y in range(25, 58):
    for x in range(8, 56):
        # Vertical gate bars
        if x % 6 in (0, 1):
            img.putpixel((4 * 64 + x, oy4 + y), C_WOOD_DARK)
        # Horizontal iron braces
        if y in (32, 44, 52):
            img.putpixel((4 * 64 + x, oy4 + y), (50, 40, 55, 255))
# Center glowing gold lock / sealing tag
for y in range(36, 46):
    for x in range(27, 37):
        img.putpixel((4 * 64 + x, oy4 + y), C_RED)
img.putpixel((4 * 64 + 31, oy4 + 40), C_GOLD_CORE)
img.putpixel((4 * 64 + 32, oy4 + 40), C_GOLD_CORE)
img.putpixel((4 * 64 + 31, oy4 + 41), C_GOLD)
img.putpixel((4 * 64 + 32, oy4 + 41), C_GOLD)

# Col 5: Door Open (Gate posts with open archway passage)
ox5 = 5 * 64
oy5 = 32
# Base threshold is visible inside
draw_floor_base(ox5, oy5 + 32, base_col=C_STONE_DARK)
# Left pillar post (width ~16)
for y in range(32):
    for x in range(16):
        if in_diamond_32(x, y):
            img.putpixel((ox5 + x, oy5 + y), C_STONE_HI)
for x in range(16):
    top_y = 16 + int(x * 0.5)
    for y in range(top_y, top_y + 32):
        img.putpixel((ox5 + x, oy5 + y), C_STONE_DARK)
# Right pillar post (width ~16)
for y in range(32):
    for x in range(48, 64):
        if in_diamond_32(x, y):
            img.putpixel((ox5 + x, oy5 + y), C_STONE_LIGHT)
for x in range(48, 64):
    top_y = 31 - int((x - 32) * 0.5)
    for y in range(top_y, top_y + 32):
        img.putpixel((ox5 + x, oy5 + y), C_NAVY_DARK)
# Lintel beam across top (shrine archway)
for y in range(4, 12):
    for x in range(10, 54):
        img.putpixel((ox5 + x, oy5 + y), C_RED)
# Highlight on lintel
for x in range(12, 52):
    img.putpixel((ox5 + x, oy5 + 4), C_GOLD)

# Col 6: Stone Toro Lantern Pillar (PointLight2D source)
draw_wall_prism(6, top_col=C_STONE_DARK, left_col=C_NAVY_DARK, right_col=C_STONE_DARK)
oy6 = 32
# Carve lantern fire chamber in the center
for y in range(24, 40):
    for x in range(24, 40):
        if 26 <= x <= 37 and 26 <= y <= 38:
            # Fire chamber glow
            rad = math.hypot(x - 31.5, y - 32)
            if rad < 3.0:
                img.putpixel((6 * 64 + x, oy6 + y), C_LANTERN_HOT)
            elif rad < 5.5:
                img.putpixel((6 * 64 + x, oy6 + y), C_LANTERN_GLOW)
            else:
                img.putpixel((6 * 64 + x, oy6 + y), C_GOLD_AMBER)
        elif x in (25, 38) or y in (25, 39):
            img.putpixel((6 * 64 + x, oy6 + y), C_WOOD_DARK)

# Col 7: Boss Room Altar Pillar
draw_wall_prism(7, top_col=C_RED_DARK, left_col=C_INK, right_col=C_RED_DARK)
oy7 = 32
# Gold crest
for y in range(36, 48):
    for x in range(26, 38):
        if abs(x - 31.5) + abs(y - 41.5) < 5:
            img.putpixel((7 * 64 + x, oy7 + y), C_GOLD_CORE)


# -------------------------------------------------------------
# 3. SPECIAL ACCENT TILES (Row 3, y=96..127)
# -------------------------------------------------------------
oy_r3 = 96
# Col 0: Dark Void / Abyss
# transparent / black diamond with faint edge
for y in range(32):
    for x in range(64):
        if in_diamond_32(x, y):
            img.putpixel((0 * 64 + x, oy_r3 + y), (8, 10, 16, 255))

# Col 1: Red shrine carpet / path
draw_floor_base(1 * 64, oy_r3, base_col=C_RED_DARK, edge_hi=C_RED_HI, edge_sh=C_RED_DARK)
for y in range(32):
    for x in range(64):
        if in_diamond_32(x, y) and (x + y) % 6 == 0:
            img.putpixel((1 * 64 + x, oy_r3 + y), C_GOLD)

# Col 2: Water / reflecting pool
draw_floor_base(2 * 64, oy_r3, base_col=(18, 25, 60, 255), edge_hi=C_LILAC, edge_sh=(10, 15, 40, 255))
for y in range(32):
    for x in range(64):
        if in_diamond_32(x, y) and y in (12, 20) and 20 < x < 44:
            img.putpixel((2 * 64 + x, oy_r3 + y), (180, 210, 255, 220))

# Col 3..7: Duplicate/variants
draw_floor_base(3 * 64, oy_r3, base_col=C_STONE_MID)
draw_floor_base(4 * 64, oy_r3, base_col=C_STONE_DARK)
draw_floor_base(5 * 64, oy_r3, base_col=C_NAVY_DARK)
draw_floor_base(6 * 64, oy_r3, base_col=C_STONE_LIGHT)
draw_floor_base(7 * 64, oy_r3, base_col=C_NAVY)

# Save output
out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "art"))
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "iso_tiles.png")
img.save(out_path)
print(f"Generated {out_path} ({W}x{H})")
