extends CharacterBody2D

# ⚙️ الإعدادات الافتراضية
var damage_amount: int = 15 # قيمة الضرر (يتم تحديثها من قبل العدو)
var direction: Vector2 = Vector2.ZERO
var speed: float = 400.0
# 💡 المرجع إلى الكائن الذي أطلق هذه المقذوفة (لمنع الاصطدام الذاتي)
var shooter: Node2D = null

# 💡 الدالة التي يستدعيها العدو الطائر عند الإطلاق
func launch(dir: Vector2, spd: float, dmg: int, source_shooter: Node2D):
	direction = dir
	speed = spd
	damage_amount = dmg
	shooter = source_shooter
	# إذا كانت لديك رسمة (Sprite) للمقذوفة، يمكنك تدويرها لتواجه الاتجاه:
	# rotation = direction.angle()

func _physics_process(delta):
	# 1. تطبيق الحركة
	velocity = direction * speed
	move_and_slide()
	
	# 2. التحقق من الاصطدام بعد الحركة
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 💡 التجاهل: لا تصطدم بالشخص الذي أطلقها 💡
		if collider == shooter:
			continue
			
		# ✅ إذا اصطدم باللاعب (أو أي كائن ضمن مجموعة 'player')
		if collider and collider.is_in_group("player"):
			# يفترض أن اللاعب لديه دالة take_damage
			if collider.has_method("take_damage"):
				# دمج اللاعب عند لمسه وإلحاق الضرر به
				collider.take_damage(damage_amount, global_position)
			queue_free() # 💡 تدمير المقذوفة فوراً بعد إلحاق الضرر 💡
			return # إنهاء حلقة الاصطدام
			
		# ✅ إذا اصطدم بأي شيء صلب (مثل الحائط، مجموعة 'solid_objects')
		if collider and collider.is_in_group("solid_objects"):
			queue_free() # 💡 تدمير المقذوفة فوراً 💡
			return
