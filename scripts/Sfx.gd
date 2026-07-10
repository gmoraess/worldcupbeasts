extends Node
## Áudio do jogo (autoload "Sfx"): efeitos chiptune + TRILHA com várias faixas,
## tudo procedural (tools/gen_sfx.py + tools/gen_music.py → assets/sfx/*.wav).
## • Buses "Music"/"Sfx" (os sliders das Configurações apontam pra eles).
## • play("nome") toca com leve variação de pitch (estilo Vampire Survivors).
## • Música: music_menu()/music_match()/music_climax() trocam de faixa com
##   fade-out → pausa de respiro → fade-in (nada de loop infinito de 14s).
##   As faixas de partida ALTERNAM (match_a/match_b) a cada partida.
## • ambience_start/stop: murmúrio de estádio contínuo durante a partida.
## • Todo Button do jogo ganha "click" automaticamente (hook em node_added).

const DIR := "res://assets/sfx/"
const NAMES := [
	"kick", "pass", "tackle", "goal", "pop", "click", "shimmer", "ko",
	"crowd_goal", "crowd_ooh", "crowd_sad", "crowd_uuh", "crowd_applause",
	"crowd_ola", "crowd_loop", "whistle", "whistle_end",
	"explosion", "zap", "magnet", "golden", "powerup", "slip", "web", "throw",
	"offer_cadeira", "offer_corredor", "offer_placa", "fire_full", "fire_ignite",
	"music_menu", "music_match_a", "music_match_b", "music_climax",
	"jingle_win", "jingle_lose",
]
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _music_track := ""            # faixa lógica atual ("" = silêncio)
var _fade_tw: Tween
var _amb_tw: Tween
var _match_flip := false          # alterna match_a/match_b entre partidas

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
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Sfx"
	add_child(_amb)
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

# ==========================================================================
#  MÚSICA — troca de faixa com fade + pausa de respiro
# ==========================================================================
func music_menu() -> void:
	music_play("music_menu")

## Faixa de partida: alterna A/B a cada chamada (cada partida soa diferente).
func music_match() -> void:
	_match_flip = not _match_flip
	music_play("music_match_a" if _match_flip else "music_match_b")

## Clímax (reta final/última mão): entra RÁPIDO, sem respiro.
func music_climax() -> void:
	music_play("music_climax", 0.25, 0.05, 0.2)

func music_play(track: String, fade_out := 0.8, gap := 0.4, fade_in := 0.7) -> void:
	if track == _music_track and _music != null and _music.playing:
		return                                       # idempotente
	_music_track = track
	if _fade_tw != null and _fade_tw.is_valid(): _fade_tw.kill()
	_fade_tw = create_tween()
	if _music.playing:
		_fade_tw.tween_property(_music, "volume_db", -42.0, fade_out)
		_fade_tw.tween_interval(maxf(gap, 0.01))     # a PAUSA (respiro entre faixas)
	_fade_tw.tween_callback(_start_track.bind(track))
	_fade_tw.tween_method(func(v: float): _music.volume_db = v, -24.0, 0.0, fade_in)

func _start_track(track: String) -> void:
	var st: AudioStreamWAV = _streams.get(track) if _streams.has(track) else null
	if st == null:
		_music.stop()
		return
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2      # 16-bit mono → 2 bytes por amostra
	_music.stream = st
	_music.play()

## Compat: chamadas antigas (Main pré-trilha) caem no tema de menu.
func music_start() -> void:
	music_menu()

# ==========================================================================
#  AMBIENCE — murmúrio do estádio (só na partida)
# ==========================================================================
func ambience_start() -> void:
	if _amb.playing: return
	var st: AudioStreamWAV = _streams.get("crowd_loop") if _streams.has("crowd_loop") else null
	if st == null: return
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2
	if _amb_tw != null and _amb_tw.is_valid(): _amb_tw.kill()
	_amb.stream = st
	_amb.volume_db = -18.0
	_amb.play()
	_amb_tw = create_tween()
	_amb_tw.tween_property(_amb, "volume_db", -7.0, 1.2)

func ambience_stop(fade := 0.8) -> void:
	if not _amb.playing: return
	if _amb_tw != null and _amb_tw.is_valid(): _amb_tw.kill()
	_amb_tw = create_tween()
	_amb_tw.tween_property(_amb, "volume_db", -42.0, fade)
	_amb_tw.tween_callback(_amb.stop)
