extends CharacterBody2D

signal health_changed(new_health, max_health)

# --- الثوابت والخصائص (تعديلات الذكاء لمواجهة الدودج والقفز) ---
const SPEED = 185.0               
const ATTACK_DISTANCE = 90.0      
const HIT_REACTION_DURATION = 0.08 # تقليل جداً لزيادة الصعوبة
const COOLDOWN_DURATION = 0.2    
const ATTACK_LUNGE_SPEED = 280.0  

@export var max_health: int = 640
var current_health: int = max_health

@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- آلة الحالة (FSM) ---
enum State { MOVE, ATTACK, HIT_REACTION, COOLDOWN, DIE }
var current_boss_state: State = State.MOVE 
var state_timer: float = 0.0

var target: CharacterBody2D = null

@onready var animated_sprite = $AnimatedSprite2D
@onready var sfx_player = $BossSFX
@onready var boss_hurt_box = $BossHurtBox as HurtBox
@onready var boss_hit_box = $BossHitBox as HitBox
@onready var boss_ost_player = $BossOSTPlayer 

var initial_hitbox_scale_x: float = 1.0

# --- دالة _ready ---
func _ready():
	initial_hitbox_scale_x = boss_hit_box.scale.x
	target = get_tree().get_first_node_in_group("player")
	
	animated_sprite.animation_finished.connect(Callable(self, "_on_animation_finished"))
	animated_sprite.frame_changed.connect(Callable(self, "_on_attack_frame_changed"))
	boss_hurt_box.connect("hit_received", Callable(self, "take_damage"))
	
	_set_hitbox_active(false)
	emit_signal("health_changed", current_health, max_health)
	
	change_state(State.MOVE)
	
	if is_instance_valid(boss_ost_player):
		boss_ost_player.play()

# ----------------------------------------------------
## 🔄 FSM Transition Handler
# ----------------------------------------------------

func change_state(new_state: State):
	var previous_state = current_boss_state
	current_boss_state = new_state
	
	match previous_state:
		State.MOVE:
			if sfx_player: sfx_player.stop_walk()

	match new_state:
		State.ATTACK:
			_set_hitbox_active(false)
			_face_target() # استدارة ابتدائية
			animated_sprite.play("attack")
		
		State.HIT_REACTION:
			state_timer = HIT_REACTION_DURATION
			_set_hitbox_active(false)
			velocity.x = 0
			animated_sprite.play("hit")
		
		State.COOLDOWN:
			# إذا كان اللاعب يقفز أو يهرب، اجعل وقت الراحة أقصر لملاحقته
			var is_target_jumping = target and not target.is_on_floor()
			state_timer = COOLDOWN_DURATION * (0.5 if is_target_jumping else 1.0)
			velocity.x = 0
		
		State.DIE:
			if is_instance_valid(boss_ost_player):
				boss_ost_player.stop()
			
			var game_enders = get_tree().get_nodes_in_group("game_ender")
			if game_enders.size() > 0:
				game_enders[0].start_game_end()
			
			_set_hitbox_active(false)
			velocity = Vector2.ZERO
			animated_sprite.play("die")
			if sfx_player: sfx_player.play_death()
			
		State.MOVE:
			animated_sprite.play("move")
			if sfx_player: sfx_player.play_walk()

# ----------------------------------------------------
## ⚡ Physics Process & State Logic
# ----------------------------------------------------

func _physics_process(delta: float):
	if current_boss_state == State.DIE:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	
	state_timer -= delta

	match current_boss_state:
		State.MOVE:
			handle_move_state(delta)
		State.ATTACK:
			# الاحتكاك أثناء الهجوم لضمان عدم الانزلاق اللانهائي
			velocity.x = move_toward(velocity.x, 0, SPEED * 1.5 * delta)
			# ذكاء إضافي: تصحيح الاتجاه في الفريمات الأولى للهجوم إذا قفز اللاعب خلفه
			if animated_sprite.frame < 4:
				_face_target()
		State.COOLDOWN:
			handle_cooldown_state(delta)
		State.HIT_REACTION:
			handle_hit_reaction_state(delta)

	move_and_slide()

func _face_target():
	if target and is_instance_valid(target):
		var direction_x = sign(target.global_position.x - global_position.x)
		if direction_x != 0:
			animated_sprite.flip_h = direction_x > 0
			boss_hit_box.scale.x = initial_hitbox_scale_x * direction_x * (-1.0)

func get_distance_to_target():
	if target and is_instance_valid(target):
		return global_position.distance_to(target.global_position)
	return 1000

func handle_move_state(_delta: float):
	var distance = get_distance_to_target()
	if distance <= ATTACK_DISTANCE:
		change_state(State.ATTACK)
		return
	
	if target and is_instance_valid(target):
		_face_target()
		var dir = sign(target.global_position.x - global_position.x)
		velocity.x = dir * SPEED
	else:
		velocity.x = 0

func handle_cooldown_state(_delta: float):
	if state_timer <= 0:
		if get_distance_to_target() <= ATTACK_DISTANCE + 20: # مدى أوسع قليلاً للذكاء
			change_state(State.ATTACK)
		else:
			change_state(State.MOVE)
			
func handle_hit_reaction_state(_delta: float):
	if state_timer <= 0:
		change_state(State.MOVE)

# ----------------------------------------------------
## 🎯 Attack & Damage Logic
# ----------------------------------------------------

func _on_attack_frame_changed():
	if current_boss_state != State.ATTACK:
		return

	var current_frame = animated_sprite.frame
	
	# ذكاء الاندفاع: الاندفاع يكون باتجاه موقع اللاعب الحالي لحظة الضربة
	if current_frame == 3: 
		_face_target() # تصحيح أخير للاتجاه قبل الاندفاع
		var dir = 1 if animated_sprite.flip_h else -1
		velocity.x = dir * ATTACK_LUNGE_SPEED 
		
	if current_frame == 4 or current_frame == 10:
		if sfx_player: sfx_player.play_axe_swing()
		_set_hitbox_active(true)
	elif current_frame == 7 or current_frame == 13:
		_set_hitbox_active(false)

func _on_animation_finished():
	if animated_sprite.animation == "attack":
		_set_hitbox_active(false)
		change_state(State.COOLDOWN)
	elif animated_sprite.animation == "die":
		queue_free()

func take_damage(amount: int, source_position: Vector2):
	if current_boss_state == State.DIE:
		return
		
	current_health -= amount
	if sfx_player: sfx_player.play_hit_received()
	
	if current_health <= 0:
		current_health = 0
		change_state(State.DIE)
		return
	
	# البوس "عنيد"؛ لا يتأثر بالضربات البسيطة أثناء الهجوم ليصعب المهمة
	if current_boss_state != State.ATTACK:
		change_state(State.HIT_REACTION)
		
	emit_signal("health_changed", current_health, max_health)

func _set_hitbox_active(is_active: bool) -> void:
	if is_active:
		boss_hit_box.activate()
	else:
		boss_hit_box.deactivate()
