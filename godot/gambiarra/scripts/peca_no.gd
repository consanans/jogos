class_name PecaNo
extends Node2D
## O desenho de uma peça (ou da laranja) num nó só dela: o palco move o nó a cada quadro e o desenho
## só é refeito quando a cara da peça muda.

var peca: Peca = null           # null: é a laranja
var palco: Palco
var _chave := "?"


func atualiza(t: float, rodando: bool, passos: int, reduz: bool, px: float) -> void:
	var xf: Transform2D
	var k := ""
	if peca == null:
		var j := palco.jogo
		if j.laranja != null and is_instance_valid(j.laranja):
			xf = j.laranja.global_transform
		else:
			xf = Transform2D(0.0, j.fase.ini)
		k = "laranja"
	else:
		xf = Pinta.pose_no(peca)
		k = Pinta.chave(peca, t, rodando, passos, reduz)
	transform = xf
	k += "|%.3f" % px
	if k != _chave:
		_chave = k
		queue_redraw()


func _draw() -> void:
	var px := palco.esc * maxf(1.0, palco.escala_tela())
	var c := Ctx.new(self, Transform2D.IDENTITY, px)
	if peca == null:
		Pinta.laranja(c)
	else:
		var j := palco.jogo
		Pinta.peca_local(c, peca, palco._t(), j.rodando(), j.passos, palco.reduz)
