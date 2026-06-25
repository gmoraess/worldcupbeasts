## Smoke do fluxo da torre: Title → seleção → dificuldade → recompensa → torre →
## partida → loja. Checa que cada tela monta sem erro.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== SMOKE DE FLUXO ===")
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	print("  TitleScreen: OK")

	var gs := root.get_node("GameState")
	main._show_beast_select()
	await process_frame
	print("  BeastSelect: OK")

	gs.start_run("foot")
	main._on_beast()                  # → DifficultyScreen
	await process_frame
	print("  DifficultyScreen: OK")

	main._on_difficulty("normal")     # monta a torre → StartRewardScreen
	await process_frame
	print("  StartReward: OK (torre com %d oponentes)" % gs.tower_len())

	main.current.reward_done.emit()   # pula a recompensa → TowerScreen
	await process_frame
	print("  TowerScreen: OK (degrau %d)" % (gs.rung + 1))

	main._show_match()                # entra no oponente do degrau → Match
	await process_frame
	await process_frame
	var m = main.current
	print("  Match: %s x %s" % [gs.beast.get("nome"), gs.enemy_name()])
	m.clock = 5.0
	var safety := 0
	while is_instance_valid(m) and not m.over and safety < 30000:
		safety += 1
		await process_frame
	await process_frame
	await process_frame                # deixa _on_match_over rotear (loja/vida-extra)
	print("  Pós-partida roteou OK")

	# — TIER: comprar cópias sobe I→V nos limiares 1/2/4/8/16 —
	var tid := "urso"
	var t0: int = gs.tier_of(tid)
	for _i in 15: gs.add_copy(tid)
	assert(gs.tier_of(tid) == 5, "16 cópias deveriam dar Tier V")
	print("  Tier de %s: %d → %d" % [tid, t0, gs.tier_of(tid)])

	# — LOJA: monta e consumível comprado entra no inventário —
	gs.gold = 999
	var cons_n: int = gs.consumables.size()
	gs.buy_consumable("adrenalina")
	assert(gs.consumables.size() == cons_n + 1, "consumível comprado deveria entrar no inventário")
	main._show_shop(func(): pass)
	await process_frame
	print("  ShopScreen: OK")

	# — SAVE/LOAD da torre —
	gs.save_run()
	assert(gs.has_save(), "deveria ter save")
	var rung_before: int = gs.rung
	gs.rung = 999
	gs.load_run()
	assert(int(gs.rung) == rung_before, "load deveria restaurar o degrau")
	gs.clear_save()
	print("  Save/Load: OK")

	print("=== FLOW OK ===")
	quit()
