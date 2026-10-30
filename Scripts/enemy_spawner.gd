class_name EnemySpawner
extends Node
## Faz nascer inimigos conforme a SpawnTable e o tempo do GameController: fora da câmera, dentro do mapa, fora de paredes.
## Aos 7:00 (abertura da janela do chefe) sorteia 1 chefe.

signal enemy_spawned(enemy: Enemy)

const ENEMY_SCENE := preload("res://Scenes/Enemy.tscn")
const BOSS_SCENE := preload("res://Scenes/Boss.tscn")
const CIRCLE_SCENE := preload("res://Scenes/SummoningCircle.tscn")
const SPAWN_TIME := 1.4 ## palpite: duração da fase de nascimento (sem colisão nem ataque)
const CIRCLE_FADE_IN := 0.8 ## palpite: o círculo aparece em ~0,8 s e o inimigo surge dentro dele depois disso
const ENEMY_FADE_IN := 0.4 ## palpite
const SPAWN_MARGIN := 80.0 ## palpite: folga, em px, além da borda da câmera
const BOSS_PRELOAD_LEAD := 20.0 ## palpite: segundos antes da janela para começar a carregar o chefe sorteado
const TRIES := 12

@export var table: SpawnTable

## Onde os inimigos entram na árvore (definido pelo Game).
var enemies_parent: Node
## Limites do mapa em coordenadas globais; vazio (sem área) = sem limite.
var bounds := Rect2()

var _timer := 0.0
var _boss_path := ""
var _boss_data: BossData
var _boss_requested := false
var _boss_pending := false
var _boss_done := false
var _warned_bounds := false
var _probe := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	_query.shape = _probe
	_query.collision_mask = 1 # World
	GameController.boss_window_started.connect(func() -> void: _boss_pending = not _boss_done)


func _physics_process(delta: float) -> void:
	if GameController.state == GameController.State.PLAYING:
		tick(delta)


## Separado do _physics_process para o teste poder acelerar o tempo.
func tick(delta: float) -> void:
	if table == null:
		return
	_preload_boss()
	if _boss_pending and _spawn_boss():
		_boss_pending = false
		_boss_done = true
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = table.interval_at(GameController.elapsed)
	if Enemy.all.size() >= table.max_alive:
		return
	var wave := table.pick(GameController.elapsed)
	if wave:
		spawn(wave.enemy)


func spawn(data: EnemyData) -> Enemy:
	var pos: Variant = _find_position(data.collision_radius)
	if pos == null:
		return null
	var circle := CIRCLE_SCENE.instantiate() as SummoningCircle
	enemies_parent.add_child(circle)
	circle.global_position = pos
	circle.play(data.tier, data.tier_color(), data.spawn_circle_size, SPAWN_TIME, CIRCLE_FADE_IN)
	var enemy := (BOSS_SCENE if data is BossData else ENEMY_SCENE).instantiate() as Enemy
	enemy.setup(data)
	enemy.global_position = pos
	enemies_parent.add_child(enemy)
	enemy.spawn_in(SPAWN_TIME, CIRCLE_FADE_IN, ENEMY_FADE_IN)
	enemy_spawned.emit(enemy)
	return enemy


func _preload_boss() -> void:
	if _boss_requested or table.boss_paths.is_empty():
		return
	if GameController.elapsed >= GameController.RUN_DURATION - GameController.BOSS_WINDOW - BOSS_PRELOAD_LEAD:
		_boss_requested = true
		_boss_path = table.boss_paths[randi() % table.boss_paths.size()]
		ResourceLoader.load_threaded_request(_boss_path)


func _spawn_boss() -> bool:
	if table.boss_paths.is_empty():
		return true
	if _boss_data == null:
		if _boss_requested:
			_boss_data = ResourceLoader.load_threaded_get(_boss_path) as BossData # só entrega 1 vez: por isso guardamos
		else: # o tempo pulou antes do pré-carregamento (ex.: teste): carrega agora
			_boss_path = table.boss_paths[randi() % table.boss_paths.size()]
			_boss_requested = true
		if _boss_data == null:
			_boss_data = load(_boss_path) as BossData
	if _boss_data == null:
		push_error("EnemySpawner: não consegui carregar o chefe %s" % _boss_path)
		return true # desiste, para não repetir o erro a cada tick
	return spawn(_boss_data) != null


## Um ponto na borda do retângulo visível (já com folga), dentro do mapa e sem parede. Null se não achar.
## Se o mapa for menor que a câmera (mapa de teste), cai para "sem limite do mapa" e avisa uma vez.
func _find_position(radius: float) -> Variant:
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position() if cam else Vector2.ZERO
	var zoom := cam.zoom if cam else Vector2.ONE
	var half := get_viewport().get_visible_rect().size / (2.0 * zoom) + Vector2.ONE * (radius + SPAWN_MARGIN)
	_probe.radius = radius * 0.6
	var pos: Variant = _try_positions(center, half, true)
	if pos == null and bounds.has_area():
		pos = _try_positions(center, half, false)
		if pos != null and not _warned_bounds:
			_warned_bounds = true
			push_warning("EnemySpawner: nenhum ponto de nascimento dentro do mapa (mapa menor que a câmera?); nascendo fora dos limites.")
	return pos


func _try_positions(center: Vector2, half: Vector2, use_bounds: bool) -> Variant:
	var space := get_viewport().world_2d.direct_space_state
	for i in TRIES:
		var dir := Vector2.from_angle(randf() * TAU)
		var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		var p := center + dir * t
		if use_bounds and bounds.has_area() and not bounds.has_point(p):
			continue
		_query.transform = Transform2D(0.0, p)
		if space.intersect_shape(_query, 1).is_empty():
			return p
	return null
