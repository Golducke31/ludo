class_name MatchRulesResource
extends Resource
## Thin Resource wrapper so data/rules/*.tres can store a MatchRules variant
## without the core class depending on Godot resources.

@export var data: Dictionary = {}

func to_rules() -> MatchRules:
    var r := MatchRules.new()
    if not data.is_empty():
        r.from_dict(data)
    return r
