class_name FactionDataResource
extends Resource
## Thin Resource wrapper so data/factions/*.tres can store FactionData.

@export var data: Dictionary = {}

func to_faction() -> FactionData:
    return FactionData.from_dict(data)
