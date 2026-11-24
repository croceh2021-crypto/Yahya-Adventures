extends "res://Scripts/main.gd"

# YAHYA ADVENTURES - MOBILE GAMEPLAY UPDATE 2
# Godot 4.4.1
# Keeps the original room, player, coins and door from main.gd.

const CONTROL_GAP := 12.0
const UI_MARGIN := 18.0

var responsive_root: Control
var title_label: Label
var stage_label: Label
var responsive_coin_label: Label
var responsive_message_label: Label
var dpad_buttons: Array[Button] = []
var dpad_directions: Array[Vector2] = []
var pressed_directions: Array[Vector2] = []
var pause_button: Button
var pause_overlay: ColorRect
var complete_overlay: ColorRect
var level_complete := false
var is_game_paused := false


func _ready() -> void:
    # Run the original scene setup. Its create_ui() call uses this file's UI.
    super._ready()


func _process(delta: float) -> void:
    # Preserve all original movement, camera, coin and door logic.
    super._process(delta)

    if not level_complete and door_open and is_instance_valid(player):
        # The player must pass through the opened doorway, not merely stand near it.
        if player.position.z < -4.85 and player.position.x > 2.55 and player.position.x < 4.45:
            _complete_level()


func create_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "ResponsiveMobileUI"
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    responsive_root = Control.new()
    responsive_root.name = "UIRoot"
    responsive_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    responsive_root.mouse_filter = Control.MOUSE_FILTER_PASS
    responsive_root.process_mode = Node.PROCESS_MODE_ALWAYS
    layer.add_child(responsive_root)

    title_label = _make_label("مغامرات يحيى", 34, Color(1.0, 0.82, 0.20))
    responsive_root.add_child(title_label)

    stage_label = _make_label("المرحلة 1  •  اجمع العملات وافتح الباب", 17, Color(0.95, 0.96, 1.0))
    responsive_root.add_child(stage_label)

    responsive_coin_label = _make_label("العملات: 0 / 4", 25, Color.WHITE)
    responsive_root.add_child(responsive_coin_label)

    responsive_message_label = _make_label("استكشف الغرفة واجمع العملات الذهبية", 19, Color.WHITE)
    responsive_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    responsive_root.add_child(responsive_message_label)

    # Keep the original script's UI references connected to the new labels.
    coin_label = responsive_coin_label
    message_label = responsive_message_label

    _make_dpad_button("▲", Vector2(0, -1))
    _make_dpad_button("◀", Vector2(-1, 0))
    _make_dpad_button("▶", Vector2(1, 0))
    _make_dpad_button("▼", Vector2(0, 1))

    pause_button = _make_action_button("Ⅱ", 30)
    pause_button.tooltip_text = "إيقاف مؤقت"
    pause_button.pressed.connect(_open_pause_menu)
    responsive_root.add_child(pause_button)

    _create_pause_overlay()
    _create_complete_overlay()

    responsive_root.resized.connect(_layout_responsive_ui)
    get_viewport().size_changed.connect(_layout_responsive_ui)
    _layout_responsive_ui()
    update_coin_label()


func _make_label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label


func _make_dpad_button(caption: String, direction: Vector2) -> void:
    var button := _make_action_button(caption, 34)
    button.custom_minimum_size = Vector2(76, 76)
    responsive_root.add_child(button)
    dpad_buttons.append(button)
    dpad_directions.append(direction)

    # Track each held direction separately, allowing diagonal movement.
    button.button_down.connect(func():
        if not pressed_directions.has(direction):
            pressed_directions.append(direction)
        _refresh_move_vector()
    )
    button.button_up.connect(func():
        pressed_directions.erase(direction)
        _refresh_move_vector()
    )
    button.mouse_exited.connect(func():
        pressed_directions.erase(direction)
        _refresh_move_vector()
    )


func _refresh_move_vector() -> void:
    var combined := Vector2.ZERO
    for direction in pressed_directions:
        combined += direction
    move_vector = combined.normalized() if combined.length() > 0.0 else Vector2.ZERO


func _make_action_button(caption: String, font_size: int) -> Button:
    var button := Button.new()
    button.text = caption
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(68, 68)
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.35))
    button.add_theme_stylebox_override("normal", _make_button_style(
        Color(0.08, 0.14, 0.23, 0.91), Color(0.95, 0.67, 0.16), 3))
    button.add_theme_stylebox_override("hover", _make_button_style(
        Color(0.17, 0.27, 0.40, 0.97), Color(1.0, 0.82, 0.30), 4))
    button.add_theme_stylebox_override("pressed", _make_button_style(
        Color(0.48, 0.29, 0.08, 0.99), Color(1.0, 0.91, 0.52), 4))
    return button


func _make_button_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(20)
    style.shadow_color = Color(0, 0, 0, 0.55)
    style.shadow_size = 7
    style.shadow_offset = Vector2(0, 4)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style


func _layout_responsive_ui() -> void:
    if not is_instance_valid(responsive_root):
        return

    var view_size := get_viewport().get_visible_rect().size
    if view_size.x <= 0.0 or view_size.y <= 0.0:
        return

    var portrait := view_size.y > view_size.x
    var button_size := clampf(minf(view_size.x * 0.19, view_size.y * 0.14), 66.0, 94.0)
    var gap := CONTROL_GAP

    title_label.position = Vector2(UI_MARGIN, 12)
    title_label.add_theme_font_size_override("font_size", 29 if portrait else 36)

    stage_label.position = Vector2(UI_MARGIN + 2, 48 if portrait else 53)
    stage_label.add_theme_font_size_override("font_size", 14 if portrait else 17)

    responsive_coin_label.position = Vector2(UI_MARGIN + 2, 72 if portrait else 82)
    responsive_coin_label.add_theme_font_size_override("font_size", 21 if portrait else 26)

    responsive_message_label.position = Vector2(UI_MARGIN, 111 if portrait else 124)
    responsive_message_label.size = Vector2(
        maxf(130.0, view_size.x - (button_size * 2.0) - 48.0),
        62.0
    )
    responsive_message_label.add_theme_font_size_override("font_size", 15 if portrait else 19)

    # Four large directional buttons in the lower-right corner.
    var center_x := button_size + gap
    var middle_y := button_size + gap
    var positions := [
        Vector2(-center_x - button_size * 0.5, -(button_size * 2.0 + gap * 2.0)),
        Vector2(-(button_size * 2.0 + gap * 2.0), -middle_y),
        Vector2(-gap, -middle_y),
        Vector2(-center_x - button_size * 0.5, -gap)
    ]

    for i in range(dpad_buttons.size()):
        var button := dpad_buttons[i]
        button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        button.size = Vector2(button_size, button_size)
        button.position = positions[i]
        button.add_theme_font_size_override("font_size", int(button_size * 0.38))

    pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    pause_button.size = Vector2(58.0, 58.0)
    pause_button.position = Vector2(-76.0, 16.0)
    pause_button.add_theme_font_size_override("font_size", 28)


func _create_pause_overlay() -> void:
    pause_overlay = _make_overlay("PauseOverlay")
    var panel := _make_overlay_panel(pause_overlay)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    panel.add_child(column)

    var heading := _make_label("اللعبة متوقفة", 28, Color(1.0, 0.82, 0.20))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)

    var resume := _make_action_button("متابعة اللعب", 22)
    resume.custom_minimum_size = Vector2(260, 62)
    resume.pressed.connect(_resume_game)
    column.add_child(resume)

    var restart := _make_action_button("إعادة المرحلة", 21)
    restart.custom_minimum_size = Vector2(260, 62)
    restart.pressed.connect(_restart_level)
    column.add_child(restart)


func _create_complete_overlay() -> void:
    complete_overlay = _make_overlay("CompleteOverlay")
    var panel := _make_overlay_panel(complete_overlay)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    panel.add_child(column)

    var heading := _make_label("أحسنت يا يحيى!", 30, Color(1.0, 0.82, 0.20))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)

    var details := _make_label("لقد جمعت العملات الأربع وأنهيت المرحلة الأولى.", 18, Color.WHITE)
    details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(details)

    var replay := _make_action_button("العب من جديد", 22)
    replay.custom_minimum_size = Vector2(260, 62)
    replay.pressed.connect(_restart_level)
    column.add_child(replay)


func _make_overlay(node_name: String) -> ColorRect:
    var overlay := ColorRect.new()
    overlay.name = node_name
    overlay.color = Color(0.015, 0.025, 0.05, 0.82)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    responsive_root.add_child(overlay)
    return overlay


func _make_overlay_panel(parent: Control) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-175, -145)
    panel.size = Vector2(350, 290)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.11, 0.18, 0.98)
    style.border_color = Color(0.95, 0.67, 0.16)
    style.set_border_width_all(3)
    style.set_corner_radius_all(24)
    style.content_margin_left = 22
    style.content_margin_right = 22
    style.content_margin_top = 22
    style.content_margin_bottom = 22
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel


func _open_pause_menu() -> void:
    if level_complete or is_game_paused:
        return
    is_game_paused = true
    move_vector = Vector2.ZERO
    pressed_directions.clear()
    get_tree().paused = true
    pause_overlay.visible = true


func _resume_game() -> void:
    pause_overlay.visible = false
    is_game_paused = false
    get_tree().paused = false


func _complete_level() -> void:
    level_complete = true
    move_vector = Vector2.ZERO
    pressed_directions.clear()
    complete_overlay.visible = true
    get_tree().paused = true


func _restart_level() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()


func follow_camera(delta: float) -> void:
    if not is_instance_valid(player) or not is_instance_valid(camera):
        return

    var view_size := get_viewport().get_visible_rect().size
    var portrait := view_size.y > view_size.x
    var camera_offset := Vector3(0, 8.4, 11.0) if portrait else Vector3(0, 6.8, 8.5)
    camera.fov = 74.0 if portrait else 62.0
    var target_position := player.global_position + camera_offset
    var weight := 1.0 - exp(-CAMERA_SMOOTHING * delta)
    camera.global_position = camera.global_position.lerp(target_position, weight)
    camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)


func update_coin_label() -> void:
    if is_instance_valid(responsive_coin_label):
        responsive_coin_label.text = "العملات: " + str(coin_count) + " / 4"
    elif is_instance_valid(coin_label):
        coin_label.text = "العملات: " + str(coin_count) + " / 4"


func show_message(value: String) -> void:
    if is_instance_valid(responsive_message_label):
        responsive_message_label.text = value
        message_timer = 2.8
    elif is_instance_valid(message_label):
        message_label.text = value
        message_timer = 2.8
