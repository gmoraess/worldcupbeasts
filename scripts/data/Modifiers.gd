extends RefCounted
## Doc 3 §4 — jokers (relíquias globais que afetam a PONTUAÇÃO), data-driven na
## gramática gatilho × condição × efeito. Adicionar um joker = 1 entrada aqui.
## efeito: chips (soma) · add_mult (soma) · x_mult (multiplica — é o que explode).

const JOKERS := {
	"furia_impar": {"nome": "Fúria Ímpar", "ic": "🎲", "desc": "Gol ímpar (1º, 3º…): ×3 mult",
		"gatilho": "ao_marcar_gol", "condicao": "gol_impar", "efeito": {"x_mult": 3.0}},
	"carrinho_eletrico": {"nome": "Carrinho Elétrico", "ic": "⚡", "desc": "Cada 5º desarme: +20 chips",
		"gatilho": "ao_desarmar", "condicao": "cada_5", "efeito": {"chips": 20}},
	"tiki_taka": {"nome": "Tiki-Taka", "ic": "🎯", "desc": "Jogada com 4+ passes: +50 chips",
		"gatilho": "ao_finalizar_jogada", "condicao": "passes_na_jogada_>=4", "efeito": {"chips": 50}},
	"violencia_recompensada": {"nome": "Violência Recompensada", "ic": "💥", "desc": "Nocaute: +2 mult",
		"gatilho": "ao_nocautear", "condicao": "", "efeito": {"add_mult": 2.0}},
	"matador": {"nome": "Matador", "ic": "🔥", "desc": "Todo gol: +1 mult na jogada",
		"gatilho": "ao_marcar_gol", "condicao": "", "efeito": {"add_mult": 1.0}},
	"artilharia": {"nome": "Artilharia", "ic": "💣", "desc": "Toda finalização: +8 chips",
		"gatilho": "ao_finalizar", "condicao": "", "efeito": {"chips": 8}},
}

## Resolve uma lista de ids em dicts de joker (com o id embutido p/ contadores).
static func resolve(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if JOKERS.has(id):
			var j: Dictionary = JOKERS[id].duplicate(true)
			j["id"] = id
			out.append(j)
	return out
