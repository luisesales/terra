class_name Boss
extends Enemy
## Chefe: o Enemy já alterna os ataques em ordem; aqui cada ataque ganha alcance/dano próprios (BossData)
## e uma barra de vida simples acima do corpo.

const BAR_SIZE := Vector2(240.0, 14.0) ## palpite

var _boss_data: BossData

@onready var _bar: Node2D = $HealthBar


func _ready() -> void:
	super()
	_bar.draw.connect(_draw_bar)
	hp_changed.connect(func(_hp_now: int, _max: int) -> void: _bar.queue_redraw())
	died.connect(func(_enemy: Enemy) -> void: _bar.hide())


func _apply_data() -> void:
	super()
	_boss_data = data as BossData
	_bar.queue_redraw()


func _attack_range(index: int) -> float:
	if _boss_data and index < _boss_data.attack_ranges.size():
		return _boss_data.attack_ranges[index]
	return super(index)


func _attack_damage(index: int) -> int:
	if _boss_data and index < _boss_data.attack_damages.size():
		return _boss_data.attack_damages[index]
	return super(index)


func _draw_bar() -> void:
	if data == null:
		return
	var origin := Vector2(-BAR_SIZE.x / 2.0, -data.collision_radius - 70.0)
	var ratio := clampf(float(_hp) / data.max_hp, 0.0, 1.0)
	_bar.draw_rect(Rect2(origin - Vector2(2, 2), BAR_SIZE + Vector2(4, 4)), Color(0, 0, 0, 0.7))
	_bar.draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), data.tier_color())
