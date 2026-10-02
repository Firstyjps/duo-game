"""Write showcase/index.html — a gallery of every action GIF (reads actions.json)."""
import html
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
meta = json.load(open(os.path.join(HERE, 'actions.json'), encoding='utf-8'))

GROUP = {
    'move': ['idle', 'walk', 'crouch', 'run', 'turn', 'jump', 'dj', 'dash', 'slide', 'backdodge'],
    'attack': ['atk1', 'atk2', 'atk2-1', 'atk2-2', 'atk3', 'jatk1', 'jatk2', 'datk1', 'datk2', 'vatk'],
    'other': ['hurt1', 'hurt2', 'heal', 'ladder', 'ledge', 'wall'],
}
group_of = {k: g for g, ks in GROUP.items() for k in ks}
n_px = sum(1 for m in meta if m['source'] == 'pixellab')

cards = []
for i, m in enumerate(meta, 1):
    src_label = 'PixelLab' if m['source'] == 'pixellab' else 'ต้นฉบับ'
    cards.append(f'''    <figure class="card" data-group="{group_of[m['key']]}">
      <img src="gifs/{m['key']}.gif" alt="{html.escape(m['en'])} animation" width="304" height="304" loading="lazy">
      <figcaption>
        <span class="num">{i:02d}</span>
        <span class="th">{html.escape(m['th'])}</span>
        <span class="en">{html.escape(m['en'])}</span>
        <span class="meta"><kbd>{html.escape(m['keys'])}</kbd><span class="src {m['source']}">{src_label}</span></span>
        <span class="stat">{m['frames']} เฟรม · {m['ms'] / 1000:.2f} วิ</span>
      </figcaption>
    </figure>''')

page = f'''<!doctype html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Kintsugi Moveset</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Kanit:wght@400;500;600&family=Pixelify+Sans:wght@500;700&display=swap" rel="stylesheet">
<style>
  /* Layout: reel + summary up top, then a filterable grid of one card per action. Single dark look taken from the sprite's own palette. */
  :root {{
    color-scheme: dark;
    --bg: #0F121B;          /* deep ink */
    --surface: #151037;     /* coat shadow navy */
    --line: #2F1850;        /* plum crease */
    --fg: #ECEBFF;
    --muted: #9EA0FA;       /* hair midtone */
    --gold: #FFA303;        /* kintsugi gold */
    --gold-hi: #FFFFCC;
    --lilac: #B2B2FF;
    --font-display: 'Pixelify Sans', 'Kanit', system-ui, sans-serif;
    --font-body: 'Kanit', system-ui, -apple-system, sans-serif;
  }}
  * {{ box-sizing: border-box; }}
  html, body {{ margin: 0; background: var(--bg); color: var(--fg); font-family: var(--font-body); }}
  body {{ padding-inline: 16px; padding-block: 28px 56px; }}
  .wrap {{ max-width: 1180px; margin: 0 auto; display: grid; gap: 28px; }}
  header {{ display: grid; grid-template-columns: minmax(0, 340px) minmax(0, 1fr); gap: 28px; align-items: center; }}
  header img {{ width: 100%; max-width: 340px; margin-inline: auto; height: auto; image-rendering: pixelated; border: 1px solid var(--line); border-radius: 10px; display: block; }}
  .eyebrow {{ font-family: var(--font-display); color: var(--muted); letter-spacing: .08em; font-size: 14px; text-transform: uppercase; }}
  h1 {{ font-family: var(--font-display); font-weight: 700; font-size: clamp(36px, 6vw, 60px); line-height: 1; margin: 6px 0 12px; color: var(--gold-hi);
        text-shadow: 0 3px 0 #A64B0A; text-wrap: balance; }}
  header p {{ margin: 0 0 10px; color: var(--fg); max-width: 60ch; line-height: 1.6; }}
  .counts {{ display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }}
  .counts span {{ border: 1px solid var(--line); border-radius: 999px; padding: 3px 12px; font-size: 14px; color: var(--muted); }}
  .counts b {{ color: var(--gold); font-weight: 600; }}
  .filters {{ display: flex; flex-wrap: wrap; gap: 8px; }}
  .filters button {{ font: inherit; font-size: 15px; color: var(--fg); background: transparent; border: 1px solid var(--line); border-radius: 8px; padding: 6px 14px; cursor: pointer; }}
  .filters button[aria-pressed="true"] {{ background: var(--surface); border-color: var(--gold); color: var(--gold-hi); }}
  .filters button:focus-visible {{ outline: 2px solid var(--gold); outline-offset: 2px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 14px; }}
  .card {{ margin: 0; background: var(--surface); border: 1px solid var(--line); border-radius: 10px; overflow: hidden; display: flex; flex-direction: column; min-width: 0; }}
  .card[hidden] {{ display: none; }}
  .card img {{ width: 100%; height: auto; aspect-ratio: 1; image-rendering: pixelated; display: block; }}
  figcaption {{ padding: 10px 12px 12px; display: grid; gap: 2px; }}
  .num {{ font-family: var(--font-display); color: var(--muted); font-size: 13px; }}
  .th {{ font-weight: 600; font-size: 17px; }}
  .en {{ font-family: var(--font-display); color: var(--lilac); font-size: 14px; }}
  .meta {{ display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-top: 6px; }}
  kbd {{ font-family: var(--font-body); font-size: 12px; background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 1px 7px; color: var(--fg); }}
  .src {{ font-size: 12px; border-radius: 999px; padding: 1px 8px; }}
  .src.pixellab {{ color: var(--gold); border: 1px solid rgba(255,163,3,.45); }}
  .src.original {{ color: var(--lilac); border: 1px solid rgba(178,178,255,.45); }}
  .stat {{ color: var(--muted); font-size: 12px; font-variant-numeric: tabular-nums; margin-top: 2px; }}
  footer {{ color: var(--muted); font-size: 13px; line-height: 1.6; }}
  @media (max-width: 640px) {{ header {{ grid-template-columns: minmax(0, 1fr); }} .grid {{ grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }} }}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <img src="all_actions.gif" alt="All {len(meta)} actions played one after another" width="304" height="348">
    <div>
      <div class="eyebrow">Kintsugi Run · Merakintsugi sample character</div>
      <h1>Kintsugi Moveset</h1>
      <p>ทุกอิริยาบถของตัวละครในเกม เล่นวนเป็น GIF ทีละท่า ภาพใหญ่เล่นต่อกันครบทุกท่า ใช้ปุ่มข้างล่างกรองตามหมวดได้</p>
      <p>ยืนและเดินมาจากไฟล์ sample ต้นฉบับ ท่าที่เหลือ PixelLab วาดใหม่จากเฟรมยืน แล้วจัดตำแหน่งเท้าและทิศให้ตรงกับเกม</p>
      <div class="counts"><span><b>{len(meta)}</b> ท่า</span><span><b>{n_px}</b> PixelLab</span><span><b>{len(meta) - n_px}</b> ต้นฉบับ</span><span>ขยาย ×4 · หันขวาแบบในเกม</span></div>
    </div>
  </header>

  <nav class="filters" aria-label="กรองท่า">
    <button type="button" data-f="all" aria-pressed="true">ทั้งหมด</button>
    <button type="button" data-f="move" aria-pressed="false">เคลื่อนที่</button>
    <button type="button" data-f="attack" aria-pressed="false">โจมตี</button>
    <button type="button" data-f="other" aria-pressed="false">อื่นๆ</button>
  </nav>

  <main class="grid">
{chr(10).join(cards)}
  </main>

  <footer>สร้างจาก <code>game/showcase/build_showcase.py</code> (GIF) และ <code>gen_html.py</code> (หน้านี้) · เฟรม PixelLab อยู่ใน <code>game/pixellab/</code></footer>
</div>
<script>
  const buttons = document.querySelectorAll('.filters button'), cards = document.querySelectorAll('.card');
  buttons.forEach(b => b.addEventListener('click', () => {{
    buttons.forEach(x => x.setAttribute('aria-pressed', x === b));
    cards.forEach(c => c.hidden = b.dataset.f !== 'all' && c.dataset.group !== b.dataset.f);
  }}));
</script>
</body>
</html>
'''
open(os.path.join(HERE, 'index.html'), 'w', encoding='utf-8').write(page)
print('wrote index.html with', len(meta), 'cards')
