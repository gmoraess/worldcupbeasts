extends Control
## Escolha de DIFICULDADE (estilo torre do Mortal Kombat): cada opção mostra a
## escada de oponentes que você vai enfrentar (retratos), o tamanho e a força.

signal difficulty_chosen(diff: String)

const ORDER := ["facil", "normal", "hardcore"]
const TIER_COR := {"partida": Color("3aa83a"), "elite": Color("c83a3a"), "boss": Color("d8b25a")}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.stone_bg())
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(s, 16)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(UI.clbl("🏯  ESCOLHA A TORRE", 30, UI.GOLD2))
	col.add_child(UI.clbl("Suba derrotando cada oponente. Mais difícil = torre mais alta.", 13, UI.RUNE2))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	for diff in ORDER:
		row.add_child(_diff_card(diff))

func _diff_card(diff: String) -> Control:
	var cfg: Dictionary = GameState.DIFFICULTY[diff]
	var ladder: Array = GameState.preview_ladder(diff)
	var card := UI.framed(UI.PANEL, UI.BRONZE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UI.clbl("%s  %s" % [cfg["ic"], cfg["nome"]], 24, UI.GOLD2))
	v.add_child(UI.clbl("%d oponentes" % ladder.size(), 13, UI.GOLD))
	var d := UI.clbl(cfg["desc"], 11, UI.RUNE2)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(220, 0)
	v.add_child(d)

	# — escada de oponentes (de baixo pra cima: o topo é o chefe) —
	var tower := VBoxContainer.new()
	tower.add_theme_constant_override("separation", 4)
	tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tower)
	for i in range(ladder.size() - 1, -1, -1):
		tower.add_child(_rung_row(i, ladder[i]))

	var pick := UI.gold_btn("Escolher", 16)
	pick.pressed.connect(func(): difficulty_chosen.emit(diff))
	v.add_child(pick)
	return card

func _rung_row(i: int, node: Dictionary) -> Control:
	var enemy: Dictionary = node.get("enemy", {})
	var tp: String = node.get("type", "partida")
	var box := UI.framed(UI.PANEL2, TIER_COR.get(tp, UI.BRONZE))
	box.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL2, TIER_COR.get(tp, UI.BRONZE), 1, 8, 6, 3))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	var icc := CenterContainer.new()
	icc.add_child(UI.icon(GameState.enemy_img_path(enemy), Vector2(34, 38), enemy.get("crest", "?")))
	h.add_child(icc)
	var nm := UI.lbl("%d. %s" % [i + 1, enemy.get("name", "?")], 12, UI.RUNE)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	if tp == "boss":
		h.add_child(UI.lbl("👑", 16, UI.GOLD2))
	elif tp == "elite":
		h.add_child(UI.lbl("💀", 14, Color("c83a3a")))
	return box
