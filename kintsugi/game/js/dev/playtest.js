// Playtest helpers, loaded only with ?debug. They drive the real input layer and step the
// simulation deterministically, so they work even when the tab is hidden.
//
//   open  game/index.html?debug  then in the console:
//   await PT.runAll()          → { level1: {...}, level2: {...} } pass/fail per section
//
const kd = c => dispatchEvent(new KeyboardEvent('keydown', { code: c }));
const ku = c => dispatchEvent(new KeyboardEvent('keyup', { code: c }));
const tap = c => { kd(c); ku(c); };
const W = () => window.__dbg();
const step = ms => window.__step(ms);
const releaseAll = () => ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Space', 'ShiftLeft', 'KeyX'].forEach(ku);

function tp(col, row, face = 1) {
  Object.assign(W().pl, { x: col * 16 + 8, y: row * 16, vx: 0, vy: 0, state: 'move', st: 0, atk: null, low: false, face });
  W().cam.x = Math.max(0, col * 16 - 200);
  step(40);
}
const pl = () => W().pl;
const calm = () => { W().enemies.forEach(e => e.dead = true); W().checkpoints.forEach(c => c.lit = true); };

/** Press X (↑+X where seq says 'up') each time a new attack reaches its active frame. Returns the attack chain. */
function combo(seq) {
  const seen = [], chain = []; let i = 0;
  tap('KeyX');
  for (let g = 0; g < 400; g++) {
    step(10);
    const a = pl().atk;
    if (a && a.phase === 'active' && !seen.includes(a.kind)) {
      seen.push(a.kind); chain.push(a.kind);
      if (i < seq.length) { const up = seq[i++] === 'up'; if (up) kd('ArrowUp'); tap('KeyX'); step(10); if (up) ku('ArrowUp'); }
    }
    if (!a && pl().state === 'move' && g > 20) break;
  }
  return chain.join('>');
}

/** Wall-jump up a two-wall shaft and leave on side exitDir, flipping once near the top. */
function shaft(col, row, exitDir, topY, exitX) {
  tp(col, row);
  const ex = exitDir > 0 ? 'ArrowRight' : 'ArrowLeft';
  let k = ex, walls = 0, flipped = false;
  kd(k); kd('Space'); step(20);
  for (let t = 0; t < 9000; t += 10) {
    step(10); const p = pl();
    if (p.state === 'wall') { walls++; ku(k); ku('Space'); k = p.wallDir > 0 ? 'ArrowLeft' : 'ArrowRight'; kd('Space'); step(10); kd(k); flipped = false; }
    else if (p.state === 'air' && !flipped && p.y < topY + 50 && p.vy > -120 && p.jumps > 0) { ku(k); k = ex; kd(k); ku('Space'); kd('Space'); flipped = true; }
    if (exitDir > 0 ? p.x > exitX : p.x < exitX) break;
    if (p.state === 'move' && t > 400) { ku(k); k = ex; kd(k); kd('Space'); }
  }
  releaseAll();
  return { ok: exitDir > 0 ? pl().x > exitX : pl().x < exitX, walls };
}

/** Climb the ladder at col from the floor at row, return the feet y reached. */
function ladder(col, row, topRow) {
  tp(col, row); kd('ArrowUp'); step(4000); ku('ArrowUp'); step(100);
  return { ok: pl().y === topRow * 16 && pl().state === 'move', y: pl().y };
}

/** Crouch-walk (or run+slide) through a low tunnel, return whether we came out at exitX. */
function tunnel(col, row, exitX, slide) {
  tp(col, row);
  if (slide) { kd('ShiftLeft'); kd('ArrowRight'); step(450); kd('ArrowDown'); step(300); }
  else { kd('ArrowDown'); kd('ArrowRight'); }
  for (let t = 0; t < 8000 && pl().x < exitX; t += 50) step(50);
  releaseAll(); step(200);
  return { ok: pl().x >= exitX, x: Math.round(pl().x), low: pl().low };
}

/** Run off a ledge and flip (and optionally dash) across a gap; ok if we land past landX. */
function gap(col, row, landX, { dash = false } = {}) {
  tp(col, row);
  kd('ShiftLeft'); kd('ArrowRight'); step(300);
  const edge = Math.ceil(pl().x / 16);
  for (let t = 0; t < 3000 && pl().state === 'move'; t += 10) step(10);   // walk off / jump at edge
  kd('Space'); step(250); ku('Space'); kd('Space'); step(200);
  if (dash) tap('KeyC');
  for (let t = 0; t < 3000 && pl().state !== 'move' && pl().state !== 'dead'; t += 10) step(10);
  releaseAll(); step(100);
  return { ok: pl().x > landX && pl().state !== 'dead' && pl().y < 15 * 16, x: Math.round(pl().x), y: pl().y, edge };
}

async function runAll() {
  const out = {};
  window.__level(0); calm();
  out.level1 = {
    combo3: combo(['x', 'x']),
    combo5: (tp(112, 14), combo(['x', 'up', 'x', 'x'])),
    tunnelCrouch: tunnel(12, 14, 19 * 16, false),
    tunnelSlide: tunnel(6, 14, 19 * 16, true),
    ladder: ladder(108, 14, 6),
    shaft: shaft(125, 14, 1, 80, 128 * 16 + 8),
  };
  window.__level(1); calm();
  out.level2 = {
    ladder1: ladder(20, 15, 8),
    chimney: shaft(40, 15, 1, 64, 44 * 16 + 8),
    tunnel: tunnel(66, 15, 77 * 16, true),
    chasm: gap(115, 9, 126 * 16),
    ladder2: ladder(146, 14, 7),
  };
  releaseAll();
  return out;
}

window.PT = { kd, ku, tap, tp, step, combo, shaft, ladder, tunnel, gap, calm, runAll };
