class_name WeaponData
extends Resource

@export var display_name := "Pistola"
@export var sprite_frames: SpriteFrames
@export var damage := 2
@export var fire_interval := 0.33
@export var magazine_size := 12
@export var current_ammo := magazine_size
@export var reload_time := 1.2
@export var pellets := 1
@export var pierce := 0
@export var is_automatic := false
@export var is_melee := false
@export var muzzle_offset := Vector2.ZERO
@export var spread_degrees := 0.0
## Só equipável com `has_flashlight` ligado no jogador; acende o cone de luz no `muzzle_offset` (a ponta da lanterna).
@export var is_flashlight := false

@export_group("Corpo a corpo")
## A hitbox é um setor de círculo com o vértice no centro da cabeça (nó Body), que gira com a mira. Só vale com `is_melee`.
@export var melee_range := 190.0 ## px do vértice até a borda do setor
@export_range(10.0, 180.0) var melee_arc_degrees := 100.0 ## abertura total do setor (no máximo 180°: o colisor é convexo)
@export_range(-90.0, 90.0) var melee_arc_offset_degrees := 0.0 ## gira o centro do setor em relação à mira (+ = lado direito do jogador)
## Primeiro e último frame (0-based, inclusive) da animação `meleeattack` em que a hitbox causa dano: o golpe só acerta
## enquanto a lâmina/punho está de fato no ar, não no começo do movimento.
@export var melee_hit_frames := Vector2i(7, 12)
