extends "res://Scripts/creature_update.gd"

# YAHYA ADVENTURES - 100 REALISM UPGRADES
# Godot 4.4.1 | Procedural 3D character, trees, foliage and natural detail.
# Mobile-conscious geometry; no external plugins or runtime downloads.

const NATURE_DETAIL_COUNT := 100
const REALISM_SEED := 20261125

var realism_rng := RandomNumberGenerator.new()
var realism_leaf_nodes: Array[Node3D] = []
var realism_leaf_phase: Array[float] = []
var realism_elapsed := 0.0
var realism_body: Node3D
var realism_left_arm: Node3D
var realism_right_arm: Node3D
var realism_left_leg: Node3D
var realism_right_leg: Node3D
var realism_detail_count := 0


func _ready() -> void:
    super._ready()
    realism_rng.seed = REALISM_SEED
    _create_100_nature_details()


func _process(delta: float) -> void:
    super._process(delta)
    realism_elapsed += delta
    _animate_realism_foliage(delta)


# -------------------------------------------------------------------
# 1. PLAYABLE HERO: replace the flat billboard with a complete 3D body
# -------------------------------------------------------------------

func create_player() -> void:
    super.create_player()

    if is_instance_valid(character_sprite):
        character_sprite.queue_free()
        character_sprite = null

    realism_body = Node3D.new()
    realism_body.name = "YahyaRealistic3DCharacter"
    player.add_child(realism_body)

    var skin := Color(0.66, 0.43, 0.31)
    var skin_light := Color(0.78, 0.55, 0.41)
    var hair := Color(0.055, 0.035, 0.025)
    var shirt := Color(0.075, 0.25, 0.66)
    var shirt_light := Color(0.13, 0.38, 0.86)
    var pants := Color(0.075, 0.09, 0.13)
    var shoe := Color(0.025, 0.03, 0.04)

    # Shoes, trousers and articulated leg pivots.
    realism_left_leg = _realism_pivot("LeftLegPivot", Vector3(-0.18, 0.84, 0.0), realism_body)
    _realism_capsule(realism_left_leg, "LeftTrouser", 0.125, 0.76, Vector3(0, -0.37, 0), pants)
    _realism_box(realism_left_leg, "LeftShoe", Vector3(0.25, 0.14, 0.39), Vector3(0, -0.76, 0.075), shoe)
    _realism_sphere(realism_left_leg, "LeftShoeToe", 0.12, Vector3(0, -0.73, 0.20), Color(0.10, 0.11, 0.13))

    realism_right_leg = _realism_pivot("RightLegPivot", Vector3(0.18, 0.84, 0.0), realism_body)
    _realism_capsule(realism_right_leg, "RightTrouser", 0.125, 0.76, Vector3(0, -0.37, 0), pants)
    _realism_box(realism_right_leg, "RightShoe", Vector3(0.25, 0.14, 0.39), Vector3(0, -0.76, 0.075), shoe)
    _realism_sphere(realism_right_leg, "RightShoeToe", 0.12, Vector3(0, -0.73, 0.20), Color(0.10, 0.11, 0.13))

    # Torso, shirt panels, collar, seams and belt.
    _realism_capsule(realism_body, "ShirtTorso", 0.32, 0.91, Vector3(0, 1.42, 0), shirt)
    _realism_box(realism_body, "ShirtFrontPanel", Vector3(0.42, 0.52, 0.035), Vector3(0, 1.43, 0.294), shirt_light)
    _realism_box(realism_body, "WaistBand", Vector3(0.49, 0.10, 0.31), Vector3(0, 0.98, 0), Color(0.035, 0.045, 0.065))
    _realism_box(realism_body, "BeltBuckle", Vector3(0.10, 0.10, 0.035), Vector3(0, 0.98, 0.17), Color(0.88, 0.67, 0.23))
    _realism_capsule(realism_body, "Neck", 0.105, 0.24, Vector3(0, 1.93, 0), skin_light)
    _realism_sphere(realism_body, "CollarLeft", 0.09, Vector3(-0.13, 1.86, 0.23), Color(0.90, 0.92, 0.98))
    _realism_sphere(realism_body, "CollarRight", 0.09, Vector3(0.13, 1.86, 0.23), Color(0.90, 0.92, 0.98))

    # Arms, sleeves, forearms and hands.
    realism_left_arm = _realism_pivot("LeftArmPivot", Vector3(-0.39, 1.73, 0), realism_body)
    _realism_capsule(realism_left_arm, "LeftSleeve", 0.14, 0.58, Vector3(0, -0.25, 0), shirt)
    _realism_capsule(realism_left_arm, "LeftForearm", 0.09, 0.43, Vector3(0, -0.70, 0), skin)
    _realism_sphere(realism_left_arm, "LeftHand", 0.105, Vector3(0, -0.96, 0.015), skin_light)

    realism_right_arm = _realism_pivot("RightArmPivot", Vector3(0.39, 1.73, 0), realism_body)
    _realism_capsule(realism_right_arm, "RightSleeve", 0.14, 0.58, Vector3(0, -0.25, 0), shirt)
    _realism_capsule(realism_right_arm, "RightForearm", 0.09, 0.43, Vector3(0, -0.70, 0), skin)
    _realism_sphere(realism_right_arm, "RightHand", 0.105, Vector3(0, -0.96, 0.015), skin_light)

    # Head shape, ears, hair cap and layered fringe.
    _realism_sphere(realism_body, "Head", 0.34, Vector3(0, 2.29, 0), skin_light, Vector3(0.92, 1.08, 0.88))
    _realism_sphere(realism_body, "HairCap", 0.35, Vector3(0, 2.48, -0.015), hair, Vector3(1.0, 0.62, 0.92))
    _realism_sphere(realism_body, "HairFringe", 0.20, Vector3(0, 2.49, 0.245), hair, Vector3(1.15, 0.45, 0.55))
    _realism_sphere(realism_body, "HairLeftLock", 0.12, Vector3(-0.24, 2.43, 0.12), hair, Vector3(0.8, 1.3, 0.8))
    _realism_sphere(realism_body, "HairRightLock", 0.12, Vector3(0.24, 2.43, 0.12), hair, Vector3(0.8, 1.3, 0.8))
    _realism_sphere(realism_body, "LeftEar", 0.075, Vector3(-0.32, 2.28, 0), skin)
    _realism_sphere(realism_body, "RightEar", 0.075, Vector3(0.32, 2.28, 0), skin)

    # Eyes, pupils, brows, nose and smile, all separate 3D meshes.
    for side in [-1.0, 1.0]:
        _realism_sphere(realism_body, "EyeWhite", 0.052, Vector3(side * 0.12, 2.34, 0.292), Color(0.97, 0.96, 0.91))
        _realism_sphere(realism_body, "EyePupil", 0.026, Vector3(side * 0.12, 2.34, 0.337), Color(0.035, 0.025, 0.02))
        _realism_box(realism_body, "Eyebrow", Vector3(0.105, 0.025, 0.025), Vector3(side * 0.12, 2.415, 0.30), hair)
    _realism_sphere(realism_body, "Nose", 0.052, Vector3(0, 2.265, 0.335), skin)
    _realism_box(realism_body, "Smile", Vector3(0.105, 0.018, 0.018), Vector3(0, 2.19, 0.315), Color(0.25, 0.065, 0.055))

    # Clothing buttons and subtle sleeve cuffs.
    for i in range(3):
        _realism_sphere(realism_body, "ShirtButton", 0.023, Vector3(0, 1.64 - float(i) * 0.14, 0.318), Color(0.92, 0.84, 0.60))
    _realism_box(realism_left_arm, "LeftCuff", Vector3(0.17, 0.07, 0.17), Vector3(0, -0.48, 0), shirt_light)
    _realism_box(realism_right_arm, "RightCuff", Vector3(0.17, 0.07, 0.17), Vector3(0, -0.48, 0), shirt_light)


func animate_character(delta: float) -> void:
    if not is_instance_valid(realism_body):
        super.animate_character(delta)
        return

    var moving := move_velocity.length() > 0.18
    if moving:
        walk_time += delta * (13.0 if sprint_enabled else 9.5)
        var swing := sin(walk_time)
        realism_left_leg.rotation.x = swing * (0.58 if sprint_enabled else 0.43)
        realism_right_leg.rotation.x = -swing * (0.58 if sprint_enabled else 0.43)
        realism_left_arm.rotation.x = -swing * 0.42
        realism_right_arm.rotation.x = swing * 0.42
        realism_body.position.y = 0.035 + absf(swing) * (0.055 if sprint_enabled else 0.035)
    else:
        var relax := minf(1.0, delta * 8.0)
        realism_left_leg.rotation.x = lerpf(realism_left_leg.rotation.x, 0.0, relax)
        realism_right_leg.rotation.x = lerpf(realism_right_leg.rotation.x, 0.0, relax)
        realism_left_arm.rotation.x = lerpf(realism_left_arm.rotation.x, 0.0, relax)
        realism_right_arm.rotation.x = lerpf(realism_right_arm.rotation.x, 0.0, relax)
        realism_body.position.y = lerpf(realism_body.position.y, 0.0, relax)
        realism_body.rotation.z = sin(realism_elapsed * 1.2) * 0.008


# -------------------------------------------------------------------
# 2. TREES: layered canopy, visible branches, roots and natural color
# -------------------------------------------------------------------

func _create_tree(pos: Vector3) -> void:
    super._create_tree(pos)
    var trunk_mat := Color(0.24, 0.125, 0.065)
    var branch_mat := Color(0.31, 0.17, 0.085)
    var variation := sin(pos.x * 1.7 + pos.z * 0.31)

    _realism_cylinder(self, "TreeRootFlare", 0.47, 0.25, pos + Vector3(0, 0.15, 0), trunk_mat)
    for angle in range(4):
        var a := float(angle) * PI * 0.5 + variation
        var root := _realism_capsule(self, "ExposedTreeRoot", 0.12, 1.05, pos + Vector3(cos(a) * 0.42, 0.16, sin(a) * 0.42), branch_mat)
        root.rotation.y = a
        root.rotation.z = cos(a) * 0.38

    for branch_index in range(3):
        var side := -1.0 if branch_index % 2 == 0 else 1.0
        var branch := _realism_cylinder(self, "TreeBranch", 0.13, 1.65, pos + Vector3(side * (0.52 + float(branch_index) * 0.08), 2.65 + float(branch_index) * 0.45, 0), branch_mat)
        branch.rotation.z = side * deg_to_rad(38.0 + float(branch_index) * 7.0)

    var leaf_colors := [
        Color(0.075, 0.28, 0.085), Color(0.10, 0.36, 0.11),
        Color(0.16, 0.43, 0.14), Color(0.22, 0.48, 0.17)
    ]
    for i in range(7):
        var angle := float(i) * TAU / 7.0 + variation
        var radius := 1.05 + 0.22 * sin(float(i) * 2.3 + variation)
        var leaf := _realism_sphere(self, "DetailedTreeLeafCluster", 1.0,
            pos + Vector3(cos(angle) * radius, 3.75 + 0.48 * sin(float(i) * 1.9), sin(angle) * radius),
            leaf_colors[i % leaf_colors.size()],
            Vector3(0.85 + 0.12 * sin(float(i)), 0.72 + 0.14 * cos(float(i)), 0.82))
        leaf.rotation.y = angle
        realism_leaf_nodes.append(leaf)
        realism_leaf_phase.append(float(i) * 0.7 + pos.x * 0.11)


func _create_bush(pos: Vector3) -> void:
    super._create_bush(pos)
    var colors := [Color(0.08, 0.30, 0.09), Color(0.13, 0.40, 0.12), Color(0.19, 0.46, 0.14)]
    for i in range(5):
        var angle := float(i) * TAU / 5.0
        var leaf := _realism_sphere(self, "BushLeafCluster", 0.48,
            pos + Vector3(cos(angle) * 0.48, 0.62 + 0.12 * sin(angle * 2.0), sin(angle) * 0.40),
            colors[i % colors.size()], Vector3(1.0, 0.82, 0.95))
        realism_leaf_nodes.append(leaf)
        realism_leaf_phase.append(float(i) * 0.8 + pos.z * 0.1)


func _create_flower_bed(pos: Vector3) -> void:
    super._create_flower_bed(pos)
    var colors := [Color(0.95, 0.22, 0.28), Color(1.0, 0.72, 0.16), Color(0.72, 0.32, 0.88), Color(0.98, 0.91, 0.72)]
    for i in range(8):
        var x := pos.x - 1.25 + float(i) * 0.36
        var stem := _realism_cylinder(self, "FlowerStem", 0.018, 0.38, Vector3(x, 0.31, pos.z), Color(0.12, 0.34, 0.10))
        stem.rotation.z = sin(float(i) * 1.7) * 0.16
        _realism_sphere(self, "FlowerPetalCenter", 0.075, Vector3(x, 0.53, pos.z), colors[i % colors.size()], Vector3(1.0, 0.8, 1.0))
        for petal in range(4):
            var a := float(petal) * TAU / 4.0
            _realism_sphere(self, "FlowerPetal", 0.055, Vector3(x + cos(a) * 0.085, 0.53 + sin(a) * 0.04, pos.z + sin(a) * 0.085), colors[i % colors.size()])


# -------------------------------------------------------------------
# 3. GARDEN HELPER: add a face, hands, shoes and clothing details
# -------------------------------------------------------------------

func _create_garden_objects() -> void:
    super._create_garden_objects()
    if not is_instance_valid(garden_npc):
        return
    var skin := Color(0.68, 0.46, 0.33)
    var dark := Color(0.055, 0.035, 0.025)
    for side in [-1.0, 1.0]:
        _realism_sphere(garden_npc, "NPC_EyeWhite", 0.055, Vector3(side * 0.12, 1.94, 0.285), Color(0.98, 0.97, 0.91))
        _realism_sphere(garden_npc, "NPC_Pupil", 0.027, Vector3(side * 0.12, 1.94, 0.33), dark)
        _realism_sphere(garden_npc, "NPC_Shoe", 0.16, Vector3(side * 0.22, 0.12, 0.12), Color(0.045, 0.04, 0.035), Vector3(1.0, 0.6, 1.4))
        _realism_capsule(garden_npc, "NPC_LowerLeg", 0.12, 0.55, Vector3(side * 0.22, 0.38, 0), Color(0.12, 0.14, 0.20))
        var arm := _realism_capsule(garden_npc, "NPC_Arm", 0.12, 0.75, Vector3(side * 0.48, 1.05, 0), Color(0.18, 0.34, 0.68))
        arm.rotation.z = side * deg_to_rad(16.0)
        _realism_sphere(garden_npc, "NPC_Hand", 0.11, Vector3(side * 0.53, 0.68, 0), skin)
    _realism_sphere(garden_npc, "NPC_Nose", 0.05, Vector3(0, 1.88, 0.31), skin)
    _realism_box(garden_npc, "NPC_Smile", Vector3(0.11, 0.018, 0.018), Vector3(0, 1.82, 0.30), Color(0.25, 0.06, 0.05))
    _realism_box(garden_npc, "NPC_ShirtTrim", Vector3(0.48, 0.08, 0.39), Vector3(0, 1.15, 0.01), Color(0.92, 0.75, 0.25))


# -------------------------------------------------------------------
# 4. ONE HUNDRED additional natural detail clusters around the garden
# -------------------------------------------------------------------

func _create_100_nature_details() -> void:
    # Build the extra world details gradually so Android can render the
    # intro menu before the full garden decoration is created.
    call_deferred("_create_100_nature_details_in_batches")


func _create_100_nature_details_in_batches() -> void:
    realism_rng.seed = REALISM_SEED
    for i in range(NATURE_DETAIL_COUNT):
        var x := realism_rng.randf_range(-26.0, 26.0)
        var z := realism_rng.randf_range(-96.0, -12.0)
        # Keep the main stone walkway and central play space readable.
        if x > 1.0 and x < 6.0:
            x = -7.0 - realism_rng.randf_range(0.0, 5.0)
        var p := Vector3(x, 0.0, z)
        var kind := i % 10
        if kind < 5:
            _create_grass_clump(p, i)
        elif kind < 8:
            _create_natural_rock(p, i)
        else:
            _create_wildflower_cluster(p, i)
        realism_detail_count += 1

        # Limit per-frame object creation to avoid a long black/loading screen.
        if i % 5 == 4:
            await get_tree().process_frame

    print("Yahya Adventures: 100 natural detail groups created in batches.")


func _create_grass_clump(pos: Vector3, index: int) -> void:
    var greens := [Color(0.18, 0.39, 0.12), Color(0.25, 0.46, 0.15), Color(0.32, 0.48, 0.17)]
    for blade in range(3):
        var item := _realism_capsule(self, "GrassBlade_%03d" % index, 0.035, 0.48 + realism_rng.randf() * 0.25,
            pos + Vector3((float(blade) - 1.0) * 0.11, 0.22, realism_rng.randf_range(-0.08, 0.08)),
            greens[(index + blade) % greens.size()])
        item.rotation.z = (float(blade) - 1.0) * 0.28
        item.rotation.x = realism_rng.randf_range(-0.12, 0.12)


func _create_natural_rock(pos: Vector3, index: int) -> void:
    var stone_colors := [Color(0.36, 0.37, 0.34), Color(0.45, 0.43, 0.38), Color(0.29, 0.31, 0.30)]
    var rock := _realism_sphere(self, "GardenStone_%03d" % index, 0.42,
        pos + Vector3(0, 0.18, 0), stone_colors[index % stone_colors.size()],
        Vector3(realism_rng.randf_range(0.55, 1.2), realism_rng.randf_range(0.35, 0.65), realism_rng.randf_range(0.55, 1.1)))
    rock.rotation.y = realism_rng.randf_range(0.0, TAU)


func _create_wildflower_cluster(pos: Vector3, index: int) -> void:
    var petal_colors := [Color(0.95, 0.30, 0.34), Color(1.0, 0.78, 0.20), Color(0.78, 0.45, 0.90), Color(0.96, 0.92, 0.78)]
    var color: Color = petal_colors[index % petal_colors.size()]
    for flower in range(3):
        var offset := Vector3((float(flower) - 1.0) * 0.16, 0.0, realism_rng.randf_range(-0.12, 0.12))
        _realism_cylinder(self, "WildflowerStem", 0.014, 0.32, pos + offset + Vector3(0, 0.16, 0), Color(0.12, 0.34, 0.10))
        _realism_sphere(self, "WildflowerBloom", 0.075, pos + offset + Vector3(0, 0.36, 0), color, Vector3(1.0, 0.65, 1.0))


# -------------------------------------------------------------------
# 5. Wind sway and reusable 3D mesh/material builders
# -------------------------------------------------------------------

func _animate_realism_foliage(delta: float) -> void:
    var count := mini(realism_leaf_nodes.size(), realism_leaf_phase.size())
    for i in range(count):
        var leaf := realism_leaf_nodes[i]
        if not is_instance_valid(leaf):
            continue
        var target := sin(realism_elapsed * 1.25 + realism_leaf_phase[i]) * 0.025
        leaf.rotation.z = lerpf(leaf.rotation.z, target, minf(1.0, delta * 2.0))


func _realism_pivot(node_name: String, pos: Vector3, parent: Node3D) -> Node3D:
    var node := Node3D.new()
    node.name = node_name
    node.position = pos
    parent.add_child(node)
    return node


func _realism_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    return material


func _realism_mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, color: Color, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = node_name
    item.mesh = mesh
    item.position = pos
    item.scale = scale_value
    item.material_override = _realism_material(color)
    # Small decorative meshes do not need individual shadow maps on mobile.
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item


func _realism_sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 10
    return _realism_mesh(parent, node_name, mesh, pos, color, scale_value)


func _realism_capsule(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    mesh.rings = 6
    return _realism_mesh(parent, node_name, mesh, pos, color)


func _realism_cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius * 0.82
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    return _realism_mesh(parent, node_name, mesh, pos, color)


func _realism_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _realism_mesh(parent, node_name, mesh, pos, color)
