class_name GameManager
extends Node
## Game orchestrator (autoload "Game").
## Owns the active GameMatch + TurnMachine, routes guarded input, drives bots
## and translates core results into EventBus signals for the views.
## Every public request goes through TurnMachine.can(): this is the single
## anti-double-action guard. Notifications are cosmetic; in fast/headless mode
## they settle the same frame, so views can never desync the logic.

const MATCH_ROOT_PATH := "res://scenes/game/match_root.tscn"
const SETUP_PATH := "res://scenes/ui/setup.tscn"
const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const SAVE_SLOT := "match"

signal state_changed(new_state: StringName)
signal match_attached

var rules: MatchRules
var active_match: GameMatch
var layout: BoardLayout
var machine := TurnMachine.new()
var factions: Dictionary = {}       # id -> FactionData
var players_setup: Array = []
var bots: Dictionary = {}           # player_index -> BotPlayer
var human_indices: Array[int] = []
var seed_value := 0
var fast_mode := false              # headless/tests: bots act synchronously
var configured := false
var match_root: Node = null

var _bot_loop_active := false
var _bot_async_active := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_factions()

func _load_factions() -> void:
    factions.clear()
    var dir := DirAccess.open("res://data/factions")
    if dir == null:
        return
    for name in dir.get_files():
        if not name.ends_with(".tres"):
            continue
        var res := load("res://data/factions/" + name) as FactionDataResource
        if res != null:
            var f := res.to_faction()
            factions[f.id] = f

func faction(id: StringName) -> FactionData:
    return factions.get(id, null)

# ------------------------------------------------------------- lifecycle ---

func configure(cfg: Dictionary) -> void:
    players_setup = cfg.get("players", [])
    var mode := String(cfg.get("rules_mode", "halloween"))
    rules = MatchRules.create_classic() if mode == "classic" else MatchRules.create_default()
    seed_value = int(cfg.get("seed", randi()))
    configured = true

func begin_match() -> void:
    if not configured:
        push_error("Game: configure() must be called before begin_match()")
        return
    active_match = GameMatch.new(rules, players_setup, seed_value)
    layout = BoardLayout.new(rules)
    bots.clear()
    human_indices.clear()
    for i in players_setup.size():
        var p: Dictionary = players_setup[i]
        if bool(p.get("is_bot", true)):
            bots[i] = BotPlayer.new(StringName(str(p.get("bot_difficulty", "normal"))), hash("%d:%d" % [seed_value, i]))
        else:
            human_indices.append(i)
    machine.reset(TurnMachine.STARTING_MATCH)
    _fire(&"match_ready")
    Stats.add_stat("matches_started", 1)
    EventBus.match_started.emit(players_setup.size(), "halloween" if rules.halloween_enabled else "classic")
    match_attached.emit()
    prompt_turn()

func attach(root: Node) -> void:
    match_root = root

func abandon_match() -> void:
    if active_match != null:
        Stats.add_stat("matches_abandoned", 1)
    active_match = null
    machine.reset(TurnMachine.MAIN_MENU)
    EventBus.match_abandoned.emit()

# ------------------------------------------------------------------ flow ---

func is_human_turn() -> bool:
    if active_match == null or active_match.state.over:
        return false
    return not bots.has(active_match.state.current)

func current_faction() -> FactionData:
    if active_match == null:
        return null
    return faction(active_match.state.players[active_match.state.current].faction_id)

func prompt_turn() -> void:
    if active_match == null:
        return
    if active_match.state.over:
        _finish_match()
        return
    EventBus.turn_changed.emit(active_match.state.current, active_match.state.turn_number)
    state_changed.emit(machine.current)
    var cur := active_match.state.current
    if bots.has(cur):
        # Guard against re-entrancy: _do_roll/_do_move settle turns (which call
        # prompt_turn again) while a bot loop is already driving the match.
        if fast_mode:
            if not _bot_loop_active:
                _run_bot_turn()
        elif not _bot_async_active:
            _bot_async_active = true
            await _bot_turn_async()
            _bot_async_active = false

func _bot_turn_async() -> void:
    ## Paced bot play for the interactive (non-fast) mode. Re-reads the current
    ## player every iteration so consecutive bot turns chain in one loop.
    while active_match != null and not active_match.state.over and machine.is_in_match():
        var player := active_match.state.current
        if not bots.has(player):
            break
        if machine.current == TurnMachine.WAITING_FOR_ROLL:
            await get_tree().create_timer(0.4).timeout
            if _stale(player):
                return
            _do_roll()
        elif machine.current == TurnMachine.WAITING_FOR_PIECE_SELECTION:
            await get_tree().create_timer(0.35).timeout
            if _stale(player):
                return
            _bot_move()
        elif machine.current == TurnMachine.RESOLVING_BONUS:
            await get_tree().create_timer(0.3).timeout
            if _stale(player):
                return
            _bot_bonus()
        else:
            return

func _stale(player: int) -> bool:
    return active_match == null or active_match.state.over or active_match.state.current != player \
        or not machine.is_in_match() or machine.current == TurnMachine.PAUSED

func _bot_move() -> void:
    var bot: BotPlayer = bots.get(active_match.state.current, null)
    if bot == null:
        return
    var legal := active_match.legal_moves()
    if legal.is_empty():
        return
    var mv: Variant = bot.choose_move(active_match, legal)
    if mv == null:
        return
    _do_move(mv)

func _bot_bonus() -> void:
    var bot: BotPlayer = bots.get(active_match.state.current, null)
    if bot == null:
        return   # a HUMAN bonus is never auto-resolved by the bot loop
    var choices := active_match.bonus_choices()
    var ch: Variant = bot.choose_bonus(active_match, choices)
    if ch == null:
        ch = &"advance"
    _do_bonus(ch)

func _run_bot_turn() -> void:
    ## Synchronous bot play: runs consecutive bot turns (including extra turns)
    ## until a human input is needed or the match ends.
    _bot_loop_active = true
    var guard := 0
    while active_match != null and not active_match.state.over and guard < 10000:
        guard += 1
        if machine.current == TurnMachine.WAITING_FOR_ROLL:
            if not bots.has(active_match.state.current):
                break
            _do_roll()
        elif machine.current == TurnMachine.WAITING_FOR_PIECE_SELECTION:
            if not bots.has(active_match.state.current):
                break
            _bot_move()
            if active_match.state.over:
                break
        elif machine.current == TurnMachine.RESOLVING_BONUS:
            if not bots.has(active_match.state.current):
                break
            _bot_bonus()
        else:
            break
    _bot_loop_active = false

# ------------------------------------------------------------- core steps ---

func _do_roll() -> void:
    # The TurnMachine must enter ROLLING_DICE before the core mutates state,
    # otherwise the roll_settled* transitions have no legal source state.
    if not _fire(&"roll_requested"):
        return
    EventBus.dice_roll_started.emit(active_match.state.current)
    var r: Dictionary = active_match.roll_dice()
    if not bool(r.get("ok", false)):
        push_warning("Game: roll failed: %s" % str(r.get("error", "?")))
        return
    EventBus.dice_rolled.emit(active_match.state.current, int(r["roll"]))
    if bool(r.get("penalty", false)):
        EventBus.extra_turn_forfeit.emit(active_match.state.current)
    if bool(r.get("auto_pass", false)):
        _fire(&"roll_settled_pass")
        _settle_after_roll()
    else:
        EventBus.move_options_changed.emit(int(r.get("moves", 0)))
        _fire(&"roll_settled")

func _settle_after_roll() -> void:
    ## After an auto-pass roll the machine sits at NEXT_TURN.
    if active_match.state.over:
        _finish_now()
        return
    _fire(&"next_turn_ready")
    prompt_turn()

func _do_move(mv: Move) -> void:
    var r: Dictionary = active_match.apply_move(mv)
    if not bool(r.get("ok", false)):
        push_warning("Game: move rejected: %s" % str(r.get("error", "?")))
        return
    var events: Array = r["events"]
    var final_progress := active_match.state.piece_by_id(mv.piece_id).progress
    EventBus.piece_moved.emit(mv.piece_id, final_progress, String(mv.action))
    for ev in events:
        var type := StringName(str((ev as Dictionary).get("type", "")))
        match type:
            &"captured":
                EventBus.pieces_captured.emit((ev as Dictionary)["pieces"], int((ev as Dictionary)["by"]))
            &"bonus_offered":
                EventBus.bonus_offered.emit(mv.piece_id, active_match.bonus_choices())
            &"portal":
                EventBus.portal_triggered.emit(mv.piece_id)
            &"exited":
                EventBus.piece_exited.emit(mv.piece_id)
    _fire(&"piece_selected")
    _fire(&"move_applied")
    _fire(&"capture_settled")
    if active_match.state.over:
        _finish_now()
        return
    if not active_match.state.pending_bonus.is_empty():
        return   # wait for the bonus choice (machine stays at RESOLVING_BONUS)
    _fire(&"bonus_none")
    _settle_turn(r)

func _do_bonus(choice: StringName) -> void:
    if active_match.state.pending_bonus.is_empty():
        return
    var r: Dictionary = active_match.resolve_bonus(choice)
    EventBus.bonus_resolved.emit(String(choice))
    if active_match.state.over:
        _finish_now()
        return
    _fire(&"bonus_settled")
    _settle_turn(r)

func _settle_turn(r: Dictionary) -> void:
    if active_match.state.over:
        _finish_now()
        return
    _fire(&"winner_none")
    if bool(r.get("extra_turn", false)):
        EventBus.extra_turn_granted.emit(active_match.state.current, active_match.state.players[active_match.state.current].extra_chain)
    _fire(&"next_turn_ready")
    prompt_turn()

func _finish_now() -> void:
    ## Finish from any mid-action state, routing through the transition table
    ## so the machine always ends at MATCH_FINISHED (never a half state).
    if machine.can(&"bonus_settled"):
        _fire(&"bonus_settled")
    if machine.can(&"winner_found"):
        _fire(&"winner_found")
    elif machine.can(&"match_finished"):
        _fire(&"match_finished")
    _finish_match()

func _finish_match() -> void:
    if active_match == null:
        return
    var winner := active_match.state.winner
    var entry: Dictionary = players_setup[winner] if winner >= 0 and winner < players_setup.size() else {}
    Stats.record_finish(String(entry.get("faction_id", "gato_negro")), bool(entry.get("is_bot", true)), active_match.state.turn_number)
    EventBus.match_finished.emit(active_match.state.ranking)
    state_changed.emit(TurnMachine.MATCH_FINISHED)

func _fire(action: StringName) -> bool:
    if not machine.can(action):
        push_warning("Game: illegal transition %s from %s" % [String(action), String(machine.current)])
        return false
    machine.apply(action)
    state_changed.emit(machine.current)
    return true

# --------------------------------------------------------------- requests ---

func request_roll() -> bool:
    if active_match == null or active_match.state.over:
        return false
    if not machine.can(&"roll_requested"):
        return false
    if bots.has(active_match.state.current):
        return false
    _do_roll()
    return true

func request_move(piece_id: int) -> bool:
    if active_match == null or active_match.state.over:
        return false
    if not machine.can(&"piece_selected"):
        return false
    if bots.has(active_match.state.current):
        return false
    for m in active_match.legal_moves():
        if m.piece_id == piece_id:
            _do_move(m)
            return true
    return false

func request_bonus(choice: StringName) -> bool:
    if active_match == null or active_match.state.over:
        return false
    if machine.current != TurnMachine.RESOLVING_BONUS:
        return false
    if bots.has(active_match.state.current):
        return false
    var choices := active_match.bonus_choices()
    if not choices.is_empty() and not choices.has(choice):
        return false
    _do_bonus(choice)
    return true

func request_pause() -> bool:
    if not machine.can(&"pause_requested"):
        return false
    _fire(&"pause_requested")
    return true

func request_resume() -> bool:
    if machine.current != TurnMachine.PAUSED:
        return false
    _fire(&"resume")
    prompt_turn()
    return true

func request_rematch() -> bool:
    # Guard first: input spam must be silently rejected, never warned about.
    if not machine.can(&"rematch"):
        return false
    _fire(&"rematch")
    begin_match()
    return true

func request_to_menu() -> bool:
    abandon_match()
    return true

# ------------------------------------------------------------- save/load ---

func save_current() -> Error:
    if active_match == null:
        return ERR_UNCONFIGURED
    return Save.save_match(active_match.to_dict(), SAVE_SLOT)

func has_save() -> bool:
    return Save.has_save(SAVE_SLOT)

func load_current() -> bool:
    var d := Save.load_match(SAVE_SLOT)
    if d.is_empty():
        return false
    active_match = GameMatch.from_dict(d)
    rules = active_match.rules
    layout = BoardLayout.new(rules)
    bots.clear()
    human_indices.clear()
    for p in active_match.state.players:
        if p.is_bot:
            bots[p.player_index] = BotPlayer.new(p.bot_difficulty, hash("%d:%d" % [active_match.state.seed_value, p.player_index]))
        else:
            human_indices.append(p.player_index)
    players_setup = []
    for p in active_match.state.players:
        players_setup.append({
            "faction_id": String(p.faction_id),
            "display_name": p.display_name,
            "is_bot": p.is_bot,
            "bot_difficulty": String(p.bot_difficulty),
        })
    if not active_match.state.pending_bonus.is_empty():
        machine.reset(TurnMachine.RESOLVING_BONUS)
    elif active_match.state.dice_value > 0 and active_match.has_legal_moves():
        machine.reset(TurnMachine.WAITING_FOR_PIECE_SELECTION)
    else:
        machine.reset(TurnMachine.WAITING_FOR_ROLL)
    EventBus.match_started.emit(active_match.state.players.size(), "halloween" if rules.halloween_enabled else "classic")
    prompt_turn()
    return true
