class_name Som
extends Node
## O som, todo sintetizado (nenhum arquivo de áudio): cada som da versão web é "tocado" uma vez no começo
## (osciladores, ruído, envelopes e filtros, as mesmas receitas do WebAudio) e guardado num AudioStreamWAV.
## Depois é só tocar, numa roda de 8 tocadores. O ronco do rolimã e o risco do giz são laços de ruído
## que mudam de tom e de volume com a velocidade.
## Pra não travar a abertura, os sons são preparados um por quadro.

const TAXA := 22050
const ORDEM := ["clique", "pulo", "vai", "erro", "pouso", "capotou", "latido", "chegada", "mola", "turbo",
	"cambalhota1", "cambalhota2", "cambalhota3", "carimbo", "apaga", "desfaz", "copia", "recorde"]

var ligado := true
var sons := {}             # nome -> AudioStreamWAV
var _fila: Array = []
var _roda: Array = []
var _vez := 0
var _ruido := PackedFloat32Array()
var ronco: AudioStreamPlayer
var zumbido: AudioStreamPlayer
var risco: AudioStreamPlayer
var _alvo := {"rv": 0.0, "rp": 1.0, "zv": 0.0, "zp": 1.0, "gv": 0.0}
var _atual := {"rv": 0.0, "rp": 1.0, "zv": 0.0, "zp": 1.0, "gv": 0.0}
var tocados: Array = []    # os últimos sons pedidos (pros testes)


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 777
	_ruido.resize(TAXA * 2)
	for i in _ruido.size():
		_ruido[i] = r.randf() * 2.0 - 1.0
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_roda.append(p)
	_fila = ORDEM.duplicate()
	ronco = _laco(_faz_ronco())
	zumbido = _laco(_faz_zumbido())
	risco = _laco(_faz_risco())


func _laco(w: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.volume_linear = 0.0
	add_child(p)
	return p


## Prepara um pedaço da fila (chamado a cada quadro: uns 4 ms de conta, uma voz por vez; false quando acabou).
func prepara_um() -> bool:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 4000:
		if _job == null:
			if _fila.is_empty():
				return false
			var r := _receita(_fila.pop_front())
			var buf := PackedFloat32Array()
			buf.resize(int(float(r["dur"]) * TAXA))
			_job = {"k": r["k"], "vozes": r["vozes"], "buf": buf, "i": 0}
		var J: Dictionary = _job
		if J["i"] < J["vozes"].size():
			_voz(J["buf"], J["vozes"][J["i"]])
			J["i"] += 1
		else:
			sons[J["k"]] = _wav(J["buf"], true)
			_job = null
	return true


func prepara_tudo() -> void:
	while prepara_um():
		pass


func liga(on: bool) -> void:
	ligado = on
	if not on:
		for p in [ronco, zumbido, risco]:
			p.volume_linear = 0.0


func toca(k: String, v := 0.0) -> void:
	tocados.append(k)
	if tocados.size() > 60:
		tocados.pop_front()
	if not ligado:
		return
	var nome := k
	var vol := 1.0
	if k == "pouso":
		vol = clampf(v / 600.0, 0.18, 1.0)
	elif k == "cambalhota":
		nome = "cambalhota" + str(clampi(int(v), 1, 3))
	if not sons.has(nome):
		if _fila.has(nome) or (_job != null and _job["k"] == nome):
			_fila.erase(nome)
			if _job != null and _job["k"] == nome:
				_job = null
			sons[nome] = _faz(nome)
		else:
			return
	var p: AudioStreamPlayer = _roda[_vez]
	_vez = (_vez + 1) % _roda.size()
	p.stream = sons[nome]
	p.volume_linear = vol
	p.play()


## O ronco do rolimã e o risco do giz, a cada quadro (a mesma conta do atualizaRonco da web).
func atualiza(vel: float, no_chao: bool, giz: float, dt: float) -> void:
	var s := clampf(vel / Nucleo.VMAX, 0.0, 1.0)
	var anda := no_chao and vel > 6.0
	_alvo["rv"] = (0.05 + s * 0.2) * 0.9 * 2.2 if anda else 0.0
	_alvo["rp"] = (240.0 + s * 1250.0) / 500.0
	_alvo["zv"] = s * 0.09 * 0.9 * 2.2 if anda else 0.0
	_alvo["zp"] = (46.0 + s * 80.0) / 55.125
	_alvo["gv"] = clampf(giz, 0.0, 1.0) * 0.16 * 0.9 * 2.0
	var tc := {"rv": 0.05 if anda else 0.03, "rp": 0.06, "zv": 0.06, "zp": 0.06, "gv": 0.03}
	for k in _atual:
		_atual[k] += (_alvo[k] - _atual[k]) * (1.0 - exp(-dt / tc[k]))
	_aplica(ronco, _atual["rv"], _atual["rp"])
	_aplica(zumbido, _atual["zv"], _atual["zp"])
	_aplica(risco, _atual["gv"], 1.0)


func _aplica(p: AudioStreamPlayer, vol: float, tom: float) -> void:
	if not ligado:
		vol = 0.0
	p.pitch_scale = clampf(tom, 0.05, 8.0)
	p.volume_linear = vol
	if vol > 0.002 and not p.playing:
		p.play()
	elif vol <= 0.002 and p.playing:
		p.stop()


# ---------------------------------------------------------------- o sintetizador
## Uma voz: oscilador (ou ruído) com o tom, o envelope e o filtro como no WebAudio.
class Voz:
	var tipo := "sine"        # sine, square, sawtooth, triangle, ruido
	var t := 0.0              # quando começa
	var fim := 0.0            # quando para
	var tom: Array = []       # [[t, f, exp?], ...] (o primeiro é o setValueAtTime)
	var env: Array = []       # [t, a, v, d]
	var filtro := ""          # lowpass, bandpass, highpass, peaking, "" sem
	var f_freq: Array = []    # [[t, f, exp?], ...]
	var f_q := 1.0
	var f_ganho := 0.0
	var lfo := Vector2.ZERO   # frequência, profundidade (Hz) no tom
	var vol := 1.0
	var ofs := 0


## Uma automação do WebAudio (setValueAtTime e exponentialRampToValueAtTime) em pedaços de amostras:
## [[amostra onde começa, valor, multiplicador por amostra], ...]. Assim cada amostra é uma multiplicação.
static func _curva(ev: Array, sr: float) -> Array:
	var segs: Array = []
	for k in range(1, ev.size()):
		var ia := int(float(ev[k - 1][0]) * sr)
		var ib := int(float(ev[k][0]) * sr)
		var n := maxi(1, ib - ia)
		var v0: float = ev[k - 1][1]
		var v1: float = ev[k][1]
		segs.append([ia, v0, pow(v1 / v0, 1.0 / n)])
	var ult: Array = ev[ev.size() - 1]
	segs.append([int(float(ult[0]) * sr), float(ult[1]), 1.0])
	return segs


static func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	elif t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


const _TIPOS := {"sine": 0, "square": 1, "sawtooth": 2, "triangle": 3, "ruido": 4}
const _FILTROS := {"": 0, "lowpass": 1, "highpass": 2, "bandpass": 3, "peaking": 4}


## Toca uma voz dentro do buffer (somando).
func _voz(buf: PackedFloat32Array, v: Voz) -> void:
	var sr := float(TAXA)
	var i0 := maxi(0, int(v.t * sr))
	var i1 := mini(buf.size(), int(v.fim * sr))
	if i1 <= i0:
		return
	var tipo: int = _TIPOS[v.tipo]
	var filtro: int = _FILTROS[v.filtro]
	var e: Array = v.env
	var ea := maxf(0.0002, float(e[2]))
	var env := _curva([[e[0], 0.0001], [float(e[0]) + float(e[1]), ea], [float(e[0]) + float(e[1]) + float(e[3]), 0.0001]], sr)
	var tom := _curva(v.tom, sr) if tipo != 4 else [[i0, 0.0, 1.0]]
	var ff := _curva(v.f_freq, sr) if filtro != 0 else [[i0, 0.0, 1.0]]
	# os ponteiros de cada curva
	var ei := 0
	var ev_: float = env[0][1]
	var er: float = env[0][2]
	var en: int = env[1][0] if env.size() > 1 else 1 << 40
	var ti := 0
	var tv: float = tom[0][1]
	var tr: float = tom[0][2]
	var tn: int = tom[1][0] if tom.size() > 1 else 1 << 40
	var fi := 0
	var fv: float = ff[0][1]
	var fr: float = ff[0][2]
	var fn: int = ff[1][0] if ff.size() > 1 else 1 << 40
	var fase := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var ri := v.ofs
	var nr := _ruido.size()
	var lfo := v.lfo.x > 0.0
	var vol := v.vol
	for i in range(i0, i1):
		while i >= en:
			ei += 1
			ev_ = env[ei][1]; er = env[ei][2]
			en = env[ei + 1][0] if ei + 1 < env.size() else 1 << 40
		while i >= tn:
			ti += 1
			tv = tom[ti][1]; tr = tom[ti][2]
			tn = tom[ti + 1][0] if ti + 1 < tom.size() else 1 << 40
		var s := 0.0
		if tipo == 4:
			s = _ruido[ri % nr]
			ri += 1
		else:
			var f := tv
			if lfo:
				f += sin(TAU * v.lfo.x * (float(i) / sr - v.t)) * v.lfo.y
			var dt := clampf(f / sr, 0.0, 0.49)
			fase += dt
			if fase >= 1.0:
				fase -= 1.0
			if tipo == 0:
				s = sin(TAU * fase)
			elif tipo == 1:
				s = (1.0 if fase < 0.5 else -1.0) + _blep(fase, dt) - _blep(fmod(fase + 0.5, 1.0), dt)
			elif tipo == 2:
				s = 2.0 * fase - 1.0 - _blep(fase, dt)
			else:
				s = 4.0 * absf(fase - 0.5) - 1.0
		if filtro != 0:
			if (i - i0) % 16 == 0:
				while i >= fn:
					fi += 1
					fv = ff[fi][1]; fr = ff[fi][2]
					fn = ff[fi + 1][0] if fi + 1 < ff.size() else 1 << 40
				var fc := clampf(fv, 20.0, sr * 0.45)
				var w0 := TAU * fc / sr
				var cw := cos(w0)
				var sw := sin(w0)
				var aa0 := 1.0
				if filtro == 1:
					var al := sw / (2.0 * pow(10.0, v.f_q / 20.0))
					b0 = (1.0 - cw) / 2.0; b1 = 1.0 - cw; b2 = (1.0 - cw) / 2.0
					aa0 = 1.0 + al; a1 = -2.0 * cw; a2 = 1.0 - al
				elif filtro == 2:
					var al := sw / (2.0 * pow(10.0, v.f_q / 20.0))
					b0 = (1.0 + cw) / 2.0; b1 = -(1.0 + cw); b2 = (1.0 + cw) / 2.0
					aa0 = 1.0 + al; a1 = -2.0 * cw; a2 = 1.0 - al
				elif filtro == 3:
					var al := sw / (2.0 * maxf(0.0001, v.f_q))
					b0 = al; b1 = 0.0; b2 = -al
					aa0 = 1.0 + al; a1 = -2.0 * cw; a2 = 1.0 - al
				else:
					var A := pow(10.0, v.f_ganho / 40.0)
					var al := sw / (2.0 * maxf(0.0001, v.f_q))
					b0 = 1.0 + al * A; b1 = -2.0 * cw; b2 = 1.0 - al * A
					aa0 = 1.0 + al / A; a1 = -2.0 * cw; a2 = 1.0 - al / A
				b0 /= aa0; b1 /= aa0; b2 /= aa0; a1 /= aa0; a2 /= aa0
			var y := b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1; x1 = s; y2 = y1; y1 = y
			s = y
			fv *= fr
		buf[i] += s * ev_ * vol
		ev_ *= er
		tv *= tr


var _job = null


func _render(dur: float, vozes: Array) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * TAXA))
	for v in vozes:
		_voz(buf, v)
	return _wav(buf, true)


## O mestre: ganho 0,9 e um compressor simples (o DynamicsCompressor da web), com um limite no fim.
func _wav(buf: PackedFloat32Array, comprime: bool, laco := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	var env := 0.0
	var lim := 0.158
	var ataque := 1.0 - exp(-1.0 / (0.003 * TAXA))
	var solta := 1.0 - exp(-1.0 / (0.25 * TAXA))
	for i in buf.size():
		var x := buf[i] * 0.9
		if comprime:
			var a := absf(x)
			env += (a - env) * (ataque if a > env else solta)
			if env > lim:
				x *= pow(env / lim, 1.0 / 5.0 - 1.0)
			x *= 2.6
		x = clampf(x, -0.98, 0.98)
		bytes.encode_s16(i * 2, int(x * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = bytes
	if laco:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _osc(tipo: String, f: float, t: float, dur: float, env: Array) -> Voz:
	var v := Voz.new()
	v.tipo = tipo
	v.t = t
	v.fim = t + dur + 0.05
	v.tom = [[t, f]]
	v.env = env
	return v


func _ruid(t: float, dur: float, env: Array) -> Voz:
	var v := Voz.new()
	v.tipo = "ruido"
	v.t = t
	v.fim = t + dur + 0.05
	v.env = env
	v.ofs = randi() % 33075
	return v


func _filt(v: Voz, tipo: String, f: float, q: float) -> Voz:
	v.filtro = tipo
	v.f_freq = [[v.t, f]]
	v.f_q = q
	return v


func _faz(k: String) -> AudioStreamWAV:
	var r := _receita(k)
	return _render(r["dur"], r["vozes"])


## As receitas, iguais às do SFX da web.
func _receita(k: String) -> Dictionary:
	var V: Array = []
	var dur := 1.0
	match k:
		"pulo":
			var a := _filt(_osc("square", 200, 0, 0.2, [0, 0.004, 0.22, 0.15]), "lowpass", 1700, 1)
			a.tom.append([0.11, 600.0])
			V.append(a)
			V.append(_filt(_ruid(0, 0.12, [0, 0.003, 0.12, 0.1]), "bandpass", 2600, 1))
			dur = 0.35
		"pouso":
			var a := _osc("sine", 125, 0, 0.2, [0, 0.003, 0.32, 0.17])
			a.tom.append([0.15, 46.0])
			V.append(a)
			V.append(_filt(_ruid(0, 0.13, [0, 0.002, 0.16, 0.11]), "lowpass", 950, 0.8))
			for i in 3:
				var t := 0.025 + i * 0.03
				V.append(_osc("triangle", 2300.0 + randf() * 1900.0, t, 0.05, [t, 0.001, 0.045, 0.04]))
			dur = 0.4
		"mola":
			var a := _osc("sine", 150, 0, 0.55, [0, 0.004, 0.3, 0.5])
			a.tom.append([0.15, 560.0])
			a.tom.append([0.5, 290.0])
			a.lfo = Vector2(17, 45)
			V.append(a)
			var b := _osc("triangle", 330, 0, 0.35, [0, 0.003, 0.1, 0.3])
			b.tom.append([0.2, 1150.0])
			V.append(b)
			dur = 0.65
		"turbo":
			var a := _filt(_osc("sawtooth", 110, 0, 0.5, [0, 0.02, 0.2, 0.45]), "lowpass", 1700, 3)
			a.tom.append([0.4, 460.0])
			V.append(a)
			var b := _filt(_ruid(0, 0.5, [0, 0.05, 0.2, 0.4]), "bandpass", 800, 1.2)
			b.f_freq.append([0.4, 5200.0])
			V.append(b)
			dur = 0.6
		"latido":
			for i in 2:
				var t: float = [0.0, 0.19][i]
				var a := _filt(_osc("sawtooth", 470.0 - i * 35.0, t, 0.14, [t, 0.006, 0.3, 0.11]), "bandpass", 1150.0 + i * 130.0, 2.2)
				a.tom.append([t + 0.12, 250.0])
				V.append(a)
				V.append(_filt(_ruid(t, 0.07, [t, 0.002, 0.13, 0.06]), "bandpass", 1700, 1.4))
			dur = 0.45
		"capotou":
			var a := _filt(_ruid(0, 0.55, [0, 0.004, 0.5, 0.5]), "lowpass", 1700, 0.9)
			a.f_freq.append([0.5, 220.0])
			V.append(a)
			var b := _osc("sine", 112, 0, 0.35, [0, 0.003, 0.42, 0.3])
			b.tom.append([0.3, 38.0])
			V.append(b)
			var frs := [523.0, 1187.0, 1712.0, 2390.0]
			for i in 4:
				V.append(_osc("sine", frs[i], 0.07, 0.65, [0.07, 0.002, 0.16 / (i + 1), 0.55 - i * 0.09]))
			dur = 0.8
		"chegada":
			var notas := [523.0, 659.0, 784.0, 1047.0]
			for i in 4:
				var fim := i == 3
				var d := 0.8 if fim else 0.16
				var t := i * 0.09
				V.append(_filt(_osc("square", notas[i], t, d + 0.05, [t, 0.006, 0.17, d]), "lowpass", 2600, 1))
				V.append(_filt(_osc("sawtooth", notas[i] / 2.0, t, d + 0.05, [t, 0.006, 0.09, d]), "lowpass", 1300, 1))
			for f in [659.0, 784.0, 1047.0]:
				V.append(_osc("triangle", f, 0.36, 1, [0.36, 0.02, 0.07, 0.9]))
			V.append(_filt(_ruid(0.3, 1.5, [0.3, 0.25, 0.05, 1.2]), "bandpass", 1400, 0.5))
			dur = 1.9
		"cambalhota1", "cambalhota2", "cambalhota3":
			var n := int(k.substr(10))
			for i in 3 + n:
				var t := i * 0.055
				V.append(_osc("triangle", 880.0 * pow(1.26, i), t, 0.26, [t, 0.003, 0.12, 0.22]))
			dur = 0.35 + (3 + n) * 0.055
		"clique":
			V.append(_filt(_osc("square", 1500, 0, 0.05, [0, 0.001, 0.08, 0.04]), "bandpass", 1900, 3))
			dur = 0.12
		"carimbo":
			var a := _osc("sine", 150, 0, 0.16, [0, 0.002, 0.32, 0.14])
			a.tom.append([0.12, 60.0])
			V.append(a)
			V.append(_filt(_ruid(0, 0.06, [0, 0.001, 0.11, 0.05]), "lowpass", 2100, 1))
			dur = 0.25
		"apaga":
			V.append(_filt(_ruid(0, 0.22, [0, 0.02, 0.1, 0.18]), "bandpass", 950, 0.7))
			dur = 0.3
		"desfaz":
			var a := _osc("triangle", 720, 0, 0.16, [0, 0.004, 0.11, 0.14])
			a.tom.append([0.12, 340.0])
			V.append(a)
			dur = 0.25
		"copia":
			var fs := [784.0, 1175.0, 1568.0]
			for i in 3:
				var t := i * 0.07
				V.append(_osc("triangle", fs[i], t, 0.22, [t, 0.004, 0.12, 0.2]))
			dur = 0.5
		"vai":
			V.append(_filt(_osc("square", 988, 0, 0.26, [0, 0.004, 0.16, 0.22]), "lowpass", 2400, 1))
			dur = 0.32
		"erro":
			V.append(_filt(_osc("square", 140, 0, 0.24, [0, 0.004, 0.14, 0.2]), "lowpass", 900, 1))
			dur = 0.3
		"recorde":
			var fs := [1047.0, 1319.0, 1568.0, 2093.0]
			for i in 4:
				var t := 0.5 + i * 0.07
				V.append(_osc("triangle", fs[i], t, 0.32, [t, 0.004, 0.1, 0.3]))
			dur = 1.1
	return {"k": k, "dur": dur, "vozes": V}


## O ronco: ruído num passa-banda (500 Hz) com as bolinhas batendo (o quadrado de 16 Hz no volume).
func _faz_ronco() -> AudioStreamWAV:
	var n := int(1.5 * TAXA)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var v := _filt(_ruid(0, 1.5, [0, 0, 1, 1]), "bandpass", 500, 1.3)
	var w0 := TAU * 500.0 / TAXA
	var al := sin(w0) / 2.6
	var aa0 := 1.0 + al
	var b0 := al / aa0
	var b2 := -al / aa0
	var a1 := -2.0 * cos(w0) / aa0
	var a2 := (1.0 - al) / aa0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var s := _ruido[(i + v.ofs) % _ruido.size()]
		var y := b0 * s + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = s; y2 = y1; y1 = y
		var am := 0.65 + (0.35 if fmod(float(i) * 16.0 / TAXA, 1.0) < 0.5 else -0.35)
		buf[i] = y * am * 2.2
	return _wav(buf, false, true)


## O grave do rolimã: um triângulo de 55 Hz, um período certinho pra fazer o laço.
func _faz_zumbido() -> AudioStreamWAV:
	var n := 400
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var f := float(i) / n
		buf[i] = (4.0 * f - 1.0) if f < 0.5 else (3.0 - 4.0 * f)
	return _wav(buf, false, true)


## O giz riscando o asfalto: ruído agudo (passa-alta 1300 Hz e um pico em 3400 Hz).
func _faz_risco() -> AudioStreamWAV:
	var v := _filt(_ruid(0, 1.0, [0, 0, 1, 1]), "highpass", 1300, 0)
	var w := _render_cru(1.0, [v])
	var v2 := Voz.new()
	return _picos(w, v2)


func _render_cru(dur: float, vozes: Array) -> PackedFloat32Array:
	var n := int(dur * TAXA)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for v: Voz in vozes:
		var w0 := TAU * 1300.0 / TAXA
		var al := sin(w0) / 2.0
		var cw := cos(w0)
		var aa0 := 1.0 + al
		var b0 := (1.0 + cw) / 2.0 / aa0
		var b1 := -(1.0 + cw) / aa0
		var b2 := (1.0 + cw) / 2.0 / aa0
		var a1 := -2.0 * cw / aa0
		var a2 := (1.0 - al) / aa0
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i in n:
			var s := _ruido[(i + v.ofs) % _ruido.size()]
			var y := b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1; x1 = s; y2 = y1; y1 = y
			buf[i] = y
	return buf


func _picos(buf: PackedFloat32Array, _v: Voz) -> AudioStreamWAV:
	# o pico de 3400 Hz (+9 dB) por cima do passa-alta
	var w0 := TAU * 3400.0 / TAXA
	var A := pow(10.0, 9.0 / 40.0)
	var al := sin(w0) / 2.0
	var cw := cos(w0)
	var aa0 := 1.0 + al / A
	var b0 := (1.0 + al * A) / aa0
	var b1 := -2.0 * cw / aa0
	var b2 := (1.0 - al * A) / aa0
	var a1 := -2.0 * cw / aa0
	var a2 := (1.0 - al / A) / aa0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in buf.size():
		var s := buf[i]
		var y := b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = s; y2 = y1; y1 = y
		buf[i] = y * 0.5
	return _wav(buf, false, true)
