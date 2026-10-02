class_name SettingsConfig
extends RefCounted
## จัดการการตั้งค่าเกม: เสียง (Master/Music/SFX), หน้าจอ (Fullscreen), ภาษา (TH/EN)
## เซฟ/โหลดลง user://settings.cfg (ConfigFile)

const CONFIG_PATH: String = "user://settings.cfg"

static var master_volume: float = 1.0
static var music_volume: float = 0.8
static var sfx_volume: float = 0.8
static var fullscreen: bool = false
static var language: String = "en"

static var _translations_registered: bool = false

const TRANSLATION_DATA: Dictionary = {
	"UI_TITLE": {"en": "Kintsugi", "th": "Kintsugi"},
	"UI_PLAY": {"en": "Start Game", "th": "เริ่มเกม"},
	"UI_SETTINGS": {"en": "Settings", "th": "ตั้งค่า"},
	"UI_QUIT": {"en": "Quit", "th": "ออกจากเกม"},
	"UI_RESUME": {"en": "Resume", "th": "กลับเกม"},
	"UI_TITLE_SCREEN": {"en": "Title Screen", "th": "กลับหน้าเริ่ม"},
	"UI_PAUSED": {"en": "Game Paused", "th": "หยุดเกม"},
	"UI_AUDIO": {"en": "Audio", "th": "เสียง"},
	"UI_MASTER_VOL": {"en": "Master Volume", "th": "ระดับเสียงรวม"},
	"UI_MUSIC_VOL": {"en": "Music Volume", "th": "เสียงดนตรี"},
	"UI_SFX_VOL": {"en": "SFX Volume", "th": "เสียงเอฟเฟกต์"},
	"UI_VIDEO": {"en": "Display", "th": "การแสดงผล"},
	"UI_FULLSCREEN": {"en": "Fullscreen", "th": "เต็มจอ"},
	"UI_LANGUAGE": {"en": "Language", "th": "ภาษา"},
	"UI_CONTROLS": {"en": "Controls", "th": "ปุ่มควบคุม"},
	"UI_RESET_DEFAULTS": {"en": "Reset Defaults", "th": "คืนค่าเริ่มต้น"},
	"UI_BACK": {"en": "Back", "th": "กลับ"},
	"UI_REBIND": {"en": "Rebind", "th": "เปลี่ยนปุ่ม"},
	"UI_PRESS_ANY_KEY": {"en": "Press any key or button...", "th": "กดปุ่มใดๆ บนคีย์บอร์ดหรือจอย..."},
	"UI_KEY_EXISTS": {"en": "Button already bound!", "th": "ปุ่มนี้ถูกใช้งานแล้ว!"},
	"UI_MOVE_UP": {"en": "Move Up", "th": "เดินขึ้น"},
	"UI_MOVE_DOWN": {"en": "Move Down", "th": "เดินลง"},
	"UI_MOVE_LEFT": {"en": "Move Left", "th": "เดินซ้าย"},
	"UI_MOVE_RIGHT": {"en": "Move Right", "th": "เดินขวา"},
	"UI_ATTACK": {"en": "Attack", "th": "โจมตี"},
	"UI_DODGE": {"en": "Dodge", "th": "หลบ"},
	"UI_PAUSE": {"en": "Pause", "th": "หยุดเกม"},
}


static func setup_translations() -> void:
	if _translations_registered:
		return
	_translations_registered = true

	var tr_en := Translation.new()
	tr_en.locale = "en"
	var tr_th := Translation.new()
	tr_th.locale = "th"

	for key: String in TRANSLATION_DATA:
		var entry: Dictionary = TRANSLATION_DATA[key]
		tr_en.add_message(key, entry.get("en", key))
		tr_th.add_message(key, entry.get("th", key))

	TranslationServer.add_translation(tr_en)
	TranslationServer.add_translation(tr_th)


## สร้าง bus Music และ SFX ตอน runtime ถ้ายังไม่มี (ห้ามแตะ default_bus_layout)
static func ensure_audio_buses() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx == -1:
		master_idx = 0

	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		music_idx = AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")

	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		sfx_idx = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")


static func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	ensure_audio_buses()
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped: float = clampf(volume_linear, 0.0, 1.0)
	if clamped <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))


static func get_bus_volume(bus_name: String) -> float:
	ensure_audio_buses()
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


static func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	set_bus_volume("Master", master_volume)


static func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	set_bus_volume("Music", music_volume)


static func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	set_bus_volume("SFX", sfx_volume)


static func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if DisplayServer.get_name() == "headless":
		return
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func set_language(lang: String) -> void:
	language = lang
	setup_translations()
	TranslationServer.set_locale(lang)


static func apply_settings() -> void:
	setup_translations()
	ensure_audio_buses()
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_fullscreen(fullscreen)
	set_language(language)


static func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 0.8
	fullscreen = false
	language = "en"
	apply_settings()


static func save_to_file(path: String = CONFIG_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("locale", "language", language)
	return cfg.save(path)


static func load_from_file(path: String = CONFIG_PATH) -> Error:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(path)
	if err != OK:
		return err
	master_volume = float(cfg.get_value("audio", "master_volume", 1.0))
	music_volume = float(cfg.get_value("audio", "music_volume", 0.8))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", 0.8))
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	language = str(cfg.get_value("locale", "language", "en"))
	return OK


static func load_and_apply(path: String = CONFIG_PATH) -> void:
	setup_translations()
	if FileAccess.file_exists(path):
		load_from_file(path)
	apply_settings()
