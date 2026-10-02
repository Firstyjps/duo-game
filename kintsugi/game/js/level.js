// Level loading, tile queries and the pre-rendered tile / background layers.
// Level data lives in levels/*.js; each exports { cols, rows, start, goal, checkpoints, shards, enemies, movers, signs, build(api) }.
import { W, H, T, P } from './config.js';

import level1 from './levels/level1.js';
import level2 from './levels/level2.js';

export const LEVELS = [level1, level2];
export const AIR = 0, SOLID = 1, SPIKE = 2, LADDER = 3, LADDER_TOP = 4;

// Live bindings: other modules always see the currently loaded level.
export let level = null, levelIndex = 0, COLS = 0, ROWS = 0, grid = [], levelCanvas = null;
export let START = { x: 0, y: 0 }, GOAL = { x: 0, y: 0 };

export function loadLevel(i) {
  levelIndex = (i + LEVELS.length) % LEVELS.length;
  level = LEVELS[levelIndex];
  COLS = level.cols; ROWS = level.rows;
  grid = Array.from({ length: ROWS }, () => new Uint8Array(COLS));
  const fill = (x0, x1, y0, y1, v) => {
    for (let y = Math.max(0, y0); y <= Math.min(ROWS - 1, y1); y++)
      for (let x = Math.max(0, x0); x <= Math.min(COLS - 1, x1); x++) grid[y][x] = v;
  };
  level.build({
    fill,
    ground: (x0, x1, top) => fill(x0, x1, top, ROWS - 1, SOLID),
    plat: (x0, x1, y) => fill(x0, x1, y, y, SOLID),
    spikes: (x0, x1, y) => fill(x0, x1, y, y, SPIKE),
    ladder: (x, top, bottom) => { fill(x, x, top + 1, bottom, LADDER); grid[top][x] = LADDER_TOP; },
  });
  START = { x: level.start[0] * T + 8, y: level.start[1] * T };
  GOAL = { x: level.goal[0] * T, y: level.goal[1] * T };
  seed = 7 + levelIndex * 101;
  levelCanvas = drawTiles();
  return level;
}

export const tileAt = (tx, ty) => (tx < 0 || tx >= COLS || ty < 0 || ty >= ROWS) ? AIR : grid[ty][tx];
export const solid = (tx, ty) => (tx < 0 || tx >= COLS) ? true : (ty < 0 || ty >= ROWS) ? false : grid[ty][tx] === SOLID;

// ---- deterministic decoration rng ----
let seed = 7;
export const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;

// ---- pre-rendered tiles ----
function drawTiles() {
  const c = document.createElement('canvas'); c.width = COLS * T; c.height = ROWS * T;
  const g = c.getContext('2d');
  const px = (x, y, c, w = 1, h = 1) => { g.fillStyle = c; g.fillRect(x, y, w, h); };
  for (let ty = 0; ty < ROWS; ty++) for (let tx = 0; tx < COLS; tx++) {
    const v = grid[ty][tx], X = tx * T, Y = ty * T;
    if (v === SOLID) {
      let depth = 0; while (depth < 3 && solid(tx, ty - depth - 1)) depth++;
      px(X, Y, depth >= 2 ? P.navyD : P.navy, T, T);
      for (let i = 0; i < 5; i++) px(X + (rnd() * 15 | 0), Y + (rnd() * 15 | 0), rnd() < .5 ? P.navyDD : (depth ? P.navyD : P.plumD));
      if (!solid(tx - 1, ty)) px(X, Y, P.navyDD, 1, T);
      if (!solid(tx + 1, ty)) px(X + T - 1, Y, P.navyDD, 1, T);
      if (tileAt(tx, ty + 1) !== SOLID && ty < ROWS - 1) px(X, Y + T - 1, P.navyDD, T, 1);
      if (depth === 0) {           // mossy lilac top
        px(X, Y, P.lilac, T, 1); px(X, Y + 1, P.lilacD, T, 2); px(X, Y + 3, P.plum, T, 1);
        for (let i = 0; i < 4; i++) { const dx = rnd() * 15 | 0, dl = 1 + (rnd() * 3 | 0); px(X + dx, Y + 3, P.lilacD, 1, dl); }
        if (rnd() < .3) px(X + (rnd() * 14 | 0), Y - 1, P.lilac, 1, 1);
      }
      if (rnd() < .22) {           // kintsugi gold crack
        let cx = X + 2 + (rnd() * 12 | 0), cy = Y + 5 + (rnd() * 4 | 0);
        for (let i = 0; i < 7; i++) { px(cx, cy, P.gold); cx += rnd() < .5 ? 1 : -1; cy += 1; if (cy >= Y + T - 1) break; }
        px(cx, cy - 1, P.goldHi);
      }
    } else if (v === SPIKE) {
      for (let s = 0; s < 4; s++) {
        const bx = X + s * 4;
        px(bx + 1, Y + 8, P.white, 1, 2); px(bx + 1, Y + 10, P.lilac, 2, 2);
        px(bx, Y + 12, P.plum, 4, 4); px(bx + 3, Y + 11, P.plumD, 1, 5); px(bx + 2, Y + 10, P.plumD, 1, 2);
      }
    } else if (v === LADDER || v === LADDER_TOP) {
      px(X + 2, Y, P.wood, 2, T); px(X + 12, Y, P.wood, 2, T);
      px(X + 2, Y, P.rust, 1, T); px(X + 12, Y, P.rust, 1, T);
      for (let r = 2; r < T; r += 5) { px(X + 4, Y + r, P.rust, 8, 2); px(X + 4, Y + r, P.gold, 8, 1); }
      if (v === LADDER_TOP) { px(X, Y, P.gold, T, 1); px(X, Y + 1, P.rust, T, 1); }
    }
  }
  return c;
}

// ---- parallax background ----
function layer(w, h, fn) { const c = document.createElement('canvas'); c.width = w; c.height = h; fn(c.getContext('2d')); return c; }
export const sky = layer(W, H, g => {
  const gr = g.createLinearGradient(0, 0, 0, H);
  gr.addColorStop(0, P.navyDD); gr.addColorStop(.55, P.plumD); gr.addColorStop(1, P.plum);
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  for (let i = 0; i < 90; i++) { g.fillStyle = rnd() < .2 ? P.goldHi : P.lilac; g.globalAlpha = .3 + rnd() * .7; g.fillRect(rnd() * W | 0, rnd() * H * .6 | 0, 1, 1); }
  g.globalAlpha = 1;
  const mx = 372, my = 62, r = 26;
  g.fillStyle = 'rgba(255,255,204,.08)'; g.beginPath(); g.arc(mx, my, r + 14, 0, 7); g.fill();
  for (let y = -r; y <= r; y++) { const hw = Math.round(Math.sqrt(r * r - y * y)); g.fillStyle = y < r * .3 ? P.goldHi : '#F2E7C0'; g.fillRect(mx - hw, my + y, hw * 2, 1); }
  g.fillStyle = '#E3D6AA'; [[-8, -6, 5], [7, 4, 4], [-3, 12, 3], [12, -12, 2]].forEach(([dx, dy, s]) => g.fillRect(mx + dx, my + dy, s, s));
  g.fillStyle = P.gold; let cx = mx - 18, cy = my - 10; for (let i = 0; i < 36; i++) { g.fillRect(cx, cy, 1, 1); cx++; if (rnd() < .45) cy += rnd() < .6 ? 1 : -1; }
});
function ridge(base, amp, col, step, pagodas) {
  return layer(960, H, g => {
    g.fillStyle = col;
    for (let x = 0; x < 960; x++) {
      const t = x / 960 * Math.PI * 2;
      const y = Math.round(base - amp * (.6 * Math.sin(t * step) + .3 * Math.sin(t * step * 2.7 + 1.3) + .15 * Math.sin(t * step * 6.1 + 2)));
      g.fillRect(x, y, 1, H);
      if (pagodas && x % 120 === 40) { g.fillRect(x - 1, y - 18, 3, 18); for (let k = 0; k < 3; k++) g.fillRect(x - 6 + k, y - 6 - k * 5, 13 - k * 2, 2); }
    }
  });
}
export const farHills = ridge(170, 40, P.plumD, 3, false);
export const nearHills = ridge(200, 28, P.navy, 4, true);
