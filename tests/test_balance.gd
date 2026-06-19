## Passe de balanceamento (Etapa 2): round-robin IA×IA entre as feras + relatório.
## Mede paridade (win-rate), gols pró/contra, vantagem de mando e taxa de gols.
##
## Uso:
##   godot --headless --fixed-fps 60 --path . --script tests/test_balance.gd
##   ...                                                 -- K=20 LEN=90
## (--fixed-fps desacopla a sim do relógio de parede → roda em velocidade de CPU)
extends SceneTree

var K := 16            # partidas por par ordenado (mando alternado entre pares)
var LEN := 90.0        # duração do tempo regulamentar (s de jogo)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("K="):   K = int(a.substr(2))
		if a.begins_with("LEN="): LEN = float(a.substr(4))
	call_deferred("_run")

func _run() -> void:
	var ids: Array = GameState.BEASTS.keys()
	print("=== PASSE DE BALANCEAMENTO — round-robin %dx ===" % K)
	print("Feras: %s | tempo=%.0fs | partidas=%d\n" % [", ".join(ids), LEN, ids.size() * (ids.size() - 1) * K])

	# acumuladores por fera
	var W := {}; var D := {}; var L := {}; var GF := {}; var GA := {}
	for id in ids: W[id]=0; D[id]=0; L[id]=0; GF[id]=0; GA[id]=0
	# globais
	var home_goals := 0; var away_goals := 0; var n := 0
	var sd_count := 0                      # partidas decididas na morte súbita (empate no tempo)
	var goals_hist := {}                   # gols por lado (distribuição)
	var scrambles := 0                     # total de vezes que a trava anti-cabo-de-guerra atuou

	var t0 := Time.get_ticks_msec()
	for i in ids.size():
		for j in ids.size():
			if i == j: continue
			for _k in K:
				var r: Dictionary = await _play(ids[i], ids[j])
				var h: int = r["h"]; var a: int = r["a"]
				GF[ids[i]] += h; GA[ids[i]] += a
				GF[ids[j]] += a; GA[ids[j]] += h
				if h > a: W[ids[i]]+=1; L[ids[j]]+=1
				elif a > h: W[ids[j]]+=1; L[ids[i]]+=1
				else: D[ids[i]]+=1; D[ids[j]]+=1
				home_goals += h; away_goals += a; n += 1
				scrambles += r["scr"]
				if r["sd"]: sd_count += 1
				goals_hist[h] = goals_hist.get(h, 0) + 1
				goals_hist[a] = goals_hist.get(a, 0) + 1

	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var per_beast := (ids.size() - 1) * K * 2   # partidas que cada fera joga

	print("--- PARIDADE POR FERA (cada uma joga %d partidas) ---" % per_beast)
	print("%-9s %5s %5s %5s  %6s  %5s %5s  %s" % ["fera","V","E","D","win%","GF/j","GA/j","perfil"])
	for id in ids:
		var played: int = W[id]+D[id]+L[id]
		var wr := 100.0 * float(W[id]) / maxf(1.0, float(played))
		var tag: String = GameState.BEASTS[id].get("type","-")
		print("%-9s %5d %5d %5d  %5.1f%%  %4.2f  %4.2f  %s" % [
			id, W[id], D[id], L[id], wr,
			float(GF[id])/maxf(1.0,played), float(GA[id])/maxf(1.0,played), tag])

	print("\n--- GLOBAL ---")
	print("gols/partida (casa)  : %.2f" % (float(home_goals)/maxf(1.0,n)))
	print("gols/partida (fora)  : %.2f" % (float(away_goals)/maxf(1.0,n)))
	print("gols/partida (total) : %.2f   (alvo GDD: ~1–2/lado)" % (float(home_goals+away_goals)/maxf(1.0,n)))
	print("vantagem de mando    : %+.2f gols/partida" % (float(home_goals-away_goals)/maxf(1.0,n)))
	print("decididas na M.SÚBITA: %d/%d (%.0f%%)  ← empate no tempo regulamentar" % [sd_count, n, 100.0*sd_count/maxf(1.0,n)])
	print("anti-cabo-de-guerra  : %d disparos (%.2f/partida) ← bola presa >3s resolvida" % [scrambles, float(scrambles)/maxf(1.0,n)])
	var spread := _winrate_spread(ids, W, D, L)
	print("amplitude de win%%    : %.1f pts (max-min entre feras) — quanto menor, mais parelho" % spread)

	print("\ndistribuição de gols por lado:")
	var keys: Array = goals_hist.keys(); keys.sort()
	for g in keys:
		print("  %d gol(s): %s (%d)" % [g, "#".repeat(int(goals_hist[g]*40.0/maxf(1,n*2))), goals_hist[g]])

	print("\ntempo de simulação: %.1fs (%.2fs/partida)" % [elapsed, elapsed/maxf(1.0,n)])

	# CALIBRAÇÃO: "stats importam" — time forte deve vencer o fraco na MAIORIA.
	await _calibration()
	print("=== FIM ===")
	quit()

func _calibration() -> void:
	print("\n--- CALIBRAÇÃO: stats importam (forte vs fraco, %dx) ---" % K)
	var strong := {"fin": 1.35, "ctrl": 1.30, "des": 1.25, "def": 1.30, "spd": 1.25, "sta": 1.25}
	var weak   := {"fin": 0.75, "ctrl": 0.75, "des": 0.80, "def": 0.75, "spd": 0.85, "sta": 0.85}
	var sw := 0; var sg := 0; var wg := 0
	for _k in K:
		var r: Dictionary = await _play_stats(strong, weak)   # forte em casa
		if r["h"] > r["a"]: sw += 1
		sg += r["h"]; wg += r["a"]
	for _k in K:
		var r: Dictionary = await _play_stats(weak, strong)   # forte fora (mando invertido)
		if r["a"] > r["h"]: sw += 1
		sg += r["a"]; wg += r["h"]
	var total := K * 2
	print("forte venceu: %d/%d (%.0f%%)  — esperado: alto (>70%%)" % [sw, total, 100.0*sw/maxf(1.0,total)])
	print("gols: forte %.2f/j  ×  fraco %.2f/j" % [float(sg)/total, float(wg)/total])

func _play_stats(home_stats: Dictionary, away_stats: Dictionary) -> Dictionary:
	var gs := root.get_node("GameState")
	gs.start_run("cuirass")
	gs.beast["stats"] = home_stats.duplicate()
	gs.current_node = {"type": "partida", "enemy": {"name": "X", "stats": away_stats.duplicate()}}
	var m = load("res://scenes/Match.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.clock = LEN
	var safety := 0
	while not m.over and safety < 400000:
		safety += 1
		await process_frame
	var r := {"h": m.score["home"], "a": m.score["away"]}
	m.queue_free()
	await process_frame
	return r

func _winrate_spread(ids: Array, W: Dictionary, D: Dictionary, L: Dictionary) -> float:
	var hi := -1.0; var lo := 101.0
	for id in ids:
		var played: int = W[id]+D[id]+L[id]
		var wr := 100.0 * float(W[id]) / maxf(1.0, float(played))
		hi = maxf(hi, wr); lo = minf(lo, wr)
	return hi - lo

func _play(home_id: String, away_id: String) -> Dictionary:
	var gs := root.get_node("GameState")
	gs.start_run(home_id)   # home = perfil da fera (sem relíquias)
	gs.current_node = {"type": "partida", "enemy": {"name": away_id, "stats": GameState.BEASTS[away_id]["stats"].duplicate()}}
	var m = load("res://scenes/Match.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.clock = LEN
	var safety := 0
	while not m.over and safety < 400000:
		safety += 1
		await process_frame
	var r := {"h": m.score["home"], "a": m.score["away"], "sd": m.sudden_death, "scr": m._scrambles}
	m.queue_free()
	await process_frame
	return r
