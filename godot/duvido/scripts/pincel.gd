class_name Pincel
extends RefCounted
## Um pincel do jeito do canvas 2D do navegador: save/restore, translate/rotate/scale e uns desenhos
## (elipse, linha com ponta redonda, texto do tamanho certo). É com ele que o carrinho, o caramelo,
## a mola e o resto são desenhados igual à versão web.

var ci: CanvasItem
var m := Transform2D.IDENTITY
var alpha := 1.0
var _pilha: Array = []


func _init(alvo: CanvasItem) -> void:
	ci = alvo


func comeca() -> void:
	m = Transform2D.IDENTITY
	alpha = 1.0
	_pilha.clear()
	ci.draw_set_transform_matrix(m)


func save() -> void:
	_pilha.append([m, alpha])


func restore() -> void:
	var t: Array = _pilha.pop_back()
	m = t[0]
	alpha = t[1]
	ci.draw_set_transform_matrix(m)


func translate(x: float, y: float) -> void:
	m = m * Transform2D(0.0, Vector2(x, y))
	ci.draw_set_transform_matrix(m)


func rotate(a: float) -> void:
	m = m * Transform2D(a, Vector2.ZERO)
	ci.draw_set_transform_matrix(m)


func scale(sx: float, sy: float) -> void:
	m = m * Transform2D(Vector2(sx, 0.0), Vector2(0.0, sy), Vector2.ZERO)
	ci.draw_set_transform_matrix(m)


func cor(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)


static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


# ---------------------------------------------------------------- formas
static var _circ := {}


func elipse_pts(cx: float, cy: float, rx: float, ry: float, rot: float = 0.0, n: int = 0) -> PackedVector2Array:
	if n <= 0:
		n = clampi(int((rx + ry) * 1.6), 12, 40)
	var u: PackedVector2Array = _circ.get(n, PackedVector2Array())
	if u.is_empty():
		for i in n:
			var a := TAU * float(i) / float(n)
			u.append(Vector2(cos(a), sin(a)))
		_circ[n] = u
	var o := PackedVector2Array()
	o.resize(n)
	if rot == 0.0:
		for i in n:
			o[i] = Vector2(cx + u[i].x * rx, cy + u[i].y * ry)
		return o
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var x := u[i].x * rx
		var y := u[i].y * ry
		o[i] = Vector2(cx + x * cr - y * sr, cy + x * sr + y * cr)
	return o


func poligono(pts: PackedVector2Array, c: Color, aa := true) -> void:
	if pts.size() < 3:
		return
	var k := cor(c)
	ci.draw_colored_polygon(pts, k)
	if aa:
		# o polígono não tem antisserrilhado: uma linha fininha em volta disfarça o degrau
		var fecha := pts.duplicate()
		fecha.append(pts[0])
		ci.draw_polyline(fecha, k, _fino(), true)


func _fino() -> float:
	# uns 0,8 ponto de tela, seja qual for a escala
	var s := m.x.length()
	return 0.8 / maxf(s, 0.001) / _escala_tela()


func _escala_tela() -> float:
	var t := ci.get_global_transform_with_canvas()
	return maxf(t.x.length(), 0.001)


func elipse(cx: float, cy: float, rx: float, ry: float, rot: float, c: Color) -> void:
	poligono(elipse_pts(cx, cy, rx, ry, rot), c)


func circulo(cx: float, cy: float, r: float, c: Color) -> void:
	poligono(elipse_pts(cx, cy, r, r), c)


func contorno_elipse(cx: float, cy: float, rx: float, ry: float, rot: float, c: Color, w: float) -> void:
	var p := elipse_pts(cx, cy, rx, ry, rot)
	p.append(p[0])
	ci.draw_polyline(p, cor(c), w, true)


func retangulo(x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), cor(c), true)


func contorno_ret(x: float, y: float, w: float, h: float, c: Color, lw: float) -> void:
	var p := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x, y)])
	ci.draw_polyline(p, cor(c), lw, true)


## Linha com ponta e junta redondas (o lineCap/lineJoin round do canvas).
func linha(pts: PackedVector2Array, c: Color, w: float, redonda := true) -> void:
	if pts.size() < 2:
		return
	var k := cor(c)
	ci.draw_polyline(pts, k, w, true)
	if redonda and w > 1.2:
		for p in pts:
			ci.draw_circle(p, w * 0.5, k, true, -1.0, true)


func seg(x1: float, y1: float, x2: float, y2: float, c: Color, w: float, redonda := true) -> void:
	linha(PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)]), c, w, redonda)


func arco(cx: float, cy: float, r: float, a0: float, a1: float, c: Color, w: float) -> void:
	var n := maxi(6, int(absf(a1 - a0) * r * 0.6))
	var o := PackedVector2Array()
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		o.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	ci.draw_polyline(o, cor(c), w, true)


static func quad(x0: float, y0: float, cx: float, cy: float, x1: float, y1: float, n := 10) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var u := 1.0 - t
		o.append(Vector2(u * u * x0 + 2.0 * u * t * cx + t * t * x1, u * u * y0 + 2.0 * u * t * cy + t * t * y1))
	return o


static func bezier(x0: float, y0: float, c1x: float, c1y: float, c2x: float, c2y: float, x1: float, y1: float, n := 14) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var u := 1.0 - t
		o.append(Vector2(u * u * u * x0 + 3.0 * u * u * t * c1x + 3.0 * u * t * t * c2x + t * t * t * x1,
			u * u * u * y0 + 3.0 * u * u * t * c1y + 3.0 * u * t * t * c2y + t * t * t * y1))
	return o


# ---------------------------------------------------------------- texto
## Texto no tamanho de tela certo (sem esticar a letra): o tamanho vem nas unidades do desenho atual.
## alinh: -1 esquerda, 0 meio, 1 direita. contorno > 0 desenha o traço por baixo (strokeText).
func texto(x: float, y: float, s: String, fonte: Font, tam: float, c: Color, alinh := -1, contorno := 0.0, cor_contorno := Color.BLACK) -> void:
	var esc := m.x.length() * _escala_tela()
	if esc <= 0.0:
		return
	var px := maxi(1, int(round(tam * esc)))
	var w := fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var ox := 0.0
	if alinh == 0:
		ox = -w * 0.5
	elif alinh == 1:
		ox = -w
	var inv := 1.0 / esc
	# o ponto (x, y) fica no lugar; a letra é desenhada em pixel de tela
	var mm := m * Transform2D(0.0, Vector2(x, y)) * Transform2D(Vector2(inv, 0.0), Vector2(0.0, inv), Vector2.ZERO)
	ci.draw_set_transform_matrix(mm)
	if contorno > 0.0:
		ci.draw_string_outline(fonte, Vector2(ox, 0.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(round(contorno * esc)), cor(cor_contorno))
	ci.draw_string(fonte, Vector2(ox, 0.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, cor(c))
	ci.draw_set_transform_matrix(m)


func largura_texto(s: String, fonte: Font, tam: float) -> float:
	var esc := m.x.length() * _escala_tela()
	var px := maxi(1, int(round(tam * esc)))
	return fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / esc
