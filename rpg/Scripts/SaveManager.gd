"""
SaveManager.gd
---------------
Singleton that saves and loads persistent data such as XP and coins. Add this
script as an AutoLoad so it can be accessed from anywhere.
"""

class_name SaveManager
extends Node

# ─── Initialization ───

# Data that will be saved
var save_data : Dictionary = {
    "player_xp": 0,
    "player_level": 1,
    "coins": 0,
    "persistent_upgrades": {}
}

# Path to the save file within the user's directory
const SAVE_PATH : String = "user://savegame.json"

func _ready() -> void:
    """Load save data when the game starts."""
    load_game()

# Save the dictionary to disk as JSON
func save_game() -> void:
    """Write the current save_data dictionary to disk."""
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()
    else:
        push_error("[SaveManager] Could not open save file for writing")

# Load data if file exists
func load_game() -> void:
    """Load the save file if it exists and populate save_data."""
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file:
            var text = file.get_as_text()
            var loaded = JSON.parse_string(text)
            if typeof(loaded) == TYPE_DICTIONARY:
                save_data = loaded
            file.close()
        else:
            push_error("[SaveManager] Could not open save file for reading")

# Example function to modify coins and save automatically
func add_coins(amount : int) -> void:
    """Increase coin total and immediately save to disk."""
    save_data["coins"] += amount
    save_game()

