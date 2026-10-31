class_name PortalFx
extends RefCounted
## Efeito de portal sobre sprites. É o INVERSO do brilho do cadáver (corpse_glow): na chegada o sprite surge inteiro na cor
## do portal e a cor escorre até a paleta original; na saída a cor sobe e o sprite some.
## Usa os uniforms `glow_color`, `glow` (0 = paleta original, 1 = chapado na cor) e `fade` (0 = visível, 1 = sumido), que o
## shader do cadáver e o do chefe-espelho têm em comum. O material só existe durante o efeito (sem material = batching normal).

const SHADER := preload("res://Assets/Shaders/corpse_glow.gdshader")
const APPEAR_FRACTION := 0.35 ## fração da chegada em que o sprite ainda está surgindo (fade 1 -> 0)
const DEPART_FADE_START := 0.5 ## fração da saída em que o sprite começa a sumir


static func make_material(color: Color, glow: float, fade: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"glow_color", color)
	mat.set_shader_parameter(&"glow", glow)
	mat.set_shader_parameter(&"fade", fade)
	return mat


## Chegada: depois de `delay` s o sprite surge na cor `color` e a cor escorre em `duration` s. `mat` = material próprio do
## sprite (ex.: o da paleta do chefe-espelho), que também é o que fica no fim; sem ele usa o do cadáver e remove no fim.
static func arrive(sprites: Array, color: Color, duration: float, delay := 0.0, mat: ShaderMaterial = null) -> Tween:
	var own := mat == null
	if own:
		mat = make_material(color, 1.0, 1.0)
	mat.set_shader_parameter(&"glow_color", color)
	mat.set_shader_parameter(&"glow", 1.0)
	mat.set_shader_parameter(&"fade", 1.0)
	_apply(sprites, mat)
	var tween: Tween = sprites[0].create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"fade", v), 1.0, 0.0, duration * APPEAR_FRACTION).set_delay(delay)
	# a cor segura um pouco e escorre depressa no fim (ease in): dá tempo de ver o jogador "colorido"
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"glow", v), 1.0, 0.0, duration) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if own: # só remove o que é nosso: se outro efeito (ex.: a saída) já trocou o material, não mexe
			for sprite in sprites:
				if is_instance_valid(sprite) and (sprite as CanvasItem).material == mat:
					(sprite as CanvasItem).material = null)
	return tween


## Saída: a cor sobe em `duration` s e na segunda metade o sprite some. O material fica (a cena vai ser trocada ou o nó liberado).
static func depart(sprites: Array, color: Color, duration: float, mat: ShaderMaterial = null) -> Tween:
	if mat == null:
		mat = make_material(color, 0.0, 0.0)
	mat.set_shader_parameter(&"glow_color", color)
	_apply(sprites, mat)
	var tween: Tween = sprites[0].create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"glow", v), 0.0, 1.0, duration * 0.6)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"fade", v), 0.0, 1.0, duration * (1.0 - DEPART_FADE_START)) \
		.set_delay(duration * DEPART_FADE_START)
	return tween


static func _apply(sprites: Array, mat: Material) -> void:
	for sprite in sprites:
		if is_instance_valid(sprite):
			(sprite as CanvasItem).material = mat
