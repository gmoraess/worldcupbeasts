extends Node2D
## Doc 4 §3 — Chute de perícia (sem %). Overlay de mira em espaço de MUNDO (filho
## do Match, compartilha a câmera). Mostra: reticle na boca do gol, medidor de
## FORÇA pelo arraste, e o TELL do goleiro (o lado pra onde ele vai mergulhar) —
## a perícia é mirar LONGE do tell. O resultado emerge da física no Match; aqui
## não há nenhum número de % na tela.
##
## Uso: o Match instancia, chama setup(...), e conecta:
##   aimed(aim_world: Vector2, power01: float)   → jogador soltou o chute
## O Match pausa a árvore enquanto mira; este nó roda em PROCESS_MODE_ALWAYS.

signal aimed(aim_world: Vector2, power01: float)

const DRAG_MIN := 36.0      # arraste mínimo (px de mundo) → força mínima
const DRAG_MAX := 220.0     # arraste pra força máxima (chega rápido — chute sempre forte)

var ball_pos := Vector2.ZERO        # de onde a bola sai
var goal_x := 0.0                   # linha do gol que o jogador ataca
var goal_top := 0.0
var goal_bot := 0.0
var gk_tell := Vector2.ZERO         # pra onde o goleiro vai mergulhar (o "tell")
var gk_color := Color(1, 0.4, 0.3)
var forgive := 14.0                 # "zona de perdão" da mira (∝ finalização)
var is_super := false

var _origin := Vector2.ZERO         # ponto onde começou o arraste
var _dragging := false
var _t := 0.0

func setup(p_ball: Vector2, p_goal_x: float, p_top: float, p_bot: float,
		p_tell: Vector2, p_gk_color: Color, p_forgive: float, p_super: bool) -> void:
	ball_pos = p_ball
	goal_x = p_goal_x
	goal_top = p_top
	goal_bot = p_bot
	gk_tell = p_tell
	gk_color = p_gk_color
	forgive = p_forgive
	is_super = p_super
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_origin = get_global_mouse_position()
			_dragging = true
		elif _dragging:
			_dragging = false
			_fire()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_origin = get_global_mouse_position()
			_dragging = true
		elif _dragging:
			_dragging = false
			_fire()

## Tecla/clique direto também dispara um chute "rápido" (mira assistida ao centro-canto).
func quick_shot() -> void:
	var aim := _aim_point()
	emit_signal("aimed", aim, 0.85)

func _fire() -> void:
	emit_signal("aimed", _aim_point(), _power01())

# — geometria da mira —
func _drag() -> Vector2:
	return get_global_mouse_position() - _origin

func _power01() -> float:
	var d: float = clampf(_drag().length(), DRAG_MIN, DRAG_MAX)
	return (d - DRAG_MIN) / (DRAG_MAX - DRAG_MIN)

## Ponto-alvo na linha do gol: projeta o raio bola→mouse até x = goal_x,
## clampado à boca do gol (com leve folga = risco de mirar fora).
func _aim_point() -> Vector2:
	var m := get_global_mouse_position()
	var dir := m - ball_pos
	if absf(dir.x) < 1.0:
		dir.x = signf(goal_x - ball_pos.x) * 1.0
	var t := (goal_x - ball_pos.x) / dir.x
	var y := ball_pos.y + dir.y * t
	if t <= 0.0:                     # mouse atrás da bola → mira no centro do gol
		y = (goal_top + goal_bot) * 0.5
	y = clampf(y, goal_top - 16.0, goal_bot + 16.0)
	return Vector2(goal_x, y)

func _draw() -> void:
	# véu leve só na boca do gol (foco), sem escurecer o campo todo
	var aim := _aim_point()
	var pw := _power01()

	# TELL do goleiro: zona pra onde ele vai (mire longe daqui)
	draw_circle(gk_tell, 26.0, Color(gk_color.r, gk_color.g, gk_color.b, 0.30))
	draw_arc(gk_tell, 30.0, 0, TAU, 28, Color(gk_color.r, gk_color.g, gk_color.b, 0.8), 3.0)

	# linha de mira da bola até o alvo
	var aim_col := Color(1, 0.95, 0.5, 0.85) if not is_super else Color(1, 0.5, 0.2, 0.9)
	draw_line(ball_pos, aim, Color(aim_col.r, aim_col.g, aim_col.b, 0.5), 2.0)

	# reticle no alvo (raio = zona de perdão; finalização alta perdoa mais)
	var rr := 10.0 + forgive
	draw_arc(aim, rr, 0, TAU, 32, aim_col, 3.0)
	draw_arc(aim, rr * 0.45, 0, TAU, 20, aim_col, 2.0)
	draw_line(aim - Vector2(rr + 6, 0), aim + Vector2(rr + 6, 0), aim_col, 1.5)
	draw_line(aim - Vector2(0, rr + 6), aim + Vector2(0, rr + 6), aim_col, 1.5)

	# medidor de FORÇA: anel ao redor da bola que enche com o arraste
	draw_arc(ball_pos, 22.0, -PI / 2, -PI / 2 + TAU * pw, 36, Color(0.4, 1.0, 0.5, 0.95), 4.0)
	draw_arc(ball_pos, 22.0, 0, TAU, 36, Color(1, 1, 1, 0.18), 2.0)
