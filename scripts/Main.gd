extends Control
## Roteador da corrida (Etapa 2B): seleção → mapa → partida/evento/relíquia/loja
## → resultado. Telas emitem sinais; aqui a gente roteia. A partida (Node2D) é
## instanciada como filha e avisa o fim por sinal.
const BeastSelect = preload("res://scripts/BeastSelect.gd")
const PrepScreen = preload("res://scripts/PrepScreen.gd")
const RelicScreen = preload("res://scripts/RelicScreen.gd")
const ShopScreen = preload("res://scripts/ShopScreen.gd")
const TitleScreen = preload("res://scripts/TitleScreen.gd")
const SettingsScreen = preload("res://scripts/SettingsScreen.gd")
const DifficultyScreen = preload("res://scripts/DifficultyScreen.gd")
const StartRewardScreen = preload("res://scripts/StartRewardScreen.gd")
const TowerScreen = preload("res://scripts/TowerScreen.gd")
const MatchScene = preload("res://scenes/Match.tscn")

var current: Node = null
var _fade: ColorRect              # véu do fade entre telas (juice aprovado)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# NÃO engolir cliques: o Main cobre a tela inteira e, com o filtro padrão
	# (STOP), consumia todo clique fora de botões — o _unhandled_input da
	# partida (pegar power-up, passe no botão direito) nunca recebia o evento.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	randomize()
	Settings.apply_all()         # aplica opções salvas (tela cheia, vsync, volumes)
	# véu de transição: acima de tudo, ignora mouse
	var lay := CanvasLayer.new()
	lay.layer = 120
	add_child(lay)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(_fade)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.music_menu()             # tema de menu (bus Music — slider nas Configurações)
	_show_title()

## Fade-in rápido (~0.15s) — cobre o corte seco na troca de tela.
func _fade_in() -> void:
	if _fade == null: return
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.15)

# --- TELA INICIAL / MENU ---
func _show_title() -> void:
	_switch(TitleScreen.new(), {
		"play_pressed": _new_game,
		"continue_pressed": _continue_run,
		"settings_pressed": _show_settings,
		"quit_pressed": _quit_game,
	})

func _new_game() -> void:
	GameState.clear_save()       # começo limpo; o save é regravado ao chegar no mapa
	_show_beast_select()

func _continue_run() -> void:
	if GameState.load_run() and not GameState.ladder.is_empty():
		_show_tower()
	else:
		_show_beast_select()

func _show_settings() -> void:
	_switch(SettingsScreen.new(), {"closed": _show_title})

func _quit_game() -> void:
	get_tree().quit()

# --- transições ---
func _switch(node: Node, sigs: Dictionary) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)
	for s in sigs:
		node.connect(s, sigs[s])
	_fade_in()
	# telas de menu (Control) voltam pro tema de menu; a partida (Node2D)
	# escolhe a própria faixa no _ready dela (match A/B, clímax)
	if node is Control:
		Sfx.music_menu()

func _show_beast_select() -> void:
	_switch(BeastSelect.new(), {"beast_selected": _on_beast})

# escolheu a capitã → escolhe a DIFICULDADE (torre estilo MK)
func _on_beast() -> void:
	_switch(DifficultyScreen.new(), {"difficulty_chosen": _on_difficulty})

func _on_difficulty(diff: String) -> void:
	GameState.start_tower(diff)
	_show_start_reward()

# recompensa de abertura (1 pacote / 1 relíquia / 3 cartas) → torre
func _show_start_reward() -> void:
	_switch(StartRewardScreen.new(), {"reward_done": _show_tower})

# TORRE: anima a subida, dá highlight no oponente, "Lutar" → partida
func _show_tower() -> void:
	GameState.save_run()         # auto-save: o "Continuar" retoma na torre
	_switch(TowerScreen.new(), {"fight_pressed": _show_match})

func _show_match() -> void:
	GameState.enter_match()      # define o oponente atual do degrau
	_switch(MatchScene.instantiate(), {"match_over": _on_match_over})

func _on_match_over(home_won: bool) -> void:
	var r: String = GameState.complete_tower(home_won)
	match r:
		"victory":
			GameState.clear_save()
			_msg("🏆 CAMPEÃO!", "%s chegou ao topo da torre e conquistou a Copa dos Mil Anos!" % GameState.beast.get("nome", ""), _show_title, true)
		"defeat":
			GameState.clear_save()
			_msg("💀 DERROTA", "Você caiu da torre. Fim da jornada de %s." % GameState.beast.get("nome", ""), _show_title, false)
		"vida_extra":
			_msg("❤️ VIDA EXTRA", "Você perdeu, mas usou sua Vida Extra! Encare o mesmo oponente de novo.", _show_tower, true)
		"continue":
			# venceu → loja (com gerenciamento de time) → sobe a torre pro próximo
			_show_shop(_show_tower)

func _show_shop(after: Callable) -> void:
	_switch(ShopScreen.new(), {"shop_done": after, "organize_team": _show_prep_from_shop})

# gerenciamento de time a partir da loja (volta pra loja ao terminar)
func _show_prep_from_shop() -> void:
	var p := PrepScreen.new()
	p.standalone = true
	_switch(p, {"prep_done": func(): _show_shop(_show_tower)})

# --- telas simples de mensagem/resultado ---
func _msg(title: String, sub: String, cont: Callable, good: bool) -> void:
	if current != null: current.queue_free()
	current = Control.new()
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(current)
	_fade_in()
	Sfx.music_menu()
	current.add_child(UI.stone_bg())
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
