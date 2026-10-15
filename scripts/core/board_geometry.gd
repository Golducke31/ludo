class_name BoardGeometry
extends RefCounted
## Pure board math: starts, home entries, safety, special squares.
## No positions (see BoardLayout) and no state (see GameMatch).

var rules: MatchRules

func _init(p_rules: MatchRules) -> void:
    rules = p_rules

func start_index(player_index: int) -> int:
    return rules.start_index(player_index)

func home_entry_index(player_index: int) -> int:
    return rules.home_entry_index(player_index)

func arm_of(idx: int) -> int:
    return idx / rules.arm_length

func offset_of(idx: int) -> int:
    return idx % rules.arm_length

func is_safe(idx: int) -> bool:
    return rules.is_safe_index(idx)

func special_at(idx: int) -> StringName:
    if not rules.halloween_enabled:
        return &""
    if idx == rules.portal_index:
        return &"portal"
    if idx == rules.lantern_index:
        return &"lantern"
    if rules.candy_heap_enabled and idx == rules.candy_heap_index:
        return &"candy"
    return &""

func step_along(player_index: int, progress: int) -> int:
    ## Ring index for a piece of player_index that has taken `progress` ring steps.
    return (start_index(player_index) + progress) % rules.ring_size
