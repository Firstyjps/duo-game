// HD-2D renderer for Kintsugi Run (prototype).
// The game keeps running its own 2D simulation; this draws the world in 3D underneath the
// 2D actor layer. Units: 1 world unit = 1 tile (16 px). Game y points down, world y points up.
// The camera sits above the gameplay plane but uses an off-axis projection (setViewOffset), so
// the z = 0 plane still maps 1:1 onto the 480×270 canvas — the 2D actors line up exactly while
// blocks, ridges and lights get real depth.
(function () {
  'use strict';
  const T = 16, FOV = 30, LIFT = 5, BLOCK_DEPTH = 3, LAYER_GAP = 6;

  const R3D = { on: false, ready: false };
  let K, renderer, scene, camera, composer, cv3, layers = [], props, flies, skyTex, shadowMat;
  let D = 0, offPx = 0, focusZ = 0, focusTarget = 0;

  function texFromCanvas(c, repeat) {
    const t = new THREE.CanvasTexture(c);
    t.magFilter = THREE.NearestFilter; t.minFilter = THREE.NearestFilter; t.generateMipmaps = false;
    if (repeat) { t.wrapS = THREE.RepeatWrapping; t.repeat.set(repeat, 1); }
    return t;
  }
  function pixelTex(w, h, paint) {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    paint(c.getContext('2d'), w, h); return texFromCanvas(c);
  }
  let seed = 11; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;

  // 16×16 textures from the character palette
  function stoneTex(top) {
    return pixelTex(16, 16, (g) => {
      g.fillStyle = top ? '#9EA0FA' : '#1C154D'; g.fillRect(0, 0, 16, 16);
      for (let i = 0; i < 26; i++) { g.fillStyle = top ? (rnd() < .5 ? '#B2B2FF' : '#40225F') : (rnd() < .5 ? '#151037' : '#2F1850'); g.fillRect(rnd() * 16 | 0, rnd() * 16 | 0, 1, 1); }
      if (!top && rnd() < .9) { g.fillStyle = '#FFA303'; let x = 3 + rnd() * 10 | 0; for (let y = 4; y < 13; y++) { g.fillRect(x, y, 1, 1); x += rnd() < .5 ? 1 : -1; } }
    });
  }

  function init() {
    K = window.KR;
    cv3 = document.createElement('canvas'); cv3.id = 'c3d';
    cv3.width = K.W; cv3.height = K.H;
    Object.assign(cv3.style, { position: 'absolute', left: 0, top: 0, imageRendering: 'pixelated', display: 'none' });
    K.canvas.parentNode.insertBefore(cv3, K.canvas);
    K.canvas.style.position = 'relative';
    renderer = new THREE.WebGLRenderer({ canvas: cv3, antialias: false, alpha: false });
    renderer.setPixelRatio(1); renderer.setSize(K.W, K.H, false);
    renderer.outputEncoding = THREE.sRGBEncoding;

    scene = new THREE.Scene();
    skyTex = texFromCanvas(K.sky); skyTex.encoding = THREE.sRGBEncoding;
    scene.background = skyTex;
    scene.fog = new THREE.Fog(0x2F1850, 34, 95);

    camera = new THREE.PerspectiveCamera(FOV, K.W / K.H, 1, 400);
    const halfH = (K.H / T) / 2;
    D = halfH / Math.tan(THREE.MathUtils.degToRad(FOV / 2));
    offPx = LIFT / halfH * (K.H / 2);
    camera.setViewOffset(K.W, K.H, 0, offPx, K.W, K.H);

    scene.add(new THREE.AmbientLight(0x6f62b8, 0.55));
    const moon = new THREE.DirectionalLight(0xfff1cf, 0.75); moon.position.set(-0.6, 1, 0.9); scene.add(moon);
    const rim = new THREE.DirectionalLight(0x97c0ff, 0.25); rim.position.set(0.8, 0.2, -1); scene.add(rim);

    shadowMat = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35, depthWrite: false });

    // post: bloom + tilt-shift band + vignette (falls back to a plain render if the scripts are missing)
    if (THREE.EffectComposer && THREE.UnrealBloomPass) {
      composer = new THREE.EffectComposer(renderer);
      composer.setPixelRatio(1); composer.setSize(K.W, K.H);
      composer.addPass(new THREE.RenderPass(scene, camera));
      composer.addPass(new THREE.UnrealBloomPass(new THREE.Vector2(K.W, K.H), 0.55, 0.6, 0.72));
      composer.addPass(new THREE.ShaderPass({
        uniforms: { tDiffuse: { value: null }, res: { value: new THREE.Vector2(K.W, K.H) } },
        vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
        fragmentShader: `uniform sampler2D tDiffuse; uniform vec2 res; varying vec2 vUv;
          void main(){
            float band = smoothstep(0.30, 0.0, vUv.y) + smoothstep(0.78, 1.0, vUv.y) * 0.8;   // blur the far top + near bottom
            vec4 c = vec4(0.0); float w = 0.0;
            for (int i = -2; i <= 2; i++) for (int j = -2; j <= 2; j++) {
              float k = 1.0 / (1.0 + float(i*i + j*j));
              c += texture2D(tDiffuse, vUv + vec2(float(i), float(j)) * band * 1.2 / res) * k; w += k; }
            c /= w;
            float v = smoothstep(0.95, 0.35, distance(vUv, vec2(0.5)));
            gl_FragColor = vec4(c.rgb * mix(0.72, 1.0, v), 1.0);
          }`,
      }));
    }
    buildBackdrop();
    R3D.ready = true;
    rebuild();
  }

  function buildBackdrop() {
    const span = 400;
    const mk = (canvas, z, y, tint) => {
      const tx = texFromCanvas(canvas, span / 60); tx.encoding = THREE.sRGBEncoding;
      const m = new THREE.Mesh(new THREE.PlaneGeometry(span, canvas.height / T * 2.4),
        new THREE.MeshBasicMaterial({ map: tx, transparent: true, color: tint, fog: true }));
      m.position.set(span / 2 - 40, y, z); scene.add(m);
    };
    mk(K.far, -70, -9, 0xbfb6ff);
    mk(K.mid, -32, -12.5, 0xd9d2ff);
    // fireflies / drifting petals at several depths
    const n = 260, pos = new Float32Array(n * 3), col = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      pos[i * 3] = rnd() * 240 - 10; pos[i * 3 + 1] = -rnd() * 17; pos[i * 3 + 2] = -rnd() * 26 + 3;
      const gold = rnd() < .4; col.set(gold ? [1, .85, .45] : [.75, .75, 1], i * 3);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3)); geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
    flies = new THREE.Points(geo, new THREE.PointsMaterial({ size: 1.6, sizeAttenuation: false, vertexColors: true, transparent: true, opacity: .8, blending: THREE.AdditiveBlending, depthWrite: false }));
    scene.add(flies);

    // mid-ground: pines and stone lanterns between the gameplay plane and the ridges
    const pineMat = new THREE.MeshStandardMaterial({ color: 0x151037, roughness: 1 });
    const trunkMat = new THREE.MeshStandardMaterial({ color: 0x2a1a33, roughness: 1 });
    const cone = new THREE.ConeGeometry(1.4, 4.2, 6), trunk = new THREE.CylinderGeometry(.18, .22, 2.2, 5);
    const pines = new THREE.InstancedMesh(cone, pineMat, 70), trunks = new THREE.InstancedMesh(trunk, trunkMat, 70);
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new THREE.Vector3();
    for (let i = 0; i < 70; i++) {
      const x = i * 3.4 + rnd() * 2, z = -13 - rnd() * 10, k = .7 + rnd() * .7, base = -14.2;
      sc.set(k, k, k); m4.compose(new THREE.Vector3(x, base + 1.1 * k + 2.1 * k, z), q, sc); pines.setMatrixAt(i, m4);
      m4.compose(new THREE.Vector3(x, base + 1.1 * k, z), q, sc); trunks.setMatrixAt(i, m4);
    }
    scene.add(pines, trunks);
    // foreground: dark grass blades right in front of the lens (blurred by the tilt-shift band)
    const blade = new THREE.PlaneGeometry(.18, 1.6);
    const fg = new THREE.InstancedMesh(blade, new THREE.MeshBasicMaterial({ color: 0x07060f, side: THREE.DoubleSide, fog: false }), 420);
    for (let i = 0; i < 420; i++) {
      const k = .5 + rnd() * 1.4, x = rnd() * 240 - 10, z = 4 + rnd() * 3;
      q.setFromAxisAngle(new THREE.Vector3(0, 0, 1), (rnd() - .5) * .5); sc.set(1, k, 1);
      m4.compose(new THREE.Vector3(x, -16.6 + .8 * k, z), q, sc); fg.setMatrixAt(i, m4);
    }
    scene.add(fg);
  }

  function buildLayer(grid, lv, z) {
    const group = new THREE.Group(); group.position.z = z;
    const ROWS = grid.length, COLS = grid[0].length;
    const solidAt = (x, y) => x < 0 || x >= COLS ? true : y < 0 || y >= ROWS ? false : grid[y][x] === 1;
    // front face = the game's own pre-rendered tile art, lit by the scene
    const ft = texFromCanvas(lv); ft.encoding = THREE.sRGBEncoding;
    const front = new THREE.Mesh(new THREE.PlaneGeometry(COLS, ROWS),
      new THREE.MeshStandardMaterial({ map: ft, transparent: true, alphaTest: 0.5, roughness: 1, metalness: 0 }));
    front.position.set(COLS / 2, -ROWS / 2, 0); group.add(front);
    // extruded blocks behind the face (only tiles with an exposed side)
    const exposed = [];
    for (let y = 0; y < ROWS; y++) for (let x = 0; x < COLS; x++)
      if (grid[y][x] === 1 && (!solidAt(x, y - 1) || !solidAt(x - 1, y) || !solidAt(x + 1, y) || !solidAt(x, y + 1))) exposed.push([x, y]);
    const stone = new THREE.MeshStandardMaterial({ map: stoneTex(false), roughness: 1, transparent: true });
    const moss = new THREE.MeshStandardMaterial({ map: stoneTex(true), roughness: 1, transparent: true });
    const box = new THREE.BoxGeometry(1, 1, BLOCK_DEPTH);
    const blocks = new THREE.InstancedMesh(box, [stone, stone, moss, stone, stone, stone], exposed.length);
    const m4 = new THREE.Matrix4();
    exposed.forEach(([x, y], i) => { m4.makeTranslation(x + .5, -y - .5, -BLOCK_DEPTH / 2 - 0.01); blocks.setMatrixAt(i, m4); });
    group.add(blocks);
    // spikes get real cones along the depth
    const spikes = [];
    for (let y = 0; y < ROWS; y++) for (let x = 0; x < COLS; x++) if (grid[y][x] === 2) spikes.push([x, y]);
    if (spikes.length) {
      const cone = new THREE.ConeGeometry(.16, .55, 4);
      const cm = new THREE.InstancedMesh(cone, new THREE.MeshStandardMaterial({ color: 0x9ea0fa, roughness: .5, metalness: .2 }), spikes.length * 6);
      let i = 0; spikes.forEach(([x, y]) => { for (let k = 0; k < 6; k++) { m4.makeTranslation(x + .25 + (k % 2) * .5, -y - .72, -.3 - Math.floor(k / 2) * .9); cm.setMatrixAt(i++, m4); } });
      group.add(cm);
    }
    // enclosed layers (caves) get a rock back wall behind their open space
    const mats = [front.material, stone, moss];
    if (z < 0) {
      let x0 = COLS, x1 = 0, y0 = ROWS, y1 = 0;
      for (let y = 0; y < ROWS; y++) for (let x = 0; x < COLS; x++) if (grid[y][x] === 1) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
      const wt = stoneTex(false); wt.wrapS = wt.wrapT = THREE.RepeatWrapping; wt.repeat.set(x1 - x0 + 1, y1 - y0 + 1);
      const wallMat = new THREE.MeshStandardMaterial({ map: wt, color: 0x3c3566, roughness: 1, transparent: true });
      const wall = new THREE.Mesh(new THREE.PlaneGeometry(x1 - x0 + 1, y1 - y0 + 1), wallMat);
      wall.position.set((x0 + x1 + 1) / 2, -(y0 + y1 + 1) / 2, -BLOCK_DEPTH + .05); group.add(wall); mats.push(wallMat);
      const torch = new THREE.PointLight(0xffa303, 1.4, 10, 2); torch.position.set((x0 + x1) / 2, -(y0 + y1) / 2 + 1, -1); group.add(torch);
    }
    scene.add(group);
    return { group, front, ft, mats };
  }

  function rebuild() {
    if (!R3D.ready) return;
    layers.forEach(l => scene.remove(l.group)); layers = [];
    if (props) scene.remove(props);
    const ls = K.layers();
    ls.forEach((l, i) => layers.push(buildLayer(l.grid, l.lv, -LAYER_GAP * i)));
    focusZ = focusTarget = -LAYER_GAP * K.activeLayer();
    // light sources: lanterns, the torii, a soft moon glow
    props = new THREE.Group();
    const glow = (x, y, color, power, size) => {
      const L = new THREE.PointLight(color, power, 9, 2); L.position.set(x, y, 1.2); props.add(L);
      const orb = new THREE.Mesh(new THREE.SphereGeometry(size, 8, 6), new THREE.MeshBasicMaterial({ color }));
      orb.position.set(x, y, -0.2); props.add(orb);
    };
    K.checkpoints().forEach(c => glow(c.x / T, -(c.y - 26) / T, 0xff7a3d, 1.6, .16));
    const g = K.goal(); glow(g.x / T + 1.6, -(g.y - 60) / T, 0xffd27a, 2.2, .2);
    scene.add(props);
  }

  function frame(cx, cy) {
    if (!R3D.ready) return;
    focusZ += (focusTarget - focusZ) * 0.12;                 // dolly between depth layers
    layers.forEach((l, i) => {                                 // a layer between the lens and the player turns to glass
      const between = -LAYER_GAP * i > focusZ + 0.5, a = between ? 0.18 : 1;
      l.mats.forEach(m => { m.opacity = a; m.depthWrite = !between; });
    });
    const x = (cx + K.W / 2) / T, y = -(cy + K.H / 2) / T;
    camera.position.set(x, y + LIFT, focusZ + D);
    camera.lookAt(x, y + LIFT, focusZ);
    const t = performance.now() / 1000;
    flies.position.x = Math.sin(t * .2) * .6; flies.position.y = Math.sin(t * .37) * .3;
    if (composer) composer.render(); else renderer.render(scene, camera);
  }

  R3D.setLayer = (active) => { focusTarget = -LAYER_GAP * active; };
  R3D.toggle = (on) => {
    R3D.on = on; if (on && !R3D.ready) init();
    if (cv3) cv3.style.display = on ? 'block' : 'none';
  };
  R3D.fit = (w, h) => { if (cv3) { cv3.style.width = w; cv3.style.height = h; } };
  R3D.rebuild = rebuild;
  R3D.frame = frame;
  window.R3D = R3D;
})();
