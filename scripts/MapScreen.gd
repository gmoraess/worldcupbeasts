extends Control
## Mapa roguelike — 3 atos, colunas e raias (estilo Slay the Spire).
signal node_chosen(target_col: int, target_lane: int)
signal organize_team

const ICONS := {"partida": "⚽", "elite": "💀", "bau": "🎁", "evento": "❓", "loja": "🛒", "boss": "👑"}
const NCOL := {"partida": Color("1e4a1e"), "elite": Color("4a1e1e"), "bau": Color("2a3a1a"),
	"evento": Color("1e2a4a"), "loja": Color("2a2a1e"), "boss": Color("3a1a0a")}
const NBORDER := {"partida": Color("3aa83a"), "elite": Color("c83a3a"), "bau": Color("8ac83a"),
	"evento": Color("3a8ac8"), "loja": Color("c8c83a"), "boss": Color("d8b25a")}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.bg_rect())
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(s, 14)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(_header())
	col.add_child(UI.clbl("━━━  ATO %d / 3  ━━━" % (GameState.act + 1), 13, UI.GOLD))
	col.add_child(_act_map())
	var tip := "Clique num nó iluminado para avançar."
	if GameState.col == -1: tip = "Escolha por onde entrar no ato."
	col.add_child(UI.clbl(tip, 11, UI.RUNE2))
	var org := UI.gold_btn("⚙ Organizar Time", 13)
	org.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	org.pressed.connect(func(): organize_team.emit())
	col.add_child(org)

func _header() -> Control:
	var pnl := UI.framed()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pnl.add_child(h)
	var bv := VBoxContainer.new()
	var bcc := CenterContainer.new()
	bcc.add_child(UI.icon(GameState.home_img(), Vector2(54, 62), GameState.beast.get("crest", "?")))
	bv.add_child(bcc)
	bv.add_child(UI.clbl(GameState.beast.get("nome", ""), 12, UI.GOLD2))
	h.add_child(bv)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(UI.lbl("Relíquias:", 10, UI.RUNE2))
	var rtxt := "—"
	if not GameState.relics.is_empty():
		rtxt = ""
		for r in GameState.relics:
			rtxt += GameState.RELICS[r]["ic"] + " "
	rv.add_child(UI.lbl(rtxt, 14, UI.RUNE))
	h.add_child(rv)
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_child(UI.clbl("🪙 %d" % GameState.gold, 14, UI.GOLD2))
	sv.add_child(UI.clbl("❤️ Repescagem" if GameState.extra_life else "💀 Sem repescagem", 10,
		Color("88ff88") if GameState.extra_life else Color("ff6666")))
	h.add_child(sv)
	return pnl

func _act_map() -> Control:
	var act_data: Array = GameState.map_data[GameState.act]
	var reachable: Array = GameState.reachable_next()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var labels := ["ENTRADA", "·", "·", "🎁 TESOURO", "·", "PRÉ-CHEFE", "CHEFE"]
	for c_idx in act_data.size():
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 8)
		cv.add_child(UI.clbl(labels[mini(c_idx, labels.size() - 1)], 9, UI.RUNE2))
		var nodes: Array = act_data[c_idx]
		if nodes.size() == 1:
			var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 70); cv.add_child(sp)
			cv.add_child(_node_btn(c_idx, 0, nodes[0], reachable))
		else:
			for l in nodes.size():
				cv.add_child(_node_btn(c_idx, l, nodes[l], reachable))
		row.add_child(cv)
	return row

func _node_btn(c_idx: int, l_idx: int, node: Dictionary, reachable: Array) -> Control:
	var tp: String = node.get("type", "partida")
	var visited: bool = node.get("visited", false)
	var is_cur: bool = (c_idx == GameState.col and (l_idx == GameState.lane or _is_boss(c_idx)))
	var can := false
	for pair in reachable:
		if pair[0] == c_idx and pair[1] == l_idx: can = true; break
	var bg: Color = NCOL.get(tp, UI.PANEL)
	var bd: Color = NBORDER.get(tp, UI.GOLD)
	if is_cur: bd = UI.GOLD2; bg = bg.lightened(0.2)
	elif visited: bg = bg.darkened(0.45); bd = Color("3a2a18")
	elif not can: bg = bg.darkened(0.5); bd = Color("2a1a08")
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 118)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not can
	btn.add_theme_stylebox_override("normal",   UI.sbf(bg, bd, 2, 12, 4, 4))
	btn.add_theme_stylebox_override("hover",    UI.sbf(bg.lightened(0.1), UI.GOLD2, 2, 12, 4, 4))
	btn.add_theme_stylebox_override("pressed",  UI.sbf(bg, UI.GOLD, 2, 12, 4, 4))
	btn.add_theme_stylebox_override("disabled", UI.sbf(bg, bd, 1, 12, 4, 4))
	btn.modulate = Color(1, 1, 1, 0.5) if (visited and not is_cur) else Color.WHITE
	btn.pressed.connect(func(): node_chosen.emit(c_idx, l_idx))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ncc := CenterContainer.new()
	ncc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ncc.add_child(UI.icon("res://assets/icons/node_%s.png" % tp, Vector2(46, 46), ICONS.get(tp, "?")))
	v.add_child(ncc)
	v.add_child(UI.clbl(tp.to_upper(), 9, UI.RUNE2))
	var enemy: Dictionary = node.get("enemy", {})
	if not enemy.is_empty():
		var nm := UI.clbl(enemy.get("crest", "") + " " + enemy.get("name", ""), 8, UI.RUNE)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nm)
	if is_cur:
		v.add_child(UI.clbl("← VOCÊ", 8, UI.GOLD2))
	btn.add_child(v)
	return btn

func _is_boss(c_idx: int) -> bool:
	return GameState.map_data[GameState.act][c_idx].size() == 1
