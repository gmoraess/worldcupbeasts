extends Control
## Torre estilo Mortal Kombat: mostra a escada de oponentes, ANIMA o jogador
## subindo até o degrau atual, dá highlight no próximo oponente e oferece "Lutar".

signal fight_pressed

const TIER_COR := {"partida": Color("3aa83a"), "elite": Color("c83a3a"), "boss": Color("d8b25a")}

var _rows: Array = []          # PanelContainers por degrau (de baixo p/ cima na tela)
var _marker: Label = null
var _fight_btn: Button = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.bg_rect())
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(s, 16)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)

	var cfg: Dictionary = GameState.DIFFICULTY.get(GameState.difficulty, {})
	col.add_child(UI.clbl("🏯  TORRE — %s" % cfg.get("nome", ""), 26, UI.GOLD2))
	col.add_child(UI.clbl("Degrau %d / %d   ·   🪙 %d   ·   %s" % [
		GameState.rung + 1, GameState.tower_len(), GameState.gold,
		"❤️ Vida Extra" if GameState.extra_life else "💀 Sem Vida Extra"], 13, UI.GOLD))

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)

	var ladder: Array = GameState.ladder
	_rows.resize(ladder.size())
	for i in range(ladder.size() - 1, -1, -1):     # topo (chefe) em cima
		var rowc := _rung_row(i, ladder[i])
		_rows[i] = rowc
		list.add_child(rowc)

	_fight_btn = UI.gold_btn("⚔  LUTAR", 20)
	_fight_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fight_btn.disabled = true
	_fight_btn.modulate.a = 0.4
	_fight_btn.pressed.connect(func(): fight_pressed.emit())
	col.add_child(_fight_btn)

	call_deferred("_animate_climb")

func _rung_row(i: int, node: Dictionary) -> PanelContainer:
	var enemy: Dictionary = node.get("enemy", {})
	var tp: String = node.get("type", "partida")
	var cleared: bool = node.get("cleared", false)
	var cur: bool = (i == GameState.rung)
	var bd: Color = TIER_COR.get(tp, UI.BRONZE)
	var box := UI.framed(UI.PANEL2, bd)
	box.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL if cur else UI.PANEL2, bd, 2 if cur else 1, 10, 8, 5))
	box.modulate.a = 0.45 if cleared else 1.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	box.add_child(h)
	# marcador "VOCÊ" (preenchido só no degrau atual, via _animate_climb)
	var mk := UI.lbl("", 14, UI.GOLD2)
	mk.custom_minimum_size = Vector2(58, 0)
	if cur: _marker = mk
	h.add_child(mk)
	var icc := CenterContainer.new()
	icc.add_child(UI.icon(GameState.enemy_img_path(enemy), Vector2(44, 50), enemy.get("crest", "?")))
	h.add_child(icc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.lbl("%d. %s" % [i + 1, enemy.get("name", "?")], 14, UI.GOLD2 if cur else UI.RUNE))
	v.add_child(UI.lbl("alvo %d pts%s" % [int(enemy.get("target", 0)), "  ·  CHEFE 👑" if tp == "boss" else ("  ·  ELITE 💀" if tp == "elite" else "")], 10, UI.RUNE2))
	h.add_child(v)
	if cleared:
		h.add_child(UI.lbl("✔", 18, Color("88ff88")))
	return box

func _animate_climb() -> void:
	var cur: PanelContainer = _rows[GameState.rung] if GameState.rung < _rows.size() else null
	if cur == null:
		_enable_fight()
		return
	# pulso de highlight no oponente atual + marcador "VOCÊ ▶" surgindo
	cur.pivot_offset = cur.size / 2.0
	cur.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(cur, "scale", Vector2(1.06, 1.06), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cur, "scale", Vector2(1.0, 1.0), 0.18)
	tw.tween_callback(func(): if _marker != null: _marker.text = "VOCÊ ▶")
	tw.tween_callback(_enable_fight)

func _enable_fight() -> void:
	if _fight_btn == null: return
	_fight_btn.disabled = false
	_fight_btn.modulate.a = 1.0
