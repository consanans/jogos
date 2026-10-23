class_name Botao
extends Button
## Botão desenhado à mão no jeito da web: o amarelo do VAI com a sombra dura embaixo,
## o de contorno, o vermelho do PARAR, os da barrinha de ferramentas com ícone.

var estilo := "vai":           # vai, linha, linha_fita, perigo, fita, tira
	set(v):
		estilo = v
		_atualiza()
var rotulo := "":
	set(v):
		rotulo = v
		_atualiza()
var tam := 16.0:
	set(v):
		tam = v
		_atualiza()
var fonte: Font = null
var raio := 10.0
var sombra := 4.0:
	set(v):
		sombra = v
		_atualiza()
var largura_min := 0.0
var altura_min := 0.0
var pad_x := 18.0
var pad_y := 13.0
var icone := ""                # gira_esq, gira_dir, x

static var teclado := false    # o anel de foco só aparece pra quem usa o teclado


func _init(txt := "", est := "vai", f: Font = null, t := 16.0) -> void:
	fonte = f if f != null else Fontes.txt(800)
	rotulo = txt
	estilo = est
	tam = t
	focus_mode = Control.FOCUS_ALL
	flat = true
	for k in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(k, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _tem_sombra() -> bool:
	return estilo == "vai" or estilo == "perigo"


func _atualiza() -> void:
	if fonte == null:
		return
	if icone != "" or rotulo == "":
		queue_redraw()
		return
	var w := Ctx.largura(rotulo, fonte, tam) + pad_x * 2.0
	var h := fonte.get_height(int(tam)) + pad_y * 2.0 + (sombra if _tem_sombra() else 0.0)
	custom_minimum_size = Vector2(maxf(w, largura_min), maxf(h, altura_min))
	queue_redraw()


func _cores() -> Array:
	# [fundo, sombra, texto, borda]
	match estilo:
		"perigo":
			return [Dados.PERIGO, Dados.PERIGO2, Color.WHITE, Color.TRANSPARENT]
		"linha":
			return [Color.TRANSPARENT, Color.TRANSPARENT, Dados.TINTA, Dados.TINTA]
		"linha_fita":
			return [Color.TRANSPARENT, Color.TRANSPARENT, Dados.FITA, Dados.FITA2]
		"fita":
			return [Dados.FITA, Color.TRANSPARENT, Dados.TINTA, Color.TRANSPARENT]
		"tira":
			return [Dados.PERIGO, Color.TRANSPARENT, Color.WHITE, Color.TRANSPARENT]
	return [Dados.VAI, Dados.VAI2, Dados.TINTA, Color.TRANSPARENT]


func _draw() -> void:
	var cs := _cores()
	var ts := _tem_sombra()
	var apertado := is_pressed()
	var s := sombra if ts else 0.0
	var h := size.y - s
	var desce := s / 2.0 if apertado and ts else 0.0
	var face := Rect2(0, desce, size.x, h)
	if ts:
		draw_style_box(Kit.estilo_caixa(cs[1], raio), Rect2(0, s if not apertado else s / 2.0, size.x, h))
	if cs[0].a > 0:
		draw_style_box(Kit.estilo_caixa(cs[0], raio), face)
	if cs[3].a > 0:
		draw_style_box(Kit.estilo_caixa(Color.TRANSPARENT, raio, 2, cs[3]), face)
	var cor_txt: Color = cs[2]
	if icone != "":
		_desenha_icone(face, cor_txt)
	elif rotulo != "":
		var asc := fonte.get_ascent(int(tam))
		var desc := fonte.get_descent(int(tam))
		var w := Ctx.largura(rotulo, fonte, tam)
		var pos := Vector2(face.position.x + (face.size.x - w) / 2.0, face.position.y + (face.size.y + asc - desc) / 2.0)
		draw_string(fonte, pos, rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), cor_txt)
	if has_focus() and teclado:
		draw_style_box(Kit.estilo_caixa(Color.TRANSPARENT, raio + 2, 3, Dados.VAI), face.grow(3))


func _desenha_icone(r: Rect2, cor: Color) -> void:
	# os ícones SVG da web (caixa de 24), desenhados em traço
	var k := 22.0 / 24.0
	var c := r.get_center()
	var m := func(x: float, y: float) -> Vector2: return c + Vector2(x - 12.0, y - 12.0) * k
	match icone:
		"gira_esq", "gira_dir":
			var esp := 1.0 if icone == "gira_esq" else -1.0
			var mx := func(x: float, y: float) -> Vector2: return m.call(12.0 + (x - 12.0) * esp, y)
			var arco := PackedVector2Array()
			for i in range(25):
				var t := deg_to_rad(156.5 - 290.9 * i / 24.0)
				arco.append(mx.call(12.4 + cos(t) * 7.5, 12.0 + sin(t) * 7.5))
			arco.append(mx.call(4, 10))
			draw_polyline(arco, cor, 2.4 * k, true)
			draw_polyline(PackedVector2Array([mx.call(4, 4), mx.call(4, 10), mx.call(10, 10)]), cor, 2.4 * k, true)
		"x":
			draw_line(m.call(6, 6), m.call(18, 18), cor, 2.6 * k, true)
			draw_line(m.call(18, 6), m.call(6, 18), cor, 2.6 * k, true)
