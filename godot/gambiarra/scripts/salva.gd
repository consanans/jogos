class_name Salva
## O que fica guardado no aparelho: a fase, o som, os recordes e quais introduções já foram vistas.

const ARQ := "user://gambiarra.cfg"
static var _cfg: ConfigFile = null


static func _abre() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(ARQ)
	return _cfg


static func le(chave: String, padrao: Variant = null) -> Variant:
	return _abre().get_value("gambiarra", chave, padrao)


static func guarda(chave: String, valor: Variant) -> void:
	var c := _abre()
	c.set_value("gambiarra", chave, valor)
	c.save(ARQ)


static func esquece_tudo() -> void:
	_cfg = ConfigFile.new()
	_cfg.save(ARQ)
