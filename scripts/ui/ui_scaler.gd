class_name UiScaler
extends RefCounted
## Applies the text_scale setting to a Control subtree. The first pass records
## each Control's in-effect font size in metadata; later passes multiply the
## recorded base, so repeated calls never compound. No-op-safe: Controls whose
## size comes from the theme are pinned explicitly (harmless and equivalent).

const META := "hc_base_font"

static func apply(root: Control) -> void:
    var scale: float = clampf(float(Settings.get_setting("text_scale")), 0.75, 1.75)
    _walk(root, scale)

static func _walk(node: Node, scale: float) -> void:
    if node is Control:
        var c := node as Control
        if not c.has_meta(META):
            c.set_meta(META, int(c.get_theme_font_size("font_size")))
        var base: int = int(c.get_meta(META))
        if base > 0:
            c.add_theme_font_size_override("font_size", maxi(8, int(round(base * scale))))
    for child in node.get_children():
        _walk(child, scale)
