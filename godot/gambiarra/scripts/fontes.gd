class_name Fontes
## As três letras da versão web: Bungee (letreiro), Permanent Marker (caneta) e Bricolage Grotesque (texto).

static var _cache := {}


static func _base(arq: String) -> FontFile:
	if not _cache.has(arq):
		_cache[arq] = load(arq)
	return _cache[arq]


static func letreiro() -> Font:
	return _base("res://assets/fonts/Bungee-Regular.ttf")


static func caneta() -> Font:
	return _base("res://assets/fonts/PermanentMarker-Regular.ttf")


static func txt(peso := 400) -> Font:
	var k := "txt%d" % peso
	if not _cache.has(k):
		var fv := FontVariation.new()
		fv.base_font = _base("res://assets/fonts/BricolageGrotesque-Variable.ttf")
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = { ts.name_to_tag("wght"): peso, ts.name_to_tag("opsz"): 14 }
		_cache[k] = fv
	return _cache[k]
