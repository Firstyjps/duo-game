class_name Hitbox
extends Area2D
## ตัวทำดาเมจ — เปิดเฉพาะช่วง active ของท่าโจมตี (`activate()` / `deactivate()`)
## โดน Hurtbox แต่ละตัวได้ 1 ครั้งต่อการ activate 1 รอบ

signal hit_landed(hurtbox: Hurtbox, info: DamageInfo)
## โดน parry — ผู้ตีตัดสินเองว่าเซไหม (นับเป็น 1 ครั้งของ activate นี้ ไม่โดนซ้ำ)
signal deflected(hurtbox: Hurtbox, info: DamageInfo)

@export var team: Combat.Team = Combat.Team.NEUTRAL
@export var damage: int = 1
@export var damage_type: StringName = &"physical"
@export var knockback_force: float = 0.0
@export var stagger: float = 0.0
## ผู้โจมตี — ว่าง = owner ของ scene
var source: Node = null
var _hit_ids: Dictionary = {}


func _init() -> void:
	collision_layer = 0
	collision_mask = Combat.LAYER_HURTBOX
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


func activate() -> void:
	_hit_ids.clear()
	set_deferred(&"monitoring", true)


func deactivate() -> void:
	set_deferred(&"monitoring", false)


## override ได้ เช่นผู้เล่นใส่ stat/crit จากไอเทม
func make_damage_info(hurtbox: Hurtbox) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = damage
	info.type = damage_type
	info.team = team
	info.stagger = stagger
	info.source = source if source != null else owner
	if is_inside_tree() and hurtbox.is_inside_tree():
		info.hit_position = hurtbox.global_position
		info.knockback = (hurtbox.global_position - global_position).normalized() * knockback_force
	return info


func try_hit(hurtbox: Hurtbox) -> bool:
	var id: int = hurtbox.get_instance_id()
	if _hit_ids.has(id):
		return false
	var info: DamageInfo = make_damage_info(hurtbox)
	var result: Hurtbox.Result = hurtbox.receive_result(info)
	if result == Hurtbox.Result.DEFLECTED:
		_hit_ids[id] = true
		deflected.emit(hurtbox, info)
		return false
	if result != Hurtbox.Result.HIT:
		return false
	_hit_ids[id] = true
	hit_landed.emit(hurtbox, info)
	return true


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		try_hit(area)
