extends Control
## Escolha de relíquia — 1 de 3 (cada uma mexe em parâmetros físicos).
signal relic_chosen(relic_id: String)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.bg_rect())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	cc.add_child(col)
	col.add_child(UI.clbl("🎁 RECOMPENSA — escolha 1 de 3", 22, UI.GOLD2))
	col.add_child(UI.clbl("Relíquias de time e Jokers de pontuação (Balatro).", 12, UI.RUNE2))
	var choices: Array = GameState.reward_choices(3)
	if choices.is_empty():
		col.add_child(UI.clbl("Sem recompensas disponíveis.", 13, UI.RUNE2))
		var sk := UI.gold_btn("Continuar →")
		sk.pressed.connect(func(): relic_chosen.emit(""))
		col.add_child(sk)
		return
	for item in choices:
		col.add_child(_relic_card(item))

func _relic_card(item: Dictionary) -> Control:
	var data: Dictionary = GameState.reward_info(item)
	var kind: String = data["kind"]
	var accent: Color = UI.GOLD2 if kind == "joker" else (Color("5fc96b") if kind == "gear" else UI.BRONZE)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(460, 76)
	btn.add_theme_stylebox_override("normal",  UI.sbf(UI.PANEL, accent, 2, 11, 12, 8))
	btn.add_theme_stylebox_override("hover",   UI.sbf(UI.PANEL, UI.GOLD, 2, 11, 12, 8))
	btn.add_theme_stylebox_override("pressed", UI.sbf(UI.PANEL2, UI.GOLD2, 2, 11, 12, 8))
	btn.pressed.connect(func(): GameState.take_reward(item); relic_chosen.emit(item["id"]))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var ic := CenterContainer.new(); ic.custom_minimum_size = Vector2(48, 0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(UI.clbl(data["ic"], 28, Color.WHITE))
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag: String = {"joker": "🃏 JOKER · ", "gear": "🦿 EQUIP · ", "relic": "🛡 RELÍQUIA · "}.get(kind, "")
	v.add_child(UI.lbl(tag + data["nome"], 15, UI.GOLD2))
	v.add_child(UI.lbl(data["desc"], 11, UI.RUNE2))
	h.add_child(v)
	return btn
