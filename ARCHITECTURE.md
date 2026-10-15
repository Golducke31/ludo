# ARCHITECTURE — Halloween Critter Royale

Diseño headless-first: el núcleo de reglas es código puro sin escenas ni
nodos, de modo que toda la lógica se testea sin render. Las vistas son
reproductoras pasivas de estado comunicado por el autoload `Game` y el
`EventBus`.

## Capas

```
┌──────────────────────────────────────────────────────────────┐
│ scenes/  boot · main_menu · setup · settings · credits ·     │
│          tutorial · match_root (board/piece/dice/hud/overlays)│
├──────────────────────────────────────────────────────────────┤
│ scripts/game/views/   vistas (solo leen estado, cero _process)│
│ scripts/game/         game_manager (autoload Game) + input    │
├──────────────────────────────────────────────────────────────┤
│ scripts/core/         NÚCLEO PURO: game_match, match_state,   │
│                       turn_machine, rng_stream, geometría     │
│ scripts/ai/           bot_player (RNG propio, no toca dados)  │
├──────────────────────────────────────────────────────────────┤
│ scripts/save · i18n · audio    autoloads de servicio          │
└──────────────────────────────────────────────────────────────┘
```

## Autoloads (orden importa)

| Autoload | Rol |
|---|---|
| `EventBus` | señales de juego (dice_rolled, piece_moved, pieces_captured, bonus_offered/resolved, portal_triggered, piece_exited, match_started/finished, settings_changed…) |
| `Settings` | preferencias persistentes (locale, accesibilidad, volúmenes, text_scale) en `user://` |
| `L10n` | localización runtime: carga `assets/i18n/ui.csv`, `t(key, args)` con `{placeholder}`, `localize_scene(root, prefix)` mapea nombres de nodo a claves |
| `Save` | guardado/carga de partida (1 slot, JSON) + recuperación de archivos corruptos |
| `Stats` | estadísticas agregadas |
| `Audio` | AudioManager: buses master/sfx/music, reproduce por eventos del EventBus |
| `Game` | game_manager: posee `active_match` + `machine`, única puerta de entrada del input |

## Núcleo determinista (`scripts/core/`)

- `rng_stream.gd`: stream dedicado para dados. Los bots usan otro stream
  (`bot_rng`), derivado por jugador de la semilla — la semilla determina la
  partida completa.
- `turn_machine.gd`: tabla explícita de transiciones (14 estados). **Todo**
  input (humano o bot) pasa por `can()` antes de actuar; es el único guardia
  anti doble-acción. En `fast_mode` los bots resuelven turnos de forma
  sincrónica (tests headless); en juego normal con timers.
- `game_match.gd`: aplica reglas y devuelve diccionarios de resultado + eventos;
  nunca habla con las vistas. `state_hash()` permite verificar determinismo y
  replays.
- Geometría (`board_geometry` / `board_layout`): anillo, brazos, columnas y
  posiciones en px — puras y serializables.

## Vistas (`scripts/game/views/`)

- Sin `_process` en ninguna vista: el estado llega por señales.
- Construcción perezosa: decor/fichas se crean en la señal `match_started`
  (los `_ready` hijos corren antes que el del padre).
- `view_palette.gd`: paleta única (prohibido neón/cian, verificado por
  `tools/audit_palette.py`). Variables `static` para poder intercambiar
  variantes de alto contraste / daltónico en caliente
  (`apply_accessibility(high_contrast, colorblind)`).
- Anti-color-only: cada facción tiene insignia de forma
  (círculo/triángulo/cuadrado/diamante) dibujada junto a sus fichas cuando el
  modo daltónico está activo.
- `vfx_view.gd`: pool de 24 sprites, tweens con auto-liberación; se desactiva
  con `fast_mode` o `reduce_motion`.

## Input

`scripts/game/input_controller.gd` (único camino del jugador humano):
- Teclado: `Space/Enter` tirar, `1–4` elegir ficha, `Esc` pausa/reanudar.
- Ratón: clic sobre la ficha (radio 26 px, solo fichas con movimiento legal).
- Todo pasa por `Game.request_*` (guardado por la máquina de turnos); input
  ilegal se descarta en silencio — seguro contra spam (prueba de 5000
  iteraciones).
- La UI (botones del HUD, overlays) usa el sistema estándar de foco de Godot:
  toda la partida es jugable **solo con teclado** (verificado por
  `test_keyboard.tscn`).

## Persistencia y servicios

- `Settings` persiste en cada cambio (emisor de `settings_changed`, que las
  vistas y el HUD escuchan para re-localizar/re-escalar/re-pintar).
- `Save` guarda el estado serializable del match; `suite_save_recovery` prueba
  recuperación ante JSON corrupto.
- `Audio`: SFX placeholder (8 WAV generados por `tools/gen_placeholder_audio.py`)
  conectados a eventos del EventBus; buses master/sfx/music desde Settings.

## Testing (framework propio)

- `HCTestCase` (`scripts/test/hc_test_case.gd`): base con `check*`.
- Escenas por grupo: `test_all.tscn` (15 suites en proceso), `test_grey_match.tscn`
  (partidas reales bot-vs-bot sobre el scene graph) y `test_keyboard.tscn`
  (playthrough solo-teclado inyectando `Input.parse_input_event`).
- Protocolo `HCTESTS:SUITE/TOTAL/PASS|FAIL`; `tools/run_tests.sh` exige un PASS
  por escena.
- Suites clave: `serialize` (roundtrip), `desync` (vista que retrasa/omite
  notificaciones → hash final idéntico), `replay` (verificación por hash),
  `bot_sim` (N partidas; `HCTESTS_SIM_MATCHES=1000` para el benchmark M5),
  `input_spam`, `accessibility`.

## Tools (`tools/`)

| Tool | Uso |
|---|---|
| `run_tests.sh` | runner canónico headless (3 escenas, 3 PASS) |
| `refresh_class_cache.sh` | `--editor --quit`: regenera el class cache + importa assets (obligatorio tras añadir `class_name` o assets) |
| `hash_assets.py` | manifiesto SHA256 de `assets/` (`--verify` detecta deriva) |
| `audit_palette.py` | gate de paleta: rechaza neón/cian en scripts, escenas y píxeles |
| `slice_atlas.py` / `build_sprite_frames.py` | slice de hojas + `SpriteFrames` deterministas |
| `gen_vfx_sprites.py` / `gen_placeholder_audio.py` | generadores deterministas (Pillow / stdlib wave) |
| `gen_ui_strings.py` | regenera `assets/i18n/ui.csv` (82 claves ES/EN) |
| `scan_i18n.py` | detecta claves usadas-faltantes / vacías / duplicadas |
| `check_scene_refs.py` | valida que cada `%Ref` tenga `unique_name_in_owner` |

## Flujo de una partida

```
setup.tscn ──Game.configure──▶ match_root.tscn
   │                              │ _ready: Game.attach + begin_match
   │                              ▼
   │                     TurnMachine: STARTING_MATCH → WAITING_FOR_ROLL
   │                              │ prompt_turn: ¿bot? (fast: loop sync)
   input (teclado/ratón/botón) ──▶ Game.request_roll/move/bonus (guardado)
                                  ▼
                        game_match aplica reglas → eventos
                                  ▼
        EventBus ──▶ vistas (board/piece/dice/hud/vfx) + audio + overlays
```

En `fast_mode` una partida completa con 3 bots se resuelve sincrónica y
deterministicamente dentro de `begin_match()` — de ahí que los tests headless
puedan jugar partidas reales sobre el scene graph sin render.

## Tablero 3D (`scripts/game/views3d/arena_3d.gd`)

La partida es **3D**; menús, HUD y overlays siguen en 2D (`CanvasLayer`). El nodo
`Arena` (Node3D) sustituye a las antiguas vistas 2D dentro de `match_root.tscn`;
los `_ready` de los hijos corren antes que el del padre, así que la Arena conecta
sus señales antes de que `match_root._ready` dispare `Game.begin_match()`.

### Contrato de escala

`K = 0.85 / (2720/52)` — el pitch de casilla del core (2720 px de diseño / 52
casillas) equivale al ancho de tile del kit GLB (0.85). Con eso:

- **Casillas del anillo** 1:1 en `ring_position(i)`.
- **Carriles** escalados `(1, 1, 0.85)` y anclados en `column_position(p, 0)` para
  que sus 6 losas caigan exactamente en las 6 casillas de columna.
- **Plataformas** centradas en los pen clusters con offset `+out·0.1` (sus 4
  sockets coinciden con nuestros 4 slots de cuna).

### Invariantes de la vista

- **Solo se construyen los asientos ACTIVOS**: el anillo siempre tiene 4 brazos,
  pero una partida de 2 o 3 deja brazos sin dueño. Iterar `for p in 4` e indexar
  `state.players[p]` **revienta** el build del tablero (bug real: el menú arranca
  con 2 jugadores por defecto → quedaban las casillas pero no plataformas,
  carriles, altar ni fichas).
- **Encuadre**: `_fit_camera()` ajusta el bounding box REAL en espacio de cámara
  (min/max, nunca `|max|`) e incluye la escenografía (`_scenery`, AABB de la
  mansión). El desplazamiento al área libre del HUD es una **traslación pura**:
  re-apuntar con `look_at` recentraría el tablero y anularía el shift.
- **Picking**: `pick_piece_at(screen_pos)` proyecta los anclajes con la cámara
  **activa** (funciona también en primera persona) manteniendo el radio en px.
- Cero `_process`; `reduce_motion` / `fast_mode` saltan todos los tweens.

### Cámara

- **Isométrica ortográfica** en `(CAM_DIST, CAM_DIST, CAM_DIST)` mirando al centro.
- **Primera persona** (perspectiva, fov 72) que cabalga una ficha; alterna con
  **C** o el botón del HUD. Cadena de foco: ficha jugable del jugador actual →
  cualquier ficha suya en juego → última ficha movida → cualquier ficha en juego.

### Assets 3D y relieve

El kit GLB (`assets/models/`, 23 piezas) venía con **materiales de color plano,
sin texturas ni normales y con UVs diminutas o ausentes**. `tools/blender_relief.py`
(Blender headless) reconstruye cada material con relieve procedural y lo hornea a
un **atlas compartido por asset** (albedo × AO, rugosidad y normal), embebido en
el GLB re-exportado. Pasos, valores y trampas: **`BLENDER_RELIEF.md`**.
