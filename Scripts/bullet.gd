class_name Bullet
extends Area2D

@export var speed := 1200.0
@export var lifetime := 1.0

var direction := Vector2.RIGHT
var damage := 1
var _hits_left := 1
var _already_hit: Array[Node2D] = []


func launch(from: Vector2, dir: Vector2, weapon: WeaponData) -> void:
	global_position = from
	direction = dir
	global_rotation = dir.angle()
	damage = weapon.damage
	_hits_left = weapon.pierce + 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		queue_free()
		return
	if body in _already_hit:
		return
	_already_hit.append(body)
	body.take_damage(damage)
	_hits_left -= 1
	if _hits_left <= 0:
		queue_free()
