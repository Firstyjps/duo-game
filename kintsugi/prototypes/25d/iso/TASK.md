# Task: Isometric prototype (temple courtyard diorama)
Folder: prototypes/25d/iso/ — read ../WORKER_SPEC_COMMON.md first.

- Camera: OrthographicCamera, true isometric angle (rotate 45° around Y, then ~35.26° down), following the player smoothly. Slight zoom so the character is ~44 px tall on the 480×270 canvas.
- World: a 16×16 tile courtyard built from 3D blocks with height levels 0–3: stone floor with gold kintsugi cracks, raised platforms reached by stairs (ramps you can walk up), a pond (water plane, gentle shimmer), torii gate, 4 stone lanterns with point lights, a small shrine building, cherry tree with falling petals (particles). Night lighting, moonlight directional light with soft shadows (shadow maps on blocks), fog.
- Player: arrows / WASD move in 4 screen directions (↑ = up-screen, i.e. diagonal on the grid; normalise diagonal speed), collision with blocks and height steps (can walk up stairs, can't walk up >0.5 tile ledges without jumping), Space jump, X attack combo (1→2→3 per common spec), C back dodge. Sprite only has left/right art: face right when moving screen-right or screen-down-right, left otherwise; keep facing when moving straight up/down.
- Enemies: 4 ink shades wandering, chasing when within 4 tiles, contact damage; 2 HP; knockback in the hit direction on the grid.
- Collectibles: 6 gold shards hidden around (on platforms, behind the shrine). Collect all → the torii lights up, show a win message.
- Occlusion: when the player is behind a tall block, show a lilac silhouette (render the player a second time with depthTest off at low opacity) so she is never lost.
