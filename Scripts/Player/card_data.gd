class_name CardData
extends Resource
## Carta de recompensa de fim de fase (≈ ScriptableObject do Unity): uma melhoria forte para UMA arma de fogo.
## Os multiplicadores valem sobre a arma base (1.0 = não muda). O `.tres` da arma nunca é alterado: o GameController entrega
## ao jogador uma CÓPIA da arma com as cartas escolhidas aplicadas (GameController.upgraded).

@export var title := "Carta"
@export_multiline var description := ""
@export var weapon: WeaponData ## a arma que a carta melhora (o `.tres` base: pistol, rifle ou shotgun)

@export_group("Melhorias")
@export var damage_mult := 1.0
@export var fire_interval_mult := 1.0 ## 0.5 = o intervalo entre tiros cai pela metade (cadência dobrada)
@export var reload_time_mult := 1.0 ## 0.5 = recarrega na metade do tempo
@export var magazine_mult := 1.0
@export var pellets_mult := 1.0
@export var pierce_bonus := 0 ## alvos EXTRAS que a bala atravessa


## A carta vale para essa arma? (compara o recurso base; a cópia que o jogador usa não conta, quem pergunta passa o `.tres`.)
func applies_to(base: WeaponData) -> bool:
	if weapon == null or base == null:
		return false
	return weapon == base or (weapon.resource_path != "" and weapon.resource_path == base.resource_path)


## Aplica as melhorias em `target` (uma cópia da arma: nunca o `.tres` original). Só mexe no que a carta muda.
func apply(target: WeaponData) -> void:
	if not is_equal_approx(damage_mult, 1.0):
		target.damage = maxi(roundi(target.damage * damage_mult), 1)
	if not is_equal_approx(fire_interval_mult, 1.0):
		target.fire_interval = maxf(target.fire_interval * fire_interval_mult, 0.02)
	if not is_equal_approx(reload_time_mult, 1.0):
		target.reload_time = target.reload_time * reload_time_mult
	if not is_equal_approx(magazine_mult, 1.0):
		target.magazine_size = maxi(roundi(target.magazine_size * magazine_mult), 1)
	if not is_equal_approx(pellets_mult, 1.0):
		target.pellets = maxi(roundi(target.pellets * pellets_mult), 1)
	target.pierce += pierce_bonus


## Uma linha por coisa que a carta muda, "antes → depois" a partir de `current` (a arma como o jogador a tem agora,
## já com as cartas anteriores). O texto sai dos números reais: não há como a descrição mentir.
func describe(current: WeaponData) -> PackedStringArray:
	var after := current.duplicate() as WeaponData
	apply(after)
	var lines := PackedStringArray()
	if after.damage != current.damage:
		lines.append("Dano: %d → %d" % [current.damage, after.damage])
	if not is_equal_approx(after.fire_interval, current.fire_interval):
		lines.append("Entre tiros: %s s → %s s" % [_num(current.fire_interval, 2), _num(after.fire_interval, 2)])
	if not is_equal_approx(after.reload_time, current.reload_time):
		lines.append("Recarga: %s s → %s s" % [_num(current.reload_time, 1), _num(after.reload_time, 1)])
	if after.magazine_size != current.magazine_size:
		lines.append("Pente: %d → %d" % [current.magazine_size, after.magazine_size])
	if after.pellets != current.pellets:
		lines.append("Balins por tiro: %d → %d" % [current.pellets, after.pellets])
	if after.pierce != current.pierce:
		lines.append("Atravessa: %d → %d alvos" % [current.pierce, after.pierce])
	return lines


## Número com vírgula decimal (o jogo é em português).
static func _num(value: float, decimals: int) -> String:
	return String.num(value, decimals).replace(".", ",")
