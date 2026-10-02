// Sprite atlas built by tools/build_sprites.py (sheet.png + sprites.json).
// The source art faces LEFT, so drawBody mirrors it to match `face` (+1 = right).

export const sprites = { sheet: null, white: null, ghost: null, meta: null };

const loadImage = src => new Promise((ok, fail) => {
  const im = new Image(); im.onload = () => ok(im); im.onerror = () => fail(new Error('cannot load ' + src)); im.src = src;
});

function tint(img, col) {
  const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
  const g = c.getContext('2d'); g.drawImage(img, 0, 0);
  g.globalCompositeOperation = 'source-in'; g.fillStyle = col; g.fillRect(0, 0, c.width, c.height);
  return c;
}

export async function loadSprites(base = 'assets/') {
  const [sheet, meta] = await Promise.all([
    loadImage(base + 'sheet.png'),
    fetch(base + 'sprites.json').then(r => r.json()),
  ]);
  Object.assign(sprites, { sheet, meta, white: tint(sheet, '#FFFFFF'), ghost: tint(sheet, '#97C0FF') });
}

export const animFrames = name => sprites.meta.animations[name].frames;
export const animLength = name => animFrames(name).length;
export const frameMs = (name, i) => animFrames(name)[i].duration;

/** Pose: { anim, i, rot, spin, ox, oy, sx, sy } — rot leans around the feet, spin turns around the body centre. */
export function drawBody(ctx, img, x, y, face, ps, alpha = 1, comp) {
  const { cell, anchor } = sprites.meta;
  const frames = animFrames(ps.anim), fr = frames[Math.max(0, Math.min(frames.length - 1, ps.i | 0))];
  ctx.save();
  ctx.globalAlpha = alpha;
  if (comp) ctx.globalCompositeOperation = comp;
  ctx.translate(Math.round(x + face * (ps.ox || 0)), Math.round(y + (ps.oy || 0)));
  ctx.scale(face, 1);
  if (ps.spin) { const c = ps.pivot || 22; ctx.translate(0, -c); ctx.rotate(ps.spin); ctx.translate(0, c); }
  ctx.rotate(ps.rot || 0);
  ctx.scale(-(ps.sx ?? 1), ps.sy ?? 1);
  ctx.drawImage(img, fr.x, fr.y, cell, cell, -anchor[0], -anchor[1], cell, cell);
  ctx.restore();
}
