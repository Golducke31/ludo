extends Node
## Signal-only global bus. Core logic never calls views through this bus;
## views listen. Payloads are plain data (ints, Strings, Dictionaries) —
## never live Node references, so headless runs can use it unchanged.

signal boot_finished
signal open_setup_requested
signal setup_back_requested
signal match_started(player_count: int, rules_mode: String)
signal turn_changed(player_index: int, turn_number: int)
signal dice_rolled(player_index: int, value: int)
signal dice_roll_started(player_index: int)
signal move_options_changed(move_count: int)
signal piece_moved(piece_id: int, to_index: int, path: String)
signal pieces_captured(piece_ids: Array, by_player: int)
signal portal_triggered(piece_id: int)
signal piece_exited(piece_id: int)
signal bonus_offered(piece_id: int, choices: Array)
signal bonus_resolved(choice: String)
signal extra_turn_granted(player_index: int, chain: int)
signal extra_turn_forfeit(player_index: int)
signal player_finished(player_index: int, rank: int)
signal match_finished(ranking: Array)
signal match_abandoned
signal rematch_requested
signal settings_changed
signal camera_mode_changed(mode: int)
