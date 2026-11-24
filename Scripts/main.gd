extends Node3D

# YAHYA ADVENTURES
# Character update: use Yahya's illustrated character sprite when the asset exists.
# If the PNG is missing, the original simple 3D character remains as a fallback.

const PLAYER_SPEED := 4.8
const ROOM_LIMIT := 5.3
const COIN_DISTANCE := 0.9
const YAHYA_TEXTURE_PATH := "res://Assets/yahya_character.png"

var player: Node3D
var camera: Camera3D
var coins: Array[MeshInstance3D] = []
var coin_count := 0
var move_vector := Vector2.ZERO
var coin_label: Label
var message_label: Label
var door_open := false

func _ready() -> void:
    create_environment()
    create_room()
    create_player()
    create_camera()
    create_ui()
    update_coin_label()

func _process(delta: float) -> void:
    move_player(delta)
    follow_camera()
    animate_coins(delta)
    collect_coins()
    check_door()

func create_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.48, 0.67, 0.83)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.8, 0.82, 0.9)
    env.ambient_light_energy = 0.8
    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-45, -30, 0)
    sun.light_energy = 1.2
    add_child(sun)

func create_room() -> void:
    make_box("Floor", Vector3(12, 0.3, 12),
        Vector3(0, -0.2, 0), Color(0.72, 0.54, 0.38))

    make_box("BackWall", Vector3(12, 3.8, 0.25),
        Vector3(0, 1.7, -6), Color(0.91, 0.76, 0.72))

    make_box("LeftWall", Vector3(0.25, 3.8, 12),
        Vector3(-6, 1.7, 0), Color(0.82, 0.69, 0.79))

    make_box("RightWall", Vector3(0.25, 3.8, 12),
        Vector3(6, 1.7, 0), Color(0.82, 0.69, 0.79))

    make_box("Rug", Vector3(5, 0.06, 3),
        Vector3(0, 0, 0.8), Color(0.58, 0.19, 0.29))

    make_box("Table", Vector3(2, 0.2, 1.2),
        Vector3(-3, 1, -2), Color(0.35, 0.17, 0.08))

    make_box("Door", Vector3(1.6, 2.6, 0.15),
        Vector3(3.5, 1.2, -5.8), Color(0.3, 0.14, 0.06))

    make_box("DoorHandle", Vector3(0.1, 0.1, 0.1),
        Vector3(3, 1.2, -5.7), Color(1, 0.75, 0.1))

    add_coin(Vector3(-2, 0.7, 1.5))
    add_coin(Vector3(1.2, 0.7, -1.5))
    add_coin(Vector3(3, 0.7, 2.2))
    add_coin(Vector3(-4.2, 0.7, -3.2))

func create_player() -> void:
    player = Node3D.new()
    player.name = "YahyaHero"
    player.position = Vector3(0, 0, 3.8)
    add_child(player)

    var yahya_texture := load(YAHYA_TEXTURE_PATH) as Texture2D
    if yahya_texture != null:
        var portrait := Sprite3D.new()
        portrait.name = "YahyaCharacterSprite"
        portrait.texture = yahya_texture
        portrait.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        portrait.pixel_size = 0.00175
        portrait.position = Vector3(0, 1.36, 0)
        portrait.shaded = false
        portrait.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        portrait.alpha_scissor_threshold = 0.15
        portrait.double_sided = true
        player.add_child(portrait)
    else:
        # Fallback: keep a visible 3D character if the image was not copied.
        create_fallback_player()

func create_fallback_player() -> void:
    var body := CapsuleMesh.new()
    body.radius = 0.38
    body.height = 1.25
    add_player_part(body, Vector3(0, 1.2, 0),
        Color(0.96, 0.96, 0.94))

    var vest := BoxMesh.new()
    vest.size = Vector3(0.8, 0.7, 0.3)
    add_player_part(vest, Vector3(0, 1.25, -0.18),
        Color(0.48, 0.49, 0.52))

    var head := SphereMesh.new()
    head.radius = 0.38
    head.height = 0.76
    add_player_part(head, Vector3(0, 2.05, 0),
        Color(0.72, 0.48, 0.32))

    var hair := SphereMesh.new()
    hair.radius = 0.39
    hair.height = 0.4
    add_player_part(hair, Vector3(0, 2.3, 0),
        Color(0.08, 0.05, 0.03))

    var leg_mesh := BoxMesh.new()
    leg_mesh.size = Vector3(0.22, 0.65, 0.25)
    add_player_part(leg_mesh, Vector3(-0.17, 0.35, 0),
        Color(0.12, 0.12, 0.16))
    add_player_part(leg_mesh, Vector3(0.17, 0.35, 0),
        Color(0.12, 0.12, 0.16))

func add_player_part(mesh: Mesh, pos: Vector3,
        color: Color) -> void:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    part.material_override = material
    player.add_child(part)

func create_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 62
    add_child(camera)
    follow_camera()

func follow_camera() -> void:
    if not is_instance_valid(player):
        return
    camera.position = player.global_position + Vector3(0, 6.8, 8.5)
    camera.look_at(player.global_position + Vector3(0, 1, 0))

func move_player(delta: float) -> void:
    var direction := Vector3(move_vector.x, 0, move_vector.y)
    if direction.length() > 1:
        direction = direction.normalized()

    player.position += direction * PLAYER_SPEED * delta
    player.position.x = clampf(player.position.x, -ROOM_LIMIT, ROOM_LIMIT)
    player.position.z = clampf(player.position.z, -ROOM_LIMIT, ROOM_LIMIT)

    if direction.length() > 0.05:
        player.rotation.y = atan2(-direction.x, -direction.z)

func make_box(node_name: String, box_size: Vector3,
        pos: Vector3, color: Color) -> void:
    var item := MeshInstance3D.new()
    item.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    item.mesh = mesh
    item.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    item.material_override = material
    add_child(item)

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
    coin.material_override = material
    add_child(coin)
    coins.append(coin)

func animate_coins(delta: float) -> void:
    for coin in coins:
        if is_instance_valid(coin):
            coin.rotate_y(delta * 2.5)
            coin.position.y = 0.7 + sin(
                Time.get_ticks_msec() * 0.003 + coin.position.x
            ) * 0.12

func collect_coins() -> void:
    for i in range(coins.size() - 1, -1, -1):
        var coin := coins[i]
        if not is_instance_valid(coin):
            coins.remove_at(i)
            continue
        if player.global_position.distance_to(coin.global_position) < COIN_DISTANCE:
            coin_count += 1
            coin.queue_free()
            coins.remove_at(i)
            update_coin_label()
            message_label.text = "أحسنت! جمعت عملة ذهبية"

func check_door() -> void:
    if door_open:
        return
    var door_position := Vector3(3.5, 0, -5.1)
    if player.global_position.distance_to(door_position) < 1.5:
        if coin_count >= 4:
            door_open = true
            message_label.text = "مبروك يا يحيى! أكملت المرحلة!"
        else:
            message_label.text = "اجمع العملات الأربع أولاً!"

func create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)

    var title := Label.new()
    title.text = "مغامرات يحيى"
    title.position = Vector2(25, 20)
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", Color(1, 0.82, 0.2))
    root.add_child(title)

    coin_label = Label.new()
    coin_label.position = Vector2(25, 70)
    coin_label.add_theme_font_size_override("font_size", 27)
    coin_label.add_theme_color_override("font_color", Color.WHITE)
    root.add_child(coin_label)

    message_label = Label.new()
    message_label.text = "اجمع العملات الذهبية!"
    message_label.position = Vector2(25, 115)
    message_label.add_theme_font_size_override("font_size", 22)
    message_label.add_theme_color_override("font_color", Color.WHITE)
    root.add_child(message_label)

    add_control_button(root, "◀", Vector2(25, -115), Vector2(-1, 0))
    add_control_button(root, "▶", Vector2(145, -115), Vector2(1, 0))
    add_control_button(root, "▲", Vector2(85, -180), Vector2(0, -1))
    add_control_button(root, "▼", Vector2(85, -48), Vector2(0, 1))

func add_control_button(root: Control, caption: String,
        pos: Vector2, direction: Vector2) -> void:
    var button := Button.new()
    button.text = caption
    button.size = Vector2(100, 62)
    button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    button.position = pos
    button.add_theme_font_size_override("font_size", 30)
    root.add_child(button)

    button.button_down.connect(func():
        move_vector = direction
    )
    button.button_up.connect(func():
        move_vector = Vector2.ZERO
    )
    button.mouse_exited.connect(func():
        move_vector = Vector2.ZERO
    )

func update_coin_label() -> void:
    if is_instance_valid(coin_label):
        coin_label.text = "العملات: " + str(coin_count) + " / 4"
