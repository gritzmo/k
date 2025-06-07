"""
Battle.gd
---------
Refactored battle system core. Handles player input, combat flow,
and text display. This version removes experimental logic from the
original 1600+ line prototype for readability.
"""

class_name BattleScene
extends Node2D

# -------------------------------------------------------------------
# Signals & Callbacks
# -------------------------------------------------------------------
signal textbox_closed
signal close_skill_menu

# -------------------------------------------------------------------
# Exported NodePaths
# -------------------------------------------------------------------
@export var textbox_path: NodePath
@export var hp_label_path: NodePath
@export var sp_label_path: NodePath
@export var sb_bar_path: NodePath
@export var skill_menu_path: NodePath
@export var attack_button_path: NodePath
@export var skills_button_path: NodePath

# -------------------------------------------------------------------
# Constants & Enums
# -------------------------------------------------------------------
enum TextState { READY, READING, FINISHED }
const ACCEPT_ACTION := "ui_accept"
const QUICKTIME_ACTION := "qte"

# -------------------------------------------------------------------
# Member Variables
# -------------------------------------------------------------------
var player_hp: int = 100
var player_max_hp: int = 100
var player_sp: int = 50
var player_max_sp: int = 50
var enemy_hp: int = 600

var stamina: int = 0
var quicktime: bool = false
var quicktime_success: bool = false
var current_state: TextState = TextState.READY
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Cached node references
@onready var textbox: RichTextLabel = get_node_or_null(textbox_path)
@onready var hp_label: Label = get_node_or_null(hp_label_path)
@onready var sp_label: Label = get_node_or_null(sp_label_path)
@onready var sb_bar: ProgressBar = get_node_or_null(sb_bar_path)
@onready var skill_menu: Control = get_node_or_null(skill_menu_path)
@onready var attack_button: Button = get_node_or_null(attack_button_path)
@onready var skills_button: Button = get_node_or_null(skills_button_path)

# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------
func _ready() -> void:
    _hide_optional_ui()
    _update_status_labels()
    _connect_signals()

# -------------------------------------------------------------------
# Per-frame processing
# -------------------------------------------------------------------
func _process(delta: float) -> void:
    if sb_bar:
        sb_bar.value = stamina
    _update_textbox_state()

# -------------------------------------------------------------------
# Core Combat Loop
# -------------------------------------------------------------------
func player_turn() -> void:
    display_text("Your move...")
    await textbox_closed
    enemy_turn()

func enemy_turn() -> void:
    display_text("Enemy attacks!")
    await textbox_closed
    player_turn()

# -------------------------------------------------------------------
# Textbox Handling
# -------------------------------------------------------------------
func display_text(text: String, rate: float = 0.05) -> void:
    if not textbox:
        return
    textbox.show()
    textbox.text = text
    textbox.visible_characters = 0
    current_state = TextState.READING
    var tween := create_tween()
    tween.tween_property(textbox, "visible_characters", text.length(), text.length() * rate)
    await tween.finished
    current_state = TextState.FINISHED

func _update_textbox_state() -> void:
    match current_state:
        TextState.READING:
            if Input.is_action_just_pressed(ACCEPT_ACTION):
                if textbox:
                    textbox.visible_characters = textbox.get_total_character_count()
                current_state = TextState.FINISHED
            if quicktime and Input.is_action_just_pressed(QUICKTIME_ACTION):
                quicktime_success = true
        TextState.FINISHED:
            if Input.is_action_just_pressed(ACCEPT_ACTION):
                _close_textbox()

func _close_textbox() -> void:
    if textbox:
        textbox.hide()
    emit_signal("textbox_closed")
    current_state = TextState.READY

# -------------------------------------------------------------------
# Menu Functions
# -------------------------------------------------------------------
func skill_menu_open() -> void:
    if skill_menu:
        skill_menu.show()
    if attack_button:
        attack_button.hide()
    if skills_button:
        skills_button.hide()
    emit_signal("close_skill_menu")

func skill_menu_close() -> void:
    if skill_menu:
        skill_menu.hide()
    if attack_button:
        attack_button.show()
    if skills_button:
        skills_button.show()

# -------------------------------------------------------------------
# Signal Handlers
# -------------------------------------------------------------------
func _on_attack_pressed() -> void:
    skill_menu_close()
    player_turn()

func _on_skills_pressed() -> void:
    skill_menu_open()

# -------------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------------
func _hide_optional_ui() -> void:
    skill_menu_close()
    if textbox:
        textbox.hide()

func _update_status_labels() -> void:
    if hp_label:
        hp_label.text = "HP: %d/%d" % [player_hp, player_max_hp]
    if sp_label:
        sp_label.text = "SP: %d/%d" % [player_sp, player_max_sp]

func _connect_signals() -> void:
    if attack_button and not attack_button.pressed.is_connected(_on_attack_pressed):
        attack_button.pressed.connect(_on_attack_pressed)
    if skills_button and not skills_button.pressed.is_connected(_on_skills_pressed):
        skills_button.pressed.connect(_on_skills_pressed)

