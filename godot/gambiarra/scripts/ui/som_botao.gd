class_name SomBotao
extends Button
## O botão redondo do som (alto-falante com as ondinhas; apagado quando desliga).

var ligado := true


func _init() -> void:
	flat = true
	for k in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(k, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(40, 40)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Som ligado"


func _draw() -> void:
	var cor := Dados.FITA if ligado else Dados.TINTA2
	var borda := Dados.FITA2 if ligado else Dados.TINTA2
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 1
	draw_arc(c, r, 0, TAU, 48, borda, 2.0, true)
	var k := 20.0 / 24.0
	var m := func(x: float, y: float) -> Vector2: return c + Vector2(x - 12.0, y - 12.0) * k
	var corpo := PackedVector2Array([m.call(4, 9), m.call(4, 15), m.call(8, 15), m.call(13, 19), m.call(13, 5), m.call(8, 9), m.call(4, 9)])
	draw_polyline(corpo, cor, 2.2 * k, true)
	for q in [[5.0, 12.93, 12.0, -0.775, 0.775], [8.5, 12.98, 12.0, -0.783, 0.783]]:
		var pts := PackedVector2Array()
		for i in range(13):
			var t: float = q[3] + (q[4] - q[3]) * i / 12.0
			pts.append(m.call(q[1] + cos(t) * q[0], q[2] + sin(t) * q[0]))
		draw_polyline(pts, cor, 2.2 * k, true)
	if has_focus() and Botao.teclado:
		draw_arc(c, r + 3, 0, TAU, 48, Dados.VAI, 3.0, true)


func liga(sim: bool) -> void:
	ligado = sim
	tooltip_text = "Som ligado" if sim else "Som desligado"
	queue_redraw()
