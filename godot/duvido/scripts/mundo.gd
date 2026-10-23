class_name Mundo
extends Node2D
## O desenho do mundo (porte do desenho.js): o asfalto de noite, o giz, a tábua da largada, a mola, o turbo,
## o caramelo, a bandeira, o carrinho de rolimã com o piloto de balde, a poeira, o confete, os pedaços,
## o barranco dos lados (no computador) e a tira da direita com a ladeira inteira.
## O que não muda (asfalto, sujeira, giz) é desenhado uma vez; o que mexe, a cada quadro.

const LARG := 420.0
const TH := 256.0
const RODA := 6.5
const CAMISAS := [Color("#FF7A2F"), Color("#4AA8FF"), Color("#FF4F9A"), Color("#FFC93C"), Color("#B07CFF"), Color("#F3EEE2")]
const CORES_CONFETE := [Color("#FFC93C"), Color("#FF4F9A"), Color("#4AA8FF"), Color("#FF7A2F"), Color("#F3EEE2"), Color("#B07CFF")]

var j    # o Principal (o estado do jogo)

# a tela
var SW := 720.0
var SH := 1280.0
var K := 1.6
var COLX := 0.0
var COLW := 700.0
var TIRAX := 700.0
var TIRAW := 40.0
var VH := 800.0
var largo := false

# a cena: a fase que tá na tela
var cena_fase: Dictionary = {}
var cena_F: Nucleo.Fase = null
var cena_tracos: Array = []      # {cor, pts, bb}
var cena_sem := 7
var y_max := 150.0

# os nós
var fora_fixo: Node2D
var fora: Node2D
var clip: Control
var cena: Node2D
var fundo: Node2D
var gizes: Node2D
var vivo: Node2D
var vivo_giz: Node2D
var tira: Node2D
var tira_topo: Node2D
var pc: Lote
var pc_fundo: Lote
var pc_fora: Lote
var linhas_vivas: Array = []

# as partículas
var parts: Array = []
var pedacos: Array = []


func _ready() -> void:
	fora_fixo = Node2D.new()
	add_child(fora_fixo)
	fora_fixo.draw.connect(_desenha_fora_fixo)
	fora = Node2D.new()
	add_child(fora)
	fora.draw.connect(_desenha_fora)
	pc_fora = Lote.new(fora)
	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	cena = Node2D.new()
	clip.add_child(cena)
	fundo = Node2D.new()
	fundo.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cena.add_child(fundo)
	fundo.draw.connect(_desenha_fundo)
	pc_fundo = Lote.new(fundo)
	gizes = Node2D.new()
	cena.add_child(gizes)
	vivo_giz = Node2D.new()
	cena.add_child(vivo_giz)
	vivo = Node2D.new()
	cena.add_child(vivo)
	vivo.draw.connect(_desenha_vivo)
	pc = Lote.new(vivo)
	tira = Node2D.new()
	add_child(tira)
	tira.draw.connect(_desenha_tira_base)
	tira_topo = Node2D.new()
	add_child(tira_topo)
	tira_topo.draw.connect(_desenha_tira_topo)
	# o traço que tá sendo riscado no editor (três passadas, como os outros)
	for i in 3:
		var l := _nova_linha(0, i)
		vivo_giz.add_child(l)
		linhas_vivas.append(l)


# ---------------------------------------------------------------- a tela
func mede(tam: Vector2, p: float) -> void:
	SW = maxf(200.0, tam.x)
	SH = maxf(200.0, tam.y)
	largo = SW / p >= 600.0
	TIRAW = (26.0 if largo else 22.0) * p
	if not largo:
		COLW = SW - TIRAW
		COLX = 0.0
		TIRAX = COLW
	else:
		COLW = minf(520.0 * p, SW - 2.0 * (TIRAW + 34.0 * p))
		COLX = round((SW - COLW) / 2.0)
		TIRAX = COLX + COLW + 14.0 * p
	K = COLW / LARG
	VH = SH / K
	clip.position = Vector2(COLX, 0)
	clip.size = Vector2(COLW, SH)
	cena.scale = Vector2(K, K)
	tira.position = Vector2(TIRAX, 0)
	tira_topo.position = Vector2(TIRAX, 0)
	Texturas.escala(K)
	fora.visible = largo
	fora_fixo.visible = largo
	_refaz_estatico()


func _refaz_estatico() -> void:
	fundo.queue_redraw()
	fora.queue_redraw()
	fora_fixo.queue_redraw()
	tira.queue_redraw()


## A câmera e o tremor: o mundo anda, o que foi desenhado uma vez fica.
func posiciona(cam_y: float, tremor: float) -> void:
	var sx := 0.0
	var sy := 0.0
	if tremor > 0.0:
		sx = (randf() - 0.5) * 14.0 * tremor * j.P
		sy = (randf() - 0.5) * 10.0 * tremor * j.P
	cena.position = Vector2(sx, sy - cam_y * K)
	fora.position = Vector2(0, -cam_y * K)
	vivo.queue_redraw()
	tira_topo.queue_redraw()


# ---------------------------------------------------------------- a cena
func monta_cena(fase: Dictionary, F: Nucleo.Fase) -> void:
	cena_fase = fase
	cena_F = F if F != null else Nucleo.compila(fase)
	y_max = cena_F.y_max
	cena_tracos = []
	var s := 7
	for t in fase["tracos"]:
		var pts: Array = t["pts"]
		var x0 := 1e9
		var y0 := 1e9
		var x1 := -1e9
		var y1 := -1e9
		var i := 0
		while i < pts.size():
			x0 = minf(x0, pts[i]); x1 = maxf(x1, pts[i]); y0 = minf(y0, pts[i + 1]); y1 = maxf(y1, pts[i + 1])
			i += 2
		cena_tracos.append({"cor": int(t["cor"]), "pts": pts, "bb": [x0, y0, x1, y1]})
		s = (s * 31 + pts.size() + (int(pts[1]) if pts.size() > 1 else 0)) % 100003
	cena_sem = s
	_refaz_gizes()
	_refaz_estatico()


## Só os carimbos mudaram (o editor arrastando um): a fase compilada nova, o giz igual.
func troca_carimbos(fase: Dictionary) -> void:
	cena_fase = fase
	cena_F = Nucleo.compila(fase)
	y_max = cena_F.y_max
	tira.queue_redraw()


func _refaz_gizes() -> void:
	for c in gizes.get_children():
		c.queue_free()
	for i in cena_tracos.size():
		var tr: Dictionary = cena_tracos[i]
		_poe_giz(gizes, tr["pts"], tr["cor"], i)


func _nova_linha(cor: int, passada: int) -> Line2D:
	var l := Line2D.new()
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	l.round_precision = 6
	_acerta_linha(l, cor, passada)
	return l


func _acerta_linha(l: Line2D, cor: int, passada: int) -> void:
	var c: Color = Estilo.CORES_GIZ[cor] if cor >= 0 and cor < 4 else Estilo.CORES_GIZ[0]
	if passada == 0:
		l.width = 13.0
		l.default_color = Color(c.r, c.g, c.b, 0.09)
		l.material = null
	elif passada == 1:
		l.width = 7.4
		l.default_color = c
		l.material = Texturas.mat_giz[cor if cor >= 0 and cor < 4 else 0]
	else:
		l.width = 4.2
		l.default_color = Color(c.r, c.g, c.b, 0.55)
		l.material = Texturas.mat_giz[cor if cor >= 0 and cor < 4 else 0]


## O giz: a poeira em volta, o miolo com grão e uma segunda passada, tudo com um tremidinho de mão.
func _poe_giz(pai: Node, pts: Array, cor: int, sem: int) -> void:
	var difs := [[sem, 0.8], [sem + 3, 0.55], [sem + 9, 0.7]]
	for passada in 3:
		var l := _nova_linha(cor, passada)
		l.points = caminho_giz(pts, difs[passada][0], difs[passada][1])
		pai.add_child(l)


func caminho_giz(pts: Array, sem: int, amp: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	var n := 0
	var i := 0
	while i < pts.size():
		if i == 0:
			o.append(Vector2(pts[0], pts[1]))
			i += 2
			continue
		var ax: float = pts[i - 2]
		var ay: float = pts[i - 1]
		var bx: float = pts[i]
		var by: float = pts[i + 1]
		var dx := bx - ax
		var dy := by - ay
		var l := Vector2(dx, dy).length()
		if l == 0.0:
			l = 1.0
		var q := maxi(1, int(round(l / 7.0)))
		for k in range(1, q + 1):
			var f := float(k) / float(q)
			var jj := 0.0
			if k != q:
				jj = (fmod(sin(float(n + sem) * 12.9898) * 43758.5453, 1.0) - 0.5) * 2.0 * amp
				n += 1
			o.append(Vector2(ax + dx * f - dy / l * jj, ay + dy * f + dx / l * jj))
		i += 2
	return o


## O traço que tá sendo riscado no editor.
func giz_vivo(pts: Array, cor: int) -> void:
	var difs := [[999, 0.8], [1002, 0.55], [1008, 0.7]]
	for passada in 3:
		var l: Line2D = linhas_vivas[passada]
		if pts.size() < 2:
			l.points = PackedVector2Array()
			continue
		_acerta_linha(l, cor, passada)
		var p := pts if pts.size() >= 4 else [pts[0], pts[1], pts[0] + 0.01, pts[1]]
		l.points = caminho_giz(p, difs[passada][0], difs[passada][1])


# ---------------------------------------------------------------- o fundo: asfalto, sujeira, faixas, tábua
func _faixa_y() -> Vector2:
	var y1 := maxf((cena_F.y_fundo if cena_F != null else 650.0) + 1500.0, float(Nucleo.ALT_MAX) + 500.0)
	return Vector2(-300.0, y1)


func _desenha_fundo() -> void:
	var fy := _faixa_y()
	# o asfalto, com o grão do tamanho de um ponto de tela
	fundo.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / K, 1.0 / K))
	fundo.draw_texture_rect(Texturas.asfalto, Rect2(0, fy.x * K, LARG * K, (fy.y - fy.x) * K), true)
	fundo.draw_set_transform_matrix(Transform2D.IDENTITY)
	if cena_F == null:
		return
	var p := pc_fundo
	p.comeca()
	var t0 := int(floor(fy.x / TH)) - 1
	var t1 := int(floor(fy.y / TH)) + 1
	for t in range(t0, t1 + 1):
		_decora(p, t)
	for t in range(t0, t1 + 1):
		_faixas(p, t)
	_tabua(p)
	p.fecha()


func _cor_giz_a(i: int, a: float) -> Color:
	var c: Color = Estilo.CORES_GIZ[i]
	return Color(c.r, c.g, c.b, a)


## A sujeira do asfalto: rachadura, mancha de óleo, faixa velha apagada, bueiro, giz velho e flor seca de ipê.
func _decora(p: Lote, t: int) -> void:
	var r := Fases.Sorteio.new(t * 7919 + cena_sem * 31 + 11)
	var y0 := float(t) * TH
	if r.r() < 0.5:
		var px := 20.0 + r.r() * 380.0
		var py := y0 + r.r() * TH
		var pts := PackedVector2Array([Vector2(px, py)])
		for k in 9:
			px += (r.r() - 0.5) * 26.0
			py += 4.0 + r.r() * 14.0
			pts.append(Vector2(px, py))
		p.linha(pts, Color(8.0 / 255, 8.0 / 255, 10.0 / 255, 0.7), 1.6, false)
		p.linha(pts, Color(1, 1, 1, 0.04), 1.0, false)
	if r.r() < 0.3:
		var px := 40.0 + r.r() * 340.0
		var py := y0 + r.r() * TH
		var raio := 26.0 + r.r() * 20.0
		var rot := r.r() * 3.0
		var w := minf(44.0, raio)
		var h := minf(26.0, raio)
		p.save(); p.translate(px, py); p.rotate(rot)
		p.textura(Texturas.mancha, Rect2(-w, -h, w * 2.0, h * 2.0))
		p.restore()
	if r.r() < 0.4:
		var px := 150.0 + r.r() * 120.0
		var py := y0 + r.r() * TH
		var a := 0.05 + r.r() * 0.06
		var rot := (r.r() - 0.5) * 0.3
		var h := 50.0 + r.r() * 40.0
		p.save(); p.translate(px, py); p.rotate(rot)
		p.retangulo(-4, 0, 8, h, Color(1.0, 201.0 / 255, 60.0 / 255, a))
		p.restore()
	if r.r() < 0.07:
		var px := 60.0 + r.r() * 300.0
		var py := y0 + r.r() * TH
		p.circulo(px, py, 17.0, Color("#121116"))
		p.contorno_elipse(px, py, 17.0, 17.0, 0.0, Color(1, 1, 1, 0.1), 1.4)
		var k := -14.0
		while k <= 14.0:
			var meia := sqrt(maxf(0.0, 14.0 * 14.0 - k * k))
			p.seg(px - meia, py + k, px + meia, py + k, Color(1, 1, 1, 0.07), 1.4, false)
			k += 4.0
	if r.r() < 0.18:
		# giz velho de outra brincadeira, quase apagado
		var px := 70.0 + r.r() * 280.0
		var py := y0 + 30.0 + r.r() * (TH - 60.0)
		var tipo := int(r.r() * 4.0)
		var ci := int(r.r() * 4.0)
		var rot := (r.r() - 0.5) * 0.5
		var c := _cor_giz_a(ci, 0.1)
		p.save(); p.translate(px, py); p.rotate(rot)
		if tipo == 0:
			for kk in 3:
				p.contorno_ret(-14, -40 + kk * 26, 28, 26, c, 3.0)
			p.contorno_ret(-28, 38, 28, 26, c, 3.0)
			p.contorno_ret(0, 38, 28, 26, c, 3.0)
		elif tipo == 1:
			var a1 := Pincel.bezier(0, 12, -26, -6, -12, -26, 0, -12)
			var a2 := Pincel.bezier(0, -12, 12, -26, 26, -6, 0, 12)
			a1.append_array(a2)
			p.linha(a1, c, 3.0)
		elif tipo == 2:
			var palavras := ["VALEU", "ZÉ", "BIA", "DUVIDO", "FUI"]
			p.texto(-30, 8, palavras[int(r.r() * 5.0)], Estilo.giz, 28.0, c)
		else:
			p.seg(-12, -12, 12, 12, c, 3.0)
			p.seg(12, -12, -12, 12, c, 3.0)
		p.restore()
	var nf := 0 if r.r() < 0.5 else 1 + int(r.r() * 3.0)
	for k in nf:
		var px := 10.0 + r.r() * 400.0
		var py := y0 + r.r() * TH
		var rosa := r.r() < 0.4
		var rot := r.r() * 3.0
		p.elipse(px, py, 2.6, 1.6, rot, Color(232.0 / 255, 110.0 / 255, 170.0 / 255, 0.45) if rosa else Color(240.0 / 255, 190.0 / 255, 50.0 / 255, 0.42))


## As faixas amarelas da beira (o barranco tá logo depois).
func _faixas(p: Lote, t: int) -> void:
	var y0 := float(t) * TH
	var r := Fases.Sorteio.new(t * 13 + 5)
	for bx in [4.0, LARG - 4.0]:
		var y := y0
		while y < y0 + TH:
			var a := 0.1 if r.r() < 0.08 else 0.55 + r.r() * 0.3
			p.poligono(PackedVector2Array([Vector2(bx - 1.8, y), Vector2(bx + 1.8, y), Vector2(bx + 1.8, y + 8.5), Vector2(bx - 1.8, y + 8.5)]), Color(1.0, 201.0 / 255, 60.0 / 255, a), false)
			y += 8.0


## A tábua da largada: madeira de verdade em cima de dois tijolos.
func _tabua(p: Lote) -> void:
	var L: Array = Nucleo.LARGADA
	var ax: float = L[2]
	var ay: float = L[3]
	var bx: float = L[4]
	var by: float = L[5]
	var l := Vector2(bx - ax, by - ay).length()
	var ang := atan2(by - ay, bx - ax)
	for k in 3:
		var x := 2.0 + float(k % 2) * 6.0
		var y := ay + 4.0 + float(k) * 9.0
		p.retangulo(x, y, 22, 9, Color("#9C3F2A"))
		p.contorno_ret(x, y, 22, 9, Color("#4A1C12"), 1.2)
	p.save(); p.translate(ax, ay); p.rotate(ang)
	p.retangulo(2, 4, l, 9, Color(0, 0, 0, 0.35))
	p.retangulo(0, -1, l + 4.0, 9, Color("#B9733A"))
	p.contorno_ret(0, -1, l + 4.0, 9, Color("#5A3218"), 1.6)
	for k in 3:
		p.linha(Pincel.bezier(6, 1.5 + k * 2.5, l * 0.3, k * 2.5 + 3.0, l * 0.6, k * 2.5, l, 2.0 + k * 2.4), Color(90.0 / 255, 50.0 / 255, 24.0 / 255, 0.55), 1.0, false)
	p.retangulo(0, -1.5, l + 4.0, 1.8, Color("#E8D9B0"))
	p.circulo(14, 3.5, 1.3, Color("#2A2830"))
	p.circulo(l - 10.0, 3.5, 1.3, Color("#2A2830"))
	p.restore()
	# o batente de trás
	p.retangulo(L[0] - 2.0, L[1], 5, L[3] - L[1] + 2.0, Color("#8E552A"))
	p.contorno_ret(L[0] - 2.0, L[1], 5, L[3] - L[1] + 2.0, Color("#4A2A14"), 1.2)
	# LARGADA escrito a giz embaixo da tábua (em cima fica o relógio)
	p.save(); p.translate(38, 146); p.rotate(ang)
	p.texto(0, 0, "LARGADA", Estilo.giz, 17.0, Color(243.0 / 255, 238.0 / 255, 226.0 / 255, 0.8))
	p.restore()


# ---------------------------------------------------------------- o fora da coluna (no computador)
static func hash_i(n: int) -> int:
	n = Codigo.imul(n ^ 0x9E3779B9, 0x85EBCA6B)
	n ^= (n & 0xFFFFFFFF) >> 13
	n = Codigo.imul(n, 0xC2B2AE35)
	return (n ^ ((n & 0xFFFFFFFF) >> 16)) & 0xFFFFFFFF


func _desenha_fora_fixo() -> void:
	if not largo:
		return
	fora_fixo.draw_rect(Rect2(0, 0, COLX, SH), Estilo.FORA, true)
	fora_fixo.draw_rect(Rect2(COLX + COLW, 0, SW - COLX - COLW, SH), Estilo.FORA, true)
	for lado in [[COLX, -1.0], [COLX + COLW, 1.0]]:
		var x0: float = lado[0]
		var dir: float = lado[1]
		# a terra roxa que aparece embaixo do asfalto, sumindo no escuro
		var w: float = 120.0 * j.P
		var n := 24
		for i in n:
			var f0 := float(i) / n
			var c := Color(74.0 / 255, 32.0 / 255, 24.0 / 255, 0.5).lerp(Color(46.0 / 255, 20.0 / 255, 18.0 / 255, 0.28), clampf(f0 / 0.35, 0, 1)) if f0 < 0.35 else Color(46.0 / 255, 20.0 / 255, 18.0 / 255, 0.28).lerp(Color(20.0 / 255, 10.0 / 255, 10.0 / 255, 0.0), (f0 - 0.35) / 0.65)
			var xa: float = x0 + dir * w * f0
			var xb: float = x0 + dir * w * (f0 + 1.0 / n)
			fora_fixo.draw_rect(Rect2(minf(xa, xb), 0, absf(xb - xa) + 0.5, SH), c, true)


func _desenha_fora() -> void:
	if not largo:
		return
	var P: float = j.P
	var fy := _faixa_y()
	pc_fora.comeca()
	for lado in [[COLX, -1.0], [COLX + COLW, 1.0]]:
		var x0: float = lado[0]
		var dir: float = lado[1]
		# os pedaços de asfalto quebrado e as pedrinhas, presos no mundo (andam junto com a ladeira)
		var passo := 16.0
		var y := floorf(fy.x / passo) * passo
		while y < fy.y:
			var h := hash_i(int(y) * 3 + (7 if dir > 0 else 0))
			var sy := y * K
			var w1 := (3.0 + h % 11) * P
			var w2 := (2.0 + (h >> 5) % 9) * P
			var alt := passo * K * (0.75 + float((h >> 9) % 6) / 10.0)
			var tom := 26 + (h >> 12) % 12
			pc_fora.poligono(PackedVector2Array([Vector2(x0, sy), Vector2(x0 + dir * w1, sy + alt * 0.2), Vector2(x0 + dir * w2, sy + alt * 0.8), Vector2(x0, sy + alt)]), Color8(tom + 2, tom, tom + 5))
			if h % 5 == 0:
				var px := x0 + dir * (18.0 + (h >> 3) % 70) * P
				var r := (1.5 + (h >> 7) % 4) * P
				pc_fora.elipse(px, sy + 6.0 * P, r * 1.4, r, float(h % 7) / 3.0, Color8(60 + (h >> 4) % 30, 34 + (h >> 6) % 16, 30, 128))
			if h % 11 == 0:
				var px := x0 + dir * (10.0 + (h >> 4) % 40) * P
				for k in 4:
					var dx := float(k % 2) * 3.0 - float(1 - k % 2) * 2.0
					pc_fora.seg(px + k * 2 * dir * P, sy + 10.0 * P, px + (k * 2 + dx) * dir * P, sy + (2.0 - float((h >> k) % 4)) * P, Color(176.0 / 255, 138.0 / 255, 72.0 / 255, 0.35), 1.0, false)
			y += passo
		# a sombra da beirada
		var n := 8
		for i in n:
			var f0 := float(i) / n
			var xa := x0 + dir * 26.0 * P * f0
			var xb := x0 + dir * 26.0 * P * (f0 + 1.0 / n)
			pc_fora.poligono(PackedVector2Array([Vector2(minf(xa, xb), fy.x * K), Vector2(maxf(xa, xb) + 0.5, fy.x * K), Vector2(maxf(xa, xb) + 0.5, fy.y * K), Vector2(minf(xa, xb), fy.y * K)]), Color(0, 0, 0, 0.55 * (1.0 - f0)), false)
	pc_fora.fecha()


# ---------------------------------------------------------------- o que mexe, a cada quadro
func _desenha_vivo() -> void:
	if cena_F == null:
		return
	var tp := Time.get_ticks_usec()
	_desenha_vivo2()
	j._mede_perf("vivo", tp)


func _desenha_vivo2() -> void:
	var F := cena_F
	pc.comeca()
	var JG = j.jogo
	var DM = j.demo
	var S: Nucleo.Estado = JG.S if JG != null else (DM.S if DM != null else null)
	var n: int = S.passos if S != null else int(floor(j.tempo * 120.0))
	var T: float = j.tempo
	for i in F.molas.size():
		var comp := 0.0
		if JG != null and i < JG.mola_t.size() and JG.mola_t[i] > 0.0:
			comp = sin(JG.mola_t[i] / 0.32 * PI)
		_mola(F.molas[i], comp)
	for tb in F.turbos:
		_turbo(tb, T)
	for i in F.caes.size():
		var q := Nucleo.pos_cao(F, F.caes[i], n)
		var bravo: bool = JG != null and T - (JG.latiu[i] if i < JG.latiu.size() else -9.0) < 0.6
		_cao(q[0], q[1], q[2], T, bravo, i * 1.7)
	if F.tem_chegada:
		_bandeira(F.chegada_x, F.chegada_y, T)
	_poeira()
	if j.tela == "editor":
		_extras_editor()
		if j.parado == null or j.parado_F != F:
			j.parado = Nucleo.novo_estado(F)
			j.parado_F = F
		desenha_carro(j.parado.p, 1.0, 0.0, 0, j.cor_de(j.nome), 0.9)
	if JG != null:
		if JG.G != null and JG.g_alfa > 0.02:
			var pg := interp(JG.G, 1.0 if JG.G.fim != "" else j.alfa)
			var gx := (pg[0] + pg[2]) / 2.0
			var gy := (pg[1] + pg[3]) / 2.0
			var sx: float = (JG.S.p[0] + JG.S.p[2]) / 2.0
			var sy: float = (JG.S.p[1] + JG.S.p[3]) / 2.0
			var longe := Vector2(gx - sx, gy - sy).length()
			desenha_carro(pg, JG.g_vis.lado, JG.g_vis.giro, JG.g_vis.pose, j.cor_de(JG.g_nome), JG.g_alfa * clampf(longe / 26.0, 0.25, 1.0))
			if longe > 34.0 or JG.S.fim != "":
				_etiqueta(pg, JG.g_nome, JG.g_alfa)
		if not (JG.S.fim in ["capotou", "torto", "cachorro"]):
			desenha_carro(interp(JG.S, j.alfa), JG.vis.lado, JG.vis.giro, JG.vis.pose, j.cor_de(j.nome), 1.0)
	elif DM != null:
		desenha_carro(interp(DM.S, 1.0 if DM.S.fim != "" else j.acc / Nucleo.PASSO), DM.vis.lado, DM.vis.giro, DM.vis.pose, DM.cam, 1.0)
	_particulas()
	pc.fecha()


func interp(S: Nucleo.Estado, a: float) -> PackedFloat64Array:
	var o := PackedFloat64Array()
	o.resize(4)
	for i in 4:
		o[i] = S.pa[i] + (S.p[i] - S.pa[i]) * a
	return o


func _ret_redondo(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	r = minf(r, minf(w, h) * 0.5)
	var cs := [[x + w - r, y + r, -PI * 0.5], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI * 0.5], [x + r, y + r, PI]]
	for c in cs:
		for k in 5:
			var a: float = c[2] + PI * 0.5 * float(k) / 4.0
			o.append(Vector2(c[0] + cos(a) * r, c[1] + sin(a) * r))
	return o


func _mola(m: Array, comp: float) -> void:
	var p := pc
	p.save(); p.translate(m[0], m[1])
	p.poligono(_ret_redondo(-15, 1, 30, 19, 4), Color("#0B0A0E"))
	var h := 15.0 * (1.0 - comp * 0.55)
	var z := PackedVector2Array([Vector2(-9, 2.5)])
	for k in range(1, 7):
		z.append(Vector2(9.0 if k % 2 == 1 else -9.0, 2.5 + h * k / 6.0))
	p.linha(z, Color("#C9CCD6"), 2.1)
	p.retangulo(-12, 2.5 + h, 24, 3, Color("#3B3A44"))
	var tampa := _ret_redondo(-Nucleo.MOLA_L - 1.0, -4.0 + comp * 4.0, Nucleo.MOLA_L * 2.0 + 2.0, 6, 3)
	p.poligono(tampa, Color("#FF4F9A"))
	var fecha := tampa.duplicate()
	fecha.append(tampa[0])
	p.linha(fecha, Color("#7A1C44"), 1.2, false)
	p.retangulo(-Nucleo.MOLA_L + 3.0, -3.0 + comp * 4.0, Nucleo.MOLA_L * 2.0 - 8.0, 1.4, Color(1, 1, 1, 0.45))
	p.restore()


func _turbo(tb: Nucleo.Turbo, t: float) -> void:
	var p := pc
	p.save(); p.translate(tb.x, tb.y); p.rotate(atan2(tb.dy, tb.dx))
	var pulsa := 0.5 + 0.5 * sin(t * 6.0)
	var c := Color(1.0, 201.0 / 255, 60.0 / 255, 0.25 + pulsa * 0.2)
	# o círculo tracejado
	var r := Nucleo.TURBO_R - 2.0
	var vol := TAU * r
	var a := 0.0
	while a < vol:
		var a0 := a / r
		var a1 := minf(a + 4.0, vol) / r
		p.arco(0, 0, r, a0, a1, c, 2.0)
		a += 9.0
	for k in 3:
		var o := fmod(t * 22.0, 12.0)
		var xx := -14.0 + k * 11.0 + o * 0.5
		var al := 0.45 + k * 0.25
		p.linha(PackedVector2Array([Vector2(xx - 5, -8), Vector2(xx + 3, 0), Vector2(xx - 5, 8)]), Color(1.0, (150.0 + k * 30.0) / 255, (40.0 + k * 10.0) / 255, minf(1.0, al)), 5.0)
	p.restore()


## O vira-lata caramelo.
func _cao(px: float, py: float, dir: float, t: float, bravo: bool, fase: float) -> void:
	var p := pc
	p.save(); p.translate(px, py + Nucleo.CAO_R + 1.0); p.scale(dir, 1)
	var anda := sin(t * 13.0 + fase)
	var rabo := sin(t * 18.0 + fase) * 0.5
	for lg in [[-8.0, anda], [-4.0, -anda], [6.0, -anda], [10.0, anda]]:
		p.seg(lg[0], -9, lg[0] + lg[1] * 3.0, -0.5, Color("#7A4416"), 2.6)
	p.save(); p.translate(-12, -14); p.rotate(-0.9 + rabo)
	p.linha(Pincel.quad(0, 0, -6, -4, -5, -10, 8), Color("#C8752E"), 3.2)
	p.restore()
	p.elipse(0, -13, 13, 6.6, 0, Color("#D0833A"))
	p.elipse(1, -10.5, 8, 3, 0, Color("#EDB677"))
	p.elipse(13, -19, 6.6, 6, 0, Color("#D0833A"))
	p.elipse(18.5, -17, 4.2, 3, 0, Color("#EDB677"))
	p.circulo(22.3, -18, 1.6, Color("#1B1416"))
	p.circulo(14.5, -21, 1.15, Color("#1B1416"))
	p.elipse(9.5, -21, 2.8, 5.2, 0.5 + (-0.5 if bravo else 0.0), Color("#9A5520"))
	if bravo:
		p.seg(17, -14.5, 22, -15.5, Color("#1B1416"), 1.4)
	p.restore()


func _chegada_chao(cx: float, cy: float) -> void:
	var p := pc
	p.save(); p.translate(cx, cy)
	for i in range(-5, 5):
		for k in 2:
			p.retangulo(i * 4.4, 3.0 + k * 4.4, 4.4, 4.4, Color(243.0 / 255, 238.0 / 255, 226.0 / 255, 0.85) if posmod(i + k, 2) == 1 else Color(20.0 / 255, 20.0 / 255, 24.0 / 255, 0.9))
	var tw := p.largura_texto("CHEGADA", Estilo.giz, 15.0)
	p.texto(-tw / 2.0, 28, "CHEGADA", Estilo.giz, 15.0, Color(243.0 / 255, 238.0 / 255, 226.0 / 255, 0.86))
	p.restore()


func _bandeira(cx: float, cy: float, t: float) -> void:
	_chegada_chao(cx, cy)
	var p := pc
	p.save(); p.translate(cx, cy)
	p.seg(-16, 1, -16, -94, Color("#B7B9C2"), 2.6, false)
	p.circulo(-16, -95, 2.8, Color("#FFC93C"))
	var W := 36.0
	var H := 22.0
	var nx := 6
	var ny := 4
	for i in nx:
		for k in ny:
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var o0 := sin(t * 5.0 - u0 * 4.0) * u0 * 4.0
			var o1 := sin(t * 5.0 - u1 * 4.0) * u1 * 4.0
			var c := Color("#F3EEE2") if (i + k) % 2 == 1 else Color("#141218")
			var y0 := -92.0 + k * H / ny
			var y1 := -92.0 + (k + 1) * H / ny
			p.poligono(PackedVector2Array([Vector2(-16 + u0 * W, y0 + o0), Vector2(-16 + u1 * W, y0 + o1), Vector2(-16 + u1 * W, y1 + o1), Vector2(-16 + u0 * W, y1 + o0)]), c, false)
	p.restore()


# ---------------------------------------------------------------- o carrinho de rolimã e o piloto de balde
func _rolima(cx: float, giro: float) -> void:
	var p := pc
	p.circulo(cx, 0, RODA, Color("#AEB2BD"))
	p.contorno_elipse(cx, 0, RODA, RODA, 0, Color("#4A4D57"), 1.3)
	p.circulo(cx, 0, 3.7, Color("#5E616C"))
	for k in 7:
		var a := giro + k * 0.8976
		p.circulo(cx + cos(a) * 5.05, sin(a) * 5.05, 1.05, Color("#E2E4EA"))
	p.circulo(cx, 0, 1.5, Color("#17161B"))
	p.arco(cx, 0, RODA - 1.2, 3.6, 4.6, Color(1, 1, 1, 0.55), 1.0)


## pose: 0 sentado, 1 encolhido (cambalhota), 2 braço pra cima (voando)
func desenha_carro(q: PackedFloat64Array, lado: float, giro: float, pose: int, cam: int, alpha: float) -> void:
	var p := pc
	var mx := (q[0] + q[2]) / 2.0
	var my := (q[1] + q[3]) / 2.0
	var ang := atan2(q[3] - q[1], q[2] - q[0])
	p.save()
	p.alpha = alpha
	p.translate(mx, my); p.rotate(ang); p.scale(lado, 1)
	p.elipse(0, 7, 22, 2.5, 0, Color(0, 0, 0, 0.25))
	p.retangulo(-17.5, -7, 5, 7, Color("#5A3218"))
	p.retangulo(12.5, -7, 5, 7, Color("#5A3218"))
	_rolima(-15, giro)
	_rolima(15, giro)
	var tabua := PackedVector2Array([Vector2(-23, -11.5), Vector2(21, -11.5), Vector2(24, -9), Vector2(21, -6.5), Vector2(-23, -6.5)])
	p.poligono(tabua, Color("#C27D3E"), false)
	var tf := tabua.duplicate()
	tf.append(tabua[0])
	p.linha(tf, Color("#5A3218"), 1.4, false)
	p.seg(-20, -9.5, 18, -9.2, Color(90.0 / 255, 50.0 / 255, 24.0 / 255, 0.5), 0.8, false)
	p.texto(-19.5, -7.5, "7", Estilo.t700, 5.0, Color("#F3EEE2"))
	# o piloto
	var camisa: Color = CAMISAS[cam % CAMISAS.size()]
	var enc := pose == 1
	var hip := Vector2(-5, -12.5)
	var ombro := Vector2(0, -18) if enc else Vector2(-2.5, -20.5)
	var cab := Vector2(3.5, -22.5) if enc else Vector2(0, -25.5)
	var joelho := Vector2(5, -21) if enc else Vector2(6, -18.5)
	var pe := Vector2(5.5, -13) if enc else Vector2(14, -12.5)
	p.linha(PackedVector2Array([hip, joelho, pe]), Color("#2E4A7A"), 4.4)
	p.elipse(pe.x + 1.5, pe.y + 0.8, 3.2, 1.9, 0, Color("#F3EEE2"))
	p.linha(PackedVector2Array([Vector2(hip.x, hip.y - 1.0), ombro]), camisa, 6.2)
	# a corda da direção e o braço
	var mao := Vector2(-1, -31) if pose == 2 else (Vector2(6, -15) if enc else Vector2(9, -16))
	if pose != 2:
		p.linha(Pincel.quad(mao.x, mao.y, 15, -13, 19, -9, 8), Color("#D9C8A0"), 0.9, false)
	p.linha(PackedVector2Array([Vector2(ombro.x, ombro.y + 1.0), Vector2(4, -17) if enc else Vector2(3.5, -18), mao]), camisa, 3.0)
	p.circulo(mao.x, mao.y, 1.6, Color("#8A5A35"))
	# a cabeça e o balde
	p.circulo(cab.x, cab.y, 4.6, Color("#8A5A35"))
	p.circulo(cab.x + 2.4, cab.y - 0.3, 0.95, Color("#1B1416"))
	p.arco(cab.x + 2.0, cab.y + 1.2, 1.6, 0.2, 1.6, Color("#1B1416"), 0.9)
	p.save(); p.translate(cab.x - 0.5, cab.y - 2.2); p.rotate(-0.12)
	var balde := PackedVector2Array([Vector2(-6.4, 0), Vector2(6.4, 0), Vector2(4.6, -8.4), Vector2(-4.6, -8.4)])
	p.poligono(balde, Color("#E8402A"), false)
	var bf := balde.duplicate()
	bf.append(balde[0])
	p.linha(bf, Color("#7A1A10"), 1.1, false)
	p.retangulo(-5.8, -3.6, 11.6, 1.6, Color("#F3EEE2"))
	p.linha(Pincel.quad(-5.6, -0.5, -1, 7, 5.6, -0.5, 8), Color("#C9CCD6"), 0.9, false)
	p.restore()
	p.restore()


## Os pedaços quando capota: a tábua, o piloto e o balde voando cada um pra um lado.
func _pedaco(d: Dictionary) -> void:
	var p := pc
	p.save()
	p.alpha = minf(1.0, d["vida"])
	p.translate(d["x"], d["y"]); p.rotate(d["a"])
	var k: String = d["k"]
	if k == "balde":
		var b := PackedVector2Array([Vector2(-6.4, 4), Vector2(6.4, 4), Vector2(4.6, -4.4), Vector2(-4.6, -4.4)])
		p.poligono(b, Color("#E8402A"), false)
		var bf := b.duplicate()
		bf.append(b[0])
		p.linha(bf, Color("#7A1A10"), 1.1, false)
		p.retangulo(-5.8, 0.4, 11.6, 1.6, Color("#F3EEE2"))
	elif k == "piloto":
		p.linha(PackedVector2Array([Vector2(0, 3), Vector2(7, 7), Vector2(10, 12)]), Color("#2E4A7A"), 4.2)
		var cam: Color = CAMISAS[int(d.get("cam", 0)) % CAMISAS.size()]
		p.seg(0, 3, -2, -5, cam, 6.0)
		p.seg(-2, -4, -8, -9, cam, 3.0)
		p.seg(-1, -4, 5, -10, cam, 3.0)
		p.circulo(-3, -10, 4.6, Color("#8A5A35"))
	else:
		p.retangulo(-23, -3, 46, 5, Color("#C27D3E"))
		p.contorno_ret(-23, -3, 46, 5, Color("#5A3218"), 1.4)
		p.translate(0, 6)
		_rolima(-15, d["a"] * 3.0)
		_rolima(15, d["a"] * 3.0)
	p.restore()


func _etiqueta(q: PackedFloat64Array, txt: String, al: float) -> void:
	var p := pc
	var mx := (q[0] + q[2]) / 2.0
	var my := minf(q[1], q[3]) - 46.0
	p.save()
	p.alpha = minf(1.0, al * 2.0)
	var w := p.largura_texto(txt, Estilo.t700, 11.0) + 10.0
	p.retangulo(mx - w / 2.0, my - 11.0, w, 15, Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.8))
	p.texto(mx, my, txt, Estilo.t700, 11.0, Color("#F3EEE2"), 0)
	p.restore()


func _extras_editor() -> void:
	var p := pc
	var ED = j.ed
	var T: float = j.tempo
	# de onde começa: a seta de giz saindo da ponta da tábua
	if ED.tracos.is_empty():
		var a := 0.55 + 0.35 * sin(T * 4.0)
		var c := Color(1.0, 201.0 / 255, 60.0 / 255, a)
		var curva := Pincel.quad(134, 158, 190, 176, 220, 218, 16)
		_tracejado(curva, c, 3.0, 6.0, 6.0)
		p.linha(PackedVector2Array([Vector2(212, 214), Vector2(221, 220), Vector2(224, 209)]), c, 3.0)
		p.texto(196, 248, "continua daqui", Estilo.giz, 17.0, c)
	# o fim do asfalto
	var alt := float(Nucleo.ALT_MAX)
	if j.cam_y + VH > alt - 20.0:
		_tracejado(PackedVector2Array([Vector2(0, alt), Vector2(LARG, alt)]), Color(232.0 / 255, 64.0 / 255, 42.0 / 255, 0.6), 2.0, 10.0, 8.0)
		p.texto(120, alt + 22.0, "daqui pra baixo não dá", Estilo.giz, 15.0, Color(232.0 / 255, 64.0 / 255, 42.0 / 255, 0.8))
	if ED.cursor != null and ED.ferr == "borracha" and not j.dedo_tela:
		var r := maxf(9.0, 16.0 / K * j.P)
		p.contorno_elipse(ED.cursor.x, ED.cursor.y, r, r, 0, Color(243.0 / 255, 238.0 / 255, 226.0 / 255, 0.6), 1.5)
	if ED.gesto != null and ED.gesto["k"] == "mira":
		var i: int = ED.gesto["i"]
		if i < ED.carimbos.size():
			var cb: Dictionary = ED.carimbos[i]
			var d: Array = Nucleo.DIRS[int(cb.get("dir", 0)) & 15]
			_tracejado(PackedVector2Array([Vector2(cb["x"], cb["y"]), Vector2(cb["x"] + d[0] * 60.0, cb["y"] + d[1] * 60.0)]), Color(1.0, 201.0 / 255, 60.0 / 255, 0.8), 2.0, 4.0, 4.0)


func _tracejado(pts: PackedVector2Array, c: Color, w: float, liga: float, desliga: float) -> void:
	var resto := 0.0
	var ligado := true
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		var pos := 0.0
		while pos < l:
			var falta := (liga if ligado else desliga) - resto
			var fim := minf(l, pos + falta)
			if ligado:
				var u := a.lerp(b, pos / l)
				var v := a.lerp(b, fim / l)
				pc.seg(u.x, u.y, v.x, v.y, c, w, false)
			resto += fim - pos
			if resto >= (liga if ligado else desliga) - 0.0001:
				resto = 0.0
				ligado = not ligado
			pos = fim


# ---------------------------------------------------------------- as partículas: poeira de giz, confete, os textos que sobem
func poeira(px: float, py: float, n: int, forca: float, cor := Color(243.0 / 255, 238.0 / 255, 226.0 / 255)) -> void:
	for i in n:
		var a := -PI / 2.0 + (randf() - 0.5) * 2.4
		parts.append({"k": "p", "x": px + (randf() - 0.5) * 10.0, "y": py, "vx": cos(a) * forca * (0.4 + randf()), "vy": sin(a) * forca * (0.3 + randf() * 0.7), "r": 1.2 + randf() * 2.4, "vida": 0.5 + randf() * 0.5, "c": cor})


func confete(px: float, py: float, n: int) -> void:
	for i in n:
		var a := -PI / 2.0 + (randf() - 0.5) * 2.2
		var v := 180.0 + randf() * 380.0
		parts.append({"k": "c", "x": px, "y": py, "vx": cos(a) * v, "vy": sin(a) * v, "a": randf() * 6.0, "va": (randf() - 0.5) * 18.0, "w": 3.0 + randf() * 3.0, "h": 5.0 + randf() * 4.0, "c": CORES_CONFETE[i % CORES_CONFETE.size()], "vida": 2.2 + randf() * 1.2})


func texto_sobe(px: float, py: float, txt: String, cor := Color("#FFC93C")) -> void:
	parts.append({"k": "t", "x": px, "y": py, "vy": -60.0, "txt": txt, "c": cor, "vida": 1.3})


func passo_particulas(dt: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var q: Dictionary = parts[i]
		q["vida"] -= dt
		if q["vida"] <= 0.0:
			parts.remove_at(i)
			i -= 1
			continue
		var k: String = q["k"]
		if k == "p":
			q["x"] += q["vx"] * dt; q["y"] += q["vy"] * dt; q["vy"] += 160.0 * dt; q["vx"] *= 1.0 - dt * 3.0
		elif k == "c":
			q["x"] += q["vx"] * dt; q["y"] += q["vy"] * dt; q["vy"] += 520.0 * dt; q["vx"] *= 1.0 - dt * 1.6; q["vy"] *= 1.0 - dt * 1.2; q["a"] += q["va"] * dt
			q["x"] += sin(q["vida"] * 9.0 + q["a"]) * 20.0 * dt
		elif k == "t":
			q["y"] += q["vy"] * dt; q["vy"] *= 1.0 - dt * 2.0
		i -= 1
	if parts.size() > 500:
		parts = parts.slice(parts.size() - 500)
	for d in pedacos:
		d["vy"] += Nucleo.G * dt; d["x"] += d["vx"] * dt; d["y"] += d["vy"] * dt; d["a"] += d["va"] * dt; d["vida"] -= dt * 0.25
		if cena_F != null and d["y"] < cena_F.y_fundo + 400.0:
			var P := PackedFloat64Array([d["x"], d["y"]])
			if Nucleo.empurra(cena_F, P, 0, d["r"]):
				var nx := cena_F.cn[0]
				var ny := cena_F.cn[1]
				var vn: float = d["vx"] * nx + d["vy"] * ny
				if vn < 0.0:
					d["vx"] -= nx * vn * 1.4; d["vy"] -= ny * vn * 1.4; d["vx"] *= 0.82; d["vy"] *= 0.82; d["va"] *= 0.7
				d["x"] = P[0]; d["y"] = P[1]


func _poeira() -> void:
	for q in parts:
		if q["k"] == "p":
			var c: Color = q["c"]
			pc.circulo(q["x"], q["y"], q["r"], Color(c.r, c.g, c.b, minf(0.6, q["vida"])))


func _particulas() -> void:
	var p := pc
	for q in parts:
		if q["k"] == "c":
			p.save(); p.translate(q["x"], q["y"]); p.rotate(q["a"])
			p.alpha = minf(1.0, q["vida"])
			var h: float = q["h"] * absf(cos(q["a"] * 1.7))
			p.retangulo(-q["w"] / 2.0, -q["h"] / 2.0, q["w"], h, q["c"])
			p.restore()
	for q in parts:
		if q["k"] != "t":
			continue
		p.save()
		p.alpha = minf(1.0, q["vida"] * 1.5)
		p.texto(q["x"], q["y"], q["txt"], Estilo.tit, 15.0, q["c"], 0, 4.0, Color(0, 0, 0, 0.8))
		p.restore()
	for d in pedacos:
		_pedaco(d)


# ---------------------------------------------------------------- a tira da direita: a ladeira inteira e o que tá aparecendo
func altura_tira() -> float:
	if cena_F == null:
		return VH
	if j.tela == "editor":
		return maxf(VH * 1.4, j.limite_editor() + VH + 40.0)
	return maxf(VH, y_max + 220.0)


func _desenha_tira_base() -> void:
	var W := TIRAW
	var H := SH
	tira.draw_rect(Rect2(0, 0, W, H), Color("#100F14"), true)
	if cena_F == null:
		return
	var P: float = j.P
	tira.draw_rect(Rect2(0, 0, 1.5 * P, H), Color(1.0, 201.0 / 255, 60.0 / 255, 0.5), true)
	tira.draw_rect(Rect2(W - 1.5 * P, 0, 1.5 * P, H), Color(1.0, 201.0 / 255, 60.0 / 255, 0.5), true)
	var alt := altura_tira()
	var topo := -40.0
	var s := H / alt
	var sx := W / LARG
	for t in cena_tracos:
		var c: Color = Estilo.CORES_GIZ[t["cor"]] if t["cor"] < 4 else Estilo.CORES_GIZ[0]
		var pts: Array = t["pts"]
		var o := PackedVector2Array()
		var i := 0
		while i < pts.size():
			o.append(Vector2(pts[i] * sx, (pts[i + 1] - topo) * s))
			i += 2
		if o.size() >= 2:
			tira.draw_polyline(o, Color(c.r, c.g, c.b, 0.9), maxf(1.2 * P, 1.0), true)
	if cena_F.tem_chegada:
		var x := cena_F.chegada_x * sx
		var y := (cena_F.chegada_y - topo) * s
		var u := 3.0 * P
		tira.draw_rect(Rect2(x - u, y - 2.0 * u, 2.0 * u, 2.0 * u), Color("#F3EEE2"), true)
		tira.draw_rect(Rect2(x - u, y - 2.0 * u, u, u), Color("#141218"), true)
		tira.draw_rect(Rect2(x, y - u, u, u), Color("#141218"), true)


func _desenha_tira_topo() -> void:
	if cena_F == null:
		return
	var P: float = j.P
	var W := TIRAW
	var H := SH
	var alt := altura_tira()
	var topo := -40.0
	var s := H / alt
	var sx := W / LARG
	var y0: float = (j.cam_y - topo) * s
	var y1: float = (j.cam_y + VH - topo) * s
	tira_topo.draw_rect(Rect2(0, y0, W, y1 - y0), Color(243.0 / 255, 238.0 / 255, 226.0 / 255, 0.1), true)
	tira_topo.draw_rect(Rect2(1, y0, W - 2.0, y1 - y0), Color(243.0 / 255, 238.0 / 255, 226.0 / 255, 0.75), false, 1.5 * P)
	var JG = j.jogo
	var DM = j.demo
	var S: Nucleo.Estado = JG.S if JG != null else (DM.S if DM != null else null)
	if S != null:
		var mx := (S.p[0] + S.p[2]) / 2.0
		var my := (S.p[1] + S.p[3]) / 2.0
		var u := 3.0 * P
		tira_topo.draw_circle(Vector2(clampf(mx * sx, u, W - u), clampf((my - topo) * s, u, H - u)), 3.4 * P, Color("#FFC93C"), true, -1.0, true)
	if j.tela == "editor" or j.tela == "jogo" or j.demo != null:
		pass


func tira_redesenha() -> void:
	tira.queue_redraw()
