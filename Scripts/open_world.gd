

extends "res://Scripts/main_updated.gd"

# ============================================================
# YAHYA ADVENTURES - REALISTIC OPEN WORLD
# Garden Expansion - Godot 4.4.1
# Preserve existing main.gd and main_updated.gd
# ============================================================

const SAVE_PATH := "user://yahya_adventures_save.cfg"

const WORLD_MIN_X := -29.0
const WORLD_MAX_X := 29.0
const WORLD_MIN_Z := -99.0
const WORLD_MAX_Z := -7.0

const GARDEN_COIN_TOTAL := 8
const CRYSTAL_TOTAL := 3

var garden_active := false
var garden_unlocked := false

var collected_garden_coins: Array[String] = []
var crystals_collected: Array[String] = []

var crystals: Array[MeshInstance3D] = []

var interact_button: Button
var garden_status_label: Label

var fountain_used := false
var has_garden_key := false
var chest_opened := false

var npc_quest_started := false
var npc_reward_claimed := false
var secret_area_unlocked := false

var interaction_cooldown := 0.0
var world_time := 0.0

var garden_npc: Node3D
var treasure_chest: Node3D
var garden_fountain: Node3D
var secret_gate: Node3D


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
    super._ready()

    _load_progress()
    _create_garden()
    _create_garden_objects()
    _create_garden_coins()
    _create_crystals()
    _create_interaction_ui()

    if garden_unlocked:
        garden_active = true
        door_open = false

        for coin in coins:
            if is_instance_valid(coin):
                coin.queue_free()

        coins.clear()

        player.position = Vector3(3.5, 0.0, -10.0)

    update_coin_label()
    _update_garden_ui()

    show_message(
        "مرحباً بك في مغامرات يحيى!"
    )


func _process(delta: float) -> void:
    super._process(delta)

    if interaction_cooldown > 0.0:
        interaction_cooldown -= delta

    if garden_active:
        world_time += delta
        _update_crystals(delta)
        _check_crystal_collection()


# ============================================================
# ENTER GARDEN
# ============================================================

func _complete_level() -> void:
    if garden_active:
        return

    garden_unlocked = true
    garden_active = true

    # Keep the original door visually open.
    door_open_amount = 1.0
    door_open = false

    player.position = Vector3(3.5, 0.0, -9.0)
    move_velocity = Vector2.ZERO

    _save_progress()
    _update_garden_ui()

    show_message(
        "رائع يا يحيى! لقد وصلت إلى الحديقة!"
    )


# ============================================================
# OPEN WORLD MOVEMENT
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
        move_velocity.x,
        0.0,
        move_velocity.y
    )

    player.position += direction * delta

    if garden_active:
        player.position.x = clampf(
            player.position.x,
            WORLD_MIN_X,
            WORLD_MAX_X
        )

        player.position.z = clampf(
            player.position.z,
            WORLD_MIN_Z,
            WORLD_MAX_Z
        )
    else:
        player.position.x = clampf(
            player.position.x,
            -ROOM_LIMIT,
            ROOM_LIMIT
        )

        player.position.z = clampf(
            player.position.z,
            -ROOM_LIMIT,
            ROOM_LIMIT
        )

    if move_velocity.length() > 0.12:
        var target_rotation := atan2(
            -move_velocity.x,
            -move_velocity.y
        )

        player.rotation.y = lerp_angle(
            player.rotation.y,
            target_rotation,
            minf(1.0, delta * 12.0)
        )


# ============================================================
# OPEN WORLD CAMERA
# ============================================================

func follow_camera(delta: float) -> void:

    if not is_instance_valid(player):
        return

    if not is_instance_valid(camera):
        return

    var target_offset := Vector3(
        0.0,
        6.3 if garden_active else camera_distance * 0.72,
        9.0 if garden_active else camera_distance * 1.05
    )

    var target_position := (
        player.global_position + target_offset
    )

    var weight := 1.0 - exp(-5.5 * delta)

    camera.global_position = camera.global_position.lerp(
        target_position,
        weight
    )

    camera.fov = 72.0 if garden_active else 76.0

    var look_target := (
        player.global_position + Vector3(0, 1.25, 0)
    )

    camera.look_at(look_target, Vector3.UP)


# ============================================================
# GARDEN ENVIRONMENT
# ============================================================

func _create_garden() -> void:

    # Large grass field.
    _make_world_box(
        "GardenGround",
        Vector3(60, 0.25, 100),
        Vector3(0, -0.18, -55),
        Color(0.19, 0.39, 0.16)
    )

    # Main stone walkway.
    _make_world_box(
        "GardenMainPath",
        Vector3(3.8, 0.10, 88),
        Vector3(3.5, -0.015, -51),
        Color(0.65, 0.59, 0.49)
    )

    # Decorative path borders.
    for side in [-1.0, 1.0]:
        _make_world_box(
            "PathBorder",
            Vector3(0.16, 0.12, 88),
            Vector3(
                3.5 + side * 2.0,
                0.02,
                -51
            ),
            Color(0.37, 0.34, 0.29)
        )

    # Side fences.
    for side in [-1.0, 1.0]:

        var fence_x := side * 29.0

        _make_world_box(
            "GardenFenceUpper",
            Vector3(0.18, 0.18, 92),
            Vector3(fence_x, 1.0, -53),
            Color(0.36, 0.22, 0.12)
        )

        _make_world_box(
            "GardenFenceLower",
            Vector3(0.18, 0.18, 92),
            Vector3(fence_x, 0.45, -53),
            Color(0.36, 0.22, 0.12)
        )

        for z in range(-98, -8, 5):
            _make_world_box(
                "FencePost",
                Vector3(0.25, 1.5, 0.25),
                Vector3(fence_x, 0.7, float(z)),
                Color(0.27, 0.15, 0.08)
            )

    # Back fence.
    _make_world_box(
        "GardenBackFence",
        Vector3(58, 1.4, 0.20),
        Vector3(0, 0.7, -99),
        Color(0.32, 0.19, 0.10)
    )

    # Grass decoration and trees.
    var tree_positions := [
        Vector3(-19, 0, -17),
        Vector3(-23, 0, -30),
        Vector3(-17, 0, -45),
        Vector3(-23, 0, -62),
        Vector3(-17, 0, -82),
        Vector3(20, 0, -17),
        Vector3(24, 0, -32),
        Vector3(19, 0, -49),
        Vector3(24, 0, -68),
        Vector3(18, 0, -85),
        Vector3(-10, 0, -88),
        Vector3(11, 0, -90)
    ]

    for tree_position in tree_positions:
        _create_tree(tree_position)

    # Bushes.
    var bush_positions := [
        Vector3(-10, 0, -13),
        Vector3(-13, 0, -24),
        Vector3(13, 0, -15),
        Vector3(15, 0, -36),
        Vector3(-12, 0, -55),
        Vector3(12, 0, -60),
        Vector3(-9, 0, -78),
        Vector3(12, 0, -83)
    ]

    for bush_position in bush_positions:
        _create_bush(bush_position)

    # Garden flower beds.
    _create_flower_bed(
        Vector3(-8, 0, -14)
    )

    _create_flower_bed(
        Vector3(10, 0, -42)
    )

    _create_flower_bed(
        Vector3(-10, 0, -70)
    )


# ============================================================
# TREES AND PLANTS
# ============================================================

func _create_tree(pos: Vector3) -> void:

    _make_world_box(
        "TreeTrunk",
        Vector3(0.65, 3.6, 0.65),
        pos + Vector3(0, 1.8, 0),
        Color(0.29, 0.16, 0.08)
    )

    _make_world_sphere(
        "TreeLeaves",
        2.0,
        pos + Vector3(0, 4.0, 0),
        Color(0.10, 0.34, 0.12)
    )

    _make_world_sphere(
        "TreeLeavesUpper",
        1.45,
        pos + Vector3(0.5, 5.0, 0.2),
        Color(0.15, 0.43, 0.16)
    )

    _make_world_sphere(
        "TreeLeavesSide",
        1.35,
        pos + Vector3(-0.8, 4.7, 0.3),
        Color(0.12, 0.39, 0.14)
    )


func _create_bush(pos: Vector3) -> void:

    _make_world_sphere(
        "GardenBush",
        0.85,
        pos + Vector3(0, 0.65, 0),
        Color(0.12, 0.35, 0.10)
    )

    _make_world_sphere(
        "GardenBushLeaf",
        0.55,
        pos + Vector3(0.55, 0.85, 0.1),
        Color(0.19, 0.46, 0.13)
    )


func _create_flower_bed(pos: Vector3) -> void:

    _make_world_box(
        "FlowerBed",
        Vector3(3.5, 0.16, 1.4),
        pos + Vector3(0, 0.08, 0),
        Color(0.27, 0.20, 0.12)
    )

    var flower_colors := [
        Color(0.95, 0.15, 0.25),
        Color(1.0, 0.72, 0.12),
        Color(0.85, 0.30, 0.85),
        Color(0.95, 0.92, 0.72)
    ]

    for i in range(8):
        var x := pos.x - 1.3 + float(i) * 0.37

        _make_world_sphere(
            "Flower",
            0.17,
            Vector3(x, 0.48, pos.z),
            flower_colors[i % flower_colors.size()]
        )


# ============================================================
# GARDEN OBJECTS
# ============================================================

func _create_garden_objects() -> void:

    # Wooden bench.
    _make_world_box(
        "BenchSeat",
        Vector3(2.5, 0.18, 0.75),
        Vector3(-7, 0.65, -19),
        Color(0.36, 0.19, 0.09)
    )

    _make_world_box(
        "BenchBack",
        Vector3(2.5, 0.85, 0.16),
        Vector3(-7, 1.12, -19.35),
        Color(0.31, 0.16, 0.07)
    )

    for x in [-7.9, -6.1]:
        _make_world_box(
            "BenchLeg",
            Vector3(0.16, 0.65, 0.16),
            Vector3(x, 0.32, -19),
            Color(0.18, 0.10, 0.05)
        )

    # Fountain.
    garden_fountain = Node3D.new()
    garden_fountain.name = "GardenFountain"
    garden_fountain.position = Vector3(-8, 0, -31)
    add_child(garden_fountain)

    _make_world_cylinder(
        "FountainBase",
        2.2,
        0.55,
        garden_fountain.position + Vector3(0, 0.27, 0),
        Color(0.53, 0.55, 0.56)
    )

    _make_world_cylinder(
        "FountainWater",
        1.75,
        0.12,
        garden_fountain.position + Vector3(0, 0.61, 0),
        Color(0.12, 0.57, 0.85)
    )

    _make_world_cylinder(
        "FountainColumn",
        0.40,
        1.35,
        garden_fountain.position + Vector3(0, 1.30, 0),
        Color(0.65, 0.66, 0.65)
    )

    _make_world_sphere(
        "FountainTop",
        0.6,
        garden_fountain.position + Vector3(0, 2.05, 0),
        Color(0.20, 0.62, 0.92)
    )

    # Treasure chest.
    treasure_chest = Node3D.new()
    treasure_chest.name = "GardenTreasureChest"
    treasure_chest.position = Vector3(9, 0, -20)
    add_child(treasure_chest)

    _make_world_box(
        "ChestBody",
        Vector3(1.65, 0.9, 1.1),
        treasure_chest.position + Vector3(0, 0.55, 0),
        Color(0.35, 0.17, 0.07)
    )

    _make_world_box(
        "ChestLid",
        Vector3(1.72, 0.35, 1.15),
        treasure_chest.position + Vector3(0, 1.15, 0),
        Color(0.50, 0.26, 0.08)
    )

    _make_world_box(
        "ChestLock",
        Vector3(0.24, 0.38, 0.12),
        treasure_chest.position + Vector3(0, 0.85, -0.58),
        Color(1.0, 0.75, 0.12)
    )

    # NPC: garden helper.
    garden_npc = Node3D.new()
    garden_npc.name = "GardenHelper"
    garden_npc.position = Vector3(-7, 0, -14)
    add_child(garden_npc)

    var npc_body := CapsuleMesh.new()
    npc_body.radius = 0.38
    npc_body.height = 1.45

    _add_npc_part(
        npc_body,
        Vector3(0, 0.95, 0),
        Color(0.20, 0.39, 0.78)
    )

    var npc_head := SphereMesh.new()
    npc_head.radius = 0.32
    npc_head.height = 0.64

    _add_npc_part(
        npc_head,
        Vector3(0, 1.9, 0),
        Color(0.78, 0.57, 0.40)
    )

    _make_world_sphere(
        "NPC_Hair",
        0.34,
        garden_npc.position + Vector3(0, 2.13, 0),
        Color(0.12, 0.08, 0.05)
    )

    # Secret garden gate.
    secret_gate = Node3D.new()
    secret_gate.name = "SecretGardenGate"
    secret_gate.position = Vector3(18, 0, -66)
    add_child(secret_gate)

    _make_world_box(
        "SecretGateLeft",
        Vector3(0.35, 3.2, 0.35),
        secret_gate.position + Vector3(-1.8, 1.6, 0),
        Color(0.18, 0.38, 0.22)
    )

    _make_world_box(
        "SecretGateRight",
        Vector3(0.35, 3.2, 0.35),
        secret_gate.position + Vector3(1.8, 1.6, 0),
        Color(0.18, 0.38, 0.22)
    )

    _make_world_box(
        "SecretGateTop",
        Vector3(4.0, 0.35, 0.35),
        secret_gate.position + Vector3(0, 3.1, 0),
        Color(0.18, 0.38, 0.22)
    )

    # Secret treasure.
    _make_world_box(
        "SecretTreasure",
        Vector3(1.5, 0.9, 1.1),
        Vector3(22, 0.45, -78),
        Color(0.85, 0.56, 0.08)
    )

    _make_world_sphere(
        "SecretGlow",
        0.8,
        Vector3(22, 1.8, -78),
        Color(1.0, 0.84, 0.20)
    )


func _add_npc_part(
    mesh: Mesh,
    pos: Vector3,
    color: Color
) -> void:

    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.8

    part.material_override = material
    garden_npc.add_child(part)


# ============================================================
# COLLECTIBLE GARDEN COINS
# ============================================================

func _create_garden_coins() -> void:

    var positions := [
        Vector3(-5, 0.7, -12),
        Vector3(8, 0.7, -27),
        Vector3(-14, 0.7, -36),
        Vector3(14, 0.7, -43),
        Vector3(-7, 0.7, -53),
        Vector3(8, 0.7, -61),
        Vector3(-13, 0.7, -76),
        Vector3(16, 0.7, -86)
    ]

    for i in range(positions.size()):

        var coin_id := "garden_coin_" + str(i + 1)

        if collected_garden_coins.has(coin_id):
            continue

        add_coin(positions[i])

        var coin := coins[coins.size() - 1]
        coin.set_meta("garden_coin_id", coin_id)


func collect_coins() -> void:

    for i in range(coins.size() - 1, -1, -1):

        var coin := coins[i]

        if not is_instance_valid(coin):
            coins.remove_at(i)
            continue

        if player.global_position.distance_to(
            coin.global_position
        ) < COIN_DISTANCE:

            var is_garden_coin := coin.has_meta(
                "garden_coin_id"
            )

            if is_garden_coin:
                var coin_id: String = str(
                    coin.get_meta("garden_coin_id")
                )

                if collected_garden_coins.has(coin_id):
                    coin.queue_free()
                    coins.remove_at(i)
                    continue

                collected_garden_coins.append(coin_id)

            coin_count += 1

            coin.queue_free()
            coins.remove_at(i)

            update_coin_label()

            _save_progress()

            show_message(
                "أحسنت! حصلت على عملة ذهبية"
            )


# ============================================================
# BLUE CRYSTALS
# ============================================================

func _create_crystals() -> void:

    var positions := [
        Vector3(-15, 0.9, -24),
        Vector3(14, 0.9, -54),
        Vector3(-17, 0.9, -83)
    ]

    for i in range(CRYSTAL_TOTAL):

        var crystal_id := "crystal_" + str(i + 1)

        if crystals_collected.has(crystal_id):
            continue

        var crystal := _make_world_sphere(
            "BlueCrystal",
            0.48,
            positions[i],
            Color(0.10, 0.75, 1.0)
        )

        crystal.set_meta("crystal_id", crystal_id)

        crystals.append(crystal)


func _update_crystals(delta: float) -> void:

    for crystal in crystals:

        if not is_instance_valid(crystal):
            continue

        crystal.rotate_y(delta * 1.8)

        crystal.position.y = (
            0.9
            + sin(
                world_time * 2.0
                + crystal.position.x
            ) * 0.15
        )


func _check_crystal_collection() -> void:

    for i in range(crystals.size() - 1, -1, -1):

        var crystal := crystals[i]

        if not is_instance_valid(crystal):
            crystals.remove_at(i)
            continue

        if player.global_position.distance_to(
            crystal.global_position
        ) < 1.25:

            var crystal_id := str(
                crystal.get_meta("crystal_id")
            )

            if not crystals_collected.has(crystal_id):
                crystals_collected.append(crystal_id)

            crystal.queue_free()
            crystals.remove_at(i)

            _save_progress()

            show_message(
                "جميل! جمعت بلورة سحرية "
                + str(crystals_collected.size())
                + " / 3"
            )

            _update_garden_ui()


# ============================================================
# INTERACTION UI
# ============================================================

func _create_interaction_ui() -> void:

    if not is_instance_valid(responsive_root):
        return

    interact_button = _make_action_button(
        "تفاعل",
        20
    )

    interact_button.custom_minimum_size = Vector2(
        120, 58
    )

    interact_button.pressed.connect(
        _interact_with_world
    )

    responsive_root.add_child(interact_button)

    garden_status_label = _make_label(
        "الحديقة",
        17,
        Color(1.0, 0.91, 0.55)
    )

    responsive_root.add_child(
        garden_status_label
    )

    responsive_root.resized.connect(
        _layout_garden_ui
    )

    get_viewport().size_changed.connect(
        _layout_garden_ui
    )

    call_deferred("_layout_garden_ui")


func _layout_garden_ui() -> void:

    if not is_instance_valid(interact_button):
        return

    var size := get_viewport().get_visible_rect().size

    interact_button.position = Vector2(
        size.x - 155,
        size.y - 170
    )

    interact_button.visible = garden_active

    if is_instance_valid(garden_status_label):
        garden_status_label.position = Vector2(
            size.x - 220,
            190
        )


func _update_garden_ui() -> void:

    if is_instance_valid(interact_button):
        interact_button.visible = garden_active

    if is_instance_valid(garden_status_label):

        garden_status_label.text = (
            "البلورات: "
            + str(crystals_collected.size())
            + " / 3"
        )

    _layout_garden_ui()


# ============================================================
# WORLD INTERACTION
# ============================================================

func _interact_with_world() -> void:

    if not garden_active:
        return

    if interaction_cooldown > 0.0:
        return

    interaction_cooldown = 0.6

    var player_position := player.global_position

    # Fountain.
    if player_position.distance_to(
        garden_fountain.global_position
    ) < 4.0:

        _use_fountain()
        return

    # Treasure chest.
    if player_position.distance_to(
        treasure_chest.global_position
    ) < 3.5:

        _open_treasure_chest()
        return

    # NPC.
    if player_position.distance_to(
        garden_npc.global_position
    ) < 3.5:

        _talk_to_npc()
        return

    # Secret gate.
    if player_position.distance_to(
        secret_gate.global_position
    ) < 4.0:

        _open_secret_gate()
        return

    # Secret treasure.
    if player_position.distance_to(
        Vector3(22, 0, -78)
    ) < 3.5:

        _collect_secret_treasure()
        return

    show_message(
        "اقترب من شخص أو شيء للتفاعل معه"
    )


# ============================================================
# FOUNTAIN AND KEY
# ============================================================

func _use_fountain() -> void:

    if fountain_used:
        show_message(
            "النافورة تعمل بشكل جميل!"
        )
        return

    fountain_used = true
    has_garden_key = true

    _save_progress()

    show_message(
        "وجدت مفتاحاً ذهبياً داخل النافورة!"
    )


# ============================================================
# TREASURE CHEST
# ============================================================

func _open_treasure_chest() -> void:

    if chest_opened:
        show_message(
            "صندوق الكنز فارغ الآن!"
        )
        return

    if not has_garden_key:
        show_message(
            "الصندوق مغلق! ابحث عن المفتاح الذهبي"
        )
        return

    chest_opened = true
    has_garden_key = false

    coin_count += 5

    _make_world_sphere(
        "ChestTreasureGlow",
        0.7,
        treasure_chest.position + Vector3(0, 2.0, 0),
        Color(1.0, 0.80, 0.10)
    )

    _save_progress()
    update_coin_label()

    show_message(
        "مبروك! فتحت صندوق الكنز وحصلت على 5 عملات!"
    )


# ============================================================
# NPC QUEST
# ============================================================

func _talk_to_npc() -> void:

    if not npc_quest_started:

        npc_quest_started = true

        _save_progress()

        show_message(
            "مرحباً يا يحيى! اجمع البلورات السحرية الثلاث!"
        )

        return

    if crystals_collected.size() < 3:

        show_message(
            "أحضر البلورات الثلاث أولاً: "
            + str(crystals_collected.size())
            + " / 3"
        )

        return

    if not npc_reward_claimed:

        npc_reward_claimed = true
        secret_area_unlocked = true

        coin_count += 10

        _save_progress()
        update_coin_label()

        show_message(
            "أحسنت! حصلت على 10 عملات وفتحت المنطقة السرية!"
        )

        return

    show_message(
        "أنت بطل الحديقة يا يحيى!"
    )


# ============================================================
# SECRET AREA
# ============================================================

func _open_secret_gate() -> void:

    if not secret_area_unlocked:

        show_message(
            "أكمل مهمة البلورات الثلاث لفتح المنطقة السرية"
        )

        return

    show_message(
        "تم فتح البوابة السرية! استكشف المنطقة!"
    )

    player.position = Vector3(
        22, 0, -72
    )

    move_velocity = Vector2.ZERO


func _collect_secret_treasure() -> void:

    if not secret_area_unlocked:
        show_message(
            "هذه المنطقة مغلقة!"
        )
        return

    if has_meta("secret_treasure_collected"):
        show_message(
            "لقد جمعت هذا الكنز سابقاً!"
        )
        return

    set_meta(
        "secret_treasure_collected",
        true
    )

    coin_count += 20

    _save_progress()
    update_coin_label()

    show_message(
        "كنز نادر! حصلت على 20 عملة ذهبية!"
    )


# ============================================================
# PERSISTENT GAME SAVE
# ============================================================

func _load_progress() -> void:

    var config := ConfigFile.new()

    var result := config.load(SAVE_PATH)

    if result != OK:
        return

    garden_unlocked = config.get_value(
        "world",
        "garden_unlocked",
        false
    )

    if garden_unlocked:
        coin_count = int(
            config.get_value(
                "world",
                "coin_count",
                4
            )
        )

    collected_garden_coins.clear()

    var saved_coins: Variant = config.get_value(
        "world",
        "collected_garden_coins",
        []
    )

    for item in saved_coins:
        collected_garden_coins.append(str(item))

    crystals_collected.clear()

    var saved_crystals: Variant = config.get_value(
        "world",
        "crystals_collected",
        []
    )

    for item in saved_crystals:
        crystals_collected.append(str(item))

    fountain_used = config.get_value(
        "world",
        "fountain_used",
        false
    )

    has_garden_key = config.get_value(
        "world",
        "has_garden_key",
        false
    )

    chest_opened = config.get_value(
        "world",
        "chest_opened",
        false
    )

    npc_quest_started = config.get_value(
        "world",
        "npc_quest_started",
        false
    )

    npc_reward_claimed = config.get_value(
        "world",
        "npc_reward_claimed",
        false
    )

    secret_area_unlocked = config.get_value(
        "world",
        "secret_area_unlocked",
        false
    )

    if config.get_value(
        "world",
        "secret_treasure_collected",
        false
    ):
        set_meta(
            "secret_treasure_collected",
            true
        )


func _save_progress() -> void:

    var config := ConfigFile.new()

    config.set_value(
        "world",
        "garden_unlocked",
        garden_unlocked
    )

    config.set_value(
        "world",
        "coin_count",
        coin_count
    )

    config.set_value(
        "world",
        "collected_garden_coins",
        collected_garden_coins
    )

    config.set_value(
        "world",
        "crystals_collected",
        crystals_collected
    )

    config.set_value(
        "world",
        "fountain_used",
        fountain_used
    )

    config.set_value(
        "world",
        "has_garden_key",
        has_garden_key
    )

    config.set_value(
        "world",
        "chest_opened",
        chest_opened
    )

    config.set_value(
        "world",
        "npc_quest_started",
        npc_quest_started
    )

    config.set_value(
        "world",
        "npc_reward_claimed",
        npc_reward_claimed
    )

    config.set_value(
        "world",
        "secret_area_unlocked",
        secret_area_unlocked
    )

    config.set_value(
        "world",
        "secret_treasure_collected",
        has_meta("secret_treasure_collected")
    )

    var result := config.save(SAVE_PATH)

    if result != OK:
        push_warning(
            "Unable to save Yahya Adventures progress."
        )


# ============================================================
# WORLD GEOMETRY HELPERS
# ============================================================

func _make_world_box(
    node_name: String,
    box_size: Vector3,
    pos: Vector3,
    color: Color
) -> MeshInstance3D:

    var item := MeshInstance3D.new()
    item.name = node_name

    var mesh := BoxMesh.new()
    mesh.size = box_size

    item.mesh = mesh
    item.position = pos

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88

    item.material_override = material

    item.cast_shadow = (
        GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    )

    add_child(item)

    return item


func _make_world_sphere(
    node_name: String,
    radius: float,
    pos: Vector3,
    color: Color
) -> MeshInstance3D:

    var item := MeshInstance3D.new()
    item.name = node_name

    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0

    item.mesh = mesh
    item.position = pos

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.72

    item.material_override = material

    add_child(item)

    return item


func _make_world_cylinder(
    node_name: String,
    radius: float,
    height: float,
    pos: Vector3,
    color: Color
) -> MeshInstance3D:

    var item := MeshInstance3D.new()
    item.name = node_name

    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 24

    item.mesh = mesh
    item.position = pos

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.55

    item.material_override = material

    add_child(item)

    return item


# ============================================================
# COIN COUNTER
# ============================================================

func update_coin_label() -> void:

    var value := (
        "العملات: "
        + str(coin_count)
        + " / 12"
    )

    if is_instance_valid(responsive_coin_label):
        responsive_coin_label.text = value

    elif is_instance_valid(coin_label):
        coin_label.text = value


# ============================================================
# END OF YAHYA OPEN WORLD EXPANSION
# ============================================================
