class_name Cenas
## Os três cômodos desenhados (cozinha com azulejo, laje, garagem) e o que mexe neles
## (relógio, pipa e fumaça, pisca-alerta), copiados da versão web.

const W := Dados.W
const H := Dados.H
const CHAO := Dados.CHAO
const LINHA := Pinta.LINHA


static func rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


static func rr(c: Ctx, x: float, y: float, w: float, h: float, r: float) -> Ctx.Caminho:
	return c.caminho().rr(x, y, w, h, r)


static func grad_v(c: Ctx, x: float, y: float, w: float, h: float, y0: float, y1: float, paradas: Array) -> void:
	c.fill_linear(c.caminho().rect(x, y, w, h), 0, y0, 0, y1, paradas)


static func mancha(c: Ctx, x: float, y: float, r: float, cor_meio: Color, cor_fora: Color) -> void:
	c.radial(x, y, 0.0, x, y, r, [[0.0, cor_meio], [1.0, cor_fora]], 1.0, 8)


static func fita_txt(c: Ctx, x: float, y: float, txt: String, ang: float) -> void:
	var f := Fontes.caneta()
	var w := Ctx.largura(txt, f, 16) + 18
	# com a Permanent Marker de verdade a fita fica mais larga que na web: não deixa sair do cômodo
	x = clampf(x, w / 2.0 + 4.0, W - w / 2.0 - 4.0)
	c.save()
	c.translate(x, y)
	c.rotate(ang)
	var pts := PackedVector2Array()
	pts.append(Vector2(-w / 2, -12))
	for i in range(9):
		pts.append(Vector2(-w / 2 + w * i / 8.0, -12 + (2 if i % 2 == 1 else 0)))
	pts.append(Vector2(w / 2, 12))
	for i in range(8, -1, -1):
		pts.append(Vector2(-w / 2 + w * i / 8.0, 12 - (2 if i % 2 == 1 else 0)))
	c.fill_pts(pts, rgba(230, 210, 155, 0.96))
	c.text(txt, 0, 1, f, 16, Color("#1F1915"), "center", "middle")
	c.restore()


static func grao(c: Ctx, r: Pinta.Rng, et: float, eb: float, escuro := 0.035) -> void:
	for i in range(2600):
		var cor := rgba(0, 0, 0, escuro) if r.f() < 0.5 else rgba(255, 255, 255, 0.04)
		c.fill_rect(r.f() * W, r.f() * (H + et + eb) - et, 1.3, 1.3, cor)


static func prateleira(c: Ctx, fx: Dictionary) -> void:
	c.save()
	c.translate(fx.x, fx.y)
	c.rotate(fx.a)
	var L: float = fx.w
	for px in [-L / 2 + 34, L / 2 - 30]:
		c.fill_pts(PackedVector2Array([Vector2(px - 12, 7), Vector2(px + 12, 7), Vector2(px - 12, 32)]), Color("#2A2422"))
	Pinta.tabua(c, L, 14, Color("#B77B45"))
	c.restore()


# ================= a cozinha =================
static func azulejos(c: Ctx, r: Pinta.Rng) -> void:
	var T := 40.0
	var y0 := 508.0
	c.fill_rect(0, y0, W, CHAO - y0, Color("#CDBF9F"))
	var j := 0
	while y0 + j * T < CHAO:
		for i in range(int(W / T)):
			var x := i * T
			var y := y0 + j * T
			var troca := (i == 11 and j == 3) or (i == 2 and j == 6)
			c.fill_rect(x + 1, y + 1, T - 2, T - 2, Color("#F3D9DF") if troca else Color("#F5F0E4"))
			var cor := Color("#C2326A") if troca else Color("#2D5DA6")
			for q in [[x + 1, y + 1, 0.0], [x + T - 1, y + 1, PI / 2], [x + T - 1, y + T - 1, PI], [x + 1, y + T - 1, 1.5 * PI]]:
				var cam := c.caminho().move_to(q[0], q[1]).arc(q[0], q[1], 9, q[2], q[2] + PI / 2).fecha()
				c.fill(cam, cor)
			c.save()
			c.translate(x + T / 2, y + T / 2)
			for k in range(4):
				c.rotate(PI / 2)
				c.fill(c.caminho().elipse(0, -7, 3.6, 6.5), cor)
			c.circle(0, 0, 2.6, Color("#F5F0E4") if troca else Color("#E0703A"))
			c.restore()
			if r.f() < 0.07:
				c.stroke_pts(PackedVector2Array([Vector2(x + r.f() * T, y + 1), Vector2(x + r.f() * T, y + T * 0.5), Vector2(x + r.f() * T, y + T - 1)]), rgba(60, 50, 40, 0.35), 0.8)
		j += 1
	# a faixa de cima
	c.fill_rect(0, y0 - 12, W, 12, Color("#1F3F7A"))
	var xx := 8.0
	while xx < W:
		c.circle(xx, y0 - 6, 2, Color("#F5F0E4"))
		xx += 16


static func janela(c: Ctx, r: Pinta.Rng) -> void:
	var x := 438.0
	var y := 44.0
	var w := 174.0
	var h := 168.0
	c.fill(rr(c, x - 6, y - 4, w + 22, h + 24, 6), rgba(70, 45, 20, 0.16))
	Pinta.fill_stroke(c, rr(c, x - 10, y - 10, w + 20, h + 20, 5), Color("#F4F1EA"), 2)
	grad_v(c, x, y, w, h, y, y + h, [[0.0, Color("#3B3A7A")], [0.55, Color("#D9627A")], [1.0, Color("#F6A65A")]])
	# o sol, recortado pela janela
	var sol := c.caminho().circulo(x + 118, y + h - 40, 20)
	Pinta.fill_recortado(c, sol.subs[0], Pinta.ret_pts(x, y, w, h), rgba(255, 214, 130, 0.9))
	for pr in [[x + 2, 62, 18], [x + 24, 96, 22], [x + 50, 72, 16], [x + 70, 124, 24], [x + 98, 86, 18], [x + 120, 108, 20], [x + 144, 78, 28]]:
		var bx: float = pr[0]
		var bh: float = pr[1]
		var bw: float = pr[2]
		var vis := minf(bw, x + w - bx)
		c.fill_rect(bx, y + h - bh, vis, bh, Color("#3A2B52"))
		var yy := y + h - bh + 6
		while yy < y + h - 4:
			var xx := bx + 3
			while xx < bx + bw - 3:
				if r.f() < 0.45 and xx < x + w:
					c.fill_rect(xx, yy, 2.5, 3.5, rgba(255, 214, 120, 0.85))
				xx += 6
			yy += 9
	# a grade de ferro
	var ferro := Color("#2A2422")
	var xx2 := x + 22
	while xx2 < x + w:
		c.line(xx2, y, xx2, y + h, ferro, 3)
		xx2 += 26
	c.line(x, y + h / 2, x + w, y + h / 2, ferro, 3)
	var xx3 := x + 9
	while xx3 < x + w:
		c.stroke_pts(PackedVector2Array([Vector2(xx3, y + h / 2), Vector2(xx3 + 13, y + h / 2 - 13), Vector2(xx3 + 26, y + h / 2), Vector2(xx3 + 13, y + h / 2 + 13)]), ferro, 2.2, true)
		xx3 += 26
	Pinta.fill_stroke(c, rr(c, x - 16, y + h + 8, w + 32, 9, 2), Color("#ECE6DA"), 2)


static func armario(c: Ctx) -> void:
	var x := 245.0
	var y := 245.0
	var w := 200.0
	var h := 110.0
	c.fill(rr(c, x + 4, y + 8, w, h, 6), rgba(60, 40, 20, 0.18))
	var cx := rr(c, x, y, w, h, 6)
	c.fill_linear(cx, 0, y, 0, y + h, [[0.0, Color("#F4EEDF")], [1.0, Color("#DCD2BC")]])
	c.stroke(cx, LINHA, 2.4)
	c.stroke(rr(c, x + 8, y + 8, w / 2 - 12, h - 16, 4), rgba(42, 31, 26, 0.55), 1.6)
	c.stroke(rr(c, x + w / 2 + 4, y + 8, w / 2 - 12, h - 16, 4), rgba(42, 31, 26, 0.55), 1.6)
	for hx in [x + w / 2 - 14, x + w / 2 + 9]:
		Pinta.fill_stroke(c, rr(c, hx, y + h / 2 - 12, 5, 24, 2.5), Color("#B9C0C8"), 1.2)
	c.circle(x + 30, y + h - 14, 4, rgba(150, 80, 40, 0.35))
	c.circle(x + 168, y + 18, 3, rgba(150, 80, 40, 0.35))


static func filtro(c: Ctx) -> void:
	var x := 413.0
	var yb := 245.0
	var barro := func(cx: float, cy: float, rx: float, ry: float) -> void:
		var e := c.caminho().elipse(cx, cy, rx, ry)
		c.fill_linear(e, cx - rx, 0, cx + rx, 0, [[0.0, Color("#93421F")], [0.4, Color("#D27A4D")], [1.0, Color("#8A3B1C")]])
		c.stroke(e, LINHA, 2)
	barro.call(x, yb - 18, 23, 18)
	Pinta.fill_stroke(c, rr(c, x - 15, yb - 39, 30, 6, 2), Color("#B4552E"), 2)
	barro.call(x, yb - 55, 19, 17)
	Pinta.fill_stroke(c, c.caminho().elipse(x, yb - 71, 15, 4), Color("#A84A25"), 2)
	Pinta.fill_stroke(c, c.caminho().circulo(x, yb - 77, 4), Color("#B4552E"), 2)
	Pinta.fill_stroke(c, rr(c, x - 31, yb - 22, 10, 5, 2), Color("#C9CED6"), 2)
	Pinta.fill_stroke(c, rr(c, x - 31, yb - 18, 4, 7, 1), Color("#C9CED6"), 2)


static func pia(c: Ctx, r: Pinta.Rng) -> void:
	# a torneira atrás
	c.cap_redondo = true
	c.stroke(c.caminho().move_to(214, 740).line_to(214, 702).quad_to(214, 690, 200, 690).line_to(186, 690).line_to(186, 698), Color("#8E969F"), 6)
	c.cap_redondo = false
	c.line(210, 740, 210, 704, LINHA, 1.4)
	Pinta.fill_stroke(c, rr(c, 220, 718, 12, 8, 3), Color("#C9CED6"), 1.4)
	# o tampo de granito
	Pinta.fill_stroke(c, rr(c, 0, 740, 302, 13, 2), Color("#2F2A2C"), 2)
	for i in range(70):
		var cor := rgba(255, 255, 255, 0.45) if r.f() < 0.5 else rgba(200, 190, 180, 0.35)
		c.fill_rect(r.f() * 298 + 2, 742 + r.f() * 9, 1.4, 1.4, cor)
	# o gabinete de aço
	grad_v(c, 4, 753, 292, 112, 753, 866, [[0.0, Color("#F1EBDD")], [1.0, Color("#D8CEB8")]])
	c.stroke(c.caminho().rect(4, 753, 292, 112), LINHA, 2.2)
	for dx in [10.0, 106.0, 202.0]:
		c.stroke(rr(c, dx, 760, 88, 98, 4), rgba(42, 31, 26, 0.55), 1.5)
	for hx in [86.0, 112.0, 208.0]:
		Pinta.fill_stroke(c, rr(c, hx, 790, 5, 22, 2.5), Color("#B9C0C8"), 1.2)
	# o pano de prato
	c.save()
	c.translate(116, 800)
	c.rotate(0.05)
	Pinta.fill_stroke(c, rr(c, -12, -4, 26, 44, 2), Color("#FBF8F1"), 1.4)
	c.fill_rect(-12, 26, 26, 3, Color("#D7342B"))
	c.fill_rect(-12, 31, 26, 2, Color("#D7342B"))
	c.restore()
	c.fill_rect(4, 862, 292, 8, Color("#2E2624"))


static func botijao(c: Ctx) -> void:
	var x := 420.0
	var corpo := rr(c, x - 27, 812, 54, 54, 14)
	c.fill_linear(corpo, x - 27, 0, x + 27, 0, [[0.0, Color("#7E2C22")], [0.35, Color("#C2503E")], [1.0, Color("#6E241B")]])
	c.stroke(corpo, LINHA, 2.2)
	Pinta.fill_stroke(c, rr(c, x - 22, 862, 44, 8, 2), Color("#5C1E17"), 2.2)
	Pinta.fill_stroke(c, rr(c, x - 18, 798, 36, 16, 5), Color("#9E3B2E"), 2.2)
	c.fill(rr(c, x - 10, 801, 7, 8, 2), Color("#2A1F1A"))
	c.fill(rr(c, x + 3, 801, 7, 8, 2), Color("#2A1F1A"))
	Pinta.fill_stroke(c, rr(c, x - 4, 792, 8, 8, 2), Color("#C9CED6"), 1.4)
	c.text("13 kg", x, 846, Fontes.txt(700), 10, rgba(255, 255, 255, 0.8), "center")


static func tomada(c: Ctx) -> void:
	c.cap_redondo = true
	c.stroke(c.caminho().move_to(486, 672).bezier_to(470, 640, 520, 640, 505, 607), Color("#1E1B1A"), 3)
	c.stroke(c.caminho().move_to(482, 690).bezier_to(470, 760, 520, 790, 590, 868), Color("#1E1B1A"), 3)
	c.cap_redondo = false
	Pinta.fill_stroke(c, rr(c, 466, 650, 26, 34, 4), Color("#F7F4EC"), 1.8)
	Pinta.fill_stroke(c, rr(c, 472, 660, 22, 30, 3), Color("#FBFAF6"), 1.8)
	for p in [[477, 666], [487, 666], [477, 682], [487, 682]]:
		c.circle(p[0], p[1], 1.6, Color("#1E1B1A"))


static func cena1(c: Ctx, F: Dictionary, et: float, eb: float) -> void:
	var r := Pinta.Rng.new(7)
	c.fill_rect(0, -et, W, et, Color("#E0CCA9"))
	grad_v(c, 0, 0, W, 520, 0, 500, [[0.0, Color("#E0CCA9")], [1.0, Color("#EFE3C9")]])
	if et > 30:
		# o teto e a lâmpada pendurada no fio, com a emenda de fita isolante
		var ty := maxf(-et, -100.0)
		if ty > -et:
			c.fill_rect(0, -et, W, ty + et, Color("#F4EFE4"))
			c.fill_rect(0, ty, W, 6, rgba(60, 40, 20, 0.18))
		var lx := 150.0
		var ly := ty + minf(70.0, et - 10)
		mancha(c, lx, ly + 10, 120, rgba(255, 214, 130, 0.45), rgba(255, 214, 130, 0))
		c.line(lx, ty, lx, ly - 8, Color("#1E1B1A"), 2)
		c.fill_rect(lx - 3, ty + (ly - ty) * 0.45, 6, 7, Color("#1B1B1B"))
		c.fill(rr(c, lx - 6, ly - 10, 12, 10, 2), Color("#3A3330"))
		Pinta.fill_stroke(c, c.caminho().circulo(lx, ly + 8, 10), Color("#FFF2C4"), 1.6)
	for i in range(9):
		var x := r.f() * W
		var y := r.f() * 470
		var rad := 30 + r.f() * 90
		mancha(c, x, y, rad, rgba(150, 110, 60, 0.10), rgba(150, 110, 60, 0))
	azulejos(c, r)
	janela(c, r)
	tomada(c)
	armario(c)
	filtro(c)
	pia(c, r)
	botijao(c)
	prateleira(c, F.prat)
	prateleira(c, F.prat2)
	# o chão de cimento queimado vermelho
	grad_v(c, 0, CHAO, W, H - CHAO + eb, CHAO, H, [[0.0, Color("#7E2A1E")], [0.25, Color("#A63F2D")], [1.0, Color("#8E3424")]])
	for i in range(6):
		c.fill_rect(r.f() * W, CHAO + 8 + r.f() * 16, 40 + r.f() * 80, 2, rgba(255, 220, 200, 0.12))
	c.fill_rect(0, CHAO - 3, W, 4, Color("#5E1F15"))
	# as etiquetas de fita crepe
	fita_txt(c, 96, 112, "a laranja sai daqui", -0.05)
	fita_txt(c, 548, 470, "cai aqui em cima", 0.04)
	grao(c, r, et, eb)


static func relogio(c: Ctx, segundos: float) -> void:
	var x := 548.0
	var y := 300.0
	var r := 30.0
	var d := Time.get_time_dict_from_system()
	c.save()
	c.translate(x, y)
	c.circle(3, 5, r + 3, rgba(60, 40, 20, 0.2))
	var aro := c.caminho().circulo(0, 0, r)
	c.fill(aro, Color("#F8F4EA"))
	c.stroke(aro, Color("#2B2422"), 5)
	for i in range(12):
		var a := i * PI / 6
		c.line(cos(a) * (r - 8), sin(a) * (r - 8), cos(a) * (r - 4), sin(a) * (r - 4), Color("#2B2422"), 2)
	var ah: float = (float(d.hour % 12) + d.minute / 60.0) * PI / 6 - PI / 2
	var am: float = d.minute * PI / 30 - PI / 2
	var asg := segundos * PI / 30 - PI / 2
	c.cap_redondo = true
	c.line(0, 0, cos(ah) * 14, sin(ah) * 14, Color("#2B2422"), 3.4)
	c.line(0, 0, cos(am) * 21, sin(am) * 21, Color("#2B2422"), 2.4)
	c.line(0, 0, cos(asg) * 24, sin(asg) * 24, Color("#D7342B"), 1.3)
	c.cap_redondo = false
	c.circle(0, 0, 2.4, Color("#D7342B"))
	c.restore()


# ================= a laje =================
static func nuvem(c: Ctx, x: float, y: float, s: float) -> void:
	for q in [[0, 0, 22], [24, -8, 26], [50, 2, 20], [26, 8, 22], [-20, 6, 15]]:
		c.circle(x + q[0] * s, y + q[1] * s, q[2] * s, rgba(255, 255, 255, 0.88))


static func tenis(c: Ctx, x: float, y: float) -> void:
	c.line(x, y, x - 6, y + 22, Color("#F4EFE6"), 1.4)
	c.line(x, y, x + 8, y + 26, Color("#F4EFE6"), 1.4)
	for q in [[-8, 26, 0.5], [8, 30, -0.4]]:
		c.save()
		c.translate(x + q[0], y + q[1])
		c.rotate(q[2])
		Pinta.fill_stroke(c, rr(c, -6, -4, 14, 9, 3), Color("#F4EFE6"), 1.2)
		c.fill_rect(-6, 3, 14, 2.5, Color("#D7342B"))
		c.restore()


static func varal(c: Ctx) -> void:
	for x in [384.0, 630.0]:
		c.line(x, 700, x, 378, Color("#5E5A57"), 5)
	c.stroke(c.caminho().move_to(384, 386).quad_to(507, 404, 630, 382), Color("#3A3533"), 1.4)
	var yv := func(x: float) -> float: return 386 + (x - 384) / 246.0 * -4 + sin((x - 384) / 246.0 * PI) * 9
	# o lençol florido, a camisa azul-celeste, a bermuda e as meias
	var y: float = yv.call(410)
	Pinta.fill_stroke(c, rr(c, 400, y, 58, 74, 2), Color("#F2B6C6"), 1.4)
	for f in [[412, 16], [436, 30], [418, 50], [446, 62], [430, 8]]:
		c.circle(f[0], y + f[1], 3.2, Color("#E0457B"))
	y = yv.call(492)
	Pinta.fill_stroke(c, c.caminho().pontos(PackedVector2Array([Vector2(474, y), Vector2(510, y), Vector2(520, y + 14), Vector2(512, y + 18), Vector2(508, y + 12), Vector2(508, y + 50), Vector2(476, y + 50), Vector2(476, y + 12), Vector2(472, y + 18), Vector2(464, y + 14)])), Color("#8EC3EC"), 1.4)
	y = yv.call(548)
	Pinta.fill_stroke(c, c.caminho().pontos(PackedVector2Array([Vector2(532, y), Vector2(566, y), Vector2(568, y + 34), Vector2(552, y + 34), Vector2(549, y + 16), Vector2(546, y + 34), Vector2(530, y + 34)])), Color("#3E5F8A"), 1.4)
	y = yv.call(596)
	Pinta.fill_stroke(c, rr(c, 586, y, 9, 24, 3), Color("#F4EFE6"), 1.4)
	Pinta.fill_stroke(c, rr(c, 600, y, 9, 22, 3), Color("#F4EFE6"), 1.4)
	for q in [[406, "#FFC531"], [452, "#3E6DB5"], [478, "#E0457B"], [506, "#FFC531"], [536, "#3E6DB5"], [562, "#E0457B"], [590, "#FFC531"], [604, "#3E6DB5"]]:
		c.fill_rect(q[0] - 2, yv.call(q[0]) - 4, 4, 9, Color(q[1]))


static func antena(c: Ctx, x: float, y: float) -> void:
	c.line(x, y + 30, x, y, Color("#4E4A47"), 3)
	c.save()
	c.translate(x, y)
	c.rotate(-0.5)
	Pinta.fill_stroke(c, c.caminho().elipse(0, 0, 10, 28), Color("#C9CED6"), 1.6)
	c.line(0, 0, 22, 0, LINHA, 1.6)
	c.fill_rect(20, -3, 6, 6, Color("#4E4A47"))
	c.restore()


static func cena2(c: Ctx, _F: Dictionary, et: float, eb: float) -> void:
	var r := Pinta.Rng.new(21)
	grad_v(c, 0, -et, W, 700 + et, -et, 700, [[0.0, Color("#3C78C2")], [0.6, Color("#93C6EC")], [1.0, Color("#F8CDA0")]])
	c.radial(470, 610, 6, 470, 610, 120, [[0.0, rgba(255, 240, 190, 0.95)], [0.25, rgba(255, 214, 150, 0.6)], [1.0, rgba(255, 214, 150, 0)]], 1.0, 12)
	for q in [[110, 40, 1.0], [420, 150, 0.8], [270, 300, 0.6], [580, 330, 0.7]]:
		nuvem(c, q[0], q[1], q[2])
	# a cidade lá longe
	var x := 0.0
	while x < W:
		var w := 16 + r.f() * 34
		var h := 30 + r.f() * (140.0 if x > 360 and x < 560 else 80.0)
		c.fill_rect(x, 700 - h, minf(w - 2, W - x), h, Color("#7D7FA8") if r.f() < 0.5 else Color("#6C6E98"))
		var yy := 700 - h + 6
		while yy < 694:
			var xx := x + 3
			while xx < x + w - 5:
				if r.f() < 0.18:
					c.fill_rect(xx, yy, 2.4, 3.4, rgba(255, 226, 160, 0.7))
				xx += 6
			yy += 9
		x += w
	# a fiação, com o tênis pendurado
	for q in [[236.0, 206.0, 40.0], [256.0, 226.0, 46.0]]:
		c.stroke(c.caminho().move_to(0, q[0]).quad_to(W / 2, (q[0] + q[1]) / 2 + q[2], W, q[1]), Color("#2A2422"), 1.6)
	tenis(c, 470, 258)
	varal(c)
	# a mureta de bloco sem reboco
	c.fill_rect(0, 700, W, CHAO - 700, Color("#8F897E"))
	var j := 0
	while 700 + j * 20 < CHAO:
		for i in range(-1, int(W / 40) + 1):
			var cor := Color("#C8C1B4") if r.f() < 0.12 else (Color("#ABA59A") if r.f() < 0.5 else Color("#A19B90"))
			var bx := i * 40 + (j % 2) * 20 + 1
			var x0 := maxf(0.0, bx)
			var x1 := minf(W, bx + 38)
			if x1 > x0:
				c.fill_rect(x0, 700 + j * 20 + 1, x1 - x0, minf(18.0, CHAO - (700 + j * 20 + 1)), cor)
		j += 1
	c.fill_rect(0, 696, W, 6, Color("#7E786E"))
	antena(c, 432, 668)
	# o chão da laje, com a poça
	grad_v(c, 0, CHAO, W, H - CHAO + eb, CHAO, H + eb, [[0.0, Color("#77736A")], [0.2, Color("#9B958A")], [1.0, Color("#8A847A")]])
	c.fill(c.caminho().elipse(430, CHAO + 15, 58, 5), rgba(140, 190, 235, 0.4))
	# a torre de tijolo baiano
	c.fill_rect(45, 266, 80, CHAO - 266, Color("#7A3A22"))
	j = 0
	while 266 + j * 18 < CHAO:
		for i in range(3):
			var bx := 45 + i * 28 + (-14 if j % 2 == 1 else 0)
			var by := 266 + j * 18
			var bw := minf(27.0, 125.0 - bx - 1)
			var bxx := maxf(46.0, bx)
			if bw <= 2:
				continue
			var cor := Color("#C0603A") if r.f() < 0.3 else Color("#B5532F")
			c.fill_rect(bxx, by + 1, minf(bw, bx + 27 - bxx), minf(16.0, CHAO - by - 1), cor)
		j += 1
	c.stroke(c.caminho().rect(45, 266, 80, CHAO - 266), LINHA, 2)
	# a caixa d'água
	var cx := rr(c, 20, 148, 130, 118, 14)
	c.fill_linear(cx, 20, 0, 150, 0, [[0.0, Color("#1F5592")], [0.4, Color("#4A93D8")], [1.0, Color("#1D4E86")]])
	c.stroke(cx, LINHA, 2.2)
	for y in [178.0, 206.0, 234.0]:
		c.line(22, y, 148, y, rgba(15, 40, 80, 0.45), 2)
	c.save()
	c.translate(85, 140)
	c.rotate(0.14)
	Pinta.fill_stroke(c, rr(c, -73, -6, 146, 12, 5), Color("#2A64A6"), 2)
	Pinta.fill_stroke(c, rr(c, -10, -12, 20, 7, 3), Color("#1D4E86"), 2)
	c.restore()
	# a churrasqueira de tambor
	for q in [[176.0, 196.0], [254.0, 234.0]]:
		c.line(q[0], CHAO, q[1], 812, Color("#3A3330"), 4)
	Pinta.fill_stroke(c, rr(c, 165, 772, 100, 44, 18), Color("#2B2624"), 2.2)
	c.circle(190, 800, 6, rgba(160, 70, 30, 0.55))
	c.circle(240, 790, 4, rgba(160, 70, 30, 0.55))
	c.fill_rect(172, 764, 86, 6, Color("#FF8A3D"))
	c.line(166, 764, 264, 764, Color("#8A8F96"), 1.6)
	var gx := 172.0
	while gx < 262:
		c.line(gx, 762, gx, 768, Color("#8A8F96"), 1.6)
		gx += 9
	for e in [[186.0, 760.0], [214.0, 758.0], [240.0, 760.0]]:
		c.line(e[0] - 18, e[1], e[0] + 18, e[1], Color("#C9A06A"), 1.6)
		for k in [-9.0, 0.0, 9.0]:
			c.fill(rr(c, e[0] + k - 4, e[1] - 4, 8, 8, 2), Color("#7A3B1F"))
	# o muro inacabado, com o ferro de espera
	c.fill_rect(302, 490, 56, CHAO - 490, Color("#9B958A"))
	j = 0
	while 490 + j * 20 < CHAO:
		c.fill_rect(304 + (j % 2) * 4, 492 + j * 20, 48, minf(17.0, CHAO - (492 + j * 20)), Color("#B2AC9F") if j % 3 != 0 else Color("#A8A295"))
		j += 1
	c.stroke(c.caminho().rect(302, 490, 56, CHAO - 490), LINHA, 2)
	c.cap_redondo = true
	for q in [[312.0, 448.0, 6.0], [330.0, 440.0, -5.0], [348.0, 452.0, 7.0]]:
		c.stroke_pts(PackedVector2Array([Vector2(q[0], 490), Vector2(q[0], q[1]), Vector2(q[0] + q[2], q[1] - 5)]), Color("#8A4B2A"), 2.6)
	c.cap_redondo = false
	# os engradados
	for q in [[730.0, "#F2B21B", "#C98D06"], [800.0, "#C8352E", "#8E211C"]]:
		Pinta.fill_stroke(c, rr(c, 495, q[0], 110, 70, 4), Color(q[1]), 2)
		for i in range(6):
			for k in range(2):
				c.fill(rr(c, 503 + i * 16, q[0] + 20 + k * 22, 10, 14, 2), Color(q[2]))
		c.fill(rr(c, 530, q[0] + 5, 40, 8, 4), rgba(0, 0, 0, 0.35))
	fita_txt(c, 104, 68, "a laranja sai daqui", -0.05)
	fita_txt(c, 550, 560, "liga o som", 0.05)
	grao(c, r, et, eb)


static func vivo2(c: Ctx, t: float, fumaca: Array, reduz := false) -> void:
	# a pipa
	var px := 520 + sin(t / 900.0) * 14
	var py := 84 + sin(t / 600.0) * 8
	c.stroke(c.caminho().move_to(px, py + 16).quad_to(600, 220, W + 10, 270), rgba(40, 30, 30, 0.45), 1)
	c.save()
	c.translate(px, py)
	c.rotate(sin(t / 700.0) * 0.15)
	var losango := PackedVector2Array([Vector2(0, -18), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0)])
	c.fill_pts(losango, Color("#E0457B"))
	c.fill_pts(PackedVector2Array([Vector2(0, -18), Vector2(13, 0), Vector2(0, 0)]), Color("#FFC531"))
	c.stroke_pts(losango, LINHA, 1.4, true)
	var rabo := PackedVector2Array([Vector2(0, 16)])
	for i in range(1, 9):
		rabo.append(Vector2(sin(t / 200.0 + i) * 5, 16 + i * 6))
	c.stroke_pts(rabo, Color("#2D5DA6"), 1.2)
	c.restore()
	# a fumaça do churrasco
	if not reduz and (fumaca.is_empty() or t - float(fumaca[fumaca.size() - 1].t) > 150):
		fumaca.append({ "x": 196 + randf() * 36, "y": 756.0, "t": t })
	while not fumaca.is_empty() and t - float(fumaca[0].t) >= 2600:
		fumaca.pop_front()
	for f in fumaca:
		var k: float = (t - float(f.t)) / 2600.0
		c.circle(f.x + k * 50 + sin(k * 6 + f.x) * 6, f.y - k * 170, 6 + k * 16, Color(0.925, 0.91, 0.886, 0.32 * (1 - k)))


# ================= a garagem =================
static func carro_vo(c: Ctx) -> void:
	# o carro do vô: redondinho, azul calcinha, cromado; desenho nosso
	c.fill(c.caminho().elipse(335, CHAO - 2, 210, 9), rgba(20, 16, 14, 0.45))
	var corpo := c.caminho()
	corpo.move_to(152, 830).line_to(150, 778).quad_to(152, 748, 196, 742).line_to(232, 740)
	corpo.quad_to(250, 664, 300, 656).line_to(372, 656).quad_to(422, 662, 440, 738)
	corpo.line_to(486, 742).quad_to(520, 752, 520, 790).line_to(520, 830).fecha()
	c.fill_linear(corpo, 0, 650, 0, 840, [[0.0, Color("#C4DDEE")], [0.45, Color("#9CC6E0")], [1.0, Color("#6F9DBD")]])
	c.stroke(corpo, LINHA, 2.6)
	# os vidros
	c.fill(c.caminho().move_to(246, 734).quad_to(260, 676, 302, 670).line_to(332, 670).line_to(332, 734).fecha(), Color("#34506B"))
	c.fill(c.caminho().move_to(342, 734).line_to(342, 670).line_to(368, 670).quad_to(410, 676, 424, 734).fecha(), Color("#34506B"))
	c.line(264, 726, 292, 680, rgba(255, 255, 255, 0.35), 3)
	c.line(356, 726, 372, 684, rgba(255, 255, 255, 0.35), 3)
	# a fitinha no retrovisor
	c.line(332, 672, 328, 694, Color("#D7342B"), 1.6)
	c.line(333, 672, 336, 692, Color("#FFC531"), 1.6)
	# porta, maçaneta, frisos
	c.line(338, 742, 338, 822, rgba(42, 31, 26, 0.55), 1.6)
	c.line(244, 742, 250, 822, rgba(42, 31, 26, 0.55), 1.6)
	c.fill(rr(c, 316, 760, 14, 4, 2), Color("#D5DAE0"))
	c.line(160, 792, 512, 792, Color("#E6EAEE"), 3)
	# para-choques cromados e farol redondo
	Pinta.fill_stroke(c, rr(c, 140, 812, 30, 10, 4), Color("#D5DAE0"), 1.6)
	Pinta.fill_stroke(c, rr(c, 504, 812, 26, 10, 4), Color("#D5DAE0"), 1.6)
	Pinta.fill_stroke(c, c.caminho().circulo(170, 764, 11), Color("#F6EFD8"), 2)
	# as rodas
	for x in [215.0, 455.0]:
		Pinta.fill_stroke(c, c.caminho().circulo(x, 846, 24), Color("#1E1B1A"), 2)
		c.circle(x, 846, 12, Color("#D5DAE0"))
		c.circle(x, 846, 4, Color("#8A8F96"))


static func ferramentas(c: Ctx) -> void:
	# o painel furado com as ferramentas penduradas
	Pinta.fill_stroke(c, rr(c, 188, 104, 214, 150, 3), Color("#C69A62"), 2)
	var y := 114
	while y < 250:
		var x := 198
		while x < 396:
			c.fill_rect(x, y, 2, 2, rgba(70, 40, 15, 0.45))
			x += 12
		y += 12
	var ferro := Color("#3A3533")
	c.cap_redondo = true
	c.line(216, 126, 216, 196, ferro, 4)
	c.fill(rr(c, 204, 120, 24, 12, 3), ferro)   # martelo
	c.line(252, 130, 252, 214, ferro, 4)
	c.stroke(c.caminho().arc(252, 128, 9, PI * 0.2, PI * 1.8), ferro, 6)   # chave
	c.line(282, 124, 292, 196, ferro, 4)
	c.line(302, 124, 292, 196, ferro, 4)   # alicate
	c.cap_redondo = false
	Pinta.fill_stroke(c, c.caminho().pontos(PackedVector2Array([Vector2(324, 124), Vector2(384, 140), Vector2(384, 166), Vector2(324, 150)])), Color("#B9BEC6"), 1.6)   # serrote
	c.fill(rr(c, 316, 122, 12, 32, 3), Color("#7A4A26"))
	Pinta.fill_stroke(c, rr(c, 336, 186, 30, 26, 6), Color("#FFC531"), 1.6)   # trena
	c.circle(351, 199, 6, ferro)


static func cena3(c: Ctx, F: Dictionary, et: float, eb: float) -> void:
	var r := Pinta.Rng.new(33)
	c.fill_rect(0, -et, W, et, Color("#2A2524"))
	# o forro de madeira com os caibros, quando sobra tela em cima
	if et > 20:
		var x := 10.0
		while x < W:
			c.fill_rect(x, -et, 14, et, Color("#3A302A"))
			x += 64
		c.fill_rect(0, -10, W, 10, Color("#4A3C33"))
	grad_v(c, 0, 0, W, 520, 0, 520, [[0.0, Color("#A9A396")], [1.0, Color("#C3BDB0")]])
	c.fill_rect(0, 520, W, CHAO - 520, Color("#2F5E8E"))
	c.fill_rect(0, 516, W, 6, Color("#F2E8D2"))
	for i in range(14):
		var x := r.f() * W
		var y := 530 + r.f() * 300
		c.fill_rect(x, y, minf(20 + r.f() * 50, W - x), 2, rgba(255, 255, 255, 0.07))
	# a lâmpada fluorescente e a luz dela
	c.radial(330, 30, 10, 330, 260, 420, [[0.0, rgba(255, 250, 230, 0.45)], [1.0, rgba(255, 250, 230, 0)]], 0.62, 14)
	Pinta.fill_stroke(c, rr(c, 250, 24, 160, 12, 6), Color("#ECE8DD"), 1.6)
	c.line(262, 24, 262, -et, Color("#2A2422"), 1.4)
	c.line(398, 24, 398, -et, Color("#2A2422"), 1.4)
	ferramentas(c)
	# o cartaz do ensaio
	c.save()
	c.translate(120, 330)
	c.rotate(-0.05)
	c.fill_rect(-46, -56, 92, 112, Color("#F2B6C6"))
	c.stroke(c.caminho().rect(-46, -56, 92, 112), LINHA, 1.6)
	c.text("OS", 0, -30, Fontes.letreiro(), 15, Color("#1F1915"), "center")
	c.text("LARANJAS", 0, -12, Fontes.letreiro(), 15, Color("#1F1915"), "center")
	Pinta.fill_stroke(c, c.caminho().circulo(0, 18, 14), Color("#F07A1C"), 1.6)
	c.text("ENSAIO SÁBADO 15H", 0, 46, Fontes.txt(400), 9, Color("#1F1915"), "center")
	c.fill_rect(-14, -62, 28, 10, rgba(230, 210, 155, 0.95))
	c.restore()
	# o portão basculante lá no fundo
	c.fill_rect(566, 250, W - 566, CHAO - 250, Color("#7F8C99"))
	var xg := 572.0
	while xg < W:
		c.line(xg, 250, xg, CHAO, rgba(30, 40, 50, 0.45), 2)
		xg += 10
	c.stroke(c.caminho().rect(566, 250, W - 566 + 4, CHAO - 250), LINHA, 2)
	# o chão de cimento com a mancha de óleo
	grad_v(c, 0, CHAO, W, H - CHAO + eb, CHAO, H + eb, [[0.0, Color("#5E5A55")], [0.2, Color("#8C8780")], [1.0, Color("#7C7770")]])
	c.fill(c.caminho().elipse(360, CHAO + 18, 70, 6), rgba(25, 20, 30, 0.45))
	# a bancada, com a morsa e a caixa de ferramenta embaixo
	c.fill_rect(8, 616, 14, CHAO - 616, Color("#7A5532"))
	c.fill_rect(124, 616, 14, CHAO - 616, Color("#7A5532"))
	c.fill_rect(8, 790, 130, 8, Color("#5E3F22"))
	Pinta.fill_stroke(c, rr(c, 34, 822, 70, 46, 4), Color("#C8352E"), 1.8)
	c.fill_rect(34, 836, 70, 4, Color("#8E211C"))
	c.fill(rr(c, 60, 816, 18, 6, 2), Color("#D5DAE0"))
	Pinta.fill_stroke(c, rr(c, 0, 600, 150, 18, 2), Color("#A6743F"), 2)
	c.line(2, 606, 148, 606, rgba(70, 40, 15, 0.45), 1)
	c.line(2, 612, 148, 612, rgba(70, 40, 15, 0.45), 1)
	Pinta.fill_stroke(c, rr(c, 128, 584, 20, 16, 2), Color("#4E5A66"), 1.6)
	c.fill_rect(136, 578, 4, 8, Color("#4E5A66"))
	carro_vo(c)
	# a prateleira de lata de tinta, de onde a laranja sai
	Pinta.fill_stroke(c, rr(c, 452, 118, 30, 40, 3), Color("#D9D4C8"), 1.6)
	c.fill_rect(452, 132, 30, 10, Color("#3E6DB5"))
	Pinta.fill_stroke(c, rr(c, 488, 128, 26, 34, 3), Color("#B9BEC6"), 1.6)
	c.fill_rect(488, 140, 26, 8, Color("#E0457B"))
	prateleira(c, F.prat)
	fita_txt(c, 540, 92, "a laranja sai daqui", 0.05)
	fita_txt(c, 76, 460, "liga o amplificador", -0.04)
	grao(c, r, et, eb, 0.04)


static func vivo3(c: Ctx, fra: float) -> void:
	# o pisca-alerta do carro marca o tempo
	var aceso := fra < 0.3
	for q in [[156.0, 800.0], [514.0, 798.0]]:
		if aceso:
			c.radial(q[0], q[1], 2, q[0], q[1], 40, [[0.0, rgba(255, 176, 32, 0.55)], [1.0, rgba(255, 176, 32, 0)]], 1.0, 8)
		Pinta.fill_stroke(c, c.caminho().circulo(q[0], q[1], 6), Color("#FFB020") if aceso else Color("#8A5A1C"), 1.4)


static func cena(i: int, c: Ctx, F: Dictionary, et: float, eb: float) -> void:
	match i:
		0:
			cena1(c, F, et, eb)
		1:
			cena2(c, F, et, eb)
		2:
			cena3(c, F, et, eb)
