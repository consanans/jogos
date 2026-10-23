class_name BotaoCaixa
extends Button
## Um botão com conteúdo dentro (miniatura, nome, recorde): ele cresce do tamanho do que tem dentro.
## (O Button calcula o tamanho mínimo dele no C++, então quem manda aqui é o custom_minimum_size.)

var dentro: Control:
	set(c):
		dentro = c
		if c != null:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.set_anchors_preset(Control.PRESET_FULL_RECT)
			c.minimum_size_changed.connect(_acerta)
			_acerta()


func _ready() -> void:
	resized.connect(_acerta)


func _acerta() -> void:
	if dentro == null:
		return
	var m := dentro.get_combined_minimum_size()
	if not is_equal_approx(custom_minimum_size.y, m.y):
		custom_minimum_size = Vector2(0, m.y)
