# GAME_RULES — Halloween Critter Royale

Referencia canónica de reglas. Fuente de verdad en código:
`scripts/core/match_rules.gd` + `data/rules/halloween_default.tres` /
`data/rules/classic.tres`. Los tests (`suite_rules`, `suite_turns`,
`suite_capture`, `suite_home`) verifican cada apartado.

## Objetivo

Llevar las 4 fichas de tu facción desde la **cuna** (pen) hasta la **meta**
(goal). Gana quien meta las 4 primero; el resto se ordena por ranking.

## Tablero

- Anillo de **52 casillas** (`ring_size`), brazos de **13** (`arm_length`) por
  facción, columna final de **6** (`column_length`), **50 pasos** de cuna a meta
  (`home_steps`), **4 fichas** por jugador.
- Cada facción tiene su casilla de salida (offset 0 de su brazo).

## Turnos

1. **Dado**: tiras al inicio de tu turno.
2. **Salida de la cuna**: solo con un **6** exacto (`exit_dice_value = 6`). Una
   ficha sale al offset 0 del anillo.
3. **Movimiento**: avanzas tantas casillas como el dado, siempre hacia adelante
   por tu brazo → columna final → meta.
4. **Captura**: si caes en una casilla ocupada por una ficha rival, esa ficha
   vuelve a su cuna (no se puede capturar en casilla segura).
5. **Fin de turno**: pasa al siguiente jugador en asiento.

## Turnos extra y penalización (ambigüedad resuelta #1)

- Sacar **6** otorga un turno extra, en cadena.
- La cadena de extras tiene **tope 3** (`extra_turn_cap = 3`).
- El **tercer 6** consecutivo hace **perder el movimiento** (y el turno pasa)
  (`third_six_penalty = true`).

## Casillas seguras

- Offsets `[0, 7]` de cada brazo (`safe_offsets`): la salida y el centro del
  brazo. Si tu casilla de destino es segura, **no hay captura**: las fichas
  rivales que haya allí permanecen.
- Si caes en una casilla **no** segura del anillo con fichas rivales, **todas**
  las rivales de esa casilla vuelven a su cuna.

## Modo Halloween (`halloween_enabled = true`)

- **Portal de Niebla** (`portal_index = 4`): al caer, la ficha se teletransporta
  `portal_bonus = 6` casillas hacia adelante en el anillo.
- **Farolillo Calabaza** (`lantern_index = 30`): al caer se ofrece un bonus de
  un solo paso (se resuelve con los botones del HUD):
  - **Avanzar** `lantern_bonus = +2` (solo si la ficha no está a menos de 2 de
    la meta).
  - **Devolver**: la ficha rival **más avanzada** retrocede
    `lantern_send_back = 6` casillas (a la cuna si quedaría por debajo de 0).
    Solo se ofrece si hay alguna rival a quien enviar.
- **Montón de Dulces** (`candy_heap_index = 47`): existe en los datos pero está
  **desactivado por defecto en v1** (`candy_heap_enabled = false`). (Ambigüedad
  resuelta #3.)

## Modo Clásico

`halloween_enabled = false`: sin portales ni farolillos; el Montón de Dulces
sigue desactivado. El resto de reglas es idéntico.

## Final de partida (ambigüedad resuelta #2)

- La partida termina con el **primer ganador** (primero en meter 4 fichas).
- Los demás jugadores reciben **ranking**: primero por fichas en meta
  descendente, luego por progreso total descendente, finalmente por asiento.
- **Tope de turnos**: 1500 (`GameMatch.TURN_CAP`) como válvula de seguridad; al
  alcanzarse la partida se resuelve por ranking. Los tests verifican que nunca
  se exceda.

## bots

- Dificultades **Easy / Normal / Hard** (`scripts/ai/bot_player.gd`).
- Usan un RNG propio (`bot_rng`) derivado de la semilla: **nunca** tocan el RNG
  de dados, que es un stream independiente y determinista
  (`scripts/core/rng_stream.gd`). La misma semilla reproduce la misma partida.

## Persistencia

- Settings, guardado de partida (1 slot) y estadísticas en `user://` (JSON).
- Al cerrar y abrir, la configuración y los ajustes de accesibilidad persisten.
