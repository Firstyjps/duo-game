#!/bin/sh
# usage: fetch.sh <job_id> <prefix>  — download the 9 frames of a PixelLab animate_image job
cd "$(dirname "$0")"
for i in 0 1 2 3 4 5 6 7 8; do
  curl -sf -o "$2_$i.png" "https://api.pixellab.ai/mcp/images/$1/download?index=$i" || echo "missing frame $i"
done
python3 - "$2" <<'PY'
import sys
from PIL import Image
p = sys.argv[1]
ims = [Image.open(f'{p}_{i}.png').convert('RGBA') for i in range(9)]
c = Image.new('RGBA', (64 * 9, 64), (40, 36, 70, 255))
for i, im in enumerate(ims): c.paste(im, (i * 64, 0), im)
c.resize((64 * 9 * 3, 64 * 3), Image.NEAREST).save(f'{p}_sheet.png')
PY
