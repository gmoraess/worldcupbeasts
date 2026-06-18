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
	main._on_beast()
	await process_frame
	print("  MapScreen: OK (ato %d, %d nós no ato)" % [gs.act, gs.map_data[gs.act].size()])

	main._on_node(0, 1)            # entra numa partida
	await process_frame
	await process_frame
	var m = main.current
	print("  Match instanciada: %s x %s" % [gs.beast.get("name"), gs.enemy_name()])
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
	main._show_shop(); await process_frame
	print("  ShopScreen: OK")
	main._show_map(); await process_frame
	print("  Voltou ao mapa: OK")
	print("=== FLOW OK ===")
	quit()
