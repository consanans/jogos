class_name Estilo
extends RefCounted
## A cara do Duvido: as cores, as letras (Bungee, Permanent Marker e Rubik), os botões e os ícones,
## os mesmos da versão web. Os tamanhos vêm em "px de CSS" e viram unidades da tela com px().
## Nada de verde.

const FORA := Color("#0B0A0E")
const CARTAO := Color("#17161C")
const BORDA := Color(243.0 / 255.0, 238.0 / 255.0, 226.0 / 255.0, 0.16)
const GIZ := Color("#F3EEE2")
const GIZ2 := Color("#C2BBAB")
const APAGADO := Color("#8F897B")
const AMARELO := Color("#FFC93C")
const AMARELO_SOMBRA := Color("#A47808")
const ROSA := Color("#FF4F9A")
const ROSA_SOMBRA := Color("#A3245C")
const AZUL := Color("#4AA8FF")
const LARANJA := Color("#FF7A2F")
const VERMELHO := Color("#E8402A")
const TINTA := Color("#121116")
const VIDRO := Color(13.0 / 255.0, 12.0 / 255.0, 17.0 / 255.0, 0.86)
const ERRO := Color("#FF9A86")

## As cores do giz: branco, amarelo, rosa e azul.
const CORES_GIZ := [Color8(243, 238, 226), Color8(255, 214, 74), Color8(255, 111, 174), Color8(108, 196, 255)]
const NOMES_COR := ["branco", "amarelo", "rosa", "azul"]

## Quantas unidades de tela vale um px de CSS da versão web (muda com o tamanho da tela).
static var P := 1.846
static var tit: Font
static var giz: Font
static var t500: FontVariation
static var t600: FontVariation
static var t700: FontVariation
static var t800: FontVariation
static var _icones := {}


static func g(a: float) -> Color:
	return Color(GIZ.r, GIZ.g, GIZ.b, a)


static func carrega() -> void:
	if tit != null:
		return
	tit = load("res://assets/fonts/Bungee-Regular.ttf")
	giz = load("res://assets/fonts/PermanentMarker-Regular.ttf")
	var rubik: FontFile = load("res://assets/fonts/Rubik-wght.ttf")
	t500 = _peso(rubik, 500)
	t600 = _peso(rubik, 600)
	t700 = _peso(rubik, 700)
	t800 = _peso(rubik, 800)


static func _peso(base: Font, w: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	return f


static func px(v: float) -> int:
	return int(round(v * P))


static func pf(v: float) -> float:
	return v * P


# ---------------------------------------------------------------- caixas
static func caixa(bg: Color, raio: float, borda := 0.0, cor_borda := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(px(raio))
	if borda > 0.0:
		s.set_border_width_all(maxi(1, px(borda)))
		s.border_color = cor_borda
	s.anti_aliasing = true
	s.corner_detail = 10
	return s


static func margens(s: StyleBox, cima: float, lado: float, baixo := -1.0, esq := -1.0) -> StyleBox:
	s.content_margin_top = pf(cima)
	s.content_margin_bottom = pf(cima if baixo < 0.0 else baixo)
	s.content_margin_right = pf(lado)
	s.content_margin_left = pf(lado if esq < 0.0 else esq)
	return s


## A sombra dura de baixo dos botões (box-shadow 0 Npx 0).
static func com_sombra(s: StyleBoxFlat, cor: Color, dy: float) -> StyleBoxFlat:
	s.shadow_color = cor
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, pf(dy))
	return s


## O botão afundado (:active do CSS): desce uns pontos e perde a sombra.
static func afundado(s: StyleBoxFlat, dy: float) -> StyleBoxFlat:
	var a := s.duplicate() as StyleBoxFlat
	a.shadow_size = 0
	a.shadow_color = Color.TRANSPARENT
	a.expand_margin_top = -pf(dy)
	a.expand_margin_bottom = pf(dy)
	a.content_margin_top = s.content_margin_top + pf(dy)
	a.content_margin_bottom = maxf(0.0, s.content_margin_bottom - pf(dy))
	return a


# ---------------------------------------------------------------- botões
## tipo: "bt" (o comum), "vai" (amarelo), "rosa", "r" (quadradinho de ícone), "testa", "manda", "link", "lixo".
static func botao(texto: String, tipo := "bt", icone := "") -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estiliza(b, tipo)
	if icone != "":
		b.icon = icone_tex(icone, 22.0)
		b.expand_icon = false
	return b


static func estiliza(b: Button, tipo: String) -> void:
	var n: StyleBoxFlat
	var fonte: Font = t800
	var tam := 16.0
	var cor := GIZ
	var desce := 3.0
	match tipo:
		"vai":
			n = com_sombra(caixa(AMARELO, 14.0), AMARELO_SOMBRA, 5.0)
			margens(n, 12.0, 16.0, 10.0)
			fonte = tit; tam = 20.0; cor = TINTA
			b.custom_minimum_size.y = pf(50.0)
		"rosa":
			n = com_sombra(caixa(ROSA, 14.0), ROSA_SOMBRA, 5.0)
			margens(n, 12.0, 16.0, 10.0)
			fonte = tit; tam = 18.0; cor = Color.WHITE
			b.custom_minimum_size.y = pf(50.0)
		"r":
			n = caixa(VIDRO, 12.0, 2.0, g(0.24))
			margens(n, 0.0, 0.0)
			b.custom_minimum_size = Vector2(pf(44.0), pf(44.0))
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desce = 0.0
		"testa":
			n = com_sombra(caixa(AMARELO, 12.0), AMARELO_SOMBRA, 4.0)
			margens(n, 0.0, 12.0)
			fonte = t800; tam = 14.0; cor = TINTA
			b.custom_minimum_size.y = pf(44.0)
		"manda":
			n = com_sombra(caixa(ROSA, 12.0), ROSA_SOMBRA, 4.0)
			margens(n, 0.0, 12.0)
			fonte = t800; tam = 14.0; cor = Color.WHITE
			b.custom_minimum_size.y = pf(44.0)
		"manda_off":
			n = caixa(g(0.1), 12.0)
			margens(n, 0.0, 12.0)
			fonte = t800; tam = 14.0; cor = APAGADO
			b.custom_minimum_size.y = pf(44.0)
			desce = 0.0
		"link":
			n = StyleBoxFlat.new()
			n.bg_color = Color.TRANSPARENT
			margens(n, 4.0, 2.0)
			fonte = t700; tam = 14.0; cor = AMARELO
			desce = 0.0
		_:
			n = caixa(g(0.05), 14.0, 2.0, g(0.26))
			margens(n, 10.0, 16.0)
			b.custom_minimum_size.y = pf(50.0)
	var a := afundado(n, desce) if desce > 0.0 else n
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", a)
	b.add_theme_stylebox_override("hover_pressed", a)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", fonte)
	b.add_theme_font_size_override("font_size", px(tam))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color", "icon_disabled_color"]:
		b.add_theme_color_override(k, cor)
	b.add_theme_constant_override("h_separation", px(6.0))
	b.add_theme_constant_override("line_spacing", px(-2.0))
	if tipo == "link":
		b.autowrap_mode = TextServer.AUTOWRAP_OFF


# ---------------------------------------------------------------- textos
static func rotulo(texto: String, fonte: Font, tam: float, cor := GIZ, alinh := HORIZONTAL_ALIGNMENT_LEFT, quebra := true) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", px(tam))
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = alinh
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Texto com pedaços coloridos (o <em> e o <b> do HTML): BBCode do RichTextLabel.
static func rico(bb: String, fonte: Font, tam: float, cor := GIZ, centro := true, negrito: Font = null) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", fonte)
	r.add_theme_font_override("bold_font", negrito if negrito != null else fonte)
	r.add_theme_font_size_override("normal_font_size", px(tam))
	r.add_theme_font_size_override("bold_font_size", px(tam))
	r.add_theme_color_override("default_color", cor)
	r.add_theme_constant_override("line_separation", px(tam * 0.3))
	r.text = ("[center]" + bb + "[/center]") if centro else bb
	return r


static func hexa(c: Color) -> String:
	return "#" + c.to_html(false)


## O olho (a linha miudinha em caixa alta com espaço entre as letras).
static func olho(texto: String, tam := 11.5, esp := 0.16, cor := GIZ2, alinh := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return rotulo(texto.to_upper(), espacada(tam * esp), tam, cor, alinh)


## A Rubik 800 com espaço entre as letras (o letter-spacing do CSS).
static func espacada(esp_css: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = t800.base_font
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	f.spacing_glyph = px(esp_css)
	return f


# ---------------------------------------------------------------- ícones (os mesmos SVG da versão web)
const SVG := {
	"reinicia": '<path d="M20 12a8 8 0 1 1-2.4-5.7"/><path d="M20 4v5h-5"/>',
	"som": '<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4z"/><path d="M16 9a4.2 4.2 0 0 1 0 6M18.5 6.5a7.8 7.8 0 0 1 0 11"/>',
	"mudo": '<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
	"sai": '<path d="M6 6l12 12M18 6L6 18"/>',
	"volta": '<path d="M15 5l-7 7 7 7"/>',
	"desfaz": '<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
	"lixo": '<path d="M4 7h16M10 7V4.5h4V7M6.5 7l1 13h9l1-13"/>',
	"testa": '<path d="M7 4.5l12 7.5-12 7.5z" fill="#FFFFFF"/>',
	"cadeado": '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
	"aviao": '<path d="M21 3L3 10.5l7.5 3L13.5 21z"/><path d="M10.5 13.5L21 3"/>',
	"lapis": '<path d="M5 19l2.5-.6L19 6.9 17.1 5 5.6 16.5z"/><path d="M15 7l2 2"/><path d="M4 21h7" stroke-dasharray="2 2.5"/>',
	"borracha": '<path d="M9 20h11"/><path d="M4.5 14.5l8.5-8.5 6.5 6.5-7.5 7.5H9.5z"/><path d="M9 10l6.5 6.5"/>',
	"mola": '<path d="M5 5h14"/><path d="M8 5l8 2.5-8 2.5 8 2.5-8 2.5 8 2.5"/><path d="M6 19h12"/>',
	"turbo": '<path d="M4 6.5l6 5.5-6 5.5M11.5 6.5l6 5.5-6 5.5"/>',
	"cachorro": '<path d="M3.5 13.5c0-3 2-5 5-5h5l2-3.5 1.5 3.5h2.5l1.5 2.5-2 1.5h-2v5.5M6.5 13.5v5.5M10 15v4M14.5 15.5v3.5"/><path d="M3.5 13.5L2 11"/>',
	"chegada": '<path d="M5.5 21V4"/><path d="M5.5 4.5h13v8h-13"/><path d="M9.5 4.5v8M13.5 4.5v8M5.5 8.5h13" stroke-width="1.6"/>',
	"conversa": '<path d="M4.5 19.5l1.2-3.6A7.8 7.8 0 1 1 8.6 18.4z"/><path d="M9 11.5h.01M12.5 11.5h.01M16 11.5h.01" stroke-width="2.8"/>',
	"copia": '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5.5A1.5 1.5 0 0 0 14.5 4h-9A1.5 1.5 0 0 0 4 5.5v9A1.5 1.5 0 0 0 5.5 16H8"/>',
	"cola": '<rect x="5" y="5" width="14" height="16" rx="2"/><path d="M9 5V3.5h6V5"/><path d="M9 11h6M9 15h4"/>',
}


static func icone_tex(nome: String, tam_css: float) -> Texture2D:
	var lado := maxi(8, px(tam_css))
	var chave := nome + "@" + str(lado)
	if _icones.has(chave):
		return _icones[chave]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">' + SVG.get(nome, "") + "</svg>"
	var img := Image.new()
	img.load_svg_from_string(svg, float(lado) / 24.0)
	var t := ImageTexture.create_from_image(img)
	_icones[chave] = t
	return t


static func limpa_cache() -> void:
	_icones.clear()
