class_name CardPool
extends Resource
## Todas as cartas de recompensa do jogo. Cada oferta (fim de fase) traz UMA carta por arma: a ordem das armas na tela é a
## ordem em que elas aparecem aqui. Hoje são 2 cartas por arma (a run tem 2 fins de fase com recompensa), então cada uma é forte.

@export var cards: Array[CardData] = []


## A oferta do fim de fase: 1 carta por arma, sorteada entre as que o jogador ainda não pegou dessa arma. Se uma arma já
## esgotou as suas, volta a oferecer qualquer uma dela (a oferta nunca fica sem carta para uma arma).
func offer(owned: Array[CardData]) -> Array[CardData]:
	var by_weapon: Dictionary = {} # caminho da arma -> Array[CardData], na ordem de aparição
	for card in cards:
		if card == null or card.weapon == null:
			continue
		var key := card.weapon.resource_path if card.weapon.resource_path != "" else str(card.weapon.get_instance_id())
		if not by_weapon.has(key):
			by_weapon[key] = [] as Array[CardData]
		(by_weapon[key] as Array[CardData]).append(card)
	var result: Array[CardData] = []
	for key in by_weapon:
		var group: Array[CardData] = by_weapon[key]
		var fresh: Array[CardData] = []
		for card in group:
			if not owned.has(card):
				fresh.append(card)
		var source := fresh if not fresh.is_empty() else group
		result.append(source.pick_random())
	return result
