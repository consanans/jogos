class_name MiniFase
extends Control
## A miniatura da ladeira (a lista da entrada e o cartão do desafio): o desenho todo, de longe.

var fase: Dictionary = {}
var raio := 8.0
var borda := false
static var desenhos := 0
var _F: Nucleo.Fase = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var W := size.x
	var H := size.y
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("#121116")
	fundo.set_corner_radius_all(int(raio))
	if borda:
		fundo.set_border_width_all(maxi(1, int(Estilo.pf(2))))
		fundo.border_color = Estilo.g(0.16)
	fundo.anti_aliasing = true
	draw_style_box(fundo, Rect2(Vector2.ZERO, size))
	if fase.is_empty():
		return
	desenhos += 1
	if _F == null:
		_F = Nucleo.compila(fase)
	var F := _F
	var alt := maxf(F.y_max + 30.0, 400.0)
	var s := minf(W / Nucleo.LARG, H / (alt + 20.0))
	var ox := (W - Nucleo.LARG * s) / 2.0
	draw_set_transform(Vector2(ox, 6.0), 0.0, Vector2(s, s))
	draw_rect(Rect2(0, 0, Nucleo.LARG, alt), Color(1.0, 201.0 / 255, 60.0 / 255, 0.35), false, 1.0 / s)
	var L: Array = Nucleo.LARGADA
	draw_line(Vector2(L[2], L[3]), Vector2(L[4], L[5]), Color("#B9733A"), 7.0, true)
	var lw := maxf(5.0, 1.6 / s)
	for t in fase["tracos"]:
		var c: Color = Estilo.CORES_GIZ[int(t["cor"])] if int(t["cor"]) < 4 else Estilo.CORES_GIZ[0]
		var p: Array = t["pts"]
		var o := PackedVector2Array()
		var i := 0
		while i < p.size():
			o.append(Vector2(p[i], p[i + 1]))
			i += 2
		if o.size() >= 2:
			draw_polyline(o, c, lw, true)
	var cores := {"mola": Color("#FF4F9A"), "turbo": Color("#FFC93C"), "cachorro": Color("#D0833A"), "chegada": Color("#F3EEE2")}
	for cb in fase["carimbos"]:
		var ch: bool = cb["tipo"] == "chegada"
		draw_circle(Vector2(cb["x"], float(cb["y"]) - (20.0 if ch else 8.0)), 16.0 if ch else 12.0, cores[cb["tipo"]], true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
