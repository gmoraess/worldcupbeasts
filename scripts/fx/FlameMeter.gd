extends Control
## Medidor de FÚRIA em forma de CHAMA (substitui a barra — pedido do usuário):
## o foguinho cresce com a fúria; CHEIO = núcleo branco + fagulhas + aviso
## sonoro + "FULL!" piscando; se `clickable`, CLICAR emite `ignited` (o Match
## incendeia o time e arma o super da capitã pro próximo lance).
## Desenho 100% procedural (círculos empilhados com lambida senoidal).

signal ignited

var value := 0.0                 # fúria 0..100
var armed := false               # super armado (contorno branco pulsando)
var clickable := false           # só o lado do JOGADOR ativa por clique
var col := Color(0.4, 0.7, 1.0)  # cor do time (tinge a brasa da base)

var _t := 0.0
var _was_full := false
var _full_lbl: Label

func _ready() -> void:
	custom_minimum_size = Vector2(88.0, 88.0)
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	_full_lbl = Label.new()
	_full_lbl.text = "FULL!"
	_full_lbl.add_theme_font_size_override("font_size", 13)
	_full_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_full_lbl.add_theme_color_override("font_outline_color", Color(0.5, 0.1, 0.0))
	_full_lbl.add_theme_constant_override("outline_size", 5)
	_full_lbl.position = Vector2(25.0, -2.0)
	_full_lbl.visible = false
	_full_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_full_lbl)

func is_full() -> bool:
	return value >= 100.0

func _gui_input(e: InputEvent) -> void:
	if clickable and is_full() and not armed and e is InputEventMouseButton \
			and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		ignited.emit()
		accept_event()

func _process(delta: float) -> void:
	_t += delta
	var full := is_full()
	if full and not _was_full:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null: sfx.play("fire_full")     # o AVISO: encheu!
	_was_full = full
	# "FULL!" piscando/pulsando enquanto espera o clique
	_full_lbl.visible = full and not armed and clickable
	if _full_lbl.visible:
		_full_lbl.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 7.0))
		_full_lbl.pivot_offset = _full_lbl.size / 2.0
		_full_lbl.scale = Vector2.ONE * (1.0 + 0.12 * sin(_t * 9.0))
	queue_redraw()

func _draw() -> void:
	var k := clampf(value / 100.0, 0.0, 1.0)
	var base := Vector2(44.0, 80.0)               # pé da chama
	# brasa da base na cor do time
	draw_circle(base + Vector2(0.0, 3.0), 9.0, Color(col.r, col.g, col.b, 0.5))
	if k <= 0.02: return
	var h := lerpf(12.0, 62.0, k)
	if armed:
		# ARMADO: a própria chama "respira" maior (nada de aro — ficava feio)
		h *= 1.0 + 0.10 * sin(_t * 9.0)
	var layers: Array = [
		[1.00, Color(0.92, 0.25, 0.08, 0.85)],    # língua externa vermelha
		[0.68, Color(1.0, 0.55, 0.10, 0.90)],     # meio laranja
		[0.38, Color(1.0, 0.90, 0.35, 0.95)],     # miolo amarelo
	]
	if is_full() or armed:
		layers.append([0.18, Color(1.0, 1.0, 0.95, 1.0)])   # núcleo BRANCO
	if armed:
		# aura DOURADA suave por trás (o "tá pronto" sem contorno duro)
		var ga := 0.16 + 0.10 * sin(_t * 6.0)
		draw_circle(base + Vector2(0.0, -h * 0.45), h * 0.95, Color(1.0, 0.78, 0.25, ga * 0.5))
		draw_circle(base + Vector2(0.0, -h * 0.45), h * 0.62, Color(1.0, 0.85, 0.4, ga))
	for li in layers.size():
		var frac: float = layers[li][0]
		var c: Color = layers[li][1]
		var lh := h * frac
		for i in 7:
			var t2 := float(i) / 6.0
			var r := lerpf(10.0 * frac + 2.5, 1.4, t2)
			var wob := sin(_t * (11.0 + li * 3.0) + t2 * 5.0) * 3.2 * t2
			draw_circle(base + Vector2(wob, -lh * t2), r, c)
	if is_full() or armed:
		# fagulhas subindo (mais quando armado) + halo respirando
		var n_sparks := 8 if armed else 5
		for i in n_sparks:
			var ph := fposmod(_t * 0.9 + i * 0.19, 1.0)
			var sx := sin((_t + i * 7.0) * 3.0) * 11.0
			draw_circle(base + Vector2(sx, -h - 6.0 - ph * 20.0), 1.6,
				Color(1.0, 0.8, 0.3, 1.0 - ph))
		draw_circle(base + Vector2(0.0, -h * 0.5), h * 0.75,
			Color(1.0, 0.6, 0.15, 0.10 + 0.06 * sin(_t * 6.0)))
