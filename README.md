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

Os frames, recortes, margens, ordem, FPS e loops montados no editor sao preservados. O script seleciona `small_idle` para parado, `small_walk` para caminhada, `small_jump` para subida e `small_fall` para descida em terra. Dentro da agua, A/D seleciona `small_swim_sides`; S seleciona `small_swim_down` e acelera o mergulho. Sem movimento lateral, o afundamento natural tambem usa `small_swim_down`. O Mario conserva a ultima direcao ao parar.

Validacao das caixas: `godot --headless --path . --script res://tests/mario_collisions.gd`.
Validacao das animacoes: `godot --headless --path . --script res://tests/mario_animations.gd`.

## Morte do Mario

Quando as tres vidas acabam, Mario inicia a morte classica: assume a pose de morte, espera por um instante, salta verticalmente e cai atravessando o cenario. Contato com perigos ou queda abaixo do mapa tambem iniciam essa sequencia diretamente. O mundo fica pausado durante a sequencia, os comandos ficam bloqueados, ele nao coleta moedas e a camera permanece fixa. Ao sair da tela, espera brevemente e reinicia a fase atual no `PlayerSpawn`, restaurando tres vidas, inimigos, moedas e blocos. Morrer na fase 2 reinicia a fase 2; tambem funciona executando cada fase diretamente com F6.

No Inspetor do Mario, o grupo `Morte` permite ajustar a pausa inicial, o impulso do salto, a gravidade e o atraso do reinicio. `Death Texture` usa um recorte separado de `Mario/mario.png`; os frames e animacoes existentes em `mario.tscn` permanecem intactos. As fases configuram automaticamente `Fall Death Y` abaixo da borda inferior do mapa.

Validacao da morte e reinicio: `godot --headless --path . --script res://tests/mario_death.gd`.

## Moedas coletaveis

Arraste `cenas/coin.tscn` para qualquer fase e duplique as instancias onde quiser colocar moedas. A raiz `Coin` e uma `Area2D` com `AnimatedSprite2D` e `CollisionShape2D`. Ela gira usando os seis quadros de `Cenario/coin.png` e monitora apenas corpos da camada do jogador que pertencem ao grupo `player`, ao qual o Mario se registra automaticamente.

Ao encostar no Mario, a moeda desativa a coleta, sobe 10 pixels e desaparece gradualmente em 0,24 segundos, sendo removida ao final. `Collect Rise` e `Collect Duration` permitem ajustar o efeito no Inspetor. Cada moeda emite `collected(player)` uma unica vez, permitindo conectar um contador futuramente.

Validacao da coleta: `godot --headless --path . --script res://tests/coins.gd`.

## Bloco de interrogacao

Os blocos de interrogacao pintados em `Mundo/Ground` usando os tiles `(27, 15)` ou `(1, 30)` de `mariotile.png` ficam interativos ao iniciar a fase. Bater a cabeca por baixo faz a imagem subir 8 pixels, voltar e assumir a aparencia de bloco usado. Encostar de lado ou pousar em cima nao ativa o bloco. A colisao permanece fixa e cada bloco so e ativado uma vez.

A cena `cenas/question_block.tscn` tambem pode ser arrastada diretamente para a fase. No Inspetor, `Bump Height`, `Rise Duration` e `Return Duration` controlam a animacao; `Used Texture` define a aparencia apos a ativacao. O sinal `activated` permite conectar uma recompensa posteriormente.

Validacao do bloco e integracao das fases: `godot --headless --path . --script res://tests/question_blocks.gd`.

## Goomba e Koopa

As cenas `cenas/goomba.tscn` e `cenas/koompa.tscn` podem ser arrastadas para qualquer fase. A fase 1 ja inclui um de cada. As cenas da raiz tambem usam a mesma logica.

- Ambos patrulham entre a posicao inicial menos e mais `patrol_amplitude`, passando pelo centro a cada volta. Mantem animacao, gravidade e colisao com o chao; tambem invertem nas paredes.
- Pisar no Goomba o achata e faz Mario rebater. Depois ele desaparece.
- Pisar no Koopa o transforma em casco deslizando na direcao atual, com um colisor menor. O casco nao fica limitado a patrulha.
- Encostar no casco parado o chuta para longe do Mario. Outro pisao para o casco em movimento.
- O casco rebate nas paredes e derrota inimigos. Dano lateral de Goomba remove duas vidas; Koopa andando e casco em movimento removem uma. Mario recebe um pequeno recuo e pisca durante 1,2 segundos de protecao, evitando danos repetidos no mesmo contato. A morte inicia ao chegar a zero vidas. Pisoes e chutes em cascos parados nao removem vidas.
- No Inspetor do no raiz do inimigo, `Patrulha > Patrol Amplitude` controla a distancia para cada lado, em pixels (padrao: 96; zero impede a caminhada). Por exemplo, 64 faz o inimigo andar de -64 a +64 em relacao ao ponto inicial.
- Em `Casco`, `Shell Duration` define o tempo antes de piscar (padrao: 4 segundos), `Shell Blink Duration` a duracao das piscadas (1 segundo) e `Shell Blink Interval` o intervalo entre mostrar/esconder (0,1 segundo). O casco continua com gravidade e colisoes durante as piscadas e depois desaparece, mesmo se for parado ou chutado novamente. O tempo conta desde a transformacao e nao reinicia nos chutes.
- `walk_speed`, `direction` e `shell_speed` tambem podem ser ajustados no Inspetor. Os inimigos podem cair de bordas.

Validacao de fisica (Godot 4): `godot --headless --path . --script res://tests/enemy_physics.gd`.

## HUD de caixas e vidas

Cada fase cria `cenas/hud.tscn` no canto superior esquerdo, fixo na tela, com a carinha do Mario, tres coracoes e o contador `ativadas / total` de caixas. O total inclui todos os blocos de interrogacao da fase, tanto os tiles convertidos de `Mundo/Ground` quanto as instancias de `question_block.tscn` colocadas no editor, mesmo fora da camera. Cada cabecada conta a caixa uma unica vez; ela continua solida no estado ativado. A fase 1 inicia com `0 / 3`.

Os coracoes esvaziam conforme o dano. As vidas restantes acompanham Mario para a fase 2, que calcula seu proprio total de caixas. Ao morrer, a fase reinicia com tres coracoes e contador zerado. O HUD tambem funciona nas fases executadas diretamente com F6.

Validacao do HUD, contagem, danos, reinicio e troca de fase: `godot --headless --path . --script res://tests/hud_lives.gd`. Para salvar capturas em `.godot`, execute sem `--headless` e acrescente `-- --capture`.

###
