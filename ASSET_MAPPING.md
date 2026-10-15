# ASSET_MAPPING — Halloween Critter Royale

Fuentes: `C:/Users/emanu/Desktop/Assetsvariados/Hallowen/` (packs PAID,
integrados en el repo del proyecto; atribución en la pantalla de Créditos,
ES/EN, y en este documento). Las fuentes son externas e informativas: **el
proyecto no depende de ellas** — todo asset usado vive en `assets/` y está
verificado por `assets/MANIFEST.sha256`.
Destino: `assets/` dentro del proyecto (autónomo, sin dependencias externas).
Integridad: `assets/MANIFEST.sha256` (sha256 por archivo, `tools/hash_assets.py`).
Regeneración: `tools/slice_atlas.py` + `tools/build_sprite_frames.py` +
`tools/gen_vfx_sprites.py` (todos deterministas).

## Fichas por facción (M3)

| Facción | Fuente | Grid | Frames | Destino |
|---|---|---|---|---|
| Gato Negro | `CatPackHalloweenPAID/draculacats.png` | 512x384 @32px | 16 (fila 0) | `assets/sprites/factions/gato_negro/` |
| Fantasma Bruja | `CatPackHalloweenPAID/BONUS/PaidGhostWitch/PurpleHat/Idle.png` | 256x32 @32px | 8 | `assets/sprites/factions/fantasma_bruja/` |
| Rey Calabaza | `CatPackHalloweenPAID/BONUS/PumpkinPaid/IdlePumpkinLighton.png` | 512x32 @32px | 16 | `assets/sprites/factions/rey_calabaza/` |
| Conejo Espectral | `DemonicBunnyPaid/Sprites/Idle.png` | 384x32 @32px | 12 | `assets/sprites/factions/conejo_espectral/` |

Cada facción: `frame_*.png` + `idle.tres` (SpriteFrames, animación "idle"
loop, speed 8.0). Consumido por `scripts/game/views/piece_view.gd`.

## Tablero y ambientación (M3)

| Uso | Fuente | Destino |
|---|---|---|
| Fondo del tablero (textura atenuada, multiplicado por `BG_ROOM_TINT`) | `CatPackHalloweenPAID/CatRoomMaker/Rooms/Room1.png` (512x512) | `assets/sprites/board/room_bg.png` |
| Decoración esquina P1 (araña colgante) | `CatPackHalloweenPAID/BONUS/Spider/Spider.png` (384x32, 12 fr @32px) | `assets/sprites/decor/spider/` |
| Decoración esquina P2 (calavera) | `CatPackHalloweenPAID/BONUS/Skull/Skull.png` (512x64, 8 fr @64px) | `assets/sprites/decor/skull/` |
| Decoración esquina P3 (lápidas RIP) | `CatPackHalloweenPAID/BONUS/RIP/RIP.png` (1280x128, 10 fr @128px) | `assets/sprites/decor/rip/` |
| Decoración esquina P4 (ojo en tarro) | `CatPackHalloweenPAID/BONUS/EyeinJar/PNG/EyeinJar.png` (2176x128, 17 fr @128px) | `assets/sprites/decor/eyejar/` |

Los decor se colocan en `scripts/game/views/board_view.gd` (`_build_decor`)
desplazados hacia fuera de cada cluster de cuna (`DECOR_PUSH = 118`), para no
pisar fichas. Las hojas originales se conservan como `*_sheet.png`.

## VFX (M3, generados — no provienen de los packs)

Generados con Pillow por `tools/gen_vfx_sprites.py` (4x supersample + LANCZOS),
paleta muda (crema / naranja calabaza / violeta polvoriento):

| Efecto | Archivo | Disparador (EventBus) |
|---|---|---|
| Chispa al aterrizar | `assets/sprites/vfx/spark.png` (64x64) | `piece_moved` |
| Estallido de captura | `assets/sprites/vfx/burst.png` (96x96) | `pieces_captured` (nodo del capturador) |
| Humo al volver a la cuna | `assets/sprites/vfx/poof.png` (80x80) | `pieces_captured` (por ficha capturada) |

Pool de 24 sprites en `scripts/game/views/vfx_view.gd`; sin `_process`; se
desactiva con `Game.fast_mode` (tests headless) o `reduce_motion`.

## UI

| Uso | Archivo |
|---|---|
| Theme (fondo negro azulado, texto crema, acentos naranja) | `assets/ui/theme.tres` |
| Colores de las vistas (tablero/dado/fichas/HUD) | `scripts/game/views/view_palette.gd` |
| Variantes de accesibilidad (alto contraste, daltónico) | `view_palette.gd` (`apply_accessibility`) |

## Audio (placeholder, generado)

Generados por `tools/gen_placeholder_audio.py` (stdlib `wave`, 22050 Hz mono
16-bit, determinista): `roll`, `move`, `capture`, `bonus`, `finish`, `portal`,
`exit`, `ui_click` → `assets/audio/sfx/*.wav`. Conectados a eventos del
EventBus desde `scripts/audio/audio_manager.gd`. Buses: master/sfx/music.

## Disponible pero NO usado todavía (backlog de assets)

- `DarkGhostPaid/Die.png` (23 fr @64px) y `DieIdle.png` (20 fr @64px):
  candidatos para animar el dado; el dado actual es vectorial (cara crema con
  pips) y cumple el requisito de 0.5 s saltable. Integración pendiente.
- `PumpkinPaid/DiePumpkin.png` (16 fr @32px): dado calabaza, alternativa.
- `PumpkinPaid/LightsOffOn.png`, `LightsOpening.png`, `LightsClosing.png`:
  VFX de farolillo para el bonus linterna; hoy el bonus se comunica con
  texto + botones del HUD.
- `CatPackHalloweenPAID/CatRoomMaker/Decorations/CatRoomDecorations.png`
  (1024x1024, rejilla mixta ~64-128px): muebles y ventanas; requiere slicing
  cuidadoso por celda antes de usarse.
- `witch.png`, `EvilCatSprites.png`, `EvilCatItems.png`, GIFs varios:
  sin slice definido; fuera del alcance actual.
- `UiHorror*` (si apareciera en fuentes): excluido del plan.

## Auditoría

`tools/audit_palette.py` rechaza neón/cian en: literales `Color()`/hex de
`scripts/`, `scenes/`, `assets/*.tres`, y píxeles de los PNG de `assets/`
(>1% de píxeles en banda cian/verde-neon = fallo). Estado M5: OK.

`tools/hash_assets.py --verify` (manifiesto SHA256, 312 archivos): OK.
Los `.translation` que Godot genera a partir de `assets/i18n/ui.csv` quedan
fuera del manifiesto (artefactos derivados).

## Kit 3D del tablero (2026-10-14)

Fuente maestra: `C:/Users/emanu/Desktop/ludo/` (GLB generados con trimesh por el
usuario). Copia de trabajo: `assets/models/` (23 GLB). No se versionan las
fuentes: el proyecto es autónomo.

| Grupo | Archivos | Uso |
|---|---|---|
| `Tile_Normal/Safe/Special/Start/Corner` | 5 | Casillas del anillo (normales, seguras, portal/farolillo, inicio teñida, esquinas) |
| `FinalLane6_*` | 5 | Carriles finales de 6 losas (carmesí, esmeralda, dorado, neutro, púrpura) |
| `HomePlatform_*` | 5 | Plataformas de cuna con 4 sockets y socket de banderín |
| `Banner_{Calabaza,Luna,Pata}_*` | 5 | Banderines (calabaza / luna / pata) |
| `tablero_halloween_base` | 1 | Base del escenario (12x12 + 4 zonas + socket central + 48 losas de borde) |
| `altar_calabaza` | 1 | Altar lunar con calabaza, velas y enredaderas |
| `mansion_embrujada` | 1 | Mansión de fondo |

Escala: `K = 0.85 / (2720/52)` → el pitch de casilla del core equivale al ancho
de tile del kit (ver `ARCHITECTURE.md`).

### Texturas de relieve (bake)

Los GLB originales traían **materiales de color plano sin ninguna imagen**
(`images = 0`), sin normales y con UVs diminutas o ausentes: de ahí el aspecto
liso. `tools/blender_relief.py` (Blender 5.2 headless) reconstruye cada material
con relieve procedural y lo hornea a un **atlas compartido por asset**:

- Albedo (color × AO^0.85), rugosidad y normal, embebidos en el GLB re-exportado.
- Copias sueltas editables en `assets/models/baked/` (69 PNG).
- Pasos, valores y trampas: **`BLENDER_RELIEF.md`**.
- Regeneración: ver los comandos de ese documento (dos pases: 512 px para
  tiles/carriles/banderines, 1024 px para plataformas/altar/mansión/base).
