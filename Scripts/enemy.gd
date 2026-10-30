class_name Enemy
extends CharacterBody2D
## Inimigo genérico: o comportamento é o mesmo para todos, o que muda é o EnemyData passado em setup().
## O sprite do zumbi TDS olha para o sul, então o visual gira com `rotation = ângulo - PI/2`; o colisor fica na raiz.

signal died(enemy: Enemy)
signal hp_changed(hp: int, max_hp: int)

enum State { SPAWNING, CHASING, ATTACKING, DEAD }

const CORPSE_SHADER := preload("res://Assets/Shaders/corpse_glow.gdshader")
const CORPSE_LIFETIME := 3.0 ## palpite: tempo total do cadáver até o queue_free
const GLOW_START := 1.0 ## palpite: quando o brilho começa a subir, contado da morte
const FADE_TIME := 0.5 ## palpite
const TURN_SPEED := 8.0 ## palpite
const SEPARATION_STRENGTH := 1.0 ## palpite
const SEPARATION_EVERY := 3 ## recalcula a separação a cada N frames de física (escalonado por inimigo)
const HIT_TOLERANCE := 1.3 ## palpite: o jogador pode se afastar um pouco entre o início do golpe e o frame de dano
const CONTACT_SLACK := 10.0 ## palpite: folga entre o encosto dos colisores e o alcance mínimo do golpe
const DETOUR_FORWARD := 0.35 ## palpite: quanto do "ir direto ao jogador" sobra enquanto contorna (o resto é ao longo da superfície)
const DETOUR_HOLD := 1.2 ## palpite: s que o inimigo mantém o lado escolhido depois de soltar o obstáculo (precisa passar da quina)

## Inimigos vivos (usado pela separação e pelo limite do spawner). Sai da lista ao morrer ou sair da árvore.
static var all: Array[Enemy] = []

var data: EnemyData
var state := State.CHASING

var _hp := 0
var _target: Node2D
var _attack_index := 0
var _attack_timer := 0.0
var _hit_done := false
var _spawn_left := 0.0
var _separation := Vector2.ZERO
var _stagger := 0
var _blocked_normal := Vector2.ZERO ## normal do obstáculo do mapa em que bateu no quadro anterior (zero = livre)
var _detour_side := 1.0 ## lado (±1) que contorna um obstáculo quando o jogador está exatamente atrás dele; sorteado por inimigo
var _detour_vec := Vector2.ZERO ## direção (ao longo da superfície) escolhida para contornar; zero = sem desvio em andamento
var _detour_left := 0.0

@onready var _visual: Node2D = $Visual
@onready var _sprite: AnimatedSprite2D = $Visual/Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D


## Chamar ANTES de add_child (ou depois: também funciona).
func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	if is_node_ready():
		_apply_data()


## Fase de nascimento: sem colisão nem ataque durante `duration` segundos; o sprite surge em fade
## (começa depois de `appear_after`, dura `fade_time`).
func spawn_in(duration: float, appear_after := 0.0, fade_time := 0.4) -> void:
	state = State.SPAWNING
	_spawn_left = duration
	collision_layer = 0
	_sprite.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(appear_after)
	tween.tween_property(_sprite, "modulate:a", 1.0, fade_time)


func is_alive() -> bool:
	return state != State.DEAD


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	_hp -= amount
	hp_changed.emit(_hp, data.max_hp)
	if _hp <= 0:
		_die()


func kill() -> void:
	take_damage(maxi(_hp, 1))


func _attack_range(_index: int) -> float:
	return data.attack_range


func _attack_damage(_index: int) -> int:
	return data.contact_damage


## Centro do corpo do alvo (o colisor do jogador é deslocado do nó): a distância de contato vale em todas as direções.
func _target_center(target: Node2D) -> Vector2:
	return target.get_body_center() if target.has_method(&"get_body_center") else target.global_position


## Distância (centro a centro) em que o colisor do inimigo encosta no do alvo.
func _contact_distance(target: Node2D) -> float:
	var target_radius: float = target.get_body_radius() if target.has_method(&"get_body_radius") else 0.0
	return data.collision_radius + target_radius


## Alcance real do golpe. O colisor trava o inimigo no jogador, então o alcance nunca pode ser menor que a distância
## de contato (senão ele ficaria colado sem conseguir atacar).
func _reach(index: int, target: Node2D) -> float:
	return maxf(_attack_range(index), _contact_distance(target) + CONTACT_SLACK)


func _ready() -> void:
	_stagger = randi() % SEPARATION_EVERY
	_detour_side = 1.0 if randf() < 0.5 else -1.0
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	GameController.run_won.connect(kill)
	all.append(self)
	if data:
		_apply_data()


func _exit_tree() -> void:
	all.erase(self)


func _apply_data() -> void:
	_hp = data.max_hp
	var circle := CircleShape2D.new() # um por instância: o raio muda de tipo para tipo
	circle.radius = data.collision_radius
	_shape.shape = circle
	_sprite.sprite_frames = data.sprite_frames
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	match state:
		State.SPAWNING:
			_spawn_left -= delta
			if _spawn_left <= 0.0:
				collision_layer = 4 # camada 3 (Enemies)
				state = State.CHASING
		State.CHASING:
			_chase(delta)


func _chase(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var target := _get_target()
	if target == null or GameController.state == GameController.State.DEAD:
		velocity = Vector2.ZERO
		_play(&"idle")
		return
	var to_target := _target_center(target) - global_position
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.001 else Vector2.ZERO
	_visual.rotation = lerp_angle(_visual.rotation, dir.angle() - PI / 2.0, 1.0 - exp(-TURN_SPEED * delta))

	var contact := _contact_distance(target)
	var reach := maxf(_attack_range(_attack_index), contact + CONTACT_SLACK)
	if dist <= reach and _attack_timer <= 0.0:
		_start_attack(dir)
		return
	if (Engine.get_physics_frames() + _stagger) % SEPARATION_EVERY == 0:
		_separation = _compute_separation()
	# Para a 0,9 x alcance, mas nunca encostado no colisor do alvo: empurrar contra ele só faria o inimigo afundar e "andar parado".
	var move := dir if dist > maxf(reach * 0.9, contact + 2.0) else Vector2.ZERO
	var detour := _detour(dir, delta) if move != Vector2.ZERO else Vector2.ZERO
	var steer := (move * DETOUR_FORWARD + detour if detour != Vector2.ZERO else move) + _separation * SEPARATION_STRENGTH
	velocity = steer.limit_length(1.0) * data.speed
	move_and_slide()
	_blocked_normal = _map_obstacle_normal()
	_play(&"walk" if velocity.length() > 1.0 else &"idle")


## Sem navegação, um inimigo que vem de frente contra uma parede/carro/mesa "empurraria" para sempre. Ao bater num obstáculo
## do mapa ele ganha uma componente ao longo da superfície e COMPROMETE o lado (o do jogador, ou o sorteado se o jogador está
## exatamente atrás): se a escolha fosse refeita a cada quadro ele oscilaria no ponto em que o jogador fica "de frente".
## O lado vale até DETOUR_HOLD s depois de soltar o obstáculo, para passar da quina antes de voltar a ir direto.
func _detour(dir: Vector2, delta: float) -> Vector2:
	if _blocked_normal != Vector2.ZERO:
		var tangent := _blocked_normal.orthogonal()
		if _detour_vec == Vector2.ZERO:
			var along := tangent.dot(dir)
			tangent *= signf(along) if absf(along) > 0.08 else _detour_side
		elif tangent.dot(_detour_vec) < 0.0:
			tangent = -tangent # manter o sentido ao dobrar a quina (a normal muda)
		_detour_vec = tangent
		_detour_left = DETOUR_HOLD
	else:
		_detour_left -= delta
		if _detour_left <= 0.0:
			_detour_vec = Vector2.ZERO
	return _detour_vec


func _map_obstacle_normal() -> Vector2:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider()
		if other is StaticBody2D or other is TileMapLayer:
			return hit.get_normal()
	return Vector2.ZERO


func _start_attack(dir: Vector2) -> void:
	state = State.ATTACKING
	_hit_done = false
	velocity = Vector2.ZERO
	_visual.rotation = dir.angle() - PI / 2.0
	_sprite.play(StringName(data.attack_animations[_attack_index]))


func _on_frame_changed() -> void:
	if state != State.ATTACKING or _hit_done:
		return
	if _sprite.frame >= data.attack_hit_frames[_attack_index]:
		_hit_done = true
		var target := _get_target()
		if target and global_position.distance_to(_target_center(target)) <= _reach(_attack_index, target) * HIT_TOLERANCE:
			target.take_damage(_attack_damage(_attack_index))


func _on_animation_finished() -> void:
	if state != State.ATTACKING:
		return
	state = State.CHASING
	_attack_timer = data.attack_cooldown
	_attack_index = (_attack_index + 1) % data.attack_animations.size()
	_play(&"idle")


func _get_target() -> Node2D:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player")
	return _target


func _play(anim: StringName) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


## Empurra para longe de vizinhos sobrepostos (O(n²) escalonado; ok para ~120). Chefes não são empurrados.
func _compute_separation() -> Vector2:
	if data.tier >= 4:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for other in all:
		if other == self or other.state == State.DEAD:
			continue
		var offset := global_position - other.global_position
		var min_dist := (data.collision_radius + other.data.collision_radius) * 0.8 # palpite: deixa sobrepor um pouco
		var d2 := offset.length_squared()
		if d2 >= min_dist * min_dist:
			continue
		if d2 < 0.0001:
			push += Vector2.from_angle(randf() * TAU)
			continue
		var d := sqrt(d2)
		push += offset / d * (1.0 - d / min_dist)
	return push.limit_length(1.0)


func _die() -> void:
	state = State.DEAD
	all.erase(self)
	# take_damage costuma vir de um callback de física (bala): mudar colisão tem que ser adiado.
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	velocity = Vector2.ZERO
	_sprite.play(&"death") # sem z_index negativo: ficaria abaixo dos tiles do chão (a ordem é o y-sort do container)
	died.emit(self)
	_fade_corpse()


## Brilho na cor do nível e sumiço em CORPSE_LIFETIME s. Material criado só agora (os vivos não têm).
func _fade_corpse() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = CORPSE_SHADER
	mat.set_shader_parameter(&"glow_color", data.tier_color())
	_sprite.material = mat
	# tween_method + set_shader_parameter (e não "shader_parameter/x") porque, sem renderizador (headless), o shader não lista uniforms.
	var tween := create_tween()
	tween.tween_interval(GLOW_START)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"glow", v), 0.0, 1.0, CORPSE_LIFETIME - GLOW_START - FADE_TIME)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"fade", v), 0.0, 1.0, FADE_TIME)
	tween.tween_callback(queue_free)
