extends Node
## Estado global da run. É autoload: NÃO reinicia junto com a cena, então tudo é zerado explicitamente em _reset().
## A run tem 3 fases (PHASES), cada uma num mapa e com 10 min. Nas duas primeiras o tempo acabando abre o portal de saída;
## na última a vitória vem da morte do chefe-espelho.

signal run_started
signal boss_window_started
signal phase_cleared ## o tempo da fase acabou (fases 1 e 2): os inimigos morrem e o portal de saída abre
signal run_won ## o chefe final caiu
signal player_died
signal player_hp_changed(hp: int)
signal ammo_changed(ammo: int, magazine_size: int)
signal weapon_changed(display_name: String)
signal reloading_changed(active: bool)
signal boss_bar_changed(boss_name: String, hp: int, max_hp: int) ## barra de vida do chefe final, no topo do HUD
signal boss_bar_closed

enum State { MENU, PLAYING, CLEARED, TRANSITION, DEAD, WON }

const RUN_DURATION := 600.0 ## 10 min (cada fase)
const BOSS_WINDOW := 180.0 ## o chefe entra nos últimos 3 min da fase (7:00 a 10:00)

## Fases em ordem de dificuldade. "table" = SpawnTable da fase (quais inimigos e quando); a última fase é a do chefe final.
const PHASES := [
	{"name": "Floresta", "scene": "res://Scenes/Worlds/WorldSoil.tscn", "table": "res://Assets/Classes/Spawn Table/phase1.tres"},
	{"name": "Escritório", "scene": "res://Scenes/Worlds/WorldOffice.tscn", "table": "res://Assets/Classes/Spawn Table/phase2.tres"},
	{"name": "Deserto", "scene": "res://Scenes/Worlds/WorldDesert.tscn", "table": "res://Assets/Classes/Spawn Table/phase3.tres"},
]

var state := State.MENU
var elapsed := 0.0
## Fase em que a run começa (escolhida no menu; fica entre as partidas) e fase em andamento (índice em PHASES).
var start_phase := 0
var phase := 0
## Chefes comuns que já "caíram" nas fases anteriores: a fase seguinte sorteia entre os que faltam.
var used_bosses := PackedStringArray()
## Chefe sorteado na tentativa atual da fase (vira "usado" só quando a fase é concluída; reiniciar a fase sorteia de novo).
var phase_boss := ""
var boss_window_open := false
var ammo := 0
var magazine_size := 0
var weapon_name := "" ## arma equipada (o HUD mostra junto da munição)
var reloading := false
var boss_bar_active := false
var boss_bar_name := ""
var boss_bar_hp := 0
var boss_bar_max := 1
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
	# No menu principal o Enter já é ui_accept: ignora. Durante a travessia do portal a cena já está trocando.
	if state != State.MENU and state != State.TRANSITION and event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		restart_run()


func time_remaining() -> float:
	return RUN_DURATION - elapsed


func phase_data() -> Dictionary:
	return PHASES[clampi(phase, 0, PHASES.size() - 1)]


func is_final_phase() -> bool:
	return phase >= PHASES.size() - 1


func advance(delta: float) -> void:
	elapsed += delta
	if not boss_window_open and elapsed >= RUN_DURATION - BOSS_WINDOW:
		boss_window_open = true
		boss_window_started.emit()
	if elapsed >= RUN_DURATION:
		elapsed = RUN_DURATION
		# Na fase final o relógio para em 0:00 e a luta continua: só a morte do chefe-espelho vence.
		if not is_final_phase():
			state = State.CLEARED
			phase_cleared.emit()


## O chefe final caiu: vitória da run.
func win_run() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	run_won.emit()


func report_ammo(current: int, magazine: int) -> void:
	ammo = current
	magazine_size = magazine
	ammo_changed.emit(ammo, magazine_size)


func report_weapon(display_name: String) -> void:
	weapon_name = display_name
	weapon_changed.emit(weapon_name)


func report_reloading(active: bool) -> void:
	reloading = active
	reloading_changed.emit(active)


func report_boss(boss_name: String, hp: int, max_hp: int) -> void:
	boss_bar_active = true
	boss_bar_name = boss_name
	boss_bar_hp = hp
	boss_bar_max = maxi(max_hp, 1)
	boss_bar_changed.emit(boss_bar_name, boss_bar_hp, boss_bar_max)


func close_boss_bar() -> void:
	boss_bar_active = false
	boss_bar_closed.emit()


## Chamado pelo menu principal: o autoload lembra o estado da última run (WON/DEAD) e o Enter precisa ser ignorado ali.
func enter_menu() -> void:
	state = State.MENU
	elapsed = 0.0
	phase = start_phase
	used_bosses.clear()
	phase_boss = ""
	boss_window_open = false
	player_hp = 0
	ammo = 0
	magazine_size = 0
	weapon_name = ""
	reloading = false
	boss_bar_active = false


## Começa uma run nova na fase escolhida no menu (esquece os chefes de runs anteriores).
func begin_run() -> void:
	phase = clampi(start_phase, 0, PHASES.size() - 1)
	used_bosses.clear()
	start_run()


## Zera tempo e estado. Vida e munição NÃO: o Player as informa no próprio _ready, que roda antes do _ready da cena de jogo.
func start_run() -> void:
	elapsed = 0.0
	boss_window_open = false
	phase_boss = ""
	boss_bar_active = false
	state = State.PLAYING
	run_started.emit()


## Reinicia a fase atual (Hotline Miami: resposta imediata). Depois de uma vitória, recomeça a run na fase escolhida no menu.
func restart_run() -> void:
	if state == State.WON:
		phase = clampi(start_phase, 0, PHASES.size() - 1)
		used_bosses.clear()
	_reload_scene()


## O jogador entrou no portal de saída: trava a travessia (uma vez só). Quem chama faz o efeito e depois chama next_phase().
func begin_transition() -> bool:
	if state != State.CLEARED:
		return false
	state = State.TRANSITION
	return true


## Passa para a fase seguinte (o chefe comum desta fase vira "usado") e recarrega a cena de jogo.
func next_phase() -> void:
	if phase_boss != "" and not used_bosses.has(phase_boss):
		used_bosses.append(phase_boss)
	phase = mini(phase + 1, PHASES.size() - 1)
	_reload_scene()


## O autoload sobrevive ao reload da cena, então tudo é zerado aqui; o novo Player informa vida e munição de novo.
func _reload_scene() -> void:
	if _restarting:
		return
	_restarting = true
	state = State.MENU # antes de zerar a vida, para o setter não contar como morte
	player_hp = 0
	ammo = 0
	magazine_size = 0
	weapon_name = ""
	reloading = false
	start_run()
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	_restarting = false
