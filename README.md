###

Background (TileMapLayer)

É o fundo da fase.

Por exemplo:

🌑 céu escuro
🌙 lua
🏔️ montanhas distantes

Normalmente o jogador não interage com isso. É apenas visual.
###

DecorationsBack (TileMapLayer)

São decorações que ficam atrás do Mario, mas na frente do fundo.

Por exemplo:

🌑 Background
      ↓
🌳 árvore distante
🏚️ casa no fundo
🌿 arbustos
      ↓
🍄 MARIO

Elas ajudam a deixar o cenário mais detalhado, mas geralmente não possuem colisão.
###
Ground (TileMapLayer)

Essa é uma das mais importantes.

É onde você pinta as coisas que fazem parte do chão/plataformas da fase:

        Mario
          🍄
          ↓
🟫🟫🟫🟫🟫🟫
     Ground

Aqui entrariam, por exemplo:

chão;
plataformas;
blocos;
paredes;
tubos, caso devam ter colisão.

E é principalmente aqui que vamos aproveitar a Physics Layer que você configurou no TileSet.

Ou seja:

Tile do chão
     ↓
Physics Layer do TileSet
     ↓
possui colisão
     ↓
Mario não atravessa
###

DecorationsFront (TileMapLayer)

São objetos que aparecem na frente do Mario.

Imagine Mario passando atrás de uma planta:

        🌳 ← DecorationsBack

        🍄 ← Mario

        🌿 ← DecorationsFront

A DecorationsFront pode esconder parcialmente o personagem.

No seu jogo de terror, isso pode ser bem interessante. Por exemplo, você pode colocar folhagens, sombras, galhos ou objetos escuros na frente da câmera, deixando a fase mais claustrofóbica.
## Mario e camera das fases

As duas fases incluem `HorrorParallax`, uma cena compartilhada com ceu noturno, ruinas, arvores secas, cemiterio e nevoa animada. Ceu, silhuetas distantes e silhuetas proximas deslizam em velocidades diferentes quando a camera acompanha Mario. A repeticao horizontal e a escala se ajustam ao tamanho da janela. A fase 1 usa tons avermelhados e a fase 2 uma paleta fria esverdeada; as cores podem ser ajustadas no Inspetor da instancia `HorrorParallax`. A nevoa pausa durante a morte, e cada fase restaura seu proprio fundo ao reiniciar.

Validacao do parallax, redimensionamento, pausa e reinicio: `godot --headless --path . --script res://tests/horror_parallax.gd`. Para salvar capturas das duas fases em `.godot`, execute sem `--headless` e acrescente `-- --capture`.

`cenas/level_01.tscn` e `cenas/level_02.tscn` incluem seu proprio Mario e podem ser executadas diretamente com F6. Para mudar o ponto inicial e o respawn, mova o marcador `PlayerSpawn` da fase.

A camera fica dentro de `Mario/Camera2D`. Ao iniciar a fase, seus limites sao calculados a partir dos tiles usados em `Mundo`, incluindo a agua. Ela acompanha o Mario sem mostrar alem das bordas do mapa. O zoom se ajusta quando a janela e maior que o mapa; `Base Zoom` permite ajustar o zoom desejado no Inspetor da camera. A cena `main` troca a fase inteira, usando o Mario e a camera da nova fase.

Validacao das fases e camera: `godot --headless --path . --script res://tests/level_camera.gd`.

O corpo e a area de dano do Mario usam caixas fixas de 28x40 pixels, centradas em `(0, 6)`, correspondendo ao corpo parado em escala 2. Os pes ficam em `y=26`. Pisoes e entrada na agua usam a posicao real dos pes; a consulta da agua ocorre 2 pixels dentro do colisor.

Os frames, recortes, margens, ordem, FPS e loops montados no editor sao preservados. O script seleciona `small_idle` para parado, `small_walk` para caminhada, `small_jump` para subida e `small_fall` para descida em terra; se `small_fall` nao existir, usa a pose `small_jump` tambem na descida. Dentro da agua, A/D seleciona `small_swim_sides`; S seleciona `small_swim_down` e acelera o mergulho. Sem movimento lateral, o afundamento natural tambem usa `small_swim_down`. O Mario conserva a ultima direcao ao parar.

Validacao das caixas: `godot --headless --path . --script res://tests/mario_collisions.gd`.
Validacao das animacoes: `godot --headless --path . --script res://tests/mario_animations.gd`.

## Morte do Mario

Quando as tres vidas acabam, Mario inicia a morte classica: inicia a animacao `mario_death`, espera por um instante, salta verticalmente e cai atravessando o cenario. Contato com perigos ou queda abaixo do mapa tambem iniciam essa sequencia diretamente. O mundo fica pausado durante a sequencia, os comandos ficam bloqueados, ele nao coleta moedas e a camera permanece fixa. Ao sair da tela, espera brevemente e reinicia a fase atual no `PlayerSpawn`, restaurando tres vidas, inimigos, moedas e blocos. Morrer na fase 2 reinicia a fase 2; tambem funciona executando cada fase diretamente com F6.

No Inspetor do Mario, o grupo `Morte` permite ajustar a pausa inicial, o impulso do salto, a gravidade e o atraso do reinicio. Os frames, a velocidade e o loop da morte sao os da animacao `mario_death` em `Mario/Animacao`, editaveis no recurso SpriteFrames de `mario.tscn`. A animacao continua durante a pausa do mundo e o salto de morte, e termina ao renascer. As fases configuram automaticamente `Fall Death Y` abaixo da borda inferior do mapa.

Validacao da morte e reinicio: `godot --headless --path . --script res://tests/mario_death.gd`.

## Moedas coletaveis

Arraste `cenas/coin.tscn` para qualquer fase e duplique as instancias onde quiser colocar moedas. A raiz `Coin` e uma `Area2D` com `AnimatedSprite2D` e `CollisionShape2D`. Ela gira usando os seis quadros de `Cenario/coin.png` e monitora apenas corpos da camada do jogador que pertencem ao grupo `player`, ao qual o Mario se registra automaticamente.

Ao encostar no Mario, a moeda desativa a coleta, sobe 10 pixels e desaparece gradualmente em 0,24 segundos, sendo removida ao final. `Collect Rise` e `Collect Duration` permitem ajustar o efeito no Inspetor. Cada moeda emite `collected(player)` uma unica vez, permitindo conectar um contador futuramente.

Validacao da coleta: `godot --headless --path . --script res://tests/coins.gd`.

## Agua e lava

As duas fases usam os recortes precisos de `Cenario/UndergroundLava.png`: lava com bolhas e agua azul com espuma. As regioes e os TileSets ficam em `Cenario/liquids`, com os pixels ampliados em 2x e filtro Nearest. As areas pintadas, o nado e as camadas de colisao anteriores sao preservados. A fase 2 possui a paleta de agua nova disponivel, embora sua camada de agua esteja vazia.

Para pintar lava, selecione `Mundo/Lava` (perigo) ou `Mundo/LavaGround` (fase 1, mesma colisao de obstaculo anterior). Para agua, use `Mundo/agua`: os quatro tiles da linha 5 sao a superficie; o tile `(9, 6)` e o preenchimento. Detalhes dos recortes em `Cenario/liquids/README.md`.

As superficies agora animam quatro quadros dos sprites: agua a 5 fps e lava a 8 fps. Os tiles vizinhos mantem fases consecutivas para as ondas fluirem. Em cada camada, **Animação → Animation Fps** ajusta a velocidade no Inspetor. A animacao pausa durante a morte e reinicia com a fase, sem mover ou reconstruir os colisores.

Validacao da animacao, continuidade, pausa e reinicio: `godot --headless --fixed-fps 60 --path . --script res://tests/liquid_animation.gd`.

Validacao do nado, cobertura dos tiles e colisao real da lava: `godot --headless --fixed-fps 60 --path . --script res://tests/liquid_tiles.gd`.

## Plataformas que caem

As plataformas laranjas das duas fases possuem colisao somente no topo, com passagem por baixo e pelas laterais. O teto sustentado por pilares na fase 2 tambem permite atravessar subindo e sustenta o Mario e os inimigos por cima, na altura da imagem.

Validacao da passagem por baixo e do pouso nas 11 plataformas e nos 23 tiles do teto: `godot --headless --fixed-fps 60 --path . --script res://tests/one_way_platforms.gd`.

As plataformas de pedra de 3x2 tiles (atlas `(9, 21)` ate `(11, 22)`) nas duas fases viram corpos independentes ao iniciar o jogo. O primeiro pouso do Mario por cima inicia um tremor crescente e uma contagem de 1,5 segundo. Sair da plataforma ou pousar de novo nao reinicia esse prazo. Ao terminar, ela perde a colisao, desce 24 pixels em 0,22 segundo e se quebra em fragmentos que giram, encolhem e desaparecem em 0,35 segundo. Cada plataforma tem sua propria contagem; inimigos, contatos laterais e cabecadas nao ativam a queda.

Depois de terminar a animacao de destruicao, cada plataforma espera 4 segundos e reaparece na posicao original, com colisao e contagem zerada, pronta para outro pouso. `Respawn Delay` controla esse intervalo. A morte do Mario tambem reinicia a fase e restaura todas as plataformas. As contagens pausam durante a morte. Os tiles originais continuam no arquivo da fase para edicao. `cenas/falling_platform.gd` permite ajustar o prazo, a distancia da queda e a duracao dos efeitos.

Validacao do pouso, prazo, destruicao, retorno apos 4 segundos e reinicio nas duas fases: `godot --headless --fixed-fps 60 --path . --script res://tests/falling_platforms.gd`.

## Plataformas brancas da fase 2

As quatro plataformas brancas sao instancias de `cenas/white_platform.tscn`, em `Level02/PlataformasBrancas/PlataformaBranca1` ate `PlataformaBranca4`. Cada uma tem colisao ajustada ao contorno da imagem e move o Mario junto quando ele esta apoiado nela.

Selecione a plataforma na arvore da cena e abra **Oscilação** no Inspetor:

- **Amplitude**: distancia maxima para cada lado do centro, em pixels; padrao 48, zero deixa parada.
- **Periodo**: segundos para uma ida e volta completa; padrao 4.
- **Eixo**: `(1, 0)` para horizontal ou `(0, 1)` para vertical; tambem aceita direcao diagonal.
- **Fase Inicial**: deslocamento do ciclo em graus, para desencontrar plataformas vizinhas.

A oscilacao usa o corpo de colisao na fisica e pausa durante a morte. Reiniciar a fase restaura o centro e o ciclo. Os inimigos evitam entrar nas plataformas moveis para manter suas patrulhas sem quedas.

Validacao de colisao, transporte real do Mario, amplitude, movimento horizontal e vertical, pausa e reinicio: `godot --headless --fixed-fps 60 --path . --script res://tests/white_platforms.gd`.

## Bloco de interrogacao

Os blocos de interrogacao pintados em `Mundo/Ground` usando os tiles `(27, 15)` ou `(1, 30)` de `mariotile.png` ficam interativos ao iniciar a fase. Bater a cabeca por baixo faz a imagem subir 8 pixels, voltar e assumir a aparencia de bloco usado. Encostar de lado ou pousar em cima nao ativa o bloco. A colisao permanece fixa e cada bloco so e ativado uma vez.

A cena `cenas/question_block.tscn` tambem pode ser arrastada diretamente para a fase. No Inspetor, `Bump Height`, `Rise Duration` e `Return Duration` controlam a animacao; `Used Texture` define a aparencia apos a ativacao. O sinal `activated` permite conectar uma recompensa posteriormente.

Na fase 2, as duas caixas sao instancias editaveis em `Level02/CaixasInterrogacao`. Abra `cenas/level_02.tscn`, expanda esse no e selecione `QuestionBlock_17_-4` ou `QuestionBlock_34_-11` para arrastar no editor 2D, alterar `Transform > Position` ou duplicar com Ctrl+D. Elas mantem colisao, animacao de cabecada e contagem no HUD. As posicoes iniciais sao `(560, -112)` e `(1104, -336)`.

Validacao do bloco e integracao das fases: `godot --headless --path . --script res://tests/question_blocks.gd`.

Na fase 1, a caixa na celula `(53, -9)` faz Mario crescer ao ser ativada por baixo. A sequencia parte da pose atual, usa o recorte `small_to_big` montado no editor numa alternancia classica de crescimento e termina em `big_idle`. O mundo e os comandos pausam durante a transformacao; depois, Mario usa `big_walk` ao caminhar. Na agua, Mario grande usa tres frames de bracada de `Mario/Big.png`: `big_swim_sides` no movimento lateral, `big_swim_up` no impulso vertical e `big_swim_down` ao afundar ou mergulhar. As animacoes usam recortes de 32x32, conservam o alinhamento e espelham para a esquerda. O mergulho com S tem prioridade no movimento diagonal. Enquanto nao houver animacoes grandes de salto, o salto conserva `big_idle`. Os pes permanecem no lugar e a colisao aumenta para 64 pixels de altura assim que houver espaco acima. Morrer ou reiniciar restaura o Mario pequeno. O campo `Growth Block Cells` da fase define quais caixas dao essa recompensa.

Validacao do crescimento, cabecada real, pausa e respawn: `godot --headless --fixed-fps 60 --path . --script res://tests/mario_growth.gd`.

A animacao `small_to_big` toca um efeito original de crescimento em estilo chiptune, com notas ascendentes durante 0,8 segundo. O no `Mario/GrowthSound` permite ajustar o volume no Inspetor (padrao: -6 dB). O efeito continua durante a pausa da transformacao, toca apenas uma vez e para se Mario morrer ou reiniciar. O arquivo e `Mario/small_to_big.wav`; `Mario/build_growth_sound.py` permite recria-lo com Python, sem dependencias extras.

Para ajustar o salto grande, selecione o node `Mario` na fase ou em `cenas/mario.tscn` e abra o grupo `Salto` no Inspector. `Big Jump Height` define a altura em pixels, com padrao de `220 px`: valores maiores produzem saltos mais altos. O impulso e calculado a partir da gravidade. `Jump Velocity` continua controlando o salto pequeno.

Cada salto iniciado no chao toca um efeito chiptune de 0,22 segundo: `Mario/jump_small.wav` e mais agudo; `Mario/jump_big.wav` soa uma oitava abaixo. O tamanho atual escolhe o som automaticamente, inclusive depois de crescer ou renascer. Segurar pulo ou apertar no ar nao dispara outro efeito. `Mario/JumpSound` controla o volume no Inspetor (padrao: -8 dB). Crescimento, morte e respawn interrompem o som anterior. `Mario/build_jump_sounds.py` recria os dois arquivos com Python sem dependencias extras. A verificacao dos sons esta incluida em `tests/mario_growth.gd`.

## Goomba e Koopa

As cenas `cenas/goomba.tscn` e `cenas/koompa.tscn` podem ser arrastadas para qualquer fase. A fase 1 ja inclui um de cada. As cenas da raiz tambem usam a mesma logica.

- Ambos patrulham entre a posicao inicial menos e mais `patrol_amplitude`, passando pelo centro a cada volta. Mantem animacao, gravidade e colisao com o chao; tambem invertem nas paredes.
- Pisar no Goomba o achata e faz Mario rebater. Depois ele desaparece.
- Pisar no Koopa o transforma em casco deslizando na direcao atual, com um colisor menor. O casco nao fica limitado a patrulha.
- Encostar no casco parado o chuta para longe do Mario. Outro pisao para o casco em movimento.
- O casco rebate nas paredes e derrota inimigos. Dano lateral de Goomba remove duas vidas; Koopa andando e casco em movimento removem uma. Mario recebe um pequeno recuo e pisca durante 1,2 segundos de protecao, evitando danos repetidos no mesmo contato. A morte inicia ao chegar a zero vidas. Pisoes e chutes em cascos parados nao removem vidas.
- No Inspetor do no raiz do inimigo, `Patrulha > Patrol Amplitude` controla a distancia para cada lado, em pixels (padrao: 96; zero impede a caminhada). Por exemplo, 64 faz o inimigo andar de -64 a +64 em relacao ao ponto inicial.
- Em `Casco`, `Shell Duration` define o tempo antes de piscar (padrao: 4 segundos), `Shell Blink Duration` a duracao das piscadas (1 segundo) e `Shell Blink Interval` o intervalo entre mostrar/esconder (0,1 segundo). O casco continua com gravidade e colisoes durante as piscadas e depois desaparece, mesmo se for parado ou chutado novamente. O tempo conta desde a transformacao e nao reinicia nos chutes.
- `walk_speed`, `direction` e `shell_speed` tambem podem ser ajustados no Inspetor. Inimigos e cascos conferem o apoio na frente do colisor e invertem antes de buracos ou mudancas de altura. Plataformas que desabam nao sao usadas como extensao da patrulha. O passo inteiro e conferido, inclusive quando o casco anda rapido.

Validacao de fisica (Godot 4): `godot --headless --path . --script res://tests/enemy_physics.gd`.

As duas fases usam inimigos em escala 2.25. As amplitudes abaixo sao distancias em pixels para cada lado do ponto inicial, conferidas contra o chao incluindo a largura do colisor e 2 pixels de margem. Os pontos iniciais foram alinhados ao apoio. O Goomba2 da fase 1 saiu do degrau de apenas 32 pixels para o patamar adjacente; os Goombas 4 e 6 da fase 2 ficam centrados nas pontes, e o Goomba5 foi trazido de fora do mapa para a ponte seguinte.

| Inimigo | Fase 1 | Fase 2 |
| --- | ---: | ---: |
| Goomba | 120 | 160 |
| Goomba2 | 12 | 140 |
| Goomba3 | 100 | 160 |
| Goomba4 | — | 14 |
| Goomba5 | — | 14 |
| Goomba6 | — | 14 |
| Koopa | 48 | 160 |
| Koopa2 | 160 | 160 |

Na fase 2, `Enemy Supports Enabled` cria apoio para os inimigos nos pilares e nas faixas das pontes que nao tinham colisao. A camada `enemy_support` e reconhecida pelos colisores e pelos sensores dos inimigos.

Validacao de todos os percursos, 40 segundos por fase e protecao contra buracos, degraus e plataformas que desabam: `godot --headless --fixed-fps 60 --path . --script res://tests/enemy_patrol.gd`.

## HUD no estilo Super Mario World

Cada fase cria `cenas/hud.tscn` como uma faixa centralizada no topo, fixa na tela. O visual usa fonte bitmap de 8 pixels com sombra, MARIO em vermelho, vidas no formato `×03`, numero da fase, moldura azul com o bloco de interrogacao e contadores de caixas e moedas. A escala usa multiplos inteiros para manter os pixels nitidos e se adapta ao tamanho da janela. A faixa nao bloqueia o mouse.

O contador de caixas mostra `ativadas/total` e inclui os tiles convertidos de `Mundo/Ground` e as instancias de `question_block.tscn`, mesmo fora da camera. Cada cabecada conta uma unica vez; a caixa continua solida no estado ativado. A fase 1 inicia com `0/3`. A moldura azul identifica esse objetivo.

As vidas atualizam com o dano e acompanham Mario para a fase 2. O contador de moedas responde ao sinal `collected` das moedas da propria fase, incluindo moedas adicionadas durante o jogo. Cada fase inicia sua propria contagem de moedas. Ao morrer, a fase reinicia com tres vidas e os contadores zerados. O numero da fase vem do arquivo da cena, funcionando tambem com F6.

Os assets exclusivos ficam em `Cenario/hud`: `world_pixel.fnt` e seu atlas PNG, a moldura azul e o icone de moeda em SVG. A fonte foi desenhada para este HUD; `build_font.py` permite reconstruir o atlas e o arquivo BMFont com Python e Pillow.

Validacao do HUD, contagem, moedas, danos, reinicio, troca de fase e redimensionamento: `godot --headless --fixed-fps 60 --path . --script res://tests/hud_lives.gd`. Para salvar capturas em `.godot/hud_world_*.png`, execute sem `--headless` e acrescente `-- --capture`.

###
