class_name Kit
## Os pedaços de interface da casa: a fita crepe rasgada, a folha de caderno, os botões, os textos.

# o clip-path "rasgo" da web: as pontas rasgadas da fita crepe
const RASGO := [[0, 7], [4, 0], [9, 6], [15, 1], [22, 7], [30, 0], [38, 6], [46, 1], [54, 7], [62, 0], [70, 6], [78, 1], [86, 7], [93, 0], [100, 6],
	[100, 94], [95, 100], [88, 93], [80, 99], [72, 94], [64, 100], [56, 94], [48, 99], [40, 93], [32, 100], [24, 94], [16, 99], [8, 93], [0, 100]]


static func rasgo_pts(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in RASGO:
		pts.append(r.position + Vector2(r.size.x * q[0] / 100.0, r.size.y * q[1] / 100.0))
	return pts


class EstiloRasgo extends StyleBox:
	var cor := Dados.FITA

	func _init(c := Dados.FITA, mx := 12.0, my := 7.0) -> void:
		cor = c
		content_margin_left = mx
		content_margin_right = mx
		content_margin_top = my
		content_margin_bottom = my

	func _draw(ci: RID, r: Rect2) -> void:
		RenderingServer.canvas_item_add_polygon(ci, Kit.rasgo_pts(r), PackedColorArray([cor]))


class EstiloCaderno extends StyleBox:
	# a folha de caderno quadriculado, com a margem vermelha
	var esq := 30.0

	func _init(m_esq := 30.0, m := 18.0, m_baixo := 16.0) -> void:
		esq = m_esq
		content_margin_left = m_esq
		content_margin_right = m
		content_margin_top = m
		content_margin_bottom = m_baixo

	func _draw(ci: RID, r: Rect2) -> void:
		var raio := 6.0
		var pts := PackedVector2Array()
		for k in [[r.end.x - raio, r.position.y + raio, -PI / 2], [r.end.x - raio, r.end.y - raio, 0.0], [r.position.x + raio, r.end.y - raio, PI / 2], [r.position.x + raio, r.position.y + raio, PI]]:
			for i in range(5):
				var t: float = k[2] + PI / 2 * i / 4.0
				pts.append(Vector2(k[0] + cos(t) * raio, k[1] + sin(t) * raio))
		RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([Dados.PAPEL]))
		var grade := Color(45 / 255.0, 93 / 255.0, 166 / 255.0, 0.13)
		var x := r.position.x + 18
		while x < r.end.x - 1:
			RenderingServer.canvas_item_add_line(ci, Vector2(x, r.position.y + 1), Vector2(x, r.end.y - 1), grade, 1.0)
			x += 18
		var y := r.position.y + 18
		while y < r.end.y - 1:
			RenderingServer.canvas_item_add_line(ci, Vector2(r.position.x + 1, y), Vector2(r.end.x - 1, y), grade, 1.0)
			y += 18
		var mx := r.position.x + (14.0 if esq < 30 else 18.0)
		RenderingServer.canvas_item_add_rect(ci, Rect2(mx, r.position.y, 2, r.size.y), Color(215 / 255.0, 52 / 255.0, 43 / 255.0, 0.45))


static func estilo_caixa(cor: Color, raio := 10.0, borda := 0.0, cor_borda := Color.TRANSPARENT, mx := 0.0, my := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(int(raio))
	if borda > 0:
		s.set_border_width_all(int(borda))
		s.border_color = cor_borda
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s


static func rotulo(txt: String, fonte: Font, tam: float, cor: Color, sombra := Color.TRANSPARENT, sombra_off := Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = txt
	var ls := LabelSettings.new()
	ls.font = fonte
	ls.font_size = int(roundf(tam))
	ls.font_color = cor
	if sombra.a > 0:
		ls.shadow_color = sombra
		ls.shadow_offset = sombra_off
		ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func entrelinha(fonte: Font, tam: float, lh: float) -> float:
	# o line-height da web: a Godot soma um espaço extra à altura natural da letra
	return tam * lh - fonte.get_height(int(tam))


static func espacada(base: Font, px: int) -> Font:
	# letter-spacing da web
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = px
	return fv


static func texto_rico(bbcode: String, tam: float, cor: Color, fonte := Fontes.txt(400), negrito := Fontes.txt(800)) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", fonte)
	r.add_theme_font_override("bold_font", negrito)
	r.add_theme_font_size_override("normal_font_size", int(tam))
	r.add_theme_font_size_override("bold_font_size", int(tam))
	r.add_theme_color_override("default_color", cor)
	r.add_theme_constant_override("line_separation", int(roundf(entrelinha(fonte, tam, 1.35))))
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.text = bbcode
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r
