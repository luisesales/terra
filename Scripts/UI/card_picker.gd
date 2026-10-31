class_name CardPicker
extends CanvasLayer
## Tela de recompensa do fim de fase: uma carta por arma, o jogador escolhe uma (clique, teclas 1 a 3 ou controle).
## Pausa o jogo enquanto está aberta (process_mode = Always para ela mesma continuar funcionando) e despausa ao sair da árvore,
## seja porque a carta foi escolhida, seja porque a cena foi trocada/liberada por fora.

signal card_chosen(card: CardData)

const CARD_SCENE := preload("res://Scenes/Card.tscn")
const FADE_TIME := 0.25

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Center/Box/Title
@onready var _cards: HBoxContainer = $Root/Center/Box/Cards

var _views: Array[CardView] = []
var _chosen := false
var _paused_tree := false


## Chamar depois de add_child. `offer` vem de GameController.offer_cards(); a ordem na tela é a ordem da lista.
func open(offer: Array[CardData]) -> void:
	_title.text = "FASE %d CONCLUÍDA" % (GameController.phase + 1)
	for i in offer.size():
		var view := CARD_SCENE.instantiate() as CardView
		_cards.add_child(view)
		view.setup(offer[i], GameController.upgraded(offer[i].weapon), i + 1) # o "antes" já conta as cartas anteriores
		view.chosen.connect(_on_card_pressed)
		_views.append(view)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_TIME) # roda pausado: o nó é Always
	get_tree().paused = true
	_paused_tree = true
	if not _views.is_empty():
		_views[0].grab_focus() # teclado e controle navegam pelo foco


func card_count() -> int:
	return _views.size()


## Escolhe a carta de posição `index` (0 a 2). Só vale uma vez.
func choose(index: int) -> void:
	if _chosen or index < 0 or index >= _views.size():
		return
	_chosen = true
	card_chosen.emit(_views[index].card)


func _on_card_pressed(card: CardData) -> void:
	choose(_views.find_custom(func(view: CardView) -> bool: return view.card == card))


func _unhandled_input(event: InputEvent) -> void:
	for i in _views.size():
		if event.is_action_pressed("equip_weapon_%d" % (i + 1)): # as teclas 1 a 3 também escolhem
			get_viewport().set_input_as_handled()
			choose(i)
			return


func _exit_tree() -> void:
	if _paused_tree and get_tree() != null:
		get_tree().paused = false
