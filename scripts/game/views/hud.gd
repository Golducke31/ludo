extends Control
## Right-side HUD: turn info, dice state, player table, action buttons.
## M4: fully localized via L10n (ES default / EN), text-scaled via UiScaler,
## themed. Refreshed on every Game signal through a FIXED pool of row labels
## (no node churn per turn). No _process.

@onready var _header: Label = %Header
@onready var _subheader: Label = %Subheader
@onready var _dice_label: Label = %DiceLabel
@onready var _hint: Label = %Hint
@onready var _rows: VBoxContainer = %PlayerRows
@onready var _btn_roll: Button = %BtnRoll
@onready var _btn_pause: Button = %BtnPause
@onready var _bonus_panel: PanelContainer = %BonusPanel
@onready var _bonus_title: Label = %BonusTitle
@onready var _btn_advance: Button = %BtnAdvance
@onready var _btn_send_back: Button = %BtnSendBack
@onready var _turn_banner: Label = %TurnBanner
@onready var _btn_camera: Button = %BtnCamera

var _row_pool: Array[Label] = []

func _ready() -> void:
    theme = load("res://assets/ui/theme.tres")
    _header.theme_type_variation = &"Title"
    _turn_banner.theme_type_variation = &"Title"
    EventBus.match_started.connect(func(_c, _m): _refresh())
    EventBus.turn_changed.connect(func(_p, _t): _refresh())
    EventBus.dice_rolled.connect(func(_p, _v): _refresh())
    EventBus.move_options_changed.connect(func(_n): _refresh())
    EventBus.piece_moved.connect(func(_id, _to, _path): _refresh())
    EventBus.pieces_captured.connect(func(_ids, _by): _refresh())
    EventBus.bonus_offered.connect(func(_id, _choices): _refresh())
    EventBus.bonus_resolved.connect(func(_c): _refresh())
    EventBus.extra_turn_granted.connect(func(_p, _chain): _refresh())
    EventBus.extra_turn_forfeit.connect(func(_p): _refresh())
    EventBus.match_finished.connect(func(_ranking): _refresh())
    EventBus.match_abandoned.connect(func(): _refresh())
    Game.state_changed.connect(func(_s): _refresh())
    EventBus.settings_changed.connect(func(): _on_settings_changed())
    _btn_roll.pressed.connect(_on_roll_pressed)
    _btn_pause.pressed.connect(func(): Audio.play_sfx(&"ui_click"); Game.request_pause())
    _btn_advance.pressed.connect(func(): Audio.play_sfx(&"ui_click"); Game.request_bonus(&"advance"))
    _btn_send_back.pressed.connect(func(): Audio.play_sfx(&"ui_click"); Game.request_bonus(&"send_back"))
    _btn_camera.pressed.connect(func(): Audio.play_sfx(&"ui_click"); _toggle_camera())
    EventBus.camera_mode_changed.connect(func(_m): _update_camera_label())
    _build_row_pool()
    _localize()
    UiScaler.apply(self)
    _refresh()

func _on_settings_changed() -> void:
    _localize()
    UiScaler.apply(self)
    _refresh()

func _localize() -> void:
    _btn_roll.text = L10n.t("hud.roll")
    _btn_pause.text = L10n.t("hud.pause")
    _bonus_title.text = L10n.t("hud.bonus_title")
    _btn_advance.text = L10n.t("hud.advance")
    _btn_send_back.text = L10n.t("hud.send_back")
    _update_camera_label()

func _arena() -> Node:
    return get_parent().get_parent().get_node_or_null("Arena")

func _toggle_camera() -> void:
    var arena := _arena()
    if arena != null and arena.has_method("toggle_camera_mode"):
        arena.toggle_camera_mode()

func _update_camera_label() -> void:
    ## Button shows the mode it switches TO.
    var arena := _arena()
    var follow := false
    if arena != null and arena.has_method("camera_mode"):
        follow = int(arena.camera_mode()) == 1
    _btn_camera.text = "%s: %s" % [L10n.t("hud.camera"),
        L10n.t("hud.cam_iso") if follow else L10n.t("hud.cam_follow")]

func _build_row_pool() -> void:
    for i in 4:
        var row := Label.new()
        row.add_theme_font_size_override("font_size", 18)
        row.visible = false
        _rows.add_child(row)
        _row_pool.append(row)

func _refresh() -> void:
    if Game.active_match == null:
        _header.text = L10n.t("hud.no_match")
        _subheader.text = ""
        _dice_label.text = ""
        _hint.text = ""
        _btn_roll.visible = false
        _btn_pause.visible = false
        _btn_camera.visible = false
        _bonus_panel.visible = false
        _turn_banner.visible = false
        for row in _row_pool:
            row.visible = false
        return
    var st: MatchState = Game.active_match.state
    var cur: PlayerState = st.players[st.current]
    _header.text = L10n.t("hud.turn", {"n": st.turn_number})
    _subheader.text = "%s - %s" % [cur.display_name, L10n.t("faction." + String(cur.faction_id))]
    _dice_label.text = L10n.t("hud.dice", {"v": st.dice_value}) if st.dice_value > 0 else L10n.t("hud.dice_none")
    _update_rows(st)
    _refresh_actions(st)

func _update_rows(st: MatchState) -> void:
    for i in _row_pool.size():
        var row := _row_pool[i]
        if i >= st.players.size():
            row.visible = false
            continue
        var p: PlayerState = st.players[i]
        var type_text: String
        if p.is_bot:
            type_text = L10n.t("hud.type_bot", {"diff": L10n.t("diff." + String(p.bot_difficulty))})
        else:
            type_text = L10n.t("hud.type_human")
        row.text = L10n.t("hud.row", {
            "n": p.player_index + 1,
            "name": p.display_name,
            "faction": L10n.t("faction." + String(p.faction_id)),
            "type": type_text,
            "goal": p.pieces_in_goal(),
            "pen": p.pieces_in_pen(),
            "current": " *" if p.player_index == st.current else "",
        })
        row.add_theme_color_override("font_color",
            ViewPalette.HIGHLIGHT if p.player_index == st.current else ViewPalette.TEXT_CREAM)
        row.visible = true

func _refresh_actions(st: MatchState) -> void:
    var m: TurnMachine = Game.machine
    var human: bool = Game.is_human_turn()
    _btn_roll.visible = human and m.current == TurnMachine.WAITING_FOR_ROLL and not st.over
    _btn_pause.visible = m.is_in_match() and not st.over
    _btn_camera.visible = m.is_in_match() and not st.over
    _turn_banner.visible = st.over
    if st.over:
        _turn_banner.text = L10n.t("hud.over")
        _hint.text = L10n.t("hud.hint_over")
    elif m.current == TurnMachine.WAITING_FOR_ROLL:
        _hint.text = L10n.t("hud.hint_roll")
    elif m.current == TurnMachine.WAITING_FOR_PIECE_SELECTION:
        _hint.text = L10n.t("hud.hint_pick")
    elif m.current == TurnMachine.RESOLVING_BONUS:
        _hint.text = L10n.t("hud.hint_bonus")
    elif m.current == TurnMachine.PAUSED:
        _hint.text = L10n.t("hud.hint_paused")
    else:
        _hint.text = L10n.t("hud.hint_wait") if human else L10n.t("hud.hint_bots")
    # bonus panel only for the human deciding player
    _bonus_panel.visible = not st.over and m.current == TurnMachine.RESOLVING_BONUS and human
    if _bonus_panel.visible:
        var choices: Array = Game.active_match.bonus_choices()
        _btn_advance.visible = choices.is_empty() or choices.has(&"advance")
        _btn_send_back.visible = choices.is_empty() or choices.has(&"send_back")

func _on_roll_pressed() -> void:
    Audio.play_sfx(&"ui_click")
    Game.request_roll()
