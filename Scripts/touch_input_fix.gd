extends "res://Scripts/ultimate_update.gd"

# YAHYA ADVENTURES - MULTI-TOUCH INPUT ROUTER FIX
# Godot 4.4.1
# Add this file as: res://Scripts/touch_input_fix.gd
# Then set Main.tscn to use this script instead of ultimate_update.gd.

var routed_touch_fingers: Dictionary = {}


func _input(event: InputEvent) -> void:
    var finger_id := -1
    var finger_position := Vector2.ZERO
    var finger_down := false
    var is_drag := false

    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        finger_id = touch.index
        finger_position = touch.position
        finger_down = touch.pressed
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        finger_id = drag.index
        finger_position = drag.position
        is_drag = true
    else:
        return

    if is_drag:
        if not routed_touch_fingers.has(finger_id):
            return

        _change_touch_target(finger_id, finger_position)
        get_viewport().set_input_as_handled()
        return

    if finger_down:
        if routed_touch_fingers.has(finger_id):
            return

        # Keep tracking a finger even when it starts outside a button,
        # so sliding onto a control still activates it.
        routed_touch_fingers[finger_id] = null
        _change_touch_target(finger_id, finger_position)

        if is_instance_valid(routed_touch_fingers.get(finger_id)):
            get_viewport().set_input_as_handled()
    else:
        if not routed_touch_fingers.has(finger_id):
            return

        _change_touch_target(finger_id, Vector2(-100000.0, -100000.0))
        routed_touch_fingers.erase(finger_id)
        touch_fingers.erase(finger_id)
        _refresh_move_vector()
        _refresh_sprint_request()
        get_viewport().set_input_as_handled()


func _get_touch_input_root() -> Control:
    # The creature intro is the active first screen in Main.tscn.
    # It must be checked before the legacy ultimate menu and gameplay HUD.
    var creature_intro_root := get_node_or_null(
        "CreatureIntroLayer/CreatureIntroRoot"
    ) as Control

    if is_instance_valid(creature_intro_root) and creature_intro_root.visible:
        return creature_intro_root

    # Keep support for the legacy ultimate menu.
    var intro_root := get_node_or_null(
        "UltimateMenuLayer/UltimateRoot"
    ) as Control

    if is_instance_valid(intro_root) and intro_root.visible:
        return intro_root

    if is_instance_valid(complete_overlay) and complete_overlay.visible:
        return complete_overlay

    if is_instance_valid(pause_overlay) and pause_overlay.visible:
        return pause_overlay

    return responsive_root


func _change_touch_target(finger_id: int, finger_position: Vector2) -> void:
    var previous_button := routed_touch_fingers.get(finger_id) as Button
    var current_button := _find_touch_button(
        _get_touch_input_root(), finger_position
    )

    if previous_button == current_button:
        return

    if is_instance_valid(previous_button):
        touch_fingers.erase(finger_id)
        _handle_touch_button(previous_button, false)

    routed_touch_fingers[finger_id] = current_button

    if is_instance_valid(current_button):
        touch_fingers[finger_id] = current_button
        _handle_touch_button(current_button, true)

    _refresh_move_vector()
    _refresh_sprint_request()


func _release_all_controls() -> void:
    routed_touch_fingers.clear()
    super._release_all_controls()
