# Halloween Critter Royale

Juego de tablero tipo Ludo con temática de Halloween, hecho en **Godot 4.7.2**
(Forward+ · tablero **3D** isométrico con relieve horneado). 4 facciones criatura
compiten por llevar sus 4 fichas de la cuna a la meta: **Gato Negro**,
**Fantasma Bruja**, **Rey Calabaza** y **Conejo Espectral**. 2–4 jugadores
(humanos o bots), modo *Halloween* (portales y farolillos) o *Clásico*,
localización **ES/EN**, accesibilidad integrada y núcleo de reglas determinista
verificado por tests headless.

**Estado**: M5 completo (QA + docs) + tablero **3D** integrado (arena isométrica
construida con el kit GLB propio, texturas de relieve horneadas en Blender,
cámara en primera persona). Pendientes conocidos: el export real necesita las
Export Templates de Godot, y quedan partículas ambientales + pulido de HUD
(ver `KNOWN_ISSUES.md`).

## Arrancar

Todos los comandos se ejecutan **desde la raíz del proyecto**:

```powershell
cd "C:\ruta\a\LudoHaloween"
```

### PowerShell (Windows)

```powershell
# 1) Editor / juego: abrir el proyecto (menú principal)
& "$env:USERPROFILE\Desktop\Godot_v4.7.2-stable_win64_console.exe" --path .

# 2) Tests headless canónicos (3 escenas; exige 3 tokens HCTESTS:PASS)
#    Usar Git Bash explícito: el "bash" del PATH suele ser el de WSL, que no
#    ve ~/Desktop de Windows y no encuentra el binario de Godot.
& "C:\Program Files\Git\bin\bash.exe" tools/run_tests.sh

# 3) Benchmark M5: 1000 partidas bots (< 30 s)
$env:GODOT_BIN = "$env:USERPROFILE\Desktop\Godot_v4.7.2-stable_win64_console.exe"
$env:HCTESTS_SIM_MATCHES = 1000
& $env:GODOT_BIN --headless --path . scenes/test/test_all.tscn --quit-after 3000
```

> El runner acepta cualquier binario: `$env:GODOT_BIN = "C:\ruta\a\Godot*.exe"`
> antes de invocarlo (también busca `godot` en el PATH).

### Bash (Linux/macOS/Git Bash)

```bash
# Editor / juego
godot --path .                      # o ./Godot_v4.7.2-stable_win64_console.exe --path .

# Tests headless canónicos
bash tools/run_tests.sh             # 3 escenas: exige 3 tokens HCTESTS:PASS

# Benchmark M5: 1000 partidas bots (< 30 s)
HCTESTS_SIM_MATCHES=1000 \
  "${GODOT_BIN:-godot}" \
  --headless --path . scenes/test/test_all.tscn --quit-after 3000
```

## Cómo se juega

- Teclado: **Espacio** tirar el dado, **1–4** elegir ficha, **C** alternar cámara
  (vista general ⇄ primera persona que sigue a las fichas), **Esc** pausa.
  Ratón: clic sobre la ficha a mover (también botones del HUD).
- Solo se sale de la cuna con un **6**. Casillas seguras (madera clara) protegen
  de capturas. Caer sobre una ficha rival la devuelve a su cuna.
- Portal de Niebla (índice 4) teletransporta; Farolillo Calabaza (índice 30) da
  bonus. Gana quien meta las 4 fichas primero.
- Reglas completas y ambigüedades resueltas: `GAME_RULES.md`.

## Estructura

| Ruta | Contenido |
|---|---|
| `scripts/core/` | Núcleo puro de reglas (sin dependencias de vista): `game_match`, `match_state`, `turn_machine`, `rng_stream`, geometría, replay |
| `scripts/game/` | Orquestador (`game_manager` = autoload `Game`), control de input, `match_root` |
| `scripts/game/views/` | Vistas 2D del HUD/overlays y paleta (sin `_process`) |
| `scripts/game/views3d/` | Arena **3D**: `arena_3d.gd` (escena, cámara iso/primera persona, luces, picking, fichas y dado procedurales) + `block_mesh.gd` |
| `scripts/ai/` | Bots Easy/Normal/Hard con RNG propio (no toca el RNG de dados) |
| `scripts/ui/` | Menú, setup, settings, créditos, tutorial, escalado de texto |
| `scripts/save/` | Settings/Save/Stats (autoloads, JSON en `user://`) |
| `scripts/i18n/` | Cargador CSV runtime (ES/EN) |
| `assets/` | Kit **3D** del tablero en `assets/models/` (23 GLB con texturas PBR embebidas), sprites 2D (facciones, decor, VFX), audio, i18n, theme |
| `data/` | Reglas (`.tres`) y facciones (`.tres`) |
| `tools/` | Runner de tests, slice/hash/audit/generadores deterministas |
| `scenes/test/` | `test_all`, `test_grey_match`, `test_keyboard` |

Arquitectura detallada: `ARCHITECTURE.md`. Mapeo de assets: `ASSET_MAPPING.md`.
Checklist de QA ejecutado: `QA_CHECKLIST.md`.

## Testing

Framework propio (`HCTestCase`), sin dependencias externas. Protocolo por
tokens `HCTESTS:*`; `tools/run_tests.sh` exige un PASS por escena:

| Escena | Cobertura | Checks |
|---|---|---|
| `test_all.tscn` | 15 suites: reglas, geometría, RNG, capturas, meta, turnos, serialización, guardado corrupto, replay, desync, 1000-partida sim (100 por defecto), spam de input, accesibilidad | 3449 |
| `test_grey_match.tscn` | 20 partidas bot-vs-bot reales sobre el scene graph, ×2 por semilla (determinismo) | 71 |
| `test_keyboard.tscn` | Partida completa solo con teclado (roll/pick/pausa/bonus inyectando eventos), foco en todas las pantallas UI, spam ilegal, determinismo | 394 |

## Accesibilidad

- **Daltónico**: paleta de tints separada por luminancia + insignias de forma
  (círculo/triángulo/cuadrado/diamante) — la información no depende solo del color.
- **Alto contraste**: cuadrícula y plumas más oscuras, madera más clara.
- **Reducir movimiento**: desactiva salto de ficha, rodada del dado y VFX.
- **Escala de texto**: 0.75×–1.75× (Settings, persiste).
- **Teclado completo**: toda la UI y la partida se pueden jugar sin ratón.
- Volúmenes master/sfx/música; locale ES/EN seleccionable.

## Export

`export_presets.cfg` incluye presets Windows Desktop (x86_64) y Web. El build
está **bloqueado** hasta instalar las Export Templates de Godot 4.7.2
(requiere red). Ver `KNOWN_ISSUES.md`.

## Licencia / assets

Arte propio de los packs de `Assetsvariados` (integrados en `assets/`), VFX y
audio placeholder generados por `tools/`. Detalle y hashes en
`ASSET_MAPPING.md` + `assets/MANIFEST.sha256`.
