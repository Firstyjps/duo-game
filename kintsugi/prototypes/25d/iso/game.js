/**
 * Kintsugi Run - Isometric Prototype (Temple Courtyard Diorama)
 * Conforms to TASK.md and WORKER_SPEC_COMMON.md
 */
(function() {
  'use strict';

  // ==========================================
  // 1. PALETTE & CONSTANTS
  // ==========================================
  const PAL = {
    navy: 0x1C154D,
    navyDark: 0x151037,
    ink: 0x0F121B,
    royal: 0x0321BC,
    lilac: 0xB2B2FF,
    lilacDark: 0x9EA0FA,
    plum: 0x40225F,
    plumDark: 0x2F1850,
    gold: 0xFFA303,
    goldHi: 0xFFFFCC,
    goldDark: 0xE05E2B,
    rust: 0xA64B0A,
    red: 0xFF0E00,
    crimson: 0x882323,
    wood: 0x4D2F1E,
    ice: 0x97C0FF
  };

  const W = 480, H = 270;
  const CHAR_H = 1.75;                       // sprite quad (64 px cell incl. margins) → body ~46 px on screen
  const CAM_H = 7.36;                        // world units visible vertically (kept from the original framing)
  const CAM_W = CAM_H * (W / H);             // ~13.0909
  const CAM_DIST = 35; // Dist along (1, 1, 1) for true isometric view

  // Screen direction unit vectors in world XZ
  // Cam looks from (+D, +D, +D) -> (0,0,0)
  // Screen Right = ( 1, 0, -1) / sqrt(2)
  // Screen Up    = (-1, 0, -1) / sqrt(2)
  const SCR_R = new THREE.Vector3( 1 / Math.SQRT2, 0, -1 / Math.SQRT2);
  const SCR_L = new THREE.Vector3(-1 / Math.SQRT2, 0,  1 / Math.SQRT2);
  const SCR_U = new THREE.Vector3(-1 / Math.SQRT2, 0, -1 / Math.SQRT2);
  const SCR_D = new THREE.Vector3( 1 / Math.SQRT2, 0,  1 / Math.SQRT2);

  // ==========================================
  // 2. PROCEDURAL TEXTURES
  // ==========================================
  function createPixelTexture(w, h, drawFn) {
    const cv = document.createElement('canvas');
    cv.width = w; cv.height = h;
    const ctx = cv.getContext('2d');
    drawFn(ctx, w, h);
    const tex = new THREE.CanvasTexture(cv);
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestFilter;
    tex.generateMipmaps = false;
    return tex;
  }

  // Stone floor with golden kintsugi cracks
  function createStoneKintsugiTex(variant) {
    return createPixelTexture(32, 32, (ctx) => {
      // Base dark stone slate
      ctx.fillStyle = variant === 1 ? '#151037' : (variant === 2 ? '#1C154D' : '#2F1850');
      ctx.fillRect(0, 0, 32, 32);

      // Noise speckles
      for (let i = 0; i < 48; i++) {
        const x = Math.floor(Math.random() * 32);
        const y = Math.floor(Math.random() * 32);
        ctx.fillStyle = Math.random() < 0.5 ? '#151037' : '#40225F';
        ctx.fillRect(x, y, 1, 1);
      }

      // Stone border line
      ctx.strokeStyle = '#0F121B';
      ctx.lineWidth = 1;
      ctx.strokeRect(0.5, 0.5, 31, 31);

      // Gold kintsugi cracks (winding organic veins)
      ctx.fillStyle = '#FFA303';
      if (variant === 1) return;              // plain slabs between the cracked ones
      let cx = (variant * 7 + 5) % 28 + 2;
      let cy = 6 + Math.floor(Math.random() * 10);
      const cyEnd = cy + 9 + Math.floor(Math.random() * 6);
      while (cy < Math.min(32, cyEnd)) {
        ctx.fillRect(cx, cy, 1, 1);
        if (Math.random() < 0.12) {
          ctx.fillStyle = '#FFFFCC'; // gold highlight
          ctx.fillRect(cx + (Math.random() < 0.5 ? 1 : -1), cy, 1, 1);
          ctx.fillStyle = '#FFA303';
        }
        if (Math.random() < 0.1) {
          // branch crack
          const bx = cx + (Math.random() < 0.5 ? 2 : -2);
          ctx.fillRect(bx, cy, 1, 1);
        }
        cx += Math.random() < 0.5 ? 1 : (Math.random() < 0.5 ? -1 : 0);
        cx = Math.max(1, Math.min(30, cx));
        cy += 1;
      }
    });
  }

  // Shimmering pond water texture
  function createWaterTex() {
    return createPixelTexture(32, 32, (ctx) => {
      ctx.fillStyle = '#0321BC';
      ctx.fillRect(0, 0, 32, 32);
      // Ripple lines
      ctx.fillStyle = '#97C0FF';
      for (let y = 3; y < 32; y += 6) {
        for (let x = 0; x < 32; x += 4) {
          if ((x + y) % 8 === 0) {
            ctx.fillRect(x, y, 3, 1);
          }
        }
      }
      ctx.fillStyle = '#B2B2FF';
      for (let y = 6; y < 32; y += 6) {
        for (let x = 2; x < 32; x += 4) {
          if ((x + y) % 6 === 0) {
            ctx.fillRect(x, y, 2, 1);
          }
        }
      }
    });
  }

  // Dark Japanese temple roof tile texture
  function createRoofTex() {
    return createPixelTexture(32, 32, (ctx) => {
      ctx.fillStyle = '#151037';
      ctx.fillRect(0, 0, 32, 32);
      // Horizontal overlapping curved tile rows
      for (let y = 0; y < 32; y += 4) {
        ctx.fillStyle = '#2F1850';
        ctx.fillRect(0, y, 32, 1);
        ctx.fillStyle = '#0F121B';
        ctx.fillRect(0, y + 1, 32, 1);
        ctx.fillStyle = '#40225F';
        for (let x = 0; x < 32; x += 4) {
          ctx.fillRect(x, y + 2, 2, 2);
        }
      }
    });
  }

  // Wood texture
  function createWoodTex() {
    return createPixelTexture(16, 16, (ctx) => {
      ctx.fillStyle = '#4D2F1E';
      ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = '#2A1A12';
      for (let y = 0; y < 16; y += 3) {
        ctx.fillRect(0, y, 16, 1);
      }
    });
  }

  // Crescent sword slash arc texture (white core -> #97C0FF -> #0321BC)
  function createCrescentSlashTex() {
    return createPixelTexture(64, 64, (ctx) => {
      ctx.clearRect(0, 0, 64, 64);
      const cx = 32, cy = 32, r = 24;

      // Outer glow (royal blue)
      ctx.strokeStyle = '#0321BC';
      ctx.lineWidth = 9;
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI * 0.7, Math.PI * 0.2);
      ctx.stroke();

      // Mid glow (ice blue)
      ctx.strokeStyle = '#97C0FF';
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI * 0.65, Math.PI * 0.15);
      ctx.stroke();

      // Sharp white core
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI * 0.6, Math.PI * 0.1);
      ctx.stroke();
    });
  }

  // Contact shadow texture (dark ellipse)
  function createShadowTex() {
    return createPixelTexture(32, 32, (ctx) => {
      ctx.clearRect(0, 0, 32, 32);
      const rad = ctx.createRadialGradient(16, 16, 2, 16, 16, 15);
      rad.addColorStop(0, 'rgba(0, 0, 0, 0.7)');
      rad.addColorStop(0.6, 'rgba(0, 0, 0, 0.4)');
      rad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = rad;
      ctx.beginPath();
      ctx.arc(16, 16, 15, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  // Procedural Ink Shade Enemy sprite sheet (128x32: 4 frames of 32x32)
  // Frame 0: Idle A, Frame 1: Idle B, Frame 2: Aggro/Lunge, Frame 3: Hit Flash (White)
  function createInkShadeTex() {
    return createPixelTexture(128, 32, (ctx) => {
      ctx.clearRect(0, 0, 128, 32);

      function drawBlob(ox, wobble, eyeSpread, isFlash) {
        ctx.fillStyle = isFlash ? '#FFFFFF' : '#1C154D';
        // Main rounded ghost body
        ctx.beginPath();
        ctx.arc(ox + 16, 14 + wobble, 10, Math.PI, 0, false);
        ctx.lineTo(ox + 26, 25 + wobble);
        // Dripping wispy ink tendrils
        ctx.lineTo(ox + 22, 22 + wobble);
        ctx.lineTo(ox + 18, 26 + wobble);
        ctx.lineTo(ox + 14, 21 + wobble);
        ctx.lineTo(ox + 10, 25 + wobble);
        ctx.lineTo(ox + 6, 22 + wobble);
        ctx.closePath();
        ctx.fill();

        if (!isFlash) {
          // Plum inner shadow
          ctx.fillStyle = '#40225F';
          ctx.beginPath();
          ctx.arc(ox + 16, 15 + wobble, 7, 0, Math.PI);
          ctx.fill();
        }

        // Glowing lilac eyes
        ctx.fillStyle = isFlash ? '#B2B2FF' : '#FFFFCC';
        ctx.fillRect(ox + 16 - eyeSpread - 1, 12 + wobble, 2, 3);
        ctx.fillRect(ox + 16 + eyeSpread - 1, 12 + wobble, 2, 3);
        // Lilac outer glow
        ctx.fillStyle = '#B2B2FF';
        ctx.fillRect(ox + 16 - eyeSpread - 2, 13 + wobble, 1, 1);
        ctx.fillRect(ox + 16 + eyeSpread + 1, 13 + wobble, 1, 1);
      }

      // Frame 0: Idle A
      drawBlob(0, 0, 3, false);
      // Frame 1: Idle B
      drawBlob(32, -1, 3.5, false);
      // Frame 2: Aggro / Lunge
      drawBlob(64, 1, 4, false);
      // Frame 3: Hurt / Hit-flash
      drawBlob(96, 0, 3, true);
    });
  }

  // ==========================================
  // 3. THREE.JS SCENE SETUP
  // ==========================================
  const canvas = document.getElementById('c');
  const renderer = new THREE.WebGLRenderer({
    canvas: canvas,
    antialias: false,
    alpha: false,
    powerPreference: 'high-performance'
  });
  renderer.setPixelRatio(1);
  renderer.setSize(W, H, false);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputEncoding = THREE.sRGBEncoding;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(PAL.ink);
  scene.fog = new THREE.Fog(0x1a1438, 62, 95);   // linear, measured from the iso camera (~60 units away)

  // Orthographic true isometric camera
  const camera = new THREE.OrthographicCamera(
    -CAM_W / 2, CAM_W / 2,
    CAM_H / 2, -CAM_H / 2,
    -100, 100
  );
  const camTarget = new THREE.Vector3(8, 0, 8);
  camera.position.set(camTarget.x + CAM_DIST, camTarget.y + CAM_DIST, camTarget.z + CAM_DIST);
  camera.lookAt(camTarget);

  // Responsive canvas CSS scaling
  function resizeCanvas() {
    const scale = Math.max(1, Math.min(
      Math.floor((window.innerWidth / W) * 2) / 2,
      Math.floor((window.innerHeight / H) * 2) / 2
    ));
    canvas.style.width = (W * scale) + 'px';
    canvas.style.height = (H * scale) + 'px';
  }
  window.addEventListener('resize', resizeCanvas);
  resizeCanvas();

  // ==========================================
  // 4. LIGHTING & ATMOSPHERE
  // ==========================================
  // Ambient moonlight
  const ambientLight = new THREE.AmbientLight(0x6a5fb0, 0.75);
  scene.add(ambientLight);
  scene.add(new THREE.HemisphereLight(0x9ea0fa, 0x1c154d, 0.45));

  // Directional moonlight casting soft shadows
  const moonLight = new THREE.DirectionalLight(0xE6E8FF, 1.25);
  moonLight.position.set(22, 28, 14);
  moonLight.castShadow = true;
  moonLight.shadow.mapSize.width = 1024;
  moonLight.shadow.mapSize.height = 1024;
  moonLight.shadow.camera.near = 1;
  moonLight.shadow.camera.far = 70;
  moonLight.shadow.camera.left = -15;
  moonLight.shadow.camera.right = 15;
  moonLight.shadow.camera.top = 15;
  moonLight.shadow.camera.bottom = -15;
  moonLight.shadow.bias = -0.001;
  scene.add(moonLight);

  // Secondary lilac rim light
  const rimLight = new THREE.DirectionalLight(PAL.lilac, 0.3);
  rimLight.position.set(-15, 12, -15);
  scene.add(rimLight);

  // ==========================================
  // 5. WORLD DIORAMA (16×16 TILES)
  // ==========================================
  // Grid coordinates: 0..15 x 0..15
  // Height levels: 0 (0.0), 1 (0.5), 2 (1.0), 3 (1.5)
  const GRID_SIZE = 16;
  const tileHeight = [];
  const tileSolid = [];
  const ramps = []; // { x, z, dir: 'x+'|'x-'|'z+'|'z-', from, to }

  for (let z = 0; z < GRID_SIZE; z++) {
    tileHeight[z] = [];
    tileSolid[z] = [];
    for (let x = 0; x < GRID_SIZE; x++) {
      tileHeight[z][x] = 0.0;
      tileSolid[z][x] = false;
    }
  }

  // Stone Materials
  const stoneTex1 = createStoneKintsugiTex(1);
  const stoneTex2 = createStoneKintsugiTex(2);
  const stoneTex3 = createStoneKintsugiTex(3);
  const stoneMats = [
    new THREE.MeshStandardMaterial({ map: stoneTex1, roughness: 0.9, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: stoneTex2, roughness: 0.9, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: stoneTex3, roughness: 0.9, metalness: 0.1 })
  ];
  const woodMat = new THREE.MeshStandardMaterial({ map: createWoodTex(), roughness: 0.8 });
  const roofMat = new THREE.MeshStandardMaterial({ map: createRoofTex(), roughness: 0.7 });
  const goldMat = new THREE.MeshStandardMaterial({
    color: PAL.gold,
    emissive: 0x663300,
    roughness: 0.3,
    metalness: 0.8
  });
  const toriiMat = new THREE.MeshStandardMaterial({
    color: PAL.red,
    roughness: 0.6,
    metalness: 0.1
  });
  const waterMat = new THREE.MeshStandardMaterial({
    map: createWaterTex(),
    color: PAL.royal,
    roughness: 0.2,
    metalness: 0.3,
    transparent: true,
    opacity: 0.82
  });

  const occludingObjects = []; // Meshes to test for camera-to-player occlusion

  // 1) Define Height Levels on Grid
  // North-West Shrine Compound
  // Terrace Level 1
  for (let z = 4; z <= 6; z++) {
    for (let x = 1; x <= 6; x++) {
      tileHeight[z][x] = 0.5;
    }
  }
  // Shrine Platform Level 2
  for (let z = 1; z <= 4; z++) {
    for (let x = 1; x <= 5; x++) {
      tileHeight[z][x] = 1.0;
    }
  }
  // Behind shrine secret ledge (Level 1)
  tileHeight[1][2] = 0.5;
  tileHeight[1][3] = 0.5;
  tileHeight[1][4] = 0.5;

  // Shrine Sanctuary Level 3
  for (let z = 2; z <= 3; z++) {
    for (let x = 2; x <= 4; x++) {
      tileHeight[z][x] = 1.5;
      tileSolid[z][x] = true; // shrine building interior is solid
    }
  }

  // South-West High Overlook
  // Level 1 terrace
  for (let z = 9; z <= 12; z++) {
    for (let x = 1; x <= 4; x++) {
      tileHeight[z][x] = 0.5;
    }
  }
  // Level 2 overlook
  for (let z = 11; z <= 13; z++) {
    for (let x = 1; x <= 3; x++) {
      tileHeight[z][x] = 1.0;
    }
  }
  // Level 3 observation dais
  tileHeight[13][1] = 1.5;
  tileHeight[12][1] = 1.5;

  // East Terrace (Level 1)
  for (let z = 8; z <= 11; z++) {
    for (let x = 13; x <= 14; x++) {
      tileHeight[z][x] = 0.5;
    }
  }

  // Pond Area (Sunken)
  const isPondTile = (x, z) => (x >= 11 && x <= 14 && z >= 3 && z <= 7);

  // Stepping stones in pond
  const steppingStones = [
    { x: 12, z: 5, h: 0.1 },
    { x: 13, z: 6, h: 0.1 }
  ];

  // 2) Define Ramps (Stairs)
  // Ramp 1: Shrine entrance (from Level 0 to Level 1)
  ramps.push({ x: 5, z: 7, dir: 'z-', from: 0.0, to: 0.5 });
  // Ramp 2: Shrine terrace to platform (from Level 1 to Level 2)
  ramps.push({ x: 4, z: 5, dir: 'z-', from: 0.5, to: 1.0 });
  // Ramp 3: Southwest terrace (from Level 0 to Level 1)
  ramps.push({ x: 5, z: 10, dir: 'x-', from: 0.0, to: 0.5 });
  // Ramp 4: Southwest overlook (from Level 1 to Level 2)
  ramps.push({ x: 2, z: 10, dir: 'z+', from: 0.5, to: 1.0 });
  // Ramp 5: East terrace (from Level 0 to Level 1)
  ramps.push({ x: 12, z: 10, dir: 'x+', from: 0.0, to: 0.5 });

  // Helper to query ground height at world (x, z)
  function getGroundHeight(x, z) {
    const gx = Math.floor(x);
    const gz = Math.floor(z);
    if (gx < 0 || gx >= GRID_SIZE || gz < 0 || gz >= GRID_SIZE) return 0;

    // Check stepping stones
    for (let i = 0; i < steppingStones.length; i++) {
      const st = steppingStones[i];
      if (Math.hypot(x - (st.x + 0.5), z - (st.z + 0.5)) < 0.45) {
        return st.h;
      }
    }

    // Check ramps
    for (let i = 0; i < ramps.length; i++) {
      const r = ramps[i];
      if (gx === r.x && gz === r.z) {
        const fx = x - gx;
        const fz = z - gz;
        let t = 0;
        if (r.dir === 'z-') t = 1 - fz;
        else if (r.dir === 'z+') t = fz;
        else if (r.dir === 'x-') t = 1 - fx;
        else if (r.dir === 'x+') t = fx;
        t = Math.max(0, Math.min(1, t));
        return r.from + t * (r.to - r.from);
      }
    }

    if (isPondTile(gx, gz)) {
      return -0.2; // Sunken pond bed
    }

    return tileHeight[gz][gx];
  }

  // Helper to test if moving to (nx, nz) with current playerY is blocked
  function canMoveTo(nx, nz, currentY, isGrounded) {
    // Courtyard boundaries
    if (nx < 0.8 || nx > 15.2 || nz < 0.8 || nz > 15.2) return false;
    const gx = Math.floor(nx);
    const gz = Math.floor(gzSafe(nz));

    // Solid tile (e.g. shrine sanctuary)
    if (tileSolid[gz] && tileSolid[gz][gx]) return false;

    // Pond deep water (cannot walk directly into water without stepping stones)
    if (isPondTile(gx, gz)) {
      let onStone = false;
      for (let i = 0; i < steppingStones.length; i++) {
        const st = steppingStones[i];
        if (Math.hypot(nx - (st.x + 0.5), nz - (st.z + 0.5)) < 0.45) {
          onStone = true; break;
        }
      }
      if (!onStone) return false; // blocked by water
    }

    // Height step check:
    const targetH = getGroundHeight(nx, nz);
    const stepUp = targetH - currentY;
    if (isGrounded) {
      // Grounded: "can walk up stairs, can't walk up >0.5 tile ledges without jumping"
      if (stepUp > 0.52) return false;
    } else {
      // Airborne: cannot pass through the side of a tall block if player's feet are below ledge
      if (currentY < targetH - 0.15) return false;
    }

    return true;
  }
  function gzSafe(z) { return Math.max(0, Math.min(GRID_SIZE - 1, Math.floor(z))); }

  // 3) Build 3D Courtyard Meshes
  const worldGroup = new THREE.Group();
  scene.add(worldGroup);

  // Ground blocks
  const boxGeoCache = {};
  function getBoxGeo(w, h, d) {
    const k = `${w}_${h}_${d}`;
    if (!boxGeoCache[k]) boxGeoCache[k] = new THREE.BoxGeometry(w, h, d);
    return boxGeoCache[k];
  }

  for (let z = 0; z < GRID_SIZE; z++) {
    for (let x = 0; x < GRID_SIZE; x++) {
      if (isPondTile(x, z)) continue; // Pond created separately

      const isRamp = ramps.some(r => r.x === x && r.z === z);
      if (isRamp) {
        // Build ramp wedge / stairs
        const r = ramps.find(r => r.x === x && r.z === z);
        const rampGroup = new THREE.Group();
        rampGroup.position.set(x + 0.5, 0, z + 0.5);

        // Subdivided steps for stair look
        const steps = 4;
        const hStep = (r.to - r.from) / steps;
        for (let s = 0; s < steps; s++) {
          const sh = r.from + (s + 1) * hStep;
          const sw = 1.0 / steps;
          const stepMesh = new THREE.Mesh(getBoxGeo(1.0, sh, sw), stoneMats[(x + z) % 3]);
          stepMesh.castShadow = true;
          stepMesh.receiveShadow = true;
          let offsetZ = (s - steps / 2 + 0.5) * sw;
          if (r.dir === 'z-') offsetZ = -offsetZ;
          stepMesh.position.set(0, sh / 2, offsetZ);
          rampGroup.add(stepMesh);
        }
        worldGroup.add(rampGroup);
        continue;
      }

      const h = tileHeight[z][x];
      const totalH = Math.max(0.4, h + 0.4);
      const mesh = new THREE.Mesh(getBoxGeo(1.0, totalH, 1.0), stoneMats[(x + z) % 3]);
      mesh.position.set(x + 0.5, h - totalH / 2 + 0.001, z + 0.5);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      worldGroup.add(mesh);

      // Track occluding blocks (tall blocks inside the courtyard)
      if (h >= 1.0) {
        occludingObjects.push(mesh);
      }
    }
  }

  // Pond basin and shimmering water plane
  const pondWater = new THREE.Mesh(new THREE.PlaneGeometry(4.0, 5.0), waterMat);
  pondWater.rotation.x = -Math.PI / 2;
  pondWater.position.set(13.0, -0.05, 5.5);
  worldGroup.add(pondWater);

  // Stepping stones
  steppingStones.forEach(st => {
    const cyl = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.4, 0.35, 8), stoneMats[0]);
    cyl.position.set(st.x + 0.5, st.h - 0.1, st.z + 0.5);
    cyl.castShadow = true;
    cyl.receiveShadow = true;
    worldGroup.add(cyl);
  });

  // Perimeter Courtyard Walls:
  // North & West: tall traditional Japanese backdrop walls
  // South & East: low stone borders so isometric camera view is unobstructed
  const wallMat = new THREE.MeshStandardMaterial({ color: PAL.plumDark, roughness: 0.95 });
  const wallTileMat = roofMat;

  function addWallSegment(x, z, w, d) {
    const wallH = 1.8;
    const wall = new THREE.Mesh(getBoxGeo(w, wallH, d), wallMat);
    wall.position.set(x, wallH / 2, z);
    wall.castShadow = true;
    wall.receiveShadow = true;
    worldGroup.add(wall);

    const cap = new THREE.Mesh(getBoxGeo(w + 0.2, 0.25, d + 0.2), wallTileMat);
    cap.position.set(x, wallH + 0.1, z);
    cap.castShadow = true;
    worldGroup.add(cap);
  }

  function addCurbSegment(x, z, w, d) {
    const curbH = 0.25;
    const curb = new THREE.Mesh(getBoxGeo(w, curbH, d), stoneMats[0]);
    curb.position.set(x, curbH / 2, z);
    curb.castShadow = true;
    curb.receiveShadow = true;
    worldGroup.add(curb);
  }

  // North wall & West wall (backdrop)
  addWallSegment(8, 0.2, 16, 0.4);
  addWallSegment(0.2, 8, 0.4, 16);

  // South & East low curbs (foreground of diorama)
  addCurbSegment(5.5, 15.8, 11, 0.4);
  addCurbSegment(14.5, 15.8, 3, 0.4);
  addCurbSegment(15.8, 8, 0.4, 16);

  // Small Shrine Building (at x: 2..4, z: 2..3, level 3)
  const shrineGroup = new THREE.Group();
  shrineGroup.position.set(3.5, 1.5, 3.0);

  // Wood pillars
  const pillarGeo = new THREE.CylinderGeometry(0.08, 0.08, 1.6, 6);
  const pCoords = [
    [-1.2, -0.9], [1.2, -0.9],
    [-1.2, 0.9], [1.2, 0.9],
    [-0.4, -0.9], [0.4, -0.9]
  ];
  pCoords.forEach(([px, pz]) => {
    const p = new THREE.Mesh(pillarGeo, woodMat);
    p.position.set(px, 0.8, pz);
    p.castShadow = true;
    shrineGroup.add(p);
  });

  // Shrine sanctuary body
  const bodyMesh = new THREE.Mesh(getBoxGeo(2.4, 1.4, 1.6), woodMat);
  bodyMesh.position.set(0, 0.7, 0);
  bodyMesh.castShadow = true;
  bodyMesh.receiveShadow = true;
  shrineGroup.add(bodyMesh);
  occludingObjects.push(bodyMesh);

  // Shrine roof with sweeping eaves
  const roofMesh = new THREE.Mesh(getBoxGeo(3.2, 0.4, 2.4), roofMat);
  roofMesh.position.set(0, 1.5, 0);
  roofMesh.castShadow = true;
  shrineGroup.add(roofMesh);
  occludingObjects.push(roofMesh);

  // Roof ridge with gold crest
  const ridge = new THREE.Mesh(getBoxGeo(3.0, 0.25, 0.35), goldMat);
  ridge.position.set(0, 1.78, 0);
  shrineGroup.add(ridge);
  worldGroup.add(shrineGroup);

  // 4 Stone Lanterns with Point Lights
  const lanterns = [];
  const lanternPoints = [
    { x: 10.5, z: 12.5, name: 'Torii Lantern' },
    { x: 10.0, z: 4.5,  name: 'Pond Lantern' },
    { x: 5.5,  z: 6.5,  name: 'Shrine Lantern' },
    { x: 3.0,  z: 9.5,  name: 'Terrace Lantern' }
  ];

  lanternPoints.forEach((lp) => {
    const lGroup = new THREE.Group();
    const groundH = getGroundHeight(lp.x, lp.z);
    lGroup.position.set(lp.x, groundH, lp.z);

    // Stone base
    const base = new THREE.Mesh(getBoxGeo(0.45, 0.25, 0.45), stoneMats[0]);
    base.position.y = 0.125;
    base.castShadow = true;
    lGroup.add(base);

    // Stone shaft
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.14, 0.6, 6), stoneMats[1]);
    shaft.position.y = 0.55;
    shaft.castShadow = true;
    lGroup.add(shaft);

    // Light chamber (firebox with glowing gold core)
    const firebox = new THREE.Mesh(getBoxGeo(0.35, 0.35, 0.35), goldMat);
    firebox.position.y = 0.95;
    lGroup.add(firebox);

    // Stone roof cap
    const cap = new THREE.Mesh(new THREE.ConeGeometry(0.38, 0.3, 4), stoneMats[0]);
    cap.rotation.y = Math.PI / 4;
    cap.position.y = 1.25;
    cap.castShadow = true;
    lGroup.add(cap);

    // Warm golden point light
    const pLight = new THREE.PointLight(PAL.gold, 1.8, 6.0, 2);
    pLight.position.set(0, 1.0, 0);
    lGroup.add(pLight);

    worldGroup.add(lGroup);
    lanterns.push({ group: lGroup, light: pLight, baseIntensity: 1.8 });
  });

  // Torii Gate (at x = 12, z = 13.5)
  const toriiGroup = new THREE.Group();
  toriiGroup.position.set(12.0, 0, 13.5);

  const pillarCyl = new THREE.CylinderGeometry(0.16, 0.18, 3.2, 8);
  const pL = new THREE.Mesh(pillarCyl, toriiMat);
  pL.position.set(-1.1, 1.6, 0);
  pL.castShadow = true;
  toriiGroup.add(pL);

  const pR = new THREE.Mesh(pillarCyl, toriiMat);
  pR.position.set(1.1, 1.6, 0);
  pR.castShadow = true;
  toriiGroup.add(pR);

  // Black bases
  const baseGeo = new THREE.CylinderGeometry(0.24, 0.26, 0.4, 8);
  const bL = new THREE.Mesh(baseGeo, wallMat);
  bL.position.set(-1.1, 0.2, 0);
  toriiGroup.add(bL);
  const bR = new THREE.Mesh(baseGeo, wallMat);
  bR.position.set(1.1, 0.2, 0);
  toriiGroup.add(bR);

  // Upper lintels (Kasagi and Shimaki)
  const lintelTop = new THREE.Mesh(getBoxGeo(3.6, 0.25, 0.35), toriiMat);
  lintelTop.position.set(0, 3.1, 0);
  lintelTop.castShadow = true;
  toriiGroup.add(lintelTop);

  const lintelLow = new THREE.Mesh(getBoxGeo(3.2, 0.2, 0.25), toriiMat);
  lintelLow.position.set(0, 2.5, 0);
  toriiGroup.add(lintelLow);

  // Central plaque (Gakuzuka)
  const plaque = new THREE.Mesh(getBoxGeo(0.28, 0.4, 0.1), goldMat);
  plaque.position.set(0, 2.8, 0);
  toriiGroup.add(plaque);

  // Torii magical awakening light (lights up when win)
  const toriiLight = new THREE.PointLight(PAL.gold, 0.2, 10, 2);
  toriiLight.position.set(0, 3.0, 0);
  toriiGroup.add(toriiLight);
  worldGroup.add(toriiGroup);

  // Cherry Blossom Tree (Sakura)
  const treeGroup = new THREE.Group();
  treeGroup.position.set(10.0, 0, 8.0);

  // Trunk
  const trunkMesh = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.35, 2.2, 6), woodMat);
  trunkMesh.position.y = 1.1;
  trunkMesh.castShadow = true;
  treeGroup.add(trunkMesh);

  // Blossom foliage clusters
  const petalMat = new THREE.MeshStandardMaterial({
    color: 0xFFB7D5,
    roughness: 0.9,
    metalness: 0.05
  });
  const foliageCoords = [
    [0, 2.6, 0, 1.2],
    [-0.7, 2.2, 0.4, 0.85],
    [0.8, 2.4, -0.3, 0.9],
    [0.2, 2.8, 0.6, 0.8]
  ];
  foliageCoords.forEach(([fx, fy, fz, fr]) => {
    const fMesh = new THREE.Mesh(new THREE.DodecahedronGeometry(fr, 1), petalMat);
    fMesh.position.set(fx, fy, fz);
    fMesh.castShadow = true;
    treeGroup.add(fMesh);
  });
  worldGroup.add(treeGroup);

  // Falling Sakura Petal Particles
  const PETAL_COUNT = 65;
  const petalGeo = new THREE.PlaneGeometry(0.06, 0.06);
  const petalParticleMat = new THREE.MeshBasicMaterial({
    color: 0xFFC0CB,
    side: THREE.DoubleSide
  });
  const petals = [];
  for (let i = 0; i < PETAL_COUNT; i++) {
    const pMesh = new THREE.Mesh(petalGeo, petalParticleMat);
    pMesh.position.set(
      treeGroup.position.x + (Math.random() - 0.5) * 3.8,
      1.0 + Math.random() * 2.8,
      treeGroup.position.z + (Math.random() - 0.5) * 3.8
    );
    pMesh.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
    scene.add(pMesh);
    petals.push({
      mesh: pMesh,
      vy: 0.35 + Math.random() * 0.3,
      swayFreq: 1.5 + Math.random() * 2,
      swayAmp: 0.4 + Math.random() * 0.3,
      phase: Math.random() * Math.PI * 2
    });
  }

  // ==========================================
  // 6. COLLECTIBLES: 6 GOLD SHARDS
  // ==========================================
  // 6 locations:
  // 1) Stepping stone in pond (12.5, 0.25, 5.5)
  // 2) Behind the shrine building (3.5, 0.7, 1.2) - fully occluded!
  // 3) Southwest upper terrace (1.5, 1.25, 12.5)
  // 4) East pavilion terrace (13.5, 0.75, 9.5)
  // 5) Beneath the cherry blossom tree (10.0, 0.25, 8.5)
  // 6) Shrine entrance terrace alcove (2.5, 0.75, 5.5)
  const shardLocations = [
    { x: 12.5, y: 0.35, z: 5.5, label: 'Pond Stone' },
    { x: 3.5,  y: 0.75, z: 1.2, label: 'Behind Shrine' },
    { x: 1.5,  y: 1.25, z: 12.5, label: 'SW Overlook' },
    { x: 13.5, y: 0.75, z: 9.5, label: 'East Terrace' },
    { x: 10.0, y: 0.35, z: 8.5, label: 'Under Sakura' },
    { x: 2.5,  y: 0.75, z: 5.5, label: 'Shrine Alcove' }
  ];

  const shardGeo = new THREE.OctahedronGeometry(0.2, 0);
  const shardMat = new THREE.MeshStandardMaterial({
    color: PAL.gold,
    emissive: 0xFFA303,
    emissiveIntensity: 0.7,
    roughness: 0.2,
    metalness: 0.9
  });

  const shards = shardLocations.map((loc, idx) => {
    const mesh = new THREE.Mesh(shardGeo, shardMat);
    mesh.position.set(loc.x, loc.y, loc.z);
    mesh.castShadow = true;
    scene.add(mesh);
    return {
      id: idx + 1,
      mesh: mesh,
      baseY: loc.y,
      x: loc.x,
      z: loc.z,
      collected: false,
      phase: idx * 1.05
    };
  });

  // ==========================================
  // 7. PLAYER SPRITE & ENTITY
  // ==========================================
  // Textures
  const textureLoader = new THREE.TextureLoader();
  const rawAtkTex = textureLoader.load('assets/atk.png');
  rawAtkTex.magFilter = THREE.NearestFilter;
  rawAtkTex.minFilter = THREE.NearestFilter;
  rawAtkTex.generateMipmaps = false;

  const rawSheetTex = textureLoader.load('assets/sheet.png');
  rawSheetTex.magFilter = THREE.NearestFilter;
  rawSheetTex.minFilter = THREE.NearestFilter;
  rawSheetTex.generateMipmaps = false;

  // only the player uses these sheets, so use the loader's textures directly — a clone made
  // before the image finishes loading carries no image and renders the sprite invisible
  const playerAtkTex = rawAtkTex;
  const playerSheetTex = rawSheetTex;

  // Quad geometry: height = 1.2, origin at bottom center (feet)
  const charGeo = new THREE.PlaneGeometry(CHAR_H, CHAR_H);
  charGeo.translate(0, CHAR_H / 2, 0);

  // Normal lit material
  const playerMat = new THREE.MeshLambertMaterial({
    map: playerAtkTex,
    alphaTest: 0.5,
    transparent: false,
    emissive: 0x1A1535
  });

  const playerMesh = new THREE.Mesh(charGeo, playerMat);
  playerMesh.castShadow = true;
  scene.add(playerMesh);

  // Occlusion silhouette: lilac color, depthTest false, opacity 0.55
  const silhouetteMat = new THREE.MeshBasicMaterial({
    map: playerAtkTex,
    color: PAL.lilac,
    transparent: true,
    opacity: 0.55,
    depthTest: false,
    depthWrite: false
  });
  const silhouetteMesh = new THREE.Mesh(charGeo, silhouetteMat);
  silhouetteMesh.renderOrder = 999;
  silhouetteMesh.visible = false;
  scene.add(silhouetteMesh);

  // Contact shadow under player
  const shadowGeo = new THREE.PlaneGeometry(0.7, 0.7);
  shadowGeo.rotateX(-Math.PI / 2);
  const shadowMat = new THREE.MeshBasicMaterial({
    map: createShadowTex(),
    transparent: true,
    opacity: 0.65,
    depthWrite: false
  });
  const playerShadow = new THREE.Mesh(shadowGeo, shadowMat);
  scene.add(playerShadow);

  // Crescent Slash Arc mesh
  const slashGeo = new THREE.PlaneGeometry(1.3, 1.3);
  const slashMat = new THREE.MeshBasicMaterial({
    map: createCrescentSlashTex(),
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide
  });
  const slashMesh = new THREE.Mesh(slashGeo, slashMat);
  slashMesh.visible = false;
  scene.add(slashMesh);

  // Raycaster for occlusion detection
  const raycaster = new THREE.Raycaster();

  // Attack combo specifications (per WORKER_SPEC_COMMON.md)
  // Hit 1: antic 60ms, smear 40ms, active 80ms, rec 170ms (total 350ms)
  // Hit 2: antic 60ms, smear 40ms, active 80ms, rec 170ms (total 350ms)
  // Hit 3: antic 110ms, active 110ms, rec 240ms (total 460ms)
  // Branch 2-1: antic 70ms, smear 40ms, active 80ms, rec 170ms (total 360ms)
  // Branch 2-2: antic 70ms, active 100ms, rec 260ms (total 430ms)
  const ATK_CONFIG = {
    '1':   { row: 0, sfx: 'slash1', antic: 60, smear: 40, active: 80, rec: 170 },
    '2':   { row: 1, sfx: 'slash2', antic: 60, smear: 40, active: 80, rec: 170 },
    '3':   { row: 2, sfx: 'slash3', antic: 110, smear: 40, active: 110, rec: 240 },
    '2-1': { row: 3, sfx: 'slash4', antic: 70, smear: 40, active: 80, rec: 170 },
    '2-2': { row: 4, sfx: 'slash5', antic: 70, smear: 40, active: 100, rec: 260 }
  };

  const player = {
    x: 12.0,
    y: 0.0,
    z: 11.5,
    vx: 0,
    vy: 0,
    vz: 0,
    speed: 3.4,
    grounded: true,
    facingRight: true, // Screen facing direction
    hp: 3,
    maxHp: 3,
    alive: true,
    isOccluded: false,

    // Animation / State
    sheet: 'atk', // 'atk' or 'sheet'
    animCol: 0,
    animRow: 0,
    state: 'idle', // 'idle', 'walk', 'jump', 'dodge', 'atk', 'hurt'
    stateTimer: 0,

    // Combat
    comboStep: 0, // 0 (none), 1, 2, 3, 21 (2-1), 22 (2-2)
    atkPhase: '', // 'antic', 'smear', 'active', 'rec'
    atkTimer: 0,
    queuedAtk: false,
    branchTimer: 0, // 0..450ms window after hit 2 ends to branch to 2-1
    hasHitEnemies: false,

    // Dodge
    dodgeTimer: 0,
    dodgeVx: 0,
    dodgeVz: 0,

    // Invulnerability / Hurt
    invincibleTimer: 0,
    hurtTimer: 0
  };

  function setPlayerFrame(col, row, sheetName) {
    player.sheet = sheetName;
    player.animCol = col;
    player.animRow = row;

    if (sheetName === 'atk') {
      // 8 columns, 23 rows (64x64)
      playerMat.map = playerAtkTex;
      silhouetteMat.map = playerAtkTex;
      playerAtkTex.offset.set(col / 8, 1 - (row + 1) / 23);
      playerAtkTex.repeat.set(1 / 8, 1 / 23);
    } else {
      // 24 columns, 3 rows (46x58)
      playerMat.map = playerSheetTex;
      silhouetteMat.map = playerSheetTex;
      playerSheetTex.offset.set(col / 24, 1 - (row + 1) / 3);
      playerSheetTex.repeat.set(1 / 24, 1 / 3);
    }
  }

  // ==========================================
  // 8. ENEMIES: 4 INK SHADES
  // ==========================================
  const inkTex = createInkShadeTex();
  const enemyGeo = new THREE.PlaneGeometry(1.0, 1.0);
  enemyGeo.translate(0, 0.5, 0);

  const enemyMat = new THREE.MeshLambertMaterial({
    map: inkTex,
    alphaTest: 0.5,
    transparent: false,
    emissive: 0x151037
  });

  const enemySpawns = [
    { x: 8.0,  z: 8.0 },
    { x: 11.5, z: 4.5 },
    { x: 6.0,  z: 5.0 },
    { x: 2.5,  z: 10.5 }
  ];

  const enemies = enemySpawns.map((sp, idx) => {
    const eTex = inkTex.clone();
    eTex.needsUpdate = true;
    eTex.repeat.set(1 / 4, 1);
    eTex.offset.set(0, 0);

    const mat = enemyMat.clone();
    mat.map = eTex;

    const mesh = new THREE.Mesh(enemyGeo, mat);
    mesh.position.set(sp.x, getGroundHeight(sp.x, sp.z), sp.z);
    mesh.castShadow = true;
    scene.add(mesh);

    // Contact shadow under enemy
    const shadow = new THREE.Mesh(shadowGeo, shadowMat);
    scene.add(shadow);

    return {
      id: idx + 1,
      mesh: mesh,
      tex: eTex,
      shadow: shadow,
      x: sp.x,
      y: getGroundHeight(sp.x, sp.z),
      z: sp.z,
      homeX: sp.x,
      homeZ: sp.z,
      hp: 2,
      maxHp: 2,
      alive: true,
      state: 'wander',
      wanderTimer: Math.random() * 2,
      targetX: sp.x,
      targetZ: sp.z,
      hitFlashTimer: 0,
      knockbackVx: 0,
      knockbackVz: 0,
      animTimer: Math.random() * 10
    };
  });

  // ==========================================
  // 9. VFX & PARTICLE SYSTEMS
  // ==========================================
  const particles = [];
  const pQuadGeo = new THREE.PlaneGeometry(0.12, 0.12);

  function spawnParticles(x, y, z, count, colorHex, speedMult, lifeTime) {
    for (let i = 0; i < count; i++) {
      const pMat = new THREE.MeshBasicMaterial({ color: colorHex, depthWrite: false });
      const pMesh = new THREE.Mesh(pQuadGeo, pMat);
      pMesh.position.set(x, y, z);
      scene.add(pMesh);

      const angle = Math.random() * Math.PI * 2;
      const speed = (0.5 + Math.random() * 1.5) * speedMult;
      particles.push({
        mesh: pMesh,
        vx: Math.cos(angle) * speed,
        vy: (0.4 + Math.random() * 1.2) * speedMult,
        vz: Math.sin(angle) * speed,
        life: lifeTime,
        maxLife: lifeTime
      });
    }
  }

  function spawnHitSparks(x, y, z) {
    spawnParticles(x, y + 0.5, z, 8, 0xFFFFFF, 1.8, 0.22);
    spawnParticles(x, y + 0.5, z, 5, PAL.goldHi, 1.4, 0.28);
  }

  function spawnDustPuff(x, y, z) {
    spawnParticles(x, y + 0.05, z, 4, PAL.lilacDark, 0.6, 0.3);
  }

  function spawnDeathBurst(x, y, z) {
    spawnParticles(x, y + 0.5, z, 14, PAL.plum, 1.8, 0.5);
    spawnParticles(x, y + 0.5, z, 10, PAL.lilac, 1.5, 0.4);
  }

  // Camera Shake & Hitstop
  let hitStopTimer = 0;
  let camShakeTimer = 0;
  let camShakeMag = 0;

  // ==========================================
  // 10. INPUT & GAME STATE
  // ==========================================
  const keys = {};
  let gameStarted = false;
  let gameWon = false;
  let gameTime = 0;
  let kills = 0;
  let shardsCollected = 0;
  let deaths = 0;

  window.addEventListener('keydown', (e) => {
    if (window.SFX && window.SFX.unlock) window.SFX.unlock();
    keys[e.code] = true;

    if (!gameStarted && (e.code === 'Space' || e.code === 'Enter')) {
      startGame();
    }
    if (e.code === 'KeyR') {
      resetGame();
    }
    if (e.code === 'KeyX' && gameStarted && player.alive && !gameWon) {
      handleAttackInput();
    }
    if (e.code === 'KeyC' && gameStarted && player.alive && !gameWon) {
      handleDodgeInput();
    }
    if (e.code === 'Space' && gameStarted && player.alive && !gameWon) {
      handleJumpInput();
    }
  });

  window.addEventListener('keyup', (e) => {
    keys[e.code] = false;
  });

  // UI buttons
  const startOverlay = document.getElementById('start');
  const winOverlay = document.getElementById('win');
  const gameoverOverlay = document.getElementById('gameover');
  const startBtn = document.getElementById('startBtn');
  const winBtn = document.getElementById('winBtn');
  const retryBtn = document.getElementById('retryBtn');

  if (startBtn) startBtn.addEventListener('click', startGame);
  if (winBtn) winBtn.addEventListener('click', resetGame);
  if (retryBtn) retryBtn.addEventListener('click', resetGame);

  function startGame() {
    gameStarted = true;
    startOverlay.classList.add('hidden');
    if (window.SFX) window.SFX.play('jump');
  }

  let winOverlayTimer = -1;

  function resetGame() {
    gameStarted = true;
    gameWon = false;
    gameTime = 0;
    kills = 0;
    shardsCollected = 0;
    deaths = 0;
    winOverlayTimer = -1;

    startOverlay.classList.add('hidden');
    winOverlay.classList.add('hidden');
    gameoverOverlay.classList.add('hidden');

    // Reset Player
    player.x = 12.0;
    player.y = 0.0;
    player.z = 11.5;
    player.vx = 0;
    player.vy = 0;
    player.vz = 0;
    player.hp = 3;
    player.alive = true;
    player.grounded = true;
    player.facingRight = true;
    player.state = 'idle';
    player.comboStep = 0;
    player.atkPhase = '';
    player.atkTimer = 0;
    player.queuedAtk = false;
    player.branchTimer = 0;
    player.dodgeTimer = 0;
    player.invincibleTimer = 0;
    player.hurtTimer = 0;

    // Reset Shards
    shards.forEach(sh => {
      sh.collected = false;
      sh.mesh.visible = true;
    });

    // Reset Enemies
    enemies.forEach((en, i) => {
      en.x = enemySpawns[i].x;
      en.z = enemySpawns[i].z;
      en.y = getGroundHeight(en.x, en.z);
      en.hp = 2;
      en.alive = true;
      en.mesh.visible = true;
      en.shadow.visible = true;
      en.state = 'wander';
      en.hitFlashTimer = 0;
      en.knockbackVx = 0;
      en.knockbackVz = 0;
    });

    // Reset Torii
    toriiLight.intensity = 0.2;
    toriiLight.color.setHex(PAL.gold);

    updateHUD();
  }

  // ==========================================
  // 11. COMBAT & DODGE LOGIC
  // ==========================================
  function handleJumpInput() {
    if (player.grounded && player.state !== 'dodge' && player.state !== 'hurt') {
      player.vy = 5.4;
      player.grounded = false;
      player.state = 'jump';
      if (window.SFX) window.SFX.play('jump');
      spawnDustPuff(player.x, player.y, player.z);
    }
  }

  function handleDodgeInput() {
    if (player.state === 'dodge' || player.state === 'hurt') return;

    player.state = 'dodge';
    player.dodgeTimer = 0.28; // 280 ms
    player.invincibleTimer = 0.35; // invulnerable during dodge
    player.comboStep = 0;
    player.atkPhase = '';
    slashMesh.visible = false;

    // Dodge backwards: opposite facing
    const dir = player.facingRight ? SCR_L : SCR_R;
    player.dodgeVx = dir.x * 6.2;
    player.dodgeVz = dir.z * 6.2;

    if (window.SFX) window.SFX.play('roll');
    spawnDustPuff(player.x, player.y, player.z);
  }

  function handleAttackInput() {
    // Attack combo branch & chain check
    if (player.state === 'atk') {
      // If currently in recovery phase, queue or trigger next hit
      if (player.atkPhase === 'rec') {
        if (player.comboStep === 1) {
          startAttack('2');
        } else if (player.comboStep === 2) {
          startAttack('3');
        } else if (player.comboStep === 21) {
          startAttack('2-2');
        }
      } else {
        player.queuedAtk = true;
      }
      return;
    }

    if (player.state === 'dodge' || player.state === 'hurt') return;

    // Check if within 0..450ms branch window after hit 2
    if (player.branchTimer > 0 && player.comboStep === 2) {
      startAttack('2-1');
      return;
    }

    // Default: start hit 1
    startAttack('1');
  }

  function startAttack(type) {
    const cfg = ATK_CONFIG[type];
    if (!cfg) return;

    player.state = 'atk';
    player.comboStep = type === '2-1' ? 21 : (type === '2-2' ? 22 : parseInt(type, 10));
    player.atkPhase = 'antic';
    player.atkTimer = cfg.antic / 1000;
    player.queuedAtk = false;
    player.branchTimer = 0;
    player.hasHitEnemies = false;

    if (window.SFX && cfg.sfx) window.SFX.play(cfg.sfx);

    // Frame setup
    const moveData = window.ATK_ART && window.ATK_ART.moves[type];
    const anticFrame = moveData && moveData.antic ? moveData.antic[0] : 1;
    setPlayerFrame(anticFrame, cfg.row, 'atk');
  }

  function checkAttackHitbox() {
    if (player.hasHitEnemies) return;

    // Hitbox in front of player
    const facingDir = player.facingRight ? SCR_R : SCR_L;
    const hitBoxX = player.x + facingDir.x * 0.7;
    const hitBoxZ = player.z + facingDir.z * 0.7;
    const hitRadius = 0.85;

    enemies.forEach(en => {
      if (!en.alive) return;
      const d = Math.hypot(en.x - hitBoxX, en.z - hitBoxZ);
      if (d < hitRadius) {
        // Hit enemy!
        player.hasHitEnemies = true;
        en.hp -= 1;
        en.hitFlashTimer = 0.15;

        // Knockback in hit direction
        en.knockbackVx = facingDir.x * 4.5;
        en.knockbackVz = facingDir.z * 4.5;

        // Hitstop & camera shake
        hitStopTimer = 0.06; // ~60 ms
        camShakeTimer = 0.14;
        camShakeMag = 0.15;

        spawnHitSparks(en.x, en.y, en.z);

        if (en.hp <= 0) {
          en.alive = false;
          en.mesh.visible = false;
          en.shadow.visible = false;
          kills++;
          if (window.SFX) window.SFX.play('kill');
          spawnDeathBurst(en.x, en.y, en.z);
        } else {
          if (window.SFX) window.SFX.play('hit');
        }
      }
    });

    // Position crescent slash arc
    slashMesh.position.set(hitBoxX, player.y + 0.6, hitBoxZ);
    slashMesh.quaternion.copy(camera.quaternion);
    slashMesh.scale.x = player.facingRight ? -1 : 1;
    slashMesh.visible = true;
  }

  // ==========================================
  // 12. SIMULATION UPDATE
  // ==========================================
  function updateSimulation(dt) {
    if (!gameStarted) return;

    if (gameWon) {
      if (winOverlayTimer > 0) {
        winOverlayTimer -= dt;
        if (winOverlayTimer <= 0) {
          winOverlay.classList.remove('hidden');
        }
      }
      updateAmbientEffects(dt);
      return;
    }

    gameTime += dt;

    // Hitstop
    if (hitStopTimer > 0) {
      hitStopTimer -= dt;
      return;
    }

    // Branch window countdown after hit 2 ends
    if (player.branchTimer > 0) {
      player.branchTimer -= dt;
      if (player.branchTimer <= 0) {
        player.comboStep = 0;
      }
    }

    // Invincibility & Hurt cooldown
    if (player.invincibleTimer > 0) player.invincibleTimer -= dt;
    if (player.hurtTimer > 0) {
      player.hurtTimer -= dt;
      if (player.hurtTimer <= 0 && player.state === 'hurt') {
        player.state = 'idle';
      }
    }

    // 1) Player Movement Input (WASD / Arrows mapped to 4 screen directions)
    let sx = 0, sy = 0;
    if (keys['KeyD'] || keys['ArrowRight']) sx += 1;
    if (keys['KeyA'] || keys['ArrowLeft'])  sx -= 1;
    if (keys['KeyW'] || keys['ArrowUp'])    sy += 1;
    if (keys['KeyS'] || keys['ArrowDown'])  sy -= 1;

    // Normalise diagonal screen input
    const inputLen = Math.hypot(sx, sy);
    if (inputLen > 0) {
      sx /= inputLen;
      sy /= inputLen;
    }

    // Facing direction rule (per TASK.md):
    // "face right when moving screen-right or screen-down-right, left otherwise; keep facing when moving straight up/down."
    if (sx > 0 && sy <= 0) {
      player.facingRight = true;
    } else if (sx < 0 || (sx > 0 && sy > 0)) {
      player.facingRight = false;
    }
    // If sx === 0 (straight up or straight down), maintain current facing!

    // Determine target velocity on ground (XZ)
    if (player.state === 'dodge') {
      player.dodgeTimer -= dt;
      player.vx = player.dodgeVx;
      player.vz = player.dodgeVz;
      if (player.dodgeTimer <= 0) {
        player.state = 'idle';
        player.vx = 0;
        player.vz = 0;
      }
    } else if (player.state === 'atk' || player.state === 'hurt') {
      player.vx *= 0.8;
      player.vz *= 0.8;
    } else {
      if (inputLen > 0) {
        // Project screen direction onto ground plane
        player.vx = ((sx - sy) / Math.SQRT2) * player.speed;
        player.vz = ((-sx - sy) / Math.SQRT2) * player.speed;
        if (player.grounded) player.state = 'walk';
      } else {
        player.vx = 0;
        player.vz = 0;
        if (player.grounded && player.state !== 'atk' && player.state !== 'dodge') {
          player.state = 'idle';
        }
      }
    }

    // 2) Player Physics & Collision
    const newX = player.x + player.vx * dt;
    const newZ = player.z + player.vz * dt;

    // Collision check: try X movement
    if (canMoveTo(newX, player.z, player.y, player.grounded)) {
      player.x = newX;
    }
    // Collision check: try Z movement
    if (canMoveTo(player.x, newZ, player.y, player.grounded)) {
      player.z = newZ;
    }

    // Vertical physics (gravity & stepping)
    const groundH = getGroundHeight(player.x, player.z);

    if (player.grounded) {
      // Step up/down smooth slope/ramp
      if (Math.abs(player.y - groundH) < 0.35) {
        player.y = groundH;
      } else if (player.y > groundH + 0.35) {
        // Stepped off a ledge -> start falling
        player.grounded = false;
        player.vy = 0;
      }
    } else {
      // Airborne
      player.y += player.vy * dt;
      player.vy -= 15.0 * dt; // Gravity

      if (player.y <= groundH) {
        player.y = groundH;
        player.vy = 0;
        if (!player.grounded) {
          player.grounded = true;
          if (window.SFX) window.SFX.play('land');
          spawnDustPuff(player.x, player.y, player.z);
          if (player.state === 'jump') player.state = 'idle';
        }
      }
    }

    // 3) Attack State Machine
    if (player.state === 'atk') {
      player.atkTimer -= dt;
      const typeKey = player.comboStep === 21 ? '2-1' : (player.comboStep === 22 ? '2-2' : String(player.comboStep));
      const cfg = ATK_CONFIG[typeKey];
      const mData = window.ATK_ART && window.ATK_ART.moves[typeKey];

      if (cfg && mData) {
        if (player.atkPhase === 'antic' && player.atkTimer <= 0) {
          // Transition to smear
          player.atkPhase = 'smear';
          player.atkTimer = cfg.smear / 1000;
          const smearF = mData.smear ? mData.smear[0] : 4;
          setPlayerFrame(smearF, cfg.row, 'atk');
        } else if (player.atkPhase === 'smear' && player.atkTimer <= 0) {
          // Transition to active
          player.atkPhase = 'active';
          player.atkTimer = cfg.active / 1000;
          const actF = mData.active ? mData.active[0] : 5;
          setPlayerFrame(actF, cfg.row, 'atk');
          checkAttackHitbox();
        } else if (player.atkPhase === 'active') {
          checkAttackHitbox();
          if (player.atkTimer <= 0) {
            // Transition to recovery
            player.atkPhase = 'rec';
            player.atkTimer = cfg.rec / 1000;
            slashMesh.visible = false;
            const recF = mData.rec ? mData.rec[0] : 6;
            setPlayerFrame(recF, cfg.row, 'atk');
          }
        } else if (player.atkPhase === 'rec' && player.atkTimer <= 0) {
          // Attack finished
          slashMesh.visible = false;
          if (player.queuedAtk) {
            if (player.comboStep === 1) startAttack('2');
            else if (player.comboStep === 2) startAttack('3');
            else if (player.comboStep === 21) startAttack('2-2');
            else {
              player.state = 'idle';
              player.comboStep = 0;
            }
          } else {
            player.state = 'idle';
            if (player.comboStep === 2) {
              player.branchTimer = 0.45; // 450 ms window for 2-1 branch
            } else {
              player.comboStep = 0;
            }
          }
        }
      }
    }

    // 4) Idle / Walk / Jump Animation Frames
    player.stateTimer += dt;
    if (player.state === 'walk') {
      const walkFrame = Math.floor(player.stateTimer / 0.045) % 8;
      setPlayerFrame(walkFrame, 11, 'atk'); // row 11 is run/walk
    } else if (player.state === 'idle') {
      const idleFrame = Math.floor(player.stateTimer / 0.075) % 10;
      setPlayerFrame(idleFrame, 0, 'sheet'); // row 0 of sheet.png is idle
    } else if (player.state === 'jump') {
      const jFrame = player.vy > 1 ? 3 : (player.vy < -1 ? 5 : 4);
      setPlayerFrame(jFrame, 10, 'atk');
    } else if (player.state === 'dodge') {
      const dFrame = Math.min(7, Math.floor((1 - (player.dodgeTimer / 0.28)) * 7));
      setPlayerFrame(dFrame, 17, 'atk'); // row 17 is backdodge
    }

    // 5) Update Player Mesh & Occlusion Detection
    playerMesh.position.set(player.x, player.y, player.z);
    playerMesh.quaternion.copy(camera.quaternion);
    // ALL sprites face LEFT in the files: mirror horizontally when facing right
    playerMesh.scale.x = player.facingRight ? -1 : 1;

    silhouetteMesh.position.copy(playerMesh.position);
    silhouetteMesh.quaternion.copy(playerMesh.quaternion);
    silhouetteMesh.scale.copy(playerMesh.scale);

    // Player contact shadow
    playerShadow.position.set(player.x, groundH + 0.01, player.z);
    const shadowScale = Math.max(0.4, 1.0 - (player.y - groundH) * 0.4);
    playerShadow.scale.set(shadowScale, shadowScale, shadowScale);

    // Occlusion Raycast (from camera to player center)
    const pCenter = new THREE.Vector3(player.x, player.y + 0.6, player.z);
    const camDir = new THREE.Vector3();
    camera.getWorldDirection(camDir);
    const rayOrigin = pCenter.clone().sub(camDir.clone().multiplyScalar(40));
    raycaster.set(rayOrigin, camDir);
    const hits = raycaster.intersectObjects(occludingObjects, true);

    let occluded = false;
    if (hits.length > 0 && hits[0].distance < 39.8) {
      occluded = true;
    }
    player.isOccluded = occluded;
    // TASK.md: "when the player is behind a tall block, show a lilac silhouette (render the player a second time with depthTest off at low opacity) so she is never lost."
    silhouetteMesh.visible = occluded;

    // 6) Collectibles Pickup Check
    shards.forEach(sh => {
      if (sh.collected) return;
      // Rotation and bobbing
      sh.mesh.rotation.y += 2.8 * dt;
      sh.mesh.position.y = sh.baseY + Math.sin(gameTime * 3.5 + sh.phase) * 0.08;

      const d = Math.hypot(player.x - sh.x, player.z - sh.z);
      if (d < 0.65 && Math.abs(player.y - sh.baseY) < 0.9) {
        // Collect shard!
        sh.collected = true;
        sh.mesh.visible = false;
        shardsCollected++;
        if (window.SFX) window.SFX.play('pickup');
        spawnParticles(sh.x, sh.baseY, sh.z, 12, PAL.goldHi, 1.2, 0.4);
        updateHUD();

        // Check Victory Condition (All 6 shards collected)
        if (shardsCollected >= 6) {
          triggerWin();
        }
      }
    });

    // 7) Enemies AI & Behavior
    enemies.forEach(en => {
      if (!en.alive) return;

      en.animTimer += dt;
      const distToPlayer = Math.hypot(player.x - en.x, player.z - en.z);

      // Flash & Knockback
      if (en.hitFlashTimer > 0) {
        en.hitFlashTimer -= dt;
        en.tex.offset.set(3 / 4, 0); // Frame 3: White hit-flash
      } else {
        // Animation frames
        const f = distToPlayer < 4.0 ? 2 : (Math.floor(en.animTimer * 4) % 2);
        en.tex.offset.set(f / 4, 0);
      }

      if (Math.abs(en.knockbackVx) > 0.05 || Math.abs(en.knockbackVz) > 0.05) {
        en.x += en.knockbackVx * dt;
        en.z += en.knockbackVz * dt;
        en.knockbackVx *= 0.85;
        en.knockbackVz *= 0.85;
      } else {
        // AI State
        if (distToPlayer <= 4.0) {
          en.state = 'chase';
          const angle = Math.atan2(player.z - en.z, player.x - en.x);
          const spd = 1.7;
          const nextEx = en.x + Math.cos(angle) * spd * dt;
          const nextEz = en.z + Math.sin(angle) * spd * dt;
          if (canMoveTo(nextEx, en.z, en.y)) en.x = nextEx;
          if (canMoveTo(en.x, nextEz, en.y)) en.z = nextEz;
        } else {
          // Wander
          en.wanderTimer -= dt;
          if (en.wanderTimer <= 0) {
            en.wanderTimer = 2 + Math.random() * 2.5;
            en.targetX = en.homeX + (Math.random() - 0.5) * 3;
            en.targetZ = en.homeZ + (Math.random() - 0.5) * 3;
          }
          const wdx = en.targetX - en.x;
          const wdz = en.targetZ - en.z;
          if (Math.hypot(wdx, wdz) > 0.2) {
            const wAngle = Math.atan2(wdz, wdx);
            const wSpd = 0.9;
            const nwEx = en.x + Math.cos(wAngle) * wSpd * dt;
            const nwEz = en.z + Math.sin(wAngle) * wSpd * dt;
            if (canMoveTo(nwEx, en.z, en.y)) en.x = nwEx;
            if (canMoveTo(en.x, nwEz, en.y)) en.z = nwEz;
          }
        }
      }

      en.y = getGroundHeight(en.x, en.z);
      en.mesh.position.set(en.x, en.y, en.z);
      en.mesh.quaternion.copy(camera.quaternion);

      en.shadow.position.set(en.x, en.y + 0.01, en.z);

      // Contact damage to player
      if (distToPlayer < 0.65 && player.invincibleTimer <= 0 && player.alive) {
        player.hp -= 1;
        player.invincibleTimer = 1.0; // 1s invincibility
        player.hurtTimer = 0.25;
        player.state = 'hurt';

        // Knockback player away from enemy
        const kAngle = Math.atan2(player.z - en.z, player.x - en.x);
        player.vx = Math.cos(kAngle) * 4.0;
        player.vz = Math.sin(kAngle) * 4.0;

        camShakeTimer = 0.15;
        camShakeMag = 0.18;

        if (window.SFX) window.SFX.play('hurt');
        updateHUD();

        if (player.hp <= 0) {
          player.alive = false;
          deaths++;
          if (window.SFX) window.SFX.play('die');
          gameoverOverlay.classList.remove('hidden');
        }
      }
    });

    updateAmbientEffects(dt);
  }

  function updateAmbientEffects(dt) {
    // 8) Update Falling Petals
    petals.forEach(p => {
      p.mesh.position.y -= p.vy * dt;
      p.mesh.position.x += Math.sin(gameTime * p.swayFreq + p.phase) * p.swayAmp * dt;
      p.mesh.rotation.y += 1.5 * dt;

      if (p.mesh.position.y <= 0.1) {
        p.mesh.position.y = 3.0 + Math.random() * 1.5;
        p.mesh.position.x = treeGroup.position.x + (Math.random() - 0.5) * 3.8;
        p.mesh.position.z = treeGroup.position.z + (Math.random() - 0.5) * 3.8;
      }
    });

    // 9) Update Flying Particles
    for (let i = particles.length - 1; i >= 0; i--) {
      const pt = particles[i];
      pt.life -= dt;
      if (pt.life <= 0) {
        scene.remove(pt.mesh);
        particles.splice(i, 1);
        continue;
      }
      pt.mesh.position.x += pt.vx * dt;
      pt.mesh.position.y += pt.vy * dt;
      pt.mesh.position.z += pt.vz * dt;
      pt.vy -= 4.0 * dt; // gravity
      pt.mesh.quaternion.copy(camera.quaternion);
      const scale = pt.life / pt.maxLife;
      pt.mesh.scale.set(scale, scale, scale);
    }

    // 10) Pond water shimmer
    waterMat.map.offset.x = Math.sin(gameTime * 0.5) * 0.04;
    waterMat.map.offset.y = Math.cos(gameTime * 0.4) * 0.04;

    // 11) Lantern light gentle flickering
    lanterns.forEach((l, i) => {
      const flicker = (Math.sin(gameTime * 6 + i * 1.8) + Math.cos(gameTime * 11 + i)) * 0.12;
      l.light.intensity = l.baseIntensity + flicker;
    });

    // 12) Smooth Camera Follow
    camTarget.x += (player.x - camTarget.x) * 0.1;
    camTarget.y += (player.y - camTarget.y) * 0.1;
    camTarget.z += (player.z - camTarget.z) * 0.1;

    // Camera shake
    let shakeX = 0, shakeY = 0;
    if (camShakeTimer > 0) {
      camShakeTimer -= dt;
      shakeX = (Math.random() - 0.5) * camShakeMag;
      shakeY = (Math.random() - 0.5) * camShakeMag;
    }

    camera.position.set(
      camTarget.x + CAM_DIST + shakeX,
      camTarget.y + CAM_DIST + shakeY,
      camTarget.z + CAM_DIST
    );
    camera.lookAt(camTarget.x + shakeX, camTarget.y + shakeY, camTarget.z);
  }

  // ==========================================
  // 13. WIN SEQUENCE
  // ==========================================
  function triggerWin() {
    gameWon = true;
    winOverlayTimer = 0.5;
    if (window.SFX) window.SFX.play('counter');

    // Torii Gate lights up with brilliant radiance!
    toriiLight.intensity = 4.5;
    toriiLight.color.setHex(PAL.goldHi);

    // Spawns burst of celebratory golden particles around Torii
    spawnParticles(12.0, 3.2, 13.5, 24, PAL.goldHi, 2.2, 1.2);
    spawnParticles(12.0, 3.2, 13.5, 18, PAL.lilac, 1.8, 1.0);

    // Update Win Overlay stats
    const wShards = document.getElementById('wShards');
    const wKills = document.getElementById('wKills');
    const wTime = document.getElementById('wTime');
    const wDeaths = document.getElementById('wDeaths');

    if (wShards) wShards.textContent = `${shardsCollected}/6`;
    if (wKills) wKills.textContent = `${kills}/4`;
    if (wTime) wTime.textContent = gameTime.toFixed(1);
    if (wDeaths) wDeaths.textContent = String(deaths);
  }

  // ==========================================
  // 14. HUD DISPLAY
  // ==========================================
  const hHp = document.getElementById('hHp');
  const hShards = document.getElementById('hShards');
  const hKills = document.getElementById('hKills');
  const hTime = document.getElementById('hTime');

  function updateHUD() {
    if (hHp) {
      const hearts = '♥'.repeat(Math.max(0, player.hp)) + '♡'.repeat(Math.max(0, player.maxHp - player.hp));
      hHp.textContent = hearts;
    }
    if (hShards) hShards.textContent = `${shardsCollected}/6`;
    if (hKills) hKills.textContent = `${kills}/4`;
    if (hTime) hTime.textContent = gameTime.toFixed(1);
  }

  // ==========================================
  // 15. MAIN RENDER LOOP & DEBUG HOOKS
  // ==========================================
  function renderScene() {
    renderer.render(scene, camera);
  }

  const STEP = 1 / 120;
  let lastTime = performance.now();
  let accumulatedTime = 0;

  function loop(now) {
    accumulatedTime += Math.min(0.1, (now - lastTime) / 1000);
    lastTime = now;

    while (accumulatedTime >= STEP) {
      updateSimulation(STEP);
      accumulatedTime -= STEP;
    }

    renderScene();
    updateHUD();

    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  // Automated Testing Debug Hooks (per WORKER_SPEC_COMMON.md)
  if (/[?&]debug/.test(location.search)) {
    window.__dbg = () => ({
      player,
      enemies,
      camera,
      shards,
      scene,
      renderer,
      isOccluded: player.isOccluded,
      kills,
      shardsCollected,
      deaths,
      reset: resetGame
    });

    window.__step = (ms) => {
      const steps = Math.max(1, Math.round((ms / 1000) / STEP));
      for (let i = 0; i < steps; i++) {
        updateSimulation(STEP);
      }
      renderScene();
      updateHUD();
    };

    // Auto-dismiss start overlay in debug mode
    startGame();
  }

})();
