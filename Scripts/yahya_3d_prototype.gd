
extends Node3D

# YAHYA ADVENTURES - 3D CHARACTER PROTOTYPE
# Godot 4.4.1
# مشهد اختبار مستقل - لا يستبدل الشخصية الأصلية

var character_root: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var camera: Camera3D

var elapsed := 0.0

const SKIN := Color(0.72, 0.49, 0.34)
const HAIR := Color(0.075, 0.045, 0.028)
const SHIRT := Color(0.10, 0.30, 0.78)
const SHIRT_LIGHT := Color(0.18, 0.43, 0.94)
const PANTS := Color(0.075, 0.095, 0.15)
const SHOE := Color(0.035, 0.035, 0.045)


func _ready() -> void:
    create_world()
    create_character()
    create_camera()
    create_ui()


func _process(delta: float) -> void:
    elapsed += delta

    character_root.position.y = sin(elapsed * 2.0) * 0.018

    left_arm.rotation.x = sin(elapsed * 1.7) * 0.035
    right_arm.rotation.x = -sin(elapsed * 1.7) * 0.035

    camera.position.x = 3.15 + sin(elapsed * 0.18) * 0.18
    camera.look_at(Vector3(0, 1.35, 0), Vector3.UP)


# WORLD

func create_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()

    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.055, 0.075, 0.12)

    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.79, 1.0)
    env.ambient_light_energy = 0.75

    world.environment = env
    add_child(world)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-38, -28, 0)
    light.light_energy = 1.55
    light.shadow_enabled = true
    add_child(light)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(12, 12)

    floor.mesh = floor_mesh
    floor.position.y = -0.04

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.10, 0.13, 0.19)
    floor.material_override = mat

    add_child(floor)


# CHARACTER

func create_character() -> void:
    character_root = Node3D.new()
    character_root.name = "Yahya3DPrototype"
    add_child(character_root)

    # LEGS

    left_leg = create_pivot(
        "LeftLeg",
        Vector3(-0.19, 0.88, 0)
    )
    character_root.add_child(left_leg)

    make_capsule(
        left_leg, "LeftTrouser",
        0.115, 0.78,
        Vector3(0, -0.39, 0),
        PANTS
    )

    make_box(
        left_leg, "LeftShoe",
        Vector3(0.25, 0.13, 0.39),
        Vector3(0, -0.79, 0.075),
        SHOE
    )

    right_leg = create_pivot(
        "RightLeg",
        Vector3(0.19, 0.88, 0)
    )
    character_root.add_child(right_leg)

    make_capsule(
        right_leg, "RightTrouser",
        0.115, 0.78,
        Vector3(0, -0.39, 0),
        PANTS
    )

    make_box(
        right_leg, "RightShoe",
        Vector3(0.25, 0.13, 0.39),
        Vector3(0, -0.79, 0.075),
        SHOE
    )

    # BODY

    make_capsule(
        character_root, "Torso",
        0.31, 0.82,
        Vector3(0, 1.48, 0),
        SHIRT
    )

    make_box(
        character_root, "ShirtFront",
        Vector3(0.43, 0.49, 0.035),
        Vector3(0, 1.48, 0.286),
        SHIRT_LIGHT
    )

    make_capsule(
        character_root, "Neck",
        0.105, 0.22,
        Vector3(0, 1.98, 0),
        SKIN
    )

    # ARMS

    left_arm = create_pivot(
        "LeftArm",
        Vector3(-0.39, 1.77, 0)
    )
    character_root.add_child(left_arm)

    make_capsule(
        left_arm, "LeftSleeve",
        0.125, 0.53,
        Vector3(0, -0.27, 0),
        SHIRT
    )

    make_capsule(
        left_arm, "LeftForearm",
        0.085, 0.43,
        Vector3(0, -0.70, 0),
        SKIN
    )

    make_sphere(
        left_arm, "LeftHand",
        0.105,
        Vector3(0, -0.94, 0),
        SKIN
    )

    right_arm = create_pivot(
        "RightArm",
        Vector3(0.39, 1.77, 0)
    )
    character_root.add_child(right_arm)

    make_capsule(
        right_arm, "RightSleeve",
        0.125, 0.53,
        Vector3(0, -0.27, 0),
        SHIRT
    )

    make_capsule(
        right_arm, "RightForearm",
        0.085, 0.43,
        Vector3(0, -0.70, 0),
        SKIN
    )

    make_sphere(
        right_arm, "RightHand",
        0.105,
        Vector3(0, -0.94, 0),
        SKIN
    )

    # HEAD

    make_sphere(
        character_root, "Head",
        0.34,
        Vector3(0, 2.30, 0),
        SKIN
    )

    make_sphere(
        character_root, "HairCap",
        0.355,
        Vector3(0, 2.48, -0.015),
        HAIR
    )

    make_sphere(
        character_root, "HairFront",
        0.20,
        Vector3(0, 2.49, 0.245),
        HAIR
    )

    make_sphere(
        character_root, "EarLeft",
        0.075,
        Vector3(-0.335, 2.29, 0),
        SKIN
    )

    make_sphere(
        character_root, "EarRight",
        0.075,
        Vector3(0.335, 2.29, 0),
        SKIN
    )

    # EYES

    var eye_color := Color(0.025, 0.02, 0.018)

    make_sphere(
        character_root, "EyeLeft",
        0.035,
        Vector3(-0.125, 2.34, 0.306),
        eye_color
    )

    make_sphere(
        character_root, "EyeRight",
        0.035,
        Vector3(0.125, 2.34, 0.306),
        eye_color
    )

    # NOSE

    make_sphere(
        character_root, "Nose",
        0.052,
        Vector3(0, 2.265, 0.335),
        SKIN
    )

    # MOUTH

    make_box(
        character_root, "Mouth",
        Vector3(0.105, 0.018, 0.018),
        Vector3(0, 2.19, 0.319),
        Color(0.20, 0.055, 0.045)
    )

    # SHIRT COLLAR

    make_sphere(
        character_root, "CollarLeft",
        0.075,
        Vector3(-0.105, 1.91, 0.245),
        Color(0.88, 0.90, 0.98)
    )

    make_sphere(
        character_root, "CollarRight",
        0.075,
        Vector3(0.105, 1.91, 0.245),
        Color(0.88, 0.90, 0.98)
    )

    # SHIRT BUTTONS

    for i in range(3):
        make_sphere(
            character_root,
            "ShirtButton%d" % i,
            0.022,
            Vector3(0, 1.64 - i * 0.14, 0.312),
            Color(0.92, 0.88, 0.70)
        )


# CAMERA

func create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "PreviewCamera"

    camera.position = Vector3(3.15, 2.75, 5.4)
    camera.fov = 42.0
    camera.current = true

    add_child(camera)

    camera.look_at(
        Vector3(0, 1.35, 0),
        Vector3.UP
    )


# UI

func create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var label := Label.new()

    label.text = "YAHYA ADVENTURES | 3D CHARACTER\nنموذج هندسي أولي - ليس الشكل النهائي"

    label.position = Vector2(22, 20)

    label.add_theme_font_size_override(
        "font_size", 22
    )

    label.add_theme_color_override(
        "font_color",
        Color(0.94, 0.96, 1.0)
    )

    layer.add_child(label)


# HELPERS

func create_pivot(
    node_name: String,
    pos: Vector3
) -> Node3D:

    var node := Node3D.new()
    node.name = node_name
    node.position = pos

    return node


func create_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.72

    return mat


func make_capsule(
    parent: Node3D,
    node_name: String,
    radius: float,
    height: float,
    pos: Vector3,
    color: Color
) -> MeshInstance3D:

    var item := MeshInstance3D.new()
    item.name = node_name

    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 16
    mesh.rings = 8

    item.mesh = mesh
    item.position = pos
    item.material_override = create_material(color)

    parent.add_child(item)

    return item


func make_sphere(
    parent: Node3D,
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
    mesh.radial_segments = 20
    mesh.rings = 12

    item.mesh = mesh
    item.position = pos
    item.material_override = create_material(color)

    parent.add_child(item)

    return item


func make_box(
    parent: Node3D,
    node_name: String,
    size: Vector3,
    pos: Vector3,
    color: Color
) -> MeshInstance3D:

    var item := MeshInstance3D.new()
    item.name = node_name

    var mesh := BoxMesh.new()
    mesh.size = size

    item.mesh = mesh
    item.position = pos
    item.material_override = create_material(color)

    parent.add_child(item)

    return item
