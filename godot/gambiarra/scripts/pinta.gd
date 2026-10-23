class_name Pinta
## O desenho da tralha, da laranja e dos alvos (rádio, caixa de som, amplificador), igual à versão web.

const LINHA := Color("#2A1F1A")


static func rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


static func hx(s: String) -> Color:
	return Color(s)


# o mesmo sorteio da versão web (mulberry32), pra os detalhes caírem nos mesmos lugares
class Rng:
	var s := 0

	func _init(semente: int) -> void:
		s = semente & 0xFFFFFFFF

	static func _imul(a: int, b: int) -> int:
		return ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF

	func f() -> float:
		s = (s + 0x6D2B79F5) & 0xFFFFFFFF
		var t := _imul(s ^ (s >> 15), 1 | s)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


# ---------- ajudantes ----------
static func rr(c: Ctx, x: float, y: float, w: float, h: float, r: float) -> Ctx.Caminho:
	return c.caminho().rr(x, y, w, h, r)


static func fill_stroke(c: Ctx, cam: Ctx.Caminho, cor: Color, lw := 2.0, linha := LINHA) -> void:
	c.fill(cam, cor)
	c.stroke(cam, linha, lw)


static func fill_recortado(c: Ctx, pts: PackedVector2Array, recorte: PackedVector2Array, cor: Color) -> void:
	for q in Geometry2D.intersect_polygons(pts, recorte):
		c.fill_pts(q, cor)


static func ret_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func stroke_degrade_x(c: Ctx, pts: PackedVector2Array, paradas: Array, x0: float, x1: float, lw: float) -> void:
	# traço com degradê na horizontal: o caminho em pedacinhos, cada um com a cor do lugar dele
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var n := 10
		for k in range(n):
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var t := ((p0.x + p1.x) / 2.0 - x0) / (x1 - x0)
			var cor := Ctx._cor_em(paradas, t)
			c.ci.draw_line(p0, p1, c._c(cor), lw, true)
		var tj := (b.x - x0) / (x1 - x0)
		c.ci.draw_circle(b, lw / 2.0, c._c(Ctx._cor_em(paradas, tj)), true, -1.0, true)
	var t0 := (pts[0].x - x0) / (x1 - x0)
	c.ci.draw_circle(pts[0], lw / 2.0, c._c(Ctx._cor_em(paradas, t0)), true, -1.0, true)


# ---------- as peças ----------
static func tabua(c: Ctx, w: float, h: float, cor := Color("#C98B4F")) -> void:
	var cam := rr(c, -w / 2, -h / 2, w, h, 3)
	c.fill(cam, cor)
	var veio := rgba(90, 50, 20, 0.33)
	for i in range(3):
		var y := -h / 2 + 3 + i * (h - 4) / 3.0
		var pts := PackedVector2Array()
		var x := -w / 2
		while x <= w / 2:
			pts.append(Vector2(x, y + sin(x * 0.09 + i * 2) * 1.1))
			x += 12
		c.stroke_pts(pts, veio, 1.1)
	c.stroke(c.caminho().elipse(w * 0.18, 0, 5, minf(2.6, h / 4.0)), veio, 1.1)
	fill_recortado(c, ret_pts(-w / 2, h / 2 - 3, w, 3), cam.subs[0], rgba(0, 0, 0, 0.12))
	c.stroke(cam, LINHA, 2.2)
	for x in [-w / 2 + 7, w / 2 - 7]:
		c.circle(x, 0, 1.8, Color("#55504B"))


static func colchao(c: Ctx, sq: float) -> void:
	var w := 124.0
	var h := 26.0
	c.save()
	c.translate(0, h / 2)
	c.scale(1 + sq * 0.07, 1 - sq * 0.32)
	c.translate(0, -h / 2)
	for mx in [-30.0, 14.0]:
		var pts := PackedVector2Array([Vector2(mx, -h / 2 + 2)])
		for i in range(1, 6):
			pts.append(Vector2(mx + (4 if i % 2 == 1 else -4), -h / 2 - i * 2.6))
		c.stroke_pts(pts, Color("#8D939B"), 1.7)
	var cam := rr(c, -w / 2, -h / 2, w, h, 9)
	var forma: PackedVector2Array = cam.subs[0]
	c.fill(cam, Color("#F2EEE4"))
	var x := -w / 2 + 2
	while x < w / 2:
		fill_recortado(c, ret_pts(x, -h / 2, 3, h), forma, Color("#3E6DB5"))
		x += 8
	var fita := Transform2D(-0.2, Vector2(30, 1)) * ret_pts(-12, -5, 24, 10)
	fill_recortado(c, fita, forma, rgba(230, 210, 155, 0.97))
	fill_recortado(c, ret_pts(-w / 2, h / 2 - 6, w, 6), forma, rgba(0, 0, 0, 0.14))
	c.stroke(cam, LINHA, 2.2)
	for bx in [-40.0, -2.0, 36.0]:
		c.circle(bx, 0, 2, Color("#23365E"))
	c.restore()


static func bacia(c: Ctx) -> void:
	c.fill(c.caminho().pontos(PackedVector2Array([Vector2(-54, -23), Vector2(-40, 19), Vector2(40, 19), Vector2(54, -23)])), Color("#5E6670"))
	var borda := PackedVector2Array([Vector2(-54, -23), Vector2(-40, 17), Vector2(40, 17), Vector2(54, -23)])
	c.cap_redondo = true
	c.stroke_pts(borda, LINHA, 11)
	c.cap_redondo = false
	stroke_degrade_x(c, borda, [[0.0, Color("#8C949E")], [0.35, Color("#E8ECF0")], [0.6, Color("#B7BEC7")], [1.0, Color("#7E8690")]], -56, 56, 6.5)
	for x in [-55.0, 55.0]:
		fill_stroke(c, c.caminho().circulo(x, -23, 4.5), Color("#D9DEE4"), 1.6)
	c.stroke(c.caminho().arc(-14, 12, 7, 3.6, 5.3), rgba(255, 255, 255, 0.55), 1.4)


static func lata(c: Ctx) -> void:
	var r := 16.0
	fill_stroke(c, c.caminho().circulo(0, 0, r), Color("#A9B0B8"), 2.2)
	fill_stroke(c, c.caminho().circulo(0, 0, r - 3.5), Color("#CDD2D8"), 1.2, Color("#7D848C"))
	c.stroke(c.caminho().circulo(0, 0, r - 7.5), rgba(125, 132, 140, 0.7), 1.2)
	var rosa := Color("#E0457B")
	var cam := c.caminho()
	cam.move_to(cos(-0.9) * (r - 1.2), sin(-0.9) * (r - 1.2))
	cam.arc(0, 0, r - 1.2, -0.9, 0.5)
	cam.arc(0, 0, r - 4.6, 0.5, -0.9, true)
	cam.fecha()
	c.fill(cam, rosa)
	c.fill(c.caminho().elipse(r - 6.5, 3, 2.2, 4.5, 0.3), rosa)
	c.fill(c.caminho().elipse(-5, -6, 4, 2, -0.6), rgba(255, 255, 255, 0.6))


static func pet_caminho(c: Ctx) -> Ctx.Caminho:
	var p := c.caminho()
	p.move_to(-4, -30).line_to(4, -30).line_to(4, -24).quad_to(11, -17, 11, -8).line_to(11, 25)
	p.quad_to(11, 31, 6, 31).line_to(-6, 31).quad_to(-11, 31, -11, 25).line_to(-11, -8).quad_to(-11, -17, -4, -24).fecha()
	return p


static func garrafa(c: Ctx) -> void:
	var pet := pet_caminho(c)
	c.fill(pet, rgba(146, 198, 236, 0.62))
	c.fill_rect(-11, 0, 22, 12, Color("#F4C430"))
	c.fill_rect(-11, 4, 22, 3, Color("#D7342B"))
	for y in [-6.0, 18.0, 23.0]:
		c.line(-11, y, 11, y, rgba(60, 110, 150, 0.45), 1)
	c.fill_rect(-7, -14, 2.5, 40, rgba(255, 255, 255, 0.55))
	c.stroke(pet, LINHA, 2)
	fill_stroke(c, rr(c, -5, -35, 10, 6, 1.5), Color("#D7342B"), 2)


static func tijolos(c: Ctx) -> void:
	for y in [-11.0, 11.0]:
		fill_stroke(c, rr(c, -22, y - 11, 44, 22, 2), Color("#B5532F"), 2)
		for x in [-12.0, 0.0, 12.0]:
			c.fill(rr(c, x - 4, y - 6, 8, 12, 2), Color("#5A2414"))


static func ventilador(c: Ctx, a: float, giro: float) -> void:
	var creme := Color("#ECE6D9")
	fill_stroke(c, rr(c, -25, 56, 50, 10, 4), creme, 2)
	fill_stroke(c, rr(c, -5, 27, 10, 30, 3), creme, 2)
	for x in [-15.0, -7.0]:
		c.fill(rr(c, x, 59, 6, 4, 1), Color("#2D5DA6"))
	c.save()
	c.rotate(a)
	fill_stroke(c, rr(c, -26, -11, 14, 22, 6), creme, 2)
	c.save()
	c.scale(0.55, 1)
	c.circle(0, 0, 28, rgba(40, 40, 40, 0.12))
	for k in range(3):
		c.save()
		c.rotate(giro + k * 2.094)
		fill_stroke(c, c.caminho().elipse(0, -13, 7, 12), rgba(241, 233, 216, 0.96), 1.4)
		c.restore()
	for r in [28.0, 19.0, 10.0]:
		c.stroke(c.caminho().circulo(0, 0, r), Color("#2B2B2B"), 1.7)
	for k in range(12):
		var t := k * PI / 6
		c.line(cos(t) * 10, sin(t) * 10, cos(t) * 28, sin(t) * 28, Color("#2B2B2B"), 1)
	c.restore()
	fill_stroke(c, c.caminho().circulo(0, 0, 4), Color("#D7342B"), 1.4)
	c.restore()


static func gato(c: Ctx, f: int, susto: bool, t: float) -> void:
	c.save()
	c.scale(f, 1)
	var preto := Color("#1E1B1A")
	var branco := Color("#F4EFE6")
	if not susto:
		var rabo := c.caminho().move_to(-12, 16).quad_to(-30, 16, -26, 0 + sin(t / 400.0) * 3)
		c.cap_redondo = true
		c.stroke(rabo, preto, 6)
		c.cap_redondo = false
		c.fill(c.caminho().elipse(-2, 7, 17, 13), preto)
		c.fill(c.caminho().elipse(8, 10, 7, 10), branco)
		c.fill(c.caminho().elipse(4, 19, 4.5, 2.6), branco)
		c.fill(c.caminho().elipse(13, 19, 4.5, 2.6), branco)
		c.circle(8, -8, 11, preto)
		c.fill(c.caminho().pontos(PackedVector2Array([Vector2(-1, -13), Vector2(2, -23), Vector2(8, -17)])), preto)
		c.fill(c.caminho().pontos(PackedVector2Array([Vector2(9, -17), Vector2(15, -23), Vector2(18, -12)])), preto)
		c.fill(c.caminho().elipse(11, -3, 6.5, 4.5), branco)
		c.fill(c.caminho().elipse(4, -10, 2.6, 3.1), Color("#F2C230"))
		c.fill(c.caminho().elipse(13, -10, 2.6, 3.1), Color("#F2C230"))
		c.fill_rect(3.4, -12.6, 1.2, 5.2, preto)
		c.fill_rect(12.4, -12.6, 1.2, 5.2, preto)
		c.fill(c.caminho().pontos(PackedVector2Array([Vector2(11, -6), Vector2(15, -6), Vector2(13, -3.5)])), Color("#E58BA0"))
		c.line(16, -3, 25, -5, rgba(244, 239, 230, 0.85), 0.9)
		c.line(16, -1.5, 25, 0, rgba(244, 239, 230, 0.85), 0.9)
	else:
		# assustado: costas arqueadas, pelo em pé, rabo de escova
		var pts := PackedVector2Array()
		for i in range(15):
			var a := PI + i / 14.0 * PI
			var r := 19.0 + (5.0 if i % 2 == 1 else 0.0)
			pts.append(Vector2(cos(a) * r * 1.05, 6 + sin(a) * r * 0.9))
		pts.append(Vector2(18, 14))
		pts.append(Vector2(-18, 14))
		c.fill_pts(pts, preto)
		for x in [-14.0, -6.0, 8.0, 15.0]:
			c.line(x, 12, x + (-2 if x < 0 else 2), 21, preto, 3)
		c.stroke_pts(PackedVector2Array([Vector2(-18, 2), Vector2(-26, -12), Vector2(-22, -26)]), preto, 8)
		c.circle(16, -6, 10, preto)
		c.fill(c.caminho().pontos(PackedVector2Array([Vector2(9, -12), Vector2(10, -22), Vector2(15, -15)])), preto)
		c.fill(c.caminho().pontos(PackedVector2Array([Vector2(17, -15), Vector2(23, -21), Vector2(24, -10)])), preto)
		c.circle(13, -7, 3.6, Color("#F2C230"))
		c.circle(21, -7, 3.6, Color("#F2C230"))
		c.circle(13, -7, 1.4, preto)
		c.circle(21, -7, 1.4, preto)
		c.fill(c.caminho().elipse(18, 0, 3, 2.4), Color("#E58BA0"))
	c.restore()


static func telha(c: Ctx) -> void:
	var R := 66.0
	var a0 := deg_to_rad(25.0)
	var a1 := deg_to_rad(155.0)
	c.cap_redondo = true
	c.stroke(c.caminho().arc(0, -50, R, a0, a1), LINHA, 11)
	c.stroke(c.caminho().arc(0, -50, R, a0, a1), Color("#B9552F"), 7.5)
	c.cap_redondo = false
	c.stroke(c.caminho().arc(0, -50, R - 2, a0 + 0.05, a1 - 0.05), rgba(255, 190, 140, 0.55), 1.6)
	for i in range(1, 6):
		var th := a0 + (a1 - a0) * i / 6.0
		c.line(cos(th) * (R - 3), sin(th) * (R - 3) - 50, cos(th) * (R + 3), sin(th) * (R + 3) - 50, rgba(90, 35, 15, 0.5), 1.2)


static func pneu(c: Ctx) -> void:
	fill_stroke(c, c.caminho().circulo(0, 0, 24), Color("#26221F"), 2)
	for i in range(16):
		var a := i * PI / 8
		c.line(cos(a) * 20, sin(a) * 20, cos(a) * 24, sin(a) * 24, Color("#4A443F"), 2)
	# pintado de amarelo e azul, que nem os de canteiro
	c.stroke(c.caminho().arc(0, 0, 16.5, 0, PI), Color("#FFC531"), 6)
	c.stroke(c.caminho().arc(0, 0, 16.5, PI, TAU), Color("#3E6DB5"), 6)
	fill_stroke(c, c.caminho().circulo(0, 0, 12), Color("#5E5852"), 1.6)


static func caramelo(c: Ctx, f: int, acordado: bool, correndo: bool, t: float, reduz := false) -> void:
	c.save()
	c.scale(f, 1)
	var pelo := Color("#D08A3E")
	var claro := Color("#F2CC8F")
	var escuro := Color("#9C5F25")
	if not acordado:
		# dormindo enroladinho
		c.cap_redondo = true
		c.stroke(c.caminho().move_to(-24, 6).quad_to(-34, 0, -28, -8), pelo, 6)
		c.cap_redondo = false
		c.fill(c.caminho().elipse(-3, 3, 25, 12), pelo)
		c.fill(c.caminho().elipse(2, 9, 16, 5), claro)
		c.fill(c.caminho().elipse(19, 2, 11, 9), pelo)
		c.fill(c.caminho().elipse(27, 6, 6, 4.5), claro)
		c.circle(32, 4, 2.2, Color("#1E1B1A"))
		c.fill(c.caminho().elipse(13, -3, 5, 8, 0.5), escuro)
		c.stroke(c.caminho().arc(20, 0, 2.6, 0.2, 2.8), Color("#3A2414"), 1.2)
		c.restore()
		if not reduz and t > 0:
			for i in range(2):
				var k := fmod(t / 1400.0 + i * 0.5, 1.0)
				c.save()
				c.alfa = 1.0 - k
				c.text("z", f * (18 + k * 10), -14 - k * 22, Fontes.txt(700), 11, rgba(42, 31, 26, 0.7), "center")
				c.restore()
		return
	var passo := sin(t / 45.0) if correndo else 0.0
	for pr in [[-16.0, 0.0], [-8.0, PI], [10.0, PI], [18.0, 0.0]]:
		var sw := sin(t / 45.0 + pr[1]) * (6.0 if correndo else 0.0)
		c.cap_redondo = true
		c.line(pr[0], 4, pr[0] + sw, 15, escuro, 4)
	c.stroke(c.caminho().move_to(-22, -2).quad_to(-32, -10 + passo * 4, -30, -18), pelo, 5)
	c.cap_redondo = false
	c.fill(c.caminho().elipse(0, -1, 23, 10), pelo)
	c.fill(c.caminho().elipse(4, 5, 14, 4), claro)
	c.fill(c.caminho().elipse(22, -10, 10, 9), pelo)
	c.fill(c.caminho().elipse(30, -7, 7, 5), claro)
	c.circle(36, -9, 2.4, Color("#1E1B1A"))
	c.circle(23, -13, 1.8, Color("#1E1B1A"))
	c.fill(c.caminho().elipse(31, -1, 3, 4.5, 0.2), Color("#E58BA0"))
	c.save()
	c.translate(16, -16)
	c.rotate(-0.6 + passo * 0.4)
	c.fill(c.caminho().elipse(0, 0, 4.5, 8), escuro)
	c.restore()
	c.restore()


static func limpador(c: Ctx, pv: Vector2, ang: float, ligado: bool) -> void:
	# o braço com a palheta de borracha e o motorzinho com a luz que acende quando liga
	c.save()
	c.translate(pv.x, pv.y)
	c.save()
	c.rotate(ang)
	c.cap_redondo = true
	c.line(0, 0, 110, 0, Color("#2B2B2E"), 5)
	c.line(36, 0, 110, 0, Color("#111013"), 8)
	c.cap_redondo = false
	c.line(38, -2.5, 108, -2.5, Color("#4A4A50"), 1.4)
	c.restore()
	fill_stroke(c, c.caminho().circulo(0, 0, 13), Color("#3A3A40"), 2)
	c.circle(0, 0, 5, Color("#9AA0A8"))
	c.circle(-7, -8, 2.6, Color("#FF5A3D") if ligado else Color("#6B2A22"))
	c.restore()


static func balde(c: Ctx) -> void:
	# balde de tinta de 18 litros, de boca pra baixo: virou bateria
	var corpo := c.caminho().pontos(PackedVector2Array([Vector2(-20, -27), Vector2(20, -27), Vector2(25, 27), Vector2(-25, 27)]))
	c.fill_linear(corpo, -25, 0, 25, 0, [[0.0, Color("#D9D4C8")], [0.4, Color("#FBF8F1")], [1.0, Color("#C9C3B6")]])
	c.stroke(corpo, LINHA, 2.2)
	c.fill(c.caminho().pontos(PackedVector2Array([Vector2(-21.6, -2), Vector2(21.6, -2), Vector2(22.7, 10), Vector2(-22.7, 10)])), Color("#E0457B"))
	c.fill(c.caminho().move_to(-14, -27).quad_to(-13, -14, -10, -16).quad_to(-8, -22, -6, -27).fecha(), Color("#3E6DB5"))
	c.fill(c.caminho().move_to(8, -27).quad_to(10, -10, 13, -13).quad_to(14, -22, 15, -27).fecha(), Color("#FFC531"))
	fill_stroke(c, rr(c, -26, 23, 52, 6, 2), Color("#C9C3B6"), 1.6)
	c.stroke(c.caminho().arc(0, 22, 21, PI * 0.1, PI * 0.9), Color("#8A8F96"), 1.6)


static var _poros: PackedVector2Array = PackedVector2Array()


static func laranja(c: Ctx) -> void:
	if _poros.is_empty():
		var r := Rng.new(3)
		for i in range(16):
			var t := r.f() * 7
			var d := r.f() * 11
			_poros.append(Vector2(cos(t) * d, sin(t) * d))
	c.radial(-5, -6, 2, 0, 0, 15, [[0.0, Color("#FFC069")], [0.6, Color("#F28C28")], [1.0, Color("#D9650E")]], 12.0 / 13.0, 10)
	c.stroke(c.caminho().circulo(0, 0, 14), LINHA, 2)
	for p in _poros:
		c.fill_rect(p.x, p.y, 1.3, 1.3, rgba(170, 70, 0, 0.4))
	c.circle(0, -11, 2, Color("#8A4A12"))
	c.line(0, -12, 2.5, -16.5, Color("#6B4423"), 2)


# ---------- a peça inteira, no lugar dela ----------
# o desenho de cada peça mora num nó próprio (PecaNo): a pose vira a transformação do nó e o desenho
# só é refeito quando a cara da peça muda (assim a CPU do celular não redesenha tudo a cada quadro)
static func pose_no(p: Peca) -> Transform2D:
	match p.tipo:
		"gangorra", "ventilador":
			var o := p.origem()
			return Transform2D(0.0, o.origin)
		"limpador":
			return Transform2D(0.0, p.pose_parte(p.partes[0]).origin)
		"gato", "caramelo":
			return p.pose_parte(p.partes[0])
	return p.origem()


static func chave(p: Peca, t: float, rodando: bool, passos: int, reduz: bool) -> String:
	# muda quando o desenho precisa ser refeito
	match p.tipo:
		"colchao":
			return "%.2f" % p.squash
		"ventilador":
			return str(int(t / 28.0 * 8.0)) if rodando and not reduz else "parado"
		"gangorra":
			return "%.3f" % p.pose_parte(p.partes[1]).get_rotation()
		"limpador":
			return "%.3f|%s" % [p.pose_parte(p.partes[1]).get_rotation(), str(p.liga >= 0 and rodando)]
		"gato":
			return "susto" if p.assustado else str(int(t / 40.0))
		"caramelo":
			if not p.acordado:
				return str(int(t / 40.0)) if not reduz else "dorme"
			var correndo := rodando and passos < p.corre
			return str(int(t / 30.0)) if correndo else "acordado"
	return ""


static func peca_local(c: Ctx, p: Peca, t: float, rodando: bool, passos: int, reduz := false) -> void:
	match p.tipo:
		"tabua":
			tabua(c, 150, 14)
		"colchao":
			colchao(c, p.squash)
		"bacia":
			bacia(c)
		"lata":
			lata(c)
		"garrafa":
			garrafa(c)
		"gangorra":
			var ref := pose_no(p).origin
			var bx := p.pose_parte(p.partes[0])
			var tx := p.pose_parte(p.partes[1])
			c.save()
			c.translate(bx.origin.x - ref.x, bx.origin.y - ref.y)
			tijolos(c)
			c.restore()
			c.save()
			c.translate(tx.origin.x - ref.x, tx.origin.y - ref.y)
			c.rotate(tx.get_rotation())
			tabua(c, 172, 12, Color("#9C6B3E"))
			fill_stroke(c, c.caminho().circulo(0, 0, 4), Color("#55504B"), 1.4)
			c.restore()
		"ventilador":
			ventilador(c, p.a, t / 28.0 if rodando and not reduz else 0.4)
		"gato":
			gato(c, p.flip, p.assustado, t)
		"telha":
			telha(c)
		"pneu":
			pneu(c)
		"limpador":
			var br := p.pose_parte(p.partes[1])
			limpador(c, Vector2.ZERO, br.get_rotation(), p.liga >= 0 and rodando)
		"balde":
			balde(c)
		"caramelo":
			caramelo(c, p.flip, p.acordado, rodando and p.acordado and passos < p.corre, t, reduz)


static func peca(c: Ctx, p: Peca, t: float, rodando: bool, passos: int, reduz := false) -> void:
	var xf := pose_no(p)
	c.save()
	c.translate(xf.origin.x, xf.origin.y)
	c.rotate(xf.get_rotation())
	peca_local(c, p, t, rodando, passos, reduz)
	c.restore()


# ---------- os alvos ----------
static func notas(c: Ctx, lista: Array, x: float, y: float, t: float) -> void:
	# as notinhas subindo do alvo ligado (a lista guarda o estado entre quadros)
	if lista.is_empty() or t - float(lista[lista.size() - 1].t) > 260:
		var cores := [Color("#F07A1C"), Color("#E0457B"), Color("#FFC531"), Color("#5B8FE0")]
		lista.append({ "x": x, "y": y, "t": t, "cor": cores[lista.size() % 4], "dx": (randf() - 0.5) * 30 })
	while not lista.is_empty() and t - float(lista[0].t) >= 1800:
		lista.pop_front()
	for n in lista:
		var k: float = (t - float(n.t)) / 1800.0
		var nx: float = n.x + n.dx * k + sin(k * 9) * 6
		var ny: float = n.y - k * 120
		c.save()
		c.alfa = 1.0 - k
		var cab := c.caminho().elipse(nx, ny, 5, 3.6, -0.4)
		fill_stroke(c, cab, n.cor, 1.2)
		c.stroke_pts(PackedVector2Array([Vector2(nx + 4.5, ny - 1), Vector2(nx + 4.5, ny - 17), Vector2(nx + 10, ny - 13)]), LINHA, 2)
		c.restore()


static func brilho(c: Ctx, x: float, y: float, r: float, cor: Color, forca := 0.5) -> void:
	# o shadowBlur do canvas, de leve: umas manchas da mesma cor em volta
	for i in range(4):
		var k := float(i + 1) / 4.0
		c.circle(x, y, r + 10 * k, Color(cor.r, cor.g, cor.b, forca * 0.18 * (1.0 - k * 0.7)))


static func radio(c: Ctx, x: float, y: float, on: bool, t: float, lista: Array, reduz := false) -> void:
	c.save()
	c.translate(x, y)
	# a antena com palha de aço na ponta e fita isolante no meio
	c.cap_redondo = true
	c.line(44, -26, 70, -106, Color("#A9B0B8"), 3)
	c.cap_redondo = false
	c.line(52, -50, 56, -49, LINHA, 1)
	c.line(60, -75, 64, -74, LINHA, 1)
	c.save()
	c.translate(58, -64)
	c.rotate(-1.26)
	c.fill_rect(-6, -3, 12, 6, Color("#1B1B1B"))
	c.restore()
	var ra := Rng.new(11)
	for i in range(9):
		var cx := 70 + (ra.f() - 0.5) * 9
		var cy := -108 + (ra.f() - 0.5) * 8
		c.stroke(c.caminho().circulo(cx, cy, 3 + ra.f() * 3), Color("#9AA0A8"), 1.2)
	# a tecla
	var desce := 3.0 if on else 0.0
	fill_stroke(c, rr(c, -42, -36 + desce, 84, 10, 3), Color("#F4D35E"), 2)
	# a caixa
	fill_stroke(c, rr(c, -59, -28, 118, 56, 9), Color("#C8352E"), 2)
	fill_stroke(c, rr(c, -53, -22, 106, 44, 6), Color("#F1E4C8"), 1.5)
	var pulso := 1.0 + 0.06 * maxf(0.0, sin(t / 60.0)) if on and not reduz else 1.0
	c.save()
	c.translate(-26, 0)
	c.scale(pulso, pulso)
	for i in range(-3, 4):
		for j in range(-3, 4):
			if i * i + j * j <= 10:
				c.circle(i * 4.6, j * 4.6, 1.5, Color("#3A2A22"))
	c.restore()
	if on:
		brilho(c, 24, -6, 14, Color("#FFB347"), 0.8)
	fill_stroke(c, rr(c, 2, -15, 44, 18, 3), Color("#FFB347") if on else Color("#2B1F1A"), 1.5)
	var cor_tr := rgba(60, 30, 10, 0.7) if on else rgba(241, 228, 200, 0.5)
	for i in range(9):
		c.line(6 + i * 4.5, -13, 6 + i * 4.5, -9, cor_tr, 1)
	var ag := 18 + sin(t / 500.0) * 4 if on else 12.0
	c.line(6 + ag, -14, 6 + ag, 1, Color("#D7342B"), 1.6)
	for kx in [14.0, 36.0]:
		c.circle(kx, 12, 5, Color("#3A2A22"))
	c.restore()
	if on:
		notas(c, lista, x - 26, y - 10, t)


static func caixa_som(c: Ctx, x: float, y: float, on: bool, t: float, lista: Array, reduz := false) -> void:
	var bum := maxf(0.0, sin(t / 60.0)) if on and not reduz else 0.0
	c.save()
	c.translate(x, y)
	fill_stroke(c, rr(c, -35, -67 + (3.0 if on else 0.0), 70, 10, 3), Color("#F4D35E"), 2)
	fill_stroke(c, rr(c, -48, -58, 96, 116, 9), Color("#1E1C1F"), 2)
	c.fill(rr(c, -42, -52, 84, 104, 6), Color("#2B2930"))
	# o anel de luz (sem verde: rosa, laranja, amarelo, azul)
	if on:
		var cores := [Color("#E0457B"), Color("#F07A1C"), Color("#FFC531"), Color("#5B8FE0")]
		var cor: Color = cores[int(t / 180.0) % 4]
		for k in range(3):
			c.stroke(c.caminho().circulo(0, 14, 34), Color(cor.r, cor.g, cor.b, 0.18), 4 + 6 * (k + 1))
		c.stroke(c.caminho().circulo(0, 14, 34), cor, 4)
	c.circle(0, -34, 9, Color("#4A4650"))
	c.circle(0, -34, 4, Color("#1A181C"))
	var s := 1 + bum * 0.07
	c.save()
	c.translate(0, 14)
	c.scale(s, s)
	c.circle(0, 0, 30, Color("#3A3740"))
	c.radial(-6, -6, 2, 0, 0, 26, [[0.0, Color("#5A5662")], [1.0, Color("#141216")]], 25.0 / 26.0, 10)
	fill_stroke(c, c.caminho().circulo(0, 0, 8), Color("#2B2930"), 1.2, Color("#6A6672"))
	c.restore()
	c.circle(34, -48, 2.6, Color("#FFC531") if on else Color("#D7342B"))
	c.restore()
	if on:
		notas(c, lista, x, y - 40, t)


static func amp(c: Ctx, x: float, y: float, on: bool, t: float, lista: Array, reduz := false) -> void:
	c.save()
	c.translate(x, y)
	fill_stroke(c, rr(c, -32, -55 + (3.0 if on else 0.0), 64, 10, 3), Color("#F4D35E"), 2)
	fill_stroke(c, rr(c, -52, -45, 104, 90, 7), Color("#1E1C1F"), 2)
	# o painel creme com os botões e a luz
	c.fill(rr(c, -46, -40, 92, 20, 3), Color("#EFE3C8"))
	for i in range(5):
		c.circle(-34 + i * 14, -30, 3.6, Color("#1E1C1F"))
	if on:
		brilho(c, 36, -30, 4, Color("#FF4A3A"), 1.0)
	c.circle(36, -30, 4, Color("#FF4A3A") if on else Color("#6B2A22"))
	# a tela do alto-falante
	var bum := 1 + 0.04 * maxf(0.0, sin(t / 60.0)) if on and not reduz else 1.0
	var tela := rr(c, -46, -16, 92, 56, 3)
	c.fill(tela, Color("#5A4A3A"))
	var recorte := ret_pts(-46, -16, 92, 56)
	var i := -60
	while i < 60:
		var a := Vector2(i, -30) * bum + Vector2(0, 12)
		var b := Vector2(i + 30, 30) * bum + Vector2(0, 12)
		var seg := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), recorte)
		for sg in seg:
			c.stroke_pts(sg, rgba(30, 22, 16, 0.55), 1)
		i += 4
	c.stroke(tela, Color("#EFE3C8"), 2)
	c.restore()
	if on:
		notas(c, lista, x + 10, y - 50, t)
