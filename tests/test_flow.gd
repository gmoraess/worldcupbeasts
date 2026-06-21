## Smoke do fluxo da corrida: instancia Main e navega seleção→mapa→partida +
## abre relíquia/evento/loja, checando que cada tela monta sem erro.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== SMOKE DE FLUXO ===")
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	print("  BeastSelect: OK")

	var gs := root.get_node("GameState")
	gs.start_run("foot")
	main._on_beast()              # → BoosterScreen
	await process_frame
	print("  BoosterScreen: OK")
	main.current.booster_done.emit()   # pula o pacote → mapa
	await process_frame
	print("  MapScreen: OK (ato %d, %d nós no ato)" % [gs.act, gs.map_data[gs.act].size()])

	main._on_node(0, 1)            # entra num nó de partida → Match (sem prep)
	await process_frame
	await process_frame
	var m = main.current
	print("  Match instanciada: %s x %s" % [gs.beast.get("nome"), gs.enemy_name()])
	m.clock = 5.0
	var safety := 0
	while is_instance_valid(m) and not m.over and safety < 30000:
		safety += 1
		await process_frame
	print("  Partida terminou: %d x %d" % [m.score["home"], m.score["away"]])

	# telas de meta montam sem erro?
	main._show_relic(func(_id): pass); await process_frame
	print("  RelicScreen: OK")
	main._show_event(); await process_frame
	print("  EventScreen: OK")

	# — TIER: comprar cópias sobe I→V nos limiares 1/2/4/8/16 —
	var tid := "urso"
	var t0: int = gs.tier_of(tid)
	for _i in 15: gs.add_copy(tid)        # 1 → 16 cópias
	print("  Tier de %s: %d → %d (esperado %d→5)" % [tid, t0, gs.tier_of(tid), t0])
	assert(gs.tier_of(tid) == 5, "16 cópias deveriam dar Tier V")
	assert(abs(gs.tier_mult(tid) - 1.32) < 0.001, "Tier V = +32%% (×1.32)")

	# — LOJA: ofertas montam, consumível comprado entra no inventário —
	print("  Ofertas: main=%d relic=%d cons=%d" % [gs.shop_main_offers(5).size(), gs.relic_offers(3).size(), gs.consumable_offers(2).size()])
	gs.gold = 999
	var cons_n: int = gs.consumables.size()
	gs.buy_consumable("adrenalina")
	assert(gs.consumables.size() == cons_n + 1, "consumível comprado deveria entrar no inventário")
	main._show_shop(func(): pass); await process_frame
	print("  ShopScreen: OK")
	main._show_map(); await process_frame
	print("  Voltou ao mapa: OK")
	print("=== FLOW OK ===")
	quit()
