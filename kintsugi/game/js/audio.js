// Thin wrapper over sfx.js (Web Audio synth, sets window.SFX). Missing audio never breaks the game.
import './sfx.js';

let unlocked = false;
export function unlockAudio() { if (unlocked) return; unlocked = true; try { window.SFX?.unlock(); } catch { /* audio unavailable */ } }
export function sfx(name, opts) { try { return window.SFX?.play(name, opts); } catch { return null; } }
export function toggleMute() {
  const S = window.SFX; if (!S) return true;
  S.setMuted(!S.muted);
  try { localStorage.setItem('kr-muted', S.muted ? '1' : '0'); } catch { /* storage blocked */ }
  return S.muted;
}
export function restoreMute() {
  try { if (localStorage.getItem('kr-muted') === '1') window.SFX?.setMuted(true); } catch { /* storage blocked */ }
  return !!window.SFX?.muted;
}
