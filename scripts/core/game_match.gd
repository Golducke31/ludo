class_name GameMatch
extends RefCounted
## THE only mutator of MatchState. Node-free, headless-safe: no signals, no
## awaits, no RNG other than the injected RngStream. Views observe results;
## they can never influence logic (desync-proof by construction).

const TURN_CAP := 1500   # safety valve for runaway matches (test invariant)
const PEN := -1          # piece progress value inside the pen (guarida)

var state: MatchState
var geo: BoardGeometry
var rng: RngStream
var log: EventLog
var rules: MatchRules

func _init(p_rules: MatchRules = null, setup: Array = [], p_seed: int = 0, forced_rolls: Array = []) -> void:
    if p_rules == null:
        return   # used by from_dict(); caller fills fields afterwards
    rules = p_rules
    geo = BoardGeometry.new(p_rules)
    rng = RngStream.new(p_seed)
    if not forced_rolls.is_empty():
        rng.force_next(forced_rolls)
    log = EventLog.new()
    state = MatchState.new()
    state.rules = p_rules
    state.seed_value = p_seed
    state.started_unix = int(Time.get_unix_time_from_system())
    state.current = 0
    state.turn_number = 0
    state.dice_value = 0
    for i in setup.size():
        var cfg: Dictionary = setup[i]
        var p := PlayerState.new()
        p.player_index = i
        p.faction_id = StringName(str(cfg.get("faction_id", "gato_negro")))
        p.display_name = str(cfg.get("display_name", "P%d" % i))
        p.is_bot = bool(cfg.get("is_bot", true))
        p.bot_difficulty = StringName(str(cfg.get("bot_difficulty", "normal")))
        for slot in p_rules.pieces_per_player:
            p.pieces.append(PieceState.new(p_rules, i * 10 + slot, i, slot))
        state.players.append(p)
    log.add(&"match_started", 0, {"players": setup.size(), "seed": p_seed})

# ------------------------------------------------------------------ dice ---

func roll_dice() -> Dictionary:
    if state.over:
        return {"ok": false, "error": "match_over"}
    if not state.pending_bonus.is_empty():
        return {"ok": false, "error": "bonus_pending"}
    if state.dice_value > 0:
        return {"ok": false, "error": "already_rolled"}
    var value := rng.roll_d6()
    state.dice_value = value
    log.add(&"dice_rolled", state.current, {"value": value}, state.turn_number)
    var p := state.players[state.current]
    # Third consecutive 6 with a legal action available loses the turn (policy).
    if value == rules.exit_dice_value and rules.third_six_penalty \
            and p.extra_chain >= rules.extra_turn_cap - 1:
        p.extra_chain = 0
        _end_turn()
        return {"ok": true, "roll": value, "penalty": true, "auto_pass": true, "moves": []}
    var moves := legal_moves()
    if moves.is_empty():
        p.extra_chain = 0
        _end_turn()
        return {"ok": true, "roll": value, "auto_pass": true, "moves": []}
    return {"ok": true, "roll": value, "auto_pass": false, "moves": moves.size()}

# ----------------------------------------------------------------- moves ---

func legal_moves(player_index := -1) -> Array[Move]:
    var moves: Array[Move] = []
    if state.over or not state.pending_bonus.is_empty():
        return moves
    var pi := player_index if player_index >= 0 else state.current
    var p := state.players[pi]
    var d := state.dice_value
    if d <= 0 or pi < 0 or pi >= state.players.size():
        return moves
    for piece in p.pieces:
        if piece.in_goal():
            continue
        if piece.in_pen():
            if d == rules.exit_dice_value:
                var exit_move := Move.new()
                exit_move.action = &"exit"
                exit_move.piece_id = piece.id
                exit_move.player_index = pi
                exit_move.from_progress = piece.progress
                exit_move.to_progress = 0
                exit_move.steps = 0
                moves.append(exit_move)
        else:
            var target := piece.progress + d
            if target <= rules.total_route_steps():
                var step := Move.new()
                step.action = &"step"
                step.piece_id = piece.id
                step.player_index = pi
                step.from_progress = piece.progress
                step.to_progress = target
                step.steps = d
                moves.append(step)
    return moves

func has_legal_moves() -> bool:
    return not legal_moves().is_empty()

func apply_move(mv: Move) -> Dictionary:
    if state.over:
        return {"ok": false, "error": "match_over"}
    if not state.pending_bonus.is_empty():
        return {"ok": false, "error": "bonus_pending"}
    var legal := legal_moves()
    var match_move: Move = null
    for m in legal:
        if m.piece_id == mv.piece_id and m.to_progress == mv.to_progress and m.action == mv.action:
            match_move = m
            break
    if match_move == null:
        return {"ok": false, "error": "illegal_move"}
    var piece := state.piece_by_id(match_move.piece_id)
    var p := state.players[piece.owner]
    var events: Array[Dictionary] = []
    if match_move.action == &"exit":
        piece.progress = 0
        events.append({"type": &"exited", "piece": piece.id, "to": 0})
    else:
        piece.progress = match_move.to_progress
    # special squares on the ring: the portal may teleport BEFORE captures,
    # so captures always resolve at the FINAL destination
    if piece.on_ring():
        var special := geo.special_at(piece.ring_index())
        match special:
            &"portal":
                var np := piece.progress + rules.portal_bonus
                if np >= rules.home_steps:
                    np = rules.home_steps - 1
                piece.progress = np
                events.append({"type": &"portal", "piece": piece.id, "to": np})
            &"lantern":
                state.pending_bonus = {"type": &"lantern", "piece_id": piece.id}
                events.append({"type": &"bonus_offered", "piece": piece.id})
            &"candy":
                if not p.candy_used:
                    p.candy_used = true
                    p.candy_extra_pending = true
                    events.append({"type": &"candy", "piece": piece.id})
    # captures at the destination (ring only, never on safe squares)
    var captured: Array[int] = []
    if piece.on_ring() and not geo.is_safe(piece.ring_index()):
        for other in state.players:
            if other.player_index == piece.owner:
                continue
            for op in other.pieces:
                if op.on_ring() and op.ring_index() == piece.ring_index():
                    captured.append(op.id)
        for pid in captured:
            state.piece_by_id(pid).progress = -1
    if not captured.is_empty():
        events.append({"type": &"captured", "pieces": captured, "by": piece.owner})
    log.add(&"move_applied", piece.owner, match_move.to_dict(), state.turn_number)
    # resolution: bonus comes first, then win check, then turn settlement
    var result := {"ok": true, "events": events, "extra_turn": false, "over": false}
    if not state.pending_bonus.is_empty():
        return result
    return _finish_turn_after_action(result)

# ----------------------------------------------------------------- bonus ---

func bonus_choices() -> Array[StringName]:
    var choices: Array[StringName] = []
    if state.pending_bonus.is_empty():
        return choices
    var pb: Dictionary = state.pending_bonus
    if StringName(str(pb.get("type", ""))) != &"lantern":
        return choices
    var piece := state.piece_by_id(int(pb.get("piece_id", -1)))
    if piece == null:
        return choices
    if piece.distance_to_goal() >= rules.lantern_bonus:
        choices.append(&"advance")
    if most_advanced_rival(piece.owner) != null:
        choices.append(&"send_back")
    return choices

func resolve_bonus(choice: StringName) -> Dictionary:
    if state.pending_bonus.is_empty():
        return {"ok": false, "error": "no_pending_bonus"}
    var pb: Dictionary = state.pending_bonus
    var piece := state.piece_by_id(int(pb.get("piece_id", -1)))
    var events: Array[Dictionary] = []
    if piece != null and StringName(str(pb.get("type", ""))) == &"lantern":
        if choice == &"advance" and piece.distance_to_goal() >= rules.lantern_bonus:
            piece.progress += rules.lantern_bonus
            events.append({"type": &"lantern_advance", "piece": piece.id, "to": piece.progress})
        elif choice == &"send_back":
            var victim := most_advanced_rival(piece.owner)
            if victim != null:
                var back := victim.progress - rules.lantern_send_back
                victim.progress = PEN if back < 0 else back
                events.append({"type": &"lantern_send_back", "piece": victim.id, "to": victim.progress})
    state.pending_bonus = {}
    log.add(&"bonus_resolved", -1 if piece == null else piece.owner, {"choice": String(choice)})
    return _finish_turn_after_action({"ok": true, "events": events, "extra_turn": false, "over": false})

func most_advanced_rival(owner: int) -> PieceState:
    var best: PieceState = null
    var best_distance := 1 << 30
    for other in state.players:
        if other.player_index == owner:
            continue
        for op in other.pieces:
            if op.in_pen():
                continue
            if op.distance_to_goal() < best_distance:
                best_distance = op.distance_to_goal()
                best = op
    return best

# ------------------------------------------------------------ resolution ---

func _finish_turn_after_action(result: Dictionary) -> Dictionary:
    if _check_winner():
        result["over"] = true
        log.add(&"match_finished", state.winner, {"ranking": state.ranking}, state.turn_number)
        return result
    var p := state.players[state.current]
    var extra := false
    if state.dice_value == rules.exit_dice_value:
        p.extra_chain += 1
        extra = true
    if p.candy_extra_pending:
        p.candy_extra_pending = false
        extra = true
    result["extra_turn"] = extra
    if extra:
        state.dice_value = 0   # same player rolls again
    else:
        p.extra_chain = 0
        _end_turn()
    return result

func _check_winner() -> bool:
    if state.over:
        return true
    for p in state.players:
        if p.finished():
            state.winner = p.player_index
            state.over = true
            _build_ranking()
            return true
    return false

func _build_ranking() -> void:
    var finished_order: Array[int] = []
    var rest: Array[int] = []
    for i in state.players.size():
        var p := state.players[i]
        if p.finished():
            finished_order.append(i)
    # Unfinished ranking: pieces in goal desc, total progress desc, seat asc.
    var unfinished: Array[PlayerState] = []
    for p in state.players:
        if not p.finished():
            unfinished.append(p)
    unfinished.sort_custom(func(a, b):
        if a.pieces_in_goal() != b.pieces_in_goal():
            return a.pieces_in_goal() > b.pieces_in_goal()
        if a.total_progress() != b.total_progress():
            return a.total_progress() > b.total_progress()
        return a.player_index < b.player_index)
    state.ranking = finished_order.duplicate()
    for p in unfinished:
        state.ranking.append(p.player_index)
    for rank in state.ranking.size():
        state.players[state.ranking[rank]].rank = rank + 1

func _end_turn() -> void:
    state.dice_value = 0
    var n := state.players.size()
    var next := (state.current + 1) % n
    for _guard in n:
        if not state.players[next].finished():
            break
        next = (next + 1) % n
    state.current = next
    state.turn_number += 1
    if state.turn_number > TURN_CAP:
        # Safety valve: declare the furthest-ahead player the winner.
        state.turn_number = TURN_CAP
        if not _check_winner():
            var best := state.players[0]
            for p in state.players:
                if p.total_progress() > best.total_progress():
                    best = p
            state.winner = best.player_index
            state.over = true
            _build_ranking()
            log.add(&"match_timeout", best.player_index, {}, state.turn_number)

# ------------------------------------------------------------------ hash ---

func state_hash() -> int:
    var parts := PackedStringArray()
    parts.append("rules=%s" % rules.signature())
    parts.append("seed=%d" % state.seed_value)
    parts.append("turn=%d" % state.turn_number)
    parts.append("cur=%d" % state.current)
    parts.append("dice=%d" % state.dice_value)
    parts.append("over=%s" % str(state.over))
    parts.append("winner=%d" % state.winner)
    parts.append("rank=%s" % str(state.ranking))
    if state.pending_bonus.is_empty():
        parts.append("pb=")
    else:
        parts.append("pb=%s,%d" % [String(state.pending_bonus.get("type", "")), int(state.pending_bonus.get("piece_id", -1))])
    for p in state.players:
        parts.append("p%d=%s,%d,%d,%d,%s" % [
            p.player_index, String(p.faction_id), p.extra_chain,
            1 if p.candy_used else 0, p.rank,
            ",".join(p.pieces.map(func(pc): return str(pc.progress))),
        ])
    return "|".join(parts).hash()

func to_dict() -> Dictionary:
    return state.to_dict()

static func from_dict(d: Dictionary) -> GameMatch:
    var m := GameMatch.new()
    m.state = MatchState.from_dict(d)
    m.rules = m.state.rules
    m.geo = BoardGeometry.new(m.rules)
    m.rng = RngStream.new(m.state.seed_value)
    m.log = EventLog.new()
    return m
