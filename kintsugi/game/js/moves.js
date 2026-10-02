// Move data. ATTACKS drives combat timing; MOVES documents every move for the studio and docs/moveset.md.
//
// Attack phases follow the guide: anticipation → smear → active → recovery (ms).
// Timings come from assets/reference/gif_timing.json: 60ms holds, 20ms×2 smear, 40ms active/recovery frames.
// hb = hitbox [x from feet (forward), y from feet, w, h]. next = what a queued X (or ↑+X) cancels into.
// sound = sfx.js voice played on the smear frame.
export const ATTACKS = {
  slash1:   { antic: 60,  smear: 40, active: 80,  rec: 170, dmg: 1, kb: 120, hb: [2, -48, 44, 46], arc: 'slash1', lunge: 110, sound: 'slash1', next: { x: 'thrust' } },
  thrust:   { antic: 60,  smear: 40, active: 90,  rec: 200, dmg: 1, kb: 140, hb: [4, -32, 64, 20], line: true, lunge: 320, sound: 'slash2', next: { x: 'crescent', up: 'uppercut' } },
  crescent: { antic: 90,  smear: 40, active: 120, rec: 340, dmg: 2, kb: 220, hb: [-30, -46, 82, 46], arc: 'crescent', shock: true, flourish: true, sound: 'slash3' },
  uppercut: { antic: 60,  smear: 40, active: 90,  rec: 200, dmg: 1, kb: 40, launch: 320, hb: [0, -62, 42, 62], arc: 'rising', spark: 'spark-orange', sound: 'slash4', next: { x: 'leap' } },
  leap:     { antic: 50,  smear: 50, active: 90,  rec: 160, dmg: 1, kb: 40, launch: 220, hb: [-6, -70, 46, 66], arc: 'leap', hop: -430, sound: 'slash5', next: { x: 'pillar' } },
  pillar:   { antic: 220, smear: 0,  active: 150, rec: 280, dmg: 3, kb: 240, hb: [-52, -50, 104, 54], dive: 780 },
  air:      { antic: 40,  smear: 40, active: 80,  rec: 120, dmg: 1, kb: 100, hb: [-4, -54, 42, 54], arc: 'air', float: true, sound: 'slash1', pitch: 1.15 },
  plunge:   { antic: 90,  smear: 0,  active: 140, rec: 260, dmg: 2, kb: 200, hb: [-44, -40, 88, 44], dive: 680 },
  counter:  { antic: 30,  smear: 110, active: 90, rec: 220, dmg: 2, kb: 220, hb: [-10, -34, 74, 26], line: true, lunge: 380, sound: 'counter' },
  burst:    { antic: 0,   smear: 0,  active: 180, rec: 320, dmg: 0, kb: 0, hb: [0, 0, 0, 0], sound: false },   // hit resolved in kintsugiBurst()
};

// source: 'sprite' = real frames from the sample pack; 'remix' = built from those frames + transforms + VFX.
// ref = the pack's preview GIF (assets/reference/gifs/) the move was analysed from.
export const MOVES = [
  { id: 'idle',    name: 'ยืนหายใจ',                       input: '—',                          source: 'sprite', ref: 'cover_idle.gif' },
  { id: 'walk',    name: 'ออกตัว + เดิน',                   input: '← →',                        source: 'sprite', ref: 'gallery_01_idle_walk.gif' },
  { id: 'run',     name: 'วิ่ง',                            input: 'Shift + ← →',                source: 'remix',  ref: 'footer_cheer.gif' },
  { id: 'turn',    name: 'เบรกกลับตัว',                     input: 'วิ่งแล้วกดทิศตรงข้าม',        source: 'remix',  ref: 'gallery_07_special_moves.gif' },
  { id: 'crouch',  name: 'หมอบ / คลาน',                     input: '↓',                          source: 'remix',  ref: 'gallery_02_run_actions.gif' },
  { id: 'slide',   name: 'สไลด์',                           input: 'วิ่ง + ↓',                    source: 'remix',  ref: 'gallery_02_run_actions.gif' },
  { id: 'jump',    name: 'กระโดด / ตก / ลงพื้น',             input: 'Space (กดค้าง = สูงขึ้น)',     source: 'remix',  ref: 'gallery_03_jump_actions.gif' },
  { id: 'flip',    name: 'กระโดดตีลังกา (ดับเบิ้ลจัมป์)',       input: 'Space กลางอากาศ',             source: 'remix',  ref: 'gallery_03_jump_actions.gif' },
  { id: 'wall',    name: 'ไถลกำแพง + ถีบกำแพง',             input: 'กระโดดเข้ากำแพง แล้ว Space',   source: 'remix',  ref: 'gallery_05_dodge_attacks.gif' },
  { id: 'ladder',  name: 'ปีนบันได',                         input: '↑ ↓ ที่บันได',                 source: 'remix',  ref: 'gallery_04_attacks.gif' },
  { id: 'roll',    name: 'กลิ้งหลบ (อมตะชั่วครู่)',              input: 'V + ทิศทาง',                        source: 'remix',  ref: 'gallery_06_combos.gif' },
  { id: 'charge',  name: 'ชาร์จพลัง → เสาแสงคินสึงิ',            input: 'กด V ค้าง (ไม่กดทิศ)',          source: 'remix',  ref: 'gallery_03_jump_actions.gif' },
  { id: 'dash',    name: 'พุ่ง / Air Dash',                  input: 'C',                          source: 'remix',  ref: 'body_air_dash.gif' },
  { id: 'combo3',  name: 'คอมโบ 3: ฟันกว้าง → แทง → เสี้ยวจันทร์ต่ำ + เก็บดาบ', input: 'X X X',     source: 'remix',  ref: 'body_basic_3_hit_combo.gif' },
  { id: 'combo5',  name: 'คอมโบ 5: ฟัน → แทง → เสยขึ้น → กระโดดฟัน → ลำแสงหยกดิ่งลง', input: 'X X ↑+X X X', source: 'remix', ref: 'body_5_hit_combo_variation.gif' },
  { id: 'counter', name: 'กลิ้งแล้วฟันสวน',                   input: 'V แล้วกด X ทันที',            source: 'remix',  ref: 'body_dodge_attack_combo.gif' },
  { id: 'air',     name: 'ฟันกลางอากาศ',                     input: 'X กลางอากาศ',                source: 'remix',  ref: 'body_5_hit_combo_variation.gif' },
  { id: 'plunge',  name: 'ปักดาบลงพื้น (6 แฉก)',               input: '↓ + X กลางอากาศ',             source: 'remix',  ref: 'body_dodge_attack_combo.gif' },
  { id: 'land',    name: 'ลงพื้นแรง (ตกสูง)',                  input: 'ตกจากที่สูง',                 source: 'remix',  ref: 'gallery_03_jump_actions.gif' },
  { id: 'hurt',    name: 'โดนตี → ล้ม → ลุก',                 input: 'ชนเงาหมึก',                  source: 'remix',  ref: 'gallery_03_jump_actions.gif' },
  { id: 'power',   name: 'ร่ายพลัง (ฟื้นเลือดเต็ม)',              input: 'จุดโคมเช็กพอยต์ใหม่',           source: 'remix',  ref: 'gallery_03_jump_actions.gif' },
  { id: 'cheer',   name: 'ดีใจเข้าเส้นชัย',                    input: 'ถึงประตูโทริอิ',               source: 'remix',  ref: 'footer_cheer.gif' },
];
