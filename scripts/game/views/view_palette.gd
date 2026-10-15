class_name ViewPalette
extends RefCounted
## Single source of visual colors for the whole view layer. Base palette from
## the plan (neon/cyan FORBIDDEN, enforced by tools/audit_palette.py):
##   deep blue-black #0E1220, muted violet #6B4E8E, pumpkin orange #E8862E,
##   spectral green #6FA35A, moon cream #F3E9C8, wood/stone.
## Values are static vars (not consts) so apply_accessibility() can swap in
## the high-contrast / colorblind variants; call sites read them unchanged.

static var BG_DEEP := Color(0.055, 0.067, 0.125)          # #0E1220
static var BG_ROOM_TINT := Color(0.16, 0.19, 0.30, 0.85)  # room texture multiply
static var SQUARE_BASE := Color(0.361, 0.302, 0.227)      # dark wood
static var SQUARE_SAFE := Color(0.478, 0.396, 0.259)      # lighter wood
static var SQUARE_COLUMN := Color(0.239, 0.204, 0.310)    # violet-dark home paths
static var SQUARE_GRID := Color(0.078, 0.063, 0.118)
static var PEN_FILL := Color(0.157, 0.137, 0.204)
static var TEXT_CREAM := Color(0.953, 0.914, 0.784)       # #F3E9C8
static var TEXT_VIOLET := Color(0.62, 0.51, 0.757)
static var ACCENT_ORANGE := Color(0.910, 0.525, 0.180)    # #E8862E
static var SPECTRAL_GREEN := Color(0.435, 0.639, 0.353)   # #6FA35A
static var HIGHLIGHT := Color(0.910, 0.525, 0.180)        # = pumpkin orange
static var PEDESTAL := Color(0.953, 0.914, 0.784, 0.16)
static var FACTION_TINTS := {
    &"gato_negro": Color(0.145, 0.125, 0.180),
    &"fantasma_bruja": Color(0.788, 0.765, 0.851),
    &"rey_calabaza": Color(0.910, 0.525, 0.180),
    &"conejo_espectral": Color(0.478, 0.353, 0.620),
}
static var FALLBACK_TINT := Color(0.42, 0.38, 0.48)
static var PIECE_OUTLINE := Color(0.078, 0.063, 0.118)
static var PIECE_LABEL_CREAM := Color(0.953, 0.914, 0.784)
static var PIECE_LABEL_INK := Color(0.106, 0.086, 0.141)
static var PEN_TEXT := Color(0.62, 0.59, 0.70)

# --- defaults (used as the reset source) ------------------------------------
const _D_BG_DEEP := Color(0.055, 0.067, 0.125)
const _D_ROOM_TINT := Color(0.16, 0.19, 0.30, 0.85)
const _D_SQ_BASE := Color(0.361, 0.302, 0.227)
const _D_SQ_SAFE := Color(0.478, 0.396, 0.259)
const _D_SQ_COLUMN := Color(0.239, 0.204, 0.310)
const _D_SQ_GRID := Color(0.078, 0.063, 0.118)
const _D_PEN_FILL := Color(0.157, 0.137, 0.204)
const _D_PEDESTAL := Color(0.953, 0.914, 0.784, 0.16)
const _D_FACTION := {
    &"gato_negro": Color(0.145, 0.125, 0.180),
    &"fantasma_bruja": Color(0.788, 0.765, 0.851),
    &"rey_calabaza": Color(0.910, 0.525, 0.180),
    &"conejo_espectral": Color(0.478, 0.353, 0.620),
}
# high contrast: stronger separation, darker lines, brighter wood
const _C_SQ_BASE := Color(0.42, 0.35, 0.25)
const _C_SQ_SAFE := Color(0.62, 0.51, 0.32)
const _C_SQ_COLUMN := Color(0.30, 0.25, 0.42)
const _C_SQ_GRID := Color(0.03, 0.02, 0.06)
const _C_PEN_FILL := Color(0.10, 0.08, 0.16)
const _C_PEDESTAL := Color(0.953, 0.914, 0.784, 0.28)
# colorblind: luminance-separated tints (navy / cream / orange / yellow)
const _B_FACTION := {
    &"gato_negro": Color(0.137, 0.137, 0.247),
    &"fantasma_bruja": Color(0.949, 0.918, 0.847),
    &"rey_calabaza": Color(0.910, 0.525, 0.180),
    &"conejo_espectral": Color(0.851, 0.722, 0.290),
}

## faction shape badges (anti-color-only): owner index -> shape id
static func badge_shape(faction_id: StringName) -> StringName:
    if faction_id == &"gato_negro":
        return &"circle"
    if faction_id == &"fantasma_bruja":
        return &"triangle"
    if faction_id == &"rey_calabaza":
        return &"square"
    if faction_id == &"conejo_espectral":
        return &"diamond"
    return &"circle"

## Swap palette variants. Called by views on match start and settings change.
static func apply_accessibility(high_contrast: bool, colorblind: bool) -> void:
    BG_DEEP = _D_BG_DEEP
    BG_ROOM_TINT = _D_ROOM_TINT
    PEDESTAL = _D_PEDESTAL
    SQUARE_BASE = _D_SQ_BASE
    SQUARE_SAFE = _D_SQ_SAFE
    SQUARE_COLUMN = _D_SQ_COLUMN
    SQUARE_GRID = _D_SQ_GRID
    PEN_FILL = _D_PEN_FILL
    FACTION_TINTS = _D_FACTION.duplicate()
    if high_contrast:
        SQUARE_BASE = _C_SQ_BASE
        SQUARE_SAFE = _C_SQ_SAFE
        SQUARE_COLUMN = _C_SQ_COLUMN
        SQUARE_GRID = _C_SQ_GRID
        PEN_FILL = _C_PEN_FILL
        PEDESTAL = _C_PEDESTAL
    if colorblind:
        FACTION_TINTS = _B_FACTION.duplicate()

static func colorblind_mode() -> bool:
    return bool(Settings.get_setting("colorblind_mode"))

static func tint(faction_id: StringName) -> Color:
    return FACTION_TINTS.get(faction_id, FALLBACK_TINT)

static func is_light(c: Color) -> bool:
    return (c.r + c.g + c.b) / 3.0 > 0.55

static func piece_label_color(faction_id: StringName) -> Color:
    return PIECE_LABEL_INK if is_light(tint(faction_id)) else PIECE_LABEL_CREAM

static func outline(faction_id: StringName) -> Color:
    return PIECE_OUTLINE
