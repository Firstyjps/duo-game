// Visual effects layer: particles, one-shot effects, after-image ghosts and the smear arcs.
// Effects are drawn on their own layer, never baked into the body frames (guide §1.4).
import { P } from './config.js';
import { rnd } from './level.js';
import { sprites, drawBody } from './sprites.js';

export let parts = [], fx = [], ghosts = [];
export function resetFx() { parts = []; fx = []; ghosts = []; }

export function burst(x, y, n, cols, spd, life, grav = 300, size = 1) {
  for (let i = 0; i < n; i++) {
    const a = rnd() * Math.PI * 2, s = spd * (.4 + rnd() * .6);
    parts.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - spd * .3, life, max: life, c: cols[i % cols.length], g: grav, s: size });
  }
}
export function dust(x, y, n, dir = 0, spd = 60, size = 1) {
  for (let i = 0; i < n; i++) parts.push({ x: x + (rnd() - .5) * 10, y: y - 1, vx: (rnd() - .5) * spd + dir * spd * .6, vy: -rnd() * 30,
    life: .35 + rnd() * .15, max: .5, c: rnd() < .5 ? P.lilacD : P.lilac, g: 40, s: size });
}
export const addFx = (type, x, y, life, extra = {}) => fx.push({ type, x, y, t: 0, life, ...extra });
export const addGhost = (x, y, face, pose, life = .22) => ghosts.push({ x, y, face, pose, life, max: life });

export function tickFx(dt) {
  for (const p of parts) { p.life -= dt; p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; }
  parts = parts.filter(p => p.life > 0);
  for (const f of fx) f.t += dt; fx = fx.filter(f => f.t < f.life);
  for (const g of ghosts) g.life -= dt; ghosts = ghosts.filter(g => g.life > 0);
}

// ---------- smear arcs (precomputed per stage: full → thinning → dissolving) ----------
export const ARC_OX = 48, ARC_OY = 88;
const ARC_S = 128;
const ARC_PAL = {
  mint: [[P.white, P.mint, P.teal], [P.white, P.mint, P.teal], [P.mint, P.teal, P.navy], [P.teal, P.plum, P.navy]],
  lav:  [[P.white, P.lilac, P.royal], [P.white, P.lilac, P.royal], [P.lilac, P.royal, P.navy], [P.lilacD, P.plum, P.navy]],
};
const ARC_SPECS = {
  slash1:   { cx: 4,  cy: -24, R: 28, ex: 1.35, a0: -2.0, a1: 1.0,  th: 14, pal: 'mint' }, // wide horizontal slash
  crescent: { cx: 6,  cy: -16, R: 34, ex: 1.5,  a0: -2.9, a1: 0.7,  th: 17, pal: 'lav' },  // low heavy crescent
  rising:   { cx: 10, cy: -20, R: 30, ex: 1.0,  a0: 1.4,  a1: -1.8, th: 13, pal: 'mint' }, // uppercut
  leap:     { cx: 6,  cy: -30, R: 30, ex: 1.1,  a0: 0.9,  a1: -2.3, th: 13, pal: 'mint' }, // jumping launcher
  air:      { cx: 4,  cy: -28, R: 26, ex: 1.2,  a0: -1.6, a1: 1.3,  th: 12, pal: 'mint' },
};
function makeArc(sp, stage) {
  const c = document.createElement('canvas'); c.width = c.height = ARC_S;
  const g = c.getContext('2d');
  const span = sp.a1 - sp.a0, thMul = [1, .72, .45, .25][stage], cut = stage * .2, pal = ARC_PAL[sp.pal][stage];
  for (let y = 0; y < ARC_S; y++) for (let x = 0; x < ARC_S; x++) {
    if (Math.abs(x - ARC_OX - sp.cx) > (sp.R + 1) * sp.ex) continue;
    const dx = (x - ARC_OX - sp.cx + .5) / sp.ex, dy = y - ARC_OY - sp.cy + .5, r = Math.hypot(dx, dy);
    if (r > sp.R + 1) continue;
    const a = Math.atan2(dy, dx); let u = -1;
    for (const k of [0, 2 * Math.PI, -2 * Math.PI]) { const v = (a + k - sp.a0) / span; if (v >= 0 && v <= 1) { u = v; break; } }
    if (u < cut) continue;
    const th = sp.th * thMul * Math.pow(Math.sin(Math.PI * u), .6) * (.3 + .7 * u);
    if (th < .6 || r < sp.R - th || r > sp.R) continue;
    if (stage && (((x * 73856093) ^ (y * 19349663) ^ (stage * 83492791)) >>> 0) % 100 < stage * 20) continue;
    const d = (sp.R - r) / th;
    g.fillStyle = u < .18 ? pal[2] : d < .35 ? pal[0] : d < .75 ? pal[1] : pal[2];
    g.fillRect(x, y, 1, 1);
  }
  return c;
}
export const ARCS = {};
for (const k in ARC_SPECS) ARCS[k] = [0, 1, 2, 3].map(s => makeArc(ARC_SPECS[k], s));

export function drawArc(ctx, name, stage, x, y, face) {
  if (!ARCS[name] || stage < 0) return;
  ctx.save(); ctx.translate(Math.round(x), Math.round(y)); ctx.scale(face, 1);
  ctx.drawImage(ARCS[name][stage], -ARC_OX, -ARC_OY);
  ctx.restore();
}

// Long iai-style thrust line (hit 2 / dodge counter).
export function drawThrust(ctx, x, y, face, stage) {
  if (stage < 0) return;
  const len = [70, 64, 46, 24][stage], tail = [0, 8, 22, 40][stage];
  ctx.save(); ctx.translate(Math.round(x), Math.round(y)); ctx.scale(face, 1);
  ctx.fillStyle = stage < 2 ? P.white : P.mint; ctx.fillRect(tail, -24, len - tail, 1);
  ctx.fillStyle = P.mint; ctx.fillRect(tail + 4, -25, len - tail - 10, 1); ctx.fillRect(tail + 6, -23, len - tail - 16, 1);
  if (stage < 2) { ctx.fillStyle = P.teal; ctx.fillRect(tail + 14, -26, len - tail - 26, 1); ctx.fillStyle = P.white; ctx.fillRect(len - 2, -25, 3, 3); }
  ctx.restore();
}

export function drawGhosts(ctx, cx, cy) {
  for (const g of ghosts) drawBody(ctx, sprites.ghost, g.x - cx, g.y - cy, g.face, g.pose, g.life / g.max * .5);
}

export function drawFx(ctx, cx, cy) {
  for (const f of fx) {
    const p = f.t / f.life, x = Math.round(f.x - cx), y = Math.round(f.y - cy);
    ctx.globalAlpha = 1;
    switch (f.type) {
      case 'spark': case 'spark-orange': {      // impact star
        const r = Math.round(3 + p * 9), hot = f.type === 'spark-orange';
        ctx.fillStyle = p < .4 ? P.white : hot ? P.orange : P.mint;
        ctx.fillRect(x - r, y, r * 2 + 1, 1); ctx.fillRect(x, y - r, 1, r * 2 + 1);
        ctx.fillStyle = hot ? P.goldD : P.teal; const d = Math.round(r * .6);
        for (let i = 1; i <= d; i++) { ctx.fillRect(x + i, y + i, 1, 1); ctx.fillRect(x - i, y - i, 1, 1); ctx.fillRect(x + i, y - i, 1, 1); ctx.fillRect(x - i, y + i, 1, 1); }
        break;
      }
      case 'shock': {                             // symmetrical ground ring
        const r = Math.round(6 + p * (f.r || 46)); ctx.globalAlpha = 1 - p;
        ctx.fillStyle = P.white; ctx.fillRect(x - r, y - 1, 6, 1); ctx.fillRect(x + r - 6, y - 1, 6, 1);
        ctx.fillStyle = P.mint; ctx.fillRect(x - r, y - 2, 10, 1); ctx.fillRect(x + r - 10, y - 2, 10, 1);
        ctx.fillStyle = P.teal; ctx.fillRect(x - r + 2, y - 4, 4, 2); ctx.fillRect(x + r - 6, y - 4, 4, 2);
        break;
      }
      case 'rays': {                              // 6 beams fanning upward
        const len = Math.round(58 * Math.min(1, p * 3)); ctx.globalAlpha = 1 - p;
        [-1, -.6, -.25, .25, .6, 1].forEach((o, i) => {
          const ang = -Math.PI / 2 + o * .9, w = i === 2 || i === 3 ? 3 : 2;
          for (let s = 0; s < len; s++) {
            ctx.fillStyle = s < len * .35 ? P.white : s < len * .7 ? P.jade : P.ice;
            ctx.fillRect(x + Math.round(Math.cos(ang) * s), y + Math.round(Math.sin(ang) * s), w, 1);
          }
        });
        break;
      }
      case 'pillar': {                            // green teleport beam
        const h = Math.round(110 * Math.min(1, p * 4)), w = Math.max(1, Math.round(9 * (1 - p)));
        ctx.globalAlpha = 1 - p * .7;
        ctx.fillStyle = P.teal; ctx.fillRect(x - w - 2, y - h, w * 2 + 5, h);
        ctx.fillStyle = P.jade; ctx.fillRect(x - w, y - h, w * 2 + 1, h);
        ctx.fillStyle = P.white; ctx.fillRect(x - 1, y - h, 3, h);
        ctx.fillStyle = P.white; ctx.fillRect(x - 14 - Math.round(p * 10), y, 28 + Math.round(p * 20), 1);
        break;
      }
      case 'kpillar': {                           // wide kintsugi light pillar (charged burst)
        const w = Math.round(28 * Math.sin(Math.PI * Math.min(1, p * 1.2))); ctx.globalAlpha = .85 * (1 - p);
        ctx.fillStyle = P.jade; ctx.fillRect(x - w, y - 140, w * 2, 140);
        ctx.fillStyle = P.goldHi; ctx.fillRect(x - Math.round(w * .55), y - 140, Math.round(w * 1.1), 140);
        ctx.fillStyle = P.white; ctx.fillRect(x - Math.round(w * .2), y - 140, Math.max(1, Math.round(w * .4)), 140);
        break;
      }
      case 'circle': {                            // expanding gold ring (charge ready / burst)
        const r = Math.round(f.r * (.2 + p * .8)); ctx.globalAlpha = 1 - p;
        for (let i = 0; i < 64; i++) { const a = i / 64 * Math.PI * 2; ctx.fillStyle = i % 2 ? P.gold : P.goldHi; ctx.fillRect(x + Math.round(Math.cos(a) * r), y + Math.round(Math.sin(a) * r * .55), 2, 1); }
        break;
      }
      case 'ring': {                              // air-dash wind ring (vertical ellipse)
        const ry = Math.round(10 + p * 14), rx = Math.round(3 + p * 4); ctx.globalAlpha = 1 - p;
        ctx.fillStyle = P.lilac;
        for (let a = 0; a < Math.PI * 2; a += .12) ctx.fillRect(x + Math.round(Math.cos(a) * rx * f.face), y + Math.round(Math.sin(a) * ry), 1, 1);
        break;
      }
      case 'aura': {                              // checkpoint power-up
        const r = Math.round(8 + p * 26); ctx.globalAlpha = 1 - p;
        ctx.fillStyle = P.goldHi;
        for (let a = 0; a < Math.PI * 2; a += .08) ctx.fillRect(x + Math.round(Math.cos(a) * r), y - 20 + Math.round(Math.sin(a) * r * .45), 1, 1);
        ctx.fillStyle = P.gold; ctx.fillRect(x - 1, y - 20 - Math.round(p * 60), 3, Math.round(p * 60));
        break;
      }
      case 'lines': {                             // dash speed lines
        ctx.globalAlpha = 1 - p; ctx.fillStyle = P.ice;
        for (let i = 0; i < 5; i++) { const l = 10 + (i * 7) % 13; ctx.fillRect(x - f.face * (18 + p * 40 + i * 3) - (f.face > 0 ? l : 0), y - 14 + i * 7, l, 1); }
        break;
      }
      case 'flourish': {                          // sword spin while sheathing after hit 3
        const a = p * Math.PI * 3, r = 9;
        ctx.fillStyle = p < .6 ? P.white : P.mint;
        ctx.fillRect(x + Math.round(Math.cos(a) * r) * f.face, y + Math.round(Math.sin(a) * r * .5), 2, 2);
        ctx.fillRect(x - Math.round(Math.cos(a) * r) * f.face, y - Math.round(Math.sin(a) * r * .5), 1, 1);
        break;
      }
    }
  }
  ctx.globalAlpha = 1;
}

export function drawParticles(ctx, cx, cy) {
  for (const p of parts) {
    ctx.globalAlpha = Math.max(0, p.life / p.max); ctx.fillStyle = p.c;
    ctx.fillRect(Math.round(p.x - cx), Math.round(p.y - cy), p.s, p.s);
  }
  ctx.globalAlpha = 1;
}
