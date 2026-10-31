class_name CardView
extends Button
## Uma carta na tela de recompensa: número e arma, imagem da arma, título, o que muda ("antes → depois") e uma frase.
## O Button inteiro é a carta (clique, Enter/Espaço ou A do controle quando está com o foco).

signal chosen(card: CardData)

@onready var _header: Label = $Margin/Column/Header
@onready var _icon: TextureRect = $Margin/Column/Icon
@onready var _title: Label = $Margin/Column/Title
@onready var _effects: Label = $Margin/Column/Effects
@onready var _flavor: Label = $Margin/Column/Flavor

var card: CardData


## `current` é a arma como o jogador a tem agora (com as cartas anteriores): o "antes" do "antes → depois". Chamar depois de add_child.
func setup(new_card: CardData, current: WeaponData, number: int) -> void:
	card = new_card
	_header.text = "%d  ·  %s" % [number, new_card.weapon.display_name.to_upper()]
	_title.text = new_card.title
	_effects.text = "\n".join(new_card.describe(current))
	_flavor.text = new_card.description
	_icon.texture = _weapon_icon(new_card.weapon)
	pressed.connect(func() -> void: chosen.emit(card))


## O 1º quadro de `idle` do jogador com essa arma (o corpo segurando a arma). Sem a margem transparente do quadro
## (`margin` do AtlasTexture, que o centraliza no pivô): só o desenho, para ocupar o espaço do ícone.
func _weapon_icon(weapon: WeaponData) -> Texture2D:
	if weapon.sprite_frames == null or not weapon.sprite_frames.has_animation(&"idle"):
		return null
	var frame := weapon.sprite_frames.get_frame_texture(&"idle", 0)
	if frame is AtlasTexture:
		var tight := frame.duplicate() as AtlasTexture
		tight.margin = Rect2()
		return tight
	return frame
