class_name NetInterface
extends RefCounted
## Prepared network interface (NO fake networking in the build).
## The core is already serialization- and replay-ready (MatchState.to_dict,
## RngStream forced queue, state_hash), so a future net layer would:
##   1. exchange the rules dict + seat order at match start,
##   2. broadcast (roll, move) pairs exactly like replay records,
##   3. verify state_hash on every applied action (desync detection),
##   4. fall back to replay-verified state on hash mismatch.
## Until a real transport exists, every method here fails loudly.

static func is_supported() -> bool:
    return false

static func unsupported_error() -> String:
    return "net play is not implemented in v1 (see KNOWN_ISSUES.md)"
