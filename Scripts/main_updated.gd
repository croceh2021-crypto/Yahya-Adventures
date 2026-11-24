
extends "res://Scripts/main.gd"

# YAHYA ADVENTURES - FULL SCREEN & MULTI-TOUCH UPDATE
# Godot 4.4.1
# Replace Scripts/main_updated.gd only.

const UI_MARGIN := 14.0
const UI_GAP := 9.0
const SPRINT_MULTIPLIER := 1.55
const STAMINA_MAX := 100.0
const JUMP_POWER := 5.0
const JUMP_GRAVITY := 13.5
const CAMERA_DISTANCE_MIN := 6.0
const CAMERA_DISTANCE_MAX := 12.0

var responsive_root: Control
var title_label: Label
var stage_label: Label
var responsive_coin_label: Label
var responsive_message_label: Label
var stamina_bar: ProgressBar
var stamina_caption: Label

var dpad_buttons: Array[Button] = []
var pressed_directions: Array[Vector2] = []
var touch_fingers: Dictionary = {}
var mouse_sprint_requested := false

var sprint_button: Button
var jump_button: Button
var pause_button: Button
var zoom_in_button: Button
var zoom_out_button: Button

var pause_overlay: ColorRect
var complete_overlay: ColorRect

var level_complete := false
var is_game_paused := false
var sprint_requested := false
var sprint_enabled := false

var stamina := STAMINA_MAX
var stamina_visual_state := -1

var jump_velocity := 0.0
var jump_height := 0.0
var camera_distance := 8.6

var message_default := "اجمع العملات الذهبية الأربع ثم اتجه إلى الباب"


func _ready() -> void:
    Input.set_emulate_mouse_from_touch(false)
    super._ready()
    _layout_responsive_ui()
    update_coin_label()


func _process(delta: float) -> void:
    _fix_interaction_button_position()

    if is_game_paused or level_complete:
        return

    var keyboard_input := Input.get_vector(
        "ui_left", "ui_right", "ui_up", "ui_down"
    )

    var moving := move_vector.length() > 0.05 or keyboard_input.length() > 0.05

    sprint_enabled = sprint_requested and moving and stamina > 0.5

    if sprint_enabled:
        stamina = maxf(0.0, stamina - 30.0 * delta)
        if stamina <= 0.5:
            sprint_enabled = false
    else:
        stamina = minf(STAMINA_MAX, stamina + 19.0 * delta)

    _update_jump(delta)

    super._process(delta)

    _update_stamina_ui()

    if not level_complete and door_open and is_instance_valid(player):
        if player.position.z < -4.85:
            if player.position.x > 2.55 and player.position.x < 4.45:
                _complete_level()


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release_all_controls()

    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _release_all_controls()


# ============================================================
# TRUE MULTI-TOUCH INPUT
# ============================================================

func _input(event: InputEvent) -> void:
    if not (event is InputEventScreenTouch):
        return

    var touch := event as InputEventScreenTouch

    if touch.pressed:
        if touch_fingers.has(touch.index):
            return

        var target: Button = null

        # FIX:
        # Check the intro / guide / achievements menu first.
        # It is displayed in ultimate_root, not responsive_root.
        if is_instance_valid(ultimate_root) and ultimate_root.visible:
            target = _find_touch_button(ultimate_root, touch.position)
        elif is_instance_valid(complete_overlay) and complete_overlay.visible:
            target = _find_touch_button(complete_overlay, touch.position)
        elif is_instance_valid(pause_overlay) and pause_overlay.visible:
            target = _find_touch_button(pause_overlay, touch.position)
        else:
            target = _find_touch_button(responsive_root, touch.position)

        if is_instance_valid(target):
            touch_fingers[touch.index] = target
            _handle_touch_button(target, true)
            get_viewport().set_input_as_handled()

    else:
        if touch_fingers.has(touch.index):
            var target: Button = touch_fingers[touch.index]
            touch_fingers.erase(touch.index)
            _handle_touch_button(target, false)
            get_viewport().set_input_as_handled()


func _find_touch_button(node: Node, screen_position: Vector2) -> Button:
    if not is_instance_valid(node):
        return null

    for i in range(node.get_child_count() - 1, -1, -1):
        var found := _find_touch_button(
            node.get_child(i),
            screen_position
        )

        if is_instance_valid(found):
            return found

    if node is Button:
        var button := node as Button

        if button.visible and button.is_visible_in_tree() and not button.disabled:
            if button.get_global_rect().has_point(screen_position):
                return button

    return null


func _handle_touch_button(button: Button, is_down: bool) -> void:
    if dpad_buttons.has(button):
        _refresh_move_vector()
        return

    if button == sprint_button:
        _refresh_sprint_request()
        return

    if not is_down:
        return

    if button == jump_button:
        _try_jump()
    elif button == pause_button:
        _open_pause_menu()
    elif button == zoom_in_button:
        _zoom_camera_in()
    elif button == zoom_out_button:
        _zoom_camera_out()
    else:
        # Includes garden interaction and all menu buttons.
        button.pressed.emit()


func _refresh_sprint_request() -> void:
    var touch_sprint := false

    for held_button in touch_fingers.values():
        if held_button == sprint_button:
            touch_sprint = true
            break

    sprint_requested = mouse_sprint_requested or touch_sprint


func _fix_interaction_button_position() -> void:
    if not is_instance_valid(responsive_root):
        return

    for child in responsive_root.get_children():
        if child is Button:
            var button := child as Button

            if button.text == "تفاعل":
                var view_size := get_viewport().get_visible_rect().size

                button.set_anchors_preset(Control.PRESET_TOP_LEFT)
                button.size = Vector2(116.0, 58.0)
                button.position = Vector2(
                    (view_size.x - button.size.x) * 0.5,
                    view_size.y - button.size.y - 18.0
                )
                return


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if is_game_paused:
            _resume_game()
        elif not level_complete:
            _open_pause_menu()


# ============================================================
# USER INTERFACE
# ============================================================

func create_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "YahyaMobileHUD"
    layer.layer = 100
    layer.follow_viewport_enabled = false
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    responsive_root = Control.new()
    responsive_root.name = "HUDRoot"
    responsive_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    responsive_root.mouse_filter = Control.MOUSE_FILTER_PASS
    responsive_root.process_mode = Node.PROCESS_MODE_ALWAYS
    layer.add_child(responsive_root)

    title_label = _make_label(
        "مغامرات يحيى", 32, Color(1.0, 0.82, 0.20)
    )
    responsive_root.add_child(title_label)

    stage_label = _make_label(
        "المرحلة 1  •  اجمع العملات وافتح الباب",
        16, Color.WHITE
    )
    responsive_root.add_child(stage_label)

    responsive_coin_label = _make_label(
        "العملات: 0 / 4", 23, Color(1.0, 0.92, 0.56)
    )
    responsive_root.add_child(responsive_coin_label)

    responsive_message_label = _make_label(
        message_default, 16, Color.WHITE
    )
    responsive_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    responsive_root.add_child(responsive_message_label)

    coin_label = responsive_coin_label
    message_label = responsive_message_label

    stamina_caption = _make_label("الطاقة", 14, Color.WHITE)
    responsive_root.add_child(stamina_caption)

    stamina_bar = ProgressBar.new()
    stamina_bar.min_value = 0.0
    stamina_bar.max_value = STAMINA_MAX
    stamina_bar.value = STAMINA_MAX
    stamina_bar.show_percentage = false
    stamina_bar.add_theme_stylebox_override(
        "background", _make_bar_style(Color(0.03, 0.06, 0.10, 0.85))
    )
    stamina_bar.add_theme_stylebox_override(
        "fill", _make_bar_style(Color(0.20, 0.82, 0.40, 1.0))
    )
    responsive_root.add_child(stamina_bar)

    # Direction pad: up, left, right, down.
    _make_dpad_button("▲", Vector2(0, -1))
    _make_dpad_button("◀", Vector2(-1, 0))
    _make_dpad_button("▶", Vector2(1, 0))
    _make_dpad_button("▼", Vector2(0, 1))

    sprint_button = _make_action_button("ركض", 19)
    sprint_button.button_down.connect(
        func():
            mouse_sprint_requested = true
            _refresh_sprint_request()
    )
    sprint_button.button_up.connect(
        func():
            mouse_sprint_requested = false
            _refresh_sprint_request()
    )
    responsive_root.add_child(sprint_button)

    jump_button = _make_action_button("قفز", 20)
    jump_button.button_down.connect(_try_jump)
    responsive_root.add_child(jump_button)

    pause_button = _make_action_button("Ⅱ", 27)
    pause_button.tooltip_text = "إيقاف مؤقت"
    pause_button.pressed.connect(_open_pause_menu)
    responsive_root.add_child(pause_button)

    zoom_in_button = _make_action_button("＋", 23)
    zoom_in_button.tooltip_text = "تقريب الكاميرا"
    zoom_in_button.pressed.connect(_zoom_camera_in)
    responsive_root.add_child(zoom_in_button)

    zoom_out_button = _make_action_button("－", 23)
    zoom_out_button.tooltip_text = "إبعاد الكاميرا"
    zoom_out_button.pressed.connect(_zoom_camera_out)
    responsive_root.add_child(zoom_out_button)

    _create_pause_overlay()
    _create_complete_overlay()

    responsive_root.resized.connect(_layout_responsive_ui)
    get_viewport().size_changed.connect(_layout_responsive_ui)

    call_deferred("_layout_responsive_ui")


func _make_label(
    value: String,
    font_size: int,
    color: Color
) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override(
        "font_shadow_color", Color(0, 0, 0, 0.95)
    )
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _make_dpad_button(
    caption: String,
    direction: Vector2
) -> void:
    var button := _make_action_button(caption, 34)
    button.name = "Move_" + caption
    responsive_root.add_child(button)
    dpad_buttons.append(button)

    button.button_down.connect(func():
        if not pressed_directions.has(direction):
            pressed_directions.append(direction)
        _refresh_move_vector()
    )

    button.button_up.connect(func():
        pressed_directions.erase(direction)
        _refresh_move_vector()
    )


func _make_action_button(
    caption: String,
    font_size: int
) -> Button:
    var button := Button.new()
    button.text = caption
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    button.custom_minimum_size = Vector2(60, 60)

    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override(
        "font_color", Color(1.0, 0.97, 0.86)
    )
    button.add_theme_color_override(
        "font_hover_color", Color.WHITE
    )
    button.add_theme_color_override(
        "font_pressed_color", Color(1.0, 0.88, 0.38)
    )

    button.add_theme_stylebox_override(
        "normal",
        _make_button_style(
            Color(0.035, 0.09, 0.17, 0.94),
            Color(0.28, 0.72, 1.0), 3
        )
    )

    button.add_theme_stylebox_override(
        "hover",
        _make_button_style(
            Color(0.10, 0.23, 0.37, 0.98),
            Color(0.65, 0.88, 1.0), 3
        )
    )

    button.add_theme_stylebox_override(
        "pressed",
        _make_button_style(
            Color(0.36, 0.23, 0.06, 1.0),
            Color(1.0, 0.84, 0.26), 4
        )
    )

    return button


func _make_button_style(
    fill_color: Color,
    border_color: Color,
    border_width: int
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(18)
    style.shadow_color = Color(0, 0, 0, 0.58)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0, 3)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    return style


func _make_bar_style(fill_color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.set_corner_radius_all(8)
    return style


# ============================================================
# RESPONSIVE LAYOUT
# ============================================================

func _layout_responsive_ui() -> void:
    if not is_instance_valid(responsive_root):
        return

    var view_size := get_viewport().get_visible_rect().size

    if view_size.x < 1.0 or view_size.y < 1.0:
        return

    var portrait := view_size.y > view_size.x
    var margin := UI_MARGIN
    var gap := UI_GAP

    var button_size := clampf(
        minf(view_size.x * 0.075, view_size.y * 0.125),
        52.0, 76.0
    )

    # Keep every button within the visible viewport.
    for button in dpad_buttons:
        button.set_anchors_preset(Control.PRESET_TOP_LEFT)
        button.size = Vector2(button_size, button_size)

    # Direction pad on the lower-right side.
    var center_x := view_size.x - margin - (button_size * 2.0) - gap
    var center_y := view_size.y - margin - (button_size * 2.0) - gap

    var dpad_positions := [
        Vector2(center_x, center_y - button_size - gap),
        Vector2(center_x - button_size - gap, center_y),
        Vector2(center_x + button_size + gap, center_y),
        Vector2(center_x, center_y + button_size + gap)
    ]

    for i in range(dpad_buttons.size()):
        dpad_buttons[i].position = dpad_positions[i]
        dpad_buttons[i].add_theme_font_size_override(
            "font_size", int(button_size * 0.40)
        )

    # Sprint and jump on the lower-left side.
    var action_width := button_size * 1.35
    var action_height := button_size * 0.82

    sprint_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    jump_button.set_anchors_preset(Control.PRESET_TOP_LEFT)

    sprint_button.size = Vector2(action_width, action_height)
    jump_button.size = Vector2(action_width, action_height)

    sprint_button.position = Vector2(
        margin, view_size.y - margin - action_height
    )

    jump_button.position = Vector2(
        margin,
        view_size.y - margin - (action_height * 2.0) - gap
    )

    sprint_button.add_theme_font_size_override(
        "font_size", int(button_size * 0.25)
    )
    jump_button.add_theme_font_size_override(
        "font_size", int(button_size * 0.25)
    )

    # Information panel.
    title_label.position = Vector2(margin, 8)
    title_label.add_theme_font_size_override(
        "font_size", 28 if portrait else 34
    )

    stage_label.position = Vector2(margin + 2, 44 if portrait else 49)
    stage_label.add_theme_font_size_override(
        "font_size", 13 if portrait else 16
    )

    responsive_coin_label.position = Vector2(
        margin + 2, 68 if portrait else 76
    )
    responsive_coin_label.add_theme_font_size_override(
        "font_size", 20 if portrait else 24
    )

    responsive_message_label.position = Vector2(
        margin, 104 if portrait else 112
    )
    responsive_message_label.size = Vector2(
        minf(view_size.x * 0.48, 430.0), 58.0
    )
    responsive_message_label.add_theme_font_size_override(
        "font_size", 14 if portrait else 17
    )

    # Energy bar is placed below the information panel.
    stamina_caption.position = Vector2(margin, 155 if portrait else 154)

    stamina_bar.position = Vector2(
        margin + 48.0, 157 if portrait else 156
    )
    stamina_bar.size = Vector2(
        112.0 if portrait else 150.0, 15.0
    )

    # Pause and camera controls at the upper-right.
    for button in [pause_button, zoom_in_button, zoom_out_button]:
        button.set_anchors_preset(Control.PRESET_TOP_LEFT)

    pause_button.size = Vector2(52, 52)
    pause_button.position = Vector2(
        view_size.x - margin - 52, margin
    )

    zoom_in_button.size = Vector2(44, 42)
    zoom_in_button.position = Vector2(
        view_size.x - margin - 44, 72
    )

    zoom_out_button.size = Vector2(44, 42)
    zoom_out_button.position = Vector2(
        view_size.x - margin - 44, 120
    )

    _fix_interaction_button_position()


func _refresh_move_vector() -> void:
    var combined := Vector2.ZERO

    # Mouse / keyboard-style held directions.
    for direction in pressed_directions:
        combined += direction

    # Independently held touch fingers.
    var touch_directions := [
        Vector2(0, -1),
        Vector2(-1, 0),
        Vector2(1, 0),
        Vector2(0, 1)
    ]

    for held_button in touch_fingers.values():
        var index := dpad_buttons.find(held_button)

        if index >= 0 and index < touch_directions.size():
            combined += touch_directions[index]

    move_vector = (
        combined.normalized()
        if combined.length() > 0.0
        else Vector2.ZERO
    )


func _release_all_controls() -> void:
    touch_fingers.clear()
    pressed_directions.clear()
    move_vector = Vector2.ZERO
    mouse_sprint_requested = false
    sprint_requested = false
    sprint_enabled = false


# ============================================================
# PLAYER MOVEMENT AND JUMP
# ============================================================

func move_player(delta: float) -> void:
    var input_direction := move_vector

    input_direction += Input.get_vector(
        "ui_left", "ui_right", "ui_up", "ui_down"
    )

    if input_direction.length() > 1.0:
        input_direction = input_direction.normalized()

    var target_speed := PLAYER_SPEED

    if sprint_enabled:
        target_speed *= SPRINT_MULTIPLIER

    if input_direction.length() > 0.05:
        move_velocity = move_velocity.move_toward(
            input_direction * target_speed,
            PLAYER_ACCELERATION * delta
        )
    else:
        move_velocity = move_velocity.move_toward(
            Vector2.ZERO,
            PLAYER_FRICTION * delta
        )

    var direction := Vector3(
        move_velocity.x, 0.0, move_velocity.y
    )

    player.position += direction * delta

    player.position.x = clampf(
        player.position.x, -ROOM_LIMIT, ROOM_LIMIT
    )

    player.position.z = clampf(
        player.position.z, -ROOM_LIMIT, ROOM_LIMIT
    )

    if move_velocity.length() > 0.12:
        var target_rotation := atan2(
            -move_velocity.x, -move_velocity.y
        )

        player.rotation.y = lerp_angle(
            player.rotation.y,
            target_rotation,
            minf(1.0, delta * 12.0)
        )


func _try_jump() -> void:
    if jump_height <= 0.02:
        jump_velocity = JUMP_POWER


func _update_jump(delta: float) -> void:
    if jump_height > 0.0 or jump_velocity > 0.0:
        jump_velocity -= JUMP_GRAVITY * delta

        jump_height = maxf(
            0.0, jump_height + jump_velocity * delta
        )

        if jump_height <= 0.0:
            jump_velocity = 0.0

    # Move the whole character vertically during the jump.
    if is_instance_valid(player):
        player.position.y = jump_height


func animate_character(delta: float) -> void:
    if not is_instance_valid(character_sprite):
        return

    var bob := 0.0

    if move_velocity.length() > 0.18:
        walk_time += delta * (
            13.0 if sprint_enabled else 10.0
        )

        bob = absf(sin(walk_time)) * (
            0.12 if sprint_enabled else 0.08
        )

        character_sprite.rotation.z = sin(walk_time) * 0.035
    else:
        character_sprite.rotation.z = lerpf(
            character_sprite.rotation.z,
            0.0,
            minf(1.0, delta * 8.0)
        )

    character_sprite.position.y = 1.36 + bob


# ============================================================
# CAMERA - ROOM FILLING VIEW
# ============================================================

func follow_camera(delta: float) -> void:
    if not is_instance_valid(player):
        return

    if not is_instance_valid(camera):
        return

    var view_size := get_viewport().get_visible_rect().size
    var aspect_ratio := view_size.x / maxf(view_size.y, 1.0)

    var portrait := aspect_ratio < 1.0

    var vertical_factor := 0.62 if not portrait else 0.72
    var depth_factor := 0.92 if not portrait else 1.05

    var vertical_offset := camera_distance * vertical_factor
    var depth_offset := camera_distance * depth_factor

    var target_position := player.global_position + Vector3(
        0.0, vertical_offset, depth_offset
    )

    var weight := 1.0 - exp(-7.5 * delta)

    camera.global_position = camera.global_position.lerp(
        target_position, weight
    )

    camera.keep_aspect = Camera3D.KEEP_HEIGHT

    # A wider field of view shows more of the room.
    camera.fov = 70.0 if not portrait else 76.0

    var look_direction := Vector3(
        move_velocity.x, 0.0, move_velocity.y
    )

    var look_ahead := Vector3.ZERO

    if look_direction.length() > 0.1:
        look_ahead = look_direction.normalized() * 0.35

    camera.look_at(
        player.global_position
        + Vector3(0.0, 1.35, 0.0)
        + look_ahead,
        Vector3.UP
    )


func _zoom_camera_in() -> void:
    camera_distance = maxf(
        CAMERA_DISTANCE_MIN, camera_distance - 0.7
    )


func _zoom_camera_out() -> void:
    camera_distance = minf(
        CAMERA_DISTANCE_MAX, camera_distance + 0.7
    )


# ============================================================
# STAMINA
# ============================================================

func _update_stamina_ui() -> void:
    if not is_instance_valid(stamina_bar):
        return

    stamina_bar.value = stamina

    var visual_state := 0

    if stamina < 25.0:
        visual_state = 2
    elif stamina < 55.0:
        visual_state = 1

    if visual_state == stamina_visual_state:
        return

    stamina_visual_state = visual_state

    var fill := Color(0.20, 0.82, 0.40, 1.0)

    if visual_state == 2:
        fill = Color(0.92, 0.22, 0.15, 1.0)
    elif visual_state == 1:
        fill = Color(1.0, 0.68, 0.12, 1.0)

    stamina_bar.add_theme_stylebox_override(
        "fill", _make_bar_style(fill)
    )


# ============================================================
# PAUSE AND COMPLETION SCREENS
# ============================================================

func _create_pause_overlay() -> void:
    pause_overlay = _make_overlay("PauseOverlay")

    var panel := _make_overlay_panel(pause_overlay)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)

    var heading := _make_label(
        "اللعبة متوقفة", 27, Color(1.0, 0.82, 0.20)
    )
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)

    var resume := _make_action_button("متابعة اللعب", 21)
    resume.custom_minimum_size = Vector2(250, 58)
    resume.pressed.connect(_resume_game)
    column.add_child(resume)

    var restart := _make_action_button("إعادة المرحلة", 20)
    restart.custom_minimum_size = Vector2(250, 58)
    restart.pressed.connect(_restart_level)
    column.add_child(restart)


func _create_complete_overlay() -> void:
    complete_overlay = _make_overlay("CompleteOverlay")

    var panel := _make_overlay_panel(complete_overlay)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)

    var heading := _make_label(
        "أحسنت يا يحيى!", 29, Color(1.0, 0.82, 0.20)
    )
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(heading)

    var details := _make_label(
        "جمعت العملات الأربع وخرجت من الغرفة بنجاح!",
        17, Color.WHITE
    )
    details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(details)

    var replay := _make_action_button("العب من جديد", 21)
    replay.custom_minimum_size = Vector2(250, 58)
    replay.pressed.connect(_restart_level)
    column.add_child(replay)


func _make_overlay(node_name: String) -> ColorRect:
    var overlay := ColorRect.new()
    overlay.name = node_name
    overlay.color = Color(0.015, 0.025, 0.05, 0.84)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    responsive_root.add_child(overlay)
    return overlay


func _make_overlay_panel(parent: Control) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-165, -140)
    panel.size = Vector2(330, 280)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.09, 0.15, 0.99)
    style.border_color = Color(0.95, 0.67, 0.16, 1.0)
    style.set_border_width_all(3)
    style.set_corner_radius_all(22)
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 20
    style.content_margin_bottom = 20

    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)

    return panel


func _open_pause_menu() -> void:
    if level_complete or is_game_paused:
        return

    is_game_paused = true
    _release_all_controls()

    get_tree().paused = true
    pause_overlay.visible = true


func _resume_game() -> void:
    pause_overlay.visible = false
    is_game_paused = false
    get_tree().paused = false


func _complete_level() -> void:
    level_complete = true

    _release_all_controls()

    complete_overlay.visible = true
    get_tree().paused = true


func _restart_level() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()


# ============================================================
# ORIGINAL SCRIPT COMPATIBILITY
# ============================================================

func update_coin_label() -> void:
    if is_instance_valid(responsive_coin_label):
        responsive_coin_label.text = (
            "العملات: " + str(coin_count) + " / 4"
        )
    elif is_instance_valid(coin_label):
        coin_label.text = (
            "العملات: " + str(coin_count) + " / 4"
        )


func show_message(value: String) -> void:
    if is_instance_valid(responsive_message_label):
        responsive_message_label.text = value
        message_timer = 2.8
    elif is_instance_valid(message_label):
        message_label.text = value
        message_timer = 2.8
