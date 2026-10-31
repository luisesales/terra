extends Node2D
## Raiz de composição da partida: instancia o mundo da fase atual (GameController.PHASES), o spawner e o HUD.
## Pode ser aberta direto (F6) ou vir do menu: nos dois casos garante que a run está em andamento.
## Também cuida dos portais: o jogador chega por um no começo de cada fase e, nas fases 1 e 2, sai por outro quando o tempo acaba.
## No fim dessas duas fases ele escolhe uma carta de recompensa (uma melhoria forte para uma das armas de fogo) antes de sair.

const PORTAL_SCENE := preload("res://Scenes/Portal.tscn")
const CIRCLE_SCENE := preload("res://Scenes/SummoningCircle.tscn")
const CARD_PICKER_SCENE := preload("res://Scenes/CardPicker.tscn")
const REWARD_DELAY := 1.5 ## s entre o fim da fase e as cartas: dá tempo de ver os zumbis morrerem e o portal abrir
const ARRIVE_TIME := 1.4 ## s do efeito de chegada (o jogador fica sem controle e sem dano)
const DEPART_TIME := 0.8 ## s do efeito de saída antes de trocar de fase
const ARRIVE_CIRCLE_SIZE := 420.0 ## diâmetro do círculo sob o jogador na chegada
const PORTAL_DISTANCE := 450.0 ## px do jogador em que o portal de saída abre (palpite; visível na tela)
const PORTAL_CLEARANCE := 160.0 ## raio livre de paredes exigido em volta do portal
const PORTAL_EDGE_MARGIN := 200.0 ## o portal não abre a menos disto da borda da área jogável

## Cor do CanvasModulate com o escurecimento ligado (palpite; não deixe o mundo abaixo de ~30% de brilho).
@export var dark_color := Color(0.45, 0.5, 0.6)

@onready var _world: Node2D = $World
@onready var _spawner: EnemySpawner = $Spawner
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
@onready var _dark_grade: CanvasLayer = $DarkGrade
@onready var _hud: CanvasLayer = $HUD

var _enemies: Node2D
var _exit_portal: Portal
var _card_picker: CardPicker


func _ready() -> void:
	if GameController.state != GameController.State.PLAYING:
		GameController.begin_run()
	_load_world()
	var player := get_tree().get_first_node_in_group(&"player")
	if _world is WorldMap:
		_apply_world(_world, player)
	# Os inimigos ficam no mesmo pai do jogador (e das balas), logo ANTES dele: desenhados sobre o chão e sob o jogador.
	var host: Node = player.get_parent() if player else _world
	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	_enemies.y_sort_enabled = true
	host.add_child(_enemies)
	if player:
		host.move_child(_enemies, player.get_index())
	_spawner.enemies_parent = _enemies
	_spawner.bounds = _world_bounds()
	var table := load(GameController.phase_data()["table"]) as SpawnTable
	if table:
		_spawner.table = table
	set_darkness(true)
	GameController.phase_cleared.connect(_open_exit_portal)
	GameController.phase_cleared.connect(_offer_reward)
	_arrive(player)


## Troca o nó World (um espaço vazio na Game.tscn) pelo mapa da fase atual. O Enter reinicia a mesma fase.
func _load_world() -> void:
	var path: String = GameController.phase_data()["scene"]
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


## O jogador nasce (início da run, da fase ou de um reinício) por um portal: círculo sob ele e corpo na cor do portal que escorre.
func _arrive(player: Node) -> void:
	if player == null or not player.has_method(&"arrive"):
		return
	var circle := CIRCLE_SCENE.instantiate() as SummoningCircle
	_enemies.add_child(circle)
	circle.global_position = (player as Node2D).global_position
	circle.play(2, Portal.COLOR, ARRIVE_CIRCLE_SIZE, ARRIVE_TIME + 0.6, 0.4)
	player.arrive(Portal.COLOR, ARRIVE_TIME)


## O tempo da fase acabou (os inimigos já estão morrendo): abre o portal de saída perto do jogador.
func _open_exit_portal() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or _exit_portal != null:
		return
	_exit_portal = PORTAL_SCENE.instantiate() as Portal
	player.get_parent().add_child(_exit_portal)
	_exit_portal.z_as_relative = false # acima das copas de árvore (WorldMap.CANOPY_Z): o jogador precisa enxergar o portal onde quer que ele abra
	_exit_portal.z_index = WorldMap.CANOPY_Z + 1
	_exit_portal.global_position = find_portal_position(player.global_position)
	_exit_portal.entered.connect(_on_portal_entered)
	_exit_portal.open()


## Fim de fase (1 e 2): sorteia as 3 cartas (uma por arma) e, depois de REWARD_DELAY, abre a tela de escolha com o jogo pausado.
## Até a escolha, a travessia do portal fica esperando (reward_pending), mesmo que o jogador chegue ao portal antes das cartas.
func _offer_reward() -> void:
	var offer := GameController.offer_cards()
	if offer.is_empty():
		return
	GameController.reward_pending = true
	get_tree().create_timer(REWARD_DELAY).timeout.connect(_show_reward.bind(offer)) # a conexão some junto com este nó


func _show_reward(offer: Array[CardData]) -> void:
	if not GameController.reward_pending or _card_picker != null:
		return
	_card_picker = CARD_PICKER_SCENE.instantiate() as CardPicker
	add_child(_card_picker)
	_hud.hide() # a tela de cartas é cheia: o aviso "entre no portal" do HUD apareceria por trás do título
	_card_picker.card_chosen.connect(_on_card_chosen)
	_card_picker.open(offer)


func _on_card_chosen(card: CardData) -> void:
	GameController.pick_card(card)
	_hud.show()
	_card_picker.queue_free() # ao sair da árvore ele despausa o jogo
	_card_picker = null


## Um ponto a PORTAL_DISTANCE do jogador, dentro da área jogável e longe de paredes. Prefere a direção do centro do mapa.
func find_portal_position(origin: Vector2) -> Vector2:
	var area := _world_bounds()
	var inner := area.grow(-PORTAL_EDGE_MARGIN) if area.has_area() else area
	var base := (inner.get_center() - origin).angle() if inner.has_area() else 0.0
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = PORTAL_CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1 # World
	for factor in [1.0, 0.6, 1.4]:
		for i in 16:
			var p: Vector2 = origin + Vector2.from_angle(base + TAU * i / 16.0) * PORTAL_DISTANCE * factor
			if inner.has_area() and not inner.has_point(p):
				continue
			query.transform = Transform2D(0.0, p)
			if space.intersect_shape(query, 1).is_empty():
				return p
	return origin + Vector2.RIGHT * PORTAL_DISTANCE # não achou espaço livre: abre ao lado mesmo


## O jogador entrou no portal: o corpo some na cor do portal e, em seguida, a fase seguinte carrega.
func _on_portal_entered() -> void:
	if not GameController.begin_transition():
		return
	if GameController.reward_pending: # chegou ao portal antes das cartas: a recompensa vem primeiro
		await GameController.reward_resolved
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.has_method(&"depart"):
		player.depart(Portal.COLOR, DEPART_TIME)
	await get_tree().create_timer(DEPART_TIME + 0.2).timeout
	GameController.next_phase()


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
