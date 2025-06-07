"""
AttackSelect.gd
-----------------
Handles menu button hover animations for attack selection buttons.
Attach this script to a `Button` node under your attack menu.
The script plays simple animations when the cursor enters or exits the button.
"""

class_name AttackSelect
extends Button

# When true, hover animations are suppressed.
var cancel: bool = false

# Path to the AnimationPlayer driving this button's hover animations.
@export var anim_player_path: NodePath = NodePath("../Attack2/AnimationPlayer")

# Optional sound to play when hovering over the button.
@export var hover_sound_path: NodePath = NodePath("../cuteping")

# Delay between move/return animation and highlight/idle animation.
const HOVER_ANIM_DELAY: float = 0.1

@onready var anim: AnimationPlayer = get_node_or_null(anim_player_path) as AnimationPlayer
@onready var hover_sound: AudioStreamPlayer = get_node_or_null(hover_sound_path) as AudioStreamPlayer

func _ready() -> void:
    """Initializes references and connects input signals."""
    if anim:
        anim.play("null")
    if not mouse_entered.is_connected(_on_mouse_entered):
        mouse_entered.connect(_on_mouse_entered)
    if not mouse_exited.is_connected(_on_mouse_exited):
        mouse_exited.connect(_on_mouse_exited)

func _play_hover_sequence(is_enter: bool) -> void:
    """Plays the hover animations with a small delay."""
    if is_enter:
        _play_animation("moveup")
    else:
        _play_animation("movedown")
    await get_tree().create_timer(HOVER_ANIM_DELAY).timeout
    if is_enter:
        _play_animation("highlight")
        if hover_sound:
            hover_sound.play()
    else:
        _play_animation("null")

func _play_animation(anim_name: StringName) -> void:
    if anim:
        anim.play(anim_name)

func _on_mouse_entered() -> void:
    if cancel:
        return
    await _play_hover_sequence(true)
    print("[AttackSelect] hover")

func _on_mouse_exited() -> void:
    if cancel:
        return
    await _play_hover_sequence(false)
    print("[AttackSelect] leave")
