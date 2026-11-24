extends "res://Scripts/main.gd"

# YAHYA ADVENTURES - RESPONSIVE MOBILE CONTROLS
# Godot 4.4.1
# هذا الملف يرث من main.gd ويحافظ على جميع عناصر اللعبة الأصلية.

var responsive_root: Control
var title_label: Label
var responsive_coin_label: Label
var responsive_message_label: Label
var dpad_buttons: Array[Button] = []
var dpad_directions: Array[Vector2] = []

const CONTROL_GAP := 12.0


func create_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "ResponsiveMobileUI"
    add_child(layer)

    responsive_root = Control.new()
    responsive_root.name = "UIRoot"
    responsive_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    responsive_root.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(responsive_root)

    title_label = Label.new()
    title_label.text = "مغامرات يحيى"
    title_label.add_theme_font_size_override("font_size", 34)
    title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.20))
    title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    title_label.add_theme_constant_override("shadow_offset_x", 2)
    title_label.add_theme_constant_override("shadow_offset_y", 2)
    responsive_root.add_child(title_label)

    responsive_coin_label = Label.new()
    responsive_coin_label.add_theme_font_size_override("font_size", 25)
    responsive_coin_label.add_theme_color_override("font_color", Color.WHITE)
    responsive_root.add_child(responsive_coin_label)

    responsive_message_label = Label.new()
    responsive_message_label.text = "استكشف الغرفة واجمع العملات الذهبية"
    responsive_message_label.add_theme_font_size_override("font_size", 20)
    responsive_message_label.add_theme_color_override("font_color", Color.WHITE)
    responsive_message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    responsive_message_label.add_theme_constant_override("shadow_offset_x", 2)
    responsive_message_label.add_theme_constant_override("shadow_offset_y", 2)
    responsive_root.add_child(responsive_message_label)

    # ربط مراجع الواجهة الجديدة بمتغيرات السكربت الأصلي
    # حتى تستمر رسائل اللعبة وتحديث العملات دون أخطاء.
    coin_label = responsive_coin_label
    message_label = responsive_message_label

    # نحتفظ بالمراجع نفسها حتى نحدّث مواضع الأزرار عند تدوير الهاتف.
    _make_dpad_button("▲", Vector2(0, -1))
    _make_dpad_button("◀", Vector2(-1, 0))
    _make_dpad_button("▶", Vector2(1, 0))
    _make_dpad_button("▼", Vector2(0, 1))

    responsive_root.resized.connect(_layout_responsive_ui)
    get_viewport().size_changed.connect(_layout_responsive_ui)

    _layout_responsive_ui()
    update_coin_label()


func _make_dpad_button(caption: String, direction: Vector2) -> void:
    var button := Button.new()
    button.text = caption
    button.focus_mode = Control.FOCUS_NONE
    button.size = Vector2(88, 88)
    button.add_theme_font_size_override("font_size", 34)
    button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.35))

    var normal_style := _make_button_style(
        Color(0.10, 0.16, 0.25, 0.88),
        Color(0.95, 0.67, 0.16),
        4
    )
    var hover_style := _make_button_style(
        Color(0.18, 0.27, 0.39, 0.96),
        Color(1.0, 0.82, 0.30),
        4
    )
    var pressed_style := _make_button_style(
        Color(0.48, 0.29, 0.08, 0.98),
        Color(1.0, 0.91, 0.52),
        5
    )

    button.add_theme_stylebox_override("normal", normal_style)
    button.add_theme_stylebox_override("hover", hover_style)
    button.add_theme_stylebox_override("pressed", pressed_style)
    button.add_theme_stylebox_override("focus", normal_style)

    responsive_root.add_child(button)
    dpad_buttons.append(button)
    dpad_directions.append(direction)

    button.button_down.connect(func():
        move_vector = direction
    )
    button.button_up.connect(func():
        move_vector = Vector2.ZERO
    )
    button.mouse_exited.connect(func():
        move_vector = Vector2.ZERO
    )


func _make_button_style(
    fill_color: Color,
    border_color: Color,
    border_width: int
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(22)
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

    var is_portrait := view_size.y > view_size.x
    var button_size := clampf(minf(view_size.x * 0.19, view_size.y * 0.14), 66.0, 92.0)
    var gap := CONTROL_GAP
    var center_x := button_size + gap
    var middle_y := button_size + gap

    title_label.position = Vector2(20, 14)
    title_label.add_theme_font_size_override(
        "font_size", 30 if is_portrait else 36
    )

    responsive_coin_label.position = Vector2(22, 56 if is_portrait else 62)
    responsive_coin_label.add_theme_font_size_override(
        "font_size", 22 if is_portrait else 26
    )

    responsive_message_label.position = Vector2(20, 94 if is_portrait else 108)
    responsive_message_label.size = Vector2(
        maxf(150.0, view_size.x - 40.0 - button_size * 2.0),
        58
    )
    responsive_message_label.add_theme_font_size_override(
        "font_size", 16 if is_portrait else 20
    )

    # مجموعة الاتجاهات مثبتة أسفل يمين الشاشة.
    # مواضعها محسوبة من الركن، لذلك تبقى صحيحة في الوضعين.
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
        button.add_theme_font_size_override(
            "font_size", int(button_size * 0.38)
        )


func follow_camera(delta: float) -> void:
    if not is_instance_valid(player) or not is_instance_valid(camera):
        return

    var view_size := get_viewport().get_visible_rect().size
    var is_portrait := view_size.y > view_size.x

    var camera_offset := Vector3(0, 8.4, 11.0) if is_portrait else Vector3(0, 6.8, 8.5)
    camera.fov = 74.0 if is_portrait else 62.0

    var target_position := player.global_position + camera_offset
    var weight := 1.0 - exp(-CAMERA_SMOOTHING * delta)
    camera.global_position = camera.global_position.lerp(target_position, weight)
    camera.look_at(
        player.global_position + Vector3(0, 1.0, 0),
        Vector3.UP
    )


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
