extends Control
## A tela do jogo, montada como a versão web: o nome e o placar em cima, o cômodo no meio,
## a caixa de tralha e o VAI! embaixo; os cartões (começo, fim, fases) em folha de caderno.

var jogo: Jogo
var palco: Palco
var placar: Placar
var som_bt: SomBotao
var marca: Control
var marca_tit: Label
var marca_sub: Label
var bandeja: GridContainer
var vai_bt: Botao
var itens: Array[ItemCaixa] = []
var ferr: PanelContainer
var g_esq: Botao
var g_dir: Botao
var tira_bt: Botao
var aviso_box: PanelContainer
var aviso_txt: Label
var pedido_box: PanelContainer
var pedido_tit: Label
var pedido_fluxo: HFlowContainer
var intro: CartaoBox
var fim: CartaoBox
var fases: CartaoBox
var raiz: MarginContainer
var _aviso_ate := 0
var _vw := 390.0
var _vh := 844.0
var _estreito := false
var _baixo := false

# o que vai no cartão do fim
var fim_carimbo: Carimbo
var fim_sub: Label
var fim_pts: Label
var fim_rec: Label
var fim_pedido: VBoxContainer
var fim_pedido_tit: Label
var fim_pedido_fluxo: HFlowContainer
var fim_conta: VBoxContainer
var fim_beat: PanelContainer
var fim_grade: GradeBeat
var fim_beat_bt: Botao
var fim_magro: Label
var fim_de_novo: Botao
var fim_do_zero: Botao
var fim_prox: Botao
var intro_tit: Label
var intro_lead: Label
var intro_passos: VBoxContainer
var intro_regra: Label
var intro_bora: Botao
var fases_lista: VBoxContainer


func _ready() -> void:
	get_tree().root.size_changed.connect(_escala)
	_escala()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	jogo = Jogo.new()
	jogo.name = "Jogo"
	add_child(jogo)
	_monta()
	jogo.mudou_pontos.connect(func(n: int) -> void: placar.pontos(n, n > 0))
	jogo.mudou_corrente.connect(_corrente)
	jogo.mudou_modo.connect(_modo)
	jogo.mudou_fase.connect(_fase_mudou)
	jogo.mudou_estoque.connect(_estoque)
	jogo.mudou_pedido.connect(_pedido_barra)
	jogo.aviso.connect(aviso)
	jogo.acabou.connect(_mostra_fim)
	_fase_mudou()
	if OS.has_feature("web"):
		# a pessoa pediu "reduzir movimento" no aparelho? (só dá pra saber na web)
		var r = JavaScriptBridge.eval("(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) ? 'sim' : 'nao'", true)
		if str(r) == "sim":
			palco.reduz = true
			jogo.reduz = true
			placar.reduz = true
	_acessivel(marca, "Escolher a fase")
	_acessivel(g_esq, "Girar pra esquerda")
	_acessivel(g_dir, "Girar pra direita")
	_acessivel(tira_bt, "Devolver pra caixa")
	_acessivel(vai_bt, "VAI!")
	if bool(Salva.le(jogo.fase.visto, false)):
		intro.visible = false
	else:
		_mostra_intro()
	som_bt.liga(Som.ligado)


# ---------- o tamanho: a interface pensada num celular de 390 x 844 e esticada pra caber ----------
func _escala() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return
	var base := minf(win.x / 720.0, win.y / 1280.0)
	var quer := minf(win.x / 390.0, win.y / 844.0)
	var k := quer / base
	if absf(get_tree().root.content_scale_factor - k) > 0.001:
		get_tree().root.content_scale_factor = k
	_vw = win.x / quer
	_vh = win.y / quer
	_estreito = _vw <= 400
	_baixo = _vh <= 700
	if bandeja != null:
		_ajeita_tamanhos()


func _ajeita_tamanhos() -> void:
	bandeja.columns = 8 if _vw >= 760 else 4
	marca_tit.label_settings.font_size = int(clampf(0.052 * _vw, 19, 27)) if not _estreito else (16 if _vw <= 340 else 18)
	marca_sub.label_settings.font_size = 12 if _estreito else 14
	placar.estreito(_estreito)
	som_bt.custom_minimum_size = Vector2(36, 36) if _estreito else Vector2(40, 40)
	for it in itens:
		it.estreito = _estreito
		it.queue_redraw()
	for cb in [intro, fim, fases]:
		cb.estreito(_estreito)
	var h1 := clampf(0.09 * _vw, 30, 40)
	if _baixo:
		h1 = 28
	for l in [intro_tit, _fases_tit]:
		l.label_settings.font_size = int(h1)
	fim_carimbo.tam = h1
	fim_carimbo.update_minimum_size()
	intro_lead.label_settings.font_size = 17 if _baixo else 19
	intro_lead.label_settings.line_spacing = Kit.entrelinha(Fontes.caneta(), intro_lead.label_settings.font_size, 1.25)
	intro_regra.label_settings.font_size = 13 if _baixo else 14
	intro_regra.label_settings.line_spacing = Kit.entrelinha(Fontes.txt(400), intro_regra.label_settings.font_size, 1.4)
	var sa := DisplayServer.get_display_safe_area()
	var lado := 16.0
	raiz.add_theme_constant_override("margin_left", int(lado))
	raiz.add_theme_constant_override("margin_right", int(lado))
	raiz.add_theme_constant_override("margin_top", 8)
	raiz.add_theme_constant_override("margin_bottom", 8)


var _fases_tit: Label


# ---------- a montagem ----------
func _monta() -> void:
	raiz = MarginContainer.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(col)
	# o alto: o nome (que abre as fases), o placar em fita crepe e o som
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	col.add_child(topo)
	marca = Clicavel.new()
	marca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marca.tooltip_text = "Escolher a fase"
	(marca as Clicavel).clicou.connect(_abre_fases)
	topo.add_child(marca)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marca.add_child(mv)
	marca_tit = Kit.rotulo("GAMBIARRA", Fontes.letreiro(), 27, Dados.VAI)
	mv.add_child(marca_tit)
	marca_sub = Kit.rotulo("Fase 1 · Liga o rádio", Fontes.caneta(), 14, Dados.FITA)
	marca_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	marca_sub.clip_text = true
	marca_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marca_sub.draw.connect(func() -> void:
		# o "▾" da web logo depois do texto (as letras da casa não têm esse sinal)
		var ls := marca_sub.label_settings
		var w := Ctx.largura(marca_sub.text, ls.font, ls.font_size)
		var x := minf(w + 6.0, marca_sub.size.x - 9.0)
		var y := marca_sub.size.y / 2.0 - 1.0
		marca_sub.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 2), Vector2(x + 8, y - 2), Vector2(x + 4, y + 3)]), Dados.FITA))
	mv.add_child(marca_sub)
	var dir := HBoxContainer.new()
	dir.add_theme_constant_override("separation", 8)
	dir.alignment = BoxContainer.ALIGNMENT_END
	topo.add_child(dir)
	placar = Placar.new()
	placar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dir.add_child(placar)
	som_bt = SomBotao.new()
	som_bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	som_bt.pressed.connect(func() -> void:
		Som.alterna()
		som_bt.liga(Som.ligado)
		_acessivel(som_bt, "Som ligado" if Som.ligado else "Som desligado"))
	dir.add_child(som_bt)
	# o palco
	palco = Palco.new()
	palco.jogo = jogo
	palco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(palco)
	palco.selecionou.connect(_seleciona)
	palco.pos_ferr_pedida.connect(_pos_ferr)
	palco.ferr_esconde.connect(func() -> void: ferr.visible = false)
	palco.aviso_pedido.connect(aviso)
	palco.tocou_palco.connect(func() -> void:
		if jogo.modo == "edita":
			intro.visible = false)
	_monta_overlays()
	# a caixa de tralha e o VAI
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	col.add_child(caixa)
	bandeja = GridContainer.new()
	bandeja.columns = 4
	bandeja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bandeja.add_theme_constant_override("h_separation", 6)
	bandeja.add_theme_constant_override("v_separation", 6)
	caixa.add_child(bandeja)
	vai_bt = Botao.new("VAI!", "vai", Fontes.letreiro(), 27)
	vai_bt.raio = 12
	vai_bt.sombra = 5
	vai_bt.largura_min = 96
	vai_bt.altura_min = 64
	vai_bt.pad_x = 16
	vai_bt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vai_bt.pressed.connect(_vai)
	caixa.add_child(vai_bt)
	_ajeita_tamanhos()


func _monta_overlays() -> void:
	# o aviso de fita crepe
	aviso_box = PanelContainer.new()
	aviso_box.add_theme_stylebox_override("panel", Kit.EstiloRasgo.new(Dados.FITA, 16, 8))
	aviso_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_box.visible = false
	aviso_box.z_index = 4
	aviso_txt = Kit.rotulo("", Fontes.caneta(), 15, Dados.TINTA)
	aviso_box.add_child(aviso_txt)
	palco.add_child(aviso_box)
	# o pedido do churrasco / a levada da banda
	pedido_box = PanelContainer.new()
	pedido_box.add_theme_stylebox_override("panel", Kit.EstiloRasgo.new(Dados.FITA, 10, 6))
	pedido_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedido_box.visible = false
	pedido_fluxo = HFlowContainer.new()
	pedido_fluxo.add_theme_constant_override("h_separation", 6)
	pedido_fluxo.add_theme_constant_override("v_separation", 4)
	pedido_fluxo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedido_box.add_child(pedido_fluxo)
	pedido_tit = Kit.rotulo("o churrasco pede", Fontes.caneta(), 13, Dados.TINTA)
	palco.add_child(pedido_box)
	# girar e devolver
	ferr = PanelContainer.new()
	var est := Kit.estilo_caixa(Dados.TINTA, 12, 0, Color.TRANSPARENT, 5, 5)
	est.shadow_color = Color(0, 0, 0, 0.35)
	est.shadow_offset = Vector2(0, 4)
	est.shadow_size = 1
	ferr.add_theme_stylebox_override("panel", est)
	ferr.visible = false
	ferr.z_index = 3
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 6)
	ferr.add_child(fh)
	g_esq = _bt_ferr("gira_esq", "fita")
	g_esq.tooltip_text = "Girar pra esquerda"
	g_esq.pressed.connect(func() -> void: _gira(-1))
	fh.add_child(g_esq)
	g_dir = _bt_ferr("gira_dir", "fita")
	g_dir.tooltip_text = "Girar pra direita"
	g_dir.pressed.connect(func() -> void: _gira(1))
	fh.add_child(g_dir)
	tira_bt = _bt_ferr("x", "tira")
	tira_bt.tooltip_text = "Devolver pra caixa"
	tira_bt.pressed.connect(_devolve)
	fh.add_child(tira_bt)
	palco.add_child(ferr)
	_monta_intro()
	_monta_fim()
	_monta_fases()


func _acessivel(c: Control, nome: String) -> void:
	# o nome que o leitor de tela fala (a Godot 4.5 tem leitor de tela; o aria-label da web)
	if "accessibility_name" in c:
		c.set("accessibility_name", nome)


func _bt_ferr(ic: String, est: String) -> Botao:
	var b := Botao.new("", est)
	b.icone = ic
	b.raio = 9
	b.sombra = 0
	b.custom_minimum_size = Vector2(40, 40)
	return b


func _novo_cartao() -> CartaoBox:
	var cb := CartaoBox.new()
	cb.z_index = 5
	palco.add_child(cb)
	return cb


func _h1(txt: String) -> Label:
	var l := Kit.rotulo(txt, Fontes.letreiro(), 40, Dados.LARANJA, Dados.TINTA, Vector2(3, 3))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _par(txt: String, f: Font, tam: float, cor: Color, lh := 1.4) -> Label:
	var l := Kit.rotulo(txt, f, tam, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.label_settings.line_spacing = Kit.entrelinha(f, tam, lh)
	l.set_meta("lh", lh)
	return l


func _monta_intro() -> void:
	intro = _novo_cartao()
	var v := intro.conteudo
	intro_tit = _h1("GAMBIARRA")
	v.add_child(intro_tit)
	intro_lead = _par("", Fontes.caneta(), 19, Dados.TINTA, 1.25)
	v.add_child(intro_lead)
	intro_passos = VBoxContainer.new()
	intro_passos.add_theme_constant_override("separation", 8)
	v.add_child(intro_passos)
	intro_regra = _par("", Fontes.txt(400), 14, Dados.TINTA2)
	v.add_child(intro_regra)
	intro_bora = Botao.new("Bora", "vai", Fontes.letreiro(), 19)
	intro_bora.pressed.connect(func() -> void:
		intro.visible = false
		Salva.guarda(jogo.fase.visto, true))
	v.add_child(intro_bora)


func _mostra_intro() -> void:
	var I: Dictionary = jogo.fase.intro
	intro_tit.text = I.titulo
	intro_lead.text = I.lead
	intro_regra.text = I.regra
	for c in intro_passos.get_children():
		c.queue_free()
	var i := 0
	for txt in I.passos:
		i += 1
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var num := Numero.new(i)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(num)
		var r := Kit.texto_rico(txt, 15, Dados.TINTA)
		h.add_child(r)
		intro_passos.add_child(h)
	intro.visible = true
	intro.rola_topo()
	intro_bora.grab_focus.call_deferred()


func _monta_fim() -> void:
	fim = _novo_cartao()
	fim.visible = false
	var v := fim.conteudo
	fim_carimbo = Carimbo.new()
	fim_carimbo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(fim_carimbo)
	fim_sub = _par("", Fontes.caneta(), 18, Dados.TINTA, 1.25)
	v.add_child(fim_sub)
	var total := PanelContainer.new()
	var linha := StyleBoxFlat.new()
	linha.bg_color = Color.TRANSPARENT
	linha.border_color = Dados.TINTA
	linha.border_width_bottom = 2
	linha.content_margin_bottom = 6
	total.add_theme_stylebox_override("panel", linha)
	v.add_child(total)
	var th := HBoxContainer.new()
	total.add_child(th)
	var lt := Kit.rotulo("PONTO DE\nGAMBIARRA", Kit.espacada(Fontes.txt(800), 1), 11, Dados.TINTA)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.size_flags_vertical = Control.SIZE_SHRINK_END
	th.add_child(lt)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	th.add_child(tv)
	fim_pts = Kit.rotulo("0", Fontes.letreiro(), 38, Dados.TINTA)
	fim_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(fim_pts)
	fim_rec = Kit.rotulo("", Fontes.txt(600), 13, Dados.TINTA2)
	fim_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(fim_rec)
	fim_pedido = VBoxContainer.new()
	fim_pedido.add_theme_constant_override("separation", 6)
	v.add_child(fim_pedido)
	fim_pedido_tit = Kit.rotulo("O CHURRASCO PEDIU", Kit.espacada(Fontes.txt(800), 1), 11, Dados.TINTA)
	fim_pedido.add_child(fim_pedido_tit)
	fim_pedido_fluxo = HFlowContainer.new()
	fim_pedido_fluxo.add_theme_constant_override("h_separation", 5)
	fim_pedido_fluxo.add_theme_constant_override("v_separation", 5)
	fim_pedido.add_child(fim_pedido_fluxo)
	fim_conta = VBoxContainer.new()
	fim_conta.add_theme_constant_override("separation", 3)
	v.add_child(fim_conta)
	fim_beat = PanelContainer.new()
	fim_beat.add_theme_stylebox_override("panel", Kit.estilo_caixa(Dados.TINTA, 8, 0, Color.TRANSPARENT, 10, 10))
	v.add_child(fim_beat)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	fim_beat.add_child(bv)
	var bt := HBoxContainer.new()
	bv.add_child(bt)
	var bl := Kit.rotulo("O beat da tua gambiarra", Fontes.caneta(), 16, Dados.FITA)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.add_child(bl)
	fim_beat_bt = Botao.new("Pausar", "linha_fita", Fontes.txt(700), 13)
	fim_beat_bt.raio = 8
	fim_beat_bt.custom_minimum_size = Vector2(0, 32)
	fim_beat_bt.pressed.connect(_beat_bt)
	bt.add_child(fim_beat_bt)
	fim_grade = GradeBeat.new()
	bv.add_child(fim_grade)
	fim_magro = _par("Beat magrinho. Mais tralha na corrente, mais batida.", Fontes.txt(400), 13, Dados.FITA)
	bv.add_child(fim_magro)
	var bots := HBoxContainer.new()
	bots.add_theme_constant_override("separation", 8)
	v.add_child(bots)
	fim_de_novo = Botao.new("Mexer de novo", "vai", Fontes.letreiro(), 19)
	fim_de_novo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fim_de_novo.pressed.connect(func() -> void: jogo.ajeita())
	bots.add_child(fim_de_novo)
	fim_do_zero = Botao.new("Do zero", "linha", Fontes.txt(800), 16)
	fim_do_zero.pressed.connect(func() -> void:
		jogo.do_zero()
		_seleciona(null))
	bots.add_child(fim_do_zero)
	fim_prox = Botao.new("", "linha", Fontes.txt(800), 16)
	fim_prox.pressed.connect(func() -> void: _vai_fase(jogo.fase_i + 1))
	v.add_child(fim_prox)


func _monta_fases() -> void:
	fases = _novo_cartao()
	fases.visible = false
	var v := fases.conteudo
	_fases_tit = _h1("Fases")
	v.add_child(_fases_tit)
	fases_lista = VBoxContainer.new()
	fases_lista.add_theme_constant_override("separation", 8)
	v.add_child(fases_lista)
	var fecha := Botao.new("Fechar", "linha", Fontes.txt(800), 16)
	fecha.pressed.connect(func() -> void: fases.visible = false)
	v.add_child(fecha)


# ---------- reações ----------
func _fase_mudou() -> void:
	marca_sub.text = "Fase %d · %s" % [jogo.fase.n, jogo.fase.nome]
	_acessivel(palco, jogo.fase.aria)
	for it in itens:
		it.queue_free()
	itens.clear()
	for k in jogo.fase.caixa:
		var it := ItemCaixa.new(k)
		it.custom_minimum_size = Vector2(0, 60)
		it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		it.estreito = _estreito
		it.tocou.connect(_item_tocou)
		it.arrasto_comeca.connect(func(t: String, toque: bool, g: Vector2) -> void:
			if jogo.modo != "edita" or int(jogo.estoque.get(t, 0)) <= 0:
				return
			intro.visible = false
			palco.comeca_novo(t, toque)
			palco.move_arrasto_global(g)
			ferr.visible = false)
		it.arrasto_move.connect(palco.move_arrasto_global)
		it.arrasto_solta.connect(func(g: Vector2) -> void: palco.solta_global(g))
		bandeja.add_child(it)
		itens.append(it)
	_estoque()
	_pedido_barra()
	_seleciona(null)


func _estoque() -> void:
	for it in itens:
		var n := int(jogo.estoque.get(it.tipo, 0))
		it.define(n, jogo.modo != "edita")
		_acessivel(it, "%s, %d na caixa" % [Dados.TIPOS[it.tipo].nome, n])


func _item_tocou(k: String) -> void:
	if jogo.modo != "edita":
		return
	if int(jogo.estoque.get(k, 0)) <= 0:
		aviso("Acabou " + ("a PET" if k == "garrafa" else "esse") + " da caixa")
		return
	intro.visible = false
	var p := jogo.auto_poe(k)
	if p != null:
		palco.seleciona(p)


func _corrente() -> void:
	var n := jogo.na_corrente()
	placar.corrente("corrente %d" % n + (" ×" + Dados.virgula(Dados.mult_de(n)) if n > 1 else ""), jogo.rodando())


func _modo(m: String) -> void:
	var rodando := m == "roda" or m == "festa"
	vai_bt.rotulo = "PARAR" if rodando else "VAI!"
	vai_bt.estilo = "perigo" if rodando else "vai"
	vai_bt.tam = 20 if rodando else 27
	vai_bt.queue_redraw()
	bandeja.modulate.a = 0.35 if rodando else 1.0
	for it in itens:
		it.desligado = rodando
		it.mouse_filter = Control.MOUSE_FILTER_IGNORE if rodando else Control.MOUSE_FILTER_STOP
	_corrente()
	if m == "edita":
		fim.visible = false
		placar.pontos(0, false)
	if rodando:
		_seleciona(null)
		intro.visible = false


func _pedido_barra() -> void:
	var ped: Array = jogo.fase.pedido
	var lev := int(jogo.fase.levada)
	if ped.is_empty() and lev == 0:
		pedido_box.visible = false
		return
	pedido_box.visible = true
	for c in pedido_fluxo.get_children():
		pedido_fluxo.remove_child(c)
		if c != pedido_tit:
			c.queue_free()
	pedido_tit.text = "o churrasco pede" if not ped.is_empty() else "a banda pede uma levada"
	pedido_fluxo.add_child(pedido_tit)
	for ch in _chips():
		pedido_fluxo.add_child(ch)
	_pos_pedido()


func _chips() -> Array:
	var out: Array = []
	var ped: Array = jogo.fase.pedido
	if not ped.is_empty():
		for k in ped:
			out.append(Chip.new(Dados.INFO[k][0], k in jogo.pedido_ok))
	else:
		for i in range(int(jogo.fase.levada)):
			out.append(Chip.new(str(i + 1), jogo.melhor_seq > i, true))
	return out


func _pos_pedido() -> void:
	# numa linha só quando cabe (como o flex-wrap da web); se não couber, quebra
	var maxw := Dados.W * palco.esc - 16
	var total := 20.0
	var n := 0
	for c in pedido_fluxo.get_children():
		total += (c as Control).get_combined_minimum_size().x
		n += 1
	total += 6.0 * maxi(0, n - 1) + 4.0   # uma folguinha: a Godot quebra a linha quando fica exato
	var w := minf(total, maxw)
	pedido_box.size = Vector2(w, 0)
	pedido_box.size = Vector2(w, pedido_box.get_combined_minimum_size().y)
	# no celular sobra céu em cima do cômodo: a fita sobe pra lá e não tampa a laranja
	var sobe := minf(palco.et * palco.esc, pedido_box.size.y + 8.0)
	pedido_box.position = Vector2(palco.ox + 8, palco.oy + 8 - sobe)
	pedido_box.pivot_offset = pedido_box.size / 2.0
	pedido_box.rotation = deg_to_rad(-0.8)


func aviso(txt: String) -> void:
	aviso_txt.text = txt
	aviso_box.visible = true
	aviso_box.reset_size()
	_aviso_ate = Time.get_ticks_msec() + 1700


func _process(_dt: float) -> void:
	_ponte()
	if aviso_box.visible:
		if Time.get_ticks_msec() > _aviso_ate:
			aviso_box.visible = false
		else:
			aviso_box.size.x = minf(aviso_box.get_combined_minimum_size().x, palco.size.x - 16)
			aviso_box.position = Vector2((palco.size.x - aviso_box.size.x) / 2.0, 10)
			aviso_box.pivot_offset = aviso_box.size / 2.0
			aviso_box.rotation = deg_to_rad(-1)
	if pedido_box.visible:
		_pos_pedido()
	if fim.visible and jogo.resumo.get("ok", false):
		fim_grade.marca(Som.coluna_loop())
	if palco.sel != null and ferr.visible:
		_pos_ferr()


# ---------- escolher, girar, devolver ----------
func _seleciona(p: Peca) -> void:
	if palco.sel != p:
		palco.sel = p
	if p == null:
		ferr.visible = false
		return
	var t: Dictionary = Dados.TIPOS[p.tipo]
	g_esq.visible = t.gira or t.vira
	g_dir.visible = t.gira
	g_esq.tooltip_text = "Virar o gato" if t.vira else "Girar pra esquerda"
	_acessivel(g_esq, g_esq.tooltip_text)
	ferr.visible = true
	ferr.reset_size()
	_pos_ferr()


func _pos_ferr() -> void:
	var p := palco.sel
	if p == null or jogo.modo != "edita":
		ferr.visible = false
		return
	if not palco.arrasto.is_empty() and palco.arrasto.mexeu:
		return
	ferr.visible = true
	var bb := p.caixa(true)
	var fw := ferr.size.x
	var fh := ferr.size.y
	var x := palco.ox + bb.get_center().x * palco.esc - fw / 2.0
	var y := palco.oy + bb.position.y * palco.esc - fh - 10
	if y < 4:
		y = palco.oy + bb.end.y * palco.esc + 10
	x = clampf(x, 4, palco.size.x - fw - 4)
	y = clampf(y, 4, palco.size.y - fh - 4)
	ferr.position = Vector2(x, y)


func _gira(d: int) -> void:
	jogo.gira(palco.sel, d)
	_pos_ferr()


func _devolve() -> void:
	if palco.sel == null or jogo.modo != "edita":
		return
	jogo.devolve(palco.sel)
	palco.seleciona(null)


# ---------- vai e volta ----------
func _vai() -> void:
	if jogo.modo == "edita":
		intro.visible = false
		fases.visible = false
		palco.seleciona(null)
		jogo.roda()
	else:
		jogo.ajeita()


func _vai_fase(i: int) -> void:
	Som.para_tudo()
	jogo.vai_fase(i)
	fim.visible = false
	fases.visible = false
	if not bool(Salva.le(jogo.fase.visto, false)):
		_mostra_intro()
	else:
		intro.visible = false


func _abre_fases() -> void:
	if jogo.rodando():
		return
	for c in fases_lista.get_children():
		c.queue_free()
	var atual: Clicavel = null
	for i in range(Dados.FASES.size()):
		var f: Dictionary = Dados.FASES[i]
		var r := int(Salva.le(f.rec, 0))
		var b := Clicavel.new()
		b.add_theme_stylebox_override("panel", Kit.estilo_caixa(Dados.FITA if i == jogo.fase_i else Dados.PAPEL, 10, 2, Dados.TINTA, 12, 10))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var num := Kit.rotulo(str(f.n), Fontes.letreiro(), 30, Dados.LARANJA, Dados.TINTA, Vector2(2, 2))
		num.custom_minimum_size = Vector2(44, 0)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(num)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tv)
		tv.add_child(Kit.rotulo(f.lugar, Fontes.caneta(), 19, Dados.TINTA))
		var sub := Kit.rotulo(str(f.nome) + ((" · recorde %d" % r) if r > 0 else ""), Fontes.txt(600), 13, Dados.TINTA2)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(sub)
		var em := Kit.rotulo("ligou" if r > 0 else "", Fontes.txt(800), 12, Dados.AZULEJO)
		em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(em)
		var idx := i
		b.clicou.connect(func() -> void: _vai_fase(idx))
		fases_lista.add_child(b)
		if i == jogo.fase_i:
			atual = b
	fases.visible = true
	fases.rola_topo()
	if atual != null:
		atual.grab_focus.call_deferred()


# ---------- o fim ----------
func _mostra_fim(r: Dictionary) -> void:
	var ok: bool = r.ok
	fim_carimbo.texto = r.carimbo
	fim_carimbo.parou = not ok
	fim_carimbo.update_minimum_size()
	fim_carimbo.queue_redraw()
	fim_sub.text = r.sub
	fim_pts.text = str(r.total)
	fim_rec.text = r.rec
	fim_pedido.visible = r.tem_pedido
	fim_pedido_tit.text = str(r.pedido_tit).to_upper()
	for c in fim_pedido_fluxo.get_children():
		c.queue_free()
	if r.tem_pedido:
		for ch in _chips():
			fim_pedido_fluxo.add_child(ch)
		if int(jogo.fase.levada) > 0:
			var s := Kit.rotulo(("melhor sequência: %d no tempo" % r.melhor_seq) if r.melhor_seq > 0 else "nenhuma batida no tempo", Fontes.txt(600), 13, Dados.TINTA2)
			fim_pedido_fluxo.add_child(s)
	for c in fim_conta.get_children():
		c.queue_free()
	for li in r.conta:
		fim_conta.add_child(_linha_conta(li))
	fim_beat.visible = ok
	fim_magro.visible = r.magro
	fim_de_novo.rotulo = r.de_novo
	fim_de_novo.queue_redraw()
	fim_prox.visible = r.prox != ""
	fim_prox.rotulo = r.prox
	fim_prox.update_minimum_size()
	intro.visible = false
	fases.visible = false
	fim.visible = true
	fim.rola_topo()
	if ok:
		var pad := jogo.padrao_beat()
		fim_grade.define(pad)
		fim_grade.marca(-1)
		Som.toca_loop(pad, jogo.fase_i)
		fim_beat_bt.rotulo = "Pausar"
	else:
		fim_grade.define([])
	fim_beat_bt.queue_redraw()
	fim_de_novo.grab_focus.call_deferred()


func _linha_conta(li: Dictionary) -> Control:
	if li.cls == "nada":
		var l := _par(li.txt, Fontes.caneta(), 14, Dados.TINTA2)
		return l
	var cor := Dados.AZULEJO if li.cls == "mult" else Dados.TINTA
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := Kit.rotulo(li.txt, Fontes.caneta(), 16, cor)
	h.add_child(t)
	var pontilhado := Pontilhado.new()
	pontilhado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pontilhado)
	h.add_child(Kit.rotulo(li.val, Fontes.caneta(), 16, cor))
	return h


func _beat_bt() -> void:
	if Som.loop_tocando():
		Som.para_loop()
		fim_beat_bt.rotulo = "Tocar"
		fim_grade.marca(-1)
	else:
		Som.toca_loop(jogo.padrao_beat(), jogo.fase_i)
		fim_beat_bt.rotulo = "Pausar"
	fim_beat_bt.update_minimum_size()
	fim_beat_bt.queue_redraw()


# ---------- teclado ----------
func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		Botao.teclado = true
	elif ev is InputEventMouseButton and ev.pressed:
		if Botao.teclado:
			Botao.teclado = false


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	var k: int = ev.keycode
	if k == KEY_ESCAPE:
		if intro.visible:
			intro.visible = false
		elif fases.visible:
			fases.visible = false
		else:
			palco.seleciona(null)
		return
	var p := palco.sel
	if jogo.modo != "edita" or p == null:
		return
	var passo := 24.0 if ev.shift_pressed else 6.0
	var mv := Vector2.ZERO
	match k:
		KEY_LEFT:
			mv = Vector2(-1, 0)
		KEY_RIGHT:
			mv = Vector2(1, 0)
		KEY_UP:
			mv = Vector2(0, -1)
		KEY_DOWN:
			mv = Vector2(0, 1)
		KEY_Q:
			_gira(-1)
		KEY_E:
			_gira(1)
		KEY_DELETE, KEY_BACKSPACE:
			_devolve()
	if mv != Vector2.ZERO:
		var x0 := p.x
		var y0 := p.y
		p.x += mv.x * passo
		p.y += mv.y * passo
		if not jogo.cabe(p):
			p.x = x0
			p.y = y0
		_pos_ferr()
		get_viewport().set_input_as_handled()


# ---------- a ponte com a página (só na versão web): pros testes automáticos ----------
# só liga com "?teste" no endereço: a cada poucos quadros o jogo escreve o estado em
# window.__gambi_estado (com os retângulos dos botões em pixels da tela) e lê os comandos que a
# página deixar em window.__gambi_cmd
var _ponte_n := 0
var _ponte_ligada := false


func _ponte() -> void:
	if not OS.has_feature("web"):
		return
	_ponte_n += 1
	if _ponte_n == 1:
		var q = JavaScriptBridge.eval("location.search.indexOf('teste') >= 0 ? 'sim' : 'nao'", true)
		_ponte_ligada = str(q) == "sim"
		if _ponte_ligada:
			JavaScriptBridge.eval("window.__gambi_cmd = window.__gambi_cmd || [];", true)
	if not _ponte_ligada:
		return
	var cmds = JavaScriptBridge.eval("JSON.stringify((window.__gambi_cmd || []).splice(0))", true)
	if cmds is String and cmds != "[]":
		var lista: Array = JSON.parse_string(cmds)
		for c in lista:
			_comando(c)
	if _ponte_n % 6 != 0:
		return
	var e := jogo.estado()
	var est := {
		"modo": e.modo, "pts": e.pts, "pecas": jogo.pecas.size(), "estoque": jogo.estoque, "fase": jogo.fase_i,
		"laranja": [e.laranja.x, e.laranja.y], "ganhou": e.ganhou, "quem": e.quem, "corrente": e.corrente,
		"intro": intro.visible, "fim": fim.visible, "fases": fases.visible, "carimbo": fim_carimbo.texto,
		"ferr": ferr.visible, "sel": palco.sel.tipo if palco.sel != null else "",
		"som_pronto": Som.esta_pronto(), "loop": Som.loop_tocando(), "batidas": jogo.gravado.size(), "fps": Engine.get_frames_per_second(),
		"ret": {
			"bora": _ret_tela(intro_bora), "vai": _ret_tela(vai_bt), "gira_esq": _ret_tela(g_esq), "gira_dir": _ret_tela(g_dir),
			"tira": _ret_tela(tira_bt), "de_novo": _ret_tela(fim_de_novo), "do_zero": _ret_tela(fim_do_zero), "marca": _ret_tela(marca),
		},
		"itens": {},
		"mundo": _mapa_mundo(),
	}
	for it in itens:
		est.itens[it.tipo] = _ret_tela(it)
	JavaScriptBridge.eval("window.__gambi_estado = " + JSON.stringify(est) + ";", true)


func _ret_tela(c: Control) -> Array:
	# o retângulo de um controle em pixels da janela (a página divide pelo devicePixelRatio)
	var xf := get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
	var a := xf * Vector2.ZERO
	var b := xf * c.size
	return [a.x, a.y, b.x - a.x, b.y - a.y, c.is_visible_in_tree()]


func _mapa_mundo() -> Array:
	# pixel da janela = [x0 + mx * k, y0 + my * k] pra um ponto (mx, my) do cômodo
	var xf := get_viewport().get_final_transform() * palco.get_global_transform_with_canvas()
	var o := xf * Vector2(palco.ox, palco.oy)
	var u := xf * Vector2(palco.ox + palco.esc, palco.oy)
	return [o.x, o.y, u.x - o.x]


func _comando(c: Dictionary) -> void:
	match str(c.get("f", "")):
		"poe":
			var a: Array = c.a
			while a.size() < 5:
				a.append(0.0 if a.size() == 3 else 1)
			jogo.poe(a[0], a[1], a[2], a[3], int(a[4]))
		"zero":
			jogo.do_zero()
			_seleciona(null)
		"fase":
			_vai_fase(int(c.i))
		"esquece":
			Salva.esquece_tudo()
