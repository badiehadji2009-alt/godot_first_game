extends Area2D

# 🛑 تأكد من تعيين هذا المسار ليتطابق مع مشهد البوس الفعلي لديك
const BOSS_ARENA_PATH = "res://boss_stage.tscn"

@onready var gate_collision_shape: CollisionShape2D = $CollisionShape2D
# يجب أن تكون هذه العقدة Label لعرض الإشعار "اضغط [زر] للدخول". اسمها يجب أن يكون PromptLabel.
@onready var prompt_label: Label = $PromptCanvas/PromptLabel
# 💡 يجب أن تكون هذه العقدة AnimationPlayer وتحتوي على حركة "fade_to_black"
@onready var fade_animator: AnimationPlayer = $AnimationPlayer 

var is_open: bool = false
var player_in_area: bool = false # لتتبع وجود اللاعب حالياً
var can_enter_boss: bool = false # لتتبع السماح بالدخول
var is_transitioning: bool = false # لمنع التحميل المتكرر

func _ready():
	# ربط إشارة body_entered و body_exited
	if is_instance_valid(self):
		self.body_entered.connect(_on_body_entered)
		self.body_exited.connect(_on_body_exited)
	
	# ربط إشارة انتهاء الحركة لتحميل المشهد مرة واحدة فقط
	if is_instance_valid(fade_animator):
		fade_animator.animation_finished.connect(_on_fade_animation_finished)
	
	# الإعدادات الأولية
	monitoring = false
	if is_instance_valid(gate_collision_shape):
		gate_collision_shape.disabled = true
	
	# إخفاء الإشعار في البداية
	if is_instance_valid(prompt_label):
		prompt_label.hide()

# ----------------------------------------------------
## 🔑 وظيفة فتح الباب (تُستدعى من WaveManager)
# ----------------------------------------------------
func open_gate():
	if is_open:
		return
		
	is_open = true
	print("BossGateArea: تم فتح البوابة! يمكنك العبور الآن.")
	
	if is_instance_valid(gate_collision_shape):
		gate_collision_shape.disabled = false 
		monitoring = true 
	
	can_enter_boss = true # السماح بإظهار الإشعار واستقبال الإدخال

# ----------------------------------------------------
## 📥 معالجة إدخال اللاعب (للكشف عن زر الضرب)
# ----------------------------------------------------
func _process(delta):
	# نتحقق فقط إذا كان الباب مفتوحاً واللاعب داخل المنطقة وغير في وضع الانتقال
	if can_enter_boss and player_in_area and not is_transitioning:
		# 🛑 تحقق من ضغط زر الضرب/الفعل (Action)
		# افترض أن اسم الإجراء هو "attack"
		if Input.is_action_just_pressed("attack"):
			_perform_transition()


# ----------------------------------------------------
## 🚀 بدء الانتقال (التعتيم)
# ----------------------------------------------------
func _perform_transition():
	# منع الانتقال المتكرر
	is_transitioning = true # تم التفعيل لمنع الضغط المتكرر
	can_enter_boss = false
	player_in_area = false
	
	if is_instance_valid(prompt_label):
		prompt_label.hide()
	
	# 1. بدء التعتيم
	if is_instance_valid(fade_animator):
		# 💡 تأكد من وجود Animation باسم "fade_to_black" في AnimationPlayer
		fade_animator.play("fade_to_black") 
		print("BossGateArea: بدء التعتيم...")
	else:
		# 2. fallback: إذا لم يكن هناك AnimationPlayer، قم بالانتقال المباشر
		print("BossGateArea: لا يوجد AnimationPlayer، انتقال مباشر.")
		_load_boss_scene() # تحميل المشهد فوراً


# ----------------------------------------------------
## 🎬 انتهاء التعتيم (تحميل المشهد)
# ----------------------------------------------------
func _on_fade_animation_finished(anim_name: String):
	# نتحقق أن الحركة التي انتهت هي حركة تعتيم الشاشة
	if anim_name == "fade_to_black":
		print("BossGateArea: التعتيم انتهى. تحميل مشهد البوس الآن.")
		_load_boss_scene() # 💥 استدعاء الدالة الجديدة لتحميل المشهد

# ----------------------------------------------------
## 🔄 وظيفة تحميل المشهد
# ----------------------------------------------------
func _load_boss_scene():
	# 💡 استخدام get_tree().change_scene_to_file لتحميل المشهد
	if get_tree().change_scene_to_file(BOSS_ARENA_PATH) != OK:
		# 🛠️ تم التعديل من print_error إلى push_error لتجنب خطأ runtime
		push_error("فشل في تحميل مشهد البوس: ", BOSS_ARENA_PATH)


# ----------------------------------------------------
## 🚶‍♂️ دخول المنطقة (ظهور الإشعار)
# ----------------------------------------------------
func _on_body_entered(body: Node2D):
	# نستخدم body.name == "Player" بدلاً من is_in_group("player")
	if body.name == "Player" and can_enter_boss:
		player_in_area = true
		if is_instance_valid(prompt_label):
			# 💡 يمكنك تعديل النص ليتناسب مع زرك
			prompt_label.text = "اضغط [Attack] للدخول!"
			prompt_label.show()


# ----------------------------------------------------
## 🏃‍♂️ مغادرة المنطقة (إخفاء الإشعار)
# ----------------------------------------------------
func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_area = false
		if is_instance_valid(prompt_label):
			prompt_label.hide()
