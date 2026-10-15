class_name EventLog
extends RefCounted
## Append-only event log (debugging, replays, future net sync). Plain dicts only.

var events: Array[Dictionary] = []
var _seq := 0

func add(type: StringName, player: int, data: Dictionary, turn := 0) -> void:
    events.append({
        "seq": _seq,
        "type": String(type),
        "player": player,
        "turn": turn,
        "data": data,
    })
    _seq += 1

func count() -> int:
    return events.size()

func last_of(type: StringName) -> Dictionary:
    for i in range(events.size() - 1, -1, -1):
        if events[i]["type"] == String(type):
            return events[i]
    return {}

func clear() -> void:
    events.clear()
    _seq = 0

func to_dict() -> Dictionary:
    return {"events": events.duplicate(true), "seq": _seq}

static func from_dict(d: Dictionary) -> EventLog:
    var l := EventLog.new()
    l.events.assign(d.get("events", []))
    l._seq = int(d.get("seq", l.events.size()))
    return l
