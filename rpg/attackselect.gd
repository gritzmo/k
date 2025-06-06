extends Button

var cancel = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	$"../Attack2/AnimationPlayer".play("null")
	
func _process(delta):
	pass


func _on_mouse_entered():
	if cancel == 1:
		return
	else:
		$"../Attack2/AnimationPlayer".play("moveup")
		await(get_tree().create_timer(0.10).timeout)
		$"../Attack2/AnimationPlayer".play("highlight")
		$"../cuteping".play()
		print("yeah!")
		
func _on_mouse_exited():
	if cancel == 1:
		return
	else:
		$"../Attack2/AnimationPlayer".play("movedown")
		await(get_tree().create_timer(0.10).timeout)
		$"../Attack2/AnimationPlayer".play("null")
		print("no!")
		
	
