class_name Confetti
extends Node2D
## Estouro de confete (estilo Vampire Survivors/Balatro): retângulos coloridos
## voando com gravidade, giro e fade. Sem timers — tudo contado no _process,
## e o nó se libera sozinho no fim (seguro se a tela for trocada no meio).

const COLORS: Array[Color] = [
	Color("f3d24a"), Color("e05263"), Color("4a90d9"),
	Color("5fc96b"), Color("e08a3a"), Color("b06ae0"), Color("ecebe2"),
]
const GRAV := 720.0
const LIFE := 1.5

var _pieces: Array = []       # {p, v, col, rot, vrot, sz, t}
var _t := 0.0

## Cria e dispara num pai qualquer (Control ou Node2D), na posição local dada.
static func burst(parent: Node, pos: Vector2, n: int = 70, power: float = 380.0) -> void:
	var c := Confetti.new()
	c.position = pos
	c.z_index = 300
	parent.add_child(c)
	c._spawn(n, power)
	var sfx := c.get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("pop")

func _spawn(n: int, power: float) -> void:
	for i in n:
		var ang := randf_range(-PI, PI)
		# viés pra cima: estouro de festa, não bola de pelos
		var v := Vector2(cos(ang), sin(ang)) * randf_range(power * 0.25, power)
		v.y -= power * 0.55
		_pieces.append({
			"p": Vector2.ZERO, "v": v,
			"col": COLORS[randi() % COLORS.size()],
			"rot": randf_range(-PI, PI), "vrot": randf_range(-9.0, 9.0),
			"sz": Vector2(randf_range(3.0, 6.0), randf_range(2.0, 3.5)),
			"t": randf_range(0.0, 0.25),      # nascem defasados (chuvisco)
		})

func _process(delta: float) -> void:
	_t += delta
	for pc in _pieces:
		pc["t"] += delta
		if pc["t"] < 0.0: continue
		var v: Vector2 = pc["v"]
		v.y += GRAV * delta
		v *= 1.0 - 1.4 * delta               # arrasto do ar (flutua no fim)
		pc["v"] = v
		pc["p"] += v * delta
		pc["rot"] += pc["vrot"] * delta
	queue_redraw()
	if _t > LIFE + 0.3:
		queue_free()

func _draw() -> void:
	for pc in _pieces:
		var t: float = pc["t"]
		if t < 0.0: continue
		var a := clampf(1.0 - (t - LIFE * 0.55) / (LIFE * 0.45), 0.0, 1.0)
		if a <= 0.0: continue
		var col: Color = pc["col"]
		col.a = a
		var sz: Vector2 = pc["sz"]
		# "vira" no ar: a largura oscila (fita de papel girando)
		sz.x *= absf(sin(pc["rot"])) * 0.8 + 0.2
		draw_set_transform(pc["p"], pc["rot"], Vector2.ONE)
		draw_rect(Rect2(-sz / 2.0, sz), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
