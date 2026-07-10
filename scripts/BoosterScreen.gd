extends Control
## Pacote de figurinhas (estilo Balatro) no início da corrida: 3 pacotes; abre 1;
## revela 3 feras (sorteadas por raridade); escolhe 1 pro elenco (reservas).
signal booster_done

var packs: Array = []     # 3 pacotes, cada um com 3 ids
var opened := -1          # índice do pacote aberto (-1 = nenhum)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _i in 3:
		packs.append(GameState.open_pack(3))
	_build()

func _build() -> void:
	for c in get_children(): c.queue_free()
	add_child(UI.stone_bg())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	cc.add_child(col)

	if opened == -1:
		col.add_child(UI.clbl("🎴 PACOTE DE FIGURINHAS", 26, UI.GOLD2))
		col.add_child(UI.clbl("Escolha 1 dos 3 pacotes pra abrir.", 13, UI.RUNE2))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		for i in packs.size():
			row.add_child(_pack_btn(i))
	else:
		col.add_child(UI.clbl("✨ ABRIU! Escolha 1 fera", 26, UI.GOLD2))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		for id in packs[opened]:
			row.add_child(_beast_card(id))

func _pack_btn(i: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 190)
	b.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, UI.BRONZE, 3, 12, 10, 10))
	b.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 3, 12, 10, 10))
	b.pressed.connect(func(): opened = i; _build())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.clbl("🎴", 56, UI.GOLD2))
	v.add_child(UI.clbl("Pacote %d" % (i + 1), 14, UI.RUNE))
	b.add_child(v)
	return b

func _beast_card(id: String) -> Control:
	var data: Dictionary = GameState.POOL[id]
	var rcor: Color = GameState.rarity_color(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 210)
	b.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, rcor, 3, 12, 8, 8))
	b.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 3, 12, 8, 8))
	b.pressed.connect(func(): GameState.recruit(id); booster_done.emit())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new(); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(UI.icon("res://assets/beasts/%s.png" % id, Vector2(112, 130), data["crest"]))
	v.add_child(cc)
	v.add_child(UI.clbl(data["nome"], 13, UI.GOLD2))
	v.add_child(UI.clbl("%s · %s" % [GameState.RARITY[GameState.rarity(id)]["nome"], data["papel"]], 11, rcor))
	b.add_child(v)
	return b
