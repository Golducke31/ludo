#!/usr/bin/env python3
"""generate ui.csv (ES/EN) - deterministic, run once to refresh strings."""
import csv
from pathlib import Path

ROWS = [
    ("key", "es", "en"),
    ("menu.title", "HALLOWEEN CRITTER ROYALE", "HALLOWEEN CRITTER ROYALE"),
    ("menu.subtitle", "Estilo Ludo - 2-4 jugadores - nucleo determinista", "Ludo-style - 2-4 players - deterministic core"),
    ("menu.play", "Jugar", "Play"),
    ("menu.settings", "Ajustes", "Settings"),
    ("menu.credits", "Creditos", "Credits"),
    ("menu.tutorial", "Como jugar", "How to play"),
    ("menu.quit", "Salir", "Quit"),
    ("setup.title", "CONFIGURAR PARTIDA", "MATCH SETUP"),
    ("setup.players", "Jugadores:", "Players:"),
    ("setup.seat", "Asiento", "Seat"),
    ("setup.faction", "Faccion", "Faction"),
    ("setup.type", "Tipo", "Type"),
    ("setup.difficulty", "Dificultad", "Difficulty"),
    ("setup.halloween", "Reglas Halloween (Portal de Niebla / Farolillo Calabaza)", "Halloween rules (Fog Portal / Pumpkin Lantern)"),
    ("setup.seed", "Semilla (vacio = aleatoria):", "Seed (empty = random):"),
    ("setup.seed_random", "aleatoria", "random"),
    ("setup.back", "Volver", "Back"),
    ("setup.start", "Empezar partida", "Start match"),
    ("setup.error_players", "El numero de jugadores debe ser 2-4", "Players must be 2-4"),
    ("setup.bot", "Bot", "Bot"),
    ("setup.human", "Humano", "Human"),
    ("faction.gato_negro", "Gato Negro", "Gato Negro"),
    ("faction.fantasma_bruja", "Fantasma Bruja", "Witch Ghost"),
    ("faction.rey_calabaza", "Rey Calabaza", "Pumpkin King"),
    ("faction.conejo_espectral", "Conejo Espectral", "Spectral Bunny"),
    ("diff.easy", "Facil", "Easy"),
    ("diff.normal", "Normal", "Normal"),
    ("diff.hard", "Dificil", "Hard"),
    ("hud.no_match", "Sin partida", "No match"),
    ("hud.turn", "Turno {n}", "Turn {n}"),
    ("hud.dice_none", "Dado: -", "Dice: -"),
    ("hud.dice", "Dado: {v}", "Dice: {v}"),
    ("hud.row", "{n}. {name} [{faction}] {type} meta={goal} cuna={pen}{current}", "{n}. {name} [{faction}] {type} goal={goal} pen={pen}{current}"),
    ("hud.type_bot", "bot/{diff}", "bot/{diff}"),
    ("hud.type_human", "humano", "human"),
    ("hud.roll", "Tirar (Espacio)", "Roll (Space)"),
    ("hud.pause", "Pausa (Esc)", "Pause (Esc)"),
    ("hud.bonus_title", "Bonus farolillo calabaza:", "Pumpkin Lantern bonus:"),
    ("hud.advance", "Avanzar +2", "Advance +2"),
    ("hud.send_back", "Retroceder rival 6", "Send rival back 6"),
    ("hud.over", "Partida terminada", "Match over"),
    ("hud.hint_over", "Consulta el panel de resultados", "Check the results panel"),
    ("hud.hint_roll", "Tu turno: tira el dado (Espacio)", "Your turn: roll the dice (Space)"),
    ("hud.hint_pick", "Elige una ficha (clic o teclas 1-4)", "Pick a piece (click or keys 1-4)"),
    ("hud.hint_bonus", "Farolillo Calabaza: elige tu bonus", "Pumpkin Lantern: choose your bonus"),
    ("hud.hint_paused", "En pausa", "Paused"),
    ("hud.hint_wait", "...", "..."),
    ("hud.hint_bots", "Los bots estan jugando...", "Bots are playing..."),
    ("pause.title", "PAUSA", "PAUSED"),
    ("pause.resume", "Continuar", "Resume"),
    ("pause.save", "Guardar partida", "Save match"),
    ("pause.load", "Cargar partida", "Load match"),
    ("pause.quit", "Salir al menu", "Quit to menu"),
    ("pause.saved", "Partida guardada", "Match saved"),
    ("pause.save_failed", "Error al guardar ({err})", "Save failed ({err})"),
    ("pause.loaded", "Partida cargada", "Match loaded"),
    ("pause.no_save", "No hay partida guardada", "No save to load"),
    ("results.title", "RESULTADOS", "RESULTS"),
    ("results.ranking", "Clasificacion final:", "Final ranking:"),
    ("results.rematch", "Revancha", "Rematch"),
    ("results.menu", "Volver al menu", "Back to menu"),
    ("settings.title", "AJUSTES", "SETTINGS"),
    ("settings.section_access", "Accesibilidad", "Accessibility"),
    ("settings.section_audio", "Audio", "Audio"),
    ("settings.section_language", "Idioma", "Language"),
    ("settings.reduce_motion", "Reducir movimiento", "Reduce motion"),
    ("settings.reduce_motion_hint", "Desactiva animaciones de fichas y dado", "Turns off piece and dice animations"),
    ("settings.colorblind", "Modo daltonico", "Colorblind mode"),
    ("settings.colorblind_hint", "Paleta alternativa + insignias de forma", "Alternative palette + shape badges"),
    ("settings.high_contrast", "Alto contraste", "High contrast"),
    ("settings.high_contrast_hint", "Colores mas marcados en el tablero", "Stronger contrast on the board"),
    ("settings.text_scale", "Escala de texto", "Text scale"),
    ("settings.volume_master", "Volumen general", "Master volume"),
    ("settings.volume_sfx", "Volumen efectos", "SFX volume"),
    ("settings.volume_music", "Volumen musica", "Music volume"),
    ("settings.locale", "Idioma", "Language"),
    ("settings.reset", "Restaurar valores", "Reset to defaults"),
    ("settings.back", "Volver", "Back"),
    ("credits.title", "CREDITOS", "CREDITS"),
    ("credits.body",
     "Halloween Critter Royale|Motor: Godot 4.7.2 (GL Compatibility)|"
     "Arte: packs de Assetsvariados (CatPackHalloweenPAID - DarkGhostPaid - DemonicBunnyPaid)|"
     "VFX y audio placeholder: generados por tools/|"
     "Detalle completo en ASSET_MAPPING.md",
     "Halloween Critter Royale|Engine: Godot 4.7.2 (GL Compatibility)|"
     "Art: Assetsvariados packs (CatPackHalloweenPAID - DarkGhostPaid - DemonicBunnyPaid)|"
     "VFX and placeholder audio: generated by tools/|"
     "Full mapping in ASSET_MAPPING.md"),
    ("tutorial.title", "COMO JUGAR", "HOW TO PLAY"),
    ("tutorial.body",
     "Objetivo: lleva las 4 fichas de tu faccion desde la cuna hasta la meta.|"
     "En tu turno tira el dado (Espacio) y elige una ficha (clic o teclas 1-4).|"
     "Solo sales de la cuna con un 6.|"
     "Casillas seguras (madera clara): nadie puede capturarte alli.|"
     "Si caes en una ficha rival, la envias de vuelta a su cuna.|"
     "Portal de Niebla: teletransporta tu ficha. Farolillo Calabaza: bonus extra.|"
     "Gana quien meta las 4 fichas primero.",
     "Goal: march your faction's 4 pieces from the pen to the goal.|"
     "On your turn roll the dice (Space) and pick a piece (click or keys 1-4).|"
     "You only leave the pen on a 6.|"
     "Safe squares (light wood): nobody can capture you there.|"
     "Land on a rival piece to send it back to its pen.|"
     "Fog Portal teleports your piece. Pumpkin Lantern grants a bonus.|"
     "First to bring all 4 pieces home wins."),
]

if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "assets" / "i18n" / "ui.csv"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows(ROWS)
    print(f"wrote {out} ({len(ROWS) - 1} keys, locales es/en)")
