class_name MirrorBossData
extends EnemyData
## Chefe-espelho (fase final): o jogador "do outro lado". Atira com armas de fogo em rajadas e só ataca quando está dentro
## da tela do jogador. Quando a vida cai à metade, zumbis passam a nascer para ajudá-lo. Todos os números são palpite.
## (Herda max_hp, tier, collision_radius e spawn_circle_size de EnemyData; o sprite vem da cena, não do `sprite_frames`.)

## Rifle (de longe, rajadas) e espingarda (de perto). O dano delas é o que o jogador leva por bala.
@export var rifle: WeaponData
@export var shotgun: WeaponData
## Velocidade relativa à do jogador (1,15 = 15% mais rápido).
@export var speed_ratio := 1.15
@export var burst_size := 5 ## tiros por rajada do rifle
@export var shot_interval := 0.11 ## s entre tiros da rajada
@export var windup := 0.5 ## s de aviso (mira a laser + corpo avermelhado) antes de cada rajada
@export var burst_cooldown := 1.6 ## s de pausa entre rajadas
@export var bullet_speed := 900.0 ## px/s (a do jogador é 1200: dá para desviar)
@export var aim_error_degrees := 2.5 ## erro aleatório de mira, para cada lado
@export var preferred_distance := 560.0 ## distância em que ele gosta de ficar do jogador
@export var shotgun_distance := 380.0 ## mais perto que isso ele usa a espingarda
## Quando a vida chega a esta fração, zumbis passam a nascer (no máximo `help_max_alive` vivos, um a cada `help_interval` s).
@export_range(0.0, 1.0) var help_hp_fraction := 0.5
@export var help_interval := 2.5
@export var help_max_alive := 14
