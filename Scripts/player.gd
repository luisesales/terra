extends CharacterBody2D

@onready var _feet = $Pivot/Feet
@onready var _body = $Pivot/Body

@export var _speed : float = 160.0
@export var _hp : int = 100
@export var _feet_turn_speed : float = 12.0

@export var _fire_interval : float = 0.33

var _weapon_index : int = 0

var _current_weapon_ammo : int = 20
var _current_weapon_max_ammo : int = 20
var _is_current_weapon_automatic : bool = false
var _fire_cooldown : float = 0.0

func _equip(index: int) -> void:
	_weapon_index = wrapi(index, 0, _weapons.size())
	_body.sprite_frames = _weapons[_weapon_index]
	_body.play(&"idle")

func _fire_weapon():
	if _fire_cooldown > 0.0:
		return
	if _current_weapon_ammo <= 0:
		print("No Ammo Left, Reload!")
		return
	_fire_cooldown = _fire_interval
	_current_weapon_ammo -= 1
	_body.play(&"shoot")
		
		

func _handle_aim() -> void:
	_body.look_at(get_global_mouse_position())
	if _is_current_weapon_automatic && Input.is_action_pressed("fire_weapon"):		
		_fire_weapon()
	elif Input.is_action_just_pressed("fire_weapon") :
		_fire_weapon()
	


func _handle_input(delta : float) -> void:
	_handle_aim()
	_handle_movement(delta)

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
	_equip(0)

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _hp >= 0:
		_handle_input(delta)
	_body.animation_finished.connect(_on_body_animation_finished)	
	
