extends Node
## ทดลองใส่ตัวละคร Merakintsugi ให้ Player ตัวจริง (ของทดสอบ ทิ้งได้ — จะออกแบบตัวละครใหม่ทีหลัง)
## วางเป็นลูกของ Player · ไม่แก้ player.gd: อ่าน state/attack_phase/aim แล้วเปลี่ยน texture ของ Sprite2D ทุกเฟรม
## sheet.png = sample ต้นฉบับ (46×58: แถว 0 idle 10f, แถว 1 walk 24f) · atk.png = PixelLab 64×64 (ตาราง MOVES)
## ⚠️ ทุกเฟรมหันซ้ายในไฟล์ และมีแค่ซ้าย/ขวา (ยังไม่มี 8 ทิศ) → flip เมื่อเล็งไปขวา

const BASE: Texture2D = preload("res://mockup/merakintsugi/sheet.png")
const ART: Texture2D = preload("res://mockup/merakintsugi/atk.png")
const BASE_W := 46
const BASE_H := 58
const ART_CELL := 64
const COMBO_RESET := 0.7   # วินาทีหลังฟันจบที่ยังนับเป็นคอมโบต่อ (1 → 2 → 3)

## column ของแต่ละเฟสในแถวของ atk.png (สร้างจาก pixellab/build_atk.py ของโปรเจกต์ Kintsugi)
const MOVES := {
	"1": {"row": 0, "antic": [1, 2, 3], "smear": [4], "active": [5], "rec": [6, 7]},
	"2": {"row": 1, "antic": [1, 2], "smear": [3], "active": [4, 5], "rec": [6, 7]},
	"3": {"row": 2, "antic": [1, 2, 3], "smear": [4], "active": [5, 6], "rec": [7]},
	"run": {"row": 11, "loop": [0, 1, 2, 3, 4, 5, 6, 7]},
	"dash": {"row": 15, "play": [3, 4, 5, 6]},
	"backdodge": {"row": 17, "play": [1, 2, 3, 4, 5, 6, 7]},
	"hurt": {"row": 21, "light": [0, 1], "down": [4, 5, 6], "up": [6, 7]},
}

var player: Player
var _cache: Dictionary = {}
var _t: float = 0.0
var _anim_t: float = 0.0
var _last_state: int = -1
var _combo: int = 0
var _since_attack: float = 99.0


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	if player == null or player.sprite == null:
		return
	var s: Sprite2D = player.sprite
	_t += delta
	_since_attack += delta
	if player.state != _last_state:
		if player.state == Player.State.ATTACK:
			_combo = _combo % 3 + 1 if _since_attack < COMBO_RESET else 1
		if _last_state == Player.State.ATTACK:
			_since_attack = 0.0
		_anim_t = 0.0
		_last_state = player.state
	_anim_t += delta

	var tex: AtlasTexture
	var big := true
	match player.state:
		Player.State.MOVE:
			var spd: float = player.velocity.length()
			if spd > 10.0:
				if spd > player.speed * 1.2:
					tex = _art_loop("run", "loop", 14.0)
				else:
					big = false
					tex = _base(1, int(_t * 26.0 * clampf(spd / player.speed, 0.5, 1.4)) % 24)
			else:
				big = false
				tex = _base(0, int(_t / 0.06) % 10)
		Player.State.DODGE:
			# ถอยหลังเมื่อหลบสวนทางกับทิศที่เล็ง ไม่งั้นใช้ท่าพุ่ง
			var back: bool = player.dodge_dir.dot(player.aim) < -0.2
			tex = _art_play("backdodge" if back else "dash", "play", _anim_t / player.dodge_time)
		Player.State.ATTACK:
			var kind := str(_combo)
			match player.attack_phase:
				Player.AttackPhase.WINDUP:
					tex = _art_play(kind, "antic", player._state_t / player.windup_time)
				Player.AttackPhase.ACTIVE:
					var p: float = player._state_t / player.active_time
					tex = _art_play(kind, "smear" if p < 0.35 else "active", p)
				_:
					tex = _art_play(kind, "rec", player._state_t / player.recover_time)
		Player.State.HURT:
			tex = _art_play("hurt", "light", _anim_t / player.hurt_time)
		Player.State.DEAD:
			tex = _art_play("hurt", "down", _anim_t / 0.5)

	if tex == null:
		return
	s.texture = tex
	# เท้าอยู่ที่จุด origin ของ Player · คอลัมน์ลำตัว: sample x=22/46, PixelLab x=31/64
	s.offset = Vector2(1, -ART_CELL / 2) if big else Vector2(1, -BASE_H / 2)
	s.flip_h = player.aim.x > 0.0   # ไฟล์หันซ้าย


func _base(row: int, col: int) -> AtlasTexture:
	return _atlas(BASE, Rect2(col * BASE_W, row * BASE_H, BASE_W, BASE_H))


func _art(kind: String, col: int) -> AtlasTexture:
	var row: int = MOVES[kind]["row"]
	return _atlas(ART, Rect2(col * ART_CELL, row * ART_CELL, ART_CELL, ART_CELL))


func _art_play(kind: String, phase: String, progress: float) -> AtlasTexture:
	var seq: Array = MOVES[kind][phase]
	var i: int = clampi(int(clampf(progress, 0.0, 0.999) * seq.size()), 0, seq.size() - 1)
	return _art(kind, seq[i])


func _art_loop(kind: String, phase: String, fps: float) -> AtlasTexture:
	var seq: Array = MOVES[kind][phase]
	return _art(kind, seq[int(_t * fps) % seq.size()])


## AtlasTexture ต่อเฟรม (แคชไว้) — ghost ตอน dodge ของ Player คัดลอก texture ไปตรงๆ จึงได้เฟรมเดียวไม่ใช่ทั้งแผ่น
func _atlas(sheet: Texture2D, rect: Rect2) -> AtlasTexture:
	var key := "%d:%s" % [sheet.get_rid().get_id(), rect]
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = rect
		_cache[key] = a
	return _cache[key]
