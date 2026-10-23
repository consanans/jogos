class_name Dados
## O que não muda: o tamanho do cômodo, as fases, a tralha, os instrumentos e os textos.
## Tudo copiado da versão web (gambiarra.html), com o mesmo português.

const W := 640.0
const H := 900.0
const CHAO := 870.0

# o compasso: 124 batidas por minuto, 4 semicolcheias por batida, a volta do beat tem 32
const BPM := 124.0
const S16 := 60.0 / BPM / 4.0          # segundos por semicolcheia
const VOLTA := 32
const P16 := 60.0 * S16               # passos de física (60 por segundo) por semicolcheia
const PB := 4.0 * P16                 # passos de física por batida
const FESTA_PASSOS := 96              # a comemoração antes do cartão do fim (1,6 s)

# ---------- as fases ----------
# cada fixo: [chave, x, y, largura, altura, opções]  (a = ângulo, atr = atrito, ch = canto arredondado, sensor)
const FASES: Array[Dictionary] = [
	{ "n": 1, "lugar": "A cozinha", "nome": "Liga o rádio", "alvoNome": "o rádio", "antes": "do rádio", "ligou": "Ligou o rádio!",
		"rec": "recorde-1", "visto": "intro-1",
		"ini": Vector2(34, 142), "vx": 2.0, "centro": Vector2(300, 470), "pedido": [], "levada": 0,
		"caixa": { "tabua": 3, "colchao": 1, "bacia": 1, "lata": 2, "garrafa": 3, "gangorra": 1, "ventilador": 1, "gato": 1 },
		"fixos": [
			["prateleira", 95, 172, 190, 14, { "a": 0.12, "atr": 0.2, "id": "prat" }],
			["armario", 345, 300, 200, 110, {}],
			["filtro", 413, 207, 46, 76, { "ch": 12 }],
			["pia", 150, 805, 300, 130, {}],
			["botijao", 420, 834, 54, 72, { "ch": 12 }],
			["prateleira", 555, 612, 170, 14, { "id": "prat2" }],
			["radio", 553, 577, 118, 56, { "ch": 8, "id": "alvo" }],
			["tecla", 553, 545, 84, 10, { "sensor": true, "id": "tecla" }],
		],
		"aria": "A cozinha: a laranja na prateleira de cima e o rádio na prateleira da direita",
		"intro": { "titulo": "GAMBIARRA", "lead": "Leva a laranja até o rádio usando a tralha da casa.",
			"passos": ["[b]Arrasta[/b] a tralha da caixa pra cozinha. Toca numa peça pra girar ou devolver.", "Aperta [b]VAI![/b] e torce.", "A laranja tem que cair em cima do rádio. Aí ele liga."],
			"regra": "Cada coisa que a corrente encosta vale ponto, e quanto mais peça na corrente, mais vale. O caminho mais doido ganha. E cada batida vira batida: o rádio toca o beat que a tua gambiarra fez." } },
	{ "n": 2, "lugar": "A laje", "nome": "Liga o som", "alvoNome": "a caixa de som", "antes": "da caixa de som", "ligou": "Ligou o som!",
		"rec": "recorde-2", "visto": "intro-2",
		"ini": Vector2(38, 110), "vx": 2.0, "centro": Vector2(240, 380), "pedido": ["surdo", "agogo", "cuica", "latido"], "levada": 0,
		"caixa": { "tabua": 2, "telha": 2, "pneu": 1, "bacia": 1, "garrafa": 3, "gangorra": 1, "ventilador": 1, "caramelo": 1 },
		"fixos": [
			["caixadagua", 85, 140, 146, 12, { "a": 0.14, "atr": 0.2, "id": "tampa" }],
			["caixadagua", 85, 205, 130, 120, { "ch": 16 }],
			["tijolo", 85, 568, 80, 604, {}],
			["churrasqueira", 215, 816, 100, 108, { "ch": 10 }],
			["bloco", 330, 680, 56, 380, {}],
			["engradado", 550, 800, 110, 140, {}],
			["caixasom", 550, 672, 96, 116, { "ch": 8, "id": "alvo" }],
			["tecla", 550, 609, 70, 10, { "sensor": true, "id": "tecla" }],
		],
		"aria": "A laje: a laranja em cima da caixa d’água e a caixa de som em cima dos engradados",
		"intro": { "titulo": "A LAJE", "lead": "Fase 2. Ninguém sabe como, mas a laranja foi parar em cima da caixa d’água. Leva ela até a caixa de som do churrasco.",
			"passos": ["Tralha nova: a [b]telha[/b] faz a laranja correr na curva, o [b]pneu[/b] quica e rola, e o [b]caramelo[/b] dorme até alguém passar perto. Aí acorda latindo e sai correndo.",
				"O churrasco pede um som com [b]surdo, agogô, cuíca e latido[/b]. Cada um que a corrente tocar vale ponto, e os quatro juntos multiplicam tudo por 1,5.",
				"A laranja tem que cair em cima da caixa de som. Aí ela liga."],
			"regra": "Surdo é a bacia, agogô é a PET, cuíca é a gangorra e latido é o caramelo." } },
	{ "n": 3, "lugar": "A garagem", "nome": "O ensaio", "alvoNome": "o amplificador", "antes": "do amplificador", "ligou": "Ligou o amplificador!",
		"rec": "recorde-3", "visto": "intro-3",
		"ini": Vector2(606, 143), "vx": -2.0, "centro": Vector2(330, 380), "pedido": [], "levada": 4,
		"caixa": { "tabua": 2, "telha": 1, "lata": 2, "garrafa": 3, "colchao": 1, "pneu": 1, "limpador": 2, "balde": 2 },
		"fixos": [
			["prateleira", 535, 175, 210, 14, { "a": -0.12, "atr": 0.2, "id": "prat" }],
			["carro", 330, 700, 210, 90, { "ch": 40 }],
			["carro", 335, 790, 370, 100, { "ch": 30 }],
			["carro", 215, 846, 50, 48, { "ch": 22 }],
			["carro", 455, 846, 50, 48, { "ch": 22 }],
			["bancada", 75, 735, 150, 270, {}],
			["amp", 72, 555, 104, 90, { "ch": 6, "id": "alvo" }],
			["tecla", 72, 505, 64, 10, { "sensor": true, "id": "tecla" }],
		],
		"aria": "A garagem: a laranja na prateleira da direita e o amplificador em cima da bancada",
		"intro": { "titulo": "A GARAGEM", "lead": "Fase 3. A banda do bairro ensaia na garagem do vô e tá sem baterista. A laranja tem que ligar o amplificador, e a gambiarra tem que segurar o tempo.",
			"passos": ["Tralha nova: o [b]limpador[/b] de para-brisa só liga quando a corrente encosta nele. Aí vai e volta uma vez por batida, sempre no tempo. O [b]balde[/b] de tinta virado é a bateria.",
				"O pisca-alerta do carro do vô marca o tempo. A banda pede uma [b]levada[/b]: 4 batidas no tempo, uma atrás da outra. O que estiver no fim da varrida do limpador apanha no tempo certinho.",
				"A laranja tem que cair em cima do amplificador. Aí ele liga."],
			"regra": "Cada batida da corrente que cai no tempo vale ponto. A levada completa multiplica tudo por 1,5." } },
]

# ---------- a tralha ----------
const TIPOS := {
	"tabua": { "nome": "Tábua", "min": "tábua", "curto": "Tábua", "gira": true, "vira": false, "pts": 5, "txt": "Tábua (o básico)" },
	"colchao": { "nome": "Colchão", "min": "colchão", "curto": "Colchão", "gira": true, "vira": false, "pts": 15, "txt": "Boing!" },
	"bacia": { "nome": "Bacia", "min": "bacia", "curto": "Bacia", "gira": true, "vira": false, "pts": 10, "txt": "Caiu na bacia" },
	"lata": { "nome": "Lata", "min": "lata", "curto": "Lata", "gira": false, "vira": false, "pts": 10, "txt": "Lata rolando" },
	"garrafa": { "nome": "Garrafa PET", "min": "garrafa PET", "curto": "PET", "gira": true, "vira": false, "pts": 10, "txt": "Esbarrou na PET" },
	"gangorra": { "nome": "Gangorra", "min": "gangorra", "curto": "Gangorra", "gira": false, "vira": false, "pts": 15, "txt": "Gangorra" },
	"ventilador": { "nome": "Ventilador", "min": "ventilador", "curto": "Ventilador", "gira": true, "vira": false, "pts": 20, "txt": "Soprou!" },
	"gato": { "nome": "Gato", "min": "gato", "curto": "Gato", "gira": false, "vira": true, "pts": 30, "txt": "Assustou o gato" },
	"telha": { "nome": "Telha", "min": "telha", "curto": "Telha", "gira": true, "vira": false, "pts": 10, "txt": "Desceu na telha" },
	"pneu": { "nome": "Pneu", "min": "pneu", "curto": "Pneu", "gira": false, "vira": false, "pts": 15, "txt": "Pneu velho" },
	"caramelo": { "nome": "Caramelo", "min": "caramelo", "curto": "Caramelo", "gira": false, "vira": true, "pts": 30, "txt": "Acordou o caramelo" },
	"limpador": { "nome": "Limpador", "min": "limpador", "curto": "Limpador", "gira": true, "vira": false, "pts": 20, "txt": "Ligou o limpador" },
	"balde": { "nome": "Balde", "min": "balde", "curto": "Balde", "gira": true, "vira": false, "pts": 10, "txt": "Batucou no balde" },
}

# ---------- os instrumentos: nome que aparece e a cor na grade do beat ----------
const INFO := {
	"bumbo": ["bumbo", "#E6D29B"], "surdo": ["surdo", "#5B8FE0"], "caixa": ["caixa", "#F0584F"], "tamborim": ["tamborim", "#D9A066"],
	"agogo": ["agogô", "#FFC531"], "grave": ["grave", "#A47BE0"], "cuica": ["cuíca", "#F06A9B"], "chocalho": ["chocalho", "#B9BEC6"],
	"miau": ["miau", "#F59A45"], "prato": ["prato", "#7CC0F0"], "udu": ["udu", "#D9784A"], "reco": ["reco-reco", "#FF8A65"],
	"latido": ["latido", "#E8B07A"], "balde": ["balde", "#F4F1EA"],
}
const ORDEM_INST := ["bumbo", "surdo", "caixa", "tamborim", "agogo", "grave", "cuica", "chocalho", "miau", "prato", "udu", "reco", "latido", "balde"]

# cada material soa como um instrumento
const SOM := {
	"tabua": "tamborim", "prateleira": "tamborim", "radio": "tamborim", "colchao": "grave", "bacia": "surdo", "lata": "caixa", "armario": "caixa",
	"garrafa": "agogo", "gangorra": "cuica", "ventilador": "chocalho", "gato": "bumbo", "chao": "bumbo", "parede": "bumbo", "teto": "bumbo",
	"pia": "bumbo", "filtro": "udu", "botijao": "prato", "telha": "reco", "pneu": "grave", "caramelo": "bumbo", "caixadagua": "udu",
	"tijolo": "tamborim", "churrasqueira": "prato", "bloco": "caixa", "engradado": "tamborim", "caixasom": "bumbo", "limpador": "tamborim",
	"balde": "balde", "carro": "surdo", "bancada": "tamborim", "amp": "bumbo", "laranja": "bumbo",
}

const FIXO_PTS := {
	"armario": [5, "No armário"], "filtro": [10, "Filtro de barro"], "botijao": [10, "No botijão (calma)"], "pia": [5, "Na pia"], "teto": [15, "No teto!"],
	"churrasqueira": [10, "Na churrasqueira"], "bloco": [5, "No muro"], "engradado": [5, "No engradado"], "tijolo": [5, "Na torre de tijolo"],
	"carro": [10, "No carro do vô"], "bancada": [5, "Na bancada"],
}
const QUEM := {
	"limpador": [40, "O limpador ligou o amplificador"], "gato": [60, "O gato ligou o rádio"], "caramelo": [60, "O caramelo ligou o som"],
	"lata": [20, "Foi a lata que ligou"], "garrafa": [20, "Foi a PET que ligou"], "pneu": [20, "Foi o pneu que ligou"],
}

# ---------- cores da casa ----------
const MOLDURA := Color("#1C1613")
const FITA := Color("#E6D29B")
const FITA2 := Color("#CDB676")
const TINTA := Color("#1F1915")
const TINTA2 := Color("#5B4E44")
const PAPEL := Color("#FBF6EA")
const LARANJA := Color("#F07A1C")
const VAI := Color("#FFC531")
const VAI2 := Color("#A97C00")
const PERIGO := Color("#D7342B")
const PERIGO2 := Color("#7D1A14")
const AZULEJO := Color("#2D5DA6")
const CLARO := Color("#F3EBDD")
const LINHA := Color("#2A1F1A")


static func mult_de(n: int) -> float:
	return 1.0 + 0.25 * (n - 1) if n > 0 else 1.0


static func virgula(x: float) -> String:
	return ("%.2f" % x).replace(".", ",")
