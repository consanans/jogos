# Gambiarra (versão Godot)

Este é o **Gambiarra** passado da página web (que usava a física do Matter.js) para a **Godot 4.5**,
um motor de jogos gratuito e de código aberto. Com a Godot o mesmo projeto vira jogo para
navegador, Android, iPhone, Windows, Linux (e Steam), sem reescrever nada.

O jogo é o mesmo: arrastar a tralha da caixa pro cômodo, girar ou devolver as peças, apertar
**VAI!** e torcer pra laranja cair em cima do rádio (ou da caixa de som, ou do amplificador).
Cada coisa que a corrente encosta vale ponto, e cada batida vira batida: no fim o alvo toca o beat
que a tua gambiarra fez, em volta, com a grade dos instrumentos.

## O que tem

- As 3 fases: **A cozinha** (liga o rádio), **A laje** (o churrasco pede surdo, agogô, cuíca e
  latido) e **A garagem** (o limpador bate no tempo e a banda pede uma levada de 4).
- Toda a tralha: tábua, colchão, bacia, lata, garrafa PET, gangorra, ventilador, gato, telha, pneu,
  caramelo, limpador e balde, cada um com o seu instrumento.
- O cartão de introdução de cada fase, o menu das fases (tocando no nome GAMBIARRA lá em cima),
  o placar em fita crepe com a corrente e o multiplicador, os pontos subindo, o cartão do fim
  (FUNCIONOU!/PAROU., o total, o recorde, a conta, a grade do beat com "Pausar", "Mexer de novo",
  "Do zero", a próxima fase), o botão do som e os recordes guardados no aparelho.
- Todos os sons são **sintetizados quando o jogo abre** (as mesmas receitas da versão web: bumbo,
  surdo, caixa, tamborim, agogô, grave, cuíca, chocalho, miau, prato, reco-reco, latido, balde, udu,
  e o baixo, o chiado e a guitarra do groove de cada fase). Nenhum arquivo de som.
- Tudo é desenhado por código (cozinha com azulejo, laje, garagem, as peças), sem imagem nenhuma.
  As letras são Bungee, Permanent Marker e Bricolage Grotesque (em `assets/fonts`, com as licenças).
- Funciona com dedo (celular) e mouse; no computador também tem teclado: setas mexem a peça
  escolhida (Shift anda mais), Q e E giram, Delete devolve, Esc fecha.

## Como abrir no computador

1. Baixe a **Godot 4.5.1** (versão "Standard", não precisa da ".NET") em
   <https://godotengine.org/download>. É um programa só, não precisa instalar.
2. Abra a Godot. Na tela "Gerenciador de Projetos", clique em **Importar** e escolha o arquivo
   `project.godot` desta pasta.
3. Com o projeto aberto, aperte **F5** (ou o botão ▶ lá em cima) pra jogar.

Para ver como fica no celular dentro do computador: no menu da Godot, em
*Projeto → Configurações do Projeto → Exibição → Janela*, troque o tamanho da janela de teste
(está 540 × 960).

## Como as coisas estão organizadas

| Pasta / arquivo | O que é |
|---|---|
| `cenas/main.tscn` | a tela do jogo (tudo é montado pelo `scripts/main.gd`) |
| `scripts/dados.gd` | as fases, a tralha, os pontos, os textos (é aqui que se cria fase nova) |
| `scripts/jogo.gd` | a física e as regras: corrente, pontos, pedido, levada, o fim |
| `scripts/peca.gd` | o formato de cada peça (igual ao da versão web) |
| `scripts/cenas.gd`, `scripts/pinta.gd` | os desenhos dos cômodos, das peças e dos alvos |
| `scripts/som.gd`, `scripts/sintese.gd` | a síntese dos instrumentos e o beat em volta |
| `scripts/palco.gd`, `scripts/main.gd`, `scripts/ui/` | a tela: arrastar, girar, cartões, placar |
| `tests/` | os testes automáticos |
| `export_presets.cfg` | as exportações prontas: Web, Android, iOS, Linux e Windows |
| `build/web/` | a versão web já exportada |

Os números do "jeitão" da física ficam no começo do `scripts/jogo.gd` (a lista `AJ`): quanto cada
coisa quica, o atrito da laranja e quanto ela segura pra rolar.

## Os testes

- **Sem tela** (confere cada fase com uma gambiarra que funciona, 3 vezes cada):
  `godot --headless --path . --fixed-fps 60 -s res://tests/teste_fases.gd`
- **Versão web num navegador de verdade** (precisa do Node e do Playwright): sirva a pasta
  `build/web` (por exemplo `python3 -m http.server 8060 --directory build/web`) e rode
  `node tests/web_teste.cjs` (ele abre a página com `?teste=1` no endereço, que liga uma ponte só
  pros testes; sem isso o jogo não fala com a página). Ele abre como celular e como computador, arrasta uma peça, aperta VAI!
  e tira fotos em `screenshots/`.

## Como exportar

Em qualquer caso, a Godot precisa dos **modelos de exportação** (uma vez só):
*Editor → Gerenciar Modelos de Exportação → Baixar e Instalar*.
Depois é *Projeto → Exportar…*, escolher a plataforma (já estão todas configuradas) e
**Exportar Projeto**.

### Web (navegador, itch.io, site próprio)
- Não precisa de conta nenhuma. A exportação gera `index.html`, `index.js`, `index.wasm`,
  `index.pck` e uns ícones; é só subir a pasta inteira num site (Netlify, itch.io, GitHub Pages…).
- A versão está **sem threads**, então funciona em qualquer servidor, sem configuração especial.
- O `index.wasm` tem uns 38 MB (é o motor da Godot); com compressão gzip/brotli no servidor cai pra
  uns 9 MB. Netlify e itch.io comprimem sozinhos.
- Já tem uma exportada em `build/web/`.

### Android (Google Play)
- Precisa instalar o **Android Studio** (que traz o Android SDK) e o **Java JDK 17**. Na Godot, em
  *Editor → Configurações do Editor → Exportação → Android*, aponte onde ficou o SDK.
- O identificador do app já está `br.com.mougus.gambiarra`, em pé (retrato).
- Para testar no celular, a Godot cria sozinha uma chave de teste (debug).
- Para a **Google Play**: criar a conta de desenvolvedor no Google Play Console (taxa única de
  US$ 25), criar uma chave de assinatura de lançamento (keystore) e configurar no preset Android;
  a Play exige o formato **AAB** (no preset: ligar "Usar build Gradle" e exportar como AAB).

### iPhone / iPad (App Store)
- Precisa de um **Mac com o Xcode** e de uma conta **Apple Developer** (US$ 99 por ano).
- No preset iOS, preencher o *App Store Team ID* (aparece na conta da Apple). O identificador já
  está `br.com.mougus.gambiarra`.
- A Godot gera um projeto do Xcode; no Xcode é que se assina e manda pra App Store
  (TestFlight pra testar antes).

### Steam (Windows e Linux)
- Precisa de uma conta **Steamworks** (taxa de US$ 100 por jogo) e de preencher a página da loja.
- Exportar com os presets **Windows** e **Linux** (os dois prontos) e subir os arquivos pelo
  SteamPipe (ferramenta `steamcmd` da Valve).
- Conquistas, nuvem da Steam etc. são opcionais; quando quiser, o jeito comum na Godot é o
  complemento gratuito **GodotSteam**.
- No computador o jogo abre numa janela em pé; dá pra deixar em tela cheia ou deitado depois.

## O que é diferente da versão web

- A física é a da Godot, não a do Matter.js. Os números foram acertados comparando as duas lado a
  lado (a laranja rolando na prateleira, o quique do colchão, do pneu e do chão, a gangorra, a telha,
  o vento, o gato, o caramelo), e as médias de pontos e corrente em 450 gambiarras sorteadas ficaram
  quase iguais. Mas uma gambiarra "no limite" que funciona numa pode não funcionar na outra: as
  soluções dos testes foram as da web com uns poucos pixels de ajuste.
- A laranja sai da prateleira da cozinha um pouquinho mais de lado que na web e às vezes raspa
  no armário ("No armário +5").
- Os sons são as mesmas receitas, mas cada um é gravado uma vez quando o jogo abre (na web cada
  batida era sintetizada na hora): o tempo das batidas durante a corrida depende do quadro da tela
  (até ~16 ms de diferença); o beat do fim é montado inteiro e fica certinho.
- "Reduzir movimento" do aparelho: na versão web exportada continua valendo (os pontos não sobem,
  o ventilador não gira, sem fumaça); nos apps (Android, iPhone, computador) a Godot não tem como
  saber dessa opção, então as animações ficam sempre ligadas.

## Licenças das letras

- Bungee e Bricolage Grotesque: SIL Open Font License (arquivos `*-OFL.txt`).
- Permanent Marker: Apache License 2.0 (arquivo `PermanentMarker-LICENSE.txt`).
