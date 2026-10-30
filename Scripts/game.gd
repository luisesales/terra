extends Node2D
## Raiz de composição da partida: instancia o mundo (um dos mapas de GameController.MAPS), o spawner e o HUD.
## Pode ser aberta direto (F6) ou vir do menu: nos dois casos garante que a run está em andamento.

## Cor do CanvasModulate com o escurecimento ligado (palpite; não deixe o mundo abaixo de ~30% de brilho).
@export var dark_color := Color(0.45, 0.5, 0.6)

@onready var _world: Node2D = $World
@onready var _spawner: EnemySpawner = $Spawner
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
@onready var _dark_grade: CanvasLayer = $DarkGrade


func _ready() -> void:
	if GameController.state != GameController.State.PLAYING:
		GameController.start_run()
	_load_world()
	var player := get_tree().get_first_node_in_group(&"player")
	if _world is WorldMap:
		_apply_world(_world, player)
	# Os inimigos ficam no mesmo pai do jogador (e das balas), logo ANTES dele: desenhados sobre o chão e sob o jogador.
	var host: Node = player.get_parent() if player else _world
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	enemies.y_sort_enabled = true
	host.add_child(enemies)
	if player:
		host.move_child(enemies, player.get_index())
	_spawner.enemies_parent = enemies
	_spawner.bounds = _world_bounds()
	set_darkness(true)


## Troca o nó World (um espaço vazio na Game.tscn) pelo mapa sorteado/escolhido. O Enter reinicia no mesmo mapa.
func _load_world() -> void:
	if GameController.current_map < 0:
		GameController.roll_map()
	var path: String = GameController.MAPS[GameController.current_map]["scene"]
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Game: não consegui carregar o mapa %s" % path)
		return
	var fresh := packed.instantiate()
	var index := _world.get_index()
	remove_child(_world)
	_world.queue_free()
	fresh.name = "World"
	add_child(fresh)
	move_child(fresh, index)
	_world = fresh


## Coloca o jogador no ponto de início e prende a câmera ao mapa (sem vazio atrás dele), com o zoom do mapa.
func _apply_world(map: WorldMap, player: Node) -> void:
	if player == null:
		return
	if player is Node2D:
		(player as Node2D).global_position = map.get_player_start()
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var rect := map.get_camera_rect()
		cam.limit_left = floori(rect.position.x)
		cam.limit_top = floori(rect.position.y)
		cam.limit_right = ceili(rect.end.x)
		cam.limit_bottom = ceili(rect.end.y)
		cam.zoom = Vector2.ONE * map.camera_zoom


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_dark"): # F2
		set_darkness(not _dark_grade.visible)


## Liga/desliga o escurecimento (CanvasModulate + shader dark_grade). Atalho de depuração: F2.
func set_darkness(on: bool) -> void:
	_dark_grade.visible = on
	_canvas_modulate.color = dark_color if on else Color.WHITE


## Onde os inimigos podem nascer: a área jogável do mapa ou, num mundo sem WorldMap, a união (em coordenadas globais)
## das células usadas por todas as TileMapLayer.
func _world_bounds() -> Rect2:
	if _world is WorldMap:
		return (_world as WorldMap).get_playable_rect()
	var result := Rect2()
	var first := true
	for node in _world.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		var used := layer.get_used_rect()
		if layer.tile_set == null or used.size == Vector2i.ZERO:
			continue
		var tile := Vector2(layer.tile_set.tile_size)
		var local := Rect2(layer.map_to_local(used.position) - tile / 2.0, Vector2(used.size) * tile)
		var rect := layer.get_global_transform() * local
		result = rect if first else result.merge(rect)
		first = false
	return result
