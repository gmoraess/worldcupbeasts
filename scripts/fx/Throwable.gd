extends Node2D
## Arremessáveis e efeitos de área (cartas 💣🍌🕸 + power-ups do inventário).
## Um nó multi-modo, sem timers (contadores no _process — morre com a partida):
##   "fly"    → voa em arco até o alvo e vira o efeito ao pousar
##   "boom"   → 💣 explosão: dano+empurrão nos inimigos, onda de choque
##   "banana" → 🍌 casca no chão; o 1º 'victim' que pisar escorrega (Player.slip)
##   "teia"   → 🕸 zona que reprende os 'victims' dentro por alguns segundos
##   "raio"   → ⚡ tempestade: relâmpago no ponto, dano+paralisia nos 'victims'
##   "ima"    → 🧲 plantado no chão, PUXA a bola pra ele por alguns segundos
##   "ouro"   → 👟 acha o ALIADO ('allies') mais perto do ponto e chama gold_cb
##
## Uso (o Match chama):
##   Throwable.throw(match, kind, from, to, victims, ball, shaker[, allies, gold_cb])
##   Throwable.boom(match, pos, victims, ball, shaker)   (power-up 💣 por toque)

const ConfettiFX = preload("res://scripts/fx/Confetti.gd")

const FLY_DUR := 0.55
const BOOM_R := 135.0
const BOOM_DMG := 55.0
const BANANA_LIFE := 10.0
const WEB_LIFE := 4.5
const WEB_R := 92.0
const ZAP_R := 105.0
const ZAP_DMG := 30.0
const MAG_LIFE := 5.0
const MAG_R := 260.0
const MAG_PULL := 1500.0

var mode := "fly"
var kind := "bomba"              # o que o "fly" vira ao pousar
var victims: Array = []          # jogadores que o efeito atinge (time adversário)
var allies: Array = []           # jogadores do SEU time (👟 ouro)
var gold_cb := Callable()        # func(p: Player) — o Match aplica o buff do 👟
var ball_ref: Node2D = null
var shaker := Callable()         # func(v: float) — shake da câmera do Match

var _t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _label: Label
var _boom_mult := 1.0            # 🪑 cadeirada explode maior que a 💣
var _bolt: PackedVector2Array = PackedVector2Array()   # traçado do ⚡

const ICONS := {"bomba": "💣", "banana": "🍌", "teia": "🕸",
	"raio": "⚡", "ima": "🧲", "ouro": "👟", "cadeira": "🪑"}

static func throw(parent: Node, k: String, from: Vector2, to: Vector2,
		vict: Array, b: Node2D, shk: Callable,
		al: Array = [], gcb: Callable = Callable()) -> void:
	var n: Node2D = load("res://scripts/fx/Throwable.gd").new()
	n.mode = "fly"; n.kind = k
	n._from = from; n._to = to
	n.position = from
	n.victims = vict; n.ball_ref = b; n.shaker = shk
	n.allies = al; n.gold_cb = gcb
	n.z_index = 60
	parent.add_child(n)
	var sfx := n.get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("throw")

## Efeito direto no ponto, SEM voo (toque do inimigo no item detona ali):
## land_mode: "boom" | "raio" | "ima" | "teia" | "banana"
static func spawn(parent: Node, land_mode: String, pos: Vector2,
		vict: Array, b: Node2D, shk: Callable) -> void:
	var n: Node2D = load("res://scripts/fx/Throwable.gd").new()
	n.mode = land_mode
	n.position = pos
	n.victims = vict; n.ball_ref = b; n.shaker = shk
	n.z_index = 60
	parent.add_child(n)

func _ready() -> void:
	if mode in ["fly", "banana", "teia", "ima"]:
		_label = Label.new()
		_label.text = ICONS.get(kind if mode == "fly" else mode, "❓")
		_label.add_theme_font_size_override("font_size", 20)
		_label.position = Vector2(-12, -14)
		add_child(_label)
	# modos que já nascem "pousados" (spawn direto) disparam o efeito agora
	var sfx := get_node_or_null("/root/Sfx")
	match mode:
		"boom": _detonate()
		"raio": _zap()
		"ima":
			if sfx != null: sfx.play("magnet")
		"teia":
			if sfx != null: sfx.play("web")

func _detonate() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("explosion")
	if shaker.is_valid(): shaker.call(12.0)
	ConfettiFX.burst(get_parent(), position, 40, 420.0)
	var r := BOOM_R * _boom_mult
	for p in victims:
		if p == null or not is_instance_valid(p) or p.ko: continue
		var d: float = p.global_position.distance_to(position)
		if d < r:
			var fall := 1.0 - d / r
			var dir: Vector2 = (p.global_position - position).normalized()
			if dir == Vector2.ZERO: dir = Vector2.RIGHT
			p.global_position += dir * (14.0 + 22.0 * fall)   # empurrão da onda
			p.take_damage(BOOM_DMG * _boom_mult * (0.4 + 0.6 * fall))
	# a bola também voa com o estouro
	if ball_ref != null and is_instance_valid(ball_ref):
		var db: float = ball_ref.global_position.distance_to(position)
		if db < BOOM_R * 1.2:
			var vdir: Vector2 = (ball_ref.global_position - position).normalized()
			if vdir == Vector2.ZERO: vdir = Vector2.UP
			ball_ref.velocity += vdir * (560.0 * (1.0 - db / (BOOM_R * 1.2)))

## ⚡ relâmpago: cai do céu no ponto — dano + paralisia curta nos inimigos da área.
func _zap() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("zap")
	if shaker.is_valid(): shaker.call(7.0)
	for p in victims:
		if p == null or not is_instance_valid(p) or p.ko: continue
		if p.global_position.distance_to(position) < ZAP_R:
			p.apply_speed(0.08, 1.4)          # eletrocutado: quase parado
			p.take_damage(ZAP_DMG)
	# traçado serrilhado do raio (desenhado por ~0.35s)
	_bolt.clear()
	var y := -190.0
	var x := 0.0
	while y < -8.0:
		_bolt.append(Vector2(x, y))
		x = randf_range(-16.0, 16.0)
		y += randf_range(18.0, 34.0)
	_bolt.append(Vector2.ZERO)

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
		"raio":
			if _t > 0.4: queue_free()
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
		"ima":
			if _t > MAG_LIFE:
				queue_free()
				return
			# puxa a BOLA (solta/em voo — no pé do carregador o carry ganha)
			if ball_ref != null and is_instance_valid(ball_ref):
				var d: float = ball_ref.global_position.distance_to(position)
				if d > 6.0 and d < MAG_R:
					var pull: Vector2 = (position - ball_ref.global_position).normalized()
					ball_ref.velocity += pull * MAG_PULL * delta * (1.0 - d / MAG_R)
			if _label != null:
				_label.position.y = -14.0 + sin(_t * 6.0) * 2.0
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
		"cadeira":
			# a CADEIRADA (meme): explosão maior que a bomba comum
			mode = "boom"; _t = 0.0
			_boom_mult = 1.25
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
		"raio":
			mode = "raio"; _t = 0.0
			if _label != null: _label.queue_free(); _label = null
			_zap()
		"ima":
			mode = "ima"; _t = 0.0
			z_index = 1
			var sfx2 := get_node_or_null("/root/Sfx")
			if sfx2 != null: sfx2.play("magnet")
		"ouro":
			# acha o aliado mais perto do ponto e entrega o buff pro Match aplicar
			var best: Node2D = null
			var bd := 1e9
			for p in allies:
				if p == null or not is_instance_valid(p) or p.ko: continue
				var d: float = p.global_position.distance_to(position)
				if d < bd: bd = d; best = p
			var sfx3 := get_node_or_null("/root/Sfx")
			if sfx3 != null: sfx3.play("golden")
			if best != null and gold_cb.is_valid():
				gold_cb.call(best)
			queue_free()

func _draw() -> void:
	if mode == "boom":
		var k := clampf(_t / 0.45, 0.0, 1.0)
		var r := 24.0 + (BOOM_R * _boom_mult + 20.0) * k
		var a := (1.0 - k)
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(1.0, 0.8, 0.3, a * 0.9), 6.0 * (1.0 - k) + 1.5)
		draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.95, 0.7, a * 0.35))
	elif mode == "raio":
		var a := clampf(1.0 - _t / 0.35, 0.0, 1.0)
		if _bolt.size() >= 2:
			draw_polyline(_bolt, Color(1.0, 1.0, 0.75, a), 3.0)
			draw_polyline(_bolt, Color(0.65, 0.85, 1.0, a * 0.6), 7.0)
		draw_circle(Vector2.ZERO, ZAP_R * (0.4 + 0.6 * (1.0 - a)), Color(0.8, 0.9, 1.0, a * 0.25))
	elif mode == "teia":
		var a := 0.65 if _t < WEB_LIFE - 1.0 else (WEB_LIFE - _t) * 0.65
		var col := Color(0.92, 0.92, 0.98, maxf(a, 0.0))
		for i in 8:
			var ang := TAU * float(i) / 8.0 + 0.2
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * WEB_R, col, 1.4)
		for ring in [0.35, 0.65, 0.95]:
			draw_arc(Vector2.ZERO, WEB_R * ring, 0, TAU, 26, col, 1.2)
	elif mode == "ima":
		var a := 0.6 if _t < MAG_LIFE - 1.0 else maxf((MAG_LIFE - _t) * 0.6, 0.0)
		var puls := fposmod(_t * 1.4, 1.0)
		# anéis "sugando" pra dentro (raio diminui com o tempo do ciclo)
		for k in 3:
			var ring_r: float = MAG_R * (1.0 - fposmod(puls + k / 3.0, 1.0)) * 0.55
			if ring_r > 14.0:
				draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32,
					Color(0.42, 0.78, 1.0, a * (0.15 + 0.5 * ring_r / MAG_R)), 2.0)
		draw_circle(Vector2.ZERO, 12.0, Color(0.42, 0.78, 1.0, a * 0.3))
