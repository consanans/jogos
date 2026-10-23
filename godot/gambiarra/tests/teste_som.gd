extends SceneTree
## O teste do som: sintetiza todos os instrumentos e compara o volume (RMS) e o pico de cada um com o
## que a versão web dá nas mesmas receitas (medido num OfflineAudioContext do navegador); depois monta
## o beat em volta e confere que cada batida cai certinha na grade de 124 BPM.
##   godot --headless --path . -s res://tests/teste_som.gd -- --som

# [rms em 1,3 s, pico] de cada instrumento na versão web (força 1)
const WEB := {
	"bumbo": [0.0744, 0.870], "surdo": [0.1038, 0.879], "caixa": [0.0162, 0.460], "tamborim": [0.0204, 0.661],
	"agogo_a": [0.0299, 0.416], "grave": [0.0984, 1.030], "cuica": [0.0111, 0.186], "chocalho": [0.0073, 0.249],
	"miau": [0.0423, 0.247], "prato": [0.0403, 0.465], "reco": [0.0054, 0.133], "latido": [0.0118, 0.214],
	"balde": [0.0521, 0.730], "udu": [0.0709, 0.759],
}

var falhas := 0
var oks := 0


func confere(cond: bool, txt: String) -> void:
	if cond:
		oks += 1
		print("  ok: ", txt)
	else:
		falhas += 1
		print("  FALHOU: ", txt)


func _initialize() -> void:
	_roda.call_deferred()


func _roda() -> void:
	var som: Node = root.get_node("Som")
	var t := Time.get_ticks_msec()
	som.sintetiza_tudo()
	print("# os instrumentos (sintetizados em %d ms)" % (Time.get_ticks_msec() - t))
	for k in WEB:
		var it: Dictionary = som._banco[k][0]
		var a: PackedFloat32Array = it.amostras
		var g: float = it.ganho
		var e := 0.0
		var pk := 0.0
		for v in a:
			e += v * v * g * g
			pk = maxf(pk, absf(v) * g)
		var rms := sqrt(e / 57330.0)
		var ref: Array = WEB[k]
		var dr := rms / float(ref[0])
		var dp := pk / float(ref[1])
		confere(dr > 0.65 and dr < 1.5 and dp > 0.6 and dp < 1.5, "%-9s rms %.4f (web %.4f)  pico %.3f (web %.3f)" % [k, rms, ref[0], pk, ref[1]])
	print("# o beat em volta cai na grade")
	var pad: Array = []
	for i in range(Dados.VOLTA):
		pad.append([])
	var esperado := [0, 4, 6, 10, 16, 22, 28]
	for i in esperado:
		pad[i].append({ "inst": "balde", "v": 1.0 })
	var w: AudioStreamWAV = som.monta_loop(pad, 9)    # 9: sem o groove, só as batidas
	var tam := int(roundf(Dados.VOLTA * Dados.S16 * Sintese.TAXA))
	confere(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_begin == tam and w.loop_end == tam * 2, "o som do fim repete a segunda volta (de %d a %d)" % [tam, tam * 2])
	# a volta que repete, decodificada de novo: acha onde cada batida começa
	var buf := Sintese.zeros(tam * 2)
	for k in range(Dados.VOLTA):
		for h in pad[k]:
			som._poe(buf, h.inst, k * Dados.S16, 1.0, true, tam, tam)
	var janela := int(0.002 * Sintese.TAXA)
	var achados := []
	var ant := 0.0
	var i0 := tam
	while i0 < tam * 2 - janela:
		var e := 0.0
		for j in range(janela):
			e += buf[i0 + j] * buf[i0 + j]
		if e > 0.02 and e > ant * 8.0:
			var t_ms := (i0 - tam) * 1000.0 / Sintese.TAXA
			if achados.is_empty() or t_ms - float(achados[achados.size() - 1]) > 40.0:
				achados.append(t_ms)
		ant = e
		i0 += janela
	var certos := 0
	for k in esperado:
		var alvo: float = k * Dados.S16 * 1000.0
		for a in achados:
			if absf(float(a) - alvo) <= 3.0:
				certos += 1
				break
	confere(certos == esperado.size() and achados.size() == esperado.size(), "%d batidas, todas a até 3 ms da semicolcheia certa (achou: %s)" % [certos, str(achados.map(func(x: float) -> int: return int(roundf(x))))])
	print("\nRESULTADO: %d ok, %d falhas" % [oks, falhas])
	quit(1 if falhas > 0 else 0)
