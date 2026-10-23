class_name Ctx
extends RefCounted
## Um "canvas 2D" por cima do _draw da Godot: pilha de transformação, caminhos (moveTo, lineTo, arc,
## ellipse, curvas), preenchimento com degradê, traço tracejado e texto. Assim o desenho da versão
## web passa pra cá quase linha por linha.

var ci: CanvasItem
var xf := Transform2D.IDENTITY
var alfa := 1.0
var _pilha: Array = []
var px := 1.0                 # quantos pixels de tela tem uma unidade (pra decidir quantos pontos tem uma curva)
var cap_redondo := false


func _init(c: CanvasItem, base := Transform2D.IDENTITY, pixels := 1.0) -> void:
	ci = c
	xf = base
	px = pixels
	_aplica()


func _aplica() -> void:
	ci.draw_set_transform_matrix(xf)


func save() -> void:
	_pilha.append([xf, alfa, cap_redondo])


func restore() -> void:
	var s: Array = _pilha.pop_back()
	xf = s[0]
	alfa = s[1]
	cap_redondo = s[2]
	_aplica()


func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(x, y))
	_aplica()


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)
	_aplica()


func scale(sx: float, sy: float) -> void:
	xf = xf * Transform2D.IDENTITY.scaled(Vector2(sx, sy))
	_aplica()


func escala_atual() -> float:
	return sqrt(absf(xf.determinant())) * px


func _c(cor: Color) -> Color:
	if alfa >= 1.0:
		return cor
	return Color(cor.r, cor.g, cor.b, cor.a * alfa)


# ---------- caminhos ----------
class Caminho:
	var subs: Array[PackedVector2Array] = []
	var fechados: Array[bool] = []
	var atual := PackedVector2Array()
	var esc := 1.0

	func _init(escala := 1.0) -> void:
		esc = escala

	func _novo() -> void:
		if atual.size() > 0:
			subs.append(atual)
			fechados.append(false)
		atual = PackedVector2Array()

	func move_to(x: float, y: float) -> Caminho:
		_novo()
		atual.append(Vector2(x, y))
		return self

	func line_to(x: float, y: float) -> Caminho:
		atual.append(Vector2(x, y))
		return self

	func _n_arco(r: float, da: float) -> int:
		return clampi(int(absf(da) * r * esc / 3.0) + 4, 4, 96)

	func arc(cx: float, cy: float, r: float, a0: float, a1: float, anti := false) -> Caminho:
		var da := a1 - a0
		if not anti and da < 0:
			da = fposmod(da, TAU)
		elif anti and da > 0:
			da = -fposmod(-da, TAU)
		if absf(da) > TAU:
			da = TAU * signf(da)
		var n := _n_arco(r, da)
		for i in range(n + 1):
			var t := a0 + da * i / n
			atual.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
		return self

	func circulo(cx: float, cy: float, r: float) -> Caminho:
		_novo()
		arc(cx, cy, r, 0, TAU)
		atual.remove_at(atual.size() - 1)
		fecha()
		return self

	func ellipse(cx: float, cy: float, rx: float, ry: float, rot := 0.0, a0 := 0.0, a1 := TAU, anti := false) -> Caminho:
		var da := a1 - a0
		if not anti and da < 0:
			da = fposmod(da, TAU)
		if absf(da) > TAU:
			da = TAU * signf(da)
		var n := _n_arco(maxf(rx, ry), da)
		var cr := cos(rot)
		var sr := sin(rot)
		for i in range(n + 1):
			var t := a0 + da * i / n
			var ex := cos(t) * rx
			var ey := sin(t) * ry
			atual.append(Vector2(cx + ex * cr - ey * sr, cy + ex * sr + ey * cr))
		return self

	func elipse(cx: float, cy: float, rx: float, ry: float, rot := 0.0) -> Caminho:
		_novo()
		ellipse(cx, cy, rx, ry, rot)
		atual.remove_at(atual.size() - 1)
		fecha()
		return self

	func quad_to(cx: float, cy: float, x: float, y: float) -> Caminho:
		var p0 := atual[atual.size() - 1] if atual.size() > 0 else Vector2(cx, cy)
		var n := clampi(int((p0.distance_to(Vector2(cx, cy)) + Vector2(cx, cy).distance_to(Vector2(x, y))) * esc / 4.0) + 2, 3, 40)
		for i in range(1, n + 1):
			var t := float(i) / n
			var a := p0.lerp(Vector2(cx, cy), t)
			var b := Vector2(cx, cy).lerp(Vector2(x, y), t)
			atual.append(a.lerp(b, t))
		return self

	func bezier_to(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> Caminho:
		var p0 := atual[atual.size() - 1] if atual.size() > 0 else Vector2(c1x, c1y)
		var c1 := Vector2(c1x, c1y)
		var c2 := Vector2(c2x, c2y)
		var p3 := Vector2(x, y)
		var n := clampi(int((p0.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(p3)) * esc / 4.0) + 2, 4, 60)
		for i in range(1, n + 1):
			var t := float(i) / n
			var u := 1.0 - t
			atual.append(p0 * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + p3 * t * t * t)
		return self

	func fecha() -> Caminho:
		if atual.size() > 0:
			subs.append(atual)
			fechados.append(true)
		atual = PackedVector2Array()
		return self

	func rect(x: float, y: float, w: float, h: float) -> Caminho:
		_novo()
		atual = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
		fecha()
		return self

	func rr(x: float, y: float, w: float, h: float, r: float) -> Caminho:
		_novo()
		r = minf(r, minf(absf(w), absf(h)) / 2.0)
		if r <= 0.01:
			return rect(x, y, w, h)
		arc(x + w - r, y + r, r, -PI / 2.0, 0.0)
		arc(x + w - r, y + h - r, r, 0.0, PI / 2.0)
		arc(x + r, y + h - r, r, PI / 2.0, PI)
		arc(x + r, y + r, r, PI, PI * 1.5)
		fecha()
		return self

	func pontos(pts: PackedVector2Array, fechado := true) -> Caminho:
		_novo()
		atual = pts.duplicate()
		if fechado:
			fecha()
		return self

	func todos() -> Array:
		var s: Array = []
		for i in range(subs.size()):
			s.append([subs[i], fechados[i]])
		if atual.size() > 0:
			s.append([atual, false])
		return s


func caminho() -> Caminho:
	return Caminho.new(escala_atual())


# ---------- preencher ----------
static func _limpa(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.size() == 0 or out[out.size() - 1].distance_squared_to(p) > 1e-6:
			out.append(p)
	if out.size() > 2 and out[0].distance_squared_to(out[out.size() - 1]) < 1e-6:
		out.remove_at(out.size() - 1)
	return out


func fill_pts(pts: PackedVector2Array, cor: Color) -> void:
	var p := _limpa(pts)
	if p.size() < 3:
		return
	if Geometry2D.triangulate_polygon(p).is_empty():
		# polígono que se cruza (raro): preenche em leque a partir do meio
		var meio := Vector2.ZERO
		for v in p:
			meio += v
		meio /= p.size()
		var cc := _c(cor)
		for i in range(p.size()):
			ci.draw_polygon(PackedVector2Array([meio, p[i], p[(i + 1) % p.size()]]), PackedColorArray([cc, cc, cc]))
		return
	ci.draw_colored_polygon(p, _c(cor))


func fill(c: Caminho, cor: Color) -> void:
	for s in c.todos():
		fill_pts(s[0], cor)


func fill_rect(x: float, y: float, w: float, h: float, cor: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), _c(cor))


func circle(x: float, y: float, r: float, cor: Color) -> void:
	fill(caminho().circulo(x, y, r), cor)


# ---------- traçar ----------
func stroke_pts(pts: PackedVector2Array, cor: Color, w: float, fechado := false) -> void:
	var p := pts
	if p.size() < 2:
		return
	if fechado:
		p = p.duplicate()
		p.append(p[0])
	var c := _c(cor)
	ci.draw_polyline(p, c, w, true)
	# juntas e pontas arredondadas (o lineJoin round do canvas) nos traços grossos
	if w * escala_atual() >= 2.5:
		var r := w / 2.0
		var ini := 0 if (fechado or cap_redondo) else 1
		var fim := p.size() if (fechado or cap_redondo) else p.size() - 1
		for i in range(ini, fim):
			if i > 0 and i < p.size() - 1:
				var d1 := (p[i] - p[i - 1]).normalized()
				var d2 := (p[i + 1] - p[i]).normalized()
				if d1.dot(d2) > 0.995:
					continue
			ci.draw_circle(p[i], r * 0.98, c, true, -1.0, true)


func stroke(c: Caminho, cor: Color, w: float) -> void:
	for s in c.todos():
		stroke_pts(s[0], cor, w, s[1])


func line(x0: float, y0: float, x1: float, y1: float, cor: Color, w: float) -> void:
	stroke_pts(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1)]), cor, w)


func dashed(c: Caminho, cor: Color, w: float, tam: float, vao: float) -> void:
	for s in c.todos():
		var pts: PackedVector2Array = s[0]
		if s[1]:
			pts = pts.duplicate()
			pts.append(pts[0])
		var ligado := true
		var resta := tam
		var seg := PackedVector2Array()
		seg.append(pts[0])
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var d := a.distance_to(b)
			var pos := 0.0
			while d - pos > resta:
				pos += resta
				var q := a.lerp(b, pos / d)
				if ligado:
					seg.append(q)
					ci.draw_polyline(seg, _c(cor), w, true)
				seg = PackedVector2Array([q])
				ligado = not ligado
				resta = tam if ligado else vao
			resta -= d - pos
			if ligado:
				seg.append(b)
			else:
				seg = PackedVector2Array([b])
		if ligado and seg.size() > 1:
			ci.draw_polyline(seg, _c(cor), w, true)


# ---------- degradê ----------
# paradas: [[0.0, Color], [0.5, Color], ...]
func fill_linear(c: Caminho, x0: float, y0: float, x1: float, y1: float, paradas: Array) -> void:
	var dir := Vector2(x1 - x0, y1 - y0)
	var L := dir.length()
	if L < 0.001:
		fill(c, paradas[0][1])
		return
	var u := dir / L
	var nrm := Vector2(-u.y, u.x)
	var o := Vector2(x0, y0)
	for s in c.todos():
		var pts := _limpa(s[0])
		if pts.size() < 3:
			continue
		# as faixas entre uma parada e outra (e antes da primeira, depois da última)
		var ts: Array[float] = [-1000.0]
		for pd in paradas:
			ts.append(float(pd[0]))
		ts.append(1000.0)
		for k in range(ts.size() - 1):
			var ta := ts[k]
			var tb := ts[k + 1]
			if tb - ta < 1e-5:
				continue
			var big := 5000.0
			var banda := PackedVector2Array([o + u * (ta * L) - nrm * big, o + u * (tb * L) - nrm * big, o + u * (tb * L) + nrm * big, o + u * (ta * L) + nrm * big])
			for pedaco in Geometry2D.intersect_polygons(pts, banda):
				if pedaco.size() < 3:
					continue
				var cores := PackedColorArray()
				for v in pedaco:
					var t := (v - o).dot(u) / L
					cores.append(_c(_cor_em(paradas, t)))
				if not Geometry2D.triangulate_polygon(pedaco).is_empty():
					ci.draw_polygon(pedaco, cores)


static func _cor_em(paradas: Array, t: float) -> Color:
	if t <= float(paradas[0][0]):
		return paradas[0][1]
	for i in range(1, paradas.size()):
		var a: float = paradas[i - 1][0]
		var b: float = paradas[i][0]
		if t <= b:
			var k := 0.0 if b - a < 1e-6 else (t - a) / (b - a)
			return (paradas[i - 1][1] as Color).lerp(paradas[i][1], k)
	return paradas[paradas.size() - 1][1]


func radial(x0: float, y0: float, r0: float, x1: float, y1: float, r1: float, paradas: Array, ate := 1.0, aneis := 20) -> void:
	# o degradê radial do canvas (dois círculos), em anéis; "ate" corta antes do círculo de fora.
	# tudo num pacote só de triângulos (uma chamada de desenho)
	var seg := clampi(int(r1 * escala_atual() / 2.0) + 16, 16, 72)
	var c0 := Vector2(x0, y0)
	var c1 := Vector2(x1, y1)
	var pts := PackedVector2Array()
	var cores := PackedColorArray()
	var idx := PackedInt32Array()
	var dirs: Array[Vector2] = []
	for j2 in range(seg):
		var a := TAU * j2 / seg
		dirs.append(Vector2(cos(a), sin(a)))
	# o miolo, com a primeira cor
	var meio := 0
	pts.append(c0)
	cores.append(_c(paradas[0][1]))
	for j2 in range(seg):
		pts.append(c0 + dirs[j2] * r0)
		cores.append(_c(paradas[0][1]))
	for j2 in range(seg):
		idx.append_array([meio, 1 + j2, 1 + (j2 + 1) % seg])
	var anel_ant := 1
	for k in range(1, aneis + 1):
		var t := ate * float(k) / aneis
		var cb := c0.lerp(c1, t)
		var rb := lerpf(r0, r1, t)
		var cor := _c(_cor_em(paradas, t))
		var base := pts.size()
		for j2 in range(seg):
			pts.append(cb + dirs[j2] * rb)
			cores.append(cor)
		for j2 in range(seg):
			var a1 := anel_ant + j2
			var a2 := anel_ant + (j2 + 1) % seg
			var b1 := base + j2
			var b2 := base + (j2 + 1) % seg
			idx.append_array([a1, b1, b2, a1, b2, a2])
		anel_ant = base
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cores)


# ---------- texto ----------
func text(txt: String, x: float, y: float, fonte: Font, tam: float, cor: Color, alinha := "left", base := "alphabetic") -> void:
	var w := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam)).x
	var px0 := x
	if alinha == "center":
		px0 = x - w / 2.0
	elif alinha == "right":
		px0 = x - w
	var py := y
	if base == "middle":
		py = y + (fonte.get_ascent(int(tam)) - fonte.get_descent(int(tam))) / 2.0
	elif base == "top":
		py = y + fonte.get_ascent(int(tam))
	ci.draw_string(fonte, Vector2(px0, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), _c(cor))


func text_contorno(txt: String, x: float, y: float, fonte: Font, tam: float, cor: Color, borda: float, cor_borda: Color, alinha := "left", base := "alphabetic") -> void:
	var w := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam)).x
	var px0 := x
	if alinha == "center":
		px0 = x - w / 2.0
	var py := y
	if base == "middle":
		py = y + (fonte.get_ascent(int(tam)) - fonte.get_descent(int(tam))) / 2.0
	ci.draw_string_outline(fonte, Vector2(px0, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), int(borda), _c(cor_borda))
	ci.draw_string(fonte, Vector2(px0, py), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), _c(cor))


static func largura(txt: String, fonte: Font, tam: float) -> float:
	return fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam)).x
