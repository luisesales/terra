class_name BossData
extends EnemyData
## Chefe: dois ataques alternados, cada um com alcance e dano próprios (mesma ordem de attack_animations).

@export var attack_ranges := PackedFloat32Array()
@export var attack_damages := PackedInt32Array()
