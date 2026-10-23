class_name CartaoBox
extends Control
## Um cartão de folha de caderno no meio do palco (o começo, o fim, as fases):
## até 400 de largura, rola quando não cabe, com a sombra dura embaixo.

var rolo: ScrollContainer
var card: PanelContainer
var conteudo: VBoxContainer
var _estilo: Kit.EstiloCaderno


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rolo = ScrollContainer.new()
	rolo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rolo)
	var barra := rolo.get_v_scroll_bar()
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color(0, 0, 0, 0)
	trilho.content_margin_left = 3
	trilho.content_margin_right = 3
	barra.add_theme_stylebox_override("scroll", trilho)
	barra.add_theme_stylebox_override("scroll_focus", trilho)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		barra.add_theme_stylebox_override(k, Kit.estilo_caixa(Color(Dados.TINTA2, 0.55 if k == "grabber" else 0.8), 3))
	rolo.scroll_deadzone = 6
	card = PanelContainer.new()
	_estilo = Kit.EstiloCaderno.new()
	card.add_theme_stylebox_override("panel", _estilo)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolo.add_child(card)
	conteudo = VBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 12)
	card.add_child(conteudo)


func estreito(sim: bool) -> void:
	_estilo.esq = 26.0 if sim else 30.0
	_estilo.content_margin_left = 26 if sim else 30
	_estilo.content_margin_right = 14 if sim else 18
	_estilo.content_margin_top = 14 if sim else 18
	_estilo.content_margin_bottom = 14 if sim else 16
	conteudo.add_theme_constant_override("separation", 10 if sim else 12)


func rola_topo() -> void:
	rolo.scroll_vertical = 0


func _process(_dt: float) -> void:
	if not visible:
		return
	var w := minf(400.0, size.x)
	var h := card.get_combined_minimum_size().y
	var hh := minf(h, size.y)
	var nova := Rect2((size.x - w) / 2.0, (size.y - hh) / 2.0, w, hh)
	if Rect2(rolo.position, rolo.size) != nova:
		rolo.position = nova.position
		rolo.size = nova.size
		queue_redraw()


func _draw() -> void:
	var r := Rect2(rolo.position + Vector2(0, 14), rolo.size)
	draw_style_box(Kit.estilo_caixa(Color(0, 0, 0, 0.28), 6), r)
