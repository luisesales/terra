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


func get_playable_rect() -> Rect2:
	return global_transform * playable_rect


func get_camera_rect() -> Rect2:
	return global_transform * camera_rect


func get_player_start() -> Vector2:
	return to_global(player_start)
