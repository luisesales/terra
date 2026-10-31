class_name Portal
extends Area2D
## Portal de saída da fase: abre quando o tempo acaba (fases 1 e 2). O jogador que entra nele é levado à fase seguinte.
## Visual: dois anéis do círculo de invocação girando em sentidos opostos sobre um brilho radial, na cor do portal.

signal entered

## Cor do portal do jogador (entrada e saída). Ciano de propósito: as cores dos inimigos são azul, roxo, vermelho, verde e laranja.
const COLOR := Color(0.3, 0.85, 1.0)
const OUTER_SIZE := 360.0 ## diâmetro dos anéis, em px
const INNER_SIZE := 220.0
const OPEN_TIME := 1.0 ## o portal cresce até o tamanho final; só então aceita o jogador
const SPIN := 0.7 ## rad/s, palpite
const PULSE_SPEED := 3.0

@onready var _outer: Sprite2D = $Outer
@onready var _inner: Sprite2D = $Inner
@onready var _glow: Sprite2D = $Glow

var _material := ShaderMaterial.new()
var _time := 0.0
var _open := false
var _fired := false


func _ready() -> void:
	_material.shader = preload("res://Assets/Shaders/summoning_circle.gdshader")
	_material.set_shader_parameter(&"tint", COLOR)
	_material.set_shader_parameter(&"alpha", 1.0)
	_outer.material = _material
	_inner.material = _material
	_outer.scale = Vector2.ONE * OUTER_SIZE / _outer.texture.get_width()
	_inner.scale = Vector2.ONE * INNER_SIZE / _inner.texture.get_width()
	_glow.modulate = Color(COLOR, 0.0)
	body_entered.connect(_on_body_entered)
	monitoring = false
	scale = Vector2.ZERO


## Anima a abertura (cresce com um leve "pulo") e liga a detecção do jogador no fim.
func open() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_open = true
		monitoring = true)


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	_time += delta
	_outer.rotation += SPIN * delta
	_inner.rotation -= SPIN * 1.4 * delta
	_glow.modulate.a = (0.4 + 0.15 * sin(_time * PULSE_SPEED)) * minf(scale.x, 1.0)


# body_entered não dispara para quem já estava em cima quando o portal abriu: por isso também se confere a sobreposição.
func _physics_process(_delta: float) -> void:
	if _open and not _fired:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if _open and not _fired and body.is_in_group(&"player"):
		_fired = true
		entered.emit()
