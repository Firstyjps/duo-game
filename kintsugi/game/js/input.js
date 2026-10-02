// Keyboard + touch input. `keys` is held state; `pressed` holds edges until the player update consumes them.
export const keys = {};
export const pressed = { jump: false, attack: false, dash: false, roll: false, down: false };

const MAP = {
  ArrowLeft: 'left', KeyA: 'left', ArrowRight: 'right', KeyD: 'right',
  ArrowUp: 'up', KeyW: 'up', ArrowDown: 'down', KeyS: 'down',
  Space: 'jump', KeyZ: 'jump', KeyK: 'jump',
  KeyX: 'attack', KeyJ: 'attack',
  KeyC: 'dash', KeyL: 'dash',
  KeyV: 'roll', Semicolon: 'roll',
  ShiftLeft: 'run', ShiftRight: 'run',
};

export function press(k) { if (k in pressed && !keys[k]) pressed[k] = true; keys[k] = true; }
export function release(k) { keys[k] = false; }
export function clearPressed() { for (const k in pressed) pressed[k] = false; }
export const axis = () => (keys.right ? 1 : 0) - (keys.left ? 1 : 0);

export function bindInput({ onRestart, onStart, onNext, onMute, onAny }) {
  addEventListener('keydown', e => {
    onAny();
    const k = MAP[e.code];
    if (k) { press(k); e.preventDefault(); }
    if (e.code === 'KeyR') onRestart();
    if (e.code === 'KeyN') onNext();
    if (e.code === 'KeyM') onMute();
    if (e.code === 'Space' || e.code === 'Enter') onStart();
  });
  addEventListener('pointerdown', onAny);
  addEventListener('keyup', e => { const k = MAP[e.code]; if (k) release(k); });
  addEventListener('blur', () => { for (const k in keys) keys[k] = false; });

  const pad = document.getElementById('touch');
  if (matchMedia('(pointer: coarse)').matches) pad.classList.add('on');
  pad.querySelectorAll('[data-key]').forEach(el => {
    const k = el.dataset.key;
    const toggle = k === 'run';
    const on = e => { e.preventDefault(); if (toggle) { keys.run = !keys.run; el.classList.toggle('down', keys.run); return; } press(k); el.classList.add('down'); };
    const off = e => { e.preventDefault(); if (toggle) return; release(k); el.classList.remove('down'); };
    el.addEventListener('pointerdown', on);
    el.addEventListener('pointerup', off); el.addEventListener('pointercancel', off); el.addEventListener('pointerleave', off);
  });
}
