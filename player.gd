extends CharacterBody2D

signal health_changed(new_health, max_health)

# --- Configuration & Stats ---
@export_group("Stats")
@export var MAX_HEALTH: int = 90
var current_health: int = MAX_HEALTH

@export_group("Movement")
@export var SPEED: float = 300.0
@export var JUMP_VELOCITY: float = -400.0
@export var GRAVITY: float = 980.0
var movement_limit: Rect2 = Rect2()

@export_group("Combat")
@export var DODGE_SPEED: float = 500.0
@export var DODGE_DURATION: float = 0.37
@export var INVULNERABILITY_DURATION: float = 0.5
@export var KNOCKBACK_FORCE: float = 350.0
@export var KNOCKBACK_Y_RATIO: float = 0.5
@export var COMBO_TIME_WINDOW: float = 0.3 

@export var game_over_scene: PackedScene
var game_over_screen: CanvasLayer = null

# --- Nodes ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player = $PlayerSoundLayer/PlayerSFX
@onready var hit_box: Area2D = $PlayerHitBox
@onready var hurt_box: Area2D = $PlayerHurtBox
var initial_hitbox_scale_x: float = 1.0

# --- State Machine ---
enum State { IDLE, RUN, JUMP, ATTACK, ATTACK2, DODGE, HIT, DIE }
var current_state: State = State.IDLE

# --- Timers & Internal Logic ---
var state_timer: float = 0.0
var facing_direction: float = 1.0
var default_collision_mask: int = 1
var knockback_direction: float = 0.0
var combo_timer: float = 0.0 

func _ready() -> void:
	initial_hitbox_scale_x = hit_box.scale.x
	default_collision_mask = collision_mask
	current_health = MAX_HEALTH
	anim_sprite.animation_finished.connect(_on_animation_finished)
	anim_sprite.frame_changed.connect(_on_frame_changed)
	hurt_box.connect("hit_received", Callable(self, "take_damage"))
	_set_hitbox_active(false)
	emit_signal("health_changed", current_health, MAX_HEALTH)

func _physics_process(delta: float) -> void:
	if current_state != State.DIE:
		if not is_on_floor() and current_state != State.DODGE:
			velocity.y += GRAVITY * delta

	if state_timer > 0:
		state_timer -= delta
		
	if combo_timer > 0:
		combo_timer -= delta

	match current_state:
		State.IDLE:
			_state_logic_idle(delta)
		State.RUN:
			_state_logic_run(delta)
		State.JUMP:
			_state_logic_jump(delta)
		State.ATTACK:
			_state_logic_attack(delta)
		State.ATTACK2:
			_state_logic_attack2(delta)
		State.DODGE:
			_state_logic_dodge(delta)
		State.HIT:
			_state_logic_hit(delta)
		State.DIE:
			velocity = Vector2.ZERO
			
	if movement_limit.size != Vector2.ZERO:
		global_position.x = clampf(global_position.x, movement_limit.position.x, movement_limit.position.x + movement_limit.size.x)
		global_position.y = clampf(global_position.y, movement_limit.position.y, movement_limit.position.y + movement_limit.size.y)

	move_and_slide()

# ----------------------------------------------------
## 📝 FSM State Logic
# ----------------------------------------------------

func _state_logic_idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_transition_to_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		_transition_to_state(State.ATTACK)
	elif Input.is_action_just_pressed("dodge") and is_on_floor():
		_transition_to_state(State.DODGE)
	elif Input.get_axis("ui_left", "ui_right") != 0:
		_transition_to_state(State.RUN)
	elif not is_on_floor():
		_transition_to_state(State.JUMP)
	else:
		anim_sprite.play("idle")

func _state_logic_run(_delta: float) -> void:
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing_direction = direction
		anim_sprite.flip_h = (direction < 0)
		hit_box.scale.x = initial_hitbox_scale_x * facing_direction
		anim_sprite.play("run")
	else:
		_transition_to_state(State.IDLE)
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_transition_to_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		_transition_to_state(State.ATTACK)
	elif Input.is_action_just_pressed("dodge") and is_on_floor():
		_transition_to_state(State.DODGE)
	elif not is_on_floor():
		_transition_to_state(State.JUMP)

func _state_logic_jump(_delta: float) -> void:
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing_direction = direction
		anim_sprite.flip_h = (direction < 0)
		hit_box.scale.x = initial_hitbox_scale_x * facing_direction
	if is_on_floor() and velocity.y >= 0:
		if direction == 0: _transition_to_state(State.IDLE)
		else: _transition_to_state(State.RUN)
	if Input.is_action_just_pressed("attack"):
		_transition_to_state(State.ATTACK)

func _state_logic_attack(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and combo_timer > 0:
		_transition_to_state(State.ATTACK2)
		return
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing_direction = direction
		anim_sprite.flip_h = (direction < 0)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)
	hit_box.scale.x = initial_hitbox_scale_x * facing_direction

func _state_logic_attack2(_delta: float) -> void:
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing_direction = direction
		anim_sprite.flip_h = (direction < 0)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)
	hit_box.scale.x = initial_hitbox_scale_x * facing_direction

# ----------------------------------------------------
# 🛠️ المنطق المعدل للدودج (القفز بعد منتصف الوقت)
# ----------------------------------------------------
func _state_logic_dodge(_delta: float) -> void:
	velocity.x = facing_direction * DODGE_SPEED
	velocity.y = 0
	
	# تحقق إذا مر نصف وقت الدودج واللاعب ضغط قفز
	if state_timer < (DODGE_DURATION / 2.0):
		if Input.is_action_just_pressed("jump"):
			_transition_to_state(State.JUMP)
			return
	
	if state_timer <= 0:
		if is_on_floor():
			_transition_to_state(State.IDLE)
		else:
			_transition_to_state(State.JUMP)

func _state_logic_hit(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, KNOCKBACK_FORCE * _delta * 3.0)
	if state_timer <= 0:
		if is_on_floor(): _transition_to_state(State.IDLE)
		else: _transition_to_state(State.JUMP)

# ----------------------------------------------------
## 🔄 State Transition Handler
# ----------------------------------------------------

func _transition_to_state(new_state: State) -> void:
	var previous_state = current_state
	current_state = new_state
	
	match previous_state:
		State.DODGE:
			_set_invulnerable(false)
			collision_mask = default_collision_mask
			_set_hitbox_active(false)
		State.HIT:
			_set_invulnerable(false)
		State.ATTACK:
			_set_hitbox_active(false)
			combo_timer = 0.0
		State.ATTACK2:
			_set_hitbox_active(false)
			combo_timer = 0.0

	match new_state:
		State.JUMP:
			# القفز مسموح من الخمول، الجري، أو أثناء الدودج (بعد التعديل)
			velocity.y = JUMP_VELOCITY
			if sfx_player: sfx_player.play_jump()
		
		State.ATTACK:
			anim_sprite.play("attack")
			anim_sprite.frame = 0
			combo_timer = COMBO_TIME_WINDOW
			if sfx_player: sfx_player.play_attack(1)
			
		State.ATTACK2:
			anim_sprite.play("attack2")
			anim_sprite.frame = 0
			combo_timer = 0.0
			if sfx_player: sfx_player.play_attack(2)
			
		State.DODGE:
			state_timer = DODGE_DURATION
			anim_sprite.play("dodge")
			_set_invulnerable(true)
			collision_mask = (1 << 0)
			if sfx_player: sfx_player.play_dodge()
			
		State.HIT:
			state_timer = INVULNERABILITY_DURATION
			anim_sprite.play("hit")
			_set_invulnerable(true)
		
		State.DIE:
			anim_sprite.play("die")
			_set_invulnerable(true)
			_set_hitbox_active(false)
			velocity = Vector2.ZERO
			if game_over_scene and not is_instance_valid(game_over_screen):
				get_tree().paused = true
				game_over_screen = game_over_scene.instantiate()
				get_tree().root.add_child(game_over_screen)
				game_over_screen.connect("restart_game", Callable(self, "_on_restart_game_requested"))
				game_over_screen.visible = true

# ----------------------------------------------------
## ⚡ Signal Callbacks & Helpers
# ----------------------------------------------------

func set_movement_limit(limits: Rect2):
	movement_limit = limits

func _on_frame_changed() -> void:
	if current_state == State.ATTACK:
		if anim_sprite.frame == 2: _set_hitbox_active(true)
		else: _set_hitbox_active(false)
	elif current_state == State.ATTACK2:
		if anim_sprite.frame == 1: _set_hitbox_active(true)
		else: _set_hitbox_active(false)
	else:
		_set_hitbox_active(false)

func _on_animation_finished() -> void:
	if current_state == State.ATTACK or current_state == State.ATTACK2:
		if is_on_floor():
			if abs(velocity.x) > 10: _transition_to_state(State.RUN)
			else: _transition_to_state(State.IDLE)
		else: _transition_to_state(State.JUMP)
	elif current_state == State.HIT:
		if state_timer <= 0:
			if is_on_floor(): _transition_to_state(State.IDLE)
			else: _transition_to_state(State.JUMP)

func take_damage(damage_amount: int, boss_position: Vector2) -> void:
	if current_state != State.DODGE and current_state != State.HIT:
		current_health -= damage_amount
		emit_signal("health_changed", current_health, MAX_HEALTH)
		if sfx_player: sfx_player.play_hurt()
		if current_health <= 0:
			_transition_to_state(State.DIE)
			return
		var knockback_direction_vector = global_position - boss_position
		knockback_direction = sign(knockback_direction_vector.x)
		velocity.x = knockback_direction * KNOCKBACK_FORCE
		velocity.y = -KNOCKBACK_FORCE * KNOCKBACK_Y_RATIO
		_transition_to_state(State.HIT)

func _on_restart_game_requested():
	var main_scene_path = "res://main.tscn"
	if is_instance_valid(game_over_screen):
		game_over_screen.queue_free()
		game_over_screen = null
	get_tree().paused = false
	if FileAccess.file_exists(main_scene_path):
		get_tree().change_scene_to_file(main_scene_path)

func _set_hitbox_active(is_active: bool) -> void:
	if is_active:
		if hit_box.has_method("activate"): hit_box.activate()
		else: hit_box.set_deferred("monitoring", true)
	else:
		if hit_box.has_method("deactivate"): hit_box.deactivate()
		else: hit_box.set_deferred("monitoring", false)

func _set_invulnerable(is_invulnerable: bool) -> void:
	hurt_box.set_deferred("monitorable", not is_invulnerable)

# دوال فارغة للتوصيل
# اذهب لآخر ملف اللاعب واستبدل الدوال الفارغة بهذا:

func enter_trigger_zone(_body: Node2D):
	print("Player entered trigger zone")

func exit_trigger_zone(_body: Node2D):
	print("Player exited trigger zone")

func _on_boss_gate_area_body_entered(body: Node2D) -> void:
	if body == self:
		print("Player is at the boss gate!")
		# هنا يمكنك إضافة متغير ليسمح بالهجوم للانتقال
		# is_at_gate = true

func _on_boss_gate_area_body_exited(body: Node2D) -> void:
	if body == self:
		print("Player left the boss gate")
		# is_at_gate = false
