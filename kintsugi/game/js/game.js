// World update + rendering + HUD.
import { W, H, T, P, K } from './config.js';
import { world } from './world.js';
import { clearPressed } from './input.js';
import { COLS, ROWS, levelCanvas, sky, farHills, nearHills, GOAL, START, level, levelIndex, LEVELS, loadLevel, rnd, solid } from './level.js';
import { sfx } from './audio.js';
import { sprites, drawBody } from './sprites.js';
import { tickFx, resetFx, burst, drawFx, drawGhosts, drawParticles, drawArc, drawThrust } from './fx.js';
import { ATTACKS } from './moves.js';
import { makeEnemies, updateEnemies, drawEnemies } from './enemies.js';
import { newPlayer, updatePlayer, pose, attackStage, startPower, startCheer } from './player.js';

const $ = id => document.getElementById(id);
let petals = [], finishTimer = 0;

export function reset(levelNo = levelIndex) {
  loadLevel(levelNo);
  for (const k in groundCache) delete groundCache[k];
  world.pl = newPlayer(START.x, START.y);
  world.shards = level.shards.map(([x, y]) => ({ x: x * T + 8, y: y * T + 8, got: false, ph: rnd() * 6 }));
  world.checkpoints = level.checkpoints.map(([x, y], i) => ({ x: x * T + 8, y: y * T, lit: i === 0 }));
  world.enemies = makeEnemies();
  world.movers = level.movers.map(m => ({ x0: m.x0 * T, x1: m.x1 * T, y: m.y * T, w: m.w * T, speed: m.speed, x: m.x0 * T, dir: 1, dx: 0 }));
  world.respawn = { ...START };
  world.cam = { x: 0, y: ROWS * T - H };
  Object.assign(world, { time: 0, deaths: 0, won: false, hitstop: 0, shake: 0 });
  resetFx(); clearPressed();
  petals = Array.from({ length: 26 }, () => ({ x: rnd() * W, y: rnd() * H, v: 8 + rnd() * 14, ph: rnd() * 6, s: rnd() < .5 ? 1 : 2 }));
  clearTimeout(finishTimer);
  $('win').classList.add('hidden');
}

export const nextLevel = () => reset(levelIndex + 1);

export function begin() { world.running = true; $('start').classList.add('hidden'); }

export function update(dt) {
  if (!world.running) { tickAmbient(dt); return; }
  if (world.hitstop > 0) { world.hitstop -= dt; return; }
  if (!world.won) world.time += dt;
  for (const m of world.movers) {
    const nx = Math.max(m.x0, Math.min(m.x1, m.x + m.dir * m.speed * dt));
    m.dx = nx - m.x; m.x = nx; if (m.x === m.x0 || m.x === m.x1) m.dir *= -1;
  }
  updateEnemies(dt);
  updatePlayer(dt);
  clearPressed();

  const pl = world.pl;
  if (pl.state !== 'dead') {
    for (const s of world.shards) if (!s.got && Math.abs(s.x - pl.x) < 13 && s.y > pl.y - (pl.low ? K.PH_LOW : K.PH) - 4 && s.y < pl.y + 4) {
      s.got = true; sfx('pickup'); burst(s.x, s.y, 16, [P.gold, P.goldHi, P.white], 120, .55, 100);
    }
    for (const c of world.checkpoints) {
      if (Math.abs(c.x - pl.x) >= 14 || Math.abs(c.y - pl.y) >= 30) continue;
      world.respawn = { x: c.x, y: c.y };
      if (!c.lit) {
        world.checkpoints.forEach(o => o.lit = false); c.lit = true; sfx('checkpoint');
        burst(c.x, c.y - 26, 12, [P.red, P.gold, P.goldHi], 90, .6, -40);
        if (pl.ground && (pl.state === 'move')) startPower(pl);
      }
    }
    if (!world.won && pl.x > GOAL.x + 8 && pl.x < GOAL.x + 40 && pl.y <= GOAL.y + 1) finish();
  }
  tickAmbient(dt);
}

function tickAmbient(dt) {
  tickFx(dt);
  world.shake = Math.max(0, world.shake - dt * 18);
  for (const p of petals) {
    p.y += p.v * dt; p.x += Math.sin(performance.now() / 900 + p.ph) * 10 * dt - 6 * dt;
    if (p.y > H) { p.y = -4; p.x = rnd() * W; } if (p.x < -4) p.x = W;
  }
  const pl = world.pl, tx = Math.max(0, Math.min(COLS * T - W, pl.x - W * .42 + pl.face * 30));
  world.cam.x += (tx - world.cam.x) * Math.min(1, dt * 5);
}

function finish() {
  world.won = true;
  startCheer(world.pl); sfx('win');
  burst(GOAL.x + 24, GOAL.y - 50, 50, [P.gold, P.goldHi, P.red, P.white], 220, 1.2, 120);
  const got = world.shards.filter(s => s.got).length, kills = world.enemies.filter(e => e.dead).length;
  $('wShards').textContent = `${got}/${world.shards.length}`;
  $('wKills').textContent = `${kills}/${world.enemies.length}`;
  $('wTime').textContent = world.time.toFixed(1) + ' วิ';
  $('wDeaths').textContent = world.deaths;
  const full = got === world.shards.length && kills === world.enemies.length;
  const last = levelIndex === LEVELS.length - 1;
  $('wTitle').textContent = last ? 'จบทุกด่านแล้ว!' : `ผ่านด่าน ${levelIndex + 1}!`;
  $('wNext').textContent = last ? 'กด N เริ่มด่าน 1 ใหม่ · R เล่นด่านนี้อีกครั้ง' : 'กด N ไปด่านถัดไป · R เล่นด่านนี้อีกครั้ง';
  $('wNote').textContent = full
    ? (world.deaths === 0 ? 'สมบูรณ์แบบ: ครบทุกอย่างและไม่ตายเลย' : 'เก็บครบ ฟันครบ! ลองอีกรอบแบบไม่ตายดูไหม')
    : `ยังขาดเศษทอง ${world.shards.length - got} ชิ้น · เงาหมึก ${world.enemies.length - kills} ตัว`;
  finishTimer = setTimeout(() => $('win').classList.remove('hidden'), 1400);
}

// ---------- render ----------
function drawProps(ctx, cx, cy) {
  const t = performance.now() / 1000;
  for (const c of world.checkpoints) {
    const x = Math.round(c.x - cx), y = Math.round(c.y - cy);
    ctx.fillStyle = P.wood; ctx.fillRect(x - 1, y - 22, 3, 22);
    ctx.fillStyle = P.navyDD; ctx.fillRect(x - 6, y - 32, 13, 2);
    ctx.fillStyle = c.lit ? P.red : P.crimsonD; ctx.fillRect(x - 4, y - 30, 9, 9);
    ctx.fillStyle = c.lit ? P.goldHi : P.crimson; ctx.fillRect(x - 2, y - 28, 5, 5);
    if (c.lit) { ctx.fillStyle = `rgba(255,163,3,${.12 + .05 * Math.sin(t * 5)})`; ctx.beginPath(); ctx.arc(x + .5, y - 26, 16, 0, 7); ctx.fill(); }
  }
  for (const s of level.signs || []) {                              // little wooden sign posts
    const x = Math.round(s.col * T + 8 - cx), y = Math.round(groundY(s.col) - cy);
    ctx.fillStyle = P.wood; ctx.fillRect(x, y - 12, 2, 12);
    ctx.fillStyle = P.rust; ctx.fillRect(x - 5, y - 17, 12, 7);
    ctx.fillStyle = P.goldHi; ctx.fillRect(x - 3, y - 15, 8, 1); ctx.fillRect(x - 3, y - 13, 6, 1);
  }
  {
    const x = Math.round(GOAL.x - cx), y = Math.round(GOAL.y - cy);
    ctx.fillStyle = P.crimson; ctx.fillRect(x + 6, y - 70, 5, 70); ctx.fillRect(x + 41, y - 70, 5, 70);
    ctx.fillStyle = P.red; ctx.fillRect(x + 7, y - 70, 2, 70); ctx.fillRect(x + 42, y - 70, 2, 70);
    ctx.fillStyle = P.crimson; ctx.fillRect(x + 2, y - 60, 48, 4);
    ctx.fillStyle = P.navyDD; ctx.fillRect(x - 4, y - 78, 60, 4);
    ctx.fillStyle = P.red; ctx.fillRect(x - 2, y - 74, 56, 4); ctx.fillRect(x - 6, y - 79, 4, 3); ctx.fillRect(x + 54, y - 79, 4, 3);
    ctx.fillStyle = P.gold; ctx.fillRect(x + 22, y - 70, 8, 10);
    ctx.fillStyle = `rgba(255,255,204,${.06 + .04 * Math.sin(t * 2)})`; ctx.fillRect(x + 11, y - 56, 30, 56);
  }
  for (const s of world.shards) if (!s.got) {
    const x = Math.round(s.x - cx), y = Math.round(s.y - cy + Math.sin(t * 3 + s.ph) * 2);
    ctx.fillStyle = 'rgba(255,163,3,.18)'; ctx.fillRect(x - 5, y - 6, 11, 13);
    ctx.fillStyle = P.goldD; for (let r = -4; r <= 4; r++) { const w = 4 - Math.abs(r); ctx.fillRect(x - w, y + r, w * 2 + 1, 1); }
    ctx.fillStyle = P.gold; for (let r = -4; r <= 2; r++) { const w = Math.max(0, 3 - Math.abs(r)); ctx.fillRect(x - w, y + r, w * 2, 1); }
    ctx.fillStyle = P.goldHi; ctx.fillRect(x - 1, y - 3, 1, 2);
    if (Math.sin(t * 4 + s.ph * 3) > .85) { ctx.fillStyle = P.white; ctx.fillRect(x + 3, y - 6, 1, 3); ctx.fillRect(x + 2, y - 5, 3, 1); }
  }
  for (const m of world.movers) {
    const x = Math.round(m.x - cx), y = Math.round(m.y - cy);
    ctx.fillStyle = P.wood; ctx.fillRect(x, y, m.w, 6);
    ctx.fillStyle = P.gold; ctx.fillRect(x, y, m.w, 1);
    ctx.fillStyle = P.rust; ctx.fillRect(x, y + 5, m.w, 1);
    ctx.fillStyle = P.crimson; ctx.fillRect(x + 3, y + 6, 2, 3); ctx.fillRect(x + m.w - 5, y + 6, 2, 3);
    ctx.fillStyle = P.goldHi; for (let i = 6; i < m.w - 4; i += 10) ctx.fillRect(x + i, y + 2, 2, 2);
  }
}
const groundCache = {};
function groundY(col) {
  if (groundCache[col] !== undefined) return groundCache[col];
  for (let ty = 0; ty < ROWS; ty++) if (solid(col, ty)) return (groundCache[col] = ty * T);
  return (groundCache[col] = ROWS * T);
}

function drawPlayer(ctx, cx, cy) {
  const pl = world.pl;
  drawGhosts(ctx, cx, cy);
  if (pl.state === 'dead') return;
  const ps = pose(pl);
  const blink = pl.inv > 0 && !['down', 'getup', 'hurt'].includes(pl.state) && Math.floor(pl.inv * 20) % 2;
  const alpha = (ps.alpha ?? 1) * (blink ? .35 : 1);
  drawBody(ctx, sprites.sheet, pl.x - cx, pl.y - cy, pl.face, ps, alpha);
  if (ps.flash) drawBody(ctx, sprites.white, pl.x - cx, pl.y - cy, pl.face, ps, ps.flash * alpha);
  if (ps.glow) drawBody(ctx, sprites.ghost, pl.x - cx, pl.y - cy, pl.face, ps, Math.min(1, ps.glow), 'lighter');
  const stage = attackStage(pl);                       // VFX layer, separate from the body
  if (stage >= 0) {
    const A = ATTACKS[pl.atk.kind];
    if (A.arc) drawArc(ctx, A.arc, stage, pl.x - cx, pl.y - cy, pl.face);
    if (A.line) drawThrust(ctx, pl.x - cx, pl.y - cy, pl.face, stage);
  }
}

export function render(ctx) {
  const sh = world.shake, sx = sh ? Math.round((rnd() - .5) * 2 * sh) : 0, sy = sh ? Math.round((rnd() - .5) * 2 * sh) : 0;
  const cx = Math.round(world.cam.x) + sx, cy = Math.round(world.cam.y) + sy;
  ctx.drawImage(sky, 0, 0);
  const fx0 = -(cx * .15) % 960, mx = -(cx * .4) % 960;
  ctx.drawImage(farHills, fx0, 0); ctx.drawImage(farHills, fx0 + 960, 0);
  ctx.drawImage(nearHills, mx, 18); ctx.drawImage(nearHills, mx + 960, 18);
  ctx.fillStyle = P.lilac; ctx.globalAlpha = .55;
  for (const p of petals) ctx.fillRect(Math.round(p.x), Math.round(p.y), p.s, 1);
  ctx.globalAlpha = 1;
  ctx.drawImage(levelCanvas, cx, cy, W, H, 0, 0, W, H);
  drawProps(ctx, cx, cy);
  drawEnemies(ctx, cx, cy);
  drawPlayer(ctx, cx, cy);
  drawFx(ctx, cx, cy);
  drawParticles(ctx, cx, cy);
  const pl = world.pl;
  if (pl.state === 'dead' && pl.dead > .45) { ctx.fillStyle = `rgba(255,14,0,${(pl.dead - .45) * .8})`; ctx.fillRect(0, 0, W, H); }
}

// ---------- HUD ----------
let lastSign = null, hintTimer = 0;
export function hud() {
  const pl = world.pl;
  $('hShards').textContent = `${world.shards.filter(s => s.got).length}/${world.shards.length}`;
  $('hKills').textContent = `${world.enemies.filter(e => e.dead).length}/${world.enemies.length}`;
  $('hTime').textContent = world.time.toFixed(1);
  $('hLevel').textContent = levelIndex + 1;
  $('hDeaths').textContent = world.deaths;
  $('hHp').textContent = '♥'.repeat(Math.max(0, pl.hp)) + '♡'.repeat(Math.max(0, K.HP - pl.hp));
  const near = (level.signs || []).find(s => Math.abs(s.col * T + 8 - pl.x) < 48);
  if (near !== lastSign) {
    lastSign = near;
    if (near) { $('hint').textContent = near.text; $('hint').style.opacity = 1; clearTimeout(hintTimer); }
    else hintTimer = setTimeout(() => { $('hint').style.opacity = 0; }, 1200);
  }
}
