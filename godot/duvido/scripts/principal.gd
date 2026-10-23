class_name Principal
extends Node
## O Duvido inteiro: as telas, a descida, o editor, o desafio que chegou, o resultado, a mensagem pro amigo.
## Porte do jogo.js da versão web. A física e o código do link moram em Nucleo, Codigo e Fases;
## o desenho em Mundo; o som em Som; o que fica no aparelho em Dados.

const TINTA_MAX := 4200.0
const LIM := {"mola": 8, "turbo": 8, "cachorro": 8, "chegada": 1}
const CARTOES := ["inicio", "desafio", "cola", "nome", "fim", "manda"]
const PULA := [KEY_SPACE, KEY_UP, KEY_W, KEY_X, KEY_K]
const TITULO := {"capotou": "CAPOTOU!", "torto": "CAPOTOU!", "cachorro": "CAPOTOU!", "barranco": "BARRANCO!", "caiu": "DESPENCOU!", "empacou": "EMPACOU!", "tempo": "DEMOROU!"}
const FRASES := {
	"capotou": ["Beijou o asfalto.", "O balde aguentou. Tu, nem tanto.", "Ralou até a alma.", "Capacete de balde salvou."],
	"torto": ["Pousou de cara no chão.", "Pousou torto demais.", "Faltou girar mais um tiquinho."],
	"cachorro": ["O caramelo não deixou.", "Cachorro do vizinho: 1. Tu: 0.", "Ele só queria brincar."],
	"barranco": ["Saiu da pista.", "Foi pro mato.", "O barranco agradece a visita."],
	"caiu": ["Lá embaixo não tem nada.", "Faltou chão."],
	"empacou": ["Parou no meio do caminho.", "Sem embalo não desce."],
	"tempo": ["Dois minutos e nada."],
}


class Vis:
	var giro := 0.0
	var lado := 1.0
	var pose := 0
	var ar_t := 0.0


class Jogo:
	var fase: Dictionary
	var F: Nucleo.Fase
	var origem := ""
	var extra: Dictionary = {}
	var id := ""
	var titulo := ""
	var S: Nucleo.Estado
	var G: Nucleo.Estado = null
	var g_ev = null
	var g_nome := ""
	var gj := 0
	var g_alfa := 0.42
	var ev: Array = []
	var sessao = null
	var tentativas := 0
	var vis := Vis.new()
	var g_vis := Vis.new()
	var fim_t := 0.0
	var pode_reiniciar := false
	var mostrou_fim := false
	var latiu: Array = []
	var mola_t: Array = []
	var po_t := 0.0
	var agenda: Array = []
	var ultimo: Dictionary = {}
	var recorde := false
	var antes = null


class Demo:
	var F: Nucleo.Fase
	var fase: Dictionary
	var S: Nucleo.Estado
	var ev = null
	var jj := 0
	var espera := 0.0
	var vis := Vis.new()
	var cam := 0


class Editor:
	var tracos: Array = []
	var carimbos: Array = []
	var ferr := "lapis"
	var cor := 0
	var desfaz: Array = []
	var cam_y := -40.0
	var validado = null
	var melhor = null
	var traco = null          # {cor, pts, len, t0}
	var gesto = null          # {k, i, antes, mexeu, novo}
	var dedos := {}           # id -> Vector2 (tela)
	var pan = null            # {y, cam}
	var tela_pt = null        # Vector2 (tela) do dedo que risca
	var cursor = null         # Vector2 (mundo)
	var risca := 0.0
	var dica_t := 0.0
	var id := ""


# ---------------------------------------------------------------- o estado
var tela := "inicio"
var jogo: Jogo = null
var demo: Demo = null
var desafio = null
var cam_y := -40.0
var tempo := 0.0
var tremor := 0.0
var acc := 0.0
var alfa := 0.0
var fila: Array = []
var nome := ""
var recs := {}
var fants := {}
var casa := {}
var dia_fase = null
var ed := Editor.new()
var parado: Nucleo.Estado = null
var parado_F = null
var tinta_cache := 0.0
var manda = null              # {msg, volta}
var depois_do_nome: Callable = Callable()
var volta_do_nome = null
var dedos_jogo := {}
var teclas_jogo := {}
var tira_dedo = null
var aviso_t := 0.0
var carimbo_t := 0.0
var rascunho_t := -1.0
var salva_t := 0.0
var trabalho = null
var cartao_atual = null

# a tela
var P := 1.846
var dedo_tela := false
var tam := Vector2(720, 1280)

# os nós
var mundo: Mundo
var som: Som
var camada: CanvasLayer
var ui: Control
var area: Control
var coluna: Control
var hud: Control
var relogio: RichTextLabel
var alvo: RichTextLabel
var b_som: Array = []
var dica_jogo: Control
var dica_tx: RichTextLabel
var carimbo_no: PanelContainer
var car_t: Label
var car_s: Label
var pos_no: Control
var pos_tx: Label
var p_editor: Button
var ed_topo: Control
var tinta_lbl: Label
var tinta_bar: Control
var tinta_frac := 1.0
var e_manda: Button
var ed_ferr: Control
var ferr_bts := {}
var cores_no: Control
var cor_bts: Array = []
var ed_dica: Label
var apaga_tudo: Control
var veu: Control
var cartoes := {}
var aviso_no: PanelContainer
var aviso_lbl: Label
var campo_nome: LineEdit
var campo_cola: TextEdit
var erro_nome: Label
var erro_cola: Label
var ok_copia: Label
var alvos := {}               # os botões que os testes tocam (nome -> Control)
var web_t := 0.0


# ---------------------------------------------------------------- começa
func _ready() -> void:
	Estilo.carrega()
	Texturas.prepara()
	Dados.carrega()
	nome = Codigo.limpa_nome(str(Dados.le("nome", "")))
	var r = Dados.le("recs", {})
	if r is Dictionary:
		for k in r:
			recs[k] = int(r[k])
	var fa = Dados.le("fant", {})
	if fa is Dictionary:
		for k in fa:
			if fa[k] is Array:
				fants[k] = _ints(fa[k])
	var cs = Dados.le("casa", {})
	if cs is Dictionary:
		casa = cs
	_le_rascunho()
	dedo_tela = DisplayServer.is_touchscreen_available()
	som = Som.new()
	add_child(som)
	som.liga(str(Dados.le("som", "1")) != "0")
	mundo = Mundo.new()
	mundo.j = self
	add_child(mundo)
	camada = CanvasLayer.new()
	camada.layer = 1
	add_child(camada)
	get_viewport().size_changed.connect(_mudou_tamanho)
	_mede()
	_monta_ui()
	# o desafio que veio no link (na versão pro navegador)
	var h := _hash_web()
	if not (h != "" and abre_codigo(h)):
		mostra_inicio()
		if h != "":
			aviso("Esse link veio quebrado. Pede pro amigo mandar de novo.", 3.5)
	_ouve_hash_web()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--roteiro="):
			var rot: Node = load("res://tests/roteiro.gd").new()
			add_child(rot)


func _ints(a: Array) -> Array:
	var o: Array = []
	for v in a:
		o.append(int(v))
	return o


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Dados.salva(true)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not dedos_jogo.is_empty():
			dedos_jogo.clear()
			soltou()
		teclas_jogo.clear()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_volta_android()


func _volta_android() -> void:
	if tela == "jogo":
		sai_do_jogo()
	elif tela == "editor":
		mostra_inicio()
	elif cartao_atual != null and cartao_atual != "inicio":
		mostra_inicio()


# ---------------------------------------------------------------- a tela
func _mede() -> void:
	tam = get_viewport().get_visible_rect().size
	P = minf(tam.x / 390.0, tam.y / 844.0)
	if tam.x <= tam.y:
		P = tam.x / 390.0
	Estilo.P = P
	mundo.mede(tam, P)


func _mudou_tamanho() -> void:
	var antes := P
	var t0 := tam
	_mede()
	if absf(P - antes) > 0.001 or t0 != tam:
		Estilo.limpa_cache()
		_monta_ui()
		_reconstroi_tela()
	if tela == "editor":
		rola_editor(0)


func _reconstroi_tela() -> void:
	mostra_ui()
	if tela == "editor":
		escolhe_ferr(ed.ferr, true)
		atualiza_tinta()
		atualiza_manda()
	if tela == "jogo" and jogo != null:
		atualiza_alvo()
	var c = cartao_atual
	if c == null:
		so_cartao(null)
		return
	match c:
		"inicio":
			_cartao_inicio()
		"desafio":
			_cartao_desafio()
		"cola":
			_cartao_cola()
		"nome":
			_cartao_nome(volta_do_nome["olho"] if volta_do_nome != null else "Teu nome")
		"fim":
			mostra_fim()
			return
		"manda":
			_cartao_manda()
	so_cartao(c)


# ---------------------------------------------------------------- formatos
func pf(v: float) -> float:
	return Estilo.pf(v)


func px(v: float) -> int:
	return Estilo.px(v)


func fmt2(cs: int) -> String:
	@warning_ignore("integer_division")
	return str(cs / 100) + "," + "%02d" % (cs % 100)


func fmt1(cs: int) -> String:
	var q := int(Nucleo.js_round(float(cs) / 10.0))
	@warning_ignore("integer_division")
	return str(q / 10) + "," + str(q % 10)


func fmt_dif(c: int) -> String:
	return (fmt1(c) if c >= 10 else fmt2(c)) + " s"


func dd(n: int) -> String:
	return "%02d" % n


func cor_de(s: String) -> int:
	var h := 7
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) % 9973
	return h


func esc(s: String) -> String:
	return s.replace("[", "[lb]")


# ---------------------------------------------------------------- a casa (o robô) e a ladeira do dia
func tempo_casa(i: int):
	var p: Dictionary = Fases.prontas()[i]
	var id := Codigo.id_fase(p["fase"])
	if casa.has(id):
		var c: Dictionary = casa[id]
		return {"cs": int(c["cs"]), "ev": _ints(c["ev"])}
	var F := Nucleo.compila(p["fase"])
	var best = null
	for antes in [0.28, 0.32, 0.36, 0.4]:
		var x := Fases.desce_robo(F, antes)
		if x["r"]["chegou"] and (best == null or int(x["r"]["cs"]) < int(best["cs"])):
			best = {"cs": int(x["r"]["cs"]), "ev": x["ev"]}
	if best != null:
		casa[id] = best
		Dados.guarda("casa", casa)
	return best


## O robô da casa trabalhando aos pouquinhos (uns milissegundos por quadro), pra o toque na ladeira ser na hora.
func _trabalha(ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t0) < ms * 1000.0:
		if trabalho == null:
			var achou := false
			for i in Fases.prontas().size():
				var id := Codigo.id_fase(Fases.prontas()[i]["fase"])
				if not casa.has(id):
					trabalho = {"i": i, "id": id, "k": 0, "F": Nucleo.compila(Fases.prontas()[i]["fase"]), "S": null, "ev": [], "best": null}
					achou = true
					break
			if not achou:
				return
		var T: Dictionary = trabalho
		if casa.has(T["id"]):
			trabalho = null
			continue
		var F: Nucleo.Fase = T["F"]
		var antes: float = [0.28, 0.32, 0.36, 0.4][T["k"]]
		if T["S"] == null:
			T["S"] = Nucleo.novo_estado(F)
			T["ev"] = []
		var S: Nucleo.Estado = T["S"]
		for n in 60:
			if S.fim != "":
				break
			var a := Fases.piloto(F, S, antes)
			if a == 1:
				Nucleo.toca(S)
				T["ev"].append(S.passos)
			elif a == 0:
				Nucleo.solta(S)
				T["ev"].append(S.passos)
			S.ev.clear()
			Nucleo.passo(F, S)
		if S.fim != "":
			if S.fim == "chegou" and (T["best"] == null or S.fim_cs < int(T["best"]["cs"])):
				T["best"] = {"cs": S.fim_cs, "ev": T["ev"]}
			T["k"] += 1
			T["S"] = null
			if T["k"] >= 4:
				if T["best"] != null:
					casa[T["id"]] = T["best"]
					Dados.guarda("casa", casa)
				trabalho = null


func do_dia() -> Dictionary:
	var d := Fases.dia_hoje()
	if dia_fase == null or dia_fase["dia"]["d"] != d["d"] or dia_fase["dia"]["m"] != d["m"] or dia_fase["dia"]["a"] != d["a"]:
		var chave := "%d-%d-%d" % [d["a"], d["m"], d["d"]]
		var guardado = Dados.le("dia", {})
		if guardado is Dictionary and guardado.get("chave", "") == chave:
			var f = Codigo.decodifica(str(guardado["cod"]))
			if f != null:
				f["autor"] = "Ladeira do dia"
				f["dia"] = d
				if guardado.get("par", null) != null:
					f["par"] = int(guardado["par"])
					f["robo"] = _ints(guardado["robo"])
				dia_fase = f
				return dia_fase
		dia_fase = Fases.ladeira_do_dia(d)
		Dados.guarda("dia", {"chave": chave, "cod": Codigo.codifica(dia_fase), "par": dia_fase.get("par", null), "robo": dia_fase.get("robo", [])})
	return dia_fase


# ---------------------------------------------------------------- os cartões e os avisos
func so_cartao(id, foco := "") -> void:
	for c in cartoes:
		cartoes[c].visible = c == id
	veu.visible = id != null
	cartao_atual = id
	if id != null and cartoes.has(id):
		var sc: ScrollContainer = cartoes[id].get_meta("scroll")
		sc.scroll_vertical = 0
		_ajusta_cartao()
		if foco != "" and not dedo_tela:
			var f: Control = null
			if foco == "nome":
				f = campo_nome
			elif foco == "cola":
				f = campo_cola
			if f != null:
				f.call_deferred("grab_focus")


func aviso(txt: String, seg := 2.6) -> void:
	aviso_lbl.text = txt
	aviso_no.visible = true
	aviso_t = seg
	aviso_no.reset_size()
	call_deferred("_poe_aviso")


func _poe_aviso() -> void:
	aviso_no.reset_size()
	var w := minf(aviso_no.get_combined_minimum_size().x, tam.x - Estilo.pf(32))
	aviso_no.size = Vector2(w, 0)
	aviso_no.reset_size()
	aviso_no.position = Vector2((tam.x - aviso_no.size.x) / 2.0, Estilo.pf(14))


func carimbo(txt: String, sub: String, tipo: String, seg := 0.0) -> void:
	car_t.text = txt
	car_s.text = sub
	car_s.visible = sub != ""
	var bg := Estilo.VERMELHO
	var fg := Color.WHITE
	var borda := Color.WHITE
	if tipo == "ok":
		bg = Estilo.AMARELO; fg = Estilo.TINTA; borda = Estilo.TINTA
	elif tipo == "vai":
		bg = Estilo.AZUL
	var sb := Estilo.caixa(bg, 12, 4, borda)
	Estilo.margens(sb, 12, 18, 8)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, Estilo.pf(9))
	carimbo_no.add_theme_stylebox_override("panel", sb)
	car_t.add_theme_color_override("font_color", fg)
	car_s.add_theme_color_override("font_color", fg)
	var tam_t := clampf(0.125 * tam.x / P, 38.0, 62.0)
	car_t.add_theme_font_size_override("font_size", Estilo.px(tam_t))
	carimbo_no.visible = true
	carimbo_no.modulate.a = 0.0
	carimbo_t = seg
	call_deferred("_bate_carimbo")


func _bate_carimbo() -> void:
	var maxw := mundo.COLW - Estilo.pf(32)
	car_t.autowrap_mode = TextServer.AUTOWRAP_OFF
	carimbo_no.custom_minimum_size = Vector2.ZERO
	carimbo_no.size = Vector2.ZERO
	carimbo_no.reset_size()
	var w := carimbo_no.get_combined_minimum_size().x
	if w > maxw:
		car_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		car_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		carimbo_no.size = Vector2(maxw, 0)
	carimbo_no.reset_size()
	var sz := carimbo_no.size
	carimbo_no.pivot_offset = sz / 2.0
	carimbo_no.position = Vector2(mundo.COLW / 2.0 - sz.x / 2.0, tam.y * 0.36 - sz.y / 2.0)
	carimbo_no.rotation = deg_to_rad(-7.0)
	carimbo_no.scale = Vector2(1.9, 1.9)
	carimbo_no.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(carimbo_no, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(carimbo_no, "modulate:a", 1.0, 0.2)


func mostra_ui() -> void:
	var jogando := tela == "jogo"
	var editando := tela == "editor"
	hud.visible = jogando
	ed_topo.visible = editando
	ed_ferr.visible = editando
	(ed_topo.get_meta("fundo") as Control).visible = editando
	(ed_ferr.get_meta("fundo") as Control).visible = editando
	cores_no.visible = editando and ed.ferr == "lapis"
	if not editando:
		ed_dica.visible = false
		apaga_tudo.visible = false
		mundo.giz_vivo([], 0)
	if not jogando:
		carimbo_no.visible = false
		pos_no.visible = false
		dica_jogo.visible = false
	DisplayServer.screen_set_keep_on(jogando or editando)


# ---------------------------------------------------------------- a entrada
func mostra_inicio() -> void:
	tela = "inicio"
	jogo = null
	_cartao_inicio()
	so_cartao("inicio")
	mostra_ui()
	var d := do_dia()
	inicia_demo(d, d.get("robo", null))


# ---------------------------------------------------------------- a demonstração atrás dos cartões
func inicia_demo(fase: Dictionary, eventos) -> void:
	var F := Nucleo.compila(fase)
	mundo.monta_cena(fase, F)
	demo = Demo.new()
	demo.F = F
	demo.fase = fase
	demo.S = Nucleo.novo_estado(F)
	demo.ev = eventos
	demo.cam = cor_de(nome if nome != "" else "demo")
	cam_y = -40.0


func passo_demo(dt: float) -> void:
	var D := demo
	if D == null:
		return
	if D.S.fim != "":
		D.espera += dt
		if D.espera > 1.4:
			D.S = Nucleo.novo_estado(D.F)
			D.jj = 0
			D.espera = 0.0
			D.vis = Vis.new()
	else:
		acc += dt
		var n := 0
		while acc >= Nucleo.PASSO and n < 30:
			if D.ev != null:
				var evs: Array = D.ev
				while D.jj < evs.size() and int(evs[D.jj]) <= D.S.passos:
					if D.jj % 2 == 0:
						Nucleo.toca(D.S)
					else:
						Nucleo.solta(D.S)
					D.jj += 1
			else:
				var a := Fases.piloto(D.F, D.S)
				if a == 1:
					Nucleo.toca(D.S)
				elif a == 0:
					Nucleo.solta(D.S)
			D.S.ev.clear()
			Nucleo.passo(D.F, D.S)
			acc -= Nucleo.PASSO
			n += 1
			if D.S.fim != "":
				break
		if n >= 30:
			acc = 0.0
	passo_vis(D.vis, D.S, dt)
	seguir(D.S, dt, 1.0 if D.S.fim != "" else acc / Nucleo.PASSO)


# ---------------------------------------------------------------- a descida
func titulo_de(origem: String, extra: Dictionary, fase: Dictionary) -> String:
	if origem == "pronta":
		return Fases.prontas()[extra["i"]]["nome"]
	if origem == "dia":
		return "Ladeira do dia · " + dd(extra["dia"]["d"]) + "/" + dd(extra["dia"]["m"])
	if origem == "teste":
		return "Tua ladeira"
	var a: String = fase.get("autor", "")
	return ("Ladeira de " + a) if a != "" else "Ladeira do desafio"


func joga_fase(fase: Dictionary, origem: String, extra := {}) -> void:
	var F := Nucleo.compila(fase)
	jogo = Jogo.new()
	jogo.fase = fase
	jogo.F = F
	jogo.origem = origem
	jogo.extra = extra
	jogo.id = Codigo.id_fase(fase)
	jogo.titulo = titulo_de(origem, extra, fase)
	demo = null
	mundo.monta_cena(fase, F)
	define_fantasma(jogo)
	tela = "jogo"
	so_cartao(null)
	mostra_ui()
	comeca_descida()


## O fantasma: no desafio, quem mandou; senão, o teu melhor; senão, a casa (o robô).
func define_fantasma(J: Jogo) -> void:
	J.g_ev = null
	J.g_nome = ""
	var co: Array = J.fase.get("corrente", []) if J.fase.get("corrente", null) != null else []
	if J.origem == "desafio" and J.fase.get("fantasma", null) != null and co.size() > 0:
		J.g_ev = J.fase["fantasma"]
		J.g_nome = co[co.size() - 1]["nome"]
	elif fants.has(J.id):
		J.g_ev = fants[J.id]
		J.g_nome = "teu recorde"
	elif J.origem == "pronta":
		var c = tempo_casa(J.extra["i"])
		if c != null:
			J.g_ev = c["ev"]
			J.g_nome = "a casa"
	elif J.origem == "dia" and J.fase.get("robo", null) != null:
		J.g_ev = J.fase["robo"]
		J.g_nome = "a casa"


func comeca_descida() -> void:
	var J := jogo
	J.S = Nucleo.novo_estado(J.F)
	J.ev = []
	J.tentativas += 1
	J.G = Nucleo.novo_estado(J.F) if J.g_ev != null else null
	J.gj = 0
	J.g_alfa = 0.42
	J.vis = Vis.new()
	J.g_vis = Vis.new()
	J.fim_t = 0.0
	J.pode_reiniciar = false
	J.mostrou_fim = false
	J.latiu = []
	J.latiu.resize(J.F.caes.size())
	J.latiu.fill(-9.0)
	J.mola_t = []
	J.mola_t.resize(J.F.molas.size())
	J.mola_t.fill(0.0)
	fila.clear()
	acc = 0.0
	mundo.parts.clear()
	mundo.pedacos.clear()
	tremor = 0.0
	cam_y = -40.0
	carimbo_no.visible = false
	pos_no.visible = false
	so_cartao(null)
	mostra_ui()
	atualiza_alvo()
	var primeira := Dados.le("dica-jogo", null) == null
	if dedo_tela:
		dica_tx.text = "[center][color=%s]Toca[/color]: pula · [color=%s]Segura[/color] no ar: cambalhota[/center]" % [Estilo.hexa(Estilo.AMARELO), Estilo.hexa(Estilo.AMARELO)]
	else:
		dica_tx.text = "[center][color=%s]Espaço[/color]: pula · [color=%s]segura[/color] no ar: cambalhota · [color=%s]R[/color] recomeça[/center]" % [Estilo.hexa(Estilo.AMARELO), Estilo.hexa(Estilo.AMARELO), Estilo.hexa(Estilo.AMARELO)]
	dica_jogo.visible = primeira or J.tentativas == 1
	if J.tentativas == 1:
		carimbo("VAI!", "", "vai", 0.6)
		som.toca("vai")
	relogio.text = _relogio_txt(0)


func _relogio_txt(cs: int) -> String:
	return fmt2(cs) + "[font_size=%d]s[/font_size]" % Estilo.px((29.0 if tam.x / P <= 420.0 else 34.0) * 0.5)


func atualiza_alvo() -> void:
	var J := jogo
	var r = recs.get(J.id, null)
	var h := ""
	var co: Array = J.fase.get("corrente", []) if J.fase.get("corrente", null) != null else []
	var am := Estilo.hexa(Estilo.AMARELO)
	if J.origem == "desafio" and co.size() > 0:
		var u: Dictionary = co[co.size() - 1]
		h = "[color=%s][b]%s[/b][/color]: %s" % [am, esc(u["nome"]), fmt2(int(u["cs"]))]
	elif J.origem == "pronta":
		var c = tempo_casa(J.extra["i"])
		if c != null:
			h = "casa: " + fmt2(int(c["cs"]))
	elif J.origem == "dia" and J.fase.get("par", null) != null:
		h = "casa: " + fmt2(int(J.fase["par"]))
	if r != null:
		h += (" · " if h != "" else "") + "teu: " + fmt2(int(r))
	alvo.text = h


func apertou() -> void:
	if tela != "jogo" or jogo == null:
		return
	var S := jogo.S
	if S.fim != "":
		if jogo.pode_reiniciar and S.fim != "chegou":
			reinicia()
		return
	fila.append(1)
	if dica_jogo.visible and S.passos > 30:
		dica_jogo.visible = false
		Dados.guarda("dica-jogo", "1")


func soltou() -> void:
	if tela == "jogo" and jogo != null and jogo.S.fim == "":
		fila.append(0)


func aplica_fila() -> void:
	var S := jogo.S
	while not fila.is_empty():
		var k: int = fila.pop_front()
		if k == 1 and not S.segura:
			Nucleo.toca(S)
			jogo.ev.append(S.passos)
		elif k == 0 and S.segura:
			Nucleo.solta(S)
			jogo.ev.append(S.passos)


func passo_fantasma() -> void:
	var J := jogo
	var G := J.G
	if G == null or G.fim != "":
		return
	var gev: Array = J.g_ev
	while J.gj < gev.size() and int(gev[J.gj]) <= G.passos:
		if J.gj % 2 == 0:
			Nucleo.toca(G)
		else:
			Nucleo.solta(G)
		J.gj += 1
	G.ev.clear()
	Nucleo.passo(J.F, G)


func passo_jogo(dt: float) -> void:
	var J := jogo
	var S := J.S
	acc += dt
	var n := 0
	while acc >= Nucleo.PASSO and n < 30:
		if S.fim == "":
			S.ev.clear()
			while not J.agenda.is_empty() and int(J.agenda[0]["n"]) <= S.passos:
				fila.append(int(J.agenda.pop_front()["k"]))
			aplica_fila()
			Nucleo.passo(J.F, S)
			trata_eventos(S)
			if S.fim != "":
				fim_da_descida()
		passo_fantasma()
		acc -= Nucleo.PASSO
		n += 1
	if n >= 30:
		acc = 0.0
	alfa = 1.0 if S.fim != "" else acc / Nucleo.PASSO
	if S.fim != "":
		J.fim_t += dt
		if not J.pode_reiniciar and J.fim_t > 0.32 and S.fim != "chegou":
			J.pode_reiniciar = true
			pos_no.visible = true
		if S.fim == "chegou" and J.fim_t > 1.0 and not J.mostrou_fim:
			J.mostrou_fim = true
			mostra_fim()
	if J.G != null:
		if J.G.fim != "" and J.G.fim != "chegou":
			J.g_alfa = maxf(0.0, J.g_alfa - dt * 0.8)
		passo_vis(J.g_vis, J.G, dt)
	passo_vis(J.vis, S, dt)
	# o caramelo late quando o carrinho chega perto
	if S.fim == "":
		for i in J.F.caes.size():
			var q := Nucleo.pos_cao(J.F, J.F.caes[i], S.passos)
			var mx := (S.p[0] + S.p[2]) / 2.0
			var my := (S.p[1] + S.p[3]) / 2.0
			if absf(q[0] - mx) < 120.0 and absf(q[1] - my) < 60.0 and tempo - float(J.latiu[i]) > 1.6:
				J.latiu[i] = tempo
				som.toca("latido")
				mundo.texto_sobe(q[0] + 10.0, q[1] - 22.0, "AU!", Color("#F3EEE2"))
	for i in J.mola_t.size():
		if J.mola_t[i] > 0.0:
			J.mola_t[i] -= dt
	# correndo no chão, o rolimã levanta pó de giz atrás
	if S.fim == "" and (S.c0 != 0 or S.c1 != 0):
		var vx := (S.v[0] + S.v[2]) / 2.0
		var vy := (S.v[1] + S.v[3]) / 2.0
		var sp := sqrt(vx * vx + vy * vy)
		J.po_t += dt * sp / 90.0
		if sp > 300.0 and J.po_t > 1.0:
			J.po_t = 0.0
			var tr := 0 if S.frente == 1 else 2
			mundo.parts.append({"k": "p", "x": S.p[tr] - S.nx * Nucleo.RR, "y": S.p[tr + 1] - S.ny * Nucleo.RR, "vx": -vx * 0.15 + (randf() - 0.5) * 30.0, "vy": -20.0 - randf() * 30.0, "r": 1.0 + randf() * 1.8, "vida": 0.35 + randf() * 0.3, "c": Color("#F3EEE2")})
	seguir(S, dt, alfa)
	relogio.text = _relogio_txt(tempo_atual(S))


func tempo_atual(S: Nucleo.Estado) -> int:
	if S.fim != "" and S.fim_cs >= 0:
		return S.fim_cs
	return maxi(0, int(Nucleo.js_round(float(S.passos * 100) / 120.0)) - 50 * S.cambalhotas)


func trata_eventos(S: Nucleo.Estado) -> void:
	var ev := S.ev
	var p := S.p
	var i := 0
	while i < ev.size():
		var k: String = ev[i]
		var v = ev[i + 1]
		if k == "pulo":
			som.toca("pulo")
			chao_poeira(S, 8, 90.0)
		elif k == "pouso":
			if float(v) > 130.0:
				som.toca("pouso", float(v))
				chao_poeira(S, mini(16, int(float(v) / 40.0)), minf(160.0, float(v) * 0.3))
				if float(v) > 420.0:
					tremor = maxf(tremor, 0.12)
		elif k == "mola":
			som.toca("mola")
			jogo.mola_t[int(v)] = 0.32
		elif k == "turbo":
			som.toca("turbo")
			mundo.poeira((p[0] + p[2]) / 2.0, (p[1] + p[3]) / 2.0, 10, 160.0, Color(1.0, 201.0 / 255, 60.0 / 255))
		elif k == "cambalhota":
			var nv := int(v)
			som.toca("cambalhota", nv)
			mundo.texto_sobe((p[0] + p[2]) / 2.0, (p[1] + p[3]) / 2.0 - 46.0, "+" + str(nv) + (" CAMBALHOTAS" if nv > 1 else " CAMBALHOTA"), Color("#FFC93C"))
			mundo.texto_sobe((p[0] + p[2]) / 2.0, (p[1] + p[3]) / 2.0 - 28.0, "−" + fmt1(nv * 50) + " s", Color("#F3EEE2"))
		i += 2


func chao_poeira(S: Nucleo.Estado, n: int, f: float) -> void:
	for i in [0, 2]:
		mundo.poeira(S.p[i] - S.nx * Nucleo.RR, S.p[i + 1] - S.ny * Nucleo.RR, int(ceil(n / 2.0)), f)


## O carrinho na tela: os rolimãs girando, o lado que ele olha virando devagar, a pose do piloto.
func passo_vis(V: Vis, S: Nucleo.Estado, dt: float) -> void:
	var v := S.v
	var p := S.p
	var ux := (p[2] - p[0]) / Nucleo.LB
	var uy := (p[3] - p[1]) / Nucleo.LB
	var vb := ((v[0] + v[2]) * ux + (v[1] + v[3]) * uy) / 2.0
	V.giro += vb * dt / Mundo.RODA
	var alvo_l := 1.0 if S.frente == 1 else -1.0
	V.lado += clampf(alvo_l - V.lado, -dt * 11.0, dt * 11.0)
	var no_ar := S.c0 == 0 and S.c1 == 0
	V.ar_t = V.ar_t + dt if no_ar else 0.0
	if S.fim != "":
		V.pose = 0
	elif no_ar and S.segura and S.seg_t >= Nucleo.SEG_MIN:
		V.pose = 1
	elif V.ar_t > 0.45:
		V.pose = 2
	else:
		V.pose = 0


func seguir(S: Nucleo.Estado, dt: float, a: float) -> void:
	var VH := mundo.VH
	var my := (S.pa[1] + S.pa[3]) / 2.0 + ((S.p[1] + S.p[3]) / 2.0 - (S.pa[1] + S.pa[3]) / 2.0) * a
	var vy := (S.v[1] + S.v[3]) / 2.0
	var al := my - VH * 0.38 + clampf(vy * 0.22, -VH * 0.1, VH * 0.18)
	al = maxf(al, -40.0)
	if my - 34.0 < al + VH * 0.1:
		al = my - 34.0 - VH * 0.1
	al = minf(al, maxf(-40.0, maxf(mundo.y_max + 150.0 - VH, my - VH * 0.62)))
	cam_y += (al - cam_y) * (1.0 - exp(-dt * 5.5))


func fim_da_descida() -> void:
	var J := jogo
	var S := J.S
	var m := S.fim
	var mx := (S.p[0] + S.p[2]) / 2.0
	var my := (S.p[1] + S.p[3]) / 2.0
	fila.clear()
	dica_jogo.visible = false
	if m == "chegou":
		var cs := S.fim_cs
		var run := {"cs": cs, "ev": J.ev.duplicate(), "camb": S.cambalhotas}
		J.ultimo = run
		var ant = recs.get(J.id, null)
		J.recorde = ant == null or cs < int(ant)
		J.antes = ant
		if J.recorde:
			recs[J.id] = cs
			Dados.guarda("recs", recs)
			fants.erase(J.id)
			fants[J.id] = run["ev"]
			poda_fants()
		if J.sessao == null or cs < int(J.sessao["cs"]):
			J.sessao = run
		if J.origem == "teste":
			if ed.validado != J.id or ed.melhor == null or cs < int(ed.melhor["cs"]):
				ed.melhor = run
			ed.validado = J.id
			salva_rascunho()
		carimbo("CHEGOU!", fmt2(cs) + " s" + ((" · " + str(S.cambalhotas) + (" cambalhotas" if S.cambalhotas > 1 else " cambalhota")) if S.cambalhotas > 0 else ""), "ok")
		som.toca("chegada")
		if J.recorde and ant != null:
			som.toca("recorde")
		mundo.confete(mx, my - 30.0, 140)
		get_tree().create_timer(0.26).timeout.connect(func():
			if jogo == J:
				mundo.confete(mx, my - 80.0, 70))
	else:
		var fr: Array = FRASES.get(m, ["Deu ruim."])
		var sub: String = fr[(J.tentativas - 1) % fr.size()]
		if J.origem == "teste" and not J.F.tem_chegada and (m == "caiu" or m == "empacou"):
			sub = "Falta a CHEGADA: põe a bandeira no fim."
		carimbo(TITULO.get(m, "DEU RUIM"), sub, "")
		pos_tx.text = "Toca pra tentar de novo" if dedo_tela else "Clica ou aperta espaço pra tentar de novo"
		p_editor.visible = J.origem == "teste"
		if m == "capotou" or m == "torto" or m == "cachorro":
			som.toca("capotou")
			tremor = 0.45
			solta_pedacos(S)
			Input.vibrate_handheld(150)
			if m == "cachorro":
				get_tree().create_timer(0.12).timeout.connect(func(): som.toca("latido"))
		else:
			som.toca("erro")


func solta_pedacos(S: Nucleo.Estado) -> void:
	var p := S.p
	var mx := (p[0] + p[2]) / 2.0
	var my := (p[1] + p[3]) / 2.0
	var vx := (S.v[0] + S.v[2]) / 2.0
	var vy := (S.v[1] + S.v[3]) / 2.0
	var ux := (p[2] - p[0]) / Nucleo.LB
	var uy := (p[3] - p[1]) / Nucleo.LB
	var hx := mx + uy * Nucleo.HC
	var hy := my - ux * Nucleo.HC
	var lado := 1.0 if S.frente == 1 else -1.0
	var ang := atan2(p[3] - p[1], p[2] - p[0])
	mundo.pedacos.append({"k": "tabua", "x": mx, "y": my, "vx": vx * 0.6, "vy": vy * 0.5 - 120.0, "a": ang, "va": (randf() - 0.5) * 8.0, "r": 9.0, "vida": 4.0})
	mundo.pedacos.append({"k": "piloto", "x": (mx + hx) / 2.0, "y": (my + hy) / 2.0, "vx": vx * 0.8 + lado * 60.0, "vy": vy * 0.4 - 300.0, "a": ang, "va": lado * (6.0 + randf() * 5.0), "r": 8.0, "vida": 4.0, "cam": cor_de(nome)})
	mundo.pedacos.append({"k": "balde", "x": hx, "y": hy - 4.0, "vx": vx * 0.9 - lado * 40.0, "vy": vy * 0.3 - 480.0, "a": 0.0, "va": (-1.0 if randf() < 0.5 else 1.0) * (12.0 + randf() * 8.0), "r": 6.0, "vida": 4.0})


func poda_fants() -> void:
	var ks := fants.keys()
	while ks.size() > 40:
		fants.erase(ks.pop_front())
	Dados.guarda("fant", fants)


func reinicia() -> void:
	if tela == "jogo" and jogo != null:
		som.toca("clique")
		comeca_descida()


func sai_do_jogo() -> void:
	if jogo == null:
		mostra_inicio()
		return
	var J := jogo
	if J.origem == "teste":
		abre_editor()
		return
	if J.origem == "desafio":
		abre_desafio(J.fase)
		return
	mostra_inicio()


# ---------------------------------------------------------------- o resultado
func mostra_fim() -> void:
	var J := jogo
	var run := J.ultimo
	var cs: int = run["cs"]
	var v := _novo_cartao("fim")
	var am := Estilo.hexa(Estilo.AMARELO)
	var ro := Estilo.hexa(Estilo.ROSA)
	v.add_child(Estilo.olho(J.titulo))
	var tg := Estilo.rico(fmt2(cs) + "[font_size=%d]s[/font_size]" % Estilo.px(_tam_grande() * 0.45), Estilo.tit, _tam_grande(), Estilo.AMARELO)
	_sombra(tg, Estilo.AMARELO_SOMBRA, 5)
	v.add_child(tg)
	var camb: int = run["camb"]
	if camb > 0:
		v.add_child(Estilo.rotulo("%d %s: −%s s no tempo" % [camb, "cambalhotas" if camb > 1 else "cambalhota", fmt2(camb * 50)], Estilo.t500, 14, Estilo.GIZ2, HORIZONTAL_ALIGNMENT_CENTER))
	var cmp := ""
	var perdeu := false
	var co: Array = J.fase.get("corrente", []) if J.fase.get("corrente", null) != null else []
	if J.origem == "desafio" and co.size() > 0:
		var u: Dictionary = co[co.size() - 1]
		var dif: int = int(u["cs"]) - cs
		var eu: bool = u["nome"] == nome
		if eu:
			cmp = ("Bateu o teu próprio tempo por [color=%s]%s[/color]." % [am, fmt_dif(dif)]) if dif > 0 else ("Teu tempo no link é [color=%s]%s s[/color]." % [am, fmt2(int(u["cs"]))])
		elif dif > 0:
			cmp = "Ganhou de [color=%s]%s[/color] por [color=%s]%s[/color]." % [am, esc(u["nome"]), am, fmt_dif(dif)]
		elif dif == 0:
			cmp = "Empatou com [color=%s]%s[/color]. No centésimo!" % [am, esc(u["nome"])]
		else:
			perdeu = true
			cmp = "Faltou [color=%s]%s[/color] pra pegar %s." % [ro, fmt_dif(-dif), esc(u["nome"])]
	elif J.origem == "pronta" or J.origem == "dia":
		var c = tempo_casa(J.extra["i"]) if J.origem == "pronta" else ({"cs": int(J.fase["par"])} if J.fase.get("par", null) != null else null)
		if c != null:
			var dif: int = int(c["cs"]) - cs
			if dif > 0:
				cmp = "Ganhou da casa por [color=%s]%s[/color]." % [am, fmt_dif(dif)]
			elif dif == 0:
				cmp = "Empatou com a casa: [color=%s]%s s[/color]. Pula, gira, tira uns centésimos." % [am, fmt2(int(c["cs"]))]
			else:
				perdeu = true
				cmp = "A casa desceu em [color=%s]%s s[/color]. Faltou %s." % [ro, fmt2(int(c["cs"])), fmt_dif(-dif)]
	else:
		cmp = "Chegou! Agora é tua vez de [color=%s]duvidar[/color] alguém." % am
	if cmp != "":
		v.add_child(Estilo.rico(cmp, Estilo.t800, 17))
	var rec := ""
	if J.recorde:
		rec = "Primeiro tempo teu nessa ladeira." if J.antes == null else "Recorde teu! O de antes era %s s." % fmt2(int(J.antes))
	else:
		rec = "Teu recorde aqui: %s s." % fmt2(int(recs[J.id]))
	v.add_child(Estilo.rotulo(rec, Estilo.t500, 14, Estilo.GIZ2, HORIZONTAL_ALIGNMENT_CENTER))
	var b_de_novo: Button = marca("fDeNovo", Estilo.botao("De novo", "vai"))
	b_de_novo.pressed.connect(func(): reinicia())
	var txt_manda := "Mandar o desafio" if J.origem == "teste" else ("Devolver" if J.origem == "desafio" else "Duvidar alguém")
	var b_manda: Button = marca("fManda", Estilo.botao(txt_manda, "rosa"))
	b_manda.pressed.connect(_f_manda)
	v.add_child(_linha([b_de_novo, b_manda]))
	var linha2: Array = []
	if J.origem == "teste":
		var be := Estilo.botao("Voltar pro editor")
		be.pressed.connect(func(): som.toca("clique"); abre_editor())
		linha2.append(be)
	var bm: Button = marca("fMenu", Estilo.botao("Voltar pro desafio" if J.origem == "desafio" else ("Começo" if J.origem == "teste" else "Outra ladeira")))
	bm.pressed.connect(func():
		som.toca("clique")
		if jogo != null and jogo.origem == "desafio":
			abre_desafio(jogo.fase)
		else:
			mostra_inicio())
	linha2.append(bm)
	v.add_child(_linha(linha2))
	so_cartao("fim")


func _tam_grande() -> float:
	return clampf(0.16 * tam.x / P, 50.0, 72.0)


func _f_manda() -> void:
	som.toca("clique")
	var J := jogo
	if J == null:
		return
	if J.origem == "teste":
		precisa_nome(manda_do_editor)
	elif J.origem == "desafio":
		precisa_nome(devolve)
	else:
		precisa_nome(duvida_pronta)


# ---------------------------------------------------------------- o link, a mensagem e o nome
func fase_para_mandar(base: Dictionary, corrente: Array, ev) -> Dictionary:
	return {"autor": base.get("autor", ""), "tracos": base["tracos"], "carimbos": base["carimbos"], "corrente": corrente, "fantasma": ev.duplicate() if ev is Array else null}


func mensagem(tipo: String, fase: Dictionary, cs: int, outro = null) -> Dictionary:
	var cod := Codigo.codifica(fase)
	var link := Codigo.LINK + "#" + cod
	var tx := ""
	if tipo == "devolve":
		if outro != null and int(outro["cs"]) > cs:
			tx = "%s fez %s s. Eu fiz %s s. Duvido tu bater." % [outro["nome"], fmt1(int(outro["cs"])), fmt1(cs)]
		else:
			tx = "Desci essa ladeira de rolimã em %s s. Duvido tu bater." % fmt1(cs)
	else:
		tx = "Duvido tu descer essa ladeira de rolimã. Eu desci em %s s." % fmt1(cs)
	return {"cod": cod, "link": link, "texto": tx + "\n" + link}


func precisa_nome(depois: Callable) -> void:
	if nome != "":
		depois.call()
		return
	pede_nome(depois, "Antes de mandar")


func pede_nome(depois: Callable, olho_txt: String) -> void:
	depois_do_nome = depois
	volta_do_nome = {"tela": tela, "cartao": cartao_atual, "olho": olho_txt}
	_cartao_nome(olho_txt)
	so_cartao("nome", "nome")


func confirma_nome() -> void:
	var n := Codigo.limpa_nome(campo_nome.text)
	if n == "":
		erro_nome.visible = true
		erro_nome.text = "Escreve um nome (ou apelido) pra ir junto no desafio."
		som.toca("erro")
		return
	nome = n
	Dados.guarda("nome", n)
	Dados.salva()
	som.toca("clique")
	var f := depois_do_nome
	depois_do_nome = Callable()
	if f.is_valid():
		f.call()
	else:
		mostra_inicio()


func volta_nome() -> void:
	var v = volta_do_nome
	depois_do_nome = Callable()
	if v != null and v["cartao"] != null and v["cartao"] != "nome" and cartoes.has(v["cartao"]):
		so_cartao(v["cartao"])
	elif tela == "editor":
		so_cartao(null)
	else:
		mostra_inicio()


func abre_manda(msg: Dictionary, volta: String) -> void:
	manda = {"msg": msg, "volta": volta}
	_cartao_manda()
	so_cartao("manda")


func copia() -> void:
	var tx: String = manda["msg"]["texto"]
	DisplayServer.clipboard_set(tx)
	ok_copia.visible = true
	ok_copia.text = "Copiado! Agora cola no zap e duvida."
	som.toca("copia")


func manda_zap() -> void:
	var tx: String = manda["msg"]["texto"]
	som.toca("clique")
	OS.shell_open("https://wa.me/?text=" + tx.uri_encode())


func manda_do_editor() -> void:
	if not editor_liberado():
		return
	var f := fase_para_mandar({"autor": nome, "tracos": ed.tracos, "carimbos": ed.carimbos}, [{"nome": nome, "cs": int(ed.melhor["cs"])}], ed.melhor["ev"])
	abre_manda(mensagem("desafio", f, int(ed.melhor["cs"])), "fim" if tela == "jogo" else "editor")


func melhor_daqui(J: Jogo):
	var r = recs.get(J.id, null)
	var ev = fants.get(J.id, null)
	if r != null and ev != null:
		return {"cs": int(r), "ev": ev}
	return J.sessao


func devolve() -> void:
	var J := jogo
	var m = melhor_daqui(J)
	if m == null:
		return
	var co_todo: Array = J.fase.get("corrente", []) if J.fase.get("corrente", null) != null else []
	var co: Array = []
	for c in co_todo:
		if c["nome"] != nome:
			co.append(c)
	var remet = co_todo[co_todo.size() - 1] if co_todo.size() > 0 else null
	co.append({"nome": nome, "cs": int(m["cs"])})
	var nova := co
	if co.size() > Codigo.CORRENTE_MAX:
		var ai := -1
		for i in co.size():
			if co[i]["nome"] == J.fase.get("autor", ""):
				ai = i
				break
		if ai >= 0 and ai < co.size() - Codigo.CORRENTE_MAX:
			nova = [co[ai]] + co.slice(co.size() - (Codigo.CORRENTE_MAX - 1))
		else:
			nova = co.slice(co.size() - Codigo.CORRENTE_MAX)
	var f := fase_para_mandar(J.fase, nova, m["ev"])
	abre_manda(mensagem("devolve", f, int(m["cs"]), remet if (remet != null and remet["nome"] != nome) else null), "fim")


func duvida_pronta() -> void:
	var J := jogo
	var m = melhor_daqui(J)
	if m == null:
		return
	var f := fase_para_mandar({"autor": "Ladeira do dia" if J.origem == "dia" else "Duvido", "tracos": J.fase["tracos"], "carimbos": J.fase["carimbos"]}, [{"nome": nome, "cs": int(m["cs"])}], m["ev"])
	abre_manda(mensagem("desafio", f, int(m["cs"])), "fim")


# ---------------------------------------------------------------- o desafio que chegou
func abre_codigo(txt: String) -> bool:
	var f = Codigo.acha_codigo(txt)
	if f != null:
		abre_desafio(f)
		return true
	return false


func abre_desafio(fase: Dictionary) -> void:
	desafio = fase
	tela = "desafio"
	jogo = null
	_cartao_desafio()
	so_cartao("desafio")
	mostra_ui()
	inicia_demo(fase, fase.get("fantasma", null))


func _hash_web() -> String:
	if not OS.has_feature("web"):
		return ""
	var h = JavaScriptBridge.eval("window.location.hash || ''", true)
	var s := str(h) if h != null else ""
	ultimo_hash = s.substr(1)
	return s.substr(1)


var ultimo_hash := ""
var _cb_hash: JavaScriptObject


func _ouve_hash_web() -> void:
	if not OS.has_feature("web"):
		return
	_cb_hash = JavaScriptBridge.create_callback(_mudou_hash)
	var w := JavaScriptBridge.get_interface("window")
	if w != null:
		w.addEventListener("hashchange", _cb_hash)


func _mudou_hash(_args) -> void:
	var h := str(JavaScriptBridge.eval("window.location.hash || ''", true)).substr(1)
	if h != "" and h != ultimo_hash:
		ultimo_hash = h
		abre_codigo(h)


# ---------------------------------------------------------------- o editor
func _le_rascunho() -> void:
	var r = Dados.le("rascunho", null)
	if r is Dictionary and r.get("tracos", null) is Array and r.get("carimbos", null) is Array:
		ed.tracos = []
		for t in r["tracos"]:
			if t is Dictionary and t.get("pts", null) is Array and t["pts"].size() >= 4:
				ed.tracos.append({"cor": int(t.get("cor", 0)) & 3, "pts": _ints(t["pts"])})
		ed.carimbos = []
		for c in r["carimbos"]:
			if c is Dictionary and Nucleo.TIPOS.has(c.get("tipo", "")):
				var cb := {"tipo": c["tipo"], "x": int(c.get("x", 0)), "y": int(c.get("y", 0))}
				if c["tipo"] == "turbo":
					cb["dir"] = int(c.get("dir", 0)) & 15
				ed.carimbos.append(cb)
		ed.validado = r.get("validado", null)
		var m = r.get("melhor", null)
		if m is Dictionary and m.get("ev", null) is Array:
			ed.melhor = {"cs": int(m["cs"]), "ev": _ints(m["ev"]), "camb": int(m.get("camb", 0))}


func salva_rascunho() -> void:
	rascunho_t = 0.25


func _grava_rascunho() -> void:
	Dados.guarda("rascunho", {"tracos": ed.tracos, "carimbos": ed.carimbos, "validado": ed.validado, "melhor": ed.melhor})


func fase_do_editor() -> Dictionary:
	return {"autor": nome, "tracos": ed.tracos, "carimbos": ed.carimbos, "corrente": [], "fantasma": null}


func tinta_usada(extra := 0.0) -> float:
	var s := 0.0
	for t in ed.tracos:
		var p: Array = t["pts"]
		var i := 2
		while i < p.size():
			s += Vector2(float(p[i]) - float(p[i - 2]), float(p[i + 1]) - float(p[i - 1])).length()
			i += 2
	return s + extra


func editor_liberado() -> bool:
	return ed.melhor != null and ed.validado != null and ed.validado == ed.id


func mudou_editor(so_carimbo := false) -> void:
	ed.id = Codigo.id_fase(fase_do_editor())
	var f := fase_do_editor()
	if so_carimbo and mundo.cena_F != null:
		mundo.troca_carimbos(f)
	else:
		mundo.monta_cena(f, Nucleo.compila(f))
	parado = null
	tinta_cache = tinta_usada()
	atualiza_tinta()
	atualiza_manda()
	salva_rascunho()
	dica_editor()


func atualiza_tinta(extra := 0.0) -> void:
	var resta := maxf(0.0, 1.0 - (tinta_cache + extra) / TINTA_MAX)
	tinta_frac = resta
	tinta_bar.queue_redraw()
	tinta_lbl.text = "GIZ: " + str(int(round(resta * 100.0))) + "%"


func atualiza_manda() -> void:
	var ok := editor_liberado()
	Estilo.estiliza(e_manda, "manda" if ok else "manda_off")
	e_manda.icon = Estilo.icone_tex("aviao" if ok else "cadeado", 22.0)
	e_manda.tooltip_text = "Mandar o desafio" if ok else "Desce até a chegada primeiro"


func abre_editor(fase = null) -> void:
	if fase != null:
		guarda_desfaz()
		ed.tracos = fase["tracos"].duplicate(true)
		ed.carimbos = fase["carimbos"].duplicate(true)
		ed.validado = null
		ed.melhor = null
		ed.cam_y = -40.0
	tela = "editor"
	jogo = null
	demo = null
	so_cartao(null)
	mostra_ui()
	escolhe_ferr(ed.ferr, true)
	mudou_editor()
	cam_y = ed.cam_y
	mostra_dica_ed(true)


func guarda_desfaz() -> void:
	ed.desfaz.append(JSON.stringify({"t": ed.tracos, "c": ed.carimbos}))
	if ed.desfaz.size() > 80:
		ed.desfaz.pop_front()


func desfaz() -> void:
	if tela != "editor":
		return
	if ed.desfaz.is_empty():
		aviso("Nada pra desfazer.", 1.4)
		return
	var o: Dictionary = JSON.parse_string(ed.desfaz.pop_back())
	ed.tracos = []
	for t in o["t"]:
		ed.tracos.append({"cor": int(t["cor"]), "pts": _ints(t["pts"])})
	ed.carimbos = []
	for c in o["c"]:
		var cb := {"tipo": c["tipo"], "x": int(c["x"]), "y": int(c["y"])}
		if c.has("dir"):
			cb["dir"] = int(c["dir"])
		ed.carimbos.append(cb)
	som.toca("desfaz")
	mudou_editor()


func limite_editor() -> float:
	var ym := mundo.y_max if mundo.cena_F != null else 150.0
	return minf(Nucleo.ALT_MAX + 60.0 - mundo.VH, maxf(mundo.VH * 0.5, ym + mundo.VH * 0.55))


func rola_editor(dy: float) -> void:
	ed.cam_y = clampf(ed.cam_y + dy, -40.0, maxf(-40.0, limite_editor()))
	cam_y = ed.cam_y


func escolhe_ferr(f: String, quieto := false) -> void:
	ed.ferr = f
	for k in ferr_bts:
		var b: Button = ferr_bts[k]
		_estilo_ferr(b, k == f)
	cores_no.visible = tela == "editor" and f == "lapis"
	if not quieto:
		som.toca("clique")
		mostra_dica_ed(true)


func mostra_dica_ed(forca := false) -> void:
	if tela != "editor":
		return
	var t := ""
	var tem_chegada := false
	for c in ed.carimbos:
		if c["tipo"] == "chegada":
			tem_chegada = true
	if ed.ferr == "borracha":
		t = "Passa o dedo no giz ou no carimbo pra apagar."
	elif ed.ferr == "turbo":
		t = "Toca pra pôr o turbo e arrasta pra apontar."
	elif ed.ferr == "mola":
		t = "A mola joga o carrinho pro alto. Põe no chão."
	elif ed.ferr == "cachorro":
		t = "O caramelo vai e volta. Encostou, capotou."
	elif ed.ferr == "chegada":
		t = "Só tem uma bandeira. Toca onde a ladeira acaba."
	elif ed.tracos.is_empty():
		t = "Desenha a ladeira com o dedo, saindo da tábua."
	elif ed.tracos.size() == 1 and not tem_chegada:
		t = "Tirou o dedo, ficou buraco: vira pulo."
	elif not tem_chegada:
		t = "Põe a CHEGADA lá embaixo."
	elif not editor_liberado():
		t = "Agora desce tu primeiro: Testar."
	else:
		t = "Liberou! Manda o desafio."
	if t != ed_dica.text or forca:
		ed_dica.text = t
		ed_dica.visible = true
		ed.dica_t = 4.5


func dica_editor() -> void:
	mostra_dica_ed(false)


func mundo_de(pt: Vector2) -> Vector2:
	return Vector2((pt.x - mundo.COLX) / mundo.K, pt.y / mundo.K + cam_y)


func carimbo_em(w: Vector2, raio: float):
	var m = null
	var md := raio * raio
	for i in ed.carimbos.size():
		var c: Dictionary = ed.carimbos[i]
		var cx: float = c["x"]
		var cy: float = float(c["y"]) - (40.0 if c["tipo"] == "chegada" else (12.0 if c["tipo"] == "cachorro" else 0.0))
		var d := (cx - w.x) * (cx - w.x) + (cy - w.y) * (cy - w.y)
		var d2 := d
		if c["tipo"] == "chegada":
			d2 = minf(d, (cx - w.x) * (cx - w.x) + (float(c["y"]) - w.y) * (float(c["y"]) - w.y))
		if d2 < md:
			md = d2
			m = i
	return m


func chao_pra(x: float, y: float) -> float:
	return Nucleo.chao_embaixo(mundo.cena_F, x, y - 30.0, 110.0)


func encaixa(c: Dictionary, w: Vector2) -> void:
	c["x"] = int(Nucleo.js_round(clampf(w.x, 6.0, Nucleo.LARG - 6.0)))
	if c["tipo"] == "turbo":
		c["y"] = int(Nucleo.js_round(clampf(w.y, 0.0, Nucleo.ALT_MAX)))
		return
	var ch := chao_pra(float(c["x"]), w.y)
	var y := w.y if is_nan(ch) else ch
	c["y"] = int(Nucleo.js_round(clampf(y - 3.0 if c["tipo"] == "mola" else y, 0.0, Nucleo.ALT_MAX)))


func _kcss() -> float:
	return mundo.K / P


func ed_down(id: int, pt: Vector2, botao: int) -> void:
	if tela != "editor":
		return
	ed.dedos[id] = pt
	if ed.dedos.size() >= 2:
		# dois dedos: rola a ladeira (o traço que tinha acabado de começar vai embora)
		if ed.traco != null:
			if ed.traco["len"] < 30.0 or Time.get_ticks_msec() - int(ed.traco["t0"]) < 260:
				ed.traco = null
				mundo.giz_vivo([], 0)
				atualiza_tinta()
			else:
				fecha_traco()
		ed.gesto = null
		ed.pan = {"y": media_dedos(), "cam": ed.cam_y}
		return
	if botao == MOUSE_BUTTON_MIDDLE or botao == MOUSE_BUTTON_RIGHT:
		ed.pan = {"y": pt.y, "cam": ed.cam_y}
		return
	apaga_tudo.visible = false
	var w := mundo_de(pt)
	ed.tela_pt = pt
	ed.cursor = w
	ed_dica.visible = false
	var f := ed.ferr
	if f == "lapis":
		if TINTA_MAX - tinta_cache < 6.0:
			sem_giz()
			return
		var im = ima_ponta(w.x, w.y)
		ed.traco = {"cor": ed.cor, "pts": [im.x, im.y] if im != null else [clampf(w.x, 0.0, Nucleo.LARG), clampf(w.y, 0.0, Nucleo.ALT_MAX)], "len": 0.0, "t0": Time.get_ticks_msec()}
	elif f == "borracha":
		ed.gesto = {"k": "apaga", "mexeu": false, "antes": null}
		apaga_em(w)
	else:
		var i = carimbo_em(w, 24.0)
		if i != null and (ed.carimbos[i]["tipo"] == f or f != "turbo"):
			var c: Dictionary = ed.carimbos[i]
			ed.gesto = {"k": "mira" if (c["tipo"] == "turbo" and f == "turbo") else "move", "i": i, "antes": JSON.stringify({"t": ed.tracos, "c": ed.carimbos}), "mexeu": false, "novo": false}
		else:
			var n := 0
			for c in ed.carimbos:
				if c["tipo"] == f:
					n += 1
			var antes := JSON.stringify({"t": ed.tracos, "c": ed.carimbos})
			if f == "chegada" and n >= 1:
				var ci := -1
				for k in ed.carimbos.size():
					if ed.carimbos[k]["tipo"] == "chegada":
						ci = k
						break
				encaixa(ed.carimbos[ci], w)
				ed.gesto = {"k": "move", "i": ci, "antes": antes, "mexeu": true, "novo": false}
				som.toca("carimbo")
				mudou_editor(true)
				return
			if n >= LIM[f]:
				aviso("No máximo %d desse por ladeira." % LIM[f], 2.0)
				som.toca("erro")
				return
			var c := {"tipo": f, "x": 0, "y": 0}
			if f == "turbo":
				c["dir"] = 0
			encaixa(c, w)
			ed.carimbos.append(c)
			ed.gesto = {"k": "mira" if f == "turbo" else "move", "i": ed.carimbos.size() - 1, "antes": antes, "mexeu": true, "novo": true}
			som.toca("carimbo")
			mudou_editor(true)


## A ponta mais perto (de um traço ou da tábua) a menos de um dedinho: o traço novo começa colado nela.
func ima_ponta(x: float, y: float):
	var lim := maxf(10.0, 14.0 / _kcss())
	var m = null
	var md := lim * lim
	var cands: Array = [[float(Nucleo.LARGADA[4]), float(Nucleo.LARGADA[5])]]
	for t in ed.tracos:
		var p: Array = t["pts"]
		cands.append([float(p[0]), float(p[1])])
		cands.append([float(p[p.size() - 2]), float(p[p.size() - 1])])
	for c in cands:
		var d: float = (c[0] - x) * (c[0] - x) + (c[1] - y) * (c[1] - y)
		if d < md:
			md = d
			m = Vector2(c[0], c[1])
	return m


func media_dedos() -> float:
	var s := 0.0
	for k in ed.dedos:
		s += ed.dedos[k].y
	return s / ed.dedos.size()


func ed_move(id: int, pt: Vector2, pressionado: bool) -> void:
	if tela != "editor":
		return
	if ed.dedos.has(id):
		ed.dedos[id] = pt
	if ed.pan != null:
		var y: float = media_dedos() if ed.dedos.size() >= 2 else pt.y
		ed.cam_y = ed.pan["cam"] - (y - ed.pan["y"]) / mundo.K
		rola_editor(0)
		return
	var w := mundo_de(pt)
	ed.cursor = w
	if not ed.dedos.has(id) or not pressionado:
		return
	ed.tela_pt = pt
	if ed.traco != null:
		soma_ponto(w)
	elif ed.gesto != null:
		var g: Dictionary = ed.gesto
		if g["k"] == "apaga":
			apaga_em(w)
		elif g["k"] == "move" and g["i"] < ed.carimbos.size():
			encaixa(ed.carimbos[g["i"]], w)
			g["mexeu"] = true
			mudou_editor(true)
		elif g["k"] == "mira" and g["i"] < ed.carimbos.size():
			var c: Dictionary = ed.carimbos[g["i"]]
			var dx := w.x - float(c["x"])
			var dy := w.y - float(c["y"])
			if dx * dx + dy * dy > 14.0 * 14.0:
				var d := Fases.dir_de(atan2(dy, dx) / Fases.GRAU)
				if d != int(c.get("dir", 0)):
					c["dir"] = d
					g["mexeu"] = true
					mudou_editor(true)


func ed_up(id: int) -> void:
	if tela != "editor":
		return
	ed.dedos.erase(id)
	if ed.pan != null:
		if ed.dedos.is_empty():
			ed.pan = null
		return
	if ed.traco != null:
		fecha_traco()
	if ed.gesto != null:
		var g: Dictionary = ed.gesto
		ed.gesto = null
		if g["k"] == "mira" and not g["mexeu"] and not g.get("novo", false):
			if g["i"] < ed.carimbos.size():
				var c: Dictionary = ed.carimbos[g["i"]]
				c["dir"] = (int(c.get("dir", 0)) + 2) & 15
				g["mexeu"] = true
				som.toca("clique")
		if g["mexeu"]:
			if g.get("antes", null) != null:
				ed.desfaz.append(g["antes"])
				if ed.desfaz.size() > 80:
					ed.desfaz.pop_front()
			mudou_editor(true)
	ed.tela_pt = null


func soma_ponto(w: Vector2) -> void:
	var t: Dictionary = ed.traco
	var pts: Array = t["pts"]
	var n := pts.size()
	var lx: float = pts[n - 2]
	var ly: float = pts[n - 1]
	var x := clampf(w.x, 0.0, Nucleo.LARG)
	var y := clampf(w.y, 0.0, Nucleo.ALT_MAX)
	var d := Vector2(x - lx, y - ly).length()
	if d < 2.5:
		return
	var resta := TINTA_MAX - tinta_cache - float(t["len"])
	if d > resta:
		if resta < 2.0:
			fecha_traco()
			sem_giz()
			return
		x = lx + (x - lx) * resta / d
		y = ly + (y - ly) * resta / d
		pts.append(x)
		pts.append(y)
		t["len"] += resta
		fecha_traco()
		sem_giz()
		return
	pts.append(x)
	pts.append(y)
	t["len"] += d
	ed.risca = minf(1.0, ed.risca + d / 30.0)
	atualiza_tinta(t["len"])
	mundo.giz_vivo(pts, t["cor"])


func sem_giz() -> void:
	aviso("Acabou o giz. Apaga alguma coisa pra desenhar mais.", 2.6)
	som.toca("erro")
	var tw := create_tween()
	var x0 := tinta_bar.position.x
	tw.tween_property(tinta_bar, "position:x", x0 - Estilo.pf(4), 0.075)
	tw.tween_property(tinta_bar, "position:x", x0 + Estilo.pf(4), 0.15)
	tw.tween_property(tinta_bar, "position:x", x0, 0.075)


## Fecha o traço: tira os pontos que não fazem falta (Douglas-Peucker) e arredonda pro inteiro.
func simplifica(pts: Array, eps: float) -> Array:
	@warning_ignore("integer_division")
	var n := pts.size() / 2
	if n < 3:
		return pts.duplicate()
	var manter := PackedByteArray()
	manter.resize(n)
	manter[0] = 1
	manter[n - 1] = 1
	var pilha: Array = [[0, n - 1]]
	while not pilha.is_empty():
		var ab: Array = pilha.pop_back()
		var a: int = ab[0]
		var b: int = ab[1]
		var ax: float = pts[a * 2]
		var ay: float = pts[a * 2 + 1]
		var dx: float = float(pts[b * 2]) - ax
		var dy: float = float(pts[b * 2 + 1]) - ay
		var l := Vector2(dx, dy).length()
		if l == 0.0:
			l = 1.0
		var md := -1.0
		var mi := -1
		for i in range(a + 1, b):
			var d := absf((float(pts[i * 2]) - ax) * dy - (float(pts[i * 2 + 1]) - ay) * dx) / l
			if d > md:
				md = d
				mi = i
		if md > eps:
			manter[mi] = 1
			pilha.append([a, mi])
			pilha.append([mi, b])
	var o: Array = []
	for i in n:
		if manter[i] == 1:
			o.append(pts[i * 2])
			o.append(pts[i * 2 + 1])
	return o


func fecha_traco() -> void:
	var t = ed.traco
	ed.traco = null
	mundo.giz_vivo([], 0)
	if t == null:
		return
	var p: Array = []
	for v in simplifica(t["pts"], 1.3):
		p.append(int(Nucleo.js_round(float(v))))
	var q: Array = []
	var i := 0
	while i < p.size():
		if q.size() > 0 and q[q.size() - 2] == p[i] and q[q.size() - 1] == p[i + 1]:
			i += 2
			continue
		q.append(clampi(p[i], 0, int(Nucleo.LARG)))
		q.append(clampi(p[i + 1], 0, Nucleo.ALT_MAX))
		i += 2
	if q.size() < 4:
		# um toque só (sem arrastar) vira um pontinho de giz de 6 de largura: dá pra fazer degrau
		if t["pts"].size() >= 2 and t["len"] < 3.0:
			var x := int(Nucleo.js_round(float(t["pts"][0])))
			var y := int(Nucleo.js_round(float(t["pts"][1])))
			q = [clampi(x - 3, 0, int(Nucleo.LARG)), y, clampi(x + 3, 0, int(Nucleo.LARG)), y]
		else:
			atualiza_tinta()
			return
	guarda_desfaz()
	ed.tracos.append({"cor": t["cor"], "pts": q})
	mudou_editor()


func apaga_em(w: Vector2) -> void:
	var r := maxf(9.0, 16.0 / _kcss())
	var r2 := r * r
	var mexeu := false
	var antes := JSON.stringify({"t": ed.tracos, "c": ed.carimbos})
	var k := ed.tracos.size() - 1
	while k >= 0:
		var p: Array = ed.tracos[k]["pts"]
		var toca := false
		var i := 2
		while i < p.size() and not toca:
			var ax: float = p[i - 2]
			var ay: float = p[i - 1]
			var dx: float = float(p[i]) - ax
			var dy: float = float(p[i + 1]) - ay
			var l2 := dx * dx + dy * dy
			if l2 == 0.0:
				l2 = 1.0
			var u := clampf(((w.x - ax) * dx + (w.y - ay) * dy) / l2, 0.0, 1.0)
			var ex := w.x - ax - dx * u
			var ey := w.y - ay - dy * u
			if ex * ex + ey * ey < r2:
				toca = true
			i += 2
		if toca:
			ed.tracos.remove_at(k)
			mexeu = true
		k -= 1
	var ci = carimbo_em(w, maxf(16.0, r))
	if ci != null:
		ed.carimbos.remove_at(ci)
		mexeu = true
	if mexeu:
		if ed.gesto == null or not ed.gesto["mexeu"]:
			ed.desfaz.append(antes)
			if ed.desfaz.size() > 80:
				ed.desfaz.pop_front()
		if ed.gesto != null:
			ed.gesto["mexeu"] = true
			ed.gesto["antes"] = null
		som.toca("apaga")
		mundo.poeira(w.x, w.y, 6, 50.0)
		mudou_editor()


func testa_editor() -> void:
	if tela != "editor":
		return
	if ed.tracos.is_empty():
		aviso("Desenha a ladeira antes de testar.", 2.0)
		som.toca("erro")
		return
	ed.cam_y = cam_y
	joga_fase(fase_do_editor(), "teste", {})


func passo_editor(dt: float) -> void:
	# desenhando perto do pé da tela, a câmera desce sozinha
	if ed.traco != null and ed.tela_pt != null:
		var zona := tam.y - (ed_ferr.get_meta("fundo") as Control).size.y - tam.y * 0.12
		var tp: Vector2 = ed.tela_pt
		if tp.y > zona:
			var v := clampf((tp.y - zona) / (tam.y * 0.12), 0.0, 1.4) * 640.0
			var ant := ed.cam_y
			rola_editor(v * dt)
			if ed.cam_y != ant:
				soma_ponto(Vector2((tp.x - mundo.COLX) / mundo.K, tp.y / mundo.K + cam_y))
	ed.risca = maxf(0.0, ed.risca - dt * 4.0)
	if ed.dica_t > 0.0:
		ed.dica_t -= dt
		if ed.dica_t <= 0.0:
			ed_dica.visible = false
	cam_y = ed.cam_y


func tira_para(y: float) -> void:
	if tela != "editor":
		return
	var f := clampf(y / tam.y, 0.0, 1.0)
	ed.cam_y = -40.0 + f * mundo.altura_tira() - mundo.VH / 2.0
	rola_editor(0)


# ---------------------------------------------------------------- os comandos
func _area_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_desce(t.index, t.position, MOUSE_BUTTON_LEFT)
		else:
			_sobe(t.index, t.position)
		area.accept_event()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_move(d.index, d.position, true)
		area.accept_event()
	elif e is InputEventMouseButton:
		var m := e as InputEventMouseButton
		if m.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if m.button_index == MOUSE_BUTTON_WHEEL_UP or m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if m.pressed and tela == "editor":
				rola_editor((-1.0 if m.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0) * 100.0 * m.factor / _kcss())
			return
		if m.pressed:
			_desce(100 + m.button_index, m.position, m.button_index)
		else:
			_sobe(100 + m.button_index, m.position)
		area.accept_event()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var algum := false
		for b in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if ed.dedos.has(100 + b) or tira_dedo == 100 + b:
				_move(100 + b, mm.position, true)
				algum = true
		if not algum:
			_move(100 + MOUSE_BUTTON_LEFT, mm.position, false)


func _na_tira(pt: Vector2) -> bool:
	return pt.x >= mundo.TIRAX and pt.x <= mundo.TIRAX + mundo.TIRAW


func _desce(id: int, pt: Vector2, botao: int) -> void:
	if tela == "jogo":
		var vazio := dedos_jogo.is_empty()
		dedos_jogo[id] = true
		if vazio:
			apertou()
	elif tela == "editor":
		if _na_tira(pt) and ed.dedos.is_empty():
			tira_dedo = id
			tira_para(pt.y)
			return
		ed_down(id, pt, botao)


func _sobe(id: int, _pt: Vector2) -> void:
	if dedos_jogo.has(id):
		dedos_jogo.erase(id)
		if dedos_jogo.is_empty():
			soltou()
	if tira_dedo == id:
		tira_dedo = null
		return
	if tela == "editor":
		ed_up(id)


func _move(id: int, pt: Vector2, pressionado: bool) -> void:
	if tira_dedo == id:
		tira_para(pt.y)
		return
	if tela == "editor":
		ed_move(id, pt, pressionado)


## Rolar o cartão arrastando o dedo, mesmo começando em cima de um botão (no navegador é assim que se rola).
## Passou de uns pontos na vertical, vira rolagem: o botão que tava sendo apertado desiste e nada é clicado.
var _rola = null


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			if _rola == null and cartao_atual != null and cartoes.has(cartao_atual):
				var sc: ScrollContainer = cartoes[cartao_atual].get_meta("scroll")
				var bar := sc.get_v_scroll_bar()
				if sc.get_global_rect().has_point(t.position) and bar.max_value > sc.size.y + 1.0:
					_rola = {"i": t.index, "y0": t.position.y, "s0": sc.scroll_vertical, "sc": sc, "rolando": false}
		elif _rola != null and t.index == _rola["i"]:
			if _rola["rolando"]:
				get_viewport().set_input_as_handled()
			_rola = null
	elif e is InputEventScreenDrag and _rola != null:
		var d := e as InputEventScreenDrag
		if d.index != _rola["i"]:
			return
		var dy: float = d.position.y - _rola["y0"]
		if not _rola["rolando"] and absf(dy) > pf(8):
			_rola["rolando"] = true
			# o botão debaixo do dedo larga sem clicar (soltou longe dele)
			var solta := InputEventMouseButton.new()
			solta.button_index = MOUSE_BUTTON_LEFT
			solta.pressed = false
			solta.position = Vector2(-9999, -9999)
			solta.global_position = solta.position
			get_viewport().push_input(solta, true)
		if _rola["rolando"]:
			var sc: ScrollContainer = _rola["sc"]
			if is_instance_valid(sc):
				sc.scroll_vertical = int(_rola["s0"] - dy)
			get_viewport().set_input_as_handled()
	elif (e is InputEventMouseButton or e is InputEventMouseMotion) and _rola != null and _rola["rolando"]:
		if (e as InputEventMouse).device == InputEvent.DEVICE_ID_EMULATION:
			get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey):
		return
	var k := e as InputEventKey
	var cod := k.keycode
	if not k.pressed:
		if teclas_jogo.has(cod):
			teclas_jogo.erase(cod)
			if teclas_jogo.is_empty() and dedos_jogo.is_empty():
				soltou()
		return
	if tela == "jogo":
		if cartao_atual == "fim" or cartao_atual == "manda" or cartao_atual == "nome":
			if cod == KEY_ESCAPE:
				sai_do_jogo()
			return
		if PULA.has(cod):
			get_viewport().set_input_as_handled()
			if k.echo:
				return
			var vazio := teclas_jogo.is_empty() and dedos_jogo.is_empty()
			teclas_jogo[cod] = true
			if vazio:
				apertou()
			return
		if (cod == KEY_R or cod == KEY_ENTER) and cartao_atual != "fim":
			reinicia()
			return
		if cod == KEY_ESCAPE:
			sai_do_jogo()
			return
	elif tela == "editor":
		if (k.ctrl_pressed or k.meta_pressed) and cod == KEY_Z:
			desfaz()
			return
		var n := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6].find(cod)
		if n >= 0 and not k.ctrl_pressed and not k.meta_pressed:
			escolhe_ferr(["lapis", "borracha", "mola", "turbo", "cachorro", "chegada"][n])
			return
		if cod == KEY_T:
			testa_editor()
			return
		if cod == KEY_DOWN or cod == KEY_PAGEDOWN:
			rola_editor(mundo.VH * 0.8 if cod == KEY_PAGEDOWN else 60.0)
			return
		if cod == KEY_UP or cod == KEY_PAGEUP:
			rola_editor(-mundo.VH * 0.8 if cod == KEY_PAGEUP else -60.0)
			return
		if cod == KEY_ESCAPE:
			mostra_inicio()
	elif cod == KEY_ESCAPE:
		if cartao_atual == "cola" or cartao_atual == "desafio":
			mostra_inicio()
		elif cartao_atual == "nome":
			volta_nome()
		elif cartao_atual == "manda":
			_volta_manda()


func _volta_manda() -> void:
	som.toca("clique")
	if manda == null:
		mostra_inicio()
		return
	if manda["volta"] == "editor":
		so_cartao(null)
		mostra_ui()
	elif manda["volta"] == "fim" and jogo != null:
		so_cartao("fim")
	else:
		mostra_inicio()


func liga_som(on: bool) -> void:
	som.liga(on)
	Dados.guarda("som", "1" if on else "0")
	for b in b_som:
		if is_instance_valid(b):
			b.icon = Estilo.icone_tex("som" if on else "mudo", 22.0)
			b.modulate.a = 1.0 if on else 0.55


# ---------------------------------------------------------------- o laço
var _perf := {}


func perf_zera() -> void:
	_perf = {}


func perf_txt() -> String:
	var o := ""
	for k in _perf:
		o += "%s %.2f ms, " % [k, _perf[k][0] / maxf(1.0, _perf[k][1]) / 1000.0]
	return o


func _mede_perf(k: String, t0: int) -> void:
	var a: Array = _perf.get(k, [0.0, 0])
	a[0] += float(Time.get_ticks_usec() - t0)
	a[1] += 1
	_perf[k] = a


func _process(dt: float) -> void:
	var tp := Time.get_ticks_usec()
	dt = clampf(dt, 0.0, 0.1)
	tempo += dt
	if tela == "jogo" and jogo != null:
		passo_jogo(dt)
	elif tela == "editor":
		passo_editor(dt)
	elif demo != null:
		passo_demo(dt)
	mundo.passo_particulas(dt)
	tremor = maxf(0.0, tremor - dt * 1.4)
	if aviso_t > 0.0:
		aviso_t -= dt
		if aviso_t <= 0.0:
			aviso_no.visible = false
	if carimbo_t > 0.0:
		carimbo_t -= dt
		if carimbo_t <= 0.0:
			carimbo_no.visible = false
	mundo.posiciona(cam_y, tremor)
	if tela == "jogo" and jogo != null and jogo.S.fim == "":
		var S := jogo.S
		var vx := (S.v[0] + S.v[2]) / 2.0
		var vy := (S.v[1] + S.v[3]) / 2.0
		som.atualiza(sqrt(vx * vx + vy * vy), S.c0 != 0 or S.c1 != 0, 0.0, dt)
	else:
		som.atualiza(0.0, false, ed.risca if (tela == "editor" and ed.traco != null) else 0.0, dt)
	if cartao_atual != null:
		_ajusta_cartao()
	if rascunho_t > 0.0:
		rascunho_t -= dt
		if rascunho_t <= 0.0:
			_grava_rascunho()
	salva_t += dt
	if salva_t > 2.0:
		salva_t = 0.0
		Dados.salva()
	# os sons ficam prontos um por quadro, e o robô da casa trabalha um tiquinho quando ninguém tá descendo
	som.prepara_um()
	if tela != "jogo":
		_trabalha(3.0)
	if OS.has_feature("web"):
		_estado_web(dt)
	_mede_perf("logica", tp)


# ---------------------------------------------------------------- a cara (os nós da interface)
func _monta_ui() -> void:
	for c in camada.get_children():
		c.queue_free()
	cartoes.clear()
	b_som.clear()
	ferr_bts.clear()
	cor_bts.clear()
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(ui)
	area = Control.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_area_input)
	ui.add_child(area)
	coluna = Control.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.position = Vector2(mundo.COLX, 0)
	coluna.size = Vector2(mundo.COLW, tam.y)
	ui.add_child(coluna)

	# a dica da descida
	dica_jogo = CenterContainer.new()
	dica_jogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica_jogo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dica_jogo.offset_top = -pf(18 + 50)
	dica_jogo.offset_bottom = -pf(18)
	coluna.add_child(dica_jogo)
	var pil := PanelContainer.new()
	pil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pil.add_theme_stylebox_override("panel", Estilo.margens(Estilo.caixa(Estilo.VIDRO, 22, 2, Estilo.g(0.22)), 8, 14))
	dica_jogo.add_child(pil)
	dica_tx = Estilo.rico("", Estilo.t700, 14, Estilo.GIZ)
	dica_tx.autowrap_mode = TextServer.AUTOWRAP_OFF
	pil.add_child(dica_tx)

	# a dica a giz do editor
	ed_dica = Estilo.rotulo("", Estilo.giz, 19, Estilo.GIZ, HORIZONTAL_ALIGNMENT_CENTER)
	ed_dica.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ed_dica.offset_left = pf(18)
	ed_dica.offset_right = -pf(18)
	ed_dica.offset_top = -pf(136 + 60)
	ed_dica.offset_bottom = -pf(136)
	ed_dica.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_sombra_lbl(ed_dica)
	ed_dica.visible = false
	coluna.add_child(ed_dica)

	# o placar da descida
	hud = HBoxContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = pf(12)
	hud.offset_right = -pf(10)
	hud.offset_top = pf(10)
	coluna.add_child(hud)
	var esq := VBoxContainer.new()
	esq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.add_theme_constant_override("separation", px(5))
	hud.add_child(esq)
	var tam_rel := 29.0 if tam.x / P <= 420.0 else 34.0
	relogio = Estilo.rico("0,00", Estilo.tit, tam_rel, Estilo.GIZ, false)
	relogio.autowrap_mode = TextServer.AUTOWRAP_OFF
	_sombra(relogio, Color.BLACK, 3)
	esq.add_child(relogio)
	alvo = Estilo.rico("", Estilo.t700, 13, Estilo.GIZ2, false, Estilo.t800)
	_sombra(alvo, Color.BLACK, 1)
	esq.add_child(alvo)
	var bts := HBoxContainer.new()
	bts.add_theme_constant_override("separation", px(6))
	bts.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hud.add_child(bts)
	var br: Button = marca("reinicia", Estilo.botao("", "r", "reinicia"))
	br.tooltip_text = "Recomeçar (R)"
	br.pressed.connect(reinicia)
	bts.add_child(br)
	bts.add_child(_bt_som())
	var bs: Button = marca("sai", Estilo.botao("", "r", "sai"))
	bs.tooltip_text = "Sair (Esc)"
	bs.pressed.connect(func(): som.toca("clique"); sai_do_jogo())
	bts.add_child(bs)

	# o editor: em cima
	ed_topo = HBoxContainer.new()
	ed_topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ed_topo.offset_left = pf(8)
	ed_topo.offset_right = -pf(8)
	ed_topo.offset_top = pf(8)
	ed_topo.offset_bottom = pf(8 + 44)
	ed_topo.add_theme_constant_override("separation", px(6))
	ed_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo_topo := _degrade(true, pf(8 + 44 + 14))
	coluna.add_child(fundo_topo)
	ed_topo.set_meta("fundo", fundo_topo)
	coluna.add_child(ed_topo)
	var bv: Button = marca("eVolta", Estilo.botao("", "r", "volta"))
	bv.tooltip_text = "Voltar pro começo"
	bv.pressed.connect(func(): som.toca("clique"); mostra_inicio())
	ed_topo.add_child(bv)
	var tinta := VBoxContainer.new()
	tinta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tinta.alignment = BoxContainer.ALIGNMENT_CENTER
	tinta.add_theme_constant_override("separation", px(3))
	tinta.custom_minimum_size.x = pf(46)
	tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ed_topo.add_child(tinta)
	tinta_lbl = Estilo.olho("Giz: 100%", 9.0 if tam.x / P <= 360.0 else 10.0, 0.12, Estilo.GIZ2, HORIZONTAL_ALIGNMENT_LEFT)
	tinta_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tinta_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tinta_lbl.clip_text = true
	tinta.add_child(tinta_lbl)
	tinta_bar = Control.new()
	tinta_bar.custom_minimum_size.y = pf(10)
	tinta_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tinta_bar.draw.connect(func():
		var r := Rect2(Vector2.ZERO, tinta_bar.size)
		tinta_bar.draw_style_box(Estilo.caixa(Estilo.g(0.14), 6), r)
		if tinta_frac > 0.0:
			var w := maxf(r.size.x * tinta_frac, pf(6) if tinta_frac > 0.0 else 0.0)
			tinta_bar.draw_style_box(Estilo.caixa(Estilo.LARANJA if tinta_frac < 0.15 else Estilo.GIZ, 6), Rect2(0, 0, w, r.size.y)))
	tinta.add_child(tinta_bar)
	var bdz: Button = marca("eDesfaz", Estilo.botao("", "r", "desfaz"))
	bdz.tooltip_text = "Desfazer (Ctrl+Z)"
	bdz.pressed.connect(desfaz)
	ed_topo.add_child(bdz)
	var bl := Estilo.botao("", "r", "lixo")
	bl.tooltip_text = "Apagar a ladeira toda"
	bl.pressed.connect(func(): som.toca("clique"); apaga_tudo.visible = not apaga_tudo.visible)
	ed_topo.add_child(bl)
	var curto := tam.x / P <= 420.0
	var bt: Button = marca("eTesta", Estilo.botao("" if curto else "Testar", "testa", "testa"))
	bt.tooltip_text = "Testar (T)"
	bt.pressed.connect(func(): som.toca("clique"); testa_editor())
	ed_topo.add_child(bt)
	e_manda = marca("eManda", Estilo.botao("" if curto else "Mandar", "manda_off", "cadeado"))
	e_manda.pressed.connect(_e_manda)
	ed_topo.add_child(e_manda)

	# o editor: as ferramentas embaixo
	ed_ferr = HBoxContainer.new()
	ed_ferr.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var alt_f := 56.0 if curto else 60.0
	ed_ferr.offset_top = -pf(alt_f + 10)
	ed_ferr.offset_bottom = -pf(10)
	ed_ferr.offset_left = pf(6)
	ed_ferr.offset_right = -pf(6)
	ed_ferr.alignment = BoxContainer.ALIGNMENT_CENTER
	ed_ferr.add_theme_constant_override("separation", px(3 if tam.x / P <= 360.0 else 4))
	ed_ferr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo_ferr := _degrade(false, pf(alt_f + 26))
	coluna.add_child(fundo_ferr)
	ed_ferr.set_meta("fundo", fundo_ferr)
	coluna.add_child(ed_ferr)
	var nomes_f := {"lapis": "Giz", "borracha": "Apaga", "mola": "Mola", "turbo": "Turbo", "cachorro": "Cachorro", "chegada": "Chegada"}
	for f in ["lapis", "borracha", "mola", "turbo", "cachorro", "chegada"]:
		var b := Button.new()
		b.text = nomes_f[f]
		b.icon = Estilo.icone_tex(f, 21.0 if tam.x / P <= 360.0 else 24.0)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, pf(alt_f))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = nomes_f[f]
		var ff: String = f
		b.pressed.connect(func(): escolhe_ferr(ff))
		ferr_bts[f] = b
		marca("ferr_" + f, b)
		ed_ferr.add_child(b)
	ed_ferr.resized.connect(_limita_ferr)

	# as cores do giz
	cores_no = PanelContainer.new()
	cores_no.add_theme_stylebox_override("panel", Estilo.margens(Estilo.caixa(Estilo.VIDRO, 14, 2, Estilo.g(0.16)), 6, 6))
	cores_no.position = Vector2(pf(10), tam.y - pf(86) - pf(34 + 16))
	coluna.add_child(cores_no)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", px(6))
	cores_no.add_child(hc)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(pf(34), pf(34))
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Giz " + Estilo.NOMES_COR[i]
		var ii := i
		b.draw.connect(func():
			var c: Color = Estilo.CORES_GIZ[ii]
			b.draw_set_transform(b.size / 2.0, deg_to_rad(28), Vector2.ONE)
			b.draw_style_box(Estilo.caixa(c, 3), Rect2(-pf(4), -pf(12), pf(8), pf(24)))
			b.draw_rect(Rect2(pf(2), -pf(12), pf(2), pf(24)), Color(0, 0, 0, 0.18))
			b.draw_set_transform_matrix(Transform2D.IDENTITY))
		b.pressed.connect(func():
			ed.cor = ii
			_estilo_cores()
			som.toca("clique"))
		cor_bts.append(b)
		hc.add_child(b)
	_estilo_cores()

	# apagar tudo?
	apaga_tudo = PanelContainer.new()
	apaga_tudo.add_theme_stylebox_override("panel", Estilo.margens(Estilo.caixa(Estilo.VIDRO, 14, 2, Estilo.g(0.2)), 8, 8))
	coluna.add_child(apaga_tudo)
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", px(6))
	apaga_tudo.add_child(ha)
	var la := Estilo.rotulo("Apagar tudo?", Estilo.t700, 14, Estilo.GIZ, HORIZONTAL_ALIGNMENT_LEFT, false)
	la.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ha.add_child(la)
	var bsim := Estilo.botao("Apagar")
	bsim.custom_minimum_size.y = pf(38)
	bsim.add_theme_font_size_override("font_size", px(14))
	bsim.pressed.connect(func():
		guarda_desfaz()
		ed.tracos = []
		ed.carimbos = []
		apaga_tudo.visible = false
		som.toca("apaga")
		mudou_editor()
		aviso("Apagou. Se arrependeu? Desfaz.", 2.2))
	ha.add_child(bsim)
	var bnao := Estilo.botao("Não")
	bnao.custom_minimum_size.y = pf(38)
	bnao.add_theme_font_size_override("font_size", px(14))
	bnao.pressed.connect(func(): apaga_tudo.visible = false)
	ha.add_child(bnao)
	apaga_tudo.visible = false
	apaga_tudo.resized.connect(func(): apaga_tudo.position = Vector2(mundo.COLW - pf(8) - apaga_tudo.size.x, pf(66)))

	# o carimbo do CAPOTOU / CHEGOU
	carimbo_no = PanelContainer.new()
	carimbo_no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(carimbo_no)
	var vc := VBoxContainer.new()
	vc.add_theme_constant_override("separation", px(6))
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carimbo_no.add_child(vc)
	car_t = Estilo.rotulo("CAPOTOU!", Estilo.tit, 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	car_t.add_theme_constant_override("line_spacing", -px(8))
	vc.add_child(car_t)
	car_s = Estilo.rotulo("", Estilo.t800, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	vc.add_child(car_s)
	carimbo_no.visible = false

	# o "toca de novo"
	pos_no = VBoxContainer.new()
	pos_no.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pos_no.offset_top = -pf(16 + 260)
	pos_no.offset_bottom = -pf(16)
	pos_no.offset_left = pf(14)
	pos_no.offset_right = -pf(14)
	pos_no.alignment = BoxContainer.ALIGNMENT_END
	pos_no.add_theme_constant_override("separation", px(10))
	pos_no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(pos_no)
	pos_tx = Estilo.rotulo("Toca pra tentar de novo", Estilo.giz, 22, Estilo.GIZ, HORIZONTAL_ALIGNMENT_CENTER)
	pos_tx.add_theme_color_override("font_shadow_color", Color.BLACK)
	pos_tx.add_theme_constant_override("shadow_offset_y", px(2))
	pos_tx.add_theme_constant_override("shadow_offset_x", 0)
	pos_no.add_child(pos_tx)
	var hp := HBoxContainer.new()
	hp.alignment = BoxContainer.ALIGNMENT_CENTER
	hp.add_theme_constant_override("separation", px(10))
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_no.add_child(hp)
	p_editor = Estilo.botao("Voltar pro editor")
	p_editor.custom_minimum_size.x = pf(130)
	p_editor.pressed.connect(func(): som.toca("clique"); abre_editor())
	hp.add_child(p_editor)
	var psai: Button = marca("pSai", Estilo.botao("Sair"))
	psai.custom_minimum_size.x = pf(130)
	psai.pressed.connect(func(): som.toca("clique"); sai_do_jogo())
	hp.add_child(psai)
	pos_no.visible = false

	# o véu e os cartões
	var gr := Gradient.new()
	gr.set_color(0, Color(11.0 / 255, 10.0 / 255, 14.0 / 255, 0.55))
	gr.set_color(1, Color(11.0 / 255, 10.0 / 255, 14.0 / 255, 0.86))
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(1.28, 0.4)
	gt.width = 128
	gt.height = 128
	var vt := TextureRect.new()
	vt.texture = gt
	vt.stretch_mode = TextureRect.STRETCH_SCALE
	vt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vt.set_anchors_preset(Control.PRESET_FULL_RECT)
	vt.mouse_filter = Control.MOUSE_FILTER_STOP
	veu = vt
	ui.add_child(veu)
	veu.visible = false

	# o aviso de cima
	aviso_no = PanelContainer.new()
	aviso_no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sa := Estilo.margens(Estilo.caixa(Estilo.GIZ, 12), 9, 14)
	sa.shadow_color = Color(0, 0, 0, 0.4)
	sa.shadow_size = 1
	sa.shadow_offset = Vector2(0, pf(6))
	aviso_no.add_theme_stylebox_override("panel", sa)
	aviso_lbl = Estilo.rotulo("", Estilo.t800, 14, Estilo.TINTA, HORIZONTAL_ALIGNMENT_CENTER)
	aviso_no.add_child(aviso_lbl)
	aviso_no.visible = false
	ui.add_child(aviso_no)
	_posiciona_coluna()
	liga_som(som.ligado)


func _posiciona_coluna() -> void:
	coluna.position = Vector2(mundo.COLX, 0)
	coluna.size = Vector2(mundo.COLW, tam.y)
	cores_no.position = Vector2(Estilo.pf(10), tam.y - Estilo.pf(86) - Estilo.pf(34 + 16))


func _limita_ferr() -> void:
	# cada ferramenta até 74 px de largura (o max-width do CSS)
	var n := ferr_bts.size()
	var maxw := Estilo.pf(74)
	var sep := ed_ferr.get_theme_constant("separation")
	var total := ed_ferr.size.x
	var w := minf(maxw, (total - sep * (n - 1)) / n)
	for k in ferr_bts:
		var b: Button = ferr_bts[k]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if w >= maxw else Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = w if w >= maxw else 0.0


func _estilo_ferr(b: Button, ligado: bool) -> void:
	var sb := Estilo.caixa(Estilo.GIZ if ligado else Estilo.g(0.05), 13, 2, Estilo.GIZ if ligado else Estilo.g(0.12))
	Estilo.margens(sb, 6, 2)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var curto := tam.x / P <= 420.0
	b.add_theme_font_override("font", Estilo.t700)
	b.add_theme_font_size_override("font_size", Estilo.px(9.5 if tam.x / P <= 360.0 else (10.0 if curto else 11.0)))
	var c := Estilo.TINTA if ligado else Estilo.GIZ
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(k, c)
	b.add_theme_constant_override("h_separation", Estilo.px(3))


func _estilo_cores() -> void:
	for i in cor_bts.size():
		var b: Button = cor_bts[i]
		var sb := Estilo.caixa(Color(0, 0, 0, 0.3), 10, 2, Estilo.GIZ if i == ed.cor else Color(0, 0, 0, 0))
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(k, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.queue_redraw()


func _e_manda() -> void:
	if not editor_liberado():
		som.toca("erro")
		var tem := false
		for c in ed.carimbos:
			if c["tipo"] == "chegada":
				tem = true
		aviso("Desce até a chegada primeiro: aí libera." if tem else "Põe a CHEGADA e desce até ela: aí libera.", 2.6)
		return
	som.toca("clique")
	precisa_nome(manda_do_editor)


func _bt_som() -> Button:
	var b := Estilo.botao("", "r", "som" if som.ligado else "mudo")
	b.tooltip_text = "Som"
	b.modulate.a = 1.0 if som.ligado else 0.55
	b.pressed.connect(func():
		liga_som(not som.ligado)
		if som.ligado:
			som.toca("clique"))
	b_som.append(b)
	return b


func _degrade(de_cima: bool, alt: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if de_cima:
		c.set_anchors_preset(Control.PRESET_TOP_WIDE)
		c.offset_bottom = alt
	else:
		c.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		c.offset_top = -alt
	c.draw.connect(func():
		var w := c.size.x
		var h := c.size.y
		var cs: Array
		var ys: Array
		if de_cima:
			ys = [0.0, h * 0.7, h]
			cs = [Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.94), Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.78), Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.0)]
		else:
			ys = [0.0, h * 0.32, h]
			cs = [Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.0), Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.8), Color(13.0 / 255, 12.0 / 255, 17.0 / 255, 0.95)]
		for i in 2:
			c.draw_polygon(PackedVector2Array([Vector2(0, ys[i]), Vector2(w, ys[i]), Vector2(w, ys[i + 1]), Vector2(0, ys[i + 1])]), PackedColorArray([cs[i], cs[i], cs[i + 1], cs[i + 1]])))
	c.resized.connect(c.queue_redraw)
	return c


func _sombra(r: RichTextLabel, c: Color, dy: float) -> void:
	r.add_theme_color_override("font_shadow_color", c)
	r.add_theme_constant_override("shadow_offset_x", 0)
	r.add_theme_constant_override("shadow_offset_y", Estilo.px(dy))


func _sombra_lbl(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", Estilo.px(2))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("outline_size", Estilo.px(6))


func _linha(bts: Array) -> Container:
	# a .linha do CSS: lado a lado, ou um embaixo do outro quando não cabe (130 px cada)
	var larg := _largura_cartao() - Estilo.pf(36)
	var cabe: bool = larg >= bts.size() * Estilo.pf(130) + (bts.size() - 1) * Estilo.pf(10)
	var c: BoxContainer = HBoxContainer.new() if cabe else VBoxContainer.new()
	c.add_theme_constant_override("separation", Estilo.px(10))
	for b in bts:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(b)
	return c


func _largura_cartao() -> float:
	return minf(Estilo.pf(460), tam.x - Estilo.pf(24))


## Um cartão novo (ou refeito): o painel, a rolagem e a coluna onde vai o conteúdo.
func _novo_cartao(id: String) -> VBoxContainer:
	if cartoes.has(id):
		cartoes[id].queue_free()
		cartoes.erase(id)
	var p := PanelContainer.new()
	var sb := Estilo.caixa(Estilo.CARTAO, 20, 2, Estilo.BORDA)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = Estilo.px(35)
	sb.shadow_offset = Vector2(0, pf(22))
	Estilo.margens(sb, 0, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# a barra de rolagem fininha e discreta (a do navegador quase não aparece)
	var bar := sc.get_v_scroll_bar()
	var trilho := StyleBoxEmpty.new()
	trilho.content_margin_left = pf(3)
	trilho.content_margin_right = pf(3)
	bar.add_theme_stylebox_override("scroll", trilho)
	bar.add_theme_stylebox_override("scroll_focus", trilho)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(k, Estilo.caixa(Estilo.g(0.22 if k == "grabber" else 0.35), 3))
	p.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var curto := tam.x / P <= 360.0
	m.add_theme_constant_override("margin_top", Estilo.px(16 if curto else 20))
	m.add_theme_constant_override("margin_left", Estilo.px(14 if curto else 18))
	m.add_theme_constant_override("margin_right", Estilo.px(14 if curto else 18))
	m.add_theme_constant_override("margin_bottom", Estilo.px(14 if curto else 18))
	sc.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", Estilo.px(9 if tam.y / P < 560.0 else 12))
	m.add_child(v)
	p.set_meta("scroll", sc)
	p.set_meta("margem", m)
	ui.add_child(p)
	ui.move_child(aviso_no, -1)
	p.visible = false
	cartoes[id] = p
	return v


func _ajusta_cartao() -> void:
	var id = cartao_atual
	if id == null or not cartoes.has(id):
		return
	var p: PanelContainer = cartoes[id]
	var m: MarginContainer = p.get_meta("margem")
	var w := _largura_cartao()
	var h := minf(m.get_combined_minimum_size().y + Estilo.pf(4), tam.y - Estilo.pf(24))
	var alvo_sz := Vector2(w, h)
	if p.size != alvo_sz:
		p.size = alvo_sz
	p.position = ((tam - alvo_sz) / 2.0).round()


# ---------------------------------------------------------------- os cartões, um por um
func _cartao_inicio() -> void:
	var v := _novo_cartao("inicio")
	# o logo
	var logo := Control.new()
	var tl := clampf(0.17 * tam.x / P, 54.0, 80.0)
	logo.custom_minimum_size = Vector2(0, pf(tl * 0.88 + 6 + 4 + 22 + 6))
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var risco := _risco_logo()
	logo.draw.connect(func():
		var fs := Estilo.px(tl)
		var f := Estilo.tit
		var sz := f.get_string_size("DUVIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var c := Vector2(logo.size.x / 2.0, pf(6) + pf(tl * 0.44))
		logo.draw_set_transform(c, deg_to_rad(-3.0), Vector2.ONE)
		var base := Vector2(-sz.x / 2.0, f.get_ascent(fs) * 0.5 - pf(4))
		logo.draw_string(f, base + Vector2(0, pf(10)), "DUVIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
		logo.draw_string(f, base + Vector2(0, pf(5)), "DUVIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Estilo.AMARELO_SOMBRA)
		logo.draw_string(f, base, "DUVIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Estilo.AMARELO)
		logo.draw_set_transform_matrix(Transform2D.IDENTITY)
		var rw := minf(pf(270), logo.size.x * 0.7)
		var rh := rw * 18.0 / 270.0
		logo.draw_texture_rect(risco, Rect2((logo.size.x - rw) / 2.0, pf(6) + pf(tl * 0.88) + pf(4), rw, rh), false))
	v.add_child(logo)
	v.add_child(Estilo.rico("Desenha a ladeira, desce de rolimã e manda pro amigo: [color=%s]duvido tu descer essa.[/color]" % Estilo.hexa(Estilo.ROSA), Estilo.giz, 21))
	var bf: Button = marca("iFaz", Estilo.botao("Fazer o meu", "vai"))
	bf.pressed.connect(func(): som.toca("clique"); abre_editor())
	var bt: Button = marca("iTenho", Estilo.botao("Tenho um desafio"))
	bt.pressed.connect(func():
		som.toca("clique")
		_cartao_cola()
		so_cartao("cola", "cola"))
	v.add_child(_linha([bf, bt]))
	if nome != "":
		var q := HBoxContainer.new()
		q.alignment = BoxContainer.ALIGNMENT_CENTER
		q.add_theme_constant_override("separation", Estilo.px(8))
		var lq := Estilo.rico("Tu é [color=%s]%s[/color]" % [Estilo.hexa(Estilo.GIZ), esc(nome)], Estilo.t600, 14, Estilo.GIZ2, false, Estilo.t800)
		lq.autowrap_mode = TextServer.AUTOWRAP_OFF
		lq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		q.add_child(lq)
		var tr := Estilo.botao("trocar", "link")
		tr.pressed.connect(func(): som.toca("clique"); pede_nome(Callable(), "Teu nome"))
		q.add_child(tr)
		v.add_child(q)
	v.add_child(_titulo_sec("Ladeiras prontas"))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", Estilo.px(8))
	v.add_child(lista)
	var dia := do_dia()
	var linhas: Array = [{"tipo": "dia", "fase": dia, "nome": "Ladeira do dia", "sub": "Muda à meia-noite, igual pra todo mundo · " + dd(dia["dia"]["d"]) + "/" + dd(dia["dia"]["m"])}]
	var pr := Fases.prontas()
	for i in pr.size():
		linhas.append({"tipo": "pronta", "i": i, "fase": pr[i]["fase"], "nome": str(i + 1) + ". " + pr[i]["nome"], "sub": pr[i]["sub"]})
	for l in linhas:
		lista.add_child(_item_fase(l))
	var pe := HBoxContainer.new()
	pe.add_theme_constant_override("separation", Estilo.px(10))
	var lp := Estilo.rotulo("Toca: pula · Segura no ar: cambalhota", Estilo.t600, 12, Estilo.APAGADO)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pe.add_child(lp)
	pe.add_child(_bt_som())
	v.add_child(pe)


func _risco_logo() -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="18" viewBox="0 0 270 18"><path d="M4 12 C 60 4, 120 16, 170 8 S 250 6, 266 10" fill="none" stroke="#F3EEE2" stroke-width="5" stroke-linecap="round" opacity=".9"/><path d="M30 15 C 90 9, 150 17, 236 12" fill="none" stroke="#F3EEE2" stroke-width="2.5" stroke-linecap="round" opacity=".45"/></svg>'
	var img := Image.new()
	img.load_svg_from_string(svg, maxf(1.0, P * 1.2))
	return ImageTexture.create_from_image(img)


func _titulo_sec(txt: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Estilo.px(10))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Estilo.olho(txt, 12.0, 0.16, Estilo.GIZ2, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var tr := Control.new()
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.draw.connect(func():
		var y := tr.size.y / 2.0
		var x := 0.0
		while x < tr.size.x:
			tr.draw_rect(Rect2(x, y - Estilo.pf(1), minf(Estilo.pf(14), tr.size.x - x), Estilo.pf(2)), Color(1.0, 201.0 / 255, 60.0 / 255, 0.6))
			x += Estilo.pf(24))
	h.add_child(tr)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", Estilo.px(4))
	m.add_child(h)
	return m


func _item_fase(l: Dictionary) -> Control:
	var dia: bool = l["tipo"] == "dia"
	var b := BotaoCaixa.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := Estilo.caixa(Color(0, 0, 0, 0.22), 14, 2, Color(1.0, 201.0 / 255, 60.0 / 255, 0.65) if dia else Estilo.g(0.13))
	if dia:
		sb.bg_color = Color(1.0, 201.0 / 255, 60.0 / 255, 0.1)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.border_color = Estilo.g(0.32) if not dia else Color(1.0, 201.0 / 255, 60.0 / 255, 0.85)
	var sp := sh.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0, 0, 0, 0.35) if not dia else Color(1.0, 201.0 / 255, 60.0 / 255, 0.16)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("hover_pressed", sp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", Estilo.px(7))
	m.add_theme_constant_override("margin_bottom", Estilo.px(7))
	m.add_theme_constant_override("margin_left", Estilo.px(7))
	m.add_theme_constant_override("margin_right", Estilo.px(10))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	b.dentro = m
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", Estilo.px(8 if tam.x / P <= 360.0 else 10))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var curto := tam.x / P <= 360.0
	var mini := MiniFase.new()
	mini.fase = l["fase"]
	mini.custom_minimum_size = Vector2(pf(42 if curto else 48), pf(54 if curto else 60))
	mini.raio = pf(8)
	mini.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mini)
	var tx := VBoxContainer.new()
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.alignment = BoxContainer.ALIGNMENT_CENTER
	tx.add_theme_constant_override("separation", Estilo.px(2))
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tx)
	tx.add_child(Estilo.rotulo(l["nome"], Estilo.t800, 15, Estilo.AMARELO if dia else Estilo.GIZ))
	tx.add_child(Estilo.rotulo(l["sub"], Estilo.t500, 12.5, Estilo.GIZ2))
	var id := Codigo.id_fase(l["fase"])
	var r = recs.get(id, null)
	var dir := VBoxContainer.new()
	dir.alignment = BoxContainer.ALIGNMENT_CENTER
	dir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dir.add_theme_constant_override("separation", Estilo.px(2))
	h.add_child(dir)
	var t1 := Estilo.rotulo((fmt2(int(r)) + " s") if r != null else "—", Estilo.t800, 14, Estilo.GIZ, HORIZONTAL_ALIGNMENT_RIGHT, false)
	dir.add_child(t1)
	if not curto:
		dir.add_child(Estilo.rotulo("teu recorde" if r != null else "sem tempo", Estilo.t600, 11.5, Estilo.APAGADO, HORIZONTAL_ALIGNMENT_RIGHT, false))
	b.tooltip_text = l["nome"] + ". " + l["sub"]
	marca("fase_dia" if dia else "fase_" + str(l["i"]), b)
	b.pressed.connect(func():
		som.toca("clique")
		if l["tipo"] == "pronta":
			joga_fase(l["fase"], "pronta", {"i": l["i"]})
		else:
			joga_fase(l["fase"], "dia", {"dia": l["fase"]["dia"]}))
	return b


func _cartao_desafio() -> void:
	var fase: Dictionary = desafio
	var v := _novo_cartao("desafio")
	v.add_child(Estilo.olho("Desafio"))
	var co: Array = fase.get("corrente", []) if fase.get("corrente", null) != null else []
	var ult = co[co.size() - 1] if co.size() > 0 else null
	var quem: String = ult["nome"] if ult != null else (fase.get("autor", "") if fase.get("autor", "") != "" else "Alguém")
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", Estilo.px(14))
	v.add_child(topo)
	var mini := MiniFase.new()
	mini.fase = fase
	mini.custom_minimum_size = Vector2(pf(86), pf(132))
	mini.raio = pf(10)
	mini.borda = true
	topo.add_child(mini)
	var h2 := Estilo.rico("[color=%s]%s[/color] duvidou tu descer essa." % [Estilo.hexa(Estilo.AMARELO), esc(quem)], Estilo.tit, 26)
	h2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(h2)
	if co.size() > 0:
		var ord: Array = []
		for i in co.size():
			ord.append({"nome": co[i]["nome"], "cs": int(co[i]["cs"]), "i": i})
		ord.sort_custom(func(a, b): return a["cs"] < b["cs"] or (a["cs"] == b["cs"] and a["i"] < b["i"]))
		var lista := VBoxContainer.new()
		lista.add_theme_constant_override("separation", Estilo.px(5))
		v.add_child(lista)
		for k in ord.size():
			var c: Dictionary = ord[k]
			var melhor := k == 0
			var eu: bool = c["nome"] == nome
			var pn := PanelContainer.new()
			var sb := Estilo.caixa(Color(1.0, 201.0 / 255, 60.0 / 255, 0.16) if melhor else Color(0, 0, 0, 0.25), 10)
			Estilo.margens(sb, 7, 10)
			pn.add_theme_stylebox_override("panel", sb)
			if eu:
				pn.draw.connect(func():
					var r := Rect2(Vector2(Estilo.pf(1), Estilo.pf(1)), pn.size - Vector2(Estilo.pf(2), Estilo.pf(2)))
					_contorno_tracejado(pn, r, Estilo.g(0.4), Estilo.pf(2)))
			var hh := HBoxContainer.new()
			hh.add_theme_constant_override("separation", Estilo.px(10))
			pn.add_child(hh)
			var cor_txt := Estilo.AMARELO if melhor else Estilo.GIZ
			var nr := Estilo.rotulo(str(k + 1) + "º", Estilo.t700, 12, Estilo.APAGADO, HORIZONTAL_ALIGNMENT_LEFT, false)
			nr.custom_minimum_size.x = pf(22)
			hh.add_child(nr)
			var nm := Estilo.rotulo(c["nome"] + (" (fez a ladeira)" if c["nome"] == fase.get("autor", "") else ""), Estilo.t700, 15, cor_txt, HORIZONTAL_ALIGNMENT_LEFT, false)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nm.clip_text = true
			hh.add_child(nm)
			hh.add_child(Estilo.rotulo(fmt2(c["cs"]) + " s", Estilo.t800, 15, cor_txt, HORIZONTAL_ALIGNMENT_RIGHT, false))
			lista.add_child(pn)
	var r = recs.get(Codigo.id_fase(fase), null)
	if r != null:
		v.add_child(Estilo.rotulo("Teu melhor aqui: " + fmt2(int(r)) + " s.", Estilo.t500, 14, Estilo.GIZ2, HORIZONTAL_ALIGNMENT_CENTER))
	var bd: Button = marca("dDesce", Estilo.botao("Descer", "vai"))
	bd.pressed.connect(func():
		if desafio != null:
			som.toca("clique")
			joga_fase(desafio, "desafio", {}))
	v.add_child(bd)
	var bv := Estilo.botao("Voltar pro começo")
	bv.pressed.connect(func(): som.toca("clique"); mostra_inicio())
	v.add_child(bv)


func _contorno_tracejado(ci: CanvasItem, r: Rect2, c: Color, w: float) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var l := a.distance_to(b)
		var x := 0.0
		while x < l:
			ci.draw_line(a.lerp(b, x / l), a.lerp(b, minf(l, x + w * 3.0) / l), c, w)
			x += w * 5.0


func _cartao_cola() -> void:
	var v := _novo_cartao("cola")
	v.add_child(Estilo.olho("Tenho um desafio"))
	v.add_child(Estilo.rotulo("Cola o link aqui", Estilo.tit, 26, Estilo.GIZ, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Estilo.rotulo("Pode ser a mensagem inteira que o amigo mandou, o link ou só o código.", Estilo.t500, 15, Estilo.GIZ))
	campo_cola = TextEdit.new()
	campo_cola.placeholder_text = "Cola aqui"
	campo_cola.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	campo_cola.custom_minimum_size = Vector2(0, Estilo.pf(104))
	_estilo_campo(campo_cola, 14)
	marca("cTexto", campo_cola)
	v.add_child(campo_cola)
	var bc := Estilo.botao("Colar o que copiei", "link")
	bc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bc.pressed.connect(func():
		var t := DisplayServer.clipboard_get()
		if t != "":
			campo_cola.text = t
		else:
			aviso("Não achei nada copiado. Segura no campo e cola.", 2.4))
	v.add_child(bc)
	erro_cola = Estilo.rotulo("", Estilo.t700, 14, Estilo.ERRO)
	erro_cola.visible = false
	v.add_child(erro_cola)
	var bv := Estilo.botao("Voltar")
	bv.pressed.connect(func(): som.toca("clique"); mostra_inicio())
	var ba: Button = marca("cAbre", Estilo.botao("Abrir", "vai"))
	ba.pressed.connect(func():
		var t := campo_cola.text
		if abre_codigo(t):
			som.toca("clique")
			return
		erro_cola.visible = true
		erro_cola.text = "Esse código veio quebrado. Pede pro amigo mandar de novo." if t.contains("dv1") else "Não achei desafio nenhum aí. Cola a mensagem inteira que o amigo mandou."
		som.toca("erro"))
	v.add_child(_linha([bv, ba]))


func _estilo_campo(c: Control, tam_f: float) -> void:
	var sb := Estilo.margens(Estilo.caixa(Color("#0F0E13"), 12, 2, Estilo.g(0.25)), 10, 12)
	var sf := sb.duplicate() as StyleBoxFlat
	sf.border_color = Estilo.AMARELO
	c.add_theme_stylebox_override("normal", sb)
	c.add_theme_stylebox_override("focus", sf)
	c.add_theme_stylebox_override("read_only", sb)
	c.add_theme_font_override("font", Estilo.t700 if c is LineEdit else Estilo.t500)
	c.add_theme_font_size_override("font_size", Estilo.px(tam_f))
	c.add_theme_color_override("font_color", Estilo.GIZ)
	c.add_theme_color_override("font_placeholder_color", Estilo.APAGADO)
	c.add_theme_color_override("caret_color", Estilo.AMARELO)
	c.add_theme_color_override("selection_color", Color(1.0, 201.0 / 255, 60.0 / 255, 0.35))
	c.add_theme_color_override("background_color", Color(0, 0, 0, 0))


func _cartao_nome(olho_txt: String) -> void:
	var v := _novo_cartao("nome")
	v.add_child(Estilo.olho(olho_txt))
	v.add_child(Estilo.rotulo("Como tu chama?", Estilo.tit, 26, Estilo.GIZ, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Estilo.rotulo("Teu nome vai junto no desafio, do lado do teu tempo.", Estilo.t500, 15, Estilo.GIZ))
	campo_nome = LineEdit.new()
	campo_nome.max_length = 14
	campo_nome.placeholder_text = "Teu nome ou apelido"
	campo_nome.text = nome
	campo_nome.custom_minimum_size = Vector2(0, Estilo.pf(50))
	campo_nome.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_estilo_campo(campo_nome, 18)
	campo_nome.text_submitted.connect(func(_t): confirma_nome())
	marca("nCampo", campo_nome)
	v.add_child(campo_nome)
	erro_nome = Estilo.rotulo("", Estilo.t700, 14, Estilo.ERRO)
	erro_nome.visible = false
	v.add_child(erro_nome)
	var bv := Estilo.botao("Voltar")
	bv.pressed.connect(func(): som.toca("clique"); volta_nome())
	var bo: Button = marca("nOk", Estilo.botao("Pronto", "vai"))
	bo.pressed.connect(confirma_nome)
	v.add_child(_linha([bv, bo]))


func _cartao_manda() -> void:
	var v := _novo_cartao("manda")
	var msg: Dictionary = manda["msg"]
	v.add_child(Estilo.olho("Manda pro amigo"))
	v.add_child(Estilo.rotulo("Duvido!", Estilo.tit, 26, Estilo.GIZ, HORIZONTAL_ALIGNMENT_CENTER))
	var bolha := PanelContainer.new()
	var sb := Estilo.margens(Estilo.caixa(Color("#24232B"), 14, 1, Estilo.g(0.12)), 12, 14)
	sb.corner_radius_bottom_left = Estilo.px(4)
	bolha.add_theme_stylebox_override("panel", sb)
	var linhas: PackedStringArray = str(msg["texto"]).split("\n")
	var bb := ""
	for i in linhas.size():
		var l := linhas[i]
		if l.begins_with("http") or l.begins_with("dv1"):
			bb += "[color=%s]%s[/color]" % [Estilo.hexa(Estilo.AZUL), esc(l)]
		else:
			bb += esc(l)
		if i < linhas.size() - 1:
			bb += "\n"
	var rt := Estilo.rico(bb, Estilo.t500, 15, Estilo.GIZ, false)
	rt.selection_enabled = true
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	bolha.add_child(rt)
	v.add_child(bolha)
	ok_copia = Estilo.rotulo("", Estilo.giz, 20, Estilo.AMARELO, HORIZONTAL_ALIGNMENT_CENTER)
	ok_copia.visible = false
	v.add_child(ok_copia)
	var bc: Button = marca("mCopia", Estilo.botao("Copiar a mensagem", "rosa"))
	bc.pressed.connect(copia)
	var bz: Button = marca("mZap", Estilo.botao("Mandar no WhatsApp", "bt", "conversa"))
	bz.pressed.connect(manda_zap)
	v.add_child(_linha([bc, bz]))
	var bv := Estilo.botao("Voltar")
	bv.pressed.connect(_volta_manda)
	v.add_child(bv)


# ---------------------------------------------------------------- pros testes (o __duvido da versão web)
func marca(nome_alvo: String, c: Control) -> Control:
	alvos[nome_alvo] = c
	return c


func estado() -> Dictionary:
	var e := {"tela": tela, "nome": nome, "camY": int(round(cam_y)), "cartao": cartao_atual, "tam": [tam.x, tam.y],
		"carimbo": car_t.text if carimbo_no.visible else "", "pos": pos_no.visible}
	var al := {}
	for k in alvos:
		var c = alvos[k]
		if is_instance_valid(c) and (c as Control).is_visible_in_tree():
			var r := (c as Control).get_global_rect()
			al[k] = [r.position.x, r.position.y, r.size.x, r.size.y]
	e["alvos"] = al
	e["manda"] = manda["msg"] if manda != null else null
	e["rolagem"] = (cartoes[cartao_atual].get_meta("scroll") as ScrollContainer).scroll_vertical if (cartao_atual != null and cartoes.has(cartao_atual)) else 0
	e["campoNome"] = campo_nome.text if (campo_nome != null and is_instance_valid(campo_nome)) else ""
	e["okCopia"] = ok_copia.text if (ok_copia != null and is_instance_valid(ok_copia) and ok_copia.visible) else ""
	if desafio != null:
		e["desafio"] = {"autor": desafio.get("autor", ""), "corrente": desafio.get("corrente", [])}
	e["mundo"] = {"colx": mundo.COLX, "colw": mundo.COLW, "k": mundo.K, "cam": cam_y}
	if jogo != null:
		var S := jogo.S
		e["jogo"] = {"origem": jogo.origem, "titulo": jogo.titulo, "passos": S.passos, "tempo": tempo_atual(S) / 100.0, "fim": S.fim, "cambalhotas": S.cambalhotas,
			"segura": S.segura, "noChao": S.c0 != 0 or S.c1 != 0, "x": (S.p[0] + S.p[2]) / 2.0, "y": (S.p[1] + S.p[3]) / 2.0, "tentativas": jogo.tentativas, "ev": jogo.ev.duplicate(), "fantasma": jogo.g_nome}
	e["editor"] = {"ferramenta": ed.ferr, "tracos": ed.tracos.size(), "carimbos": ed.carimbos.map(func(c): return c["tipo"]), "liberado": editor_liberado()}
	e["sons"] = som.tocados.duplicate()
	e["fps"] = Engine.get_frames_per_second()
	return e


## Na versão do navegador, o estado fica em window.__duvidoEstado (pros testes de fora).
func _estado_web(dt: float) -> void:
	web_t += dt
	if web_t < 0.15:
		return
	web_t = 0.0
	JavaScriptBridge.eval("window.__duvidoEstado=" + JSON.stringify(estado()) + ";", true)
	var c = JavaScriptBridge.eval("(function(){var a=window.__duvidoCmd||[];window.__duvidoCmd=[];return JSON.stringify(a);})()", true)
	if c is String and c != "[]":
		var l = JSON.parse_string(c)
		if l is Array:
			for cmd in l:
				Comandos.executa(self, str(cmd))
