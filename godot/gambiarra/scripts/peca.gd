class_name Peca
extends RefCounted
## Uma peça da tralha: o desenho de colisão (igual ao da versão web) e, enquanto roda, os corpos de física.
## Parada (editando), a peça é só número: x, y, ângulo e pra que lado olha. Os corpos nascem no VAI!.

class Forma:
	var circulo := false
	var r := 0.0
	var c := Vector2.ZERO               # centro (círculo) relativo ao centro da parte
	var pts := PackedVector2Array()     # polígono convexo relativo ao centro da parte

class Parte:
	var lx := 0.0
	var ly := 0.0
	var fixa := false                   # não gira com a peça (o pé do ventilador, a base da gangorra)
	var formas: Array[Forma] = []
	var dinamico := false
	var densidade := 0.001
	var atrito := 1.0                   # corpo parado no Matter fica com atrito 1 e quique 0
	var quique := 0.0
	var ar := 0.0                       # frictionAir do Matter (por passo)
	var trava_giro := false
	var motor := false                  # o braço do limpador: a gente leva ele na mão a cada passo
	var corpo: PhysicsBody2D = null

var id := 0
var tipo := ""
var x := 0.0
var y := 0.0
var a := 0.0
var flip := 1
var partes: Array[Parte] = []
var ev := {}
var entrou := false
var assustado := false
var acordado := false
var corre := 0
var squash := 0.0
var liga := -1.0                       # passo em que o limpador começou a varrer (-1: desligado)
var junta: Joint2D = null


static func retangulo(w: float, h: float, ch := 0.0, ang := 0.0, c := Vector2.ZERO) -> PackedVector2Array:
	# o retângulo do Matter, com o canto arredondado (chamfer) quando pede
	var p := PackedVector2Array()
	var hw := w / 2.0
	var hh := h / 2.0
	if ch <= 0.0:
		p = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	else:
		var r := minf(ch, minf(hw, hh))
		var n := clampi(int(ceil(pow(r, 0.32) * 1.75)), 2, 14)
		var cantos := [[Vector2(hw - r, -hh + r), -PI / 2.0], [Vector2(hw - r, hh - r), 0.0], [Vector2(-hw + r, hh - r), PI / 2.0], [Vector2(-hw + r, -hh + r), PI]]
		for k in cantos:
			var cc: Vector2 = k[0]
			var a0: float = k[1]
			for i in range(n + 1):
				var t := a0 + (PI / 2.0) * float(i) / float(n)
				p.append(cc + Vector2(cos(t), sin(t)) * r)
	if ang != 0.0 or c != Vector2.ZERO:
		p = Transform2D(ang, c) * p
	return p


static func circulo_pts(r: float, c := Vector2.ZERO, n := 0) -> PackedVector2Array:
	if n <= 0:
		n = int(ceil(maxf(10.0, minf(25.0, r))))
	var p := PackedVector2Array()
	for i in range(n):
		var t := TAU * float(i) / float(n)
		p.append(c + Vector2(cos(t), sin(t)) * r)
	return p


static func _f_poly(pts: PackedVector2Array) -> Forma:
	var f := Forma.new()
	f.pts = pts
	return f


static func _f_circ(r: float, c := Vector2.ZERO) -> Forma:
	var f := Forma.new()
	f.circulo = true
	f.r = r
	f.c = c
	f.pts = circulo_pts(r, c)
	return f


static func _parte(formas: Array[Forma], lx := 0.0, ly := 0.0, fixa := false) -> Parte:
	var pt := Parte.new()
	pt.formas = formas
	pt.lx = lx
	pt.ly = ly
	pt.fixa = fixa
	return pt


static func nova(tipo_: String, x_ := 0.0, y_ := 0.0, a_ := 0.0, flip_ := 1) -> Peca:
	var p := Peca.new()
	p.tipo = tipo_
	p.x = x_
	p.y = y_
	p.a = a_
	p.flip = flip_
	p._monta()
	return p


func _monta() -> void:
	partes.clear()
	match tipo:
		"tabua":
			var pt := _parte([_f_poly(retangulo(150, 14))])
			pt.atrito = 0.25
			partes.append(pt)
		"colchao":
			var pt := _parte([_f_poly(retangulo(124, 26, 9))])
			pt.quique = 0.97
			pt.atrito = 0.3
			partes.append(pt)
		"bacia":
			var pt := _parte([_f_poly(retangulo(84, 10, 0, 0, Vector2(0, 15))), _f_poly(retangulo(8, 44, 0, -0.36, Vector2(-47, -2))), _f_poly(retangulo(8, 44, 0, 0.36, Vector2(47, -2)))])
			partes.append(pt)
		"lata":
			var pt := _parte([_f_circ(16)])
			pt.dinamico = true
			pt.densidade = 0.002
			pt.quique = 0.25
			pt.atrito = 0.05
			pt.ar = 0.004
			partes.append(pt)
		"garrafa":
			var pt := _parte([_f_poly(retangulo(22, 62, 6))])
			pt.dinamico = true
			pt.densidade = 0.0006
			pt.atrito = 0.6
			pt.quique = 0.2
			pt.ar = 0.004
			partes.append(pt)
		"gangorra":
			var base := _parte([_f_poly(retangulo(44, 44))], 0, 23, true)
			var tab := _parte([_f_poly(retangulo(172, 12))], 0, -6)
			tab.dinamico = true
			tab.densidade = 0.0025
			tab.atrito = 0.7
			tab.quique = 0.15
			tab.ar = 0.004
			partes.append(base)
			partes.append(tab)
		"ventilador":
			partes.append(_parte([_f_poly(retangulo(40, 56, 15))], -6, 0))
			partes.append(_parte([_f_poly(retangulo(10, 30))], 0, 42, true))
			partes.append(_parte([_f_poly(retangulo(50, 10))], 0, 61, true))
		"gato":
			var pt := _parte([_f_poly(retangulo(40, 40, 12))])
			pt.dinamico = true
			pt.densidade = 0.0012
			pt.atrito = 0.8
			pt.quique = 0.1
			pt.ar = 0.004
			partes.append(pt)
		"telha":
			# a telha colonial é um arco de pedacinhos: a laranja corre por dentro da curva
			var fs: Array[Forma] = []
			var R := 66.0
			for i in range(8):
				var th := deg_to_rad(25.0 + 130.0 * (i + 0.5) / 8.0)
				fs.append(_f_poly(retangulo(21, 8, 0, th + PI / 2.0, Vector2(R * cos(th), R * sin(th) - 50.0))))
			var pt := _parte(fs)
			pt.atrito = 0.05
			pt.quique = 0.1
			partes.append(pt)
		"pneu":
			var pt := _parte([_f_circ(24)])
			pt.dinamico = true
			pt.densidade = 0.0011
			pt.quique = 0.72
			pt.atrito = 0.9
			pt.ar = 0.002
			partes.append(pt)
		"caramelo":
			var pt := _parte([_f_poly(retangulo(58, 30, 12))])
			pt.dinamico = true
			pt.densidade = 0.0016
			pt.atrito = 0.6
			pt.quique = 0.1
			pt.ar = 0.004
			pt.trava_giro = true        # cachorro corre de pé, não capota
			partes.append(pt)
		"limpador":
			var base := _parte([_f_circ(13)])
			var br := _parte([_f_poly(retangulo(112, 7))], 56, 0)
			br.dinamico = true
			br.motor = true
			br.densidade = 0.02
			br.atrito = 0.3
			br.quique = 0.25
			partes.append(base)
			partes.append(br)
		"balde":
			var pt := _parte([_f_poly(retangulo(50, 54, 5))])
			pt.quique = 0.3
			partes.append(pt)


# ---------- onde fica cada parte ----------
func pose_parte(pt: Parte) -> Transform2D:
	if pt.corpo != null and is_instance_valid(pt.corpo):
		return pt.corpo.global_transform
	return pose_parada(pt)


func pose_parada(pt: Parte) -> Transform2D:
	if pt.fixa:
		return Transform2D(0.0, Vector2(x + pt.lx, y + pt.ly))
	return Transform2D(a, Vector2(x, y) + Vector2(pt.lx, pt.ly).rotated(a))


func origem() -> Transform2D:
	# de onde a peça é desenhada: a primeira parte menos o deslocamento dela
	var pt := partes[0]
	var xf := pose_parte(pt)
	if pt.fixa:
		return Transform2D(0.0, xf.origin - Vector2(pt.lx, pt.ly))
	var ang := xf.get_rotation()
	return Transform2D(ang, xf.origin - Vector2(pt.lx, pt.ly).rotated(ang))


func poligonos(parada := false) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for pt in partes:
		var xf := pose_parada(pt) if parada else pose_parte(pt)
		for f in pt.formas:
			out.append(xf * f.pts)
	return out


func caixa(parada := true) -> Rect2:
	var r := Rect2()
	var primeiro := true
	for pg in poligonos(parada):
		for v in pg:
			if primeiro:
				r = Rect2(v, Vector2.ZERO)
				primeiro = false
			else:
				r = r.expand(v)
	return r


func caixas_partes(parada := true) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pt in partes:
		var xf := pose_parada(pt) if parada else pose_parte(pt)
		var r := Rect2()
		var primeiro := true
		for f in pt.formas:
			for v in xf * f.pts:
				if primeiro:
					r = Rect2(v, Vector2.ZERO)
					primeiro = false
				else:
					r = r.expand(v)
		out.append(r)
	return out


func reseta_estado() -> void:
	entrou = false
	ev = {}
	assustado = false
	acordado = false
	corre = 0
	squash = 0.0
	liga = -1.0
