class_name Jogo
extends Node2D
## O mundo da gambiarra: os fixos do cômodo, a tralha, a laranja e a física passo a passo.
## A lógica é a da versão web (gambiarra.html), passo por passo; a física é a da Godot,
## com os números ajustados (AJ) pra cada fase se comportar como no Matter.js.

signal mudou_pontos(pts: int)
signal mudou_corrente
signal mudou_modo(modo: String)
signal mudou_fase
signal mudou_estoque
signal mudou_pedido
signal saiu_popup(pos: Vector2, txt: String, cor: Color)
signal aviso(txt: String)
signal acabou(resumo: Dictionary)

const W := Dados.W
const H := Dados.H
const CHAO := Dados.CHAO
const ALC := 300.0
const LIMP_A := PI / 4.0
const POR_PASSO := 60.0                 # o Matter conta velocidade em px por passo; a Godot em px por segundo

# ---------- o ajuste da física (Matter.js → Godot) ----------
# Medido lado a lado com a web (a laranja caindo no chão, no colchão, o pneu, a gangorra, a telha, o vento...):
# - quique: na Godot o quique de um par é a SOMA dos dois (no Matter é o maior), e o Matter na prática perde
#   uns 20% do quique que diz ter; então os parados ficam com 0 e cada coisa leva uns 80% do da web
#   (o colchão leva 0,48 porque soma com os 0,34 da laranja).
# - a laranja: no Matter ela rola devagar e quase sem acelerar na prateleira (o círculo dele tem 14 lados e
#   a inércia é ×4); aqui ela é áspera (sempre rola) e tem um amortecimento no giro que faz o mesmo papel.
var AJ := {
	"gravidade": 1200.0,
	"inercia": 4.0,                       # o Matter multiplica a inércia por 4: as coisas giram mais devagar
	"quique_laranja": 0.34,
	"quique_fixo": 0.0,
	"quique": { "colchao": 0.48, "balde": 0.0, "telha": 0.0, "lata": 0.2, "garrafa": 0.12, "gato": 0.04, "pneu": 0.7, "caramelo": 0.04, "gangorra": 0.04, "limpador": 0.0 },
	"atrito_laranja": 0.9,
	"atrito": {},
	"ccd": true,
	"laranja_poligono": false,            # o Matter faz o círculo com 14 lados
	"laranja_giro": 1.05,                 # amortecimento do giro da laranja (resistência de rolar)
	"laranja_densidade": 0.0014,
	"laranja_aspera": true,               # o atrito da laranja manda no par (no Matter ele é sempre o menor)
}

var fase_i := 0
var fase: Dictionary = {}
var modo := "edita"                     # edita, roda, festa, fim
var tentativas := 0
var passos := 0
var quieto := 0
var festa_passo := 0
var cadeia := {}                        # instance_id → true: o que veio da laranja
var pts := 0
var eventos: Array[Dictionary] = []
var fixos_tocados := {}
var nao_vale := {}
var caidas := 0
var quem_ligou: Object = null
var ultima_peca: Peca = null
var radio_ligado := 0                   # ms em que o alvo ligou (0: desligado)
var pedido_ok: Array[String] = []
var no_tempo_set := {}
var melhor_seq := 0
var levada_ok := false
var gravado: Array[Dictionary] = []     # cada batida: { passo, inst, v }
var tocou := {}
var pecas: Array[Peca] = []
var pid := 0
var estoque := {}
var recorde := 0
var ventos: Array[Dictionary] = []      # os risquinhos do vento (só enfeite)

var fixos: Array[Dictionary] = []       # { chave, id, corpo, pts, x, y, w, h, a, sensor }
var F := {}                             # id → fixo (prat, alvo, tecla...)
var laranja: RigidBody2D = null
var tecla: Area2D = null
var _contatos_ant := {}
var _vel_ant := {}
var _fila_tecla: Array[Object] = []
var _corpos: Array[PhysicsBody2D] = []  # tudo que nasceu no VAI!
var _rng := RandomNumberGenerator.new()
var resumo: Dictionary = {}
var laranja_ini_teste: Variant = null
var reduz := false                      # "reduzir movimento": sem os risquinhos do vento   # os testes de cenário começam a laranja noutro lugar


var _som_no: Node = null


func _som() -> Node:
	# o som é um autoload; os testes sem tela rodam sem ele e aí ninguém toca nada
	if _som_no == null or not is_instance_valid(_som_no):
		_som_no = get_tree().root.get_node_or_null("Som") if is_inside_tree() else null
		if _som_no == null:
			_som_no = Node.new()
			_som_no.set_script(load("res://scripts/som_mudo.gd"))
	return _som_no


func _ready() -> void:
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, AJ.gravidade)
	var f := int(Salva.le("fase", 0))
	carrega_fase(clampi(f, 0, Dados.FASES.size() - 1))


# ============ as fases ============
func carrega_fase(i: int) -> void:
	if modo != "edita":
		ajeita()
	for p in pecas:
		_tira_corpos(p)
	pecas.clear()
	fase_i = i
	fase = Dados.FASES[i]
	Salva.guarda("fase", i)
	recorde = int(Salva.le(fase.rec, 0))
	tentativas = 0
	_monta_fixos()
	zera_estoque()
	_zera_rodada()
	mudou_fase.emit()
	mudou_estoque.emit()
	mudou_pedido.emit()
	mudou_corrente.emit()


func zera_estoque() -> void:
	estoque = (fase.caixa as Dictionary).duplicate()


func _fixo(chave: String, x: float, y: float, w: float, h: float, o: Dictionary) -> Dictionary:
	var ang: float = o.get("a", 0.0)
	var pts_local := Peca.retangulo(w, h, o.get("ch", 0.0))
	var d := { "chave": chave, "id": o.get("id", chave), "x": x, "y": y, "w": w, "h": h, "a": ang, "sensor": o.get("sensor", false),
		"pts": Transform2D(ang, Vector2(x, y)) * pts_local, "corpo": null }
	if d.sensor:
		var ar := Area2D.new()
		ar.collision_layer = 2
		ar.collision_mask = 1
		ar.monitorable = false
		var cs := CollisionShape2D.new()
		var sh := ConvexPolygonShape2D.new()
		sh.points = pts_local
		cs.shape = sh
		ar.add_child(cs)
		ar.position = Vector2(x, y)
		ar.rotation = ang
		ar.body_entered.connect(func(b: Node2D) -> void: _fila_tecla.append(b))
		add_child(ar)
		d.corpo = ar
		tecla = ar
	else:
		var sb := StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask = 1
		var mat := PhysicsMaterial.new()
		mat.friction = o.get("atr", 0.5)
		mat.bounce = AJ.quique_fixo
		sb.physics_material_override = mat
		var cs := CollisionShape2D.new()
		var sh := ConvexPolygonShape2D.new()
		sh.points = pts_local
		cs.shape = sh
		sb.add_child(cs)
		sb.position = Vector2(x, y)
		sb.rotation = ang
		sb.set_meta("fixo", chave)
		sb.set_meta("mat", chave)
		add_child(sb)
		d.corpo = sb
	fixos.append(d)
	F[d.id] = d
	return d


func _monta_fixos() -> void:
	for d in fixos:
		if is_instance_valid(d.corpo):
			_some(d.corpo)
	fixos.clear()
	F.clear()
	tecla = null
	_fixo("parede", -40, H / 2, 80, H * 3, { "id": "esq" })
	_fixo("parede", W + 40, H / 2, 80, H * 3, { "id": "dir" })
	_fixo("teto", W / 2, -140, W * 2, 80, {})
	_fixo("chao", W / 2, CHAO + 40, W * 2, 80, {})
	for fx in fase.fixos:
		_fixo(fx[0], fx[1], fx[2], fx[3], fx[4], fx[5])


# ============ a tralha parada (editando) ============
func laranja_pts() -> PackedVector2Array:
	var c: Vector2 = fase.ini if laranja == null else laranja.global_position
	return Peca.circulo_pts(14, c, 14)


func nova_peca(tipo: String, x: float, y: float, a := 0.0, flip := 1) -> Peca:
	var p := Peca.nova(tipo, x, y, a, flip)
	return p


func _poli_bate(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for pg in Geometry2D.intersect_polygons(a, b):
		if absf(_area(pg)) > 0.5:
			return true
	return false


static func _area(pg: PackedVector2Array) -> float:
	var s := 0.0
	var n := pg.size()
	for i in range(n):
		var p1 := pg[i]
		var p2 := pg[(i + 1) % n]
		s += p1.x * p2.y - p2.x * p1.y
	return s / 2.0


static func _caixa_de(pg: PackedVector2Array) -> Rect2:
	var r := Rect2(pg[0], Vector2.ZERO)
	for v in pg:
		r = r.expand(v)
	return r


func cabe(p: Peca) -> bool:
	for bb in p.caixas_partes(true):
		if bb.position.x < 2 or bb.end.x > W - 2 or bb.position.y < 2 or bb.end.y > CHAO + 1:
			return false
	var meus := p.poligonos(true)
	var outros: Array[PackedVector2Array] = []
	for d in fixos:
		if not d.sensor:
			outros.append(d.pts)
	for q in pecas:
		if q != p:
			outros.append_array(q.poligonos(true))
	outros.append(laranja_pts())
	for m in meus:
		var cm := _caixa_de(m)
		for o in outros:
			if not cm.intersects(_caixa_de(o)):
				continue
			if _poli_bate(m, o):
				return false
	return true


func poe(tipo: String, x: float, y: float, a := 0.0, flip := 1) -> bool:
	# pros testes e pro carregamento: põe direto, se tiver na caixa e couber
	if modo != "edita" or int(estoque.get(tipo, 0)) <= 0:
		return false
	var p := nova_peca(tipo, x, y, a, flip)
	if not cabe(p):
		return false
	poe_peca(p)
	return true


func poe_peca(p: Peca) -> void:
	pid += 1
	p.id = pid
	pecas.append(p)
	estoque[p.tipo] = int(estoque[p.tipo]) - 1
	mudou_estoque.emit()


func auto_poe(tipo: String) -> Peca:
	if modo != "edita" or int(estoque.get(tipo, 0)) <= 0:
		return null
	var p := nova_peca(tipo, 0, 0)
	var cands: Array[Vector2] = []
	var yy := 110
	while yy < CHAO - 30:
		var xx := 70
		while xx < W - 60:
			cands.append(Vector2(xx, yy))
			xx += 30
		yy += 30
	var c: Vector2 = fase.centro
	cands.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.distance_to(c) < v.distance_to(c))
	for cd in cands:
		p.x = cd.x
		p.y = cd.y
		if cabe(p):
			poe_peca(p)
			aviso.emit("Arrasta pra onde quiser")
			return p
	aviso.emit("Não tem lugar livre")
	return null


func pega(pt: Vector2, folga := 16.0) -> Peca:
	for i in range(pecas.size() - 1, -1, -1):
		for pg in pecas[i].poligonos(true):
			if Geometry2D.is_point_in_polygon(pt, pg):
				return pecas[i]
	var melhor: Peca = null
	var md := 1e9
	for p in pecas:
		for pt_ in p.partes:
			var xf := p.pose_parada(pt_)
			var bb := Rect2()
			var primeiro := true
			for f in pt_.formas:
				for v in xf * f.pts:
					if primeiro:
						bb = Rect2(v, Vector2.ZERO)
						primeiro = false
					else:
						bb = bb.expand(v)
			if bb.grow(folga).has_point(pt):
				var d := pt.distance_to(xf.origin)
				if d < md:
					md = d
					melhor = p
	return melhor


func gira(p: Peca, d: int) -> void:
	if p == null or modo != "edita":
		return
	var t: Dictionary = Dados.TIPOS[p.tipo]
	if t.vira:
		p.flip *= -1
		return
	if not t.gira:
		return
	var a0 := p.a
	p.a = roundf((p.a + d * PI / 12.0) * 1e6) / 1e6
	if not cabe(p):
		p.a = a0
		aviso.emit("Girado não cabe aí")


func devolve(p: Peca) -> void:
	if p == null or modo != "edita":
		return
	pecas.erase(p)
	estoque[p.tipo] = int(estoque[p.tipo]) + 1
	mudou_estoque.emit()


# ============ os corpos (nascem no VAI!) ============
func _material(atrito: float, quique: float) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = atrito
	m.bounce = quique
	return m


func _formas_em(corpo: CollisionObject2D, pt: Peca.Parte) -> void:
	for f in pt.formas:
		var cs := CollisionShape2D.new()
		if f.circulo:
			var sh := CircleShape2D.new()
			sh.radius = f.r
			cs.shape = sh
			cs.position = f.c
		else:
			var sh := ConvexPolygonShape2D.new()
			sh.points = f.pts
			cs.shape = sh
		corpo.add_child(cs)


static func _area_formas(pt: Peca.Parte) -> float:
	var s := 0.0
	for f in pt.formas:
		s += PI * f.r * f.r if f.circulo else absf(_area(f.pts))
	return s


static func _inercia_formas(pt: Peca.Parte, massa: float) -> float:
	# o momento de inércia de verdade (como o Matter calcula), antes do ×4
	var f := pt.formas[0]
	if f.circulo:
		return massa * f.r * f.r / 2.0
	var bb := _caixa_de(f.pts)
	return massa * (bb.size.x * bb.size.x + bb.size.y * bb.size.y) / 12.0


func _rigido(pt: Peca.Parte, mat_nome: String, quique: float, atrito: float) -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.collision_layer = 1
	rb.collision_mask = 1
	_formas_em(rb, pt)
	var massa := pt.densidade * _area_formas(pt)
	rb.mass = massa
	if pt.trava_giro:
		rb.lock_rotation = true
	else:
		rb.inertia = _inercia_formas(pt, massa) * AJ.inercia
	rb.physics_material_override = _material(atrito, quique)
	rb.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.linear_damp = pt.ar * POR_PASSO
	rb.angular_damp = pt.ar * POR_PASSO
	rb.can_sleep = false
	rb.contact_monitor = true
	rb.max_contacts_reported = 16
	if AJ.ccd:
		rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	rb.set_meta("mat", mat_nome)
	return rb


func _cria_corpos(p: Peca) -> void:
	var qa: Dictionary = AJ.quique
	var base: PhysicsBody2D = null
	for i in range(p.partes.size()):
		var pt := p.partes[i]
		var xf := p.pose_parada(pt)
		var corpo: PhysicsBody2D
		if pt.dinamico:
			var q: float = qa.get(p.tipo, pt.quique)
			var at: float = (AJ.atrito as Dictionary).get(p.tipo, pt.atrito)
			var rb := _rigido(pt, p.tipo, q, at)
			if pt.motor:
				rb.gravity_scale = 0.0
				rb.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
				rb.set_meta("motor", true)
			if p.tipo == "gato" or p.tipo == "caramelo":
				rb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				rb.freeze = true
			corpo = rb
		else:
			var sb := StaticBody2D.new()
			sb.collision_layer = 1
			sb.collision_mask = 1
			_formas_em(sb, pt)
			var q: float = qa.get(p.tipo, AJ.quique_fixo) if p.tipo in ["colchao", "balde", "telha"] else AJ.quique_fixo
			var at: float = (AJ.atrito as Dictionary).get(p.tipo, pt.atrito)
			sb.physics_material_override = _material(at, q)
			sb.set_meta("mat", p.tipo)
			corpo = sb
		corpo.set_meta("peca", p)
		corpo.global_transform = xf
		add_child(corpo)
		pt.corpo = corpo
		_corpos.append(corpo)
		if i == 0:
			base = corpo
		elif (p.tipo == "gangorra" or p.tipo == "limpador") and base != null:
			corpo.add_collision_exception_with(base)
	if p.tipo == "gangorra":
		var j := PinJoint2D.new()
		j.position = Vector2(p.x, p.y - 6)
		add_child(j)
		j.node_a = j.get_path_to(p.partes[0].corpo)
		j.node_b = j.get_path_to(p.partes[1].corpo)
		j.softness = 0.0
		j.disable_collision = true
		p.junta = j


func _tira_corpos(p: Peca) -> void:
	if p.junta != null and is_instance_valid(p.junta):
		_some(p.junta)
	p.junta = null
	for pt in p.partes:
		if pt.corpo != null and is_instance_valid(pt.corpo):
			_some(pt.corpo)
		pt.corpo = null


func _cria_laranja() -> void:
	if laranja != null and is_instance_valid(laranja):
		_some(laranja)
	var pt := Peca.Parte.new()
	var f := Peca.Forma.new()
	if AJ.laranja_poligono:
		f.pts = Peca.circulo_pts(14, Vector2.ZERO, 14)
	else:
		f.circulo = true
		f.r = 14
	pt.formas.append(f)
	pt.densidade = AJ.laranja_densidade
	pt.ar = 0.0015
	laranja = _rigido(pt, "laranja", AJ.quique_laranja, AJ.atrito_laranja)
	if AJ.laranja_aspera:
		laranja.physics_material_override.rough = true
	if AJ.laranja_poligono:
		laranja.inertia = laranja.mass * 14.0 * 14.0 / 2.0 * AJ.inercia
	if AJ.laranja_giro > 0.0:
		laranja.angular_damp = AJ.laranja_giro
	laranja.global_position = fase.ini if laranja_ini_teste == null else laranja_ini_teste
	add_child(laranja)
	_corpos.append(laranja)


func _tira_laranja() -> void:
	if laranja != null and is_instance_valid(laranja):
		_some(laranja)
	laranja = null


func _some(n: Node) -> void:
	# sai do mundo na hora (senão o corpo velho ainda bate um passo junto com o novo)
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()


static func _peca_de(o: Object) -> Peca:
	if o != null and is_instance_valid(o) and o.has_meta("peca"):
		return o.get_meta("peca") as Peca
	return null


static func estatico(o: Object) -> bool:
	if o is StaticBody2D:
		return true
	if o is RigidBody2D:
		return (o as RigidBody2D).freeze
	return true


func dinamicos() -> Array[RigidBody2D]:
	var out: Array[RigidBody2D] = []
	for c in _corpos:
		if is_instance_valid(c) and c is RigidBody2D and not (c as RigidBody2D).freeze:
			out.append(c)
	return out


func _vel(o: Object) -> Vector2:
	# a velocidade de antes do passo (em px por passo, como no Matter)
	if estatico(o):
		return Vector2.ZERO
	var id := o.get_instance_id()
	if _vel_ant.has(id):
		return _vel_ant[id] / POR_PASSO
	return (o as RigidBody2D).linear_velocity / POR_PASSO


func _set_xf(rb: RigidBody2D, xf: Transform2D) -> void:
	PhysicsServer2D.body_set_state(rb.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, xf)


# ============ pontos ============
func popup(pos: Vector2, txt: String, cor := Color("#F07A1C")) -> void:
	saiu_popup.emit(pos, txt, cor)


func pontua(n: int, txt: String, pos: Vector2, cor := Color("#F07A1C")) -> void:
	pts += n
	eventos.append({ "txt": txt, "n": n })
	popup(Vector2(pos.x, pos.y - 18), "+%d %s" % [n, txt], cor)
	mudou_pontos.emit(pts)


func entra(p: Peca, n: int, txt: String, pos: Vector2) -> void:
	if p.entrou:
		return
	p.entrou = true
	ultima_peca = p
	pontua(n, txt, pos)
	mudou_corrente.emit()


func na_corrente() -> int:
	var n := 0
	for p in pecas:
		if p.entrou:
			n += 1
	return n


func rodando() -> bool:
	return modo == "roda" or modo == "festa"


# ============ o som: cada batida cai na grade do beat ============
func bate(inst: String, v: float, pos: Vector2, da_corrente: bool) -> void:
	# o que o lugar pede só conta quando quem tocou tava na corrente
	var pedido: Array = fase.pedido
	if da_corrente and inst in pedido and not (inst in pedido_ok) and rodando():
		pedido_ok.append(inst)
		mudou_pedido.emit()
		pontua(15, "Pedido: " + str(Dados.INFO[inst][0]), pos, Color("#2D5DA6"))
	# perto da batida (até um quinto dela pra lá ou pra cá) conta como no tempo e o som cai em cima dela
	var xb := passos / Dados.PB
	var bq := int(roundf(xb))
	var na_batida := absf(xb - bq) <= 0.22
	var passo16 := bq * 4 if na_batida else maxi(0, int(ceil(passos / Dados.P16 - 0.2)))
	if da_corrente and int(fase.levada) > 0 and na_batida and passos > 12 and rodando():
		_no_tempo(bq, pos)
	if not Dados.INFO.has(inst):
		return
	var chave := "%s@%d" % [inst, passo16]
	if tocou.has(chave):
		return
	tocou[chave] = true
	gravado.append({ "passo": passo16, "inst": inst, "v": v })
	_som().agenda(inst, v, passo16)


func _no_tempo(b: int, pos: Vector2) -> void:
	# a levada: batidas da corrente que caem em cima do tempo, uma atrás da outra
	if no_tempo_set.has(b):
		return
	no_tempo_set[b] = true
	pontua(5, "No tempo", pos, Color("#2D5DA6"))
	var ini := b
	var fim := b
	while no_tempo_set.has(ini - 1):
		ini -= 1
	while no_tempo_set.has(fim + 1):
		fim += 1
	melhor_seq = maxi(melhor_seq, fim - ini + 1)
	if not levada_ok and melhor_seq >= int(fase.levada):
		levada_ok = true
		pontua(30, "Levada!", Vector2(pos.x, pos.y - 24), Color("#C2326A"))
	mudou_pedido.emit()


# ============ a física passo a passo ============
func _vento() -> void:
	for p in pecas:
		if p.tipo != "ventilador":
			continue
		var o := p.origem()
		var ang := o.get_rotation()
		var ca := cos(ang)
		var sa := sin(ang)
		for b in dinamicos():
			var rx := b.global_position.x - o.origin.x
			var ry := b.global_position.y - o.origin.y
			var d := rx * ca + ry * sa
			var l := -rx * sa + ry * ca
			var larg := 26.0 + d * 0.28
			if d < 16 or d > ALC or absf(l) > larg:
				continue
			var k := (1.0 - d / ALC) * (1.0 - absf(l) / larg * 0.5)
			if not b.has_meta("motor"):
				# no Matter a força é 0,0019 × massa e vira velocidade com o passo ao quadrado (16,7 ms)²;
				# em px/s² isso dá 0,0019 × 277,8 × 3600 ≈ 1900 × k
				var acel := 0.0019 * k * pow(1000.0 / 60.0, 2) * POR_PASSO * POR_PASSO
				b.apply_central_force(Vector2(ca, sa) * acel * b.mass)
			if cadeia.has(b.get_instance_id()):
				entra(p, 20, "Soprou!", b.global_position)
				if passos - int(p.ev.get("choc", -99)) > 15:
					p.ev["choc"] = passos
					bate("chocalho", 0.7, b.global_position, true)


func _raio(b: RigidBody2D) -> float:
	if b == laranja:
		return 14.0
	var p: Peca = _peca_de(b)
	if p != null and (p.tipo == "lata" or p.tipo == "pneu"):
		return 16.0 if p.tipo == "lata" else 24.0
	return 18.0


func _perto(g: RigidBody2D, raio: float) -> RigidBody2D:
	for b in dinamicos():
		if b == g:
			continue
		var sp := _speed(b)
		if sp >= 0.6 and b.global_position.distance_to(g.global_position) < raio + _raio(b):
			return b
	return null


func _speed(b: RigidBody2D) -> float:
	return b.linear_velocity.length() / POR_PASSO


func _bichos() -> void:
	# o gato e o caramelo acordam quando alguma coisa passa mexendo perto
	for p in pecas:
		if p.tipo != "gato" and p.tipo != "caramelo":
			continue
		var g := p.partes[0].corpo as RigidBody2D
		if g == null:
			continue
		if p.tipo == "gato" and not p.assustado:
			var b := _perto(g, 50)
			if b != null:
				_assusta(p, b)
		if p.tipo == "caramelo":
			if not p.acordado:
				var b := _perto(g, 58)
				if b != null:
					_acorda(p, b)
			elif passos < p.corre:
				g.linear_velocity = Vector2(p.flip * 5.2 * POR_PASSO, g.linear_velocity.y)
				if passos == p.corre - 38:
					bate("latido", 0.7, g.global_position, cadeia.has(g.get_instance_id()))
			elif passos == p.corre:
				g.linear_velocity = Vector2(g.linear_velocity.x * 0.3, g.linear_velocity.y)


func _acorda(p: Peca, quem: Object) -> void:
	var g := p.partes[0].corpo as RigidBody2D
	var ch := cadeia.has(quem.get_instance_id())
	p.acordado = true
	p.corre = passos + 75
	g.freeze = false
	g.linear_velocity = Vector2(p.flip * 5.2, -3) * POR_PASSO
	if ch:
		cadeia[g.get_instance_id()] = true
		entra(p, 30, "Acordou o caramelo", g.global_position)
	else:
		popup(g.global_position + Vector2(0, -30), "acordou à toa", Color("#8A7E74"))
	bate("latido", 0.95, g.global_position, ch)


func _assusta(p: Peca, quem: Object) -> void:
	var g := p.partes[0].corpo as RigidBody2D
	p.assustado = true
	g.freeze = false
	g.linear_velocity = Vector2(p.flip * 4.4, -10.5) * POR_PASSO
	g.angular_velocity = p.flip * 0.05 * POR_PASSO
	var ch := cadeia.has(quem.get_instance_id())
	bate("miau", 0.95, g.global_position, ch)
	if ch:
		cadeia[g.get_instance_id()] = true
		entra(p, 30, "Assustou o gato", g.global_position)
	else:
		popup(g.global_position + Vector2(0, -30), "pulou à toa", Color("#8A7E74"))


func pose_limp(p: Peca, n: float) -> float:
	# parado ele fica no meio; ligado, vai até a ponta em cima de cada batida
	if p.liga < 0 or n < p.liga:
		return p.a
	return p.a + LIMP_A * sin(PI * (n - p.liga) / Dados.PB)


func _motores() -> void:
	for p in pecas:
		if p.tipo != "limpador":
			continue
		var base := p.partes[0].corpo
		var br := p.partes[1].corpo as RigidBody2D
		if base == null or br == null:
			continue
		var th0 := pose_limp(p, passos)
		var th1 := pose_limp(p, passos + 1)
		var bp := base.global_position
		var c0 := bp + Vector2(cos(th0), sin(th0)) * 56.0
		_set_xf(br, Transform2D(th0, c0))
		var v := (Vector2(cos(th1), sin(th1)) - Vector2(cos(th0), sin(th0))) * 56.0 * POR_PASSO
		PhysicsServer2D.body_set_state(br.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v)
		PhysicsServer2D.body_set_state(br.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, (th1 - th0) * POR_PASSO)
		_vel_ant[br.get_instance_id()] = v


func _liga_limp(p: Peca, pos: Vector2) -> void:
	if p.liga >= 0:
		return
	p.liga = (floorf(passos / Dados.PB) + 0.5) * Dados.PB
	if p.liga <= passos:
		p.liga += Dados.PB
	cadeia[p.partes[1].corpo.get_instance_id()] = true
	entra(p, 20, "Ligou o limpador", pos)


func _depois() -> void:
	_motores()
	for p in pecas:
		if p.tipo == "gangorra":
			var t := p.partes[1].corpo as RigidBody2D
			if t == null:
				continue
			var LIM := 0.42
			var av := t.angular_velocity / POR_PASSO
			var ang := wrapf(t.rotation, -PI, PI)
			if cadeia.has(t.get_instance_id()) and absf(av) > 0.06 and not p.ev.get("cat", false):
				p.ev["cat"] = true
				pontua(20, "Catapulta!", t.global_position)
			if absf(ang) > LIM:
				if absf(av) > 0.05:
					bate("cuica", 0.8, t.global_position, cadeia.has(t.get_instance_id()))
				_set_xf(t, Transform2D(signf(ang) * LIM, t.global_position))
				t.angular_velocity = 0.0
		if p.tipo == "garrafa" and p.entrou and not p.ev.get("caiu", false):
			var b := p.partes[0].corpo as RigidBody2D
			var aa := absf(wrapf(b.rotation, -PI, PI))
			if aa > 1.1:
				p.ev["caiu"] = true
				caidas += 1
				pontua(10, "Derrubou a PET", b.global_position)
				if caidas == 2:
					pontua(20, "Dominó de PET", b.global_position, Color("#C2326A"))
				if caidas == 3:
					pontua(20, "Dominó completo", b.global_position, Color("#C2326A"))
		if p.squash > 0:
			p.squash = maxf(0.0, p.squash - 0.08)
	var maxv := 0.0
	for b in dinamicos():
		if b.has_meta("motor"):
			continue   # o limpador não para nunca: não conta pra saber se a gambiarra parou
		var sp := _speed(b)
		if sp > 19.0:
			b.linear_velocity *= 19.0 / sp
		maxv = maxf(maxv, maxf(sp, absf(b.angular_velocity / POR_PASSO) * 15.0))
	if modo != "roda":
		return
	quieto = quieto + 1 if maxv < 0.1 else 0
	if quieto > 80:
		_falha("parou")
	elif passos > 60 * 25:
		_falha("demorou")


func _processa_contatos() -> void:
	var atuais := {}
	var novos: Array = []
	for corpo in dinamicos():
		var st := PhysicsServer2D.body_get_direct_state(corpo.get_rid())
		if st == null:
			continue
		var idc := corpo.get_instance_id()
		for i in range(st.get_contact_count()):
			var outro := st.get_contact_collider_object(i)
			if outro == null or not (outro is PhysicsBody2D):
				continue
			var ka := "%d:%d" % [idc, st.get_contact_local_shape(i)]
			var kb := "%d:%d" % [outro.get_instance_id(), st.get_contact_collider_shape(i)]
			var k := ka + "|" + kb if ka < kb else kb + "|" + ka
			if atuais.has(k):
				continue
			atuais[k] = true
			if not _contatos_ant.has(k):
				novos.append([corpo, outro, st.get_contact_local_position(i)])
	_contatos_ant = atuais
	for n in novos:
		_colisao(n[0], n[1], n[2])


func _colisao(A: Object, B: Object, pos: Vector2) -> void:
	if not rodando():
		return
	var ca := cadeia.has(A.get_instance_id())
	var cb := cadeia.has(B.get_instance_id())
	var rv := (_vel(A) - _vel(B)).length()
	# encostada da corrente sempre soa (mesmo de leve); o resto só se bater forte
	if rv > 1.0 or (rv > 0.3 and (ca or cb)):
		_som_de(A, B, maxf(rv, 1.0), pos)
	if ca and not estatico(A):
		_toca(B, A, rv, pos)
	if cb and not estatico(B):
		_toca(A, B, rv, pos)


func _som_de(A: Object, B: Object, rv: float, pos: Vector2) -> void:
	var ma: String = A.get_meta("mat", "")
	var mb: String = B.get_meta("mat", "")
	var m := mb if ma == "laranja" else (ma if mb == "laranja" else (ma if _vel(A).length() < _vel(B).length() else mb))
	var da_c := cadeia.has(A.get_instance_id()) or cadeia.has(B.get_instance_id())
	bate(Dados.SOM.get(m, ""), minf(1.0, 0.28 + (rv - 1.0) / 7.0), pos, da_c)


func _toca(y: Object, x: Object, rv: float, pos: Vector2) -> void:
	var p: Peca = _peca_de(y)
	if p != null:
		if p.tipo == "gato":
			if not p.assustado:
				_assusta(p, x)
			return
		if p.tipo == "caramelo":
			if not p.acordado:
				_acorda(p, x)
			return
		if p.tipo == "limpador":
			_liga_limp(p, pos)
			return
		if p.tipo == "colchao":
			if rv > 2.5:
				p.squash = 1.0
			if not p.entrou:
				entra(p, 15, "Boing!", pos)
			elif rv > 2.5 and int(p.ev.get("boing", 0)) < 3:
				p.ev["boing"] = int(p.ev.get("boing", 0)) + 1
				pontua(10, "Boing de novo", pos)
		else:
			entra(p, Dados.TIPOS[p.tipo].pts, "Bateu no ventilador" if p.tipo == "ventilador" else Dados.TIPOS[p.tipo].txt, pos)
		if not estatico(y):
			cadeia[y.get_instance_id()] = true
	elif y.has_meta("fixo"):
		var fx: String = y.get_meta("fixo")
		if Dados.FIXO_PTS.has(fx) and not fixos_tocados.has(fx) and rv > 0.8:
			fixos_tocados[fx] = true
			pontua(Dados.FIXO_PTS[fx][0], Dados.FIXO_PTS[fx][1], pos, Color("#8A6A55"))


func _aperta(o: Object) -> void:
	if modo != "roda" or estatico(o) or not is_instance_valid(o):
		return
	if cadeia.has(o.get_instance_id()):
		_ganha(o)
		return
	if not nao_vale.has(o.get_instance_id()):
		nao_vale[o.get_instance_id()] = true
		var tp: Vector2 = Vector2(F.tecla.x, F.tecla.y)
		popup(tp + Vector2(0, -40), "Não vale: não veio da laranja", Color("#D7342B"))


func _ganha(o: Object) -> void:
	quem_ligou = o
	modo = "festa"
	festa_passo = passos
	radio_ligado = Time.get_ticks_msec()
	var pos := Vector2(F.tecla.x, F.tecla.y - 30)
	pontua(50, fase.ligou, pos, Color("#D7342B"))
	var p: Peca = _peca_de(o)
	if p != null and Dados.QUEM.has(p.tipo):
		var q: Array = Dados.QUEM[p.tipo]
		pontua(q[0], q[1], pos + Vector2(0, -30), Color("#C2326A"))
	_som().liga_radio()
	mudou_modo.emit(modo)


func _falha(motivo: String) -> void:
	modo = "fim"
	_mostra_fim(false, motivo)


func _physics_process(_dt: float) -> void:
	if not rodando():
		return
	if passos > 0:
		_processa_contatos()
		var fila := _fila_tecla.duplicate()
		_fila_tecla.clear()
		for o in fila:
			_aperta(o)
		_depois()
		if modo == "festa" and passos >= festa_passo + Dados.FESTA_PASSOS:
			_mostra_fim(true, "")
		if not rodando():
			return
	passos += 1
	_vento()
	_bichos()
	# o vento é só enfeite, mas anda junto com a física
	for p in pecas:
		if p.tipo == "ventilador" and not reduz and _rng.randf() < 0.5:
			var o := p.origem()
			var ang := o.get_rotation()
			var l := (_rng.randf() - 0.5) * 40.0
			ventos.append({ "x": o.origin.x + cos(ang) * 22 - sin(ang) * l, "y": o.origin.y + sin(ang) * 22 + cos(ang) * l, "a": ang, "d": 0.0 })
	for v in ventos:
		v.x += cos(v.a) * 7
		v.y += sin(v.a) * 7
		v.d += 7
	ventos = ventos.filter(func(v: Dictionary) -> bool: return v.d < ALC)
	for b in dinamicos():
		if not b.has_meta("motor"):
			_vel_ant[b.get_instance_id()] = b.linear_velocity


# ============ vai e volta ============
func _zera_rodada() -> void:
	passos = 0
	quieto = 0
	cadeia = {}
	pts = 0
	eventos.clear()
	fixos_tocados = {}
	nao_vale = {}
	caidas = 0
	pedido_ok.clear()
	no_tempo_set = {}
	melhor_seq = 0
	levada_ok = false
	quem_ligou = null
	ultima_peca = null
	radio_ligado = 0
	ventos.clear()
	_contatos_ant = {}
	_vel_ant = {}
	_fila_tecla.clear()
	gravado.clear()
	tocou = {}


func roda() -> void:
	if modo != "edita":
		return
	modo = "roda"
	tentativas += 1
	_zera_rodada()
	for p in pecas:
		p.reseta_estado()
		_cria_corpos(p)
	_cria_laranja()
	cadeia[laranja.get_instance_id()] = true
	laranja.linear_velocity = Vector2(float(fase.vx) * POR_PASSO, 0)
	_vel_ant[laranja.get_instance_id()] = laranja.linear_velocity
	_motores()
	_som().comeca_rodada()
	mudou_pontos.emit(0)
	mudou_pedido.emit()
	mudou_corrente.emit()
	mudou_modo.emit(modo)


func ajeita() -> void:
	_som().para_tudo()
	modo = "edita"
	for p in pecas:
		_tira_corpos(p)
		p.reseta_estado()
	_tira_laranja()
	_corpos.clear()
	_zera_rodada()
	mudou_pontos.emit(0)
	mudou_pedido.emit()
	mudou_corrente.emit()
	mudou_modo.emit(modo)


func do_zero() -> void:
	ajeita()
	pecas.clear()
	zera_estoque()
	mudou_estoque.emit()


func vai_fase(i: int) -> void:
	carrega_fase(i)


# ============ o fim: a conta e o beat ============
func _congela() -> void:
	for c in _corpos:
		if is_instance_valid(c) and c is RigidBody2D:
			var rb := c as RigidBody2D
			rb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			rb.set_deferred("freeze", true)


func _mostra_fim(ok: bool, motivo: String) -> void:
	modo = "fim"
	_congela()
	_som().para_rodada()
	var n := na_corrente()
	var mult := Dados.mult_de(n)
	var prim := ok and tentativas == 1
	var pedido: Array = fase.pedido
	var lev := int(fase.levada)
	var pedido_todo := false
	if ok:
		if pedido.size() > 0:
			pedido_todo = true
			for k in pedido:
				if not (k in pedido_ok):
					pedido_todo = false
		elif lev > 0:
			pedido_todo = levada_ok
	var total := int(roundf(pts * mult * (1.5 if prim else 1.0) * (1.5 if pedido_todo else 1.0)))
	var r := { "ok": ok, "motivo": motivo }
	r.carimbo = "FUNCIONOU!" if ok else "PAROU."
	if ok:
		var q := "laranja"
		var pq: Peca = _peca_de(quem_ligou) if quem_ligou != null and is_instance_valid(quem_ligou) else null
		if pq != null:
			q = pq.tipo
		if q == "gato":
			r.sub = "Quem ligou o rádio foi o gato. Ninguém vai acreditar."
		elif q == "caramelo":
			r.sub = "Quem ligou o som foi o caramelo. Bom garoto."
		elif q == "laranja":
			r.sub = "A laranja chegou e " + str(fase.alvoNome) + " ligou."
		else:
			r.sub = "Ligou, mas quem apertou não foi a laranja."
	else:
		var ate := ("Chegou até: " + str(Dados.TIPOS[ultima_peca.tipo].min) + ".") if ultima_peca != null else "A laranja nem encostou na tralha."
		r.sub = ("Passou do tempo: tem coisa que não para quieta. " if motivo == "demorou" else "A gambiarra parou antes " + str(fase.antes) + ". ") + ate
	r.total = total if ok else pts
	var rec_txt := ""
	if ok and total > recorde:
		rec_txt = ("recorde novo! (era %d)" % recorde) if recorde > 0 else "teu primeiro recorde"
		recorde = total
		Salva.guarda(fase.rec, total)
	elif ok:
		rec_txt = "teu recorde: %d" % recorde
	else:
		rec_txt = "não conta: " + str(fase.alvoNome) + " não ligou"
	r.rec = rec_txt
	# a conta, juntando o que repetiu
	var agrup: Array[Dictionary] = []
	for e in eventos:
		var achou := false
		for g in agrup:
			if g.txt == e.txt:
				g.n += e.n
				g.vezes += 1
				achou = true
				break
		if not achou:
			agrup.append({ "txt": e.txt, "n": e.n, "vezes": 1 })
	var L: Array[Dictionary] = []
	for g in agrup:
		L.append({ "txt": g.txt + (" ×%d" % g.vezes if g.vezes > 1 else ""), "val": str(g.n), "cls": "" })
	if ok:
		if n > 1:
			L.append({ "txt": "Corrente de %d peças" % n, "val": "×" + Dados.virgula(mult), "cls": "mult" })
		if prim:
			L.append({ "txt": "Funcionou de primeira", "val": "×1,50", "cls": "mult" })
		if pedido_todo:
			L.append({ "txt": "Levada completa" if lev > 0 else "Pedido completo", "val": "×1,50", "cls": "mult" })
	var enfeite: Array[String] = []
	for p in pecas:
		if not p.entrou:
			var nm: String = Dados.TIPOS[p.tipo].min
			if not (nm in enfeite):
				enfeite.append(nm)
	if enfeite.size() > 0:
		L.append({ "txt": "Ficou de enfeite: " + ", ".join(enfeite), "val": "", "cls": "nada" })
	if agrup.is_empty():
		L.append({ "txt": "Nenhuma peça entrou na corrente.", "val": "", "cls": "nada" })
	r.conta = L
	var passos_beat := {}
	for g in gravado:
		passos_beat[int(g.passo) % Dados.VOLTA] = true
	r.beat = ok
	r.magro = ok and passos_beat.size() < 7
	r.de_novo = "Mexer de novo" if ok else "Ajeitar"
	r.tem_pedido = pedido.size() > 0 or lev > 0
	r.pedido_tit = "O churrasco pediu" if pedido.size() > 0 else "A banda pediu uma levada de %d" % lev
	r.melhor_seq = melhor_seq
	var prox := fase_i + 1
	r.prox = ("Fase %d: %s →" % [Dados.FASES[prox].n, str(Dados.FASES[prox].lugar).to_lower()]) if ok and prox < Dados.FASES.size() else ""
	resumo = r
	mudou_modo.emit(modo)
	acabou.emit(r)


func padrao_beat() -> Array:
	# a volta de 32 semicolcheias: em cada uma, os instrumentos que tocaram (o mais forte vale)
	var pad: Array = []
	for i in range(Dados.VOLTA):
		pad.append([])
	for g in gravado:
		var cel: Array = pad[int(g.passo) % Dados.VOLTA]
		var ja: Dictionary = {}
		for h in cel:
			if h.inst == g.inst:
				ja = h
		if ja.is_empty():
			cel.append({ "inst": g.inst, "v": g.v })
		else:
			ja.v = maxf(ja.v, g.v)
	return pad


# ============ pros testes ============
func estado() -> Dictionary:
	var q = null
	if quem_ligou != null and is_instance_valid(quem_ligou):
		var pq: Peca = _peca_de(quem_ligou)
		q = pq.tipo if pq != null else "laranja"
	var ev: Array[String] = []
	for e in eventos:
		ev.append("%s %d" % [e.txt, e.n])
	var bat: Array[String] = []
	for g in gravado:
		bat.append("%s@%d" % [g.inst, g.passo])
	var lp := laranja.global_position if laranja != null and is_instance_valid(laranja) else Vector2(fase.ini)
	return { "modo": modo, "pts": pts, "ganhou": quem_ligou != null, "quem": q, "laranja": lp.round(), "corrente": na_corrente(),
		"eventos": ev, "batidas": bat, "passos": passos, "pedido": pedido_ok.duplicate(), "melhor_seq": melhor_seq, "levada_ok": levada_ok }
