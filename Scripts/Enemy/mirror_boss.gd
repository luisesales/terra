class_name MirrorBoss
extends CharacterBody2D
## Chefe-espelho da fase final: o sprite do jogador com outra paleta e armas de fogo. Mais rápido que o jogador, circula a
## uma distância preferida e atira em rajadas, mas SÓ quando está dentro da tela do jogador (não atira de fora de vista).
## Cada rajada é avisada por uma mira a laser e o corpo avermelhado; entre rajadas há um tempo de recarga.
## Na metade da vida emite `half_life` (o EnemySpawner passa a chamar zumbis). A API (setup, spawn_in, take_damage, kill,
## is_alive, sinais died/hp_changed) imita a do Enemy para o spawner tratar os dois do mesmo jeito.

signal died(boss: MirrorBoss)
signal hp_changed(hp: int, max_hp: int)
signal half_life

enum State { SPAWNING, FIGHTING, DEAD }
enum Fire { IDLE, WINDUP, BURST }

const PALETTE_SHADER := preload("res://Assets/Shaders/mirror_palette.gdshader")
const BULLET_SCENE := preload("res://Scenes/Bullet.tscn")
const BULLET_TINT := Color(1.0, 0.45, 0.35)
const BULLET_LIFETIME := 1.6
const PLAYER_BODY_LAYER := 2
const WORLD_LAYER := 1
const MAX_BARREL_SINE := 0.5 ## igual ao do jogador: limita a correção do cano a 30°
const VIEW_MARGIN := 80.0 ## px de tela: o chefe só atira se estiver pelo menos isto dentro da borda da tela do jogador
const AIM_TURN_SPEED := 12.0
const BURST_TURN_SPEED := 3.0 ## durante a rajada a mira demora a acompanhar: andar de lado faz as balas passarem
const FEET_TURN_SPEED := 12.0
const BAND_FAR := 1.25 ## além de preferred_distance * isto ele se aproxima
const BAND_NEAR := 0.75 ## aquém de preferred_distance * isto ele recua
const STRAFE_TIME := Vector2(1.5, 3.0) ## s entre trocas do lado em que ele circula
const BURST_SPEED_FACTOR := 0.6 ## anda mais devagar enquanto atira
const STUCK_TIME := 0.5
const UNSTICK_TIME := 0.8
const CORPSE_TIME := 2.5

var data: MirrorBossData
var state := State.SPAWNING

var _hp := 0
var _weapon: WeaponData
var _target: Node2D
var _fire := Fire.IDLE
var _fire_timer := 0.0
var _shots_left := 0
var _cooldown := 1.0 ## a primeira rajada vem logo depois do nascimento
var _spawn_left := 0.0
var _strafe_side := 1.0
var _strafe_left := 0.0
var _stuck_time := 0.0
var _unstick_left := 0.0
var _half_fired := false
var _mat := ShaderMaterial.new()

@onready var _feet: AnimatedSprite2D = $Pivot/Feet
@onready var _body: AnimatedSprite2D = $Pivot/Body
@onready var _muzzle: Marker2D = $Pivot/Body/Muzzle
@onready var _sight: Line2D = $Pivot/Body/Muzzle/Sight
@onready var _flash: Sprite2D = $Pivot/Body/Muzzle/MuzzleFlash
@onready var _shape: CollisionShape2D = $CollisionShape2D


## Chamar ANTES de add_child (ou depois: também funciona).
func setup(boss_data: MirrorBossData) -> void:
	data = boss_data
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	_mat.shader = PALETTE_SHADER
	_feet.material = _mat
	_body.material = _mat
	_body.animation_finished.connect(_on_body_animation_finished)
	_strafe_side = 1.0 if randf() < 0.5 else -1.0
	_strafe_left = randf_range(STRAFE_TIME.x, STRAFE_TIME.y)
	_sight.hide()
	_flash.hide()
	if data:
		_apply_data()


func _apply_data() -> void:
	_hp = data.max_hp
	var circle := CircleShape2D.new() # um por instância: o raio vem do EnemyData
	circle.radius = data.collision_radius
	_shape.shape = circle
	_equip(data.rifle if data.rifle else data.shotgun)


## Nascimento pelo portal: invisível até o círculo abrir (`appear_after`), depois surge na cor do portal (laranja, "último
## nível") e a cor escorre até a paleta dele. Sem colisão durante `duration` s. Já mostra a barra de vida no topo do HUD.
func spawn_in(duration: float, appear_after := 0.0, _fade_time := 0.4) -> void:
	state = State.SPAWNING
	_spawn_left = duration
	collision_layer = 0
	PortalFx.arrive([_feet, _body], data.tier_color(), maxf(duration - appear_after, 0.3), appear_after, _mat)
	GameController.report_boss(data.display_name, _hp, data.max_hp)


func is_alive() -> bool:
	return state != State.DEAD


func get_body_center() -> Vector2:
	return _shape.global_position


func get_body_radius() -> float:
	var circle := _shape.shape as CircleShape2D
	return circle.radius if circle else 0.0


func take_damage(amount: int) -> void:
	if state != State.FIGHTING:
		return
	_hp = maxi(_hp - amount, 0)
	hp_changed.emit(_hp, data.max_hp)
	GameController.report_boss(data.display_name, _hp, data.max_hp)
	if not _half_fired and _hp <= data.max_hp * data.help_hp_fraction:
		_half_fired = true
		half_life.emit()
	if _hp <= 0:
		_die()


func kill() -> void:
	take_damage(maxi(_hp, 1))


func _physics_process(delta: float) -> void:
	match state:
		State.SPAWNING:
			_spawn_left -= delta
			if _spawn_left <= 0.0:
				collision_layer = 4 # camada 3 (Enemies)
				state = State.FIGHTING
		State.FIGHTING:
			_fight(delta)


func _fight(delta: float) -> void:
	var target := _get_target()
	if target == null or GameController.state != GameController.State.PLAYING:
		velocity = Vector2.ZERO
		_cancel_fire(0.0)
		_update_feet(Vector2.ZERO, delta)
		return
	var center := _target_center(target)
	var to_target := center - global_position
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.001 else Vector2.RIGHT
	_aim(center, delta)

	var move := _desired_move(dir, dist, delta)
	var speed := _speed_for(target) * (BURST_SPEED_FACTOR if _fire == Fire.BURST else 1.0)
	velocity = move * speed
	move_and_slide()
	_check_stuck(move, speed, delta)
	_update_feet(move, delta)
	_update_fire(delta, dist)


## Faixa de distância: longe demais ele se aproxima, perto demais recua em arco, no meio circula o jogador.
func _desired_move(dir: Vector2, dist: float, delta: float) -> Vector2:
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_side = 1.0 if randf() < 0.5 else -1.0
		_strafe_left = randf_range(STRAFE_TIME.x, STRAFE_TIME.y)
	var lateral := dir.orthogonal() * _strafe_side
	if _unstick_left > 0.0:
		_unstick_left -= delta
		return lateral
	if dist > data.preferred_distance * BAND_FAR:
		return (dir + lateral * 0.25).normalized()
	if dist < data.preferred_distance * BAND_NEAR:
		return (-dir + lateral * 0.5).normalized()
	return lateral


## Sem navegação: se tenta andar e não sai do lugar (parede, carro), troca o lado e circula por um tempo.
func _check_stuck(move: Vector2, speed: float, delta: float) -> void:
	if move != Vector2.ZERO and get_real_velocity().length() < speed * 0.25:
		_stuck_time += delta
		if _stuck_time >= STUCK_TIME:
			_stuck_time = 0.0
			_strafe_side = -_strafe_side
			_unstick_left = UNSTICK_TIME
	else:
		_stuck_time = 0.0


func _speed_for(target: Node2D) -> float:
	var base: float = target.get_move_speed() if target.has_method(&"get_move_speed") else data.speed
	return base * data.speed_ratio


## Gira o corpo para o CANO apontar para `at` (mesma geometria do jogador, ver Player._aim_at).
func _aim(at: Vector2, delta: float) -> void:
	var to_at := at - _body.global_position
	var side := _muzzle.position.y * _body.global_scale.y
	var sine := 0.0
	if not is_zero_approx(side):
		sine = clampf(side / maxf(to_at.length(), 0.001), -MAX_BARREL_SINE, MAX_BARREL_SINE)
	var goal := to_at.angle() - asin(sine)
	var rate := BURST_TURN_SPEED if _fire == Fire.BURST else AIM_TURN_SPEED
	_body.global_rotation = lerp_angle(_body.global_rotation, goal, 1.0 - exp(-rate * delta))


func _update_feet(direction: Vector2, delta: float) -> void:
	_feet.rotation = lerp_angle(_feet.rotation, _body.rotation, 1.0 - exp(-FEET_TURN_SPEED * delta))
	if direction == Vector2.ZERO:
		_play(_feet, &"idle")
		return
	var relative := rad_to_deg(angle_difference(_body.rotation, direction.angle()))
	if absf(relative) < 67.5:
		_play(_feet, &"walk")
	elif absf(relative) > 112.5:
		if _feet.animation != &"walk" or not _feet.is_playing():
			_feet.play_backwards(&"walk")
	elif relative > 0.0:
		_play(_feet, &"strafe_right")
	else:
		_play(_feet, &"strafe_left")


func _play(sprite: AnimatedSprite2D, anim: StringName) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## O jogador "vê" o chefe quando ele está dentro da tela (com uma margem). Fora disso o chefe não atira.
func is_in_player_view() -> bool:
	var viewport := get_viewport()
	var on_screen: Vector2 = viewport.get_canvas_transform() * global_position
	return viewport.get_visible_rect().grow(-VIEW_MARGIN).has_point(on_screen)


func _update_fire(delta: float, dist: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var sees := is_in_player_view()
	match _fire:
		Fire.IDLE:
			if _cooldown <= 0.0 and sees:
				_begin_windup(dist)
		Fire.WINDUP:
			if not sees:
				_cancel_fire(0.4)
				return
			_fire_timer -= delta
			_set_warn(1.0 - clampf(_fire_timer / maxf(data.windup, 0.01), 0.0, 1.0))
			if _fire_timer <= 0.0:
				_fire = Fire.BURST
				_sight.hide()
				_set_warn(0.0)
				_shots_left = 1 if _weapon == data.shotgun else data.burst_size
				_fire_timer = 0.0
		Fire.BURST:
			if not sees:
				_cancel_fire(0.8)
				return
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_shoot()
				_shots_left -= 1
				_fire_timer = data.shot_interval
				if _shots_left <= 0:
					_fire = Fire.IDLE
					_cooldown = data.burst_cooldown * randf_range(0.85, 1.2)


func _begin_windup(dist: float) -> void:
	var wanted := data.shotgun if (dist < data.shotgun_distance and data.shotgun) else data.rifle
	if wanted == null:
		wanted = data.shotgun
	if wanted == null:
		return
	_equip(wanted)
	_fire = Fire.WINDUP
	_fire_timer = data.windup
	_sight.show()


func _cancel_fire(extra_cooldown: float) -> void:
	if _fire == Fire.IDLE and extra_cooldown <= 0.0:
		return
	_fire = Fire.IDLE
	_sight.hide()
	_set_warn(0.0)
	_cooldown = maxf(_cooldown, extra_cooldown)


func _set_warn(value: float) -> void:
	_mat.set_shader_parameter(&"warn", value)


func _equip(weapon: WeaponData) -> void:
	if weapon == null or weapon == _weapon:
		return
	_weapon = weapon
	_body.sprite_frames = weapon.sprite_frames
	_muzzle.position = weapon.muzzle_offset
	_body.play(&"idle")


func _shoot() -> void:
	_body.play(&"shoot")
	_show_flash()
	for i in _weapon.pellets:
		var t := 0.5 if _weapon.pellets == 1 else float(i) / (_weapon.pellets - 1)
		var angle := lerpf(-_weapon.spread_degrees, _weapon.spread_degrees, t)
		angle += randf_range(-data.aim_error_degrees, data.aim_error_degrees)
		_spawn_bullet(deg_to_rad(angle))


func _spawn_bullet(spread: float) -> void:
	var bullet := BULLET_SCENE.instantiate() as Bullet
	bullet.collision_mask = WORLD_LAYER | PLAYER_BODY_LAYER # paredes e jogador; não acerta zumbis nem o próprio chefe
	bullet.speed = data.bullet_speed
	bullet.lifetime = BULLET_LIFETIME
	bullet.modulate = BULLET_TINT
	get_parent().add_child(bullet)
	bullet.launch(_muzzle.global_position, Vector2.RIGHT.rotated(_body.global_rotation + spread), _weapon)


func _show_flash() -> void:
	_flash.rotation = randf_range(-0.02, 0.02)
	_flash.show()
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(_flash):
		_flash.hide()


func _on_body_animation_finished() -> void:
	if state != State.DEAD:
		_body.play(&"idle")


func _die() -> void:
	state = State.DEAD
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	velocity = Vector2.ZERO
	_cancel_fire(0.0)
	_sight.hide()
	_body.play(&"idle")
	_feet.play(&"idle")
	GameController.close_boss_bar()
	died.emit(self)
	# mesmo fim dos zumbis: brilho na cor do nível e sumiço (o jogador não tem animação de morte)
	PortalFx.depart([_feet, _body], data.tier_color(), CORPSE_TIME, _mat).finished.connect(queue_free)


func _get_target() -> Node2D:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player")
	return _target


func _target_center(target: Node2D) -> Vector2:
	return target.get_body_center() if target.has_method(&"get_body_center") else target.global_position
