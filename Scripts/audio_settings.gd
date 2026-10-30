extends Node
## Volume por bus (Master, Music, SFX) com persistência em user://settings.cfg. Autoload.
## O valor é linear de 0 a 1; 0 = mudo.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
const DEFAULT_VOLUME := 1.0
const MIN_LINEAR := 0.0001 ## evita linear_to_db(0) = -inf; abaixo disso o bus é mutado

var _volumes := {}


func _ready() -> void:
	load_settings()


func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, DEFAULT_VOLUME)


func set_volume(bus: StringName, value: float, save := true) -> void:
	value = clampf(value, 0.0, 1.0)
	_volumes[bus] = value
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("AudioSettings: bus '%s' não existe (confira default_bus_layout.tres)" % bus)
		return
	AudioServer.set_bus_mute(index, value < MIN_LINEAR)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, MIN_LINEAR)))
	if save:
		save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(SETTINGS_PATH) == OK # sem arquivo = tudo no padrão
	for bus in BUSES:
		set_volume(bus, config.get_value(SECTION, String(bus), DEFAULT_VOLUME) if loaded else DEFAULT_VOLUME, false)


func save_settings() -> void:
	var config := ConfigFile.new()
	for bus in BUSES:
		config.set_value(SECTION, String(bus), get_volume(bus))
	config.save(SETTINGS_PATH)
