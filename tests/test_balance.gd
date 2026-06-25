## Passe de balanceamento (Doc 3 — Balatro): mede PONTOS por capitã e taxa de
## acerto do alvo. Round-robin IA×IA (capitã ataca, squad inimigo resiste).
##
## Uso: godot --headless --fixed-fps 60 --path . --script tests/test_balance.gd -- K=20 LEN=90 ALVO=140
extends SceneTree

var K := 16
var LEN := 90.0
var ALVO := 140      # alvo de teste p/ medir taxa de acerto (independe do alvo do nó)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("K="):   K = int(a.substr(2))
		if a.begins_with("LEN="): LEN = float(a.substr(4))
		if a.begins_with("ALVO="): ALVO = int(a.substr(5))
		if a.begins_with("EF="): EF = float(a.substr(3))
	call_deferred("_run")

func _run() -> void:
	var ids: Array = GameState.HERO_IDS
	print("=== BALANCEAMENTO BALATRO — round-robin %dx (alvo de teste=%d) ===" % [K, ALVO])
	print("Capitãs: %s | tempo=%.0fs | partidas=%d\n" % [", ".join(ids), LEN, ids.size() * (ids.size() - 1) * K])

	var PTS := {}; var HITS := {}; var N := {}
	for id in ids: PTS[id] = 0; HITS[id] = 0; N[id] = 0
	var sumShots := 0.0; var sumBusts := 0.0; var sumGoals := 0.0; var zeroShot := 0; var nAll := 0
	var t0 := Time.get_ticks_msec()
	for i in ids.size():
		for j in ids.size():
			if i == j: continue
			for _k in K:
				var r: Dictionary = await _play(ids[i], ids[j])
				PTS[ids[i]] += r["pts"]; N[ids[i]] += 1
				if r["pts"] >= ALVO: HITS[ids[i]] += 1
				sumShots += r["shots"]; sumBusts += r["busts"]; sumGoals += r["goals"]
				if int(r["shots"]) == 0: zeroShot += 1
				nAll += 1

	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	print("--- POR CAPITÃ (atacando; cada uma joga %d partidas) ---" % ((ids.size() - 1) * K))
	print("%-9s %8s %8s  %s" % ["capitã", "pts/j", "acerto%", "papel"])
	var avgs: Array = []
	for id in ids:
		var avg := float(PTS[id]) / maxf(1.0, N[id])
		avgs.append(avg)
		print("%-9s %8.1f %7.0f%%  %s" % [id, avg, 100.0 * HITS[id] / maxf(1.0, N[id]), GameState.POOL[id]["papel"]])
	print("MÉDIA/partida: chutes=%.1f  busts=%.1f  gols=%.2f  | partidas SEM nenhum chute: %.0f%%" % [
		sumShots / maxf(1.0, nAll), sumBusts / maxf(1.0, nAll), sumGoals / maxf(1.0, nAll), 100.0 * zeroShot / maxf(1.0, nAll)])
	avgs.sort()
	var spread: float = avgs[avgs.size() - 1] - avgs[0]
	print("\namplitude de pts/j: %.1f (max-min entre capitãs) — quanto menor, mais parelho" % spread)
	print("tempo de simulação: %.1fs (%.2fs/partida)" % [elapsed, elapsed / maxf(1.0, ids.size() * (ids.size() - 1) * K)])

	await _calibration()
	print("=== FIM ===")
	quit()

func _calibration() -> void:
	print("\n--- CALIBRAÇÃO: stats importam (squad forte vs fraco, %dx) ---" % K)
	var strong := {"fin": 1.30, "ctrl": 1.30, "des": 1.25, "def": 1.30, "spd": 1.25, "sta": 1.25}
	var weak := {"fin": 0.78, "ctrl": 0.78, "des": 0.80, "def": 0.78, "spd": 0.85, "sta": 0.85}
	var strong5: Array = []; var weak5: Array = []
	for i in 5: strong5.append(strong.duplicate()); weak5.append(weak.duplicate())
	var sp := 0; var wp := 0
	for _k in K:
		sp += (await _play_squads(strong5, weak5))["pts"]    # forte ataca, fraco resiste
		wp += (await _play_squads(weak5, strong5))["pts"]    # fraco ataca, forte resiste
	print("pts/j  forte=%.1f  ×  fraco=%.1f  (forte deve pontuar bem mais)" % [float(sp) / K, float(wp) / K])

# — helpers —
var EF := 0.82      # fator do inimigo (ato-0 normal). Passe EF= pra simular outros nós.

func _play(home_id: String, away_id: String) -> Dictionary:
	var gs := root.get_node("GameState")
	gs.start_run(home_id)
	var away_ids: Array = gs.build_default_squad(away_id)
	return await _run_match(_scale_squad(gs.squad_profiles(away_ids), EF))

func _scale_squad(profiles: Array, f: float) -> Array:
	var out: Array = []
	for p: Dictionary in profiles:
		var s: Dictionary = {}
		for k in p: s[k] = p[k] * f
		out.append(s)
	return out

func _play_squads(home_profiles: Array, away_profiles: Array) -> Dictionary:
	var gs := root.get_node("GameState")
	gs.start_run("foot")
	gs.home_squad_override = home_profiles
	var r: Dictionary = await _run_match(away_profiles)
	gs.home_squad_override = []
	return r

func _run_match(away_squad: Array) -> Dictionary:
	var gs := root.get_node("GameState")
	gs.current_node = {"type": "partida", "enemy": {"name": "X", "leader": "", "squad": away_squad, "target": 999999}}
	var m = load("res://scenes/Match.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.clock = LEN                       # alvo gigante → a partida vai até o fim do tempo
	var safety := 0
	while not m.over and safety < 400000:
		safety += 1
		await process_frame
	var r := {"pts": m._score.total, "scr": m._scrambles,
		"shots": m._shots_taken, "busts": m._busts, "goals": m._goals_home}
	m.queue_free()
	await process_frame
	return r
