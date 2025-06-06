"""
BattleHUD.gd
---------------
Updates the on-screen bars and combat log during battle. Attach this
script to a `CanvasLayer` named `HUD` in your battle scene.
"""

class_name BattleHUD
extends CanvasLayer

@export var player_hp_bar : TextureProgressBar
@export var player_sp_bar : TextureProgressBar
@export var player_stamina_bar : TextureProgressBar
@export var boss_hp_bar : TextureProgressBar
@export var boss_rage_bar : TextureProgressBar
@export var log_panel : RichTextLabel

# Reference to the battle manager node controlling the fight
var battle : Node = null

# ─── Initialization ───

func _ready() -> void:
    """Cache the battle manager and update the HUD once on start."""
    if get_parent().has_node("AnkhaFight"):
        battle = get_parent().get_node("AnkhaFight")
    update_bars()

# ─── UI Updates ───

func update_bars() -> void:
    """Refresh progress bars with the latest battle stats."""
    if battle == null:
        return
    player_hp_bar.value = float(battle.player.hp) / battle.player.max_hp * 100
    player_sp_bar.value = float(battle.player.sp) / battle.player.max_sp * 100
    player_stamina_bar.value = float(battle.player.stamina) / battle.player.max_stamina * 100
    boss_hp_bar.value = float(battle.boss.hp) / battle.boss.max_hp * 100
    boss_rage_bar.value = float(battle.boss.rage)

func log(text : String) -> void:
    if log_panel:
        log_panel.append_text(text + "\n")

