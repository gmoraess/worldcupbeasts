extends Control
## Seleção de fera — 4 perfis de stats. Clicar inicia a corrida.
signal beast_selected

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.bg_rect())
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(s, 28)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)
	col.add_child(UI.clbl("⚔ ESCOLHA SUA CAPITÃ", 30, UI.GOLD2))
	col.add_child(UI.clbl("A capitã lidera um time de 5 feras (montado do pool). Recrute o resto na corrida.", 13, UI.RUNE2))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	for id in GameState.HERO_IDS:
		grid.add_child(_card(id))

func _card(id: String) -> Control:
	var data: Dictionary = GameState.POOL[id]
	var st: Dictionary = data["stats"]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(520, 150)
	btn.add_theme_stylebox_override("normal",  UI.sbf(UI.PANEL, UI.BRONZE, 2, 12, 12, 10))
	btn.add_theme_stylebox_override("hover",   UI.sbf(UI.PANEL, UI.GOLD, 2, 12, 12, 10))
	btn.add_theme_stylebox_override("pressed", UI.sbf(UI.PANEL2, UI.GOLD2, 2, 12, 12, 10))
	btn.pressed.connect(func(): GameState.start_run(id); beast_selected.emit())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	# retrato (PNG) com fallback no emoji da crista
	var cc := CenterContainer.new(); cc.custom_minimum_size = Vector2(108, 0)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(UI.icon("res://assets/beasts/%s.png" % id, Vector2(100, 132), data["crest"]))
	h.add_child(cc)
	# textos
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.lbl(data["nome"] + "  ·  Capitã (" + data["papel"] + ")", 18, UI.GOLD2))
	v.add_child(UI.lbl("🎯%.2f  ⚽%.2f  🦵%.2f  🛡%.2f  ⚡%.2f" % [st["fin"], st["ctrl"], st["des"], st["def"], st["spd"]], 12, UI.RUNE))
	var lore := UI.lbl(data["lore"], 11, UI.RUNE2)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lore)
	# squad inicial (capitã + comuns que ela lidera)
	var squad_ids: Array = GameState.build_default_squad(id)
	var crests := ""
	for sid in squad_ids:
		crests += GameState.POOL[sid]["crest"] + " "
	v.add_child(UI.lbl("Time: " + crests, 13, UI.RUNE2))
	h.add_child(v)
	return btn
