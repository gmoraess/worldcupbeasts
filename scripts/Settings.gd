class_name Settings
## Configurações do jogo (clássicas) persistidas em user://settings.cfg.
## Aplicadas no boot (Main._ready) e quando o jogador mexe na tela de opções.

const PATH := "user://settings.cfg"

static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)            # ok falhar na 1ª vez (usa defaults)
	return c

static func get_val(key: String, def: Variant) -> Variant:
	return _cfg().get_value("opcoes", key, def)

static func set_val(key: String, val: Variant) -> void:
	var c := _cfg()
	c.set_value("opcoes", key, val)
	c.save(PATH)

## Lê tudo e aplica ao sistema (janela/áudio). Chamar no boot.
static func apply_all() -> void:
	apply_fullscreen(get_val("fullscreen", false))
	apply_vsync(get_val("vsync", true))
	apply_volume("master", get_val("vol_master", 0.9))
	apply_volume("music", get_val("vol_music", 0.8))
	apply_volume("sfx", get_val("vol_sfx", 0.9))

static func apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

static func apply_vsync(on: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

## Volume 0..1 → dB no bus correspondente (se existir; senão usa o Master).
static func apply_volume(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus.capitalize())
	if idx < 0: idx = 0                       # sem buses dedicados ainda → Master
	var db: float = -80.0 if v <= 0.001 else linear_to_db(clampf(v, 0.0, 1.0))
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, v <= 0.001)
