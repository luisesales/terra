extends CharacterBody2D

@onready var _feet = $Pivot/Feet
@onready var _body = $Pivot/Body

@export var _speed := 160.0
@export var _hp = 100
@export var _feet_turn_speed := 12.0

func _handle_aim() -> void:
	_body.look_at(get_global_mouse_position())


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


func _ready() -> void:
	GameController._player_hp = _hp

func _physics_process(delta: float) -> void:
	if _hp >= 0:
		_handle_input(delta)
