class_name FactionData
extends RefCounted
## One of the four critter factions. Pure data; display fields are localized.

var id := &"gato_negro"
var name_es := ""
var name_en := ""
var desc_es := ""
var desc_en := ""
var color_hex := "#F3E9C8"     # primary (muted palette only, never neon/cyan)
var accent_hex := "#E8862E"
var sprite_dir := "res://assets/sprites/factions/gato_negro/"

func name(locale: String) -> String:
    return name_en if locale == "en" else name_es

func desc(locale: String) -> String:
    return desc_en if locale == "en" else desc_es

func color() -> Color:
    return Color.html(color_hex)

func accent() -> Color:
    return Color.html(accent_hex)

func to_dict() -> Dictionary:
    return {
        "id": String(id),
        "name_es": name_es,
        "name_en": name_en,
        "desc_es": desc_es,
        "desc_en": desc_en,
        "color": color_hex,
        "accent": accent_hex,
        "sprite_dir": sprite_dir,
    }

static func from_dict(d: Dictionary) -> FactionData:
    var f := FactionData.new()
    f.id = StringName(str(d.get("id", "gato_negro")))
    f.name_es = str(d.get("name_es", ""))
    f.name_en = str(d.get("name_en", ""))
    f.desc_es = str(d.get("desc_es", ""))
    f.desc_en = str(d.get("desc_en", ""))
    f.color_hex = str(d.get("color", "#F3E9C8"))
    f.accent_hex = str(d.get("accent", "#E8862E"))
    f.sprite_dir = str(d.get("sprite_dir", "res://assets/sprites/factions/gato_negro/"))
    return f
