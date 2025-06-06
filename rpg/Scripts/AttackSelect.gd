"""
AttackSelect.gd
-----------------
Handles menu button hover animations for attack selection buttons.
Attach this script to a `Button` node under your attack menu. The script
plays simple animations when the cursor enters or exits the button.
"""

class_name AttackSelect
extends Button

# ─── Initialization ───

# When true, hovering will not play animations
var cancel := false

# Cached reference to the AnimationPlayer controlling button animations
onready var anim: AnimationPlayer = get_node("../Attack2/AnimationPlayer")

func _ready() -> void:
    """Called when the node enters the scene tree."""
    if anim:
        anim.play("null")

# ─── Input Handling ───

func _on_mouse_entered() -> void:
    """Signal Handler: mouse entered the button."""
    if cancel:
        return
    if anim:
        anim.play("moveup")
    await get_tree().create_timer(0.10).timeout
    if anim:
        anim.play("highlight")
    if has_node("../cuteping"):
        get_node("../cuteping").play()
    print("[AttackSelect] hover")

func _on_mouse_exited() -> void:
    """Signal Handler: mouse exited the button."""
    if cancel:
        return
    if anim:
        anim.play("movedown")
    await get_tree().create_timer(0.10).timeout
    if anim:
        anim.play("null")
    print("[AttackSelect] leave")

# ─── Utility Functions ───

func _process(delta: float) -> void:
    pass
