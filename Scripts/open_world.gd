extends "res://Scripts/main_updated.gd"

# ============================================================
# YAHYA ADVENTURES - OPEN GARDEN EXPANSION
# Godot 4.4.1 | Full replacement: Scripts/open_world.gd
# Mobile-friendly world, quests, collectibles, save system,
# procedural sound effects, ambience and visual particles.
# ============================================================

const SAVE_PATH := "user://yahya_adventures_save.cfg"
const WORLD_MIN_X := -29.0
const WORLD_MAX_X := 29.0
const WORLD_MIN_Z := -99.0
const WORLD_MAX_Z := -7.0
const GARDEN_COIN_TOTAL := 8
const CRYSTAL_TOTAL := 3
const INTERACT_DISTANCE := 4.2
const SFX_RATE := 22050

var garden_active := false
var garden_unlocked := false
var collected_garden_coins: Array[String] = []
var crystals_collected: Array[String] = []
var crystals: Array[MeshInstance3D] = []

var garden_npc: Node3D
var treasure_chest: Node3D
var garden_fountain: Node3D
var secret_gate: Node3D
var secret_treasure: Node3D
var interact_button: Button
var garden_status_label: Label
var quest_label: Label

var fountain_used := false
var has_garden_key := false
var chest_opened := false
var npc_quest_started := false
var npc_reward_claimed := false
var secret_area_unlocked := false
var secret_treasure_collected := false
var interaction_cooldown := 0.0
var world_time := 0.0
var ambience_timer := 0.0
var footstep_timer := 0.0
var effects_enabled := true
var sound_enabled := true
var master_volume := 0.75
var sfx_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var audio_rng := RandomNumberGenerator.new()
var fountain_water: MeshInstance3D
var chest_lid: MeshInstance3D
var gate_door: MeshInstance3D
var garden_lights: Array[OmniLight3D] = []
var sparkle_particles: CPUParticles3D
var coin_particles: CPUParticles3D

func _ready() -> void:
    audio_rng.randomize()
    super._ready()
    _load_progress()
    _setup_audio()
    _create_garden()
    _create_garden_objects()
    _create_garden_coins()
    _create_crystals()
    _create_interaction_ui()
    _create_particle_effects()
    if garden_unlocked:
        _enter_garden(false)
    update_coin_label()
    _update_garden_ui()
    show_message("مرحباً يا يحيى! اجمع العملات وافتح باب الحديقة.")

func _process(delta: float) -> void:
    super._process(delta)
    if interaction_cooldown > 0.0:
        interaction_cooldown = maxf(0.0, interaction_cooldown - delta)
    if not garden_active or is_game_paused or level_complete:
        return
    world_time += delta
    _update_crystals(delta)
    _check_crystal_collection()
    _animate_garden(delta)
    _update_ambient_sound(delta)
    _update_footsteps(delta)
    _update_nearby_prompt()

func _notification(what: int) -> void:
    super._notification(what)
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _stop_audio()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        if sound_enabled and garden_active:
            _start_ambience()

# ------------------------------------------------------------
# PROGRESSION AND ROOM -> GARDEN TRANSITION
# ------------------------------------------------------------

func _complete_level() -> void:
    if garden_active:
        return
    garden_unlocked = true
    _save_progress()
    _enter_garden(true)

func _enter_garden(show_intro: bool) -> void:
    garden_active = true
    level_complete = false
    is_game_paused = false
    get_tree().paused = false
    door_open_amount = 1.0
    door_open = false
    # Remove only the four original room coins. Keep uncollected
    # garden coins so saved progress and first entry both work.
    for i in range(coins.size() - 1, -1, -1):
        var existing_coin := coins[i]
        if not is_instance_valid(existing_coin):
            coins.remove_at(i)
            continue
        if not existing_coin.has_meta("garden_coin_id"):
            existing_coin.queue_free()
            coins.remove_at(i)
    player.position = Vector3(3.5, 0.0, -10.0)
    move_velocity = Vector2.ZERO
    if is_instance_valid(complete_overlay):
        complete_overlay.visible = false
    _update_garden_ui()
    _start_ambience()
    if show_intro:
        _play_sfx("unlock")
        _spawn_sparkles(player.global_position + Vector3(0, 1.2, 0))
        show_message("رائع يا يحيى! دخلت الحديقة المفتوحة. استكشف المكان!")
    else:
        show_message("أهلاً بعودتك إلى الحديقة يا يحيى!")

func move_player(delta: float) -> void:
    var input_direction := move_vector
    input_direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if input_direction.length() > 1.0:
        input_direction = input_direction.normalized()
    var speed := PLAYER_SPEED * (SPRINT_MULTIPLIER if sprint_enabled else 1.0)
    if input_direction.length() > 0.05:
        move_velocity = move_velocity.move_toward(input_direction * speed, PLAYER_ACCELERATION * delta)
    else:
        move_velocity = move_velocity.move_toward(Vector2.ZERO, PLAYER_FRICTION * delta)
    player.position += Vector3(move_velocity.x, 0.0, move_velocity.y) * delta
    if garden_active:
        player.position.x = clampf(player.position.x, WORLD_MIN_X, WORLD_MAX_X)
        player.position.z = clampf(player.position.z, WORLD_MIN_Z, WORLD_MAX_Z)
    else:
        player.position.x = clampf(player.position.x, -ROOM_LIMIT, ROOM_LIMIT)
        player.position.z = clampf(player.position.z, -ROOM_LIMIT, ROOM_LIMIT)
    if move_velocity.length() > 0.12:
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-move_velocity.x, -move_velocity.y), minf(1.0, delta * 12.0))

func follow_camera(delta: float) -> void:
    if not is_instance_valid(player) or not is_instance_valid(camera):
        return
    var offset := Vector3(0, 7.2, 10.0) if garden_active else Vector3(0, camera_distance * 0.72, camera_distance * 1.05)
    var target := player.global_position + offset
    var weight := 1.0 - exp(-5.5 * delta)
    camera.global_position = camera.global_position.lerp(target, weight)
    camera.fov = 72.0 if garden_active else 76.0
    camera.look_at(player.global_position + Vector3(0, 1.3, 0), Vector3.UP)

# ------------------------------------------------------------
# GARDEN WORLD BUILD
# ------------------------------------------------------------

func _create_garden() -> void:
    _make_box("GardenGround", Vector3(60, 0.25, 100), Vector3(0, -0.18, -55), Color(0.19, 0.39, 0.16))
    _make_box("MainStoneWalkway", Vector3(4.0, 0.12, 88), Vector3(3.5, -0.015, -51), Color(0.65, 0.59, 0.49))
    for side in [-1.0, 1.0]:
        _make_box("PathEdge", Vector3(0.15, 0.14, 88), Vector3(3.5 + side * 2.08, 0.02, -51), Color(0.34, 0.31, 0.27))
        var fx: float = float(side) * 29.0
        _make_box("FenceRailUpper", Vector3(0.18, 0.18, 92), Vector3(fx, 1.0, -53), Color(0.36, 0.22, 0.12))
        _make_box("FenceRailLower", Vector3(0.18, 0.18, 92), Vector3(fx, 0.45, -53), Color(0.36, 0.22, 0.12))
        for z in range(-98, -8, 5):
            _make_box("FencePost", Vector3(0.25, 1.5, 0.25), Vector3(fx, 0.7, float(z)), Color(0.27, 0.15, 0.08))
    _make_box("BackFence", Vector3(58, 1.4, 0.2), Vector3(0, 0.7, -99), Color(0.32, 0.19, 0.10))
    var trees := [
        Vector3(-19,0,-17),Vector3(-23,0,-30),Vector3(-17,0,-45),Vector3(-23,0,-62),
        Vector3(-17,0,-82),Vector3(20,0,-17),Vector3(24,0,-32),Vector3(19,0,-49),
        Vector3(24,0,-68),Vector3(18,0,-85),Vector3(-10,0,-88),Vector3(11,0,-90),
        Vector3(-25,0,-50),Vector3(26,0,-76),Vector3(-25,0,-91),Vector3(25,0,-12)
    ]
    for p in trees:
        _create_tree(p)
    var bushes := [
        Vector3(-10,0,-13),Vector3(-13,0,-24),Vector3(13,0,-15),Vector3(15,0,-36),
        Vector3(-12,0,-55),Vector3(12,0,-60),Vector3(-9,0,-78),Vector3(12,0,-83),
        Vector3(-20,0,-38),Vector3(21,0,-55),Vector3(-20,0,-72),Vector3(20,0,-91)
    ]
    for p in bushes:
        _create_bush(p)
    for p in [Vector3(-8,0,-14), Vector3(10,0,-42), Vector3(-10,0,-70), Vector3(11,0,-88)]:
        _create_flower_bed(p)
    _make_box("GardenPondBank", Vector3(8,0.3,5), Vector3(-15,0.0,-39), Color(0.32,0.25,0.15))
    var pond := _make_cylinder("GardenPond", 3.7, 0.18, Vector3(-15,0.12,-39), Color(0.08,0.42,0.67))
    var pond_material := pond.material_override as StandardMaterial3D
    pond_material.metallic = 0.18
    _make_box("PicnicTableTop", Vector3(2.8,0.18,1.3), Vector3(15,1.0,-32), Color(0.42,0.22,0.1))
    for x in [13.9,16.1]:
        for z in [-32.4,-31.6]:
            _make_box("PicnicTableLeg", Vector3(0.15,1.0,0.15), Vector3(x,0.48,z), Color(0.25,0.13,0.06))
    _make_box("GazeboFloor", Vector3(7,0.2,6), Vector3(0,0.0,-73), Color(0.55,0.48,0.38))
    for x in [-3.0,3.0]:
        for z in [-75.5,-70.5]:
            _make_box("GazeboPost", Vector3(0.22,3.0,0.22), Vector3(x,1.5,z), Color(0.34,0.18,0.08))
    _make_box("GazeboRoof", Vector3(7.5,0.25,6.5), Vector3(0,3.1,-73), Color(0.48,0.20,0.13))
    _create_lighting()

func _create_tree(pos: Vector3) -> void:
    _make_cylinder("TreeTrunk", 0.34, 3.6, pos + Vector3(0,1.8,0), Color(0.29,0.16,0.08))
    _make_sphere("TreeCrown", 2.0, pos + Vector3(0,4.0,0), Color(0.10,0.34,0.12))
    _make_sphere("TreeCrownTop", 1.45, pos + Vector3(0.5,5.0,0.2), Color(0.15,0.43,0.16))
    _make_sphere("TreeCrownSide", 1.35, pos + Vector3(-0.8,4.7,0.3), Color(0.12,0.39,0.14))

func _create_bush(pos: Vector3) -> void:
    _make_sphere("Bush", 0.85, pos + Vector3(0,0.65,0), Color(0.12,0.35,0.10))
    _make_sphere("BushLeaf", 0.55, pos + Vector3(0.55,0.85,0.1), Color(0.19,0.46,0.13))

func _create_flower_bed(pos: Vector3) -> void:
    _make_box("FlowerBed", Vector3(3.5,0.16,1.4), pos + Vector3(0,0.08,0), Color(0.27,0.20,0.12))
    var colors := [Color(0.95,0.15,0.25),Color(1.0,0.72,0.12),Color(0.85,0.30,0.85),Color(0.95,0.92,0.72)]
    for i in range(8):
        _make_sphere("Flower", 0.17, Vector3(pos.x-1.3+float(i)*0.37,0.48,pos.z), colors[i%colors.size()])

func _create_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "GardenSunlight"
    sun.rotation_degrees = Vector3(-48,-32,0)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    add_child(sun)
    var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
    if env_node and env_node.environment:
        env_node.environment.background_color = Color(0.48,0.70,0.88)
        env_node.environment.ambient_light_energy = 0.95
        env_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

# ------------------------------------------------------------
# INTERACTIVE OBJECTS, NPC, QUEST AND SECRET AREA
# ------------------------------------------------------------

func _create_garden_objects() -> void:
    _make_box("BenchSeat", Vector3(2.5,0.18,0.75), Vector3(-7,0.65,-19), Color(0.36,0.19,0.09))
    _make_box("BenchBack", Vector3(2.5,0.85,0.16), Vector3(-7,1.12,-19.35), Color(0.31,0.16,0.07))
    for x in [-7.9,-6.1]:
        _make_box("BenchLeg", Vector3(0.16,0.65,0.16), Vector3(x,0.32,-19), Color(0.18,0.10,0.05))
    garden_fountain = Node3D.new()
    garden_fountain.name = "GardenFountain"
    garden_fountain.position = Vector3(-8,0,-31)
    add_child(garden_fountain)
    _make_cylinder("FountainBase", 2.2, 0.55, garden_fountain.position+Vector3(0,0.27,0), Color(0.53,0.55,0.56))
    fountain_water = _make_cylinder("FountainWater", 1.75, 0.12, garden_fountain.position+Vector3(0,0.61,0), Color(0.12,0.57,0.85))
    _make_cylinder("FountainColumn", 0.4, 1.35, garden_fountain.position+Vector3(0,1.30,0), Color(0.65,0.66,0.65))
    _make_sphere("FountainTop", 0.6, garden_fountain.position+Vector3(0,2.05,0), Color(0.20,0.62,0.92))
    treasure_chest = Node3D.new()
    treasure_chest.name = "GardenTreasureChest"
    treasure_chest.position = Vector3(9,0,-20)
    add_child(treasure_chest)
    _make_box("ChestBody", Vector3(1.65,0.9,1.1), treasure_chest.position+Vector3(0,0.55,0), Color(0.35,0.17,0.07))
    chest_lid = _make_box("ChestLid", Vector3(1.72,0.35,1.15), treasure_chest.position+Vector3(0,1.15,0), Color(0.50,0.26,0.08))
    _make_box("ChestLock", Vector3(0.24,0.38,0.12), treasure_chest.position+Vector3(0,0.85,-0.58), Color(1.0,0.75,0.12))
    garden_npc = Node3D.new()
    garden_npc.name = "GardenHelper"
    garden_npc.position = Vector3(-7,0,-14)
    add_child(garden_npc)
    _npc_part(CapsuleMesh.new(), Vector3(0,0.95,0), Color(0.20,0.39,0.78))
    _npc_part(SphereMesh.new(), Vector3(0,1.9,0), Color(0.78,0.57,0.40))
    _make_sphere("NPC_Hair",0.34,garden_npc.position+Vector3(0,2.13,0),Color(0.12,0.08,0.05))
    secret_gate = Node3D.new()
    secret_gate.name = "SecretGardenGate"
    secret_gate.position = Vector3(18,0,-66)
    add_child(secret_gate)
    _make_box("SecretGateLeft",Vector3(0.35,3.2,0.35),secret_gate.position+Vector3(-1.8,1.6,0),Color(0.18,0.38,0.22))
    _make_box("SecretGateRight",Vector3(0.35,3.2,0.35),secret_gate.position+Vector3(1.8,1.6,0),Color(0.18,0.38,0.22))
    _make_box("SecretGateTop",Vector3(4.0,0.35,0.35),secret_gate.position+Vector3(0,3.1,0),Color(0.18,0.38,0.22))
    gate_door = _make_box("SecretGateDoor",Vector3(3.1,2.8,0.2),secret_gate.position+Vector3(0,1.4,0),Color(0.25,0.48,0.25))
    secret_treasure = Node3D.new()
    secret_treasure.name = "SecretTreasure"
    secret_treasure.position = Vector3(22,0,-78)
    add_child(secret_treasure)
    _make_box("SecretTreasureChest",Vector3(1.5,0.9,1.1),secret_treasure.position+Vector3(0,0.45,0),Color(0.85,0.56,0.08))
    _make_sphere("SecretTreasureGlow",0.8,secret_treasure.position+Vector3(0,1.8,0),Color(1.0,0.84,0.20))
    var lamp_positions := [Vector3(-5,0,-32),Vector3(5,0,-50),Vector3(-5,0,-68),Vector3(5,0,-88)]
    for p in lamp_positions:
        _make_cylinder("GardenLampPost",0.08,2.8,p+Vector3(0,1.4,0),Color(0.12,0.12,0.13))
        var lamp := OmniLight3D.new()
        lamp.position = p+Vector3(0,2.8,0)
        lamp.light_color = Color(1.0,0.78,0.48)
        lamp.light_energy = 0.45
        lamp.omni_range = 7.0
        add_child(lamp)
        garden_lights.append(lamp)

func _npc_part(mesh: Mesh, pos: Vector3, color: Color) -> void:
    if mesh is CapsuleMesh:
        (mesh as CapsuleMesh).radius = 0.38
        (mesh as CapsuleMesh).height = 1.45
    elif mesh is SphereMesh:
        (mesh as SphereMesh).radius = 0.32
        (mesh as SphereMesh).height = 0.64
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    part.material_override = mat
    garden_npc.add_child(part)

# ------------------------------------------------------------
# COLLECTIBLES AND SAVED PROGRESS
# ------------------------------------------------------------

func _create_garden_coins() -> void:
    var positions := [
        Vector3(-5,0.7,-12),Vector3(8,0.7,-27),Vector3(-14,0.7,-36),Vector3(14,0.7,-43),
        Vector3(-7,0.7,-53),Vector3(8,0.7,-61),Vector3(-13,0.7,-76),Vector3(16,0.7,-86)
    ]
    for i in range(positions.size()):
        var id := "garden_coin_" + str(i+1)
        if collected_garden_coins.has(id):
            continue
        add_coin(positions[i])
        coins.back().set_meta("garden_coin_id",id)

func collect_coins() -> void:
    for i in range(coins.size()-1,-1,-1):
        var coin := coins[i]
        if not is_instance_valid(coin):
            coins.remove_at(i)
            continue
        if player.global_position.distance_to(coin.global_position) < COIN_DISTANCE:
            if coin.has_meta("garden_coin_id"):
                var id := str(coin.get_meta("garden_coin_id"))
                if collected_garden_coins.has(id):
                    coin.queue_free()
                    coins.remove_at(i)
                    continue
                collected_garden_coins.append(id)
            coin_count += 1
            _spawn_coin_burst(coin.global_position)
            _play_sfx("coin")
            coin.queue_free()
            coins.remove_at(i)
            update_coin_label()
            _save_progress()
            show_message("عملة ذهبية جديدة! أحسنت يا يحيى.")

func _create_crystals() -> void:
    var positions := [Vector3(-15,0.9,-24),Vector3(14,0.9,-54),Vector3(-17,0.9,-83)]
    for i in range(CRYSTAL_TOTAL):
        var id := "crystal_"+str(i+1)
        if crystals_collected.has(id):
            continue
        var crystal := _make_sphere("BlueCrystal",0.48,positions[i],Color(0.10,0.75,1.0))
        crystal.set_meta("crystal_id",id)
        var mat := crystal.material_override as StandardMaterial3D
        mat.emission_enabled = true
        mat.emission = Color(0.05,0.42,0.9)
        mat.emission_energy_multiplier = 1.8
        crystals.append(crystal)

func _update_crystals(delta: float) -> void:
    for c in crystals:
        if is_instance_valid(c):
            c.rotate_y(delta*1.8)
            c.position.y = 0.9 + sin(world_time*2.0+c.position.x)*0.15

func _check_crystal_collection() -> void:
    for i in range(crystals.size()-1,-1,-1):
        var c := crystals[i]
        if not is_instance_valid(c):
            crystals.remove_at(i)
            continue
        if player.global_position.distance_to(c.global_position) < 1.35:
            var id := str(c.get_meta("crystal_id"))
            if not crystals_collected.has(id):
                crystals_collected.append(id)
            _spawn_sparkles(c.global_position)
            _play_sfx("crystal")
            c.queue_free()
            crystals.remove_at(i)
            _save_progress()
            _update_garden_ui()
            show_message("بلورة سحرية! "+str(crystals_collected.size())+" / 3")

# ------------------------------------------------------------
# TOUCH INTERACTION AND QUEST LOGIC
# ------------------------------------------------------------

func _create_interaction_ui() -> void:
    if not is_instance_valid(responsive_root):
        return
    interact_button = _make_action_button("تفاعل",20)
    interact_button.custom_minimum_size = Vector2(116,58)
    interact_button.pressed.connect(_interact_with_world)
    responsive_root.add_child(interact_button)
    garden_status_label = _make_label("البلورات: 0 / 3",16,Color(1.0,0.91,0.55))
    responsive_root.add_child(garden_status_label)
    quest_label = _make_label("المهمة: استكشف الحديقة",15,Color.WHITE)
    responsive_root.add_child(quest_label)
    responsive_root.resized.connect(_layout_garden_ui)
    get_viewport().size_changed.connect(_layout_garden_ui)
    call_deferred("_layout_garden_ui")

func _layout_garden_ui() -> void:
    if not is_instance_valid(interact_button):
        return
    var s := get_viewport().get_visible_rect().size
    interact_button.position = Vector2(s.x-142.0,s.y-148.0)
    interact_button.visible = garden_active
    if is_instance_valid(garden_status_label):
        garden_status_label.position = Vector2(s.x-205.0,188.0)
        garden_status_label.visible = garden_active
    if is_instance_valid(quest_label):
        quest_label.position = Vector2(s.x-260.0,216.0)
        quest_label.visible = garden_active

func _update_garden_ui() -> void:
    if is_instance_valid(interact_button):
        interact_button.visible = garden_active
    if is_instance_valid(garden_status_label):
        garden_status_label.text = "البلورات: "+str(crystals_collected.size())+" / 3"
    if is_instance_valid(quest_label):
        if not npc_quest_started:
            quest_label.text = "المهمة: تحدث مع البستاني"
        elif crystals_collected.size() < 3:
            quest_label.text = "المهمة: اجمع البلورات "+str(crystals_collected.size())+"/3"
        elif not npc_reward_claimed:
            quest_label.text = "المهمة: عد إلى البستاني"
        else:
            quest_label.text = "المهمة: اكتشف الكنز السري"
    _layout_garden_ui()

func _update_nearby_prompt() -> void:
    if not is_instance_valid(player):
        return
    if player.global_position.distance_to(garden_npc.global_position) < 4.0:
        return
    # Keep the HUD uncluttered; interaction button is always available.

func _interact_with_world() -> void:
    if not garden_active or interaction_cooldown > 0.0:
        return
    interaction_cooldown = 0.55
    var p := player.global_position
    if p.distance_to(garden_fountain.global_position) < INTERACT_DISTANCE:
        _use_fountain()
    elif p.distance_to(treasure_chest.global_position) < INTERACT_DISTANCE:
        _open_treasure_chest()
    elif p.distance_to(garden_npc.global_position) < INTERACT_DISTANCE:
        _talk_to_npc()
    elif p.distance_to(secret_gate.global_position) < INTERACT_DISTANCE:
        _open_secret_gate()
    elif p.distance_to(secret_treasure.global_position) < INTERACT_DISTANCE:
        _collect_secret_treasure()
    elif p.distance_to(Vector3(-15,0,-39)) < INTERACT_DISTANCE:
        show_message("بركة جميلة! استمع إلى صوت الماء.")
        _play_sfx("water")
    elif p.distance_to(Vector3(15,0,-32)) < INTERACT_DISTANCE:
        show_message("مكان رائع للراحة والنزهة!")
    else:
        show_message("اقترب من البستاني أو النافورة أو صندوق الكنز.")

func _use_fountain() -> void:
    if fountain_used:
        show_message("النافورة تتدفق بالماء.")
        _play_sfx("water")
        return
    fountain_used = true
    has_garden_key = true
    _spawn_sparkles(garden_fountain.global_position+Vector3(0,2.0,0))
    _play_sfx("key")
    _save_progress()
    show_message("وجدت المفتاح الذهبي داخل النافورة!")

func _open_treasure_chest() -> void:
    if chest_opened:
        show_message("لقد فتحت الصندوق من قبل.")
        return
    if not has_garden_key:
        show_message("الصندوق مقفل. ابحث عن المفتاح الذهبي قرب النافورة.")
        _play_sfx("locked")
        return
    chest_opened = true
    has_garden_key = false
    coin_count += 5
    if is_instance_valid(chest_lid):
        chest_lid.position.y += 0.48
        chest_lid.rotation.x = -0.45
    _spawn_sparkles(treasure_chest.global_position+Vector3(0,1.5,0))
    _play_sfx("treasure")
    _save_progress()
    update_coin_label()
    show_message("رائع! حصلت على خمس عملات من صندوق الكنز.")

func _talk_to_npc() -> void:
    if not npc_quest_started:
        npc_quest_started = true
        _save_progress()
        _play_sfx("dialog")
        show_message("البستاني: مرحباً يا يحيى! أحتاج البلورات السحرية الثلاث.")
    elif crystals_collected.size() < CRYSTAL_TOTAL:
        _play_sfx("dialog")
        show_message("البستاني: ابحث عن البلورات الثلاث. جمعت "+str(crystals_collected.size())+" من 3.")
    elif not npc_reward_claimed:
        npc_reward_claimed = true
        secret_area_unlocked = true
        coin_count += 10
        _save_progress()
        update_coin_label()
        _update_garden_ui()
        _play_sfx("quest")
        _spawn_sparkles(garden_npc.global_position+Vector3(0,1.5,0))
        show_message("أحسنت! مكافأتك عشر عملات، وقد فتحت البوابة السرية!")
    else:
        show_message("البستاني: أنت بطل الحديقة يا يحيى!")

func _open_secret_gate() -> void:
    if not secret_area_unlocked:
        show_message("أكمل مهمة البلورات الثلاث أولاً.")
        _play_sfx("locked")
        return
    if is_instance_valid(gate_door):
        gate_door.visible = false
    _play_sfx("unlock")
    _spawn_sparkles(secret_gate.global_position+Vector3(0,1.5,0))
    player.position = Vector3(22,0,-72)
    move_velocity = Vector2.ZERO
    show_message("دخلت المنطقة السرية! ابحث عن الكنز النادر.")

func _collect_secret_treasure() -> void:
    if not secret_area_unlocked:
        show_message("هذه المنطقة مغلقة.")
        return
    if secret_treasure_collected:
        show_message("جمعت هذا الكنز سابقاً.")
        return
    secret_treasure_collected = true
    coin_count += 20
    secret_treasure.visible = false
    _save_progress()
    update_coin_label()
    _play_sfx("treasure")
    _spawn_sparkles(secret_treasure.global_position+Vector3(0,1,0))
    show_message("كنز نادر! حصلت على عشرين عملة ذهبية!")

# ------------------------------------------------------------
# SAVE / LOAD
# ------------------------------------------------------------

func _load_progress() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    garden_unlocked = bool(cfg.get_value("world","garden_unlocked",false))
    coin_count = int(cfg.get_value("world","coin_count",coin_count))
    for v in cfg.get_value("world","collected_garden_coins",[]):
        collected_garden_coins.append(str(v))
    for v in cfg.get_value("world","crystals_collected",[]):
        crystals_collected.append(str(v))
    fountain_used = bool(cfg.get_value("world","fountain_used",false))
    has_garden_key = bool(cfg.get_value("world","has_garden_key",false))
    chest_opened = bool(cfg.get_value("world","chest_opened",false))
    npc_quest_started = bool(cfg.get_value("world","npc_quest_started",false))
    npc_reward_claimed = bool(cfg.get_value("world","npc_reward_claimed",false))
    secret_area_unlocked = bool(cfg.get_value("world","secret_area_unlocked",false))
    secret_treasure_collected = bool(cfg.get_value("world","secret_treasure_collected",false))

func _save_progress() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("world","garden_unlocked",garden_unlocked)
    cfg.set_value("world","coin_count",coin_count)
    cfg.set_value("world","collected_garden_coins",collected_garden_coins)
    cfg.set_value("world","crystals_collected",crystals_collected)
    cfg.set_value("world","fountain_used",fountain_used)
    cfg.set_value("world","has_garden_key",has_garden_key)
    cfg.set_value("world","chest_opened",chest_opened)
    cfg.set_value("world","npc_quest_started",npc_quest_started)
    cfg.set_value("world","npc_reward_claimed",npc_reward_claimed)
    cfg.set_value("world","secret_area_unlocked",secret_area_unlocked)
    cfg.set_value("world","secret_treasure_collected",secret_treasure_collected)
    var err := cfg.save(SAVE_PATH)
    if err != OK:
        push_warning("Yahya Adventures: save failed ("+str(err)+")")

# ------------------------------------------------------------
# SOUND SYSTEM - GENERATED LOCALLY, NO EXTRA AUDIO FILES
# ------------------------------------------------------------

func _setup_audio() -> void:
    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "YahyaSFX"
    sfx_player.volume_db = linear_to_db(master_volume)
    add_child(sfx_player)
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "GardenAmbience"
    ambience_player.volume_db = linear_to_db(master_volume*0.22)
    add_child(ambience_player)
    ambience_player.stream = _make_ambience_stream()
    ambience_player.finished.connect(_start_ambience)

func _start_ambience() -> void:
    if sound_enabled and garden_active and is_instance_valid(ambience_player) and not ambience_player.playing:
        ambience_player.play()

func _stop_audio() -> void:
    if is_instance_valid(ambience_player):
        ambience_player.stop()
    if is_instance_valid(sfx_player):
        sfx_player.stop()

func _update_ambient_sound(delta: float) -> void:
    ambience_timer += delta
    if ambience_timer > 17.0:
        ambience_timer = 0.0
        if sound_enabled and audio_rng.randf() < 0.55:
            _play_sfx("bird")

func _play_sfx(kind: String) -> void:
    if not sound_enabled or not is_instance_valid(sfx_player):
        return
    var f1 := 600.0
    var f2 := 900.0
    var duration := 0.16
    var volume := 0.42
    match kind:
        "coin":
            f1=880.0; f2=1320.0; duration=0.20
        "crystal":
            f1=660.0; f2=1760.0; duration=0.38
        "key":
            f1=520.0; f2=1040.0; duration=0.32
        "unlock":
            f1=330.0; f2=880.0; duration=0.55
        "locked":
            f1=170.0; f2=120.0; duration=0.22
        "treasure":
            f1=440.0; f2=1480.0; duration=0.65
        "quest":
            f1=523.0; f2=1046.0; duration=0.7
        "dialog":
            f1=440.0; f2=620.0; duration=0.12
        "water":
            f1=360.0; f2=510.0; duration=0.25
        "step":
            f1=105.0; f2=78.0; duration=0.075; volume=0.12
        "bird":
            f1=1450.0; f2=2100.0; duration=0.18
        _:
            f1=500.0; f2=700.0
    sfx_player.stream = _make_tone_stream(f1,f2,duration,volume)
    sfx_player.play()

func _make_tone_stream(freq_a: float, freq_b: float, duration: float, volume: float) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SFX_RATE
    stream.stereo = false
    var samples := int(SFX_RATE*duration)
    var bytes := PackedByteArray()
    bytes.resize(samples*2)
    for i in range(samples):
        var t := float(i)/float(SFX_RATE)
        var fade := minf(1.0,float(i)/500.0)*minf(1.0,float(samples-i)/1200.0)
        var blend := float(i)/maxf(1.0,float(samples-1))
        var freq := lerpf(freq_a,freq_b,blend)
        var wave := sin(TAU*freq*t)*0.72 + sin(TAU*freq*2.01*t)*0.18
        var sample := int(clampf(wave*volume*fade,-1.0,1.0)*32767.0)
        bytes[i*2] = sample & 0xff
        bytes[i*2+1] = (sample >> 8) & 0xff
    stream.data = bytes
    return stream

func _make_ambience_stream() -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SFX_RATE
    stream.stereo = false
    var samples := SFX_RATE*8
    var bytes := PackedByteArray()
    bytes.resize(samples*2)
    var phase := 0.0
    for i in range(samples):
        phase += TAU*0.19/float(SFX_RATE)
        var breeze := sin(phase)*0.014 + sin(phase*2.7)*0.006
        var bird_tone := sin(TAU*620.0*float(i)/float(SFX_RATE))*0.002
        var value := int(clampf(breeze+bird_tone,-1.0,1.0)*32767.0)
        bytes[i*2] = value & 0xff
        bytes[i*2+1] = (value >> 8) & 0xff
    stream.data = bytes
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = samples
    return stream

func _update_footsteps(delta: float) -> void:
    if move_velocity.length() < 1.0:
        footstep_timer = 0.0
        return
    footstep_timer += delta
    var interval := 0.34 if sprint_enabled else 0.48
    if footstep_timer >= interval:
        footstep_timer = 0.0
        # Subtle generated footstep taps; kept quiet on mobile.
        if sound_enabled:
            _play_sfx("step")

# ------------------------------------------------------------
# VISUAL EFFECTS - PARTICLES, GLOW, WATER AND LIGHT ANIMATION
# ------------------------------------------------------------

func _create_particle_effects() -> void:
    sparkle_particles = _new_particle_node("WorldSparkles",Color(0.4,0.85,1.0),36,0.85)
    coin_particles = _new_particle_node("CoinPickupBurst",Color(1.0,0.78,0.15),24,0.55)

func _new_particle_node(node_name: String, tint: Color, count: int, life: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = node_name
    p.amount = count
    p.lifetime = life
    p.one_shot = true
    p.emitting = false
    p.explosiveness = 0.92
    p.direction = Vector3(0,1,0)
    p.spread = 180.0
    p.gravity = Vector3(0,-2.8,0)
    p.initial_velocity_min = 1.0
    p.initial_velocity_max = 3.0
    p.scale_amount_min = 0.035
    p.scale_amount_max = 0.11
    var mesh := SphereMesh.new()
    mesh.radius = 0.08
    mesh.height = 0.16
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.emission_enabled = true
    mat.emission = tint
    mat.emission_energy_multiplier = 1.4
    p.mesh = mesh
    p.mesh.material = mat
    add_child(p)
    return p

func _spawn_sparkles(pos: Vector3) -> void:
    if not effects_enabled or not is_instance_valid(sparkle_particles):
        return
    sparkle_particles.global_position = pos
    sparkle_particles.restart()
    sparkle_particles.emitting = true

func _spawn_coin_burst(pos: Vector3) -> void:
    if not effects_enabled or not is_instance_valid(coin_particles):
        return
    coin_particles.global_position = pos
    coin_particles.restart()
    coin_particles.emitting = true

func _animate_garden(delta: float) -> void:
    if is_instance_valid(fountain_water):
        fountain_water.scale.x = 1.0+sin(world_time*2.2)*0.025
        fountain_water.scale.z = 1.0+cos(world_time*1.8)*0.025
    for i in range(garden_lights.size()):
        var lamp := garden_lights[i]
        if is_instance_valid(lamp):
            lamp.light_energy = 0.40+sin(world_time*1.4+float(i))*0.035

# ------------------------------------------------------------
# PROCEDURAL MESH HELPERS
# ------------------------------------------------------------

func _make_box(node_name: String, box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    item.mesh = mesh
    item.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.86
    item.material_override = mat
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(item)
    return item

func _make_sphere(node_name: String, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius*2.0
    item.mesh = mesh
    item.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.72
    item.material_override = mat
    add_child(item)
    return item

func _make_cylinder(node_name: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 24
    item.mesh = mesh
    item.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.55
    item.material_override = mat
    add_child(item)
    return item

func update_coin_label() -> void:
    var value := "العملات: "+str(coin_count)
    if is_instance_valid(responsive_coin_label):
        responsive_coin_label.text = value
    elif is_instance_valid(coin_label):
        coin_label.text = value
