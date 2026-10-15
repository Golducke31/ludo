# Pack visual (referencia: dungeon isométrico estilizado)
1. Copiá `textures/` a `res://textures/` y `visual_polish.gd` a tu proyecto.
2. En tu escena principal agregá un Node3D hijo, adjuntale `visual_polish.gd` y (opcional) elegí en `Apply To` el nodo raíz del tablero.
3. En Project Settings: Rendering > Renderer = Forward+ (SSAO/SSIL/niebla volumétrica no están en Compatibility/móvil).
4. Para móvil: en el script comentá `ssil_enabled` y `volumetric_fog_enabled`, y bajá `directional_shadow_mode` a SHADOW_ORTHOGONAL con una sola luz.
5. Las luces de calidez (velas, linternas, calabaza) ponelas como OmniLight3D naranja (energía 1.5–3, rango 3–4) en los nodos `LightSocket`.
Texturas (1024²): floor_stone, tile_pale, wall_brick, tile_rune_glow (con emisión), wood_dark, pumpkin_skin. Cada una trae _albedo, _normal y _orm (R=AO, G=rugosidad).
