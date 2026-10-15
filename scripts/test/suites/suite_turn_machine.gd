extends HCTestCase

func suite_name() -> String:
    return "turn_machine"

func run() -> void:
    var tm := TurnMachine.new()
    check_eq(tm.current, TurnMachine.BOOTING, "starts BOOTING")
    check_eq(TurnMachine.ALL_STATES.size(), 14, "14 states in the table")
    for s in TurnMachine.ALL_STATES:
        check(TurnMachine.TRANSITIONS.has(s), "state %s has transitions" % s)
    check_eq(TurnMachine.TRANSITIONS.size(), 14, "exactly 14 transition rows")

    check(tm.apply(&"boot_finished"), "boot_finished applies")
    check_eq(tm.current, TurnMachine.MAIN_MENU, "now MAIN_MENU")
    check(tm.apply(&"open_setup"), "open_setup applies")
    check_eq(tm.current, TurnMachine.SETUP, "now SETUP")
    check(tm.apply(&"start_match"), "start_match applies")
    check_eq(tm.current, TurnMachine.STARTING_MATCH, "now STARTING_MATCH")
    check(tm.apply(&"match_ready"), "match_ready applies")
    check_eq(tm.current, TurnMachine.WAITING_FOR_ROLL, "now WAITING_FOR_ROLL")
    check(tm.apply(&"roll_requested"), "roll_requested applies")
    check_eq(tm.current, TurnMachine.ROLLING_DICE, "now ROLLING_DICE")
    check(tm.apply(&"roll_settled"), "roll_settled applies")
    check_eq(tm.current, TurnMachine.WAITING_FOR_PIECE_SELECTION, "now WAITING_FOR_PIECE_SELECTION")
    check(tm.apply(&"piece_selected"), "piece_selected applies")
    check_eq(tm.current, TurnMachine.MOVING_PIECE, "now MOVING_PIECE")
    check(tm.apply(&"move_applied"), "move_applied applies")
    check_eq(tm.current, TurnMachine.RESOLVING_CAPTURE, "now RESOLVING_CAPTURE")
    check(tm.apply(&"capture_settled"), "capture_settled applies")
    check_eq(tm.current, TurnMachine.RESOLVING_BONUS, "now RESOLVING_BONUS")
    check(tm.apply(&"bonus_settled"), "bonus_settled applies")
    check_eq(tm.current, TurnMachine.CHECKING_WINNER, "now CHECKING_WINNER")
    check(tm.apply(&"winner_found"), "winner_found applies")
    check_eq(tm.current, TurnMachine.MATCH_FINISHED, "now MATCH_FINISHED")
    check(tm.apply(&"rematch"), "rematch applies")
    check_eq(tm.current, TurnMachine.SETUP, "rematch returns to SETUP")

    tm.reset(TurnMachine.ROLLING_DICE)
    check(tm.apply(&"roll_settled_pass"), "pass path applies")
    check_eq(tm.current, TurnMachine.NEXT_TURN, "now NEXT_TURN")
    check(tm.apply(&"next_turn_ready"), "next_turn_ready applies")
    check_eq(tm.current, TurnMachine.WAITING_FOR_ROLL, "back to WAITING_FOR_ROLL")

    check(not tm.can(&"bogus_action"), "unknown action rejected")
    check(not tm.apply(&"bogus_action"), "unknown action not applied")
    check_eq(tm.current, TurnMachine.WAITING_FOR_ROLL, "state unchanged")
    check(not tm.can(&"piece_selected"), "piece_selected invalid while waiting for roll")

    var in_match := [
        TurnMachine.WAITING_FOR_ROLL, TurnMachine.ROLLING_DICE,
        TurnMachine.WAITING_FOR_PIECE_SELECTION, TurnMachine.MOVING_PIECE,
        TurnMachine.RESOLVING_CAPTURE, TurnMachine.RESOLVING_BONUS,
        TurnMachine.CHECKING_WINNER, TurnMachine.NEXT_TURN,
    ]
    for s in in_match:
        tm.reset(s)
        check(tm.is_in_match(), "in match at %s" % s)
        check(tm.can(&"pause_requested"), "pause allowed from %s" % s)
        check(tm.apply(&"pause_requested"), "paused from %s" % s)
        check_eq(tm.current, TurnMachine.PAUSED, "is PAUSED")
        check(tm.apply(&"resume"), "resume from PAUSED")
        check_eq(tm.current, s, "resumed to %s" % s)
    tm.reset(TurnMachine.MAIN_MENU)
    check(not tm.is_in_match(), "not in match at MAIN_MENU")
    check(not tm.can(&"pause_requested"), "pause rejected in menu")
    check(not tm.can(&"resume"), "resume rejected outside pause")
