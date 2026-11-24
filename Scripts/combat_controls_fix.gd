extends "res://Scripts/water_realism.gd"

# YAHYA ADVENTURES - COMBAT CONTROLS FIX
# Godot 4.4.1
# إصلاح أزرار الهجوم والعلاج وتوحيد طبقة اللمس


func _exp_create_hud() -> void:
    # إنشاء واجهة القتال الأصلية
    super._exp_create_hud()

    if not is_instance_valid(responsive_root):
        push_warning("Combat HUD: responsive_root is missing")
        return

    if not is_instance_valid(exp_hud_root):
        push_warning("Combat HUD: expansion root is missing")
        return

    # نقل عناصر الصحة والهجوم والعلاج إلى طبقة أزرار الحركة نفسها.
    # بذلك يستطيع نظام اللمس اكتشافها والاستجابة لها.
    var old_root := exp_hud_root

    for child in old_root.get_children():
        old_root.remove_child(child)
        responsive_root.add_child(child)

    exp_hud_root = responsive_root

    # لم نعد بحاجة إلى طبقة واجهة القتال المنفصلة.
    if is_instance_valid(exp_hud_layer):
        exp_hud_layer.queue_free()

    exp_hud_layer = null

    call_deferred("_exp_layout_hud")


func _exp_layout_hud() -> void:
    if not is_instance_valid(responsive_root):
        return

    var view_size := get_viewport().get_visible_rect().size

    if view_size.x < 1.0 or view_size.y < 1.0:
        return

    var margin := 16.0
    var button_width := clampf(view_size.x * 0.22, 82.0, 100.0)
    var button_height := clampf(view_size.y * 0.075, 52.0, 62.0)

    # معلومات الصحة في أعلى اليسار.
    if is_instance_valid(exp_health_label):
        exp_health_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_health_label.position = Vector2(margin, 184)
        exp_health_label.size = Vector2(190, 25)

    if is_instance_valid(exp_health_bar):
        exp_health_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_health_bar.position = Vector2(margin, 210)
        exp_health_bar.size = Vector2(155, 16)

    if is_instance_valid(exp_level_label):
        exp_level_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_level_label.position = Vector2(margin, 233)
        exp_level_label.size = Vector2(260, 25)

    if is_instance_valid(exp_gem_label):
        exp_gem_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_gem_label.position = Vector2(margin, 260)
        exp_gem_label.size = Vector2(270, 25)

    if is_instance_valid(exp_quest_label):
        exp_quest_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_quest_label.position = Vector2(margin, 287)
        exp_quest_label.size = Vector2(280, 28)

    # زر الهجوم في الجهة اليمنى العليا.
    # بعيد عن أزرار الحركة الموجودة أسفل اليمين.
    if is_instance_valid(exp_attack_button):
        exp_attack_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_attack_button.size = Vector2(button_width, button_height)
        exp_attack_button.position = Vector2(
            view_size.x - button_width - margin,
            176
        )
        exp_attack_button.z_index = 10

    # زر العلاج أسفل زر الهجوم.
    if is_instance_valid(exp_heal_button):
        exp_heal_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
        exp_heal_button.size = Vector2(button_width, button_height)
        exp_heal_button.position = Vector2(
            view_size.x - button_width - margin,
            242
        )
        exp_heal_button.z_index = 10

    # إبقاء الأزرار فوق عناصر المشهد.
    if is_instance_valid(exp_attack_button):
        exp_attack_button.show()

    if is_instance_valid(exp_heal_button):
        exp_heal_button.show()


func _exp_update_hud() -> void:
    super._exp_update_hud()

    # تحديث حالة زر العلاج بحسب الصحة والجواهر.
    if is_instance_valid(exp_heal_button):
        exp_heal_button.disabled = (
            exp_health >= EXP_MAX_HEALTH
            or exp_gems < EXP_HEAL_COST
        )

    # إظهار حالة الهجوم عند عدم توفر الأعداء أو المنطقة.
    if is_instance_valid(exp_attack_button):
        exp_attack_button.disabled = (
            is_game_paused
            or level_complete
            or not garden_active
            or exp_attack_timer > 0.0
        )
