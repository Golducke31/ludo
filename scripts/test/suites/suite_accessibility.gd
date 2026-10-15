extends HCTestCase
## M5 accessibility + i18n verification suite. Everything here is
## deterministic and headless: palette swaps, label contrast, shape badges,
## UiScaler clamping and the ES/EN localization loader. Run as part of
## test_all; restores every global it touches before returning.

func suite_name() -> String:
    return "accessibility"

func run() -> void:
    _palette_modes()
    _label_contrast()
    _badges()
    _ui_scaler()
    _i18n()
    # leave globals clean for the remaining suites
    ViewPalette.apply_accessibility(false, false)
    Settings.set_setting("text_scale", 1.0)
    Settings.set_setting("reduce_motion", false)
    Settings.set_setting("colorblind_mode", false)
    Settings.set_setting("high_contrast", false)

# ------------------------------------------------------------ palettes ---

func _palette_modes() -> void:
    ViewPalette.apply_accessibility(false, false)
    check_eq(ViewPalette.SQUARE_BASE, Color(0.361, 0.302, 0.227), "defaults: SQUARE_BASE reset")
    check_eq(ViewPalette.FACTION_TINTS.size(), 4, "defaults: 4 faction tints")

    ViewPalette.apply_accessibility(true, false)
    check(ViewPalette.SQUARE_BASE != Color(0.361, 0.302, 0.227), "high contrast: board squares brighten")
    check(ViewPalette.SQUARE_GRID.r < 0.05 and ViewPalette.SQUARE_GRID.g < 0.05, "high contrast: grid lines darken")
    check(ViewPalette.PEN_FILL.r < 0.157, "high contrast: pen fill darkens")
    check(ViewPalette.PEDESTAL.a > 0.16, "high contrast: pedestal alpha strengthens")
    check(ViewPalette.FACTION_TINTS[&"gato_negro"] == Color(0.145, 0.125, 0.180),
            "high contrast: faction tints untouched (contrast is not colorblind)")

    ViewPalette.apply_accessibility(false, true)
    check(ViewPalette.FACTION_TINTS[&"gato_negro"] == Color(0.137, 0.137, 0.247),
            "colorblind: gato_negro becomes navy")
    check(ViewPalette.FACTION_TINTS[&"fantasma_bruja"] == Color(0.949, 0.918, 0.847),
            "colorblind: fantasma_bruja becomes cream")
    check(ViewPalette.FACTION_TINTS[&"conejo_espectral"] == Color(0.851, 0.722, 0.290),
            "colorblind: conejo_espectral becomes yellow")
    check(ViewPalette.SQUARE_BASE == Color(0.361, 0.302, 0.227),
            "colorblind: board squares untouched (high contrast is off)")

    ViewPalette.apply_accessibility(true, true)
    check(ViewPalette.SQUARE_BASE != Color(0.361, 0.302, 0.227) and
            ViewPalette.FACTION_TINTS[&"gato_negro"] == Color(0.137, 0.137, 0.247),
            "combined: high contrast + colorblind both apply")
    ViewPalette.apply_accessibility(false, false)
    check_eq(ViewPalette.FACTION_TINTS[&"gato_negro"], Color(0.145, 0.125, 0.180), "reset: defaults restored")

# ------------------------------------------------------------- contrast ---

func _lum(c: Color) -> float:
    return (c.r + c.g + c.b) / 3.0

func _label_contrast() -> void:
    ## The piece/start-square label must never sit on a same-luminance
    ## background: this is the check that caught the inverted CREAM/INK
    ## selection in M5 QA.
    var ids: Array[StringName] = [&"gato_negro", &"fantasma_bruja", &"rey_calabaza", &"conejo_espectral"]
    for cb in [false, true]:
        for hc in [false, true]:
            ViewPalette.apply_accessibility(hc, cb)
            for id in ids:
                var tint: Color = ViewPalette.tint(id)
                # start squares draw the tint at 0.55 alpha over dark wood:
                var wood := ViewPalette.SQUARE_BASE
                var bg := Color(0.55 * tint.r + 0.45 * wood.r,
                                0.55 * tint.g + 0.45 * wood.g,
                                0.55 * tint.b + 0.45 * wood.b)
                var label: Color = ViewPalette.piece_label_color(id)
                var d: float = absf(_lum(label) - _lum(bg))
                check(d >= 0.25, "label contrast %s (cb=%s hc=%s): |ΔL|=%.3f" % [id, cb, hc, d])

# -------------------------------------------------------------- badges ---

func _badges() -> void:
    var shapes := {}
    for id in [&"gato_negro", &"fantasma_bruja", &"rey_calabaza", &"conejo_espectral"]:
        var s := ViewPalette.badge_shape(id)
        check(s != &"", "badge shape defined for %s" % id)
        check(not shapes.has(s), "badge shape %s unique (faction %s)" % [s, id])
        shapes[s] = true
    check_eq(shapes.size(), 4, "4 distinct shape badges (anti-color-only)")
    check_eq(ViewPalette.badge_shape(&"unknown"), &"circle", "unknown faction falls back to circle")
    # colorblind tints are pairwise distinct (shape badges reinforce them)
    ViewPalette.apply_accessibility(false, true)
    var tints: Array = ViewPalette.FACTION_TINTS.values()
    for i in tints.size():
        for j in range(i + 1, tints.size()):
            check(tints[i] != tints[j], "colorblind tints %d/%d distinct" % [i, j])
    ViewPalette.apply_accessibility(false, false)

# ----------------------------------------------------------- ui scaler ---

func _ui_scaler() -> void:
    var btn := Button.new()
    btn.add_theme_font_size_override("font_size", 20)
    Settings.set_setting("text_scale", 0.5)
    UiScaler.apply(btn)
    check_eq(btn.get_theme_font_size("font_size"), 15, "text_scale 0.5 clamps to 0.75 (20 -> 15)")
    Settings.set_setting("text_scale", 3.0)
    UiScaler.apply(btn)
    check_eq(btn.get_theme_font_size("font_size"), 35, "text_scale 3.0 clamps to 1.75 (20 -> 35)")
    Settings.set_setting("text_scale", 1.0)
    UiScaler.apply(btn)
    check_eq(btn.get_theme_font_size("font_size"), 20, "scale 1.0 restores the base (no compounding)")
    Settings.set_setting("text_scale", 1.3)
    UiScaler.apply(btn)
    check_eq(btn.get_theme_font_size("font_size"), 26, "mid scale multiplies the recorded base (20*1.3)")
    btn.free()
    Settings.set_setting("text_scale", 1.0)

# ---------------------------------------------------------------- i18n ---

func _i18n() -> void:
    var original: String = Settings.get_setting("locale")
    L10n.set_locale("es")
    var es := L10n.t("menu.play")
    L10n.set_locale("en")
    var en := L10n.t("menu.play")
    check(es != "" and en != "", "localized key resolves in both locales")
    check(es != en, "ES and EN differ for menu.play (%s vs %s)" % [es, en])
    check_eq(L10n.t("hud.turn", {"n": 7}), "Turn 7", "placeholder substitution (en)")
    check_eq(L10n.t("does.not.exist"), "does.not.exist", "missing key returns the key itself")
    # restore the operator locale
    L10n.set_locale(original if original != "" else "es")
    check_eq(Settings.get_setting("locale"), original if original != "" else "es", "locale restored")
