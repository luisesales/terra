extends CharacterBody2D

@onready var _feet := $Pivot/Feet
@onready var _body := $Pivot/Body
@onready var _muzzle := $Pivot/Body/Muzzle
@onready var _muzzle_flash := $Pivot/Body/Muzzle/MuzzleFlash


@export var _speed := 160.0
@export var _hp := 100
@export var _feet_turn_speed := 12.0

@export var _weapons : Array[WeaponData] = []

var _weapon: WeaponData
var _weapon_index := 0
var _is_reloading := false

var _fire_cooldown := 0.0

const BULLET_SCENE := preload("res://Scenes/bullet.tscn")

func _spawn_bullet(spread := 0.0) -> void:
	var bullet := BULLET_SCENE.instantiate() as Bullet
	get_parent().add_child(bullet)
	var direction := Vector2.RIGHT.rotated(_body.global_rotation + spread)
	bullet.launch(_muzzle.global_position, direction, _weapon)


func _show_muzzle_flash() -> void:
	_muzzle_flash.rotation = randf_range(-0.02, 0.02,)
	_muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	_muzzle_flash.visible = false


func _equip(index: int) -> void:
	_weapon_index = wrapi(index, 0, _weapons.size())
	_weapon = _weapons[_weapon_index]
	_body.sprite_frames = _weapon.sprite_frames
	_muzzle.position = _weapon.muzzle_offset
	_body.play(&"idle")

func _fire_weapon():
	if _fire_cooldown > 0.0 || _is_reloading:
		return
	if not _weapon.is_melee :
		if _weapon.current_ammo <= 0 :
			print("No Ammo Left, Reload!")
			return
		_weapon.current_ammo -= 1
		_show_muzzle_flash()
		_body.play(&"shoot")
		for i in _weapon.pellets:
			var t := 0.5 if _weapon.pellets == 1 else float(i) / (_weapon.pellets - 1)
			var angle := lerpf(-_weapon.spread_degrees, _weapon.spread_degrees, t)
			_spawn_bullet(deg_to_rad(angle + randf_range(-1.5, 1.5)))

	else:
		_body.play(&"meleeattack")	
	_fire_cooldown = _weapon.fire_interval		

func _handle_aim() -> void:
	_body.look_at(get_global_mouse_position())
	if _weapon.is_automatic && Input.is_action_pressed("fire_weapon"):		
		_fire_weapon()
	elif Input.is_action_just_pressed("fire_weapon") :
		_fire_weapon()
	
func _handle_equipament() -> void:
	if Input.is_action_just_pressed("reload") && not _is_reloading:
		_is_reloading = true
		await get_tree().create_timer(_weapon.reload_time).timeout
		_weapon.current_ammo = _weapon.magazine_size
		_is_reloading = false
	
	if Input.is_action_just_pressed("swap_weapon"):
		_equip(_weapon_index+1)
	for i in _weapons.size():
		if Input.is_action_just_pressed("equip_weapon_%d" % (i + 1)):
			_equip(i)	
	

func _handle_input(delta : float) -> void:
	_handle_aim()
	_handle_movement(delta)
	_handle_equipament()
	
	

func _handle_feet(direction: Vector2, delta: float) -> void:
	_feet.rotation = lerp_angle(_feet.rotation, _body.rotation, 1.0 - exp(-_feet_turn_speed * delta))

	if direction == Vector2.ZERO:
		_feet.play(&"idle")
		return
	var relative := rad_to_deg(angle_difference(_body.rotation, direction.angle()))
	
	if absf(relative) < 67.5:
		_feet.play(&"walk")
	elif absf(relative) > 112.5:
		_feet.play_backwards(&"walk")
	elif relative > 0.0:
		_feet.play(&"strafe_right")
	else:
		_feet.play(&"strafe_left")


func _handle_movement(delta : float) -> void:
	var _direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = _direction * _speed
	_handle_feet(_direction, delta)
	move_and_slide()

func _on_body_animation_finished() -> void:
	_body.play(&"idle")

func _ready() -> void:
	GameController._player_hp = _hp
	if not _weapons.is_empty():
		_equip(0)

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _hp >= 0:
		_handle_input(delta)
	
