extends CanvasLayer
## HUD mínimo: tempo restante, PV e munição, ligados aos sinais do GameController; mensagem de morte/vitória.
## Painel da arma (canto inferior direito): nome da arma equipada, balas no carregador / tamanho do carregador e uma barra.
## A cor avisa: amarelo = pouca munição ou recarregando, vermelho = acabou.

const INFINITE_AMMO_THRESHOLD := 9999 ## a faca tem carregador de 99999999: mostra ∞
const LOW_AMMO_FRACTION := 0.34 ## palpite: abaixo disso (≈ 1/3 do pente) o contador fica amarelo
const COLOR_NORMAL := Color.WHITE
const COLOR_LOW := Color(1.0, 0.8, 0.2)
const COLOR_EMPTY := Color(1.0, 0.3, 0.25)

@onready var _time: Label = $Root/TimeLabel
@onready var _hp: Label = $Root/HpLabel
@onready var _ammo: Label = $Root/AmmoLabel
@onready var _weapon: Label = $Root/WeaponLabel
@onready var _ammo_bar: ProgressBar = $Root/AmmoBar
@onready var _message: Label = $Root/MessageLabel

var _shown_seconds := -1
var _ammo_now := 0
var _magazine_now := 0


func _ready() -> void:
	GameController.player_hp_changed.connect(_on_hp_changed)
	GameController.ammo_changed.connect(_on_ammo_changed)
	GameController.weapon_changed.connect(_on_weapon_changed)
	GameController.reloading_changed.connect(_on_reloading_changed)
	GameController.run_started.connect(_refresh_message)
	GameController.player_died.connect(_refresh_message)
	GameController.run_won.connect(_refresh_message)
	_on_hp_changed(GameController.player_hp)
	_on_ammo_changed(GameController.ammo, GameController.magazine_size)
	_refresh_ammo_panel()
	_refresh_time()
	_refresh_message()


func _process(_delta: float) -> void:
	_refresh_time()


func _refresh_time() -> void:
	var seconds := ceili(GameController.time_remaining()) # arredonda para cima: começa em 10:00 e termina em 0:00
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	_time.text = "%d:%02d" % [seconds / 60, seconds % 60]


func _on_hp_changed(hp: int) -> void:
	_hp.text = "PV %d" % hp


func _on_ammo_changed(ammo: int, magazine: int) -> void:
	_ammo_now = ammo
	_magazine_now = magazine
	_refresh_ammo_panel()


func _on_weapon_changed(_display_name: String) -> void:
	_refresh_ammo_panel()


func _on_reloading_changed(_active: bool) -> void:
	_refresh_ammo_panel()


func _refresh_ammo_panel() -> void:
	var infinite := _magazine_now > INFINITE_AMMO_THRESHOLD
	_ammo.text = "∞" if infinite else "%d / %d" % [_ammo_now, _magazine_now]
	_ammo_bar.visible = not infinite
	if not infinite:
		_ammo_bar.max_value = maxi(_magazine_now, 1)
		_ammo_bar.value = _ammo_now
	var color := COLOR_NORMAL
	var title := GameController.weapon_name
	if GameController.reloading:
		color = COLOR_LOW
		title = "RECARREGANDO…"
	elif not infinite and _ammo_now <= 0:
		color = COLOR_EMPTY
		title = "SEM MUNIÇÃO — R"
	elif not infinite and float(_ammo_now) / maxf(_magazine_now, 1.0) <= LOW_AMMO_FRACTION:
		color = COLOR_LOW
	_weapon.text = title
	_weapon.add_theme_color_override(&"font_color", color)
	_ammo.add_theme_color_override(&"font_color", color)
	_ammo_bar.modulate = color


func _refresh_message() -> void:
	match GameController.state:
		GameController.State.DEAD:
			_message.text = "VOCÊ MORREU\nEnter para reiniciar"
		GameController.State.WON:
			_message.text = "VITÓRIA!\nEnter para reiniciar"
		_:
			_message.text = ""
	_message.visible = _message.text != ""
