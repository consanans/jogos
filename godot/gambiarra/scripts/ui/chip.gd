class_name Chip
extends Control
## As pílulas do pedido (surdo, agogô...) e as bolinhas da levada (1 2 3 4): tracejadas até a
## corrente tocar, aí ficam azuis com o ✓.

var texto := ""
var ok := false
var slot := false
var _f := Fontes.txt(700)


func _init(t := "", o := false, s := false) -> void:
	texto = t
	ok = o
	slot = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	if slot:
		return Vector2(24, 24)
	return Vector2(Ctx.largura(texto, _f, 12) + 14 + 3 + (11.0 if ok else 0.0), 20)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var raio := size.y / 2.0 if slot else 10.0
	if ok:
		draw_style_box(Kit.estilo_caixa(Dados.AZULEJO, raio), r)
	else:
		# a borda tracejada
		var pts := PackedVector2Array()
		var rr := r.grow(-0.75)
		var rad := minf(raio, rr.size.y / 2.0)
		for k in [[rr.end.x - rad, rr.position.y + rad, -PI / 2], [rr.end.x - rad, rr.end.y - rad, 0.0], [rr.position.x + rad, rr.end.y - rad, PI / 2], [rr.position.x + rad, rr.position.y + rad, PI]]:
			for i in range(9):
				var t: float = k[2] + PI / 2 * i / 8.0
				pts.append(Vector2(k[0] + cos(t) * rad, k[1] + sin(t) * rad))
		pts.append(pts[0])
		var total := 0.0
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var d := a.distance_to(b)
			var pos := 0.0
			while pos < d:
				var fase := fmod(total + pos, 6.0)
				var resta := (4.0 - fase) if fase < 4.0 else (6.0 - fase)
				var fim := minf(d, pos + resta)
				if fase < 4.0:
					draw_line(a.lerp(b, pos / d), a.lerp(b, fim / d), Dados.TINTA2, 1.5, true)
				pos = fim + 0.0001
			total += d
	var cor := Color.WHITE if ok else Dados.TINTA2
	var w := Ctx.largura(texto, _f, 12)
	var asc := _f.get_ascent(12)
	var desc := _f.get_descent(12)
	var x := (size.x - w) / 2.0
	if ok and not slot:
		# o ✓ (as letras da casa não têm esse sinal): um risquinho em V
		x += 5.5
		var cy := size.y / 2.0
		draw_polyline(PackedVector2Array([Vector2(x - 10, cy), Vector2(x - 7.5, cy + 2.8), Vector2(x - 2.5, cy - 3.2)]), cor, 1.8, true)
	draw_string(_f, Vector2(x, (size.y + asc - desc) / 2.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cor)
