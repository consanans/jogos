class_name Clicavel
extends PanelContainer
## Um painel que se comporta como botão (a marca do alto, os botões das fases).

signal clicou

var _dentro := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_dentro = true
			accept_event()
		elif _dentro:
			_dentro = false
			if Rect2(Vector2.ZERO, size).has_point(ev.position):
				clicou.emit()
			accept_event()
	elif ev is InputEventKey and ev.pressed and (ev.keycode == KEY_ENTER or ev.keycode == KEY_SPACE or ev.keycode == KEY_KP_ENTER):
		clicou.emit()
		accept_event()


func _draw() -> void:
	if has_focus() and Botao.teclado:
		draw_style_box(Kit.estilo_caixa(Color.TRANSPARENT, 10, 3, Dados.VAI), Rect2(Vector2.ZERO, size).grow(2))
