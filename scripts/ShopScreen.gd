extends Control
## Loja — comprar relíquias com ouro.
signal shop_done

const PRICE := 25
var offers: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offers = GameState.random_relic_choices(3)
	_build()

func _build() -> void:
	for c in get_children(): c.queue_free()
	add_child(UI.bg_rect())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	cc.add_child(col)
	col.add_child(UI.clbl("🛒 LOJA   ·   🪙 %d" % GameState.gold, 24, UI.GOLD2))
	if offers.is_empty():
		col.add_child(UI.clbl("Estoque esgotado.", 13, UI.RUNE2))
	for id in offers:
		col.add_child(_buy_card(id))
	var leave := UI.gold_btn("Sair →")
	leave.pressed.connect(func(): shop_done.emit())
	col.add_child(leave)

func _buy_card(id: String) -> Control:
	var data: Dictionary = GameState.RELICS[id]
	var box := UI.framed()
	box.custom_minimum_size = Vector2(470, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	h.add_child(UI.clbl(data["ic"], 26, Color.WHITE))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.lbl(data["name"], 14, UI.GOLD2))
	v.add_child(UI.lbl(data["desc"], 11, UI.RUNE2))
	h.add_child(v)
	var b := UI.gold_btn("🪙 %d" % PRICE)
	b.disabled = GameState.gold < PRICE
	b.pressed.connect(func():
		if GameState.gold >= PRICE:
			GameState.gold -= PRICE
			GameState.add_relic(id)
			offers.erase(id)
			_build())
	h.add_child(b)
	return box
