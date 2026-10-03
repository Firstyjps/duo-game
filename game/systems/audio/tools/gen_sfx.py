#!/usr/bin/env python3
"""
Procedural Audio & Music Generator for Phase 6 Audio System (Issue #60)
Theme: Japanese Night / Dark Dungeon (theme In / Miyako-bushi scale, non-piercing, clean fades)
Standard Library only: wave, struct, math, random.
Outputs 16-bit PCM WAV mono (44.1kHz) for SFX and stereo for Music.
"""

import math
import os
import random
import struct
import sys
import wave

SAMPLE_RATE = 44100

# ─────────────────────────────────────────────────────────────
# DSP & Math Utilities
# ─────────────────────────────────────────────────────────────

def clamp(val, low=-1.0, high=1.0):
    return max(low, min(high, val))

def lerp(a, b, t):
    return a + (b - a) * t

def db_to_linear(db):
    return 10.0 ** (db / 20.0)

def normalize(samples, target_peak=0.85):
    """Normalize array of float samples to target peak amplitude."""
    peak = max(abs(s) for s in samples) if samples else 0.0
    if peak <= 1e-6:
        return samples
    gain = target_peak / peak
    return [s * gain for s in samples]

def normalize_stereo(left, right, target_peak=0.85):
    peak = 0.0
    for s in left:
        if abs(s) > peak:
            peak = abs(s)
    for s in right:
        if abs(s) > peak:
            peak = abs(s)
    if peak <= 1e-6:
        return left, right
    gain = target_peak / peak
    return [s * gain for s in left], [s * gain for s in right]

def apply_fades(samples, fade_in_sec=0.005, fade_out_sec=0.02):
    n = len(samples)
    fade_in_len = int(fade_in_sec * SAMPLE_RATE)
    fade_out_len = int(fade_out_sec * SAMPLE_RATE)
    out = list(samples)
    for i in range(min(fade_in_len, n)):
        out[i] *= (i / max(1, fade_in_len))
    for i in range(min(fade_out_len, n)):
        idx = n - 1 - i
        out[idx] *= (i / max(1, fade_out_len))
    return out

def lowpass_filter(samples, cutoff_hz):
    """Single-pole lowpass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    prev = 0.0
    for i, s in enumerate(samples):
        prev += alpha * (s - prev)
        out[i] = prev
    return out

def bandpass_filter(samples, center_hz, bandwidth_hz):
    """Simple 2-pass resonant bandpass simulation."""
    hp_cutoff = max(20.0, center_hz - bandwidth_hz / 2.0)
    lp_cutoff = min(SAMPLE_RATE * 0.45, center_hz + bandwidth_hz / 2.0)
    # High-pass: sample - lowpass(sample)
    lp1 = lowpass_filter(samples, hp_cutoff)
    hp = [s - l for s, l in zip(samples, lp1)]
    # Low-pass
    return lowpass_filter(hp, lp_cutoff)

def save_wav_mono(filepath, samples):
    samples = normalize(samples, target_peak=0.88)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        raw = bytearray()
        for s in samples:
            val = int(clamp(s, -1.0, 1.0) * 32767.0)
            raw.extend(struct.pack('<h', val))
        wf.writeframes(raw)

def save_wav_stereo(filepath, left, right):
    left, right = normalize_stereo(left, right, target_peak=0.85)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        raw = bytearray()
        n = min(len(left), len(right))
        for i in range(n):
            vl = int(clamp(left[i], -1.0, 1.0) * 32767.0)
            vr = int(clamp(right[i], -1.0, 1.0) * 32767.0)
            raw.extend(struct.pack('<hh', vl, vr))
        wf.writeframes(raw)

# ─────────────────────────────────────────────────────────────
# Synthesis Primitives
# ─────────────────────────────────────────────────────────────

def karplus_strong(freq, duration, decay=0.985, pluck_brightness=0.7):
    """Karplus-Strong plucked string (Koto timbre)."""
    n_samples = int(duration * SAMPLE_RATE)
    delay_len = max(2, int(SAMPLE_RATE / freq))
    # Seed buffer with filtered noise
    buf = [(random.uniform(-1.0, 1.0) * pluck_brightness) for _ in range(delay_len)]
    out = [0.0] * n_samples
    idx = 0
    prev = 0.0
    for i in range(n_samples):
        val = buf[idx]
        out[i] = val
        # Lowpass filter in loop
        new_val = (val + prev) * 0.5 * decay
        prev = val
        buf[idx] = new_val
        idx = (idx + 1) % delay_len
    return out

def synth_bell(freq, duration, harmonics=((1.0, 1.0, 1.0), (2.76, 0.4, 1.8), (5.4, 0.15, 2.5))):
    """Resonant metallic bell (chime / gold pickup / heal)."""
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    for h_mult, h_amp, decay_rate in harmonics:
        f = freq * h_mult
        d = decay_rate * 4.0 / duration
        phase = 0.0
        dp = 2.0 * math.pi * f / SAMPLE_RATE
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            env = math.exp(-d * t)
            out[i] += math.sin(phase) * h_amp * env
            phase += dp
    return apply_fades(out, 0.003, 0.05)

def synth_shakuhachi_note(freq, duration, vibrato_start=0.2, vibrato_depth=0.015, vibrato_speed=4.5):
    """Shakuhachi / bamboo flute with breath chiff and expressive pitch bend."""
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    phase = 0.0
    # Noise for breath
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    filtered_noise = bandpass_filter(noise, max(800.0, freq * 2.5), 600.0)

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Envelope: soft attack ~50ms, release ~80ms
        if t < 0.05:
            env = t / 0.05
        elif t > duration - 0.08:
            env = max(0.0, (duration - t) / 0.08)
        else:
            env = 1.0

        # Subtle grace note pitch bend at start (starts slightly flat)
        cur_f = freq
        if t < 0.08:
            cur_f *= (0.96 + 0.04 * (t / 0.08))

        # Vibrato
        if t > vibrato_start:
            vib = math.sin(2.0 * math.pi * vibrato_speed * (t - vibrato_start)) * vibrato_depth
            cur_f *= (1.0 + vib)

        dp = 2.0 * math.pi * cur_f / SAMPLE_RATE
        phase += dp

        # Rich woodwind harmonics
        tone = (
            math.sin(phase) * 0.7 +
            math.sin(phase * 2.0) * 0.18 +
            math.sin(phase * 3.0) * 0.12 +
            math.sin(phase * 4.0) * 0.05
        )
        # Breath noise stronger at attack
        breath_env = (1.5 if t < 0.08 else 0.4) * env
        breath = filtered_noise[i] * 0.25 * breath_env

        out[i] = (tone + breath) * env
    return apply_fades(out, 0.01, 0.05)

def synth_taiko(pitch_start, pitch_end, duration, rim=False):
    """Taiko drum hit (punchy attack + low resonant body)."""
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    phase = 0.0
    # Noise for impact click
    click_len = int(0.02 * SAMPLE_RATE)
    click = [random.uniform(-1.0, 1.0) for _ in range(click_len)]
    filtered_click = lowpass_filter(click, 1200.0 if not rim else 3500.0)

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Pitch drop
        drop_factor = math.exp(-35.0 * t) if not rim else math.exp(-50.0 * t)
        cur_f = lerp(pitch_end, pitch_start, drop_factor)
        dp = 2.0 * math.pi * cur_f / SAMPLE_RATE
        phase += dp

        # Amplitude decay
        env = math.exp(-t * (8.0 if not rim else 16.0))
        tone = math.sin(phase) + 0.3 * math.sin(phase * 1.5)
        if rim:
            tone += 0.4 * math.sin(phase * 2.8)

        impact = filtered_click[i] * math.exp(-t * 80.0) if i < click_len else 0.0
        out[i] = (tone * 0.8 + impact * 0.5) * env

    return apply_fades(out, 0.002, 0.03)

# ─────────────────────────────────────────────────────────────
# SFX Generation Functions
# ─────────────────────────────────────────────────────────────

def gen_slash():
    """slash: whoosh สั้น (blade slicing through air)."""
    duration = 0.18
    n_samples = int(duration * SAMPLE_RATE)
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    # Pitch swept bandpass
    out = [0.0] * n_samples
    # Simple swept filter simulation
    for i in range(n_samples):
        norm_t = i / max(1, n_samples)
        # Envelope: rises quickly, smooth decay
        env = max(0.0, math.sin(norm_t * math.pi)) ** 1.8
        out[i] = noise[i] * env

    # Bandpass center sweeps 600 -> 2200 -> 500
    bp = bandpass_filter(out, 1500.0, 1000.0)
    # Add subtle high metallic whistle
    p_metal = 0.0
    for i in range(n_samples):
        norm_t = i / max(1, n_samples)
        dp = 2.0 * math.pi * (1600.0 - 600.0 * norm_t) / SAMPLE_RATE
        p_metal += dp
        bp[i] += math.sin(p_metal) * 0.15 * max(0.0, math.sin(norm_t * math.pi))

    return apply_fades(bp, 0.01, 0.03)

def gen_hit_flesh():
    """hit_flesh: ตุบ (impact on enemy flesh)."""
    duration = 0.20
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    phase = 0.0
    # Noise transient
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    noise_filt = lowpass_filter(noise, 600.0)

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Pitch drops 170 -> 50 Hz
        cur_f = lerp(50.0, 170.0, math.exp(-30.0 * t))
        phase += 2.0 * math.pi * cur_f / SAMPLE_RATE
        body = math.sin(phase) * math.exp(-18.0 * t)
        snap = noise_filt[i] * math.exp(-40.0 * t)
        out[i] = body * 0.8 + snap * 0.5
    return apply_fades(out, 0.002, 0.03)

def gen_hit_player():
    """hit_player: ตุบหนัก+ต่ำ (heavy deep impact on player)."""
    duration = 0.35
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    phase = 0.0
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    noise_filt = lowpass_filter(noise, 400.0)

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Deep sub drop 130 -> 38 Hz
        cur_f = lerp(38.0, 130.0, math.exp(-22.0 * t))
        phase += 2.0 * math.pi * cur_f / SAMPLE_RATE
        # Strong fundamental + sub octave
        sub = math.sin(phase) + 0.4 * math.sin(phase * 0.5)
        env = math.exp(-9.0 * t)
        crack = noise_filt[i] * math.exp(-30.0 * t) * 0.6
        out[i] = (sub + crack) * env
    return apply_fades(out, 0.003, 0.04)

def gen_parry():
    """parry: เหล็กกระทบ ดังกังวาน (steel deflect ping with ringing resonance)."""
    duration = 0.70
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples

    # Clang noise burst
    noise = [random.uniform(-1.0, 1.0) for _ in range(int(0.03 * SAMPLE_RATE))]
    noise_clang = bandpass_filter(noise, 3200.0, 1600.0)
    for i in range(len(noise_clang)):
        out[i] += noise_clang[i] * 0.6 * math.exp(-i / (0.01 * SAMPLE_RATE))

    # Inharmonic blade modes: 2350 Hz, 3620 Hz, 5450 Hz, 7800 Hz
    modes = [
        (2350.0, 0.8, 4.0),
        (3620.0, 0.6, 6.0),
        (5450.0, 0.4, 9.0),
        (7800.0, 0.25, 14.0),
        (1180.0, 0.35, 3.5),
    ]
    for freq, amp, decay_rate in modes:
        phase = 0.0
        dp = 2.0 * math.pi * freq / SAMPLE_RATE
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            env = math.exp(-decay_rate * t)
            out[i] += math.sin(phase) * amp * env
            phase += dp

    return apply_fades(out, 0.002, 0.06)

def gen_dodge():
    """dodge: ลมสั้น (quick airy whoosh)."""
    duration = 0.22
    n_samples = int(duration * SAMPLE_RATE)
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    # Soft swept bandpass around 1200 Hz
    filtered = bandpass_filter(noise, 1200.0, 700.0)
    out = [0.0] * n_samples
    for i in range(n_samples):
        norm_t = i / max(1, n_samples)
        # Smooth arc envelope
        env = max(0.0, math.sin(norm_t * math.pi)) ** 2.0
        out[i] = filtered[i] * env
    return apply_fades(out, 0.01, 0.04)

def gen_enemy_die():
    """enemy_die: หมึกละลาย noise กรองต่ำ (ink dissolving low-pass bubbling noise)."""
    duration = 0.80
    n_samples = int(duration * SAMPLE_RATE)
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    out = [0.0] * n_samples
    p_drone = 0.0

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        norm_t = t / duration
        # Descending pitch drone
        drone_f = lerp(35.0, 85.0, math.exp(-3.0 * t))
        p_drone += 2.0 * math.pi * drone_f / SAMPLE_RATE
        # Bubble / dissipation amplitude modulation
        bub = 0.6 + 0.4 * math.sin(2.0 * math.pi * (20.0 - 10.0 * norm_t) * t)
        env = math.exp(-3.2 * t)
        out[i] = (noise[i] * 0.5 * bub + math.sin(p_drone) * 0.5) * env

    # Filtered lowpass to keep it dark and velvety (ink-like)
    lp = lowpass_filter(out, 350.0)
    return apply_fades(lp, 0.01, 0.08)

def gen_boss_roar():
    """boss_roar: ต่ำ (deep menacing beast rumble / guttural roar)."""
    duration = 1.50
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    p_car = 0.0
    p_mod = 0.0
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    noise_filt = lowpass_filter(noise, 300.0)

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        norm_t = t / duration
        # Envelope: growl ramps up then sustains and falls
        if norm_t < 0.25:
            env = norm_t / 0.25
        else:
            env = max(0.0, (1.0 - norm_t) / 0.75) ** 1.2

        # Low carrier with FM
        f_car = lerp(45.0, 70.0, math.sin(norm_t * math.pi))
        f_mod = 28.0 + 8.0 * math.sin(2.0 * math.pi * 5.0 * t)
        p_mod += 2.0 * math.pi * f_mod / SAMPLE_RATE
        mod_val = math.sin(p_mod) * 3.5

        p_car += 2.0 * math.pi * (f_car + mod_val * 12.0) / SAMPLE_RATE
        roar = math.sin(p_car) + 0.35 * math.sin(p_car * 0.5)
        out[i] = (roar * 0.75 + noise_filt[i] * 0.4) * env

    return apply_fades(out, 0.03, 0.12)

def gen_door_open():
    """door_open: หินลาก (heavy stone dragging sliding open)."""
    duration = 1.00
    n_samples = int(duration * SAMPLE_RATE)
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    out = [0.0] * n_samples

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        norm_t = t / duration
        # Friction grind modulation (rough stone scraping)
        friction = 0.7 + 0.3 * math.sin(2.0 * math.pi * 12.0 * t + math.sin(t * 40.0))
        env = math.sin(norm_t * math.pi) ** 0.8
        out[i] = noise[i] * friction * env

    bp = bandpass_filter(out, 280.0, 240.0)
    return apply_fades(bp, 0.05, 0.10)

def gen_door_close():
    """door_close: หินลาก (heavy stone dragging then solid thud closing)."""
    duration = 1.00
    n_samples = int(duration * SAMPLE_RATE)
    noise = [random.uniform(-1.0, 1.0) for _ in range(n_samples)]
    out = [0.0] * n_samples
    drag_len = int(0.75 * SAMPLE_RATE)

    # Drag portion
    for i in range(drag_len):
        t = i / SAMPLE_RATE
        friction = 0.7 + 0.3 * math.sin(2.0 * math.pi * 14.0 * t)
        env = (i / drag_len) ** 0.5
        out[i] = noise[i] * friction * env * 0.6
    bp = bandpass_filter(out[:drag_len], 300.0, 260.0)
    for i in range(drag_len):
        out[i] = bp[i]

    # Closing slam thud at t=0.75
    p_slam = 0.0
    for i in range(drag_len, n_samples):
        t_slam = (i - drag_len) / SAMPLE_RATE
        cur_f = lerp(45.0, 120.0, math.exp(-28.0 * t_slam))
        p_slam += 2.0 * math.pi * cur_f / SAMPLE_RATE
        env_slam = math.exp(-14.0 * t_slam)
        out[i] = math.sin(p_slam) * 0.9 * env_slam

    return apply_fades(out, 0.04, 0.05)

def gen_heal():
    """heal: ระฆังลมเบา ๆ (gentle wind chimes / peaceful restorative bells)."""
    # Pentatonic serene chimes: E5, G5, A5, B5, E6
    duration = 1.40
    notes = [
        (0.00, 659.25),  # E5
        (0.12, 783.99),  # G5
        (0.25, 880.00),  # A5
        (0.40, 987.77),  # B5
        (0.55, 1318.51), # E6
    ]
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    for start_t, freq in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        rem_dur = duration - start_t
        bell = synth_bell(freq, rem_dur, harmonics=((1.0, 0.7, 1.2), (2.0, 0.25, 1.8), (3.0, 0.1, 2.4)))
        for i, s in enumerate(bell):
            if start_idx + i < n_samples:
                out[start_idx + i] += s * 0.5
    return apply_fades(out, 0.01, 0.08)

def gen_shard_pickup():
    """shard_pickup: กริ๊งทอง (bright golden chime ping)."""
    duration = 0.50
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    # Two swift bright bell tones: A5 (880 Hz) then E6 (1318 Hz)
    bell1 = synth_bell(880.0, 0.45, harmonics=((1.0, 0.8, 1.8), (2.76, 0.35, 2.5)))
    bell2 = synth_bell(1318.5, 0.42, harmonics=((1.0, 0.9, 1.6), (2.76, 0.4, 2.2)))
    idx2 = int(0.07 * SAMPLE_RATE)

    for i in range(len(bell1)):
        if i < n_samples:
            out[i] += bell1[i] * 0.5
    for i in range(len(bell2)):
        if idx2 + i < n_samples:
            out[idx2 + i] += bell2[i] * 0.65

    return apply_fades(out, 0.002, 0.04)

def gen_ui_move():
    """ui_move: soft woodblock / subtle tick."""
    duration = 0.06
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    phase = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        cur_f = 950.0 * math.exp(-40.0 * t)
        phase += 2.0 * math.pi * cur_f / SAMPLE_RATE
        out[i] = math.sin(phase) * math.exp(-65.0 * t)
    return apply_fades(out, 0.002, 0.01)

def gen_ui_confirm():
    """ui_confirm: twin tone warm bell confirmation."""
    duration = 0.22
    b1 = synth_bell(587.33, 0.20, harmonics=((1.0, 0.7, 2.0), (2.0, 0.2, 3.0))) # D5
    b2 = synth_bell(880.00, 0.16, harmonics=((1.0, 0.8, 1.8), (2.0, 0.25, 2.5))) # A5
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    idx2 = int(0.06 * SAMPLE_RATE)
    for i in range(len(b1)):
        if i < n_samples:
            out[i] += b1[i] * 0.55
    for i in range(len(b2)):
        if idx2 + i < n_samples:
            out[idx2 + i] += b2[i] * 0.6
    return apply_fades(out, 0.002, 0.02)

def gen_thud():
    """thud: low screen shake impact (strength >= 0.4)."""
    duration = 0.40
    n_samples = int(duration * SAMPLE_RATE)
    out = [0.0] * n_samples
    phase = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        cur_f = lerp(30.0, 95.0, math.exp(-25.0 * t))
        phase += 2.0 * math.pi * cur_f / SAMPLE_RATE
        sub = math.sin(phase) + 0.3 * math.sin(phase * 0.5)
        out[i] = sub * math.exp(-10.0 * t)
    return apply_fades(out, 0.002, 0.04)

# ─────────────────────────────────────────────────────────────
# Music Generation
# ─────────────────────────────────────────────────────────────

# In / Miyako-bushi scale frequencies on D
# D, Eb, G, A, Bb
NOTES = {
    'D2': 73.42,
    'A2': 110.00,
    'D3': 146.83,
    'Eb3': 155.56,
    'G3': 196.00,
    'A3': 220.00,
    'Bb3': 233.08,
    'D4': 293.66,
    'Eb4': 311.13,
    'G4': 392.00,
    'A4': 440.00,
    'Bb4': 466.16,
    'D5': 587.33,
    'Eb5': 622.25,
    'G5': 783.99,
    'A5': 880.00,
}

def render_seamless_loop(duration, render_func):
    """
    Renders 2 * duration with duplicated pattern into the 2nd loop,
    then extracts the slice [duration, 2 * duration) without folding.
    This ensures that steady-state decays naturally enter the start of the loop
    without doubling notes or energy at the beginning.
    """
    total_dur = 2.0 * duration
    left, right = render_func(total_dur)

    loop_samples = int(duration * SAMPLE_RATE)
    end_samples = int(2.0 * duration * SAMPLE_RATE)

    final_l = left[loop_samples:end_samples]
    final_r = right[loop_samples:end_samples]

    return final_l, final_r

def gen_music_explore():
    """
    music_explore: 16.0s seamless loop.
    Atmosphere: Moonlit Japanese dungeon, meditative koto & shakuhachi, Miyako-bushi scale.
    """
    loop_dur = 16.0

    def render(total_duration):
        n_samples = int(total_duration * SAMPLE_RATE)
        left = [0.0] * n_samples
        right = [0.0] * n_samples

        # 1. Warm temple bowl / ambient drone on D2 (73.4 Hz)
        p_drone = 0.0
        p_drone_5th = 0.0
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            p_drone += 2.0 * math.pi * NOTES['D2'] / SAMPLE_RATE
            p_drone_5th += 2.0 * math.pi * NOTES['A2'] / SAMPLE_RATE
            shimmer = 0.15 * math.sin(2.0 * math.pi * 0.25 * t)
            drone_val = (math.sin(p_drone) * 0.25 + math.sin(p_drone_5th) * 0.12) * (0.85 + shimmer)
            left[i] += drone_val * 0.65
            right[i] += drone_val * 0.65

        # 2. Meditative Koto phrases (plucks spaced across 16 seconds)
        # 4 bars of 4.0s each (tempo 60 bpm)
        koto_score = [
            # Bar 1 (0..4s)
            (0.00, 'D3', 0.8), (1.50, 'A3', 0.6), (2.00, 'D4', 0.7), (3.00, 'Eb4', 0.65), (3.50, 'D4', 0.5),
            # Bar 2 (4..8s)
            (4.00, 'G4', 0.75), (5.00, 'A4', 0.7), (5.50, 'Bb4', 0.65), (6.50, 'A4', 0.6), (7.00, 'G4', 0.55),
            # Bar 3 (8..12s)
            (8.00, 'Eb4', 0.7), (9.00, 'D4', 0.65), (10.00, 'A3', 0.6), (10.75, 'Bb3', 0.55), (11.25, 'A3', 0.5),
            # Bar 4 (12..16s)
            (12.00, 'G3', 0.7), (13.50, 'Eb3', 0.6), (14.50, 'D3', 0.75), (15.25, 'A2', 0.5),
        ]
        # Duplicate pattern into tail if total_duration > 16.0
        extended_score = list(koto_score)
        for t_note, note_name, amp in koto_score:
            if t_note + loop_dur < total_duration:
                extended_score.append((t_note + loop_dur, note_name, amp))

        for t_note, note_name, amp in extended_score:
            start_i = int(t_note * SAMPLE_RATE)
            f = NOTES[note_name]
            note_dur = 2.8
            # Double string Karplus-Strong with slight stereo detuning
            s_l = karplus_strong(f, note_dur, decay=0.988, pluck_brightness=0.75)
            s_r = karplus_strong(f * 1.002, note_dur, decay=0.988, pluck_brightness=0.75)
            for j in range(len(s_l)):
                if start_i + j < n_samples:
                    left[start_i + j] += s_l[j] * amp * 0.45
                    right[start_i + j] += s_r[j] * amp * 0.45

        # 3. Shakuhachi Melodic phrases
        # Long expressive sustained phrases in Bar 2 and Bar 4
        flute_score = [
            # Phrase 1: bar 2
            (4.5, 'D4', 1.8),
            (6.5, 'Eb4', 1.4),
            # Phrase 2: bar 3-4
            (9.5, 'A4', 2.0),
            (11.8, 'G4', 1.6),
            (13.5, 'D4', 2.2),
        ]
        extended_flute = list(flute_score)
        for t_flute, note_name, dur in flute_score:
            if t_flute + loop_dur < total_duration:
                extended_flute.append((t_flute + loop_dur, note_name, dur))

        for t_flute, note_name, dur in extended_flute:
            start_i = int(t_flute * SAMPLE_RATE)
            f = NOTES[note_name]
            flute_samples = synth_shakuhachi_note(f, dur)
            for j, s in enumerate(flute_samples):
                if start_i + j < n_samples:
                    left[start_i + j] += s * 0.35
                    right[start_i + j] += s * 0.35

        return left, right

    final_l, final_r = render_seamless_loop(loop_dur, render)
    return final_l, final_r

def gen_music_combat():
    """
    music_combat: 16.0s seamless loop.
    Atmosphere: Driving Taiko drums, fast aggressive Koto ostinato, high battle whistle.
    Tempo: 120 BPM (1 beat = 0.5s, 1 bar = 2.0s). 8 bars = 16.0s.
    """
    loop_dur = 16.0

    def render(total_duration):
        n_samples = int(total_duration * SAMPLE_RATE)
        left = [0.0] * n_samples
        right = [0.0] * n_samples

        beat_dur = 0.5  # 120 bpm
        total_beats = int(total_duration / beat_dur)

        # 1. Taiko Drum Patterns
        # O-daiko (deep) on beat 0, 2 (beat 1, 3 of bar) and syncopated beat 3.5
        # Shime-daiko (snappy) driving 8th and 16th rhythms
        for beat in range(total_beats):
            t_beat = beat * beat_dur
            bar_beat = beat % 4

            # O-daiko
            if bar_beat in (0, 2):
                hit = synth_taiko(140.0, 48.0, 0.45, rim=False)
                start_i = int(t_beat * SAMPLE_RATE)
                for j, s in enumerate(hit):
                    if start_i + j < n_samples:
                        left[start_i + j] += s * 0.7
                        right[start_i + j] += s * 0.7

            # Syncopated off-beat O-daiko
            if bar_beat == 3:
                t_sub = t_beat + 0.25
                hit = synth_taiko(150.0, 52.0, 0.35, rim=False)
                start_i = int(t_sub * SAMPLE_RATE)
                for j, s in enumerate(hit):
                    if start_i + j < n_samples:
                        left[start_i + j] += s * 0.55
                        right[start_i + j] += s * 0.55

            # Shime-daiko crisp accents (panned slightly left/right)
            for sub_i in (0, 1):
                t_shime = t_beat + sub_i * 0.25
                rim_hit = synth_taiko(220.0, 110.0, 0.18, rim=True)
                start_i = int(t_shime * SAMPLE_RATE)
                pan = 0.7 if sub_i == 0 else 0.3
                for j, s in enumerate(rim_hit):
                    if start_i + j < n_samples:
                        left[start_i + j] += s * 0.4 * pan
                        right[start_i + j] += s * 0.4 * (1.0 - pan)

        # 2. Fast Koto Ostinato (16th-note driving runs)
        # In scale running pattern
        koto_pattern = [
            'D3', 'Eb3', 'G3', 'A3',
            'Bb3', 'A3', 'G3', 'Eb3',
            'D4', 'Eb4', 'D4', 'Bb3',
            'A3', 'G3', 'Eb3', 'D3'
        ]
        step_dur = 0.125  # 16th note at 120 bpm
        total_steps = int(total_duration / step_dur)
        for step in range(total_steps):
            t_step = step * step_dur
            note_name = koto_pattern[step % len(koto_pattern)]
            f = NOTES[note_name]
            koto_note = karplus_strong(f, 0.4, decay=0.965, pluck_brightness=0.85)
            start_i = int(t_step * SAMPLE_RATE)
            pan = 0.4 + 0.2 * math.sin(step)
            for j, s in enumerate(koto_note):
                if start_i + j < n_samples:
                    left[start_i + j] += s * 0.28 * pan
                    right[start_i + j] += s * 0.28 * (1.0 - pan)

        # 3. Piercing Battle Flute Accents (Shinobue style)
        flute_accents = [
            (2.0, 'A5', 0.8),
            (3.0, 'Bb5', 0.6),
            (3.75, 'A5', 0.9),
            (6.0, 'D5', 1.0),
            (7.0, 'Eb5', 0.7),
            (7.5, 'D5', 1.1),
            (10.0, 'A5', 0.8),
            (11.0, 'Bb5', 0.7),
            (11.75, 'A5', 1.0),
            (14.0, 'D5', 1.2),
        ]
        # In NOTES add high octave if needed
        hi_notes = dict(NOTES)
        hi_notes['Bb5'] = 932.33

        extended_accents = list(flute_accents)
        for t_acc, n_name, d_acc in flute_accents:
            if t_acc + loop_dur < total_duration:
                extended_accents.append((t_acc + loop_dur, n_name, d_acc))

        for t_acc, n_name, d_acc in extended_accents:
            start_i = int(t_acc * SAMPLE_RATE)
            f = hi_notes.get(n_name, 880.0)
            flute_s = synth_shakuhachi_note(f, d_acc, vibrato_start=0.08, vibrato_speed=6.0)
            for j, s in enumerate(flute_s):
                if start_i + j < n_samples:
                    left[start_i + j] += s * 0.38
                    right[start_i + j] += s * 0.38

        return left, right

    final_l, final_r = render_seamless_loop(loop_dur, render)
    return final_l, final_r

# ─────────────────────────────────────────────────────────────
# Main Generator Runner
# ─────────────────────────────────────────────────────────────

def main():
    # Target directory defaults to ../sfx relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.abspath(os.path.join(script_dir, "..", "sfx"))
    if len(sys.argv) > 1:
        out_dir = os.path.abspath(sys.argv[1])

    os.makedirs(out_dir, exist_ok=True)
    print(f"Generating audio files into: {out_dir}")

    sfx_generators = [
        ("slash.wav", gen_slash, 1001),
        ("hit_flesh.wav", gen_hit_flesh, 1002),
        ("hit_player.wav", gen_hit_player, 1003),
        ("parry.wav", gen_parry, 1004),
        ("dodge.wav", gen_dodge, 1005),
        ("enemy_die.wav", gen_enemy_die, 1006),
        ("boss_roar.wav", gen_boss_roar, 1007),
        ("door_close.wav", gen_door_close, 1008),
        ("door_open.wav", gen_door_open, 1009),
        ("heal.wav", gen_heal, 1010),
        ("shard_pickup.wav", gen_shard_pickup, 1011),
        ("ui_move.wav", gen_ui_move, 1012),
        ("ui_confirm.wav", gen_ui_confirm, 1013),
        ("thud.wav", gen_thud, 1014),
    ]

    for fname, func, seed_val in sfx_generators:
        random.seed(seed_val)
        path = os.path.join(out_dir, fname)
        print(f"  Synthesizing SFX: {fname}...")
        samples = func()
        save_wav_mono(path, samples)

    music_generators = [
        ("music_explore.wav", gen_music_explore, 2001),
        ("music_combat.wav", gen_music_combat, 2002),
    ]

    for fname, func, seed_val in music_generators:
        random.seed(seed_val)
        path = os.path.join(out_dir, fname)
        print(f"  Synthesizing Music: {fname}...")
        l, r = func()
        save_wav_stereo(path, l, r)

    print("Audio generation complete! All files generated successfully.")

if __name__ == "__main__":
    main()
