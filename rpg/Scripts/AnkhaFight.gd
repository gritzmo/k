"""
AnkhaFight.gd
---------------
Main battle controller for the "Ankha Fight!" demo. Handles player and boss
stats, actions, turn order and UI updates. The script is heavily commented so
that beginners can see how a basic turn-based combat loop works in Godot 4.
Assign this script to a `Node2D` called `AnkhaFight` in your battle scene.
"""

class_name AnkhaFight
extends Node2D


# ─── Player Stats ───
# Converted to inner class. Removed class_name to keep only one global
# class per file as required by GDScript.
class PlayerStats:
    # The player's current and maximum health points
    var max_hp : int = 100
    var hp : int = max_hp

    # Spirit Points (used for special abilities)
    var max_sp : int = 100
    var sp : int = 0

    # Stamina controls how many actions we can do
    var max_stamina : int = 100
    var stamina : int = max_stamina

    # Used to decide turn order (higher means faster)
    var speed : int = 10

    # Chance to dodge enemy attacks (0..100)
    var dodge_rate : int = 20

    # A flag used when the player is guarding
    var guard_active : bool = false

    # Tracks if the player is vulnerable next turn
    var vulnerable_next_turn : bool = false

    # A dictionary of status effects currently on the player
    var status_effects : Array = []

    # Helper function to clamp SP between 0 and max
    func add_sp(amount : int) -> void:
        sp = clamp(sp + amount, 0, max_sp)



# ─── Enemy Stats ───
# Inner class for boss stats.
class EnemyStats:
    var max_hp : int = 300
    var hp : int = max_hp

    # The boss builds rage when taking damage
    var rage : int = 0        # 0..100

    # Phase control for different move sets
    var phase : int = 1

    # Simple example speeds
    var speed : int = 8

    # Status effects on the boss
    var status_effects : Array = []



# ─── Ability Definitions ───
# Each ability has a cost, a cooldown and an effect.
class Ability:
    var name : String = ""
    var sp_cost : int = 0
    var cooldown : int = 0
    var current_cd : int = 0
    var effect : String = ""  # could be "damage" or "heal"

    func _init(n : String, cost : int, cd : int, eff : String):
        name = n
        sp_cost = cost
        cooldown = cd
        effect = eff
        current_cd = 0

# Helper to tick down cooldown each turn
func tick_cooldowns(abilities : Dictionary) -> void:
    for key in abilities.keys():
        var ability : Ability = abilities[key]
        if ability.current_cd > 0:
            ability.current_cd -= 1

# ─── Combo Manager ───
# Inner helper class for handling simple QTE combos.
class ComboManager:
    var combo_count : int = 0
    var qte_window : float = 0.0
    var qte_active : bool = false
    var success : bool = false

    # Called to start the quick-time-event after an attack
    func start_qte(window_time : float) -> void:
        qte_window = window_time
        qte_active = true
        success = false
        combo_count += 1

    # In your BattleScene's _process(delta) you would call this
    # to handle timing and input detection
    func update_qte(delta : float) -> void:
        if qte_active:
            qte_window -= delta
            if qte_window <= 0:
                qte_active = false
            elif Input.is_action_just_pressed("qte"):
                success = true
                qte_active = false

# ─── Main Battle Class ───

var player : PlayerStats = PlayerStats.new()
var boss : EnemyStats = EnemyStats.new()
var combo_manager : ComboManager = ComboManager.new()

# Dictionary storing the player's special abilities
var abilities : Dictionary = {
    "FlurryStrike": Ability.new("Flurry Strike", 20, 3, "damage"),
    "MendWounds": Ability.new("Mend Wounds", 35, 5, "heal")
}

# References to UI elements are exported so they can be set
# in the editor (e.g., drag the ProgressBars from the scene)
@export var player_hp_bar : TextureProgressBar
@export var player_sp_bar : TextureProgressBar
@export var player_stamina_bar : TextureProgressBar
@export var boss_hp_bar : TextureProgressBar
@export var boss_rage_bar : TextureProgressBar
@export var log_panel : RichTextLabel

# This Array represents the order of turns. For simplicity
# 0 means player, 1 means boss
var turn_queue : Array = [0, 1]
var current_turn_index : int = 0


func _ready() -> void:
    update_ui()
    log_action("The fight begins!")


# ─── Combat Logic ───
# Each of these functions represents an action the player
# can perform during their turn. They modify stats and
# write to the battle log so the UI can display what
# happened.

func fast_strike() -> void:
    var damage = 10
    var accuracy = 90
    var cost_stamina = 5
    if player.stamina < cost_stamina:
        log_action("Too tired to attack!")
        return
    player.stamina -= cost_stamina
    if randf() * 100 <= accuracy:
        boss.hp -= damage
        player.add_sp(5)
        log_action("Fast Strike hits for %d" % damage)
        start_combo()
    else:
        log_action("Fast Strike missed!")
    end_player_turn()

func strong_strike() -> void:
    var damage = 20
    var accuracy = 75
    var cost_stamina = 10
    if player.stamina < cost_stamina:
        log_action("Too tired to attack!")
        return
    player.stamina -= cost_stamina
    if randf() * 100 <= accuracy:
        boss.hp -= damage
        player.add_sp(3)
        log_action("Strong Strike hits for %d" % damage)
        start_combo()
    else:
        log_action("Strong Strike missed!")
    end_player_turn()

func charged_strike() -> void:
    var damage = 35
    var accuracy = 60
    var cost_stamina = 20
    if player.stamina < cost_stamina:
        log_action("Too tired to attack!")
        return
    player.stamina -= cost_stamina
    if randf() * 100 <= accuracy:
        boss.hp -= damage
        player.add_sp(1)
        log_action("Charged Strike hits for %d" % damage)
        start_combo()
    else:
        log_action("Charged Strike missed!")
    end_player_turn()

func use_flurry_strike() -> void:
    var ability : Ability = abilities["FlurryStrike"]
    if ability.current_cd > 0:
        log_action("Flurry Strike is on cooldown!")
        return
    if player.sp < ability.sp_cost:
        log_action("Not enough SP!")
        return
    player.sp -= ability.sp_cost
    ability.current_cd = ability.cooldown
    var damage = 15  # base damage used twice
    for i in range(2):
        if randf() * 100 <= 75:
            boss.hp -= damage
            log_action("Flurry hit %d for %d" % [i + 1, damage])
        else:
            log_action("Flurry hit %d missed" % [i + 1])
    end_player_turn()

func use_mend_wounds() -> void:
    var ability : Ability = abilities["MendWounds"]
    if ability.current_cd > 0:
        log_action("Mend Wounds is on cooldown!")
        return
    if player.sp < ability.sp_cost:
        log_action("Not enough SP!")
        return
    player.sp -= ability.sp_cost
    ability.current_cd = ability.cooldown
    player.hp = clamp(player.hp + 25, 0, player.max_hp)
    # Remove one status effect if any
    if player.status_effects.size() > 0:
        player.status_effects.pop_front()
    log_action("Mend Wounds restores health")
    end_player_turn()

func guard_action() -> void:
    player.guard_active = true
    player.add_sp(5)
    log_action("Ankha guards and gains SP")
    end_player_turn()

func dodge_action() -> void:
    var stamina_cost = 20
    if player.stamina < stamina_cost:
        log_action("Not enough stamina to dodge")
        return
    player.stamina -= stamina_cost
    if randi() % 100 < player.dodge_rate:
        # Successful dodge: player gets next turn earlier
        turn_queue.insert(current_turn_index + 1, 0)
        log_action("Successful dodge!")
    else:
        log_action("Dodge failed")
    end_player_turn()

func counter_action() -> void:
    var sp_cost = 30
    if player.sp < sp_cost:
        log_action("Not enough SP to counter")
        return
    player.sp -= sp_cost
    # Here we would start a short timed input window
    # and check for a button press when the boss attacks.
    # For simplicity we simulate success half the time.
    if randi() % 100 < 50:
        var reflected = 10
        boss.hp -= reflected
        log_action("Counter successful, %d damage returned" % reflected)
    else:
        log_action("Counter failed")
    end_player_turn()

# ─── Turn Handling ───

# Called after each player action to finish their turn
func end_player_turn() -> void:
    tick_cooldowns(abilities)
    combo_manager.update_qte(0)  # ensure qte state resets
    player.guard_active = false
    current_turn_index = (current_turn_index + 1) % turn_queue.size()
    update_ui()
    check_end_conditions()
    if turn_queue[current_turn_index] == 1:
        boss_turn()

# Starts a QTE after a successful hit
func start_combo() -> void:
    combo_manager.start_qte(0.5)
    if combo_manager.success:
        player.add_sp(10)

# Very simple boss AI
func boss_turn() -> void:
    log_action("Boss takes a turn")
    # Example phase change based on HP
    if boss.hp <= boss.max_hp / 2 and boss.phase == 1:
        boss.phase = 2
        log_action("Boss enters Rage Phase!")
    var damage = 15 if boss.phase == 1 else 25
    if player.guard_active:
        damage = int(damage * 0.5)
    player.hp -= damage
    boss.rage += int(damage * 0.2)
    log_action("Boss attacks for %d" % damage)
    if boss.rage >= 100:
        boss_rage_attack()
    current_turn_index = (current_turn_index + 1) % turn_queue.size()
    update_ui()
    check_end_conditions()

func boss_rage_attack() -> void:
    boss.rage = 0
    var damage = 30
    if player.guard_active:
        damage = int(damage * 0.5)
    player.hp -= damage
    log_action("Boss unleashes a rage attack!")

func check_end_conditions() -> void:
    if player.hp <= 0:
        log_action("Ankha has been defeated...")
    elif boss.hp <= 0:
        log_action("Boss defeated! Victory!")

# ─── UI Updates ───

func update_ui() -> void:
    if player_hp_bar:
        player_hp_bar.value = float(player.hp) / player.max_hp * 100
    if player_sp_bar:
        player_sp_bar.value = float(player.sp) / player.max_sp * 100
    if player_stamina_bar:
        player_stamina_bar.value = float(player.stamina) / player.max_stamina * 100
    if boss_hp_bar:
        boss_hp_bar.value = float(boss.hp) / boss.max_hp * 100
    if boss_rage_bar:
        boss_rage_bar.value = float(boss.rage)

func log_action(text : String) -> void:
    if log_panel:
        log_panel.append_text(text + "\n")
    print(text)


# End of AnkhaFight.gd

