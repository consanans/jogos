class_name Sintese
extends RefCounted
## A síntese dos instrumentos: as receitas do WebAudio da versão web (osciladores, envelopes,
## ruído filtrado) feitas amostra por amostra numa vez só, quando o jogo abre.
## Cada receita devolve um PackedFloat32Array (mono, TAXA amostras por segundo) tocado com força 1.

const TAXA := 44100

var _rng := RandomNumberGenerator.new()


func _init(semente := 1) -> void:
	_rng.seed = semente


# ---------- curvas de automação (setValueAtTime, exponentialRamp, linearRamp) ----------
# eventos: [[tipo, valor, tempo]] com tipo "set", "exp" ou "lin", na ordem do tempo
static func curva(eventos: Array, n: int, inicial := 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var v := inicial
	var i := 0
	var t_ant := 0.0
	for e in eventos:
		var tipo: String = e[0]
		var alvo: float = e[1]
		var fim := mini(n, int(roundf(float(e[2]) * TAXA)))
		if tipo == "set":
			while i < fim:
				out[i] = v
				i += 1
			v = alvo
		else:
			var ini := i
			var len := maxi(1, fim - ini)
			if tipo == "exp":
				var r := pow(maxf(alvo, 1e-6) / maxf(v, 1e-6), 1.0 / len)
				var x := v
				while i < fim:
					out[i] = x
					x *= r
					i += 1
			else:
				var passo := (alvo - v) / len
				var x := v
				while i < fim:
					out[i] = x
					x += passo
					i += 1
			v = alvo
		t_ant = float(e[2])
	while i < n:
		out[i] = v
		i += 1
	return out


static func env(n: int, t: float, a: float, v: float, d: float) -> PackedFloat32Array:
	# o env() da web: sobe exponencial de quase zero até v em a, e desce até quase zero em d
	return curva([["set", 0.0001, t], ["exp", maxf(0.0002, v), t + a], ["exp", 0.0001, t + a + d]], n, 0.0)


static func n_de(seg: float) -> int:
	return int(ceil(seg * TAXA))


# ---------- fontes ----------
static func onda(tipo: String, freq: PackedFloat32Array, t0: float, dur: float, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var i0 := int(t0 * TAXA)
	var i1 := mini(n, int((t0 + dur) * TAXA))
	var fase := 0.0
	var inv := 1.0 / TAXA
	match tipo:
		"sine":
			for i in range(i0, i1):
				out[i] = sin(TAU * fase)
				fase += freq[i] * inv
				fase -= floorf(fase)
		"triangle":
			for i in range(i0, i1):
				out[i] = 1.0 - 4.0 * absf(fase - 0.5)
				fase += freq[i] * inv
				fase -= floorf(fase)
		"sawtooth":
			# dente de serra com polyBLEP (menos chiado de aliasing)
			for i in range(i0, i1):
				var dt := freq[i] * inv
				var s := 2.0 * fase - 1.0
				if fase < dt:
					var x := fase / dt
					s -= x + x - x * x - 1.0
				elif fase > 1.0 - dt:
					var x := (fase - 1.0) / dt
					s -= x * x + x + x + 1.0
				out[i] = s
				fase += dt
				fase -= floorf(fase)
		"square":
			for i in range(i0, i1):
				out[i] = 1.0 if fase < 0.5 else -1.0
				fase += freq[i] * inv
				fase -= floorf(fase)
	return out


func ruido(t0: float, dur: float, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var i0 := int(t0 * TAXA)
	var i1 := mini(n, int((t0 + dur) * TAXA))
	for i in range(i0, i1):
		out[i] = _rng.randf() * 2.0 - 1.0
	return out


# ---------- filtro biquad do WebAudio (lowpass/highpass com Q em dB, bandpass com Q linear) ----------
static func filtra(x: PackedFloat32Array, tipo: String, freq: PackedFloat32Array, q: float) -> PackedFloat32Array:
	var n := x.size()
	var y := PackedFloat32Array()
	y.resize(n)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var i := 0
	while i < n:
		# recalcula os coeficientes a cada 16 amostras (a frequência pode estar andando)
		var w0 := TAU * clampf(freq[i], 10.0, TAXA * 0.49) / TAXA
		var cw := cos(w0)
		var sw := sin(w0)
		var al := 0.0
		var a0 := 1.0
		if tipo == "bandpass":
			al = sw / (2.0 * q)
			a0 = 1.0 + al
			b0 = al / a0
			b1 = 0.0
			b2 = -al / a0
		else:
			al = sw / (2.0 * pow(10.0, q / 20.0))
			a0 = 1.0 + al
			if tipo == "lowpass":
				b0 = (1.0 - cw) / 2.0 / a0
				b1 = (1.0 - cw) / a0
				b2 = b0
			else:
				b0 = (1.0 + cw) / 2.0 / a0
				b1 = -(1.0 + cw) / a0
				b2 = b0
		a1 = -2.0 * cw / a0
		a2 = (1.0 - al) / a0
		var fim := mini(n, i + 16)
		while i < fim:
			var xi := x[i]
			var yi := b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = xi
			y2 = y1
			y1 = yi
			y[i] = yi
			i += 1
	return y


static func const_(v: float, n: int) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	c.resize(n)
	c.fill(v)
	return c


static func mult(x: PackedFloat32Array, g: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := x.size()
	out.resize(n)
	for i in range(n):
		out[i] = x[i] * g[i]
	return out


static func soma(dst: PackedFloat32Array, src: PackedFloat32Array, ofs := 0, g := 1.0) -> void:
	var n := mini(src.size(), dst.size() - ofs)
	for i in range(n):
		dst[ofs + i] += src[i] * g


static func zeros(n: int) -> PackedFloat32Array:
	var z := PackedFloat32Array()
	z.resize(n)
	return z


# ---------- os instrumentos (força 1) ----------
func bumbo() -> PackedFloat32Array:
	var n := n_de(0.46)
	var out := mult(onda("sine", curva([["set", 135.0, 0.0], ["exp", 42.0, 0.13]], n), 0.0, 0.45, n), env(n, 0.0, 0.003, 0.95, 0.3))
	soma(out, mult(filtra(ruido(0.0, 0.1, n), "lowpass", const_(1400, n), 0.7), env(n, 0.0, 0.001, 0.22, 0.03)))
	return out


func surdo() -> PackedFloat32Array:
	var n := n_de(0.86)
	var out := mult(onda("sine", curva([["set", 84.0, 0.0], ["exp", 55.0, 0.3]], n), 0.0, 0.85, n), env(n, 0.0, 0.004, 0.85, 0.7))
	soma(out, mult(onda("triangle", const_(523, n), 0.0, 0.5, n), env(n, 0.0, 0.002, 0.12, 0.4)))
	soma(out, mult(onda("sine", const_(1347, n), 0.0, 0.4, n), env(n, 0.0, 0.001, 0.06, 0.3)))
	return out


func caixa() -> PackedFloat32Array:
	var n := n_de(0.26)
	var out := mult(filtra(ruido(0.0, 0.25, n), "bandpass", const_(2100, n), 0.8), env(n, 0.0, 0.002, 0.6, 0.17))
	soma(out, mult(onda("triangle", curva([["set", 215.0, 0.0], ["exp", 150.0, 0.08]], n), 0.0, 0.15, n), env(n, 0.0, 0.002, 0.35, 0.08)))
	return out


func tamborim() -> PackedFloat32Array:
	var n := n_de(0.16)
	var out := mult(onda("sine", curva([["set", 920.0, 0.0], ["exp", 640.0, 0.06]], n), 0.0, 0.15, n), env(n, 0.0, 0.001, 0.5, 0.07))
	soma(out, mult(filtra(ruido(0.0, 0.09, n), "highpass", const_(3200, n), 0.7), env(n, 0.0, 0.001, 0.25, 0.025)))
	return out


func agogo(f: float) -> PackedFloat32Array:
	var n := n_de(0.51)
	var out := mult(onda("sine", const_(f, n), 0.0, 0.5, n), env(n, 0.0, 0.002, 0.3, 0.38))
	soma(out, mult(onda("sine", const_(f * 2.76, n), 0.0, 0.3, n), env(n, 0.0, 0.002, 0.12, 0.18)))
	return out


func grave() -> PackedFloat32Array:
	var n := n_de(0.71)
	var out := mult(onda("sine", curva([["set", 140.0, 0.0], ["exp", 46.0, 0.38]], n), 0.0, 0.7, n), env(n, 0.0, 0.004, 0.9, 0.55))
	soma(out, mult(onda("triangle", curva([["set", 320.0, 0.0], ["exp", 760.0, 0.2]], n), 0.0, 0.35, n), env(n, 0.0, 0.004, 0.16, 0.22)))
	return out


func cuica() -> PackedFloat32Array:
	var n := n_de(0.42)
	var s := onda("sawtooth", curva([["set", 300.0, 0.0], ["lin", 780.0, 0.11], ["lin", 420.0, 0.3]], n), 0.0, 0.41, n)
	var f := filtra(s, "bandpass", curva([["set", 700.0, 0.0], ["lin", 1500.0, 0.11], ["lin", 800.0, 0.3]], n), 3.0)
	return mult(f, env(n, 0.0, 0.02, 0.45, 0.3))


func chocalho() -> PackedFloat32Array:
	var n := n_de(0.2)
	var out := zeros(n)
	for d in [0.0, 0.055]:
		soma(out, mult(filtra(ruido(d, 0.13, n), "highpass", const_(6500, n), 0.7), env(n, d, 0.004, 0.22, 0.05)))
	return out


func miau() -> PackedFloat32Array:
	var n := n_de(0.66)
	var g := curva([["set", 0.0001, 0.0], ["exp", 0.4, 0.05], ["set", 0.4, 0.3], ["exp", 0.0001, 0.56]], n)
	var s := onda("sawtooth", curva([["set", 520.0, 0.0], ["lin", 790.0, 0.15], ["lin", 440.0, 0.52]], n), 0.0, 0.65, n)
	var f1 := filtra(s, "bandpass", curva([["set", 520.0, 0.0], ["lin", 980.0, 0.18], ["lin", 380.0, 0.5]], n), 6.0)
	var f2 := filtra(s, "bandpass", curva([["set", 2300.0, 0.0], ["lin", 1700.0, 0.2], ["lin", 820.0, 0.5]], n), 8.0)
	soma(f1, f2)
	return mult(f1, g)


func prato() -> PackedFloat32Array:
	var n := n_de(1.26)
	var out := mult(filtra(ruido(0.0, 1.25, n), "highpass", const_(5200, n), 0.6), env(n, 0.0, 0.002, 0.3, 1.1))
	for f in [3150.0, 4270.0, 5630.0]:
		soma(out, mult(filtra(onda("square", const_(f, n), 0.0, 0.95, n), "highpass", const_(3000, n), 0.5), env(n, 0.0, 0.002, 0.035, 0.8)))
	return out


func reco() -> PackedFloat32Array:
	var n := n_de(0.32)
	var out := zeros(n)
	for i in range(9):
		var d := i * 0.026
		soma(out, mult(filtra(ruido(d, 0.08, n), "bandpass", const_(3200, n), 1.5), env(n, d, 0.002, 0.3, 0.018)))
	return out


func latido() -> PackedFloat32Array:
	var n := n_de(0.42)
	var out := zeros(n)
	for d in [0.0, 0.19]:
		var g := curva([["set", 0.0001, d], ["exp", 0.5, d + 0.015], ["exp", 0.0001, d + 0.14]], n)
		var s := onda("sawtooth", curva([["set", 440.0, d], ["exp", 250.0, d + 0.13]], n, 440.0), d, 0.21, n)
		var f1 := filtra(s, "bandpass", const_(760, n), 4.0)
		soma(f1, filtra(s, "bandpass", const_(1500, n), 6.0))
		soma(out, mult(f1, g))
		soma(out, mult(filtra(ruido(d, 0.11, n), "bandpass", const_(1800, n), 1.0), env(n, d, 0.002, 0.12, 0.05)))
	return out


func balde() -> PackedFloat32Array:
	var n := n_de(0.31)
	var out := mult(onda("sine", curva([["set", 165.0, 0.0], ["exp", 92.0, 0.1]], n), 0.0, 0.3, n), env(n, 0.0, 0.002, 0.8, 0.2))
	soma(out, mult(filtra(ruido(0.0, 0.12, n), "bandpass", const_(950, n), 1.4), env(n, 0.0, 0.001, 0.35, 0.05)))
	return out


func udu() -> PackedFloat32Array:
	var n := n_de(0.51)
	var out := mult(onda("sine", curva([["set", 118.0, 0.0], ["exp", 190.0, 0.18]], n), 0.0, 0.5, n), env(n, 0.0, 0.006, 0.75, 0.4))
	soma(out, mult(filtra(ruido(0.0, 0.13, n), "lowpass", const_(600, n), 1.0), env(n, 0.0, 0.002, 0.15, 0.06)))
	return out


# ---------- o resto: metrônomo, apito, o rádio ligando e o que o rádio toca por baixo ----------
func tic(forte: bool) -> PackedFloat32Array:
	var n := n_de(0.1)
	var s := onda("square", const_(2300.0 if forte else 1750.0, n), 0.0, 0.1, n)
	return mult(filtra(s, "bandpass", const_(2000, n), 4.0), env(n, 0.0, 0.001, 0.09 if forte else 0.05, 0.03))


func apito() -> PackedFloat32Array:
	var n := n_de(0.45)
	var fr := PackedFloat32Array()
	fr.resize(n)
	for i in range(n):
		fr[i] = 2650.0 + 90.0 * sin(TAU * 36.0 * i / TAXA)
	var g := curva([["set", 0.0001, 0.0], ["exp", 0.14, 0.02], ["set", 0.14, 0.3], ["exp", 0.0001, 0.38]], n)
	return mult(onda("sine", fr, 0.0, 0.45, n), g)


func liga_radio() -> PackedFloat32Array:
	var n := n_de(1.2)
	var out := mult(filtra(ruido(0.0, 0.55, n), "bandpass", curva([["set", 400.0, 0.0], ["exp", 3500.0, 0.45]], n, 400.0), 4.0), env(n, 0.0, 0.01, 0.12, 0.45))
	for f in [220.0, 261.6, 329.6, 440.0]:
		soma(out, mult(filtra(onda("sawtooth", const_(f, n), 0.42, 0.75, n), "lowpass", const_(2400, n), 1.0), env(n, 0.42, 0.01, 0.07, 0.6)))
	return out


func baixo(f: float) -> PackedFloat32Array:
	var n := n_de(0.36)
	return mult(filtra(onda("sawtooth", const_(f, n), 0.0, 0.35, n), "lowpass", const_(420, n), 2.0), env(n, 0.0, 0.005, 0.32, 0.22))


func chiado() -> PackedFloat32Array:
	# força 1: quem toca multiplica pelo volume que a fase pede
	var n := n_de(0.1)
	return mult(filtra(ruido(0.0, 0.1, n), "highpass", const_(8000, n), 0.7), env(n, 0.0, 0.002, 1.0, 0.03))


func guitarra(f: float) -> PackedFloat32Array:
	var n := n_de(0.32)
	var s := zeros(n)
	for k in [1.0, 1.5, 2.0]:
		soma(s, onda("sawtooth", const_(f * k, n), 0.0, 0.31, n))
	# a distorção: tanh(6x), com o que passa de 1 cortado (o WaveShaper do navegador faz assim)
	for i in range(n):
		s[i] = tanh(6.0 * clampf(s[i], -1.0, 1.0))
	return mult(filtra(s, "lowpass", const_(2600, n), 0.8), env(n, 0.0, 0.004, 0.11, 0.2))


static func filtra_radio(x: PackedFloat32Array, ate: int) -> void:
	# o rádio abre o som aos poucos, como quem acabou de sintonizar (900 Hz → 16 kHz em 2,2 s)
	var n := mini(ate, x.size())
	var fr := curva([["set", 900.0, 0.0], ["exp", 16000.0, 2.2]], n, 900.0)
	var y := filtra(x.slice(0, n), "lowpass", fr, 0.0)
	for i in range(n):
		x[i] = y[i]


# ---------- de amostras pra som da Godot ----------
static func pra_wav(x: PackedFloat32Array, loop_ini := -1, loop_fim := -1) -> AudioStreamWAV:
	# monta um WAV de float 32 e deixa a Godot converter (rápido, sem laço amostra por amostra)
	var dados := x.to_byte_array()
	var cab := PackedByteArray()
	cab.resize(44)
	cab.encode_u32(0, 0x46464952)        # "RIFF"
	cab.encode_u32(4, 36 + dados.size())
	cab.encode_u32(8, 0x45564157)        # "WAVE"
	cab.encode_u32(12, 0x20746d66)       # "fmt "
	cab.encode_u32(16, 16)
	cab.encode_u16(20, 3)                # IEEE float
	cab.encode_u16(22, 1)
	cab.encode_u32(24, TAXA)
	cab.encode_u32(28, TAXA * 4)
	cab.encode_u16(32, 4)
	cab.encode_u16(34, 32)
	cab.encode_u32(36, 0x61746164)       # "data"
	cab.encode_u32(40, dados.size())
	cab.append_array(dados)
	var w := AudioStreamWAV.load_from_buffer(cab, { "compress/mode": 0 })
	if w != null and loop_ini >= 0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = loop_ini
		w.loop_end = loop_fim
	return w


static func pico(x: PackedFloat32Array) -> float:
	var m := 0.0
	for v in x:
		m = maxf(m, absf(v))
	return m
