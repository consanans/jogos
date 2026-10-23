# Jogos

Os jogos independentes do Thales (@consanans), fora do Corre. Os da web estão no ar em
[mougus.com.br](https://mougus.com.br); os em Godot são o caminho pras lojas de app.

| Jogo | Web | Godot | No ar |
|---|---|---|---|
| **Duvido**: desenha uma ladeira com o dedo, desce de carrinho de rolimã e manda o link. | `web/duvido` | `godot/duvido` | mougus.com.br/jogos/duvido |
| **Gambiarra**: monta a tralha da casa pra laranja cair no rádio, e cada batida vira beat. | `web/gambiarra` | `godot/gambiarra` | (ainda não) |
| **Nó**: twister de dedo pra 2 a 4 pessoas no mesmo celular. | `web/no` | (fica na web) | mougus.com.br/jogos/no |

## Godot

Os dois projetos são da **Godot 4.5.1** (a "Standard"). Pra abrir: na Godot, **Importar** e escolher o
`project.godot` da pasta do jogo; **F5** joga. Cada pasta tem o seu `README.md` com tudo: como exportar
pro navegador, Android e iPhone, e como rodar os testes.

- **Duvido:** a física e o código do link são os mesmos da versão web, conta por conta. Um desafio feito
  num abre no outro com o mesmo tempo. O teste (`godot/duvido/tests`) roda o JavaScript de
  `web/duvido/partes` e compara: 432 ok.
- **Gambiarra:** a física é a da Godot, afinada pra ficar no jeito da versão web (que usa o Matter.js).
  As 3 fases têm solução conferida por robô: 63 ok.

O que fica de fora do repositório: o cache da Godot (`.godot/`), os exportados (`build/`), os rascunhos
dos testes (`tmp/`) e as fotos dos testes (`screenshots/`). A Godot refaz o cache sozinha na primeira vez.

## Web

Cada jogo web é uma página só, sem nada pra instalar.

- `web/duvido`: o código em partes (`partes/`); `node monta.mjs` junta tudo no `duvido.html`. Testes no
  Playwright: `teste.cjs` e `teste2.cjs`.
- `web/gambiarra/gambiarra.html`: a página inteira (o Matter.js 0.19.0 vem do cdnjs).
- `web/no`: `no.html` e o teste `teste.cjs`.

As páginas do mougus.com.br são estas com o "← Mougus", o favicon e o título do site em volta.

## Regras da casa

- Nada de verde, em lugar nenhum.
- Som e música compostos ou sintetizados no próprio jogo. As letras usadas têm licença livre (OFL ou
  Apache 2.0) e a licença vai junto, em `assets/fonts`.
- Nada sai do aparelho de quem joga: recorde e configuração ficam guardados nele.
