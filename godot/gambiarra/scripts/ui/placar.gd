class_name Placar
extends PanelContainer
## O placar em fita crepe: "Ponto de Gambiarra", o número que pula a cada ponto, a corrente e a
## bolinha vermelha piscando enquanto grava o beat.

var _tit: Label
var _num: Label
var _cor: Label
var _gravando := false
var _estreito := false
var reduz := false


func _init() -> void:
	add_theme_stylebox_override("panel", Kit.EstiloRasgo.new(Dados.FITA, 12, 7))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	_tit = Kit.rotulo("PONTO DE GAMBIARRA", Kit.espacada(Fontes.txt(800), 1), 10, Dados.TINTA2)
	v.add_child(_tit)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	_num = Kit.rotulo("0", Fontes.letreiro(), 25, Dados.TINTA)
	h.add_child(_num)
	_cor = Kit.rotulo("corrente 0", Fontes.txt(600), 12, Dados.TINTA)
	_cor.size_flags_vertical = Control.SIZE_SHRINK_END
	_cor.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	h.add_child(_cor)
	resized.connect(_ajeita)


func _ajeita() -> void:
	pivot_offset = size / 2.0
	rotation = deg_to_rad(1.4)
	_num.pivot_offset = _num.size / 2.0


func estreito(sim: bool) -> void:
	_estreito = sim
	var est := get_theme_stylebox("panel") as Kit.EstiloRasgo
	est.content_margin_left = 9 if sim else 12
	est.content_margin_right = 9 if sim else 12
	est.content_margin_top = 6 if sim else 7
	est.content_margin_bottom = 5 if sim else 6
	_tit.label_settings.font_size = 9 if sim else 10
	_tit.custom_minimum_size.x = Ctx.largura(_tit.text, _tit.label_settings.font, _tit.label_settings.font_size) + 14
	_num.label_settings.font_size = 21 if sim else 25
	_cor.label_settings.font_size = 11 if sim else 12


func _process(_dt: float) -> void:
	if _gravando:
		queue_redraw()


func _draw() -> void:
	# a bolinha vermelha do "gravando o beat", no canto de cima, piscando
	if _gravando and (reduz or int(Time.get_ticks_msec() / 500) % 2 == 0):
		draw_circle(Vector2(size.x - 14.5, 11.5), 4.5, Dados.PERIGO, true, -1.0, true)


func pontos(n: int, pula := true) -> void:
	_num.text = str(n)
	if pula and n > 0 and not reduz:
		_num.pivot_offset = _num.size / 2.0
		var tw := create_tween()
		tw.tween_property(_num, "scale", Vector2(1.28, 1.28), 0.128)
		tw.parallel().tween_property(_num, "rotation", deg_to_rad(-4), 0.128)
		tw.tween_property(_num, "scale", Vector2.ONE, 0.192)
		tw.parallel().tween_property(_num, "rotation", 0.0, 0.192)


func corrente(txt: String, gravando: bool) -> void:
	_cor.text = txt
	_gravando = gravando
	queue_redraw()
