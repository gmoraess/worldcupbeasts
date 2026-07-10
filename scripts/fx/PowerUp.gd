extends Node2D
## Power-up no gramado (estilo Mario Strikers): um item pulsante surge no campo;
## QUALQUER jogador que encostar ativa o efeito pro time dele (o Match detecta
## por distância e aplica). Sem timers — contadores no _process; some sozinho.
##
## Tipos: 💣 bomba (explosão nos adversários) · ⚡ raio (time acelera)
##        🧲 ímã (controle de bola ampliado) · 👟 ouro (próximo chute mais forte)

const KINDS := {
	"bomba": {"ic": "💣", "col": Color("ff6a4a")},
	"raio":  {"ic": "⚡", "col": Color("ffd94a")},
	"ima":   {"ic": "🧲", "col": Color("6ac8ff")},
	"ouro":  {"ic": "👟", "col": Color("f3da93")},
}
const LIFE := 10.0               # segundos até sumir se ninguém pegar

var kind := "bomba"
var _t := 0.0
var _label: Label

var _hint: Label

func _ready() -> void:
	z_index = 4
	_label = Label.new()
	_label.text = KINDS.get(kind, {}).get("ic", "❓")
	_label.add_theme_font_size_override("font_size", 22)
	_label.position = Vector2(-14, -16)
	add_child(_label)
	# convite: dá pra PEGAR COM O MOUSE (o Match trata o clique)
	_hint = Label.new()
	_hint.text = "clique!"
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.position = Vector2(-17, 16)
	add_child(_hint)

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	# flutua + pisca quando está pra sumir
	_label.position.y = -16.0 + sin(_t * 3.4) * 3.0
	_hint.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 4.6))
	if _t > LIFE - 2.5:
		visible = fmod(_t, 0.24) < 0.15
	queue_redraw()

func _draw() -> void:
	var col: Color = KINDS.get(kind, {}).get("col", Color.WHITE)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	# halo pulsante + losango girando (moldura de "item especial")
	draw_circle(Vector2.ZERO, 16.0 + pulse * 5.0, Color(col.r, col.g, col.b, 0.16 + pulse * 0.10))
	var pts := PackedVector2Array()
	var r := 15.0 + pulse * 2.0
	for i in 5:
		var a := _t * 1.8 + TAU * float(i) / 4.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.85), 2.0)
	# sombra no chão
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
