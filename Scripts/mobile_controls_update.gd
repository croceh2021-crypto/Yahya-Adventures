extends "res://Scripts/realism_100_update.gd"

# YAHYA ADVENTURES - MOBILE CONTROL LAYOUT UPDATE
# Godot 4.4.1
# Keeps the complete existing gameplay inheritance chain and improves
# combat HUD placement on narrow portrait and landscape phone screens.

func _exp_layout_hud() -> void:
    # Preserve the inherited combat HUD setup, then refine it for compact
    # screens. This hook is defined by combat_controls_fix.gd.
    super._exp_layout_hud()
    _mobile_layout_combat_hud()


func _mobile_layout_combat_hud() -> void:
    if not is_instance_valid(responsive_root):
        return

    var view_size := get_viewport().get_visible_rect().size
    if view_size.x < 1.0 or view_size.y < 1.0:
        return

    var portrait := view_size.y > view_size.x
    var margin := 14.0
    var button_width := clampf(view_size.x * 0.22, 76.0, 100.0)
    var button_height := clampf(view_size.y * 0.075, 48.0, 62.0)

    # Reserve a separate left column for status text so it does not
    # collide with the attack/heal buttons on narrow portrait screens.
    var status_width := maxf(
        128.0,
        view_size.x - button_width - (margin * 3.0) - 12.0
    )
    status_width = minf(status_width, 250.0)

    if is_instance_valid(exp_health_label):
        exp_health_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_health_label.position = Vector2(margin, 184.0)
        exp_health_label.size = Vector2(status_width, 24.0)
        exp_health_label.add_theme_font_size_override(
            "font_size", 13 if portrait else 15
        )

    if is_instance_valid(exp_health_bar):
        exp_health_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_health_bar.position = Vector2(margin, 210.0)
        exp_health_bar.size = Vector2(minf(status_width, 155.0), 16.0)

    if is_instance_valid(exp_level_label):
        exp_level_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_level_label.position = Vector2(margin, 233.0)
        exp_level_label.size = Vector2(status_width, 24.0)
        exp_level_label.add_theme_font_size_override(
            "font_size", 13 if portrait else 15
        )

    if is_instance_valid(exp_gem_label):
        exp_gem_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_gem_label.position = Vector2(margin, 259.0)
        exp_gem_label.size = Vector2(status_width, 24.0)
        exp_gem_label.add_theme_font_size_override(
            "font_size", 13 if portrait else 15
        )

    if is_instance_valid(exp_quest_label):
        exp_quest_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_quest_label.position = Vector2(margin, 285.0)
        exp_quest_label.size = Vector2(status_width, 38.0)
        exp_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        exp_quest_label.add_theme_font_size_override(
            "font_size", 12 if portrait else 14
        )

    var action_x := view_size.x - button_width - margin
    var attack_y := 184.0 if portrait else 176.0
    var heal_y := attack_y + button_height + 10.0

    if is_instance_valid(exp_attack_button):
        exp_attack_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_attack_button.size = Vector2(button_width, button_height)
        exp_attack_button.position = Vector2(action_x, attack_y)
        exp_attack_button.z_index = 10
        exp_attack_button.show()

    if is_instance_valid(exp_heal_button):
        exp_heal_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_heal_button.size = Vector2(button_width, button_height)
        exp_heal_button.position = Vector2(action_x, heal_y)
        exp_heal_button.z_index = 10
        exp_heal_button.show()
