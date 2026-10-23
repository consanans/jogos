class_name Comandos
extends RefCounted
## Comandos pros testes (o motor de verdade sendo dirigido de fora): no roteiro da linha de comando
## e, na versão do navegador, pela fila window.__duvidoCmd. Nada disso aparece pra quem joga.


static func executa(p: Principal, s: String) -> void:
	var k := s.get_slice(":", 0)
	var arg := s.substr(k.length() + 1)
	match k:
		"joga":
			var pr: Dictionary = Fases.prontas()[int(arg)]
			p.joga_fase(pr["fase"], "pronta", {"i": int(arg)})
		"dia":
			var d := p.do_dia()
			p.joga_fase(d, "dia", {"dia": d["dia"]})
		"editor":
			p.abre_editor()
		"editor_pronta":
			p.abre_editor(Fases.prontas()[int(arg)]["fase"])
		"inicio":
			p.mostra_inicio()
		"toca":
			p.apertou()
		"solta":
			p.soltou()
		"agenda":
			var l: Array = []
			for par in arg.split(","):
				l.append({"n": int(par.get_slice("/", 0)), "k": int(par.get_slice("/", 1))})
			if p.jogo != null:
				p.jogo.agenda = l
		"ferr":
			p.escolhe_ferr(arg)
		"risca":
			var v := arg.split(",")
			var pts: Array = []
			for j in range(0, v.size(), 2):
				pts.append(Vector2(float(v[j]), float(v[j + 1])))
			p.ed_down(7, _tela(p, pts[0]), MOUSE_BUTTON_LEFT)
			for j in range(1, pts.size()):
				for q in range(1, 7):
					var w: Vector2 = pts[j - 1].lerp(pts[j], q / 6.0)
					p.ed_move(7, _tela(p, w), true)
			p.ed_up(7)
		"tap":
			var v := arg.split(",")
			var t := _tela(p, Vector2(float(v[0]), float(v[1])))
			p.ed_down(8, t, MOUSE_BUTTON_LEFT)
			p.ed_up(8)
		"testa":
			p.testa_editor()
		"nome":
			p.nome = arg
		"desafio":
			p.abre_codigo(arg)
		"descer":
			if p.desafio != null:
				p.joga_fase(p.desafio, "desafio", {})
		"fim":
			p.mostra_fim()
		"manda":
			p._f_manda()


static func _tela(p: Principal, w: Vector2) -> Vector2:
	return Vector2(p.mundo.COLX + w.x * p.mundo.K, (w.y - p.cam_y) * p.mundo.K)
