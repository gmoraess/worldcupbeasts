extends RefCounted
## Doc 3 §5 — cartas de partida (poções/consumíveis de uso único). Mecânica de
## poção (Slay the Spire): efeito tático imediato, NÃO o motor da partida.
## alvo: "jogador_alvo" | "todos" | "time" | "pontuacao". tipo: "fisica" | "pontuacao".

const POOL := {
	# — físicas —
	"primeiros_socorros": {"nome": "Primeiros Socorros", "ic": "🩹", "tipo": "fisica", "alvo": "jogador_alvo",
		"desc": "Cura todo o HP de 1 jogador", "efeito": {"cura_hp": 999.0}},
	"adrenalina": {"nome": "Adrenalina", "ic": "💉", "tipo": "fisica", "alvo": "jogador_alvo",
		"desc": "+50% velocidade de 1 jogador (6s)", "efeito": {"vel_burst": 1.5, "dur_s": 6.0}},
	"folego_coletivo": {"nome": "Fôlego Coletivo", "ic": "🌬", "tipo": "fisica", "alvo": "todos",
		"desc": "+25% velocidade do time (5s)", "efeito": {"vel_burst": 1.25, "dur_s": 5.0}},
	"mira_certeira": {"nome": "Mira Certeira", "ic": "🎯", "tipo": "fisica", "alvo": "time",
		"desc": "Próxima finalização: +60% potência", "efeito": {"next_shot_pot": 1.6}},
	"segundo_folego": {"nome": "Segundo Fôlego", "ic": "🔋", "tipo": "fisica", "alvo": "time",
		"desc": "Recarrega a barra de fúria", "efeito": {"recarrega_furia": true}},
	"chute_teleguiado": {"nome": "Chute Teleguiado", "ic": "🚀", "tipo": "fisica", "alvo": "time",
		"desc": "Próxima finalização: +100% potência", "efeito": {"next_shot_pot": 2.0}},
	"doping": {"nome": "Doping", "ic": "⚗", "tipo": "fisica", "alvo": "todos",
		"desc": "+40% velocidade do time (8s)", "efeito": {"vel_burst": 1.4, "dur_s": 8.0}},
	"tonico": {"nome": "Tônico", "ic": "🧉", "tipo": "fisica", "alvo": "jogador_alvo",
		"desc": "Cura metade do HP de 1 jogador", "efeito": {"cura_hp": 90.0}},
	# — de pontuação (Balatro) —
	"catalisador": {"nome": "Catalisador", "ic": "🧪", "tipo": "pontuacao", "alvo": "pontuacao",
		"desc": "+2 mult nesta posse", "efeito": {"add_mult": 2.0}},
	"banca_dobrada": {"nome": "Banca Dobrada", "ic": "🎰", "tipo": "pontuacao", "alvo": "pontuacao",
		"desc": "×2 mult na posse atual", "efeito": {"x_mult": 2.0}},
	"hora_do_show": {"nome": "Hora do Show", "ic": "✨", "tipo": "pontuacao", "alvo": "pontuacao",
		"desc": "+40 chips na posse atual", "efeito": {"chips": 40}},
	"festival": {"nome": "Festival", "ic": "🎆", "tipo": "pontuacao", "alvo": "pontuacao",
		"desc": "×3 mult na posse atual", "efeito": {"x_mult": 3.0}},
	"combo": {"nome": "Combo", "ic": "🔗", "tipo": "pontuacao", "alvo": "pontuacao",
		"desc": "+1 mult e +25 chips na posse", "efeito": {"add_mult": 1.0, "chips": 25}},
	"jackpot": {"nome": "Jackpot", "ic": "💰", "tipo": "pontuacao", "alvo": "pontuacao",
		"desc": "+70 chips na posse atual", "efeito": {"chips": 70}},
}

## Mão inicial: n cartas aleatórias do pool (MVP — depois vem da loja/corrida).
static func random_hand(n: int = 3) -> Array:
	var ids: Array = POOL.keys()
	ids.shuffle()
	return ids.slice(0, mini(n, ids.size()))
