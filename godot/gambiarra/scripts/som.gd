extends Node
## O som (autoload "Som"): cada instrumento é sintetizado uma vez quando o jogo abre e vira um
## AudioStreamWAV; as batidas caem na grade do beat (124 BPM) e no fim o alvo toca o beat gravado
## em volta, com o groove de cada fase (baixo, chiado, guitarra) por baixo.

signal pronto
signal mudou_som(ligado: bool)

const VOL_MESTRE := 0.85
const VOZES := 24

var ligado := true
var _banco := {}            # nome → Array de { wav, ganho } (variações do ruído)
var _alterna := {}          # o agogô alterna entre duas notas
var _pendente: Array = []   # o que ainda falta sintetizar: [nome, Callable]
var _pronto := false
var _sint := Sintese.new(7)
var _vozes: Array[AudioStreamPlayer] = []
var _prox_voz := 0
var _fila: Array = []       # batidas agendadas: [tempo_s, nome, força]
var _t0 := 0.0
var _rodando := false
var _prox_tic := 0
var _loop: AudioStreamPlayer = null
var _loop_ini := 0.0
var _loop_tocando := false
var _loop_len := 0.0
var _rodape_web := false


func agora() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ligado = bool(Salva.le("som", true))
	_rodape_web = OS.has_feature("web")
	for i in range(VOZES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_vozes.append(p)
	_loop = AudioStreamPlayer.new()
	add_child(_loop)
	_aplica_volume()
	# a lista do que sintetizar; o groove é sintetizado na hora do fim, a partir destes
	var s := _sint
	var lista := [
		["bumbo", s.bumbo, 2], ["tamborim", s.tamborim, 3], ["caixa", s.caixa, 3], ["surdo", s.surdo, 1],
		["agogo_a", s.agogo.bind(1046.0), 1], ["agogo_b", s.agogo.bind(784.0), 1], ["grave", s.grave, 1], ["cuica", s.cuica, 1],
		["chocalho", s.chocalho, 3], ["miau", s.miau, 1], ["prato", s.prato, 2], ["reco", s.reco, 2], ["latido", s.latido, 2],
		["balde", s.balde, 3], ["udu", s.udu, 2], ["tic_forte", s.tic.bind(true), 1], ["tic", s.tic.bind(false), 1],
		["apito", s.apito, 1], ["liga_radio", s.liga_radio, 1], ["chiado", s.chiado, 3],
		["baixo_55", s.baixo.bind(55.0), 1], ["baixo_49", s.baixo.bind(49.0), 1], ["baixo_73.4", s.baixo.bind(73.4), 1],
		["baixo_110", s.baixo.bind(110.0), 1], ["baixo_98", s.baixo.bind(98.0), 1], ["baixo_146.8", s.baixo.bind(146.8), 1],
		["baixo_82.4", s.baixo.bind(82.4), 1], ["guitarra_164.8", s.guitarra.bind(164.8), 1], ["guitarra_196", s.guitarra.bind(196.0), 1],
	]
	for l in lista:
		for v in range(int(l[2])):
			_pendente.append([l[0], l[1]])
	if DisplayServer.get_name() == "headless" and not ("--som" in OS.get_cmdline_user_args()):
		_pendente.clear()   # os testes sem tela não precisam ouvir nada
		_pronto = true


func _registra(w: AudioStreamWAV) -> AudioStreamWAV:
	# na web o som toca direto pelo navegador (Web Audio): avisa antes, pra a primeira batida não atrasar
	if _rodape_web and w != null and AudioServer.has_method("register_stream_as_sample"):
		AudioServer.call("register_stream_as_sample", w)
	return w


func esta_pronto() -> bool:
	return _pronto


func sintetiza_tudo() -> void:
	while not _pendente.is_empty():
		_um_pendente()


func _um_pendente() -> void:
	var l: Array = _pendente.pop_front()
	var amostras: PackedFloat32Array = (l[1] as Callable).call()
	var pk := Sintese.pico(amostras)
	var ganho := 1.0
	if pk > 0.98:
		ganho = pk / 0.98
		for i in range(amostras.size()):
			amostras[i] /= ganho
	var item := { "amostras": amostras, "ganho": ganho, "wav": _registra(Sintese.pra_wav(amostras)) }
	if not _banco.has(l[0]):
		_banco[l[0]] = []
	(_banco[l[0]] as Array).append(item)
	if _pendente.is_empty():
		_pronto = true
		pronto.emit()


func _process(_dt: float) -> void:
	# sintetiza aos poucos (uns 12 ms por quadro) pra a tela não travar quando o jogo abre
	if not _pendente.is_empty():
		var t := Time.get_ticks_usec()
		while not _pendente.is_empty() and Time.get_ticks_usec() - t < 12000:
			_um_pendente()
	var t_agora := agora()
	# o metrônomo, enquanto a gambiarra roda
	if _rodando:
		while _t0 + _prox_tic * 4.0 * Dados.S16 < t_agora + 0.01:
			_toca("tic_forte" if _prox_tic % 4 == 0 else "tic", 1.0)
			_prox_tic += 1
	# as batidas agendadas
	var i := 0
	while i < _fila.size():
		var e: Array = _fila[i]
		if e[0] <= t_agora + 0.008:
			_toca(e[1], e[2])
			_fila.remove_at(i)
		else:
			i += 1


func _toca(nome: String, forca: float) -> void:
	if not ligado:
		return
	var k := nome
	if nome == "agogo":
		_alterna["agogo"] = not bool(_alterna.get("agogo", false))
		k = "agogo_a" if _alterna["agogo"] else "agogo_b"
	if not _banco.has(k):
		return
	var vs: Array = _banco[k]
	var item: Dictionary = vs[randi() % vs.size()]
	var p := _vozes[_prox_voz]
	_prox_voz = (_prox_voz + 1) % VOZES
	p.stream = item.wav
	var lin := forca * float(item.ganho)
	p.volume_db = linear_to_db(maxf(lin, 0.0001))
	p.play()


# ---------- a rodada ----------
func comeca_rodada() -> void:
	_fila.clear()
	_t0 = agora() + 0.06
	_prox_tic = 0
	_rodando = true
	_fila.append([_t0, "apito", 1.0])
	para_loop()


func para_rodada() -> void:
	_rodando = false


func para_tudo() -> void:
	_rodando = false
	_fila.clear()
	para_loop()


func agenda(inst: String, v: float, passo16: int) -> void:
	var t := maxf(agora() + 0.004, _t0 + passo16 * Dados.S16)
	_fila.append([t, inst, v])


func liga_radio() -> void:
	_fila.append([agora() + 0.02, "liga_radio", 1.0])


func toca_agora(nome: String, v := 1.0) -> void:
	_toca(nome, v)


# ---------- o beat em volta, no fim ----------
func _amostras(nome: String) -> Dictionary:
	var vs: Array = _banco.get(nome, [])
	if vs.is_empty():
		return {}
	return vs[randi() % vs.size()]


func _poe(buf: PackedFloat32Array, nome: String, t: float, forca: float, circular: bool, ofs: int, tam: int) -> void:
	var it := _amostras(nome)
	if it.is_empty():
		return
	var src: PackedFloat32Array = it.amostras
	var g: float = forca * float(it.ganho)
	var i0 := int(roundf(t * Sintese.TAXA))
	var n := src.size()
	if not circular:
		Sintese.soma(buf, src, ofs + i0, g)
		return
	# no pedaço que repete, o rabo do som volta pro começo (é o rabo da volta de antes)
	var j := 0
	while j < n:
		var pos := (i0 + j) % tam
		var quanto := mini(n - j, tam - pos)
		for k in range(quanto):
			buf[ofs + pos + k] += src[j + k] * g
		j += quanto


func _groove(fase_i: int, k: int) -> Array:
	# o que o rádio põe por baixo do teu beat em cada semicolcheia: [nome, força]
	var out: Array = []
	var b := k % 16
	match fase_i:
		0:
			if b in [0, 3, 6, 8, 11, 14]:
				out.append(["baixo_55" if k < 16 else "baixo_49", 1.0])
			if b % 2 == 0:
				out.append(["chiado", 0.06 if b % 4 == 0 else 0.035])
		1:
			# pagode de laje: o baixo responde e o pandeiro chia nas semicolcheias
			var n1 := { 0: "73.4", 6: "110", 8: "73.4", 12: "98", 14: "110" }
			var n2 := { 0: "98", 6: "146.8", 8: "98", 12: "110", 14: "73.4" }
			var nn: Dictionary = n1 if k < 16 else n2
			if nn.has(b):
				out.append(["baixo_" + str(nn[b]), 1.0])
			out.append(["chiado", 0.07 if b % 4 == 3 else (0.02 if b % 2 == 1 else 0.035)])
		2:
			# rock de garagem: baixo nas colcheias e a guitarra suja respondendo
			var raiz := "82.4" if k < 16 else "98"
			if b % 2 == 0:
				out.append(["baixo_" + raiz, 1.0])
			if b in [0, 3, 6, 10]:
				out.append(["guitarra_" + ("164.8" if k < 16 else "196"), 1.0])
			if b % 4 == 2:
				out.append(["chiado", 0.05])
	return out


func monta_loop(padrao: Array, fase_i: int) -> AudioStreamWAV:
	# duas voltas: a primeira com o rádio abrindo o som, a segunda é a que repete pra sempre
	var tam := int(roundf(Dados.VOLTA * Dados.S16 * Sintese.TAXA))
	var buf := Sintese.zeros(tam * 2)
	for volta in range(2):
		var circular := volta == 1
		var ofs := tam * volta
		for k in range(Dados.VOLTA):
			var t := k * Dados.S16
			for h in padrao[k]:
				_poe(buf, h.inst if h.inst != "agogo" else ("agogo_a" if k % 2 == 0 else "agogo_b"), t, float(h.v) * 0.9, circular, ofs, tam)
			for g in _groove(fase_i, k):
				_poe(buf, g[0], t, g[1], circular, ofs, tam)
	Sintese.filtra_radio(buf, tam)
	var pk := Sintese.pico(buf)
	if pk > 0.98:
		var g := 0.98 / pk
		for i in range(buf.size()):
			buf[i] *= g
	return Sintese.pra_wav(buf, tam, tam * 2)


func toca_loop(padrao: Array, fase_i: int) -> void:
	para_loop()
	if not _pronto:
		sintetiza_tudo()
	var velho := _loop.stream
	_loop.stream = _registra(monta_loop(padrao, fase_i))
	if velho != null and _rodape_web and AudioServer.has_method("unregister_stream_as_sample"):
		AudioServer.call("unregister_stream_as_sample", velho)
	_loop_len = Dados.VOLTA * Dados.S16
	_loop.volume_db = 0.0
	if ligado:
		_loop.play()
	_loop_ini = agora()
	_loop_tocando = true


func para_loop() -> void:
	_loop_tocando = false
	if _loop != null:
		_loop.stop()


func loop_tocando() -> bool:
	return _loop_tocando


func coluna_loop() -> int:
	if not _loop_tocando:
		return -1
	return int(floorf((agora() - _loop_ini) / Dados.S16)) % Dados.VOLTA


# ---------- liga e desliga ----------
func alterna() -> void:
	ligado = not ligado
	Salva.guarda("som", ligado)
	_aplica_volume()
	if not ligado:
		_loop.stop()
	elif _loop_tocando:
		_loop.play()
		_loop_ini = agora()
	mudou_som.emit(ligado)


func _aplica_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(VOL_MESTRE) if ligado else -80.0)
	AudioServer.set_bus_mute(bus, not ligado)
