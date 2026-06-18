extends Node2D
## ETAPA 0 — Vertical slice da BOLA (GDD §9). Sandbox pra provar que a bola gruda.
## Campo + gol/traves + rede + câmera (slow-mo/zoom/shake) + rastro de fogo +
## input de chute (carrega-e-solta toward mouse + presets 1-5 + tuning ao vivo).
const Ball = preload("res://scripts/Ball.gd")

const FIELD := Rect2(90, 70, 1100, 580)            # x,y,w,h
const GOAL_TOP := 290.0
const GOAL_BOT := 430.0
const GOAL_X := 1182.0
const KICK_MIN := 260.0
const KICK_MAX := 1150.0

var ball: Ball
var cam: Camera2D
var _net: Node2D
var _aim: Line2D
var _power_meter: ColorRect
var _power_fill: ColorRect
var _hud_info: Label
var _hud_tune: Label
var _goal_lbl: Label
var _speed_lbl: Label

var _charging := false
var _charge := 0.0
var _shake := 0.0
var _climax := false
var _goal_cooldown := 0.0

# tuning ao vivo (sweep de feel — GDD §5.3)
var _tune_idx := 0
const TUNE_KEYS := ["ground_drag", "magnus_k", "restitution"]

func _ready() -> void:
	# fundo / gramado
	var grass := ColorRect.new()
	grass.color = Color("2f7d3a")
	grass.position = Vector2.ZERO; grass.size = Vector2(1280, 720)
	add_child(grass)
	_build_pitch_lines()
	_build_walls()
	_build_goal()

	# câmera
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	cam.zoom = Vector2(1, 1)
	add_child(cam)
	cam.make_current()

	# bola
	ball = Ball.new()
	add_child(ball)
	ball.reset_to(Vector2(420, 360))
	ball.bounced.connect(_on_ball_bounced)

	# mira
	_aim = Line2D.new()
	_aim.width = 3.0
	_aim.default_color = Color(1, 1, 1, 0.6)
	add_child(_aim)

	_build_hud()

func _process(delta: float) -> void:
	_goal_cooldown = maxf(0.0, _goal_cooldown - delta)
	# carga do chute
	if _charging:
		_charge = minf(1.0, _charge + delta / 0.75)
		_update_aim()
		_power_meter.visible = true
		_power_fill.size.x = _charge * (_power_meter.size.x - 4)
	else:
		_aim.clear_points()
		_power_meter.visible = false

	# rastro de fogo quando rápido
	var spd := ball.speed()
	if spd > 240.0:
		_spawn_trail(spd)

	# clímax: bola rápida indo pro gol → slow-mo + zoom + fogo
	var near_goal: bool = ball.global_position.x > 820.0 and ball.velocity.x > 80.0 and spd > 520.0
	if near_goal and not _climax and _goal_cooldown <= 0.0:
		_enter_climax()
	elif _climax and (spd < 120.0 or ball.global_position.x < 760.0 or _goal_cooldown > 0.0):
		_exit_climax()

	# câmera: segue a bola sutilmente + shake
	var target := Vector2(640, 360).lerp(ball.global_position, 0.18)
	if _climax:
		target = ball.global_position.lerp(Vector2(GOAL_X, (GOAL_TOP + GOAL_BOT) * 0.5), 0.4)
	cam.position = cam.position.lerp(target, 0.12)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		cam.offset = cam.offset.lerp(Vector2.ZERO, 0.3)

	# HUD readout
	_speed_lbl.text = "vel: %d   altura: %d   spin: %+.1f" % [int(spd), int(ball.height), ball.spin]
	_hud_tune.text = "TUNING (Tab troca · ↑↓ ajusta)\n%s drag=%.2f  magnus=%.2f  restituição=%.2f" % [
		"▶ " + TUNE_KEYS[_tune_idx], ball.ground_drag, ball.magnus_k, ball.restitution]

# ==========================================================================
#  INPUT
# ==========================================================================
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_charging = true; _charge = 0.0
		elif _charging:
			_charging = false
			_do_kick(lerpf(KICK_MIN, KICK_MAX, _charge), _spin_from_keys(), _lift_from_keys())
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1: _do_kick(380.0, 0.0, 0.0)        # passe rasteiro
			KEY_2: _do_kick(560.0, 0.0, 560.0)      # cruzamento
			KEY_3: _do_kick(720.0, 2.6, 0.0)        # chute colocado
			KEY_4: _do_kick(1050.0, 0.4, 120.0)     # bomba
			KEY_5: _do_kick(330.0, 0.0, 720.0)      # cavadinha
			KEY_R: ball.reset_to(Vector2(420, 360))
			KEY_TAB: _tune_idx = (_tune_idx + 1) % TUNE_KEYS.size()
			KEY_UP: _tune(0.05)
			KEY_DOWN: _tune(-0.05)

func _spin_from_keys() -> float:
	if Input.is_key_pressed(KEY_A): return -2.6
	if Input.is_key_pressed(KEY_D): return 2.6
	return 0.0

func _lift_from_keys() -> float:
	return 520.0 if Input.is_key_pressed(KEY_W) else 0.0

func _do_kick(power: float, spin: float, lift: float) -> void:
	var dir := (get_global_mouse_position() - ball.global_position)
	if dir.length() < 1.0: dir = Vector2.RIGHT
	ball.kick(dir, power, spin, lift)

func _tune(d: float) -> void:
	match TUNE_KEYS[_tune_idx]:
		"ground_drag": ball.ground_drag = maxf(0.0, ball.ground_drag + d)
		"magnus_k":    ball.magnus_k = maxf(0.0, ball.magnus_k + d)
		"restitution": ball.restitution = clampf(ball.restitution + d, 0.0, 1.0)

func _update_aim() -> void:
	var dir := (get_global_mouse_position() - ball.global_position)
	if dir.length() < 1.0: return
	var p := lerpf(KICK_MIN, KICK_MAX, _charge)
	_aim.clear_points()
	_aim.add_point(ball.global_position)
	_aim.add_point(ball.global_position + dir.normalized() * (40.0 + p * 0.12))
	_aim.default_color = Color(1, 0.9, 0.3, 0.5 + _charge * 0.4)

# ==========================================================================
#  CLÍMAX / JUICE
# ==========================================================================
func _enter_climax() -> void:
	_climax = true
	ball.ball_time_scale = 0.35
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(1.7, 1.7), 0.25).set_trans(Tween.TRANS_SINE)

func _exit_climax() -> void:
	_climax = false
	ball.ball_time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_SINE)

func _on_ball_bounced(strength: float, where: Vector2) -> void:
	_shake = clampf(strength * 0.012, 1.0, 14.0)

func _on_goal(_body: Node) -> void:
	if _goal_cooldown > 0.0: return
	_goal_cooldown = 1.5
	_shake = 16.0
	_jiggle_net()
	ball.ball_time_scale = 1.0
	_goal_lbl.modulate = Color(1, 1, 1, 0)
	_goal_lbl.scale = Vector2(0.3, 0.3)
	_goal_lbl.pivot_offset = _goal_lbl.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_goal_lbl, "modulate:a", 1.0, 0.12)
	tw.tween_property(_goal_lbl, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(_goal_lbl, "modulate:a", 0.0, 0.4)
	# devolve a bola
	await get_tree().create_timer(1.4).timeout
	ball.reset_to(Vector2(420, 360))

func _spawn_trail(spd: float) -> void:
	var dot := Polygon2D.new()
	var r := clampf(spd * 0.012, 4.0, 11.0)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	dot.polygon = pts
	var hot: bool = _climax or spd > 720.0
	dot.color = Color(1.0, 0.5, 0.12, 0.8) if hot else Color(1.0, 0.85, 0.4, 0.5)
	dot.global_position = ball.global_position + Vector2(0, -ball.height)
	add_child(dot)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dot, "modulate:a", 0.0, 0.35)
	tw.tween_property(dot, "scale", Vector2(0.2, 0.2), 0.35)
	tw.chain().tween_callback(dot.queue_free)

# ==========================================================================
#  CONSTRUÇÃO DO CAMPO
# ==========================================================================
func _build_pitch_lines() -> void:
	var col := Color(1, 1, 1, 0.5)
	_line([Vector2(FIELD.position.x, FIELD.position.y), Vector2(FIELD.end.x, FIELD.position.y),
		   Vector2(FIELD.end.x, FIELD.end.y), Vector2(FIELD.position.x, FIELD.end.y),
		   Vector2(FIELD.position.x, FIELD.position.y)], col, 3.0)
	_line([Vector2(640, FIELD.position.y), Vector2(640, FIELD.end.y)], col, 2.0)
	var circ := Line2D.new(); circ.width = 2.0; circ.default_color = col
	for i in 33:
		var a := TAU * float(i) / 32.0
		circ.add_point(Vector2(640, 360) + Vector2(cos(a), sin(a)) * 70.0)
	add_child(circ)

func _line(points: Array, col: Color, w: float) -> void:
	var l := Line2D.new(); l.width = w; l.default_color = col
	for p in points: l.add_point(p)
	add_child(l)

func _build_walls() -> void:
	# topo, base, esquerda
	_wall(Rect2(FIELD.position.x - 20, FIELD.position.y - 20, FIELD.size.x + 40, 20))   # topo
	_wall(Rect2(FIELD.position.x - 20, FIELD.end.y, FIELD.size.x + 40, 20))             # base
	_wall(Rect2(FIELD.position.x - 20, FIELD.position.y, 20, FIELD.size.y))             # esquerda
	# direita com gap pro gol (acima e abaixo da boca)
	_wall(Rect2(FIELD.end.x, FIELD.position.y, 20, GOAL_TOP - FIELD.position.y))
	_wall(Rect2(FIELD.end.x, GOAL_BOT, 20, FIELD.end.y - GOAL_BOT))

func _wall(r: Rect2) -> void:
	var sb := StaticBody2D.new()
	sb.position = r.position + r.size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new(); shape.size = r.size
	cs.shape = shape
	sb.add_child(cs)
	add_child(sb)

func _build_goal() -> void:
	# traves (postes) — alta restituição vem do bounce da bola
	for y in [GOAL_TOP, GOAL_BOT]:
		var post := StaticBody2D.new()
		post.position = Vector2(GOAL_X, y)
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new(); sh.radius = 7.0
		cs.shape = sh
		post.add_child(cs)
		add_child(post)
		var dot := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * float(i) / 12.0
			pts.append(Vector2(cos(a), sin(a)) * 7.0)
		dot.polygon = pts; dot.color = Color(1, 1, 1, 0.95)
		post.add_child(dot)
	# rede
	_net = Node2D.new(); add_child(_net)
	for i in 9:
		var t := float(i) / 8.0
		_net_line([Vector2(GOAL_X + 6, lerp(GOAL_TOP, GOAL_BOT, t)), Vector2(GOAL_X + 46, lerp(GOAL_TOP, GOAL_BOT, t))])
	for i in 5:
		var x := GOAL_X + 6 + i * 10.0
		_net_line([Vector2(x, GOAL_TOP), Vector2(x, GOAL_BOT)])
	# sensor de gol
	var area := Area2D.new()
	area.position = Vector2(GOAL_X + 26, (GOAL_TOP + GOAL_BOT) / 2.0)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new(); sh.size = Vector2(40, GOAL_BOT - GOAL_TOP)
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_goal)

func _net_line(points: Array) -> void:
	var l := Line2D.new(); l.width = 1.0; l.default_color = Color(1, 1, 1, 0.45)
	for p in points: l.add_point(p)
	_net.add_child(l)

func _jiggle_net() -> void:
	var tw := create_tween()
	tw.tween_property(_net, "position:x", 14.0, 0.08)
	tw.tween_property(_net, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# ==========================================================================
#  HUD
# ==========================================================================
func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	_hud_info = Label.new()
	_hud_info.text = "ETAPA 0 — sinta a bola\n[ segura e solta o BOTÃO ESQ ] chuta na direção do mouse (potência pela carga)\nA/D = curva ·  W = elevar (lob)\n1 passe  2 cruzamento  3 colocado  4 bomba  5 cavadinha  ·  R = resetar"
	_hud_info.position = Vector2(16, 12)
	_hud_info.add_theme_font_size_override("font_size", 14)
	_hud_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_hud_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_info.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud_info)

	_hud_tune = Label.new()
	_hud_tune.position = Vector2(16, 690)
	_hud_tune.add_theme_font_size_override("font_size", 13)
	_hud_tune.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_hud_tune.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_tune.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud_tune)

	_speed_lbl = Label.new()
	_speed_lbl.position = Vector2(1040, 12)
	_speed_lbl.add_theme_font_size_override("font_size", 14)
	_speed_lbl.add_theme_color_override("font_color", Color(0.8, 0.95, 1))
	_speed_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_speed_lbl.add_theme_constant_override("outline_size", 4)
	layer.add_child(_speed_lbl)

	# medidor de potência
	_power_meter = ColorRect.new()
	_power_meter.color = Color(0, 0, 0, 0.6)
	_power_meter.position = Vector2(540, 670); _power_meter.size = Vector2(200, 14)
	_power_meter.visible = false
	layer.add_child(_power_meter)
	_power_fill = ColorRect.new()
	_power_fill.color = Color(1, 0.7, 0.2)
	_power_fill.position = Vector2(2, 2); _power_fill.size = Vector2(0, 10)
	_power_meter.add_child(_power_fill)

	# GOOOL!
	_goal_lbl = Label.new()
	_goal_lbl.text = "G O O O L !"
	_goal_lbl.add_theme_font_size_override("font_size", 64)
	_goal_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_goal_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_goal_lbl.add_theme_constant_override("outline_size", 8)
	_goal_lbl.position = Vector2(440, 150)
	_goal_lbl.modulate = Color(1, 1, 1, 0)
	layer.add_child(_goal_lbl)
