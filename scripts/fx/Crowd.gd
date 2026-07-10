extends Node2D
## Torcida do coliseu: centenas de fãs-animais desenhados em _draw (1 nó só),
## sentados nos anéis da arquibancada do stadium_bg. Sem timers — tudo contado
## no _process (seguro ao trocar de tela, mesma lição do Confetti/Match).
##
## GEOMETRIA ESPELHADA de tools/gen_stadium.py (mudou lá, muda aqui):
##   campo Rect2(90, 70, 1100, 580) · fileiras a 16/28/40 px da borda.
##
## API (o Match chama):
##   goal_home()  → pulos + braços pra cima + chuva de confete + mascote comemora
##   goal_away()  → torcida murcha (cinza, cabisbaixa)
##   ooh()        → reação curta (chute pra fora / defesa)

const ConfettiFX = preload("res://scripts/fx/Confetti.gd")

const TEX_PATH := "res://assets/stadium/fans_sheet.png"
const FW := 12.0
const FH := 12.0
const N_VAR := 10
const FIELD := Rect2(90, 70, 1100, 580)
const ROW_OFF: Array[float] = [16.0, 28.0, 40.0]
const SEAT_STEP := 16.0
const SC := 1.25                 # escala dos fãs (12px → ~15px no mundo)
const OLA_DUR := 5.0             # segundos pra onda dar a volta
const OLA_W := 0.055             # largura da janela da ola (fração do perímetro)

var mascot_id := ""              # fera que dança na lateral (setado pelo Match)

var _tex: Texture2D
var _seats: Array = []           # {p: Vector2, v: int, ph: float, t: float}
var _t := 0.0
var _mood := ""                  # "" | "cheer" | "sad" | "ooh"
var _mood_t := 0.0
var _ola_next := 14.0
var _ola_t := -1.0               # posição da onda (0..1); -1 = sem onda
var _mascot: AnimatedSprite2D
var _mascot_base := Vector2(980.0, 664.0)
var _mascot_action_t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2                   # sobre o bg do estádio, sob confete/cut-ins
	_tex = load(TEX_PATH) if ResourceLoader.exists(TEX_PATH) else null
	if _tex == null: return
	_build_seats()
	_build_mascot()

func _build_seats() -> void:
	var cx := FIELD.get_center()
	# arquibancadas de cima e de baixo: largura inteira (inclui cantos)
	for off_i in [2, 1, 0]:       # fileira do fundo primeiro (a da frente cobre)
		var off: float = ROW_OFF[off_i]
		var x := FIELD.position.x - 34.0 + fmod(off_i * 7.0, SEAT_STEP)
		while x <= FIELD.end.x + 34.0:
			_add_seat(Vector2(x, FIELD.position.y - off), cx)
			_add_seat(Vector2(x, FIELD.end.y + off + 4.0), cx)
			x += SEAT_STEP
	# laterais: só entre as arquibancadas de cima/baixo
	for off_i in [2, 1, 0]:
		var off: float = ROW_OFF[off_i]
		var y := FIELD.position.y + 14.0 + fmod(off_i * 7.0, SEAT_STEP)
		while y <= FIELD.end.y - 6.0:
			_add_seat(Vector2(FIELD.position.x - off, y), cx)
			_add_seat(Vector2(FIELD.end.x + off, y), cx)
			y += SEAT_STEP

func _add_seat(pos: Vector2, cx: Vector2) -> void:
	pos.x += randf_range(-3.0, 3.0)
	pos.y += randf_range(-1.5, 1.5)
	_seats.append({
		"p": pos,
		"v": randi() % N_VAR,
		"ph": randf(),
		# posição angular no perímetro (0..1) — a ola varre isso
		"t": fposmod(pos.angle_to_point(cx) + PI, TAU) / TAU,
	})

## Mascote: uma fera de verdade (spritesheet) dançando na beira do fosso.
func _build_mascot() -> void:
	if mascot_id == "": return
	var p := "res://assets/beasts/anim/%s_sheet.png" % mascot_id
	if not ResourceLoader.exists(p): return
	var tex: Texture2D = load(p)
	if tex == null: return
	var defs := {"idle": [0, 4, 6.0, true], "run": [1, 6, 9.0, true], "kick": [2, 4, 12.0, false]}
	var frames := SpriteFrames.new()
	for anim_name in defs:
		var d: Array = defs[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, d[2])
		frames.set_animation_loop(anim_name, d[3])
		for i in int(d[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 32, int(d[0]) * 32, 32, 32)
			frames.add_frame(anim_name, at)
	if frames.has_animation("default"): frames.remove_animation("default")
	_mascot = AnimatedSprite2D.new()
	_mascot.sprite_frames = frames
	_mascot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mascot.scale = Vector2(1.45, 1.45)
	_mascot.position = _mascot_base
	_mascot.z_index = 6
	_mascot.play("run")           # "dança": passinhos no lugar
	add_child(_mascot)

# ==========================================================================
#  REAÇÕES (o Match chama)
# ==========================================================================
func goal_home() -> void:
	_mood = "cheer"
	_mood_t = 3.4
	_ola_t = -1.0
	# chuva de confete caindo das arquibancadas
	for i in 6:
		var x := randf_range(FIELD.position.x + 60.0, FIELD.end.x - 60.0)
		var y := FIELD.position.y - 26.0 if i % 2 == 0 else FIELD.end.y + 26.0
		ConfettiFX.burst(self, Vector2(x, y), 26, 210.0)
	if _mascot != null:
		_mascot.play("kick")
		_mascot_action_t = 4.0 / 12.0

func goal_away() -> void:
	_mood = "sad"
	_mood_t = 2.8

func ooh() -> void:
	if _mood == "":
		_mood = "ooh"
		_mood_t = 0.9

# ==========================================================================
#  LOOP
# ==========================================================================
func _process(delta: float) -> void:
	if _tex == null: return
	_t += delta
	if _mood_t > 0.0:
		_mood_t -= delta
		if _mood_t <= 0.0: _mood = ""
	# ola mexicana: varre o perímetro de tempos em tempos (só com a torcida calma)
	if _ola_t >= 0.0:
		_ola_t += delta / OLA_DUR
		if _ola_t > 1.0 + OLA_W * 4.0:
			_ola_t = -1.0
			_ola_next = randf_range(16.0, 30.0)
	elif _mood == "":
		_ola_next -= delta
		if _ola_next <= 0.0:
			_ola_t = 0.0
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null: sfx.play("crowd_ola", 0.6)
	_update_mascot(delta)
	queue_redraw()

func _update_mascot(delta: float) -> void:
	if _mascot == null: return
	var hop := 4.0
	var speed := 3.6
	if _mood == "cheer":
		hop = 9.0; speed = 8.0
	_mascot.position.y = _mascot_base.y - absf(sin(_t * speed)) * hop
	_mascot.flip_h = sin(_t * 1.7) > 0.0
	if _mascot_action_t > 0.0:
		_mascot_action_t -= delta
		if _mascot_action_t <= 0.0 and _mascot.animation != "run":
			_mascot.play("run")

func _draw() -> void:
	if _tex == null: return
	var size := Vector2(FW * SC, FH * SC)
	for s in _seats:
		var ph: float = s["ph"]
		var frame := 0
		var dy := 0.0
		var tint := Color.WHITE
		match _mood:
			"cheer":
				var w := sin(_t * 9.0 + ph * TAU)
				frame = 2 if w > -0.35 else 1
				dy = -absf(w) * 4.0
			"sad":
				frame = 0
				dy = 2.0
				tint = Color(0.62, 0.62, 0.68)
			"ooh":
				frame = 1 if ph > 0.35 else 0
				dy = -1.0
			_:
				# vida ociosa: bob suave + fã aleatório se empolgando sozinho
				var b := sin(_t * 2.4 + ph * TAU)
				frame = 1 if b > 0.74 else 0
				if fmod(_t * 0.23 + ph * 7.0, 1.0) < 0.035: frame = 2
				# ola: janela da onda levanta todo mundo em sequência
				if _ola_t >= 0.0:
					var d: float = absf(fposmod(s["t"] - _ola_t, 1.0))
					d = minf(d, 1.0 - d)
					var e := clampf(1.0 - d / OLA_W, 0.0, 1.0)
					if e > 0.2:
						frame = 2
						dy = -e * 5.0
		var p: Vector2 = s["p"]
		draw_texture_rect_region(_tex,
			Rect2(Vector2(p.x - size.x * 0.5, p.y - size.y + dy), size),
			Rect2(frame * FW, s["v"] * FH, FW, FH), tint)
