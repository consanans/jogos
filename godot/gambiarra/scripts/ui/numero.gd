class_name Numero
extends Control
## A bolinha amarela com o número de cada passo da introdução.

var n := 1


func _init(k := 1) -> void:
	n = k
	custom_minimum_size = Vector2(28, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_circle(Vector2(13, 13), 13, Dados.VAI, true, -1.0, true)
	var f := Fontes.letreiro()
	var t := str(n)
	var w := Ctx.largura(t, f, 17)
	draw_string(f, Vector2(13 - w / 2.0, 13 + (f.get_ascent(17) - f.get_descent(17)) / 2.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Dados.TINTA)
