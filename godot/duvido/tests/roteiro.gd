extends Node
## Roteiro de teste no motor de verdade (com tela, no Xvfb): passos e fotos.
## godot --path . --resolution 390x844 -- "--roteiro=passo;passo;..." --fotos=PASTA
## Passos: espera:S, foto:NOME, estado, sai, e os comandos de scripts/comandos.gd.

var p: Principal
var passos: PackedStringArray
var i := 0
var espera := 0.0
var pasta := "user://"


func _ready() -> void:
	p = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--roteiro="):
			passos = a.substr(10).split(";", false)
		elif a.begins_with("--fotos="):
			pasta = a.substr(8)


var ocupado := false


func _process(dt: float) -> void:
	if ocupado:
		return
	if espera > 0.0:
		espera -= dt
		return
	if i >= passos.size():
		print("ROTEIRO: fim")
		get_tree().quit()
		return
	var s := passos[i]
	i += 1
	var k := s.get_slice(":", 0)
	var arg := s.substr(k.length() + 1)
	match k:
		"espera":
			espera = float(arg)
		"foto":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(pasta.path_join(arg + ".png"))
			print("ROTEIRO: foto ", arg)
		"perf":
			# o custo do quadro (CPU): processo e desenho, em ms, média dos próximos 120 quadros
			ocupado = true
			var soma := 0.0
			var n := 0
			var m0 := MiniFase.desenhos
			p.perf_zera()
			for q in 120:
				await get_tree().process_frame
				soma += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
				n += 1
			print("ROTEIRO: perf processo %.2f ms/quadro, %d chamadas de desenho, fps %d, miniaturas redesenhadas %d, %s" % [soma / n, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second(), MiniFase.desenhos - m0, p.perf_txt()])
			ocupado = false
		"esconde":
			var mapa := {"fundo": p.mundo.fundo, "gizes": p.mundo.gizes, "vivo": p.mundo.vivo, "ui": p.camada, "fora": p.mundo.fora, "tira": p.mundo.tira}
			mapa[arg].visible = false
		"dedo", "move", "larga":
			# um dedo de verdade (o evento entra pela janela, como no celular): dedo:índice,x,y em unidades da tela
			var v := arg.split(",")
			var pt := _janela(Vector2(float(v[1]), float(v[2])))
			if k == "move":
				var ev := InputEventScreenDrag.new()
				ev.index = int(v[0])
				ev.position = pt
				Input.parse_input_event(ev)
			else:
				var ev := InputEventScreenTouch.new()
				ev.index = int(v[0])
				ev.position = pt
				ev.pressed = k == "dedo"
				Input.parse_input_event(ev)
		"roda":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if float(arg) > 0.0 else MOUSE_BUTTON_WHEEL_UP
			ev.factor = absf(float(arg))
			ev.pressed = true
			ev.position = _janela(p.tam / 2.0)
			Input.parse_input_event(ev)
		"janela":
			var v := arg.split(",")
			DisplayServer.window_set_size(Vector2i(int(v[0]), int(v[1])))
		"estado":
			print("ROTEIRO: estado ", JSON.stringify(p.estado()))
		"sai":
			get_tree().quit()
		_:
			Comandos.executa(p, s)


func _janela(logico: Vector2) -> Vector2:
	# das unidades da tela (720 de largura) pros pontos da janela
	return logico * get_viewport().get_final_transform().x.length()
