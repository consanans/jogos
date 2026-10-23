class_name Palco
extends Control
## O palco: o cômodo desenhado no meio da tela (do tamanho que couber, com o que sobra em cima e
## embaixo continuando o cenário), a tralha, os pontos subindo, e o arrasto com o dedo ou o mouse.

signal selecionou(p: Peca)

const W := Dados.W
const H := Dados.H
const CHAO := Dados.CHAO
const ALC := Jogo.ALC

var jogo: Jogo
var esc := 1.0
var ox := 0.0
var oy := 0.0
var et := 0.0
var eb := 0.0
var sel: Peca = null
var arrasto: Dictionary = {}
var popups: Array[Dictionary] = []
var notas: Array = []
var fumaca: Array = []
var reduz := false

var _janela: Control          # recorta o cômodo
var _fundo_vp: SubViewport    # o cenário desenhado uma vez (como o canvas "fundo" da web)
var _fundo_no: Node2D
var _fundo_tex: TextureRect
var _vivo: Node2D             # o que mexe, desenhado todo quadro
var _topo: Node2D             # por cima das peças: a escolhida, a arrastada e os pontos subindo
var _nos := {}                # peca.id → PecaNo
var _no_laranja: PecaNo
var _sombra: ColorRect
var _fundo_chave := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sombra = ColorRect.new()
	_sombra.color = Color(0, 0, 0, 0.35)
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sombra)
	_janela = Control.new()
	_janela.clip_contents = true
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_janela)
	_fundo_vp = SubViewport.new()
	_fundo_vp.transparent_bg = false
	_fundo_vp.disable_3d = true
	_fundo_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_fundo_vp)
	_fundo_no = Node2D.new()
	_fundo_no.draw.connect(_desenha_fundo)
	_fundo_vp.add_child(_fundo_no)
	_fundo_tex = TextureRect.new()
	_fundo_tex.texture = _fundo_vp.get_texture()
	_fundo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_janela.add_child(_fundo_tex)
	_vivo = Node2D.new()
	_vivo.draw.connect(_desenha_vivo)
	_janela.add_child(_vivo)
	_no_laranja = PecaNo.new()
	_no_laranja.palco = self
	_vivo.add_child(_no_laranja)
	_topo = Node2D.new()
	_topo.draw.connect(_desenha_topo)
	_vivo.add_child(_topo)
	resized.connect(ajusta)
	jogo.saiu_popup.connect(_popup)
	jogo.mudou_fase.connect(func() -> void:
		sel = null
		arrasto = {}
		notas.clear()
		fumaca.clear()
		ajusta()
		selecionou.emit(null))
	jogo.mudou_modo.connect(func(m: String) -> void:
		if m == "roda" or m == "edita":
			popups.clear()
			notas.clear())
	ajusta.call_deferred()


# ---------- o tamanho ----------
func escala_tela() -> float:
	# quantos pixels de verdade tem uma unidade da interface
	return get_global_transform_with_canvas().get_scale().x


func ajusta() -> void:
	var cw := size.x
	var ch := size.y
	if cw <= 1 or ch <= 1:
		return
	esc = minf(cw / W, ch / H)
	ox = (cw - W * esc) / 2.0
	oy = (ch - H * esc) / 2.0
	et = floorf(oy / esc)
	eb = floorf((ch - oy) / esc - H)
	var topo := oy - et * esc
	_janela.position = Vector2(ox, topo)
	_janela.size = Vector2(W * esc, (H + et + eb) * esc)
	_sombra.position = Vector2(ox + 6, topo + 8)
	_sombra.size = _janela.size
	_vivo.position = Vector2(0, et * esc)
	_vivo.scale = Vector2(esc, esc)
	_fundo_tex.position = Vector2.ZERO
	_fundo_tex.size = _janela.size
	# o cenário vira uma imagem do tamanho de verdade da tela (nítido em qualquer celular)
	var s := _escala_fundo()
	var px := Vector2i(int(ceil(W * esc * s)), int(ceil((H + et + eb) * esc * s)))
	var chave := "%d|%s|%d|%d" % [jogo.fase_i, str(px), int(et), int(eb)]
	if chave != _fundo_chave:
		_fundo_chave = chave
		_fundo_vp.size = px
		_fundo_no.position = Vector2(0, et * esc * s)
		_fundo_no.scale = Vector2(esc * s, esc * s)
		_fundo_no.queue_redraw()
		_fundo_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	pos_ferr_pedida.emit()


signal pos_ferr_pedida


func _process(_dt: float) -> void:
	_vivo.queue_redraw()
	_topo.queue_redraw()
	_sincroniza_nos()
	# a escala da tela pode mudar sem o palco mudar de tamanho (janela arrastada pra outra tela)
	var s := _escala_fundo()
	var px := Vector2i(int(ceil(W * esc * s)), int(ceil((H + et + eb) * esc * s)))
	if _fundo_vp.size != px:
		ajusta()


func _escala_fundo() -> float:
	# o cenário é desenhado com o dobro de pixels e reduzido na tela: assim as bordas ficam lisas
	# (o renderizador de compatibilidade não tem antisserrilhado no 2D)
	var s := maxf(1.0, escala_tela()) * 2.0
	var maior := maxf(W * esc * s, (H + et + eb) * esc * s)
	if maior > 4096.0:
		s *= 4096.0 / maior
	return s


func _sincroniza_nos() -> void:
	# um nó por peça, na ordem da lista; a laranja e o "de cima" sempre por último
	var vivos := {}
	var t := _t()
	var rod := jogo.rodando()
	var px := esc * maxf(1.0, escala_tela())
	var i := 0
	for p in jogo.pecas:
		vivos[p.id] = true
		var no: PecaNo = _nos.get(p.id, null)
		if no == null or no.peca != p:
			if no != null:
				no.queue_free()
			no = PecaNo.new()
			no.peca = p
			no.palco = self
			_vivo.add_child(no)
			_nos[p.id] = no
		if no.get_index() != i:
			_vivo.move_child(no, i)
		no.atualiza(t, rod, jogo.passos, reduz, px)
		i += 1
	for id in _nos.keys():
		if not vivos.has(id):
			(_nos[id] as Node).queue_free()
			_nos.erase(id)
	_vivo.move_child(_no_laranja, _vivo.get_child_count() - 1)
	_vivo.move_child(_topo, _vivo.get_child_count() - 1)
	_no_laranja.atualiza(t, rod, jogo.passos, reduz, px)


func mundo_de(pos_local: Vector2) -> Vector2:
	return Vector2((pos_local.x - ox) / esc, (pos_local.y - oy) / esc)


func local_de(pt: Vector2) -> Vector2:
	return Vector2(ox + pt.x * esc, oy + pt.y * esc)


# ---------- desenho ----------
func _desenha_fundo() -> void:
	var c := Ctx.new(_fundo_no, Transform2D.IDENTITY, esc * _escala_fundo())
	Cenas.cena(jogo.fase_i, c, jogo.F, et, eb)


func _t() -> float:
	return float(Time.get_ticks_msec())


func _desenha_vivo() -> void:
	var t := _t()
	var c := Ctx.new(_vivo, Transform2D.IDENTITY, esc * maxf(1.0, escala_tela()))
	var rodando := jogo.rodando()
	# o que mexe no cômodo
	match jogo.fase_i:
		0:
			var seg := float(Time.get_time_dict_from_system().second)
			if rodando:
				seg = floorf(jogo.passos / Dados.PB)
			Cenas.relogio(c, seg)
		1:
			Cenas.vivo2(c, t, fumaca, reduz)
		2:
			var fra := fmod(jogo.passos / Dados.PB, 1.0) if rodando else fmod(t / 1000.0 * Dados.BPM / 60.0, 1.0)
			Cenas.vivo3(c, fra)
	# o alcance do vento (aparece quando o ventilador tá escolhido ou rodando)
	for p in jogo.pecas:
		if p.tipo != "ventilador":
			continue
		if jogo.modo == "edita" and sel != p and not (not arrasto.is_empty() and arrasto.p == p):
			continue
		var o := p.origem()
		c.save()
		c.translate(o.origin.x, o.origin.y)
		c.rotate(o.get_rotation())
		var cone := c.caminho().pontos(PackedVector2Array([Vector2(16, -30), Vector2(ALC, -26 - ALC * 0.28), Vector2(ALC, 26 + ALC * 0.28), Vector2(16, 30)]))
		c.fill(cone, Color(91 / 255.0, 143 / 255.0, 224 / 255.0, 0.10))
		c.dashed(cone, Color(45 / 255.0, 93 / 255.0, 166 / 255.0, 0.5), 1.5, 6, 6)
		c.restore()
	if not arrasto.is_empty() and arrasto.novo and arrasto.p.tipo == "ventilador" and arrasto.mexeu:
		var p: Peca = arrasto.p
		c.save()
		c.translate(p.x, p.y)
		c.rotate(p.a)
		var cone := c.caminho().pontos(PackedVector2Array([Vector2(16, -30), Vector2(ALC, -26 - ALC * 0.28), Vector2(ALC, 26 + ALC * 0.28), Vector2(16, 30)]))
		c.fill(cone, Color(91 / 255.0, 143 / 255.0, 224 / 255.0, 0.10))
		c.dashed(cone, Color(45 / 255.0, 93 / 255.0, 166 / 255.0, 0.5), 1.5, 6, 6)
		c.restore()
	# a varrida do limpador
	for p in jogo.pecas:
		if p.tipo != "limpador":
			continue
		_varrida(c, p)
	if not arrasto.is_empty() and arrasto.novo and arrasto.p.tipo == "limpador" and arrasto.mexeu:
		_varrida(c, arrasto.p)
	for v in jogo.ventos:
		c.save()
		c.alfa = 1.0 - v.d / ALC
		c.cap_redondo = true
		c.line(v.x, v.y, v.x - cos(v.a) * 12, v.y - sin(v.a) * 12, Color(1, 1, 1, 0.55), 1.6)
		c.restore()
	# o alvo
	var on := jogo.radio_ligado > 0
	var alvo: Dictionary = jogo.F.alvo
	match jogo.fase_i:
		0:
			Pinta.radio(c, alvo.x, alvo.y, on, t, notas, reduz)
		1:
			Pinta.caixa_som(c, alvo.x, alvo.y, on, t, notas, reduz)
		2:
			Pinta.amp(c, alvo.x, alvo.y, on, t, notas, reduz)


func _desenha_topo() -> void:
	var c := Ctx.new(_topo, Transform2D.IDENTITY, esc * maxf(1.0, escala_tela()))
	var t := _t()
	# a peça escolhida e a que tá sendo arrastada
	if sel != null and jogo.modo == "edita" and not (not arrasto.is_empty() and arrasto.novo):
		_contorno(c, sel, Color(1, 197 / 255.0, 49 / 255.0, 0.95))
	if not arrasto.is_empty() and arrasto.mexeu:
		var p: Peca = arrasto.p
		if arrasto.novo:
			c.save()
			c.alfa = 0.8
			Pinta.peca(c, p, t, false, 0, reduz)
			c.restore()
		if not arrasto.ok:
			_contorno(c, p, Color(215 / 255.0, 52 / 255.0, 43 / 255.0, 0.95))
	# os pontos subindo
	var agora := _t()
	popups = popups.filter(func(q: Dictionary) -> bool: return agora - float(q.t) < 1500)
	var f := Fontes.letreiro()
	for q in popups:
		var k: float = (agora - float(q.t)) / 1500.0
		var y: float = q.y - (0.0 if reduz else k * 46.0)
		c.save()
		c.alfa = 1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.25
		var mw := Ctx.largura(q.txt, f, 17) / 2.0 + 8
		var x := clampf(q.x, mw, W - mw)
		c.text_contorno(q.txt, x, y, f, 17, q.cor, 5, Color("#FBF6EA"), "center", "middle")
		c.restore()


func _varrida(c: Ctx, p: Peca) -> void:
	var pv := p.pose_parte(p.partes[0]).origin if p.partes[0].corpo != null else Vector2(p.x, p.y)
	var forte: bool = sel == p or (not arrasto.is_empty() and arrasto.p == p)
	var LA := Jogo.LIMP_A
	c.save()
	c.translate(pv.x, pv.y)
	var leque := c.caminho().move_to(0, 0).arc(0, 0, 112, p.a - LA, p.a + LA).fecha()
	c.fill(leque, Color(1, 176 / 255.0, 32 / 255.0, 0.16 if forte else 0.07))
	c.dashed(leque, Color(160 / 255.0, 100 / 255.0, 20 / 255.0, 0.7 if forte else 0.35), 1.5, 5, 6)
	# as pontas da varrida: o que estiver ali apanha em cima da batida
	for a in [p.a - LA, p.a + LA]:
		c.line(cos(a) * 96, sin(a) * 96, cos(a) * 120, sin(a) * 120, Color("#E58A00"), 3)
	c.restore()


func _contorno(c: Ctx, p: Peca, cor: Color) -> void:
	var parada := p.partes[0].corpo == null
	for pg in p.poligonos(parada):
		c.dashed(c.caminho().pontos(pg), cor, 2.7 / esc, 7, 5)


func _popup(pos: Vector2, txt: String, cor: Color) -> void:
	var agora := _t()
	var y := pos.y
	var achou := true
	while achou:
		achou = false
		for q in popups:
			if agora - float(q.t) < 500 and absf(float(q.x) - pos.x) < 140 and absf(float(q.y) - y) < 20:
				y -= 22
				achou = true
				break
	popups.append({ "x": pos.x, "y": y, "txt": txt, "cor": cor, "t": agora })
	if popups.size() > 14:
		popups.pop_front()


# ---------- escolher, arrastar ----------
func seleciona(p: Peca) -> void:
	sel = p
	selecionou.emit(p)


func comeca_novo(tipo: String, toque: bool) -> void:
	var p := jogo.nova_peca(tipo, 0, 0)
	arrasto = { "p": p, "novo": true, "dx": 0.0, "dy": (-52.0 / esc) if toque else 0.0, "mexeu": true, "ok": false }
	seleciona(null)


func move_arrasto_global(gpos: Vector2) -> void:
	if arrasto.is_empty():
		return
	var pt := mundo_de(get_global_transform().affine_inverse() * gpos)
	var p: Peca = arrasto.p
	p.x = roundf(pt.x + arrasto.dx)
	p.y = roundf(pt.y + arrasto.dy)
	arrasto.ok = jogo.cabe(p)


func solta_global(gpos: Vector2, cancelou := false) -> void:
	if arrasto.is_empty():
		return
	var a := arrasto
	var p: Peca = a.p
	arrasto = {}
	if a.novo:
		if a.ok and not cancelou:
			jogo.poe_peca(p)
			seleciona(p)
		elif not cancelou:
			var pt := mundo_de(get_global_transform().affine_inverse() * gpos)
			if pt.y < H and pt.y > 0 and pt.x > 0 and pt.x < W:
				aviso_pedido.emit("Ali não cabe")
	elif a.mexeu and not a.ok:
		p.x = a.de.x
		p.y = a.de.y
		aviso_pedido.emit("Ali não cabe")
	pos_ferr_pedida.emit()


signal aviso_pedido(txt: String)
signal tocou_palco


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			tocou_palco.emit()
			if jogo.modo != "edita":
				return
			var pt := mundo_de(ev.position)
			var p := jogo.pega(pt, 16.0 / esc)
			if p == null:
				seleciona(null)
				return
			arrasto = { "p": p, "novo": false, "dx": p.x - pt.x, "dy": p.y - pt.y, "de": Vector2(p.x, p.y), "mexeu": false, "sx": ev.position.x, "sy": ev.position.y, "ok": true }
			seleciona(p)
			accept_event()
		else:
			if not arrasto.is_empty() and not arrasto.novo:
				solta_global(get_global_transform() * ev.position)
	elif ev is InputEventMouseMotion and not arrasto.is_empty() and not arrasto.novo:
		if not arrasto.mexeu and Vector2(ev.position.x - arrasto.sx, ev.position.y - arrasto.sy).length() < 5:
			return
		arrasto.mexeu = true
		ferr_esconde.emit()
		var pt := mundo_de(ev.position)
		var p: Peca = arrasto.p
		p.x = roundf(pt.x + arrasto.dx)
		p.y = roundf(pt.y + arrasto.dy)
		arrasto.ok = jogo.cabe(p)


signal ferr_esconde
