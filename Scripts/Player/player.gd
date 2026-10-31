extends CharacterBody2D

## A recarga começou (com a duração em s), terminou ou foi cancelada (troca de arma). O Crosshair desenha o círculo se fechando.
signal reload_started(duration: float)
signal reload_finished
signal reload_cancelled

@onready var _feet := $Pivot/Feet
@onready var _body := $Pivot/Body
@onready var _muzzle := $Pivot/Body/Muzzle
@onready var _muzzle_flash := $Pivot/Body/Muzzle/MuzzleFlash
@onready var _hitbox: CollisionShape2D = $Hitbox ## o colisor do CORPO (os inimigos encostam nele); a hitbox do golpe é a `_melee_area`
@onready var _melee_area: Area2D = $Pivot/Body/MeleeHitbox
@onready var _melee_shape: CollisionShape2D = $Pivot/Body/MeleeHitbox/CollisionShape2D
@onready var _beam: PointLight2D = $Pivot/Body/Muzzle/FlashlightBeam


@export var _speed := 160.0
@export var _hp := 100
@export var _feet_turn_speed := 12.0

@export var _weapons : Array[WeaponData] = []
## Variável de controle da lanterna (equipamento 5): desligada, ela não pode ser equipada (tecla 5 e Tab a ignoram).
## Ligue pelo Inspector ou por código (`player.has_flashlight = true`). Desligar com ela na mão troca para a primeira arma.
## Vive no jogador, que é recriado a cada fase: para manter entre fases, guarde o valor no GameController e reaplique.
@export var has_flashlight := false: set = set_has_flashlight

## As armas da run: cópias das `_weapons` já com as cartas de recompensa aplicadas (GameController.upgraded). É esta lista que o
## jogador usa; as `_weapons` e os `.tres` ficam como estão, senão a melhoria vazaria para a próxima run.
var _loadout: Array[WeaponData] = []
var _weapon: WeaponData
var _weapon_index := 0
var _is_reloading := false
var _reload_serial := 0 ## cada recarga tem um número: a espera de uma recarga cancelada não completa nada
var _ammo: Dictionary[WeaponData, int] = {}

var _fire_cooldown := 0.0
var _swinging := false ## golpe corpo a corpo em andamento: a hitbox só fere na janela de frames da arma (melee_hit_frames)
var _melee_hit: Array[Node2D] = [] ## quem já levou o golpe atual: cada alvo apanha uma vez por golpe
var _locked := false ## chegando ou saindo por um portal: sem controle e sem dano
var _departing := false ## já entrou no portal de saída (a trava não termina mais)

const BULLET_SCENE := preload("res://Scenes/Bullet.tscn")
const CROSSHAIR_SCENE := preload("res://Scenes/Crosshair.tscn")

## Perto demais do corpo não há ângulo que faça o cano passar pelo mouse: limita a correção do cano a 30° (seno 0,5).
const MAX_BARREL_SINE := 0.5

const WORLD_LAYER := 1 ## paredes: a única camada que o raio de linha de visão do golpe enxerga
const MELEE_ARC_SEGMENTS := 8 ## divisões do arco do setor da hitbox corpo a corpo


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


## Equipa a arma `index`. Se ela não está disponível (a lanterna sem `has_flashlight`), vai para a próxima disponível.
func _equip(index: int) -> void:
	if _is_reloading:
		_cancel_reload()
	_weapon_index = _next_available(index)
	_weapon = _loadout[_weapon_index]
	_swinging = false # trocar no meio de um golpe o cancela
	_body.sprite_frames = _weapon.sprite_frames
	_muzzle.position = _weapon.muzzle_offset
	_beam.visible = _weapon.is_flashlight
	_build_melee_shape()
	_body.play(&"idle")
	GameController.report_weapon(_weapon.display_name)
	_report_ammo()


## A lanterna só existe para o jogador com `has_flashlight`; as demais armas estão sempre disponíveis.
func _is_available(weapon: WeaponData) -> bool:
	return has_flashlight or not weapon.is_flashlight


## Primeiro índice disponível a partir de `index` (com volta ao começo da lista).
func _next_available(index: int) -> int:
	var count := _loadout.size()
	for step in count:
		var candidate := wrapi(index + step, 0, count)
		if _is_available(_loadout[candidate]):
			return candidate
	return 0


func set_has_flashlight(value: bool) -> void:
	has_flashlight = value
	if not value and _weapon != null and _weapon.is_flashlight:
		_equip(0) # perdeu a lanterna que estava na mão


## Monta a hitbox do golpe da arma equipada: um setor de círculo com o vértice na cabeça (nó Body) e aberto para a mira.
## Armas de fogo não têm hitbox (o colisor fica desligado).
func _build_melee_shape() -> void:
	_melee_shape.disabled = not _weapon.is_melee
	if not _weapon.is_melee:
		return
	var half := deg_to_rad(_weapon.melee_arc_degrees) * 0.5
	var center := deg_to_rad(_weapon.melee_arc_offset_degrees)
	var points := PackedVector2Array([Vector2.ZERO])
	for i in MELEE_ARC_SEGMENTS + 1:
		var angle := center - half + 2.0 * half * i / MELEE_ARC_SEGMENTS
		points.append(Vector2.from_angle(angle) * _weapon.melee_range)
	var sector := ConvexPolygonShape2D.new() # um por equipar: o alcance e a abertura mudam de arma para arma
	sector.set_point_cloud(points)
	_melee_shape.shape = sector


## Chamado todo quadro de física. Durante os frames `melee_hit_frames` da animação `meleeattack`, fere uma vez cada alvo
## que a hitbox toca. Roda aqui (e não no sinal `body_entered`) para não ferir o alvo dentro do callback de física e porque
## um alvo que já estava dentro quando a janela abriu, ou que entra nela depois, também apanha. Também faz a consulta do raio.
func _update_melee() -> void:
	if not _swinging:
		return
	var frame: int = _body.frame
	if _hp <= 0 or _locked or _body.animation != &"meleeattack" or frame > _weapon.melee_hit_frames.y:
		_swinging = false
		return
	if frame < _weapon.melee_hit_frames.x:
		return
	for target in _melee_area.get_overlapping_bodies():
		if target in _melee_hit or not target.has_method(&"take_damage") or not _has_line_of_sight(target):
			continue
		_melee_hit.append(target)
		target.take_damage(_weapon.damage)


## Uma parede entre o jogador e o alvo bloqueia o golpe (a bala também some na parede). Raio do centro do corpo ao
## centro do alvo, só na camada World; se o alvo estiver atrás da quina neste quadro, tenta de novo no próximo.
func _has_line_of_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(get_body_center(), target.global_position, WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _report_ammo() -> void:
	GameController.report_ammo(_ammo[_weapon], _weapon.magazine_size)


## Centro e raio do colisor do corpo (o colisor é deslocado do nó). Os inimigos usam os dois para saber a que distância encostam.
func get_body_center() -> Vector2:
	return _hitbox.global_position


func get_body_radius() -> float:
	var circle := _hitbox.shape as CircleShape2D
	return circle.radius if circle else 0.0


## Gira o corpo para que o CANO (e não o centro do corpo) aponte para `target`. O Muzzle fica deslocado para o lado da
## arma (muzzle_offset.y), então com `look_at` a bala sairia paralela à linha corpo→mouse, esse tanto à direita dela.
## Geometria: o raio do cano passa por `target` quando sen(ângulo entre corpo→mouse e o cano) = deslocamento / distância.
func _aim_at(target: Vector2) -> void:
	var to_target: Vector2 = target - _body.global_position
	var side: float = _muzzle.position.y * _body.global_scale.y
	var sine := 0.0
	if not is_zero_approx(side):
		sine = clampf(side / maxf(to_target.length(), 0.001), -MAX_BARREL_SINE, MAX_BARREL_SINE)
	_body.global_rotation = to_target.angle() - asin(sine)


## Velocidade de movimento (px/s). O chefe-espelho usa para ser "um pouco mais rápido que o jogador".
func get_move_speed() -> float:
	return _speed


func is_locked() -> bool:
	return _locked


## Chegada por um portal (início da fase): o corpo surge na cor do portal e a cor escorre até a paleta original.
## Sem controle e sem dano até o fim do efeito.
func arrive(color: Color, duration: float) -> void:
	_locked = true
	velocity = Vector2.ZERO
	var tween := PortalFx.arrive([_feet, _body], color, duration)
	await tween.finished
	if not _departing: # uma saída que começou durante a chegada manda mais
		_locked = false


## Saída por um portal: a cor sobe e o corpo some. Fica travado (a cena vai ser trocada em seguida).
func depart(color: Color, duration: float) -> void:
	_departing = true
	_locked = true
	velocity = Vector2.ZERO
	_feet.play(&"idle")
	PortalFx.depart([_feet, _body], color, duration)


func take_damage(amount: int) -> void:
	if _hp <= 0 or _locked:
		return
	_hp = maxi(_hp - amount, 0)
	GameController.player_hp = _hp


func _fire_weapon():
	if _fire_cooldown > 0.0 || _is_reloading:
		return
	if not _weapon.is_melee :
		if _ammo[_weapon] <= 0 :
			print("No Ammo Left, Reload!")
			return
		_ammo[_weapon] -= 1
		_report_ammo()
		_show_muzzle_flash()
		_body.play(&"shoot")
		for i in _weapon.pellets:
			var t := 0.5 if _weapon.pellets == 1 else float(i) / (_weapon.pellets - 1)
			var angle := lerpf(-_weapon.spread_degrees, _weapon.spread_degrees, t)
			_spawn_bullet(deg_to_rad(angle + randf_range(-1.5, 1.5)))

	else:
		_body.play(&"meleeattack")
		_body.set_frame_and_progress(0, 0.0) # play() não reinicia uma animação que já está tocando (golpes em sequência)
		_melee_hit.clear()
		_swinging = true
	_fire_cooldown = _weapon.fire_interval

func _handle_aim() -> void:
	_aim_at(get_global_mouse_position())
	if _weapon.is_automatic && Input.is_action_pressed("fire_weapon"):		
		_fire_weapon()
	elif Input.is_action_just_pressed("fire_weapon") :
		_fire_weapon()
	
## Recarrega a arma equipada. O marcador na mira (Crosshair) acompanha pelos sinais reload_*.
func _start_reload() -> void:
	if _is_reloading or _weapon.is_melee or _ammo[_weapon] >= _weapon.magazine_size:
		return
	_is_reloading = true
	_reload_serial += 1
	var serial := _reload_serial
	var weapon := _weapon # trocar de arma cancela a recarga, mas a espera não pode ler `_weapon` depois
	GameController.report_reloading(true)
	reload_started.emit(weapon.reload_time)
	await get_tree().create_timer(weapon.reload_time).timeout
	if serial != _reload_serial:
		return # cancelada enquanto esperava
	_ammo[weapon] = weapon.magazine_size
	_report_ammo()
	_is_reloading = false
	GameController.report_reloading(false)
	reload_finished.emit()


func _cancel_reload() -> void:
	_reload_serial += 1
	_is_reloading = false
	GameController.report_reloading(false)
	reload_cancelled.emit()


func _handle_equipament() -> void:
	if Input.is_action_just_pressed("reload"):
		_start_reload()

	if Input.is_action_just_pressed("swap_weapon"):
		_equip(_weapon_index+1)
	for i in _loadout.size():
		var action := "equip_weapon_%d" % (i + 1)
		if InputMap.has_action(action) and Input.is_action_just_pressed(action) and _is_available(_loadout[i]):
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
	add_to_group(&"player")
	add_child(CROSSHAIR_SCENE.instantiate())
	GameController.player_hp = _hp
	for weapon in _weapons:
		_loadout.append(GameController.upgraded(weapon))
	for weapon in _loadout:
		_ammo[weapon] = weapon.magazine_size
	if not _loadout.is_empty():
		_equip(0)

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _locked:
		_aim_at(get_global_mouse_position()) # o corpo já acompanha o mouse, só não age
		_feet.play(&"idle")
	elif _hp > 0:
		_handle_input(delta)
	_update_melee()
	
