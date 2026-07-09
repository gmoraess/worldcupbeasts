extends Node
## Áudio do jogo (autoload "Sfx"): efeitos chiptune + loop musical, ambos
## procedurais (gerados por script — assets/sfx/*.wav).
## • Cria os buses "Music" e "Sfx" (os sliders das Configurações apontam pra eles).
## • play("nome") toca com leve variação de pitch (estilo Vampire Survivors).
## • Todo Button do jogo ganha "click" automaticamente (hook em node_added).

const DIR := "res://assets/sfx/"
const NAMES := ["kick", "pass", "tackle", "goal", "pop", "click", "shimmer", "ko"]
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer

func _enter_tree() -> void:
	# buses ANTES do Settings.apply_all (Main._ready) — os sliders acham o alvo
	for bus_name in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")

func _ready() -> void:
	for n: String in NAMES:
		var p: String = DIR + n + ".wav"
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in POOL_SIZE:
		var pl := AudioStreamPlayer.new()
		pl.bus = "Sfx"
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	# clique automático em todo botão que entrar na árvore
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_ui_click):
		(n as BaseButton).pressed.connect(_ui_click)

func _ui_click() -> void:
	play("click", 0.9, 0.05)

## Toca um efeito com variação de pitch (repetição não soa robótica).
func play(sfx_name: String, volume: float = 1.0, pitch_var: float = 0.08) -> void:
	if not _streams.has(sfx_name): return
	var pl := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	pl.stream = _streams[sfx_name]
	pl.volume_db = linear_to_db(clampf(volume, 0.05, 1.0))
	pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	pl.play()

## Liga o loop musical (idempotente — chamadas repetidas não reiniciam).
func music_start() -> void:
	if _music.playing: return
	var p := DIR + "music_loop.wav"
	if not ResourceLoader.exists(p): return
	var st: AudioStreamWAV = load(p)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2      # 16-bit mono → 2 bytes por amostra
	_music.stream = st
	_music.play()
