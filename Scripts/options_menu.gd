extends Control

const MENU_SCENE := "res://Scenes/MainMenu.tscn"

@onready var _sliders := {
	&"Master": $Center/Box/MasterRow/Slider,
	&"Music": $Center/Box/MusicRow/Slider,
	&"SFX": $Center/Box/SfxRow/Slider,
}
@onready var _back: Button = $Center/Box/BackButton


func _ready() -> void:
	for bus: StringName in _sliders:
		var slider: HSlider = _sliders[bus]
		slider.set_value_no_signal(AudioSettings.get_volume(bus))
		slider.value_changed.connect(func(value: float) -> void: AudioSettings.set_volume(bus, value))
	_back.pressed.connect(_go_back)
	_sliders[&"Master"].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
