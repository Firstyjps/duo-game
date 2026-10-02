/**
 * ============================================================================
 * sfx.js - Web Audio 8-bit SFX Engine for Kintsugi / Japanese Pixel Art Platformer
 * Pure Web Audio API synthesis (zero external files, zero dependencies).
 *
 * API:
 *   window.SFX = {
 *     unlock(),
 *     play(name, opts?),
 *     setMuted(bool),
 *     muted
 *   }
 * ============================================================================
 */

(function(global) {
  'use strict';

  // --- Audio Context & Graph ---
  let ctx = null;
  let masterGain = null;
  let compressor = null;
  let noiseBuffer = null;
  let isMuted = false;

  // Track active voices for voice-limiting and stopping handles
  const activeVoices = {};
  const lastPlayTime = {};

  // Voice limits per sound name to avoid crackle / sound buildup
  const MAX_VOICES = {
    step: 2,
    hit: 2,
    slash1: 2,
    slash2: 2,
    slash3: 2,
    slash4: 2,
    slash5: 2,
    impact: 2,
    land: 2,
    heavyland: 1,
    dash: 2,
    roll: 1,
    slide: 1,
    wallslide: 1,
    climb: 2,
    charge: 1,
    hurt: 1,
    die: 1
  };
  const DEFAULT_MAX_VOICES = 3;

  // Minimum trigger interval in seconds to throttle frame-spam
  const MIN_INTERVAL = {
    step: 0.05,
    hit: 0.04,
    slide: 0.06,
    climb: 0.05,
    wallslide: 0.06
  };

  /**
   * Initialize AudioContext and Master Compressor Graph
   */
  function initContext() {
    if (ctx) return ctx;
    const AudioCtx = (typeof window !== 'undefined' && (window.AudioContext || window.webkitAudioContext));
    if (!AudioCtx) return null;

    try {
      ctx = new AudioCtx();

      // Master Compressor (prevents distortion and clipping when sounds overlap)
      compressor = ctx.createDynamicsCompressor();
      compressor.threshold.setValueAtTime(-18, ctx.currentTime);
      compressor.knee.setValueAtTime(24, ctx.currentTime);
      compressor.ratio.setValueAtTime(10, ctx.currentTime);
      compressor.attack.setValueAtTime(0.003, ctx.currentTime);
      compressor.release.setValueAtTime(0.18, ctx.currentTime);

      // Master Gain Node (~0.35 level as required)
      masterGain = ctx.createGain();
      masterGain.gain.setValueAtTime(isMuted ? 0 : 0.35, ctx.currentTime);

      masterGain.connect(compressor);
      compressor.connect(ctx.destination);
    } catch (e) {
      ctx = null;
    }
    return ctx;
  }

  /**
   * Unlock or resume AudioContext on player first interaction
   */
  function unlock() {
    if (!ctx) {
      initContext();
    }
    if (ctx && ctx.state === 'suspended') {
      ctx.resume().catch(function() {});
    }
    return ctx;
  }

  /**
   * Shared 2-second white noise buffer for crisp percussion and swooshes
   */
  function getNoiseBuffer() {
    if (!noiseBuffer && ctx) {
      const sampleRate = ctx.sampleRate || 44100;
      const length = sampleRate * 2;
      noiseBuffer = ctx.createBuffer(1, length, sampleRate);
      const data = noiseBuffer.getChannelData(0);
      for (let i = 0; i < length; i++) {
        data[i] = Math.random() * 2 - 1;
      }
    }
    return noiseBuffer;
  }

  /**
   * Voice Manager: limit concurrency and track voice handles
   */
  function registerVoice(name, stopFn) {
    if (!activeVoices[name]) activeVoices[name] = [];
    const list = activeVoices[name];
    const max = MAX_VOICES[name] || DEFAULT_MAX_VOICES;

    while (list.length >= max) {
      const oldVoice = list.shift();
      try { oldVoice.stop(); } catch (e) {}
    }

    const voice = {
      stop: function() {
        try { stopFn(); } catch (e) {}
        const idx = list.indexOf(voice);
        if (idx !== -1) list.splice(idx, 1);
      }
    };
    list.push(voice);
    return voice;
  }

  // --- Chiptune / Kintsugi Sound Synthesis Primitives ---

  /**
   * Pluck sound for Japanese Koto / Bell timbre
   * Uses fundamental triangle + sine harmonic overtone + crisp attack pick tap
   */
  function playPluck(t, freq, duration, vol, harmonicRatio, isBell) {
    const osc1 = ctx.createOscillator();
    const osc2 = ctx.createOscillator();
    const gain = ctx.createGain();

    osc1.type = isBell ? 'sine' : 'triangle';
    osc1.frequency.setValueAtTime(freq, t);

    // Koto string slight pitch bend on attack
    if (!isBell) {
      osc1.frequency.linearRampToValueAtTime(freq * 0.98, t + duration);
    }

    osc2.type = 'sine';
    osc2.frequency.setValueAtTime(freq * (harmonicRatio || 2.0), t);

    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);

    osc1.connect(gain);
    osc2.connect(gain);
    gain.connect(masterGain);

    osc1.start(t);
    osc2.start(t);
    osc1.stop(t + duration + 0.02);
    osc2.stop(t + duration + 0.02);

    // Pluck plectrum attack noise transient
    const nBuf = getNoiseBuffer();
    if (nBuf) {
      const nSrc = ctx.createBufferSource();
      const nFilter = ctx.createBiquadFilter();
      const nGain = ctx.createGain();

      nSrc.buffer = nBuf;
      nFilter.type = 'bandpass';
      nFilter.frequency.setValueAtTime(isBell ? 2800 : 1800, t);
      nFilter.Q.setValueAtTime(2, t);

      nGain.gain.setValueAtTime(vol * 0.25, t);
      nGain.gain.exponentialRampToValueAtTime(0.0001, t + 0.025);

      nSrc.connect(nFilter);
      nFilter.connect(nGain);
      nGain.connect(masterGain);

      nSrc.start(t);
      nSrc.stop(t + 0.03);
    }
  }

  /**
   * Noise sweep with filter envelope (used for sharp blade slashes and dashes)
   */
  function playSlashNoise(t, startFreq, endFreq, duration, vol, qVal) {
    const nBuf = getNoiseBuffer();
    if (!nBuf) return;

    const src = ctx.createBufferSource();
    const filter = ctx.createBiquadFilter();
    const gain = ctx.createGain();

    src.buffer = nBuf;
    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(startFreq, t);
    filter.frequency.exponentialRampToValueAtTime(Math.max(40, endFreq), t + duration);
    filter.Q.setValueAtTime(qVal || 3, t);

    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);

    src.connect(filter);
    filter.connect(gain);
    gain.connect(masterGain);

    src.start(t);
    src.stop(t + duration + 0.02);
  }

  // --- Sound Definitions Table (29 sounds) ---
  const SOUNDS = {
    // 1. jump: Classic 8-bit upward frequency sweep (triangle wave)
    jump: function(t, p, v) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(140 * p, t);
      osc.frequency.exponentialRampToValueAtTime(390 * p, t + 0.12);

      gain.gain.setValueAtTime(0.4 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.12);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.13);
    },

    // 2. doublejump: Lighter, crisp two-tone rising chime (Japanese aerial leap)
    doublejump: function(t, p, v) {
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gain = ctx.createGain();

      osc1.type = 'triangle';
      osc1.frequency.setValueAtTime(260 * p, t);
      osc1.frequency.exponentialRampToValueAtTime(650 * p, t + 0.14);

      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(520 * p, t);
      osc2.frequency.exponentialRampToValueAtTime(1300 * p, t + 0.14);

      gain.gain.setValueAtTime(0.35 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.14);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(masterGain);

      osc1.start(t);
      osc2.start(t);
      osc1.stop(t + 0.15);
      osc2.stop(t + 0.15);
    },

    // 3. land: Short soft earth thud (low triangle + filtered puff)
    land: function(t, p, v) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(120 * p, t);
      osc.frequency.exponentialRampToValueAtTime(35 * p, t + 0.07);

      gain.gain.setValueAtTime(0.3 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.07);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.08);
    },

    // 4. heavyland: Deep heavy bass impact with ground dust crunch
    heavyland: function(t, p, v) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(95 * p, t);
      osc.frequency.exponentialRampToValueAtTime(25 * p, t + 0.22);

      gain.gain.setValueAtTime(0.6 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.22);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.24);

      // Lowpass dust burst
      playSlashNoise(t, 380 * p, 60 * p, 0.18, 0.45 * v, 1.2);
    },

    // 5. step: Subtle stone/tatami tap (bandpass noise + tiny click)
    step: function(t, p, v) {
      playSlashNoise(t, 850 * p, 300 * p, 0.035, 0.18 * v, 3.5);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(90 * p, t);
      osc.frequency.exponentialRampToValueAtTime(40 * p, t + 0.03);

      gain.gain.setValueAtTime(0.15 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.03);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.04);
    },

    // 6. slash1: Combo 1: Sharp crisp high blade swipe (noise burst + filter sweep)
    slash1: function(t, p, v) {
      playSlashNoise(t, 4200 * p, 900 * p, 0.065, 0.5 * v, 4);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(320 * p, t);
      osc.frequency.exponentialRampToValueAtTime(110 * p, t + 0.04);

      gain.gain.setValueAtTime(0.18 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.04);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.05);
    },

    // 7. slash2: Combo 2: Rising diagonal slash (higher frequency slice)
    slash2: function(t, p, v) {
      playSlashNoise(t, 5000 * p, 1200 * p, 0.065, 0.52 * v, 4.2);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(420 * p, t);
      osc.frequency.exponentialRampToValueAtTime(140 * p, t + 0.04);

      gain.gain.setValueAtTime(0.18 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.04);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.05);
    },

    // 8. slash3: Combo 3: Piercing thrust (narrow resonant bandpass slice)
    slash3: function(t, p, v) {
      playSlashNoise(t, 3600 * p, 700 * p, 0.075, 0.55 * v, 5.5);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(480 * p, t);
      osc.frequency.exponentialRampToValueAtTime(160 * p, t + 0.05);

      gain.gain.setValueAtTime(0.15 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.05);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.06);
    },

    // 9. slash4: Combo 4: Heavy downward cleave (double noise swipe + low bite)
    slash4: function(t, p, v) {
      playSlashNoise(t, 4600 * p, 800 * p, 0.085, 0.58 * v, 3.8);
      setTimeout(function() {
        if (ctx && ctx.state === 'running') {
          playSlashNoise(ctx.currentTime, 3200 * p, 600 * p, 0.06, 0.4 * v, 3.5);
        }
      }, 20);

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(260 * p, t);
      osc.frequency.exponentialRampToValueAtTime(70 * p, t + 0.07);

      gain.gain.setValueAtTime(0.25 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.07);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.08);
    },

    // 10. slash5: Finisher: Lethal blade strike with resonant Koto bell overtone
    slash5: function(t, p, v) {
      playSlashNoise(t, 5500 * p, 450 * p, 0.12, 0.65 * v, 3);
      // Japanese Hirajoshi A5 ringing katana resonance
      playPluck(t, 880 * p, 0.22, 0.35 * v, 2.0, false);

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(350 * p, t);
      osc.frequency.exponentialRampToValueAtTime(50 * p, t + 0.09);

      gain.gain.setValueAtTime(0.3 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.09);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.1);
    },

    // 11. plunge: Downward dive whoosh into a heavy low-end thud
    plunge: function(t, p, v) {
      // Descending dive whistle
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(340 * p, t);
      osc.frequency.exponentialRampToValueAtTime(75 * p, t + 0.18);

      gain.gain.setValueAtTime(0.35 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.18);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.19);

      // Low dive rush noise
      playSlashNoise(t, 1800 * p, 200 * p, 0.18, 0.45 * v, 2);

      // Sub thud tail
      const sub = ctx.createOscillator();
      const subGain = ctx.createGain();
      sub.type = 'triangle';
      sub.frequency.setValueAtTime(110 * p, t + 0.08);
      sub.frequency.exponentialRampToValueAtTime(30 * p, t + 0.25);

      subGain.gain.setValueAtTime(0.55 * v, t + 0.08);
      subGain.gain.linearRampToValueAtTime(0.0001, t + 0.25);

      sub.connect(subGain);
      subGain.connect(masterGain);
      sub.start(t + 0.08);
      sub.stop(t + 0.26);
    },

    // 12. impact: Heavy low bass punch + crunch (ทุ้มหนัก)
    impact: function(t, p, v) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(140 * p, t);
      osc.frequency.exponentialRampToValueAtTime(28 * p, t + 0.22);

      gain.gain.setValueAtTime(0.7 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.22);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.24);

      // Crunchy lowpass shockwave
      playSlashNoise(t, 550 * p, 60 * p, 0.19, 0.6 * v, 1.8);
    },

    // 13. hit: Crisp retro hit transient on target
    hit: function(t, p, v) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(240 * p, t);
      osc.frequency.exponentialRampToValueAtTime(60 * p, t + 0.075);

      gain.gain.setValueAtTime(0.35 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.075);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.085);

      playSlashNoise(t, 1200 * p, 300 * p, 0.05, 0.35 * v, 2.5);
    },

    // 14. kill: Ceramic shatter / Kintsugi golden break & disintegration
    kill: function(t, p, v) {
      // Porcelain crack burst
      playSlashNoise(t, 3800 * p, 400 * p, 0.16, 0.65 * v, 2.5);

      // Rapid 3-step retro disintegrate arpeggio
      const notes = [587.33, 440.00, 220.00];
      notes.forEach(function(freq, i) {
        const stepTime = t + i * 0.035;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'square';
        osc.frequency.setValueAtTime(freq * p, stepTime);
        osc.frequency.exponentialRampToValueAtTime((freq * 0.5) * p, stepTime + 0.04);

        gain.gain.setValueAtTime(0.28 * v, stepTime);
        gain.gain.linearRampToValueAtTime(0.0001, stepTime + 0.04);

        osc.connect(gain);
        gain.connect(masterGain);
        osc.start(stepTime);
        osc.stop(stepTime + 0.045);
      });
    },

    // 15. dash: Quick air rush / wind burst
    dash: function(t, p, v) {
      playSlashNoise(t, 2200 * p, 350 * p, 0.13, 0.5 * v, 2);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(240 * p, t);
      osc.frequency.exponentialRampToValueAtTime(100 * p, t + 0.11);

      gain.gain.setValueAtTime(0.25 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.11);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.12);
    },

    // 16. roll: Ground tumble / forward roll whoosh
    roll: function(t, p, v) {
      playSlashNoise(t, 700 * p, 250 * p, 0.16, 0.38 * v, 1.8);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(130 * p, t);
      osc.frequency.exponentialRampToValueAtTime(60 * p, t + 0.15);

      gain.gain.setValueAtTime(0.25 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.15);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.16);
    },

    // 17. slide: Ground skid friction across surface
    slide: function(t, p, v) {
      playSlashNoise(t, 900 * p, 350 * p, 0.15, 0.42 * v, 2.2);
    },

    // 18. wallslide: Gritty wall friction scrape
    wallslide: function(t, p, v) {
      playSlashNoise(t, 1300 * p, 500 * p, 0.12, 0.35 * v, 3.2);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(110 * p, t);
      osc.frequency.linearRampToValueAtTime(70 * p, t + 0.1);

      gain.gain.setValueAtTime(0.12 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.1);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.11);
    },

    // 19. walljump: Punchy kick off wall + springy ascending note
    walljump: function(t, p, v) {
      // Wall kick tap
      const kick = ctx.createOscillator();
      const kickGain = ctx.createGain();
      kick.type = 'triangle';
      kick.frequency.setValueAtTime(160 * p, t);
      kick.frequency.exponentialRampToValueAtTime(50 * p, t + 0.04);

      kickGain.gain.setValueAtTime(0.35 * v, t);
      kickGain.gain.linearRampToValueAtTime(0.0001, t + 0.04);

      kick.connect(kickGain);
      kickGain.connect(masterGain);
      kick.start(t);
      kick.stop(t + 0.05);

      // Springy leap upward chirp
      const jump = ctx.createOscillator();
      const jumpGain = ctx.createGain();
      jump.type = 'triangle';
      jump.frequency.setValueAtTime(240 * p, t + 0.02);
      jump.frequency.exponentialRampToValueAtTime(520 * p, t + 0.13);

      jumpGain.gain.setValueAtTime(0.38 * v, t + 0.02);
      jumpGain.gain.linearRampToValueAtTime(0.0001, t + 0.13);

      jump.connect(jumpGain);
      jumpGain.connect(masterGain);
      jump.start(t + 0.02);
      jump.stop(t + 0.14);
    },

    // 20. climb: Subtle handhold grab tap on ledge/ladder
    climb: function(t, p, v) {
      playSlashNoise(t, 750 * p, 280 * p, 0.035, 0.22 * v, 3);
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(130 * p, t);
      osc.frequency.exponentialRampToValueAtTime(60 * p, t + 0.035);

      gain.gain.setValueAtTime(0.2 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.035);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.045);
    },

    // 21. hurt: Downward pitch fall with retro vibrato (เสียงตก)
    hurt: function(t, p, v) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(360 * p, t);
      osc.frequency.exponentialRampToValueAtTime(80 * p, t + 0.18);

      // Tremolo / vibrato LFO
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      lfo.frequency.setValueAtTime(28, t);
      lfoGain.gain.setValueAtTime(30 * p, t);
      lfo.connect(osc.frequency);
      lfo.start(t);
      lfo.stop(t + 0.19);

      gain.gain.setValueAtTime(0.45 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.18);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.19);
    },

    // 22. die: Tragic descending multi-step 8-bit death cascade (เสียงตก)
    die: function(t, p, v) {
      // 5-step descending pitch cascade
      const steps = [440, 349, 293, 220, 110];
      steps.forEach(function(freq, i) {
        const stepTime = t + i * 0.11;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = i === steps.length - 1 ? 'sawtooth' : 'triangle';
        osc.frequency.setValueAtTime(freq * p, stepTime);
        osc.frequency.exponentialRampToValueAtTime((freq * 0.75) * p, stepTime + 0.11);

        gain.gain.setValueAtTime(0.4 * v, stepTime);
        gain.gain.linearRampToValueAtTime(0.0001, stepTime + 0.11);

        osc.connect(gain);
        gain.connect(masterGain);
        osc.start(stepTime);
        osc.stop(stepTime + 0.12);
      });

      // Low hollow rumble tail
      playSlashNoise(t + 0.35, 300 * p, 50 * p, 0.35, 0.35 * v, 1.5);
    },

    // 23. pickup: Pentatonic Koto 3-note arpeggio chime (D5 -> G5 -> A5)
    pickup: function(t, p, v) {
      const notes = [587.33, 783.99, 880.00];
      notes.forEach(function(freq, i) {
        playPluck(t + i * 0.055, freq * p, 0.18, 0.35 * v, 2.0, false);
      });
    },

    // 24. checkpoint: Majestic temple chime (5-note Japanese Pentatonic: D4, F4, G4, A4, D5)
    checkpoint: function(t, p, v) {
      const notes = [293.66, 349.23, 392.00, 440.00, 587.33];
      notes.forEach(function(freq, i) {
        playPluck(t + i * 0.07, freq * p, 0.45, 0.32 * v, 2.76, true);
      });
    },

    // 25. charge: Looping power surge (returns handle with .stop())
    charge: function(t, p, v) {
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const filter = ctx.createBiquadFilter();
      const gain = ctx.createGain();

      osc1.type = 'triangle';
      osc1.frequency.setValueAtTime(110 * p, t);

      osc2.type = 'sawtooth';
      osc2.frequency.setValueAtTime(111.5 * p, t); // Slight detune for pulsing chorus

      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(250 * p, t);
      filter.frequency.linearRampToValueAtTime(700 * p, t + 1.2);

      gain.gain.setValueAtTime(0.01, t);
      gain.gain.linearRampToValueAtTime(0.35 * v, t + 0.3);

      osc1.connect(filter);
      osc2.connect(filter);
      filter.connect(gain);
      gain.connect(masterGain);

      osc1.start(t);
      osc2.start(t);

      let stopped = false;
      return {
        stop: function() {
          if (stopped || !ctx) return;
          stopped = true;
          const stopTime = ctx.currentTime;
          gain.gain.cancelScheduledValues(stopTime);
          gain.gain.setValueAtTime(gain.gain.value, stopTime);
          gain.gain.linearRampToValueAtTime(0.0001, stopTime + 0.06);
          osc1.stop(stopTime + 0.07);
          osc2.stop(stopTime + 0.07);
        }
      };
    },

    // 26. chargeready: Sparkling crystalline Koto bell ring (full charge reached)
    chargeready: function(t, p, v) {
      playPluck(t, 880.00 * p, 0.35, 0.45 * v, 2.0, true);
      playPluck(t + 0.03, 1318.51 * p, 0.4, 0.35 * v, 2.0, true);
      playPluck(t + 0.06, 1760.00 * p, 0.45, 0.3 * v, 2.0, true);
    },

    // 27. burst: Heavy energy explosion (sub-bass boom + opening resonant noise)
    burst: function(t, p, v) {
      // Sub-bass thud (ทุ้มหนัก)
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(120 * p, t);
      osc.frequency.exponentialRampToValueAtTime(24 * p, t + 0.28);

      gain.gain.setValueAtTime(0.75 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.28);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.3);

      // Explosive noise filter sweep
      playSlashNoise(t, 1800 * p, 80 * p, 0.24, 0.65 * v, 2);

      // Golden harmonic shimmer
      playPluck(t, 1174.66 * p, 0.25, 0.3 * v, 2.0, true);
    },

    // 28. counter: Metallic blade deflection "ting!" followed by heavy counter punch
    counter: function(t, p, v) {
      // Sharp katana parry clink (high square + sine)
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(1400 * p, t);
      osc.frequency.exponentialRampToValueAtTime(800 * p, t + 0.07);

      gain.gain.setValueAtTime(0.45 * v, t);
      gain.gain.linearRampToValueAtTime(0.0001, t + 0.07);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(t);
      osc.stop(t + 0.08);

      playPluck(t, 1760.00 * p, 0.15, 0.35 * v, 1.5, true);

      // Follow-up counter bass punch
      const sub = ctx.createOscillator();
      const subGain = ctx.createGain();
      sub.type = 'triangle';
      sub.frequency.setValueAtTime(150 * p, t + 0.035);
      sub.frequency.exponentialRampToValueAtTime(35 * p, t + 0.18);

      subGain.gain.setValueAtTime(0.55 * v, t + 0.035);
      subGain.gain.linearRampToValueAtTime(0.0001, t + 0.18);

      sub.connect(subGain);
      subGain.connect(masterGain);
      sub.start(t + 0.035);
      sub.stop(t + 0.19);
    },

    // 29. win: Celebratory Japanese Pentatonic fanfare with lingering koto chords
    win: function(t, p, v) {
      // D4 -> F4 -> G4 -> A4 -> C5 -> D5 sequence
      const melody = [
        { f: 293.66, dt: 0.00 },
        { f: 349.23, dt: 0.09 },
        { f: 392.00, dt: 0.18 },
        { f: 440.00, dt: 0.27 },
        { f: 523.25, dt: 0.36 },
        { f: 587.33, dt: 0.45 }
      ];

      melody.forEach(function(item) {
        playPluck(t + item.dt, item.f * p, 0.28, 0.35 * v, 2.0, false);
      });

      // Grand sustaining chord: D5 (587.33Hz) + A5 (880.00Hz) bell resonance
      setTimeout(function() {
        if (!ctx || ctx.state !== 'running') return;
        const ct = ctx.currentTime;
        playPluck(ct, 587.33 * p, 0.9, 0.4 * v, 2.0, true);
        playPluck(ct, 880.00 * p, 0.9, 0.35 * v, 2.0, true);
      }, 540);
    }
  };

  /**
   * Main Play function
   * @param {string} name - Sound name
   * @param {object} [opts] - Optional { volume?: 0-1, pitch?: multiplier }
   * @returns {object} handle with .stop()
   */
  function play(name, opts) {
    const dummyHandle = { stop: function() {} };

    // Before unlock or if audio context is not ready, stay silent without error
    if (!ctx) return dummyHandle;
    if (isMuted) return dummyHandle;

    const fn = SOUNDS[name];
    if (!fn) return dummyHandle;

    const now = ctx.currentTime;

    // Throttle high-frequency sounds to avoid stacking clicks
    const minDt = MIN_INTERVAL[name];
    if (minDt && lastPlayTime[name] && (now - lastPlayTime[name] < minDt)) {
      return dummyHandle;
    }
    lastPlayTime[name] = now;

    opts = opts || {};
    const pitch = typeof opts.pitch === 'number' && opts.pitch > 0 ? opts.pitch : 1.0;
    const vol = typeof opts.volume === 'number' ? Math.max(0, Math.min(1, opts.volume)) : 1.0;

    let customHandle = null;
    try {
      customHandle = fn(now, pitch, vol);
    } catch (e) {
      return dummyHandle;
    }

    if (customHandle && typeof customHandle.stop === 'function') {
      return registerVoice(name, customHandle.stop);
    }

    // Default voice entry for automatic tracking/limiting
    return registerVoice(name, function() {});
  }

  /**
   * Set Mute status
   * @param {boolean} val
   */
  function setMuted(val) {
    isMuted = !!val;
    if (masterGain && ctx) {
      masterGain.gain.setValueAtTime(isMuted ? 0 : 0.35, ctx.currentTime);
    }
  }

  // --- Public API Object ---
  const SFX = {
    unlock: unlock,
    play: play,
    setMuted: setMuted
  };

  Object.defineProperty(SFX, 'muted', {
    get: function() { return isMuted; },
    set: function(val) { setMuted(val); },
    enumerable: true,
    configurable: true
  });

  // Export to global scope
  global.SFX = SFX;

})(typeof window !== 'undefined' ? window : this);

/**
 * ============================================================================
 * ตัวอย่างวิธีเรียกใช้งาน (Usage Examples):
 * ============================================================================
 *
 * 1. ปลดล็อค AudioContext (เรียกตอนเริ่มเกม หรือผู้เล่นกดปุ่ม/คลิกครั้งแรก):
 *    window.addEventListener('keydown', () => SFX.unlock(), { once: true });
 *    window.addEventListener('pointerdown', () => SFX.unlock(), { once: true });
 *
 * 2. เล่นเสียงพื้นฐาน:
 *    SFX.play('jump');
 *    SFX.play('step');
 *    SFX.play('hit');
 *    SFX.play('kill');
 *
 * 3. ส่งตัวเลือก volume (0-1) หรือ pitch (ตัวคูณความถี่):
 *    SFX.play('slash1', { volume: 0.8, pitch: 1.2 });
 *    SFX.play('pickup', { pitch: 1.05 });
 *
 * 4. ชาร์จพลัง (เสียง charge เป็น loop คืน handle ที่มี method .stop()):
 *    const chargeHandle = SFX.play('charge');
 *    // เมื่อชาร์จเสร็จ หรือปล่อยปุ่ม:
 *    chargeHandle.stop();
 *    SFX.play('chargeready');
 *
 * 5. ปิด/เปิดเสียง (Mute):
 *    SFX.setMuted(true);   // ปิดเสียง
 *    SFX.setMuted(false);  // เปิดเสียง
 *    console.log(SFX.muted); // เช็คสถานะปัจจุบัน
 * ============================================================================
 */
