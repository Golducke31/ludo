extends Control
## Settings screen (M4): accessibility toggles, text scale, volumes, locale.
## Every change persists immediately through the Settings autoload and repaints
## the live views (palette swap + text scale happen on settings_changed).

const LOCALE_LABELS := {"es": "Espanol", "en": "English"}

@onready var _check_reduce: CheckBox = %CheckReduceMotion
@onready var _check_colorblind: CheckBox = %CheckColorblind
@onready var _check_contrast: CheckBox = %CheckHighContrast
@onready var _scale_slider: HSlider = %TextScaleSlider
@onready var _scale_value: Label = %TextScaleValue
@onready var _vol_master: HSlider = %VolMasterSlider
@onready var _vol_sfx: HSlider = %VolSfxSlider
@onready var _vol_music: HSlider = %VolMusicSlider
@onready var _locale_option: OptionButton = %LocaleOption
@onready var _btn_reset: Button = %BtnReset
@onready var _btn_back: Button = %BtnBack


func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    _check_reduce.toggled.connect(_on_reduce_toggled)
    _check_colorblind.toggled.connect(_on_colorblind_toggled)
    _check_contrast.toggled.connect(_on_contrast_toggled)
    _scale_slider.value_changed.connect(_on_scale_changed)
    _vol_master.value_changed.connect(_on_vol_master_changed)
    _vol_sfx.value_changed.connect(_on_vol_sfx_changed)
    _vol_music.value_changed.connect(_on_vol_music_changed)
    _locale_option.item_selected.connect(_on_locale_selected)
    _btn_reset.pressed.connect(_on_reset)
    _btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
    EventBus.settings_changed.connect(func(): _sync_from_settings())
    _build_locale_options()
    _sync_from_settings()
    L10n.localize_scene(self, "settings")
    UiScaler.apply(self)
    _btn_back.grab_focus()

func _build_locale_options() -> void:
    _locale_option.clear()
    for loc in L10n.available_locales():
        _locale_option.add_item(LOCALE_LABELS.get(loc, loc))
        _locale_option.set_item_metadata(_locale_option.item_count - 1, loc)

func _sync_from_settings() -> void:
    _check_reduce.set_pressed_no_signal(bool(Settings.get_setting("reduce_motion")))
    _check_colorblind.set_pressed_no_signal(bool(Settings.get_setting("colorblind_mode")))
    _check_contrast.set_pressed_no_signal(bool(Settings.get_setting("high_contrast")))
    _scale_slider.set_value_no_signal(float(Settings.get_setting("text_scale")))
    _vol_master.set_value_no_signal(float(Settings.get_setting("volume_master")))
    _vol_sfx.set_value_no_signal(float(Settings.get_setting("volume_sfx")))
    _vol_music.set_value_no_signal(float(Settings.get_setting("volume_music")))
    _refresh_scale_label()
    var loc: String = L10n.locale()
    for i in _locale_option.item_count:
        if String(_locale_option.get_item_metadata(i)) == loc:
            _locale_option.selected = i
            break

func _refresh_scale_label() -> void:
    _scale_value.text = "%d%%" % int(round(_scale_slider.value * 100.0))

func _apply_palette_now() -> void:
    ViewPalette.apply_accessibility(
        bool(Settings.get_setting("high_contrast")),
        bool(Settings.get_setting("colorblind_mode")))

func _on_reduce_toggled(on: bool) -> void:
    Settings.set_setting("reduce_motion", on)

func _on_colorblind_toggled(on: bool) -> void:
    Settings.set_setting("colorblind_mode", on)
    _apply_palette_now()

func _on_contrast_toggled(on: bool) -> void:
    Settings.set_setting("high_contrast", on)
    _apply_palette_now()

func _on_scale_changed(v: float) -> void:
    Settings.set_setting("text_scale", snappedf(v, 0.05))
    _refresh_scale_label()

func _on_vol_master_changed(v: float) -> void:
    Settings.set_setting("volume_master", snappedf(v, 0.05))

func _on_vol_sfx_changed(v: float) -> void:
    Settings.set_setting("volume_sfx", snappedf(v, 0.05))

func _on_vol_music_changed(v: float) -> void:
    Settings.set_setting("volume_music", snappedf(v, 0.05))

func _on_locale_selected(idx: int) -> void:
    var meta: Variant = _locale_option.get_item_metadata(idx)
    if meta != null:
        L10n.set_locale(String(meta))

func _on_reset() -> void:
    Settings.reset_defaults()
    L10n.set_locale(String(Settings.get_setting("locale")))
    _apply_palette_now()
    L10n.localize_scene(self, "settings")
    UiScaler.apply(self)
