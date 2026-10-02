# PixelLab knight (mockup test)

- tool: `create_character_pro_flash` · view `low top-down` · 8 directions · rotation = idle pose (no animation yet)
- seed: `7341` (same for both sizes)
- prompt: dark fantasy knight, low top-down 3/4 view, battered dark blue-grey steel plate armor, closed great helm with narrow visor slit, tattered crimson red cape, longsword held in right hand, round dark iron shield on left arm, grim souls-like mood, muted desaturated palette, dark purple-black outline, standing idle pose

| folder | canvas | PixelLab character_id |
|---|---|---|
| `knight_32/` | 32×32 | `9fa7cb7b-fc03-411f-be5c-327ff5b30350` |
| `knight_48/` | 48×48 | `2cd53187-7ccf-4c8f-8740-0ea4d879e41f` |

`compare_knight_x3.png` = 32 / 48 / old `knight.png` on `arena_grass.png`, nearest ×3 · column order: S, SE, E, NE, N, NW, W, SW

## Idle (48 px)
- template `breathing-idle` **ไม่ใช้**: redraw จาก skeleton แล้วดาบ/โล่หาย ผ้าคลุมเล็กลง (ดู `idle_template_vs_v3.png` แถวบน)
- ใช้ v3 แทน: action "idle breathing, subtle slow chest rise and fall, shoulders lift slightly, cape sways gently, standing still holding sword and shield" · frame_count 4 (+ frame 0 = rotation) · group `854e5c3d-819f-4cd6-9b1d-2c59c8c9d058`
- เสร็จแล้ว: `knight_48/idle/south/` · ที่เหลือ 7 ทิศยังไม่ได้ทำ
