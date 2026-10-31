class_name SummoningCircle
extends Node2D
## Círculo de nascimento: aparece, segura e some em `duration` s. Só existe no nascimento do inimigo (o brilho da morte é outro efeito).

const SHADER := preload("res://Assets/Shaders/summoning_circle.gdshader")
## Desenho por nível (1 a 5): estrela, flor da vida, heptágono, espiral, espiral (laranja).
const TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Effects/SummoningCircles/circle7.svg"),
	preload("res://Assets/Effects/SummoningCircles/circle6.svg"),
	preload("res://Assets/Effects/SummoningCircles/circle5.svg"),
	preload("res://Assets/Effects/SummoningCircles/circle4.svg"),
	preload("res://Assets/Effects/SummoningCircles/circle4.svg"),
]
const SPIN_SPEED := 0.6 ## rad/s, palpite
const HOLD_FRACTION := 0.2 ## palpite: fração da duração com o círculo totalmente visível

@onready var _sprite: Sprite2D = $Sprite
var _material := ShaderMaterial.new()


## `size` = diâmetro em px (só reduz: o SVG rasteriza no máximo em 1000 px). `fade_in` = tempo até ficar visível.
func play(tier: int, color: Color, size: float, duration: float, fade_in: float) -> void:
	var texture := TEXTURES[clampi(tier, 1, TEXTURES.size()) - 1]
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * minf(size / texture.get_width(), 1.0)
	_material.shader = SHADER
	_material.set_shader_parameter(&"tint", color)
	_material.set_shader_parameter(&"alpha", 0.0)
	_sprite.material = _material
	var fade_out := maxf(duration - fade_in - duration * HOLD_FRACTION, 0.05)
	var tween := create_tween()
	tween.tween_method(_set_alpha, 0.0, 1.0, fade_in)
	tween.tween_interval(duration * HOLD_FRACTION)
	tween.tween_method(_set_alpha, 1.0, 0.0, fade_out)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	rotation += SPIN_SPEED * delta


func _set_alpha(value: float) -> void:
	_material.set_shader_parameter(&"alpha", value)
