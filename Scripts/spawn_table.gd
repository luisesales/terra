class_name SpawnTable
extends Resource
## Tabela de ondas da run. Todos os números são palpite (ver Tools/zombies/gen_spawn_table.py).
## A cada "tick" nasce 1 inimigo sorteado por peso entre as linhas ativas (start <= tempo).
## O intervalo entre ticks é o da fase mais recente, dividido pela intensidade.

@export var waves: Array[SpawnWave] = []
## Limite de inimigos comuns vivos. O chefe entra mesmo com o limite cheio.
@export var max_alive := 120
## A partir de `late_intensity_start` o intervalo é dividido por `late_intensity` (6:00 -> ×1,5).
@export var late_intensity_start := 360.0
@export var late_intensity := 1.5
## Caminhos (res://) dos BossData sorteáveis. Strings de propósito: o chefe só é carregado perto da janela (a folha do MegaBoss tem ~70 MB).
@export var boss_paths := PackedStringArray()


func active_waves(time: float) -> Array[SpawnWave]:
	var result: Array[SpawnWave] = []
	for wave in waves:
		if wave.start <= time and wave.enemy != null:
			result.append(wave)
	return result


func interval_at(time: float) -> float:
	var latest := -1.0
	var interval := 1.5
	for wave in active_waves(time):
		if wave.start > latest:
			latest = wave.start
			interval = wave.interval
		elif wave.start == latest:
			interval = minf(interval, wave.interval)
	if time >= late_intensity_start:
		interval /= late_intensity
	return interval


func pick(time: float) -> SpawnWave:
	var active := active_waves(time)
	var total := 0.0
	for wave in active:
		total += wave.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	for wave in active:
		roll -= wave.weight
		if roll <= 0.0:
			return wave
	return active.back()
