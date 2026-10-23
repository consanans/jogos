class_name Texturas
extends RefCounted
## As texturas feitas uma vez, no código (nenhuma imagem de fora): o asfalto, o grão do giz e a mancha.

static var asfalto: ImageTexture
static var grao_giz: Array = []        # uma por cor (o grão muda um tiquinho)
static var mancha: Texture2D
static var shader_giz: Shader
static var mat_giz: Array = []         # ShaderMaterial por cor


static func prepara() -> void:
	if asfalto != null:
		return
	asfalto = _asfalto()
	for i in 4:
		grao_giz.append(_grao(70 + i))
	var gr := Gradient.new()
	gr.set_color(0, Color8(5, 5, 8, 128))
	gr.set_color(1, Color8(5, 5, 8, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	mancha = gt
	shader_giz = Shader.new()
	shader_giz.code = """
shader_type canvas_item;
// o giz: cada pontinho do traço tem a sua força (o grão), presa no chão, do tamanho de um ponto de tela
uniform sampler2D grao : repeat_enable, filter_nearest;
uniform float escala = 1.0;
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec4 t = texture(grao, lp * escala / 64.0);
	COLOR = vec4(COLOR.rgb * t.g, COLOR.a * t.r);
}
"""
	for i in 4:
		var m := ShaderMaterial.new()
		m.shader = shader_giz
		m.set_shader_parameter("grao", grao_giz[i])
		mat_giz.append(m)


static func escala(k: float) -> void:
	for m in mat_giz:
		m.set_shader_parameter("escala", k)


static func _asfalto() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color8(0x1C, 0x1B, 0x21))
	var r := Fases.Sorteio.new(4242)
	for i in 11000:
		var claro := r.r() < 0.5
		var g := (34.0 + r.r() * 22.0) if claro else (13.0 + r.r() * 9.0)
		var quente := 10.0 if r.r() < 0.12 else 0.0
		var s := 1 if r.r() < 0.88 else 2
		var a := 0.3 + r.r() * 0.55
		var c := Color8(int(g + quente), int(g), int(g + 4.0))
		var x := int(r.r() * 256.0)
		var y := int(r.r() * 256.0)
		for dy in s:
			for dx in s:
				var px := (x + dx) % 256
				var py := (y + dy) % 256
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(c, a))
	for i in 300:
		var c := Color8(int(160.0 + r.r() * 60.0), int(150.0 + r.r() * 50.0), int(140.0 + r.r() * 40.0))
		var a := 0.06 + r.r() * 0.14
		var cx := r.r() * 256.0
		var cy := r.r() * 256.0
		var rr := 0.6 + r.r() * 1.5
		for yy in range(int(cy - rr - 1.0), int(cy + rr + 2.0)):
			for xx in range(int(cx - rr - 1.0), int(cx + rr + 2.0)):
				var d := Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length()
				var cob := clampf(rr + 0.5 - d, 0.0, 1.0)
				if cob > 0.0:
					var px := posmod(xx, 256)
					var py := posmod(yy, 256)
					img.set_pixel(px, py, img.get_pixel(px, py).lerp(c, a * cob))
	return ImageTexture.create_from_image(img)


## O grão do giz: o vermelho é a força do ponto (furo, meio apagado, cheio) e o verde, o brilho.
static func _grao(sem: int) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var r := Fases.Sorteio.new(sem)
	for i in 4096:
		var a := r.r()
		var al := 0.0 if a < 0.13 else ((110.0 + r.r() * 60.0) if a < 0.3 else (205.0 + r.r() * 50.0))
		var v := 0.92 + r.r() * 0.08
		img.set_pixel(i % 64, i >> 6, Color(al / 255.0, v, 0.0, 1.0))
	return ImageTexture.create_from_image(img)
