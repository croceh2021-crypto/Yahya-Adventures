
extends "res://Scripts/music_system.gd"

# ============================================================
# YAHYA ADVENTURES - REALISTIC WORLD V1
# Godot 4.4.1
# Visual enhancement layer - preserves existing game systems
# ============================================================

const VISUAL_GRASS_COUNT := 850
const VISUAL_STONE_COUNT := 190

var visual_rng := RandomNumberGenerator.new()
var visual_grass_material: StandardMaterial3D
var visual_stone_material: StandardMaterial3D


func _ready() -> void:
    super._ready()
    visual_rng.randomize()
    call_deferred("_visual_apply")


# ============================================================
# MAIN VISUAL SETUP
# ============================================================

func _visual_apply() -> void:
    _visual_improve_environment()
    _visual_improve_lighting()
    _visual_improve_ground()
    _visual_improve_trees()
    _visual_create_grass()
    _visual_create_path_stones()

    print("Yahya Adventures: Realistic World V1 enabled.")


# ============================================================
# SKY AND ATMOSPHERE
# ============================================================

func _visual_improve_environment() -> void:
    var world := get_node_or_null("WorldEnvironment") as WorldEnvironment

    if world == null:
        push_warning("Visual V1: WorldEnvironment not found.")
        return

    var env := world.environment

    if env == null:
        env = Environment.new()
        world.environment = env

    var sky_material := ProceduralSkyMaterial.new()

    sky_material.sky_top_color = Color(0.12, 0.30, 0.55)
    sky_material.sky_horizon_color = Color(0.68, 0.79, 0.88)
    sky_material.ground_bottom_color = Color(0.16, 0.22, 0.15)
    sky_material.ground_horizon_color = Color(0.55, 0.62, 0.52)
    sky_material.sun_angle_max = 24.0
    sky_material.sun_curve = 0.12

    var sky := Sky.new()
    sky.sky_material = sky_material

    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.80, 0.96)
    env.ambient_light_energy = 0.85
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    env.fog_enabled = true
    env.fog_light_color = Color(0.65, 0.76, 0.84)
    env.fog_density = 0.0018
    env.fog_sun_scatter = 0.12


# ============================================================
# SUNLIGHT AND SHADOWS
# ============================================================

func _visual_improve_lighting() -> void:
    var sun := get_node_or_null("GardenSunlight") as DirectionalLight3D

    if sun == null:
        sun = DirectionalLight3D.new()
        sun.name = "GardenSunlight"
        add_child(sun)

    sun.rotation_degrees = Vector3(-43.0, -28.0, 0.0)
    sun.light_color = Color(1.0, 0.94, 0.82)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    sun.shadow_bias = 0.035
    sun.shadow_normal_bias = 1.0
    sun.directional_shadow_max_distance = 65.0


# ============================================================
# GROUND MATERIALS
# ============================================================

func _visual_improve_ground() -> void:
    var ground := get_node_or_null("GardenGround") as MeshInstance3D

    if is_instance_valid(ground):
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.25, 0.43, 0.19)
        material.roughness = 1.0
        material.metallic = 0.0
        ground.material_override = material

    var path := get_node_or_null("MainStoneWalkway") as MeshInstance3D

    if is_instance_valid(path):
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.58, 0.54, 0.46)
        material.roughness = 0.94
        material.metallic = 0.0
        path.material_override = material

    visual_grass_material = StandardMaterial3D.new()
    visual_grass_material.albedo_color = Color(0.34, 0.58, 0.22)
    visual_grass_material.roughness = 1.0
    visual_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    visual_grass_material.vertex_color_use_as_albedo = true

    visual_stone_material = StandardMaterial3D.new()
    visual_stone_material.albedo_color = Color(0.65, 0.61, 0.53)
    visual_stone_material.roughness = 0.96
    visual_stone_material.vertex_color_use_as_albedo = true


# ============================================================
# TREE DETAILS
# ============================================================

func _visual_improve_trees() -> void:
    var leaf_colors := [
        Color(0.12, 0.37, 0.13),
        Color(0.17, 0.43, 0.15),
        Color(0.22, 0.48, 0.17),
        Color(0.10, 0.31, 0.12)
    ]

    for child in get_children():
        if child is not MeshInstance3D:
            continue

        if child.name != "TreeTrunk":
            continue

        var trunk := child as MeshInstance3D
        var p := trunk.position

        for i in range(3):
            var leaf := MeshInstance3D.new()
            leaf.name = "RealisticTreeFoliage"

            var mesh := SphereMesh.new()
            mesh.radius = 1.0
            mesh.height = 1.65
            mesh.radial_segments = 12
            mesh.rings = 8

            leaf.mesh = mesh

            var offset := Vector3(
                visual_rng.randf_range(-0.95, 0.95),
                visual_rng.randf_range(3.6, 4.8),
                visual_rng.randf_range(-0.75, 0.75)
            )

            leaf.position = p + offset

            var material := StandardMaterial3D.new()
            material.albedo_color = leaf_colors[
                visual_rng.randi_range(0, leaf_colors.size() - 1)
            ]
            material.roughness = 0.92

            leaf.material_override = material
            leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

            add_child(leaf)


# ============================================================
# GRASS - MULTIMESH FOR MOBILE PERFORMANCE
# ============================================================

func _visual_create_grass() -> void:
    var grass_mesh := QuadMesh.new()
    grass_mesh.size = Vector2(0.16, 0.38)
    grass_mesh.material = visual_grass_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = grass_mesh
    multi.instance_count = VISUAL_GRASS_COUNT

    var index := 0

    for i in range(VISUAL_GRASS_COUNT):
        var x := visual_rng.randf_range(-28.0, 28.0)
        var z := visual_rng.randf_range(-98.0, -9.0)

        # Keep the main walkway clear.
        if x > 1.1 and x < 5.9:
            x += 5.5 if x < 3.5 else -5.5

        # Keep the pond area clear.
        if Vector2(x + 15.0, z + 39.0).length() < 4.8:
            x += 6.0

        var height := visual_rng.randf_range(0.65, 1.25)
        var width := visual_rng.randf_range(0.7, 1.35)
        var angle := visual_rng.randf_range(0.0, TAU)

        var basis := Basis(Vector3.UP, angle)
        basis = basis.scaled(Vector3(width, height, 1.0))

        var transform := Transform3D(
            basis,
            Vector3(x, 0.10, z)
        )

        multi.set_instance_transform(index, transform)

        var tint := Color(
            visual_rng.randf_range(0.75, 1.0),
            visual_rng.randf_range(0.78, 1.0),
            visual_rng.randf_range(0.70, 0.95),
            1.0
        )

        multi.set_instance_color(index, tint)
        index += 1

    var grass_node := MultiMeshInstance3D.new()
    grass_node.name = "RealisticGrass"
    grass_node.multimesh = multi
    grass_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    grass_node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

    add_child(grass_node)


# ============================================================
# STONE PATH DETAILS
# ============================================================

func _visual_create_path_stones() -> void:
    var stone_mesh := BoxMesh.new()
    stone_mesh.size = Vector3(0.78, 0.055, 0.52)
    stone_mesh.material = visual_stone_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = stone_mesh
    multi.instance_count = VISUAL_STONE_COUNT

    for i in range(VISUAL_STONE_COUNT):
        var x := visual_rng.randf_range(1.55, 5.45)
        var z := visual_rng.randf_range(-96.0, -10.0)

        var rotation := visual_rng.randf_range(-0.10, 0.10)
        var scale_x := visual_rng.randf_range(0.75, 1.2)
        var scale_z := visual_rng.randf_range(0.75, 1.15)

        var basis := Basis(Vector3.UP, rotation)
        basis = basis.scaled(Vector3(scale_x, 1.0, scale_z))

        var transform := Transform3D(
            basis,
            Vector3(x, 0.105, z)
        )

        multi.set_instance_transform(i, transform)

        var shade := visual_rng.randf_range(0.82, 1.08)

        multi.set_instance_color(
            i,
            Color(shade, shade, shade * 0.96, 1.0)
        )

    var stones := MultiMeshInstance3D.new()
    stones.name = "RealisticPathStones"
    stones.multimesh = multi
    stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stones.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

    add_child(stones)
