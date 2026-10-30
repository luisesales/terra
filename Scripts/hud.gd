extends CanvasLayer
## HUD mínimo: tempo restante, PV e munição, ligados aos sinais do GameController; mensagem de morte/vitória.

const INFINITE_AMMO_THRESHOLD := 9999 ## a faca tem carregador de 99999999: mostra ∞

@onready var _time: Label = $Root/TimeLabel
@onready var _hp: Label = $Root/HpLabel
@onready var _ammo: Label = $Root/AmmoLabel
@onready var _message: Label = $Root/MessageLabel

var _shown_seconds := -1


func _ready() -> void:
	GameController.player_hp_changed.connect(_on_hp_changed)
	GameController.ammo_changed.connect(_on_ammo_changed)
	GameController.run_started.connect(_refresh_message)
	GameController.player_died.connect(_refresh_message)
	GameController.run_won.connect(_refresh_message)
	_on_hp_changed(GameController.player_hp)
	_on_ammo_changed(GameController.ammo, GameController.magazine_size)
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
	_ammo.text = "∞" if magazine > INFINITE_AMMO_THRESHOLD else "%d / %d" % [ammo, magazine]


func _refresh_message() -> void:
	match GameController.state:
		GameController.State.DEAD:
			_message.text = "VOCÊ MORREU\nEnter para reiniciar"
		GameController.State.WON:
			_message.text = "VITÓRIA!\nEnter para reiniciar"
		_:
			_message.text = ""
	_message.visible = _message.text != ""
