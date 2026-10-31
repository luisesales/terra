extends CanvasLayer
## Mira na tela. O Player gira o corpo para que o CANO aponte para o mouse (Player._aim_at), então a bala passa por aqui.
## Fica numa CanvasLayer própria: não é escurecida pelo CanvasModulate nem acompanha a câmera (usa a posição do mouse na tela).
## Esconde o cursor do sistema enquanto existir e o devolve ao sair da árvore (menu, troca de cena).
## Recarga: um círculo em volta da mira começa a se fechar quando a recarga começa (Player.reload_started) e fecha de vez
## quando ela termina (reload_finished). Se a recarga for cancelada (troca de arma) o círculo some sem fechar.

const RING_RADIUS := 13.0 ## palpite
const TICK_START := 20.0
const TICK_END := 30.0
const CENTER_DOT := 2.5
const LINE_WIDTH := 2.5
const OUTLINE_WIDTH := 6.0
const COLOR := Color(1.0, 1.0, 1.0, 0.95)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.85)
const RELOAD_RADIUS := 44.0 ## palpite: fora das marcas da mira (20 a 30 px)
const RELOAD_WIDTH := 5.0
const RELOAD_COLOR := Color(1.0, 0.8, 0.2, 1.0) ## amarelo: se distingue do branco da mira
const RELOAD_FLASH := 0.3 ## s: o círculo fechado brilha e some depois de terminar

@onready var _reticle: Node2D = $Reticle

var _reload_time := 0.0 ## duração da recarga em andamento (0 = nenhuma)
var _reload_left := 0.0
var _flash_left := 0.0


func _ready() -> void:
	_reticle.draw.connect(_draw_reticle)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_follow_mouse()
	var player := get_parent()
	if player and player.has_signal(&"reload_started"):
		player.reload_started.connect(_on_reload_started)
		player.reload_finished.connect(_on_reload_finished)
		player.reload_cancelled.connect(_on_reload_cancelled)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_follow_mouse()
	if _reload_left > 0.0:
		_reload_left = maxf(_reload_left - delta, 0.0)
		_reticle.queue_redraw()
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_reticle.queue_redraw()


## 0 = recarga recém-começada, 1 = círculo fechado.
func reload_progress() -> float:
	return 0.0 if _reload_time <= 0.0 else 1.0 - _reload_left / _reload_time


func _on_reload_started(duration: float) -> void:
	_reload_time = maxf(duration, 0.01)
	_reload_left = _reload_time
	_flash_left = 0.0
	_reticle.queue_redraw()


func _on_reload_finished() -> void:
	_reload_left = 0.0 # fecha de vez (o timer do jogador e o daqui podem diferir por um quadro)
	_flash_left = RELOAD_FLASH
	_reticle.queue_redraw()


func _on_reload_cancelled() -> void:
	_reload_time = 0.0
	_reload_left = 0.0
	_flash_left = 0.0
	_reticle.queue_redraw()


func _follow_mouse() -> void:
	_reticle.position = get_viewport().get_mouse_position()


func _draw_reticle() -> void:
	# primeiro o contorno preto (mais grosso), depois o traço branco por cima: legível no chão claro e no escuro
	for pass_index in 2:
		var color := OUTLINE if pass_index == 0 else COLOR
		var width := OUTLINE_WIDTH if pass_index == 0 else LINE_WIDTH
		_reticle.draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 32, color, width, true)
		for k in 4:
			var dir := Vector2.from_angle(k * PI / 2.0)
			_reticle.draw_line(dir * TICK_START, dir * TICK_END, color, width)
	_reticle.draw_circle(Vector2.ZERO, CENTER_DOT + 1.5, OUTLINE)
	_reticle.draw_circle(Vector2.ZERO, CENTER_DOT, COLOR)
	_draw_reload_ring()


## O círculo da recarga: um trilho fraco e o arco amarelo que cresce a partir do topo, em sentido horário, até fechar.
func _draw_reload_ring() -> void:
	if _reload_time <= 0.0:
		return
	var closing := _reload_left > 0.0
	if not closing and _flash_left <= 0.0:
		return
	var progress := reload_progress()
	var alpha := 1.0 if closing else _flash_left / RELOAD_FLASH
	var width := RELOAD_WIDTH if closing else RELOAD_WIDTH + 3.0 * alpha # ao fechar, dá um "pulso" que some
	var color := Color(RELOAD_COLOR, alpha)
	var start := -PI / 2.0
	_reticle.draw_arc(Vector2.ZERO, RELOAD_RADIUS, 0.0, TAU, 48, Color(OUTLINE, 0.35 * alpha), width + 2.0, true)
	if progress <= 0.0:
		return
	var end := start + TAU * progress
	_reticle.draw_arc(Vector2.ZERO, RELOAD_RADIUS, start, end, maxi(int(48.0 * progress), 3), Color(OUTLINE, OUTLINE.a * alpha), width + 4.0, true)
	_reticle.draw_arc(Vector2.ZERO, RELOAD_RADIUS, start, end, maxi(int(48.0 * progress), 3), color, width, true)
	if closing:
		_reticle.draw_circle(Vector2.from_angle(end) * RELOAD_RADIUS, width * 0.7, color) # ponta do arco
