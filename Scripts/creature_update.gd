extends "res://Scripts/advanced_50_update.gd"

# YAHYA ADVENTURES - CREATURES AND INTRO UPDATE
# Godot 4.4.1
# Adds wolves/dogs, dragons with fire breath, and the repository cover image.
# Existing gameplay systems remain inherited and unchanged.

const CREATURE_INTRO_IMAGE := "res://IMG_20261124_032029.jpg"

var creature_clock := 0.0
var creature_intro_layer: CanvasLayer
var creature_intro_root: Control


func _ready() -> void:
    # Queue the intro before parent scripts queue their heavy deferred
    # visual generation. This lets the first visible frame be our game
    # cover instead of leaving Android on the Godot splash screen.
    call_deferred("_creature_show_intro")
    super._ready()


func _process(delta: float) -> void:
    super._process(delta)
    creature_clock += delta
    _creature_animate_enemies()


# ------------------------------------------------------------
# INTRO SCREEN
# ------------------------------------------------------------

func _creature_show_intro() -> void:
    if not is_inside_tree():
        return

    is_game_paused = true
    get_tree().paused = true

    creature_intro_layer = CanvasLayer.new()
    creature_intro_layer.name = "CreatureIntroLayer"
    creature_intro_layer.layer = 240
    creature_intro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(creature_intro_layer)

    creature_intro_root = Control.new()
    creature_intro_root.name = "CreatureIntroRoot"
    creature_intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    creature_intro_root.process_mode = Node.PROCESS_MODE_ALWAYS
    creature_intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
    creature_intro_layer.add_child(creature_intro_root)

    var cover := TextureRect.new()
    cover.name = "RepositoryCoverImage"
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    cover.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if ResourceLoader.exists(CREATURE_INTRO_IMAGE):
        cover.texture = load(CREATURE_INTRO_IMAGE) as Texture2D
    else:
        push_warning("Intro cover image was not found: " + CREATURE_INTRO_IMAGE)

    creature_intro_root.add_child(cover)

    var shade := ColorRect.new()
    shade.name = "IntroShade"
    shade.color = Color(0.015, 0.025, 0.055, 0.62)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    creature_intro_root.add_child(shade)

    var center := CenterContainer.new()
    center.name = "IntroCenter"
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    creature_intro_root.add_child(center)

    var column := VBoxContainer.new()
    column.name = "IntroContent"
    column.custom_minimum_size = Vector2(290, 0)
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 14)
    center.add_child(column)

    var english_title := _creature_intro_label(
        "YAHYA ADVENTURES", 31, Color(1.0, 0.82, 0.22)
    )
    column.add_child(english_title)

    var arabic_title := _creature_intro_label(
        "مغامرات يحيى", 34, Color.WHITE
    )
    column.add_child(arabic_title)

    var subtitle := _creature_intro_label(
        "واجه الكلاب الوحشية والتنانين واجمع الكنوز!", 18,
        Color(0.91, 0.95, 1.0)
    )
    column.add_child(subtitle)

    var start_button := Button.new()
    start_button.name = "StartAdventureButton"
    start_button.text = "▶  ابدأ المغامرة"
    start_button.custom_minimum_size = Vector2(270, 62)
    start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    start_button.focus_mode = Control.FOCUS_NONE
    start_button.add_theme_font_size_override("font_size", 23)
    start_button.add_theme_color_override("font_color", Color.WHITE)

    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color(0.035, 0.24, 0.34, 0.96)
    button_style.border_color = Color(1.0, 0.78, 0.20)
    button_style.set_border_width_all(3)
    button_style.set_corner_radius_all(18)
    button_style.content_margin_left = 18
    button_style.content_margin_right = 18
    button_style.content_margin_top = 10
    button_style.content_margin_bottom = 10
    start_button.add_theme_stylebox_override("normal", button_style)
    start_button.add_theme_stylebox_override("hover", button_style)
    start_button.add_theme_stylebox_override("pressed", button_style)
    start_button.pressed.connect(_creature_start_adventure)
    column.add_child(start_button)

    var footer := _creature_intro_label(
        "استكشف العالم • قاتل الوحوش • كن البطل", 14,
        Color(0.86, 0.91, 1.0)
    )
    column.add_child(footer)


func _creature_intro_label(
    caption: String,
    font_size: int,
    color: Color
) -> Label:
    var label := Label.new()
    label.text = caption
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _creature_start_adventure() -> void:
    is_game_paused = false
    if is_instance_valid(creature_intro_layer):
        creature_intro_layer.queue_free()
    get_tree().paused = false
    show_message("انطلقت المغامرة يا يحيى! احذر من التنانين والكلاب الوحشية.")


# ------------------------------------------------------------
# ENEMY CREATION - DOGS AND DRAGONS
# ------------------------------------------------------------

func _exp_create_enemy(position: Vector3, enemy_type: int) -> void:
    super._exp_create_enemy(position, enemy_type)

    if exp_enemy_list.is_empty():
        return

    var data: Dictionary = exp_enemy_list.back()
    var enemy := data.get("node") as Node3D
    if not is_instance_valid(enemy):
        return

    # Keep the advanced health bar created by the parent update.
    for child in enemy.get_children():
        if child.name != "AdvancedEnemyHealthBar":
            child.queue_free()

    if enemy_type == 1:
        enemy.name = "FireDragon"
        _creature_build_dragon(enemy)
    else:
        enemy.name = "WildDog"
        _creature_build_dog(enemy, enemy_type == 2)


func _creature_material(color: Color, glow: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    if glow:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.4
    return material


func _creature_add_mesh(
    parent: Node3D,
    mesh: Mesh,
    node_name: String,
    local_position: Vector3,
    local_scale: Vector3,
    color: Color,
    glow: bool = false
) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = node_name
    part.mesh = mesh
    part.position = local_position
    part.scale = local_scale
    part.material_override = _creature_material(color, glow)
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(part)
    return part


func _creature_sphere(
    parent: Node3D,
    node_name: String,
    position: Vector3,
    scale: Vector3,
    color: Color
) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 12
    mesh.rings = 8
    return _creature_add_mesh(parent, mesh, node_name, position, scale, color)


func _creature_build_dog(enemy: Node3D, fast_variant: bool) -> void:
    var fur := Color(0.34, 0.19, 0.10) if not fast_variant else Color(0.48, 0.27, 0.12)
    var dark_fur := Color(0.16, 0.085, 0.055)
    var belly := Color(0.66, 0.43, 0.25)

    _creature_sphere(enemy, "DogBody", Vector3(0, 0.72, 0), Vector3(0.82, 0.68, 1.25), fur)
    _creature_sphere(enemy, "DogChest", Vector3(0, 0.82, 0.38), Vector3(0.70, 0.70, 0.62), belly)
    _creature_sphere(enemy, "DogHead", Vector3(0, 1.12, 0.62), Vector3(0.67, 0.63, 0.65), fur)
    _creature_sphere(enemy, "DogMuzzle", Vector3(0, 0.98, 0.99), Vector3(0.38, 0.28, 0.40), belly)
    _creature_sphere(enemy, "DogNose", Vector3(0, 1.04, 1.18), Vector3(0.17, 0.13, 0.12), Color(0.035, 0.025, 0.02))

    for side in [-1.0, 1.0]:
        var ear_mesh := CylinderMesh.new()
        ear_mesh.top_radius = 0.025
        ear_mesh.bottom_radius = 0.13
        ear_mesh.height = 0.36
        _creature_add_mesh(
            enemy, ear_mesh, "DogEar",
            Vector3(side * 0.23, 1.48, 0.50),
            Vector3.ONE, dark_fur
        )

        _creature_sphere(
            enemy, "DogEye",
            Vector3(side * 0.22, 1.22, 0.91),
            Vector3(0.11, 0.12, 0.07),
            Color(1.0, 0.78, 0.16)
        )

        var leg_mesh := CapsuleMesh.new()
        leg_mesh.radius = 0.105
        leg_mesh.height = 0.55
        _creature_add_mesh(
            enemy, leg_mesh, "DogLeg",
            Vector3(side * 0.25, 0.30, 0.38),
            Vector3.ONE, dark_fur
        )
        _creature_add_mesh(
            enemy, leg_mesh, "DogLeg",
            Vector3(side * 0.25, 0.30, -0.40),
            Vector3.ONE, dark_fur
        )

    var tail_mesh := CapsuleMesh.new()
    tail_mesh.radius = 0.10
    tail_mesh.height = 0.62
    var tail := _creature_add_mesh(
        enemy, tail_mesh, "DogTail",
        Vector3(0, 0.92, -0.73),
        Vector3(0.75, 0.75, 1.0), fur
    )
    tail.rotation.x = deg_to_rad(72.0)


func _creature_build_dragon(enemy: Node3D) -> void:
    var scales := Color(0.12, 0.34, 0.22)
    var belly := Color(0.72, 0.38, 0.12)
    var wing_color := Color(0.20, 0.075, 0.09)

    _creature_sphere(enemy, "DragonBody", Vector3(0, 0.83, 0), Vector3(1.02, 0.82, 1.30), scales)
    _creature_sphere(enemy, "DragonChest", Vector3(0, 0.94, 0.42), Vector3(0.78, 0.78, 0.68), belly)
    _creature_sphere(enemy, "DragonNeck", Vector3(0, 1.12, 0.58), Vector3(0.52, 0.66, 0.58), scales)
    _creature_sphere(enemy, "DragonHead", Vector3(0, 1.35, 0.86), Vector3(0.70, 0.58, 0.70), scales)
    _creature_sphere(enemy, "DragonSnout", Vector3(0, 1.20, 1.20), Vector3(0.45, 0.28, 0.42), belly)

    for side in [-1.0, 1.0]:
        _creature_sphere(
            enemy, "DragonEye",
            Vector3(side * 0.24, 1.43, 1.12),
            Vector3(0.10, 0.11, 0.07),
            Color(1.0, 0.16, 0.025)
        )

        var horn_mesh := CylinderMesh.new()
        horn_mesh.top_radius = 0.015
        horn_mesh.bottom_radius = 0.12
        horn_mesh.height = 0.38
        var horn := _creature_add_mesh(
            enemy, horn_mesh, "DragonHorn",
            Vector3(side * 0.25, 1.70, 0.72),
            Vector3.ONE, Color(0.82, 0.72, 0.48)
        )
        horn.rotation.z = -side * 0.42

        var wing_pivot := Node3D.new()
        wing_pivot.name = "WingLeft" if side < 0.0 else "WingRight"
        wing_pivot.position = Vector3(side * 0.47, 1.12, -0.10)
        enemy.add_child(wing_pivot)

        var wing_mesh := BoxMesh.new()
        wing_mesh.size = Vector3(0.10, 0.78, 1.02)
        var wing := _creature_add_mesh(
            wing_pivot, wing_mesh, "WingMembrane",
            Vector3(side * 0.08, 0.02, -0.20),
            Vector3.ONE, wing_color
        )
        wing.rotation.z = side * 0.36

        var wing_tip := BoxMesh.new()
        wing_tip.size = Vector3(0.08, 0.42, 0.62)
        var tip := _creature_add_mesh(
            wing_pivot, wing_tip, "WingTip",
            Vector3(side * 0.12, 0.05, -0.64),
            Vector3.ONE, Color(0.30, 0.09, 0.10)
        )
        tip.rotation.z = side * 0.55

        var leg_mesh := CapsuleMesh.new()
        leg_mesh.radius = 0.12
        leg_mesh.height = 0.55
        _creature_add_mesh(
            enemy, leg_mesh, "DragonLeg",
            Vector3(side * 0.34, 0.32, 0.34),
            Vector3.ONE, scales
        )
        _creature_add_mesh(
            enemy, leg_mesh, "DragonLeg",
            Vector3(side * 0.34, 0.32, -0.42),
            Vector3.ONE, scales
        )

    var tail_mesh := CapsuleMesh.new()
    tail_mesh.radius = 0.13
    tail_mesh.height = 1.0
    var tail := _creature_add_mesh(
        enemy, tail_mesh, "DragonTail",
        Vector3(0, 0.72, -0.82),
        Vector3(0.8, 0.8, 1.0), scales
    )
    tail.rotation.x = deg_to_rad(72.0)

    var flame := _creature_sphere(
        enemy, "DragonThroatGlow",
        Vector3(0, 1.15, 1.02),
        Vector3(0.20, 0.16, 0.16),
        Color(1.0, 0.20, 0.015)
    )
    var flame_material := flame.material_override as StandardMaterial3D
    if flame_material != null:
        flame_material.emission_enabled = true
        flame_material.emission = Color(1.0, 0.10, 0.01)


# ------------------------------------------------------------
# ENEMY AI - DOGS CHASE, DRAGONS BREATHE FIRE
# ------------------------------------------------------------

func _exp_update_enemies(delta: float) -> void:
    if not is_instance_valid(player):
        return

    for i in range(exp_enemy_list.size() - 1, -1, -1):
        var data: Dictionary = exp_enemy_list[i]
        var enemy := data.get("node") as Node3D

        if not is_instance_valid(enemy):
            exp_enemy_list.remove_at(i)
            continue

        var distance := enemy.global_position.distance_to(player.global_position)
        if distance > 22.0:
            continue

        var enemy_type := int(data.get("type", 0))
        var is_dragon := enemy_type == 1
        var attack_range := 4.8 if is_dragon else 1.5

        if distance > attack_range:
            var direction := player.global_position - enemy.global_position
            direction.y = 0.0
            direction = direction.normalized()
            enemy.position += direction * float(data.get("speed", 1.2)) * delta
            if direction.length() > 0.01:
                enemy.rotation.y = atan2(direction.x, direction.z)
        else:
            var timer := float(data.get("attack_timer", 0.0)) - delta
            if timer <= 0.0:
                _exp_damage_player(float(data.get("damage", 8.0)))
                if is_dragon:
                    _creature_dragon_breath(enemy)
                    timer = 2.0
                else:
                    timer = 1.35
            data["attack_timer"] = timer

        exp_enemy_list[i] = data


func _creature_dragon_breath(dragon: Node3D) -> void:
    if not is_instance_valid(player):
        return

    var target := player.global_position + Vector3(0, 0.9, 0)
    var origin := dragon.global_position + Vector3(0, 1.15, 0.8)
    var distance := origin.distance_to(target)

    var fire := MeshInstance3D.new()
    fire.name = "DragonFireBreath"
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 10
    mesh.rings = 6
    fire.mesh = mesh
    fire.scale = Vector3(0.62, 0.48, maxf(1.0, distance * 0.48))

    var material := _creature_material(Color(1.0, 0.22, 0.015, 0.88), true)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fire.material_override = material
    fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    add_child(fire)
    fire.global_position = origin.lerp(target, 0.5)
    fire.look_at(target, Vector3.UP)

    var timer := get_tree().create_timer(0.30)
    timer.timeout.connect(fire.queue_free)


func _creature_animate_enemies() -> void:
    if is_game_paused or not garden_active:
        return

    for data in exp_enemy_list:
        var enemy := data.get("node") as Node3D
        if not is_instance_valid(enemy):
            continue

        if int(data.get("type", 0)) == 1:
            var flap := sin(creature_clock * 8.0) * 0.48
            var left := enemy.get_node_or_null("WingLeft") as Node3D
            var right := enemy.get_node_or_null("WingRight") as Node3D
            if is_instance_valid(left):
                left.rotation.z = 0.45 + flap
            if is_instance_valid(right):
                right.rotation.z = -0.45 - flap
        else:
            var tail := enemy.get_node_or_null("DogTail") as Node3D
            if is_instance_valid(tail):
                tail.rotation.z = sin(creature_clock * 5.0) * 0.28
