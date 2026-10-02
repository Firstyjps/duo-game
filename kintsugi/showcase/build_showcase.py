"""Render every action of Kintsugi Run as GIFs + a combined reel.

Sources: game/sheet.png (original sample idle / walk / from idle, 46x58 cells)
and game/atk.png + atk.js (PixelLab animations, 64x64 cells, already aligned
and flip-corrected by pixellab/build_atk.py). The sprites face left in the
files; everything here is mirrored to face right, the way the game shows them.

Outputs (next to this script):
  gifs/<key>.gif      one looping GIF per action
  all_actions.gif     every action in order, with an English label
  actions.json        metadata the HTML gallery reads
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
SCALE = 4
BOX = 76                    # logical canvas (px) — feet at y=70, anchor at x=38
FEET, AXC = 70, 38
BG = (21, 16, 55)           # #151037 — the character's own deep navy
GROUND = (64, 34, 95)

base = Image.open(os.path.join(GAME, 'sheet.png')).convert('RGBA')
art = Image.open(os.path.join(GAME, 'atk.png')).convert('RGBA')
ART = json.loads(open(os.path.join(GAME, 'atk.js'), encoding='utf-8').read().split('= ', 1)[1].rstrip(';\n'))
M = ART['moves']


def base_frame(row, col):
    return base.crop((col * 46, row * 58, col * 46 + 46, row * 58 + 58)), 22, 58


def art_frame(kind, col):
    r = M[kind]['row']
    return art.crop((col * 64, r * 64, col * 64 + 64, r * 64 + 64)), 31, 64


def compose(cell, ax, h, dy=0):
    """Place a left-facing cell on the canvas, feet on the ground, then mirror to face right."""
    c = Image.new('RGBA', (BOX, BOX), (0, 0, 0, 0))
    c.paste(cell, (AXC - ax, FEET - h + dy), cell)
    return c.transpose(Image.FLIP_LEFT_RIGHT)


def seq(kind, *phases):
    out = []
    for ph in phases:
        for col in M[kind].get(ph, []):
            if not out or out[-1] != col:
                out.append(col)
    return out


def art_frames(kind, phases, ms, hold=0, dy=0):
    cols = seq(kind, *phases)
    fr = [(compose(*art_frame(kind, c), dy=dy), ms) for c in cols]
    if hold and fr:
        fr[-1] = (fr[-1][0], ms + hold)
    return fr


# key, Thai, English, keys, source, frames
ACTIONS = [
    ('idle', 'ยืนหายใจ', 'Idle', '—', 'original', [(compose(*base_frame(0, c)), 60) for c in range(10)]),
    ('walk', 'เดิน', 'Walk', '← →', 'original',
     [(compose(*base_frame(2, c)), 50) for c in range(2)] + [(compose(*base_frame(1, c)), 50) for c in range(24)]),
    ('crouch', 'หมอบ', 'Crouch', '↓', 'pixellab', art_frames('crouch', ['down', 'hold'], 90, 200)),
    ('run', 'วิ่ง', 'Run', 'Shift + ← →', 'pixellab', art_frames('run', ['loop'], 70)),
    ('turn', 'กลับตัวขณะวิ่ง', 'Run turn', 'วิ่งแล้วกดทิศกลับ', 'pixellab', art_frames('turn', ['play'], 70, 200)),
    ('jump', 'กระโดด', 'Jump', 'Space', 'pixellab', art_frames('jump', ['crouch', 'rise', 'apex', 'fall', 'land'], 90, 200)),
    ('dj', 'กระโดด 2 ชั้น', 'Double jump', 'Space กลางอากาศ', 'pixellab', art_frames('dj', ['play'], 80, 200)),
    ('dash', 'พุ่งกลางอากาศ', 'Air dash', 'C กลางอากาศ', 'pixellab', art_frames('dash', ['play'], 70, 200)),
    ('slide', 'สไลด์', 'Slide', '↓ + C', 'pixellab', art_frames('slide', ['play'], 80, 200)),
    ('backdodge', 'หลบถอยหลัง', 'Back dodge', 'C', 'pixellab', art_frames('backdodge', ['play'], 70, 200)),
    ('atk1', 'ฟัน 1', 'Attack 1', 'X', 'pixellab', art_frames('1', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('atk2', 'ฟัน 2', 'Attack 2', 'X X', 'pixellab', art_frames('2', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('atk2-1', 'ฟัน 2-1 (แทง)', 'Attack 2-1', 'X X · เว้น · X', 'pixellab', art_frames('2-1', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('atk2-2', 'ฟัน 2-2 (กวาด)', 'Attack 2-2', '… X', 'pixellab', art_frames('2-2', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('atk3', 'ฟัน 3 (ฟันลง)', 'Attack 3', 'X X X', 'pixellab', art_frames('3', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('jatk1', 'ฟันกลางอากาศ 1', 'Jump attack 1', 'X กลางอากาศ', 'pixellab', art_frames('air', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('jatk2', 'ฟันกลางอากาศ 2', 'Jump attack 2', 'X X กลางอากาศ', 'pixellab', art_frames('air2', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('datk1', 'ฟันสวน 1', 'Dodge attack 1', 'C แล้ว X', 'pixellab', art_frames('dodge1', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('datk2', 'ฟันสวน 2', 'Dodge attack 2', 'C แล้ว X X', 'pixellab', art_frames('dodge2', ['antic', 'smear', 'active', 'rec'], 80, 250)),
    ('vatk', 'ฟันแนวดิ่ง', 'Vertical attack', '↓ + X กลางอากาศ', 'pixellab', art_frames('plunge', ['antic', 'dive', 'active', 'rec'], 90, 250)),
    ('hurt1', 'โดนตี (เบา)', 'Hurt 1', 'โดนบนพื้น', 'pixellab', art_frames('hurt', ['light'], 110, 250)),
    ('hurt2', 'โดนตี (ล้ม)', 'Hurt 2', 'โดนกลางอากาศ', 'pixellab', art_frames('hurt', ['down', 'up'], 110, 300)),
    ('heal', 'ฟื้นพลัง', 'Heal', 'Q ค้าง', 'pixellab', art_frames('heal', ['play'], 100, 250)),
    ('ladder', 'ปีนบันได', 'Ladder', '↑ ที่บันได', 'pixellab', art_frames('ladder', ['loop'], 110)),
    ('ledge', 'เกาะขอบผา', 'Ledge grab & climb', 'ชนขอบผา แล้ว ↑', 'pixellab', art_frames('ledge', ['hang', 'climb'], 110, 250, dy=14)),
    ('wall', 'เกาะกำแพง / ถีบกำแพง', 'Wall slide & jump', 'ดันเข้ากำแพง + Space', 'pixellab', art_frames('wall', ['slide', 'jump'], 100, 250)),
]


def backdrop():
    bg = Image.new('RGB', (BOX * SCALE, BOX * SCALE), BG)
    d = ImageDraw.Draw(bg)
    gy = FEET * SCALE
    d.rectangle((0, gy, BOX * SCALE, BOX * SCALE), fill=GROUND)
    d.rectangle((0, gy, BOX * SCALE, gy + SCALE - 1), fill=(178, 178, 255))
    return bg


def render(frame):
    bg = backdrop()
    big = frame.resize((BOX * SCALE, BOX * SCALE), Image.NEAREST)
    bg.paste(big, (0, 0), big)
    return bg


def save_gif(path, frames):
    imgs = [render(f).quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE) for f, _ in frames]
    imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=[ms for _, ms in frames], loop=0, disposal=2, optimize=True)


os.makedirs(os.path.join(HERE, 'gifs'), exist_ok=True)
meta = []
for key, th, en, keys, src, frames in ACTIONS:
    save_gif(os.path.join(HERE, 'gifs', f'{key}.gif'), frames)
    meta.append({'key': key, 'th': th, 'en': en, 'keys': keys, 'source': src, 'frames': len(frames),
                 'ms': sum(ms for _, ms in frames)})

# combined reel with a label band
try:
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 22)
    small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 15)
except OSError:
    font = small = ImageFont.load_default()
W, BAND = BOX * SCALE, 44
reel, durs = [], []
for i, (key, th, en, keys, src, frames) in enumerate(ACTIONS):
    loops = 2 if key in ('idle', 'walk', 'run', 'ladder') else 1
    for _ in range(loops):
        for f, ms in frames:
            canvas = Image.new('RGB', (W, W + BAND), (15, 18, 27))
            canvas.paste(render(f), (0, BAND))
            d = ImageDraw.Draw(canvas)
            d.text((12, 9), en, font=font, fill=(255, 255, 204))
            d.text((W - 12, 14), f'{i + 1:02d}/{len(ACTIONS)}', font=small, fill=(158, 160, 250), anchor='ra')
            reel.append(canvas.quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE))
            durs.append(ms)
    durs[-1] += 350   # short pause between actions
reel[0].save(os.path.join(HERE, 'all_actions.gif'), save_all=True, append_images=reel[1:], duration=durs, loop=0, optimize=True)

json.dump(meta, open(os.path.join(HERE, 'actions.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(meta), 'actions ·', len(reel), 'reel frames ·', round(sum(durs) / 1000, 1), 's')
