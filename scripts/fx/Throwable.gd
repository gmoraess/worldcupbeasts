extends Node2D
## Arremessáveis e explosões (cartas 💣🍌🕸 + power-up bomba).
## Um nó multi-modo, sem timers (contadores no _process — morre com a partida):
##   "fly"    → voa em arco do banco até o alvo e vira o efeito ao pousar
##   "boom"   → explosão: dano+empurrão nos inimigos, onda de choque desenhada
##   "banana" → casca no chão; o 1º 'victim' que pisar escorrega (Player.slip)
##   "teia"   → zona que reprende os 'victims' dentro por alguns segundos
##
## Uso (o Match chama):
##   Throwable.throw(match, "bomba"|"banana"|"teia", from, to, victims, ball, shaker)
##   Throwable.boom(match, pos, victims, ball, shaker)   (power-up 💣 direto)

const ConfettiFX = preload("res://scripts/fx/Confetti.gd")

const FLY_DUR := 0.55
const BOOM_R := 135.0
const BOOM_DMG := 55.0
const BANANA_LIFE := 10.0
const WEB_LIFE := 4.5
const WEB_R := 92.0

var mode := "fly"
var kind := "bomba"              # o que o "fly" vira ao pousar
var victims: Array = []          # jogadores que o efeito atinge (time adversário)
var ball_ref: Node2D = null
var shaker := Callable()         # func(v: float) — shake da câmera do Match

var _t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _label: Label

const ICONS := {"bomba": "💣", "banana": "🍌", "teia": "🕸"}

static func throw(parent: Node, k: String, from: Vector2, to: Vector2,
		vict: Array, b: Node2D, shk: Callable) -> void:
	var n: Node2D = load("res://scripts/fx/Throwable.gd").new()
	n.mode = "fly"; n.kind = k
	n._from = from; n._to = to
	n.position = from
	n.victims = vict; n.ball_ref = b; n.shaker = shk
	n.z_index = 60
	parent.add_child(n)
	var sfx := n.get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("throw")

static func boom(parent: Node, pos: Vector2, vict: Array, b: Node2D, shk: Callable) -> void:
	var n: Node2D = load("res://scripts/fx/Throwable.gd").new()
	n.mode = "boom"
	n.position = pos
	n.victims = vict; n.ball_ref = b; n.shaker = shk
	n.z_index = 60
	parent.add_child(n)

func _ready() -> void:
	if mode == "fly" or mode == "banana" or mode == "teia":
		_label = Label.new()
		_label.text = ICONS.get(kind if mode == "fly" else mode, "❓")
		_label.add_theme_font_size_override("font_size", 20)
		_label.position = Vector2(-12, -14)
		add_child(_label)
	if mode == "boom":
		_detonate()

func _detonate() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("explosion")
	if shaker.is_valid(): shaker.call(12.0)
	ConfettiFX.burst(get_parent(), position, 40, 420.0)
	for p in victims:
		if p == null or not is_instance_valid(p) or p.ko: continue
		var d: float = p.global_position.distance_to(position)
		if d < BOOM_R:
			var fall := 1.0 - d / BOOM_R
			var dir: Vector2 = (p.global_position - position).normalized()
			if dir == Vector2.ZERO: dir = Vector2.RIGHT
			p.global_position += dir * (14.0 + 22.0 * fall)   # empurrão da onda
			p.take_damage(BOOM_DMG * (0.4 + 0.6 * fall))
	# a bola também voa com o estouro
	if ball_ref != null and is_instance_valid(ball_ref):
		var db: float = ball_ref.global_position.distance_to(position)
		if db < BOOM_R * 1.2:
			var vdir: Vector2 = (ball_ref.global_position - position).normalized()
			if vdir == Vector2.ZERO: vdir = Vector2.UP
			ball_ref.velocity += vdir * (560.0 * (1.0 - db / (BOOM_R * 1.2)))

func _process(delta: float) -> void:
	_t += delta
	match mode:
		"fly":
			var k := clampf(_t / FLY_DUR, 0.0, 1.0)
			position = _from.lerp(_to, k) - Vector2(0.0, sin(PI * k) * 130.0)
			if _label != null: _label.rotation = _t * 9.0
			if k >= 1.0: _land()
		"boom":
			if _t > 0.5: queue_free()
			queue_redraw()
		"banana":
			if _t > BANANA_LIFE:
				queue_free()
				return
			visible = _t < BANANA_LIFE - 2.0 or fmod(_t, 0.24) < 0.15
			for p in victims:
				if p == null or not is_instance_valid(p) or p.ko: continue
				if p.global_position.distance_to(position) < 26.0:
					p.slip()
					var sfx := get_node_or_null("/root/Sfx")
					if sfx != null: sfx.play("slip")
					queue_free()
					return
		"teia":
			if _t > WEB_LIFE:
				queue_free()
				return
			for p in victims:
				if p == null or not is_instance_valid(p) or p.ko: continue
				if p.global_position.distance_to(position) < WEB_R:
					p.apply_speed(0.22, 0.25)     # re-aplicado enquanto estiver dentro
			queue_redraw()

## Pousou: vira o efeito de verdade.
func _land() -> void:
	position = _to
	if _label != null: _label.rotation = 0.0
	match kind:
		"bomba":
			mode = "boom"; _t = 0.0
			if _label != null: _label.queue_free(); _label = null
			_detonate()
		"banana":
			mode = "banana"; _t = 0.0
			z_index = 1                      # fica no chão, sob os jogadores
		"teia":
			mode = "teia"; _t = 0.0
			z_index = 1
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null: sfx.play("web")

func _draw() -> void:
	if mode == "boom":
		var k := clampf(_t / 0.45, 0.0, 1.0)
		var r := 24.0 + (BOOM_R + 20.0) * k
		var a := (1.0 - k)
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(1.0, 0.8, 0.3, a * 0.9), 6.0 * (1.0 - k) + 1.5)
		draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.95, 0.7, a * 0.35))
	elif mode == "teia":
		var a := 0.65 if _t < WEB_LIFE - 1.0 else (WEB_LIFE - _t) * 0.65
		var col := Color(0.92, 0.92, 0.98, maxf(a, 0.0))
		for i in 8:
			var ang := TAU * float(i) / 8.0 + 0.2
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * WEB_R, col, 1.4)
		for ring in [0.35, 0.65, 0.95]:
			draw_arc(Vector2.ZERO, WEB_R * ring, 0, TAU, 26, col, 1.2)
