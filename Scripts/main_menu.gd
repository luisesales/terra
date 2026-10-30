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


## Item 0 = aleatório (sorteia a cada "Iniciar"); os demais seguem GameController.MAPS. A escolha fica guardada entre as partidas.
func _fill_maps() -> void:
	_map.add_item("Aleatório")
	for map in GameController.MAPS:
		_map.add_item(map["name"])
	_map.select(GameController.map_choice + 1) # MAP_RANDOM (-1) cai no item 0


func _on_map_selected(index: int) -> void:
	GameController.map_choice = index - 1


func _on_start_pressed() -> void:
	GameController.roll_map()
	GameController.start_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)
