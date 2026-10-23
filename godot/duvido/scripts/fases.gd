class_name Fases
extends RefCounted
## As ladeiras feitas por nós, a ladeira do dia e o piloto robô (porte fiel do fases.js da versão web).
## A ladeira do dia sai da data: a mesma em todo aparelho, no navegador e aqui.

const LARG := 420.0
const GRAU := PI / 180.0


## Seno sem o seno da máquina (série de Taylor): a ladeira do dia tem que sair igual em todo aparelho.
static func sen(x: float) -> float:
	var DP := TAU
	var P := PI
	var M := PI * 0.5
	x = x - DP * floorf(x / DP + 0.5)
	if x > M:
		x = P - x
	elif x < -M:
		x = -P - x
	var x2 := x * x
	return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0 * (1.0 - x2 / 72.0 * (1.0 - x2 / 110.0)))))


static func cos_(x: float) -> float:
	return sen(x + PI * 0.5)


## O sorteio com semente (mulberry32, inteiro de 32 bits igual ao do JS).
class Sorteio:
	var a: int

	func _init(semente: int) -> void:
		a = Codigo.i32(semente)

	func r() -> float:
		a = Codigo.i32(a + 0x6D2B79F5)
		var t := Codigo.imul(a ^ ((a & 0xFFFFFFFF) >> 15), 1 | a)
		t = Codigo.i32(t + Codigo.imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t
		return float((t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func rnd(x: float) -> float:
	return Nucleo.js_round(x)


static func arco(cx: float, cy: float, r: float, a0: float, a1: float, pg: float = 9.0) -> Array:
	var n := int(maxf(2.0, ceilf(absf(a1 - a0) / pg)))
	var o: Array = []
	for i in n + 1:
		var a := (a0 + (a1 - a0) * float(i) / float(n)) * GRAU
		o.append(rnd(cx + cos_(a) * r))
		o.append(rnd(cy + sen(a) * r))
	return o


static func junta(ps: Array) -> Array:
	var o: Array = []
	for p in ps:
		var i := 0
		while i < p.size():
			if o.size() > 0 and o[o.size() - 2] == p[i] and o[o.size() - 1] == p[i + 1]:
				i += 2
				continue
			o.append(p[i])
			o.append(p[i + 1])
			i += 2
	return o


## Inclinação → graus, sem o atan da máquina.
static func graus_de(s: float) -> float:
	var z := s / (1.0 + sqrt(1.0 + s * s))
	var z2 := z * z
	return 2.0 * z * (1.0 - z2 * (1.0 / 3.0 - z2 * (1.0 / 5.0 - z2 * (1.0 / 7.0 - z2 / 9.0)))) / GRAU


## A direção do turbo mais perto de um ângulo (graus, 0 = direita, 90 = pra baixo).
static func dir_de(g: float) -> int:
	var r := int(rnd(g / 22.5))
	return ((r % 16) + 16) % 16


static func _num(d: Dictionary, k: String, padrao: float) -> float:
	# o "x || padrão" do JS: falta ou zero vira o padrão
	var v = d.get(k, null)
	if v == null or float(v) == 0.0:
		return padrao
	return float(v)


static func _ordena_itens(itens: Array) -> Array:
	# ordem estável pelo "em" (o sort do JS é estável)
	var o: Array = []
	for it in itens:
		var j := o.size()
		while j > 0 and float(o[j - 1]["em"]) > float(it["em"]):
			j -= 1
		o.insert(j, it)
	return o


## A serra: andares em zigue-zague. Cada andar desce pra um lado e acaba numa beirada; o de baixo pega o carrinho
## numa curva grande colada no barranco (ele sobe, perde força e volta) e desce pro outro lado.
static func serra(spec: Dictionary) -> Dictionary:
	var tracos: Array = []
	var carimbos: Array = []
	var MURO := 412.0
	var BEIRA := _num(spec, "beira", 270.0)
	var x := 128.0
	var y := 150.0
	var d := 1.0
	var andares: Array = spec["andares"]
	for k in andares.size():
		var A: Dictionary = andares[k]
		var P0 = andares[k + 1] if k + 1 < andares.size() else null
		var cor := int(_num(A, "cor", 0.0))
		var desce := float(A["desce"])
		# queda grande pro próximo andar pede beirada mais longe do barranco (senão ele bate alto na curva)
		var beira: float
		if _num(A, "beira", 0.0) != 0.0:
			beira = _num(A, "beira", 0.0)
		else:
			beira = 230.0 if (P0 != null and _num(P0, "queda", 66.0) > 110.0) else BEIRA
		var fim_x := beira if d > 0.0 else LARG - beira
		var partes: Array = []
		if k > 0:
			var R := _num(A, "raio", 96.0)
			var lado := -d
			var wx := MURO if lado > 0.0 else LARG - MURO
			var cx := wx - lado * R
			var cy := y - R
			partes.append([wx, maxf(0.0, cy - _num(A, "parede", 70.0))])
			partes.append(arco(cx, cy, R, 0.0, 90.0) if lado > 0.0 else arco(cx, cy, R, 180.0, 90.0))
		else:
			partes.append([x, y])
		var x0 := x
		var y0 := y
		var off := 0.0
		for it in _ordena_itens(A.get("itens", [])):
			var em := float(it["em"])
			var xi := rnd(x0 + (fim_x - x0) * em)
			var kk: String = it["k"]
			if kk == "lombada":
				var w := _num(it, "w", 60.0)
				var h := _num(it, "h", 14.0)
				var n := 8.0
				var xa := xi - d * w / 2.0
				partes.append([rnd(xa), rnd(_fx(xa, x0, y0, desce, off))])
				for i in range(1, 9):
					var xx := xa + d * w * float(i) / n
					partes.append([rnd(xx), rnd(_fx(xx, x0, y0, desce, off) - h * sen(PI * float(i) / n))])
			elif kk == "buraco":
				var w := _num(it, "w", 50.0)
				var xa := xi - d * w / 2.0
				var xb := xi + d * w / 2.0
				partes.append([rnd(xa), rnd(_fx(xa, x0, y0, desce, off))])
				tracos.append({"cor": cor, "pts": _inteiros(junta(partes))})
				off += _num(it, "cai", 8.0)
				partes = [[rnd(xb), rnd(_fx(xb, x0, y0, desce, off))]]
			elif kk == "meiofio" or kk == "muro":
				# um degrau no meio do chão: o meio-fio pede pulo, o muro pede mola
				var h := _num(it, "h", 90.0 if kk == "muro" else 18.0)
				var w := _num(it, "w", 8.0)
				var ya := rnd(_fx(xi, x0, y0, desce, off))
				partes.append([xi, ya, xi, ya - h, xi + d * w, ya - h, xi + d * w, rnd(_fx(xi + d * w, x0, y0, desce, off))])
			elif kk == "turbo":
				var g := graus_de(desce)
				carimbos.append({"tipo": "turbo", "x": int(xi), "y": int(rnd(_fx(xi, x0, y0, desce, off)) - 16.0), "dir": dir_de(g if d > 0.0 else 180.0 - g)})
			elif kk == "cachorro":
				carimbos.append({"tipo": "cachorro", "x": int(xi), "y": int(rnd(_fx(xi, x0, y0, desce, off)))})
			elif kk == "mola":
				carimbos.append({"tipo": "mola", "x": int(xi), "y": int(rnd(_fx(xi, x0, y0, desce, off)) - 3.0)})
		var y_lip := 0.0
		if k == andares.size() - 1:
			# o último andar acaba num reto com a bandeira e um murinho
			var y_f := rnd(_fx(fim_x, x0, y0, desce, off))
			var reto := _num(spec, "reto", 70.0)
			var xr := fim_x + d * reto
			partes.append([fim_x, y_f, xr, y_f + 2.0, xr + d * 12.0, y_f - 12.0])
			carimbos.append({"tipo": "chegada", "x": int(rnd(fim_x + d * reto * 0.5)), "y": int(y_f + 1.0)})
		elif _num(A, "chuta", 0.0) != 0.0:
			# o chutador: o fim do andar sobe numa curvinha e joga o carrinho pro alto
			var chuta := _num(A, "chuta", 0.0)
			var xa := fim_x - d * 46.0
			var ya := rnd(_fx(xa, x0, y0, desce, off))
			partes.append([rnd(xa), ya, rnd(fim_x - d * 22.0), ya + 3.0, rnd(fim_x - d * 8.0), ya - 2.0, fim_x, ya - chuta])
			y_lip = ya - chuta
		else:
			# a beirada: o fim do andar deita um pouco, pra o carrinho sair reto
			var xa := fim_x - d * 34.0
			var ya := rnd(_fx(xa, x0, y0, desce, off))
			partes.append([rnd(xa), ya, fim_x, ya + 4.0])
			y_lip = ya + 4.0
		tracos.append({"cor": cor, "pts": _inteiros(junta(partes))})
		if k + 1 < andares.size():
			var P: Dictionary = andares[k + 1]
			var R := _num(P, "raio", 96.0)
			var cx := (MURO if d > 0.0 else LARG - MURO) - d * R
			# o chão do próximo fica abaixo da beirada o bastante pra caber a cabeça quando ele voltar por baixo
			y = rnd(y_lip + _num(P, "queda", 66.0) - absf(cx - fim_x) * float(P["desce"]))
			x = cx
		d = -d
	var autor = spec.get("autor", "")
	return {"autor": autor if autor is String else "", "tracos": tracos, "carimbos": carimbos, "corrente": [], "fantasma": null}


static func _fx(xx: float, x0: float, y0: float, desce: float, off: float) -> float:
	return y0 + absf(xx - x0) * desce + off


static func _inteiros(a: Array) -> Array:
	var o: Array = []
	for v in a:
		o.append(int(v))
	return o


# ---------------------------------------------------------------- o piloto robô
## Pula os cachorros que vêm pela frente (é com ele que a ladeira do dia é conferida, e é ele que desce na entrada).
## Devolve 1 (toca), 0 (solta) ou -1 (nada).
static func piloto(F: Nucleo.Fase, S: Nucleo.Estado, antes: float = 0.36) -> int:
	if S.segura:
		return 0 if S.seg_t >= 3 else -1
	# só pula de chão reto (na curva o pulo sai torto) e com velocidade
	if S.coyote < Nucleo.COYOTE or S.ny > -0.8:
		return -1
	var p := S.p
	var v := S.v
	var mx := (p[0] + p[2]) / 2.0
	var my := (p[1] + p[3]) / 2.0
	var vx := (v[0] + v[2]) / 2.0
	if absf(vx) < 30.0:
		return -1
	# degrau em pé na frente (meio-fio): pula um tiquinho antes
	var fr := 2 if S.frente == 1 else 0
	var sg := 1.0 if S.frente == 1 else -1.0
	var ux := (p[2] - p[0]) / Nucleo.LB * sg
	var uy := (p[3] - p[1]) / Nucleo.LB * sg
	var d_obs := degrau_na_frente(F, p[fr], p[fr + 1], ux, uy, absf(vx) * 0.32 + 14.0)
	if not is_nan(d_obs) and d_obs > absf(vx) * 0.12:
		# só se o chão continua até o degrau (na beirada, o que aparece na frente é a curva do andar de baixo)
		var qx := p[fr] + ux * d_obs * 0.6
		var qy := p[fr + 1] + uy * d_obs * 0.6
		var ch := Nucleo.chao_embaixo(F, qx, qy, 24.0)
		if not is_nan(ch):
			return 1
	for i in F.caes.size():
		var c := Nucleo.pos_cao(F, F.caes[i], S.passos)
		var dx := c[0] - mx
		var dy := c[1] - my
		# só o cachorro do chão em que ele tá: a altura que o chão teria lá, seguindo a tábua
		var bx := p[2] - p[0]
		var by := p[3] - p[1]
		if dx * vx <= 0.0 or absf(bx) < 1.0 or absf(dy - by / bx * dx) > 24.0:
			continue
		var t := (absf(dx) - 26.0) / absf(vx)
		if t > 0.0 and t < antes:
			return 1
	return -1


## A distância até um segmento quase em pé cruzando a linha da tábua, na frente da roda da frente (NAN = nenhum).
static func degrau_na_frente(F: Nucleo.Fase, ox: float, oy: float, ux: float, uy: float, L: float) -> float:
	var n := Nucleo.consulta(F, ox + ux * L / 2.0, oy + uy * L / 2.0, L / 2.0 + 12.0)
	var s := F.segs
	var melhor := NAN
	var tem := false
	for j in n:
		var k := F.lista[j]
		var o := k * 4
		var ax := s[o]
		var ay := s[o + 1]
		var bx := s[o + 2] - ax
		var by := s[o + 3] - ay
		if absf(bx) > absf(by) * 0.5:
			continue
		# só degrau que nasce do chão em que ele tá (a ponta de baixo na altura do chão)
		var ha := (ax - ox) * uy - (ay - oy) * ux
		var hb := (s[o + 2] - ox) * uy - (s[o + 3] - oy) * ux
		var hb0 := minf(-ha, -hb)
		if hb0 < -17.0 or hb0 > -3.0:
			continue
		var den := ux * by - uy * bx
		if absf(den) < 1e-9:
			continue
		var t := ((ax - ox) * by - (ay - oy) * bx) / den
		var u := ((ax - ox) * uy - (ay - oy) * ux) / den
		if t > 0.0 and t < L and u >= 0.0 and u <= 1.0 and (not tem or t < melhor):
			melhor = t
			tem = true
	return melhor


## Desce com o robô e devolve os toques que ele deu (em passos) e o resultado.
static func desce_robo(F: Nucleo.Fase, antes: float = 0.36) -> Dictionary:
	var S := Nucleo.novo_estado(F)
	var ev: Array = []
	while S.fim == "":
		var a := piloto(F, S, antes)
		if a == 1:
			Nucleo.toca(S)
			ev.append(S.passos)
		elif a == 0:
			Nucleo.solta(S)
			ev.append(S.passos)
		S.ev.clear()
		Nucleo.passo(F, S)
	return {"r": Nucleo.resumo(S), "ev": ev}


# ---------------------------------------------------------------- a ladeira do dia
## A data vira a semente; a serra sai sorteada e o robô confere que dá pra chegar.
static func gera_dia(semente: int) -> Dictionary:
	var rr := Sorteio.new(semente)
	var na := 6 + int(floorf(rr.r() * 3.0))
	var andares: Array = []
	for k in na:
		var desce := rnd((0.24 + rr.r() * 0.12) * 100.0) / 100.0
		var raio := 84.0 + floorf(rr.r() * 16.0)
		var queda := 84.0 + floorf(rr.r() * 22.0)
		var cor := 0
		if rr.r() < 0.25:
			cor = 1 + int(floorf(rr.r() * 3.0))
		var A := {"desce": desce, "raio": raio, "queda": queda, "itens": [], "cor": cor}
		var sorte := rr.r()
		# o cachorro fica na parte larga do andar (longe do andar de cima), e o andar desce mais pra caber o pulo
		if k > 0 and sorte < 0.3:
			A["itens"].append({"k": "cachorro", "em": 0.74 + rr.r() * 0.14})
			A["queda"] = 96.0 + floorf(rr.r() * 16.0)
		elif sorte < 0.55:
			var em := 0.35 + rr.r() * 0.35
			var h := 8.0 + floorf(rr.r() * 10.0)
			var w := 50.0 + floorf(rr.r() * 30.0)
			A["itens"].append({"k": "lombada", "em": em, "h": h, "w": w})
		elif sorte < 0.75:
			var em := 0.55 + rr.r() * 0.3
			var w := 26.0 + floorf(rr.r() * 22.0)
			A["itens"].append({"k": "buraco", "em": em, "w": w})
		# turbo só em andar manso (no ladeirão ele joga o carrinho longe demais)
		if k > 0 and desce < 0.3 and rr.r() < 0.35:
			A["itens"].append({"k": "turbo", "em": 0.12 + rr.r() * 0.1})
		if k < na - 1 and rr.r() < 0.25:
			A["chuta"] = 5.0 + floorf(rr.r() * 5.0)
		andares.append(A)
	return serra({"autor": "Ladeira do dia", "andares": andares, "reto": 60.0 + floorf(rr.r() * 30.0)})


## O dia de hoje no horário de Brasília (a ladeira muda à meia-noite, igual pra todo mundo).
static func dia_hoje(agora_unix: float = -1.0) -> Dictionary:
	if agora_unix < 0.0:
		agora_unix = Time.get_unix_time_from_system()
	var t := Time.get_datetime_dict_from_unix_time(int(floorf(agora_unix - 3.0 * 3600.0)))
	return {"a": int(t["year"]), "m": int(t["month"]), "d": int(t["day"])}


static func ladeira_do_dia(dia: Dictionary = {}) -> Dictionary:
	if dia.is_empty():
		dia = dia_hoje()
	var base: int = int(dia["a"]) * 10000 + int(dia["m"]) * 100 + int(dia["d"])
	for t in 40:
		var f := gera_dia(base * 31 + t * 7919)
		var F := Nucleo.compila(f)
		var r := desce_robo(F)
		var rs: Dictionary = r["r"]
		if rs["chegou"] and int(rs["cs"]) >= 500 and int(rs["cs"]) <= 2000:
			f["dia"] = dia
			f["par"] = rs["cs"]
			f["robo"] = r["ev"]
			return f
	var f2 := serra({"autor": "Ladeira do dia", "andares": [{"desce": 0.35}, {"desce": 0.3}, {"desce": 0.3}, {"desce": 0.25}]})
	f2["dia"] = dia
	return f2


# ---------------------------------------------------------------- as cinco da casa
## Da fácil à safada (todas conferidas pelo robô: dá pra chegar).
const PRONTAS_SPEC := [
	{"nome": "Pra aquecer", "sub": "Desce sozinha. Só não atrapalha.", "spec": {"andares": [{"desce": .34}, {"desce": .3, "queda": 96, "itens": [{"k": "lombada", "em": .6, "h": 10}]}, {"desce": .32, "cor": 1, "queda": 100}, {"desce": .3, "queda": 104}, {"desce": .3, "queda": 96, "itens": [{"k": "lombada", "em": .5, "h": 9}]}, {"desce": .28, "queda": 100, "cor": 3}, {"desce": .24, "queda": 96}]}},
	{"nome": "Lombada", "sub": "Lombada, buraco e meio-fio. No meio-fio, pula.", "spec": {"andares": [{"desce": .34, "itens": [{"k": "lombada", "em": .45, "h": 14}, {"k": "lombada", "em": .75, "h": 12}]}, {"desce": .3, "queda": 100, "itens": [{"k": "buraco", "em": .7, "w": 40}]}, {"desce": .32, "queda": 104, "cor": 1, "itens": [{"k": "meiofio", "em": .86, "h": 16}]}, {"desce": .3, "queda": 96, "itens": [{"k": "lombada", "em": .4, "h": 14}, {"k": "lombada", "em": .7, "h": 14}]}, {"desce": .32, "queda": 104, "itens": [{"k": "buraco", "em": .75, "w": 46}]}, {"desce": .3, "queda": 100, "cor": 2, "itens": [{"k": "meiofio", "em": .84, "h": 16}]}, {"desce": .24, "queda": 96, "itens": [{"k": "lombada", "em": .5, "h": 16}]}]}},
	{"nome": "Cachorro do vizinho", "sub": "Quatro caramelos de guarda. Pula os quatro.", "spec": {"andares": [{"desce": .34}, {"desce": .3, "queda": 112, "itens": [{"k": "cachorro", "em": .84}]}, {"desce": .28, "queda": 110, "cor": 2, "itens": [{"k": "lombada", "em": .35, "h": 10}, {"k": "cachorro", "em": .72}]}, {"desce": .32, "queda": 96}, {"desce": .28, "queda": 112, "itens": [{"k": "cachorro", "em": .72}]}, {"desce": .3, "queda": 100, "cor": 1, "itens": [{"k": "lombada", "em": .45, "h": 10}]}, {"desce": .24, "queda": 112, "itens": [{"k": "cachorro", "em": .62}]}]}},
	{"nome": "Mola maluca", "sub": "A mola te manda pro céu. Volta inteiro.", "spec": {"andares": [{"desce": .2, "itens": [{"k": "mola", "em": .35}, {"k": "muro", "em": .53, "h": 70}]}, {"desce": .26, "parede": 292, "raio": 106, "queda": 97, "cor": 3, "itens": [{"k": "turbo", "em": .14}, {"k": "buraco", "em": .52, "w": 76, "cai": 4}]}, {"desce": .3, "queda": 100}, {"desce": .3, "queda": 104, "itens": [{"k": "lombada", "em": .4, "h": 12}]}, {"desce": .26, "queda": 96, "itens": [{"k": "turbo", "em": .16}, {"k": "buraco", "em": .62, "w": 60, "cai": 4}]}, {"desce": .3, "queda": 104, "cor": 1}, {"desce": .24, "queda": 100, "itens": [{"k": "lombada", "em": .5, "h": 12}]}]}},
	{"nome": "A safada", "sub": "Tudo junto, e o caramelo te esperando. Duvido.", "spec": {"andares": [{"desce": .12, "itens": [{"k": "mola", "em": .19}, {"k": "muro", "em": .56, "h": 88}]}, {"desce": .24, "parede": 237, "raio": 116, "queda": 83, "cor": 2, "itens": [{"k": "turbo", "em": .16}, {"k": "buraco", "em": .52, "w": 81, "cai": 4}]}, {"desce": .25, "queda": 114, "itens": [{"k": "lombada", "em": .43, "h": 12}, {"k": "cachorro", "em": .8}]}, {"desce": .26, "queda": 114, "chuta": 6, "cor": 3, "itens": [{"k": "meiofio", "em": .89, "h": 16}]}, {"desce": .3, "queda": 96, "itens": [{"k": "buraco", "em": .7, "w": 50}]}, {"desce": .26, "queda": 110, "chuta": 7, "itens": [{"k": "cachorro", "em": .78}]}, {"desce": .3, "queda": 104, "cor": 1, "itens": [{"k": "lombada", "em": .4, "h": 14}, {"k": "meiofio", "em": .86, "h": 16}]}, {"desce": .24, "queda": 116, "itens": [{"k": "cachorro", "em": .7}]}]}},
]

static var _prontas: Array = []


## As cinco da casa, montadas uma vez: [{nome, sub, fase, i}].
static func prontas() -> Array:
	if _prontas.is_empty():
		for i in PRONTAS_SPEC.size():
			var p: Dictionary = PRONTAS_SPEC[i]
			var spec: Dictionary = p["spec"].duplicate(true)
			spec["autor"] = "Duvido"
			_prontas.append({"nome": p["nome"], "sub": p["sub"], "fase": serra(spec), "i": i})
	return _prontas
