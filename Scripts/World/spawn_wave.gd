class_name SpawnWave
extends Resource
## Uma linha da tabela de ondas: a partir de `start`, `enemy` entra no sorteio com `weight`.

## Segundos desde o início da run.
@export var start := 0.0
@export var enemy: EnemyData
## Peso no sorteio entre as linhas ativas.
@export var weight := 1.0
## Segundos entre nascimentos. Vale o menor intervalo entre as linhas ativas de início mais recente.
@export var interval := 1.5
