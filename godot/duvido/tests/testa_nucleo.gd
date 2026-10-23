extends SceneTree
## Confere o porte do núcleo contra a versão web: roda o mesmo que tests/gera_esperado.mjs rodou no JS
## e compara tudo (o código de cada ladeira letra por letra, cada descida com o rastro a cada 120 passos,
## as idas e voltas do código do link, o nome limpo). Uso:
##   godot --headless --path . -s res://tests/testa_nucleo.gd
## Sai com 0 se bateu tudo.

var oks := 0
var falhas := 0
var detalhes: Array = []


func ok(c: bool, m: String) -> void:
	if c:
		oks += 1
	else:
		falhas += 1
		if detalhes.size() < 60:
			detalhes.append(m)
			print("FALHOU: ", m)


func hx(x: float) -> String:
	return PackedFloat64Array([x]).to_byte_array().hex_encode()


func hx_p(p: PackedFloat64Array) -> String:
	return hx(p[0]) + hx(p[1]) + hx(p[2]) + hx(p[3])


func ints(a) -> Array:
	var o: Array = []
	if a == null:
		return o
	for v in a:
		o.append(int(v))
	return o


func desce(F: Nucleo.Fase, ev: Array) -> Dictionary:
	var S := Nucleo.novo_estado(F)
	var j := 0
	var rastro: Array = []
	while S.fim == "":
		while j < ev.size() and int(ev[j]) <= S.passos:
			if j % 2 == 0:
				Nucleo.toca(S)
			else:
				Nucleo.solta(S)
			j += 1
		S.ev.clear()
		Nucleo.passo(F, S)
		if S.passos % 120 == 0:
			rastro.append(hx_p(S.p))
	var r := Nucleo.resumo(S)
	r["fimP"] = hx_p(S.p)
	r["fimV"] = hx_p(S.v)
	r["giro"] = hx(S.giro)
	r["rastro"] = rastro
	return r


## A fase vinda do JSON (os números do JSON viram float aqui; o código só quer inteiros).
func fase_de(j: Dictionary) -> Dictionary:
	var tr: Array = []
	for t in j["tracos"]:
		tr.append({"cor": int(t["cor"]), "pts": ints(t["pts"])})
	var cb: Array = []
	for c in j["carimbos"]:
		var d := {"tipo": c["tipo"], "x": int(c["x"]), "y": int(c["y"])}
		if c.has("dir"):
			d["dir"] = int(c["dir"])
		cb.append(d)
	var co: Array = []
	for c in j.get("corrente", []):
		co.append({"nome": c["nome"], "cs": int(c["cs"])})
	var fa = null
	if j.get("fantasma", null) != null:
		fa = ints(j["fantasma"])
	return {"autor": j.get("autor", ""), "tracos": tr, "carimbos": cb, "corrente": co, "fantasma": fa}


func igual_fase(a, b) -> bool:
	if a == null or b == null:
		return a == null and b == null
	if a["autor"] != b["autor"]:
		return false
	if a["tracos"].size() != b["tracos"].size() or a["carimbos"].size() != b["carimbos"].size():
		return false
	for i in a["tracos"].size():
		if int(a["tracos"][i]["cor"]) != int(b["tracos"][i]["cor"]) or ints(a["tracos"][i]["pts"]) != ints(b["tracos"][i]["pts"]):
			return false
	for i in a["carimbos"].size():
		var x: Dictionary = a["carimbos"][i]
		var y: Dictionary = b["carimbos"][i]
		if x["tipo"] != y["tipo"] or int(x["x"]) != int(y["x"]) or int(x["y"]) != int(y["y"]) or int(x.get("dir", -1)) != int(y.get("dir", -1)):
			return false
	var ca: Array = a.get("corrente", [])
	var cb: Array = b.get("corrente", [])
	if ca.size() != cb.size():
		return false
	for i in ca.size():
		if ca[i]["nome"] != cb[i]["nome"] or int(ca[i]["cs"]) != int(cb[i]["cs"]):
			return false
	return (a["fantasma"] == null) == (b["fantasma"] == null) and ints(a["fantasma"]) == ints(b["fantasma"])


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var f := FileAccess.open("res://tests/esperado.json", FileAccess.READ)
	var E: Dictionary = JSON.parse_string(f.get_as_text())
	var n_desc := 0
	var n_passos := 0
	# 1. as cinco da casa: o código de cada uma, letra por letra
	var prontas := Fases.prontas()
	var por_nome := {}
	for i in prontas.size():
		por_nome["pronta" + str(i)] = prontas[i]["fase"]
	# 2. a ladeira do dia de vários dias
	for d in E["dias"]:
		var dia := {"a": int(d["dia"]["a"]), "m": int(d["dia"]["m"]), "d": int(d["dia"]["d"])}
		var lf := Fases.ladeira_do_dia(dia)
		var nome := "dia%d-%d-%d" % [dia["a"], dia["m"], dia["d"]]
		por_nome[nome] = lf
		ok(Codigo.codifica(lf) == d["cod"], nome + ": o código da ladeira do dia é igual ao da web")
		ok((d["par"] == null and not lf.has("par")) or (lf.has("par") and int(lf["par"]) == int(d["par"])), nome + ": o tempo da casa (par) é igual (" + str(lf.get("par")) + " / " + str(d["par"]) + ")")
		ok(ints(lf.get("robo", [])) == ints(d["robo"]), nome + ": os toques do robô são iguais")
	# 3. cada ladeira: o código, a identidade e todas as descidas
	for fj in E["fases"]:
		var nome: String = fj["nome"]
		var fase: Dictionary
		if por_nome.has(nome):
			fase = por_nome[nome]
		else:
			fase = _monta_sorteada(nome)
		var cod := Codigo.codifica(fase)
		ok(cod == fj["cod"], nome + ": o código é igual, letra por letra" + ("" if cod == fj["cod"] else " (" + cod.substr(0, 60) + "... vs " + str(fj["cod"]).substr(0, 60) + "...)"))
		ok(Codigo.id_fase(fase) == fj["id"], nome + ": a identidade (o recorde mora nela) é igual (" + Codigo.id_fase(fase) + " / " + str(fj["id"]) + ")")
		var F := Nucleo.compila(fase)
		ok(hx(F.y_max) == hx(float(fj["yMax"])) and F.n == int(fj["n"]), nome + ": a fase compilada tem os mesmos segmentos")
		for dj in fj["descidas"]:
			var r := desce(F, ints(dj["ev"]))
			n_desc += 1
			n_passos += int(r["passos"])
			var k: String = dj["k"]
			var cs_esp: int = -1 if dj["cs"] == null else int(dj["cs"])
			var bate: bool = r["motivo"] == dj["motivo"] and int(r["cs"]) == cs_esp and int(r["passos"]) == int(dj["passos"]) and int(r["cambalhotas"]) == int(dj["cambalhotas"])
			var rastro_ok: bool = r["rastro"] == Array(dj["rastro"])
			var bits_ok: bool = r["fimP"] == dj["fimP"] and r["fimV"] == dj["fimV"] and r["giro"] == dj["giro"]
			var onde := ""
			if not rastro_ok:
				for i in mini(r["rastro"].size(), dj["rastro"].size()):
					if r["rastro"][i] != dj["rastro"][i]:
						onde = " (o rastro separa no passo %d)" % ((i + 1) * 120)
						break
			ok(bate and rastro_ok and bits_ok, "%s/%s: %s %s em %d passos (web: %s %s em %d)%s" % [nome, k, r["motivo"], str(r["cs"]), r["passos"], dj["motivo"], str(dj["cs"]), int(dj["passos"]), onde])
			if dj.has("robo"):
				var rb := Fases.desce_robo(F, float(k.substr(4)))
				ok(ints(rb["ev"]) == ints(dj["ev"]) and int(rb["r"]["cs"]) == (-1 if dj["robo"]["cs"] == null else int(dj["robo"]["cs"])), nome + "/" + k + ": o robô dá os mesmos toques")
		var sj: Dictionary = fj["simula"]
		var rs := Nucleo.simula(F, sj["toques"])
		ok(rs["motivo"] == sj["motivo"] and int(rs["cs"]) == (-1 if sj["cs"] == null else int(sj["cs"])) and int(rs["passos"]) == int(sj["passos"]), nome + ": simula com toques em segundos bate (" + str(rs["motivo"]) + " " + str(rs["passos"]) + ")")
	# 4. o código do link: autores com acento, corrente comprida, fantasma
	var n_cod := 0
	for cj in E["codigos"]:
		var fe := fase_de(cj["entrada"])
		var cod := Codigo.codifica(fe)
		n_cod += 1
		ok(cod == cj["cod"], "código %d: o Godot escreve o mesmo código da web (%s)" % [n_cod, fe["autor"]])
		ok(Codigo.id_fase(fe) == cj["id"], "código %d: a identidade é igual" % n_cod)
		var dec = Codigo.decodifica(cj["cod"])
		ok(igual_fase(dec, fase_de(cj["dec"]) if cj["dec"] != null else null), "código %d: o código da web abre aqui com tudo igual" % n_cod)
		if dec != null:
			ok(Codigo.codifica(dec) == cj["recod"], "código %d: ida e volta dá o mesmo código" % n_cod)
	for ij in E["invalidos"]:
		var dec = Codigo.decodifica(ij["cod"])
		ok(igual_fase(dec, fase_de(ij["dec"]) if ij["dec"] != null else null), "código quebrado '%s...': o Godot responde igual à web (%s)" % [str(ij["cod"]).substr(0, 12), "abre" if ij["dec"] != null else "não abre"])
	# as cinco da casa e as do dia, ida e volta
	for nome in por_nome:
		var cod := Codigo.codifica(por_nome[nome])
		var dec = Codigo.decodifica(cod)
		ok(dec != null and Codigo.codifica(dec) == cod, nome + ": ida e volta do código")
	# 5. o nome limpo
	for nj in E["nomes"]:
		ok(Codigo.limpa_nome(nj["de"]) == nj["pra"], "nome '%s' vira '%s' (web: '%s')" % [nj["de"], Codigo.limpa_nome(nj["de"]), nj["pra"]])
	var ms := Time.get_ticks_msec() - t0
	print("descidas comparadas: %d (%d passos de física), códigos: %d, tempo: %d ms" % [n_desc, n_passos, n_cod, ms])
	print("%d ok, %d falharam" % [oks, falhas])
	quit(1 if falhas > 0 else 0)


## As ladeiras "sorteadas" do teste (iguais às do gera_esperado.mjs).
func _monta_sorteada(nome: String) -> Dictionary:
	var sem := int(nome.substr(8))
	var r := Fases.Sorteio.new(sem)
	var tracos: Array = []
	var carimbos: Array = []
	var x := 128
	var y := 150
	for k in 7:
		var pts: Array = [x, y]
		var dir := -1 if k % 2 != 0 else 1
		var n := 3 + int(floorf(r.r() * 9.0))
		for i in n:
			x = maxi(0, mini(420, x + dir * (10 + int(floorf(r.r() * 40.0)))))
			y = mini(5200, y + int(floorf(r.r() * 30.0)) - 4)
			pts.append(x)
			pts.append(y)
		tracos.append({"cor": int(floorf(r.r() * 4.0)), "pts": pts})
		if r.r() < 0.5:
			carimbos.append({"tipo": "mola", "x": maxi(20, mini(400, x - dir * 60)), "y": y - 3})
		if r.r() < 0.5:
			var tx := maxi(20, mini(400, x - dir * 100))
			carimbos.append({"tipo": "turbo", "x": tx, "y": y - 16, "dir": int(floorf(r.r() * 16.0))})
		if r.r() < 0.4:
			carimbos.append({"tipo": "cachorro", "x": maxi(40, mini(380, x - dir * 140)), "y": y})
		y += 70 + int(floorf(r.r() * 50.0))
		x = maxi(0, mini(420, x - dir * 20))
	carimbos.append({"tipo": "chegada", "x": x, "y": y - 70})
	return {"autor": "Teste", "tracos": tracos, "carimbos": carimbos, "corrente": [], "fantasma": null}
