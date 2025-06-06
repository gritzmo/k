# AttackSelect.gd: handles menu button hover animations
class_name AttackSelect
extends Button

var cancel := false

onready var anim: AnimationPlayer = get_node("../Attack2/AnimationPlayer")

func _ready() -> void:
    if anim:
        anim.play("null")

func _process(delta: float) -> void:
    pass

func _on_mouse_entered() -> void:
    if cancel:
        return
    if anim:
        anim.play("moveup")
    await get_tree().create_timer(0.10).timeout
    if anim:
        anim.play("highlight")
    if has_node("../cuteping"):
        get_node("../cuteping").play()
    print("yeah!")

func _on_mouse_exited() -> void:
    if cancel:
        return
    if anim:
        anim.play("movedown")
    await get_tree().create_timer(0.10).timeout
    if anim:
        anim.play("null")
    print("no!")
