class_name TurnMachine
extends RefCounted
## Explicit transition table for the 14 game states. ALL input (human or bot)
## must pass can() before acting; this is the single anti-double-action guard.

const BOOTING := &"BOOTING"
const MAIN_MENU := &"MAIN_MENU"
const SETUP := &"SETUP"
const STARTING_MATCH := &"STARTING_MATCH"
const WAITING_FOR_ROLL := &"WAITING_FOR_ROLL"
const ROLLING_DICE := &"ROLLING_DICE"
const WAITING_FOR_PIECE_SELECTION := &"WAITING_FOR_PIECE_SELECTION"
const MOVING_PIECE := &"MOVING_PIECE"
const RESOLVING_CAPTURE := &"RESOLVING_CAPTURE"
const RESOLVING_BONUS := &"RESOLVING_BONUS"
const CHECKING_WINNER := &"CHECKING_WINNER"
const NEXT_TURN := &"NEXT_TURN"
const PAUSED := &"PAUSED"
const MATCH_FINISHED := &"MATCH_FINISHED"

const ALL_STATES: Array[StringName] = [
    BOOTING, MAIN_MENU, SETUP, STARTING_MATCH, WAITING_FOR_ROLL, ROLLING_DICE,
    WAITING_FOR_PIECE_SELECTION, MOVING_PIECE, RESOLVING_CAPTURE, RESOLVING_BONUS,
    CHECKING_WINNER, NEXT_TURN, PAUSED, MATCH_FINISHED,
]

const TRANSITIONS := {
    BOOTING: {&"boot_finished": MAIN_MENU},
    MAIN_MENU: {&"open_setup": SETUP},
    SETUP: {&"start_match": STARTING_MATCH, &"back": MAIN_MENU},
    STARTING_MATCH: {&"match_ready": WAITING_FOR_ROLL},
    WAITING_FOR_ROLL: {
        &"roll_requested": ROLLING_DICE,
        &"pause_requested": PAUSED,
        &"match_finished": MATCH_FINISHED,
    },
    ROLLING_DICE: {
        &"roll_settled": WAITING_FOR_PIECE_SELECTION,
        &"roll_settled_pass": NEXT_TURN,
        &"pause_requested": PAUSED,
    },
    WAITING_FOR_PIECE_SELECTION: {
        &"piece_selected": MOVING_PIECE,
        &"bonus_offered": RESOLVING_BONUS,
        &"auto_pass": NEXT_TURN,
        &"pause_requested": PAUSED,
    },
    MOVING_PIECE: {
        &"move_applied": RESOLVING_CAPTURE,
        &"capture_none": RESOLVING_BONUS,
        &"pause_requested": PAUSED,
    },
    RESOLVING_CAPTURE: {&"capture_settled": RESOLVING_BONUS, &"pause_requested": PAUSED},
    RESOLVING_BONUS: {
        &"bonus_settled": CHECKING_WINNER,
        &"bonus_none": CHECKING_WINNER,
        &"pause_requested": PAUSED,
    },
    CHECKING_WINNER: {
        &"winner_found": MATCH_FINISHED,
        &"winner_none": NEXT_TURN,
        &"pause_requested": PAUSED,
    },
    NEXT_TURN: {&"next_turn_ready": WAITING_FOR_ROLL, &"match_finished": MATCH_FINISHED, &"pause_requested": PAUSED},
    PAUSED: {&"resume": &"__resume__", &"quit_match": MAIN_MENU},
    MATCH_FINISHED: {&"rematch": SETUP, &"to_menu": MAIN_MENU},
}

var current: StringName = BOOTING
var _prev: StringName = BOOTING

func reset(state_name: StringName = BOOTING) -> void:
    current = state_name
    _prev = state_name

func can(action: StringName) -> bool:
    if not TRANSITIONS.has(current):
        return false
    return TRANSITIONS[current].has(action)

func apply(action: StringName) -> bool:
    if not can(action):
        return false
    if action == &"resume":
        current = _prev
        return true
    _prev = current
    var target: StringName = TRANSITIONS[current][action]
    if target != &"__resume__":
        current = target
    return true

func try_pause() -> bool:
    return apply(&"pause_requested")

func is_in_match() -> bool:
    return current in [
        WAITING_FOR_ROLL, ROLLING_DICE, WAITING_FOR_PIECE_SELECTION,
        MOVING_PIECE, RESOLVING_CAPTURE, RESOLVING_BONUS, CHECKING_WINNER, NEXT_TURN,
    ] or current == PAUSED
