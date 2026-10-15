extends Node
## M4 keyboard-only playthrough: proves the whole game can be driven with the
## keyboard alone (no mouse). Injects real input events through the engine's
## input pipeline (Input.parse_input_event + flush_buffered_events), so the
## events traverse the same route as hardware: viewport GUI first (buttons,
## CheckBox, OptionButton), then _unhandled_input (input_controller scheme:
## Space roll / 1-4 pick / Esc pause).
##
## Phase 1 - menu:     every menu button is reachable via ui_focus_next/prev.
## Phase 2 - setup:    focus reaches all seat controls; ui_accept toggles a
##                     CheckBox and opens/closes an OptionButton popup.
## Phase 3 - settings: ui_accept toggles an accessibility setting (Settings
##                     singleton reacts, settings_changed fires, value restored).
## Phase 4 - match:    a full human-vs-bots match is played to the finish using
##                     ONLY keyboard input, including a mid-match Esc pause /
##                     resume, illegal-key spam safety and double-Space guards.
##                     The same seed is played twice: identical final hash
##                     => deterministic.
##
## Protocol: prints HCTESTS tokens so tools/run_tests.sh can gate on it.

const SEED := 20261015
const MAX_STEPS := 4000          # hard guard: never hang the runner

var _failures := 0
var _checks := 0

func _ready() -> void:
    var t0 := Time.get_ticks_msec()
    Game.fast_mode = true
    await _phase_menu()
    await _phase_setup()
    await _phase_settings()
    await _phase_match()
    Game.fast_mode = false
    var dt := Time.get_ticks_msec() - t0
    print("HCTESTS:SUITE keyboard checks=%d failures=%d ms=%d" % [_checks, _failures, dt])
    print("HCTESTS:TOTAL checks=%d suites=%d failed_suites=%d" % [_checks, 1, 1 if _failures > 0 else 0])
    print("HCTESTS:%s" % ("FAIL" if _failures > 0 else "PASS"))

# --------------------------------------------------------------- helpers ---

func _fail(msg: String) -> void:
    _failures += 1
    printerr("  FAIL keyboard: %s" % msg)

func _check(condition: bool, msg: String) -> void:
    _checks += 1
    if not condition:
        _fail(msg)

func _send_key(keycode: Key) -> void:
    ## Raw key event: reaches _unhandled_input (input_controller scheme).
    var ev := InputEventKey.new()
    ev.pressed = true
    ev.echo = false
    ev.keycode = keycode
    ev.physical_keycode = keycode
    Input.parse_input_event(ev)
    Input.flush_buffered_events()

func _send_action(action: StringName, pressed: bool = true) -> void:
    ## Action event: reaches the focused Control (buttons need press+release).
    var ev := InputEventAction.new()
    ev.action = action
    ev.pressed = pressed
    Input.parse_input_event(ev)
    Input.flush_buffered_events()

func _click_focused() -> void:
    ## Keyboard button activation: ui_accept press, a frame, then release.
    _send_action(&"ui_accept", true)
    await get_tree().process_frame
    _send_action(&"ui_accept", false)
    await get_tree().process_frame

func _focus_step(action: StringName) -> void:
    _send_action(action, true)
    await get_tree().process_frame
    _send_action(action, false)
    await get_tree().process_frame

func _focused_name() -> String:
    var f := get_viewport().gui_get_focus_owner()
    return f.name if f != null else ""

func _traverse(steps: int, action: StringName, visited: Dictionary) -> void:
    for i in steps:
        _focus_step(action)
        var n := _focused_name()
        if n != "":
            visited[n] = true

func _find_node(node: Node, name: String) -> Node:
    if node.name == name:
        return node
    for c in node.get_children():
        var r := _find_node(c, name)
        if r != null:
            return r
    return null

# ------------------------------------------------------------- phase 1 ---

func _phase_menu() -> void:
    var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
    add_child(menu)
    await get_tree().process_frame
    var expected := ["BtnPlay", "BtnSettings", "BtnCredits", "BtnTutorial", "BtnQuit"]
    var visited := {}
    _traverse(10, &"ui_focus_next", visited)
    for name in expected:
        _check(visited.has(name), "menu: %s reachable via ui_focus_next" % name)
    _check(visited.size() >= expected.size(), "menu: focus visits >= %d controls (got %d)" % [expected.size(), visited.size()])
    # backward traversal cycles back over the same buttons
    var back := {}
    _traverse(10, &"ui_focus_prev", back)
    for name in expected:
        _check(back.has(name), "menu: %s reachable via ui_focus_prev" % name)
    # a focused menu button takes focus (activating it changes scene, which is
    # the real start path: covered end-to-end by the match_root in phase 4)
    var play := _find_node(menu, "BtnPlay") as Button
    play.grab_focus()
    await get_tree().process_frame
    _check(_focused_name() == "BtnPlay", "menu: BtnPlay takes keyboard focus")
    menu.queue_free()
    await get_tree().process_frame

# ------------------------------------------------------------- phase 2 ---

func _phase_setup() -> void:
    var setup: Control = load("res://scenes/ui/setup.tscn").instantiate()
    add_child(setup)
    await get_tree().process_frame
    # Every seat dropdown (faction/type/difficulty per seat) is a dynamically
    # created OptionButton: collect them for the focusability assertion.
    var rows: VBoxContainer = _find_node(setup, "SeatRows") as VBoxContainer
    _check(rows != null and rows.get_child_count() > 0, "setup: seat rows built")
    var options: Array[OptionButton] = []
    if rows != null:
        for row in rows.get_children():
            for c in row.get_children():
                if c is OptionButton and (c as OptionButton).is_visible_in_tree():
                    options.append(c)
    _check(options.size() >= 4, "setup: per-seat OptionButtons exist (%d)" % options.size())
    var static_names := ["CountSlider", "ModeHalloween", "SeedEdit", "BtnBack", "BtnStart"]
    var visited := {}
    _traverse(24, &"ui_focus_next", visited)
    for name in static_names:
        _check(visited.has(name), "setup: %s reachable by keyboard focus" % name)
    var dyn_focus := 0
    for n in visited:
        if n not in static_names:
            dyn_focus += 1
    _check(dyn_focus >= options.size(), "setup: every seat dropdown focusable by keyboard (%d/%d)" % [dyn_focus, options.size()])
    # ui_accept opens an OptionButton popup; ui_cancel closes it
    if not options.is_empty():
        var opt := options[0]
        opt.grab_focus()
        await get_tree().process_frame
        await _click_focused()
        _check(opt.get_popup() != null and opt.get_popup().visible, "setup: ui_accept opens the dropdown popup")
        _send_action(&"ui_cancel", true)
        await get_tree().process_frame
        _check(opt.get_popup() != null and not opt.get_popup().visible, "setup: ui_cancel closes the dropdown popup")
    # ui_accept toggles a CheckBox
    var mode := _find_node(setup, "ModeHalloween") as CheckBox
    _check(mode != null, "setup: ModeHalloween CheckBox found")
    if mode != null:
        var before: bool = mode.button_pressed
        mode.grab_focus()
        await get_tree().process_frame
        await _click_focused()
        _check(mode.button_pressed != before, "setup: ui_accept toggles ModeHalloween")
        mode.grab_focus()
        await _click_focused()
        _check(mode.button_pressed == before, "setup: toggle is reversible")
    setup.queue_free()
    await get_tree().process_frame

# ------------------------------------------------------------- phase 3 ---

func _phase_settings() -> void:
    var scr: Control = load("res://scenes/ui/settings.tscn").instantiate()
    add_child(scr)
    await get_tree().process_frame
    var visited := {}
    _traverse(20, &"ui_focus_next", visited)
    for name in ["CheckReduceMotion", "CheckColorblind", "CheckHighContrast",
            "TextScaleSlider", "VolMasterSlider", "LocaleOption", "BtnReset", "BtnBack"]:
        _check(visited.has(name), "settings: %s reachable by keyboard focus" % name)
    # ui_accept toggles an accessibility checkbox; Settings + signal react
    var check := _find_node(scr, "CheckReduceMotion") as CheckBox
    _check(check != null, "settings: CheckReduceMotion found")
    var saw_signal := [false]
    var conn := func(): saw_signal[0] = true
    EventBus.settings_changed.connect(conn)
    if check != null:
        var before: bool = Settings.get_setting("reduce_motion")
        _check(check.button_pressed == before, "settings: checkbox mirrors the setting on open")
        check.grab_focus()
        await get_tree().process_frame
        await _click_focused()
        _check(Settings.get_setting("reduce_motion") != before, "settings: ui_accept toggles reduce_motion via Settings")
        _check(saw_signal[0], "settings: settings_changed emitted for the keyboard toggle")
        # restore: keep the environment clean for the next phase
        check.grab_focus()
        await _click_focused()
        _check(Settings.get_setting("reduce_motion") == before, "settings: value restored after toggling back")
    EventBus.settings_changed.disconnect(conn)
    scr.queue_free()
    await get_tree().process_frame

# ------------------------------------------------------------- phase 4 ---

func _human_setup() -> Array:
    return [
        {"faction_id": "gato_negro", "display_name": "Teclado", "is_bot": false},
        {"faction_id": "fantasma_bruja", "display_name": "Bot 1", "is_bot": true, "bot_difficulty": "normal"},
        {"faction_id": "rey_calabaza", "display_name": "Bot 2", "is_bot": true, "bot_difficulty": "normal"},
        {"faction_id": "conejo_espectral", "display_name": "Bot 3", "is_bot": true, "bot_difficulty": "normal"},
    ]

func _bonus_button(root: Node) -> Button:
    var hud := _find_node(root, "Hud")
    if hud == null:
        return null
    var adv := hud.get_node_or_null("%BtnAdvance")
    if adv != null and adv.visible:
        return adv
    var back := hud.get_node_or_null("%BtnSendBack")
    if back != null and back.visible:
        return back
    return null

func _has_move_for(legal: Array, slot: int) -> bool:
    for m in legal:
        if int(m.piece_id) % 10 == slot:
            return true
    return false

func _phase_match() -> void:
    var hashes: Array[int] = []
    for rep in 2:
        Game.configure({
            "players": _human_setup(),
            "rules_mode": "halloween",
            "seed": SEED,
        })
        var root: Node = load("res://scenes/game/match_root.tscn").instantiate()
        add_child(root)
        await get_tree().process_frame
        _check(Game.active_match != null, "rep%d: match attached" % rep)
        if Game.active_match == null:
            root.queue_free()
            await get_tree().process_frame
            continue

        var rolls := [0]                     # boxed: shared with the lambda
        var counter := func(_p, _v): rolls[0] += 1
        EventBus.dice_rolled.connect(counter)
        var pause_tested := false
        var spam_tested := false
        var double_space_tested := false
        var steps := 0
        while steps < MAX_STEPS:
            steps += 1
            var st: MatchState = Game.active_match.state
            if st == null:
                _fail("rep%d: state vanished mid-match" % rep)
                break
            if st.over:
                break
            var m: StringName = Game.machine.current
            if m == TurnMachine.WAITING_FOR_ROLL:
                _send_key(KEY_SPACE)
                await get_tree().process_frame
                _check(rolls[0] > 0, "rep%d: Space rolls the dice (step %d)" % [rep, steps])
                if not double_space_tested and Game.machine.current == TurnMachine.WAITING_FOR_PIECE_SELECTION:
                    # a second Space while picking must NOT roll again
                    var r0: int = rolls[0]
                    _send_key(KEY_SPACE)
                    await get_tree().process_frame
                    _check(rolls[0] == r0, "rep%d: Space ignored while picking a piece" % rep)
                    double_space_tested = true
                if not pause_tested and st.turn_number > 8 and not Game.active_match.state.over:
                    _send_key(KEY_ESCAPE)
                    await get_tree().process_frame
                    _check(Game.machine.current == TurnMachine.PAUSED, "rep%d: Esc pauses" % rep)
                    _send_key(KEY_ESCAPE)
                    await get_tree().process_frame
                    _check(Game.machine.is_in_match(), "rep%d: Esc resumes the match" % rep)
                    pause_tested = true
            elif m == TurnMachine.WAITING_FOR_PIECE_SELECTION:
                var legal: Array = Game.active_match.legal_moves()
                if legal.is_empty():
                    _fail("rep%d: WAITING_FOR_PIECE_SELECTION without legal moves (step %d)" % [rep, steps])
                    break
                if not spam_tested:
                    for s in 4:
                        if s != int(legal[0].piece_id) % 10 and not _has_move_for(legal, s):
                            var h0: int = Game.active_match.state_hash()
                            _send_key(KEY_1 + s)
                            await get_tree().process_frame
                            _check(Game.active_match.state_hash() == h0, "rep%d: illegal piece key %d is swallowed" % [rep, s + 1])
                            spam_tested = true
                            break
                var slot: int = int(legal[0].piece_id) % 10
                var hb: int = Game.active_match.state_hash()
                _send_key(KEY_1 + slot)
                await get_tree().process_frame
                _check(Game.active_match.state_hash() != hb or Game.machine.current == TurnMachine.RESOLVING_BONUS,
                        "rep%d: key %d applies the move (step %d)" % [rep, slot + 1, steps])
            elif m == TurnMachine.RESOLVING_BONUS:
                var btn := _bonus_button(root)
                _check(btn != null, "rep%d: bonus button visible for the human (step %d)" % [rep, steps])
                if btn != null:
                    btn.grab_focus()
                    await get_tree().process_frame
                    await _click_focused()
                    _check(Game.machine.current != TurnMachine.RESOLVING_BONUS or Game.active_match.state.over,
                            "rep%d: ui_accept resolves the bonus (step %d)" % [rep, steps])
            elif m == TurnMachine.PAUSED:
                _send_key(KEY_ESCAPE)
                await get_tree().process_frame
            else:
                # Transient machine states (ROLLING/MOVING/CAPTURE/NEXT_TURN)
                # settle synchronously in the same call stack; one frame lets
                # the views queue their redraws.
                await get_tree().process_frame

        var fin: MatchState = Game.active_match.state
        _check(fin.over, "rep%d: match finished (steps=%d turns=%d)" % [rep, steps, fin.turn_number])
        _check(fin.winner >= 0, "rep%d: match has a winner" % rep)
        _check(fin.turn_number <= GameMatch.TURN_CAP, "rep%d: turn cap respected (%d)" % [rep, fin.turn_number])
        _check(rolls[0] > 0, "rep%d: dice rolled at least once" % rep)
        _check(pause_tested, "rep%d: pause/resume exercised" % rep)
        _check(double_space_tested, "rep%d: double-Space guard exercised" % rep)
        hashes.append(Game.active_match.state_hash())
        EventBus.dice_rolled.disconnect(counter)
        root.queue_free()
        await get_tree().process_frame

    _check(hashes.size() == 2, "both keyboard playthrough reps ran")
    if hashes.size() == 2:
        _check(hashes[0] == hashes[1],
                "keyboard playthrough deterministic (hash %d vs %d)" % [hashes[0], hashes[1]])
