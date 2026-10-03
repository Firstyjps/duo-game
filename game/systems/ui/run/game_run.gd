class_name GameRun
extends Node2D
## ฉากเล่นจริง (เฟส 7 · #64): ด่าน + Player + กล้อง + HUD + pause (+ เสียงถ้ามีระบบ audio)
## ด่าน = `level_scene` · จุดเกิด = node ในกลุ่ม "player_spawn" ของด่าน (ไม่มี = origin)
## ตาย: ถ้าด่านจัดการฟื้นเอง (มีกลุ่ม "respawn_handler" เช่น Dungeon ตาม dungeon-flow) รอ EventBus.player_respawn_requested
##       ไม่งั้นฟื้นผู้เล่นที่จุดเกิดเองหลัง `respawn_delay`

const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://systems/hud/hud.tscn")
const PAUSE_SCENE: PackedScene = preload("res://systems/ui/pause/pause_menu.tscn")
const AUDIO_SCENE_PATH: String = "res://systems/audio/audio_director.tscn"

@export var level_scene: PackedScene = preload("res://systems/ui/run/levels/courtyard_level.tscn")
@export var camera_zoom: float = 2.0
@export var respawn_delay: float = 1.6

var level: Node
var player: Player
var camera: GameCamera
var hud: GameHud
var pause_menu: Node
var audio: Node
var _respawn_timer: Timer


func _ready() -> void:
	setup()


func _enter_tree() -> void:
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)


func _exit_tree() -> void:
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


## สร้างทุกชิ้น — แยกจาก _ready ให้เทสต์เรียกได้นอก tree
func setup() -> void:
	y_sort_enabled = true  # ผู้เล่นเรียงลึกร่วมกับกำแพง/ศัตรูของด่าน (ด่านต้องเปิด y_sort ของตัวเองด้วย)
	level = level_scene.instantiate() if level_scene != null else Node2D.new()
	add_child(level)

	player = PLAYER_SCENE.instantiate()
	player.position = find_spawn(level)
	add_child(player)
	player.setup()

	camera = GameCamera.new()
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	add_child(camera)
	camera.setup()
	camera.follow(player, true)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup()
	hud.bind_player(player.health, player, player)
	hud.bind_lock_source(player)

	pause_menu = PAUSE_SCENE.instantiate()
	add_child(pause_menu)

	if ResourceLoader.exists(AUDIO_SCENE_PATH):
		audio = (load(AUDIO_SCENE_PATH) as PackedScene).instantiate()
		add_child(audio)

	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_respawn_here)
	add_child(_respawn_timer)


## จุดเกิด: node แรกในกลุ่ม "player_spawn" ใต้ด่าน (พิกัดเทียบ GameRun ที่อยู่ origin)
static func find_spawn(root: Node) -> Vector2:
	for n: Node in _walk(root):
		if n.is_in_group(&"player_spawn") and n is Node2D:
			return (n as Node2D).position + _offset_to(root, n.get_parent())
	return Vector2.ZERO


static func level_handles_respawn(root: Node) -> bool:
	for n: Node in _walk(root):
		if n.is_in_group(&"respawn_handler"):
			return true
	return false


static func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	var i: int = 0
	while i < out.size():
		out.append_array(out[i].get_children())
		i += 1
	return out


## ผลรวม position จาก root ลงมาถึง node (ใช้ได้นอก tree)
static func _offset_to(root: Node, node: Node) -> Vector2:
	var off := Vector2.ZERO
	var n: Node = node
	while n != null and n != root.get_parent():
		if n is Node2D:
			off += (n as Node2D).position
		n = n.get_parent()
	return off


func _on_player_died() -> void:
	if level_handles_respawn(level):
		return
	if _respawn_timer != null and _respawn_timer.is_inside_tree():
		_respawn_timer.start(respawn_delay)


func _respawn_here() -> void:
	if player != null and is_instance_valid(player):
		player.revive(find_spawn(level))
		camera.snap_to_target()
