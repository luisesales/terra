class_name EnemyData
extends Resource
## Configuração de um tipo de inimigo (≈ ScriptableObject do Unity).
## Só guarda dados fixos: a vida atual vive na instância (Enemy._hp), nunca aqui.

## Cor por nível (1 a 5): azul, roxo, vermelho, verde, laranja abóbora. Usada no círculo de nascimento e no brilho do cadáver.
const TIER_COLORS: Array[Color] = [
	Color8(72, 72, 182), Color8(174, 41, 174), Color8(183, 38, 38), Color8(82, 187, 82), Color8(255, 117, 24),
]

@export var display_name := "Zumbi"
@export_range(1, 5) var tier := 1
@export var sprite_frames: SpriteFrames
@export var max_hp := 3
@export var speed := 70.0
@export var contact_damage := 5
## Distância (centro a centro) a partir da qual o inimigo para e ataca. Como ele colide com o jogador, o alcance
## efetivo nunca é menor que (collision_radius + raio do jogador + folga): valores menores que isso são ignorados.
@export var attack_range := 110.0
@export var attack_cooldown := 1.0
## Nomes das animações de ataque no SpriteFrames; o inimigo alterna entre elas em ordem.
@export var attack_animations := PackedStringArray(["attack"])
## Frame (0-based) de cada animação de ataque em que o dano é causado. Mesma ordem de attack_animations.
@export var attack_hit_frames := PackedInt32Array([2])
@export var collision_radius := 55.0
## Diâmetro do círculo de invocação no nascimento, em px.
@export var spawn_circle_size := 210.0


func tier_color() -> Color:
	return TIER_COLORS[clampi(tier, 1, TIER_COLORS.size()) - 1]
