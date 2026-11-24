
extends Node3D

# YAHYA ADVENTURES - CAMERA PERSPECTIVE UPDATE
# Godot 4.4.1

const PLAYER_SPEED := 4.8
const PLAYER_ACCELERATION := 16.0
const PLAYER_FRICTION := 20.0
const ROOM_LIMIT := 5.25
const COIN_DISTANCE := 0.95
const YAHYA_TEXTURE_PATH := "res://Assets/yahya_character.png"

# CAMERA SETTINGS
const CAMERA_OFFSET := Vector3(0, 5.3, 7.8)
const CAMERA_SMOOTHING := 6.5
const CAMERA_LOOK_AHEAD := 0.55
const CAMERA_TARGET_HEIGHT := 1.15

var player: Node3D
var camera: Camera3D
var character_sprite: Sprite3D
var coins: Array[MeshInstance3D] = []

var coin_count := 0
var move_vector := Vector2.ZERO
var move_velocity := Vector2.ZERO

var coin_label: Label
var message_label: Label
var door_mesh: MeshInstance3D

var door_open := false
var door_open_amount := 0.0
var walk_time := 0.0
var message_timer := 0.0


func _ready() -> void:
    create_environment()
    create_room()
    create_player()
    create_camera()
    create_ui()
    update_coin_label()


func _process(delta: float) -> void:
    move_player(delta)
    follow_camera(delta)
    animate_character(delta)
    animate_coins(delta)
    collect_coins()
    check_door(delta)

    if message_timer > 0.0:
        message_timer -= delta

        if message_timer <= 0.0 and not door_open:
            message_label.text = "استكشف الغرفة واجمع العملات الذهبية"


# ENVIRONMENT

func create_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()

    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.48, 0.67, 0.83)

    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.88, 0.88, 0.96)
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)


# ROOM

func create_room() -> void:

    make_box("Floor",
        Vector3(12, 0.3, 12),
        Vector3(0, -0.2, 0),
        Color(0.68, 0.48, 0.32))

    make_box("BackWall",
        Vector3(12, 3.8, 0.25),
        Vector3(0, 1.7, -6),
        Color(0.91, 0.79, 0.70))

    make_box("LeftWall",
        Vector3(0.25, 3.8, 12),
        Vector3(-6, 1.7, 0),
        Color(0.79, 0.69, 0.78))

    make_box("RightWall",
        Vector3(0.25, 3.8, 12),
        Vector3(6, 1.7, 0),
        Color(0.78, 0.72, 0.84))

    # FLOOR BORDERS

    make_box("FloorBorderBack",
        Vector3(11.7, 0.08, 0.12),
        Vector3(0, 0, -5.78),
        Color(0.36, 0.20, 0.12))

    make_box("FloorBorderFront",
        Vector3(11.7, 0.08, 0.12),
        Vector3(0, 0, 5.78),
        Color(0.36, 0.20, 0.12))

    make_box("FloorBorderLeft",
        Vector3(0.12, 0.08, 11.7),
        Vector3(-5.78, 0, 0),
        Color(0.36, 0.20, 0.12))

    make_box("FloorBorderRight",
        Vector3(0.12, 0.08, 11.7),
        Vector3(5.78, 0, 0),
        Color(0.36, 0.20, 0.12))

    # RUG

    make_box("Rug",
        Vector3(5.0, 0.06, 3.2),
        Vector3(0, 0, 0.8),
        Color(0.52, 0.12, 0.22))

    make_box("RugInner",
        Vector3(4.55, 0.025, 2.75),
        Vector3(0, 0.045, 0.8),
        Color(0.72, 0.38, 0.34))

    # DOOR FRAME

    make_box("DoorFrameLeft",
        Vector3(0.13, 2.85, 0.24),
        Vector3(2.62, 1.22, -5.72),
        Color(0.25, 0.12, 0.06))

    make_box("DoorFrameRight",
        Vector3(0.13, 2.85, 0.24),
        Vector3(4.38, 1.22, -5.72),
        Color(0.25, 0.12, 0.06))

    make_box("DoorFrameTop",
        Vector3(1.88, 0.16, 0.24),
        Vector3(3.5, 2.65, -5.72),
        Color(0.25, 0.12, 0.06))

    door_mesh = make_box("Door",
        Vector3(1.6, 2.55, 0.15),
        Vector3(3.5, 1.18, -5.78),
        Color(0.38, 0.19, 0.08))

    make_box("DoorPanelTop",
        Vector3(1.18, 0.78, 0.045),
        Vector3(3.5, 1.78, -5.68),
        Color(0.48, 0.27, 0.13))

    make_box("DoorPanelBottom",
        Vector3(1.18, 0.78, 0.045),
        Vector3(3.5, 0.72, -5.68),
        Color(0.48, 0.27, 0.13))

    make_sphere("DoorHandle",
        0.09,
        Vector3(4.05, 1.2, -5.58),
        Color(1.0, 0.75, 0.16))

    # TABLE

    make_box("TableTop",
        Vector3(2.2, 0.18, 1.25),
        Vector3(-3.25, 1.0, -2.1),
        Color(0.38, 0.20, 0.10))

    for x in [-4.12, -2.38]:
        for z in [-2.55, -1.65]:
            make_box("TableLeg",
                Vector3(0.13, 1.0, 0.13),
                Vector3(x, 0.48, z),
                Color(0.25, 0.12, 0.06))

    make_box("BookRed",
        Vector3(0.48, 0.08, 0.34),
        Vector3(-3.75, 1.14, -2.0),
        Color(0.72, 0.12, 0.12))

    make_box("BookBlue",
        Vector3(0.42, 0.08, 0.34),
        Vector3(-3.2, 1.14, -2.0),
        Color(0.12, 0.32, 0.72))

    # CHAIR

    make_box("ChairSeat",
        Vector3(0.85, 0.16, 0.8),
        Vector3(-3.25, 0.62, -0.85),
        Color(0.30, 0.16, 0.09))

    make_box("ChairBack",
        Vector3(0.85, 0.9, 0.14),
        Vector3(-3.25, 1.08, -0.48),
        Color(0.30, 0.16, 0.09))

    # BED

    make_box("BedBase",
        Vector3(1.75, 0.42, 2.65),
        Vector3(-4.65, 0.28, 2.65),
        Color(0.40, 0.22, 0.12))

    make_box("BedMattress",
        Vector3(1.68, 0.22, 2.55),
        Vector3(-4.65, 0.58, 2.65),
        Color(0.91, 0.91, 0.84))

    make_box("BedPillow",
        Vector3(1.15, 0.18, 0.58),
        Vector3(-4.65, 0.78, 3.55),
        Color(0.72, 0.82, 0.96))

    make_box("BedBlanket",
        Vector3(1.7, 0.12, 1.25),
        Vector3(-4.65, 0.77, 2.0),
        Color(0.18, 0.42, 0.72))

    make_box("BedHeadboard",
        Vector3(1.9, 1.05, 0.16),
        Vector3(-4.65, 0.72, 4.02),
        Color(0.32, 0.16, 0.08))

    # BOOKSHELF

    make_box("ShelfBack",
        Vector3(0.18, 2.25, 1.75),
        Vector3(4.95, 1.18, 1.2),
        Color(0.34, 0.18, 0.09))

    for y in [0.35, 1.05, 1.75, 2.45]:
        make_box("ShelfBoard",
            Vector3(0.55, 0.10, 1.9),
            Vector3(4.7, y, 1.2),
            Color(0.30, 0.14, 0.06))

    var book_colors := [
        Color(0.75, 0.16, 0.12),
        Color(0.12, 0.38, 0.72),
        Color(0.95, 0.65, 0.12),
        Color(0.18, 0.58, 0.32)
    ]

    for i in range(4):
        make_box("ShelfBook",
            Vector3(0.28, 0.52, 0.24),
            Vector3(4.42, 0.68, 0.55 + float(i) * 0.4),
            book_colors[i])

    # WINDOW

    make_box("WindowGlass",
        Vector3(0.06, 1.45, 2.25),
        Vector3(5.78, 2.25, -2.4),
        Color(0.30, 0.72, 0.91))

    make_box("WindowFrameTop",
        Vector3(0.16, 0.12, 2.5),
        Vector3(5.68, 3.02, -2.4),
        Color(0.95, 0.91, 0.78))

    make_box("WindowFrameBottom",
        Vector3(0.16, 0.12, 2.5),
        Vector3(5.68, 1.48, -2.4),
        Color(0.95, 0.91, 0.78))

    make_box("WindowFrameNear",
        Vector3(0.16, 1.65, 0.12),
        Vector3(5.68, 2.25, -3.62),
        Color(0.95, 0.91, 0.78))

    make_box("WindowFrameFar",
        Vector3(0.16, 1.65, 0.12),
        Vector3(5.68, 2.25, -1.18),
        Color(0.95, 0.91, 0.78))

    make_box("WindowCross",
        Vector3(0.18, 1.5, 0.09),
        Vector3(5.64, 2.25, -2.4),
        Color(0.95, 0.91, 0.78))

    # WALL PICTURE

    make_box("WallPictureFrame",
        Vector3(0.08, 1.05, 1.3),
        Vector3(-5.78, 2.55, -2.5),
        Color(0.28, 0.15, 0.08))

    make_box("WallPicture",
        Vector3(0.04, 0.88, 1.12),
        Vector3(-5.72, 2.55, -2.5),
        Color(0.22, 0.58, 0.72))

    make_box("PictureSun",
        Vector3(0.05, 0.28, 0.28),
        Vector3(-5.68, 2.72, -2.58),
        Color(1.0, 0.78, 0.18))

    # PLANT

    make_box("PlantPot",
        Vector3(0.55, 0.48, 0.55),
        Vector3(4.75, 0.25, 4.55),
        Color(0.64, 0.24, 0.12))

    make_sphere("PlantLeaves",
        0.48,
        Vector3(4.75, 0.78, 4.55),
        Color(0.12, 0.48, 0.20))

    make_sphere("PlantLeafLeft",
        0.28,
        Vector3(4.42, 1.02, 4.55),
        Color(0.16, 0.58, 0.24))

    make_sphere("PlantLeafRight",
        0.28,
        Vector3(5.05, 1.02, 4.55),
        Color(0.16, 0.58, 0.24))

    # COINS

    add_coin(Vector3(-2, 0.7, 1.5))
    add_coin(Vector3(1.2, 0.7, -1.5))
    add_coin(Vector3(3, 0.7, 2.2))
    add_coin(Vector3(-4.2, 0.7, -3.2))


# PLAYER

func create_player() -> void:
    player = Node3D.new()
    player.name = "YahyaHero"
    player.position = Vector3(0, 0, 3.8)
    add_child(player)

    var yahya_texture := load(YAHYA_TEXTURE_PATH) as Texture2D

    if yahya_texture != null:
        character_sprite = Sprite3D.new()
        character_sprite.name = "YahyaCharacterSprite"
        character_sprite.texture = yahya_texture
        character_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        character_sprite.pixel_size = 0.00175
        character_sprite.position = Vector3(0, 1.36, 0)
        character_sprite.shaded = false
        character_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        character_sprite.alpha_scissor_threshold = 0.15
        character_sprite.double_sided = true
        player.add_child(character_sprite)
    else:
        create_fallback_player()


func create_fallback_player() -> void:
    var body := CapsuleMesh.new()
    body.radius = 0.38
    body.height = 1.25

    add_player_part(body,
        Vector3(0, 1.2, 0),
        Color(0.96, 0.96, 0.94))

    var vest := BoxMesh.new()
    vest.size = Vector3(0.8, 0.7, 0.3)

    add_player_part(vest,
        Vector3(0, 1.25, -0.18),
        Color(0.48, 0.49, 0.52))

    var head := SphereMesh.new()
    head.radius = 0.38
    head.height = 0.76

    add_player_part(head,
        Vector3(0, 2.05, 0),
        Color(0.72, 0.48, 0.32))

    var hair := SphereMesh.new()
    hair.radius = 0.39
    hair.height = 0.4

    add_player_part(hair,
        Vector3(0, 2.3, 0),
        Color(0.08, 0.05, 0.03))

    var leg_mesh := BoxMesh.new()
    leg_mesh.size = Vector3(0.22, 0.65, 0.25)

    add_player_part(leg_mesh,
        Vector3(-0.17, 0.35, 0),
        Color(0.12, 0.12, 0.16))

    add_player_part(leg_mesh,
        Vector3(0.17, 0.35, 0),
        Color(0.12, 0.12, 0.16))


func add_player_part(mesh: Mesh, pos: Vector3, color: Color) -> void:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos

    var material := StandardMaterial3D.new()
    material.albedo_color = color

    part.material_override = material
    player.add_child(part)


# CAMERA - IMPROVED THIRD PERSON PERSPECTIVE

func create_camera() -> void:
    camera = Camera3D.new()
    camera.current = true

    camera.fov = 58.0
    camera.near = 0.05
    camera.far = 100.0

    camera.position = player.global_position + CAMERA_OFFSET

    add_child(camera)
    follow_camera(1.0)


func follow_camera(delta: float) -> void:
    if not is_instance_valid(player):
        return

    # Smooth camera movement
    var target_position := player.global_position + CAMERA_OFFSET
    var weight := 1.0 - exp(-CAMERA_SMOOTHING * delta)

    camera.global_position = camera.global_position.lerp(
        target_position, weight)

    # Look ahead according to player movement
    var movement_direction := Vector3(
        move_velocity.x, 0.0, move_velocity.y)

    var look_ahead := Vector3.ZERO

    if movement_direction.length() > 0.05:
        look_ahead = movement_direction.normalized() * CAMERA_LOOK_AHEAD

    var look_target := player.global_position

    look_target += Vector3(
        0.0,
        CAMERA_TARGET_HEIGHT,
        0.0)

    look_target += look_ahead

    camera.look_at(look_target, Vector3.UP)


# MOVEMENT

func move_player(delta: float) -> void:
    var input_direction := move_vector

    if input_direction.length() > 1.0:
        input_direction = input_direction.normalized()

    if input_direction.length() > 0.05:
        move_velocity = move_velocity.move_toward(
            input_direction * PLAYER_SPEED,
            PLAYER_ACCELERATION * delta)
    else:
        move_velocity = move_velocity.move_toward(
            Vector2.ZERO,
            PLAYER_FRICTION * delta)

    var direction := Vector3(
        move_velocity.x,
        0,
        move_velocity.y)

    player.position += direction * delta

    player.position.x = clampf(
        player.position.x,
        -ROOM_LIMIT,
        ROOM_LIMIT)

    player.position.z = clampf(
        player.position.z,
        -ROOM_LIMIT,
        ROOM_LIMIT)

    if move_velocity.length() > 0.12:
        var target_rotation := atan2(
            -move_velocity.x,
            -move_velocity.y)

        player.rotation.y = lerp_angle(
            player.rotation.y,
            target_rotation,
            minf(1.0, delta * 12.0))


func animate_character(delta: float) -> void:
    if not is_instance_valid(character_sprite):
        return

    if move_velocity.length() > 0.18:
        walk_time += delta * 10.0

        character_sprite.position.y = (
            1.36 + absf(sin(walk_time)) * 0.10)

        character_sprite.rotation.z = sin(walk_time) * 0.035
    else:
        character_sprite.position.y = lerpf(
            character_sprite.position.y,
            1.36,
            minf(1.0, delta * 8.0))

        character_sprite.rotation.z = lerpf(
            character_sprite.rotation.z,
            0.0,
            minf(1.0, delta * 8.0))


# OBJECTS

func make_box(
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
    material.roughness = 0.82

    item.material_override = material
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

    add_child(item)

    return item


func make_sphere(
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

    item.material_override = material

    add_child(item)

    return item


# COINS

func add_coin(pos: Vector3) -> void:
    var coin := MeshInstance3D.new()
    coin.name = "GoldCoin"

    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.32
    mesh.bottom_radius = 0.32
    mesh.height = 0.12

    coin.mesh = mesh
    coin.position = pos
    coin.rotation_degrees.x = 90

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1, 0.72, 0.05)
    material.metallic = 0.5
    material.roughness = 0.28

    coin.material_override = material

    add_child(coin)
    coins.append(coin)


func animate_coins(delta: float) -> void:
    for coin in coins:
        if is_instance_valid(coin):
            coin.rotate_y(delta * 2.5)

            coin.position.y = (
                0.7 + sin(
                    Time.get_ticks_msec() * 0.003
                    + coin.position.x
                ) * 0.12)


func collect_coins() -> void:
    for i in range(coins.size() - 1, -1, -1):
        var coin := coins[i]

        if not is_instance_valid(coin):
            coins.remove_at(i)
            continue

        if player.global_position.distance_to(
            coin.global_position) < COIN_DISTANCE:

            coin_count += 1
            coin.queue_free()
            coins.remove_at(i)

            update_coin_label()
            show_message("رائع يا يحيى! حصلت على عملة ذهبية")


# DOOR

func check_door(delta: float) -> void:
    var door_position := Vector3(3.5, 0, -5.1)

    if not door_open and player.global_position.distance_to(
        door_position) < 1.5:

        if coin_count >= 4:
            door_open = true
            show_message(
                "مبروك يا يحيى! فُتح الباب وأكملت المرحلة!")
        elif message_timer <= 0.0:
            show_message("اجمع العملات الأربع أولاً!")

    if door_open:
        door_open_amount = minf(
            door_open_amount + delta * 1.8,
            1.0)

        if is_instance_valid(door_mesh):
            door_mesh.rotation.y = -door_open_amount * 1.25
            door_mesh.position.x = (
                3.5 - door_open_amount * 0.78)


# MESSAGES

func show_message(value: String) -> void:
    if is_instance_valid(message_label):
        message_label.text = value
        message_timer = 2.8


# USER INTERFACE

func create_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "TouchControlsLayer"
    layer.layer = 10
    add_child(layer)

    var root := Control.new()
    root.name = "TouchControls"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(root)

    # TITLE

    var title := Label.new()
    title.text = "مغامرات يحيى"
    title.position = Vector2(25, 20)

    title.add_theme_font_size_override(
        "font_size", 38)

    title.add_theme_color_override(
        "font_color",
        Color(1, 0.82, 0.2))

    root.add_child(title)

    # COINS COUNTER

    coin_label = Label.new()
    coin_label.position = Vector2(25, 70)

    coin_label.add_theme_font_size_override(
        "font_size", 27)

    coin_label.add_theme_color_override(
        "font_color",
        Color.WHITE)

    root.add_child(coin_label)

    # MESSAGE

    message_label = Label.new()
    message_label.text = "استكشف الغرفة واجمع العملات الذهبية"

    message_label.position = Vector2(25, 115)

    message_label.add_theme_font_size_override(
        "font_size", 22)

    message_label.add_theme_color_override(
        "font_color",
        Color.WHITE)

    root.add_child(message_label)

    # TOUCH CONTROLS

    add_control_button(
        root, "◀", Vector2(-246, -128),
        Vector2(-1, 0))

    add_control_button(
        root, "▶", Vector2(-110, -128),
        Vector2(1, 0))

    add_control_button(
        root, "▲", Vector2(-178, -210),
        Vector2(0, -1))

    add_control_button(
        root, "▼", Vector2(-178, -46),
        Vector2(0, 1))


func add_control_button(
    root: Control,
    caption: String,
    pos: Vector2,
    direction: Vector2
) -> void:

    var button := Button.new()

    button.name = "Move_" + caption
    button.text = caption

    button.custom_minimum_size = Vector2(112, 76)
    button.size = Vector2(112, 76)

    button.set_anchors_preset(
        Control.PRESET_BOTTOM_RIGHT)

    button.position = pos

    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP

    button.add_theme_font_size_override(
        "font_size", 38)

    button.add_theme_color_override(
        "font_color", Color.WHITE)

    button.add_theme_color_override(
        "font_hover_color", Color.WHITE)

    button.add_theme_color_override(
        "font_pressed_color",
        Color(1.0, 0.86, 0.35))

    # NORMAL STYLE

    var normal_style := StyleBoxFlat.new()

    normal_style.bg_color = Color(0.07, 0.16, 0.27, 0.88)
    normal_style.border_color = Color(0.35, 0.78, 1.0, 1.0)

    normal_style.set_border_width_all(3)
    normal_style.set_corner_radius_all(20)

    normal_style.shadow_color = Color(0, 0, 0, 0.35)
    normal_style.shadow_size = 5

    button.add_theme_stylebox_override(
        "normal", normal_style)

    # HOVER STYLE

    var hover_style := normal_style.duplicate() as StyleBoxFlat

    hover_style.bg_color = Color(0.10, 0.30, 0.46, 0.96)

    button.add_theme_stylebox_override(
        "hover", hover_style)

    # PRESSED STYLE

    var pressed_style := normal_style.duplicate() as StyleBoxFlat

    pressed_style.bg_color = Color(0.12, 0.48, 0.68, 1.0)
    pressed_style.border_color = Color(1.0, 0.82, 0.25, 1.0)

    button.add_theme_stylebox_override(
        "pressed", pressed_style)

    root.add_child(button)

    # TOUCH INPUT

    button.button_down.connect(func():
        move_vector = direction
    )

    button.button_up.connect(func():
        move_vector = Vector2.ZERO
    )

    button.mouse_exited.connect(func():
        move_vector = Vector2.ZERO
    )


# UPDATE COINS LABEL

func update_coin_label() -> void:
    if is_instance_valid(coin_label):
        coin_label.text = (
            "العملات: " + str(coin_count) + " / 4")
