extends Node
## Volume por bus (Master, Music, SFX) com persistência em user://settings.cfg. Autoload.
## O valor é linear de 0 a 1; 0 = mudo.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
const DEFAULT_VOLUME := 1.0
const MIN_LINEAR := 0.0001 ## evita linear_to_db(0) = -inf; abaixo disso o bus é mutado

var _volumes := {}

var new_stream_player
var aux_music = null
var music
var music_pos : float = 0.0
@onready var ost = $Music
#MUSIC


#SFXs

#NOTES
##SFXs variables with "group" on the end of the name should be called by the new function play_random_sfx_from_group or be called with the position on array
##SFXs variables without "group" on the name should be called by the play_sfx function

#INTERACTION


#var ui_accept = {
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Accept/ui1.ogg"),
	#"volume" : 0.0,
	#"pitch" : [0.8,1.1],
#}
#
#var ui_refuse = {
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Refuse/ui1.ogg"),
	#"volume" : 0.0,
	#"pitch" : [1.1,1.2],
#}
#
#var ui_select_group = [
	#{
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Accept/ui1.ogg"),
	#"volume" : 0.0,
	#"pitch" : [0.8,1.1],
	#},
	#{
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Select/ui2.ogg"),
	#"volume" : 0.0,
	#"pitch" : [0.8,1.2],
	#},
	#{
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Select/ui3.ogg"),
	#"volume" : 0.0,
	#"pitch" : [0.8,1.1],
	#},
	#{
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Select/ui4.ogg"),
	#"volume" : 0.0,
	#"pitch" : [0.8,1.2],
	#},
	#{
	#"stream" : preload("res://Soundtracks/SFXs/UI/UI Select/ui5.ogg"),
	#"volume" : 0.0,
	#"pitch" : [0.8,1.1],
	#},
#]
#
 ##ENEMY
#
#var enemy_fire_magic_group = [
	#{
	#"stream" : preload("res://Soundtracks/SFXs/Enemy/Enemy Fire Magic/1st Attempt/fireMagic1.ogg"),
	#"volume" : -12.5,
	#"pitch" : [0.9,1.1],
	#},
	#{
	#"stream" : preload("res://Soundtracks/SFXs/Enemy/Enemy Fire Magic/1st Attempt/fireMagic2.ogg"),
	#"volume" : -12.5,
	#"pitch" : [0.9,1.1],
	#},
	#{
	#"stream" : preload("res://Soundtracks/SFXs/Enemy/Enemy Fire Magic/1st Attempt/fireMagic3.ogg"),
	#"volume" : -12.5,
	#"pitch" : [0.9,1.1],
	#},
#


 #PLAYER

func play_ost(audio):
	if audio != null:		
		aux_music = music
		ost.set_stream(audio)
		ost.play()
		

func start_sfx(audio, stream_player):		
	if audio["stream"] != null: 				
		stream_player.set_stream(audio["stream"])	
		stream_player.volume_db = audio["volume"]
		stream_player.bus = "SFX"	
		stream_player.process_mode = Node.PROCESS_MODE_ALWAYS
		stream_player.set_pitch_scale(randf_range(audio["pitch"][0], audio["pitch"][1]))
	return stream_player 		
	
func play_directional_sfx(audio,node):
	new_stream_player = StreamPlayer2D.new()
	node.add_child(start_sfx(audio,new_stream_player))
	
func play_sfx(audio):
	new_stream_player = StreamPlayer.new() 
	add_child(start_sfx(audio,new_stream_player))	
	
func play_controlled_sfx(audio):
	new_stream_player = StreamPlayer.new() 
	add_child(start_sfx(audio,new_stream_player))	
	return new_stream_player
	
func play_random_sfx_from_group(audios: Array):
	play_sfx(audios.pick_random())

		
func pause_resume_ost(timer): 	
	music_pos = ost.get_playback_position()
	ost.stop()
	await(get_tree().create_timer(timer).timeout)
	ost.play(music_pos)
		
func stop_ost():
	ost.stop()



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
