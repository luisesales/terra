extends Node
## Estado global da run. É autoload: NÃO reinicia junto com a cena, então tudo é zerado explicitamente em _reset().

signal run_started
signal boss_window_started
signal run_won
signal player_died
signal player_hp_changed(hp: int)
signal ammo_changed(ammo: int, magazine_size: int)

enum State { MENU, PLAYING, DEAD, WON }

const RUN_DURATION := 600.0 ## 10 min
const BOSS_WINDOW := 180.0 ## o chefe entra nos últimos 3 min (7:00 a 10:00)

const MAP_RANDOM := -1
## Mapas jogáveis (cenas geradas por Tools/maps/build_worlds.py). A ordem é a do menu.
const MAPS := [
	{"name": "Floresta", "scene": "res://Scenes/Worlds/WorldSoil.tscn"},
	{"name": "Deserto", "scene": "res://Scenes/Worlds/WorldDesert.tscn"},
	{"name": "Escritório", "scene": "res://Scenes/Worlds/WorldOffice.tscn"},
]

var state := State.MENU
var elapsed := 0.0
## Escolha do menu (índice em MAPS ou MAP_RANDOM). Fica entre as partidas.
var map_choice := MAP_RANDOM
## Mapa da partida em andamento (-1 = ainda não sorteado). O Enter reinicia no MESMO mapa; só o menu sorteia de novo.
var current_map := -1
var boss_window_open := false
var ammo := 0
var magazine_size := 0
var player_hp := 0:
	set(value):
		player_hp = value
		player_hp_changed.emit(player_hp)
		if player_hp <= 0 and state == State.PLAYING:
			state = State.DEAD
			player_died.emit()

var _restarting := false


func _process(delta: float) -> void:
	if state == State.PLAYING:
		advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	# No menu principal o Enter já é ui_accept: ignora.
	if state != State.MENU and event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		restart_run()


func time_remaining() -> float:
	return RUN_DURATION - elapsed


func advance(delta: float) -> void:
	elapsed += delta
	if not boss_window_open and elapsed >= RUN_DURATION - BOSS_WINDOW:
		boss_window_open = true
		boss_window_started.emit()
	if elapsed >= RUN_DURATION:
		elapsed = RUN_DURATION
		state = State.WON
		run_won.emit()


func report_ammo(current: int, magazine: int) -> void:
	ammo = current
	magazine_size = magazine
	ammo_changed.emit(ammo, magazine_size)


## Fixa o mapa da partida: o escolhido no menu ou, em "aleatório", um sorteado.
func roll_map() -> int:
	current_map = map_choice if map_choice >= 0 and map_choice < MAPS.size() else randi() % MAPS.size()
	return current_map


## Chamado pelo menu principal: o autoload lembra o estado da última run (WON/DEAD) e o Enter precisa ser ignorado ali.
func enter_menu() -> void:
	current_map = -1
	state = State.MENU
	elapsed = 0.0
	boss_window_open = false
	player_hp = 0
	ammo = 0
	magazine_size = 0


## Zera tempo e estado. Vida e munição NÃO: o Player as informa no próprio _ready, que roda antes do _ready da cena de jogo.
func start_run() -> void:
	elapsed = 0.0
	boss_window_open = false
	state = State.PLAYING
	run_started.emit()


## O autoload sobrevive ao reload da cena, então tudo é zerado aqui; o novo Player informa vida e munição de novo.
func restart_run() -> void:
	if _restarting:
		return
	_restarting = true
	state = State.MENU # antes de zerar a vida, para o setter não contar como morte
	player_hp = 0
	ammo = 0
	magazine_size = 0
	start_run()
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	_restarting = false
