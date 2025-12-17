class_name FlyingEnemy
extends CharacterBody2D

# ----------------------------------------------------
# ⚙️ الإعدادات والثوابت (Configuration)
# ----------------------------------------------------
const MAX_HEALTH: float = 30.0
const FLY_SPEED: float = 150.0 
const KNOCKBACK_FORCE: float = 200.0
const PATROL_DISTANCE: float = 100.0 # مدى الدوريات الأفقية
# const MOUTH_OFFSET_X: float = 30.0 # 💡 تم إلغاء الإزاحة لإطلاق المقذوفة من المركز 💡

# 🎯 إعدادات الهجوم
const RANGED_ATTACK_RANGE: float = 300.0 # مدى بدء هجوم القذف
const DIVE_THRESHOLD: float = 100.0   # مدى بدء هجوم الغوص (قريب جداً)
const DIVE_SPEED: float = 800.0       # سرعة الغوص
const SHOOT_PREPARE_TIME: float = 1.0 # وقت التحضير قبل الرمي
const ATTACK_DAMAGE: int = 15
const PROJECTILE_SPEED: float = 400.0

# 💡 مسار مشهد المقذوفة (Projectile Scene Path) - يجب تعديله
# NOTE: Replace "Projectile.tscn" with the actual path to your projectile scene.
const PROJECTILE_SCENE = preload("res://projectile.tscn") 

# ----------------------------------------------------
# 🔍 المراجع (Node References)
# ----------------------------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea 
@onready var hitbox: Area2D = $HitBox     # للهجوم الغاطس (Dive Attack)
@onready var hurt_box: Area2D = $HurtBox 
@onready var attack_timer: Timer = $AttackTimer 

# ----------------------------------------------------
# 💡 المتغيرات الداخلية وآلة الحالة
# ----------------------------------------------------
var current_health: float = MAX_HEALTH
var target_player: CharacterBody2D = null
var initial_position: Vector2 
var hit_reaction_timer: float = 0.0

# 🎯 الحالات: تم تقسيم DIVE_ATTACK إلى 3 مراحل
enum State { PATROL, CHASE, SHOOT_PREPARE, SHOOT, DIVE_START, DIVE_FALLING, DIVE_END, HIT, DIE }
var current_state = State.PATROL

# ----------------------------------------------------
# 🏁 دالة الإعداد (Setup)
# ----------------------------------------------------
func _ready():
	initial_position = global_position
	# الاتصال بالإشارات
	if is_instance_valid(hurt_box):
		hurt_box.hit_received.connect(Callable(self, "take_damage"))
	if is_instance_valid(detection_area):
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	# ✅ فحص صلاحية anim قبل ربط الإشارة
	if is_instance_valid(anim):
		anim.animation_finished.connect(_on_animation_finished)
	if is_instance_valid(attack_timer):
		attack_timer.timeout.connect(Callable(self, "_on_attack_timer_timeout"))

	add_to_group("enemies")
	
	# الهيت بوكس معطل في البداية (يفعل فقط أثناء الغوص)
	if is_instance_valid(hitbox) and hitbox.has_method("deactivate"): hitbox.deactivate()
	
	change_state(State.PATROL)

# ----------------------------------------------------
# ⚡ المعالجة الفيزيائية (Physics Loop)
# ----------------------------------------------------
func _physics_process(delta: float):
	if current_state == State.DIE: return
	
	match current_state:
		State.PATROL: _logic_patrol(delta)
		State.CHASE: _logic_chase(delta)
		State.HIT: _logic_hit(delta)
		State.SHOOT_PREPARE, State.SHOOT:
			# التوقف أثناء الرمي
			velocity = velocity.lerp(Vector2.ZERO, delta * 10.0)
		
		# يتم استخدام منطق الغوص في مرحلتين
		State.DIVE_START, State.DIVE_FALLING:
			_logic_dive_falling(delta)
			
		State.DIVE_END:
			# التوقف لحظياً بعد الهبوط
			velocity = velocity.lerp(Vector2.ZERO, delta * 20.0)
			
	move_and_slide()

# ----------------------------------------------------
# 🎮 منطق الحالات (State Logic)
# ----------------------------------------------------

func _logic_patrol(delta: float):
	if target_player: 
		change_state(State.CHASE)
		return

	# حركة Sine/Cosine لنمط الدوريات
	var time = Time.get_ticks_msec() / 1000.0
	var offset_x = sin(time * 1.5) * PATROL_DISTANCE
	var target_pos = initial_position + Vector2(offset_x, 0)
	
	_set_orientation(sign(target_pos.x - global_position.x))
	var direction = (target_pos - global_position).normalized()
	velocity = direction * (FLY_SPEED / 2.0)

func _logic_chase(delta: float):
	if not target_player: 
		change_state(State.PATROL) # العودة للدوريات
		return
	
	var direction_to_player = (target_player.global_position - global_position)
	var distance = direction_to_player.length()
	
	# 1. قرار الهجوم (بناءً على الأولوية)
	
	# 💡 الأولوية 1: هجوم الغوص (إذا كان قريب جداً وأسفل منه)
	if distance < DIVE_THRESHOLD and direction_to_player.y > 0:
		change_state(State.DIVE_START) # يبدأ رسمة الغوص
		return
	
	# 💡 الأولوية 2: هجوم القذف (إذا كان ضمن المدى المتوسط)
	# ✅ الشرط الجديد: يجب أن يكون العدو مواجهاً للاعب لكي يطلق النار
	if distance < RANGED_ATTACK_RANGE and _is_facing_player():
		change_state(State.SHOOT_PREPARE)
		return
		
	# 2. الحركة نحو اللاعب (يستمر في المطاردة إذا لم يهاجم)
	_set_orientation(sign(direction_to_player.x))
	velocity = direction_to_player.normalized() * FLY_SPEED

func _logic_dive_falling(delta: float):
	# التحرك عمودياً للأسفل بسرعة الغوص
	velocity.x = 0
	velocity.y = DIVE_SPEED
	
	# 💡 التحقق من الهبوط:
	if is_on_floor():
		velocity.y = 0
		change_state(State.DIVE_END) # الانتقال إلى رسمة الهبوط (End)
		return
	
	# ✅ ضمان تشغيل DIVE_LOOP مرة واحدة فقط عند الدخول لـ DIVE_FALLING
	if current_state == State.DIVE_FALLING and anim.is_valid() and anim.animation != "Dive_Loop":
		anim.play("Dive_Loop")


func _logic_hit(delta: float):
	hit_reaction_timer -= delta
	if hit_reaction_timer <= 0:
		change_state(State.CHASE if target_player else State.PATROL)
	
	# إبطاء الارتداد
	velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)

# ----------------------------------------------------
# 🔄 تغيير الحالة (State Transitions)
# ----------------------------------------------------
func change_state(new_state: State):
	# إدارة الهيت بوكس (يفعل فقط أثناء السقوط)
	if is_instance_valid(hitbox):
		if new_state == State.DIVE_START or new_state == State.DIVE_FALLING:
			hitbox.activate() # يفعل الهيت بوكس ليضر باللاعب أثناء السقوط
		else:
			hitbox.deactivate()
			
	current_state = new_state
	
	# ✅ فحص صلاحية anim قبل استدعاء play()
	if not is_instance_valid(anim):
		return
		
	match new_state:
		State.PATROL, State.CHASE:
			anim.play("Fly") 
			
		State.SHOOT_PREPARE:
			anim.play("Smash_Start") 
			velocity = Vector2.ZERO
			attack_timer.start(SHOOT_PREPARE_TIME)
			# ✅ عند بدء التحضير، يتم توجيه العدو نحو اللاعب
			if target_player:
				_set_orientation(sign(target_player.global_position.x - global_position.x))
			
		State.SHOOT:
			_shoot_projectile()
			anim.play("Smash_End") 
			
		State.DIVE_START:
			# 💡 يبدأ الحركة (رسوم مرة واحدة)
			anim.play("Dive_Start") 
			
		State.DIVE_FALLING:
			# 💡 حركة السقوط (رسوم حلقة) - قد تكون تشغيلها في _logic_dive_falling أكثر دقة
			pass # يتم تشغيلها في _logic_dive_falling بعد انتهاء Dive_Start
			
		State.DIVE_END:
			# 💡 رسمة الهبوط (رسوم مرة واحدة)
			anim.play("Dive_End") 
			
		State.HIT:
			anim.play("Hit")
			hit_reaction_timer = 0.3
			
		State.DIE:
			# استخدام set_deferred لتجنب الأخطاء في الإطار الحالي
			hurt_box.set_deferred("monitorable", false) 
			anim.play("Die")

# ----------------------------------------------------
# 🎯 منطق الهجوم (Projectile Logic)
# ----------------------------------------------------
func _shoot_projectile():
	if not is_instance_valid(target_player) or not PROJECTILE_SCENE:
		return
		
	var projectile = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(projectile)
	
	var direction = (target_player.global_position - global_position).normalized()
	
	# 💡 تم تعديل: الإطلاق من مركز الكائن (global_position) 💡
	projectile.global_position = global_position
	
	# ✅ تمرير مرجع العدو المُطلق لمنع الاصطدام الذاتي
	if projectile.has_method("launch"):
		projectile.launch(direction, PROJECTILE_SPEED, ATTACK_DAMAGE, self)

# ----------------------------------------------------
# 🎬 معالجة الرسوم والإشارات والدوال المساعدة
# ----------------------------------------------------

# 💡 دالة مساعدة: للتحقق ما إذا كان العدو يواجه اللاعب
func _is_facing_player() -> bool:
	if not target_player: return false
	
	var player_direction_sign = sign(target_player.global_position.x - global_position.x)
	var enemy_facing_sign = _get_facing_direction()
	
	# يواجه اللاعب إذا كانت إشارة اتجاه العدو هي نفسها إشارة اتجاه اللاعب
	return player_direction_sign == enemy_facing_sign

# 💡 دالة مساعدة: تعيد اتجاه العدو (-1 يسار، 1 يمين)
func _get_facing_direction() -> float:
	if not is_instance_valid(anim): return 1.0
	return -1.0 if anim.flip_h else 1.0

func _on_animation_finished():
	var finished_anim = anim.animation

	match finished_anim:
		"Smash_End":
			# العودة إلى المطاردة أو الدوريات بعد القذف
			change_state(State.CHASE if target_player else State.PATROL)
			
		"Dive_Start":
			# بعد انتهاء حركة بدء الغوص، ننتقل إلى حالة السقوط المستمر
			if current_state == State.DIVE_START:
				change_state(State.DIVE_FALLING)
				
		"Dive_End":
			# بعد انتهاء رسمة الهبوط، يعود للمطاردة
			if current_state == State.DIVE_END:
				change_state(State.CHASE if target_player else State.PATROL)
				
		"Die":
			queue_free()
			
		"Hit":
			if current_state == State.HIT:
				change_state(State.CHASE if target_player else State.PATROL)
		
func _on_attack_timer_timeout():
	# إذا انتهى التحضير، ينتقل لحالة الرمي
	if current_state == State.SHOOT_PREPARE:
		change_state(State.SHOOT)

func _on_detection_body_entered(body: Node2D):
	if body.is_in_group("player"):
		target_player = body
		
func _on_detection_body_exited(body: Node2D):
	if body == target_player:
		target_player = null
		
func _set_orientation(direction: float):
	# ✅ فحص صلاحية anim قبل التعديل
	if not is_instance_valid(anim):
		return
		
	if direction != 0:
		anim.flip_h = direction > 0
