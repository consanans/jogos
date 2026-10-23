class_name Codigo
extends RefCounted
## O código do link: a fase inteira em letras, dígitos, - e _ (porte fiel do codigo.js da versão web).
## É base64url sem "=": cada letra carrega 6 bits. Os números vão em Exp-Golomb (número pequeno, código curto)
## e os traços em diferenças de um ponto pro outro. Começa com "dv1" (a versão) e fecha com uma conferência de 12 bits,
## pra link cortado no meio do caminho (zap adora fazer isso) não abrir uma ladeira quebrada.
## Um código feito no navegador abre aqui e vice-versa, letra por letra igual.

const ALFA := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
const PREFIXO := "dv1"
const NOME_MAX := 14
const CORRENTE_MAX := 6
const LINK := "https://mougus.com.br/jogos/duvido"


# ---------------------------------------------------------------- inteiros de 32 bits do JS
static func i32(x: int) -> int:
	x = x & 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x


static func u32(x: int) -> int:
	return x & 0xFFFFFFFF


## Math.imul: a multiplicação de 32 bits do JS (sem estourar o int de 64).
static func imul(a: int, b: int) -> int:
	var a32 := a & 0xFFFFFFFF
	var b32 := b & 0xFFFFFFFF
	var ah := a32 >> 16
	var al := a32 & 0xFFFF
	return i32(al * b32 + ((ah * (b32 & 0xFFFF)) << 16))


# ---------------------------------------------------------------- a escrita e a leitura dos bits
class Escreve:
	var b := PackedByteArray()

	func n(v: int, k: int) -> void:
		var u := v & 0xFFFFFFFF
		var i := k - 1
		while i >= 0:
			b.append((u >> i) & 1 if i < 32 else 0)
			i -= 1

	func eg(v: int, k: int) -> void:
		var w := v + (1 << k)
		var nb := 0
		var t := w
		while t > 0:
			nb += 1
			t = t >> 1
		for i in nb - k - 1:
			b.append(0)
		n(w, nb)

	func sz(v: int, k: int) -> void:
		eg(-2 * v - 1 if v < 0 else 2 * v, k)

	func txt(s: String) -> void:
		var c := Codigo.codigos_nome(s)
		n(c.size(), 4)
		for k in c:
			n(k, 8)


class Le:
	var b: PackedByteArray
	var i := 0
	var erro := false

	func _init(bits: PackedByteArray) -> void:
		b = bits

	func bit() -> int:
		if i >= b.size():
			erro = true
			return 1   # devolve 1 pra nenhum laço ficar preso; quem chama confere o erro
		i += 1
		return b[i - 1]

	func n(k: int) -> int:
		var v := 0
		for j in k:
			v = v * 2 + bit()
		return v

	func eg(k: int) -> int:
		var z := 0
		while bit() == 0:
			z += 1
			if z > 24:
				erro = true
				return 0
		if erro:
			return 0
		var w := 1
		for j in z + k:
			w = w * 2 + bit()
		return w - (1 << k)

	func sz(k: int) -> int:
		var u := eg(k)
		@warning_ignore("integer_division")
		return -(u + 1) / 2 if u % 2 != 0 else u / 2

	func txt() -> String:
		var nn := n(4)
		var s := ""
		for j in nn:
			var k := n(8)
			# nenhum código de verdade traz letra de controle (quem escreve troca por "?"); só um código
			# adulterado traria, e aí ela vira "?" também (a letra zero nem cabe numa String do Godot)
			s += String.chr(k if k >= 32 else 63)
		return s


## As letras do nome que vão no código: até 14 letras; fora do Latin-1 vira "?".
static func codigos_nome(s: String) -> PackedInt32Array:
	var o := PackedInt32Array()
	for j in mini(s.length(), NOME_MAX):
		var k := s.unicode_at(j)
		o.append(k if (k > 31 and k < 256) else 63)
	return o


static func soma12(b: PackedByteArray, ate: int) -> int:
	var h := 0
	for i in ate:
		h = (h * 31 + b[i] + 7) % 4093
	return h


static func tam_eg(v: int, k: int) -> int:
	var w := v + (1 << k)
	var nb := 0
	var t := w
	while t > 0:
		nb += 1
		t = t >> 1
	return 2 * nb - k - 1


static func zz(v: int) -> int:
	return -2 * v - 1 if v < 0 else 2 * v


static func codifica(fase: Dictionary) -> String:
	var w := Escreve.new()
	var tr: Array = []
	for t in fase.get("tracos", []):
		if t.has("pts") and t["pts"].size() >= 4:
			tr.append(t)
	# o k que deixa os traços mais curtos
	var k := 2
	var melhor := -1
	for kk in 7:
		var tt := 0
		for x in tr:
			var pts: Array = x["pts"]
			for i in range(2, pts.size()):
				tt += tam_eg(zz(int(pts[i]) - int(pts[i - 2])), kk)
		if melhor < 0 or tt < melhor:
			melhor = tt
			k = kk
	# o fantasma pode ter zero toques (a descida sem encostar no dedo também é uma descida)
	var fant = fase.get("fantasma", null)
	var tem_fant: bool = fant is Array
	w.n(1 if tem_fant else 0, 1)
	w.n(0, 3)
	var autor = fase.get("autor", "")
	w.txt(autor if autor is String else "")
	w.n(k, 3)
	w.eg(tr.size(), 2)
	for t in tr:
		var pts: Array = t["pts"]
		w.n(int(t.get("cor", 0)) & 3, 2)
		@warning_ignore("integer_division")
		w.eg(pts.size() / 2 - 2, 3)
		w.n(int(pts[0]), 9)
		w.n(int(pts[1]), 13)
		for i in range(2, pts.size()):
			w.sz(int(pts[i]) - int(pts[i - 2]), k)
	var cs: Array = fase.get("carimbos", [])
	w.eg(cs.size(), 1)
	for c in cs:
		var ti: int = Nucleo.TIPOS.find(c["tipo"])
		w.n(ti, 2)
		w.n(int(c["x"]), 9)
		w.n(int(c["y"]), 13)
		if ti == 1:
			w.n(int(c.get("dir", 0)) & 15, 4)
	var co_todo: Array = fase.get("corrente", [])
	if co_todo == null:
		co_todo = []
	var co: Array = co_todo.slice(maxi(0, co_todo.size() - CORRENTE_MAX))
	w.n(co.size(), 3)
	for c in co:
		var nm = c.get("nome", "")
		w.txt(nm if nm is String else "")
		w.eg(int(c["cs"]), 9)
	if tem_fant:
		var f: Array = fant
		w.eg(f.size(), 2)
		var a := 0
		for nn in f:
			w.eg(int(nn) - a, 4)
			a = int(nn)
	w.n(soma12(w.b, w.b.size()), 12)
	var s := PREFIXO
	var i := 0
	var bb := w.b
	while i < bb.size():
		var v := 0
		for j in 6:
			v = v * 2 + (bb[i + j] if i + j < bb.size() else 0)
		s += ALFA[v]
		i += 6
	return s


## Devolve a fase ou null (código quebrado, cortado ou de outra versão).
static func decodifica(cod) -> Variant:
	if not (cod is String):
		return null
	var c: String = cod
	if c.substr(0, 3) != PREFIXO or c.length() > 12000:
		return null
	var bits := PackedByteArray()
	for i in range(3, c.length()):
		var v := ALFA.find(c[i])
		if v < 0:
			return null
		var j := 5
		while j >= 0:
			bits.append((v >> j) & 1)
			j -= 1
	var r := Le.new(bits)
	var tem_fant := r.n(1)
	r.n(3)
	var autor := r.txt()
	var k := r.n(3)
	var nt := r.eg(2)
	if r.erro or nt > 400:
		return null
	var tracos: Array = []
	var tot := 0
	for i in nt:
		var cor := r.n(2)
		var np := r.eg(3) + 2
		if r.erro:
			return null
		tot += np
		if tot > 8000:
			return null
		var px := r.n(9)
		var py := r.n(13)
		var pts: Array = [px, py]
		for j in range(2, np * 2):
			pts.append(int(pts[j - 2]) + r.sz(k))
			if r.erro:
				return null
		var j := 0
		while j < pts.size():
			if pts[j] < 0 or pts[j] > Nucleo.LARG or pts[j + 1] < 0 or pts[j + 1] > Nucleo.ALT_MAX:
				return null
			j += 2
		tracos.append({"cor": cor, "pts": pts})
	var nc := r.eg(1)
	if r.erro or nc > 80:
		return null
	var carimbos: Array = []
	for i in nc:
		var ti := r.n(2)
		var cx := r.n(9)
		var cy := r.n(13)
		var cb := {"tipo": Nucleo.TIPOS[ti], "x": cx, "y": cy}
		if ti == 1:
			cb["dir"] = r.n(4)
		if r.erro:
			return null
		if cb["x"] > Nucleo.LARG or cb["y"] > Nucleo.ALT_MAX:
			return null
		carimbos.append(cb)
	var nco := r.n(3)
	if r.erro or nco > CORRENTE_MAX:
		return null
	var corrente: Array = []
	for i in nco:
		var nome := r.txt()
		var cs := r.eg(9)
		if r.erro:
			return null
		corrente.append({"nome": nome, "cs": cs})
	var fantasma = null
	if tem_fant == 1:
		var ne := r.eg(2)
		if r.erro or ne > 4000:
			return null
		var f: Array = []
		var a := 0
		for i in ne:
			a += r.eg(4)
			if r.erro:
				return null
			f.append(a)
		fantasma = f
	var conta := soma12(bits, r.i)
	if r.n(12) != conta or r.erro:
		return null
	return {"autor": autor, "tracos": tracos, "carimbos": carimbos, "corrente": corrente, "fantasma": fantasma}


## A identidade da ladeira (só o desenho): o recorde de cada uma mora aqui. Igual ao idFase do JS.
static func id_fase(fase: Dictionary) -> String:
	var s := codifica({"autor": "", "tracos": fase.get("tracos", []), "carimbos": fase.get("carimbos", []), "corrente": [], "fantasma": null})
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xFFFFFFFF
		h = imul(h, 16777619) & 0xFFFFFFFF
	return base36(h)


static func base36(v: int) -> String:
	if v == 0:
		return "0"
	var d := "0123456789abcdefghijklmnopqrstuvwxyz"
	var s := ""
	while v > 0:
		s = d[v % 36] + s
		@warning_ignore("integer_division")
		v = v / 36
	return s


## Acha o primeiro código bom num texto (a mensagem inteira, o link ou só o código).
static func acha_codigo(txt: String) -> Variant:
	var re := RegEx.new()
	re.compile("dv1[A-Za-z0-9_-]+")
	for m in re.search_all(txt):
		var f = decodifica(m.get_string())
		if f != null:
			return f
	return null


## O nome como a página web limpa: só Latin-1 imprimível, espaços juntos, até 14 letras.
static func limpa_nome(s: String) -> String:
	var o := ""
	for i in s.length():
		var k := s.unicode_at(i)
		if (k >= 0x20 and k <= 0x7E) or (k >= 0xA0 and k <= 0xFF):
			o += String.chr(k)
	# \s+ vira um espaço (o espaço duro também é espaço) e tira das pontas
	var r := ""
	var esp := false
	for i in o.length():
		var k := o.unicode_at(i)
		if k == 0x20 or k == 0xA0:
			esp = true
		else:
			if esp and r != "":
				r += " "
			esp = false
			r += String.chr(k)
	return r.substr(0, NOME_MAX)
