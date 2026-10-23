extends SceneTree
## O teste sem tela: em cada fase monta uma gambiarra conhecida (tiradas das soluções da versão web
## e acertadas pra física da Godot), aperta VAI! e confere que a laranja chega no alvo e que os
## pontos certos acontecem. Roda cada gambiarra 3 vezes pra ver que dá sempre igual.
##   godot --headless --path . --fixed-fps 60 -s res://tests/teste_fases.gd

const CASOS := [
	{ "nome": "cozinha: o gato liga o rádio", "fase": 0,
		"pecas": [["colchao", 226, 701, 0.33, 1], ["gato", 580, 513, 0.0, -1]],
		"quem": "gato", "eventos": ["Boing!", "Assustou o gato", "Ligou o rádio!", "O gato ligou o rádio"] },
	{ "nome": "cozinha: tábua, colchão, PET e gato", "fase": 0,
		"pecas": [["colchao", 238, 702, 0.43, 1], ["gato", 589, 504, 0.0, -1], ["garrafa", 140, 697, 0.03, 1], ["tabua", 110, 289, 0.18, 1]],
		"quem": "laranja", "eventos": ["Boing!", "Ligou o rádio!"] },
	{ "nome": "laje: o caramelo liga o som com o pedido completo", "fase": 1,
		"pecas": [["caramelo", 110, 108, 0.0, 1], ["tabua", 234, 330, 0.37, 1], ["garrafa", 278, 301, -0.07, 1], ["gangorra", 428, 471, 0.0, 1], ["bacia", 417, 320, 3.15, 1]],
		"quem": "caramelo", "pedido": 4,
		"eventos": ["Acordou o caramelo", "Pedido: latido", "Pedido: agogô", "Pedido: surdo", "Pedido: cuíca", "Gangorra", "Ligou o som!", "O caramelo ligou o som"],
		"conta": "Pedido completo" },
	{ "nome": "garagem: o limpador segura a levada", "fase": 2,
		"pecas": [["tabua", 363, 320, -0.32, 1], ["limpador", 258, 383, 1.64, 1], ["balde", 162, 478, -0.07, 1], ["balde", 342, 492, 0.01, 1], ["lata", 589, 846, 0.0, 1]],
		"quem": "laranja", "levada": true,
		"eventos": ["Ligou o limpador", "Batucou no balde", "No tempo", "Levada!", "Ligou o amplificador!"],
		"conta": "Levada completa" },
]

var jogo: Jogo
var falhas := 0
var oks := 0


func _initialize() -> void:
	_roda.call_deferred()


func confere(cond: bool, txt: String) -> void:
	if cond:
		oks += 1
		print("  ok: ", txt)
	else:
		falhas += 1
		print("  FALHOU: ", txt)


func _roda_caso(c: Dictionary) -> Dictionary:
	jogo.vai_fase(int(c.fase))
	jogo.do_zero()
	var postas := 0
	for pz in c.pecas:
		if jogo.poe(pz[0], pz[1], pz[2], pz[3], int(pz[4])):
			postas += 1
	jogo.roda()
	var max_passos := 0
	for i in range(2400):
		await physics_frame
		max_passos = jogo.passos
		if not jogo.rodando():
			break
	await physics_frame
	var e := jogo.estado()
	e["postas"] = postas
	e["resumo"] = jogo.resumo.duplicate(true)
	e["gravado"] = jogo.gravado.duplicate(true)
	e["pecas_total"] = c.pecas.size()
	jogo.ajeita()
	await physics_frame
	return e


func _roda() -> void:
	Salva.esquece_tudo()
	jogo = Jogo.new()
	root.add_child(jogo)
	await process_frame

	print("# a tralha parada")
	jogo.vai_fase(0)
	jogo.do_zero()
	confere(jogo.poe("tabua", 300, 450, 0.0), "põe uma tábua num lugar livre")
	confere(not jogo.poe("tabua", 310, 452, 0.0), "não deixa pôr outra tábua em cima dela")
	confere(not jogo.poe("tabua", 345, 300, 0.0), "não deixa pôr dentro do armário")
	confere(not jogo.poe("tabua", 20, 450, 0.0), "não deixa pôr pra fora da parede")
	confere(int(jogo.estoque.tabua) == 2, "a caixa ficou com 2 tábuas")
	var p: Peca = jogo.pecas[0]
	jogo.gira(p, 1)
	confere(absf(p.a - PI / 12.0) < 1e-4, "girou 15 graus")
	jogo.devolve(p)
	confere(jogo.pecas.is_empty() and int(jogo.estoque.tabua) == 3, "devolveu pra caixa")
	var g := jogo.auto_poe("gato")
	confere(g != null and jogo.cabe(g), "tocar no gato põe ele num lugar livre")
	jogo.gira(g, -1)
	confere(g.flip == -1, "o gato vira pro outro lado")
	confere(jogo.auto_poe("gato") == null, "acabou o gato da caixa")
	jogo.do_zero()

	for c in CASOS:
		print("# ", c.nome)
		var res: Array = []
		for vez in range(3):
			res.append(await _roda_caso(c))
		var e: Dictionary = res[0]
		confere(int(e.postas) == int(e.pecas_total), "todas as peças couberam (%d)" % e.postas)
		confere(e.ganhou, "a laranja levou a corrente até o alvo (modo %s, laranja em %s)" % [e.modo, str(e.laranja)])
		confere(str(e.quem) == str(c.quem), "quem ligou: %s (esperado %s)" % [e.quem, c.quem])
		var tem: Array = []
		for ev in e.eventos:
			tem.append(ev.rsplit(" ", true, 1)[0])
		for ev in c.eventos:
			confere(ev in tem, "aconteceu: " + ev)
		if c.has("pedido"):
			confere(e.pedido.size() == int(c.pedido), "o churrasco recebeu o pedido inteiro: " + ",".join(e.pedido))
		if c.has("levada"):
			confere(e.levada_ok and int(e.melhor_seq) >= 4, "a levada saiu: %d batidas no tempo seguidas" % e.melhor_seq)
			# o limpador bate no balde em cima da batida: toda batida de balde cai numa semicolcheia múltipla de 4
			var baldes := 0
			var no_tempo := 0
			for gv in e.gravado:
				if gv.inst == "balde":
					baldes += 1
					if int(gv.passo) % 4 == 0:
						no_tempo += 1
			confere(no_tempo >= 4, "o limpador bate nos baldes em cima da batida (%d de %d batidas de balde no tempo)" % [no_tempo, baldes])
		var r: Dictionary = e.resumo
		confere(r.get("ok", false) and r.get("carimbo", "") == "FUNCIONOU!", "o cartão do fim diz FUNCIONOU!")
		confere(int(r.get("total", 0)) > int(e.pts), "o total multiplica os pontos (%d → %d)" % [e.pts, r.get("total", 0)])
		if c.has("conta"):
			var achou := false
			for li in r.get("conta", []):
				if li.txt == c.conta:
					achou = true
			confere(achou, "a conta tem: " + c.conta)
		confere(e.batidas.size() >= 6, "a gambiarra gravou um beat (%d batidas)" % e.batidas.size())
		var igual := true
		for k in range(1, 3):
			if res[k].eventos != e.eventos or res[k].pts != e.pts or res[k].batidas != e.batidas:
				igual = false
		confere(igual, "3 vezes, sempre igual (%d pontos)" % e.pts)
		print("    eventos: ", " · ".join(e.eventos))

	print("# o recorde ficou guardado")
	confere(int(Salva.le("recorde-1", 0)) > 0 and int(Salva.le("recorde-2", 0)) > 0 and int(Salva.le("recorde-3", 0)) > 0, "recorde das 3 fases")
	Salva.esquece_tudo()
	print("\nRESULTADO: %d ok, %d falhas" % [oks, falhas])
	quit(1 if falhas > 0 else 0)
