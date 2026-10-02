// Ink shades: patrol a strip of ground, take knockback and can be launched into the air.
import { T, P } from './config.js';
import { level, rnd } from './level.js';
import { sfx } from './audio.js';
import { world } from './world.js';
import { burst, addFx } from './fx.js';

const GRAV = 900, HP = 3;

export const makeEnemies = () => level.enemies.map(([a, b, y]) => ({
  x0: a * T + 8, x1: b * T + 8, x: (a + b) / 2 * T + 8, y: y * T,
  dir: rnd() < .5 ? -1 : 1, hp: HP, flash: 0, kb: 0, h: 0, hv: 0, dead: false, ph: rnd() * 6,
}));

export function updateEnemies(dt) {
  for (const e of world.enemies) {
    if (e.dead) continue;
    e.flash = Math.max(0, e.flash - dt);
    if (e.h > 0 || e.hv) { e.h += e.hv * dt; e.hv -= GRAV * dt; if (e.h <= 0) { e.h = 0; e.hv = 0; } }
    if (e.kb) { e.x += e.kb * dt; e.kb *= Math.pow(.002, dt); if (Math.abs(e.kb) < 5) e.kb = 0; }
    else if (!e.h) e.x += e.dir * 26 * dt;
    if (e.x < e.x0) { e.x = e.x0; e.dir = 1; }
    if (e.x > e.x1) { e.x = e.x1; e.dir = -1; }
  }
}

/** Resolve an attack box [ox, oy, w, h] placed at the player's feet, facing `face`. Returns true on any hit. */
export function hitEnemies(pl, box, { dmg, kb, launch = 0, spark = 'spark' }) {
  const [ox, oy, w, h] = box;
  const x0 = pl.face > 0 ? pl.x + ox : pl.x - ox - w, y0 = pl.y + oy;
  let any = false;
  for (const e of world.enemies) {
    if (e.dead) continue;
    const ey = e.y - e.h;
    if (e.x + 8 > x0 && e.x - 8 < x0 + w && ey > y0 && ey - 14 < y0 + h) {
      any = true; e.hp -= dmg; e.flash = .12; e.kb = (e.x > pl.x ? 1 : -1) * kb;
      if (launch) e.hv = launch;
      addFx(spark, e.x, ey - 8, .18);
      burst(e.x, ey - 8, 8, spark === 'spark' ? [P.white, P.mint, P.teal] : [P.white, P.orange, P.goldD], 140, .3, 120);
      if (e.hp <= 0) {
        e.dead = true; sfx('kill');
        burst(e.x, ey - 6, 22, [P.navyDD, P.plum, P.plumD, P.lilacD], 150, .6, 260, 2);
        burst(e.x, ey - 6, 10, [P.gold, P.goldHi], 90, .7, 60);
      }
    }
  }
  if (any) sfx('hit');
  if (any) { world.hitstop = Math.max(world.hitstop, dmg > 1 ? .09 : .055); world.shake = Math.max(world.shake, dmg > 1 ? 3 : 1.5); }
  return any;
}

export function touchingEnemy(pl, ph) {
  for (const e of world.enemies) {
    if (e.dead) continue;
    const ey = e.y - e.h;
    if (Math.abs(e.x - pl.x) < 7 + 6 && ey - 12 < pl.y && ey > pl.y - ph + 4) return e;
  }
  return null;
}

export function drawEnemies(ctx, cx, cy) {
  const t = performance.now() / 1000;
  for (const e of world.enemies) {
    if (e.dead) continue;
    const x = Math.round(e.x - cx), y = Math.round(e.y - e.h - cy), h = 12 + Math.round(Math.sin(t * 6 + e.ph)), fl = e.flash > 0;
    for (let i = 0; i < h; i++) {
      const f = i / h, half = Math.round(8 * Math.sqrt(Math.max(0, 1 - Math.pow(f, 2.2))));
      ctx.fillStyle = fl ? P.white : (i >= h - 2 ? P.lilacD : '#6B4A9E'); ctx.fillRect(x - half, y - i - 1, half * 2, 1);
      if (half > 1) { ctx.fillStyle = fl ? P.white : (i > h - 4 ? P.plumD : P.navyDD); ctx.fillRect(x - half + 1, y - i - 1, half * 2 - 2, 1); }
    }
    if (fl) continue;
    ctx.fillStyle = P.plumD;
    for (let k = -7; k < 8; k += 3) ctx.fillRect(x + k, y - 1 + (Math.sin(t * 8 + k + e.ph) > 0 ? 1 : 0), 2, 1);
    const ex = x + e.dir * 2;
    ctx.fillStyle = e.hp < HP ? P.red : P.lilac; ctx.fillRect(ex - 4, y - 8, 2, 2); ctx.fillRect(ex + 2, y - 8, 2, 2);
    ctx.fillStyle = P.white; ctx.fillRect(ex - 4, y - 8, 1, 1); ctx.fillRect(ex + 2, y - 8, 1, 1);
  }
}
