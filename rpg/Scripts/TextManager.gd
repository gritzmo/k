# TextManager.gd: manages simple text display states
class_name TextManager
extends Label

enum State { READY, READING, FINISHED }

var current_state: State = State.READY

func _ready() -> void:
    print("starting state is ready")

func change_state(next_state: State) -> void:
    current_state = next_state
    match current_state:
        State.READY:
            print("state is ready")
        State.READING:
            print("state is reading")
        State.FINISHED:
            print("state is finished")
