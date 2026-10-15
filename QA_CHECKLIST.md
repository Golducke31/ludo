# QA_CHECKLIST — Halloween Critter Royale (M5, ejecutado)

Fecha de ejecución: sesión M5 (build actual, semilla canónica 20261015).
Verde = verificado en esta sesión. Los ítems marcados MANUAL requieren GPU /
ventana real y no son verificables headless; quedan anotados para el operador.

## 1. Suite completa

| Ítem | Estado | Evidencia |
|---|---|---|
| `tools/run_tests.sh` (3 escenas, 3 PASS) | 🟢 | test_all 3449/14 suites · grey_match 71 · keyboard 394 — 0 fallos |
| `python tools/scan_i18n.py` | 🟢 | OK: 40 claves literales, 82 en CSV, es/en |
| `python tools/hash_assets.py --verify` | 🟢 | OK: 125 archivos, sin deriva |
| `python tools/audit_palette.py` | 🟢 | OK: sin fugas neón/cian |
| `python tools/check_scene_refs.py` | 🟢 | OK: 8% refs con `unique_name_in_owner` |
| Benchmark 1000 partidas | 🟢 | 23.4 s (< 30 s de presupuesto), 6000 checks, 0 fallos |

## 2. Matriz de jugadores (2/3/4)

| Config | Estado | Evidencia |
|---|---|---|
| 2 jugadores (bots) | 🟢 | `suite_bot_sim` cicla count = 2 + i%3 sobre 1000 semillas; todas terminan con ganador y ranking consistente |
| 3 jugadores (bots) | 🟢 | idem |
| 4 jugadores (bots) | 🟢 | `test_grey_match.tscn`: 20 partidas × 2 reps, determinismo por semilla |
| 1 humano + 3 bots | 🟢 | `test_keyboard.tscn`: partida completa solo con teclado, 2 reps con hash idéntico |
| Humanos mezclados con bots | 🟢 | setup permite humano/bot por asiento; la máquina de turnos enruta cada asiento (cubierto por suites de turnos + playthrough) |
| Tope de turnos ≤ 1500 | 🟢 | verificado en bot_sim + grey_match + keyboard |
| **Vista 3D** con 2/3/4 jugadores | 🟢 | `arena_3d.gd` verificada con partida de 2 (pieces=8) y de 4 (pieces=16); solo se construyen los brazos activos |

## 3. Modos de accesibilidad

| Ítem | Estado | Evidencia |
|---|---|---|
| Daltónico (paleta + insignias) | 🟢 | `suite_accessibility`: tints por luminancia, 4 insignias de forma distintas, pares distintos |
| Alto contraste | 🟢 | `suite_accessibility`: cuadrícula/plumas oscurecen, madera aclara, pedestal refuerza alpha |
| Reducir movimiento | 🟢 | salto/dado/VFX se saltan (fast_mode y setting); ejercicio en playthrough teclado |
| Escala de texto 0.75–1.75 | 🟢 | `suite_accessibility`: clamp en ambos extremos + anti-compounding (base registrada en metadata) |
| Contraste de etiquetas de ficha | 🟢 | suite: ΔL ≥ 0.25 para las 4 facciones en los 4 modos (corrige bug invertido detectado en M5) |
| Teclado completo (menús + partida) | 🟢 | `test_keyboard.tscn`: foco recorre menú/setup/settings; partida completa sin ratón |
| Persistencia de ajustes | 🟢 | Settings escribe `user://` en cada cambio; locale/accesibilidad/volúmenes sobreviven al cierre (suite i18n restaura y verifica round-trip) |

## 4. Rendimiento (presupuesto: ≥ 60 FPS @1080p, < 200 partículas)

| Ítem | Estado | Evidencia |
|---|---|---|
| Cero `_process` en vistas/UI | 🟢 | grep sobre `scripts/game/views/` y `scripts/ui/`: 0 coincidencias |
| VFX acotados | 🟢 | pool fijo de 24 sprites (`vfx_view.gd`), auto-liberación por tween |
| Sprites por escena | 🟢 | 16 fichas (4×4) + 4 decor animados + dado; sin instanciación por frame |
| FPS real en GPU | ⚪ MANUAL | requiere ventana; correr `scenes/tools/shot_host.tscn` y observar con el profiler de Godot |
| Resoluciones 16:9 / 16:10 / ultrawide | ⚪ MANUAL | `window/stretch = canvas_items + expand` (independiente por diseño); verificar visualmente |

## 5. Funcional

| Ítem | Estado | Evidencia |
|---|---|---|
| Partida completa jugable de punta a punta | 🟢 | playthrough teclado + grey match sobre el scene graph real |
| Reinicio / revancha | 🟢 | `request_rematch` cubierto por suites de turnos; overlays con botones |
| Guardar / cargar partida | 🟢 | `suite_save_recovery`: roundtrip + JSON corrupto recuperable |
| Entrada ilegal segura | 🟢 | `suite_input_spam`: 5000 iteraciones sin doble-movimiento; playthrough repite el check con teclas inválidas |
| Localización ES/EN coherente | 🟢 | scan_i18n OK; texto del tutorial corregido en M5 (salida de cuna = solo 6, coincide con la regla) |
| Audio placeholder cableado | 🟢 | 8 WAV generados, conectados a EventBus (roll/move/capture/bonus/finish/portal/exit/ui_click) |
| UI comunica estado | 🟢 | HUD: turno, dado, tabla de jugadores con cursor `*`, hints por estado, overlay de pausa y resultados |

## Notas de la ejecución

- **Bug corregido (arena 3D)**: `arena_3d.gd` iteraba `for p in 4` al construir
  carriles/plataformas, pero el menú arranca con **2 jugadores** por defecto (el
  slider tiene `min_value = 2` y ningún `value`) → índice fuera de rango → el
  tablero quedaba a medias (casillas sí; plataformas, carriles, altar y fichas
  no). Ahora itera `state.players.size()` y `_start_owner()` solo considera
  asientos activos. **La suite headless es solo del core y NO cubre vistas**:
  cualquier cambio en la arena hay que verificarlo con partidas de 2, 3 y 4
  jugadores.
- **Bug corregido (relieve)**: el horneado en Blender se ejecutó varias veces
  sobre su propia salida; como tras un bake `Base Color` queda *conectado* a la
  textura, el script leía el gris por defecto y **dejó todo el kit en escala de
  grises**. Corregido con `clean_name()` + fallback de color enlazado; regla:
  `--in` debe apuntar siempre a los GLB prístinos.
- Bug corregido en M5: `piece_label_color` devolvía crema sobre fondos claros y
  tinta sobre fondos oscuros (contraste invertido). Ahora `suite_accessibility`
  lo protege con el check de ΔL.
- Doc Bug corregido en M5: el tutorial decía "sales con 5 o 6"; la regla
  implementada (`exit_dice_value = 6`) exige un 6 exacto. Corregido en
  `tools/gen_ui_strings.py` + CSV regenerado.
- Deriva de manifiesto corregida en M5: los `.translation` generados por Godot
  se excluyen del manifiesto (`hash_assets.py`), que vuelve a verificar OK.
