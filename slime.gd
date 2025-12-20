extends CharacterBody2D

# ----------------------------------------------------
# Signals
# ----------------------------------------------------
signal died
signal health_changed(current_health, max_health)

# ----------------------------------------------------
# Configuration
# ----------------------------------------------------
const SLIME_SCENE_PATH := "res://Slime.tscn"

const BIG_SLIME_HEALTH := 45.0
const SMALL_SLIME_HEALTH := 1.0
const SMALL_SLIME_SCALE := 0.5
const SPLIT_COUNT := 2

const MOVE_SPEED := 150.0
const JUMP_VELOCITY := -200.0
const GRAVITY := 980.0
const JUMP_INTERVAL := 0.67

const HIT_REACTION_DURATION := 0.2
const KNOCKBACK_FORCE := 150.0
const KNOCKBACK_Y_RATIO := 0.5

# ----------------------------------------------------
# Node References
# ----------------------------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $HitBox
@onready var hurt_box: Area2D = $HurtBox
# تم حذف سطر sfx_player لضمان عمل الأندرويد

# ----------------------------------------------------
# Variables
# ----------------------------------------------------
var size_stage: int = 1         # 1 = كبير | 0 = صغير
var current_health: float = 0.0

enum State { IDLE, JUMP_PREPARE, JUMPING, LAND, HIT, DIE, DEAD }
var current_state: State = State.IDLE

var state_timer: float = 0.0
var target_player: CharacterBody2D = null
var jump_direction: float = 1.0

# ----------------------------------------------------
# Ready
# ----------------------------------------------------
func _ready():
	# ---------- Health & Scale ----------
	if size_stage == 1:
		current_health = BIG_SLIME_HEALTH
		scale = Vector2.ONE
	else:
		current_health = SMALL_SLIME_HEALTH
		scale = Vector2(SMALL_SLIME_SCALE, SMALL_SLIME_SCALE)

		# السلايم الصغير لا يصطدم فيزيائيًا
		set_collision_layer_value(1, false)
		set_collision_mask_value(2, false)
		set_collision_mask_value(3, false)

	# ---------- Signals ----------
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	if hitbox and hitbox.has_signal("hit_target"):
		hitbox.connect("hit_target", Callable(self, "_on_hit_target"))

	if hurt_box and hurt_box.has_signal("hit_received"):
		hurt_box.connect("hit_received", Callable(self, "take_damage"))

	anim.animation_finished.connect(_on_animation_finished)
	add_to_group("enemies")

	var max_h: float = BIG_SLIME_HEALTH if size_stage == 1 else SMALL_SLIME_HEALTH
	emit_signal("health_changed", current_health, max_h)

	change_state(State.IDLE)

# ----------------------------------------------------
# Physics
# ----------------------------------------------------
func _physics_process(delta: float):
	if current_state != State.DEAD and not is_on_floor():
		velocity.y += GRAVITY * delta

	if state_timer > 0:
		state_timer -= delta

	match current_state:
		State.IDLE:
			velocity.x = 0
			if state_timer <= 0 and target_player:
				change_state(State.JUMP_PREPARE)

		State.JUMP_PREPARE:
			if state_timer <= 0:
				change_state(State.JUMPING)

		State.JUMPING:
			pass

		State.LAND:
			velocity.x = 0

		State.HIT:
			velocity.x = move_toward(velocity.x, 0, 10)
			if state_timer <= 0:
				change_state(State.IDLE)

		State.DEAD:
			velocity = Vector2.ZERO
			return

	move_and_slide()

	if current_state == State.JUMPING and is_on_floor():
		change_state(State.LAND)

# ----------------------------------------------------
# State Machine
# ----------------------------------------------------
func change_state(new_state: State):
	current_state = new_state

	match new_state:
		State.IDLE:
			anim.play("Slime_Idle")
			state_timer = JUMP_INTERVAL

		State.JUMP_PREPARE:
			state_timer = 0.3

		State.JUMPING:
			if target_player:
				jump_direction = sign(target_player.global_position.x - global_position.x)
				if jump_direction == 0:
					jump_direction = 1.0

				anim.flip_h = jump_direction > 0
				velocity.y = JUMP_VELOCITY
				velocity.x = jump_direction * MOVE_SPEED

		State.LAND:
			anim.play("Slime_Land")

		State.HIT:
			state_timer = HIT_REACTION_DURATION
			anim.play("Slime_Hurt")

		State.DIE:
			_disable_combat()
			anim.play("Slime_Death")
			velocity = Vector2.ZERO

		State.DEAD:
			if size_stage == 1:
				_split()
			else:
				died.emit()
				queue_free()

# ----------------------------------------------------
# Disable Combat
# ----------------------------------------------------
func _disable_combat():
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)

# ----------------------------------------------------
# Split Logic
# ----------------------------------------------------
func _split():
	var scene = load(SLIME_SCENE_PATH)
	if not scene:
		queue_free()
		return

	for i in range(SPLIT_COUNT):
		var s: CharacterBody2D = scene.instantiate()
		s.size_stage = 0

		var offset_x: float = -16.0 if i == 0 else 16.0
		s.global_position = global_position + Vector2(offset_x, 0)

		get_parent().call_deferred("add_child", s)
		s.call_deferred("_apply_split_force", i)

	died.emit() 
	queue_free()

func _apply_split_force(index: int):
	var dir: float = -1.0 if index == 0 else 1.0
	velocity.x = dir * 120.0
	velocity.y = -220.0

# ----------------------------------------------------
# Damage
# ----------------------------------------------------
func take_damage(dmg: int, source_pos: Vector2):
	if current_state in [State.DIE, State.DEAD]:
		return

	current_health -= dmg
	var max_h: float = BIG_SLIME_HEALTH if size_stage == 1 else SMALL_SLIME_HEALTH
	emit_signal("health_changed", current_health, max_h)

	if current_health <= 0:
		change_state(State.DIE)
	else:
		var dir: float = sign(global_position.x - source_pos.x)
		if dir == 0:
			dir = 1.0

		velocity = Vector2(
			dir * KNOCKBACK_FORCE,
			-KNOCKBACK_FORCE * KNOCKBACK_Y_RATIO
		)
		change_state(State.HIT)

# ----------------------------------------------------
# Animation
# ----------------------------------------------------
func _on_animation_finished():
	if anim.animation == "Slime_Land":
		change_state(State.IDLE)
	elif anim.animation == "Slime_Death":
		change_state(State.DEAD)

# ----------------------------------------------------
# Detection
# ----------------------------------------------------
func _on_detection_body_entered(body):
	if body.is_in_group("player"):
		target_player = body

func _on_detection_body_exited(body):
	if body == target_player:
		target_player = null

# ----------------------------------------------------
# HitBox
# ----------------------------------------------------
func _on_hit_target(damage: int, source_pos: Vector2):
	if current_state in [State.DIE, State.DEAD]:
		return

	if target_player:
		target_player.take_damage(damage, source_pos)
