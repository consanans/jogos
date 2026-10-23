class_name Lote
extends Pincel
## O pincel que junta tudo num lote só: em vez de mandar cada elipse, linha e retângulo pra placa de vídeo
## (centenas de chamadas por quadro, pesado em celular velho), monta uma lista de triângulos com a cor em
## cada ponta e manda de uma vez. A borda de cada forma ganha uma franja de um ponto de tela que some
## (o antisserrilhado), como o canvas do navegador faz sozinho.

var _pts := PackedVector2Array()
var _cores := PackedColorArray()
var _idx := PackedInt32Array()
var _fr := 1.0          # a franja: um ponto de tela, nas unidades do nó
var _esc := 1.0         # do nó pra ponto de tela de verdade
var chamadas := 0


func comeca() -> void:
	super.comeca()
	_pts.clear()
	_cores.clear()
	_idx.clear()
	chamadas = 0
	var vp := ci.get_viewport()
	var est := 1.0
	if vp != null:
		est = vp.get_final_transform().x.length()
	_esc = maxf(0.001, ci.get_global_transform_with_canvas().x.length() * est)
	_fr = 1.0 / _esc


## Manda o que juntou pra placa de vídeo (uma chamada).
func fecha() -> void:
	if _idx.size() > 0:
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _idx, _pts, _cores)
		ci.draw_set_transform_matrix(m)
		chamadas += 1
	_pts.clear()
	_cores.clear()
	_idx.clear()


# ---------------------------------------------------------------- formas
## Polígono convexo (o que o jogo desenha é todo convexo: elipse, retângulo, trapézio).
func poligono(pts: PackedVector2Array, c: Color, aa := true) -> void:
	var n := pts.size()
	if n < 3:
		return
	var k := cor(c)
	var k0 := Color(k.r, k.g, k.b, 0.0)
	var q := PackedVector2Array()
	q.resize(n)
	for i in n:
		q[i] = m * pts[i]
	# a orientação (pra franja ir pra fora)
	var area := 0.0
	for i in n:
		var a := q[i]
		var b := q[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var s := 1.0 if area > 0.0 else -1.0
	var base := _pts.size()
	if not aa:
		for i in n:
			_pts.append(q[i])
			_cores.append(k)
		for i in range(1, n - 1):
			_idx.append(base); _idx.append(base + i); _idx.append(base + i + 1)
		return
	var h := _fr * 0.5
	# normal de cada ponta: a média das normais dos dois lados
	for i in n:
		var a := q[(i + n - 1) % n]
		var b := q[i]
		var d := q[(i + 1) % n]
		var e1 := (b - a)
		var e2 := (d - b)
		var n1 := Vector2(e1.y, -e1.x) * s
		var n2 := Vector2(e2.y, -e2.x) * s
		var l1 := n1.length()
		var l2 := n2.length()
		if l1 > 0.0:
			n1 /= l1
		if l2 > 0.0:
			n2 /= l2
		var nm := n1 + n2
		var ln := nm.length()
		if ln < 0.0001:
			nm = n1
		else:
			nm /= ln
			var cosm := nm.dot(n1)
			if cosm > 0.25:
				nm /= cosm
			else:
				nm *= 4.0
		_pts.append(b - nm * h)
		_cores.append(k)
		_pts.append(b + nm * h)
		_cores.append(k0)
	for i in range(1, n - 1):
		_idx.append(base); _idx.append(base + 2 * i); _idx.append(base + 2 * (i + 1))
	for i in n:
		var a := base + 2 * i
		var b := base + 2 * ((i + 1) % n)
		_idx.append(a); _idx.append(a + 1); _idx.append(b + 1)
		_idx.append(a); _idx.append(b + 1); _idx.append(b)


func elipse(cx: float, cy: float, rx: float, ry: float, rot: float, c: Color) -> void:
	poligono(elipse_pts(cx, cy, rx, ry, rot, _lados(maxf(rx, ry))), c)


func circulo(cx: float, cy: float, r: float, c: Color) -> void:
	poligono(elipse_pts(cx, cy, r, r, 0.0, _lados(r)), c)


func _lados(r: float) -> int:
	# quantos lados pra parecer redondo do tamanho que aparece na tela
	var px := r * m.x.length() * _esc
	return clampi(int(px * 1.2) + 6, 8, 40)


func retangulo(x: float, y: float, w: float, h: float, c: Color) -> void:
	poligono(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), c)


func contorno_ret(x: float, y: float, w: float, h: float, c: Color, lw: float) -> void:
	linha(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x, y)]), c, lw, false)


func contorno_elipse(cx: float, cy: float, rx: float, ry: float, rot: float, c: Color, w: float) -> void:
	var p := elipse_pts(cx, cy, rx, ry, rot, _lados(maxf(rx, ry)))
	p.append(p[0])
	linha(p, c, w, false)


func arco(cx: float, cy: float, r: float, a0: float, a1: float, c: Color, w: float) -> void:
	var n := maxi(3, int(absf(a1 - a0) * float(_lados(r)) / TAU) + 1)
	var o := PackedVector2Array()
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		o.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	linha(o, c, w, false)


func seg(x1: float, y1: float, x2: float, y2: float, c: Color, w: float, redonda := true) -> void:
	linha(PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)]), c, w, redonda)


## Linha grossa: um retângulo por pedaço, com a franja dos lados; redonda põe um círculo nas pontas e juntas.
func linha(pts: PackedVector2Array, c: Color, w: float, redonda := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var esc := m.x.length()
	var wl := w * esc                     # a largura nas unidades do nó
	var k := cor(c)
	if wl < _fr:
		# mais fina que um ponto: um ponto de largura, mais clarinha
		k.a *= wl / _fr
		wl = _fr
	var k0 := Color(k.r, k.g, k.b, 0.0)
	var meio := maxf(0.0, (wl - _fr) * 0.5)
	var fora := (wl + _fr) * 0.5
	var q := PackedVector2Array()
	q.resize(n)
	for i in n:
		q[i] = m * pts[i]
	for i in range(1, n):
		var a := q[i - 1]
		var b := q[i]
		var d := b - a
		var l := d.length()
		if l < 0.00001:
			continue
		var nv := Vector2(-d.y, d.x) / l
		var base := _pts.size()
		_pts.append(a + nv * fora); _cores.append(k0)
		_pts.append(a + nv * meio); _cores.append(k)
		_pts.append(a - nv * meio); _cores.append(k)
		_pts.append(a - nv * fora); _cores.append(k0)
		_pts.append(b + nv * fora); _cores.append(k0)
		_pts.append(b + nv * meio); _cores.append(k)
		_pts.append(b - nv * meio); _cores.append(k)
		_pts.append(b - nv * fora); _cores.append(k0)
		for j in 3:
			var a0 := base + j
			var b0 := base + 4 + j
			_idx.append(a0); _idx.append(b0); _idx.append(b0 + 1)
			_idx.append(a0); _idx.append(b0 + 1); _idx.append(a0 + 1)
	if redonda and wl > _fr * 1.5:
		var r := wl * 0.5 / esc
		var mm := m
		for i in n:
			poligono(elipse_pts(pts[i].x, pts[i].y, r, r, 0.0, _lados(r)), c)
		m = mm


func _fino() -> float:
	return _fr / maxf(0.001, m.x.length())


# ---------------------------------------------------------------- o que não vira triângulo
func texto(x: float, y: float, s: String, fonte: Font, tam: float, c: Color, alinh := -1, contorno := 0.0, cor_contorno := Color.BLACK) -> void:
	fecha()
	super.texto(x, y, s, fonte, tam, c, alinh, contorno, cor_contorno)
	chamadas += 1


func textura(t: Texture2D, r: Rect2, modula := Color.WHITE) -> void:
	fecha()
	ci.draw_texture_rect(t, r, false, cor(modula))
	chamadas += 1
