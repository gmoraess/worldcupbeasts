extends Control
## Roteador da corrida (Etapa 2B): seleção → mapa → partida/evento/relíquia/loja
## → resultado. Telas emitem sinais; aqui a gente roteia. A partida (Node2D) é
## instanciada como filha e avisa o fim por sinal.
const BeastSelect = preload("res://scripts/BeastSelect.gd")
const MapScreen = preload("res://scripts/MapScreen.gd")
const PrepScreen = preload("res://scripts/PrepScreen.gd")
const RelicScreen = preload("res://scripts/RelicScreen.gd")
const EventScreen = preload("res://scripts/EventScreen.gd")
const ShopScreen = preload("res://scripts/ShopScreen.gd")
const MatchScene = preload("res://scenes/Match.tscn")

var current: Node = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	randomize()
	_show_beast_select()

# --- transições ---
func _switch(node: Node, sigs: Dictionary) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)
	for s in sigs:
		node.connect(s, sigs[s])

func _show_beast_select() -> void:
	_switch(BeastSelect.new(), {"beast_selected": _on_beast})

func _on_beast() -> void:
	_show_map()

func _show_map() -> void:
	_switch(MapScreen.new(), {"node_chosen": _on_node})

func _on_node(c: int, l: int) -> void:
	var node: Dictionary = GameState.enter_node(c, l)
	match node.get("type", ""):
		"partida", "elite", "boss": _show_prep()
		"bau": _show_relic(func(_id): _show_map())
		"evento": _show_event()
		"loja": _show_shop()
		_: _show_map()

func _show_prep() -> void:
	_switch(PrepScreen.new(), {"prep_done": _show_match})

func _show_match() -> void:
	_switch(MatchScene.instantiate(), {"match_over": _on_match_over})

func _on_match_over(home_won: bool) -> void:
	var r: String = GameState.complete_node(home_won)
	match r:
		"victory": _msg("🏆 CAMPEÃO!", "%s conquistou a Copa dos Mil Anos!" % GameState.beast.get("nome", ""), _show_beast_select, true)
		"defeat": _msg("💀 DERROTA", "%s caiu. Fim da jornada." % GameState.beast.get("nome", ""), _show_beast_select, false)
		"repechage": _msg("❤️ REPESCAGEM", "Você perdeu, mas tinha uma vida extra. Segue na Copa!", _show_map, true)
		"act_clear":
			# boss vencido → recompensa de relíquia, depois anuncia o ato e segue
			_show_relic(func(_id): _msg("👑 ATO %d / 3" % GameState.act, "Ato anterior conquistado! Avance.", _show_map, true))
		"continue":
			var tp: String = GameState.current_node.get("type", "")
			if home_won and tp in ["elite", "boss"]:
				_show_relic(func(_id): _show_map())
			else:
				_show_map()

func _show_relic(after: Callable) -> void:
	_switch(RelicScreen.new(), {"relic_chosen": after})

func _show_event() -> void:
	_switch(EventScreen.new(), {"event_done": func(): _show_map()})

func _show_shop() -> void:
	_switch(ShopScreen.new(), {"shop_done": func(): _show_map()})

# --- telas simples de mensagem/resultado ---
func _msg(title: String, sub: String, cont: Callable, good: bool) -> void:
	if current != null: current.queue_free()
	current = Control.new()
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(current)
	current.add_child(UI.bg_rect())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current.add_child(cc)
	var pnl := UI.framed(UI.PANEL2, UI.GOLD)
	cc.add_child(pnl)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	pnl.add_child(v)
	v.add_child(UI.clbl(title, 30, UI.GOLD2 if good else Color("ff6b6b")))
	var sl := UI.clbl(sub, 14, UI.RUNE2)
	sl.custom_minimum_size = Vector2(440, 0)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var b := UI.gold_btn("Continuar →")
	b.pressed.connect(func(): cont.call())
	v.add_child(b)
