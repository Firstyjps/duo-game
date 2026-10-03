class_name DirSprite
extends AnimatedSprite2D
## สไปรต์ 8 ทิศ — SpriteFrames มีแอนิเมชันชื่อ "<ท่า>_<ทิศ>" เช่น "walk_south-east"
## (สร้างจาก tools/build_dir_atlas.py) · ผู้ใช้สั่งแค่ set_facing() + play_action()

@export var sticky_margin_deg: float = 8.0

var facing: int = Dir8.SOUTH
var action: StringName = &"idle"


static func anim_name(act: StringName, dir: int) -> StringName:
	return StringName("%s_%s" % [act, Dir8.name_of(dir)])


## v = ทิศบนจอ (ความเร็วหรือทิศเล็ง) · v ยาว ~0 = หันทางเดิม
func set_facing(v: Vector2) -> void:
	var d: int = Dir8.from_vector_sticky(v, facing, sticky_margin_deg)
	if d != facing:
		facing = d
		_apply(true)


## เปลี่ยนท่า — ท่าเดิมไม่ restart · ท่าที่ไม่มีใน SpriteFrames → ใช้ idle แทน
func play_action(act: StringName) -> void:
	if act == action and is_playing():
		return
	action = act
	_apply(false)


## แสดงเฟรมที่กำหนดของท่า (ไม่เล่นเอง) — ใช้ให้ภาพตรงกับจังหวะในโค้ด เช่น windup/active ของท่าฟัน
## frame เกินจำนวนเฟรม → ใช้เฟรมสุดท้าย · ท่าไม่มี → ไม่ทำอะไร
func show_frame(act: StringName, index: int) -> void:
	if not has_action(act):
		return
	action = act
	var target: StringName = anim_name(act, facing)
	if animation != target:
		play(target)
	pause()
	frame = clampi(index, 0, sprite_frames.get_frame_count(target) - 1)


func has_action(act: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(anim_name(act, facing))


## เปลี่ยนทิศกลางท่า → เล่นต่อจากเฟรมเดิม (เดินแล้วเลี้ยวไม่สะดุด)
func _apply(keep_progress: bool) -> void:
	if sprite_frames == null:
		return
	var act: StringName = action if has_action(action) else &"idle"
	var target: StringName = anim_name(act, facing)
	if not sprite_frames.has_animation(target):
		return
	var f: int = frame
	var p: float = frame_progress
	play(target)
	if keep_progress and f < sprite_frames.get_frame_count(target):
		set_frame_and_progress(f, p)
