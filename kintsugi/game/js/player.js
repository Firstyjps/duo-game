// Player state machine. Every move is a state; `pose()` turns the current state into a body frame + transform.
import { T, P, K } from './config.js';
import { keys, pressed, axis } from './input.js';
import { world } from './world.js';
import { tileAt, solid, SPIKE, LADDER, LADDER_TOP, ROWS } from './level.js';
import { burst, dust, addFx, addGhost } from './fx.js';
import { ATTACKS } from './moves.js';
import { hitEnemies, touchingEnemy } from './enemies.js';
import { sfx } from './audio.js';
import { animLength, frameMs } from './sprites.js';

const TAU = Math.PI * 2;
const FLIP_T = .32, TURN_T = .16, DOWN_T = .38, GETUP_T = .3, POWER_T = .8, LAND_T = .12, CHARGE_MIN = .45;

export function newPlayer(x, y) {
  return {
    x, y, vx: 0, vy: 0, face: 1, ground: false, ride: null,
    state: 'move', st: 0, low: false,
    anim: 'idle', ai: 0, at: 0, sx: 1, sy: 1, spinT: 0,
    coyote: 0, buffer: 0, jumps: 1, canDash: true, dashCd: 0, ghostT: 0, dustT: 0,
    hp: K.HP, inv: 0, lock: 0, counterWin: 0, wallDir: 0, awayT: 0, ladderX: 0, hopT: 0,
    atk: null, dead: 0,
  };
}

const ph = pl => pl.low ? K.PH_LOW : K.PH;
const setState = (pl, s) => { pl.state = s; pl.st = 0; };

// ---------- tile queries ----------
function overlaps(pl, x, y, h = ph(pl)) {
  const l = Math.floor((x - K.PW / 2) / T), r = Math.floor((x + K.PW / 2 - .01) / T);
  const t = Math.floor((y - h) / T), b = Math.floor((y - .01) / T);
  for (let ty = t; ty <= b; ty++) for (let tx = l; tx <= r; tx++) if (solid(tx, ty)) return { tx, ty };
  return null;
}
const canStand = pl => !overlaps(pl, pl.x, pl.y, K.PH);
function wallAt(pl, dir) {
  const tx = Math.floor((pl.x + dir * (K.PW / 2 + 1)) / T);
  const t = Math.floor((pl.y - ph(pl) + 4) / T), b = Math.floor((pl.y - 6) / T);
  for (let ty = t; ty <= b; ty++) if (solid(tx, ty)) return true;
  return false;
}
function ladderAt(pl) {
  const tx = Math.floor(pl.x / T), t = Math.floor((pl.y - ph(pl)) / T), b = Math.floor((pl.y - 1) / T);
  for (let ty = t; ty <= b; ty++) { const v = tileAt(tx, ty); if (v === LADDER || v === LADDER_TOP) return tx; }
  return -1;
}
const ladderTopBelow = pl => { const tx = Math.floor(pl.x / T); return tileAt(tx, Math.floor((pl.y + 1) / T)) === LADDER_TOP ? tx : -1; };
function ladderTopY(tx) { for (let ty = 0; ty < ROWS; ty++) if (tileAt(tx, ty) === LADDER_TOP) return ty * T; return 0; }
function hitSpike(pl) {
  const l = Math.floor((pl.x - K.PW / 2 + 2) / T), r = Math.floor((pl.x + K.PW / 2 - 2) / T);
  const t = Math.floor((pl.y - ph(pl)) / T), b = Math.floor((pl.y - 1) / T);
  for (let ty = t; ty <= b; ty++) for (let tx = l; tx <= r; tx++)
    if (tileAt(tx, ty) === SPIKE && pl.y > ty * T + 9) return true;
  return false;
}

// ---------- physics ----------
function physics(pl, dt, gravMul = 1, maxFall = K.MAX_FALL) {
  if (gravMul) {
    const g = pl.vy < 0 && !keys.jump && pl.state === 'air' && !pl.lock ? K.GRAV * 2.2 : pl.vy > 0 ? K.GRAV * 1.15 : K.GRAV;
    pl.vy = Math.min(maxFall, pl.vy + g * gravMul * dt);
  }
  if (pl.ride) { pl.x += pl.ride.dx; if (overlaps(pl, pl.x, pl.y)) pl.x -= pl.ride.dx; }
  pl.x += pl.vx * dt;
  let hit = overlaps(pl, pl.x, pl.y);
  if (hit) { pl.x = pl.vx > 0 ? hit.tx * T - K.PW / 2 : (hit.tx + 1) * T + K.PW / 2; pl.vx = 0; }

  const prevY = pl.y, fallV = pl.vy;
  pl.y += pl.vy * dt; pl.ground = false; pl.ride = null;
  hit = overlaps(pl, pl.x, pl.y);
  if (hit) {
    if (pl.vy > 0) { pl.y = Math.floor((pl.y - .01) / T) * T; pl.ground = true; }
    else pl.y = (Math.floor((pl.y - ph(pl)) / T) + 1) * T + ph(pl);
    pl.vy = 0;
  }
  if (fallV >= 0) {
    for (const m of world.movers)
      if (pl.x + K.PW / 2 > m.x && pl.x - K.PW / 2 < m.x + m.w && prevY <= m.y + 1 && pl.y >= m.y) { pl.y = m.y; pl.vy = 0; pl.ground = true; pl.ride = m; }
    const l = Math.floor((pl.x - K.PW / 2) / T), r = Math.floor((pl.x + K.PW / 2 - .01) / T), ty = Math.floor((pl.y - .01) / T);
    for (let tx = l; tx <= r; tx++)                         // one-way ladder tops
      if (tileAt(tx, ty) === LADDER_TOP && prevY <= ty * T + 1 && pl.y >= ty * T) { pl.y = ty * T; pl.vy = 0; pl.ground = true; }
  }
  return fallV;
}

function land(pl, fallV) {
  pl.jumps = 1; pl.canDash = true; pl.spinT = 0;
  if (fallV > 470) { pl.sx = 1.3; pl.sy = .72; dust(pl.x, pl.y, 12, 0, 90); world.shake = Math.max(world.shake, 1.5); sfx('heavyland'); return true; }
  if (fallV > 200) { pl.sx = 1.22; pl.sy = .78; dust(pl.x, pl.y, 8); sfx('land'); }
  return false;
}

// ---------- shared actions ----------
function jump(pl) {
  pl.vy = -K.JUMP_V; pl.buffer = 0; pl.coyote = 0; pl.ground = false; pl.ride = null; pl.low = false;
  pl.sx = .82; pl.sy = 1.2; dust(pl.x, pl.y, 6, -pl.face); sfx('jump');
  setState(pl, 'air');
}
function flip(pl) {                       // double jump with a forward somersault
  pl.vy = -K.DJUMP_V; pl.jumps--; pl.buffer = 0; pl.spinT = FLIP_T; sfx('doublejump');
  for (let i = 0; i < 8; i++) burst(pl.x, pl.y, 1, [P.lilac, P.white], 60, .3, 0);
  addFx('ring', pl.x, pl.y + 2, .25, { face: 1 });
}
function startDash(pl, dir) {
  if (dir) pl.face = dir;
  if (!pl.ground) pl.canDash = false;
  pl.atk = null; pl.dashCd = .32; pl.low = false;
  pl.vx = pl.face * K.DASH_V; pl.vy = 0; pl.sx = 1.3; pl.sy = .8; pl.ghostT = 0;
  dust(pl.x, pl.y, 6, -pl.face, 90); sfx('dash');
  addFx('lines', pl.x, pl.y - 22, .22, { face: pl.face });
  addFx('ring', pl.x - pl.face * 6, pl.y - 22, .3, { face: pl.face });
  setState(pl, 'dash');
}
function startRoll(pl, dir) {
  if (dir) pl.face = dir;
  pl.counterBuf = false;
  pl.low = true; pl.ghostT = 0; pl.atk = null;
  dust(pl.x, pl.y, 5, -pl.face, 70); sfx('roll');
  setState(pl, 'roll');
}
function startAttack(pl, kind, dir) {
  const A = ATTACKS[kind];
  if (dir) pl.face = dir;
  pl.atk = { kind, phase: 'antic', t: 0, queued: null };
  pl.low = false;
  if (A.hop && pl.ground) { pl.vy = A.hop; pl.ground = false; pl.ride = null; }
  if (A.float) pl.vy = Math.min(pl.vy, 40);
  if (A.dive) { pl.vy = kind === 'pillar' ? 0 : -90; pl.vx *= .3; }
  if (!A.float) pl.vx *= .3;
  setState(pl, 'attack');
}
function kintsugiBurst(pl, power) {                    // charged special: light pillar + gold ring, hits all around
  const r = 70 + power * 40;
  startAttack(pl, 'burst', 0);
  addFx('kpillar', pl.x, pl.y, .6); addFx('circle', pl.x, pl.y - 22, .45, { r }); addFx('rays', pl.x, pl.y, .5);
  burst(pl.x, pl.y - 20, 30, [P.gold, P.goldHi, P.jade, P.white], 260, .8, 120);
  hitEnemies(pl, [-r, -80, 2 * r, 84], { dmg: 2 + (power >= 1 ? 1 : 0), kb: 260 });
  world.shake = 6; world.hitstop = Math.max(world.hitstop, .07); sfx('burst');
}
function ghostTrail(pl, dt, every) {
  pl.ghostT -= dt;
  if (pl.ghostT <= 0) { pl.ghostT = every; addGhost(pl.x, pl.y, pl.face, pose(pl)); }
}

export function hurt(pl, from) {
  pl.hp--; pl.atk = null; pl.low = false; world.shake = 3; sfx('hurt');
  pl.chargeSnd?.stop?.();
  burst(pl.x, pl.y - 20, 12, [P.white, P.red, P.lilac], 120, .4, 200);
  if (pl.hp <= 0) { die(pl); return; }
  pl.inv = K.INV + DOWN_T + GETUP_T;
  pl.vx = (pl.x < from.x ? -1 : 1) * 150; pl.vy = -240; pl.face = pl.x < from.x ? 1 : -1;
  setState(pl, 'hurt');
}
export function die(pl) {
  if (pl.dead) return;
  pl.dead = .7; pl.atk = null; world.deaths++; world.shake = 4; sfx('die');
  pl.chargeSnd?.stop?.();
  burst(pl.x, pl.y - 20, 26, [P.lilac, P.white, P.royal, P.gold], 160, .7, 200);
  setState(pl, 'dead');
}
export function startPower(pl) { sfx('chargeready'); pl.vx = 0; pl.atk = null; pl.low = false; pl.hp = K.HP; addFx('aura', pl.x, pl.y, .8); setState(pl, 'power'); }
export function startCheer(pl) { pl.atk = null; pl.low = false; pl.hopT = .25; setState(pl, 'cheer'); }

const invulnerable = pl => pl.inv > 0 || pl.dead || ['dash', 'roll', 'power', 'cheer', 'down', 'getup', 'hurt'].includes(pl.state)
  || (pl.state === 'attack' && ['smear', 'active', 'dive'].includes(pl.atk.phase));

// ---------- update ----------
export function updatePlayer(dt) {
  const pl = world.pl, dir = axis();
  pl.st += dt; pl.inv = Math.max(0, pl.inv - dt); pl.lock = Math.max(0, pl.lock - dt);
  pl.dashCd -= dt; pl.counterWin -= dt; pl.spinT = Math.max(0, pl.spinT - dt);
  pl.buffer = pressed.jump ? .12 : pl.buffer - dt;

  if (pl.state === 'dead') {
    pl.dead -= dt;
    if (pl.dead <= 0) {
      Object.assign(pl, newPlayer(world.respawn.x, world.respawn.y), { face: pl.face });
      burst(pl.x, pl.y - 20, 14, [P.gold, P.goldHi], 80, .5, 0);
    }
    return;
  }

  STATES[pl.state](pl, dt, dir);

  if (pl.state !== 'dead') {
    if (hitSpike(pl) || pl.y > ROWS * T + 40) die(pl);
    else if (!invulnerable(pl)) { const e = touchingEnemy(pl, ph(pl)); if (e) hurt(pl, e); }
  }
  if (!['dash'].includes(pl.state)) { pl.sx += (1 - pl.sx) * Math.min(1, dt * 12); pl.sy += (1 - pl.sy) * Math.min(1, dt * 12); }
}

function groundControl(pl, dt, dir) {
  const max = pl.low ? K.CRAWL : keys.run ? K.RUN : K.WALK;
  if (dir) { pl.vx += dir * K.ACC * dt; pl.face = dir; }
  else { const f = K.FRICTION * dt; pl.vx = Math.abs(pl.vx) <= f ? 0 : pl.vx - Math.sign(pl.vx) * f; }
  if (Math.abs(pl.vx) > max) pl.vx = Math.sign(pl.vx) * Math.max(max, Math.abs(pl.vx) - K.FRICTION * 1.5 * dt);
}

function stepLocomotionAnim(pl, dt) {
  const moving = Math.abs(pl.vx) > 8;
  let want = moving ? (pl.anim === 'idle' ? 'from_idle' : pl.anim === 'from_idle' ? 'from_idle' : 'walk') : 'idle';
  if (want !== pl.anim) { pl.anim = want; pl.ai = 0; pl.at = 0; }
  pl.at += dt * 1000;
  for (;;) {
    let ms = frameMs(pl.anim, pl.ai);
    if (pl.anim === 'walk') ms *= K.WALK / Math.max(60, Math.abs(pl.vx));
    if (pl.at < ms) break;
    pl.at -= ms; pl.ai++;
    if (pl.ai >= animLength(pl.anim)) { if (pl.anim === 'from_idle') { pl.anim = 'walk'; } pl.ai = 0; }
    if (pl.anim === 'walk' && (pl.ai === 5 || pl.ai === 17)) { dust(pl.x - pl.face * 6, pl.y, Math.abs(pl.vx) > 150 ? 4 : 2, -pl.face); sfx('step', { volume: pl.low ? .3 : .6 }); }
  }
}

const STATES = {
  move(pl, dt, dir) {
    pl.low = keys.down || (pl.low && !canStand(pl));
    if (!pl.low && Math.abs(pl.vx) > 150 && dir && dir === -Math.sign(pl.vx)) { setState(pl, 'turn'); return; }
    if (pressed.down && keys.run && Math.abs(pl.vx) > 150) { startSlide(pl); return; }
    if (pressed.roll) { if (dir) startRoll(pl, dir); else { pl.chargeReady = false; pl.chargeSnd = sfx('charge'); setState(pl, 'charge'); } return; }
    if (pressed.dash && pl.dashCd <= 0) { startDash(pl, dir); return; }
    if (pressed.attack) { startAttack(pl, pl.counterWin > 0 ? 'counter' : 'slash1', dir); return; }
    if (keys.up && ladderAt(pl) >= 0) { enterLadder(pl, ladderAt(pl)); return; }
    if (keys.down && ladderTopBelow(pl) >= 0) { enterLadder(pl, ladderTopBelow(pl)); pl.y += 2; return; }
    if (pl.buffer > 0 && (!pl.low || canStand(pl))) { jump(pl); return; }
    groundControl(pl, dt, dir);
    physics(pl, dt);
    pl.coyote = .09;
    if (!pl.ground) { pl.low = false; setState(pl, 'air'); return; }
    stepLocomotionAnim(pl, dt);
  },

  air(pl, dt, dir) {
    pl.coyote -= dt;
    if (pl.buffer > 0 && pl.coyote > 0) { jump(pl); }
    else if (pressed.jump && pl.jumps > 0) flip(pl);
    if (pressed.attack) { startAttack(pl, keys.down ? 'plunge' : 'air', dir); return; }
    if (pressed.dash && pl.canDash && pl.dashCd <= 0) { startDash(pl, dir); return; }
    if (keys.up && ladderAt(pl) >= 0 && pl.vy > -200) { enterLadder(pl, ladderAt(pl)); return; }
    if (!pl.lock) {
      if (dir) { pl.vx += dir * K.AIR_ACC * dt; pl.face = dir; }
      const max = keys.run ? K.RUN : K.WALK;
      if (Math.abs(pl.vx) > max) pl.vx = Math.sign(pl.vx) * Math.max(max, Math.abs(pl.vx) - 600 * dt);
    }
    if (dir && pl.vy > -40 && !pl.lock && wallAt(pl, dir)) { pl.wallDir = dir; pl.awayT = 0; pl.spinT = 0; setState(pl, 'wall'); return; }
    const fallV = physics(pl, dt);
    if (pl.ground) setState(pl, land(pl, fallV) ? 'land' : 'move');
  },

  land(pl, dt) {                                           // heavy landing: brief stop
    const f = K.FRICTION * 3 * dt; pl.vx = Math.abs(pl.vx) <= f ? 0 : pl.vx - Math.sign(pl.vx) * f;
    physics(pl, dt);
    if (pl.st >= LAND_T) setState(pl, 'move');
  },

  charge(pl, dt) {                                         // hold V: gather light, release for a kintsugi burst
    const f = K.FRICTION * 3 * dt; pl.vx = Math.abs(pl.vx) <= f ? 0 : pl.vx - Math.sign(pl.vx) * f;
    const ready = pl.st >= CHARGE_MIN;
    if (Math.random() < dt * 80) {
      const a = Math.random() * Math.PI * 2, r = 26 + Math.random() * 10;
      burst(pl.x + Math.cos(a) * r, pl.y - 22 + Math.sin(a) * r * .6, 1, ready ? [P.gold, P.goldHi] : [P.ice, P.jade], 1, .25, 0);
    }
    if (ready && !pl.chargeReady) { pl.chargeReady = true; addFx('circle', pl.x, pl.y - 22, .3, { r: 30 }); sfx('chargeready'); }
    physics(pl, dt);
    if (pl.buffer > 0) { pl.chargeSnd?.stop?.(); jump(pl); return; }
    if (!keys.roll) {
      pl.chargeSnd?.stop?.();
      if (!ready) { startRoll(pl, 0); return; }                // a short tap is still a roll
      kintsugiBurst(pl, Math.min(1, (pl.st - CHARGE_MIN) / .7));
    }
  },

  wall(pl, dt, dir) {
    const w = pl.wallDir;
    pl.face = -w; pl.jumps = 1; pl.canDash = true;
    if (pl.buffer > 0) {                                   // wall jump
      pl.buffer = 0; pl.vx = -w * K.WJ_VX; pl.vy = -K.WJ_VY; pl.lock = .16; pl.sx = .85; pl.sy = 1.15;
      burst(pl.x + w * 7, pl.y - 20, 8, [P.lilac, P.white], 70, .3, 60); sfx('walljump');
      setState(pl, 'air'); return;
    }
    if (pressed.attack) { pl.face = -w; startAttack(pl, 'air', 0); return; }
    pl.awayT = dir === -w ? pl.awayT + dt : 0;
    if (pl.awayT > .1 || !wallAt(pl, w)) { setState(pl, 'air'); return; }
    pl.vx = w * 20;
    pl.vy = Math.min(K.WALL_SLIDE, pl.vy + K.GRAV * dt);
    pl.dustT -= dt; if (pl.dustT <= 0) { pl.dustT = .06; dust(pl.x + w * 7, pl.y - 30, 1, 0, 20); if (pl.vy > 40) sfx('wallslide', { volume: .4 }); }
    physics(pl, dt, 0);
    if (pl.ground) { land(pl, 0); setState(pl, 'move'); }
  },

  ladder(pl, dt, dir) {
    pl.x = pl.ladderX * T + 8; pl.vx = 0;
    if (pl.buffer > 0) { pl.buffer = 0; pl.vy = -300; pl.vx = dir * K.WALK; pl.jumps = 1; setState(pl, 'air'); return; }
    const v = ((keys.down ? 1 : 0) - (keys.up ? 1 : 0)) * K.CLIMB;
    pl.vy = v; pl.y += v * dt;
    if (v && Math.floor(pl.y / 8) !== Math.floor((pl.y - v * dt) / 8)) sfx('climb');
    const top = ladderTopY(pl.ladderX);
    if (v < 0 && pl.y <= top) { pl.y = top; pl.vy = 0; pl.ground = true; setState(pl, 'move'); return; }
    if (v > 0) { const hit = overlaps(pl, pl.x, pl.y); if (hit) { pl.y = hit.ty * T; pl.vy = 0; pl.ground = true; setState(pl, 'move'); return; } }
    if (ladderAt(pl) < 0 && pl.y > top) { setState(pl, 'air'); }
  },

  dash(pl, dt) {
    pl.vx = pl.face * K.DASH_V; pl.vy = 0;
    ghostTrail(pl, dt, .045);
    physics(pl, dt, 0);
    if (pl.st >= K.DASH_T) { pl.vx = pl.face * K.RUN; setState(pl, pl.ground ? 'move' : 'air'); }
  },

  roll(pl, dt, dir) {
    const p = Math.min(1, pl.st / K.ROLL_T);
    if (pressed.attack) pl.counterBuf = true;
    pl.vx = pl.face * K.ROLL_V * (1 - .4 * p);
    ghostTrail(pl, dt, .05);
    physics(pl, dt);
    if (p >= 1) {
      pl.counterWin = .25; pl.low = !canStand(pl);
      if (pl.counterBuf && pl.ground && !pl.low) { pl.counterBuf = false; startAttack(pl, 'counter', dir); return; }
      setState(pl, pl.ground ? 'move' : 'air');
    }
  },

  slide(pl, dt) {
    const p = Math.min(1, pl.st / K.SLIDE_T);
    pl.vx = pl.face * (K.SLIDE_V * (1 - p) + 80 * p);
    ghostTrail(pl, dt, .05);
    pl.dustT -= dt; if (pl.dustT <= 0) { pl.dustT = .03; dust(pl.x - pl.face * 8, pl.y, 1, -pl.face, 50); }
    if (pl.buffer > 0 && canStand(pl)) { jump(pl); return; }
    physics(pl, dt);
    if (!pl.ground) { pl.low = false; setState(pl, 'air'); return; }
    if (p >= 1 || pl.vx === 0) { pl.low = !canStand(pl) || keys.down; setState(pl, 'move'); }
  },

  turn(pl, dt, dir) {
    const f = K.FRICTION * 2.5 * dt;
    pl.vx = Math.abs(pl.vx) <= f ? 0 : pl.vx - Math.sign(pl.vx) * f;
    pl.dustT -= dt; if (pl.dustT <= 0) { pl.dustT = .03; dust(pl.x + pl.face * 6, pl.y, 2, pl.face, 80); }
    physics(pl, dt);
    if (pl.buffer > 0) { pl.face = dir || -pl.face; jump(pl); return; }
    if (pl.st >= TURN_T) { pl.face = dir || -pl.face; pl.vx = pl.face * 60; setState(pl, 'move'); }
  },

  attack(pl, dt, dir) { updateAttack(pl, dt, dir); },

  hurt(pl, dt) {
    const fallV = physics(pl, dt);
    if (pl.ground && pl.st > .1) { land(pl, fallV); pl.vx = 0; setState(pl, 'down'); }
  },
  down(pl, dt) { pl.vx = 0; physics(pl, dt); if (pl.st >= DOWN_T) setState(pl, 'getup'); },
  getup(pl, dt) { physics(pl, dt); if (pl.st >= GETUP_T) setState(pl, 'move'); },

  power(pl, dt) {
    pl.vx = 0; physics(pl, dt);
    if (Math.random() < dt * 30) burst(pl.x + (Math.random() - .5) * 24, pl.y - 4, 1, [P.goldHi, P.gold], 30, .6, -80);
    if (pl.st >= POWER_T) setState(pl, 'move');
  },

  cheer(pl, dt) {
    const f = K.FRICTION * dt; pl.vx = Math.abs(pl.vx) <= f ? 0 : pl.vx - Math.sign(pl.vx) * f;
    pl.hopT -= dt;
    if (pl.ground && pl.hopT <= 0) { pl.hopT = .55; pl.vy = -210; pl.spinT = FLIP_T; burst(pl.x, pl.y - 40, 14, [P.gold, P.goldHi, P.red, P.mint], 130, .7, 160); }
    physics(pl, dt);
  },
};

function startSlide(pl) { sfx('slide'); pl.low = true; pl.ghostT = 0; pl.sx = 1.2; pl.sy = .8; dust(pl.x, pl.y, 8, -pl.face, 120); setState(pl, 'slide'); }
function enterLadder(pl, tx) { pl.ladderX = tx; pl.low = false; pl.vx = 0; pl.vy = 0; pl.atk = null; pl.jumps = 1; setState(pl, 'ladder'); }

// ---------- attacks ----------
function updateAttack(pl, dt, dir) {
  const a = pl.atk, A = ATTACKS[a.kind];
  a.t += dt * 1000;
  if (pressed.attack) { if (a.queued) a.queued.up ||= keys.up; else a.queued = { up: keys.up }; }  // first press queues, ↑ on any press branches
  let grav = 1;
  switch (a.phase) {
    case 'antic':
      if (a.kind === 'pillar') { grav = 0; pl.vy = 0; pl.vx = 0; }
      if (a.t >= A.antic) {
        a.t = 0;
        if (A.dive) {
          a.phase = 'dive';
          if (a.kind === 'pillar') { addFx('pillar', pl.x, pl.y, .35); sfx('burst'); } else sfx('plunge');
        } else {
          a.phase = 'smear';
          if (A.lunge) pl.vx = pl.face * A.lunge;
          if (A.sound !== false) sfx(A.sound || 'slash1', A.pitch ? { pitch: A.pitch } : undefined);
        }
      }
      break;
    case 'smear':
      if (a.kind === 'counter') ghostTrail(pl, dt, .03);
      if (a.t >= A.smear) {
        a.t = 0; a.phase = 'active';
        if (A.shock && pl.ground) { addFx('shock', pl.x + pl.face * 14, pl.y, .4); dust(pl.x - 10, pl.y, 8, -1, 150, 2); dust(pl.x + 10, pl.y, 8, 1, 150, 2); world.shake = Math.max(world.shake, 2.5); }
        hitEnemies(pl, A.hb, { dmg: A.dmg, kb: A.kb, launch: A.launch, spark: A.spark });
      }
      break;
    case 'dive':
      grav = 0; pl.vx = 0; pl.vy = A.dive;
      if (a.kind === 'pillar') ghostTrail(pl, dt, .03);
      if (pl.ground) {
        a.phase = 'active'; a.t = 0; pl.sx = 1.35; pl.sy = .7;
        addFx('rays', pl.x, pl.y, .5); addFx('shock', pl.x, pl.y, .45, { r: a.kind === 'pillar' ? 64 : 46 });
        burst(pl.x, pl.y - 2, 18, [P.navy, P.lilacD, P.plum, P.navyD], 210, .7, 650, 2);
        burst(pl.x, pl.y - 6, 16, [P.jade, P.ice, P.white], 180, .5, 200);
        if (a.kind === 'pillar') { addFx('pillar', pl.x, pl.y, .4); dust(pl.x - 14, pl.y, 12, -1, 170, 2); dust(pl.x + 14, pl.y, 12, 1, 170, 2); }
        world.shake = Math.max(world.shake, a.kind === 'pillar' ? 6 : 5); sfx('impact');
        hitEnemies(pl, A.hb, { dmg: A.dmg, kb: A.kb });
      } else if (a.t > 1500) { a.phase = 'rec'; a.t = 0; }
      break;
    case 'active':
      if (A.float) grav = .35;
      if (a.t >= A.active) { a.t = 0; a.phase = 'rec'; if (A.flourish) addFx('flourish', pl.x + pl.face * 10, pl.y - 26, .3, { face: pl.face }); }
      break;
    case 'rec': {
      const q = a.queued, nxt = q && A.next && ((q.up && A.next.up) || A.next.x);
      if (nxt && (pl.ground || nxt === 'pillar')) { startAttack(pl, nxt, dir); return; }
      if (a.t >= A.rec) { pl.atk = null; setState(pl, pl.ground ? 'move' : 'air'); return; }
      break;
    }
  }
  if (A.float && a.phase !== 'rec') grav = Math.min(grav, .35);
  if (pl.ground && a.phase !== 'smear') { const f = 2.2 * K.FRICTION * dt; pl.vx = Math.abs(pl.vx) <= f ? 0 : pl.vx - Math.sign(pl.vx) * f; }
  if (A.float && !pl.ground && dir) pl.vx = Math.max(-K.WALK, Math.min(K.WALK, pl.vx + dir * K.AIR_ACC * dt));
  const fallV = physics(pl, dt, grav, A.dive ? 900 : K.MAX_FALL);
  if (pl.ground && fallV > 200 && !A.dive && a.phase !== 'active') { pl.sx = 1.15; pl.sy = .85; dust(pl.x, pl.y, 5); }
  if (pl.ground && a.kind === 'air' && a.phase === 'rec') { pl.atk = null; setState(pl, 'move'); }
}

// ---------- pose ----------
const ATTACK_POSES = {
  //            antic                                             smear                                                   active
  slash1:   [{ anim: 'idle', i: 0, rot: -.1, ox: -2, sx: 1.04, sy: .96 }, { anim: 'walk', i: 3, rot: .16, ox: 3, sx: 1.12, sy: .92, flash: .3 }, { anim: 'walk', i: 3, rot: .1, ox: 2 }],
  thrust:   [{ anim: 'idle', i: 0, rot: -.12, ox: -3, sy: .94 }, { anim: 'walk', i: 3, rot: .25, ox: 5, sx: 1.2, sy: .86, flash: .3 }, { anim: 'walk', i: 3, rot: .2, ox: 4, sx: 1.1, sy: .9 }],
  crescent: [{ anim: 'idle', i: 0, rot: -.15, ox: -2, sy: .9 }, { anim: 'walk', i: 3, rot: .3, ox: 3, sx: 1.18, sy: .78, flash: .3 }, { anim: 'walk', i: 3, rot: .22, sx: 1.15, sy: .8 }],
  uppercut: [{ anim: 'idle', i: 0, rot: .05, sx: 1.06, sy: .88 }, { anim: 'walk', i: 0, rot: -.15, sx: .9, sy: 1.15, flash: .3 }, { anim: 'walk', i: 0, rot: -.1, sy: 1.08 }],
  leap:     [{ anim: 'idle', i: 0, sx: 1.08, sy: .85 }, { anim: 'walk', i: 0, rot: -.2, sy: 1.12, flash: .3 }, { anim: 'walk', i: 0, rot: -.1 }],
  air:      [{ anim: 'walk', i: 0, rot: -.1 }, { anim: 'walk', i: 3, rot: .2, flash: .3 }, { anim: 'walk', i: 3, rot: .12 }],
  plunge:   [{ anim: 'walk', i: 0, rot: -.12, sx: .92, sy: .92 }, null, { anim: 'walk', i: 3, sx: 1.3, sy: .72 }],
  pillar:   [{ anim: 'idle', i: 0, sx: .9, sy: 1.1, alpha: 1 }, null, { anim: 'walk', i: 3, sx: 1.35, sy: .7 }],
  burst:    [{ anim: 'walk', i: 0, rot: -.15, sy: 1.12, flash: .4 }, { anim: 'walk', i: 0, rot: -.15, sy: 1.12, flash: .4 }, { anim: 'walk', i: 0, rot: -.15, sy: 1.12, flash: .4 }],
  counter:  [{ anim: 'idle', i: 0, ox: -2, sy: .9 }, { anim: 'walk', i: 3, rot: .3, ox: 6, sx: 1.3, sy: .82, flash: .4 }, { anim: 'walk', i: 3, rot: .2, ox: 4 }],
};

export function pose(pl) {
  const base = { anim: 'idle', i: 0, rot: 0, spin: 0, ox: 0, sx: pl.sx, sy: pl.sy };
  const flipSpin = pl.spinT > 0 ? (1 - pl.spinT / FLIP_T) * TAU : 0;
  switch (pl.state) {
    case 'move':
      if (pl.low) return { ...base, anim: Math.abs(pl.vx) > 8 ? 'walk' : 'idle', i: pl.ai, sx: pl.sx * 1.08, sy: pl.sy * .74 };
      return { ...base, anim: pl.anim, i: pl.ai, rot: pl.anim === 'walk' ? (Math.abs(pl.vx) > 150 ? .12 : .04) : 0 };
    case 'air':
      if (flipSpin) return { ...base, anim: 'walk', i: 0, spin: flipSpin, sx: .9, sy: .9 };
      return { ...base, anim: 'walk', i: pl.vy < -60 ? 0 : pl.vy < 120 ? 3 : 10, rot: pl.vy < -60 ? -.05 : .04 };
    case 'wall': return { ...base, anim: 'walk', i: 12, rot: -.08, ox: -2 };
    case 'ladder': return { ...base, anim: 'walk', i: Math.floor(pl.y / 6) % 2 ? 0 : 12 };
    case 'dash': return { ...base, anim: 'walk', i: 3, rot: .22 };
    case 'roll': return { ...base, anim: 'idle', i: 0, spin: Math.min(1, pl.st / K.ROLL_T) * TAU, pivot: 14, sx: .85, sy: .7 };
    case 'slide': return { ...base, anim: 'walk', i: 3, rot: -.18, sx: pl.sx * 1.15, sy: pl.sy * .62 };
    case 'turn': return { ...base, anim: 'walk', i: 8, rot: -.2, sx: 1.06, sy: .96 };
    case 'hurt': return { ...base, anim: 'idle', i: 0, rot: -.35, flash: pl.st < .1 ? .6 : 0 };
    case 'down': return { ...base, anim: 'idle', i: 0, rot: -1.45, sy: .95 };
    case 'getup': { const k = Math.min(1, pl.st / GETUP_T); return { ...base, anim: 'idle', i: 0, rot: -1.45 * (1 - k) * (1 - k), sy: .9 + .1 * k }; }
    case 'power': return { ...base, anim: 'idle', i: Math.floor(pl.st * 16) % 10, sy: 1 + .05 * Math.sin(pl.st * 22), flash: .25 + .2 * Math.sin(pl.st * 18) };
    case 'land': return { ...base, anim: 'idle', i: 0 };
    case 'charge': { const k = Math.min(1, pl.st / CHARGE_MIN); return { ...base, anim: 'idle', i: Math.floor(pl.st * 10) % 10, sx: 1.04, sy: .96, glow: k * (.25 + .25 * Math.sin(pl.st * 22)) + (k >= 1 ? .25 : 0) }; }
    case 'cheer': return pl.ground ? { ...base, anim: 'idle', i: Math.floor(pl.st * 16) % 10 } : { ...base, anim: 'walk', i: 0, spin: flipSpin };
    case 'attack': {
      const a = pl.atk, A = ATTACKS[a.kind], set = ATTACK_POSES[a.kind];
      if (a.phase === 'antic') {
        const p = set[0];
        return { ...base, ...p, alpha: a.kind === 'pillar' ? Math.max(0, 1 - a.t / A.antic) : 1 };
      }
      if (a.phase === 'dive') return { ...base, anim: 'walk', i: 10, sx: .8, sy: 1.28 };
      if (a.phase === 'smear') return { ...base, ...set[1] };
      if (a.phase === 'active') return { ...base, ...set[2], sx: set[2].sx ?? pl.sx, sy: set[2].sy ?? pl.sy };
      const last = set[2], k = Math.min(1, a.t / A.rec);
      return { ...base, anim: pl.ground ? 'idle' : 'walk', i: pl.ground ? Math.min(4, Math.floor(k * 5)) : 3, rot: (last.rot || 0) * (1 - k), ox: (last.ox || 0) * (1 - k) };
    }
  }
  return base;
}

/** Which VFX stage the current attack shows: 0 full smear … 3 dissolving, -1 none. */
export function attackStage(pl) {
  const a = pl.atk; if (!a || pl.state !== 'attack') return -1;
  const A = ATTACKS[a.kind];
  if (a.phase === 'smear') return 0;
  if (a.phase === 'active') return a.t < A.active / 2 ? 1 : 2;
  if (a.phase === 'rec' && a.t < 80) return 3;
  return -1;
}
