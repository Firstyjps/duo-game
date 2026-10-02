// Boot: load sprites, wire input, run the fixed-step loop.
import { W, H, STEP } from './config.js';
import { world } from './world.js';
import { bindInput } from './input.js';
import { loadSprites } from './sprites.js';
import { reset, begin, nextLevel, update, render, hud } from './game.js';
import { unlockAudio, toggleMute, restoreMute } from './audio.js';

const cv = document.getElementById('c'), ctx = cv.getContext('2d');
ctx.imageSmoothingEnabled = false;

function fit() {
  const s = Math.max(1, Math.floor(Math.min(innerWidth / W, innerHeight / H) * 2) / 2);
  cv.style.width = W * s + 'px'; cv.style.height = H * s + 'px';
}
addEventListener('resize', fit); fit();

const muteBtn = document.getElementById('mute');
const showMute = muted => { muteBtn.textContent = muted ? '🔇' : '🔊'; muteBtn.setAttribute('aria-pressed', String(muted)); };
const mute = () => showMute(toggleMute());
bindInput({
  onRestart: () => { reset(); begin(); },
  onStart: () => { if (!world.running) begin(); },
  onNext: () => { if (world.won) { nextLevel(); begin(); } },
  onMute: mute,
  onAny: unlockAudio,
});
muteBtn.addEventListener('pointerdown', e => { e.stopPropagation(); mute(); });
document.getElementById('start').addEventListener('pointerdown', begin);
document.getElementById('win').addEventListener('pointerdown', () => { nextLevel(); begin(); });
showMute(restoreMute());

await loadSprites('assets/');
reset(0);

// ?debug exposes deterministic stepping for automated checks (works while the tab is hidden).
if (/[?&]debug/.test(location.search)) {
  window.__dbg = () => world;
  window.__level = n => { reset(n); begin(); };
  import('./dev/playtest.js');
  window.__step = ms => { for (let i = 0; i < Math.round(ms / 1000 / STEP); i++) update(STEP); render(ctx); hud(); };
}

let last = performance.now(), acc = 0;
function frame(now) {
  acc += Math.min(.1, (now - last) / 1000); last = now;
  while (acc >= STEP) { update(STEP); acc -= STEP; }
  render(ctx); hud();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
