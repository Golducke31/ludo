class_name RngStream
extends RefCounted
## Deterministic RNG. Seedable per match; supports an injectable `forced` queue
## so tests/debug/replays can drive dice without touching production paths.
## Bots must receive their own fork (bot_rng) and never the dice stream.

var seed_value: int

var _rng := RandomNumberGenerator.new()
var _forced: Array[int] = []

func _init(p_seed: int = 0) -> void:
    reseed(p_seed)

func reseed(p_seed: int) -> void:
    seed_value = p_seed
    _rng.seed = p_seed
    _forced.clear()

func force_next(values: Array) -> void:
    for v in values:
        _forced.append(int(v))

func clear_forced() -> void:
    _forced.clear()

func forced_remaining() -> int:
    return _forced.size()

func next_int(max_exclusive: int) -> int:
    if max_exclusive <= 0:
        return 0
    if _forced.size() > 0:
        return _forced.pop_front() % max_exclusive
    return _rng.randi_range(0, max_exclusive - 1)

func roll_d6() -> int:
    ## Forced values are dice faces (1..6); they bypass the stream entirely.
    if _forced.size() > 0:
        return clampi(_forced.pop_front(), 1, 6)
    return _rng.randi_range(1, 6)

func randf01() -> float:
    if _forced.size() > 0:
        return clampf(float(_forced.pop_front()) / 6.0, 0.0, 1.0)
    return _rng.randf()

func pick(array: Array) -> Variant:
    if array.is_empty():
        return null
    return array[next_int(array.size())]

func fork(label: String) -> RngStream:
    ## Deterministic sub-stream derived from this stream (bots, cosmetic FX).
    return RngStream.new(hash("%d:%s" % [seed_value, label]))
