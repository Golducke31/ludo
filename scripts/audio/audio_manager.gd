extends Node
## AudioManager: runtime buses (Master/SFX/Music) + placeholder-safe playback.
## Until M4 real audio exists, every play_* call is a guarded no-op: the
## generated placeholder WAVs may simply not be present yet.

const BUS_MASTER := &"Master"
const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 8

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music: AudioStreamPlayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_buses()
    _build_players()
    apply_volumes()
    EventBus.settings_changed.connect(apply_volumes)
    _connect_game_events()

## Placeholder SFX wiring (M4): every event maps to one short generated beep.
## Headless runs use the dummy audio driver, so these calls are harmless there.
func _connect_game_events() -> void:
    EventBus.dice_rolled.connect(func(_p, _v): play_sfx(&"roll"))
    EventBus.piece_moved.connect(func(_id, _to, _path): play_sfx(&"move"))
    EventBus.pieces_captured.connect(func(_ids, _by): play_sfx(&"capture"))
    EventBus.bonus_offered.connect(func(_id, _c): play_sfx(&"bonus"))
    EventBus.portal_triggered.connect(func(_id): play_sfx(&"portal"))
    EventBus.piece_exited.connect(func(_id): play_sfx(&"exit"))
    EventBus.match_finished.connect(func(_r): play_sfx(&"finish"))

func _ensure_buses() -> void:
    var existing := {}
    for i in AudioServer.bus_count:
        existing[AudioServer.get_bus_name(i)] = i
    if not existing.has(BUS_SFX):
        var idx := AudioServer.bus_count
        AudioServer.add_bus(idx)
        AudioServer.set_bus_name(idx, BUS_SFX)
        AudioServer.set_bus_send(idx, BUS_MASTER)
    if not existing.has(BUS_MUSIC):
        var idx2 := AudioServer.bus_count
        AudioServer.add_bus(idx2)
        AudioServer.set_bus_name(idx2, BUS_MUSIC)
        AudioServer.set_bus_send(idx2, BUS_MASTER)

func _build_players() -> void:
    for _i in POOL_SIZE:
        var p := AudioStreamPlayer.new()
        p.bus = String(BUS_SFX)
        add_child(p)
        _pool.append(p)
    _music = AudioStreamPlayer.new()
    _music.bus = String(BUS_MUSIC)
    add_child(_music)

func apply_volumes() -> void:
    _set_bus_volume_linear(BUS_MASTER, float(Settings.get_setting("volume_master")))
    _set_bus_volume_linear(BUS_SFX, float(Settings.get_setting("volume_sfx")))
    _set_bus_volume_linear(BUS_MUSIC, float(Settings.get_setting("volume_music")))

func _set_bus_volume_linear(bus: StringName, linear: float) -> void:
    var idx := AudioServer.get_bus_index(String(bus))
    if idx >= 0:
        AudioServer.set_bus_volume_linear(idx, clampf(linear, 0.0, 1.0))

func has_sfx(id: String) -> bool:
    return ResourceLoader.exists(SFX_DIR + id + ".wav")

func play_sfx(id: StringName, pitch := 1.0) -> void:
    var path := SFX_DIR + String(id) + ".wav"
    if not ResourceLoader.exists(path):
        return
    var stream := _load_cached(path)
    if stream == null:
        return
    if _pool.is_empty():
        return
    var p := _pool[_pool_i]
    _pool_i = (_pool_i + 1) % _pool.size()
    p.stream = stream
    p.pitch_scale = pitch
    p.play()

func play_music(id: StringName) -> void:
    var path := MUSIC_DIR + String(id) + ".wav"
    if not ResourceLoader.exists(path):
        return
    _music.stream = _load_cached(path)
    _music.play()

func stop_music() -> void:
    _music.stop()

func _load_cached(path: String) -> AudioStream:
    if _cache.has(path):
        return _cache[path]
    var s: AudioStream = load(path)
    if s != null:
        _cache[path] = s
    return s
