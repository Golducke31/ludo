class_name BotPlayer
extends RefCounted
## Bot brains. IMPORTANT: bots never touch the match dice RNG; they receive
## their own bot_rng fork for cosmetic randomization only, so bot play can
## never change dice determinism of a match.

const EASY := &"easy"
const NORMAL := &"normal"
const HARD := &"hard"

var difficulty: StringName = NORMAL
var bot_rng: RngStream

func _init(p_difficulty: StringName = NORMAL, p_seed := 12345) -> void:
    difficulty = p_difficulty
    bot_rng = RngStream.new(p_seed)

# ------------------------------------------------------------------ moves ---

func choose_move(gm: GameMatch, legal: Array) -> Variant:
    if legal.is_empty():
        return null
    match difficulty:
        EASY:
            return bot_rng.pick(legal)
        NORMAL:
            return _best(gm, legal, 1.0)
        HARD:
            return _best(gm, legal, 0.0)
    return bot_rng.pick(legal)

func choose_bonus(gm: GameMatch, choices: Array) -> StringName:
    if choices.is_empty():
        return &"advance"
    if difficulty == EASY:
        return bot_rng.pick(choices)
    # Normal/Hard: send the leader back when it is clearly better for us,
    # otherwise take the free steps.
    if choices.has(&"send_back"):
        var pb: Dictionary = gm.state.pending_bonus
        var piece := gm.state.piece_by_id(int(pb.get("piece_id", -1)))
        if piece != null and difficulty == HARD:
            var victim := gm.most_advanced_rival(piece.owner)
            if victim != null and victim.progress > piece.progress:
                return &"send_back"
    return &"advance"

func _best(gm: GameMatch, legal: Array, jitter: float) -> Variant:
    var best: Variant = null
    var best_score := -1000000000.0
    for m in legal:
        var mv: Move = m
        var score := _score_move(gm, mv)
        if jitter > 0.0:
            score += bot_rng.randf01() * jitter * 12.0
        if score > best_score:
            best_score = score
            best = mv
    return best

func _score_move(gm: GameMatch, mv: Move) -> float:
    var rules: MatchRules = gm.rules
    var dest := mv.to_progress
    var score := 0.0
    # captures are king
    var would_capture := 0
    if dest >= 0 and dest < rules.home_steps:
        var dest_ring := (rules.start_index(mv.player_index) + dest) % rules.ring_size
        if not gm.geo.is_safe(dest_ring):
            for other in gm.state.players:
                if other.player_index == mv.player_index:
                    continue
                for op in other.pieces:
                    if op.on_ring() and op.ring_index() == dest_ring:
                        would_capture += 1
    score += would_capture * 120.0
    # reaching the goal is gold
    if dest >= rules.total_route_steps():
        score += 100.0
    # exiting the pen early is nice
    if mv.action == &"exit":
        score += 40.0
    # general progress
    score += float(maxi(0, dest)) * 2.0
    # safety: landing on a safe square
    if dest >= 0 and dest < rules.home_steps:
        var dr := (rules.start_index(mv.player_index) + dest) % rules.ring_size
        if gm.geo.is_safe(dr):
            score += 18.0
    # risk: enemies 1..6 behind the destination (hard bots feel this strongly)
    if difficulty == HARD and dest >= 0 and dest < rules.home_steps:
        var dest_ring2 := (rules.start_index(mv.player_index) + dest) % rules.ring_size
        var threats := _count_threats(gm, mv.player_index, dest_ring2)
        score -= threats * 45.0
    # avoid leaving a piece stranded in the pen when it could move
    if mv.action != &"exit":
        var home_pen := 0
        for op in gm.state.players[mv.player_index].pieces:
            if op.in_pen():
                home_pen += 1
        score -= home_pen * 1.0
    return score

func _count_threats(gm: GameMatch, player_index: int, dest_ring: int) -> int:
    var rules: MatchRules = gm.rules
    var count := 0
    for other in gm.state.players:
        if other.player_index == player_index:
            continue
        for op in other.pieces:
            if not op.on_ring():
                continue
            var gap := (dest_ring - op.ring_index() + rules.ring_size) % rules.ring_size
            if gap >= 1 and gap <= 6:
                count += 1
    return count
