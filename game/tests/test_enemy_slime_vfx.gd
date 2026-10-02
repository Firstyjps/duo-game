extends RefCounted
## เอฟเฟกต์ท่าพุ่งของสไลม์ — game/systems/enemy/slime/slime_vfx.gd


func test_impact_spawns_droplets_and_finishes() -> bool:
	var vfx: SlimeVfx = SlimeVfx.spawn_impact(null, Vector2.ZERO, 18.0, 10)
	var started: bool = vfx.particles.size() == 10 and not vfx.is_done()
	for i: int in 120:
		vfx.tick(1.0 / 60.0)
	var ok: bool = started and vfx.is_done()
	vfx.free()
	return ok


func test_droplets_land_on_ground() -> bool:
	var vfx: SlimeVfx = SlimeVfx.spawn_impact(null, Vector2.ZERO, 18.0, 8)
	for i: int in 50:
		vfx.tick(1.0 / 60.0)
	var grounded: bool = true
	for p: Dictionary in vfx.particles:
		grounded = grounded and p["z"] == 0.0 and p["vz"] == 0.0
	vfx.free()
	return grounded


func test_dust_has_no_ring_and_fades() -> bool:
	var vfx: SlimeVfx = SlimeVfx.spawn_dust(null, Vector2.ZERO, 6)
	var ok: bool = vfx.particles.size() == 6 and vfx.ring_time == 0.0
	for i: int in 60:
		vfx.tick(1.0 / 60.0)
	ok = ok and vfx.is_done()
	vfx.free()
	return ok
