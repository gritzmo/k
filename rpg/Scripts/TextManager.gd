"""
TextManager.gd
---------------
Very small helper for tracking a label's text state. This is a starting point
for more complex dialogue systems.
"""

class_name TextManager
extends Label

enum State { READY, READING, FINISHED }

# Current state of the text display
var current_state: State = State.READY

# ─── Initialization ───

func _ready() -> void:
    print("[TextManager] starting in READY")

# ─── Utility Functions ───

func change_state(next_state: State) -> void:
    """Switch to a new text state and print debug info."""
    current_state = next_state
    match current_state:
        State.READY:
            print("state is ready")
        State.READING:
            print("state is reading")
        State.FINISHED:
            print("state is finished")
