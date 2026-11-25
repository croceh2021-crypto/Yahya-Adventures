
extends "res://Scripts/touch_input_fix.gd"

# ============================================================
# YAHYA ADVENTURES - EXPANSION SYSTEM
# Godot 4.4.1
# Phase 1: Combat, XP, Health, Enemies, Zones, Saving
# ============================================================

const EXP_SAVE_PATH := "user://yahya_expansion.cfg"

const EXP_MAX_HEALTH := 100.0
const EXP_ATTACK_RANGE := 3.4
const EXP_ATTACK_DAMAGE := 35.0
const EXP_ATTACK_COOLDOWN := 0.55
const EXP_HEAL_COST := 3
const EXP_HEAL_AMOUNT := 35.0

var exp_health := EXP_MAX_HEALTH
var exp_level := 1
var exp_xp := 0
var exp_gems := 0
var exp_kills := 0

var exp_attack_timer := 0.0
var exp_spawned := false
var exp_enemy_list: Array = []
var exp_discovered_zones: Array[String] = []

var exp_hud_layer: CanvasLayer
var exp_hud_root: Control
var exp_health_label: Label
var exp_level_label: Label
var exp_gem_label: Label
var exp_quest_label: Label
var exp_health_bar: ProgressBar
var exp_attack_button: Button
var exp_heal_button: Button

var exp_coin_record := 0
var exp_quest_reward_claimed := false


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
    super._ready()

    _exp_load_progress()
    _exp_create_hud()

    call_deferred("_exp_update_hud")


func _process(delta: float) -> void:
    super._process(delta)

    if is_game_paused or level_complete:
        return

    exp_attack_timer = maxf(
        0.0,
        exp_attack_timer - delta
    )

    _exp_track_coin_progress()
    _exp_discover_zone()

    if garden_active:
        if not exp_spawned:
            _exp_spawn_initial_enemies()

        _exp_update_enemies(delta)

    _exp_update_hud()


func _notification(what: int) -> void:
    super._notification(what)

    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _exp_save_progress()

    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        _exp_save_progress()


# ============================================================
# USER INTERFACE
# ============================================================

func _exp_create_hud() -> void:
    exp_hud_layer = CanvasLayer.new()
    exp_hud_layer.name = "AdventureExpansionHUD"
    exp_hud_layer.layer = 130
    exp_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(exp_hud_layer)

    exp_hud_root = Control.new()
    exp_hud_root.name = "ExpansionHUDRoot"
    exp_hud_root.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    exp_hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
    exp_hud_root.process_mode = Node.PROCESS_MODE_ALWAYS
    exp_hud_layer.add_child(exp_hud_root)

    exp_health_label = _exp_make_label(
        "الصحة: 100 / 100",
        17,
        Color(1.0, 0.55, 0.48)
    )
    exp_hud_root.add_child(exp_health_label)

    exp_health_bar = ProgressBar.new()
    exp_health_bar.min_value = 0
    exp_health_bar.max_value = EXP_MAX_HEALTH
    exp_health_bar.value = EXP_MAX_HEALTH
    exp_health_bar.show_percentage = false
    exp_health_bar.custom_minimum_size = Vector2(145, 15)
    exp_hud_root.add_child(exp_health_bar)

    exp_level_label = _exp_make_label(
        "المستوى: 1 | الخبرة: 0 / 100",
        16,
        Color(1.0, 0.85, 0.30)
    )
    exp_hud_root.add_child(exp_level_label)

    exp_gem_label = _exp_make_label(
        "الجواهر: 0",
        16,
        Color(0.40, 0.85, 1.0)
    )
    exp_hud_root.add_child(exp_gem_label)

    exp_quest_label = _exp_make_label(
        "المهمة: اهزم 3 أعداء",
        15,
        Color(0.75, 1.0, 0.72)
    )
    exp_hud_root.add_child(exp_quest_label)

    exp_attack_button = _exp_make_button("هجوم", 20)
    exp_attack_button.pressed.connect(_exp_attack)
    exp_hud_root.add_child(exp_attack_button)

    exp_heal_button = _exp_make_button("علاج", 18)
    exp_heal_button.pressed.connect(_exp_heal)
    exp_hud_root.add_child(exp_heal_button)

    exp_hud_root.resized.connect(_exp_layout_hud)
    get_viewport().size_changed.connect(_exp_layout_hud)

    call_deferred("_exp_layout_hud")


func _exp_make_label(
    value: String,
    font_size: int,
    color: Color
) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override(
        "font_size", font_size
    )
    label.add_theme_color_override(
        "font_color", color
    )
    label.add_theme_color_override(
        "font_shadow_color", Color.BLACK
    )
    label.add_theme_constant_override(
        "shadow_offset_x", 2
    )
    label.add_theme_constant_override(
        "shadow_offset_y", 2
    )
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _exp_make_button(
    caption: String,
    font_size: int
) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(88, 55)
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP

    button.add_theme_font_size_override(
        "font_size", font_size
    )

    button.add_theme_color_override(
        "font_color", Color.WHITE
    )

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.035, 0.12, 0.22, 0.96)
    normal.border_color = Color(0.30, 0.78, 1.0)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(14)

    var pressed := StyleBoxFlat.new()
    pressed.bg_color = Color(0.30, 0.20, 0.06, 1.0)
    pressed.border_color = Color(1.0, 0.82, 0.25)
    pressed.set_border_width_all(3)
    pressed.set_corner_radius_all(14)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)

    return button


func _exp_layout_hud() -> void:
    if not is_instance_valid(exp_hud_root):
        return

    var size := get_viewport().get_visible_rect().size

    exp_health_label.position = Vector2(15, 185)
    exp_health_bar.position = Vector2(15, 210)

    exp_level_label.position = Vector2(15, 232)
    exp_gem_label.position = Vector2(15, 258)
    exp_quest_label.position = Vector2(15, 284)

    exp_attack_button.position = Vector2(
        size.x - 110,
        size.y - 205
    )

    exp_heal_button.position = Vector2(
        size.x - 110,
        size.y - 140
    )


func _exp_update_hud() -> void:
    if not is_instance_valid(exp_hud_root):
        return

    exp_health = clampf(
        exp_health,
        0.0,
        EXP_MAX_HEALTH
    )

    exp_health_bar.value = exp_health

    exp_health_label.text = (
        "الصحة: %d / %d"
        % [int(exp_health), int(EXP_MAX_HEALTH)]
    )

    exp_level_label.text = (
        "المستوى: %d | الخبرة: %d / %d"
        % [exp_level, exp_xp, _exp_xp_required()]
    )

    exp_gem_label.text = (
        "الجواهر: %d | الأعداء: %d"
        % [exp_gems, exp_kills]
    )

    if exp_kills >= 3:
        exp_quest_label.text = "المهمة: اكتملت! مكافأتك جاهزة"
    else:
        exp_quest_label.text = (
            "المهمة: اهزم 3 أعداء (%d / 3)"
            % exp_kills
        )


# ============================================================
# ENEMY SYSTEM
# ============================================================

func _exp_spawn_initial_enemies() -> void:
    if not garden_active:
        return

    exp_spawned = true

    # Nine encounters: three wild dogs, three fire dragons and
    # three forest monsters, distributed through the garden.
    var positions := [
        Vector3(-12, 0, -28),
        Vector3(12, 0, -36),
        Vector3(-20, 0, -53),
        Vector3(19, 0, -68),
        Vector3(-8, 0, -82),
        Vector3(8, 0, -47),
        Vector3(-25, 0, -75),
        Vector3(24, 0, -90),
        Vector3(0, 0, -95)
    ]

    for i in range(positions.size()):
        var enemy_type := i % 3
        _exp_create_enemy(positions[i], enemy_type)


func _exp_create_enemy(
    position: Vector3,
    enemy_type: int
) -> void:
    var enemy := Node3D.new()
    enemy.name = "AdventureEnemy"
    enemy.position = position

    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.42
    body_mesh.height = 1.45

    var body := MeshInstance3D.new()
    body.name = "EnemyBody"
    body.mesh = body_mesh
    body.position.y = 0.85

    var material := StandardMaterial3D.new()

    var enemy_health := 60.0
    var enemy_speed := 1.45
    var enemy_damage := 8.0
    var reward := 25

    match enemy_type:
        0:
            material.albedo_color = Color(0.75, 0.18, 0.16)
            enemy_health = 60.0
            enemy_speed = 1.45
            enemy_damage = 8.0
            reward = 25

        1:
            material.albedo_color = Color(0.55, 0.20, 0.78)
            enemy_health = 90.0
            enemy_speed = 1.0
            enemy_damage = 13.0
            reward = 40

        2:
            material.albedo_color = Color(0.90, 0.48, 0.10)
            enemy_health = 45.0
            enemy_speed = 2.0
            enemy_damage = 7.0
            reward = 35

    material.roughness = 0.65
    body.material_override = material
    enemy.add_child(body)

    var eye_mesh := SphereMesh.new()
    eye_mesh.radius = 0.07
    eye_mesh.height = 0.14

    for eye_x in [-0.15, 0.15]:
        var eye := MeshInstance3D.new()
        eye.mesh = eye_mesh
        eye.position = Vector3(eye_x, 1.05, -0.34)

        var eye_material := StandardMaterial3D.new()
        eye_material.albedo_color = Color.WHITE
        eye.material_override = eye_material

        enemy.add_child(eye)

    add_child(enemy)

    exp_enemy_list.append({
        "node": enemy,
        "health": enemy_health,
        "speed": enemy_speed,
        "damage": enemy_damage,
        "reward": reward,
        "attack_timer": 0.0,
        "type": enemy_type
    })


func _exp_update_enemies(delta: float) -> void:
    if not is_instance_valid(player):
        return

    for i in range(exp_enemy_list.size() - 1, -1, -1):
        var data: Dictionary = exp_enemy_list[i]
        var enemy := data["node"] as Node3D

        if not is_instance_valid(enemy):
            exp_enemy_list.remove_at(i)
            continue

        var distance := enemy.global_position.distance_to(
            player.global_position
        )

        if distance > 22.0:
            continue

        if distance > 1.45:
            var direction := (
                player.global_position - enemy.global_position
            )
            direction.y = 0.0
            direction = direction.normalized()

            enemy.position += (
                direction * float(data["speed"]) * delta
            )

            if direction.length() > 0.01:
                enemy.rotation.y = atan2(
                    direction.x,
                    direction.z
                )

        else:
            data["attack_timer"] = (
                float(data["attack_timer"]) - delta
            )

            if float(data["attack_timer"]) <= 0.0:
                _exp_damage_player(float(data["damage"]))
                data["attack_timer"] = 1.35

        exp_enemy_list[i] = data


func _exp_attack() -> void:
    if is_game_paused or not garden_active:
        show_message("الهجوم متاح داخل الحديقة")
        return

    if exp_attack_timer > 0.0:
        return

    exp_attack_timer = EXP_ATTACK_COOLDOWN

    var nearest_index := -1
    var nearest_distance := EXP_ATTACK_RANGE + 0.1

    for i in range(exp_enemy_list.size()):
        var data: Dictionary = exp_enemy_list[i]
        var enemy := data["node"] as Node3D

        if not is_instance_valid(enemy):
            continue

        var distance := player.global_position.distance_to(
            enemy.global_position
        )

        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = i

    if nearest_index < 0:
        show_message("لا يوجد عدو قريب!")
        return

    var target: Dictionary = exp_enemy_list[nearest_index]
    target["health"] = (
        float(target["health"]) - EXP_ATTACK_DAMAGE
    )

    exp_enemy_list[nearest_index] = target

    _play_sfx("coin")

    if float(target["health"]) <= 0.0:
        _exp_defeat_enemy(nearest_index)


func _exp_defeat_enemy(index: int) -> void:
    if index < 0 or index >= exp_enemy_list.size():
        return

    var data: Dictionary = exp_enemy_list[index]
    var enemy := data["node"] as Node3D

    if is_instance_valid(enemy):
        _spawn_coin_burst(
            enemy.global_position + Vector3(0, 1.0, 0)
        )
        enemy.queue_free()

    exp_enemy_list.remove_at(index)

    exp_kills += 1
    exp_gems += 1

    _exp_add_xp(int(data["reward"]))

    show_message("أحسنت! هزمت عدواً وحصلت على جوهرة")

    if exp_kills >= 3 and not exp_quest_reward_claimed:
        exp_quest_reward_claimed = true
        exp_gems += 5
        _exp_add_xp(100)
        show_message("اكتملت مهمة الأعداء! حصلت على 5 جواهر")


# ============================================================
# PLAYER HEALTH AND HEALING
# ============================================================

func _exp_damage_player(amount: float) -> void:
    exp_health = maxf(
        0.0,
        exp_health - amount
    )

    _exp_update_hud()

    if exp_health <= 0.0:
        _exp_player_defeated()


func _exp_player_defeated() -> void:
    exp_health = EXP_MAX_HEALTH

    if is_instance_valid(player):
        player.position = Vector3(3.5, 0.0, -10.0)

    move_velocity = Vector2.ZERO
    move_vector = Vector2.ZERO

    _release_all_controls()

    show_message("سقط البطل! عاد إلى نقطة البداية")

    _exp_save_progress()


func _exp_heal() -> void:
    if exp_health >= EXP_MAX_HEALTH:
        show_message("صحتك مكتملة بالفعل")
        return

    if exp_gems < EXP_HEAL_COST:
        show_message("تحتاج إلى 3 جواهر للعلاج")
        return

    exp_gems -= EXP_HEAL_COST

    exp_health = minf(
        EXP_MAX_HEALTH,
        exp_health + EXP_HEAL_AMOUNT
    )

    _play_sfx("unlock")
    show_message("تم العلاج واستعادة الصحة")

    _exp_save_progress()
    _exp_update_hud()


# ============================================================
# EXPERIENCE AND LEVELS
# ============================================================

func _exp_xp_required() -> int:
    return 100 + ((exp_level - 1) * 50)


func _exp_add_xp(amount: int) -> void:
    if amount <= 0:
        return

    exp_xp += amount

    while exp_xp >= _exp_xp_required():
        exp_xp -= _exp_xp_required()
        exp_level += 1

        exp_health = EXP_MAX_HEALTH

        show_message(
            "مستوى جديد! وصلت إلى المستوى %d"
            % exp_level
        )

        _play_sfx("unlock")

    _exp_save_progress()
    _exp_update_hud()


func _exp_track_coin_progress() -> void:
    if coin_count > exp_coin_record:
        var difference := coin_count - exp_coin_record
        exp_coin_record = coin_count

        _exp_add_xp(difference * 10)


# ============================================================
# WORLD DISCOVERY
# ============================================================

func _exp_discover_zone() -> void:
    if not garden_active or not is_instance_valid(player):
        return

    var x_zone := int(floor(player.position.x / 12.0))
    var z_zone := int(floor(player.position.z / 18.0))

    var zone_id := "zone_%d_%d" % [x_zone, z_zone]

    if exp_discovered_zones.has(zone_id):
        return

    exp_discovered_zones.append(zone_id)

    _exp_add_xp(10)

    show_message("منطقة جديدة اكتُشفت! +10 خبرة")


# ============================================================
# SAVE AND LOAD
# ============================================================

func _exp_save_progress() -> void:
    var config := ConfigFile.new()

    config.set_value("player", "health", exp_health)
    config.set_value("player", "level", exp_level)
    config.set_value("player", "xp", exp_xp)
    config.set_value("player", "gems", exp_gems)
    config.set_value("player", "kills", exp_kills)

    config.set_value(
        "player",
        "coin_record",
        exp_coin_record
    )

    config.set_value(
        "player",
        "quest_reward_claimed",
        exp_quest_reward_claimed
    )

    config.set_value(
        "world",
        "discovered_zones",
        exp_discovered_zones
    )

    var error := config.save(EXP_SAVE_PATH)

    if error != OK:
        push_warning(
            "Could not save expansion progress: %s"
            % error
        )


func _exp_load_progress() -> void:
    var config := ConfigFile.new()

    var error := config.load(EXP_SAVE_PATH)

    if error != OK:
        return

    exp_health = float(
        config.get_value(
            "player", "health", EXP_MAX_HEALTH
        )
    )

    exp_level = int(
        config.get_value("player", "level", 1)
    )

    exp_xp = int(
        config.get_value("player", "xp", 0)
    )

    exp_gems = int(
        config.get_value("player", "gems", 0)
    )

    exp_kills = int(
        config.get_value("player", "kills", 0)
    )

    exp_coin_record = int(
        config.get_value("player", "coin_record", 0)
    )

    exp_quest_reward_claimed = bool(
        config.get_value(
            "player",
            "quest_reward_claimed",
            false
        )
    )

    var saved_zones = config.get_value(
        "world",
        "discovered_zones",
        []
    )

    exp_discovered_zones.clear()

    for zone in saved_zones:
        exp_discovered_zones.append(str(zone))

    exp_health = clampf(
        exp_health,
        0.0,
        EXP_MAX_HEALTH
    )

    exp_level = maxi(1, exp_level)
    exp_xp = maxi(0, exp_xp)
    exp_gems = maxi(0, exp_gems)
