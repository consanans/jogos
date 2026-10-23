class_name ItemCaixa
extends Control
## Um item da caixa de tralha: o desenho da peça, o nome e quantos ainda tem.
## Tocar põe a peça sozinha num lugar livre; arrastar leva ela pra onde o dedo for.

signal tocou(tipo: String)
signal arrasto_comeca(tipo: String, toque: bool, gpos: Vector2)
signal arrasto_move(gpos: Vector2)
signal arrasto_solta(gpos: Vector2)

var tipo := ""
var n := 0
var desligado := false
var estreito := false
var _peca: Peca
var _pend := {}
var _arrastando := false


func _init(t: String) -> void:
	tipo = t
	_peca = Peca.nova(t, 0, 0, 0, 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	focus_mode = Control.FOCUS_ALL
	tooltip_text = ""


func _get_minimum_size() -> Vector2:
	return Vector2(40, 60)


func define(qtd: int, desl: bool) -> void:
	n = qtd
	desligado = desl
	queue_redraw()


func _draw() -> void:
	var vazio := n <= 0
	var a := 0.38 if vazio else 1.0
	RenderingServer.canvas_item_add_polygon(get_canvas_item(), Kit.rasgo_pts(Rect2(Vector2.ZERO, size)), PackedColorArray([Color(Dados.FITA, a)]))
	# a miniatura (como o canvas de 124x68 da web, mostrado em 62x34)
	var bb := _peca.caixa(true)
	var x0 := bb.position.x
	var y0 := bb.position.y
	var x1 := bb.end.x
	var y1 := bb.end.y
	if tipo == "colchao":
		y0 -= 14
	if tipo == "caramelo":
		x0 -= 4
		y0 -= 6
	var s := minf(minf(112.0 / (x1 - x0), 60.0 / (y1 - y0)), 1.4) / 2.0
	var largura_mini := minf(62.0, size.x - 4)
	s *= largura_mini / 62.0
	var centro := Vector2(size.x / 2.0, 5 + 17)
	var base := Transform2D(0.0, centro) * Transform2D.IDENTITY.scaled(Vector2(s, s)) * Transform2D(0.0, -Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0))
	var c := Ctx.new(self, base, s * maxf(1.0, get_global_transform_with_canvas().get_scale().x))
	c.alfa = a
	Pinta.peca(c, _peca, 0.0, false, 0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var f := Fontes.caneta()
	var tam := 11.5 if estreito else 13.0
	var nome: String = Dados.TIPOS[tipo].curto
	var w := Ctx.largura(nome, f, tam)
	while w > size.x - 6 and tam > 8:
		tam -= 0.5
		w = Ctx.largura(nome, f, tam)
	var cor := Color(Dados.TINTA, a)
	draw_string(f, Vector2((size.x - w) / 2.0, size.y - 8), nome, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, int(tam), cor)
	var fn := Fontes.txt(800)
	var q := "×%d" % n
	draw_string(fn, Vector2(size.x - 5 - Ctx.largura(q, fn, 11), 4 + fn.get_ascent(11)), q, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cor)
	if has_focus() and Botao.teclado:
		draw_rect(Rect2(Vector2.ZERO, size).grow(2), Dados.VAI, false, 3.0)


func _gui_input(ev: InputEvent) -> void:
	if desligado:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var toque: bool = ev.device == InputEvent.DEVICE_ID_EMULATION
			_pend = { "pos": ev.position, "toque": toque }
			_arrastando = false
			accept_event()
		else:
			if _arrastando:
				arrasto_solta.emit(get_global_transform() * ev.position)
			elif not _pend.is_empty():
				tocou.emit(tipo)
			_pend = {}
			_arrastando = false
			accept_event()
	elif ev is InputEventMouseMotion and not _pend.is_empty():
		var g: Vector2 = get_global_transform() * ev.position
		if not _arrastando:
			if ev.position.distance_to(_pend.pos) < 6 or n <= 0:
				return
			_arrastando = true
			arrasto_comeca.emit(tipo, _pend.toque, g)
		arrasto_move.emit(g)
		accept_event()
	elif ev is InputEventKey and ev.pressed and (ev.keycode == KEY_ENTER or ev.keycode == KEY_SPACE or ev.keycode == KEY_KP_ENTER):
		tocou.emit(tipo)
		accept_event()
