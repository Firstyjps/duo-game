// Kitsune Studio: tabs, frame inspector, moveset gallery, concepts and docs.
// Reads the same data the game uses: game/assets/sprites.json + sheet.png and game/js/moves.js.
import { MOVES, ATTACKS } from '../game/js/moves.js';
import { K } from '../game/js/config.js';

const $ = id => document.getElementById(id);

// ---------- tabs (deep-linkable with #inspector, #moves …) ----------
const TABS = ['play', 'inspector', 'moves', 'concepts', 'docs'];
function show(tab) {
  if (!TABS.includes(tab)) tab = 'play';
  document.querySelectorAll('[role=tab]').forEach(b => b.setAttribute('aria-selected', String(b.dataset.tab === tab)));
  document.querySelectorAll('.panel').forEach(p => p.classList.toggle('active', p.dataset.panel === tab));
  if (tab === 'play') $('gameFrame').contentWindow?.focus();
  if (location.hash.slice(1) !== tab) history.replaceState(null, '', '#' + tab);
}
document.querySelectorAll('[role=tab]').forEach(b => b.addEventListener('click', () => show(b.dataset.tab)));
addEventListener('hashchange', () => show(location.hash.slice(1)));
show(location.hash.slice(1));

// ---------- frame inspector ----------
const meta = await fetch('../game/assets/sprites.json').then(r => r.json());
const sheet = await new Promise(ok => { const im = new Image(); im.onload = () => ok(im); im.src = '../game/assets/sheet.png'; });
const cv = $('insp'), g = cv.getContext('2d');
cv.width = cv.height = meta.cell;
g.imageSmoothingEnabled = false;

const NAMES = { idle: 'Idle — ยืนหายใจ', from_idle: 'From idle — ออกตัว', walk: 'Walk cycle — เดิน' };
const st = { anim: 'idle', i: 0, t: 0, playing: true, speed: 1 };
const frames = () => meta.animations[st.anim].frames;

function renderList() {
  $('animList').innerHTML = '';
  for (const [name, a] of Object.entries(meta.animations)) {
    const li = document.createElement('li'), b = document.createElement('button');
    b.type = 'button'; b.setAttribute('aria-pressed', String(name === st.anim));
    b.innerHTML = `<span>${NAMES[name] || name}</span><span class="meta">${a.frames.length}f · ${a.frames[0].duration}ms</span>`;
    b.addEventListener('click', () => { st.anim = name; st.i = 0; st.t = 0; renderList(); sync(); });
    li.append(b); $('animList').append(li);
  }
}
function facts() {
  const a = meta.animations[st.anim], total = a.frames.reduce((s, f) => s + f.duration, 0);
  const rows = [
    ['ไฟล์ต้นทาง', a.source], ['เฟรม (ในไฟล์)', `${a.range[0]}–${a.range[1]}`], ['Canvas เดิม', `${a.size[0]}×${a.size[1]} px`],
    ['ความยาวลูป', `${total} ms (${(1000 * a.frames.length / total).toFixed(1)} fps)`], ['ช่องใน atlas', `${meta.cell}×${meta.cell} px`],
    ['จุดยึดเท้า', `x ${meta.anchor[0]}, y ${meta.anchor[1]}`], ['Hitbox ในเกม', `${K.PW}×${K.PH} px (หมอบ ${K.PH_LOW})`],
  ];
  $('facts').innerHTML = rows.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('');
}
function draw() {
  const c = meta.cell, f = frames(), mirror = $('mirror').checked;
  g.clearRect(0, 0, c, c);
  g.save();
  if (mirror) { g.translate(c, 0); g.scale(-1, 1); }
  const blit = (fr, a) => { g.globalAlpha = a; g.drawImage(sheet, fr.x, fr.y, c, c, 0, 0, c, c); };
  if ($('onion').checked && f.length > 1) blit(f[(st.i - 1 + f.length) % f.length], .28);
  blit(f[st.i], 1);
  g.restore(); g.globalAlpha = 1;
  if ($('guides').checked) {
    const ax = mirror ? c - meta.anchor[0] : meta.anchor[0];
    g.fillStyle = 'rgba(127,245,200,.85)'; g.fillRect(ax - 3, c - 1, 7, 1); g.fillRect(ax, c - 4, 1, 4);
    g.strokeStyle = 'rgba(255,163,3,.7)'; g.lineWidth = 1; g.strokeRect(ax - K.PW / 2 + .5, c - K.PH + .5, K.PW - 1, K.PH - 1);
  }
}
function sync() {
  const f = frames();
  $('scrub').max = f.length - 1; $('scrub').value = st.i;
  $('frameLabel').textContent = `F${String(st.i + 1).padStart(2, '0')} / ${f.length}`;
  $('durLabel').textContent = `${f[st.i].duration}ms`;
  $('play').textContent = st.playing ? '⏸ หยุด' : '▶ เล่น';
  facts(); draw();
}
const stepFrame = d => { st.playing = false; st.i = (st.i + d + frames().length) % frames().length; sync(); };
$('play').addEventListener('click', () => { st.playing = !st.playing; sync(); });
$('prev').addEventListener('click', () => stepFrame(-1));
$('next').addEventListener('click', () => stepFrame(1));
$('scrub').addEventListener('input', e => { st.playing = false; st.i = +e.target.value; sync(); });
['onion', 'guides', 'mirror'].forEach(id => $(id).addEventListener('change', draw));
document.querySelectorAll('[data-speed]').forEach(b => b.addEventListener('click', () => {
  st.speed = +b.dataset.speed; document.querySelectorAll('[data-speed]').forEach(x => x.classList.toggle('on', x === b));
}));
document.querySelectorAll('[data-bg]').forEach(b => b.addEventListener('click', () => {
  $('stagebox').className = 'stagebox bg-' + b.dataset.bg; document.querySelectorAll('[data-bg]').forEach(x => x.classList.toggle('on', x === b));
}));
$('stagebox').classList.add('bg-checker');
addEventListener('keydown', e => {
  if (!document.querySelector('[data-panel=inspector]').classList.contains('active')) return;
  if (e.key === 'ArrowLeft') stepFrame(-1);
  if (e.key === 'ArrowRight') stepFrame(1);
  if (e.key === ' ') { e.preventDefault(); st.playing = !st.playing; sync(); }
});
let last = performance.now();
(function loop(now) {
  const dt = (now - last) * st.speed; last = now;
  if (st.playing) {
    st.t += dt;
    while (st.t >= frames()[st.i].duration) { st.t -= frames()[st.i].duration; st.i = (st.i + 1) % frames().length; sync(); }
  }
  requestAnimationFrame(loop);
})(last);
renderList(); sync();

// ---------- moveset ----------
$('moves').innerHTML = MOVES.map(m => `
  <article class="move">
    <div class="thumb"><img loading="lazy" src="../assets/reference/gifs/${m.ref}" alt="ภาพอ้างอิงท่า ${m.name}"></div>
    <div class="body">
      <h3>${m.name}</h3>
      <div class="input">${m.input}</div>
      <div><span class="tag ${m.source === 'sprite' ? 'real' : 'remix'}">${m.source === 'sprite' ? 'เฟรมจริง' : 'รีมิกซ์'}</span></div>
      <div class="ref">อ้างอิง: ${m.ref}</div>
    </div>
  </article>`).join('');

const PHASE_COL = { antic: '#9EA0FA', smear: '#FFFFFF', active: '#7FF5C8', rec: '#40225F' };
const maxTotal = Math.max(...Object.values(ATTACKS).map(a => a.antic + a.smear + a.active + a.rec));
$('timing').innerHTML = `<thead><tr><th>ท่า</th><th>ง้าง</th><th>Smear</th><th>ปะทะ</th><th>เก็บท่า</th><th>รวม</th><th>ดาเมจ</th><th>สัดส่วนเวลา</th></tr></thead><tbody>` +
  Object.entries(ATTACKS).map(([k, a]) => {
    const total = a.antic + a.smear + a.active + a.rec;
    const seg = ['antic', 'smear', 'active', 'rec'].map(p => `<i style="width:${a[p] / maxTotal * 100}%;background:${PHASE_COL[p]}" title="${p} ${a[p]}ms"></i>`).join('');
    return `<tr><td>${k}</td><td>${a.antic}</td><td>${a.smear || '—'}</td><td>${a.active}</td><td>${a.rec}</td><td>${total}</td><td>${a.dmg}</td><td class="bar"><span class="seg-bar">${seg}</span></td></tr>`;
  }).join('') + '</tbody>';

// ---------- concepts ----------
const CONCEPTS = [
  ['01_oni_ronin.jpg', 'Oni Wandering Ronin', 'ยักษ์สาวซามูไรพเนจร'],
  ['02_tengu_ninja.jpg', 'Tengu Wind Shinobi', 'นินจาการาสุเท็งงูสายลม'],
  ['03_miko_kitsune.jpg', 'Kitsune Shrine Maiden', 'มิโกะจิ้งจอกเก้าหาง'],
  ['04_jade_dragon_states.jpg', 'Jade Dragon Warrior', 'นักรบหยกมังกร (ชีตท่าทาง)'],
  ['05_slime_yokai_states.jpg', 'Slime Yokai Companion', 'สไลม์โยไกตัวช่วย (ชีตท่าทาง)'],
  ['06_oni_ronin_states.jpg', 'Oni Ronin — states', 'ชีตท่าทางของโอนิ'],
];
$('concepts').innerHTML = CONCEPTS.map(([f, en, th]) => `
  <figure class="concept"><a href="../assets/concepts/${f}" target="_blank" rel="noopener"><img loading="lazy" src="../assets/concepts/${f}" alt="${en}"></a>
  <figcaption><b>${en}</b><span>${th}</span></figcaption></figure>`).join('');

// ---------- docs ----------
const DOCS = [
  ['README.md', 'ภาพรวมโปรเจกต์'],
  ['docs/moveset.md', 'ท่าทั้งหมด + วิธีสร้าง'],
  ['docs/character-design-guide.md', 'คู่มือดีไซน์ตัวละคร'],
  ['docs/concepts.md', 'คอนเซปต์ตัวละครใหม่'],
];
async function openDoc(path) {
  document.querySelectorAll('#docList button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.path === path)));
  try {
    const md = await fetch('../' + path).then(r => { if (!r.ok) throw new Error(r.status); return r.text(); });
    const base = new URL('../' + path, location.href);
    const html = window.marked ? window.marked.parse(md) : `<pre>${md.replace(/[&<]/g, c => ({ '&': '&amp;', '<': '&lt;' }[c]))}</pre>`;
    $('doc').innerHTML = html;
    $('doc').querySelectorAll('img[src], a[href]').forEach(el => {          // resolve links relative to the .md file
      const attr = el.tagName === 'IMG' ? 'src' : 'href', v = el.getAttribute(attr);
      if (v && !/^(https?:|#|mailto:)/.test(v)) el.setAttribute(attr, new URL(v, base).href);
    });
  } catch (e) { $('doc').textContent = `เปิดไฟล์ ${path} ไม่ได้ (${e.message})`; }
}
$('docList').innerHTML = DOCS.map(([p, t]) => `<button type="button" data-path="${p}" aria-pressed="false">${t}</button>`).join('');
$('docList').querySelectorAll('button').forEach(b => b.addEventListener('click', () => openDoc(b.dataset.path)));
openDoc(DOCS[0][0]);
