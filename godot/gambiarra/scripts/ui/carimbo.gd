class_name Carimbo
extends Control
## O carimbo do fim: FUNCIONOU! em azul ou PAROU. em vermelho, torto, com a borda grossa.

var texto := "FUNCIONOU!"
var parou := false
var tam := 40.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	var f := Fontes.letreiro()
	return Vector2(Ctx.largura(texto, f, tam) + 24 + 8, tam + 10 + 8 + 4)


func _draw() -> void:
	var f := Fontes.letreiro()
	var cor := Dados.PERIGO if parou else Dados.AZULEJO
	var w := Ctx.largura(texto, f, tam) + 24
	var h := tam * 1.0 + 10
	var r := Rect2(4, 4 + 4, w, h)
	draw_set_transform(r.get_center(), deg_to_rad(-4), Vector2.ONE)
	var rr := Rect2(-w / 2.0, -h / 2.0, w, h)
	draw_style_box(Kit.estilo_caixa(Color.TRANSPARENT, 8, 4, cor), rr)
	draw_string(f, Vector2(-w / 2.0 + 12, (f.get_ascent(int(tam)) - f.get_descent(int(tam))) / 2.0 + 2), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), cor)
	draw_set_transform_matrix(Transform2D.IDENTITY)
