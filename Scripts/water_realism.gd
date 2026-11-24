
extends "res://Scripts/visual_realism.gd"

# ============================================================
# YAHYA ADVENTURES - WATER REALISM V1
# Godot 4.4.1
# تحسين واقعية مياه البركة والنافورة
# ============================================================

var water_clock := 0.0
var water_ripples: Array[MeshInstance3D] = []
var water_glints: Array[MeshInstance3D] = []


func _ready() -> void:
    super._ready()
    call_deferred("_water_setup")


func _process(delta: float) -> void:
    super._process(delta)
    water_clock += delta
    _water_animate(delta)


func _water_setup() -> void:
    # سطح مياه البركة
    _water_add_surface(
        "PondRealisticSurface",
        Vector3(-15.0, 0.225, -39.0),
        3.55,
        Color(0.10, 0.48, 0.72, 0.52)
    )

    # سطح مياه النافورة
    _water_add_surface(
        "FountainRealisticSurface",
        Vector3(-8.0, 0.685, -31.0),
        1.68,
        Color(0.12, 0.58, 0.82, 0.58)
    )

    # تموجات البركة
    _water_add_ripple(
        Vector3(-15.0, 0.255, -39.0), 1.0, 0.22, 0.0
    )
    _water_add_ripple(
        Vector3(-16.1, 0.255, -38.5), 0.72, 0.17, 0.36
    )
    _water_add_ripple(
        Vector3(-14.0, 0.255, -39.8), 0.85, 0.19, 0.68
    )

    # تموجات النافورة
    _water_add_ripple(
        Vector3(-8.0, 0.715, -31.0), 0.60, 0.30, 0.18
    )
    _water_add_ripple(
        Vector3(-8.45, 0.715, -31.15), 0.42, 0.24, 0.57
    )

    _water_create_glints()

    print("Yahya Adventures: Water Realism V1 enabled.")


# ============================================================
# إنشاء سطح الماء
# ============================================================

func _water_add_surface(
    node_name: String,
    world_position: Vector3,
    radius: float,
    tint: Color
) -> void:

    var surface := MeshInstance3D.new()
    surface.name = node_name

    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = 0.018
    mesh.radial_segments = 48

    surface.mesh = mesh
    surface.position = world_position

    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness = 0.16
    material.metallic = 0.18
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    surface.material_override = material
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    add_child(surface)


# ============================================================
# إنشاء حلقات التموج
# ============================================================

func _water_add_ripple(
    world_position: Vector3,
    base_scale: float,
    speed: float,
    phase_offset: float
) -> void:

    var ripple := MeshInstance3D.new()
    ripple.name = "AnimatedWaterRipple"

    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.025
    mesh.outer_radius = 0.075
    mesh.rings = 16
    mesh.ring_segments = 8

    ripple.mesh = mesh
    ripple.position = world_position
    ripple.scale = Vector3.ONE * base_scale

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.72, 0.91, 1.0, 0.25)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    ripple.material_override = material
    ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    ripple.set_meta("base_scale", base_scale)
    ripple.set_meta("speed", speed)
    ripple.set_meta("phase_offset", phase_offset)

    add_child(ripple)
    water_ripples.append(ripple)


# ============================================================
# اللمعان الضوئي فوق الماء
# ============================================================

func _water_create_glints() -> void:

    var positions := [
        Vector3(-16.2, 0.29, -39.4),
        Vector3(-14.3, 0.29, -38.2),
        Vector3(-15.1, 0.29, -40.5),
        Vector3(-8.7, 0.75, -31.0),
        Vector3(-7.4, 0.75, -30.7)
    ]

    for i in range(positions.size()):

        var glint := MeshInstance3D.new()
        glint.name = "WaterLightGlint"

        var mesh := SphereMesh.new()
        mesh.radius = 0.045
        mesh.height = 0.09
        mesh.radial_segments = 8
        mesh.rings = 4

        glint.mesh = mesh
        glint.position = positions[i]

        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.78, 0.94, 1.0, 0.88)
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.emission_enabled = true
        material.emission = Color(0.25, 0.62, 0.92)

        glint.material_override = material
        glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

        glint.set_meta("origin", positions[i])
        glint.set_meta("phase", float(i) * 1.37)

        add_child(glint)
        water_glints.append(glint)


# ============================================================
# تحريك الماء والتموجات والانعكاسات
# ============================================================

func _water_animate(_delta: float) -> void:

    for ripple in water_ripples:

        if not is_instance_valid(ripple):
            continue

        var speed: float = float(ripple.get_meta("speed"))
        var offset: float = float(ripple.get_meta("phase_offset"))
        var base_scale: float = float(ripple.get_meta("base_scale"))

        var phase := fposmod(
            water_clock * speed + offset,
            1.0
        )

        ripple.scale = Vector3.ONE * base_scale * (
            0.55 + phase * 1.55
        )

        var material := ripple.material_override as StandardMaterial3D

        if material != null:
            material.albedo_color = Color(
                0.72,
                0.91,
                1.0,
                0.28 * (1.0 - phase)
            )

    # تحريك نقاط انعكاس الضوء
    for glint in water_glints:

        if not is_instance_valid(glint):
            continue

        var origin: Vector3 = glint.get_meta("origin")
        var phase: float = float(glint.get_meta("phase"))

        glint.position = origin + Vector3(
            sin(water_clock * 1.25 + phase) * 0.18,
            0.025 + sin(water_clock * 2.0 + phase) * 0.025,
            cos(water_clock * 1.05 + phase) * 0.14
        )
