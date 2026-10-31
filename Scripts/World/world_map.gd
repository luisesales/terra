class_name WorldMap
extends Node2D
## Raiz de um mapa jogável (Scenes/Worlds/*.tscn, geradas por Tools/maps/build_worlds.py; dá para editar à mão no editor).
## As medidas abaixo são LOCAIS (antes da escala do nó). O `scale` do nó é o tamanho do mundo em relação aos
## personagens: aumentar deixa o mundo maior sem mexer nos PNGs (o filtro linear do nó suaviza a ampliação).

@export var display_name := ""
## Onde o jogador anda (a faixa de mar/parede já está descontada). O spawner usa isto como limite de nascimento.
@export var playable_rect := Rect2()
## Toda a arte pintada: a câmera não passa daqui, então nunca aparece vazio atrás do mapa.
@export var camera_rect := Rect2()
@export var player_start := Vector2.ZERO
## Zoom da câmera neste mapa (menor que 1 mostra mais mundo ao redor do jogador).
@export var camera_zoom := 0.75
## Opacidade da copa/arbusto com alguém embaixo: o personagem aparece por (1 - isto), então MENOR = enxerga-se melhor quem está embaixo.
## 1.0 desliga o efeito e deixa tudo opaco. Palpite: 0.3 deixava o jogador fraco sob vários arbustos, 0.5 piorava; confira no jogo.
@export_range(0.0, 1.0) var canopy_fade_alpha := 0.2

## O mundo inteiro (chão, props) é desenhado abaixo disto; os círculos de invocação (z -2) ficam ACIMA do chão e abaixo dos
## personagens. Com o chão em z 0 os círculos ficavam escondidos sob os tiles. A ordem interna do mapa não muda.
const GROUND_Z := -10
## O nó "Canopy" do mapa (copas de árvore e arbustos) é desenhado ACIMA de todos os personagens, que andam por baixo.
## Vale como z ABSOLUTO (não soma o GROUND_Z) e fica acima dos chefes (Boss.tscn usa z 10).
const CANOPY_Z := 20
## Uma copa tem 600 a 900 px na tela e o jogador uns 140: opaca, esconderia quem passasse por baixo. Por isso cada copa
## tem um detector (Area2D) que a deixa translúcida enquanto há alguém dentro.
const CANOPY_FADE_TIME := 0.15 ## s para escurecer/clarear a copa
const CANOPY_BODY_MASK := 6 ## camadas 2 (Player) e 3 (Enemies): quem faz a copa ficar translúcida
const CROWN_RADIUS := 0.5 ## fração do lado maior do sprite que conta como "embaixo da copa" (0,5 = até a ponta das folhas)

var _under := {} ## copa/arbusto -> quantos personagens estão embaixo dela
var _fades := {} ## copa/arbusto -> Tween de opacidade em andamento


func _ready() -> void:
	z_index = GROUND_Z
	add_to_group(&"world_map")
	var canopy := get_node_or_null(^"Canopy") as Node2D
	if canopy == null:
		return
	canopy.z_as_relative = false
	canopy.z_index = CANOPY_Z
	if canopy_fade_alpha < 1.0:
		for item in canopy.get_children():
			_add_fade_detector(item as Node2D)


func get_playable_rect() -> Rect2:
	return global_transform * playable_rect


func get_camera_rect() -> Rect2:
	return global_transform * camera_rect


func get_player_start() -> Vector2:
	return to_global(player_start)


## Cria o detector (um círculo Area2D, irmão de `item` no Canopy) que deixa a copa/arbusto translúcido enquanto há alguém dentro.
func _add_fade_detector(item: Node2D) -> void:
	var sprite := item as Sprite2D if item is Sprite2D else item.get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null or sprite.region_rect.size == Vector2.ZERO:
		return
	var shape := CircleShape2D.new()
	shape.radius = CROWN_RADIUS * maxf(sprite.region_rect.size.x, sprite.region_rect.size.y) * sprite.scale.x
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = CANOPY_BODY_MASK
	area.monitorable = false # ninguém precisa enxergar o detector
	area.position = item.position
	area.add_child(collision)
	item.get_parent().add_child(area)
	area.body_entered.connect(_on_crown_body.bind(item, 1))
	area.body_exited.connect(_on_crown_body.bind(item, -1))


func _on_crown_body(_body: Node2D, item: CanvasItem, change: int) -> void:
	var count := maxi(0, int(_under.get(item, 0)) + change)
	_under[item] = count
	if _fades.has(item):
		(_fades[item] as Tween).kill()
	var tween := create_tween()
	_fades[item] = tween
	tween.tween_property(item, "modulate:a", canopy_fade_alpha if count > 0 else 1.0, CANOPY_FADE_TIME)
