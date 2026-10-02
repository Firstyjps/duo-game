/**
 * Kintsugi Brawler - 2.5D Depth-Lane Beat 'Em Up
 * Built with Three.js r128 (pixel look: 480x270, NearestFilter, Kanit Thai UI)
 */
(function() {
'use strict';

// ============================================================================
// 1. PALETTE & CONSTANTS
// ============================================================================
const P = {
  navy: '#1C154D',
  navyDark: '#151037',
  ink: '#0F121B',
  royal: '#0321BC',
  lilac: '#B2B2FF',
  lilacDark: '#9EA0FA',
  plum: '#40225F',
  plumDark: '#2F1850',
  gold: '#FFA303',
  goldHi: '#FFFFCC',
  goldDark: '#E05E2B',
  rust: '#A64B0A',
  red: '#FF0E00',
  crimson: '#882323',
  wood: '#4D2F1E',
  ice: '#97C0FF',
  white: '#FFFFFF'
};

const W = 480, H = 270;
const TILE_PX = 16;
const Z_MIN = 0.5, Z_MAX = 4.8;
const X_MIN = 0, X_MAX = 130;
const LANE_TOLERANCE = 0.6; // depth lane tolerance for hit detection

// Attack Timing & Hitbox definitions (in ms & world units)
const ATK_DATA = {
  '1':      { antic: 60,  smear: 40, active: 80,  rec: 170, dmg: 1, range: 1.8, sfx: 'slash1' },
  '2':      { antic: 60,  smear: 40, active: 80,  rec: 170, dmg: 1, range: 2.0, sfx: 'slash2' },
  '3':      { antic: 110, smear: 40, active: 110, rec: 240, dmg: 2, range: 2.5, sfx: 'slash3' },
  '2-1':    { antic: 50,  smear: 40, active: 80,  rec: 180, dmg: 1, range: 2.0, sfx: 'slash4' },
  '2-2':    { antic: 70,  smear: 40, active: 100, rec: 260, dmg: 2, range: 2.6, sfx: 'slash5' },
  'air':    { antic: 40,  smear: 40, active: 80,  rec: 120, dmg: 1, range: 1.9, sfx: 'slash1' },
  'air2':   { antic: 40,  smear: 40, active: 80,  rec: 140, dmg: 1, range: 2.1, sfx: 'slash2' },
  'dodge1': { antic: 30,  smear: 70, active: 90,  rec: 200, dmg: 2, range: 2.4, sfx: 'slash3' },
  'dodge2': { antic: 60,  smear: 50, active: 100, rec: 240, dmg: 2, range: 2.6, sfx: 'slash4' },
  'plunge': { antic: 90,  dive: 400, active: 120, rec: 240, dmg: 2, radius: 2.5, sfx: 'impact' }
};

// Crescent Slash Arc specs (rendered via canvas)
const ARC_SPECS = {
  '1':      { cx: 4,  cy: -24, R: 28, ex: 1.3,  a0: -2.0, a1: 1.0,  th: 14 },
  '2':      { cx: 8,  cy: -12, R: 26, ex: 1.45, a0: 1.7,  a1: -1.2, th: 12 },
  '3':      { cx: 10, cy: -30, R: 34, ex: 1.1,  a0: -2.7, a1: 1.25, th: 16 },
  '2-1':    { cx: 6,  cy: -20, R: 28, ex: 1.3,  a0: -1.8, a1: 1.1,  th: 13 },
  'dodge1': { cx: 12, cy: -22, R: 40, ex: 1.9,  a0: -1.0, a1: 0.8,  th: 12 },
  'dodge2': { cx: 10, cy: -28, R: 34, ex: 1.2,  a0: -2.5, a1: 1.2,  th: 15 },
  'air':    { cx: 4,  cy: -28, R: 26, ex: 1.2,  a0: -1.6, a1: 1.3,  th: 12 },
  'air2':   { cx: 6,  cy: -20, R: 28, ex: 1.3,  a0: 1.5,  a1: -1.4, th: 14 }
};

// ============================================================================
// 2. AUDIO WRAPPER
// ============================================================================
let audioUnlocked = false;
function playSFX(name, opts) {
  if (window.SFX && window.SFX.play) {
    try { window.SFX.play(name, opts); } catch (e) {}
  }
}
function unlockAudio() {
  if (!audioUnlocked && window.SFX && window.SFX.unlock) {
    try { window.SFX.unlock(); audioUnlocked = true; } catch (e) {}
  }
}

// ============================================================================
// 3. TEXTURE GENERATORS (NearestFilter Pixel Art)
// ============================================================================
function hexRGB(h) {
  return [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
}

// Crescent smear arcs: White core -> #97C0FF -> #0321BC
const ARC_S = 128, ARC_OX = 55, ARC_OY = 80;
function makeArcCanvas(sp, stage) {
  const c = document.createElement('canvas');
  c.width = c.height = ARC_S;
  const g = c.getContext('2d');
  const img = g.createImageData(ARC_S, ARC_S);
  const d = img.data;
  const span = sp.a1 - sp.a0;
  const thMul = [1, 0.72, 0.45, 0.25][stage];
  const cut = stage * 0.2;
  const pal = [
    [P.white, P.ice, P.royal],
    [P.white, P.ice, P.royal],
    [P.ice, P.royal, P.navy],
    [P.royal, P.navy, P.navy]
  ][stage].map(hexRGB);

  for (let y = 0; y < ARC_S; y++) {
    for (let x = 0; x < ARC_S; x++) {
      const dx = (x - ARC_OX - sp.cx) / sp.ex;
      const dy = y - ARC_OY - sp.cy;
      const r = Math.hypot(dx, dy);
      if (r > sp.R + 1) continue;
      const a = Math.atan2(dy, dx);
      let u = -1;
      for (const k of [0, 2 * Math.PI, -2 * Math.PI]) {
        const v = (a + k - sp.a0) / span;
        if (v >= 0 && v <= 1) { u = v; break; }
      }
      if (u < cut) continue;
      const th = sp.th * thMul * Math.pow(Math.sin(Math.PI * u), 0.6) * (0.3 + 0.7 * u);
      if (th < 0.6 || r < sp.R - th || r > sp.R) continue;
      const q = (sp.R - r) / th;
      const col = u < 0.18 ? pal[2] : q < 0.35 ? pal[0] : q < 0.75 ? pal[1] : pal[2];
      const i = (y * ARC_S + x) * 4;
      d[i] = col[0];
      d[i + 1] = col[1];
      d[i + 2] = col[2];
      d[i + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  return c;
}

const ARC_TEXTURES = {};
function initArcTextures() {
  for (const k in ARC_SPECS) {
    ARC_TEXTURES[k] = [0, 1, 2, 3].map(s => {
      const c = makeArcCanvas(ARC_SPECS[k], s);
      const t = new THREE.CanvasTexture(c);
      t.magFilter = THREE.NearestFilter;
      t.minFilter = THREE.NearestFilter;
      t.generateMipmaps = false;
      return t;
    });
  }
}

// Procedural Contact Shadow Texture
function makeShadowTexture() {
  const c = document.createElement('canvas');
  c.width = 32; c.height = 32;
  const g = c.getContext('2d');
  const grd = g.createRadialGradient(16, 16, 2, 16, 16, 15);
  grd.addColorStop(0, 'rgba(15, 18, 27, 0.75)');
  grd.addColorStop(0.6, 'rgba(21, 16, 55, 0.45)');
  grd.addColorStop(1, 'rgba(15, 18, 27, 0)');
  g.fillStyle = grd;
  g.beginPath();
  g.arc(16, 16, 15, 0, Math.PI * 2);
  g.fill();
  const t = new THREE.CanvasTexture(c);
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  return t;
}

// Procedural 3D Temple Floor Texture (Stone tiles + Lilac moss edges + Kintsugi Gold cracks)
function makeFloorTexture() {
  const c = document.createElement('canvas');
  c.width = 128; c.height = 128;
  const g = c.getContext('2d');
  
  // Base dark stone
  g.fillStyle = P.navyDark;
  g.fillRect(0, 0, 128, 128);

  // Stone tiles grid (32x32 tiles)
  for (let ty = 0; ty < 128; ty += 32) {
    for (let tx = 0; tx < 128; tx += 32) {
      g.fillStyle = ((tx + ty) % 64 === 0) ? P.navy : '#221A58';
      g.fillRect(tx + 1, ty + 1, 30, 30);

      // Texture noise
      for (let i = 0; i < 20; i++) {
        const nx = tx + 2 + Math.floor(Math.random() * 28);
        const ny = ty + 2 + Math.floor(Math.random() * 28);
        g.fillStyle = Math.random() < 0.5 ? P.navyDark : P.plumDark;
        g.fillRect(nx, ny, 1, 1);
      }
    }
  }

  // Stone tile mortar seams
  g.fillStyle = '#0E0B24';
  for (let i = 0; i <= 128; i += 32) {
    g.fillRect(0, i, 128, 1);
    g.fillRect(i, 0, 1, 128);
  }

  // Kintsugi Gold Cracks running through the tiles
  g.fillStyle = P.gold;
  let kx = 18, ky = 12;
  for (let i = 0; i < 45; i++) {
    g.fillRect(kx, ky, 2, 2);
    kx += (Math.random() < 0.5 ? 1 : -1) * (1 + Math.floor(Math.random() * 2));
    ky += 2;
    if (Math.random() < 0.3) {
      g.fillStyle = P.goldHi;
      g.fillRect(kx - 1, ky - 1, 2, 2);
      g.fillStyle = P.gold;
    }
  }

  let kx2 = 85, ky2 = 40;
  for (let i = 0; i < 50; i++) {
    g.fillRect(kx2, ky2, 2, 2);
    kx2 += 2;
    ky2 += (Math.random() < 0.5 ? 1 : -1) * (1 + Math.floor(Math.random() * 2));
    if (Math.random() < 0.35) {
      g.fillStyle = P.goldHi;
      g.fillRect(kx2, ky2, 2, 2);
      g.fillStyle = P.gold;
    }
  }

  // Lilac Moss along top edge (Z=0 back) and bottom edge (Z=5 front)
  for (let x = 0; x < 128; x++) {
    const topH = 3 + Math.floor(Math.sin(x * 0.2) * 2 + Math.sin(x * 0.08) * 3);
    g.fillStyle = P.plum;
    g.fillRect(x, 0, 1, topH + 3);
    g.fillStyle = P.lilacDark;
    g.fillRect(x, 0, 1, topH + 1);
    g.fillStyle = P.lilac;
    g.fillRect(x, 0, 1, topH - 1);

    const btmH = 3 + Math.floor(Math.cos(x * 0.25) * 2 + Math.cos(x * 0.05) * 2);
    g.fillStyle = P.plum;
    g.fillRect(x, 128 - btmH - 3, 1, btmH + 3);
    g.fillStyle = P.lilacDark;
    g.fillRect(x, 128 - btmH - 1, 1, btmH + 1);
    g.fillStyle = P.lilac;
    g.fillRect(x, 128 - btmH + 1, 1, btmH - 1);
  }

  const t = new THREE.CanvasTexture(c);
  t.wrapS = THREE.RepeatWrapping;
  t.wrapT = THREE.RepeatWrapping;
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  t.repeat.set(45, 2);
  return t;
}

// Procedural Shoji Screen Back Wall Texture
function makeShojiTexture() {
  const c = document.createElement('canvas');
  c.width = 64; c.height = 64;
  const g = c.getContext('2d');

  // Dark wood background
  g.fillStyle = P.navyDark;
  g.fillRect(0, 0, 64, 64);

  // Translucent glowing paper
  g.fillStyle = '#261F54';
  g.fillRect(2, 2, 60, 60);

  // Kumiko wooden lattice grid
  g.fillStyle = P.wood;
  for (let x = 2; x <= 62; x += 10) g.fillRect(x, 2, 1, 60);
  for (let y = 2; y <= 62; y += 10) g.fillRect(2, y, 60, 1);

  // Wood frame borders
  g.fillStyle = '#3A1F14';
  g.fillRect(0, 0, 64, 2);
  g.fillRect(0, 62, 64, 2);
  g.fillRect(0, 0, 2, 64);
  g.fillRect(62, 0, 2, 64);

  // Subtle interior glow
  g.fillStyle = 'rgba(178, 178, 255, 0.15)';
  g.fillRect(10, 10, 44, 44);

  const t = new THREE.CanvasTexture(c);
  t.wrapS = THREE.RepeatWrapping;
  t.wrapT = THREE.RepeatWrapping;
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  t.repeat.set(30, 2);
  return t;
}

// Breakable Wood Crate Texture
function makeCrateTexture() {
  const c = document.createElement('canvas');
  c.width = 32; c.height = 32;
  const g = c.getContext('2d');
  g.fillStyle = P.wood;
  g.fillRect(0, 0, 32, 32);

  // Planks
  g.fillStyle = '#3C2214';
  g.fillRect(0, 7, 32, 1);
  g.fillRect(0, 15, 32, 1);
  g.fillRect(0, 23, 32, 1);

  // Cross braces & border
  g.fillStyle = P.rust;
  g.fillRect(0, 0, 32, 2);
  g.fillRect(0, 30, 32, 2);
  g.fillRect(0, 0, 2, 32);
  g.fillRect(30, 0, 2, 32);

  // Corner gold brackets
  g.fillStyle = P.gold;
  g.fillRect(0, 0, 6, 6);
  g.fillRect(26, 0, 6, 6);
  g.fillRect(0, 26, 6, 6);
  g.fillRect(26, 26, 6, 6);

  // Gold Kintsugi seam across crate
  g.fillStyle = P.goldHi;
  let cx = 10;
  for (let cy = 4; cy < 28; cy += 2) {
    g.fillRect(cx, cy, 2, 2);
    cx += (Math.random() < 0.5 ? 1 : -1);
  }

  const t = new THREE.CanvasTexture(c);
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  return t;
}

// Heart Health Pickup Texture
function makeHeartTexture() {
  const c = document.createElement('canvas');
  c.width = 16; c.height = 16;
  const g = c.getContext('2d');
  g.fillStyle = 'rgba(0,0,0,0)';
  g.fillRect(0, 0, 16, 16);

  // Golden heart with red core
  g.fillStyle = P.gold;
  g.fillRect(3, 2, 4, 3);
  g.fillRect(9, 2, 4, 3);
  g.fillRect(2, 4, 12, 4);
  g.fillRect(3, 8, 10, 2);
  g.fillRect(5, 10, 6, 2);
  g.fillRect(7, 12, 2, 2);

  g.fillStyle = P.crimson;
  g.fillRect(4, 3, 2, 2);
  g.fillRect(10, 3, 2, 2);
  g.fillRect(3, 5, 10, 3);
  g.fillRect(4, 8, 8, 2);
  g.fillRect(6, 10, 4, 2);

  g.fillStyle = P.goldHi;
  g.fillRect(4, 4, 2, 2);

  const t = new THREE.CanvasTexture(c);
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  return t;
}

// Procedural Enemy Sprite Sheet ("Ink Shades")
// Specs: dark blob/ghost shapes in navy/plum with lilac eyes, drawn onto small canvas texture per frame
// 6 Rows x 4 Columns (cell size 32x32)
// Row 0: Idle wobble (4 frames)
// Row 1: Move / glide (4 frames)
// Row 2: Windup / Telegraph flash (4 frames)
// Row 3: Attack / Lunge claw swipe (4 frames)
// Row 4: Hurt flash (2 frames)
// Row 5: Death dissolve (4 frames)
const ENEMY_CELL = 32;
function makeEnemySheet() {
  const c = document.createElement('canvas');
  c.width = ENEMY_CELL * 4;
  c.height = ENEMY_CELL * 6;
  const g = c.getContext('2d');

  function drawInkBody(cx, cy, w, h, eyeColor, auraColor, tendrilOffset, eyeGlow) {
    // Outer shadow / aura
    g.fillStyle = auraColor || P.plumDark;
    g.beginPath();
    g.ellipse(cx, cy, w + 2, h + 2, 0, 0, Math.PI * 2);
    g.fill();

    // Main dark ink core
    g.fillStyle = P.navyDark;
    g.beginPath();
    g.ellipse(cx, cy, w, h, 0, 0, Math.PI * 2);
    g.fill();

    // Wispy tendrils at bottom
    g.fillStyle = P.navyDark;
    for (let i = -w + 3; i < w - 2; i += 4) {
      const th = 4 + Math.sin(tendrilOffset + i) * 3;
      g.fillRect(cx + i, cy + h - 4, 3, th);
    }

    // Glowing eyes
    g.fillStyle = eyeColor || P.lilac;
    g.fillRect(cx - 5, cy - 3, 3, 2);
    g.fillRect(cx + 2, cy - 3, 3, 2);

    if (eyeGlow) {
      g.fillStyle = eyeGlow;
      g.fillRect(cx - 6, cy - 4, 5, 4);
      g.fillRect(cx + 1, cy - 4, 5, 4);
    }
  }

  // Row 0: Idle (4 frames)
  for (let f = 0; f < 4; f++) {
    const ox = f * ENEMY_CELL + 16;
    const oy = 0 * ENEMY_CELL + 18 + Math.sin(f * Math.PI / 2) * 2;
    drawInkBody(ox, oy, 9, 11, P.lilac, P.plumDark, f * 1.5, null);
  }

  // Row 1: Move (4 frames)
  for (let f = 0; f < 4; f++) {
    const ox = f * ENEMY_CELL + 16 - f;
    const oy = 1 * ENEMY_CELL + 18;
    drawInkBody(ox, oy, 10, 10, P.lilac, P.plumDark, f * 2.0, null);
  }

  // Row 2: Telegraph / Wind-up (4 frames - eyes flash red/gold, dark spikes flare)
  for (let f = 0; f < 4; f++) {
    const ox = f * ENEMY_CELL + 16 + (f % 2 === 0 ? 1 : -1);
    const oy = 2 * ENEMY_CELL + 17;
    const eyeCol = (f >= 2) ? P.goldHi : P.red;
    const glowCol = (f >= 2) ? 'rgba(255, 163, 3, 0.4)' : 'rgba(255, 14, 0, 0.4)';
    drawInkBody(ox, oy, 11 + f, 12, eyeCol, P.crimson, f * 3.0, glowCol);
    
    // Warning claws
    g.fillStyle = P.gold;
    g.fillRect(ox - 13, oy - 2, 3, 2);
    g.fillRect(ox - 15, oy + 2, 3, 2);
  }

  // Row 3: Lunge / Attack (4 frames - forward thrust claw swipe)
  for (let f = 0; f < 4; f++) {
    const ox = f * ENEMY_CELL + 12 - f * 2;
    const oy = 3 * ENEMY_CELL + 18;
    drawInkBody(ox, oy, 12, 9, P.red, P.navy, f * 2.5, null);

    // Ink claw swipe slash
    g.fillStyle = (f === 1 || f === 2) ? P.ice : P.royal;
    g.fillRect(ox - 14, oy - 6, 8 + f * 3, 3);
    g.fillRect(ox - 16, oy - 1, 10 + f * 2, 4);
    g.fillRect(ox - 13, oy + 4, 7 + f * 2, 3);
  }

  // Row 4: Hurt (2 frames - white flash / recoil)
  for (let f = 0; f < 2; f++) {
    const ox = f * ENEMY_CELL + 18 + f * 3;
    const oy = 4 * ENEMY_CELL + 16;
    g.fillStyle = (f === 0) ? P.white : P.ice;
    g.beginPath();
    g.ellipse(ox, oy, 11, 12, 0.3, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = P.crimson;
    g.fillRect(ox - 4, oy - 2, 3, 3);
    g.fillRect(ox + 2, oy - 2, 3, 3);
  }

  // Row 5: Death (4 frames - bursting into dissolving blobs)
  for (let f = 0; f < 4; f++) {
    const ox = f * ENEMY_CELL + 16;
    const oy = 5 * ENEMY_CELL + 18;
    const rad = 10 + f * 3;
    for (let p = 0; p < 8; p++) {
      const ang = p * Math.PI / 4 + f * 0.4;
      const px = ox + Math.cos(ang) * (rad * 0.6);
      const py = oy + Math.sin(ang) * (rad * 0.6);
      g.fillStyle = (p % 2 === 0) ? P.gold : P.navy;
      g.fillRect(px - 2, py - 2, 3, 3);
    }
  }

  const t = new THREE.CanvasTexture(c);
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  t.generateMipmaps = false;
  return t;
}

// Procedural Distant Backdrop (Moon with Kintsugi Crack & Mountain Pagodas)
function makeBackdropTexture() {
  const c = document.createElement('canvas');
  c.width = 512; c.height = 256;
  const g = c.getContext('2d');

  // Sky gradient
  const grad = g.createLinearGradient(0, 0, 0, 256);
  grad.addColorStop(0, '#0B0D15');
  grad.addColorStop(0.5, '#151037');
  grad.addColorStop(1, '#2F1850');
  g.fillStyle = grad;
  g.fillRect(0, 0, 512, 256);

  // Stars
  for (let i = 0; i < 120; i++) {
    const sx = Math.floor(Math.random() * 512);
    const sy = Math.floor(Math.random() * 160);
    g.fillStyle = Math.random() < 0.25 ? P.goldHi : P.lilac;
    g.globalAlpha = 0.3 + Math.random() * 0.7;
    g.fillRect(sx, sy, 1, 1);
  }
  g.globalAlpha = 1.0;

  // Moon
  const mx = 390, my = 70, mr = 32;
  const mgrd = g.createRadialGradient(mx, my, mr * 0.5, mx, my, mr + 18);
  mgrd.addColorStop(0, 'rgba(255, 255, 204, 0.95)');
  mgrd.addColorStop(0.7, 'rgba(255, 163, 3, 0.4)');
  mgrd.addColorStop(1, 'rgba(255, 163, 3, 0)');
  g.fillStyle = mgrd;
  g.beginPath();
  g.arc(mx, my, mr + 18, 0, Math.PI * 2);
  g.fill();

  g.fillStyle = P.goldHi;
  g.beginPath();
  g.arc(mx, my, mr, 0, Math.PI * 2);
  g.fill();

  // Kintsugi gold vein across moon
  g.fillStyle = P.gold;
  let cx = mx - mr + 6, cy = my - 12;
  for (let i = 0; i < 48; i++) {
    g.fillRect(cx, cy, 2, 2);
    cx += 1 + Math.floor(Math.random() * 2);
    if (Math.random() < 0.4) cy += (Math.random() < 0.5 ? 1 : -1);
  }

  // Mountain Ridges
  g.fillStyle = '#1D1342';
  for (let x = 0; x < 512; x++) {
    const y = 160 - Math.sin(x * 0.015) * 35 - Math.cos(x * 0.04) * 15;
    g.fillRect(x, Math.floor(y), 1, 256);
  }

  g.fillStyle = '#110C2A';
  for (let x = 0; x < 512; x++) {
    const y = 195 - Math.sin(x * 0.02 + 1) * 25 - Math.cos(x * 0.06) * 10;
    g.fillRect(x, Math.floor(y), 1, 256);
  }

  // Tiny pagoda silhouettes on ridge
  const pagodas = [80, 240, 420];
  g.fillStyle = '#0F121B';
  for (const px of pagodas) {
    g.fillRect(px, 150, 4, 25);
    g.fillRect(px - 6, 160, 16, 3);
    g.fillRect(px - 4, 168, 12, 3);
    g.fillRect(px - 8, 175, 20, 4);
  }

  const t = new THREE.CanvasTexture(c);
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  return t;
}

// ============================================================================
// 4. THREE.JS SCENE SETUP
// ============================================================================
let renderer, scene, camera, composer;
let cv, stageEl;
let floorTex, shadowTex, enemySheetTex, crateTex, heartTex;
let playerSharedTex, atkSharedTex;

function initThree() {
  cv = document.getElementById('c');
  stageEl = document.getElementById('stage');

  renderer = new THREE.WebGLRenderer({
    canvas: cv,
    antialias: false,
    alpha: false,
    powerPreference: 'high-performance'
  });
  renderer.setPixelRatio(1);
  renderer.setSize(W, H, false);
  renderer.outputEncoding = THREE.sRGBEncoding;

  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0F121B);
  scene.fog = new THREE.Fog(0x151037, 22, 70);

  // PerspectiveCamera ~35° FOV, elevated and tilted down ~25°
  camera = new THREE.PerspectiveCamera(35, W / H, 0.5, 300);
  camera.rotation.order = 'YXZ';
  camera.rotation.x = -25 * Math.PI / 180; // ~ -0.43633 rad

  // Lighting
  const ambientLight = new THREE.AmbientLight(0x40225F, 0.75);
  scene.add(ambientLight);

  const moonLight = new THREE.DirectionalLight(0xFFFFCC, 0.7);
  moonLight.position.set(-15, 25, 20);
  scene.add(moonLight);

  const rimLight = new THREE.DirectionalLight(0x97C0FF, 0.35);
  rimLight.position.set(20, 10, -15);
  scene.add(rimLight);

  // Textures
  floorTex = makeFloorTexture();
  shadowTex = makeShadowTexture();
  enemySheetTex = makeEnemySheet();
  crateTex = makeCrateTexture();
  heartTex = makeHeartTexture();
  initArcTextures();

  // Load character sprite sheets
  const texLoader = new THREE.TextureLoader();
  playerSharedTex = texLoader.load('assets/sheet.png', (t) => {
    if (player && player.sheetMat && player.sheetMat.map) {
      player.sheetMat.map.image = t.image;
      player.sheetMat.map.needsUpdate = true;
    }
  });
  playerSharedTex.magFilter = THREE.NearestFilter;
  playerSharedTex.minFilter = THREE.NearestFilter;
  playerSharedTex.generateMipmaps = false;

  atkSharedTex = texLoader.load('assets/atk.png', (t) => {
    if (player && player.atkMat && player.atkMat.map) {
      player.atkMat.map.image = t.image;
      player.atkMat.map.needsUpdate = true;
    }
  });
  atkSharedTex.magFilter = THREE.NearestFilter;
  atkSharedTex.minFilter = THREE.NearestFilter;
  atkSharedTex.generateMipmaps = false;

  // Build Environment
  buildWorld();
  initVFX();

  // Post-processing setup (Bloom)
  if (THREE.EffectComposer && THREE.UnrealBloomPass) {
    try {
      composer = new THREE.EffectComposer(renderer);
      composer.setPixelRatio(1);
      composer.setSize(W, H);
      composer.addPass(new THREE.RenderPass(scene, camera));
      const bloomPass = new THREE.UnrealBloomPass(new THREE.Vector2(W, H), 0.45, 0.5, 0.75);
      composer.addPass(bloomPass);
    } catch (e) {
      composer = null;
    }
  }

  window.addEventListener('resize', handleResize);
  handleResize();
}

function handleResize() {
  const ww = window.innerWidth;
  const wh = window.innerHeight;
  // Fit 480x270 keeping aspect ratio with crisp pixel scaling
  const scale = Math.max(1, Math.floor(Math.min(ww / W, wh / H) * 2) / 2);
  stageEl.style.width = (W * scale) + 'px';
  stageEl.style.height = (H * scale) + 'px';
}

// ============================================================================
// 5. ENVIRONMENT & ARENA BUILDER
// ============================================================================
const lanterns = [];
function buildWorld() {
  // 1. Floor Plane (3D plane for z in [0, 5])
  const floorGeo = new THREE.PlaneGeometry(160, 5.8);
  const floorMat = new THREE.MeshStandardMaterial({
    map: floorTex,
    roughness: 0.85,
    metalness: 0.1
  });
  const floor = new THREE.Mesh(floorGeo, floorMat);
  floor.rotation.x = -Math.PI / 2;
  floor.position.set(65, 0, 2.5);
  scene.add(floor);

  // Front street curb / stone border at z = 5.4
  const curbGeo = new THREE.BoxGeometry(160, 0.4, 0.3);
  const curbMat = new THREE.MeshLambertMaterial({ color: 0x151037 });
  const curb = new THREE.Mesh(curbGeo, curbMat);
  curb.position.set(65, -0.15, 5.4);
  scene.add(curb);

  // 2. Back Wall (Shoji screens and dark wood pillars at z = -0.05)
  const shojiTex = makeShojiTexture();
  const wallGeo = new THREE.PlaneGeometry(160, 6.0);
  const wallMat = new THREE.MeshStandardMaterial({
    map: shojiTex,
    roughness: 0.9,
    metalness: 0.05
  });
  const wall = new THREE.Mesh(wallGeo, wallMat);
  wall.position.set(65, 3.0, -0.05);
  scene.add(wall);

  // Wood pillars along back wall every 6 units
  const pillarGeo = new THREE.BoxGeometry(0.5, 6.2, 0.4);
  const pillarMat = new THREE.MeshLambertMaterial({ color: 0x2F1850 });
  for (let x = -5; x <= 135; x += 6) {
    const pillar = new THREE.Mesh(pillarGeo, pillarMat);
    pillar.position.set(x, 3.0, 0.05);
    scene.add(pillar);
  }

  // Temple Eaves (Kawara roof overhanging)
  const eaveGeo = new THREE.BoxGeometry(160, 0.6, 1.2);
  const eaveMat = new THREE.MeshLambertMaterial({ color: 0x151037 });
  const eave = new THREE.Mesh(eaveGeo, eaveMat);
  eave.position.set(65, 5.9, 0.4);
  scene.add(eave);

  // 3. Torii Gates
  // Entrance Torii at X = 5
  createTorii(5, false);
  // Grand Goal Torii at X = 118
  createTorii(118, true);

  // 4. Stone Lanterns (Tōrō) and Point Lights
  const lanternX = [14, 32, 50, 68, 86, 104];
  for (const lx of lanternX) {
    createStoneLantern(lx, 4.8);
    // Point light with golden warmth
    const light = new THREE.PointLight(0xFFA303, 1.1, 9, 1.6);
    light.position.set(lx, 1.8, 4.5);
    scene.add(light);
    lanterns.push({ light, baseInt: 1.1, offset: Math.random() * 10 });
  }

  // Hanging lanterns under eaves
  for (let hx = 10; hx <= 120; hx += 18) {
    createHangingLantern(hx, 5.0, 0.6);
    const hLight = new THREE.PointLight(0xFF4500, 0.65, 6, 1.8);
    hLight.position.set(hx, 4.6, 0.8);
    scene.add(hLight);
    lanterns.push({ light: hLight, baseInt: 0.65, offset: Math.random() * 10 });
  }

  // 5. Distant Backdrop (Moon, Pagoda, Mountains)
  const backdropTex = makeBackdropTexture();
  const bgGeo = new THREE.PlaneGeometry(240, 100);
  const bgMat = new THREE.MeshBasicMaterial({ map: backdropTex, fog: false });
  const bgMesh = new THREE.Mesh(bgGeo, bgMat);
  bgMesh.position.set(65, 36, -55);
  scene.add(bgMesh);
}

function createTorii(x, isGoal) {
  const group = new THREE.Group();
  const colColor = isGoal ? 0xFF0E00 : 0x882323;
  const pillarMat = new THREE.MeshLambertMaterial({ color: colColor });
  const blackMat = new THREE.MeshLambertMaterial({ color: 0x0F121B });
  const goldMat = new THREE.MeshLambertMaterial({ color: 0xFFA303 });

  const h = isGoal ? 7.5 : 6.0;
  const span = isGoal ? 6.5 : 5.0;

  // Two vertical pillars
  const pGeo = new THREE.CylinderGeometry(0.32, 0.38, h, 8);
  const p1 = new THREE.Mesh(pGeo, pillarMat);
  p1.position.set(-span / 2, h / 2, 0);
  group.add(p1);

  const p2 = new THREE.Mesh(pGeo, pillarMat);
  p2.position.set(span / 2, h / 2, 0);
  group.add(p2);

  // Black stone bases
  const baseGeo = new THREE.BoxGeometry(1.0, 0.6, 1.0);
  const b1 = new THREE.Mesh(baseGeo, blackMat);
  b1.position.set(-span / 2, 0.3, 0);
  group.add(b1);
  const b2 = new THREE.Mesh(baseGeo, blackMat);
  b2.position.set(span / 2, 0.3, 0);
  group.add(b2);

  // Top lintels (Kasagi & Shimaki)
  const topGeo = new THREE.BoxGeometry(span + 2.5, 0.45, 0.7);
  const top = new THREE.Mesh(topGeo, pillarMat);
  top.position.set(0, h + 0.1, 0);
  group.add(top);

  // Curved top cap with gold tips
  const capGeo = new THREE.BoxGeometry(span + 3.0, 0.25, 0.8);
  const cap = new THREE.Mesh(capGeo, blackMat);
  cap.position.set(0, h + 0.35, 0);
  group.add(cap);

  // Secondary crossbeam (Nuki)
  const nukiGeo = new THREE.BoxGeometry(span + 1.2, 0.35, 0.45);
  const nuki = new THREE.Mesh(nukiGeo, pillarMat);
  nuki.position.set(0, h - 0.9, 0);
  group.add(nuki);

  // Gold plaque on Goal Torii
  if (isGoal) {
    const plaqueGeo = new THREE.BoxGeometry(1.2, 1.4, 0.15);
    const plaque = new THREE.Mesh(plaqueGeo, goldMat);
    plaque.position.set(0, h - 0.4, 0.1);
    group.add(plaque);
  }

  group.position.set(x, 0, 2.5);
  scene.add(group);
}

function createStoneLantern(x, z) {
  const g = new THREE.Group();
  const stoneMat = new THREE.MeshLambertMaterial({ color: 0x2F1850 });
  const glowMat = new THREE.MeshBasicMaterial({ color: 0xFFA303 });

  // Base
  const base = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.3, 0.9), stoneMat);
  base.position.y = 0.15;
  g.add(base);

  // Pillar
  const pillar = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.25, 0.9, 6), stoneMat);
  pillar.position.y = 0.7;
  g.add(pillar);

  // Lamp chamber platform
  const plat = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.2, 0.8), stoneMat);
  plat.position.y = 1.25;
  g.add(plat);

  // Glowing fire box
  const fireBox = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.55, 0.55), glowMat);
  fireBox.position.y = 1.6;
  g.add(fireBox);

  // Roof
  const roof = new THREE.Mesh(new THREE.ConeGeometry(0.7, 0.4, 4), stoneMat);
  roof.rotation.y = Math.PI / 4;
  roof.position.y = 2.05;
  g.add(roof);

  g.position.set(x, 0, z);
  scene.add(g);
}

function createHangingLantern(x, y, z) {
  const g = new THREE.Group();
  const redMat = new THREE.MeshLambertMaterial({ color: 0xFF0E00 });
  const goldMat = new THREE.MeshLambertMaterial({ color: 0xFFA303 });

  // Lantern cylinder
  const body = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.8, 8), redMat);
  body.position.y = -0.4;
  g.add(body);

  const topRim = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.34, 0.08, 8), goldMat);
  topRim.position.y = 0.02;
  g.add(topRim);

  const btmRim = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.34, 0.08, 8), goldMat);
  btmRim.position.y = -0.82;
  g.add(btmRim);

  g.position.set(x, y, z);
  scene.add(g);
}

// ============================================================================
// 6. VFX & PARTICLES SYSTEM
// ============================================================================
let particles = [];
let shockwaves = [];
let cameraShakeTrauma = 0;
let hitStopTimer = 0;

function spawnHitSpark(x, y, z) {
  for (let i = 0; i < 7; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 3.5 + Math.random() * 5.0;
    particles.push({
      x: x + (Math.random() - 0.5) * 0.4,
      y: y + (Math.random() - 0.5) * 0.4,
      z: z + (Math.random() - 0.5) * 0.2,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed + 2.0,
      vz: (Math.random() - 0.5) * 1.5,
      color: i % 2 === 0 ? 0xFFFFFF : (Math.random() < 0.5 ? 0x97C0FF : 0xFFA303),
      size: 0.16,
      life: 0.22,
      maxLife: 0.22,
      gravity: 12.0
    });
  }
}

function spawnDeathBurst(x, y, z) {
  // Ink splashes (dark navy/plum) + Kintsugi gold sparks
  for (let i = 0; i < 22; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 2.0 + Math.random() * 6.5;
    const isGold = Math.random() < 0.4;
    particles.push({
      x: x + (Math.random() - 0.5) * 0.6,
      y: y + 0.8 + (Math.random() - 0.5) * 0.8,
      z: z + (Math.random() - 0.5) * 0.4,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed + 3.0,
      vz: (Math.random() - 0.5) * 3.0,
      color: isGold ? (Math.random() < 0.5 ? 0xFFA303 : 0xFFFFCC) : (Math.random() < 0.5 ? 0x151037 : 0x40225F),
      size: isGold ? 0.15 : 0.22,
      life: 0.45,
      maxLife: 0.45,
      gravity: 14.0
    });
  }
}

function spawnDust(x, y, z, count = 4) {
  for (let i = 0; i < count; i++) {
    particles.push({
      x: x + (Math.random() - 0.5) * 0.5,
      y: y + 0.1,
      z: z + (Math.random() - 0.5) * 0.3,
      vx: (Math.random() - 0.5) * 2.0,
      vy: 0.8 + Math.random() * 1.5,
      vz: (Math.random() - 0.5) * 1.0,
      color: 0x9EA0FA,
      size: 0.2,
      life: 0.3,
      maxLife: 0.3,
      gravity: 0
    });
  }
}

function spawnPlungeShockwave(x, z) {
  shockwaves.push({
    x, z,
    radius: 0.3,
    maxRadius: 2.8,
    life: 0.35,
    maxLife: 0.35
  });
  spawnDust(x, 0, z, 14);
}

let partPositions, partColors, partGeo, partMat, partPoints;
let shockGeo, shockMat, shockMesh;
const MAX_PARTS = 250;

function initVFX() {
  partGeo = new THREE.BufferGeometry();
  partPositions = new Float32Array(MAX_PARTS * 3);
  partColors = new Float32Array(MAX_PARTS * 3);
  partGeo.setAttribute('position', new THREE.BufferAttribute(partPositions, 3));
  partGeo.setAttribute('color', new THREE.BufferAttribute(partColors, 3));
  partMat = new THREE.PointsMaterial({
    size: 7,
    vertexColors: true,
    transparent: true,
    depthWrite: false
  });
  partPoints = new THREE.Points(partGeo, partMat);
  scene.add(partPoints);

  shockGeo = new THREE.RingGeometry(0.1, 0.4, 24);
  shockMat = new THREE.MeshBasicMaterial({
    color: 0xFFA303,
    transparent: true,
    opacity: 0.8,
    side: THREE.DoubleSide,
    depthWrite: false
  });
  shockMesh = new THREE.Mesh(shockGeo, shockMat);
  shockMesh.rotation.x = -Math.PI / 2;
  shockMesh.visible = false;
  scene.add(shockMesh);
}

function updateParticles(dt) {
  let active = 0;
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.life -= dt;
    if (p.life <= 0) {
      particles.splice(i, 1);
      continue;
    }
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.z += p.vz * dt;
    p.vy -= p.gravity * dt;
    if (p.y < 0.05) { p.y = 0.05; p.vy = -p.vy * 0.3; p.vx *= 0.7; }

    if (active < MAX_PARTS) {
      const idx = active * 3;
      partPositions[idx] = p.x;
      partPositions[idx + 1] = p.y;
      partPositions[idx + 2] = p.z;
      const c = new THREE.Color(p.color);
      partColors[idx] = c.r;
      partColors[idx + 1] = c.g;
      partColors[idx + 2] = c.b;
      active++;
    }
  }

  // Clear rest
  for (let i = active * 3; i < MAX_PARTS * 3; i++) {
    partPositions[i] = 9999;
  }
  partGeo.attributes.position.needsUpdate = true;
  partGeo.attributes.color.needsUpdate = true;

  // Shockwaves
  if (shockwaves.length > 0) {
    const sw = shockwaves[0];
    sw.life -= dt;
    if (sw.life <= 0) {
      shockwaves.shift();
      shockMesh.visible = false;
    } else {
      const prog = 1.0 - (sw.life / sw.maxLife);
      const curR = sw.radius + prog * (sw.maxRadius - sw.radius);
      shockMesh.position.set(sw.x, 0.03, sw.z);
      shockMesh.scale.set(curR, curR, 1);
      shockMat.opacity = 0.8 * (1.0 - prog);
      shockMesh.visible = true;
    }
  } else {
    shockMesh.visible = false;
  }
}

// ============================================================================
// 7. BREAKABLE CRATES & HEALTH PICKUPS
// ============================================================================
let crates = [];
let pickups = [];

class Crate {
  constructor(x, z) {
    this.x = x;
    this.z = z;
    this.hp = 1;
    this.alive = true;

    // 3D Box Mesh
    const geo = new THREE.BoxGeometry(1.2, 1.2, 1.2);
    const mat = new THREE.MeshLambertMaterial({ map: crateTex });
    this.mesh = new THREE.Mesh(geo, mat);
    this.mesh.position.set(x, 0.6, z);
    scene.add(this.mesh);

    // Floor shadow
    const sGeo = new THREE.PlaneGeometry(1.4, 0.9);
    const sMat = new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, opacity: 0.4, depthWrite: false });
    this.shadow = new THREE.Mesh(sGeo, sMat);
    this.shadow.rotation.x = -Math.PI / 2;
    this.shadow.position.set(x, 0.01, z);
    scene.add(this.shadow);
  }

  hit() {
    if (!this.alive) return;
    this.hp--;
    if (this.hp <= 0) {
      this.destroy();
    }
  }

  destroy() {
    this.alive = false;
    scene.remove(this.mesh);
    scene.remove(this.shadow);
    playSFX('impact');
    spawnDust(this.x, 0.6, this.z, 8);
    // Spawn wooden splinters
    for (let i = 0; i < 10; i++) {
      particles.push({
        x: this.x + (Math.random() - 0.5) * 0.6,
        y: 0.6 + (Math.random() - 0.5) * 0.4,
        z: this.z + (Math.random() - 0.5) * 0.4,
        vx: (Math.random() - 0.5) * 4.0,
        vy: 2.0 + Math.random() * 3.5,
        vz: (Math.random() - 0.5) * 2.5,
        color: Math.random() < 0.5 ? 0x4D2F1E : 0xA64B0A,
        size: 0.2,
        life: 0.4,
        maxLife: 0.4,
        gravity: 12.0
      });
    }
    // Drop Heart Pickup
    pickups.push(new Pickup(this.x, this.z));
  }
}

class Pickup {
  constructor(x, z) {
    this.x = x;
    this.z = z;
    this.y = 0.5;
    this.bobT = 0;
    this.collected = false;

    const geo = new THREE.PlaneGeometry(0.8, 0.8);
    const mat = new THREE.MeshBasicMaterial({ map: heartTex, transparent: true, side: THREE.DoubleSide });
    this.mesh = new THREE.Mesh(geo, mat);
    this.mesh.rotation.x = camera.rotation.x;
    scene.add(this.mesh);

    const sGeo = new THREE.PlaneGeometry(0.9, 0.5);
    const sMat = new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, opacity: 0.4, depthWrite: false });
    this.shadow = new THREE.Mesh(sGeo, sMat);
    this.shadow.rotation.x = -Math.PI / 2;
    this.shadow.position.set(x, 0.01, z);
    scene.add(this.shadow);
  }

  update(dt) {
    if (this.collected) return;
    this.bobT += dt * 3.0;
    this.y = 0.5 + Math.sin(this.bobT) * 0.15;
    this.mesh.position.set(this.x, this.y, this.z);
    this.mesh.rotation.x = camera.rotation.x;

    // Check player collection
    const dx = Math.abs(player.x - this.x);
    const dz = Math.abs(player.z - this.z);
    if (dx < 1.0 && dz < 0.8) {
      this.collect();
    }
  }

  collect() {
    this.collected = true;
    scene.remove(this.mesh);
    scene.remove(this.shadow);
    playSFX('pickup');
    if (player.hp < 5) {
      player.hp = Math.min(5, player.hp + 1);
      updateHUD();
    }
    spawnHitSpark(this.x, this.y, this.z);
  }
}

function initCrates() {
  crates.forEach(c => { scene.remove(c.mesh); scene.remove(c.shadow); });
  pickups.forEach(p => { scene.remove(p.mesh); scene.remove(p.shadow); });
  crates = [];
  pickups = [];

  const cratePositions = [
    [18, 1.2], [36, 4.0],
    [52, 1.0], [70, 4.2],
    [86, 1.5], [102, 3.8]
  ];
  for (const [cx, cz] of cratePositions) {
    crates.push(new Crate(cx, cz));
  }
}

// ============================================================================
// 8. PLAYER (Kintsugi Swordsman)
// ============================================================================
const PLAYER_W = 4.0, PLAYER_H = 4.0;

class Player {
  constructor() {
    this.x = 2.0;
    this.y = 0.0;
    this.z = 2.5;
    this.vx = 0;
    this.vy = 0;
    this.vz = 0;
    this.facing = 1; // 1 = right, -1 = left
    this.ground = true;
    this.hp = 5;
    this.maxHp = 5;

    this.state = 'idle'; // idle, walk, run, jump, fall, attack, dodge, plunge, hurt, knockdown, dead
    this.animTime = 0;
    this.animFrame = 0;

    // Attack state
    this.atk = null; // { kind, phase, t, dur, hitDone }
    this.comboQueued = false;
    this.branch21Timer = 0; // 0-450ms after hit 2 ends to branch into 2-1

    // Dodge state
    this.dodgeTime = 0;
    this.dodgeDur = 0.32;
    this.dodging = false;

    // Hurt & i-frames
    this.invuln = 0;
    this.hurtTimer = 0;
    this.knockdown = false;
    this.knockdownTimer = 0;

    // Mesh setup
    const geo = new THREE.PlaneGeometry(1, 1);
    geo.translate(0, 0.5, 0); // anchor at feet

    this.sheetMat = new THREE.MeshLambertMaterial({
      map: playerSharedTex.clone(),
      emissive: new THREE.Color(0x181230),
      alphaTest: 0.5,
      transparent: false,
      side: THREE.DoubleSide
    });
    if (this.sheetMat.map.image) this.sheetMat.map.needsUpdate = true;

    this.atkMat = new THREE.MeshLambertMaterial({
      map: atkSharedTex.clone(),
      emissive: new THREE.Color(0x181230),
      alphaTest: 0.5,
      transparent: false,
      side: THREE.DoubleSide
    });
    if (this.atkMat.map.image) this.atkMat.map.needsUpdate = true;

    this.mesh = new THREE.Mesh(geo, this.sheetMat);
    scene.add(this.mesh);

    // Crescent Slash Arc Mesh
    const arcGeo = new THREE.PlaneGeometry(3.5, 3.5);
    this.arcMat = new THREE.MeshBasicMaterial({
      map: null,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false
    });
    this.arcMesh = new THREE.Mesh(arcGeo, this.arcMat);
    this.arcMesh.visible = false;
    scene.add(this.arcMesh);

    // Floor shadow
    const sGeo = new THREE.PlaneGeometry(1.6, 0.9);
    const sMat = new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, opacity: 0.45, depthWrite: false });
    this.shadow = new THREE.Mesh(sGeo, sMat);
    this.shadow.rotation.x = -Math.PI / 2;
    this.shadow.position.y = 0.01;
    scene.add(this.shadow);
  }

  reset(x = 2.0, z = 2.5) {
    this.x = x;
    this.y = 0.0;
    this.z = z;
    this.vx = 0;
    this.vy = 0;
    this.vz = 0;
    this.facing = 1;
    this.ground = true;
    this.hp = 5;
    this.state = 'idle';
    this.atk = null;
    this.comboQueued = false;
    this.branch21Timer = 0;
    this.dodging = false;
    this.invuln = 0;
    this.hurtTimer = 0;
    this.knockdown = false;
    this.knockdownTimer = 0;
    this.arcMesh.visible = false;
  }

  startAttack(kind) {
    const def = ATK_DATA[kind];
    if (!def) return;
    this.atk = {
      kind,
      phase: 'antic',
      t: 0,
      dur: def.antic,
      hitDone: false
    };
    this.state = 'attack';
    this.comboQueued = false;
    if (def.sfx) playSFX(def.sfx);
  }

  startDodge() {
    this.dodging = true;
    this.dodgeTime = 0;
    this.invuln = this.dodgeDur + 0.1;
    this.state = 'dodge';
    this.vx = -this.facing * 8.5; // Slip backwards
    this.vz = 0;
    playSFX('dash');
  }

  startPlunge() {
    this.startAttack('plunge');
    this.vy = 2.0; // slight hop before plunge
    playSFX('dash');
  }

  takeDamage(dmg, fromX) {
    if (this.dodging || this.invuln > 0 || this.knockdown || this.state === 'dead') return;

    this.hp = Math.max(0, this.hp - dmg);
    updateHUD();
    playSFX('hurt');
    spawnHitSpark(this.x, this.y + 1.2, this.z);
    cameraShake(0.5);
    hitStop(0.06);

    // Knockdown when HP <= 1 or hit while airborne
    if (this.hp <= 1 || !this.ground) {
      this.knockdown = true;
      this.knockdownTimer = 0.9;
      this.invuln = 1.3;
      this.state = 'knockdown';
      this.vy = 6.0;
      this.vx = (this.x < fromX ? -1 : 1) * 4.5;
      this.ground = false;
    } else {
      // Light flinch
      this.state = 'hurt';
      this.hurtTimer = 0.25;
      this.invuln = 0.8;
      this.vx = (this.x < fromX ? -1 : 1) * 3.0;
    }

    if (this.hp <= 0) {
      this.state = 'dead';
      playSFX('die');
      showGameOver();
    }
  }

  update(dt, input) {
    if (this.branch21Timer > 0) {
      this.branch21Timer -= dt;
    }
    if (this.invuln > 0) {
      this.invuln -= dt;
    }

    // Dead state
    if (this.state === 'dead') {
      this.updatePhysics(dt, 0, 0);
      this.updateAnimation(dt);
      return;
    }

    // Knockdown state
    if (this.knockdown) {
      this.knockdownTimer -= dt;
      this.updatePhysics(dt, 0, 0);
      if (this.ground && this.knockdownTimer <= 0) {
        this.knockdown = false;
        this.state = 'idle';
      }
      this.updateAnimation(dt);
      return;
    }

    // Hurt state
    if (this.state === 'hurt') {
      this.hurtTimer -= dt;
      this.updatePhysics(dt, 0, 0);
      if (this.hurtTimer <= 0) {
        this.state = 'idle';
      }
      this.updateAnimation(dt);
      return;
    }

    // Back Dodge state
    if (this.dodging) {
      this.dodgeTime += dt;
      this.updatePhysics(dt, 0, 0);
      // Spawn dodge after-image dust
      if (Math.random() < 0.4) spawnDust(this.x, 0, this.z, 1);

      // Check attack cancel during / after dodge
      if (input.attackPressed) {
        this.dodging = false;
        this.startAttack('dodge1');
        return;
      }

      if (this.dodgeTime >= this.dodgeDur) {
        this.dodging = false;
        this.state = 'idle';
      }
      this.updateAnimation(dt);
      return;
    }

    // Attack State Machine
    if (this.atk) {
      this.updateAttack(dt, input);
      return;
    }

    // Movement & Combat Input Handling
    let moveX = 0, moveZ = 0;
    if (input.left) moveX -= 1;
    if (input.right) moveX += 1;
    if (input.up) moveZ -= 1; // into depth (-z)
    if (input.down) moveZ += 1; // towards camera (+z)

    if (moveX !== 0) this.facing = moveX > 0 ? 1 : -1;

    const isRunning = input.shift && (moveX !== 0 || moveZ !== 0);
    const speedX = isRunning ? 7.5 : 4.2;
    const speedZ = isRunning ? 5.2 : 3.2;

    // Check Dodge input
    if (input.dodgePressed && this.ground) {
      this.startDodge();
      return;
    }

    // Check Attack input
    if (input.attackPressed) {
      if (!this.ground) {
        // Airborne attack
        if (input.down) {
          this.startPlunge(); // ↓ + X in air = plunge
        } else {
          this.startAttack('air');
        }
        return;
      } else {
        // Ground Attack
        if (this.branch21Timer > 0) {
          this.startAttack('2-1');
          this.branch21Timer = 0;
        } else {
          this.startAttack('1');
        }
        return;
      }
    }

    // Check Jump input
    if (input.jumpPressed && this.ground) {
      this.vy = 10.5;
      this.ground = false;
      playSFX('jump');
      spawnDust(this.x, 0, this.z, 3);
    }

    // Apply movement physics
    this.vx = moveX * speedX;
    this.vz = moveZ * speedZ;

    // Update state
    if (!this.ground) {
      this.state = this.vy > 0 ? 'jump' : 'fall';
    } else if (moveX !== 0 || moveZ !== 0) {
      this.state = isRunning ? 'run' : 'walk';
    } else {
      this.state = 'idle';
    }

    this.updatePhysics(dt, moveX, moveZ);
    this.updateAnimation(dt);
  }

  updatePhysics(dt, moveX, moveZ) {
    // Gravity
    if (!this.ground) {
      this.vy -= 28.0 * dt;
      this.y += this.vy * dt;
      if (this.y <= 0) {
        this.y = 0;
        this.vy = 0;
        this.ground = true;
        playSFX('land');
        spawnDust(this.x, 0, this.z, 4);
      }
    }

    // Position updates
    this.x += this.vx * dt;
    this.z += this.vz * dt;

    // Boundaries
    this.z = Math.max(Z_MIN, Math.min(Z_MAX, this.z));

    // Zone Lock clamp
    if (zoneLocked) {
      this.x = Math.max(zoneMinX, Math.min(zoneMaxX, this.x));
    } else {
      this.x = Math.max(X_MIN + 1, Math.min(X_MAX, this.x));
    }
  }

  updateAttack(dt, input) {
    const a = this.atk;
    const def = ATK_DATA[a.kind];
    a.t += dt * 1000; // in ms

    // Queue next combo input
    if (input.attackPressed) {
      this.comboQueued = true;
    }

    // Handle Plunge Dive Phase
    if (a.kind === 'plunge' && a.phase === 'dive') {
      this.vy = -22.0; // fast downward dive
      this.y += this.vy * dt;
      if (this.y <= 0) {
        this.y = 0;
        this.vy = 0;
        this.ground = true;
        a.phase = 'active';
        a.t = 0;
        a.dur = def.active;
        playSFX('impact');
        cameraShake(0.75);
        hitStop(0.08);
        spawnPlungeShockwave(this.x, this.z);
        // Hit all enemies in shockwave area
        this.checkPlungeHit();
      }
      this.updateAnimation(dt);
      return;
    }

    // Phase Transitions: antic -> smear -> active -> rec
    if (a.t >= a.dur) {
      a.t = 0;
      if (a.phase === 'antic') {
        if (a.kind === 'plunge') {
          a.phase = 'dive';
          a.dur = 400;
        } else {
          a.phase = 'smear';
          a.dur = def.smear || 40;
        }
      } else if (a.phase === 'smear') {
        a.phase = 'active';
        a.dur = def.active;
        a.hitDone = false;
      } else if (a.phase === 'active') {
        a.phase = 'rec';
        a.dur = def.rec;
      } else if (a.phase === 'rec') {
        // Recovery ended
        const prevKind = a.kind;
        this.atk = null;
        this.arcMesh.visible = false;
        this.state = 'idle';

        // Branch 2-1 window: if hit 2 ends without combo, player has 450ms to branch into 2-1!
        if (prevKind === '2') {
          this.branch21Timer = 0.45;
        }
        return;
      }
    }

    // Hit checking during Active phase
    if (a.phase === 'active' && !a.hitDone && a.kind !== 'plunge') {
      this.checkAttackHit();
    }

    // Combo chaining on input during recovery (or active)
    if (this.comboQueued && (a.phase === 'active' || a.phase === 'rec')) {
      if (a.kind === '1') {
        this.startAttack('2');
        return;
      } else if (a.kind === '2') {
        this.startAttack('3');
        return;
      } else if (a.kind === '2-1') {
        this.startAttack('2-2');
        return;
      } else if (a.kind === 'air') {
        this.startAttack('air2');
        return;
      } else if (a.kind === 'dodge1') {
        this.startAttack('dodge2');
        return;
      }
    }

    // Airborne physics during air attacks
    if (!this.ground) {
      this.vy -= 18.0 * dt; // slightly floatier gravity during air slash
      this.y += this.vy * dt;
      if (this.y <= 0) {
        this.y = 0;
        this.vy = 0;
        this.ground = true;
      }
    }

    this.updateAnimation(dt);
  }

  checkAttackHit() {
    const a = this.atk;
    const def = ATK_DATA[a.kind];
    let hitAny = false;

    // Check Enemies
    for (const enemy of enemies) {
      if (!enemy.alive) continue;
      // Hit detection uses x overlap AND |z difference| <= 0.6 tiles
      const zDiff = Math.abs(this.z - enemy.z);
      if (zDiff > LANE_TOLERANCE) continue;

      // X overlap forward in facing direction
      const dx = (enemy.x - this.x) * this.facing;
      if (dx >= -0.2 && dx <= def.range) {
        // Vertical Y overlap
        if (Math.abs(this.y - enemy.y) <= 1.8) {
          enemy.takeDamage(def.dmg, this.facing);
          hitAny = true;
        }
      }
    }

    // Check Crates
    for (const crate of crates) {
      if (!crate.alive) continue;
      const zDiff = Math.abs(this.z - crate.z);
      if (zDiff <= 0.8) {
        const dx = (crate.x - this.x) * this.facing;
        if (dx >= -0.2 && dx <= def.range) {
          crate.hit();
          hitAny = true;
        }
      }
    }

    if (hitAny) {
      a.hitDone = true;
      cameraShake(a.kind === '3' || a.kind === '2-2' ? 0.6 : 0.35);
      hitStop(0.06);
    }
  }

  checkPlungeHit() {
    for (const enemy of enemies) {
      if (!enemy.alive) continue;
      const dx = Math.abs(this.x - enemy.x);
      const dz = Math.abs(this.z - enemy.z);
      if (dx <= 2.5 && dz <= 1.2 && enemy.y <= 1.0) {
        enemy.takeDamage(2, enemy.x > this.x ? 1 : -1);
      }
    }
    for (const crate of crates) {
      if (!crate.alive) continue;
      const dx = Math.abs(this.x - crate.x);
      const dz = Math.abs(this.z - crate.z);
      if (dx <= 2.2 && dz <= 1.2) {
        crate.hit();
      }
    }
  }

  updateAnimation(dt) {
    this.animTime += dt;

    // Sprite billboard position & rotation
    this.mesh.position.set(this.x, this.y, this.z);
    this.mesh.rotation.x = camera.rotation.x;

    // Contact shadow
    this.shadow.position.set(this.x, 0.01, this.z);
    const jumpScale = Math.max(0.4, 1.0 - this.y * 0.18);
    this.shadow.scale.set(jumpScale, jumpScale, 1);

    // Invulnerability flashing
    if (this.invuln > 0) {
      this.mesh.visible = (Math.floor(this.animTime * 24) % 2 === 0);
    } else {
      this.mesh.visible = true;
    }

    // Determine texture and UV frame
    let useAtk = false;
    let col = 0, row = 0;
    let cellW = 46, cellH = 58;

    const ART = window.ATK_ART;

    if (this.atk && ART) {
      useAtk = true;
      const a = this.atk;
      const mDef = ART.moves[a.kind];
      if (mDef) {
        row = mDef.row;
        const frames = mDef[a.phase] || mDef.active || [0];
        const prog = Math.min(1.0, a.t / (a.dur || 1));
        const idx = Math.min(frames.length - 1, Math.floor(prog * frames.length));
        col = frames[idx];
      }

      // Update Crescent Slash Arc
      if ((a.phase === 'smear' || a.phase === 'active') && ARC_TEXTURES[a.kind]) {
        const stage = a.phase === 'smear' ? 0 : 2;
        this.arcMat.map = ARC_TEXTURES[a.kind][stage];
        this.arcMat.map.needsUpdate = true;
        this.arcMesh.visible = true;
        this.arcMesh.position.set(this.x + this.facing * 0.8, this.y + 1.2, this.z + 0.04);
        this.arcMesh.scale.set(this.facing * 3.2, 3.2, 1);
        this.arcMesh.rotation.x = camera.rotation.x;
      } else {
        this.arcMesh.visible = false;
      }
    } else if (this.knockdown && ART) {
      useAtk = true;
      row = ART.moves.hurt.row;
      col = this.y > 0 ? 4 : 6;
    } else if (this.state === 'hurt' && ART) {
      useAtk = true;
      row = ART.moves.hurt.row;
      col = 0;
    } else if (this.dodging && ART) {
      useAtk = true;
      row = ART.moves.backdodge.row;
      const prog = Math.min(1.0, this.dodgeTime / this.dodgeDur);
      col = ART.moves.backdodge.play[Math.min(ART.moves.backdodge.play.length - 1, Math.floor(prog * ART.moves.backdodge.play.length))];
    } else if (!this.ground && ART) {
      useAtk = true;
      row = ART.moves.jump.row;
      col = this.vy > 2 ? 3 : (this.vy < -2 ? 5 : 4);
    } else if (this.state === 'run' && ART) {
      useAtk = true;
      row = ART.moves.run.row;
      col = ART.moves.run.loop[Math.floor(this.animTime * 12) % ART.moves.run.loop.length];
    } else if (this.state === 'walk') {
      useAtk = false;
      row = 1;
      col = Math.floor(this.animTime * 16) % 24;
    } else {
      // Idle
      useAtk = false;
      row = 0;
      col = Math.floor(this.animTime * 8) % 10;
    }

    if (useAtk) {
      this.mesh.material = this.atkMat;
      cellW = 64; cellH = 64;
      // atk.png is 8 cols x 23 rows
      this.atkMat.map.repeat.set(1 / 8, 1 / 23);
      this.atkMat.map.offset.set(col / 8, (23 - 1 - row) / 23);
      // Mirrored when facing right (since original faces LEFT)
      this.mesh.scale.set((this.facing > 0 ? -1 : 1) * (cellW / TILE_PX), cellH / TILE_PX, 1);
    } else {
      this.mesh.material = this.sheetMat;
      cellW = 46; cellH = 58;
      // sheet.png is 24 cols x 3 rows
      this.sheetMat.map.repeat.set(1 / 24, 1 / 3);
      this.sheetMat.map.offset.set(col / 24, (3 - 1 - row) / 3);
      this.mesh.scale.set((this.facing > 0 ? -1 : 1) * (cellW / TILE_PX), cellH / TILE_PX, 1);
    }
  }
}

// ============================================================================
// 9. ENEMIES ("Ink Shades")
// ============================================================================
let enemies = [];

class InkShade {
  constructor(x, z) {
    this.x = x;
    this.y = 0;
    this.z = z;
    this.vx = 0;
    this.vy = 0;
    this.vz = 0;
    this.facing = -1;
    this.hp = 2;
    this.maxHp = 2;
    this.alive = true;

    this.state = 'approach'; // approach, telegraph, attack, hurt, dead
    this.stateTimer = 0;
    this.laneTargetZ = z;
    this.animTime = Math.random() * 10;
    this.cooldown = 1.2 + Math.random() * 1.5;

    // Sprite Mesh setup
    const geo = new THREE.PlaneGeometry(1, 1);
    geo.translate(0, 0.5, 0);

    this.mat = new THREE.MeshLambertMaterial({
      map: enemySheetTex.clone(),
      emissive: new THREE.Color(0x181230),
      alphaTest: 0.5,
      transparent: false,
      side: THREE.DoubleSide
    });
    if (this.mat.map.image) this.mat.map.needsUpdate = true;

    this.mesh = new THREE.Mesh(geo, this.mat);
    scene.add(this.mesh);

    // Floor shadow
    const sGeo = new THREE.PlaneGeometry(1.3, 0.7);
    const sMat = new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, opacity: 0.45, depthWrite: false });
    this.shadow = new THREE.Mesh(sGeo, sMat);
    this.shadow.rotation.x = -Math.PI / 2;
    this.shadow.position.y = 0.01;
    scene.add(this.shadow);
  }

  takeDamage(dmg, knockDir) {
    if (!this.alive) return;
    this.hp -= dmg;
    playSFX(this.hp <= 0 ? 'kill' : 'hit');
    spawnHitSpark(this.x, this.y + 1.0, this.z);

    // Knockback
    this.vx = knockDir * 5.0;
    this.state = 'hurt';
    this.stateTimer = 0.35;

    // Hit-stop
    hitStop(0.06);

    // Increment combo
    incrementCombo();

    if (this.hp <= 0) {
      this.die();
    }
  }

  die() {
    this.alive = false;
    this.state = 'dead';
    this.stateTimer = 0.4;
    spawnDeathBurst(this.x, this.y, this.z);
    totalKills++;
    updateHUD();
    checkWaveProgress();
  }

  update(dt) {
    this.animTime += dt;
    if (!this.alive) {
      this.stateTimer -= dt;
      if (this.stateTimer <= 0) {
        scene.remove(this.mesh);
        scene.remove(this.shadow);
      }
      return;
    }

    if (this.cooldown > 0) this.cooldown -= dt;

    const dx = player.x - this.x;
    const dz = player.z - this.z;
    const dist = Math.hypot(dx, dz);

    if (this.state === 'hurt') {
      this.stateTimer -= dt;
      this.x += this.vx * dt;
      this.vx *= 0.85;
      if (this.stateTimer <= 0) {
        this.state = 'approach';
      }
    } else if (this.state === 'telegraph') {
      this.stateTimer -= dt;
      this.vx = 0;
      this.vz = 0;
      if (this.stateTimer <= 0) {
        // Lunge attack forward!
        this.state = 'attack';
        this.stateTimer = 0.28;
        this.facing = dx >= 0 ? 1 : -1;
        this.vx = this.facing * 7.5;
        playSFX('slash2');
      }
    } else if (this.state === 'attack') {
      this.stateTimer -= dt;
      this.x += this.vx * dt;

      // Hit detection against player
      const pzDiff = Math.abs(this.z - player.z);
      const pxDiff = Math.abs(this.x - player.x);
      if (pzDiff <= LANE_TOLERANCE && pxDiff <= 1.4 && player.ground) {
        player.takeDamage(1, this.x);
      }

      if (this.stateTimer <= 0) {
        this.state = 'approach';
        this.cooldown = 1.6 + Math.random() * 1.4;
      }
    } else if (this.state === 'approach') {
      this.facing = dx >= 0 ? 1 : -1;

      // Check if ready to attack (in lane and close)
      if (Math.abs(dz) <= 0.5 && Math.abs(dx) <= 2.0 && this.cooldown <= 0 && player.hp > 0) {
        this.state = 'telegraph';
        this.stateTimer = 0.42; // Telegraph flash warning
      } else {
        // Move towards lane and player
        const targetX = player.x + (dx >= 0 ? -1.4 : 1.4);
        const tdx = targetX - this.x;
        const tdz = player.z - this.z;

        const moveSpeed = 2.4;
        this.vx = Math.sign(tdx) * Math.min(Math.abs(tdx), moveSpeed);
        this.vz = Math.sign(tdz) * Math.min(Math.abs(tdz), moveSpeed * 0.7);

        this.x += this.vx * dt;
        this.z += this.vz * dt;
      }
    }

    // Keep in lane limits
    this.z = Math.max(Z_MIN, Math.min(Z_MAX, this.z));

    // Clamp inside zone lock
    if (zoneLocked) {
      this.x = Math.max(zoneMinX - 1, Math.min(zoneMaxX + 1, this.x));
    }

    // Update mesh position and animation frame
    this.mesh.position.set(this.x, this.y, this.z);
    this.mesh.rotation.x = camera.rotation.x;
    this.shadow.position.set(this.x, 0.01, this.z);

    // Frame pick
    let row = 0, col = 0;
    if (this.state === 'hurt') {
      row = 4;
      col = Math.floor(this.animTime * 12) % 2;
    } else if (this.state === 'attack') {
      row = 3;
      col = Math.min(3, Math.floor((0.28 - this.stateTimer) / 0.07));
    } else if (this.state === 'telegraph') {
      row = 2;
      col = Math.min(3, Math.floor((0.42 - this.stateTimer) / 0.1));
    } else if (Math.abs(this.vx) > 0.2 || Math.abs(this.vz) > 0.2) {
      row = 1;
      col = Math.floor(this.animTime * 8) % 4;
    } else {
      row = 0;
      col = Math.floor(this.animTime * 6) % 4;
    }

    // Sheet is 4 cols x 6 rows (32x32)
    this.mat.map.repeat.set(1 / 4, 1 / 6);
    this.mat.map.offset.set(col / 4, (6 - 1 - row) / 6);
    this.mesh.scale.set((this.facing > 0 ? -1 : 1) * 2.8, 2.8, 1);
  }
}

// ============================================================================
// 10. ARENA WAVES & COMBAT FLOW
// ============================================================================
let currentWave = 1;
let totalKills = 0;
let waveEnemiesDefeated = 0;
let waveTotalEnemies = 3;
let zoneLocked = false;
let zoneCenterCamX = 26;
let zoneMinX = 13, zoneMaxX = 39;
let goPromptVisible = false;
let gameWon = false;
let gameStartTime = 0;

// 3 Waves setup
// Wave 1: 3 enemies at X ≈ 26
// Wave 2: 4 enemies at X ≈ 60
// Wave 3: 5 enemies at X ≈ 94
const WAVES_CONFIG = [
  {
    triggerX: 24,
    camX: 26,
    minX: 13,
    maxX: 39,
    count: 3,
    spawns: [
      { x: 35, z: 1.2 },
      { x: 37, z: 3.8 },
      { x: 16, z: 2.5 }
    ]
  },
  {
    triggerX: 58,
    camX: 60,
    minX: 47,
    maxX: 73,
    count: 4,
    spawns: [
      { x: 70, z: 1.0 },
      { x: 72, z: 4.2 },
      { x: 50, z: 2.0 },
      { x: 71, z: 2.8 }
    ]
  },
  {
    triggerX: 92,
    camX: 94,
    minX: 81,
    maxX: 107,
    count: 5,
    spawns: [
      { x: 104, z: 1.0 },
      { x: 106, z: 4.5 },
      { x: 84, z: 1.8 },
      { x: 83, z: 3.6 },
      { x: 105, z: 2.7 }
    ]
  }
];

function checkFightZoneTriggers() {
  if (zoneLocked || currentWave > 3) return;

  const conf = WAVES_CONFIG[currentWave - 1];
  if (conf && player.x >= conf.triggerX) {
    // Lock the screen into the fight zone!
    zoneLocked = true;
    zoneCenterCamX = conf.camX;
    zoneMinX = conf.minX;
    zoneMaxX = conf.maxX;
    waveTotalEnemies = conf.count;
    waveEnemiesDefeated = 0;
    hideGoPrompt();

    // Spawn wave enemies with ink rise effect
    for (const sp of conf.spawns) {
      const e = new InkShade(sp.x, sp.z);
      enemies.push(e);
      spawnDust(sp.x, 0, sp.z, 6);
    }
    playSFX('impact');
    updateHUD();
  }
}

function checkWaveProgress() {
  const aliveEnemies = enemies.filter(e => e.alive).length;
  if (zoneLocked && aliveEnemies === 0) {
    // Wave cleared!
    zoneLocked = false;
    currentWave++;
    playSFX('counter');
    showGoPrompt();
    updateHUD();

    if (currentWave > 3) {
      // All 3 waves defeated! Arrow points to goal torii
    }
  }
}

function showGoPrompt() {
  goPromptVisible = true;
  const el = document.getElementById('go-prompt');
  if (el) el.style.display = 'block';
}

function hideGoPrompt() {
  goPromptVisible = false;
  const el = document.getElementById('go-prompt');
  if (el) el.style.display = 'none';
}

// ============================================================================
// 11. COMBO COUNTER SYSTEM
// ============================================================================
let comboHits = 0;
let comboTimer = 0;
let maxCombo = 0;

function incrementCombo() {
  comboHits++;
  comboTimer = 1.8; // resets after 1.8s of no hits
  if (comboHits > maxCombo) maxCombo = comboHits;

  const box = document.getElementById('combo-box');
  const count = document.getElementById('combo-count');
  if (comboHits >= 3 && box && count) {
    count.textContent = comboHits + ' HITS!';
    box.classList.remove('pop');
    void box.offsetWidth; // retrigger CSS animation
    box.classList.add('pop');
  }
}

function updateCombo(dt) {
  if (comboHits > 0) {
    comboTimer -= dt;
    if (comboTimer <= 0) {
      comboHits = 0;
      const box = document.getElementById('combo-box');
      if (box) box.classList.remove('pop');
    }
  }
}

// ============================================================================
// 12. CAMERA CONTROLLER & EFFECTS
// ============================================================================
let camX = 4.0;
function updateCamera(dt) {
  // Smoothly follow player along X, unless locked in fight zone
  let targetX = player.x;
  if (zoneLocked) {
    targetX = zoneCenterCamX;
  }
  camX += (targetX - camX) * Math.min(1.0, dt * 5.0);

  // Elevated and tilted down ~25°
  const D = 18.0;
  const tiltRad = 25 * Math.PI / 180;
  const targetY = 1.0;
  const targetZ = 2.5;

  let shakeX = 0, shakeY = 0;
  if (cameraShakeTrauma > 0) {
    cameraShakeTrauma = Math.max(0, cameraShakeTrauma - dt * 2.8);
    const shakeP = cameraShakeTrauma * cameraShakeTrauma;
    shakeX = (Math.random() - 0.5) * 0.7 * shakeP;
    shakeY = (Math.random() - 0.5) * 0.7 * shakeP;
  }

  camera.position.x = camX + shakeX;
  camera.position.y = targetY + D * Math.sin(tiltRad) + shakeY;
  camera.position.z = targetZ + D * Math.cos(tiltRad);
  camera.rotation.x = -tiltRad;
  camera.rotation.y = 0;
  camera.rotation.z = 0;

  // Animate flickering point lights
  const time = performance.now() * 0.001;
  for (const l of lanterns) {
    l.light.intensity = l.baseInt + Math.sin(time * 12 + l.offset) * 0.12;
  }
}

function cameraShake(amount) {
  cameraShakeTrauma = Math.min(1.0, cameraShakeTrauma + amount);
}

function hitStop(duration = 0.06) {
  hitStopTimer = duration;
}

// ============================================================================
// 13. HUD & UI MANAGEMENT
// ============================================================================
function updateHUD() {
  const hHp = document.getElementById('hHp');
  const hWave = document.getElementById('hWave');
  const hEnemies = document.getElementById('hEnemies');
  const hKills = document.getElementById('hKills');

  if (hHp) {
    let hearts = '';
    for (let i = 0; i < 5; i++) {
      hearts += i < player.hp ? '♥' : '♡';
    }
    hHp.textContent = hearts;
  }

  if (hWave) {
    hWave.textContent = currentWave <= 3 ? `${currentWave}/3` : 'ผ่านครบแล้ว!';
  }

  if (hEnemies) {
    const remaining = enemies.filter(e => e.alive).length;
    hEnemies.textContent = remaining;
  }

  if (hKills) {
    hKills.textContent = totalKills;
  }
}

function showGameOver() {
  const el = document.getElementById('gameover-overlay');
  const k = document.getElementById('goKills');
  const c = document.getElementById('goCombo');
  if (k) k.textContent = totalKills;
  if (c) c.textContent = maxCombo;
  if (el) el.classList.remove('hidden');
}

function showWin() {
  gameWon = true;
  const el = document.getElementById('win-overlay');
  const t = document.getElementById('winTime');
  const k = document.getElementById('winKills');
  const c = document.getElementById('winCombo');
  const h = document.getElementById('winHp');

  const elapsed = Math.floor((performance.now() - gameStartTime) / 1000);
  const mins = Math.floor(elapsed / 60);
  const secs = elapsed % 60;
  if (t) t.textContent = `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  if (k) k.textContent = `${totalKills}/12`;
  if (c) c.textContent = maxCombo;
  if (h) {
    let hearts = '';
    for (let i = 0; i < 5; i++) hearts += i < player.hp ? '♥' : '♡';
    h.textContent = hearts;
  }

  if (el) el.classList.remove('hidden');
  playSFX('pickup');
}

function resetGame() {
  document.getElementById('start-overlay').classList.add('hidden');
  document.getElementById('gameover-overlay').classList.add('hidden');
  document.getElementById('win-overlay').classList.add('hidden');

  currentWave = 1;
  totalKills = 0;
  comboHits = 0;
  maxCombo = 0;
  zoneLocked = false;
  gameWon = false;
  gameStartTime = performance.now();

  hideGoPrompt();

  // Clear existing enemies
  for (const e of enemies) {
    scene.remove(e.mesh);
    scene.remove(e.shadow);
  }
  enemies = [];

  initCrates();
  player.reset(2.0, 2.5);
  camX = 4.0;
  updateHUD();
}

// ============================================================================
// 14. INPUT HANDLING
// ============================================================================
const keys = {};
const input = {
  left: false,
  right: false,
  up: false,
  down: false,
  shift: false,
  jumpPressed: false,
  attackPressed: false,
  dodgePressed: false
};

const KEY_MAP = {
  ArrowLeft: 'left', KeyA: 'left',
  ArrowRight: 'right', KeyD: 'right',
  ArrowUp: 'up', KeyW: 'up',
  ArrowDown: 'down', KeyS: 'down',
  ShiftLeft: 'shift', ShiftRight: 'shift',
  Space: 'jump',
  KeyX: 'attack', KeyJ: 'attack',
  KeyC: 'dodge', KeyK: 'dodge',
  KeyR: 'restart'
};

function initInput() {
  window.addEventListener('keydown', e => {
    unlockAudio();
    const action = KEY_MAP[e.code];
    if (action) {
      if (!keys[action]) {
        if (action === 'jump') input.jumpPressed = true;
        if (action === 'attack') input.attackPressed = true;
        if (action === 'dodge') input.dodgePressed = true;
        if (action === 'restart') resetGame();
      }
      keys[action] = true;
      e.preventDefault();
    }
  });

  window.addEventListener('keyup', e => {
    const action = KEY_MAP[e.code];
    if (action) {
      keys[action] = false;
      e.preventDefault();
    }
  });

  // UI buttons
  const startBtn = document.getElementById('start-btn');
  if (startBtn) startBtn.addEventListener('click', () => { unlockAudio(); resetGame(); });

  const rGoBtn = document.getElementById('restart-go-btn');
  if (rGoBtn) rGoBtn.addEventListener('click', () => { resetGame(); });

  const rWinBtn = document.getElementById('restart-win-btn');
  if (rWinBtn) rWinBtn.addEventListener('click', () => { resetGame(); });
}

function pollInput() {
  input.left = !!keys.left;
  input.right = !!keys.right;
  input.up = !!keys.up;
  input.down = !!keys.down;
  input.shift = !!keys.shift;
}

function clearPressedInput() {
  input.jumpPressed = false;
  input.attackPressed = false;
  input.dodgePressed = false;
}

// ============================================================================
// 15. MAIN GAME LOOP & SIMULATION STEP
// ============================================================================
let player;
let lastTime = performance.now();
const FIXED_STEP = 1 / 60;
let accumTime = 0;

function update(dt) {
  if (hitStopTimer > 0) {
    hitStopTimer -= dt;
    return;
  }

  pollInput();
  player.update(dt, input);
  clearPressedInput();

  // Update Enemies
  for (const enemy of enemies) {
    enemy.update(dt);
  }

  // Update Pickups
  for (const pickup of pickups) {
    pickup.update(dt);
  }

  // Check Fight Zone Trigger & Wave Progress
  checkFightZoneTriggers();

  // Check Goal reached (Victory!)
  if (!gameWon && currentWave > 3 && player.x >= 115) {
    showWin();
  }

  // Update Particles & Combo
  updateParticles(dt);
  updateCombo(dt);
  updateCamera(dt);
}

function render() {
  if (composer) {
    composer.render();
  } else {
    renderer.render(scene, camera);
  }
}

function gameLoop(now) {
  const dt = Math.min(0.1, (now - lastTime) / 1000);
  lastTime = now;
  accumTime += dt;

  while (accumTime >= FIXED_STEP) {
    update(FIXED_STEP);
    accumTime -= FIXED_STEP;
  }

  render();
  requestAnimationFrame(gameLoop);
}

// ============================================================================
// 16. DEBUG HOOK FOR AUTOMATED TESTING
// ============================================================================
// Expose __step(ms) and __dbg() when URL has ?debug
if (/[?&]debug/.test(location.search)) {
  window.__dbg = () => ({
    player,
    enemies,
    crates,
    pickups,
    camera,
    scene,
    currentWave,
    zoneLocked,
    totalKills,
    comboHits,
    maxCombo,
    reset: resetGame,
    SFX: window.SFX,
    THREE: window.THREE
  });

  window.__step = (ms = 16.67) => {
    const steps = Math.max(1, Math.round((ms / 1000) / FIXED_STEP));
    for (let i = 0; i < steps; i++) {
      update(FIXED_STEP);
    }
    render();
    updateHUD();
  };
}

// ============================================================================
// 17. INITIALIZATION
// ============================================================================
function init() {
  initThree();
  initInput();
  player = new Player();
  initCrates();
  updateHUD();
  lastTime = performance.now();
  requestAnimationFrame(gameLoop);
}

if (document.readyState === 'loading') {
  window.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

})();
