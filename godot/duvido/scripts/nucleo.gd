class_name Nucleo
extends RefCounted
## O núcleo do Duvido: a física do carrinho de rolimã, porte fiel do nucleo.js da versão web.
## Tudo aqui é determinístico: só + − × ÷ e raiz quadrada em float de 64 bits, na mesma ordem do JS,
## em passos fixos de 1/120 s. A mesma ladeira com os mesmos toques dá o mesmo resultado aqui e no navegador,
## e o fantasma de quem mandou o desafio desce igualzinho.
## Cuidado ao mexer: nada de Vector2 (é float de 32 bits), nada de int / int (vira divisão inteira),
## e nada de número com muitos dígitos escrito à mão (o leitor do GDScript erra o último bit; use PI e contas).

const PASSO := 1.0 / 120.0
const G := 980.0
const LARG := 420.0
const ALT_MAX := 5200
const LB := 30.0
const RR := 10.0
const RH := 8.5
const HC := 26.0
const V0 := 90.0
const PULO := 350.0
const VMAX := 780.0
const ARRASTO := 0.00032
const ROLA := 16.0
const QUIQUE := 0.16
const QUIQUE_MIN := 110.0
const W_GIRO := 8.5
const A_GIRO := 55.0
const A_SOLTA := 60.0
const SEG_MIN := 16
const AR_MIN := 22
const PE_MIN := 0.14
const COYOTE := 7
const MOLA_L := 18.0
const MOLA_V := 560.0
const TURBO_V := 720.0
const TURBO_R := 26.0
const CAO_R := 11.0
const CAO_VAI := 32.0
const CAO_PER := 384
const CHEG_L := 22.0
const CHEG_A := 100.0
const T_MAX := 14400
const PARADO_MAX := 360
const LARGADA := [4.0, 78.0, 4.0, 100.0, 128.0, 150.0]
const TIPOS := ["mola", "turbo", "cachorro", "chegada"]
const MEIO_PI := PI * 0.5
# as 16 direções do turbo, de 22,5 em 22,5 graus (0 = direita, 4 = pra baixo), os mesmos números do JS
const DIRS := [[1.0, 0.0], [0.9238795, 0.3826834], [0.7071068, 0.7071068], [0.3826834, 0.9238795], [0.0, 1.0], [-0.3826834, 0.9238795], [-0.7071068, 0.7071068], [-0.9238795, 0.3826834],
	[-1.0, 0.0], [-0.9238795, -0.3826834], [-0.7071068, -0.7071068], [-0.3826834, -0.9238795], [0.0, -1.0], [0.3826834, -0.9238795], [0.7071068, -0.7071068], [0.9238795, -0.3826834]]

const CEL := 40.0
const GX0 := -2
const GCOLS := 16


class Turbo:
	var x: float
	var y: float
	var dx: float
	var dy: float
	var dir: int


class Cao:
	var x: float
	var y: float
	var cam: PackedFloat64Array
	var fase: int


## A fase compilada: os segmentos numa grade, os carimbos prontos.
class Fase:
	var segs: PackedFloat64Array
	var tipo: PackedInt32Array
	var n: int = 0
	var molas: Array = []        # [x, y] (floats)
	var turbos: Array = []       # Turbo
	var caes: Array = []         # Cao
	var tem_chegada := false
	var chegada_x := 0.0
	var chegada_y := 0.0
	var y_max := 150.0
	var y_fundo := 650.0
	var rows := 0
	var cells: Array = []        # PackedInt32Array ou null
	var marca: PackedInt32Array
	var q := 0
	var lista: PackedInt32Array
	var cn := PackedFloat64Array([0.0, 0.0, -1.0])   # a normal média do último empurra e a mola
	var pc := PackedFloat64Array([0.0, 0.0, 0.0])    # onde o caramelo tá (posCao)


## O estado de uma descida.
class Estado:
	var p := PackedFloat64Array()
	var pa := PackedFloat64Array()
	var v := PackedFloat64Array()
	var c0 := 1
	var c1 := 1
	var nx := 0.0
	var ny := 0.0
	var coyote := COYOTE
	var ar := 0
	var frente := 1
	var giro := 0.0
	var cambalhotas := 0
	var segura := false
	var seg_t := 0
	var passos := 0
	var parado := 0
	var fim := ""            # vazio enquanto desce; senão o motivo
	var fim_passos := 0
	var fim_cs := -1         # -1 = null (só quem chegou tem tempo)
	var cd_t := PackedInt32Array()
	var cd_m := PackedInt32Array()
	var ev: Array = []       # nome, valor, nome, valor...


# ---------------------------------------------------------------- a fase compilada
static func compila(fase: Dictionary) -> Fase:
	var F := Fase.new()
	var S := PackedFloat64Array()
	var T := PackedInt32Array()
	var L: Array = LARGADA
	var i := 2
	while i < L.size():
		_seg(S, T, L[i - 2], L[i - 1], L[i], L[i + 1], -1)
		i += 2
	var y_max := 150.0
	for tr in fase.get("tracos", []):
		var p: Array = tr["pts"]
		i = 2
		while i < p.size():
			_seg(S, T, float(p[i - 2]), float(p[i - 1]), float(p[i]), float(p[i + 1]), -1)
			i += 2
		i = 1
		while i < p.size():
			if float(p[i]) > y_max:
				y_max = float(p[i])
			i += 2
	for c in fase.get("carimbos", []):
		var cx := float(c["x"])
		var cy := float(c["y"])
		if cy > y_max:
			y_max = cy
		var tipo: String = c["tipo"]
		if tipo == "mola":
			F.molas.append([cx, cy])
			_seg(S, T, cx - MOLA_L, cy, cx + MOLA_L, cy, F.molas.size() - 1)
		elif tipo == "turbo":
			var dr: int = int(c.get("dir", 0)) & 15
			var d: Array = DIRS[dr]
			var t := Turbo.new()
			t.x = cx; t.y = cy; t.dx = d[0]; t.dy = d[1]; t.dir = dr
			F.turbos.append(t)
		elif tipo == "cachorro":
			var k := Cao.new()
			k.x = cx; k.y = cy
			F.caes.append(k)
		elif tipo == "chegada":
			F.tem_chegada = true
			F.chegada_x = cx
			F.chegada_y = cy
	F.segs = S
	F.tipo = T
	F.n = T.size()
	F.y_max = y_max
	F.y_fundo = y_max + 500.0
	_monta_grade(F)
	# o caramelo anda no chão que tem embaixo dele
	for j in F.caes.size():
		var k: Cao = F.caes[j]
		k.cam = _caminho_cao(F, k)
		k.fase = (j * 97) % CAO_PER
	return F


static func _seg(S: PackedFloat64Array, T: PackedInt32Array, x1: float, y1: float, x2: float, y2: float, t: int) -> void:
	if x1 == x2 and y1 == y2:
		return
	S.append(x1); S.append(y1); S.append(x2); S.append(y2)
	T.append(t)


static func _cl(v: int, a: int, b: int) -> int:
	return a if v < a else (b if v > b else v)


static func _monta_grade(F: Fase) -> void:
	var rows := int(floorf((F.y_fundo + 600.0) / CEL)) + 8
	var cells: Array = []
	cells.resize(GCOLS * rows)
	var m := 14.0
	var s := F.segs
	for k in F.n:
		var o := k * 4
		var xa: float = minf(s[o], s[o + 2]) - m
		var xb: float = maxf(s[o], s[o + 2]) + m
		var ya: float = minf(s[o + 1], s[o + 3]) - m
		var yb: float = maxf(s[o + 1], s[o + 3]) + m
		var c0 := _cl(int(floorf(xa / CEL)) - GX0, 0, GCOLS - 1)
		var c1 := _cl(int(floorf(xb / CEL)) - GX0, 0, GCOLS - 1)
		var r0 := _cl(int(floorf(ya / CEL)) + 4, 0, rows - 1)
		var r1 := _cl(int(floorf(yb / CEL)) + 4, 0, rows - 1)
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				var idx := r * GCOLS + c
				if cells[idx] == null:
					cells[idx] = PackedInt32Array()
				var cel: PackedInt32Array = cells[idx]
				cel.append(k)
	F.rows = rows
	F.cells = cells
	F.marca = PackedInt32Array()
	F.marca.resize(F.n)
	F.q = 0
	F.lista = PackedInt32Array()
	F.lista.resize(maxi(1, F.n))


## Os segmentos perto de um ponto (sem repetir), na ordem de sempre: o resultado fica em F.lista.
static func consulta(F: Fase, x: float, y: float, r: float) -> int:
	F.q += 1
	var q := F.q
	var c0 := _cl(int(floorf((x - r) / CEL)) - GX0, 0, GCOLS - 1)
	var c1 := _cl(int(floorf((x + r) / CEL)) - GX0, 0, GCOLS - 1)
	var r0 := _cl(int(floorf((y - r) / CEL)) + 4, 0, F.rows - 1)
	var r1 := _cl(int(floorf((y + r) / CEL)) + 4, 0, F.rows - 1)
	var n := 0
	var marca := F.marca
	var lista := F.lista
	var cells := F.cells
	for rr in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var cel = cells[rr * GCOLS + c]
			if cel == null:
				continue
			var cc: PackedInt32Array = cel
			for j in cc.size():
				var k := cc[j]
				if marca[k] != q:
					marca[k] = q
					lista[n] = k
					n += 1
	return n


## O chão logo abaixo de um ponto (pra pôr cachorro, mola e bandeira em cima do giz). NAN = não tem.
static func chao_embaixo(F: Fase, x: float, y0: float, alcance: float) -> float:
	var melhor := NAN
	var tem := false
	var s := F.segs
	for k in F.n:
		if F.tipo[k] >= 0:
			continue
		var o := k * 4
		var x1 := s[o]
		var y1 := s[o + 1]
		var x2 := s[o + 2]
		var y2 := s[o + 3]
		if x1 == x2 or x < minf(x1, x2) or x > maxf(x1, x2):
			continue
		var y := y1 + (y2 - y1) * (x - x1) / (x2 - x1)
		if y >= y0 and y <= y0 + alcance and (not tem or y < melhor):
			melhor = y
			tem = true
	return melhor


static func _caminho_cao(F: Fase, c: Cao) -> PackedFloat64Array:
	var pts := PackedFloat64Array()
	for k in 9:
		var x := c.x - CAO_VAI + float(k) * CAO_VAI / 4.0
		var y := chao_embaixo(F, x, c.y - 24.0, 90.0)
		pts.append(x)
		pts.append(c.y if is_nan(y) else y)
	return pts


## Onde o caramelo tá no passo n: vai e volta, sem seno. Fica em F.pc (x, y, lado).
static func pos_cao(F: Fase, c: Cao, n: int) -> PackedFloat64Array:
	var m := (n + c.fase) % CAO_PER
	var h := float(CAO_PER) / 2.0
	var mf := float(m)
	var u := mf / h if mf < h else 2.0 - mf / h
	var f := u * 8.0
	var i := 7 if f >= 8.0 else int(floorf(f))
	var r := f - float(i)
	var p := c.cam
	var PC := F.pc
	PC[0] = p[i * 2] + (p[i * 2 + 2] - p[i * 2]) * r
	PC[1] = p[i * 2 + 1] + (p[i * 2 + 3] - p[i * 2 + 1]) * r - CAO_R - 1.0
	PC[2] = 1.0 if mf < h else -1.0
	return PC


# ---------------------------------------------------------------- a física do carrinho
static func novo_estado(F: Fase) -> Estado:
	var ax: float = LARGADA[2]
	var ay: float = LARGADA[3]
	var bx: float = LARGADA[4]
	var by: float = LARGADA[5]
	var dx := bx - ax
	var dy := by - ay
	var l := sqrt(dx * dx + dy * dy)
	var ux := dx / l
	var uy := dy / l
	var nx := uy
	var ny := -ux
	var S := Estado.new()
	S.p = PackedFloat64Array([ax + ux * 20.0 + nx * RR, ay + uy * 20.0 + ny * RR, ax + ux * (20.0 + LB) + nx * RR, ay + uy * (20.0 + LB) + ny * RR])
	S.pa = S.p.duplicate()
	S.v = PackedFloat64Array([ux * V0, uy * V0, ux * V0, uy * V0])
	S.nx = nx
	S.ny = ny
	S.cd_t = PackedInt32Array()
	S.cd_t.resize(F.turbos.size())
	S.cd_m = PackedInt32Array()
	S.cd_m.resize(F.molas.size())
	return S


## O dedo encostou: no chão é pulo (na direção do chão); no ar, segurando, vira cambalhota.
static func toca(S: Estado) -> void:
	if S.fim != "" or S.segura:
		return
	S.segura = true
	S.seg_t = 0
	if S.coyote > 0:
		var v := S.v
		v[0] += S.nx * PULO; v[1] += S.ny * PULO; v[2] += S.nx * PULO; v[3] += S.ny * PULO
		S.coyote = 0
		S.ev.append("pulo"); S.ev.append(0)


static func solta(S: Estado) -> void:
	S.segura = false


## Empurra um círculo pra fora do giz; devolve se encostou (a normal média e a mola, se for, ficam em F.cn).
static func empurra(F: Fase, p: PackedFloat64Array, i: int, r: float) -> bool:
	var cx := p[i]
	var cy := p[i + 1]
	var nx := 0.0
	var ny := 0.0
	var mola := -1
	var hit := false
	var n := consulta(F, cx, cy, r + 2.0)
	var s := F.segs
	var L := F.lista
	var r2 := r * r
	for j in n:
		var k := L[j]
		var o := k * 4
		var x1 := s[o]
		var y1 := s[o + 1]
		var dx := s[o + 2] - x1
		var dy := s[o + 3] - y1
		var l2 := dx * dx + dy * dy
		var u := ((cx - x1) * dx + (cy - y1) * dy) / l2
		if u < 0.0:
			u = 0.0
		elif u > 1.0:
			u = 1.0
		var ex := cx - (x1 + dx * u)
		var ey := cy - (y1 + dy * u)
		var d2 := ex * ex + ey * ey
		if d2 >= r2:
			continue
		var d := sqrt(d2)
		var mx: float
		var my: float
		if d > 1e-9:
			mx = ex / d
			my = ey / d
		else:
			var ll := sqrt(l2)
			mx = dy / ll
			my = -dx / ll
			if my > 0.0:
				mx = -mx
				my = -my
			d = 0.0
		cx += mx * (r - d)
		cy += my * (r - d)
		nx += mx
		ny += my
		hit = true
		if F.tipo[k] >= 0:
			mola = F.tipo[k]
	if not hit:
		return false
	p[i] = cx
	p[i + 1] = cy
	var nl := sqrt(nx * nx + ny * ny)
	var CN := F.cn
	if nl > 1e-9:
		CN[0] = nx / nl
		CN[1] = ny / nl
	else:
		CN[0] = 0.0
		CN[1] = -1.0
	CN[2] = float(mola)
	return true


static func encosta(F: Fase, x: float, y: float, r: float) -> bool:
	var n := consulta(F, x, y, r)
	var s := F.segs
	var L := F.lista
	var r2 := r * r
	for j in n:
		var o := L[j] * 4
		var x1 := s[o]
		var y1 := s[o + 1]
		var dx := s[o + 2] - x1
		var dy := s[o + 3] - y1
		var u := ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)
		if u < 0.0:
			u = 0.0
		elif u > 1.0:
			u = 1.0
		var ex := x - (x1 + dx * u)
		var ey := y - (y1 + dy * u)
		if ex * ex + ey * ey < r2:
			return true
	return false


static func _barra(p: PackedFloat64Array) -> void:
	var dx := p[2] - p[0]
	var dy := p[3] - p[1]
	var d := sqrt(dx * dx + dy * dy)
	var k := (d - LB) / d * 0.5
	p[0] += dx * k; p[1] += dy * k; p[2] -= dx * k; p[3] -= dy * k


## O rolimã no chão: tira o que entra no chão, quica um tiquinho e quase não freia.
static func _contato(v: PackedFloat64Array, i: int, nx: float, ny: float, ox: float, oy: float) -> void:
	var vn := v[i] * nx + v[i + 1] * ny
	if vn < 0.0:
		v[i] -= nx * vn
		v[i + 1] -= ny * vn
	var on := ox * nx + oy * ny
	if on < -QUIQUE_MIN:
		var q := -on * QUIQUE
		v[i] += nx * q
		v[i + 1] += ny * q
	var tx := -ny
	var ty := nx
	var vt := v[i] * tx + v[i + 1] * ty
	var d := ROLA * PASSO
	if vt > d:
		v[i] -= tx * d
		v[i + 1] -= ty * d
	elif vt < -d:
		v[i] += tx * d
		v[i + 1] += ty * d
	else:
		v[i] -= tx * vt
		v[i + 1] -= ty * vt


## O quanto a barra girou num passo (atan2 pra ângulo pequeno, só com conta e raiz).
static func angulo_passo(sn: float, cs: float) -> float:
	if cs <= 0.0:
		return MEIO_PI if sn >= 0.0 else -MEIO_PI
	var z := sn / cs
	z = z / (1.0 + sqrt(1.0 + z * z))
	var z2 := z * z
	return 2.0 * z * (1.0 - z2 * (1.0 / 3.0 - z2 * (1.0 / 5.0 - z2 * (1.0 / 7.0 - z2 / 9.0))))


## O Math.round do JS: meio pra cima (−2,5 vira −2).
static func js_round(x: float) -> float:
	var f := floorf(x)
	return f + 1.0 if x - f >= 0.5 else f


static func _acaba(S: Estado, motivo: String) -> void:
	S.fim = motivo
	S.fim_passos = S.passos
	if motivo == "chegou":
		S.fim_cs = int(maxf(0.0, js_round(float(S.passos * 100) / 120.0) - float(50 * S.cambalhotas)))
	else:
		S.fim_cs = -1
	S.ev.append("fim"); S.ev.append(0)


static func passo(F: Fase, S: Estado) -> void:
	if S.fim != "":
		return
	S.passos += 1
	var p := S.p
	var v := S.v
	var pa := S.pa
	var dt := PASSO
	pa[0] = p[0]; pa[1] = p[1]; pa[2] = p[2]; pa[3] = p[3]
	v[1] += G * dt
	v[3] += G * dt
	var bx := p[2] - p[0]
	var by := p[3] - p[1]
	var bl := sqrt(bx * bx + by * by)
	var ux := bx / bl
	var uy := by / bl
	var upx := uy
	var upy := -ux
	if S.segura:
		S.seg_t += 1
	# no ar: segurando, gira pra trás (a frente sobe); soltou, o giro morre rápido
	if S.c0 == 0 and S.c1 == 0 and S.ar >= 2:
		var w := ((v[2] - v[0]) * upx + (v[3] - v[1]) * upy) / LB
		var alvo := 0.0
		var a := A_SOLTA
		if S.segura and S.seg_t >= SEG_MIN:
			alvo = (1.0 if S.frente == 1 else -1.0) * W_GIRO
			a = A_GIRO
		var dw := alvo - w
		var lim := a * dt
		if dw > lim:
			dw = lim
		elif dw < -lim:
			dw = -lim
		var k := dw * LB / 2.0
		v[2] += upx * k; v[3] += upy * k; v[0] -= upx * k; v[1] -= upy * k
	var ii := 0
	while ii < 4:
		var sp := sqrt(v[ii] * v[ii] + v[ii + 1] * v[ii + 1])
		var fr := 1.0 - ARRASTO * sp * dt
		v[ii] *= fr
		v[ii + 1] *= fr
		ii += 2
	var o0x := v[0]
	var o0y := v[1]
	var o1x := v[2]
	var o1y := v[3]
	p[0] += v[0] * dt; p[1] += v[1] * dt; p[2] += v[2] * dt; p[3] += v[3] * dt
	var c0 := 0
	var c1 := 0
	var n0x := 0.0
	var n0y := 0.0
	var n1x := 0.0
	var n1y := 0.0
	var m0 := -1
	var m1 := -1
	var CN := F.cn
	for it in 3:
		_barra(p)
		if empurra(F, p, 0, RR):
			c0 = 1; n0x = CN[0]; n0y = CN[1]
			if CN[2] >= 0.0:
				m0 = int(CN[2])
		if empurra(F, p, 2, RR):
			c1 = 1; n1x = CN[0]; n1y = CN[1]
			if CN[2] >= 0.0:
				m1 = int(CN[2])
	v[0] = (p[0] - pa[0]) / dt; v[1] = (p[1] - pa[1]) / dt; v[2] = (p[2] - pa[2]) / dt; v[3] = (p[3] - pa[3]) / dt
	var impacto := 0.0
	if c0 != 0:
		_contato(v, 0, n0x, n0y, o0x, o0y)
		impacto = -(o0x * n0x + o0y * n0y)
	if c1 != 0:
		_contato(v, 2, n1x, n1y, o1x, o1y)
		impacto = maxf(impacto, -(o1x * n1x + o1y * n1y))
	# a mola: pisou por cima, voa
	for k in S.cd_m.size():
		if S.cd_m[k] > 0:
			S.cd_m[k] -= 1
	var mk := m0 if m0 >= 0 else m1
	var mny := n0y if m0 >= 0 else n1y
	if mk >= 0 and S.cd_m[mk] == 0 and mny < -0.5:
		v[1] = -MOLA_V
		v[3] = -MOLA_V
		S.cd_m[mk] = 24
		S.ev.append("mola"); S.ev.append(mk)
		c0 = 0
		c1 = 0
	ii = 0
	while ii < 4:
		var s2 := v[ii] * v[ii] + v[ii + 1] * v[ii + 1]
		if s2 > VMAX * VMAX:
			var f := VMAX / sqrt(s2)
			v[ii] *= f
			v[ii + 1] *= f
		ii += 2
	bx = p[2] - p[0]
	by = p[3] - p[1]
	bl = sqrt(bx * bx + by * by)
	var ux2 := bx / bl
	var uy2 := by / bl
	if c0 == 0 and c1 == 0:
		S.giro += angulo_passo(ux * uy2 - uy * ux2, ux * ux2 + uy * uy2)
		S.ar += 1
		if S.coyote > 0:
			S.coyote -= 1
	else:
		var nx := (n0x if c0 != 0 else 0.0) + (n1x if c1 != 0 else 0.0)
		var ny := (n0y if c0 != 0 else 0.0) + (n1y if c1 != 0 else 0.0)
		var nl := sqrt(nx * nx + ny * ny)
		if nl > 1e-9:
			nx /= nl
			ny /= nl
		else:
			nx = 0.0
			ny = -1.0
		if S.ar >= AR_MIN:
			# pousou: de pé conta as cambalhotas; torto demais, capotou
			if uy2 * nx - ux2 * ny < PE_MIN:
				S.c0 = c0
				S.c1 = c1
				_acaba(S, "torto")
				return
			var voltas := int(floorf((absf(S.giro) + PI) / TAU))
			if voltas > 0:
				S.cambalhotas += voltas
				S.ev.append("cambalhota"); S.ev.append(voltas)
			S.ev.append("pouso"); S.ev.append(impacto)
		elif impacto > 160.0:
			S.ev.append("pouso"); S.ev.append(impacto)
		S.giro = 0.0
		S.ar = 0
		S.coyote = COYOTE
		S.nx = nx
		S.ny = ny
		var vb := ((v[0] + v[2]) * ux2 + (v[1] + v[3]) * uy2) / 2.0
		if vb > 25.0:
			S.frente = 1
		elif vb < -25.0:
			S.frente = 0
	S.c0 = c0
	S.c1 = c1
	var mx := (p[0] + p[2]) / 2.0
	var my := (p[1] + p[3]) / 2.0
	var hx := mx + uy2 * HC
	var hy := my - ux2 * HC
	# a cabeça no chão: capotou
	if encosta(F, hx, hy, RH):
		_acaba(S, "capotou")
		return
	# o caramelo
	for i in F.caes.size():
		var c := pos_cao(F, F.caes[i], S.passos)
		var cx := c[0]
		var cy := c[1]
		if _perto(p[0], p[1], cx, cy, CAO_R + 6.5) or _perto(p[2], p[3], cx, cy, CAO_R + 6.5) or _perto(hx, hy, cx, cy, CAO_R + 7.0) or _perto(mx + uy2 * 12.0, my - ux2 * 12.0, cx, cy, CAO_R + 9.0):
			_acaba(S, "cachorro")
			return
	# o turbo: passou por dentro, ganha velocidade pro lado da seta
	for i in F.turbos.size():
		var t: Turbo = F.turbos[i]
		if S.cd_t[i] > 0:
			S.cd_t[i] -= 1
		var dx := mx - t.x
		var dy := my - t.y
		if dx * dx + dy * dy < TURBO_R * TURBO_R:
			if S.cd_t[i] == 0:
				var j := 0
				while j < 4:
					var a := v[j] * t.dx + v[j + 1] * t.dy
					if a < TURBO_V:
						v[j] += t.dx * (TURBO_V - a)
						v[j + 1] += t.dy * (TURBO_V - a)
					j += 2
				S.ev.append("turbo"); S.ev.append(i)
			S.cd_t[i] = 30
	if F.tem_chegada and mx >= F.chegada_x - CHEG_L and mx <= F.chegada_x + CHEG_L and my >= F.chegada_y - CHEG_A and my <= F.chegada_y + 16.0:
		_acaba(S, "chegou")
		return
	if mx < -8.0 or mx > LARG + 8.0:
		_acaba(S, "barranco")
		return
	if my > F.y_fundo:
		_acaba(S, "caiu")
		return
	var vx := (v[0] + v[2]) / 2.0
	var vy := (v[1] + v[3]) / 2.0
	if (c0 != 0 or c1 != 0) and vx * vx + vy * vy < 64.0:
		S.parado += 1
	else:
		S.parado = 0
	if S.parado > PARADO_MAX:
		_acaba(S, "empacou")
		return
	if S.passos >= T_MAX:
		_acaba(S, "tempo")


static func _perto(x: float, y: float, cx: float, cy: float, r: float) -> bool:
	return (x - cx) * (x - cx) + (y - cy) * (y - cy) < r * r


## Desce a fase com uma lista de toques ({t em segundos, tipo "toca" ou "solta"}); puro e determinístico.
static func simula(fase, toques: Array) -> Dictionary:
	var F: Fase = fase if fase is Fase else compila(fase)
	var S := novo_estado(F)
	var evs: Array = []
	for i in toques.size():
		var e: Dictionary = toques[i]
		evs.append([int(maxf(0.0, js_round(float(e["t"]) / PASSO))), 1 if e["tipo"] == "toca" else 0, i])
	evs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[2] < b[2]))
	var j := 0
	while S.fim == "":
		while j < evs.size() and evs[j][0] <= S.passos:
			if evs[j][1] == 1:
				toca(S)
			else:
				solta(S)
			j += 1
		S.ev.clear()
		passo(F, S)
	return resumo(S)


## O mesmo, com os toques gravados em passos (é assim que o fantasma viaja no link): toca, solta, toca...
static func roda_gravado(F: Fase, eventos: Array, S: Estado = null) -> Dictionary:
	if S == null:
		S = novo_estado(F)
	var j := 0
	while S.fim == "":
		while j < eventos.size() and int(eventos[j]) <= S.passos:
			if j % 2 == 0:
				toca(S)
			else:
				solta(S)
			j += 1
		S.ev.clear()
		passo(F, S)
	return resumo(S)


static func resumo(S: Estado) -> Dictionary:
	var m := S.fim
	return {"chegou": m == "chegou", "cs": S.fim_cs, "capotou": m == "capotou" or m == "torto" or m == "cachorro",
		"motivo": m, "cambalhotas": S.cambalhotas, "passos": S.passos}
