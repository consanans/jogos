class_name Dados
extends RefCounted
## O que fica guardado no aparelho (user://): o nome, os recordes, o fantasma de cada recorde,
## o rascunho do editor, o som ligado ou não, a ladeira do dia já conferida e o tempo da casa.

const ARQ := "user://duvido.json"
static var d: Dictionary = {}
static var _sujo := false


static func carrega() -> void:
	d = {}
	if FileAccess.file_exists(ARQ):
		var f := FileAccess.open(ARQ, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				d = j


static func le(k: String, padrao = null) -> Variant:
	var v = d.get(k, null)
	return padrao if v == null else v


static func guarda(k: String, v) -> void:
	d[k] = v
	_sujo = true


## Grava de verdade (o jogo chama de tempos em tempos e ao sair).
static func salva(forca := false) -> void:
	if not _sujo and not forca:
		return
	_sujo = false
	var f := FileAccess.open(ARQ, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()
