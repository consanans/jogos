# Duvido (Godot 4.5)

O Duvido de sempre (desenha a ladeira de giz, desce de rolimã e manda pro amigo: *duvido tu descer essa*),
agora num projeto do **Godot 4.5**, pronto pra virar app de celular.

- **A física é a mesma da versão web, conta por conta.** A mesma ladeira com os mesmos toques dá o mesmo
  resultado aqui e no navegador, no centésimo. Isso foi conferido: 198 descidas (186 mil passos de física)
  e todos os códigos de link batem com a versão web, bit por bit (ver "Testes", embaixo).
- **O código do link é o mesmo.** Um desafio feito no navegador abre no app, e um feito no app abre no
  navegador. Os tempos são comparáveis e o fantasma de quem mandou desce igualzinho.
- **Tudo é desenhado no código** (o asfalto, o giz, o carrinho, o caramelo, a mola, o turbo, a bandeira,
  o confete). Fora as três letras (fontes), não tem imagem nem som de fora: os sons são sintetizados quando
  o jogo abre, com as mesmas receitas da versão web.
- Os textos são os mesmos da versão web, em português.

## Abrir no Godot

1. Baixa o **Godot 4.5** (versão "Standard", não precisa da .NET) em https://godotengine.org/download.
2. Abre o Godot, toca em **Importar**, escolhe o arquivo `project.godot` desta pasta e confirma.
3. Aperta **F5** (ou o ▶ lá em cima) pra jogar no computador. A janela abre em pé, do tamanho de um celular.

Pra ver como fica num celular de verdade sem exportar: no Godot, **Depurar → Implantação remota com um clique**
funciona com Android ligado no cabo (depois de configurar o Android, ver embaixo).

## O que tem em cada pasta

| Pasta / arquivo | O que é |
|---|---|
| `scripts/nucleo.gd` | A física (porte fiel do `nucleo.js`): carrinho, rolimãs, cabeça, pulo, cambalhota, mola, turbo, caramelo, chegada |
| `scripts/codigo.gd` | O código do link (`dv1...`), igual ao `codigo.js` |
| `scripts/fases.gd` | As cinco ladeiras da casa, a Ladeira do Dia (sai da data, igual pra todo mundo) e o piloto robô |
| `scripts/principal.gd` | As telas, a descida, o editor, o desafio, o resultado, a mensagem pro amigo |
| `scripts/mundo.gd`, `lote.gd`, `pincel.gd`, `texturas.gd` | O desenho (o asfalto, o giz, o carrinho...) |
| `scripts/som.gd` | O som sintetizado |
| `scripts/estilo.gd` | Cores, letras, botões e ícones (os mesmos da web; nada de verde) |
| `scripts/dados.gd` | O que fica guardado no aparelho |
| `assets/fonts/` | Bungee e Rubik (licença OFL, `OFL-*.txt`) e Permanent Marker (licença Apache 2.0, `LICENSE-PermanentMarker.txt`; no repositório do Google Fonts ela fica na pasta `apache/`, não na `ofl/`) |
| `tests/` | Os testes (não vão junto quando exporta) |
| `export_presets.cfg` | As configurações de exportação: Web, Android, iOS e Linux |
| `build/web/` | A versão pro navegador, já exportada |

O que o jogo guarda no aparelho (nome, recordes, fantasmas, rascunho do editor, som ligado, a Ladeira do Dia
já conferida) fica num arquivo só, `user://duvido.json`. No navegador, isso fica no próprio navegador.

## Como o link funciona com a versão web

- O desafio vai numa mensagem com o link `https://mougus.com.br/jogos/duvido#dv1...`. O que vem depois do `#`
  é a ladeira inteira (desenho, carimbos, a corrente de nomes e tempos e os toques de quem mandou).
- **Quem não tem o app** toca no link e joga no navegador, na versão web de sempre.
- **Quem tem o app** toca em **Tenho um desafio** e cola a mensagem (ou só o link, ou só o código). O botão
  "Colar o que copiei" pega o que tá copiado no celular.
- **Mandar o desafio** copia a mensagem e tem o botão **Mandar no WhatsApp**, que abre o WhatsApp já com a
  mensagem escrita (é o endereço `https://wa.me/?text=...`).
- A versão do Godot pro navegador (`build/web`) também abre o desafio que vem no `#` do endereço.
- Os recordes de cada ladeira são guardados pela "identidade" do desenho, igual à web.

**Pra depois:** fazer o link abrir direto no app (sem copiar e colar) pede os "App Links" do Android e os
"Universal Links" do iPhone: dois arquivinhos no site mougus.com.br (`assetlinks.json` e
`apple-app-site-association`) e uma configuração no app. Ainda não foi feito.

## Exportar

No Godot: **Projeto → Exportar...**, escolhe a configuração e toca em **Exportar projeto**.
Os modelos de exportação (export templates) do Godot 4.5.1 precisam estar instalados
(**Editor → Gerenciar modelos de exportação → Baixar e instalar**).

### Web (navegador)

- Já tem um exportado em `build/web/` (uns 38 MB; o grosso é o motor, `index.wasm`).
- Sobe **a pasta inteira** pra um servidor (por exemplo `mougus.com.br/jogos/duvido-app/`). Abre pelo `index.html`.
- Foi exportado **sem threads**, então funciona em qualquer servidor, sem cabeçalho especial.
- Se o servidor compactar `.wasm` com gzip ou brotli, o download cai pra uns 9 MB.
- Pra testar no computador: `python3 -m http.server 8765 --directory build/web` e abre `http://127.0.0.1:8765`.

### Android (Google Play)

O que precisa:
- **Android Studio** (ou só o Android SDK) e o **JDK 17**. No Godot: **Editor → Configurações do Editor →
  Exportar → Android**, aponta onde ficou o SDK e o Java.
- Uma **keystore** (a "assinatura" do app). A de teste o Godot cria; a de verdade, pra loja, tu cria uma vez e
  guarda muito bem (sem ela não dá pra atualizar o app nunca mais).
- Uma conta de desenvolvedor no **Google Play Console** (pagamento único de US$ 25).
- A Play Store pede o formato **AAB**: na configuração Android, liga **Gradle Build → Use Gradle Build** e
  escolhe o formato AAB (o Godot instala o modelo Android na primeira vez).

Já configurado: nome **Duvido**, pacote `br.com.mougus.duvido`, em pé, tela cheia, permissão de vibrar
(o celular treme quando capota) e os ícones (`assets/icone/`, feitos do `icon.svg`).

Aqui nesta máquina não tem Android SDK, então o APK não foi gerado.

### iOS (App Store)

O que precisa:
- Um **Mac com Xcode** (não tem jeito: app de iPhone só sai de um Mac).
- A conta do **Apple Developer Program** (US$ 99 por ano) e o **Team ID** dela (vai em
  "App Store Team ID" na configuração iOS).
- Os modelos de exportação do Godot pra iOS.

Já configurado: identificador `br.com.mougus.duvido`, versão 1.0.0, iPhone e iPad.
O Godot gera um projeto do Xcode; dali se assina e se manda pra App Store.
Aqui não dá pra gerar (não é um Mac e não tem o modelo iOS).

### Linux

A configuração `Linux` gera um executável só (`build/linux/duvido.x86_64`), bom pra testar.

## Testes

1. **A física e o código do link contra a versão web** (o mais importante):
   ```
   node tests/gera_esperado.mjs ../../web/duvido/partes > tests/esperado.json
   godot --headless --path . --import
   godot --headless --path . -s res://tests/testa_nucleo.gd
   ```
   O primeiro roda o JavaScript da versão web (as partes em `../../web/duvido/partes`) e grava o que tem que dar:
   o código de cada ladeira, as cinco da casa e a Ladeira do Dia de 9 datas, cada descida (sem tocar, com o robô
   e com toques sorteados) com a posição a cada segundo, os códigos de desafio com nome acentuado, corrente
   comprida e fantasma, os códigos quebrados e o nome limpo. O segundo roda tudo de novo no Godot e compara.
   Resultado de hoje: **432 ok, 0 falharam**.
2. **A versão do navegador, de verdade** (Playwright, num celular de toque e num computador):
   ```
   python3 -m http.server 8765 --directory build/web &
   node tests/web.cjs cel 8765      # celular de toque, 390 x 844
   node tests/web.cjs pc 8765       # computador, 1366 x 860
   node tests/web.cjs p320 8765     # celular pequeno, 320 x 568
   ```
   Liga, toca numa ladeira, o carrinho anda, pula, capota (CAPOTOU!), recomeça, abre o editor, risca, põe a
   bandeira, desfaz, dá cambalhota (e a mesma descida, com os toques gravados no Godot, dá o mesmo tempo no
   JavaScript da web), pede o nome (com acento), monta a mensagem com o link, copia, abre o WhatsApp, o código
   feito no Godot abre no JavaScript da web com o fantasma chegando no mesmo centésimo, e o link com `#código`
   feito na web abre o desafio. As fotos ficam em `screenshots/` (`web-cel-*`, `web-pc-*`, `web-p320-*`; as `godot-cel-*` saíram do roteiro, embaixo).
   O teste usa o Chrome sem placa de vídeo (desenho por software), então o jogo roda a poucos quadros por
   segundo ali; isso não diz nada sobre a velocidade num celular de verdade.
3. **Roteiro com tela** (fotos e medidas no motor, no Linux com Xvfb; os passos estão em `tests/roteiro.gd`
   e `scripts/comandos.gd`, e só rodam quando o `--roteiro` é passado):
   `godot --path . --resolution 390x844 -- "--roteiro=espera:2;joga:0;espera:3;foto:descendo;perf;sai" --fotos=$PWD/tmp`

## Diferenças da versão web

- O "menos movimento" do celular (acessibilidade) não chega no Godot: as animações rodam sempre.
- Não tem leitor de tela nem a navegação pelo Tab com o contorno amarelo nos botões (a web tem).
- Rolar os cartões arrastando o dedo funciona, mas sem o embalo (para onde o dedo larga).
- O botão "Compartilhar" do navegador virou **Mandar no WhatsApp** (no app, o WhatsApp é o caminho de todo mundo).
- Na tela de colar o desafio tem um botão a mais, **Colar o que copiei**.
