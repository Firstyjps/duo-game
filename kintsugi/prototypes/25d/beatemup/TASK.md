# Task: Beat 'em up prototype (depth-lane brawler)
Folder: prototypes/25d/beatemup/ — read ../WORKER_SPEC_COMMON.md first.

- Camera: PerspectiveCamera ~35° FOV, elevated and tilted down ~25°, side-on, following the player along x. The floor is a 3D plane (stone tiles, lilac moss edges, gold cracks) with depth range z ∈ [0, 5] tiles that the player can walk across.
- Arena: temple street ~4 screens long: back wall with shoji/wood pillars, lanterns (point lights), torii, stone lanterns, a few breakable crates (code-drawn). Screen locks in 3 "fight zones" until the wave is cleared (classic brawler), arrow "GO →" after each.
- Player: ← → move x, ↑ ↓ move in depth (z), Shift run, Space jump (real y with gravity; shadow stays on the floor), X attack with the combo rules from the common spec, X in air = air → air2, C = back dodge (i-frames) then X = dodge1 → dodge2, ↓+X in air = plunge with a ground shockwave. Hurt: light flinch on ground, knockdown (hurt down/up) when HP ≤1 or hit while airborne. 5 HP.
- Hit detection uses x overlap AND |z difference| ≤ 0.6 tiles (depth lane tolerance). Enemies only hit you if they are in your lane.
- Enemies: 3 waves (3, 4, 5 ink shades). They spread across depth lanes, approach, wind up (telegraph flash), lunge. Knockback, hit-stop, death burst of ink particles + gold sparks.
- Depth sort: sprites at larger z (nearer the camera) draw in front; make sure the floor shadow is under each sprite.
- HUD: hearts, wave counter, combo counter that pops on 3+ hits.
