# Água e lava

Sprites da imagem `../UndergroundLava.png` fornecida pelo usuário. O PNG foi copiado sem alterações; os recortes são regiões exatas do atlas, sem reamostragem.

| Recorte | Região no PNG (x, y, largura, altura) | Uso |
| --- | --- | --- |
| Superfície da lava | `(144, 32, 64, 16)` | Lava com bolhas; mais legível que a faixa lisa `(144, 0, 64, 16)` |
| Superfície da água | `(144, 80, 64, 16)` | Superfície azul com espuma |
| Preenchimento da água | `(144, 96, 16, 16)` | Preenchimento da água, sem a região transparente ao lado |

Os três TileSets abaixo definem esses recortes diretamente no atlas. A animação cria seus `AtlasTexture` em tempo de execução; não são necessárias cópias avulsas desses recortes em arquivos `.tres`.

Os TileSets usam células nativas de 16 px e as camadas ficam em escala 2, com filtro **Nearest**, resultando nos mesmos tiles de 32 px das fases. As quatro partes das superfícies seguem a coordenada horizontal do mapa para formar uma faixa contínua. Apenas células de água sem outra célula acima usam espuma.

Durante o jogo, `cenas/liquid_animation.gd` anima cada tile da superfície com um `AnimatedSprite2D` e quatro recortes de 16×16 px. As colunas mantêm fases consecutivas para a faixa parecer fluir. A água usa **5 fps** e a lava **8 fps**. Selecione `Mundo/agua`, `Mundo/Lava` ou `Mundo/LavaGround` e ajuste **Animação → Animation Fps** no Inspetor.

Os tiles originais continuam responsáveis pela colisão e pelo nado; apenas sua imagem de superfície é substituída durante o jogo. As animações pausam junto com a fase e voltam após a pausa. Reiniciar a fase recria os sprites e seus ciclos.

Validação de movimento, continuidade, pausa e reinício: `godot --headless --fixed-fps 60 --path . --script res://tests/liquid_animation.gd`.

- `water.tres`: tiles de superfície e preenchimento, sem colisão.
- `lava_hazard.tres`: lava das camadas `Mundo/Lava`, mantém perigo na camada física 8.
- `lava_floor.tres`: lava de `Mundo/LavaGround` na fase 1, mantém a camada física 5 que os tiles anteriores usavam.

As faixas de pedra cinza e os sprites de cascata não fazem parte dos recortes usados.
