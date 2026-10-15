# KNOWN_ISSUES — Halloween Critter Royale

Pendientes conocidos al cierre de M5. N bloqueante para jugar; todo lo demás
está documentado con workaround.

## 1. Export real bloqueado (único pendiente del plan)

- **Qué**: `export_presets.cfg` existe con presets *Windows Desktop (x86_64)* y
  *Web*, pero **no se puede generar un build**.
- **Por qué**: faltan las Export Templates de Godot 4.7.2
  (`export_templates/4.7.2.stable/...`); instalarlas requiere descargarlas desde
  el gestor de plantillas (necesita red).
- **Evidencia**: al ejecutar (PowerShell, desde la raíz del proyecto)
  `& "$env:USERPROFILE\Desktop\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-debug "Windows Desktop (needs export templates)"`
  el motor falla con *"No se encontró una plantilla de exportación en la ruta:
  .../export_templates/4.7.2.stable/windows_release_x86_64.exe"* — es decir, el
  preset parsea bien; solo falta la plantilla.
- **Workaround**: jugar desde el editor (`godot --path .`) o instalar las
  plantillas y reintentar el export. El nombre de cada preset incluye
  "(needs export templates)" para que el estado sea auto-documentado.

## 2. Audio placeholder (no es audio final)

- Los 8 SFX (roll, move, capture, bonus, finish, portal, exit, ui_click) son
  WAV generados por `tools/gen_placeholder_audio.py` (tonos cortos, 22050 Hz
  mono). Son marcadores de posición, no sonido final.
- No hay música de fondo implementada (bus `music` existe y respeta volumen).
- Los archivos viven en `assets/audio/sfx/` y están en el manifiesto SHA256.

## 3. Assets disponibles sin usar (backlog)

- `DarkGhostPaid/Die.png` (23 fr) / `DieIdle.png` (20 fr) y
  `PumpkinPaid/DiePumpkin.png` (16 fr): hojas candidatas para animar el dado;
  el dado actual es vectorial (cara crema, pips). Integración pendiente.
- `PumpkinPaid/LightsOffOn.png`, `LightsOpening.png`, `LightsClosing.png`: VFX
  de farolillo para el bonus; hoy el bonus se comunica con texto + botones.
- `CatRoomMaker/Decorations/CatRoomDecorations.png` (1024×1024, rejilla mixta):
  muebles/ventanas; requiere slice cuidadoso por celda antes de usarse.
- `witch.png`, `EvilCatSprites.png`, `EvilCatItems.png` y GIFs varios: sin
  slice definido; fuera del alcance actual.
- `UiHorror*`: excluido explícitamente del plan (no se integra).
- Detalle completo en `ASSET_MAPPING.md`.

## 4. Verificaciones que requieren GPU/ventana (no headless)

- FPS real a 1080p (presupuesto ≥ 60): medir con el profiler de Godot sobre
  `scenes/tools/shot_host.tscn`. Las invariantes headless sí están verificadas:
  0 `_process` en vistas, VFX con pool de 24, sin instanciación por frame.
- Aspecto en 16:10 / ultrawide: el stretch es `canvas_items + expand`
  (independiente por diseño); falta la confirmación visual.
- Fuentes/tamaños reales de render: la escala de texto está verificada en
  lógica (0.75–1.75, anti-compounding), no en píxeles.

## 5. Detalles menores

- Los bots Easy/Normal/Hard comparten la máquina de reglas; difieren solo en la
  elección de movimiento/bonus y su RNG propio. No hay "personalidad" por
  facción.
- Un solo slot de guardado (`match`).
- El locale por defecto es ES; el cambio a EN persiste por Settings.
- La partida termina con el primer ganador (ranking para el resto); no hay
  modo "hasta el último".
