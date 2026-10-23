class_name Pontilhado
extends Control
## O pontilhado entre o nome e o valor na conta do fim.

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(12, 4)


func _draw() -> void:
	var y := size.y * 0.72
	var x := 1.0
	while x < size.x:
		draw_rect(Rect2(x, y, 2, 2), Color(31 / 255.0, 25 / 255.0, 21 / 255.0, 0.35))
		x += 4
