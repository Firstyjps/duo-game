# Common spec for 2.5D prototypes (Kintsugi Run)

Goal: a small playable prototype so the owner can judge a 2.5D *style*. Quality of feel and look matters more than content size.

## Hard rules
- Work ONLY inside your own folder (given in the task). Never edit files outside it. Do not touch git.
- Single page `index.html` + optional `game.js`. Plain JS, no build step, no npm.
- Three.js r128 UMD only: `<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>` (global `THREE`).
  Optional post FX from `https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/...` (EffectComposer, RenderPass, ShaderPass, UnrealBloomPass, CopyShader, LuminosityHighPassShader).
- Pixel look: render at 480×270 (`renderer.setPixelRatio(1); renderer.setSize(480,270,false)`), canvas CSS scaled by an integer/half-integer factor with `image-rendering: pixelated`. All textures `NearestFilter`, no mipmaps.
- UI text in Thai (font Kanit from Google Fonts). Dark page background `#0F121B`.
- Must load with no console errors from a plain static server (`python3 -m http.server`).
- Debug hook required for automated testing: when URL has `?debug`, expose `window.__step(ms)` (advance the simulation by ms in fixed steps, then render once) and `window.__dbg()` (returns live objects: player, enemies, camera…). Keys are read from `keydown`/`keyup` on `window` using `e.code`.

## Sprites (in ./assets)
- `assets/sheet.png`: original sample. Cells 46×58. Row 0 = idle 10 frames (60 ms), row 1 = walk 24 frames (~38 ms), row 2 = "from idle" 2 frames. Feet at the cell bottom, body centre at x = 22.
- `assets/atk.png` + `assets/atk.js` (defines `window.ATK_ART = {cell: 64, ax: 31, moves: {...}}`): PixelLab animations, cells 64×64, feet at the cell bottom, body centre at x = 31. Each move has a `row` and phase arrays of column indices, e.g. `"1": {row:0, antic:[1,2,3], smear:[4], active:[5], rec:[6,7]}`.
  Move keys: `1`, `2`, `3`, `2-1`, `2-2` (ground attacks), `air`, `air2` (jump attacks), `dodge1`, `dodge2` (attacks after a back dodge), `plunge` (vertical attack: antic/dive/active/rec), `jump` (crouch/rise/apex/fall/land), `run` (loop), `turn` (play), `crouch` (down/hold), `dj` (play), `dash` (play), `slide` (play), `backdodge` (play), `wall` (slide/jump), `ledge` (hang/climb), `ladder` (loop), `hurt` (light/down/up), `heal` (play).
- **ALL sprites face LEFT in the files.** Mirror horizontally (`scale.x = -1` or flip UVs) when the character faces right.
- Draw sprites as textured planes (billboards facing the camera). One shared texture per sheet; per entity clone the texture object (`tex.clone()`, `needsUpdate = true`) and set `offset`/`repeat` to pick the frame. `alphaTest: 0.5`, `transparent: false` avoids sorting artefacts. Lit material (`MeshLambertMaterial` or `MeshStandardMaterial` with a little `emissive`) so scene lights tint the sprite.
- Attack timing (ms): antic 60, smear 40, active 80, rec 170 (hit 3: antic 110, active 110, rec 240; 2-2: antic 70, active 100, rec 260). Combo: pressing X during recovery chains 1→2→3; if X is pressed 0–450 ms *after* hit 2 fully ends, start the branch 2-1, then X → 2-2.
- `assets/sfx.js` defines `window.SFX = {unlock(), play(name, {volume, pitch}), setMuted(bool)}`. Call `SFX.unlock()` on the first key press. Names: jump, land, step, slash1..slash5, hit, kill, dash, roll, hurt, die, pickup, counter, impact.

## Palette (use these for the world)
navy #1C154D, navyDark #151037, ink #0F121B, royal #0321BC, lilac #B2B2FF, lilacDark #9EA0FA, plum #40225F, plumDark #2F1850,
gold #FFA303, goldHi #FFFFCC, goldDark #E05E2B, rust #A64B0A, red #FF0E00, crimson #882323, wood #4D2F1E, ice #97C0FF.
Theme: Japanese mountain temple at night, moon, lanterns, kintsugi gold cracks in stone.

## Enemies
Draw them in code (no image files): "ink shades" — dark blob/ghost shapes in navy/plum with lilac eyes, drawn onto a small canvas texture per animation frame (idle wobble, attack lunge, hit flash white, death burst). 2 HP, contact or swipe damage.

## Effects to include
Hit-stop (~60 ms) and small camera shake on hits, white hit spark, crescent slash arc (white core → #97C0FF → #0321BC) drawn as a textured quad in front of the sword, dust/smoke puffs, lantern point lights, fog, contact shadow (dark ellipse) under every character.

## Deliverable
`index.html` (+ `game.js`) in your folder, start screen with controls in Thai, HUD (HP hearts, score/kills), restart with R.
At the end print a short Thai summary: what was built, controls, known issues.
