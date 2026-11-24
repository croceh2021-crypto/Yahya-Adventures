
extends "res://Scripts/adventure_expansion.gd"

# ============================================================
# YAHYA ADVENTURES - DUAL BACKGROUND MUSIC SYSTEM
# Godot 4.4.1
# ============================================================

const MUSIC_INTRO_PATH := "res://Audio/cyberwave-orchestra-adventure-game-loop-fun-and-uplifting-background-music-247664.mp3"
const MUSIC_ADVENTURE_PATH := "res://Audio/gamer-stream-music-rpg-_-adventure-background-music-10-476323.mp3"

const MUSIC_SETTINGS_PATH := "user://yahya_music_settings.cfg"

const MUSIC_INTRO := 0
const MUSIC_ADVENTURE := 1

const MUSIC_DEFAULT_VOLUME := 0.65
const MUSIC_VOLUME_STEP := 0.08

var music_player: AudioStreamPlayer
var music_enabled := true
var music_volume := MUSIC_DEFAULT_VOLUME
var current_music_mode := MUSIC_INTRO
var current_music_path := ""

var music_menu_toggle_button: Button
var music_game_toggle_button: Button
var music_volume_label: Label


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
    super._ready()

    _music_load_settings()
    _music_create_player()
    _music_create_game_controls()

    _music_play_track(MUSIC_INTRO)


# ============================================================
# INTRO MENU INTEGRATION
# ============================================================

func _show_intro_screen() -> void:
    super._show_intro_screen()

    _music_add_intro_controls()


func _music_add_intro_controls() -> void:
    if not is_instance_valid(ultimate_content):
        return

    var heading := _make_ultimate_label(
        "إعدادات الموسيقى",
        18,
        Color(1.0, 0.85, 0.35)
    )

    ultimate_content.add_child(heading)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ultimate_content.add_child(row)

    music_menu_toggle_button = _music_make_button(
        "♫ إيقاف" if music_enabled else "♫ تشغيل",
        17
    )

    music_menu_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    music_menu_toggle_button.pressed.connect(_music_toggle)
    row.add_child(music_menu_toggle_button)

    var down_button := _music_make_button("−", 22)
    down_button.custom_minimum_size = Vector2(55, 52)
    down_button.pressed.connect(_music_volume_down)
    row.add_child(down_button)

    var up_button := _music_make_button("+", 22)
    up_button.custom_minimum_size = Vector2(55, 52)
    up_button.pressed.connect(_music_volume_up)
    row.add_child(up_button)

    var volume_text := _make_ultimate_label(
        "مستوى الصوت: %d%%" % int(music_volume * 100.0),
        15,
        Color(0.80, 0.90, 1.0)
    )

    volume_text.name = "MusicVolumeText"
    ultimate_content.add_child(volume_text)


# ============================================================
# AUDIO PLAYER
# ============================================================

func _music_create_player() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.name = "YahyaBackgroundMusic"
    music_player.process_mode = Node.PROCESS_MODE_ALWAYS
    music_player.bus = "Master"

    add_child(music_player)

    _music_apply_volume()


func _music_play_track(mode: int) -> void:
    if not is_instance_valid(music_player):
        return

    current_music_mode = mode

    var path := MUSIC_INTRO_PATH

    if mode == MUSIC_ADVENTURE:
        path = MUSIC_ADVENTURE_PATH

    if not ResourceLoader.exists(path):
        push_warning("Music file not found: " + path)
        music_player.stop()
        current_music_path = ""
        return

    var audio := load(path) as AudioStreamMP3

    if audio == null:
        push_warning("Unable to load music: " + path)
        music_player.stop()
        current_music_path = ""
        return

    audio.loop = true

    music_player.stop()
    music_player.stream = audio
    current_music_path = path

    _music_apply_volume()

    if music_enabled:
        music_player.play()

    _music_refresh_buttons()


# ============================================================
# GAME START INTEGRATION
# ============================================================

func _start_adventure() -> void:
    super._start_adventure()

    _music_play_track(MUSIC_ADVENTURE)


# ============================================================
# GAMEPLAY MUSIC CONTROLS
# ============================================================

func _music_create_game_controls() -> void:
    if not is_instance_valid(responsive_root):
        return

    var panel := HBoxContainer.new()
    panel.name = "MusicControls"
    panel.add_theme_constant_override("separation", 5)
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    panel.z_index = 25

    responsive_root.add_child(panel)

    music_game_toggle_button = _music_make_button(
        "♫ إيقاف" if music_enabled else "♫ تشغيل",
        15
    )

    music_game_toggle_button.custom_minimum_size = Vector2(100, 43)
    music_game_toggle_button.pressed.connect(_music_toggle)
    panel.add_child(music_game_toggle_button)

    var down_button := _music_make_button("−", 21)
    down_button.custom_minimum_size = Vector2(43, 43)
    down_button.pressed.connect(_music_volume_down)
    panel.add_child(down_button)

    var up_button := _music_make_button("+", 21)
    up_button.custom_minimum_size = Vector2(43, 43)
    up_button.pressed.connect(_music_volume_up)
    panel.add_child(up_button)

    panel.set_meta("music_controls", true)

    get_viewport().size_changed.connect(
        _music_layout_game_controls
    )

    call_deferred("_music_layout_game_controls")


func _music_layout_game_controls() -> void:
    if not is_instance_valid(responsive_root):
        return

    var panel := responsive_root.get_node_or_null(
        "MusicControls"
    ) as HBoxContainer

    if not is_instance_valid(panel):
        return

    var view_size := get_viewport().get_visible_rect().size

    panel.position = Vector2(
        maxf(8.0, view_size.x - 205.0),
        174.0
    )


# ============================================================
# BUTTON HELPERS
# ============================================================

func _music_make_button(
    caption: String,
    font_size: int
) -> Button:
    var button := Button.new()

    button.text = caption
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.custom_minimum_size = Vector2(48, 48)

    button.add_theme_font_size_override(
        "font_size",
        font_size
    )

    button.add_theme_color_override(
        "font_color",
        Color(1.0, 0.96, 0.82)
    )

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.035, 0.12, 0.22, 0.96)
    normal.border_color = Color(0.25, 0.72, 1.0)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(12)

    var pressed := StyleBoxFlat.new()
    pressed.bg_color = Color(0.32, 0.22, 0.07, 1.0)
    pressed.border_color = Color(1.0, 0.82, 0.25)
    pressed.set_border_width_all(3)
    pressed.set_corner_radius_all(12)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)

    return button


# ============================================================
# MUSIC ACTIONS
# ============================================================

func _music_toggle() -> void:
    music_enabled = not music_enabled

    if music_enabled:
        if current_music_path == "":
            _music_play_track(current_music_mode)
        elif is_instance_valid(music_player):
            music_player.play()
    else:
        if is_instance_valid(music_player):
            music_player.stop()

    _music_save_settings()
    _music_refresh_buttons()


func _music_volume_up() -> void:
    music_volume = clampf(
        music_volume + MUSIC_VOLUME_STEP,
        0.0,
        1.0
    )

    _music_apply_volume()
    _music_save_settings()
    _music_refresh_buttons()


func _music_volume_down() -> void:
    music_volume = clampf(
        music_volume - MUSIC_VOLUME_STEP,
        0.0,
        1.0
    )

    _music_apply_volume()
    _music_save_settings()
    _music_refresh_buttons()


func _music_apply_volume() -> void:
    if not is_instance_valid(music_player):
        return

    if music_volume <= 0.001:
        music_player.volume_db = -60.0
    else:
        music_player.volume_db = linear_to_db(music_volume)


# ============================================================
# BUTTON STATE
# ============================================================

func _music_refresh_buttons() -> void:
    var caption := "♫ إيقاف" if music_enabled else "♫ تشغيل"

    if is_instance_valid(music_menu_toggle_button):
        music_menu_toggle_button.text = caption

    if is_instance_valid(music_game_toggle_button):
        music_game_toggle_button.text = caption

    if is_instance_valid(ultimate_content):
        for child in ultimate_content.get_children():
            if child is Label and child.name == "MusicVolumeText":
                child.text = "مستوى الصوت: %d%%" % int(music_volume * 100.0)


# ============================================================
# SAVE AND LOAD SETTINGS
# ============================================================

func _music_save_settings() -> void:
    var config := ConfigFile.new()

    config.set_value(
        "Music",
        "enabled",
        music_enabled
    )

    config.set_value(
        "Music",
        "volume",
        music_volume
    )

    config.set_value(
        "Music",
        "mode",
        current_music_mode
    )

    config.save(MUSIC_SETTINGS_PATH)


func _music_load_settings() -> void:
    var config := ConfigFile.new()

    var result := config.load(MUSIC_SETTINGS_PATH)

    if result != OK:
        music_enabled = true
        music_volume = MUSIC_DEFAULT_VOLUME
        current_music_mode = MUSIC_INTRO
        return

    music_enabled = config.get_value(
        "Music",
        "enabled",
        true
    )

    music_volume = clampf(
        float(config.get_value(
            "Music",
            "volume",
            MUSIC_DEFAULT_VOLUME
        )),
        0.0,
        1.0
    )

    current_music_mode = int(
        config.get_value(
            "Music",
            "mode",
            MUSIC_INTRO
        )
    )

    if current_music_mode != MUSIC_ADVENTURE:
        current_music_mode = MUSIC_INTRO


# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
    _music_save_settings()

    if is_instance_valid(music_player):
        music_player.stop()
