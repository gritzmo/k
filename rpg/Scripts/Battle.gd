"""
Battle.gd
----------
Large prototype battle script containing experimental logic. The script
handles player input, cutscenes and attack sequences. It is recommended to
split this file into smaller components for maintainability.
"""

extends Node2D
class_name BattleScene

# =============================================================================
# Feature Roadmap
# -----------------------------------------------------------------------------
# Development notes and upcoming features for this prototype.
# =============================================================================
# add better textbox, font, etc
# add speed buff and "leg kick" move
# add game over screen
# add wham to attacks and better animations for enemy and player
# add results screen showing exp and money earned
# add enemy events/phase changes
#   - added event for first turn
# add phase 2 and 3 as well as their respective new attacks
# add SP bar

# =============================================================================
# Status Flags
# -----------------------------------------------------------------------------
# Booleans and counters that represent buffs, debuffs and combat states.
# =============================================================================
var charmer = false          # True while the player is forced to submit
var charm = -1              # Turns remaining under charm (-1 when inactive)
var taunt = -1              # Enemy taunt duration; increases enemy damage
var SB_Boost = -1           # Turns remaining of SB boost (-1 = none)
var attackup = -1           # Turns remaining of combo buff
var phase = 2               # Current battle phase (1..3)
var disable = 0             # Generic disable flag (unused)
var build = 0               # Build up meter for enemy AI (unused)
var aistrats = 0            # AI strategy flag (unused)
var SB = 0                  # SB meter value used for special actions
var submit = 0              # Submission counter used during headscissor
var freedodge = 0           # Allows a free dodge when > 0
var kickmiss = 0            # How many times player dodged a kick
var kickaccuracy = 0        # Current kick accuracy modifier
var bleeding = 0            # Turns remaining of bleed damage

# =============================================================================
# Combat Stats
# -----------------------------------------------------------------------------
# Numerical values for player/enemy stats and timers.
# =============================================================================
var playerdefense = 10      # Base defense stat
var enemyspeed = 1          # Enemy speed used in quick‑time events
var playerspeed = 10        # Player speed stat
var criticalenemydamage = 6 # Extra damage dealt on enemy critical hits
var turn_count = 1          # Number of turns elapsed
var enemyattack = 15        # Base damage from enemy attacks
var playerdam = 2           # Base player attack damage
var enemydam = 2            # Base enemy damage? (unused)
var playerhp = 100          # Player current HP
var playersp = 50           # Player current SP
var playermaxsp = 50        # Player maximum SP
var playermaxhp = 100       # Player maximum HP
var enemyhp = 600           # Enemy current HP

# Random number generator for various rolls
var rng = RandomNumberGenerator.new()
# When 1, stumbling is guaranteed
var stumble = 0
# When 1, next hit will critically strike
var crit = 0

# =============================================================================
# Dialogue State Machine
# -----------------------------------------------------------------------------
# Controls the typewriter effect and textbox interaction.
# =============================================================================
signal textbox_closed                # Fired when player closes dialogue
signal close_skill_menu              # Used to close the skill menu externally
var skillmenu = 0                    # 1 while the skill menu is open

enum state { ready, reading, finished }
@onready var currentstate = state.ready  # Active textbox state
var statechange = 0                       # Set to 1 to request a state change
@onready var next_char = $TB.visible_characters  # Tracks character count

# =============================================================================
# Display & Tween Helpers
# -----------------------------------------------------------------------------
# Tween and audio helpers for the typewriter effect.
# =============================================================================
@onready var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
var current_char = 0              # Index of the last played character tick
var ankhatext = 0                 # 1 while Ankha is speaking
var legstatus = 0                 # 2 when player is locked in headscissor
var time2die = 1                  # Countdown before instant loss
var quicktime = false             # True when a quick‑time event is active
var quicktimesuccess = false      # Result of the quick‑time event
var attackcount = 0               # Number of consecutive player attacks
var kickhit = 0                   # Tracks whether kick connected

# -----------------------------------------------------------------------------
# Helper: play a tick sound when text advances.
# "texq" delays audio ticks so the sound is not played every frame.
# -----------------------------------------------------------------------------
func textq():
    """Plays a sound whenever a new character appears on screen."""
    if ankhatext == 1:
        next_char = $TB.visible_characters  # $TB is the on‑screen dialogue Label
        if next_char > current_char:
            current_char = next_char
            $ankhatextding.play()  # sound effect for Ankha's dialogue
            if current_char == current_char:
                print(current_char)
    else:
        next_char = $TB.visible_characters
        if next_char > current_char:
            current_char = next_char
            $H_LetGo/textding.play()  # generic text blip sound
            if current_char == current_char:
                print(current_char)

# =============================================================================
# Process Loop
# -----------------------------------------------------------------------------
# Handles turn logic, quick‑time events and textbox state transitions.
# =============================================================================
func _process(delta):
    """Frame update: handles UI updates and dialogue state machine."""
    $SB_bar.value = SB  # ProgressBar showing current SB meter

    # Phase transition check
    if enemyhp < 400:
        print("phase 2 is on")
        phase = 2

    # Taunt buff temporarily increases enemy damage
    if taunt > 0:
        enemyattack = 50
        playerdam = 5
    else:
        playerdam = 2
        enemyattack = 15

    quicktimeevent()  # listen for quick‑time input when active


    match currentstate:
        state.ready:
            if statechange == 1:
                await(changestate(state.reading))
            else:
                pass
        state.reading:
            # Play tick sounds as characters appear
            textq()

            if Input.is_action_just_pressed("ui_accept"):
                $TB.visible_characters = len($TB.text)
                tween.stop()
                changestate(state.finished)

            pass
            await(get_tree().create_timer(1).timeout)
        state.finished:
            if Input.is_action_just_pressed("ui_accept"):
                $TB.hide()
                $AnkhaIcon.hide()
                emit_signal("textbox_closed")
                changestate(state.ready)

                pass


# =============================================================================
# Initialization
# -----------------------------------------------------------------------------
# Hides and resets all UI elements on scene load.
# =============================================================================
func _ready():
    """Initial setup for UI widgets and battle state."""
    $"Submit/Submit Bar".hide()     # ProgressBar for submission mini‑game
    $Submit/FelineFlash.hide()       # Skill button
    $Submit/ThighTomb.hide()
    $Submit/StayStill.hide()
    $Speedboost.hide()
    $"Pre-Kick".hide()
    $SMbox.hide()                    # Small text pop‑ups
    $AnkhaIcon.hide()                # Sprite displayed when Ankha speaks
    $kickpost.hide()
    $kickhit.hide()
    $H_LockIn.hide()
    $H_LetGo.hide()
    $H_Squeeze.hide()
    $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    $HP/AnimationPlayer.play("move down")
    $TB.hide()
    $JumpKick.hide()
    $Flash.hide()
    $FlyingKick.hide()
    $GetUp.hide()
    $RHCrit.hide()
    $CritStance.hide()
    $SkillsM.hide()                  # Skill selection menu
    $R_Headscissor.hide()
    $R_Headscissor2.hide()
    $A_Roundhouse.hide()
    $H_Sitdown.hide()
    $H_Prep.hide()
    $kickmiss.hide()

# -----------------------------------------------------------------------------
# Quick Time Event helper.
# -----------------------------------------------------------------------------
func quicktimeevent():
    """Checks for quick‑time event input when active."""
    if quicktime == true:
        if Input.is_action_just_pressed("qte"):
            quicktimesuccess = true
            print("qte is working")
            pass

# -----------------------------------------------------------------------------
# Opens the skill menu UI and pauses the regular attack UI.
# -----------------------------------------------------------------------------
func skill_menu():
    """Displays the skill selection menu."""
    $SkillsM.show()
    $Attack.hide()
    $Skills.hide()
    $HP/AnimationPlayer.play("moveup")
    emit_signal("close_skill_menu")
    skillmenu = 1

# -----------------------------------------------------------------------------
# Buff that guarantees the next attack will be a critical hit.
# -----------------------------------------------------------------------------
func critboost():
    """Applies a one‑turn critical hit buff to the player."""
    $CritStance.show()
    $CritStance/AnimationPlayer.play("fadein")
    display_text("Ankha strikes a fighting stance!")
    await(textbox_closed)
    crit = 1
    display_text("Her next attack will be a critical hit!")
    await(textbox_closed)
    $CritStance/AnimationPlayer.play("fadeout")
    player_turn()

# -----------------------------------------------------------------------------
# Checks if the player or enemy has been defeated and ends the game.
# -----------------------------------------------------------------------------
func deathcheck():
    """Ends the game if the player's HP reaches zero."""
    if playerhp <= 0:
        display_text("You died lol")
        await(textbox_closed)
        get_tree().quit()

func enemydeathcheck():
    """Ends the game if the enemy's HP reaches zero."""
    if enemyhp <= 0:
        display_text("You won!")
        await(textbox_closed)
        get_tree().quit()
        await(get_tree().create_timer(1).timeout)

# -----------------------------------------------------------------------------
# Handles the start of the player's turn including status effects.
# -----------------------------------------------------------------------------
func player_turn(rng = 0):
    """Begins the player's turn and processes ongoing effects."""

    # Charm forces the player to submit instead of attacking
    if charm >= 1:
        charm -= 1
        display_text("Your lust clouds your judgement!")
        await(textbox_closed)
        rng = 1  # rng.randi_range(1, 3) in future
        if rng == 1:
            SB += 15
            display_text("You get on your knees and beg Ankha to wrap\nher thighs around your head.")
            await(textbox_closed)
            display_text("Ugh, you're a freak, \nyou know that.", 0.05, true)
            await(textbox_closed)
            display_text("But very well...", 0.05, true)
            await(textbox_closed)
            display_text("She kicks you down to the ground.", 0.05, false)
            await(textbox_closed)
            charmer = true
            await(headscissor())
            return

        if rng == 2:
            SB += 10
            display_text("You stick your tongue and ask Ankha if you\ncould worship her soles.")
            await(textbox_closed)
            display_text("Ugh, you're a freak,\nyou know that.", 0.05, true)
            await(textbox_closed)
            display_text("But very well...", 0.05, true)
            await(textbox_closed)
            display_text("She kicks you down to the ground.", 0.05, false)
            await(textbox_closed)
            charmer = true
            await(footgag())
            return
        # roundhouse works but footgag and headscissor need fixing
        if rng == 3:
            display_text("You point at your cheek and ask Ankha if she could \nkick you there again.")
            await(textbox_closed)
            display_text("Ugh, you're a freak, you know that.", 0.05, true)
            await(textbox_closed)
            display_text("But very well...", 0.05, true)
            await(textbox_closed)
            display_text("You close your eyes as you brace for impact.")
            await(textbox_closed)
            submit = 3
            # apply charmer = true solution to footgag and headscissor
            charmer = true
            await(roundhouse_kick())
            return

    # Countdown and removal for temporary buffs
    if SB_Boost > 0:
        SB_Boost -= 1

    if SB_Boost == 0:
        SB_Boost -= 1
        display_text("Your SB boost is over.")
        await(textbox_closed)

    if attackup > 0:
        attackup  -= 1

    if attackup == 0:
        print(str(attackcount) + "is attack acount")
        attackup -= 1
        display_text("Your combo buff is over.")
        await(textbox_closed)

    # If locked in headscissor automatically resolve it
    if legstatus == 2:
        await(headscissor())
        $Background/AnimationPlayer.play("attack_phase")
        $Amy/AnimationPlayer.play("attack_phase")
        legstatus = 0
        player_turn()
        return

    # Unique dialogue for the very first turn
    if turn_count == 1:
        display_text("H-Hey!", 0.02, true)
        $Camera2D/AnimationPlayer.play("shake")
        await(textbox_closed)
        display_text("You're not supposed\n to dodge that!", 0.05, true)
        await(textbox_closed)
        display_text("I command you to\n stay still!", 0.05, true)
        await(textbox_closed)
        ankhatext = 0

    # Enemy reacts if too many kicks miss in a row
    if kickmiss == 2:
        display_text("God damn it!", 0.02, true)
        $Camera2D/AnimationPlayer.play("shake")
        await(textbox_closed)
        display_text("If you dodge one\n more frickin' time...", 0.05, true)
        await(textbox_closed)
        display_text("I. WILL. END. YOU.", 0.2, true)
        await(textbox_closed)
        display_text("She seems to be attacking more\n violently every time she misses.")
        await(textbox_closed)
        display_text("Maybe letting her hit you could\n calm her down...?")
        kickmiss += 1
        await(textbox_closed)

    # Bleeding damage over time
    if bleeding >= 1:
        bleeding -= 1
        print("bleeding is " + str(bleeding))
        display_text("You don't feel so good...")
        await(textbox_closed)
        print("bleeding off")
        await(Bleeding())
        print("bleeding on")
        $Background/AnimationPlayer.play("attack_phase")
        $Amy/AnimationPlayer.play("attack_phase")
        $TB.hide()
        $Attack.show()
        $Skills.show()
        if bleeding == 0:
            display_text("You're feel much better now!")
            await(textbox_closed)
            $Attack.show()
            $Skills.show()
    else:
        $Background/AnimationPlayer.play("attack_phase")
        $Amy/AnimationPlayer.play("attack_phase")
        $TB.hide()
        $Submit.show()
        $Attack.show()
        $Skills.show()

# =============================================================================
# Input Handling
# -----------------------------------------------------------------------------
# Responds to player input outside the main battle loop.
# =============================================================================
func _input(_event):
    """Handles global input such as closing the skill menu."""

    if Input.is_action_just_pressed("ui_cancel"):
        $SkillsM.hide()
        $Attack.show()
        $Skills.show()
        $"Submit/Submit Bar".hide()
        $Submit/FelineFlash.hide()
        $Submit/ThighTomb.hide()
        $Submit/StayStill.hide()

        emit_signal("close_skill_menu")


# =============================================================================
# Display Helpers
# -----------------------------------------------------------------------------
# Utility functions for showing text boxes and small popups.
# =============================================================================
func display_attack(text):
    """Shows a temporary pop‑up describing the enemy attack."""
    $SMbox.show()
    $SMbox/AnimationPlayer.play("slidein")
    $SMbox.text = text
    await(get_tree().create_timer(2).timeout)
    $SMbox/AnimationPlayer.play("slideout")
    await(get_tree().create_timer(1).timeout)
    $SMbox.hide()

func display_text(text, readrate = 0.05, ankha = false):
    """Displays scrolling text in the main textbox."""
    if ankha == true:
        $AnkhaIcon.show()
        ankhatext = 1
    else:
        pass

    current_char = 0
    statechange = 1
    tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
    changestate(state.reading)
    $Attack.hide()
    $TB.show()
    $TB.text = text

    $TB.visible_characters = 0

    tween.tween_property($TB, "visible_characters", len(text), len(text) * readrate)
    await(tween.finished)
    if tween.finished:
        changestate(state.finished)
        statechange = 0
    ankhatext = 0

    
    
func changestate(nextstate):
    currentstate = nextstate
    match currentstate:
        state.ready:
            print("state is ready")
        state.reading:
            print("state is reading")
        state.finished:
            print("state is finished")
       
            
           


func headscissor(chance = 0, times = 0):
    #chance = 2 #rng.randi_range(0, 2)
    #if chance == 2 or stumble == 1:
        #print("headscissor in effect")
        #display_text("You start to stumble...")
        #await(textbox_closed)
        #chance = rng.randi_range(0, 2)
        #stumble = 0
        #if chance == 1:
                #display_text("And you fell down!")
                #await(textbox_closed)
    $H_Sitdown.show()
    display_attack("Thigh Tomb")
    display_text("Ankha hops on top of you!")
    await(textbox_closed)
    $H_Sitdown/AnimationPlayer.play("slideleft")
    $H_Prep.show()
    $H_Prep/AnimationPlayer.play("slidein")
    display_text("She wraps her thighs around 
    your head and..")
    await(textbox_closed)
    $H_Sitdown/AnimationPlayer.play("slideout")
    $H_Prep/AnimationPlayer.play("slideleftup")
    display_text("")
    await(get_tree().create_timer(0.4).timeout)
    $H_Prep.hide()
    $Flash.show()
    await(get_tree().create_timer(0.1).timeout)
    $Flash.hide()
    for i in 4:
        $H_Squeeze.show()
        $Camera2D/AnimationPlayer.play("shake")
        $H_Squeeze/AnimationPlayer.play("squeeze")
        #$R_Headscissor/AnimationPlayer.play("shake")
        print(i)
        times = rng.randi_range(-13, -10)
        playerhp = playerhp - enemyattack - times
        display_text("You took " + str(enemyattack + times) + " damage", 0.02)
        $ScissorCrush.play()
        if playerhp <= 0:
            playerhp = 0
        $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
        await(get_tree().create_timer(0.5).timeout)
        await(deathcheck())
    $H_Squeeze.hide()
    
    $H_LetGo.show()
    $H_LetGo/AnimationPlayer.play("letgo")
    chance = rng.randi_range(0, 3)
    display_text("You tried to break out...")
    await(textbox_closed)
    if chance == 1:
        $R_Headscissor.hide()
        display_text("And you were successful!")
        $R_Headscissor.hide()
        $H_LetGo.hide()
        $H_LockIn.hide()
        await(textbox_closed)
        if charmer == true:
            charmer = false
            enemyturn()
        else:
            player_turn()
        return
    else:
        display_text("But you failed...", 0.1)
        await(textbox_closed)
        display_text("She squeezes even more tightly!")
        await(textbox_closed)
        $H_LetGo.hide()
        $H_LockIn.show()
        $H_LockIn/AnimationPlayer.play("lockin")
        await(get_tree().create_timer(0.4).timeout)
        for i in 8:
            $H_LockIn.hide()
            $H_Squeeze.show()
            $Camera2D/AnimationPlayer.play("shake")
            $H_Squeeze/AnimationPlayer.play("squeeze")
            print(i)
            times = rng.randi_range(-10, -5)
            playerhp = playerhp - enemyattack - times
            display_text("You took " + str(enemyattack + times) + " damage", 0.02)
            $ScissorCrush.play()
            if playerhp <= 0:
                playerhp = 0
            $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
            await(get_tree().create_timer(0.4).timeout)
            $H_LetGo.hide()
        await(deathcheck())
        chance = rng.randi_range(0, 1)
        $H_LetGo.show()
        $H_LetGo/AnimationPlayer.play("letgo")
        display_text("You tried to break out...")
        await(textbox_closed)
    if chance == 1: #1:
        $R_Headscissor.hide()
        $H_LetGo.hide()
        $H_LockIn.hide()
        display_text("And you were successful!")
        await(textbox_closed)
        if charmer == true:
            charmer = false
            enemyturn()
        else:
            player_turn()
        return
    else:
        display_text("But you failed...", 0.1)
        await(textbox_closed)
        display_text("She grabs ahold of your arms this time.")
        await(textbox_closed)
        display_text("There's no escape.", 0.35)
        await(textbox_closed)
        $H_LetGo.hide()
        $H_LockIn.show()
        $H_LockIn/AnimationPlayer.play("lockin")
        await(get_tree().create_timer(0.4).timeout)
        for i in 32:
            $H_LockIn.hide()
            $H_Squeeze.show()
            $Camera2D/AnimationPlayer.play("shake")
            $H_Squeeze/AnimationPlayer.play("squeeze")
            print(i)
            times = rng.randi_range(-10, 10)
            playerhp = playerhp - enemyattack - times
            display_text("You took " + str(enemyattack + times) + " damage", 0.01)
            $ScissorCrush.play()
            if playerhp <= 0:
                playerhp = 0
            $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
            await(get_tree().create_timer(0.3).timeout)
        await(deathcheck())
#else:
    #display_text("But you were able to 
    #regain your footing!")
    #await(textbox_closed)
    #return
            
    #display_text("And you were successul!")
    #await(textbox_closed)
    #display_text("But you failed...")
    #await(textbox_closed)

func charming():
    display_attack("Charmer")
    display_text("Ankha strikes a sexy pose!")
    await(textbox_closed)
    display_text("Oh no! You've been charmed!")
    await(textbox_closed)
    charm =+ 3
    player_turn()
    

func throatkick(counterdam = 0):
    display_attack("Bloody Rain")
    display_text("Ankha dodged your punch!")
    await(textbox_closed)
    display_text("She lifts her leg up and...")
    await(textbox_closed)
    counterdam = rng.randi_range(10, 25)
    playerhp = playerhp - enemyattack - counterdam - 20
    $Camera2D/AnimationPlayer.play("shake")
    $ScissorCrush.play()
    if playerhp <= 0:
        playerhp = 0
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp) 
    display_text("Counters with a kick to your throat")
    await(textbox_closed)
    await(deathcheck())
    display_text("You stumble backwards at you as you 
    cough up blood!")
    await(textbox_closed)
    display_text("You took " + str(enemyattack + 20 + counterdam) + " damage!")
    bleeding += 3
    await(textbox_closed)
    player_turn()
    
func footgag(times = 0, chance = 0, norepeat = 0):
    display_attack("Choking Hazard")
    display_text("Ankha forcefully shoves her foot down your throat!")
    await(textbox_closed)
    display_text("You start gagging on her soles!")
    await(textbox_closed)
    chance = 1 #rng.randi_range(1, 2)
    for i in 10:
        $Camera2D/AnimationPlayer.play("shake")
        times = rng.randi_range(-14, -9)
        if chance == 1:
            playersp = playersp - enemyattack - times
            if playersp <= 0:
                playersp = 0
            display_text("You lost " + str(enemyattack + times) + " SP!", 0.02)
            $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
            $ScissorCrush.play()
            norepeat = 1
        else:
            SB = SB - enemyattack - times
            display_text("You lost " + str(enemyattack + times) + " SB!", 0.02)
            print("Current SB: " + str(SB))
            $ScissorCrush.play()
            $SB_bar.value = SB
            if SB <= 0:
                SB = 0
            norepeat = 2
        await(get_tree().create_timer(0.4).timeout)
    display_text("You tried to break free...")
    await(textbox_closed)
    display_text("But she shoves her foot down your mouth again!")
    await(textbox_closed)
    display_text("You start choking...")
    await(textbox_closed)
    for i in 10:
        $Camera2D/AnimationPlayer.play("shake")
        $H_Squeeze/AnimationPlayer.play("squeeze")
        times = rng.randi_range(-14, -9)
        print("chance is: " + str(chance))
        if norepeat == 1:
            chance = 2
        if norepeat == 2:
            chance = 1
        if chance == 1:
            playersp = playersp - enemyattack - times
            display_text("You lost " + str(enemyattack + times) + " SP!", 0.02)
            if playersp <= 0:
                playersp = 0
            display_text("You lost " + str(enemyattack + times) + " SP!", 0.02)
            $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
            $ScissorCrush.play()
        else:
            print("Count is 1 but should be: " + str(i))
            SB = SB - enemyattack - times
            display_text("You lost " + str(enemyattack + times) + " SB!", 0.02)
            $ScissorCrush.play()
            $SB_bar.value = SB
            if SB <= 0:
                SB = 0
            
        await(get_tree().create_timer(0.4).timeout)
    display_text("You tried to break free again...")
    await(textbox_closed)
    display_text("But you failed...")
    await(textbox_closed)
    display_text("Hmph, look at you. 
    You're disgusting...", 0.05, true)
    await(textbox_closed)
    display_text("Now begone with you!", 0.05, true)
    await(textbox_closed)
    display_text("Ankha kicks you in the chin as you fly into the air!", 0.05, false)
    $Camera2D/AnimationPlayer.play("shake")
    playerhp = playerhp - enemyattack - 5
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    await(textbox_closed)
    display_text("And crash into the ground!")
    $Camera2D/AnimationPlayer.play("shake")
    playerhp = playerhp - enemyattack - 5
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    await(textbox_closed)
    chance = 0
    display_text("You took " + str(enemyattack + enemyattack + 10) + " damage!")
    await(textbox_closed)
    $Background/AnimationPlayer.play("attack_phase")
    $Amy/AnimationPlayer.play("attack_phase")
    if charmer == true:
        charmer = false
        enemyturn()
        print("is this running during charmer too [footgag]?")
    else:
        print("this shouldn't be on!")
        player_turn()
func kneel(chance = 0):
    display_text("Ankha leaps into the air...")
    
    display_text("You look up in the air and suddenly...")
    await(textbox_closed)
    chance = rng.randi_range(1, 2)
    if chance == 1:
            criticalenemydamage = rng.randi_range(5, 10)
            playerhp = playerhp - enemyattack - criticalenemydamage
            if playerhp <= 0:
                    playerhp = 0
            $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
            display_text("Ankha hits you with an axe kick!")
            await(textbox_closed)
            display_text("The attack leaves you kneeling, groveling beneath her feet.")
            await(textbox_closed)
            display_text("You took " + str(enemyattack + criticalenemydamage) + " damage.")
            await(textbox_closed)
            stumble = 1
            await(grounded_attacks())
            
    if chance == 2:
        display_text("You quickly dodge as Ankha tries hitting you with an axe kick!")
        await(textbox_closed)
        $Background/AnimationPlayer.play("attack_phase")
        $Amy/AnimationPlayer.play("attack_phase")
        player_turn()
        
func enemyturn(attackselection = 1, chance = 0, norepeat = 0):
    
    
    if taunt > 0:
        taunt -= 1
        
    if taunt == 0:
        taunt -= 1
        display_text("Ankha is no longer angry.")
        await(textbox_closed)
        
    if turn_count == 0:
        display_text("Ugh! How dare you 
        hit me?!", 0.05, true)
        await(textbox_closed)
        display_text("I will put you 
        down like the rest 
        of your kind!", 0.05, true )
        await(textbox_closed)
        display_text("Filthy human!", 0.2, true)
        await(textbox_closed)
        ankhatext = 0
        $Background/AnimationPlayer.play("attack_phase_transition")
        $Amy/AnimationPlayer.play("attack_phase_transition")
        freedodge = 1
        roundhouse_kick()
        turn_count += 1
        return
    
    turn_count += 1
    $Background/AnimationPlayer.play("attack_phase_transition")
    $Amy/AnimationPlayer.play("attack_phase_transition")
    #strategy chooser
    if aistrats == 0:
        aistrats = 3 #rng.randi_range(1, 2)  #3 
    #if phase == 2:
        #if aistrats == 0:
            #aistrats = rng.randi_range(1, 4)
    #
        
    if aistrats == 3:
        print("Drain is working.")
        #footgag()
        #kneel()
        #throatkick()
        charming()
        return
        
    if aistrats == 1:
        print("Build is working")
        build = 1.0
        aistrats = 1.1
        
    if build > 0.9 and build < 1.2:
        if phase == 2:
            build += 0.2
            await(roundhouse_kick())
            kickmiss += 5
        else:
            build += 0.1
            print("DOODLE BOBU " + str(build))
            await(roundhouse_kick())
            
        

    elif build >= 1.5:
        roundhouse_kick()
        build = 0
        aistrats = 0
        return
        
    elif build >= 1.2:
        if phase == 2 and kickaccuracy > 0:
            chance = rng.randi_range(1, 2)
            #if legstatus == 1:
                #kneel()
                #legstatus = 0
                #build = 0
                #aistrats = 0
                #return
            if chance == 1 or norepeat == 1:
                build += 0.1
                kick_up()
                norepeat = 0
            elif chance == 2 and norepeat == 0:
                legkick()
                norepeat = 1
                print("norepeat is now 1")
            
                
        else:        
            build += 0.1
            print("YOOO LETS GO " + str(build))
            kick_up()
            #
    
        
    #disable 
    if aistrats == 2:
        print("Disable is working")
        #print("This value should be fucking 1 but instead it's " + str(aistrats))
        disable = 1
        aistrats = 2.2
        
    if disable > 0.9 and disable < 1.2:
        disable += 0.1
        print("dada!" + str(disable))
        if kickaccuracy == 3:
            roundhouse_kick()
            disable = 0
            aistrats = 0
        if phase == 2:
            chance = rng.randi_range(1, 2)
            if chance == 1:
                kick_up()
            elif chance == 2:
                #throat_kick()
                pass
        else:
            kick_up()
    
    elif disable >= 1.3:
        print("YEEEEAAAAH!!!")
        roundhouse_kick()
        disable = 0
        aistrats = 0
        return
        
    elif disable > 1.2:
        print("tata! " + str(disable))
        await(legkick())
        if legstatus == 2:
            print("leg off")
            disable = 0
            aistrats = 0
        else:
            disable += 0.1
    
        
    #attackselection = rng.randi_range(1, 2)
    #if kickaccuracy == 2:
        #attackselection = rng.randi_range(1, 3)
        #print("it's up!")
        #
    #if attackselection == 1:
        #roundhouse_kick()
        ##headscissor()
        ##kick_up()
    ##if attackselection == 2:
        ##if crit == 1:
            ##roundhouse_kick()
        ##else:
            ##flying_kick()
    #if attackselection == 2:
        #if kickaccuracy == 3 or legstatus == 2:
            #roundhouse_kick()
        #else:
            #kick_up()
    #
    #if attackselection == 3:
        #if legstatus == 2:
            #roundhouse_kick()
        #else:
            #legkick()

func dialogue():
    display_text("Woah, you're terrible!") 
    await(textbox_closed)
    display_text("Take this!")
    await(textbox_closed)
    
func _on_skills_pressed():
    $HP/AnimationPlayer.play("moveup")
    skill_menu()
    $HP/AnimationPlayer.play("moveup")
    await(close_skill_menu)
    $HP/AnimationPlayer.play("move down")
        
    

func _on_jab_combo_pressed():
    if playersp < 25:
        $SkillsM.hide()
        display_text("You don't have enough SP!")
        await(textbox_closed)
        $SkillsM.show()
        return
    else:
        playersp -= 25
        skillmenu = 0
        $HP/AnimationPlayer.play("move down")
        $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
        await(jab_combo())
        enemyturn()
        

func Bleeding(bleeddamage = 0, chance = 0):
    #chance = rng.randi_range(0, 1)
    #print("your chance was: " + str(chance))
    if chance == 0:
        display_text("You're coughing up blood!")
        await(textbox_closed)
        bleeddamage = rng.randi_range(5, 20)
    
        playerhp = playerhp - bleeddamage
        if playerhp <= 0:
            playerhp = 0
        $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp) 
        display_text("You lost " + str(bleeddamage) + "HP.")
        await(textbox_closed)
        print("bleed" + str(bleeddamage))
        await(deathcheck())
    else:
        pass


    
func grounded_kick(chance = 0, criticaldamage = 0):
    chance = rng.randi_range(0, 4)
    if chance == 2 or stumble == 1:
        display_text("You start to stumble...")
        await(textbox_closed)
        chance = rng.randi_range(0, 1)
        stumble = 0
    else:
            return 
    if chance == 1:
        display_text("And you fell down!")
        await(textbox_closed)
    
        display_text("Ankha starts to wind up her foot...")
        await(textbox_closed)
        $Flash.show()
        await(get_tree().create_timer(0.1).timeout)
        $Flash.hide()
        $GetUp.show()
        $GetUp/AnimationPlayer.play("jumpkick")
        criticaldamage = criticalenemydamage +  + rng.randi_range(10, 50)
        playerhp = playerhp - criticaldamage + playerdefense
        if playerhp <= 0:
            playerhp = 0
        $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
        display_text("And WHAM! Smacks you 
        off the ground!")
        await(textbox_closed)
        display_text("You lost a whopping " + str(criticaldamage) + " HP!")
        $GetUp.hide()
        await(textbox_closed)
        await(deathcheck())
    else:
        display_text("But you were able to 
        regain your footing!")
        await(textbox_closed)
        pass
    

    

func flying_kick(hitchance = 0, bleedchance = 0):
    display_text("Amy takes off her boots and
     leaps in the air!")
    await(textbox_closed)
    hitchance = rng.randi_range(1, 10)
    if hitchance <= playerspeed:
        print("hitchance was" + str(hitchance))
        display_text("You quickly duck and 
        barely avoided her kick!")
        await(textbox_closed)
        crit = 0
        player_turn()
        return
    else:
        $Flash.show()
        await(get_tree().create_timer(0.1).timeout)
        $Flash.hide()
        player_took_damage()
        print(playerhp)
        $FlyingKick.show()
        $FlyingKick/AnimationPlayer.play("jumpkick")
        display_text("And kicks you in the throat!")
        await(textbox_closed)
        display_text("You took " + str(enemyattack - playerdefense) + " damage")
        await(textbox_closed)
        $FlyingKick.hide()
        bleedchance = rng.randi_range(0,1)
        if bleedchance == 1:
            bleeding += 3
            await(deathcheck())
            player_turn()
        else:
            await(deathcheck())
            player_turn()
    
    
func jab_combo(punchcount = 0, hitchance = 0):
    $SkillsM.hide()
    display_text("You strike a fighting stance!")
    await(textbox_closed)
    #hitchance = rng.randi_range(1, 10)
    attackup = 3
    display_text("Your combo damage has increased for 3 turns!")
    await(textbox_closed)
    
    #if hitchance <= enemyspeed:
        #print("hitchance was" + str(hitchance))
        #display_text("But all your punches missed?!")
        #await(textbox_closed)
        #return
    #else:
        #punchcount = rng.randi_range(2, 10)
        #enemyhp = enemyhp - playerdam * punchcount
        #display_text("You landed " + str(punchcount) + " punches!" )
        #await(textbox_closed)
        #display_text("You dealt " + str(playerdam * punchcount) + " damage!")
        #await(textbox_closed)
        #await(enemydeathcheck())
    #
func rush(timer = 0, textdisplay = 0):
    
    $Camera2D/AnimationPlayer.play("shake")
    textdisplay = rng.randi_range(1, 3)
    timer = rng.randf_range(0.15, 0.20)
    if textdisplay == 1:
        display_text("Once again...", 0.02)
    if textdisplay == 2:
        display_text("One more time...", 0.02)
    if textdisplay == 3:
        display_text("Keep it going...", 0.02)
    
    if attackcount > 4 and attackcount < 8:
        timer = rng.randf_range(0.1, 0.15)
        attackcount += 2
        if attackup > 0:
            print("attackup 1 is working")
            attackcount += 3
            
    if attackcount > 8 and attackcount < 10:
        timer = rng.randf_range(0.05, 0.1)
        attackcount += 3
        if attackup > 0:
            print("attack up is working")
            attackcount += 5
        
    if attackcount > 10: 
        timer = rng.randf_range(0.01, 0.05)
        attackcount += 5
        if attackup > 0:
            print("attack up 2 is working")
            attackcount += 10
        
        
    await(get_tree().create_timer(0.50).timeout)
    quicktime = true
    $Flash.show()
    await(get_tree().create_timer(timer).timeout)
    print(timer)
    quicktime = false
    $Flash.hide()
    if quicktimesuccess == true:
        $Camera2D/AnimationPlayer.play("shake")
        quicktimesuccess = false
        SB += 1
        $SB_bar.value += 1
        if SB_Boost > 0:
            SB += 3
            $SB_bar.value += 3
            
        attackcount += 1
        await(rush())
    else:
        quicktimesuccess = false
        enemyhp = enemyhp - playerdam * attackcount
        display_text("You dealt  " + str(playerdam * attackcount) + " damage")
        await(textbox_closed)
        attackcount = 0
        await(enemydeathcheck())
    
    
func player_attack(critchance = 0, critdamage = 0, hitchance = 0):
    
    display_text("You rush towards Ankha!")
    await(textbox_closed)
    #hitchance = rng.randi_range(1, 10)
    #if hitchance <= enemyspeed:
        #print("hitchance was" + str(hitchance))
        #display_text("But you missed?!")
        #await(textbox_closed)
        #return
    #else:
        ## $Amy/AnimationPlayer.play("enemydamage")
        #critchance = rng.randi_range(0, 2)
        #critdamage = rng.randi_range(5, 10)
    #if critchance == 1:
        #enemyhp = enemyhp - playerdam - critdamage
        #display_text("You landed a critical blow")
        #await(textbox_closed)
        #display_text("You dealt " + str(playerdam + critdamage) + " damage!")
        #await(textbox_closed)
        #await(enemydeathcheck())
    #else:
    if legstatus == 1:
        display_text("But your broken legs paralyzes you!")
        await(textbox_closed)
        return
    else:
        $Flash.show()
        quicktime = true
        await(get_tree().create_timer(0.50).timeout)
        $Flash.hide()
        quicktime = false
        if quicktimesuccess == true:
            quicktimesuccess = false
            attackcount += 1 
            await(rush())
        else:
            enemyhp = enemyhp - playerdam * attackcount
                #enemy_took_damage()
            display_text("You missed!")
            await(textbox_closed)
                #await(increase_turn())
            await(enemydeathcheck())



func firstdialogue():
    display_text("How'd my boot against your face feel?")
    await(textbox_closed)
    display_text("Tee-hee! I can't wait to do that again!")
    await(textbox_closed)

func increase_turn():
    turn_count += 1
    print(turn_count)
    
func legkick(status = 0):
    display_attack("Stay Still, Peasant!")
    display_text("Ankha kicks you in the leg!")
    status = 2 #rng.randi_range(2, 3)
    criticalenemydamage = rng.randi_range(5, 10)
    playerhp = playerhp - enemyattack - criticalenemydamage
    if playerhp <= 0:
            playerhp = 0
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    await(textbox_closed)
    
    #if status == 1:
        #display_text("Your leg hurts, but you were able to shrug off the pain!")
        #await(textbox_closed)
        #display_text("You took " + str(enemyattack + criticalenemydamage) + " damage!")
        #await(textbox_closed)
        #legstatus = 0
        #await(deathcheck())
        #player_turn()
        #return
    if status == 2:
        display_text("You grunt as the pain leaves you paralyzed.")
        await(textbox_closed)
        display_text("You took " + str(enemyattack + criticalenemydamage) + " damage!")
        await(textbox_closed)
        legstatus = 1
        await(deathcheck())
        player_turn()
        return
    if status == 3:
        display_text("You scream out in pain as you start losing balance!")
        await(textbox_closed)
        display_text("You took " + str(enemyattack + criticalenemydamage) + " damage!")
        await(textbox_closed)
        legstatus = 2
        await(deathcheck())
        player_turn()
        return
func kick_up():
    kickaccuracy += 1
    display_attack("Foot 2 Face")
    $Speedboost.show()
    $Speedboost/AnimationPlayer.play("kickup")
    if kickaccuracy == 1:
        display_text("Ankha strikes a fighting stance!")
        await(textbox_closed)
        display_text("Her next kick will be slightly more accurate.")
    elif kickaccuracy == 2:
        display_text("Ankha strikes a fighting stance!")
        await(textbox_closed)
        display_text("Her next kick will be dramatically more accurate.")
    elif kickaccuracy == 3:
        display_text("Ankha strikes a fighting stance!")
        await(textbox_closed)
        display_text("Her next kick is guaranteened to hit!")
    await(textbox_closed)    
    $Speedboost.hide()
    player_turn()
    return
    
func roundhouse_kick(critchance = 0, criticalenemydamage = 0, hitchance = 0, attackselection = 0):
    if submit == 1:
        submit = 2
        kickmiss = 0
    var revengemeter = kickmiss * 30
    display_attack("Feline Flash")
    $"Pre-Kick".show()
    $"Pre-Kick/AnimationPlayer".play("prekick")
    display_text("Ankha gets into position...")
    await(get_tree().create_timer(0.4).timeout)
    $Camera2D/AnimationPlayer.play("shake")
    await(textbox_closed)
    $"Pre-Kick".hide()
    $dashzoom.play()
    $Camera2D/AnimationPlayer.play("shake")
    $Flash.show()
    await(get_tree().create_timer(0.1).timeout)
    $Flash.hide()
    $chargezoom/AnimationPlayer.play("new_animation")
    $A_Roundhouse.show()
    $A_Roundhouse/AnimationPlayer.play("jitter")
    display_text("And rushes towards 
    you at high speeds!")
    await(textbox_closed)
    $chargezoom/AnimationPlayer.stop()
    $chargezoom.stop()
    hitchance = rng.randi_range(4, 11)
    
    
        
    if kickaccuracy == 1:
        hitchance = rng.randi_range(5, 14)
    
    elif kickaccuracy == 2:
        hitchance == rng.randi_range(7, 20)
    
    
    elif kickaccuracy == 3:
        hitchance = 999
        legstatus = 0
        submit = 0
    
    if submit == 2:
        print("This should hit.")
        hitchance = 999
        legstatus = 0
        submit = 1
    
    if submit == 3:
        hitchance = 999
        submit = 0
        SB += 5
            
    if legstatus == 1:
        print("leg should be fucking broken")
        hitchance = 999
        revengemeter = rng.randi_range(40, 70)
        legstatus = 0
        if submit == 2:
            revengemeter = 0
            legstatus = 0
            kickaccuracy = 0
            submit = 1
    
    if freedodge == 1:
        hitchance = 0
        
    if hitchance <= playerspeed:
        $kickmiss.show()
        $kickmiss/AnimationPlayer.play("shake")
        $hitmiss.play()
        $A_Roundhouse.hide()
        print("hitchance was" + str(hitchance))
        display_text("She tried to kick you but missed!")
        await(textbox_closed)
        $kickmiss.hide()
        crit = 0
        kickaccuracy = 0
        kickmiss += 1
        freedodge = 0
        player_turn()
        return
    else:
        kickhit = 1
        kickaccuracy = 0
        $A_Roundhouse.hide()
        $hitwhoosh.play()
        $Flash.show()
        await(get_tree().create_timer(0.1).timeout)
        $Flash.hide()
        critchance = rng.randi_range(0, 1)
        print("critchance is:" + str(critchance))
        criticalenemydamage = rng.randi_range(10, 20)
    #if critchance == 1 or crit == 1: 
    if submit == 1:
        print("syb 1")
        playerhp = playerhp - enemyattack -  criticalenemydamage - revengemeter + playerdefense + 10
    
    else:
        playerhp = playerhp - enemyattack -  criticalenemydamage - revengemeter + playerdefense - 30
    #else:
        #playerhp = playerhp - enemyattack + playerdefense
    if playerhp <= 0:
            playerhp = 0
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    kickmiss = 0
    #dashzoom is placeholder below. replace with better hit sound later
    $kickhit.show()
    $Camera2D/AnimationPlayer.play("shake heavy")
    $dashzoom.play()
    $kickhit/AnimationPlayer.play("shake")
    display_text("and hits you with a roundhouse kick!")
    await(textbox_closed)
    #if critchance == 1 or crit == 1:
        #$RHCrit.show()
        #$RHCrit/AnimationPlayer.play("jumpkick")
    if submit == 1:
        display_text("You took " + str(enemyattack + criticalenemydamage + revengemeter - playerdefense - 10 ) + " damage!")
        #submit = 0
    else:
        display_text("You took " + str(enemyattack + criticalenemydamage + revengemeter - playerdefense + 30) + " damage.")
    await(textbox_closed)
    $kickpost.show()
    $kickhit/AnimationPlayer.play("slideleft")
    $kickpost/AnimationPlayer.play("slidein")
    display_text("Hmph! Pathetic.", 0.1, true)
    await(textbox_closed)
    $AnkhaIcon.hide()
        #await(textbox_closed)
        #$RHCrit.hide()
        #crit = 0
    if submit == 1:
        $kickhit.hide()
        $kickpost.hide()
        await(deathcheck())
        display_text("Your right cheek hurts like hell, 
        but the pain pleases you.")
        await(textbox_closed)
        playersp += 25
        if playersp >= 50:
            playersp = 50
        $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
        display_text("You gained 25 SP!")
        await(textbox_closed)
        submit = 0
        player_turn()
        
    else:
    
        stumble = 1
        #else:
        #display_text("You took " + str(enemyattack - playerdefense) + " damage")
        $kickhit.hide()
        $kickpost.hide()
        #$kickhit.hide()
        await(deathcheck())
        #if stumble == 1:
            #attackselection = 1 #rng.randi_range(1, 2)
            #print("attack selection is" + str(attackselection))
            #if attackselection == 1:
                #await(headscissor())
                #player_turn()
            #if attackselection == 2:
                #await(grounded_kick())
                #player_turn()
        #else:
        if charmer == true:
            charmer == false
            enemyturn()
            print("is this running during charmer too?")
        else:
            player_turn()
            print("this should be disabled during Charmer.")
    
func grounded_attacks(attackselection = 0):
        if stumble == 1:
            attackselection = 1 #rng.randi_range(1, 2)
            print("attack selection is" + str(attackselection))
        if attackselection == 1:
            await(headscissor())
            return
        if attackselection == 2:
            #await(foot_worship())
            player_turn()
        else:
            player_turn()
    #if turn_count == 1:
    #    await(firstdialogue())
    #    player_turn()
    #else:
    #    player_turn()
    #pass
    
#func enemy_took_damage():
    #enemyhp = enemyhp - playerdam
    
    # changes players health variable and updates ui HP text
func player_took_damage():
    playerhp = playerhp - enemyattack + playerdefense 
    if playerhp <= 0:
            playerhp = 0
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    

    
func player_took_critdamage(critchance = 0):
    critchance = rng.randi_range(0, 1)
    print("critchance is:" + str(critchance))
    if critchance == 1: 
        playerhp = playerhp - enemyattack -  rng.randi_range(2, 4)
    else:
        playerhp = playerhp - enemyattack 
    if playerhp <= 0:
            playerhp = 0
    $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp)
    

func _on_attack_pressed():
    get_node("Attack").cancel = 1
    emit_signal("attackselect")
    $Attack2/AnimationPlayer.play("selecthighlight")
    $Attack/select.play()
    $Attack.hide()
    await(get_tree().create_timer(1).timeout)
    $Submit.hide()
    await(player_attack())
    enemyturn()
    get_node("Attack").cancel = 0
    $Attack.show()
    $Attack2/AnimationPlayer.play("movedown")
    $Attack2/AnimationPlayer.play("null")
    
    #if turn_count == 1:
    #    await(dialogue())
    #    roundhouse_kick()
    #else:
    #    roundhouse_kick()
    
func tripleattack():
    pass

#func _on_AnimationPlayer_animation_finished(anim_name):
    #pass

func _on_submit_button_down():
    
    emit_signal("close_skill_menu")
    skillmenu = 1
    $"Submit/Submit Bar".show()
    $Submit/FelineFlash.show()
    $Submit/ThighTomb.show()
    $Submit/StayStill.show()



func _on_feline_flash_button_down():
    if SB <= 25:
        $Submit.hide()
        $"Submit/Submit Bar".hide()
        $Submit/FelineFlash.hide()
        $Submit/ThighTomb.hide()
        $Submit/StayStill.hide()
        display_text("You don't have enough SB!")
        await(textbox_closed)
        $Submit.show()
        $"Submit/Submit Bar".show()
        $Submit/FelineFlash.show()
        $Submit/ThighTomb.show()
        $Submit/StayStill.show()
        return
    else:
        SB -= 25
        $SB_bar.value -= 25
        $Skills.hide()
        $Attack.hide()
        $Submit.hide()
        $"Submit/Submit Bar".hide()
        $Submit/FelineFlash.hide()
        $Submit/ThighTomb.hide()
        $Submit/StayStill.hide()
        display_text("You get down on your knees and tell 
        Ankha that you want to be punished!")
        await(textbox_closed)
        display_text("Oh, I see you've
        learned your 
        place, human.", 0.05, true)
        await(textbox_closed)
        display_text("Fine. I suppose
         I'll grant 
        you your wish.", 0.05, true)
        await(textbox_closed)
        display_text("Now hold still.", 0.05, true)
        await(textbox_closed)
        submit = 1
        ankhatext = 0
        $Background/AnimationPlayer.play("attack_phase_transition")
        $Amy/AnimationPlayer.play("attack_phase_transition")
        roundhouse_kick()

func sb_boost():
    $SkillsM.hide()
    display_text("Your let your perverseness take over!")
    await(textbox_closed)
    SB_Boost = 2
    display_text("Your SB gain will increase next turn!")
    await(textbox_closed)

func gamble(chance = 1, hprestore = 0, sprestore = 0):
    $SkillsM.hide()
    display_text("You grab some magic dice from your pocket.")
    await(textbox_closed)
    display_text("And toss them in the air!")
    await(textbox_closed)
    display_text("And the result is...")
    await(textbox_closed)
    if chance == 1:
        
        hprestore = rng.randi_range(30, 100)
        playerhp += hprestore
        if playerhp >= 100:
            playerhp = 100
        $HP.text = "HP: " + str(playerhp) + "/" + str(playermaxhp) 
        display_text("Vitality! You recovered " + str(hprestore) + " health!")
        await(textbox_closed)
    if chance == 2:
        sprestore = rng.randi_range(10, 50)
        display_text("Spirit! You recovered some SP!")
        #playersp += sprestore
        await(textbox_closed)
    if chance == 3:
        display_text("Doom.")
        await(textbox_closed)
        display_text("You have been marked for death.")
        await(textbox_closed)
        
func Taunt(chance = 0):
    $SkillsM.hide()
    display_text("Your taunted Ankha")
    await(textbox_closed)
    chance = rng.randi_range(1, 2)
    if chance == 1:
        taunt = 3
        display_text("She looks pissed...")
        await(textbox_closed)
        display_text("Her defense has decreaed, but her attack 
        increased dramatically!")
        await(textbox_closed)
    elif chance == 2:
        taunt = -1
        display_text("She starts laughing at you.")
        await(textbox_closed)
        display_text("It didn't seem to work...")
        await(textbox_closed)
    
func _on_headbutt_pressed():
    if playersp < 15:
        $SkillsM.hide()
        display_text("You don't have enough SP!")
        await(textbox_closed)
        $SkillsM.show()
        return
    else:
        playersp -= 15
        skillmenu = 0
        $HP/AnimationPlayer.play("move down")
        $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
        await(sb_boost())
        enemyturn()
        


func _on_taunt_button_down():
    if playersp < 25:
        $SkillsM.hide()
        display_text("You don't have enough SP!")
        await(textbox_closed)
        $SkillsM.show()
        return
    else:
        playersp -= 25
        skillmenu = 0
        $HP/AnimationPlayer.play("move down")
        $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
        await(Taunt())
        enemyturn()    
    
    


func _on_speed_up_button_down():
    if playersp < 15:
        $SkillsM.hide()
        display_text("You don't have enough SP!")
        await(textbox_closed)
        $SkillsM.show()
        return
    else:
        playersp -= 15
        skillmenu = 0
        $HP/AnimationPlayer.play("move down")
        $SP.text = "SP: " + str(playersp) + "/" + str(playermaxsp)
        await(gamble())
        enemyturn()    
        
