
extends "res://Scripts/combat_controls_fix.gd"

# ============================================================
# YAHYA ADVENTURES - ADVANCED UPDATE
# Godot 4.4.1
# إضافة تحسينات القتال والواجهة والمؤثرات والحفظ
# يحافظ على الأنظمة السابقة ولا يستبدلها
# ============================================================

const ADV_SAVE_INTERVAL := 20.0
const ADV_DAMAGE_PROTECTION := 0.85
const ADV_COMBO_TIMEOUT := 5.0
const ADV_FLOAT_TEXT_LIFE := 1.0
const ADV_EFFECT_LIFE := 0.42

var adv_save_timer := 0.0
var adv_protection_timer := 0.0
var adv_combo_timer := 0.0
var adv_combo_count := 0

var adv_xp_bar: ProgressBar
var adv_combo_label: Label
var adv_warning_label: Label

var adv_floating_texts: Array[Dictionary] = []
var adv_effects: Array[Dictionary] = []

var adv_total_play_time := 0.0
var adv_damage_received := 0.0
var adv_damage_dealt := 0.0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
    super._ready()

    call_deferred("_adv_create_interface")
    call_deferred("_adv_prepare_existing_enemies")

    print("Yahya Adventures: Advanced Update enabled.")


func _process(delta: float) -> void:
    super._process(delta)

    adv_total_play_time += delta

    adv_save_timer += delta
    adv_protection_timer = maxf(
        0.0,
        adv_protection_timer - delta
    )

    adv_combo_timer = maxf(
        0.0,
        adv_combo_timer - delta
    )

    if adv_combo_timer <= 0.0:
        adv_combo_count = 0

    if adv_save_timer >= ADV_SAVE_INTERVAL:
        adv_save_timer = 0.0
        _adv_save_game()

    _adv_update_enemy_bars()
    _adv_update_floating_texts(delta)
    _adv_update_effects(delta)
    _adv_update_warning()


# ============================================================
# ADVANCED INTERFACE
# ============================================================

func _adv_create_interface() -> void:
    if not is_instance_valid(exp_hud_root):
        return

    if is_instance_valid(adv_xp_bar):
        return

    adv_xp_bar = ProgressBar.new()
    adv_xp_bar.name = "AdvancedXPBar"
    adv_xp_bar.min_value = 0
    adv_xp_bar.max_value = 100
    adv_xp_bar.value = 0
    adv_xp_bar.show_percentage = false
    adv_xp_bar.custom_minimum_size = Vector2(190, 12)

    var xp_background := StyleBoxFlat.new()
    xp_background.bg_color = Color(0.04, 0.07, 0.12, 0.90)
    xp_background.set_corner_radius_all(6)

    var xp_fill := StyleBoxFlat.new()
    xp_fill.bg_color = Color(0.15, 0.68, 1.0, 1.0)
    xp_fill.set_corner_radius_all(6)

    adv_xp_bar.add_theme_stylebox_override(
        "background",
        xp_background
    )

    adv_xp_bar.add_theme_stylebox_override(
        "fill",
        xp_fill
    )

    exp_hud_root.add_child(adv_xp_bar)

    adv_combo_label = Label.new()
    adv_combo_label.name = "AdvancedComboLabel"
    adv_combo_label.text = ""
    adv_combo_label.add_theme_font_size_override(
        "font_size",
        23
    )
    adv_combo_label.add_theme_color_override(
        "font_color",
        Color(1.0, 0.78, 0.20)
    )
    adv_combo_label.add_theme_color_override(
        "font_shadow_color",
        Color.BLACK
    )
    adv_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    exp_hud_root.add_child(adv_combo_label)

    adv_warning_label = Label.new()
    adv_warning_label.name = "AdvancedHealthWarning"
    adv_warning_label.text = "تحذير: صحتك منخفضة!"
    adv_warning_label.add_theme_font_size_override(
        "font_size",
        21
    )
    adv_warning_label.add_theme_color_override(
        "font_color",
        Color(1.0, 0.20, 0.16)
    )
    adv_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    adv_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    adv_warning_label.visible = false
    exp_hud_root.add_child(adv_warning_label)

    _adv_layout_interface()


func _adv_layout_interface() -> void:
    if not is_instance_valid(exp_hud_root):
        return

    var size := get_viewport().get_visible_rect().size

    if is_instance_valid(adv_xp_bar):
        adv_xp_bar.position = Vector2(15, 312)
        adv_xp_bar.size = Vector2(
            clampf(size.x * 0.30, 170, 250),
            12
        )

    if is_instance_valid(adv_combo_label):
        adv_combo_label.position = Vector2(
            size.x * 0.42,
            115
        )
        adv_combo_label.size = Vector2(250, 40)

    if is_instance_valid(adv_warning_label):
        adv_warning_label.position = Vector2(
            size.x * 0.30,
            65
        )
        adv_warning_label.size = Vector2(
            size.x * 0.40,
            35
        )


func _exp_create_hud() -> void:
    super._exp_create_hud()

    call_deferred("_adv_create_interface")


func _exp_layout_hud() -> void:
    super._exp_layout_hud()
    _adv_layout_interface()


func _exp_update_hud() -> void:
    super._exp_update_hud()

    if is_instance_valid(adv_xp_bar):
        adv_xp_bar.max_value = maxf(
            1.0,
            float(_exp_xp_required())
        )
        adv_xp_bar.value = exp_xp

    if is_instance_valid(adv_combo_label):
        if adv_combo_count >= 2:
            adv_combo_label.text = (
                "سلسلة ضربات × %d" % adv_combo_count
            )
        else:
            adv_combo_label.text = ""


# ============================================================
# ENEMY HEALTH BARS
# ============================================================

func _exp_create_enemy(
    position: Vector3,
    enemy_type: int
) -> void:

    super._exp_create_enemy(position, enemy_type)

    if exp_enemy_list.is_empty():
        return

    var data: Dictionary = exp_enemy_list.back()
    var enemy := data.get("node") as Node3D

    if is_instance_valid(enemy):
        _adv_add_enemy_health_bar(enemy)


func _adv_prepare_existing_enemies() -> void:
    for data in exp_enemy_list:
        var enemy := data.get("node") as Node3D

        if is_instance_valid(enemy):
            _adv_add_enemy_health_bar(enemy)


func _adv_add_enemy_health_bar(enemy: Node3D) -> void:
    if enemy.has_node("AdvancedEnemyHealthBar"):
        return

    var holder := Node3D.new()
    holder.name = "AdvancedEnemyHealthBar"
    holder.position = Vector3(0, 2.15, 0)
    enemy.add_child(holder)

    var background := MeshInstance3D.new()
    background.name = "HealthBackground"

    var background_mesh := BoxMesh.new()
    background_mesh.size = Vector3(0.95, 0.105, 0.035)
    background.mesh = background_mesh

    var background_material := StandardMaterial3D.new()
    background_material.albedo_color = Color(0.10, 0.04, 0.04)
    background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    background.material_override = background_material

    holder.add_child(background)

    var fill := MeshInstance3D.new()
    fill.name = "HealthFill"

    var fill_mesh := BoxMesh.new()
    fill_mesh.size = Vector3(0.91, 0.075, 0.045)
    fill.mesh = fill_mesh

    var fill_material := StandardMaterial3D.new()
    fill_material.albedo_color = Color(0.12, 0.92, 0.24)
    fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fill.material_override = fill_material

    fill.position.z = -0.025
    holder.add_child(fill)

    var title := Label3D.new()
    title.name = "EnemyHealthText"
    title.text = "عدو"
    title.font_size = 28
    title.pixel_size = 0.004
    title.position = Vector3(0, 0.23, 0)
    title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    title.no_depth_test = true
    title.outline_size = 5
    title.modulate = Color.WHITE
    holder.add_child(title)


func _adv_update_enemy_bars() -> void:
    for data in exp_enemy_list:
        var enemy := data.get("node") as Node3D

        if not is_instance_valid(enemy):
            continue

        var holder := enemy.get_node_or_null(
            "AdvancedEnemyHealthBar"
        ) as Node3D

        if not is_instance_valid(holder):
            _adv_add_enemy_health_bar(enemy)
            continue

        var fill := holder.get_node_or_null(
            "HealthFill"
        ) as MeshInstance3D

        var title := holder.get_node_or_null(
            "EnemyHealthText"
        ) as Label3D

        var current_health := float(data.get("health", 0.0))
        var maximum_health := 60.0

        match int(data.get("type", 0)):
            1:
                maximum_health = 100.0
            2:
                maximum_health = 125.0

        var ratio := clampf(
            current_health / maximum_health,
            0.0,
            1.0
        )

        if is_instance_valid(fill):
            fill.scale.x = maxf(0.01, ratio)
            fill.position.x = -0.455 * (1.0 - ratio)

            var material := fill.material_override as StandardMaterial3D

            if material != null:
                if ratio > 0.60:
                    material.albedo_color = Color(0.12, 0.92, 0.24)
                elif ratio > 0.30:
                    material.albedo_color = Color(1.0, 0.72, 0.12)
                else:
                    material.albedo_color = Color(1.0, 0.16, 0.12)

        if is_instance_valid(title):
            title.text = "%d%%" % int(ratio * 100.0)


# ============================================================
# FLOATING TEXT EFFECTS
# ============================================================

func _adv_spawn_floating_text(
    world_position: Vector3,
    message: String,
    color: Color
) -> void:

    var label := Label3D.new()
    label.name = "AdvancedFloatingText"
    label.text = message
    label.font_size = 42
    label.pixel_size = 0.005
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.outline_size = 7
    label.modulate = color
    label.position = world_position

    add_child(label)

    adv_floating_texts.append({
        "node": label,
        "life": ADV_FLOAT_TEXT_LIFE,
        "velocity": Vector3(0, 1.15, 0)
    })


func _adv_update_floating_texts(delta: float) -> void:
    for i in range(adv_floating_texts.size() - 1, -1, -1):
        var item: Dictionary = adv_floating_texts[i]
        var label := item.get("node") as Label3D

        if not is_instance_valid(label):
            adv_floating_texts.remove_at(i)
            continue

        var life := float(item.get("life", 0.0))
        life -= delta

        label.position += (
            item.get("velocity", Vector3.ZERO) * delta
        )

        label.modulate.a = clampf(
            life / ADV_FLOAT_TEXT_LIFE,
            0.0,
            1.0
        )

        item["life"] = life
        adv_floating_texts[i] = item

        if life <= 0.0:
            label.queue_free()
            adv_floating_texts.remove_at(i)


# ============================================================
# ATTACK EFFECTS
# ============================================================

func _adv_spawn_attack_effect() -> void:
    if not is_instance_valid(player):
        return

    var effect := MeshInstance3D.new()
    effect.name = "AdvancedAttackEffect"

    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.55
    mesh.outer_radius = 0.68
    mesh.rings = 12
    mesh.ring_segments = 16

    effect.mesh = mesh
    effect.position = Vector3(0, 1.0, -1.0)
    effect.rotation.x = deg_to_rad(90.0)
    effect.scale = Vector3(0.35, 0.35, 0.35)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.25, 0.82, 1.0, 0.85)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = Color(0.10, 0.45, 1.0)

    effect.material_override = material
    player.add_child(effect)

    adv_effects.append({
        "node": effect,
        "life": ADV_EFFECT_LIFE,
        "kind": "attack"
    })


func _adv_update_effects(delta: float) -> void:
    for i in range(adv_effects.size() - 1, -1, -1):
        var item: Dictionary = adv_effects[i]
        var effect := item.get("node") as Node3D

        if not is_instance_valid(effect):
            adv_effects.remove_at(i)
            continue

        var life := float(item.get("life", 0.0))
        life -= delta

        if item.get("kind", "") == "attack":
            var progress := 1.0 - (
                life / ADV_EFFECT_LIFE
            )

            var size := 0.35 + progress * 1.15
            effect.scale = Vector3.ONE * size

            var material := effect.material_override as StandardMaterial3D

            if material != null:
                material.albedo_color.a = clampf(
                    life / ADV_EFFECT_LIFE,
                    0.0,
                    1.0
                )

        item["life"] = life
        adv_effects[i] = item

        if life <= 0.0:
            effect.queue_free()
            adv_effects.remove_at(i)


func _exp_attack() -> void:
    if is_game_paused or not garden_active:
        super._exp_attack()
        return

    if exp_attack_timer > 0.0:
        return

    var nearest_enemy: Node3D
    var nearest_distance := EXP_ATTACK_RANGE + 0.1

    for data in exp_enemy_list:
        var enemy := data.get("node") as Node3D

        if not is_instance_valid(enemy):
            continue

        var distance := player.global_position.distance_to(
            enemy.global_position
        )

        if distance < nearest_distance:
            nearest_distance = distance
            nearest_enemy = enemy

    var old_health := -1.0

    if is_instance_valid(nearest_enemy):
        for data in exp_enemy_list:
            if data.get("node") == nearest_enemy:
                old_health = float(data.get("health", 0.0))
                break

    super._exp_attack()

    _adv_spawn_attack_effect()

    if is_instance_valid(nearest_enemy):
        var new_health := -1.0

        for data in exp_enemy_list:
            if data.get("node") == nearest_enemy:
                new_health = float(data.get("health", 0.0))
                break

        if old_health >= 0.0 and new_health >= 0.0:
            var damage := old_health - new_health

            if damage > 0.0:
                adv_damage_dealt += damage
                _adv_spawn_floating_text(
                    nearest_enemy.global_position + Vector3(0, 2.5, 0),
                    "-%d" % int(damage),
                    Color(1.0, 0.28, 0.18)
                )


# ============================================================
# COMBO SYSTEM
# ============================================================

func _exp_defeat_enemy(index: int) -> void:
    super._exp_defeat_enemy(index)

    adv_combo_count += 1
    adv_combo_timer = ADV_COMBO_TIMEOUT

    if adv_combo_count >= 2:
        _adv_spawn_floating_text(
            player.global_position + Vector3(0, 2.8, 0),
            "COMBO x%d" % adv_combo_count,
            Color(1.0, 0.82, 0.20)
        )

    if adv_combo_count >= 5:
        _exp_add_xp(20)
        show_message("سلسلة رائعة! مكافأة 20 خبرة")


# ============================================================
# PLAYER DAMAGE PROTECTION
# ============================================================

func _exp_damage_player(amount: float) -> void:
    if adv_protection_timer > 0.0:
        return

    var previous_health := exp_health

    super._exp_damage_player(amount)

    if exp_health < previous_health:
        adv_protection_timer = ADV_DAMAGE_PROTECTION
        adv_damage_received += previous_health - exp_health

        _adv_spawn_floating_text(
            player.global_position + Vector3(0, 2.4, 0),
            "-%d" % int(previous_health - exp_health),
            Color(1.0, 0.20, 0.16)
        )


# ============================================================
# HEALING EFFECT
# ============================================================

func _exp_heal() -> void:
    var old_health := exp_health

    super._exp_heal()

    if exp_health > old_health:
        var restored := exp_health - old_health

        _adv_spawn_floating_text(
            player.global_position + Vector3(0, 2.5, 0),
            "+%d" % int(restored),
            Color(0.25, 1.0, 0.42)
        )


# ============================================================
# LOW HEALTH WARNING
# ============================================================

func _adv_update_warning() -> void:
    if not is_instance_valid(adv_warning_label):
        return

    var low_health := (
        exp_health > 0.0
        and exp_health <= 30.0
        and garden_active
    )

    adv_warning_label.visible = low_health

    if low_health:
        var pulse := 0.65 + absf(
            sin(float(Time.get_ticks_msec()) * 0.006)
        ) * 0.35

        adv_warning_label.modulate.a = pulse


# ============================================================
# AUTOMATIC SAVE
# ============================================================

func _adv_save_game() -> void:
    if not is_inside_tree():
        return

    _exp_save_progress()

    var config := ConfigFile.new()

    config.set_value(
        "statistics",
        "play_time",
        adv_total_play_time
    )

    config.set_value(
        "statistics",
        "damage_dealt",
        adv_damage_dealt
    )

    config.set_value(
        "statistics",
        "damage_received",
        adv_damage_received
    )

    config.set_value(
        "statistics",
        "combo",
        adv_combo_count
    )

    var error := config.save(
        "user://yahya_advanced_stats.cfg"
    )

    if error != OK:
        push_warning("Advanced statistics save failed.")


func _notification(what: int) -> void:
    super._notification(what)

    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _adv_save_game()

    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        _adv_save_game()
