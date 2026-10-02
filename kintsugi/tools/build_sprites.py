#!/usr/bin/env python3
"""Build the shared sprite atlas from the .aseprite sources.

Reads  assets/sprites/*.aseprite
Writes game/assets/sheet.png      one 64x64 cell per frame, feet on the cell bottom
       game/assets/sprites.json   frame rects, durations and tags (used by game + studio)
       assets/sprites/exports/*.gif  x4 previews for quick sharing

Run from anywhere:  python3 tools/build_sprites.py
"""
import json
import os
import struct
import zlib

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'sprites')
OUT_GAME = os.path.join(ROOT, 'game', 'assets')
OUT_GIF = os.path.join(SRC, 'exports')

CELL = 64          # every frame is packed into a CELL x CELL square
LEFT = 9           # union bbox of each source file starts at this x inside the cell
ANCHOR_X = LEFT + 22  # feet centre; matches the creator's trimmed exports

# animation name -> (source file, first frame, last frame); tags come from walk.aseprite
ANIMATIONS = {
    'idle':      ('idle.aseprite', 0, 9),
    'from_idle': ('walk.aseprite', 0, 1),
    'walk':      ('walk.aseprite', 2, 25),
}


def read_aseprite(path):
    """Minimal .aseprite reader: composites cels per frame (RGBA, compressed or linked cels)."""
    data = open(path, 'rb').read()
    _, _, n_frames, width, height = struct.unpack_from('<IHHHH', data, 0)
    frames, tags, off = [], [], 128
    for _ in range(n_frames):
        size, _, old_chunks, duration = struct.unpack_from('<IHHH', data, off)
        new_chunks = struct.unpack_from('<I', data, off + 12)[0]
        canvas = Image.new('RGBA', (width, height))
        p = off + 16
        for _ in range(new_chunks or old_chunks):
            csize, ctype = struct.unpack_from('<IH', data, p)
            if ctype == 0x2005:  # cel
                _, x, y, _, cel_type = struct.unpack_from('<HhhBH', data, p + 6)
                if cel_type == 2:
                    cw, ch = struct.unpack_from('<HH', data, p + 22)
                    cel = Image.frombytes('RGBA', (cw, ch), zlib.decompress(data[p + 26:p + csize]))
                    canvas.alpha_composite(cel, (x, y))
                elif cel_type == 1:
                    canvas = frames[struct.unpack_from('<H', data, p + 22)[0]][0].copy()
            elif ctype == 0x2018:  # tags
                count = struct.unpack_from('<H', data, p + 6)[0]
                q = p + 16
                for _ in range(count):
                    a, b = struct.unpack_from('<HH', data, q)
                    q += 17
                    ln = struct.unpack_from('<H', data, q)[0]
                    tags.append({'name': data[q + 2:q + 2 + ln].decode(), 'from': a, 'to': b})
                    q += 2 + ln
            p += csize
        frames.append((canvas, duration))
        off += size
    return frames, (width, height), tags


def main():
    os.makedirs(OUT_GAME, exist_ok=True)
    os.makedirs(OUT_GIF, exist_ok=True)
    sources, cells, manifest = {}, [], {'cell': CELL, 'anchor': [ANCHOR_X, CELL], 'animations': {}, 'tags': {}}

    for name, (src, a, b) in ANIMATIONS.items():
        if src not in sources:
            sources[src] = read_aseprite(os.path.join(SRC, src))
            manifest['tags'][src] = sources[src][2]
        frames = sources[src][0][a:b + 1]
        # trim by the union of the whole source file, so animations from one file stay registered
        boxes = [im.getbbox() for im, _ in sources[src][0]]
        union = (min(x[0] for x in boxes), min(x[1] for x in boxes), max(x[2] for x in boxes), max(x[3] for x in boxes))
        uw, uh = union[2] - union[0], union[3] - union[1]
        assert uw + LEFT <= CELL and uh <= CELL, f'{name} does not fit the cell'
        entry = {'source': src, 'range': [a, b], 'size': list(sources[src][1]), 'frames': []}
        row = []
        for im, dur in frames:
            cell = Image.new('RGBA', (CELL, CELL))
            cell.alpha_composite(im.crop(union), (LEFT, CELL - uh))
            row.append(cell)
            entry['frames'].append({'duration': dur})
        cells.append((name, row))
        manifest['animations'][name] = entry

    cols = max(len(r) for _, r in cells)
    sheet = Image.new('RGBA', (cols * CELL, len(cells) * CELL))
    for y, (name, row) in enumerate(cells):
        for x, cell in enumerate(row):
            sheet.alpha_composite(cell, (x * CELL, y * CELL))
            manifest['animations'][name]['frames'][x].update(x=x * CELL, y=y * CELL)
        big = [c.resize((CELL * 4, CELL * 4), Image.NEAREST) for c in row]
        durs = [f['duration'] for f in manifest['animations'][name]['frames']]
        big[0].save(os.path.join(OUT_GIF, f'{name}.gif'), save_all=True, append_images=big[1:],
                    duration=durs, loop=0, disposal=2)

    sheet.save(os.path.join(OUT_GAME, 'sheet.png'))
    with open(os.path.join(OUT_GAME, 'sprites.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    print(f'sheet {sheet.size} · ' + ', '.join(f'{n} {len(r)}f' for n, r in cells))


if __name__ == '__main__':
    main()
