# Camadas do céu

`horror_sky.png` é a arte original, preservada. As duas camadas derivadas usam a ferramenta integrada imagegen:

- `horror_sky_static.png`: fundo opaco com lua e montanhas; fica fixo na tela.
- `horror_clouds.png`: nuvens com transparência; deslizam para a esquerda a 6 pixels por segundo, além do efeito da câmera.

Ambas têm 1536 × 1024 pixels e recebem a paleta de cada fase em `cenas/horror_parallax.gd`. A cena compartilhada é `cenas/horror_parallax.tscn`.

## Prompt do fundo fixo

Use case: precise-object-edit. Edit target: supplied 1536x1024 pixel-art night landscape texture for a Godot game. Create the stationary base layer of this exact game background: REMOVE ONLY ALL CLOUDS in the upper sky and the thin atmospheric cloud streaks above the mountains, replacing them with the matching clean dark purple night-sky gradient. Preserve the original pixel-art moon at EXACT same center (1033,316), diameter approximately 144 pixels, restore its full circle and crater surface behind the clouds which originally cover it. Preserve all mountains, distant castles, forest silhouettes, colors, textures, scale, framing and bottom terrain EXACTLY. Keep the sky empty of clouds, no stars added, no new objects, no text. Entire image opaque. Same 3:2 aspect ratio, ideally 1536x1024. Tileable left/right sky edges. This must match the source composition so a separate cloud overlay can move over the stationary moon and mountains.

## Prompt das nuvens

Use case: background-extraction. Edit target: supplied 1536x1024 pixel-art night landscape game background. Extract ONLY all purple CLOUDS from the original sky as a transparent overlay for a Godot game. Preserve cloud shapes, original purple colors, pixel-art details, relative positions and scale. Output full 3:2 original canvas, ideally 1536x1024. The purple clouds in upper 60 percent of the canvas and cloud wisps floating just above the mountains should remain, including the thin cloud wisps originally crossing in front of the moon. Remove the moon COMPLETELY: no moon pixels, no glow, no pale disk. Remove the entire night sky, mountains, castles, forests, ground completely to genuine alpha transparency. Lower 35 percent must be empty transparent. Keep the extracted purple clouds visible but naturally wispy, with transparent gaps around them. Do not add any objects or text. Clouds must be suitable for slowly repeating horizontally over the matching stationary original night landscape; maintain seamless/tileable left/right edges where the source clouds cross them.
