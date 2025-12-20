extends CharacterBody2D

# ----------------------------------------------------
# ⚔️ الثوابت والإشارات
# ----------------------------------------------------
signal died 
signal health_changed(new_health, max_health)

# --- إعدادات الحركة والفيزياء ---
const MAX_HEALTH: float = 96.0
var current_health: float = MAX_HEALTH
const CHASE_SPEED: float = 120.0
const GRAVITY: float = 980.0     

# --- إعدادات القتال والـ FSM ---
const ATTACK_DISTANCE: float = 50.0 
const ATTACK_DAMAGE: int = 15     
const COMBO_INVULNERABILITY_TIME: float = 0.05 # المناعة القصيرة للكومبو
const HIT_REACTION_DURATION: float = 0.2 # مدة رسوم رد الفعل
const COOLDOWN_DURATION: float = 0.5 

# إعدادات الارتداد عند تلقي الضرر
const KNOCKBACK_FORCE: float = 200.0 
const KNOCKBACK_Y_RATIO: float = 0.4

# ----------------------------------------------------
# 🔍 المراجع (Nodes)
# ----------------------------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea 
@onready var hitbox = $HitBox     
@onready var hurt_box = $HurtBox 

var initial_hitbox_scale_x: float = 1.0 
var initial_hitbox_pos_x: float = 0.0 

# ----------------------------------------------------
# 💡 حالات آلة الحالة (FSM)
# ----------------------------------------------------
enum State { IDLE, MOVE, ATTACK, HIT_REACTION, COOLDOWN, DIE, DEAD }
var current_state: State = State.IDLE

var target_player: CharacterBody2D = null 
var is_dead: bool = false
var state_timer: float = 0.0 
var last_direction: float = -1.0 

var is_immune_from_hit: bool = false # حالة المناعة القصيرة للكومبو

# ----------------------------------------------------
# 🏁 دالة الإعداد
# ----------------------------------------------------
func _ready():
	current_health = MAX_HEALTH
	if is_instance_valid(hitbox):
		initial_hitbox_scale_x = hitbox.scale.x
		initial_hitbox_pos_x = hitbox.position.x 
		hitbox.damage_amount = ATTACK_DAMAGE

	# 🛑 ربط إشارة HurtBox
	if is_instance_valid(hurt_box):
		hurt_box.hit_received.connect(Callable(self, "take_damage"))
	
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_attack_frame_changed)
	_set_hitbox_active(false) 
	
	if is_instance_valid(detection_area):
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	add_to_group("enemies") 
	change_state(State.IDLE) 
	emit_signal("health_changed", current_health, MAX_HEALTH)


# ----------------------------------------------------
# ⚡ Physics Process & State Logic Execution
# ----------------------------------------------------
func _physics_process(delta: float):
	if current_state != State.DEAD:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if state_timer > 0:
			state_timer -= delta

		match current_state:
			State.IDLE:
				_state_logic_idle()
			State.MOVE:
				_state_logic_move()
			State.HIT_REACTION:
				_state_logic_hit_reaction(delta)
			State.COOLDOWN:
				_state_logic_cooldown()
			State.DIE, State.DEAD:
				pass

		move_and_slide()

# ----------------------------------------------------
# 📝 FSM State Logic
# ----------------------------------------------------

func _state_logic_idle():
	velocity.x = move_toward(velocity.x, 0, CHASE_SPEED)
	anim.play("Idle")
	if is_instance_valid(hitbox):
		hitbox.scale.x = abs(initial_hitbox_scale_x) * last_direction * (-1.0)
		hitbox.position.x = abs(initial_hitbox_pos_x) * last_direction * (-1.0)


func _state_logic_move():
	if target_player:
		var direction_x = sign(target_player.global_position.x - global_position.x)
		var distance_to_player = global_position.distance_to(target_player.global_position)
		if direction_x != 0:
			anim.flip_h = direction_x > 0
			last_direction = direction_x 
			if is_instance_valid(hitbox):
				hitbox.scale.x = abs(initial_hitbox_scale_x) * direction_x * (-1.0)
				hitbox.position.x = abs(initial_hitbox_pos_x) * direction_x * (-1.0) 

		if distance_to_player <= ATTACK_DISTANCE:
			change_state(State.ATTACK)
			return
		else:
			velocity.x = direction_x * CHASE_SPEED
			anim.play("Run")
	else:
		change_state(State.IDLE)


func _state_logic_hit_reaction(delta: float):
	velocity.x = move_toward(velocity.x, 0, CHASE_SPEED * delta * 5.0) 
	if state_timer <= 0:
		_set_invulnerable(false)
		change_state(State.MOVE) 

func _state_logic_cooldown():
	if state_timer <= 0:
		change_state(State.MOVE)


# ----------------------------------------------------
# 🔄 FSM Transition Handler
# ----------------------------------------------------
func change_state(new_state: State):
	match current_state:
		State.HIT_REACTION:
			_set_invulnerable(false)

	current_state = new_state
	match new_state:
		State.IDLE:
			velocity.x = 0
		State.ATTACK:
			_set_hitbox_active(false)
			velocity.x = 0
			if is_instance_valid(hitbox):
				hitbox.scale.x = abs(initial_hitbox_scale_x) * last_direction * (1.0)
				hitbox.position.x = abs(initial_hitbox_pos_x) * last_direction * (1.0) 

			anim.play("Attack")
		State.HIT_REACTION:
			state_timer = HIT_REACTION_DURATION
			_set_hitbox_active(false)
			anim.play("Hit")
		State.COOLDOWN:
			state_timer = COOLDOWN_DURATION
			velocity.x = 0
		State.DIE:
			_set_hitbox_active(false)
			_set_invulnerable(true) 
			is_dead = true
			velocity = Vector2.ZERO
			anim.play("Die")
		State.DEAD: 
			set_collision_mask_value(1, false) 
			died.emit()
			queue_free()

# ----------------------------------------------------
# 🎯 Attack & Damage Logic
# ----------------------------------------------------

func _on_attack_frame_changed():
	if current_state != State.ATTACK: 
		_set_hitbox_active(false)
		return

	var current_frame = anim.frame
	if current_frame == 5:
		_set_hitbox_active(true)
	elif current_frame == 8:
		_set_hitbox_active(false)
	elif current_frame > 8:
		_set_hitbox_active(false)


func _on_animation_finished():
	if anim.animation == "Attack":
		_set_hitbox_active(false)
		change_state(State.COOLDOWN)
	elif anim.animation == "Die":
		change_state(State.DEAD) 
	elif anim.animation == "Hit":
		if state_timer <= 0:
			change_state(State.MOVE)

func take_damage(damage_amount: int, source_position: Vector2):
	if current_state == State.DIE or current_state == State.DEAD or is_immune_from_hit:
		return
	
	current_health -= damage_amount 
	emit_signal("health_changed", current_health, MAX_HEALTH)
	
	if current_health <= 0:
		current_health = 0
		change_state(State.DIE)
		return
	
	_set_invulnerable(true) 
	get_tree().create_timer(COMBO_INVULNERABILITY_TIME).timeout.connect(func():
		_set_invulnerable(false)
	)

	var knockback_direction_vector = global_position - source_position
	var knockback_direction = sign(knockback_direction_vector.x)
	velocity.x = knockback_direction * KNOCKBACK_FORCE
	velocity.y = -KNOCKBACK_FORCE * KNOCKBACK_Y_RATIO
	change_state(State.HIT_REACTION)

# ----------------------------------------------------
# 🔎 Detection & Helper Functions
# ----------------------------------------------------
func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		target_player = body
		if current_state == State.IDLE:
			change_state(State.MOVE)

func _on_detection_area_body_exited(body: Node2D):
	if body == target_player:
		target_player = null
		if current_state != State.ATTACK and current_state != State.HIT_REACTION:
			change_state(State.IDLE)


func _set_hitbox_active(is_active: bool) -> void:
	if is_instance_valid(hitbox):
		if is_active:
			hitbox.activate()
		else:
			hitbox.deactivate()

func _set_invulnerable(is_invulnerable_state: bool) -> void:
	is_immune_from_hit = is_invulnerable_state
	if is_instance_valid(hurt_box):
		hurt_box.set_invulnerable(is_invulnerable_state)
