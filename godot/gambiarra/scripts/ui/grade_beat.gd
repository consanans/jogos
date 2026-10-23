class_name GradeBeat
extends Control
## A grade do beat no cartão do fim: uma linha por instrumento, 32 semicolcheias, e a coluna que
## tá tocando acesa.

var padrao: Array = []
var coluna := -1
var _f := Fontes.txt(600)


func _get_minimum_size() -> Vector2:
	return Vector2(100, maxi(1, _insts().size()) * 15 + 4)


func _insts() -> Array:
	var out: Array = []
	for k in Dados.ORDEM_INST:
		for cel in padrao:
			var achou := false
			for h in cel:
				if h.inst == k:
					achou = true
					break
			if achou:
				out.append(k)
				break
	return out


func define(p: Array) -> void:
	padrao = p
	update_minimum_size()
	queue_redraw()


func marca(col: int) -> void:
	if col != coluna:
		coluna = col
		queue_redraw()


func _draw() -> void:
	var insts := _insts()
	var lin := 15.0
	var rot := 62.0
	var w := size.x
	var hh := maxf(1, insts.size()) * lin + 4
	var cw := (w - rot) / Dados.VOLTA
	if coluna >= 0:
		draw_rect(Rect2(rot + coluna * cw, 0, cw, hh), Color(1, 197 / 255.0, 49 / 255.0, 0.18))
	var asc := _f.get_ascent(11)
	var desc := _f.get_descent(11)
	for j in range(insts.size()):
		var k: String = insts[j]
		var y := 2 + j * lin
		var cor := Color(Dados.INFO[k][1])
		draw_string(_f, Vector2(0, y + (lin + asc - desc) / 2.0), Dados.INFO[k][0], HORIZONTAL_ALIGNMENT_LEFT, rot - 2, 11, cor)
		for i in range(Dados.VOLTA):
			var x := rot + i * cw
			var hit: Dictionary = {}
			for h in padrao[i]:
				if h.inst == k:
					hit = h
			if not hit.is_empty():
				var c2 := Color(cor, 0.45 + float(hit.v) * 0.55)
				draw_style_box(Kit.estilo_caixa(c2, 2), Rect2(x + 1, y + 2, cw - 2, lin - 4))
			else:
				draw_rect(Rect2(x + 1, y + 2, cw - 2, lin - 4), Color(230 / 255.0, 210 / 255.0, 155 / 255.0, 0.16 if i % 4 == 0 else 0.07))
