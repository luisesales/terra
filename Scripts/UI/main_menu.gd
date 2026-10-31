extends Control

const GAME_SCENE := "res://Scenes/Game.tscn"
const OPTIONS_SCENE := "res://Scenes/OptionsMenu.tscn"

@onready var _start: Button = $Center/Box/StartButton
@onready var _options: Button = $Center/Box/OptionsButton
@onready var _map: OptionButton = $Center/Box/MapRow/MapOption


func _ready() -> void:
	GameController.enter_menu() # no menu o Enter (ação restart) é ignorado: ele já é ui_accept
	_fill_maps()
	_map.item_selected.connect(_on_map_selected)
	_start.pressed.connect(_on_start_pressed)
	_options.pressed.connect(_on_options_pressed)
	_start.grab_focus() # teclado e controle navegam pelo foco


## Fase em que a run começa (a 1 é a normal; as outras servem para testar). Segue GameController.PHASES e fica guardada entre as partidas.
func _fill_maps() -> void:
	for i in GameController.PHASES.size():
		_map.add_item("%d — %s" % [i + 1, GameController.PHASES[i]["name"]])
	_map.select(GameController.start_phase)


func _on_map_selected(index: int) -> void:
	GameController.start_phase = index


func _on_start_pressed() -> void:
	GameController.begin_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)
